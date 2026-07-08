class ProductTax {
  final int productId;
  final String productName;
  final int taxId;
  final String taxName;
  final double taxRate;

  ProductTax({
    required this.productId,
    required this.productName,
    required this.taxId,
    required this.taxName,
    required this.taxRate,
  });

  factory ProductTax.fromJson(Map<String, dynamic> json) {
    return ProductTax(
      productId: json['productId'] ?? 0,
      productName: json['productName'] ?? '',
      taxId: json['taxId'] ?? 0,
      taxName: json['taxName'] ?? '',
      taxRate: (json['taxRate'] ?? 0).toDouble(),
    );
  }
}
