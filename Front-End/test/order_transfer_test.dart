// Pins that transferring an order between tables MOVES it instead of copying it.
//
// Reported 2026-08-06: "it doesn't clear the old table, it just copies to the
// new table and I end up with two orders". The Transfer dialog updated the
// server (`/PosOrder/Update`) and the in-memory cart, and wrote NOTHING to
// Drift — but floor-plan occupancy is derived from open `pos_orders.tableId`
// (handoff §3: `floor_plan_tables.status` is a dead column), so the origin table
// kept showing occupied from a local row that still pointed at it.
//
// On a `pending` row it was worse than cosmetic: the open-order pull refuses to
// overwrite an unpushed row's tableId, so the stale value survived every poll
// AND was pushed back — dragging the server order to the table it had just been
// moved off. The live database showed the residue: PosOrder 123 named
// "ORD- A7" sitting on table 30 ("A5").
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insertOpenOrder({
    required String localId,
    int? serverId,
    required int tableId,
    String orderName = 'ORD- A7',
    String syncStatus = 'synced',
  }) =>
      db.into(db.posOrdersTable).insert(
            PosOrdersTableCompanion.insert(
              localId: localId,
              companyId: 25,
              userId: 9,
              serviceType: 0,
              openedAt: DateTime.now().toUtc(),
              status: const Value(0),
              warehouseId: 17,
              lastModified: DateTime.now().toUtc(),
              serverId: Value(serverId),
              tableId: Value(tableId),
              orderName: Value(orderName),
              total: const Value(36),
              syncStatus: Value(syncStatus),
            ),
          );

  /// What the floor plan actually asks: which open orders sit on this table.
  Future<int> openOrdersOnTable(int tableId) =>
      (db.select(db.posOrdersTable)
            ..where((t) => t.tableId.equals(tableId))
            ..where((t) => t.status.equals(0)))
          .get()
          .then((r) => r.length);

  test('the origin table is freed and the order is not duplicated', () async {
    await insertOpenOrder(localId: 'o1', serverId: 123, tableId: 32); // A7

    await db.moveOrderToTable(
        localId: 'o1', tableId: 30, orderName: 'ORD- A5'); // → A5

    // Both assertions fail against the pre-fix code: the local row was never
    // written, so A7 stayed occupied and the order showed on two tables.
    expect(await openOrdersOnTable(32), 0, reason: 'origin must be freed');
    expect(await openOrdersOnTable(30), 1, reason: 'destination holds it');
    expect(await db.select(db.posOrdersTable).get(), hasLength(1),
        reason: 'a transfer moves one row — it never creates a second');
  });

  test('the order is renamed after its destination table', () async {
    await insertOpenOrder(localId: 'o1', serverId: 123, tableId: 32);

    await db.moveOrderToTable(
        localId: 'o1', tableId: 30, orderName: 'ORD- A5');

    final row = await (db.select(db.posOrdersTable)
          ..where((t) => t.localId.equals('o1')))
        .getSingle();
    // The live residue of the bug: named for one table, sitting on another.
    expect(row.orderName, 'ORD- A5');
    expect(row.tableId, 30);
  });

  test('a row with unpushed work keeps its pending status', () async {
    // It still has edits to push; the move must not silently mark it synced or
    // the cashier's unsaved work would never reach the server.
    await insertOpenOrder(
        localId: 'o1', serverId: 123, tableId: 32, syncStatus: 'pending');

    await db.moveOrderToTable(localId: 'o1', tableId: 30);

    final row = await (db.select(db.posOrdersTable)
          ..where((t) => t.localId.equals('o1')))
        .getSingle();
    expect(row.syncStatus, 'pending');
    expect(row.tableId, 30,
        reason: 'the pushed tableId must be the destination, not the origin');
  });

  test('an order transferred to no table (tableless) leaves its table', () async {
    await insertOpenOrder(localId: 'o1', serverId: 123, tableId: 32);

    await db.moveOrderToTable(localId: 'o1', tableId: null);

    expect(await openOrdersOnTable(32), 0);
  });

  test('getOpenOrderByServerId survives a duplicate instead of throwing',
      () async {
    // The transfer resolves the local row through this when the cart has no
    // existingLocalOrderId. getSingleOrNull() would throw here and surface as
    // an opaque "transfer failed".
    await insertOpenOrder(localId: 'o1', serverId: 123, tableId: 32);
    await insertOpenOrder(localId: 'svr_123', serverId: 123, tableId: 32);

    expect(await db.getOpenOrderByServerId(123), isNotNull);
  });
}
