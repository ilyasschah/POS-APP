// Pins that a sale rung up on ONE terminal shows its payment on EVERY terminal.
//
// Reported 2026-08-06 as "the Paiement column says N/A on POS1 but is filled on
// POS2, and vice versa". Verified against both databases:
//
//   SQL Server  — all four documents had exactly one Payment row, correct
//                 amounts, type "Espèces". The server was never wrong.
//   POS1 Drift  — `srv_95` / `srv_96` (pulled from POS2) had payment_rows = 0;
//                 the two documents created ON POS1 had 1 each.
//
// Cause: **there was no payment pull at all.** `payments` had `pushPendingPayments`
// and nothing on the way back, so every terminal held payments only for its own
// sales. Not just a cosmetic column — the Z-report's breakdown-by-payment-type
// and the credit screen read the same table, so each till's takings report
// counted only what it had rung up itself.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insertDoc(String localId, {int? serverId}) =>
      db.into(db.documentsTable).insert(
            DocumentsTableCompanion.insert(
              localId: localId,
              companyId: 25,
              userId: 9,
              warehouseId: 17,
              date: DateTime.utc(2026, 8, 6),
              serverId: Value(serverId),
              number: const Value('POS1-200-000037'),
              total: const Value(47),
              lastModified: DateTime.utc(2026, 8, 6),
            ),
          );

  PaymentsTableCompanion serverPayment(String docLocalId, int serverId,
          {double amount = 47}) =>
      PaymentsTableCompanion.insert(
        localId: 'srvp_$serverId',
        documentId: docLocalId,
        paymentTypeId: 45,
        amount: amount,
        userId: 9,
        date: DateTime.utc(2026, 8, 6),
        serverId: Value(serverId),
        companyId: const Value(25),
        syncStatus: const Value('synced'),
      );

  Future<List<PaymentsTableData>> paymentsFor(String docLocalId) =>
      (db.select(db.paymentsTable)
            ..where((t) => t.documentId.equals(docLocalId)))
          .get();

  test('a pulled document arrives WITH its payment', () async {
    await insertDoc('srv_94', serverId: 94);

    await db.replaceServerPayments('srv_94', [serverPayment('srv_94', 97)]);

    // Was 0 — the row the "N/A" column was rendering from.
    final rows = await paymentsFor('srv_94');
    expect(rows, hasLength(1));
    expect(rows.single.amount, 47);
    expect(rows.single.paymentTypeId, 45);
    expect(rows.single.serverId, 97,
        reason: 'without the server id a later edit/delete has nothing to push');
  });

  test('re-pulling the same payment updates one row, never duplicates', () async {
    await insertDoc('srv_94', serverId: 94);

    await db.replaceServerPayments('srv_94', [serverPayment('srv_94', 97)]);
    await db.replaceServerPayments('srv_94', [serverPayment('srv_94', 97)]);
    await db.replaceServerPayments('srv_94', [serverPayment('srv_94', 97)]);

    expect(await paymentsFor('srv_94'), hasLength(1),
        reason: 'the deterministic srvp_<id> localId is what prevents this');
  });

  test('a payment removed on another terminal is removed here', () async {
    await insertDoc('srv_94', serverId: 94);
    await db.replaceServerPayments('srv_94', [serverPayment('srv_94', 97)]);

    // The other till voided the payment; the server now reports none.
    await db.replaceServerPayments('srv_94', const []);

    expect(await paymentsFor('srv_94'), isEmpty);
  });

  test('an UNPUSHED local payment is never destroyed by a pull', () async {
    // The load-bearing guard. This payment exists only here; deleting it would
    // drop money the server has never seen.
    await insertDoc('local-doc-1');
    await db.into(db.paymentsTable).insert(
          PaymentsTableCompanion.insert(
            localId: 'local-pay-1',
            documentId: 'local-doc-1',
            paymentTypeId: 45,
            amount: 20,
            userId: 9,
            date: DateTime.utc(2026, 8, 6),
            syncStatus: const Value('pending'),
          ),
        );

    await db.replaceServerPayments('local-doc-1', const []);

    final rows = await paymentsFor('local-doc-1');
    expect(rows, hasLength(1), reason: 'unpushed money must survive');
    expect(rows.single.amount, 20);
  });

  test('a locally-edited payment is not overwritten by the server copy',
      () async {
    await insertDoc('srv_94', serverId: 94);
    // Pulled earlier, then edited here and not yet pushed.
    await db.into(db.paymentsTable).insert(
          PaymentsTableCompanion.insert(
            localId: 'srvp_97',
            documentId: 'srv_94',
            paymentTypeId: 45,
            amount: 99,
            userId: 9,
            date: DateTime.utc(2026, 8, 6),
            serverId: const Value(97),
            syncStatus: const Value('pending_update'),
          ),
        );

    await db.replaceServerPayments('srv_94', [serverPayment('srv_94', 97)]);

    final rows = await paymentsFor('srv_94');
    expect(rows, hasLength(1));
    expect(rows.single.amount, 99,
        reason: 'the pusher owns this row until its edit lands');
  });
}
