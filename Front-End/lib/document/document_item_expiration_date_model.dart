class DocumentItemExpirationDateModel {
  final int documentItemId;
  final DateTime expirationDate;

  DocumentItemExpirationDateModel({
    required this.documentItemId,
    required this.expirationDate,
  });

  factory DocumentItemExpirationDateModel.fromJson(Map<String, dynamic> json) {
    return DocumentItemExpirationDateModel(
      documentItemId: json['documentItemId'] ?? 0,
      expirationDate: DateTime.parse(json['expirationDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'documentItemId': documentItemId,
      'expirationDate': expirationDate.toIso8601String(),
    };
  }
}
