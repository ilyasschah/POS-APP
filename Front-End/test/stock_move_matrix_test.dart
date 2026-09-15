// The Stock Moves matrix: which way each document type moves goods — read from
// the type's stock_direction and category, never from a list of type ids — and
// how an inventory count's variance is read out of Quantity and
// ExpectedQuantity.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/document/document_type_constants.dart';
import 'package:pos_app/stock/stock_move_line.dart';

/// The server's seeded types (GlobalDefaultsSeeder.cs): id → (category, direction).
const seeded = {
  DocumentTypes.purchase: (DocumentCategories.expenses, StockDirections.intoStock),
  DocumentTypes.sales: (DocumentCategories.sales, StockDirections.outOfStock),
  DocumentTypes.inventoryCount:
      (DocumentCategories.inventory, StockDirections.intoStock),
  DocumentTypes.refund: (DocumentCategories.sales, StockDirections.intoStock),
  DocumentTypes.stockReturn:
      (DocumentCategories.expenses, StockDirections.outOfStock),
  DocumentTypes.lossAndDamage:
      (DocumentCategories.loss, StockDirections.outOfStock),
  DocumentTypes.proforma: (DocumentCategories.sales, StockDirections.none),
};

void main() {
  // Either side of the day counts started recording their expected quantity.
  final recorded = DateTime.utc(2026, 10, 1);
  final legacy = DateTime.utc(2026, 9, 10);

  /// A line of [type], resolved with its seeded category and direction unless
  /// the test overrides them.
  StockMoveRoute? route(
    int type,
    double quantity, {
    double? expected,
    DateTime? date,
    int? direction,
    int? category,
  }) =>
      StockMoveMatrix.resolve(
        documentTypeId: type,
        stockDirection: direction ?? seeded[type]?.$2 ?? StockDirections.none,
        documentCategoryId: category ?? seeded[type]?.$1,
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
    test('each seeded type crosses the warehouse wall the way its direction says',
        () {
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

    test('every direction-1 type comes in, every direction-2 type goes out', () {
      seeded.forEach((type, entry) {
        final r = route(type, 1, expected: 0);
        switch (entry.$2) {
          case StockDirections.intoStock:
            expect(r?.to, stock, reason: 'type $type puts goods into stock');
          case StockDirections.outOfStock:
            expect(r?.from, stock, reason: 'type $type takes goods out');
          default:
            expect(r, isNull, reason: 'type $type moves no stock');
        }
      });
    });

    test('a type with no stock direction moves nothing', () {
      expect(route(DocumentTypes.proforma, 5), isNull);
      // A type this till has not pulled yet has no direction either.
      expect(route(99, 5), isNull);
    });

    test('the direction is read, not assumed from the type id', () {
      // Were Purchase re-pointed out of stock on the server, it would follow.
      expect(route(DocumentTypes.purchase, 5,
              direction: StockDirections.outOfStock),
          (from: stock, to: vendors, quantity: 5.0));
    });

    test('a type the server added moves by its own direction and category', () {
      expect(
          route(42, 3,
              direction: StockDirections.outOfStock,
              category: DocumentCategories.loss),
          (from: stock, to: scrap, quantity: 3.0));
      // A category this app does not know is booked against adjustment.
      expect(route(43, 3, direction: StockDirections.intoStock, category: 99),
          (from: adjustment, to: stock, quantity: 3.0));
    });

    test("a line's sign is not a direction", () {
      // This till records a refund's lines negative, like the money it gives
      // back; the goods still came back in, green, from the customer.
      expect(route(DocumentTypes.refund, -2),
          (from: customers, to: stock, quantity: 2.0));
      expect(route(DocumentTypes.sales, -2),
          (from: stock, to: customers, quantity: 2.0));
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
