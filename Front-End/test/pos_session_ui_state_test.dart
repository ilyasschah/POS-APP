// Phase 6 — the state the session screen renders from.
//
// The screen's job is to make the round trip OBSERVABLE before selling is gated
// on it, so what matters is that its inputs are correct: which register's
// session is shown, what stops a close, and that two devices never read each
// other's state.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/session/session_reconciliation.dart';
import 'package:pos_app/session/session_summary_provider.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime.utc(2026, 8, 17, 8);

  Future<void> openSession(String localId, String uid,
      {int status = PosSessionStatus.opened, double opening = 2000}) {
    return db.into(db.shiftsTable).insert(
          ShiftsTableCompanion.insert(
            localId: localId,
            companyId: 25,
            userId: 9,
            openedAt: now,
            lastModified: now,
            startingCash: Value(opening),
            posDeviceUid: Value(uid),
            status: Value(status),
            syncStatus: const Value('pending_create'),
          ),
        );
  }

  Future<void> order(String id, String session,
      {int status = 1, String sync = 'synced'}) {
    return db.into(db.posOrdersTable).insert(
          PosOrdersTableCompanion.insert(
            localId: id,
            companyId: 25,
            userId: 9,
            serviceType: 0,
            openedAt: now,
            warehouseId: 17,
            lastModified: now,
            status: Value(status),
            sessionLocalId: Value(session),
            syncStatus: Value(sync),
          ),
        );
  }

  group('the screen only ever shows THIS register', () {
    test('each device reads its own live session', () async {
      await openSession('S-A', 'device-a');
      await openSession('S-B', 'device-b');

      Future<ShiftsTableData?> liveFor(String uid) =>
          (db.select(db.shiftsTable)
                ..where((t) => t.posDeviceUid.equals(uid))
                ..where((t) => t.status.isIn(PosSessionStatus.live)))
              .getSingleOrNull();

      expect((await liveFor('device-a'))!.localId, 'S-A');
      expect((await liveFor('device-b'))!.localId, 'S-B');
    });

    test('a device with no session sees none, even while another trades',
        () async {
      await openSession('S-A', 'device-a');
      final none = await (db.select(db.shiftsTable)
            ..where((t) => t.posDeviceUid.equals('device-c'))
            ..where((t) => t.status.isIn(PosSessionStatus.live)))
          .getSingleOrNull();
      expect(none, isNull);
    });

    test('a closed session stops being the active one', () async {
      await openSession('S-A', 'device-a', status: PosSessionStatus.closed);
      final live = await (db.select(db.shiftsTable)
            ..where((t) => t.posDeviceUid.equals('device-a'))
            ..where((t) => t.status.isIn(PosSessionStatus.live)))
          .getSingleOrNull();
      expect(live, isNull, reason: 'the screen should offer Open Register again');
    });
  });

  group('close blockers — what the device alone knows', () {
    test('parked orders block', () async {
      await openSession('S-A', 'device-a');
      await order('parked', 'S-A', status: 0);

      final open = await (db.select(db.posOrdersTable)
            ..where((t) => t.sessionLocalId.equals('S-A'))
            ..where((t) => t.status.equals(0)))
          .get();
      expect(open.length, 1);
      expect(
        canCloseNormally(
            [SessionCloseBlocker(SessionCloseBlockerKind.openOrders, open.length)]),
        isFalse,
      );
    });

    test('unsynced completed sales block', () async {
      // 🚨 The server cannot see these. Closing anyway produces a Z-report that
      // omits sales which really happened.
      await openSession('S-A', 'device-a');
      await order('sold', 'S-A', sync: 'pending');

      final unsynced = await (db.select(db.posOrdersTable)
            ..where((t) => t.sessionLocalId.equals('S-A'))
            ..where((t) => t.status.equals(1))
            ..where((t) => t.syncStatus.equals('pending')))
          .get();
      expect(unsynced.length, 1);
    });

    test('a fully synced session with nothing parked can close', () async {
      await openSession('S-A', 'device-a');
      await order('sold', 'S-A');
      expect(canCloseNormally(const []), isTrue);
    });

    test("another register's parked order does not block this one", () async {
      await openSession('S-A', 'device-a');
      await openSession('S-B', 'device-b');
      await order('parked-on-b', 'S-B', status: 0);

      final blockingA = await (db.select(db.posOrdersTable)
            ..where((t) => t.sessionLocalId.equals('S-A'))
            ..where((t) => t.status.equals(0)))
          .get();
      expect(blockingA, isEmpty);
    });
  });

  group('cash method resolution matches the server', () {
    test('the configured setting is authoritative', () {
      // Credit must never be counted as drawer cash because a flag says so.
      final ids = resolveCashPaymentTypeIds(
        {kCashPaymentTypeIdsSetting: '1'},
        const [_Pt(1, 'Espèces', true), _Pt(2, 'Credit', true)],
      );
      expect(ids, {1});
    });

    test('an unconfigured company falls back to isChangeAllowed', () {
      final ids = resolveCashPaymentTypeIds(
        const {},
        const [_Pt(1, 'Espèces', true), _Pt(2, 'Credit', false)],
      );
      expect(ids, {1});
    });

    test('a garbage setting falls back rather than counting nothing as cash',
        () {
      final ids = resolveCashPaymentTypeIds(
        {kCashPaymentTypeIdsSetting: 'abc'},
        const [_Pt(1, 'Espèces', true)],
      );
      expect(ids, {1}, reason: 'zero cash methods would understate the drawer');
    });
  });
}

class _Pt {
  const _Pt(this.id, this.name, this.isChangeAllowed);
  final int id;
  final String name;
  final bool isChangeAllowed;
}
