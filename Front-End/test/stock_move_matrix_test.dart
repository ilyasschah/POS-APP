// The Stock Moves matrix: which way each document type moves goods, and how an
// inventory count's variance is read out of Quantity and ExpectedQuantity.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/document/document_type_constants.dart';
import 'package:pos_app/stock/stock_move_line.dart';

void main() {
  // Either side of the day counts started recording their expected quantity.
  final recorded = DateTime.utc(2026, 10, 1);
  final legacy = DateTime.utc(2026, 9, 10);

  StockMoveRoute? route(
    int type,
    double quantity, {
    double? expected,
    DateTime? date,
  }) =>
      StockMoveMatrix.resolve(
        documentTypeId: type,
        quantity: quantity,
        expectedQuantity: expected,
        date: date ?? recorded,
      );

  const vendors = StockLocationKind.vendors;
  const customers = StockLocationKind.customers;
  const adjustment = StockLocationKind.inventoryAdjustment;
  const scrap = StockLocationKind.scrap;
  const stock = StockLocationKind.warehouse;

  group('the matrix', () {
    test('each moving type crosses the warehouse wall its own way', () {
      expect(route(DocumentTypes.purchase, 5),
          (from: vendors, to: stock, quantity: 5.0));
      expect(route(DocumentTypes.sales, 5),
          (from: stock, to: customers, quantity: 5.0));
      expect(route(DocumentTypes.refund, 5),
          (from: customers, to: stock, quantity: 5.0));
      expect(route(DocumentTypes.stockReturn, 5),
          (from: stock, to: vendors, quantity: 5.0));
      expect(route(DocumentTypes.lossAndDamage, 5),
          (from: stock, to: scrap, quantity: 5.0));
    });

    test('a proforma, or a type nobody knows, moves nothing', () {
      expect(route(DocumentTypes.proforma, 5), isNull);
      expect(route(99, 5), isNull);
      expect(StockMoveMatrix.movingDocumentTypes,
          isNot(contains(DocumentTypes.proforma)));
    });

    test("agrees with the server's seeded StockDirection", () {
      // GlobalDefaultsSeeder.cs: 1 = into stock, 2 = out of stock, 0 = none.
      const seeded = {1: 1, 2: 2, 3: 1, 4: 1, 5: 2, 6: 2, 7: 0};
      seeded.forEach((type, direction) {
        final r = route(type, 1, expected: 0);
        switch (direction) {
          case 0:
            expect(r, isNull, reason: 'type $type moves no stock');
          case 1:
            expect(r?.to, stock, reason: 'type $type puts goods into stock');
          case 2:
            expect(r?.from, stock, reason: 'type $type takes goods out');
        }
        expect(StockMoveMatrix.movingDocumentTypes.contains(type),
            direction != 0);
      });
    });

    test('a negative line turns the route around instead of going negative',
        () {
      expect(route(DocumentTypes.sales, -2),
          (from: customers, to: stock, quantity: 2.0));
    });

    test('a zero line moves nothing', () {
      expect(route(DocumentTypes.purchase, 0), isNull);
    });
  });

  group('an inventory count', () {
    test('that found more brings the surplus in from Inventory adjustment',
        () {
      expect(route(DocumentTypes.inventoryCount, 12, expected: 10),
          (from: adjustment, to: stock, quantity: 2.0));
    });

    test('that came up short sends the shortfall out to Inventory adjustment',
        () {
      expect(route(DocumentTypes.inventoryCount, 7, expected: 10),
          (from: stock, to: adjustment, quantity: 3.0));
    });

    test('that agreed with the system moves nothing', () {
      expect(route(DocumentTypes.inventoryCount, 10, expected: 10), isNull);
    });

    test('from before the variance was recorded is an opening balance', () {
      // Every writer copied Quantity into ExpectedQuantity back then.
      expect(
          route(DocumentTypes.inventoryCount, 148,
              expected: 148, date: legacy),
          (from: adjustment, to: stock, quantity: 148.0));
    });

    test('that never recorded what it expected is an opening balance', () {
      expect(route(DocumentTypes.inventoryCount, 6.61),
          (from: adjustment, to: stock, quantity: 6.61));
    });

    test('does not invent a move out of floating-point error', () {
      expect(route(DocumentTypes.inventoryCount, 0.1 + 0.2, expected: 0.3),
          isNull);
    });
  });
}
