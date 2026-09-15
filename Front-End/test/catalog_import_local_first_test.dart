// The XML product import, local-first: a file lands in this till's catalogue
// first, then reaches the server in batches from the sync's push phase.
//
// 🚨 Why this exists: the import used to POST a whole file in ONE request, and a
// 5,000-product export died with "Server took too long to respond" — with
// nothing saved on the till either. These pin the new path end to end against a
// fake server that behaves like the real ImportBulk (products and groups matched
// by NAME, a per-row outcome and id), through every way an upload is interrupted.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/product/catalog_import_local.dart';
import 'package:pos_app/product/catalog_transfer.dart';
import 'package:pos_app/product/product_export_model.dart';
import 'package:pos_app/sync/catalog_import_sync.dart';
import 'package:pos_app/sync/sync_manager.dart';
import 'package:pos_app/uom/unit_of_measure.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quiet_sync_logs.dart';

const _company = 25;

/// `/Products/ImportBulk` and `/ProductGroups/ImportBulk`, reduced to the rules
/// the upload relies on: a product or a group is identified by its NAME, so a
/// row sent twice lands on the same id. Everything else answers 404.
class _FakeCatalogServer implements HttpClientAdapter {
  final Map<String, int> productIds = {};
  final Map<int, String> productNames = {};
  final Map<String, int> groupIds = {};
  int _nextId = 1000;

  /// Rows in each product batch the server APPLIED, in order.
  final List<int> appliedBatches = [];
  int productCalls = 0;
  int groupCalls = 0;

  bool offline = false;

  /// An API from before per-row results: no `rows`, no `groups`.
  bool oldApi = false;

  /// Product calls (1-based) answered 500 with nothing applied.
  final Set<int> failCalls = {};

  /// Product calls applied, after which the connection drops unanswered.
  final Set<int> dropAfterApplyCalls = {};

  /// Any batch carrying a row of this name is refused with a 400.
  String? refuseRowNamed;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (offline) throw const SocketException('Network is unreachable');
    final bytes = requestStream == null
        ? const <int>[]
        : await requestStream.expand((chunk) => chunk).toList();
    final body = bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes)) as Map;

    if (options.path.endsWith('/ProductGroups/ImportBulk')) {
      groupCalls++;
      return _json(_importGroups(body!));
    }
    if (options.path.endsWith('/Products/ImportBulk')) {
      final call = ++productCalls;
      final rows = (body!['rows'] as List).cast<Map<String, dynamic>>();
      if (failCalls.contains(call)) {
        return _json({'message': 'Execution Timeout Expired'}, 500);
      }
      if (refuseRowNamed != null && rows.any((r) => r['name'] == refuseRowNamed)) {
        return _json({
          'message': 'The JSON value could not be converted to System.Decimal.',
        }, 400);
      }
      final result = _importProducts(body['mergeDuplicates'] == true, rows);
      appliedBatches.add(rows.length);
      if (dropAfterApplyCalls.contains(call)) {
        throw const SocketException('Connection reset by peer');
      }
      return _json(result);
    }
    return ResponseBody.fromString('null', 404);
  }

  Map<String, dynamic> _importGroups(Map body) {
    final named = <String>{
      for (final r in (body['rows'] as List).cast<Map>()) ...[
        if (r['parentGroupName'] is String) r['parentGroupName'] as String,
        r['name'] as String,
      ],
    };
    for (final name in named) {
      groupIds.putIfAbsent(name.toLowerCase(), () => _nextId++);
    }
    return {
      'created': 0, 'updated': 0, 'skipped': 0, 'errors': [], 'warnings': [],
      if (!oldApi)
        'groups': [
          for (final name in named) {'name': name, 'id': groupIds[name.toLowerCase()]},
        ],
    };
  }

  Map<String, dynamic> _importProducts(bool merge, List<Map<String, dynamic>> rows) {
    final results = <Map<String, dynamic>>[];
    var created = 0, updated = 0, skipped = 0;
    for (var i = 0; i < rows.length; i++) {
      final name = (rows[i]['name'] as String).trim();
      for (final link in (rows[i]['productGroupPath'] as List?) ?? const []) {
        groupIds.putIfAbsent('$link'.toLowerCase(), () => _nextId++);
      }
      final existing = productIds[name.toLowerCase()];
      if (existing != null && !merge) {
        skipped++;
        results.add({'index': i, 'outcome': 'skipped', 'productId': existing});
        continue;
      }
      final id = existing ?? (productIds[name.toLowerCase()] = _nextId++);
      productNames[id] = name;
      if (existing == null) {
        created++;
      } else {
        updated++;
      }
      results.add({
        'index': i,
        'outcome': existing == null ? 'created' : 'updated',
        'productId': id,
      });
    }
    return {
      'created': created, 'updated': updated, 'skipped': skipped,
      'errors': [], 'warnings': [],
      if (!oldApi) 'rows': results,
    };
  }

  ResponseBody _json(Object data, [int status = 200]) => ResponseBody.fromString(
        jsonEncode(data),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

ProductExportRow _product(
  String name, {
  String? group,
  List<String> barcodes = const [],
  int uomId = kUomPieces,
  String? unit,
  bool isToWeigh = false,
  double? packSize,
  double price = 10,
  String color = 'Transparent',
  String? description,
  List<TaxExportItem> taxes = const [],
}) =>
    ProductExportRow(
      id: name.hashCode,
      name: name,
      productGroupName: group,
      code: 'SKU-$name',
      measurementUnit: unit,
      uomId: uomId,
      isToWeigh: isToWeigh,
      packSize: packSize,
      cost: 4,
      price: price,
      isTaxInclusivePrice: true,
      isPriceChangeAllowed: false,
      isUsingDefaultQuantity: true,
      isService: false,
      isEnabled: true,
      description: description,
      totalStock: 0,
      reorderPoint: 0,
      preferredQuantity: 0,
      isLowStockWarningEnabled: false,
      lowStockWarningQuantity: 0,
      color: color,
      barcodes: barcodes,
      taxes: taxes,
    );

/// An export of [count] products "Product 0…", barcodes "B0…".
String _catalogue(int count, {String? group}) => buildProductsXml(
      [
        for (var i = 0; i < count; i++)
          _product('Product $i', group: group, barcodes: ['B$i']),
      ],
      [if (group != null) GroupNode(name: group)],
    );

Dio _dioFor(_FakeCatalogServer server) =>
    Dio(BaseOptions(baseUrl: 'http://test.local/api'))..httpClientAdapter = server;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The restart test opens a second database on a file beside the in-memory one.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() {
    // Every endpoint but the two imports answers 404 — see quiet_sync_logs.
    silenceDebugPrint();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  /// A picked file, read the way the import screen reads it.
  Future<LocalImportOutcome> importXml(AppDatabase into, String xml,
      {bool merge = true}) async {
    final parsed = await parseCatalogXmlInBackground(utf8.encode(xml));
    return LocalCatalogImporter(into).importProducts(
      companyId: _company,
      rows: parsed.rows,
      groups: parsed.groups,
      merge: merge,
      fileName: 'products_export.xml',
    );
  }

  CatalogImportUploader uploaderFor(AppDatabase on, _FakeCatalogServer server,
          {int maxBatchSize = 250}) =>
      CatalogImportUploader(
        db: on,
        dio: _dioFor(server),
        initialBatchSize: math.min(100, maxBatchSize),
        maxBatchSize: maxBatchSize,
      );

  /// Sync after sync until the queue is empty, as the notifier does.
  Future<void> drain(CatalogImportUploader uploader) async {
    do {
      await uploader.push(_company);
    } while (uploader.hasMoreWork);
  }

  Future<List<ProductsTableData>> products(AppDatabase on) =>
      (on.select(on.productsTable)..where((t) => t.companyId.equals(_company))).get();

  Future<Map<String, int>> rowStatuses(AppDatabase on) async => {
        for (final r in await on
            .customSelect(
                'SELECT status, COUNT(*) AS c FROM catalog_import_rows GROUP BY status')
            .get())
          r.read<String>('status'): r.read<int>('c'),
      };

  Future<CatalogImportJobsTableData> onlyJob(AppDatabase on) async =>
      (await on.select(on.catalogImportJobsTable).get()).single;

  // ── Small file ────────────────────────────────────────────────────────────

  test('a small file lands in the local catalogue first, then syncs under real ids',
      () async {
    await db.into(db.taxesTable).insert(TaxesTableCompanion.insert(
        id: const Value(7),
        companyId: _company,
        name: 'VAT 20',
        rate: 20,
        lastModified: DateTime.utc(2026)));
    final vat = TaxExportItem(
        id: 7, name: 'VAT 20', rate: 20, isFixed: false, isTaxOnTotal: false, isEnabled: true);
    final xml = buildProductsXml([
      _product('Mint tea', group: 'Hot', barcodes: ['555', '666'], taxes: [vat]),
      _product('Saffron',
          group: 'Drinks', uomId: kUomKilogram, unit: 'kg', isToWeigh: true, price: 12.5),
      _product('Loose', barcodes: ['777']),
    ], const [
      GroupNode(name: 'Drinks', color: '#FF0000FF'),
      GroupNode(name: 'Hot', parentName: 'Drinks', color: '#FFFF0000', rank: 2),
    ]);

    final outcome = await importXml(db, xml);

    expect(outcome.created, 3);
    expect(outcome.queued, 3);
    expect(outcome.warnings, isEmpty);

    // Usable at the till before the server has heard a word of it.
    final before = await products(db);
    expect(before, hasLength(3));
    expect(before.every((p) => p.id < 0 && p.syncStatus == kPendingImport), isTrue);
    final groupsBefore = {
      for (final g in await db.select(db.productGroupsTable).get()) g.name: g,
    };
    expect(groupsBefore['Hot']!.parentGroupId, groupsBefore['Drinks']!.id);
    expect(groupsBefore['Hot']!.colorHex, '#FFFF0000');
    expect(before.singleWhere((p) => p.name == 'Mint tea').productGroupId,
        groupsBefore['Hot']!.id);
    final saffron = before.singleWhere((p) => p.name == 'Saffron');
    expect(saffron.uomId, kUomKilogram);
    expect(saffron.isToWeigh, isTrue);
    expect((await db.select(db.barcodesTable).get()).map((b) => b.value),
        unorderedEquals(['555', '666', '777']));
    expect(await db.select(db.productTaxesTable).get(), hasLength(1));

    final server = _FakeCatalogServer();
    await drain(uploaderFor(db, server));

    expect(server.groupCalls, 1);
    expect(server.appliedBatches, [3]);
    final after = await products(db);
    expect({for (final p in after) p.name: p.id},
        {for (final e in server.productNames.entries) e.value: e.key});
    expect(after.map((p) => p.syncStatus).toSet(), {'synced'});

    final groupsAfter = {
      for (final g in await db.select(db.productGroupsTable).get()) g.name: g,
    };
    expect(groupsAfter['Hot']!.id, server.groupIds['hot']);
    expect(groupsAfter['Hot']!.parentGroupId, server.groupIds['drinks']);
    expect(after.singleWhere((p) => p.name == 'Mint tea').productGroupId,
        server.groupIds['hot']);

    final barcodes = await db.select(db.barcodesTable).get();
    expect(barcodes.every((b) => b.productId > 0 && b.syncStatus == 'synced'), isTrue);
    final tax = (await db.select(db.productTaxesTable).get()).single;
    expect(tax.productId, server.productIds['mint tea']);
    expect(tax.syncStatus, 'synced');

    expect((await onlyJob(db)).status, 'completed');
    expect(await rowStatuses(db), {'done': 3});
  });

  test('merging into an existing product changes only what the file carries',
      () async {
    await db.into(db.productsTable).insert(ProductsTableCompanion.insert(
          id: const Value(42),
          companyId: _company,
          name: 'Tea',
          lastModified: DateTime.utc(2026),
          price: const Value(5),
          description: const Value('keep me'),
          isToWeigh: const Value(true),
        ));

    // Same product in another case, a new price, no description, not weighed.
    final outcome = await importXml(db, buildProductsXml([_product('tea', price: 7)], const []));

    expect(outcome.updated, 1);
    final tea = (await products(db)).single;
    expect(tea.id, 42);
    expect(tea.price, 7);
    expect(tea.description, 'keep me');
    expect(tea.isToWeigh, isTrue, reason: 'a file never switches weighing off');
    expect(tea.syncStatus, 'synced',
        reason: 'the change travels in its import row, not through the product push');
  });

  // ── 5,000+ products ───────────────────────────────────────────────────────

  test('5,200 products: written locally in chunks, uploaded in bounded batches, each row once',
      () async {
    const total = 5200;
    final xml = buildProductsXml(
      [
        for (var i = 0; i < total; i++)
          _product('Product $i',
              group: 'Group ${i % 50}',
              barcodes: ['20${i.toString().padLeft(11, '0')}'],
              price: 10.0 + i % 7),
      ],
      [
        const GroupNode(name: 'Catalogue'),
        for (var g = 0; g < 50; g++) GroupNode(name: 'Group $g', parentName: 'Catalogue'),
      ],
    );

    final clock = Stopwatch()..start();
    final parsed = await parseCatalogXmlInBackground(utf8.encode(xml));
    final parseMs = clock.elapsedMilliseconds;
    expect(parsed.rows, hasLength(total));

    final progress = <int>[];
    var longestChunkMs = 0;
    var last = 0;
    clock.reset();
    final outcome = await LocalCatalogImporter(db).importProducts(
      companyId: _company,
      rows: parsed.rows,
      groups: parsed.groups,
      merge: true,
      onProgress: (done, _) {
        progress.add(done);
        longestChunkMs = math.max(longestChunkMs, clock.elapsedMilliseconds - last);
        last = clock.elapsedMilliseconds;
      },
    );
    final localMs = clock.elapsedMilliseconds;

    expect(outcome.created, total);
    expect(outcome.queued, total);
    expect(progress, [for (var d = 500; d < total; d += 500) d, total],
        reason: 'the screen hears after every chunk, not once at the end');
    expect(await products(db), hasLength(total));
    expect(await db.select(db.productGroupsTable).get(), hasLength(51));

    final server = _FakeCatalogServer();
    clock.reset();
    await drain(uploaderFor(db, server));
    final uploadMs = clock.elapsedMilliseconds;

    expect(server.productIds, hasLength(total));
    expect(server.appliedBatches.fold<int>(0, (a, b) => a + b), total,
        reason: 'every row sent exactly once');
    expect(server.appliedBatches.every((n) => n <= 250), isTrue);
    final after = await products(db);
    expect(after.where((p) => p.id < 0), isEmpty);
    expect(after.map((p) => p.id).toSet(), server.productIds.values.toSet());
    expect(await rowStatuses(db), {'done': total});

    // ignore: avoid_print
    print('[perf] ${(xml.length / 1024 / 1024).toStringAsFixed(1)} MB XML, $total products: '
        'parse on a background isolate ${parseMs}ms; local write ${localMs}ms in '
        '${progress.length} chunks (longest ${longestChunkMs}ms); upload ${uploadMs}ms in '
        '${server.appliedBatches.length} batches ${server.appliedBatches}');
  }, timeout: const Timeout(Duration(minutes: 5)));

  // ── Duplicate / repeated import ───────────────────────────────────────────

  test('the same file imported twice queues each row once and duplicates nothing',
      () async {
    final xml = _catalogue(30, group: 'Shelf');

    final first = await importXml(db, xml);
    final again = await importXml(db, xml); // before any of it has uploaded

    expect(first.created, 30);
    expect(again.created, 0);
    expect(again.updated, 30);
    expect(again.queued, 0);
    expect(again.alreadyQueued, 30);
    expect(await products(db), hasLength(30));
    expect(await db.select(db.barcodesTable).get(), hasLength(30));
    expect(await db.select(db.productGroupsTable).get(), hasLength(1));
    expect(await rowStatuses(db), {'pending': 30});

    final server = _FakeCatalogServer();
    final uploader = uploaderFor(db, server);
    await drain(uploader);
    expect(server.appliedBatches.fold<int>(0, (a, b) => a + b), 30,
        reason: 'once — not once per import');

    // And again after the upload, in both modes: sent, since the server is the
    // judge of what it holds, and still nothing twice.
    for (final merge in [true, false]) {
      final later = await importXml(db, xml, merge: merge);
      expect(later.created, 0);
      await drain(uploader);
    }

    expect(server.productIds, hasLength(30));
    final after = await products(db);
    expect(after, hasLength(30));
    expect(after.every((p) => p.id > 0 && p.syncStatus == 'synced'), isTrue);
    expect(await db.select(db.barcodesTable).get(), hasLength(30));
    expect(await db.select(db.productGroupsTable).get(), hasLength(1));
  });

  // ── Failed batch, retry ───────────────────────────────────────────────────

  test('a failed batch keeps its rows pending with the reason; the retry finishes without duplicates',
      () async {
    await importXml(db, _catalogue(250));
    final server = _FakeCatalogServer()..failCalls.add(2);
    final uploader = uploaderFor(db, server, maxBatchSize: 100);

    await expectLater(uploader.push(_company), throwsA(isA<DioException>()));

    expect(await rowStatuses(db), {'done': 100, 'pending': 150});
    final failed = await onlyJob(db);
    expect(failed.status, 'pending');
    expect(failed.attempts, 1);
    expect(failed.lastError, contains('Execution Timeout Expired'));
    final halfway = await products(db);
    expect(halfway.where((p) => p.id > 0), hasLength(100));
    expect(halfway.where((p) => p.id < 0 && p.syncStatus == kPendingImport), hasLength(150));

    // The retry: the next sync.
    await drain(uploader);

    expect(server.appliedBatches, [100, 100, 50]);
    expect(server.productIds, hasLength(250));
    expect(await rowStatuses(db), {'done': 250});
    final done = await onlyJob(db);
    expect(done.status, 'completed');
    expect(done.lastError, isNull);
    expect((await products(db)).every((p) => p.id > 0), isTrue);
  });

  test('a batch the server applied but whose answer was lost is resent — onto the same products',
      () async {
    await importXml(db, _catalogue(150));
    final server = _FakeCatalogServer()..dropAfterApplyCalls.add(1);
    final uploader = uploaderFor(db, server, maxBatchSize: 100);

    await expectLater(uploader.push(_company), throwsA(isA<DioException>()));
    expect(server.productIds, hasLength(100));
    expect(await rowStatuses(db), {'pending': 150}, reason: 'this till never heard back');

    await drain(uploader);

    expect(server.productIds, hasLength(150), reason: 'the resend updated, it did not duplicate');
    expect(server.appliedBatches, [100, 100, 50]);
    final outcomes = {
      for (final r in await db
          .customSelect('SELECT outcome, COUNT(*) AS c FROM catalog_import_rows GROUP BY outcome')
          .get())
        r.read<String>('outcome'): r.read<int>('c'),
    };
    expect(outcomes, {'updated': 100, 'created': 50});
    expect((await products(db)).map((p) => p.id).toSet(), server.productIds.values.toSet());
  });

  test('in skip mode a resent batch comes back "skipped" with its ids, and the till re-pulls them',
      () async {
    await importXml(db, _catalogue(40), merge: false);
    await db.into(db.syncMetaTable).insert(SyncMetaTableCompanion.insert(
        entity: 'products', lastSyncedAt: Value(DateTime.utc(2026, 9, 1))));
    final server = _FakeCatalogServer()..dropAfterApplyCalls.add(1);
    final uploader = uploaderFor(db, server);

    await expectLater(uploader.push(_company), throwsA(isA<DioException>()));
    await drain(uploader);

    expect(server.productIds, hasLength(40));
    expect((await products(db)).map((p) => p.id).toSet(), server.productIds.values.toSet());
    expect(await db.select(db.syncMetaTable).get(), isEmpty,
        reason: 'a skipped product is unchanged server-side, so only a full pull brings its copy');
  });

  test('a row the server refuses outright fails alone; the rest of its batch syncs',
      () async {
    await importXml(
        db,
        buildProductsXml(
            [for (final n in ['A', 'B', 'C', 'Broken', 'D', 'E', 'F', 'G']) _product(n)],
            const []));
    final server = _FakeCatalogServer()..refuseRowNamed = 'Broken';

    await drain(uploaderFor(db, server));

    expect(server.productNames.values.toSet(), {'A', 'B', 'C', 'D', 'E', 'F', 'G'});
    expect(await rowStatuses(db), {'done': 7, 'failed': 1});
    final broken = (await products(db)).singleWhere((p) => p.name == 'Broken');
    expect(broken.id, lessThan(0), reason: 'kept on this till');
    expect(broken.syncStatus, 'sync_failed');
    expect(broken.syncError, contains('could not be converted'));
    final job = await onlyJob(db);
    expect(job.status, 'completed');
    expect(await loadRefusedCatalogImportRows(db, job.id), [startsWith('Broken — ')]);
  });

  // ── Offline → online ──────────────────────────────────────────────────────

  test('offline: the products work on this till at once; the upload completes once back online',
      () async {
    await importXml(db, _catalogue(40, group: 'Shelf'));
    final server = _FakeCatalogServer()..offline = true;
    final uploader = uploaderFor(db, server);

    await expectLater(uploader.push(_company), throwsA(isA<DioException>()));

    expect(server.groupCalls + server.productCalls, 0);
    expect(await rowStatuses(db), {'pending': 40});
    expect((await onlyJob(db)).lastError, 'The server could not be reached');

    // A scan finds the product before the server has ever seen it.
    final scanned =
        await (db.select(db.barcodesTable)..where((t) => t.value.equals('B7'))).getSingle();
    final product = await (db.select(db.productsTable)
          ..where((t) => t.id.equals(scanned.productId)))
        .getSingle();
    expect(product.name, 'Product 7');

    server.offline = false;
    await drain(uploader);

    expect(server.productIds, hasLength(40));
    expect(await rowStatuses(db), {'done': 40});
    final job = await onlyJob(db);
    expect(job.status, 'completed');
    expect(job.lastError, isNull);
  });

  test('the upload runs inside SyncManager.sync() as its own push step', () async {
    SharedPreferences.setMockInitialValues({});
    await importXml(db, _catalogue(20));
    final server = _FakeCatalogServer();

    final failed = await SyncManager(db: db, dio: _dioFor(server), authStorage: AuthStorage())
        .sync(_company);

    expect(failed, isNot(contains('push:catalogImport')));
    expect(failed, isNot(contains('catalogImport:reconcile')));
    expect(server.productIds, hasLength(20));
    expect(await rowStatuses(db), {'done': 20});
  });

  // ── Application restart ───────────────────────────────────────────────────

  test('the app closed mid-upload: after a restart the upload resumes and nothing is duplicated',
      () async {
    final dir = await Directory.systemTemp.createTemp('catalog_import_restart_');
    final file = File('${dir.path}${Platform.pathSeparator}pos.sqlite');
    final server = _FakeCatalogServer()..dropAfterApplyCalls.add(3);

    // First run: two batches land, the third is applied server-side and the app
    // dies before the answer arrives.
    final firstRun = AppDatabase.forTesting(NativeDatabase(file));
    await importXml(firstRun, _catalogue(600));
    await expectLater(uploaderFor(firstRun, server, maxBatchSize: 100).push(_company),
        throwsA(isA<DioException>()));
    expect(await rowStatuses(firstRun), {'done': 200, 'pending': 400});
    await firstRun.close();

    // Second run: a new process — new connection, new uploader.
    final secondRun = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(() async {
      await secondRun.close();
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });
    expect(await rowStatuses(secondRun), {'done': 200, 'pending': 400},
        reason: 'the queue survived the restart');

    await drain(uploaderFor(secondRun, server, maxBatchSize: 100));

    expect(server.productIds, hasLength(600));
    expect(await rowStatuses(secondRun), {'done': 600});
    final local = await products(secondRun);
    expect(local, hasLength(600));
    expect(local.map((p) => p.id).toSet(), server.productIds.values.toSet());
  });

  test('an import the app closed mid-write still uploads every product it saved',
      () async {
    final outcome = await importXml(db, _catalogue(30));
    // As if the app died before the job was finalised.
    await (db.update(db.catalogImportJobsTable)..where((t) => t.id.equals(outcome.jobId)))
        .write(const CatalogImportJobsTableCompanion(status: Value('importing')));

    final server = _FakeCatalogServer();
    await drain(uploaderFor(db, server));

    expect(server.productIds, hasLength(30));
    expect((await onlyJob(db)).status, 'completed');
  });

  test('a product deleted on this till before it uploaded is never sent', () async {
    await importXml(db, _catalogue(3));
    final doomed = (await products(db)).singleWhere((p) => p.name == 'Product 1');
    await (db.delete(db.productsTable)..where((t) => t.id.equals(doomed.id))).go();

    final server = _FakeCatalogServer();
    await drain(uploaderFor(db, server));

    expect(server.productNames.values.toSet(), {'Product 0', 'Product 2'});
    expect(await rowStatuses(db), {'done': 2, 'cancelled': 1});
  });

  test('an older API with no per-row ids: rows are matched by name once the pull brings them',
      () async {
    await importXml(db, _catalogue(5, group: 'Shelf'));
    final server = _FakeCatalogServer()..oldApi = true;
    final uploader = uploaderFor(db, server);

    await drain(uploader);
    expect(server.productIds, hasLength(5));
    expect((await products(db)).where((p) => p.id < 0), hasLength(5),
        reason: 'no ids to swap in yet');

    // What pullProductGroups and pullProducts write.
    await db.into(db.productGroupsTable).insert(ProductGroupsTableCompanion.insert(
        id: Value(server.groupIds['shelf']!),
        companyId: _company,
        name: 'Shelf',
        lastModified: DateTime.utc(2026)));
    for (final e in server.productNames.entries) {
      await db.into(db.productsTable).insert(ProductsTableCompanion.insert(
          id: Value(e.key),
          companyId: _company,
          name: e.value,
          lastModified: DateTime.utc(2026),
          productGroupId: Value(server.groupIds['shelf'])));
    }
    await uploader.reconcileByName(_company);

    final local = await products(db);
    expect(local, hasLength(5));
    expect(local.map((p) => p.id).toSet(), server.productIds.values.toSet());
    expect(await db.select(db.productGroupsTable).get(), hasLength(1));
    expect((await db.select(db.barcodesTable).get()).every((b) => b.productId > 0), isTrue);
  });

  // ── Existing XML export ───────────────────────────────────────────────────

  test('the existing XML export still round-trips through the local-first import',
      () async {
    final exported = buildProductsXml([
      _product('Eggs',
          group: 'Hot',
          uomId: kUomBox,
          unit: 'box',
          packSize: 30,
          barcodes: ['111', '222'],
          color: '#FF4CAF50',
          description: 'Fresh "free range" <local> & farmed',
          price: 3.5),
    ], const [
      GroupNode(name: 'Drinks', color: '#FF0000FF'),
      GroupNode(name: 'Hot', parentName: 'Drinks'),
    ]);

    // The export writes what the server import has always read.
    final row = parseProductsXml(exported).single;
    expect(row['productGroupPath'], ['Drinks', 'Hot']);
    expect(row['barcodes'], ['111', '222']);

    await importXml(db, exported);

    final eggs = (await products(db)).single;
    expect(eggs.uomId, kUomBox);
    expect(eggs.packSize, 30);
    expect(eggs.price, 3.5);
    expect(eggs.colorHex, '#FF4CAF50');
    expect(eggs.description, 'Fresh "free range" <local> & farmed');
    expect(eggs.description, row['description'],
        reason: 'the local import keeps exactly what the export wrote');
    expect(eggs.barcode, '111');
    final groups = {for (final g in await db.select(db.productGroupsTable).get()) g.id: g};
    final hot = groups[eggs.productGroupId]!;
    expect(hot.name, 'Hot');
    expect(groups[hot.parentGroupId]!.name, 'Drinks');
    expect(groups[hot.parentGroupId]!.colorHex, '#FF0000FF');
    expect((await db.select(db.barcodesTable).get()).map((b) => b.value),
        unorderedEquals(['111', '222']));
  });
}
