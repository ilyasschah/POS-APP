// Pins that a server FAULT never strands a completed, paid sale.
//
// What happened on 2026-08-06: `PosOrderItem` gained two columns and the API was
// restarted before the migration was applied. BatchSync answered
//
//     Invalid column name 'DiscountInputType'.
//     Invalid column name 'DiscountInputValue'.
//
// and a paid sale (POS1-200-000038, 28.00 MAD, payment recorded) was marked
// `failed`. `failed` is TERMINAL — every push query selects `pending` only and
// nothing in the app requeues — so that sale would never have reached the server
// again, no matter how many times anyone pressed Sync.
//
// handoff §3 predicted it: "that assumption holds for business conflicts but NOT
// for client bugs — a bad payload strands real data permanently. Watch for this
// whenever a push payload changes."
//
// The distinction that matters: a BUSINESS rejection cannot be fixed by retrying
// and must stay terminal; an INFRASTRUCTURE fault must not.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insertFailedOrder(String localId, String error) async {
    await db.into(db.posOrdersTable).insert(
          PosOrdersTableCompanion.insert(
            localId: localId,
            companyId: 25,
            userId: 9,
            serviceType: 0,
            openedAt: DateTime.now().toUtc(),
            status: const Value(1), // completed sale
            warehouseId: 17,
            lastModified: DateTime.now().toUtc(),
            total: const Value(28),
            syncStatus: const Value('failed'),
            syncError: Value(error),
          ),
        );
  }

  Future<String> statusOf(String localId) async =>
      (await (db.select(db.posOrdersTable)
                ..where((t) => t.localId.equals(localId)))
              .getSingle())
          .syncStatus;

  test('the exact failure that stranded the live sale is requeued', () async {
    await insertFailedOrder('paid-sale',
        "Error: Invalid column name 'DiscountInputType'.\r\n"
        "Invalid column name 'DiscountInputValue'.");

    expect(await db.requeueInfrastructureFailedOrders(), 1);
    expect(await statusOf('paid-sale'), 'pending',
        reason: 'only `pending` rows are ever pushed');
  });

  test('other infrastructure faults are requeued too', () async {
    await insertFailedOrder('a', 'Invalid object name \'dbo.PosOrderItem\'.');
    await insertFailedOrder('b', 'The wait operation timed out');
    await insertFailedOrder('c', 'Transaction was deadlocked on lock resources');
    await insertFailedOrder('d',
        'The server is temporarily unable to reach the database. Please try again.');
    await insertFailedOrder('e', 'A transport-level error has occurred');

    expect(await db.requeueInfrastructureFailedOrders(), 5);
    for (final id in ['a', 'b', 'c', 'd', 'e']) {
      expect(await statusOf(id), 'pending');
    }
  });

  group('a BUSINESS rejection stays terminal', () {
    // Load-bearing in the other direction: requeueing these would re-push a
    // genuinely rejected order on every sync, forever.
    const rejections = [
      'Product Coffee is out of stock in this warehouse (needed 2 more).',
      'A Document with this number already exists.',
      'Order not found.',
      'Server returned success without a serverId.',
    ];

    test('none of them are requeued', () async {
      for (var i = 0; i < rejections.length; i++) {
        await insertFailedOrder('rej-$i', rejections[i]);
      }

      expect(await db.requeueInfrastructureFailedOrders(), 0);
      for (var i = 0; i < rejections.length; i++) {
        expect(await statusOf('rej-$i'), 'failed');
      }
    });
  });

  test('requeueing is idempotent — a second pass finds nothing', () async {
    await insertFailedOrder('paid-sale', "Invalid column name 'X'.");

    expect(await db.requeueInfrastructureFailedOrders(), 1);
    expect(await db.requeueInfrastructureFailedOrders(), 0,
        reason: 'the row is pending now, not failed');
  });
}
