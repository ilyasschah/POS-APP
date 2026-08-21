// Pins backlog item 33 — an offline PAID sale must never become unsendable.
//
// The shape of the bug, from the live terminal on 2026-08-15:
//
//   A checkout's Document + Payment are created SERVER-SIDE by
//   /PosOrder/BatchSync. That is why pushPendingDocuments / pushPendingPayments
//   deliberately skip `'pending'` rows — pushing them there too would
//   double-create every sale. So the `pos_orders` row is the ONLY thing that can
//   carry an offline sale to the cloud.
//
//   Delete that row before the push lands and no client code path can ever send
//   the sale again, while Sync Status keeps counting it as "1 pending" forever.
//   The operator deleted the rows by hand (the label read like a stale open
//   order) and 90 MAD stopped existing anywhere but locally.
//
// Two halves, both tested here: the app never removes a carrier row while its
// checkout is unbanked, and anything already orphaned is rebuilt from the
// document it left behind so the normal push banks it.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/document/document_type_constants.dart';
import 'package:pos_app/sync/sync_status_provider.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime.utc(2026, 8, 15, 12);

  /// Writes exactly what `PaymentCheckoutDialog` writes for an offline sale:
  /// the order carrier + its items, and the document + items + payment that the
  /// push will have the server create.
  Future<void> seedCheckout({
    required String localId,
    String number = 'POS1-200-000007',
    double total = 90,
    bool withCarrier = true,
    bool withPayment = true,
    bool withDocItems = true,
    int documentTypeId = DocumentTypes.sales,
    String documentStatus = 'pending',
    int? documentServerId,
  }) async {
    const lineId = 'line-1';
    if (withCarrier) {
      await db.insertOfflineOrder(
        PosOrdersTableCompanion.insert(
          localId: localId,
          companyId: 25,
          userId: 9,
          serviceType: 0,
          openedAt: now,
          warehouseId: 17,
          lastModified: now,
          closedAt: Value(now),
          status: const Value(1),
          total: Value(total),
          number: Value(number),
          paymentTypeId: const Value(3),
          amountPaid: Value(total),
          syncStatus: const Value('pending'),
        ),
        [
          PosOrderItemsTableCompanion(
            localId: const Value(lineId),
            orderId: Value(localId),
            productId: const Value(41),
            quantity: const Value(2),
            unitPrice: const Value(45),
            taxRate: const Value(20),
            taxesJson: const Value('[{"id":7,"amount":15}]'),
            comment: const Value('no ice'),
            warehouseId: const Value(17),
            syncStatus: const Value('pending'),
          ),
        ],
      );
    }

    await db.insertOfflineDocument(
      document: DocumentsTableCompanion.insert(
        localId: localId,
        companyId: 25,
        userId: 9,
        warehouseId: 17,
        date: now,
        lastModified: now,
        documentTypeId: Value(documentTypeId),
        serverId: Value(documentServerId),
        number: Value(number),
        total: Value(total),
        orderNumber: const Value('ORD- Table 1'),
        customerId: const Value(12),
        syncStatus: Value(documentStatus),
      ),
      items: withDocItems
          ? [
              DocumentItemsTableCompanion.insert(
                localId: lineId,
                documentId: localId,
                productId: 41,
                quantity: 2,
                unitPrice: 45,
                total: 90,
                taxAmount: const Value(15),
                taxId: const Value(7),
                taxRate: const Value(20),
              ),
            ]
          : const [],
      payment: PaymentsTableCompanion.insert(
        localId: 'pay-$localId',
        documentId: localId,
        paymentTypeId: 3,
        amount: total,
        userId: 9,
        date: now,
      ),
    );

    if (!withPayment) {
      await (db.delete(db.paymentsTable)
            ..where((t) => t.documentId.equals(localId)))
          .go();
    }
  }

  /// The hand-run `DELETE FROM pos_orders …` an operator can do in a DB tool:
  /// with `foreign_keys` OFF the header goes and the line items are left behind.
  Future<void> dropCarrierRowByHand(String localId) async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
        'DELETE FROM pos_orders WHERE local_id = ?', [localId]);
    await db.customStatement('PRAGMA foreign_keys = ON');
  }

  group('detection', () {
    test('a paid sale whose carrier row is gone is found', () async {
      await seedCheckout(localId: 'sale-1');
      await dropCarrierRowByHand('sale-1');

      final stranded = await db.findStrandedCheckouts(25);
      expect(stranded.map((d) => d.localId), ['sale-1']);
      expect(stranded.single.total, 90);
    });

    test('a normal pending sale is NOT stranded — it still has its carrier',
        () async {
      await seedCheckout(localId: 'sale-1');

      expect(await db.findStrandedCheckouts(25), isEmpty);
      // And it is still queued exactly once for the ordinary BatchSync push,
      // which is the double-create this whole design protects against.
      expect((await db.getPendingOrders()).length, 1);
    });

    test('a closed-but-unsynced sale is never treated as an open order',
        () async {
      await seedCheckout(localId: 'sale-1');

      // Everything that shows an order as "still going" — the floor plan's
      // occupancy join, the Open Orders list, the kitchen push, the open-order
      // pusher — selects `status = 0`. This one is status 1, so it can neither
      // occupy a table nor be pushed a second time as an open order.
      expect(await db.getPendingOpenOrders(), isEmpty);
      final open = await (db.select(db.posOrdersTable)
            ..where((t) => t.status.equals(0)))
          .get();
      expect(open, isEmpty);
    });

    test('an already-banked document is not stranded', () async {
      await seedCheckout(
        localId: 'sale-1',
        documentStatus: 'synced',
        documentServerId: 4120,
      );
      await dropCarrierRowByHand('sale-1');

      expect(await db.findStrandedCheckouts(25), isEmpty);
    });

    test('an orphaned REFUND is not touched — it pushes on its own path',
        () async {
      // Refunds reach the server via pushPendingRefundOps (/Document/Refund),
      // never through an order row, so a missing pos_orders row means nothing.
      await seedCheckout(
        localId: 'refund-1',
        number: 'POS1-220-000002',
        documentTypeId: DocumentTypes.refund,
        withCarrier: false,
      );

      expect(await db.findStrandedCheckouts(25), isEmpty);
    });
  });

  group('rebuild and replay', () {
    test('the carrier is rebuilt and the sale is queued for BatchSync',
        () async {
      await seedCheckout(localId: 'sale-1');
      await dropCarrierRowByHand('sale-1');
      expect(await db.getPendingOrders(), isEmpty, reason: 'unsendable');

      expect(await db.rebuildOrderForStrandedCheckout('sale-1'),
          StrandedRepairOutcome.rebuilt);

      final pending = await db.getPendingOrders();
      expect(pending.length, 1);
      final order = pending.single.order;
      expect(order.localId, 'sale-1');
      expect(order.status, 1, reason: 'a closed sale, not an open order');
      expect(order.number, 'POS1-200-000007',
          reason: 'the number already printed on the receipt is kept');
      expect(order.total, 90);
      expect(order.paymentTypeId, 3);
      expect(order.amountPaid, 90);
      expect(order.customerId, 12);
      expect(order.orderName, 'ORD- Table 1');
      expect(order.syncStatus, 'pending');
      expect(order.tableId, isNull,
          reason: 'a closed sale must not re-occupy a table');
    });

    test('line items that outlived the header are kept, not re-derived',
        () async {
      await seedCheckout(localId: 'sale-1');
      await dropCarrierRowByHand('sale-1');

      await db.rebuildOrderForStrandedCheckout('sale-1');

      final items = (await db.getPendingOrders()).single.items;
      expect(items.length, 1);
      // Fidelity the document line simply does not carry.
      expect(items.single.comment, 'no ice');
      expect(items.single.taxesJson, '[{"id":7,"amount":15}]');
      expect(items.single.warehouseId, 17);
    });

    test('with the items gone too, they are rebuilt from the document lines',
        () async {
      await seedCheckout(localId: 'sale-1');
      // A cascading delete (or a tool with foreign_keys ON) takes the lines too.
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.customStatement(
          'DELETE FROM pos_order_items WHERE order_id = ?', ['sale-1']);
      await db.customStatement(
          'DELETE FROM pos_orders WHERE local_id = ?', ['sale-1']);
      await db.customStatement('PRAGMA foreign_keys = ON');

      expect(await db.rebuildOrderForStrandedCheckout('sale-1'),
          StrandedRepairOutcome.rebuilt);

      final items = (await db.getPendingOrders()).single.items;
      expect(items.length, 1);
      expect(items.single.productId, 41);
      expect(items.single.quantity, 2);
      expect(items.single.unitPrice, 45);
      expect(items.single.warehouseId, 17);
      // The line id is the SAME one the document item carries, so BatchSync's
      // itemServerIds echo still stamps the right document_items row.
      expect(items.single.localId, 'line-1');
      expect(jsonDecode(items.single.taxesJson!), [
        {'id': 7, 'amount': 15},
      ]);
    });

    test('repairing twice does nothing the second time', () async {
      await seedCheckout(localId: 'sale-1');
      await dropCarrierRowByHand('sale-1');

      expect(await db.rebuildOrderForStrandedCheckout('sale-1'),
          StrandedRepairOutcome.rebuilt);
      expect(await db.rebuildOrderForStrandedCheckout('sale-1'),
          StrandedRepairOutcome.skipped);
      expect((await db.getPendingOrders()).length, 1);
      expect(await db.findStrandedCheckouts(25), isEmpty);
    });
  });

  group('unrecoverable sales are surfaced, never left counting down', () {
    test('no lines anywhere', () async {
      await seedCheckout(localId: 'sale-1', withDocItems: false);
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.customStatement(
          'DELETE FROM pos_order_items WHERE order_id = ?', ['sale-1']);
      await db.customStatement(
          'DELETE FROM pos_orders WHERE local_id = ?', ['sale-1']);
      await db.customStatement('PRAGMA foreign_keys = ON');

      expect(await db.rebuildOrderForStrandedCheckout('sale-1'),
          StrandedRepairOutcome.unrecoverable);
    });

    test('no payment — how it was paid cannot be invented', () async {
      await seedCheckout(localId: 'sale-1', withPayment: false);
      await dropCarrierRowByHand('sale-1');

      expect(await db.rebuildOrderForStrandedCheckout('sale-1'),
          StrandedRepairOutcome.unrecoverable);
    });

    test('marking one failed moves it out of the pending count', () async {
      await seedCheckout(localId: 'sale-1');
      await dropCarrierRowByHand('sale-1');

      await db.markStrandedCheckoutFailed('sale-1');

      final doc = await (db.select(db.documentsTable)
            ..where((t) => t.localId.equals('sale-1')))
          .getSingle();
      expect(doc.syncStatus, 'failed');
      final payment = await (db.select(db.paymentsTable)
            ..where((t) => t.documentId.equals('sale-1')))
          .getSingle();
      expect(payment.syncStatus, 'failed');
      // And it is no longer offered for repair, so it can't flip-flop.
      expect(await db.findStrandedCheckouts(25), isEmpty);
    });
  });

  group('the app never strands a sale itself', () {
    test('deleteCompletedOrder refuses while the checkout is unbanked',
        () async {
      await seedCheckout(localId: 'sale-1');

      expect(await db.deleteCompletedOrder('sale-1'), isFalse);
      expect((await db.getPendingOrders()).length, 1,
          reason: 'the carrier — and therefore the sale — survives');
    });

    test('deleteCompletedOrder proceeds once the server has the document',
        () async {
      await seedCheckout(localId: 'sale-1');
      // Exactly what pushPendingOrders does immediately before deleting.
      await db.linkDocumentToServer('sale-1', 4120);

      expect(await db.deleteCompletedOrder('sale-1'), isTrue);
      expect(await db.getPendingOrders(), isEmpty);
      expect(await db.findStrandedCheckouts(25), isEmpty);
    });

    test('voiding an order that carries an unbanked sale is refused', () async {
      await seedCheckout(localId: 'sale-1');

      expect(
        () => db.queueVoidAndDeleteOrder(
          localId: 'sale-1',
          serverOrderId: 812,
          companyId: 25,
          userId: 9,
          orderNumber: 'ORD- Table 1',
          warehouseId: 17,
          itemsJson: '[]',
        ),
        throwsA(isA<UnbankedCheckoutException>()),
      );
      expect((await db.getPendingOrders()).length, 1);
      expect(await db.getPendingVoids(), isEmpty,
          reason: 'the void must not be queued either');
    });

    test('deleteLocalOrder refuses the same case, allows a plain open order',
        () async {
      await seedCheckout(localId: 'sale-1');
      expect(() => db.deleteLocalOrder('sale-1'),
          throwsA(isA<UnbankedCheckoutException>()));

      // An open order has no document at all — deleting it strands nothing.
      await db.insertOfflineOrder(
        PosOrdersTableCompanion.insert(
          localId: 'open-1',
          companyId: 25,
          userId: 9,
          serviceType: 0,
          openedAt: now,
          warehouseId: 17,
          lastModified: now,
          status: const Value(0),
          syncStatus: const Value('pending'),
        ),
        const [],
      );
      await db.deleteLocalOrder('open-1');
      expect(
        await (db.select(db.posOrdersTable)
              ..where((t) => t.localId.equals('open-1')))
            .getSingleOrNull(),
        isNull,
      );
    });
  });

  test('Sync Status calls a closed sale a completed sale, not an open order',
      () async {
    // The label is what pushed the operator to delete the row: "Sales orders
    // 1 pending" reads like an order still sitting on a table.
    await seedCheckout(localId: 'sale-1'); // status 1 — paid, awaiting upload
    await db.insertOfflineOrder(
      PosOrdersTableCompanion.insert(
        localId: 'open-1',
        companyId: 25,
        userId: 9,
        serviceType: 0,
        openedAt: now,
        warehouseId: 17,
        lastModified: now,
        status: const Value(0),
        syncStatus: const Value('pending'),
      ),
      const [],
    );

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.listen(syncStatusProvider, (_, __) {});

    final byLabel = {
      for (final e in await container.read(syncStatusProvider.future))
        e.label: e,
    };
    expect(byLabel['Completed sales']?.pending, 1);
    expect(byLabel['Open orders']?.pending, 1);
    expect(byLabel.containsKey('Sales orders'), isFalse,
        reason: 'the ambiguous single line is gone');
  });

  group('document numbering stops colliding', () {
    Future<String> issue() => db.nextDocumentNumber(
          companyId: 25,
          deviceName: 'POS1',
          docTypeCode: DocumentTypes.salesCode,
        );

    Future<void> seedPulledDocument(String number, int serverId) =>
        db.into(db.documentsTable).insert(
              DocumentsTableCompanion.insert(
                localId: 'srv_$serverId',
                companyId: 25,
                userId: 9,
                warehouseId: 17,
                date: now,
                lastModified: now,
                serverId: Value(serverId),
                number: Value(number),
                syncStatus: const Value('synced'),
              ),
            );

    test('the counter jumps past numbers the cloud already issued', () async {
      // A restore rolled this terminal's counter back to 2 while the account
      // already holds …000007 — the live POS1-200-000007 collision.
      expect(await issue(), 'POS1-200-000001');
      expect(await issue(), 'POS1-200-000002');
      for (var i = 1; i <= 7; i++) {
        await seedPulledDocument('POS1-200-${'$i'.padLeft(6, '0')}', 100 + i);
      }

      expect(
        await db.advanceLocalDocumentCounter(
            companyId: 25, deviceName: 'POS1', docTypeCode: '200'),
        5,
      );
      expect(await issue(), 'POS1-200-000008');
    });

    test("another terminal's numbers are ignored", () async {
      await seedPulledDocument('CAISSE2-200-000099', 900);

      expect(
        await db.advanceLocalDocumentCounter(
            companyId: 25, deviceName: 'POS1', docTypeCode: '200'),
        0,
      );
      expect(await issue(), 'POS1-200-000001');
    });

    test('a counter already ahead is never wound back', () async {
      for (var i = 0; i < 9; i++) {
        await issue();
      }
      await seedPulledDocument('POS1-200-000004', 104);

      expect(
        await db.advanceLocalDocumentCounter(
            companyId: 25, deviceName: 'POS1', docTypeCode: '200'),
        0,
      );
      expect(await issue(), 'POS1-200-000010');
    });

    test('a hand-typed number sharing the prefix is not read as a sequence',
        () async {
      // The server's collision fallback (item 30) issues "…-000007-2".
      await seedPulledDocument('POS1-200-000007-2', 907);

      expect(
        await db.advanceLocalDocumentCounter(
            companyId: 25, deviceName: 'POS1', docTypeCode: '200'),
        0,
      );
    });
  });
}
