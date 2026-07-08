class StockItem {
  final int id;
  final double quantity;
  final int warehouseId;
  final String warehouseName;
  final int productId;
  final String productName;
  final int companyId;

  // Fetched separately from Products/GetById
  final double? cost;
  final double? price;
  final String? productCode;

  StockItem({
    required this.id,
    required this.quantity,
    required this.warehouseId,
    required this.warehouseName,
    required this.productId,
    required this.productName,
    required this.companyId,
    this.cost,
    this.price,
    this.productCode,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      id: json['id'] ?? 0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      warehouseId: json['warehouseId'] ?? 0,
      warehouseName: json['warehouseName'] ?? '',
      productId: json['productId'] ?? 0,
      productName: json['productName'] ?? '',
      companyId: json['companyId'] ?? 0,
    );
  }

  StockItem copyWith({double? cost, double? price, String? productCode}) {
    return StockItem(
      id: id,
      quantity: quantity,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      productId: productId,
      productName: productName,
      companyId: companyId,
      cost: cost ?? this.cost,
      price: price ?? this.price,
      productCode: productCode ?? this.productCode,
    );
  }
}
