class PrinterSelectionModel {
  final int id;
  final String key;
  final String? printerName;
  final bool isEnabled;

  const PrinterSelectionModel({
    required this.id,
    required this.key,
    this.printerName,
    required this.isEnabled,
  });

  factory PrinterSelectionModel.fromJson(Map<String, dynamic> json) {
    return PrinterSelectionModel(
      id: json['id'] ?? 0,
      key: json['key'] ?? '',
      printerName: json['printerName'],
      isEnabled: json['isEnabled'] ?? false,
    );
  }

  PrinterSelectionModel copyWith({
    String? key,
    String? printerName,
    bool? isEnabled,
  }) {
    return PrinterSelectionModel(
      id: id,
      key: key ?? this.key,
      printerName: printerName ?? this.printerName,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
