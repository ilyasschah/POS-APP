// What a sale, a void and a refund actually do to the shelf.
//
// Stock is held in the category's REFERENCE unit (weight ⇒ kg) while a cart
// line is counted in the product's SALE unit. `deductStockForCheckout` is the
// one place the two meet, and for a while it did not convert at all: selling
// 100 g of saffron took 100 kilograms off the shelf, and voiding that order put
// 100 kilograms back. On a product with half a kilo in stock that is not a
// rounding error, it is inventory invented out of nothing.
//
// Every case here is stated end-to-end — shelf before, line quantity, shelf
// after — because the failure mode is a number that is plausible in isolation
// and absurd against the row it came from.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

void main() {
  late AppDatabase db;

  const productId = 42;
  const warehouseId = 7;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<void> seedStock(double quantity) async {
    await db.into(db.stocksTable).insert(
          StocksTableCompanion.insert(
            id: const Value(1),
            productId: productId,
            warehouseId: warehouseId,
            companyId: 1,
            quantity: Value(quantity),
            lastModified: DateTime.now().toUtc(),
          ),
        );
  }

  Future<double> shelf() async {
    final row = await (db.select(db.stocksTable)
          ..where((t) => t.productId.equals(productId)))
        .getSingle();
    return row.quantity;
  }

  ({
    int productId,
    double quantity,
    int uomId,
    int warehouseId,
    bool isService,
    String productName,
  }) line(double quantity, int uomId) => (
        productId: productId,
        quantity: quantity,
        uomId: uomId,
        warehouseId: warehouseId,
        isService: false,
        productName: 'Saffron',
      );

  group('a sale in grams moves stock in kilograms', () {
    test('selling 100 g off 0.500 kg leaves 0.400 kg', () async {
      await seedStock(0.500);
      await db.deductStockForCheckout(
        items: [line(100, kUomGram)],
        allowNegative: true,
      );
      expect(await shelf(), 0.400);
    });

    test('selling 350 g leaves a figure with no binary residue', () async {
      // The shelf figure is read back and rendered; 0.15000000000000002 would
      // print as `0.150000 kg` in every stock view.
      await seedStock(0.500);
      await db.deductStockForCheckout(
        items: [line(350, kUomGram)],
        allowNegative: true,
      );
      expect(await shelf(), 0.150);
      expect(formatQuantity(await shelf(), kUomKilogram), '0.150 kg');
    });

    test('a whole kilo sold in grams empties a one-kilo shelf', () async {
      await seedStock(1.000);
      await db.deductStockForCheckout(
        items: [line(1000, kUomGram)],
        allowNegative: true,
      );
      expect(await shelf(), 0);
    });
  });

  group('putting stock back', () {
    test('voiding a 100 g line restores 0.100 kg, not 100 kg', () async {
      // The user-reported shape: a void handed back a negative quantity in the
      // sale unit, and the shelf gained a hundred kilograms of saffron.
      await seedStock(0.400);
      await db.deductStockForCheckout(
        items: [line(-100, kUomGram)],
        allowNegative: true,
      );
      expect(await shelf(), 0.500);
      expect(await shelf(), lessThan(1));
    });

    test('a sale and its void cancel out exactly', () async {
      await seedStock(0.500);
      await db.deductStockForCheckout(
        items: [line(137, kUomGram)],
        allowNegative: true,
      );
      await db.deductStockForCheckout(
        items: [line(-137, kUomGram)],
        allowNegative: true,
      );
      expect(await shelf(), 0.500);
    });
  });

  group('the out-of-stock pre-flight compares like with like', () {
    test('1 g is sellable from half a kilo', () async {
      // The tap that started this: one gram read as one kilogram, 0.500 − 1
      // went negative, and a product with 500 g on the shelf refused to sell.
      await seedStock(0.500);
      final result = await db.deductStockForCheckout(
        items: [line(1, kUomGram)],
        allowNegative: false,
      );
      expect(result.success, isTrue);
      expect(await shelf(), 0.499);
    });

    test('asking for more grams than exist is still refused', () async {
      await seedStock(0.500);
      final result = await db.deductStockForCheckout(
        items: [line(600, kUomGram)],
        allowNegative: false,
      );
      expect(result.success, isFalse);
      expect(await shelf(), 0.500, reason: 'a refused sale moves nothing');
    });

    test('the refusal names both figures in the STOCK unit', () async {
      await seedStock(0.500);
      final result = await db.deductStockForCheckout(
        items: [line(600, kUomGram)],
        allowNegative: false,
      );
      // "available: 0.500 kg, needed: 0.600 kg" — two figures a human can
      // compare. Quoting the sale unit on one side and the stock unit on the
      // other is how the original message read as nonsense.
      expect(result.message, contains('0.500 kg'));
      expect(result.message, contains('0.600 kg'));
    });
  });

  group('a product sold in its own reference unit is unaffected', () {
    test('kilograms pass through untouched', () async {
      await seedStock(2.000);
      await db.deductStockForCheckout(
        items: [line(0.250, kUomKilogram)],
        allowNegative: true,
      );
      expect(await shelf(), 1.750);
    });

    test('pieces pass through untouched, fractions included', () async {
      await seedStock(88.5);
      await db.deductStockForCheckout(
        items: [line(0.5, kUomPieces)],
        allowNegative: true,
      );
      expect(await shelf(), 88.0);
    });
  });

  test('a service never touches stock, whatever its unit says', () async {
    await seedStock(0.500);
    await db.deductStockForCheckout(
      items: [
        (
          productId: productId,
          quantity: 100,
          uomId: kUomGram,
          warehouseId: warehouseId,
          isService: true,
          productName: 'Grinding',
        )
      ],
      allowNegative: true,
    );
    expect(await shelf(), 0.500);
  });
}
