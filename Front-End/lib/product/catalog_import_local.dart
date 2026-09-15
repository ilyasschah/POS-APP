/// The local half of the XML product import: the file lands in the local
/// catalogue FIRST — sellable at the till straight away, online or not — and
/// every row is queued in the catalog import outbox, which the sync's push
/// phase drains to the server in batches (`lib/sync/catalog_import_sync.dart`).
///
/// 🚨 Why: the import used to POST every row in ONE request and only then pull
/// the result back. A 5,000-product export ran far past the client's receive
/// timeout ("Server took too long to respond"), and the till had nothing to show
/// for it.
///
/// What a row does here mirrors `ImportProductsCommandHandler` on the server —
/// products matched by name, groups by name along the row's path, taxes by rate
/// AND kind, a barcode already on another product reported rather than taken —
/// so the catalogue the till shows before the upload is the one it gets back.
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/product/catalog_transfer.dart';
import 'package:pos_app/product/csv_codec.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

/// `sync_status` of a catalogue row the XML import wrote and the server has not
/// acknowledged yet.
///
/// Deliberately NOT `pending_create`: those are pushed one request per row by
/// their own pushers (`/Products/Add`, `/Barcodes/Add` …) — exactly the slow,
/// non-idempotent path the import avoids. These travel with their import row
/// instead, and `CatalogImportUploader` settles them when the server answers.
const String kPendingImport = 'pending_import';

/// A products XML file, read: the rows `/Products/ImportBulk` takes and the
/// group skeleton `/ProductGroups/ImportBulk` takes.
typedef ParsedCatalogXml = ({
  List<Map<String, dynamic>> rows,
  List<GroupNode> groups,
});

/// Decodes and parses a picked XML file on a background isolate.
///
/// Drift — and so the local write — has to stay on the UI isolate (SQLCipher's
/// key is applied there), so the part that CAN leave it does: a DOM parse of a
/// megabytes-long export froze the screen for as long as it ran.
Future<ParsedCatalogXml> parseCatalogXmlInBackground(List<int> bytes) =>
    Isolate.run(() {
      final text = decodeCsvBytes(bytes);
      return parseProductsXmlWithGroups(
          text.startsWith('﻿') ? text.substring(1) : text);
    });

/// What the local import did.
class LocalImportOutcome {
  const LocalImportOutcome({
    required this.jobId,
    required this.created,
    required this.updated,
    required this.skipped,
    required this.queued,
    required this.alreadyQueued,
    required this.warnings,
  });

  final String jobId;
  final int created;
  final int updated;
  final int skipped;

  /// Rows now waiting for the server.
  final int queued;

  /// Rows not queued again because the very same row is still waiting from an
  /// earlier import of the file.
  final int alreadyQueued;

  final List<String> warnings;
}

/// Writes an XML import into the local catalogue and the import outbox.
class LocalCatalogImporter {
  LocalCatalogImporter(this.db, {this.chunkSize = 500});

  final AppDatabase db;

  /// Rows per transaction. Drift runs on the UI isolate, so a chunk holds the
  /// frame while it commits: small enough to keep the progress bar moving, large
  /// enough that 5,000 rows are ten commits rather than 5,000 — and ten rounds of
  /// the catalogue screens' watch queries, not 5,000.
  final int chunkSize;

  /// Jobs this process is writing right now. A job left at 'importing' that is
  /// NOT in here was interrupted (the app closed mid-import); the uploader
  /// releases it rather than wait for a finish that will never come.
  static final Set<String> activeJobs = <String>{};

  Future<LocalImportOutcome> importProducts({
    required int companyId,
    required List<Map<String, dynamic>> rows,
    required bool merge,
    List<GroupNode> groups = const [],
    String? fileName,
    void Function(int done, int total)? onProgress,
  }) async {
    final jobId = const Uuid().v4();
    activeJobs.add(jobId);
    try {
      await db.into(db.catalogImportJobsTable).insert(
            CatalogImportJobsTableCompanion.insert(
              id: jobId,
              companyId: companyId,
              mergeDuplicates: merge,
              createdAt: DateTime.now().toUtc(),
              fileName: Value(fileName),
              groupsJson:
                  Value(jsonEncode([for (final g in groups) g.toImportJson()])),
              totalRows: Value(rows.length),
            ),
          );

      final run = await _ImportRun.load(db,
          companyId: companyId, jobId: jobId, merge: merge);
      await db.batch((b) => run.writeGroups(b, groups));

      // Each chunk commits its catalogue rows and their outbox rows TOGETHER, so
      // an app closed mid-import leaves every written product queued — never a
      // product the server will not hear about.
      for (var start = 0; start < rows.length; start += chunkSize) {
        final end = math.min(start + chunkSize, rows.length);
        await db.batch((b) {
          for (var i = start; i < end; i++) {
            run.writeRow(b, i, rows[i]);
          }
        });
        onProgress?.call(end, rows.length);
        // Hand the shared isolate back between chunks so a frame can paint.
        await Future<void>.delayed(Duration.zero);
      }

      final nothingToSend = run.queued == 0;
      await (db.update(db.catalogImportJobsTable)
            ..where((t) => t.id.equals(jobId)))
          .write(CatalogImportJobsTableCompanion(
        status: Value(nothingToSend ? 'completed' : 'pending'),
        groupsSent: nothingToSend ? const Value(true) : const Value.absent(),
        completedAt: nothingToSend
            ? Value(DateTime.now().toUtc())
            : const Value.absent(),
      ));

      return LocalImportOutcome(
        jobId: jobId,
        created: run.created,
        updated: run.updated,
        skipped: run.skipped,
        queued: run.queued,
        alreadyQueued: run.alreadyQueued,
        warnings: run.warnings,
      );
    } finally {
      activeJobs.remove(jobId);
    }
  }
}

// ── internals ───────────────────────────────────────────────────────────────

String _nameKey(String s) => s.trim().toLowerCase();

String? _clean(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

double? _num(Object? v) => v is num ? v.toDouble() : null;

bool? _flag(Object? v) => v is bool ? v : null;

Value<T> _present<T>(T? v) => v == null ? Value<T>.absent() : Value<T>(v);

String _short(String s) => s.length > 60 ? '${s.substring(0, 60)}…' : s;

String _rate(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

String _taxKey(double rate, bool isFixed) => '$rate|$isFixed';

/// A real id beats a temp one, then the lowest — the server's own "first by id"
/// when two products share a name.
bool _preferred(int candidate, int current) {
  if ((candidate > 0) != (current > 0)) return candidate > 0;
  return candidate.abs() < current.abs();
}

class _LocalProduct {
  _LocalProduct(this.id, this.uomId, this.packSize, this.barcode);

  final int id;
  int uomId;
  double? packSize;
  String? barcode;
}

class _QueuedRow {
  const _QueuedRow(this.jobId, this.rowIndex, this.payload, this.merge);

  final String jobId;
  final int rowIndex;
  final String payload;
  final bool merge;
}

/// One import's view of the catalogue, loaded once and kept current as rows are
/// written — so a row sees the products, groups and barcodes the rows before it
/// created, exactly as the server's own import cache does.
class _ImportRun {
  _ImportRun._(this.db,
      {required this.companyId, required this.jobId, required this.merge});

  final AppDatabase db;
  final int companyId;
  final String jobId;
  final bool merge;
  final DateTime now = DateTime.now().toUtc();

  final Map<String, _LocalProduct> products = {};
  final Map<String, int> groupIds = {};
  final Map<String, GroupNode> skeleton = {};
  final Map<String, int> taxIds = {};
  final Map<String, int> barcodeOwner = {};
  final Set<String> productTaxes = {};
  final Map<String, _QueuedRow> queuedByKey = {};

  int created = 0;
  int updated = 0;
  int skipped = 0;
  int queued = 0;
  int alreadyQueued = 0;
  final List<String> warnings = [];

  // Temp ids with 16 digits: three past the product editor's
  // -millisecondsSinceEpoch, so the two schemes can never meet, and a later
  // import starts a whole millisecond × 1000 further on than this one.
  int _nextTempId = -(DateTime.now().millisecondsSinceEpoch * 1000);
  int _takeTempId() => _nextTempId--;

  static Future<_ImportRun> load(
    AppDatabase db, {
    required int companyId,
    required String jobId,
    required bool merge,
  }) async {
    final run =
        _ImportRun._(db, companyId: companyId, jobId: jobId, merge: merge);
    const notDeleted = ['pending_delete'];

    // Only the columns a merge needs — `products.image` is a blob.
    final p = db.productsTable;
    for (final r in await (db.selectOnly(p)
          ..addColumns([p.id, p.name, p.uomId, p.packSize, p.barcode])
          ..where(p.companyId.equals(companyId) &
              p.syncStatus.isNotIn(notDeleted)))
        .get()) {
      final id = r.read(p.id)!;
      final key = _nameKey(r.read(p.name) ?? '');
      final current = run.products[key];
      if (current == null || _preferred(id, current.id)) {
        run.products[key] = _LocalProduct(id, r.read(p.uomId) ?? kUomPieces,
            r.read(p.packSize), r.read(p.barcode));
      }
    }

    final g = db.productGroupsTable;
    for (final r in await (db.selectOnly(g)
          ..addColumns([g.id, g.name])
          ..where(g.companyId.equals(companyId) &
              g.syncStatus.isNotIn(notDeleted)))
        .get()) {
      final id = r.read(g.id)!;
      final key = _nameKey(r.read(g.name) ?? '');
      final current = run.groupIds[key];
      if (current == null || _preferred(id, current)) run.groupIds[key] = id;
    }

    for (final t in await (db.select(db.taxesTable)
          ..where((t) =>
              t.companyId.equals(companyId) & t.syncStatus.isNotIn(notDeleted)))
        .get()) {
      final key = _taxKey(t.rate, t.isFixed);
      final current = run.taxIds[key];
      if (current == null || _preferred(t.id, current)) run.taxIds[key] = t.id;
    }

    final bc = db.barcodesTable;
    for (final r in await (db.selectOnly(bc)
          ..addColumns([bc.value, bc.productId])
          ..where(bc.companyId.equals(companyId) &
              bc.syncStatus.isNotIn(notDeleted)))
        .get()) {
      run.barcodeOwner.putIfAbsent(r.read(bc.value)!, () => r.read(bc.productId)!);
    }

    final pt = db.productTaxesTable;
    for (final r in await (db.selectOnly(pt)
          ..addColumns([pt.productId, pt.taxId])
          ..where(pt.companyId.equals(companyId) &
              pt.syncStatus.isNotIn(notDeleted)))
        .get()) {
      run.productTaxes.add('${r.read(pt.productId)}:${r.read(pt.taxId)}');
    }

    // Rows still waiting from earlier imports, oldest first so the newest wins.
    for (final r in await db.customSelect(
      'SELECT r.job_id, r.row_index, r.name_key, r.payload, j.merge_duplicates '
      'FROM catalog_import_rows r '
      'JOIN catalog_import_jobs j ON j.id = r.job_id '
      "WHERE r.company_id = ? AND r.status = 'pending' "
      'ORDER BY j.created_at, r.row_index',
      variables: [Variable.withInt(companyId)],
      readsFrom: {db.catalogImportRowsTable, db.catalogImportJobsTable},
    ).get()) {
      run.queuedByKey[r.read<String>('name_key')] = _QueuedRow(
        r.read<String>('job_id'),
        r.read<int>('row_index'),
        r.read<String>('payload'),
        r.read<bool>('merge_duplicates'),
      );
    }
    return run;
  }

  /// The file's own groups, parents first, so each one's colour and rank are
  /// right from the start — the product rows alone would create them plain.
  void writeGroups(Batch b, List<GroupNode> groups) {
    for (final shape in orderParentsFirst(groups)) {
      skeleton[shape.key] = shape;
      final existing = groupIds[shape.key];
      if (existing != null) {
        if (merge) {
          b.update(
            db.productGroupsTable,
            ProductGroupsTableCompanion(
                colorHex: Value(shape.color), rank: Value(shape.rank)),
            where: (t) => t.id.equals(existing),
          );
        }
        continue;
      }
      final parent = shape.parentName == null
          ? null
          : groupIds[_nameKey(shape.parentName!)];
      _createGroup(b, shape.name, parent);
    }
  }

  void writeRow(Batch b, int index, Map<String, dynamic> row) {
    final name = _clean(row['name']);
    if (name == null) return;
    final key = _nameKey(name);
    final existing = products[key];

    final int productId;
    if (existing != null && !merge) {
      skipped++;
      productId = existing.id;
    } else {
      final groupId = _resolveGroup(b, row);
      final barcodes = _barcodesOf(row);
      if (existing != null) {
        productId = existing.id;
        _mergeProduct(b, existing, row, groupId, barcodes);
        updated++;
      } else {
        productId = _takeTempId();
        _createProduct(b, productId, key, name, row, groupId, barcodes);
        created++;
      }
      _attachTax(b, productId, name, row);
      _attachBarcodes(b, productId, name, barcodes);
    }
    _enqueue(b, index, key, productId, row);
  }

  // ── groups ────────────────────────────────────────────────────────────────

  int _createGroup(Batch b, String name, int? parentId) {
    final key = _nameKey(name);
    final shape = skeleton[key];
    final id = _takeTempId();
    b.insert(
      db.productGroupsTable,
      ProductGroupsTableCompanion.insert(
        id: Value(id),
        companyId: companyId,
        name: name,
        lastModified: now,
        parentGroupId: Value(parentId),
        colorHex: Value(shape?.color ?? 'Transparent'),
        rank: Value(shape?.rank ?? 0),
        syncStatus: const Value(kPendingImport),
      ),
    );
    groupIds[key] = id;
    return id;
  }

  /// The server's rule: the leaf's NAME finds an existing group, used where it
  /// is; only a leaf that does not exist is built, with any missing link above.
  int? _resolveGroup(Batch b, Map<String, dynamic> row) {
    final chain = [
      for (final link in (row['productGroupPath'] as List?) ?? const [])
        if (_clean(link) != null) _clean(link)!,
    ];
    if (chain.isEmpty && _clean(row['productGroupName']) != null) {
      chain.add(_clean(row['productGroupName'])!);
    }
    if (chain.isEmpty) return null;

    final leaf = groupIds[_nameKey(chain.last)];
    if (leaf != null) return leaf;

    int? parent;
    for (final link in chain) {
      parent = groupIds[_nameKey(link)] ?? _createGroup(b, link, parent);
    }
    return parent;
  }

  // ── products ──────────────────────────────────────────────────────────────

  void _createProduct(Batch b, int id, String key, String name,
      Map<String, dynamic> row, int? groupId, List<String> barcodes) {
    final unit = _clean(row['measurementUnit']);
    final uomId = uomFromLegacyText(unit);
    final packSize = normalisePackSize(uomId, _num(row['packSize']));
    b.insert(
      db.productsTable,
      ProductsTableCompanion.insert(
        id: Value(id),
        companyId: companyId,
        name: name,
        lastModified: now,
        price: Value(_num(row['price']) ?? 0),
        cost: Value(_num(row['cost']) ?? 0),
        markup: Value(_num(row['markup'])),
        code: Value(_clean(row['code'])),
        barcode: Value(barcodes.isEmpty ? null : barcodes.first),
        productGroupId: Value(groupId),
        measurementUnit: Value(unit),
        uomId: Value(uomId),
        isToWeigh: Value(row['isToWeigh'] == true),
        packSize: Value(packSize),
        description: Value(row['description'] as String?),
        isTaxInclusivePrice: Value(_flag(row['isTaxInclusivePrice']) ?? true),
        isPriceChangeAllowed: Value(_flag(row['isPriceChangeAllowed']) ?? false),
        isService: Value(_flag(row['isService']) ?? false),
        isUsingDefaultQuantity:
            Value(_flag(row['isUsingDefaultQuantity']) ?? true),
        isEnabled: Value(_flag(row['isEnabled']) ?? true),
        colorHex: Value(_clean(row['color']) ?? 'Transparent'),
        dateCreated: Value(now),
        dateUpdated: Value(now),
        syncStatus: const Value(kPendingImport),
      ),
    );
    products[key] = _LocalProduct(
        id, uomId, packSize, barcodes.isEmpty ? null : barcodes.first);
  }

  /// A value the row does not carry keeps the product's own — the server's
  /// merge rule, so a file that says nothing about a field never blanks it.
  void _mergeProduct(Batch b, _LocalProduct existing, Map<String, dynamic> row,
      int? groupId, List<String> barcodes) {
    final unit = _clean(row['measurementUnit']);
    final uomId = unit != null ? uomFromLegacyText(unit) : existing.uomId;
    final packSize =
        normalisePackSize(uomId, _num(row['packSize']) ?? existing.packSize);
    final firstBarcode = existing.barcode == null && barcodes.isNotEmpty
        ? barcodes.first
        : null;

    b.update(
      db.productsTable,
      ProductsTableCompanion(
        productGroupId: _present(groupId),
        code: _present(_clean(row['code'])),
        measurementUnit: _present(unit),
        uomId: Value(uomId),
        packSize: Value(packSize),
        price: _present(_num(row['price'])),
        cost: _present(_num(row['cost'])),
        markup: _present(_num(row['markup'])),
        description: _present(row['description'] as String?),
        isTaxInclusivePrice: _present(_flag(row['isTaxInclusivePrice'])),
        isPriceChangeAllowed: _present(_flag(row['isPriceChangeAllowed'])),
        isService: _present(_flag(row['isService'])),
        isUsingDefaultQuantity: _present(_flag(row['isUsingDefaultQuantity'])),
        isEnabled: _present(_flag(row['isEnabled'])),
        // The server ORs it: a file never switches weighing off.
        isToWeigh: row['isToWeigh'] == true
            ? const Value(true)
            : const Value.absent(),
        colorHex: _present(_clean(row['color'])),
        barcode: _present(firstBarcode),
        dateUpdated: Value(now),
        lastModified: Value(now),
      ),
      where: (t) => t.id.equals(existing.id),
    );
    existing
      ..uomId = uomId
      ..packSize = packSize
      ..barcode = existing.barcode ?? firstBarcode;
  }

  void _attachTax(
      Batch b, int productId, String name, Map<String, dynamic> row) {
    final rate = _num(row['taxRate']);
    if (rate == null) return;
    final fixed = row['taxIsFixed'] == true;
    final taxId = taxIds[_taxKey(rate, fixed)];
    if (taxId == null) {
      warnings.add(fixed
          ? "'${_short(name)}': no fixed tax of ${_rate(rate)} in this company — imported without a tax"
          : "'${_short(name)}': no tax at ${_rate(rate)}% in this company — imported without a tax");
      return;
    }
    if (!productTaxes.add('$productId:$taxId')) return;
    b.insert(
      db.productTaxesTable,
      ProductTaxesTableCompanion.insert(
        productId: productId,
        taxId: taxId,
        companyId: companyId,
        syncStatus: const Value(kPendingImport),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  List<String> _barcodesOf(Map<String, dynamic> row) => {
        for (final v in [...?(row['barcodes'] as List?), row['barcode']])
          if (_clean(v) != null) _clean(v)!,
      }.toList();

  void _attachBarcodes(
      Batch b, int productId, String name, List<String> barcodes) {
    for (final value in barcodes) {
      final owner = barcodeOwner[value];
      if (owner != null) {
        if (owner != productId) {
          warnings.add(
              "'${_short(name)}': barcode $value already belongs to another product — not added");
        }
        continue;
      }
      b.insert(
        db.barcodesTable,
        BarcodesTableCompanion.insert(
          localId: const Uuid().v4(),
          productId: productId,
          companyId: companyId,
          value: value,
          syncStatus: const Value(kPendingImport),
        ),
      );
      barcodeOwner[value] = productId;
    }
  }

  // ── outbox ────────────────────────────────────────────────────────────────

  /// Queues the row for the server — unless the very same row is already
  /// waiting, which is what importing one file twice before it uploads does.
  void _enqueue(Batch b, int index, String key, int productId,
      Map<String, dynamic> row) {
    final payload = jsonEncode(row);
    final earlier = queuedByKey[key];
    if (earlier != null && earlier.payload == payload && earlier.merge == merge) {
      alreadyQueued++;
      return;
    }
    // A newer file's values for a product an older import has not sent yet:
    // sending both would only write the stale values first.
    if (earlier != null && merge && earlier.jobId != jobId) {
      b.update(
        db.catalogImportRowsTable,
        const CatalogImportRowsTableCompanion(
          status: Value('cancelled'),
          message: Value('superseded by a later import'),
        ),
        where: (t) =>
            t.jobId.equals(earlier.jobId) &
            t.rowIndex.equals(earlier.rowIndex) &
            t.status.equals('pending'),
      );
    }
    b.insert(
      db.catalogImportRowsTable,
      CatalogImportRowsTableCompanion.insert(
        jobId: jobId,
        rowIndex: index,
        companyId: companyId,
        nameKey: key,
        payload: payload,
        localProductId: Value(productId),
      ),
    );
    queuedByKey[key] = _QueuedRow(jobId, index, payload, merge);
    queued++;
  }
}
