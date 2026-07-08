class PaymentModel {
  final int id;
  final int documentId;
  final int paymentTypeId;
  final String? paymentTypeName;
  final double amount;
  final DateTime date;
  final int userId;
  final String? userName;
  final int? zReportId;

  /// Drift local UUID PK — present only for payments read from the offline-first
  /// local store. Null for payments parsed straight from an API payload.
  final String? localId;

  /// Offline-first sync state: 'synced' | 'pending_create' | 'pending_update' |
  /// 'pending_delete' (or the legacy checkout 'pending'). Used by the editor to
  /// decide how an edit/delete is queued.
  final String syncStatus;

  PaymentModel({
    required this.id,
    required this.documentId,
    required this.paymentTypeId,
    this.paymentTypeName,
    required this.amount,
    required this.date,
    required this.userId,
    this.userName,
    this.zReportId,
    this.localId,
    this.syncStatus = 'synced',
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] ?? 0,
      documentId: json['documentId'] ?? 0,
      paymentTypeId: json['paymentTypeId'] ?? 0,
      paymentTypeName: json['paymentTypeName'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(json['date']),
      userId: json['userId'] ?? 0,
      userName: json['userName'],
      zReportId: json['zReportId'],
    );
  }
}
