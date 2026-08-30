// A sale in a session's PAYMENTS tab but missing from its DOCUMENTS tab.
//
// 🚨 Reported 2026-08-29 on two devices sharing a register. Device A listed five
// documents for session 22; device B listed four — POS1-200-000011 was gone —
// while device B's Payments tab held that document's payment perfectly.
//
// Verified against the live server: all four sales carried `SessionId = 22`. So
// the server always knew. The two halves of one sale simply arrived by
// different routes:
//
//   • the PAYMENT carried its `SessionId` in the sales-history payload and was
//     translated to the local session on pull;
//   • the DOCUMENT carried nothing, and had to be GUESSED back onto a session
//     locally by `attachOrphanSalesToSession` — company + time window + number
//     prefix. Anything the guess missed vanished from the Documents tab.
//
// The guess is at its weakest on exactly the setup that exposed it: with a
// shared register every document carries another terminal's prefix, and a
// document pulled before this device knew the session had no way back.
//
// The fix is to stop guessing — the document now carries `sessionId` too.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/sync/sync_manager.dart';

const _companyId = 25;
const _sessionServerId = 22;
const _sessionLocalId = 'sess-opened-on-device-a';

class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.salesHistory);
  final List<Map<String, dynamic>> salesHistory;

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<List<int>>? _, Future<void>? __) async {
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

/// One sales-history row as the server now returns it — `sessionId` included.
Map<String, dynamic> _serverDoc(
  int id,
  String number, {
  int? sessionId = _sessionServerId,
  double total = 44.10,
  String at = '2026-08-29T17:33:05.698Z',
  List<Map<String, dynamic>> payments = const [],
}) =>
    {
      'id': id,
      'number': number,
      'total': total,
      'discount': 0.0,
      'paidStatus': 1,
      'documentTypeId': 2,
      'warehouseId': 17,
      'userId': 9,
      'date': at,
      'stockDate': at,
      if (sessionId != null) 'sessionId': sessionId,
      'items': const <Map<String, dynamic>>[],
      'payments': payments,
    };

void main() {
  // `pullDocuments` finishes by advancing the document counters, which reads
  // platform channels. Without the binding it logs a caught failure on every
  // test and buries the actual output.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  SyncManager managerFor(List<Map<String, dynamic>> docs) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api'))
      ..httpClientAdapter = _CannedAdapter(docs);
    return SyncManager(db: db, dio: dio, authStorage: AuthStorage());
  }

  /// The session, already pulled — `pullSessions` runs before `pullDocuments`,
  /// which is what makes the server-id → local-id translation possible.
  Future<void> insertSession() => db.into(db.shiftsTable).insert(
        ShiftsTableCompanion.insert(
          localId: _sessionLocalId,
          companyId: _companyId,
          userId: 4,
          openedAt: DateTime.utc(2026, 8, 29, 11, 39),
          lastModified: DateTime.utc(2026, 8, 29, 11, 39),
          serverId: const Value(_sessionServerId),
          posDeviceUid: const Value('reg-front-till'),
          posDeviceName: const Value('POS1'),
          status: const Value(PosSessionStatus.opened),
          syncStatus: const Value('synced'),
        ),
      );

  Future<List<DocumentsTableData>> documentsInSession() =>
      (db.select(db.documentsTable)
            ..where((t) => t.sessionLocalId.equals(_sessionLocalId)))
          .get();

  test('a pulled document lands attached to its session', () async {
    await insertSession();
    await managerFor([
      _serverDoc(175, 'POS1-200-000012'),
      _serverDoc(176, 'POS1-200-000013', total: 47.04),
    ]).pullDocuments(_companyId);

    final inSession = await documentsInSession();
    expect(inSession.map((d) => d.number),
        containsAll(['POS1-200-000012', 'POS1-200-000013']));
  });

  test('the sale that fell outside the old guess is attached too', () async {
    // 🚨 The reported row. POS1-200-000011 was banked at 11:48 UTC — nine
    // minutes after the session opened, so a time-window guess should in theory
    // have caught it, and did not. The point of the fix is that the answer no
    // longer depends on a window at all: the server said 22, so it is 22.
    await insertSession();
    await managerFor([
      _serverDoc(174, 'POS1-200-000011',
          total: 92.00, at: '2026-08-29T11:48:20.918Z'),
    ]).pullDocuments(_companyId);

    final inSession = await documentsInSession();
    expect(inSession.map((d) => d.number), ['POS1-200-000011']);
  });

  test('a document already pulled WITHOUT a session gets repaired', () async {
    // The state every existing device is in right now: the row is local, its
    // link is null, and no delta pull will ever mention it again. A full pass
    // has to be able to fix it in place, or the history stays wrong forever.
    await insertSession();
    await db.into(db.documentsTable).insert(
          DocumentsTableCompanion.insert(
            localId: 'srv_174',
            companyId: _companyId,
            userId: 9,
            warehouseId: 17,
            date: DateTime.utc(2026, 8, 29, 11, 48),
            serverId: const Value(174),
            number: const Value('POS1-200-000011'),
            total: const Value(92.00),
            syncStatus: const Value('synced'),
            lastModified: DateTime.utc(2026, 8, 29, 11, 48),
          ),
        );
    expect(await documentsInSession(), isEmpty, reason: 'the broken state');

    await managerFor([
      _serverDoc(174, 'POS1-200-000011',
          total: 92.00, at: '2026-08-29T11:48:20.918Z'),
    ]).pullDocuments(_companyId);

    expect((await documentsInSession()).map((d) => d.number),
        ['POS1-200-000011']);
  });

  test('a document the server attributes to no session stays unattached',
      () async {
    // Not every sale belongs to a session — one banked with the guard off, or
    // before sessions existed. Inventing a link would put money in a drawer
    // that never held it.
    await insertSession();
    await managerFor([
      _serverDoc(200, 'POS1-200-000020', sessionId: null),
    ]).pullDocuments(_companyId);

    expect(await documentsInSession(), isEmpty);
    final all = await db.select(db.documentsTable).get();
    expect(all.single.sessionLocalId, isNull);
  });

  test('a session this device has never pulled leaves the document unattached',
      () async {
    // No session row, so nothing to translate the server id onto. The document
    // is still stored — it is only its drawer that is unknown here.
    await managerFor([
      _serverDoc(300, 'POS2-200-000001', sessionId: 99),
    ]).pullDocuments(_companyId);

    final all = await db.select(db.documentsTable).get();
    expect(all.single.number, 'POS2-200-000001');
    expect(all.single.sessionLocalId, isNull);
  });
}
