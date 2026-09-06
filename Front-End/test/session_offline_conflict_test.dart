// Backlog 42 — two devices on ONE shared register, both offline, both open a
// session.
//
// 🚨 The server takes the first push and rejects the second with "This register
// already has an open session". Before this, `_resolveRejection` turned that
// into `sync_failed`, which is TERMINAL — and the second cashier's whole day
// went with it. Nothing was ever wrong with those sales: they point at a
// session the server will never own.
//
// The fix is a merge, not a failure. `_adoptOnRegisterConflict` asks the server
// which session actually holds the register and `adoptSessionInto` re-points
// every trading row onto it.
//
// The load-bearing detail, and the reason this file exists rather than a single
// happy-path test: the OPENING FLOAT must not travel. Expected cash is
//   openingCash + cashPayments + cashIn − cashOut
// where `openingCash` is the SURVIVING session's own `starting_cash`. Carrying
// a second `opening` row across would show two floats on one drawer for money
// that was counted into it once.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/cash/cash_movement_kind.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/sync/sync_manager.dart';

import 'quiet_sync_logs.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _companyId = 25;
const _registerUid = 'reg-front-till';

/// Device A got there first: its session is the one the server has.
const _survivorLocalId = 'sess-device-a';
const _survivorServerId = 41;

/// Device B opened its own while offline. This is the row that used to die.
const _doomedLocalId = 'sess-device-b';

/// The server as it behaves in this exact collision: `/PosSession/Sync` refuses,
/// `/Current` and `/History` both name device A's session.
class _ConflictingServer implements HttpClientAdapter {
  _ConflictingServer({this.currentReturnsNull = false});

  /// Simulates the recovery itself losing the network — the till dropped off
  /// again between the rejection and the follow-up call.
  final bool currentReturnsNull;

  int syncAttempts = 0;

  static final _survivor = {
    'id': _survivorServerId,
    'localId': _survivorLocalId,
    'posDeviceUid': _registerUid,
    'posDeviceName': 'POS1',
    'openedByUserId': 4,
    'openedAt': '2026-09-03T07:02:00.000Z',
    'lastModified': '2026-09-03T07:02:00.000Z',
    'openingCash': 200.0,
    'status': PosSessionStatus.opened,
  };

  ResponseBody _json(Object? body, [int code = 200]) => ResponseBody.fromString(
        jsonEncode(body),
        code,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<List<int>>? _, Future<void>? __) async {
    final path = options.path;

    if (path.contains('/PosSession/Sync')) {
      syncAttempts++;
      // The exact refusal from `PosSessionService.OpenAsync`.
      return _json({
        'message': 'This register already has an open session '
            '(#$_survivorServerId, OPENED). Continue selling in it, or close '
            'it first.',
      }, 400);
    }
    if (path.contains('/PosSession/Current')) {
      return _json(currentReturnsNull ? null : _survivor);
    }
    if (path.contains('/PosSession/History')) {
      return _json([_survivor]);
    }
    return _json(null, 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _ConflictingServer server;

  setUp(() {
    // Every unstubbed request is answered 404 on purpose — see quiet_sync_logs.
    silenceDebugPrint();
    // `pushPendingSessions` reads the REGISTER's name before it posts, and that
    // is a shared_preferences call — without this the push throws
    // MissingPluginException and never reaches the server at all, so every
    // assertion here would be testing nothing.
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  SyncManager managerFor({bool currentReturnsNull = false}) {
    server = _ConflictingServer(currentReturnsNull: currentReturnsNull);
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api'))
      ..httpClientAdapter = server;
    return SyncManager(db: db, dio: dio, authStorage: AuthStorage());
  }

  /// Device B's parallel session, still queued to push.
  Future<void> insertDoomedSession({
    int status = PosSessionStatus.opened,
  }) =>
      db.into(db.shiftsTable).insert(
            ShiftsTableCompanion.insert(
              localId: _doomedLocalId,
              companyId: _companyId,
              userId: 9,
              openedAt: DateTime.utc(2026, 9, 3, 7, 14),
              lastModified: DateTime.utc(2026, 9, 3, 7, 14),
              startingCash: const Value(150),
              posDeviceUid: const Value(_registerUid),
              posDeviceName: const Value('POS1'),
              status: Value(status),
              syncStatus: const Value('pending_create'),
            ),
          );

  /// A day's trading rung into the doomed session: a sale, its payment, the
  /// order carrier, the opening float and one cash-out.
  Future<void> insertTradingRows() async {
    await db.into(db.documentsTable).insert(
          DocumentsTableCompanion.insert(
            localId: 'doc-1',
            companyId: _companyId,
            userId: 9,
            warehouseId: 17,
            date: DateTime.utc(2026, 9, 3, 8),
            lastModified: DateTime.utc(2026, 9, 3, 8),
            sessionLocalId: const Value(_doomedLocalId),
          ),
        );
    await db.into(db.paymentsTable).insert(
          PaymentsTableCompanion.insert(
            localId: 'pay-1',
            documentId: 'doc-1',
            paymentTypeId: 1,
            amount: 44.10,
            userId: 9,
            date: DateTime.utc(2026, 9, 3, 8),
            sessionLocalId: const Value(_doomedLocalId),
          ),
        );
    await db.into(db.posOrdersTable).insert(
          PosOrdersTableCompanion.insert(
            localId: 'doc-1',
            companyId: _companyId,
            userId: 9,
            serviceType: 1,
            openedAt: DateTime.utc(2026, 9, 3, 8),
            warehouseId: 17,
            lastModified: DateTime.utc(2026, 9, 3, 8),
            sessionLocalId: const Value(_doomedLocalId),
          ),
        );
    await db.into(db.startingCashTable).insert(
          StartingCashTableCompanion.insert(
            localId: 'cash-opening',
            companyId: _companyId,
            userId: 9,
            amount: 150,
            type: CashMovementKind.opening,
            createdAt: DateTime.utc(2026, 9, 3, 7, 14),
            sessionLocalId: const Value(_doomedLocalId),
          ),
        );
    await db.into(db.startingCashTable).insert(
          StartingCashTableCompanion.insert(
            localId: 'cash-out-1',
            companyId: _companyId,
            userId: 9,
            amount: 20,
            type: CashMovementKind.cashOut,
            createdAt: DateTime.utc(2026, 9, 3, 9),
            sessionLocalId: const Value(_doomedLocalId),
          ),
        );
  }

  Future<List<String>> sessionIdsOf(String table) async {
    switch (table) {
      case 'documents':
        return (await db.select(db.documentsTable).get())
            .map((r) => r.sessionLocalId ?? '')
            .toList();
      case 'payments':
        return (await db.select(db.paymentsTable).get())
            .map((r) => r.sessionLocalId ?? '')
            .toList();
      case 'orders':
        return (await db.select(db.posOrdersTable).get())
            .map((r) => r.sessionLocalId ?? '')
            .toList();
      default:
        throw ArgumentError(table);
    }
  }

  Future<ShiftsTableData?> shift(String localId) =>
      (db.select(db.shiftsTable)..where((t) => t.localId.equals(localId)))
          .getSingleOrNull();

  group('the rejected parallel session is merged, not lost', () {
    test('trading rows move onto the session the server kept', () async {
      await insertDoomedSession();
      await insertTradingRows();

      await managerFor().pushPendingSessions(_companyId);

      expect(await sessionIdsOf('documents'), [_survivorLocalId]);
      expect(await sessionIdsOf('payments'), [_survivorLocalId]);
      expect(await sessionIdsOf('orders'), [_survivorLocalId]);
    });

    test('the duplicate session row is gone, and the survivor is here',
        () async {
      await insertDoomedSession();
      await insertTradingRows();

      await managerFor().pushPendingSessions(_companyId);

      expect(await shift(_doomedLocalId), isNull,
          reason: 'a phantom register that closed uncounted would be left in '
              'the session history');
      final survivor = await shift(_survivorLocalId);
      expect(survivor, isNotNull);
      expect(survivor!.serverId, _survivorServerId);
    });

    test('it never parks at sync_failed', () async {
      await insertDoomedSession();
      await insertTradingRows();

      await managerFor().pushPendingSessions(_companyId);

      final rows = await db.select(db.shiftsTable).get();
      expect(rows.map((r) => r.syncStatus), isNot(contains('sync_failed')));
    });
  });

  group('the opening float does not travel', () {
    test('the doomed float is deleted and the cash-out is kept', () async {
      await insertDoomedSession();
      await insertTradingRows();

      await managerFor().pushPendingSessions(_companyId);

      final cash = await db.select(db.startingCashTable).get();
      expect(cash.map((c) => c.localId), ['cash-out-1'],
          reason: 'the surviving session already carries its own counted '
              'float in shifts.starting_cash — a second opening row would '
              'show two floats on one drawer');
      expect(cash.single.sessionLocalId, _survivorLocalId);
    });

    test('no opening row survives on either session', () async {
      await insertDoomedSession();
      await insertTradingRows();

      await managerFor().pushPendingSessions(_companyId);

      final openings = await (db.select(db.startingCashTable)
            ..where((t) => t.type.equals(CashMovementKind.opening)))
          .get();
      expect(openings, isEmpty);
    });
  });

  group('the cases that must NOT merge', () {
    test('a CLOSED session parks instead — its Z-report is already signed',
        () async {
      await insertDoomedSession(status: PosSessionStatus.closed);
      await insertTradingRows();

      await managerFor().pushPendingSessions(_companyId);

      final doomed = await shift(_doomedLocalId);
      expect(doomed, isNotNull, reason: 'nothing may be merged away silently '
          'once a Z-report has been produced against it');
      expect(doomed!.syncStatus, 'sync_failed');
      expect(await sessionIdsOf('documents'), [_doomedLocalId]);
    });

    test('a recovery that cannot reach the server changes nothing', () async {
      await insertDoomedSession();
      await insertTradingRows();

      await managerFor(currentReturnsNull: true)
          .pushPendingSessions(_companyId);

      // Falls through to the normal resolver rather than half-merging.
      expect(await sessionIdsOf('documents'), [_doomedLocalId]);
      expect(await shift(_doomedLocalId), isNotNull);
    });
  });

  test('merging is idempotent — a second sync finds nothing left to move',
      () async {
    await insertDoomedSession();
    await insertTradingRows();

    final manager = managerFor();
    await manager.pushPendingSessions(_companyId);
    await manager.pushPendingSessions(_companyId);

    // The doomed row is gone, so the second run has nothing pending to push.
    expect(server.syncAttempts, 1);
    expect(await sessionIdsOf('documents'), [_survivorLocalId]);
  });

  test('adoptSessionInto refuses to merge a session into itself', () async {
    await insertDoomedSession();
    await insertTradingRows();

    final moved = await db.adoptSessionInto(
      doomedLocalId: _doomedLocalId,
      survivingLocalId: _doomedLocalId,
    );

    expect(moved, 0);
    expect(await shift(_doomedLocalId), isNotNull);
  });
}
