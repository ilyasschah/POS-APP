class ZReportPaymentSummaryModel {
  final int id;
  final int zReportId;
  final int paymentTypeId;
  final String? paymentTypeName;
  final double totalAmount;

  ZReportPaymentSummaryModel({
    required this.id,
    required this.zReportId,
    required this.paymentTypeId,
    this.paymentTypeName,
    required this.totalAmount,
  });

  factory ZReportPaymentSummaryModel.fromJson(Map<String, dynamic> json) {
    return ZReportPaymentSummaryModel(
      id: json['id'] ?? 0,
      zReportId: json['zReportId'] ?? 0,
      paymentTypeId: json['paymentTypeId'] ?? 0,
      paymentTypeName: json['paymentTypeName'],
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ZReportModel {
  final int id;
  final int companyId;
  final int number;
  final DateTime dateCreated;
  final int fromDocumentId;
  final int toDocumentId;
  /// How many documents the report closes over, and the device-local
  /// `YY-CCC-NNNNNN` range they span. Null on reports written before these were
  /// recorded, and on server-sourced rows — the API exposes only the int id
  /// range above, which is meaningless for documents that never synced.
  final int? documentCount;
  final String? fromDocumentNumber;
  final String? toDocumentNumber;
  final double totalSales;
  final double totalReturns;
  final double discountsGranted;
  final double taxableTotal;
  final double totalTax;
  final double grandTotal;
  final double totalCashIn;
  final double totalCashOut;

  /// The float the register opened with, when this report covers one.
  ///
  /// Null means "not applicable" — a company-wide report spanning no single
  /// session, or a report pulled from a server that does not carry the field.
  /// Never 0.00, which would read as "the drawer opened empty".
  final double? openingCash;
  final List<ZReportPaymentSummaryModel> paymentSummaries;

  ZReportModel({
    required this.id,
    required this.companyId,
    required this.number,
    required this.dateCreated,
    required this.fromDocumentId,
    required this.toDocumentId,
    this.documentCount,
    this.fromDocumentNumber,
    this.toDocumentNumber,
    required this.totalSales,
    required this.totalReturns,
    required this.discountsGranted,
    required this.taxableTotal,
    required this.totalTax,
    required this.grandTotal,
    this.totalCashIn = 0.0,
    this.totalCashOut = 0.0,
    this.openingCash,
    required this.paymentSummaries,
  });

  factory ZReportModel.fromJson(Map<String, dynamic> json) {
    return ZReportModel(
      id: json['id'] ?? 0,
      companyId: json['companyId'] ?? 0,
      number: json['number'] ?? 0,
      dateCreated: DateTime.parse(json['dateCreated']),
      fromDocumentId: json['fromDocumentId'] ?? 0,
      toDocumentId: json['toDocumentId'] ?? 0,
      totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0.0,
      totalReturns: (json['totalReturns'] as num?)?.toDouble() ?? 0.0,
      discountsGranted: (json['discountsGranted'] as num?)?.toDouble() ?? 0.0,
      taxableTotal: (json['taxableTotal'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['totalTax'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0.0,
      totalCashIn: (json['totalCashIn'] as num?)?.toDouble() ?? 0.0,
      totalCashOut: (json['totalCashOut'] as num?)?.toDouble() ?? 0.0,
      openingCash: (json['openingCash'] as num?)?.toDouble(),
      paymentSummaries: (json['paymentSummaries'] as List?)
              ?.map((x) => ZReportPaymentSummaryModel.fromJson(x))
              .toList() ??
          [],
    );
  }
}