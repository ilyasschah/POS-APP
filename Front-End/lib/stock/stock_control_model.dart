class StockControl {
  final int id;
  final int productId;
  final String productName;
  final int? customerId;
  final String? customerName;
  final double reorderPoint;
  final double preferredQuantity;
  final bool isLowStockWarningEnabled;
  final double lowStockWarningQuantity;

  StockControl({
    required this.id,
    required this.productId,
    required this.productName,
    this.customerId,
    this.customerName,
    required this.reorderPoint,
    required this.preferredQuantity,
    required this.isLowStockWarningEnabled,
    required this.lowStockWarningQuantity,
  });

  factory StockControl.fromJson(Map<String, dynamic> json) {
    return StockControl(
      id: json['id'] ?? 0,
      productId: json['productId'] ?? 0,
      productName: json['productName'] ?? '',
      customerId: json['customerId'],
      customerName: json['customerName'],
      reorderPoint: (json['reorderPoint'] as num?)?.toDouble() ?? 0.0,
      preferredQuantity: (json['preferredQuantity'] as num?)?.toDouble() ?? 0.0,
      isLowStockWarningEnabled: json['isLowStockWarningEnabled'] ?? true,
      lowStockWarningQuantity:
          (json['lowStockWarningQuantity'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
