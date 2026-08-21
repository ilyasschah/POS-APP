// Phase 5 — the offline round trip and its idempotency.
//
// The whole point of this file is one failure window: the device pushes a
// session, the server creates it, the RESPONSE IS LOST, and the device retries.
// If that produces a second session, a day's takings split across two periods
// and neither reconciles against the drawer.
//
// The client half of the protection is that the session's `localId` never
// changes and is what every child row points at. The server half is
// `PosSessionService.OpenAsync` returning the existing row for a known localId
// (pinned in `PosSessionIdempotencyTests`).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/session/pos_session_status.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime.utc(2026, 8, 17, 8);
  const deviceA = 'device-aaa';
  const deviceB = 'device-bbb';

  Future<void> openSession(String localId, String deviceUid,
      {int status = PosSessionStatus.opened, String sync = 'pending_create'}) {
    return db.into(db.shiftsTable).insert(
          ShiftsTableCompanion.insert(
            localId: localId,
            companyId: 25,
            userId: 9,
            openedAt: now,
            lastModified: now,
            startingCash: const Value(2000),
            posDeviceUid: Value(deviceUid),
            status: Value(status),
            syncStatus: Value(sync),
          ),
        );
  }

  Future<void> sell(String orderLocalId, String sessionLocalId,
      {double total = 90}) async {
    await db.insertOfflineOrder(
      PosOrdersTableCompanion.insert(
        localId: orderLocalId,
        companyId: 25,
        userId: 9,
        serviceType: 0,
        openedAt: now,
        warehouseId: 17,
        lastModified: now,
        status: const Value(1),
        total: Value(total),
        number: Value('POS1-200-$orderLocalId'),
        paymentTypeId: const Value(3),
        amountPaid: Value(total),
        sessionLocalId: Value(sessionLocalId),
        syncStatus: const Value('pending'),
      ),
      const [],
    );
    await db.insertOfflineDocument(
      document: DocumentsTableCompanion.insert(
        localId: orderLocalId,
        companyId: 25,
        userId: 9,
        warehouseId: 17,
        date: now,
        lastModified: now,
        total: Value(total),
        sessionLocalId: Value(sessionLocalId),
        syncStatus: const Value('pending'),
      ),
      items: const [],
      payment: PaymentsTableCompanion.insert(
        localId: 'pay-$orderLocalId',
        documentId: orderLocalId,
        paymentTypeId: 3,
        amount: total,
        userId: 9,
        date: now,
        sessionLocalId: Value(sessionLocalId),
      ),
    );
  }

  Future<ShiftsTableData> session(String localId) =>
      (db.select(db.shiftsTable)..where((t) => t.localId.equals(localId)))
          .getSingle();

  group('the push queue', () {
    test('a session is selected as pending_create, not pending', () async {
      // 🚨 The documented double-create trap. `pending` is the checkout-artifact
      // family, created server-side by BatchSync; a session written that way
      // would never be pushed by ANY pusher. `pending_create` is the generic
      // family, which POSTs directly — which is what a session needs.
      await openSession('S-123', deviceA);
      final sessions = await db.getPendingSessions();
      expect(sessions.map((s) => s.localId), ['S-123']);
      expect(sessions.single.syncStatus, 'pending_create');
    });

    test('an attendance shift never appears in the session queue', () async {
      await db.into(db.shiftsTable).insert(
            ShiftsTableCompanion.insert(
              localId: 'clock-in',
              companyId: 25,
              userId: 9,
              openedAt: now,
              lastModified: now,
              status: const Value(0),
              syncStatus: const Value('pending'),
            ),
          );
      expect(await db.getPendingSessions(), isEmpty);

      // …and it is still picked up by its own pusher, unchanged.
      final shifts = await db.getPendingShifts();
      expect(shifts.map((s) => s.localId), ['clock-in']);
    });

    test('a POS session never leaks into the attendance pusher', () async {
      // Belt and braces: even if a session were written as plain `pending`,
      // /Shifts/BatchSync must not take it — it would land as a device-less
      // shift with no session semantics at all.
      await openSession('S-123', deviceA, sync: 'pending');
      expect(await db.getPendingShifts(), isEmpty);
    });
  });

  group('the lost-response retry — the window Phase 5 exists to close', () {
    test('stamping the server id leaves the localId and every child untouched',
        () async {
      await openSession('S-123', deviceA);
      await sell('o1', 'S-123');
      await sell('o2', 'S-123');
      await sell('o3', 'S-123');

      // The push succeeds; the server returns 501.
      await db.markSessionSynced('S-123', 501);

      final s = await session('S-123');
      expect(s.serverId, 501);
      expect(s.localId, 'S-123', reason: 'the identity never changes');
      expect(s.syncStatus, 'synced');

      // 🚨 The property the whole design rests on: NOT ONE child row had to be
      // rewritten from localId to server id.
      final orders = await (db.select(db.posOrdersTable)
            ..where((t) => t.sessionLocalId.equals('S-123')))
          .get();
      expect(orders.length, 3);
      final payments = await (db.select(db.paymentsTable)
            ..where((t) => t.sessionLocalId.equals('S-123')))
          .get();
      expect(payments.length, 3);
    });

    test('a replayed push finds nothing left to send', () async {
      await openSession('S-123', deviceA);
      expect((await db.getPendingSessions()).length, 1);

      await db.markSessionSynced('S-123', 501);

      // The retry: the queue is empty, so the second push never happens. The
      // server-side localId match is the backstop for a retry that DOES happen
      // (response lost before this line ran) — see PosSessionIdempotencyTests.
      expect(await db.getPendingSessions(), isEmpty);
    });

    test('orders keep their session after it gains a server id', () async {
      // Requirement 6 verbatim: sales created under S-123 stay on S-123.
      await openSession('S-123', deviceA);
      await sell('o1', 'S-123');
      await db.markSessionSynced('S-123', 501);
      await sell('o2', 'S-123'); // rung up after the id arrived

      final orders = await (db.select(db.posOrdersTable)
            ..where((t) => t.sessionLocalId.equals('S-123')))
          .get();
      expect(orders.map((o) => o.localId).toSet(), {'o1', 'o2'});
      expect(orders.every((o) => o.sessionLocalId == 'S-123'), isTrue);
    });

    test('a sale carries its session into the BatchSync payload', () async {
      await openSession('S-123', deviceA);
      await sell('o1', 'S-123');

      final pending = await db.getPendingOrders();
      expect(pending.single.order.sessionLocalId, 'S-123',
          reason: 'the server resolves this localId to a session id');
    });
  });

  group('two registers syncing at once stay isolated', () {
    test('each session queues and syncs independently', () async {
      await openSession('S-A', deviceA);
      await openSession('S-B', deviceB);
      await sell('a1', 'S-A');
      await sell('a2', 'S-A');
      await sell('b1', 'S-B');

      expect((await db.getPendingSessions()).length, 2);

      // Device A's push lands; device B's does not (still offline).
      await db.markSessionSynced('S-A', 501);

      expect((await session('S-A')).serverId, 501);
      expect((await session('S-B')).serverId, isNull);
      expect((await db.getPendingSessions()).map((s) => s.localId), ['S-B']);
    });

    test('sales never cross between registers', () async {
      await openSession('S-A', deviceA);
      await openSession('S-B', deviceB);
      await sell('a1', 'S-A', total: 100);
      await sell('a2', 'S-A', total: 250);
      await sell('b1', 'S-B', total: 400);

      Future<double> totalFor(String s) async {
        final rows = await (db.select(db.posOrdersTable)
              ..where((t) => t.sessionLocalId.equals(s)))
            .get();
        return rows.fold<double>(0, (sum, o) => sum + (o.total ?? 0));
      }

      expect(await totalFor('S-A'), 350);
      expect(await totalFor('S-B'), 400);
    });

    test('closing one register leaves the other trading', () async {
      await openSession('S-A', deviceA);
      await openSession('S-B', deviceB);

      await (db.update(db.shiftsTable)
            ..where((t) => t.localId.equals('S-A')))
          .write(const ShiftsTableCompanion(
        status: Value(PosSessionStatus.closed),
      ));

      expect((await session('S-A')).status, PosSessionStatus.closed);
      expect((await session('S-B')).status, PosSessionStatus.opened);

      final live = await (db.select(db.shiftsTable)
            ..where((t) => t.status.isIn(PosSessionStatus.live)))
          .get();
      expect(live.map((s) => s.localId), ['S-B']);
    });
  });

  test('a pre-session sale still pushes, with a null session', () async {
    // The guard is off, so orders with no session must remain perfectly valid —
    // they bank unattached rather than failing.
    await sell('legacy', 'unused');
    await (db.update(db.posOrdersTable)
          ..where((t) => t.localId.equals('legacy')))
        .write(const PosOrdersTableCompanion(sessionLocalId: Value(null)));

    final pending = await db.getPendingOrders();
    expect(pending.single.order.sessionLocalId, isNull);
  });
}
