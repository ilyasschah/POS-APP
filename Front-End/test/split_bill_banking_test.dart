// A split bill banks ONE document carrying a payment per guest — so opening
// that document's Payments tab lists every one of them.
//
// Pins the local half: the rows land together, read back in the order the
// guests paid, settle the paid status, and all flip to synced when the order's
// BatchSync links the document (the server creates them from the same push).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime.utc(2026, 9, 11, 20);
  const docId = 'split-doc';

  PaymentsTableCompanion pay(String id, int type, double amount, int order) =>
      PaymentsTableCompanion.insert(
        localId: id,
        documentId: docId,
        paymentTypeId: type,
        amount: amount,
        userId: 9,
        date: now.add(Duration(seconds: order)),
        companyId: const Value(25),
      );

  Future<void> bank({required double total, required List<PaymentsTableCompanion> payments}) =>
      db.insertOfflineDocument(
        document: DocumentsTableCompanion.insert(
          localId: docId,
          companyId: 25,
          userId: 9,
          warehouseId: 17,
          date: now,
          lastModified: now,
          number: const Value('POS1-200-000041'),
          total: Value(total),
          syncStatus: const Value('pending'),
        ),
        items: [
          DocumentItemsTableCompanion.insert(
            localId: 'line-1',
            documentId: docId,
            productId: 41,
            quantity: 1,
            unitPrice: total,
            total: total,
          ),
        ],
        payment: payments.first,
        otherPayments: payments.skip(1).toList(),
      );

  test("every guest's payment is on the one document, in the order they paid",
      () async {
    await bank(total: 100, payments: [
      pay('guest-1', 1, 40, 0),
      pay('guest-2', 2, 35, 1),
      pay('guest-3', 1, 25, 2),
    ]);

    final rows = await db.watchPayments(docId).first;
    expect(rows.map((r) => r.localId), ['guest-1', 'guest-2', 'guest-3']);
    expect(rows.map((r) => r.amount), [40, 35, 25]);
    expect(rows.every((r) => r.syncStatus == 'pending'), isTrue,
        reason: 'travelled with the order — never pushed on their own');
    expect(await db.recomputePaidStatus(docId), 1);
  });

  test('a share put on account leaves the document partly paid', () async {
    await bank(total: 100, payments: [
      pay('guest-1', 1, 40, 0),
      pay('guest-2', 3, 0, 1),
    ]);

    expect(await db.recomputePaidStatus(docId), 2);
  });

  test('linking the document to the server settles every payment', () async {
    await bank(total: 100, payments: [
      pay('guest-1', 1, 40, 0),
      pay('guest-2', 2, 60, 1),
    ]);

    await db.linkDocumentToServer(docId, 77);

    final rows = await db.getPayments(docId);
    expect(rows.map((r) => r.syncStatus).toSet(), {'synced'});
  });
}
