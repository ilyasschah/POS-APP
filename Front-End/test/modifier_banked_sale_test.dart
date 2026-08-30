// Phase 5 — what happens to the choices once the sale is BANKED.
//
// Phase 4 got them as far as the cart and the parked order. The moment a sale
// is paid for, the open order and its lines are deleted: the modifier rows hang
// off those lines, so unless they are copied onto the DOCUMENT at checkout they
// cease to exist the second the customer pays.
//
// 🚨 The shape this fails in is the one nothing looks broken in. The surcharge
// is already inside the banked line price, so the till, the Z-report and the
// customer's change are all correct — only the reprint is wrong, and it is
// wrong by printing a plain burger for a line that was sold with Extra Cheese
// and charged for it.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/modifier/modifier_models.dart';

void main() {
  late AppDatabase db;
  const companyId = 25;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  DocumentsTableCompanion doc(String localId) => DocumentsTableCompanion(
        localId: Value(localId),
        number: const Value('26-200-000001'),
        companyId: const Value(companyId),
        userId: const Value(1),
        warehouseId: const Value(1),
        total: const Value(25),
        date: Value(DateTime.utc(2026, 8, 29)),
        syncStatus: const Value('pending'),
        lastModified: Value(DateTime.utc(2026, 8, 29)),
      );

  DocumentItemsTableCompanion line(String docId, String lineId,
          {int productId = 7, double price = 25}) =>
      DocumentItemsTableCompanion(
        localId: Value(lineId),
        documentId: Value(docId),
        productId: Value(productId),
        quantity: const Value(1),
        unitPrice: Value(price),
        total: Value(price),
      );

  DocumentItemModifiersTableCompanion mod(
    String lineId,
    String name, {
    double price = 0,
    int rank = 0,
    int? optionId,
  }) =>
      DocumentItemModifiersTableCompanion(
        localId: Value('m-$lineId-$name'),
        documentItemLocalId: Value(lineId),
        modifierOptionId: Value(optionId),
        groupName: const Value('Toppings'),
        name: Value(name),
        additionalPrice: Value(price),
        rank: Value(rank),
      );

  group('a banked sale keeps its choices', () {
    test('checkout writes them beside the document line', () async {
      await db.insertOfflineDocument(
        document: doc('d1'),
        items: [line('d1', 'l1')],
        payment: PaymentsTableCompanion(
          localId: const Value('p1'),
          documentId: const Value('d1'),
          paymentTypeId: const Value(1),
          amount: const Value(25),
          userId: const Value(1),
          date: Value(DateTime.utc(2026, 8, 29)),
          companyId: const Value(companyId),
        ),
        itemModifiers: [
          mod('l1', 'Extra Cheese', price: 5, optionId: 4),
          mod('l1', 'No Sugar', rank: 1, optionId: 5),
        ],
      );

      final byLine = await db.documentItemModifiersByLine('d1');
      expect(byLine['l1'], hasLength(2));
      expect(byLine['l1']!.map((m) => m.name),
          ['Extra Cheese', 'No Sugar']);
      // A free choice is a real kitchen instruction, not a missing price.
      expect(byLine['l1']!.last.additionalPrice, 0);
    });

    test('a sale with no choices writes nothing at all', () async {
      await db.insertOfflineDocument(
        document: doc('d2'),
        items: [line('d2', 'l2')],
        payment: PaymentsTableCompanion(
          localId: const Value('p2'),
          documentId: const Value('d2'),
          paymentTypeId: const Value(1),
          amount: const Value(25),
          userId: const Value(1),
          date: Value(DateTime.utc(2026, 8, 29)),
          companyId: const Value(companyId),
        ),
      );

      expect(await db.documentItemModifiersByLine('d2'), isEmpty);
    });

    test('one document never reads another document\'s choices', () async {
      // Both documents are keyed on their own lines; a reader that queried by
      // product or by rank would cross them.
      for (final id in ['d3', 'd4']) {
        await db.insertOfflineDocument(
          document: doc(id),
          items: [line(id, 'line-$id')],
          payment: PaymentsTableCompanion(
            localId: Value('pay-$id'),
            documentId: Value(id),
            paymentTypeId: const Value(1),
            amount: const Value(25),
            userId: const Value(1),
            date: Value(DateTime.utc(2026, 8, 29)),
            companyId: const Value(companyId),
          ),
          itemModifiers: [mod('line-$id', 'Sauce $id', price: 2)],
        );
      }

      final d3 = await db.documentItemModifiersByLine('d3');
      expect(d3.keys, ['line-d3']);
      expect(d3['line-d3']!.single.name, 'Sauce d3');
    });
  });

  group('the reprint rebuilds the split', () {
    test('basePrice comes out by SUBTRACTION, never from the product',
        () async {
      // 🚨 The banked line price already contains the surcharge. Re-reading
      // today's shelf price to get the base would reprint a year-old receipt
      // at this year's prices — the snapshot exists precisely so it cannot.
      await db.insertOfflineDocument(
        document: doc('d5'),
        items: [line('d5', 'l5', price: 25)],
        payment: PaymentsTableCompanion(
          localId: const Value('p5'),
          documentId: const Value('d5'),
          paymentTypeId: const Value(1),
          amount: const Value(25),
          userId: const Value(1),
          date: Value(DateTime.utc(2026, 8, 29)),
          companyId: const Value(companyId),
        ),
        itemModifiers: [mod('l5', 'Extra Cheese', price: 5, optionId: 4)],
      );

      final rows = (await db.documentItemModifiersByLine('d5'))['l5']!;
      final mods = selectedModifiersFromDocumentRows(rows);
      const bankedPrice = 25.0;

      expect(modifierSurcharge(mods), 5);
      expect(bankedPrice - modifierSurcharge(mods), 20,
          reason: 'the product line prints at 20, the choice at +5');
    });

    test('the snapshot survives the option being deleted', () async {
      // A null option id is the deleted case, and the line still reads.
      await db.insertOfflineDocument(
        document: doc('d6'),
        items: [line('d6', 'l6')],
        payment: PaymentsTableCompanion(
          localId: const Value('p6'),
          documentId: const Value('d6'),
          paymentTypeId: const Value(1),
          amount: const Value(25),
          userId: const Value(1),
          date: Value(DateTime.utc(2026, 8, 29)),
          companyId: const Value(companyId),
        ),
        itemModifiers: [mod('l6', 'Discontinued Sauce', price: 3)],
      );

      final mods = selectedModifiersFromDocumentRows(
          (await db.documentItemModifiersByLine('d6'))['l6']!);

      expect(mods.single.modifierOptionId, isNull);
      expect(mods.single.name, 'Discontinued Sauce');
      expect(mods.single.additionalPrice, 3);
    });
  });
}
