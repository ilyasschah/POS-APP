import '../core/json_utils.dart';
import 'product.dart';
import 'stock_rule.dart';
import 'unit_of_measure.dart';

/// A row from `GET /Stocks/GetAllStocks`.
///
/// This endpoint returns a flat `(product, warehouse) -> quantity` list, so a
/// product stocked in three warehouses appears three times, and a product
/// stocked nowhere does not appear at all.
class StockEntry {
  const StockEntry({
    required this.id,
    required this.productId,
    required this.productName,
    required this.warehouseId,
    required this.warehouseName,
    required this.quantity,
  });

  final int id;
  final int productId;
  final String productName;
  final int warehouseId;
  final String warehouseName;
  final double quantity;

  factory StockEntry.fromJson(Map<String, dynamic> json) => StockEntry(
    id: asInt(json['id']),
    productId: asInt(json['productId']),
    productName: asString(json['productName']),
    warehouseId: asInt(json['warehouseId']),
    warehouseName: asString(json['warehouseName'], 'Unknown warehouse'),
    quantity: asDouble(json['quantity']),
  );
}

/// One product's stock position across every warehouse, with its rules.
///
/// Built by left-joining [StockEntry] rows onto the *full* product list, so a
/// product with no stock record anywhere still gets a row — surfaced as
/// "Unassigned" rather than being silently hidden.
class ProductStock {
  const ProductStock({required this.product, required this.entries, this.rule});

  final Product product;
  final List<StockEntry> entries;

  /// Its low-stock / reorder rules; null when none were ever set.
  final StockRule? rule;

  /// True when this product has no stock record in any warehouse.
  bool get isUnassigned => entries.isEmpty;

  /// Quantity summed across every warehouse holding this product, in
  /// [stockUnit].
  double get totalQuantity =>
      entries.fold<double>(0, (sum, e) => sum + e.quantity);

  /// Only shown when the product is split across more than one warehouse.
  bool get isMultiWarehouse => entries.length > 1;

  UnitOfMeasure get stockUnit => product.stockUnit;

  /// At or below its low-stock warning. The POS's rule, exactly; a product
  /// with no stock record is "Unassigned", not low.
  bool get isLow => !isUnassigned && (rule?.isLowAt(totalQuantity) ?? false);

  /// At or below its reorder point.
  bool get needsReorder =>
      !isUnassigned && (rule?.needsReorderAt(totalQuantity) ?? false);

  /// What to order to get back to the preferred quantity.
  double get suggestedOrder => rule?.suggestedOrderAt(totalQuantity) ?? 0;

  /// [quantity] in this product's stock unit — `12.500 kg`.
  String format(double quantity) => formatUomQuantity(quantity, stockUnit);

  /// Left-joins stock rows and rules onto all products, sorted by name.
  static List<ProductStock> join(
    List<Product> products,
    List<StockEntry> stocks, {
    List<StockRule> rules = const [],
  }) {
    final byProduct = <int, List<StockEntry>>{};
    for (final entry in stocks) {
      byProduct.putIfAbsent(entry.productId, () => []).add(entry);
    }
    final ruleOf = <int, StockRule>{};
    for (final rule in rules) {
      ruleOf.putIfAbsent(rule.productId, () => rule);
    }

    final joined = products
        .map(
          (p) => ProductStock(
            product: p,
            entries: List.unmodifiable(byProduct[p.id] ?? const <StockEntry>[]),
            rule: ruleOf[p.id],
          ),
        )
        .toList();

    joined.sort(
      (a, b) => a.product.displayName.toLowerCase().compareTo(
        b.product.displayName.toLowerCase(),
      ),
    );
    return joined;
  }
}
