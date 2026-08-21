// Phase 4 — the LOCAL half of the POS session.
//
// What matters here is the property the whole offline design rests on: a
// session opened with no connectivity has a stable identity of its own, and
// everything rung up against it keeps pointing at that identity until the push
// resolves it. If the local session id could change — or if a second session
// could open on the same register — a day's takings would split across two
// periods and neither would reconcile.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/session/session_reconciliation.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime.utc(2026, 8, 17, 8);
  const deviceA = 'device-aaa';
  const deviceB = 'device-bbb';

  Future<String> openSession({
    String localId = 'sess-1',
    String deviceUid = deviceA,
    double openingCash = 2000,
    int status = PosSessionStatus.openingControl,
  }) async {
    await db.into(db.shiftsTable).insert(
          ShiftsTableCompanion.insert(
            localId: localId,
            companyId: 25,
            userId: 9,
            openedAt: now,
            lastModified: now,
            startingCash: Value(openingCash),
            posDeviceUid: Value(deviceUid),
            status: Value(status),
            syncStatus: const Value('pending_create'),
          ),
        );
    return localId;
  }

  Future<ShiftsTableData> read(String localId) =>
      (db.select(db.shiftsTable)..where((t) => t.localId.equals(localId)))
          .getSingle();

  group('status numbering keeps sessions and attendance shifts apart', () {
    test('a session status can never be mistaken for an attendance one', () {
      // 🚨 The reason sessions start at 10. `activeShiftProvider` selects
      // `status = 0` and legacy code reads `1` as "closed"; if a session could
      // hold either value, a trading register would surface as a clocked-in
      // employee and a closed shift would look like a live session.
      expect(PosSessionStatus.live, isNot(contains(0)));
      expect(PosSessionStatus.live, isNot(contains(1)));
      expect(PosSessionStatus.closed, isNot(1));
      expect(PosSessionStatus.openingControl, greaterThanOrEqualTo(10));
    });

    test('CLOSING_CONTROL still counts as live but cannot sell', () {
      // A half-closed register is still that register's session — otherwise a
      // second one could open beside it and split the day.
      expect(PosSessionStatus.isLive(PosSessionStatus.closingControl), isTrue);
      expect(PosSessionStatus.canSell(PosSessionStatus.closingControl), isFalse);
      expect(PosSessionStatus.canSell(PosSessionStatus.opened), isTrue);
      expect(PosSessionStatus.canSell(PosSessionStatus.openingControl), isFalse,
          reason: 'the opening float has not been confirmed yet');
    });
  });

  group('local session identity', () {
    test('a session is scoped to its DEVICE, not its user', () async {
      // Several cashiers ring into one register's session — that is the whole
      // difference between a session and an attendance shift.
      await openSession(localId: 'a', deviceUid: deviceA);
      await openSession(localId: 'b', deviceUid: deviceB);

      final onA = await (db.select(db.shiftsTable)
            ..where((t) => t.posDeviceUid.equals(deviceA)))
          .get();
      expect(onA.map((s) => s.localId), ['a']);
    });

    test('two registers may each hold a live session at the same time',
        () async {
      await openSession(localId: 'a', deviceUid: deviceA);
      await openSession(localId: 'b', deviceUid: deviceB);

      final live = await (db.select(db.shiftsTable)
            ..where((t) => t.status.isIn(PosSessionStatus.live)))
          .get();
      expect(live.length, 2, reason: 'different registers, different sessions');
    });

    test('an attendance shift is never picked up as a session', () async {
      // The pre-existing clock-in path: no device, legacy status 0.
      await db.into(db.shiftsTable).insert(
            ShiftsTableCompanion.insert(
              localId: 'clock-in',
              companyId: 25,
              userId: 9,
              openedAt: now,
              lastModified: now,
              status: const Value(0),
            ),
          );

      final sessions = await (db.select(db.shiftsTable)
            ..where((t) => t.posDeviceUid.isNotNull()))
          .get();
      expect(sessions, isEmpty);

      // And it still reads as an open attendance shift, exactly as before.
      final shifts = await (db.select(db.shiftsTable)
            ..where((t) => t.status.equals(0)))
          .get();
      expect(shifts.single.localId, 'clock-in');
    });
  });

  group('offline attachment — the property the whole design rests on', () {
    test('orders, payments and cash movements hold the session LOCAL id',
        () async {
      // Not the server id: a session opened offline has never seen one, so the
      // client UUID is the only handle that exists at write time.
      final sessionLocalId = await openSession(status: PosSessionStatus.opened);

      await db.into(db.posOrdersTable).insert(
            PosOrdersTableCompanion.insert(
              localId: 'order-1',
              companyId: 25,
              userId: 9,
              serviceType: 0,
              openedAt: now,
              warehouseId: 17,
              lastModified: now,
              status: const Value(1),
              sessionLocalId: Value(sessionLocalId),
            ),
          );

      final order = await (db.select(db.posOrdersTable)
            ..where((t) => t.localId.equals('order-1')))
          .getSingle();
      expect(order.sessionLocalId, sessionLocalId);
      expect(order.serverId, isNull,
          reason: 'offline: neither the order nor its session is on the server');
    });

    test('the session id survives the session being stamped with a server id',
        () async {
      // The push assigns a server id to the SESSION; the children keep pointing
      // at the localId. Nothing has to be rewritten, which is exactly why the
      // localId is what gets stored.
      final sessionLocalId = await openSession(status: PosSessionStatus.opened);
      await db.into(db.posOrdersTable).insert(
            PosOrdersTableCompanion.insert(
              localId: 'order-1',
              companyId: 25,
              userId: 9,
              serviceType: 0,
              openedAt: now,
              warehouseId: 17,
              lastModified: now,
              sessionLocalId: Value(sessionLocalId),
            ),
          );

      await (db.update(db.shiftsTable)
            ..where((t) => t.localId.equals(sessionLocalId)))
          .write(const ShiftsTableCompanion(
        serverId: Value(501),
        syncStatus: Value('synced'),
      ));

      final order = await (db.select(db.posOrdersTable)
            ..where((t) => t.localId.equals('order-1')))
          .getSingle();
      expect(order.sessionLocalId, sessionLocalId,
          reason: 'the child link is stable across the parent gaining an id');
      expect((await read(sessionLocalId)).serverId, 501);
    });

    test('pre-session rows keep a null session and stay valid', () async {
      // The upgrade path: everything that existed before v58 is untouched.
      await db.into(db.posOrdersTable).insert(
            PosOrdersTableCompanion.insert(
              localId: 'legacy-order',
              companyId: 25,
              userId: 9,
              serviceType: 0,
              openedAt: now,
              warehouseId: 17,
              lastModified: now,
            ),
          );
      final order = await (db.select(db.posOrdersTable)
            ..where((t) => t.localId.equals('legacy-order')))
          .getSingle();
      expect(order.sessionLocalId, isNull);
    });
  });

  group('reconciliation arithmetic', () {
    SessionReconciliation build({double? counted}) => SessionReconciliation(
          openingCash: 2000,
          cashPayments: 8500,
          cashIn: 500,
          cashOut: 200,
          documentCount: 5,
          countedCash: counted,
          methods: const [
            SessionMethodTotal(
              paymentTypeId: 1,
              paymentTypeName: 'Espèces',
              isCash: true,
              expected: 8500,
            ),
            SessionMethodTotal(
              paymentTypeId: 2,
              paymentTypeName: 'Credit',
              isCash: false,
              expected: 4200,
            ),
          ],
        );

    test('the worked example', () {
      // 2,000 + 8,500 + 500 − 200 = 10,800 expected; counted 10,750 ⇒ −50.
      final r = build(counted: 10750);
      expect(r.expectedCash, 10800);
      expect(r.cashDifference, -50);
      expect(r.needsManagerAuthorisation, isTrue,
          reason: '50 is beyond the 10 DH tolerance');
    });

    test('cash out is subtracted, not added', () {
      // Getting this sign wrong overstates the drawer by twice the withdrawal.
      final r = build();
      expect(r.expectedCash, 2000 + 8500 + 500 - 200);
    });

    test('a NON-cash method never moves the expected cash', () {
      // The Credit row is 4,200 and must not appear in the drawer figure. This
      // is the mistake `OpenCashDrawer` would have caused server-side.
      final r = build();
      expect(r.totalTaken, 12700);
      expect(r.expectedCash, 10800);
    });

    test('within tolerance closes without a manager', () {
      expect(build(counted: 10795).needsManagerAuthorisation, isFalse);
      expect(build(counted: 10810).needsManagerAuthorisation, isFalse,
          reason: 'exactly 10 is allowed; the rule is "greater than"');
      expect(build(counted: 10811).needsManagerAuthorisation, isTrue);
    });

    test('an uncounted drawer reports no difference rather than zero', () {
      // "Not counted yet" and "counted, and it balanced" are different facts.
      final r = build();
      expect(r.countedCash, isNull);
      expect(r.cashDifference, isNull);
      expect(r.needsManagerAuthorisation, isFalse);
    });

    test('per-method differences are independent of the cash count', () {
      final m = const SessionMethodTotal(
        paymentTypeId: 2,
        paymentTypeName: 'Bank',
        isCash: false,
        expected: 4137.70,
      ).withCounted(4137.70);
      expect(m.difference, 0);
      expect(m.withCounted(null).difference, isNull);
    });
  });

  group('close blockers', () {
    test('an empty list is what permits a normal close', () {
      expect(canCloseNormally(const []), isTrue);
      expect(
        canCloseNormally(const [
          SessionCloseBlocker(SessionCloseBlockerKind.openOrders, 2),
        ]),
        isFalse,
      );
    });

    test('unsynced sales block too — the server cannot see them', () {
      // §14: closing without these produces a Z-report missing sales that
      // exist. This is the check that prevents it rather than repairing it.
      expect(
        canCloseNormally(const [
          SessionCloseBlocker(SessionCloseBlockerKind.unsyncedSales, 7),
        ]),
        isFalse,
      );
    });
  });

  test('sessionAcceptsSales is true only in OPENED', () {
    expect(sessionAcceptsSales(PosSessionStatus.opened), isTrue);
    for (final s in [
      PosSessionStatus.openingControl,
      PosSessionStatus.closingControl,
      PosSessionStatus.closed,
      null,
    ]) {
      expect(sessionAcceptsSales(s), isFalse, reason: 'status $s');
    }
  });
}
