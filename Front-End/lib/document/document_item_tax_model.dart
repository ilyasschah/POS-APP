class DocumentItemTaxModel {
  final int documentItemId;
  final int taxId;
  final String taxName;
  final double amount;

  DocumentItemTaxModel({
    required this.documentItemId,
    required this.taxId,
    required this.taxName,
    required this.amount,
  });

  factory DocumentItemTaxModel.fromJson(Map<String, dynamic> json) {
    return DocumentItemTaxModel(
      documentItemId: json['documentItemId'] ?? 0,
      taxId: json['taxId'] ?? 0,
      taxName: json['taxName'] ?? 'N/A',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
