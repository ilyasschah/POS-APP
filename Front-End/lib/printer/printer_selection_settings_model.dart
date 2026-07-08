class PrinterSelectionSettingsModel {
  final int id;
  final int posPrinterSelectionId;
  final int paperWidth;
  final String? header;
  final String? footer;
  final int feedLines;
  final bool cutPaper;
  final bool printBitmap;
  final bool openCashDrawer;
  final String? cashDrawerCommand;
  final int headerAlignment;
  final int footerAlignment;
  final bool isFormattingEnabled;
  final int printerType;
  final int numberOfCopies;
  final int codePage;
  final int characterSet;
  final int margin;
  final double leftMargin;
  final double topMargin;
  final double rightMargin;
  final double bottomMargin;
  final bool printBarcode;
  final String? fontName;
  final double fontSizePercent;
  final bool printLogoFullWidth;

  const PrinterSelectionSettingsModel({
    required this.id,
    required this.posPrinterSelectionId,
    required this.paperWidth,
    this.header,
    this.footer,
    required this.feedLines,
    required this.cutPaper,
    required this.printBitmap,
    required this.openCashDrawer,
    this.cashDrawerCommand,
    required this.headerAlignment,
    required this.footerAlignment,
    required this.isFormattingEnabled,
    required this.printerType,
    required this.numberOfCopies,
    required this.codePage,
    required this.characterSet,
    required this.margin,
    required this.leftMargin,
    required this.topMargin,
    required this.rightMargin,
    required this.bottomMargin,
    required this.printBarcode,
    this.fontName,
    required this.fontSizePercent,
    required this.printLogoFullWidth,
  });

  factory PrinterSelectionSettingsModel.fromJson(Map<String, dynamic> json) {
    return PrinterSelectionSettingsModel(
      id: json['id'] ?? 0,
      posPrinterSelectionId: json['posPrinterSelectionId'] ?? 0,
      paperWidth: json['paperWidth'] ?? 80,
      header: json['header'],
      footer: json['footer'],
      feedLines: json['feedLines'] ?? 0,
      cutPaper: json['cutPaper'] ?? true,
      printBitmap: json['printBitmap'] ?? false,
      openCashDrawer: json['openCashDrawer'] ?? true,
      cashDrawerCommand: json['cashDrawerCommand'],
      headerAlignment: json['headerAlignment'] ?? 0,
      footerAlignment: json['footerAlignment'] ?? 0,
      isFormattingEnabled: json['isFormattingEnabled'] ?? true,
      printerType: json['printerType'] ?? 0,
      numberOfCopies: json['numberOfCopies'] ?? 1,
      codePage: json['codePage'] ?? -1,
      characterSet: json['characterSet'] ?? -1,
      margin: json['margin'] ?? 0,
      leftMargin: (json['leftMargin'] as num?)?.toDouble() ?? 0.0,
      topMargin: (json['topMargin'] as num?)?.toDouble() ?? 0.0,
      rightMargin: (json['rightMargin'] as num?)?.toDouble() ?? 0.0,
      bottomMargin: (json['bottomMargin'] as num?)?.toDouble() ?? 0.0,
      printBarcode: json['printBarcode'] ?? true,
      fontName: json['fontName'],
      fontSizePercent: (json['fontSizePercent'] as num?)?.toDouble() ?? 100.0,
      printLogoFullWidth: json['printLogoFullWidth'] ?? false,
    );
  }

  PrinterSelectionSettingsModel copyWith({
    int? paperWidth,
    String? header,
    String? footer,
    int? feedLines,
    bool? cutPaper,
    bool? printBitmap,
    bool? openCashDrawer,
    String? cashDrawerCommand,
    int? headerAlignment,
    int? footerAlignment,
    bool? isFormattingEnabled,
    int? printerType,
    int? numberOfCopies,
    int? codePage,
    int? characterSet,
    int? margin,
    double? leftMargin,
    double? topMargin,
    double? rightMargin,
    double? bottomMargin,
    bool? printBarcode,
    String? fontName,
    double? fontSizePercent,
    bool? printLogoFullWidth,
  }) {
    return PrinterSelectionSettingsModel(
      id: id,
      posPrinterSelectionId: posPrinterSelectionId,
      paperWidth: paperWidth ?? this.paperWidth,
      header: header ?? this.header,
      footer: footer ?? this.footer,
      feedLines: feedLines ?? this.feedLines,
      cutPaper: cutPaper ?? this.cutPaper,
      printBitmap: printBitmap ?? this.printBitmap,
      openCashDrawer: openCashDrawer ?? this.openCashDrawer,
      cashDrawerCommand: cashDrawerCommand ?? this.cashDrawerCommand,
      headerAlignment: headerAlignment ?? this.headerAlignment,
      footerAlignment: footerAlignment ?? this.footerAlignment,
      isFormattingEnabled: isFormattingEnabled ?? this.isFormattingEnabled,
      printerType: printerType ?? this.printerType,
      numberOfCopies: numberOfCopies ?? this.numberOfCopies,
      codePage: codePage ?? this.codePage,
      characterSet: characterSet ?? this.characterSet,
      margin: margin ?? this.margin,
      leftMargin: leftMargin ?? this.leftMargin,
      topMargin: topMargin ?? this.topMargin,
      rightMargin: rightMargin ?? this.rightMargin,
      bottomMargin: bottomMargin ?? this.bottomMargin,
      printBarcode: printBarcode ?? this.printBarcode,
      fontName: fontName ?? this.fontName,
      fontSizePercent: fontSizePercent ?? this.fontSizePercent,
      printLogoFullWidth: printLogoFullWidth ?? this.printLogoFullWidth,
    );
  }

  Map<String, dynamic> toQueryParams() {
    return {
      'posPrinterSelectionId': posPrinterSelectionId,
      'paperWidth': paperWidth,
      if (header != null) 'header': header,
      if (footer != null) 'footer': footer,
      'feedLines': feedLines,
      'cutPaper': cutPaper,
      'printBitmap': printBitmap,
      'openCashDrawer': openCashDrawer,
      if (cashDrawerCommand != null) 'cashDrawerCommand': cashDrawerCommand,
      'headerAlignment': headerAlignment,
      'footerAlignment': footerAlignment,
      'isFormattingEnabled': isFormattingEnabled,
      'printerType': printerType,
      'numberOfCopies': numberOfCopies,
      'codePage': codePage,
      'characterSet': characterSet,
      'margin': margin,
      'leftMargin': leftMargin,
      'topMargin': topMargin,
      'rightMargin': rightMargin,
      'bottomMargin': bottomMargin,
      'printBarcode': printBarcode,
      if (fontName != null) 'fontName': fontName,
      'fontSizePercent': fontSizePercent,
      'printLogoFullWidth': printLogoFullWidth,
    };
  }
}
