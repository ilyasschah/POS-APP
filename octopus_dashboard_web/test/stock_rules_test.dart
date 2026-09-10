import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_dashboard_web/models/product.dart';
import 'package:octopus_dashboard_web/models/stock.dart';
import 'package:octopus_dashboard_web/models/stock_rule.dart';
import 'package:octopus_dashboard_web/models/unit_of_measure.dart';

/// The Stock screen's units and rules.
///
/// 🚨 Why this exists: the owner's stock page showed a bare number — "477" of
/// what? — and nothing about the rules the till already enforces. The flags
/// here must agree with the POS's `StockControl.isLowStockAt/needsReorderAt`,
/// or the owner and the cashier see different answers to "are we running out".
Product product({
  int id = 1,
  int uomId = kUomPieces,
  String? unit,
  double? packSize,
}) => Product(
  id: id,
  name: 'P$id',
  code: null,
  price: 10,
  cost: 5,
  isTaxInclusivePrice: true,
  isPriceChangeAllowed: false,
  isService: false,
  isUsingDefaultQuantity: true,
  isEnabled: true,
  color: 'Transparent',
  measurementUnit: unit,
  uomId: uomId,
  packSize: packSize,
);

StockEntry stock(int productId, double quantity) => StockEntry(
  id: productId,
  productId: productId,
  productName: 'P$productId',
  warehouseId: 1,
  warehouseName: 'Main',
  quantity: quantity,
);

void main() {
  group('the rule, exactly as the till applies it', () {
    const rule = StockRule(
      productId: 1,
      reorderPoint: 10,
      preferredQuantity: 30,
      isLowStockWarningEnabled: true,
      lowStockWarningQuantity: 5,
    );

    test('low at or below the warning quantity', () {
      expect(rule.isLowAt(5), isTrue);
      expect(rule.isLowAt(5.001), isFalse);
    });

    test('a switched-off or zero warning never fires', () {
      const off = StockRule(productId: 1, lowStockWarningQuantity: 5);
      const zero = StockRule(productId: 1, isLowStockWarningEnabled: true);
      expect(off.isLowAt(0), isFalse);
      expect(zero.isLowAt(0), isFalse);
    });

    test('reorder at or below the reorder point, never with none set', () {
      expect(rule.needsReorderAt(10), isTrue);
      expect(rule.needsReorderAt(11), isFalse);
      expect(const StockRule(productId: 1).needsReorderAt(-3), isFalse);
    });

    test('the suggested order tops up to the preferred quantity', () {
      expect(rule.suggestedOrderAt(8), 22);
      expect(rule.suggestedOrderAt(40), 0);
    });

    test('the supplier arrives as the stock control customer', () {
      final r = StockRule.fromJson(const {
        'id': 3,
        'productId': 9,
        'customerId': 4,
        'customerName': 'Atlas Foods',
        'reorderPoint': 2.5,
        'preferredQuantity': 10,
        'isLowStockWarningEnabled': true,
        'lowStockWarningQuantity': 1,
      });
      expect(r.supplierName, 'Atlas Foods');
      expect(r.reorderPoint, 2.5);
      expect(r.hasLowStockWarning, isTrue);
    });
  });

  group('each product gets its rules', () {
    test('joined by product id; a product with none has none', () {
      final rows = ProductStock.join(
        [product(id: 1), product(id: 2)],
        [stock(1, 3), stock(2, 3)],
        rules: const [
          StockRule(
            productId: 1,
            isLowStockWarningEnabled: true,
            lowStockWarningQuantity: 5,
          ),
        ],
      );

      expect(rows[0].rule, isNotNull);
      expect(rows[0].isLow, isTrue);
      expect(rows[1].rule, isNull);
      expect(rows[1].isLow, isFalse);
    });

    test('a product with no stock record is Unassigned, not low', () {
      final row = ProductStock.join(
        [product(id: 1)],
        const [],
        rules: const [
          StockRule(productId: 1, reorderPoint: 10, isLowStockWarningEnabled: true, lowStockWarningQuantity: 5),
        ],
      ).single;

      expect(row.isUnassigned, isTrue);
      expect(row.isLow, isFalse);
      expect(row.needsReorder, isFalse);
    });
  });

  group('units', () {
    test('stock is shown in the unit it is counted in', () {
      final kilo = ProductStock.join([product(uomId: 10)], [stock(1, 12.5)]).single;
      expect(kilo.format(kilo.totalQuantity), '12.500 kg');
    });

    test('a product sold in grams counts its stock in kilograms', () {
      final grams = product(uomId: 11);
      expect(grams.saleUnit.code, 'g');
      expect(grams.stockUnit.code, 'kg');
    });

    test('a product sold by the box counts its stock in pieces', () {
      expect(product(uomId: kUomBox, packSize: 24).stockUnit.code, 'pcs');
    });

    test('a digit the quantity has is never hidden', () {
      expect(formatUomQuantity(0.25, uomById(kUomPieces)), '0.25 pcs');
    });

    test('an old row with only the legacy text is healed like the POS heals it', () {
      final legacy = product(uomId: kUomPieces, unit: 'KG');
      expect(legacy.effectiveUomId, 10);
      expect(legacy.stockUnit.code, 'kg');
    });

    test('an unknown id falls back to pieces instead of throwing', () {
      expect(uomById(999).code, 'pcs');
    });
  });

  group('the product record', () {
    final json = {
      'id': 5,
      'name': 'Saffron',
      'price': 30,
      'cost': 20,
      'isTaxInclusivePrice': true,
      'isPriceChangeAllowed': false,
      'isService': false,
      'isUsingDefaultQuantity': true,
      'isEnabled': true,
      'color': 'Transparent',
      'measurementUnit': 'g',
      'uomId': 11,
      'isToWeigh': true,
      'packSize': null,
    };

    test('reads the unit it is sold in', () {
      final p = Product.fromJson(json);
      expect(p.uomId, 11);
      expect(p.isToWeigh, isTrue);
    });

    test('a price edit sends the unit back, so the server cannot reset it', () {
      final body = Product.fromJson(json).toUpdateJson(newPrice: 31, newCost: 20);
      expect(body['uomId'], 11);
      expect(body['isToWeigh'], isTrue);
      expect(body.containsKey('packSize'), isTrue);
    });
  });
}
