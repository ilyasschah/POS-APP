// Reproduces the two-device failure seen live on 2026-08-06.
//
// FACTS FROM THE LIVE SYSTEM (not a hypothetical):
//   • cloud `Document` for company 25 held exactly TWO rows — ids 55 and 93.
//     The gap 56..92 is real: ~37 documents were created and later deleted,
//     cleanly (zero orphaned DocumentItem / Payment / DiscountLine rows).
//   • POS1's local DB matched the cloud: the same two documents.
//   • POS2 displayed **35** documents, including POS1-200-000031..35 — sales
//     that no longer exist anywhere, totalling real money.
//
// Cause: `pullDocuments` could only ever INSERT or UPDATE. A deleted row reports
// no `DateUpdated`, so the delta watermark cannot surface it and a document
// removed on one terminal lived forever on every other one — inflating that
// device's document list, dashboard and Z-report with phantom revenue.
//
// `_reconcileDeletedDocuments` closes it on a full-window pass. These tests pin
// that it removes what the server dropped, and — just as important — that it
// never touches the three categories that only LOOK absent.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/sync/sync_manager.dart';

/// Serves a canned `/Document/GetSalesHistory` payload; every other endpoint
/// 404s so nothing else in the pull can accidentally succeed.
class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.salesHistory);

  final List<Map<String, dynamic>> salesHistory;
  final List<String> requestedUris = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? _, Future<void>? __) async {
    requestedUris.add(options.uri.toString());
    if (options.path.contains('GetSalesHistory')) {
      return ResponseBody.fromString(
        jsonEncode(salesHistory),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString('null', 404);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _serverDoc(int id, String number) => {
      'id': id,
      'number': number,
      'total': 35.0,
      'discount': 0.0,
      'paidStatus': 1,
      'documentTypeId': 2,
      'warehouseId': 17,
      'userId': 9,
      'date': '2026-07-26T20:00:00.000Z',
      'stockDate': '2026-07-26T20:00:00.000Z',
      'items': <Map<String, dynamic>>[],
    };

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  SyncManager managerFor(_CannedAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api'))
      ..httpClientAdapter = adapter;
    return SyncManager(db: db, dio: dio, authStorage: AuthStorage());
  }

  /// A document this device pulled from the server earlier.
  Future<void> insertPulledDoc(int serverId, String number,
      {String syncStatus = 'synced', DateTime? date}) async {
    await db.into(db.documentsTable).insert(
          DocumentsTableCompanion.insert(
            localId: 'srv_$serverId',
            companyId: 25,
            userId: 9,
            warehouseId: 17,
            date: date ?? DateTime.utc(2026, 7, 26, 20),
            serverId: Value(serverId),
            number: Value(number),
            total: const Value(35.0),
            syncStatus: Value(syncStatus),
            lastModified: DateTime.utc(2026, 7, 26, 20),
          ),
        );
  }

  Future<List<int?>> localServerIds() async =>
      (await db.select(db.documentsTable).get()).map((d) => d.serverId).toList();

  test('documents deleted on another terminal are retired here — the POS2 bug',
      () async {
    // POS2's July-26 snapshot: ids 55 and 93 plus the 56..92 range that has
    // since been deleted server-side.
    await insertPulledDoc(55, 'POS1-200-000001');
    await insertPulledDoc(93, 'POS1-200-000036');
    for (var id = 56; id <= 92; id++) {
      await insertPulledDoc(id, 'POS1-200-${id.toString().padLeft(6, '0')}');
    }
    expect(await localServerIds(), hasLength(39));

    // The server now reports only the two survivors — exactly what the live
    // `Document` table holds.
    final adapter = _CannedAdapter([
      _serverDoc(55, 'POS1-200-000001'),
      _serverDoc(93, 'POS1-200-000036'),
    ]);
    await managerFor(adapter).pullDocuments(25);

    // Against the pre-fix code this is still 39 — the 35-documents-on-POS2 bug.
    final remaining = await localServerIds();
    expect(remaining, hasLength(2),
        reason: 'the 37 deleted documents must not survive locally');
    expect(remaining.toSet(), {55, 93});
  });

  test('a deleted document takes its items, payments and discount lines with it',
      () async {
    await insertPulledDoc(60, 'POS1-200-000006');
    await db.into(db.documentItemsTable).insert(
          DocumentItemsTableCompanion.insert(
            localId: 'item-1',
            documentId: 'srv_60',
            productId: 1,
            quantity: 1,
            unitPrice: 35,
            total: 35,
          ),
        );

    await managerFor(_CannedAdapter(const [])).pullDocuments(25);

    expect(await db.select(db.documentsTable).get(), isEmpty);
    expect(await db.select(db.documentItemsTable).get(), isEmpty,
        reason: 'orphaned children are what the whole delete bug is made of');
  });

  group('never retires something that only looks absent', () {
    test('a locally-created document the server has never seen', () async {
      // No serverId → it is PENDING, not missing. Retiring it would delete a
      // sale that has not been pushed yet.
      await db.into(db.documentsTable).insert(
            DocumentsTableCompanion.insert(
              localId: 'local-uuid-1',
              companyId: 25,
              userId: 9,
              warehouseId: 17,
              date: DateTime.utc(2026, 7, 26, 20),
              number: const Value('POS2-200-000001'),
              syncStatus: const Value('pending'),
              lastModified: DateTime.utc(2026, 7, 26, 20),
            ),
          );

      await managerFor(_CannedAdapter(const [])).pullDocuments(25);

      expect(await db.select(db.documentsTable).get(), hasLength(1),
          reason: 'an unpushed local sale must survive');
    });

    test('a document with an unpushed local edit', () async {
      // The pusher owns a pending_* row until it lands; this must not race it.
      await insertPulledDoc(70, 'POS1-200-000016',
          syncStatus: 'pending_update');

      await managerFor(_CannedAdapter(const [])).pullDocuments(25);

      expect(await db.select(db.documentsTable).get(), hasLength(1));
    });

    test('history older than the 90-day window the server was asked about',
        () async {
      // The server was never asked about this date, so its silence proves
      // nothing. Local history reaches back further than the pull window.
      await insertPulledDoc(10, 'POS1-200-000000',
          date: DateTime.now().toUtc().subtract(const Duration(days: 200)));

      await managerFor(_CannedAdapter(const [])).pullDocuments(25);

      expect(await db.select(db.documentsTable).get(), hasLength(1),
          reason: 'outside the pulled window — absence is not evidence');
    });
  });

  group('an operator-pressed Sync reconciles deletions immediately', () {
    // The acceptance criterion, in the user's own words: "if i deleted from POS1
    // and i clicked on sync on POS2 it should be deleted". The 6-hour throttle
    // that keeps BACKGROUND syncs cheap must never make someone wait for that.

    test('a manual sync retires the deletion even right after a full pass',
        () async {
      await insertPulledDoc(55, 'POS1-200-000001');
      await insertPulledDoc(60, 'POS1-200-000006');

      // First sync (fresh device) — full pass, nothing deleted yet server-side.
      await managerFor(_CannedAdapter([
        _serverDoc(55, 'POS1-200-000001'),
        _serverDoc(60, 'POS1-200-000006'),
      ])).pullDocuments(25);
      expect(await localServerIds(), hasLength(2));

      // POS1 now deletes doc 60. The operator taps Sync on POS2 seconds later —
      // well inside the 6-hour reconcile window.
      await managerFor(_CannedAdapter([_serverDoc(55, 'POS1-200-000001')]))
          .pullDocuments(25, forceFullPull: true);

      expect(await localServerIds(), [55],
          reason: 'a manual sync must not defer to the background cadence');
    });

    test('a background sync inside the window stays cheap and delta-only',
        () async {
      await insertPulledDoc(55, 'POS1-200-000001');
      await insertPulledDoc(60, 'POS1-200-000006');
      await managerFor(_CannedAdapter([
        _serverDoc(55, 'POS1-200-000001'),
        _serverDoc(60, 'POS1-200-000006'),
      ])).pullDocuments(25);

      // Same deletion, but this is the hourly/connectivity sync, not the button.
      final adapter = _CannedAdapter([_serverDoc(55, 'POS1-200-000001')]);
      await managerFor(adapter).pullDocuments(25);

      // It sends a watermark (delta) and does NOT reconcile — by design, so the
      // background traffic stays small. The manual path above is the guarantee.
      expect(adapter.requestedUris.single, contains('modifiedAfter='));
      expect(await localServerIds(), hasLength(2));
    });

    test('a full pass sends no watermark, so absence is meaningful', () async {
      final adapter = _CannedAdapter(const []);
      await managerFor(adapter).pullDocuments(25, forceFullPull: true);
      // Load-bearing: with a watermark the server returns only CHANGED rows, so
      // "not returned" would wrongly look like "deleted" for every quiet row.
      expect(adapter.requestedUris.single, isNot(contains('modifiedAfter=')));
    });
  });

  test('the pull asks for every document type, not just sales', () async {
    // The other half of the same report: GetSalesHistory defaults to
    // DocumentTypeId == 2, so refunds and purchases could never cross devices.
    final adapter = _CannedAdapter(const []);
    await managerFor(adapter).pullDocuments(25);

    final uri = adapter.requestedUris.single;
    for (final type in [1, 2, 4]) {
      expect(uri, contains('documentTypeIds=$type'));
    }
  });

  // ── Number-collision adoption (reported 2026-08-15) ───────────────────────
  //
  // `pullDocuments` "Case 1b" adopts a local row that has no serverId but whose
  // NUMBER matches an incoming server document, stamping it `synced`. That is
  // right for a row the server has already seen, and destroys money when it has
  // not: `synced` retires the row from the push queue forever, so the sale never
  // reaches the cloud while the local row starts impersonating a different
  // server document that merely shares its number.
  //
  // Document numbers are per-terminal sequences, so a collision is near-guaranteed
  // after a RESTORE: a till works offline issuing POS1-200-000004, dies, and its
  // backup is restored onto a new machine while the account has its own
  // …000004. This is the reported "the cloud overwrote my restored data".
  group('a pending document is never adopted by number', () {
    /// A sale rung up on THIS device that has never been pushed: no serverId,
    /// pending_create. Row 4 of the operator's screenshot.
    Future<void> insertUnsyncedDoc(String number) async {
      await db.into(db.documentsTable).insert(
            DocumentsTableCompanion.insert(
              localId: 'local-offline-sale',
              companyId: 25,
              userId: 9,
              warehouseId: 17,
              date: DateTime.utc(2026, 8, 13, 10),
              serverId: const Value(null),
              number: Value(number),
              total: const Value(88.0),
              // 'pending' — what a POS checkout actually writes. An
              // earlier version of this fixture used 'pending_create' (the
              // manual document editor's status) and so passed against a guard
              // that did not cover real sales at all.
              syncStatus: const Value('pending'),
              lastModified: DateTime.utc(2026, 8, 13, 10),
            ),
          );
    }

    test('it keeps its pending status and stays pushable', () async {
      await insertUnsyncedDoc('POS1-200-000004');

      // The cloud's OWN …000004 — a different sale, same number.
      final adapter = _CannedAdapter([_serverDoc(109, 'POS1-200-000004')]);
      await managerFor(adapter).pullDocuments(25);

      final local = await (db.select(db.documentsTable)
            ..where((t) => t.localId.equals('local-offline-sale')))
          .getSingle();

      // Pre-fix: serverId 109 and syncStatus 'synced' — the two days of takings
      // silently retired from the push queue and never seen by the cloud again.
      expect(local.syncStatus, 'pending',
          reason: 'the pusher owns it until the server has actually seen it');
      expect(local.serverId, isNull,
          reason: 'adopting the server id makes it impersonate another sale');
      expect(local.total, 88.0, reason: 'its own money must survive');
    });

    test('the server document is still stored, as a separate row', () async {
      await insertUnsyncedDoc('POS1-200-000004');

      final adapter = _CannedAdapter([_serverDoc(109, 'POS1-200-000004')]);
      await managerFor(adapter).pullDocuments(25);

      // Refusing to adopt must not mean dropping the server's document — both
      // sales are real and both have to exist.
      final all = await db.select(db.documentsTable).get();
      expect(all, hasLength(2));
      expect(all.map((d) => d.serverId).toSet(), {null, 109});
    });

    test('a NON-pending row with no serverId is still adopted', () async {
      // The legitimate Case 1b: pushed through its own queue, server assigned
      // the number, local row never got its id stamped. Adoption is correct
      // here and must keep working — the guard has to be narrow.
      await db.into(db.documentsTable).insert(
            DocumentsTableCompanion.insert(
              localId: 'awaiting-id-stamp',
              companyId: 25,
              userId: 9,
              warehouseId: 17,
              date: DateTime.utc(2026, 7, 26, 20),
              serverId: const Value(null),
              number: const Value('POS1-200-000007'),
              total: const Value(35.0),
              syncStatus: const Value('synced'),
              lastModified: DateTime.utc(2026, 7, 26, 20),
            ),
          );

      final adapter = _CannedAdapter([_serverDoc(120, 'POS1-200-000007')]);
      await managerFor(adapter).pullDocuments(25);

      final row = await (db.select(db.documentsTable)
            ..where((t) => t.localId.equals('awaiting-id-stamp')))
          .getSingle();
      expect(row.serverId, 120, reason: 'this one SHOULD adopt');
      expect(await db.select(db.documentsTable).get(), hasLength(1),
          reason: 'adoption exists to prevent a duplicate row');
    });

    // Both statuses, explicitly. The first version of this guard listed only
    // the manual editor's pending_create/update/delete and therefore protected
    // nothing a cashier ever rings up. Naming both here is what stops that
    // regressing.
    for (final status in const ['pending', 'pending_create', 'pending_update']) {
      test('status "$status" is never adopted by number', () async {
        await db.into(db.documentsTable).insert(
              DocumentsTableCompanion.insert(
                localId: 'doc-$status',
                companyId: 25,
                userId: 9,
                warehouseId: 17,
                date: DateTime.utc(2026, 8, 13, 10),
                serverId: const Value(null),
                number: const Value('POS1-200-000009'),
                total: const Value(42.0),
                syncStatus: Value(status),
                lastModified: DateTime.utc(2026, 8, 13, 10),
              ),
            );

        final adapter = _CannedAdapter([_serverDoc(200, 'POS1-200-000009')]);
        await managerFor(adapter).pullDocuments(25);

        final row = await (db.select(db.documentsTable)
              ..where((t) => t.localId.equals('doc-$status')))
            .getSingle();
        expect(row.serverId, isNull, reason: '$status must stay pushable');
        expect(row.syncStatus, status);
      });
    }
  });
}
