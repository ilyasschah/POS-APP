import '../core/json_utils.dart';

/// A product's stock rules — a row from `GET /StockControls/GetAll`.
///
/// Mirrors the POS's `StockControl` (`Front-End/lib/stock/stock_control_provider.dart`):
/// the same flags computed the same way, so the owner and the till never
/// disagree about whether something is running low. Quantities are in the
/// product's stock unit, like the stock itself.
class StockRule {
  const StockRule({
    required this.productId,
    this.supplierName,
    this.reorderPoint = 0,
    this.preferredQuantity = 0,
    this.isLowStockWarningEnabled = false,
    this.lowStockWarningQuantity = 0,
  });

  final int productId;

  /// Who to reorder from. The API calls it the stock control's customer.
  final String? supplierName;
  final double reorderPoint;
  final double preferredQuantity;
  final bool isLowStockWarningEnabled;
  final double lowStockWarningQuantity;

  factory StockRule.fromJson(Map<String, dynamic> json) => StockRule(
    productId: asInt(json['productId']),
    supplierName: asStringOrNull(json['customerName']),
    reorderPoint: asDouble(json['reorderPoint']),
    preferredQuantity: asDouble(json['preferredQuantity']),
    isLowStockWarningEnabled: asBool(json['isLowStockWarningEnabled']),
    lowStockWarningQuantity: asDouble(json['lowStockWarningQuantity']),
  );

  /// A warning that can actually fire: switched on AND given a threshold.
  bool get hasLowStockWarning =>
      isLowStockWarningEnabled && lowStockWarningQuantity > 0;

  bool get hasReorderPoint => reorderPoint > 0;

  /// Nothing set — the row exists but nobody filled it in.
  bool get isEmpty =>
      !hasLowStockWarning &&
      !hasReorderPoint &&
      preferredQuantity <= 0 &&
      (supplierName?.trim().isEmpty ?? true);

  bool isLowAt(double quantity) =>
      hasLowStockWarning && quantity <= lowStockWarningQuantity;

  bool needsReorderAt(double quantity) =>
      hasReorderPoint && quantity <= reorderPoint;

  /// How much to order to get back to the preferred level; 0 when already there.
  double suggestedOrderAt(double quantity) {
    final s = preferredQuantity - quantity;
    return s > 0 ? s : 0;
  }
}
