import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/cart/discount_display.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/printer/pdf_fonts.dart';
import 'package:pos_app/printer/pdf_file_name.dart';
import 'package:pos_app/printer/pdf_save_service.dart';
import 'package:pos_app/printer/printer_platform.dart';
import 'package:pos_app/reports/z_report_model.dart';
import 'package:printing/printing.dart';

class ReceiptPrinterService {
  // ── Settings helpers ──────────────────────────────────────────────────────

  static PdfPageFormat _paperFmt(String? size) =>
      size == '58mm' ? PdfPageFormat.roll57 : PdfPageFormat.roll80;

  static pw.EdgeInsets _margins(Map<String, String> s, String role) {
    double mm(String key) =>
        (double.tryParse(s['$role.$key'] ?? '') ?? 3) * PdfPageFormat.mm;
    return pw.EdgeInsets.only(
      top: mm('MarginTop'),
      bottom: mm('MarginBottom'),
      left: mm('MarginLeft'),
      right: mm('MarginRight'),
    );
  }

  static int _copies(Map<String, String> s, String role) {
    final v = int.tryParse(s['$role.Copies'] ?? '1') ?? 1;
    return v < 1 ? 1 : v;
  }

  static double _fontScale(Map<String, String> s, String role) =>
      (double.tryParse(s['$role.FontSize'] ?? '100') ?? 100) / 100;

  static Future<pw.Font> _font(Map<String, String> s, String role) async {
    switch (s['$role.FontFamily'] ?? '(None)') {
      case 'Courier':
      case 'Monospace':
        return pw.Font.courier();
      case 'Times New Roman':
      case 'Times':
        return pw.Font.times();
      default:
        return await PdfFonts.latin();
    }
  }

  static Future<pw.Font> _fontBold(Map<String, String> s, String role) async {
    switch (s['$role.FontFamily'] ?? '(None)') {
      case 'Courier':
      case 'Monospace':
        return pw.Font.courierBold();
      case 'Times New Roman':
      case 'Times':
        return pw.Font.timesBold();
      default:
        return await PdfFonts.latin(bold: true);
    }
  }

  static bool _flag(Map<String, String> s, String key) =>
      (s[key] ?? 'false').toLowerCase() == 'true';

  /// Merges identical cart lines into one (summing quantity) for the receipt
  /// display. Lines are "identical" only when every per-unit value matches
  /// (product, price, discounts, taxes, unit, comment), so the line math stays
  /// correct. Copies are made so the live cart is never mutated.
  static List<CartItem> _mergeReceiptItems(List<CartItem> items) {
    final map = <String, CartItem>{};
    final order = <String>[];
    for (final it in items) {
      final key = [
        it.productId,
        it.price,
        it.discount,
        it.promotionalDiscount,
        it.measurementUnit ?? '',
        it.comment ?? '',
        it.appliedTaxes.map((t) => t.id).join(','),
      ].join('|');
      final existing = map[key];
      if (existing == null) {
        map[key] = CartItem(
          cartItemId: it.cartItemId,
          posOrderId: it.posOrderId,
          productId: it.productId,
          roundNumber: it.roundNumber,
          quantity: it.quantity,
          price: it.price,
          cost: it.cost,
          discount: it.discount,
          discountType: it.discountType,
          discountInputValue: it.discountInputValue,
          discountInputType: it.discountInputType,
          promotionalDiscount: it.promotionalDiscount,
          promotionId: it.promotionId,
          comment: it.comment,
          bundle: it.bundle,
          isSaved: it.isSaved,
          productName: it.productName,
          appliedTaxes: it.appliedTaxes,
          warehouseId: it.warehouseId,
          measurementUnit: it.measurementUnit,
          isService: it.isService,
        );
        order.add(key);
      } else {
        existing.quantity += it.quantity;
      }
    }
    return [for (final k in order) map[k]!];
  }

  /// Renders a customer address from the configured template, substituting the
  /// %PLACEHOLDER% tokens with the customer's fields. Falls back to the plain
  /// `address` field when the template is empty or yields nothing. Newlines are
  /// collapsed to ", " so it fits on a single receipt line.
  static String _formatCustomerAddress(Customer c, String? template) {
    final tpl = (template ?? '').trim();
    final out = tpl.isEmpty
        ? (c.address ?? '')
        : tpl
            .replaceAll('%STREET_NAME%', c.streetName ?? '')
            .replaceAll('%ADDITIONAL_STREET_NAME%', c.additionalStreetName ?? '')
            .replaceAll('%BUILDING_NUMBER%', c.buildingNumber ?? '')
            .replaceAll('%PLOT_IDENTIFICATION%', c.plotIdentification ?? '')
            .replaceAll('%CITY_SUBDIVISION%', c.citySubdivisionName ?? '')
            .replaceAll('%CITY%', c.city ?? '')
            .replaceAll('%POSTAL_CODE%', c.postalCode ?? '');
    final joined = out
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.replaceAll(RegExp(r'[\s,]+'), '').isNotEmpty)
        .join(', ');
    // Template produced nothing (customer only has the plain address field).
    if (joined.isEmpty && (c.address?.trim().isNotEmpty ?? false)) {
      return c.address!.trim();
    }
    return joined;
  }

  // ── Print dispatcher ──────────────────────────────────────────────────────

  static Future<void> _dispatch(
    pw.Document pdf,
    String name,
    int copies,
    String? printerName,
  ) async {
    final bytes = await pdf.save();
    Printer? target;
    // Gated: on Android `listPrinters()` has no implementation and throws, so
    // this used to run — and silently fail — on every single print. The saved
    // printer name there is a Windows queue inherited through the (formerly
    // cloud-synced) setting anyway, so there is nothing it could ever match.
    if (PrinterPlatform.canPrintSilently &&
        printerName != null &&
        printerName.isNotEmpty) {
      try {
        final printers = await Printing.listPrinters();
        target = printers.where((p) => p.name == printerName).firstOrNull;
      } catch (_) {}
    }
    for (var i = 0; i < copies; i++) {
      if (target != null) {
        await Printing.directPrintPdf(
          printer: target,
          onLayout: (_) async => bytes,
          name: name,
        );
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      }
    }
  }

  // ── Shared row builder ────────────────────────────────────────────────────

  static pw.Widget _row(
    String label,
    String value, {
    bool bold = false,
    double fontSize = 10,
    double fontScale = 1.0,
    pw.Font? font,
    pw.Font? boldFont,
    bool rtl = false,
  }) {
    final size = fontSize * fontScale;
    final activeFont = bold ? (boldFont ?? font) : font;
    final style = pw.TextStyle(
      font: activeFont,
      fontWeight: bold ? pw.FontWeight.bold : null,
      fontSize: size,
    );
    final dir = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final labelW = pw.Text(label, style: style, textDirection: dir);
    final valueW = pw.Text(value, style: style, textDirection: dir);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: rtl ? [valueW, labelW] : [labelW, valueW],
      ),
    );
  }

  static String _fmtDateTime(DateTime dt) {
    final d =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    return '$d ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── Receipt / Guest Check ─────────────────────────────────────────────────

  Future<void> printCartReceipt({
    required Company company,
    required User? cashier,
    Customer? customer,
    required String orderNumber,
    /// The banked sale's document number, when this receipt is for one. Drives
    /// the PDF file name only — a document is a permanent, uniquely-numbered
    /// record, so it names itself; an order (guest check, not yet banked) has
    /// only its name + the print time. Null for anything not yet a document.
    String? documentNumber,
    required DateTime printTime,
    required List<CartItem> items,
    required double subtotal,
    required double totalDiscount,
    required double totalTax,
    required double grandTotal,
    required String currencySymbol,
    // Itemized discount breakdown (manual item/cart, promotion, customer). When
    // non-empty each line is printed instead of the single merged "Discount:"
    // row. Loyalty points are shown separately (Points Used), so the caller
    // excludes them from this list.
    List<ReceiptDiscountLine> discountLines = const [],
    String? paymentTypeName,
    double? amountPaid,
    Uint8List? logoBytes,
    Map<String, String> roleSettings = const {},
    // Settings-key prefix for this printer's HARDWARE keys (PaperSize, Margins,
    // Header/Footer, Font, RightToLeft, PrinterName…). Defaults to 'Receipt';
    // the demo test print passes a specific printer's prefix so the preview
    // reflects that exact printer. Receipt *content* keys (tax/customer/labels)
    // stay global.
    String role = 'Receipt',
    bool isGuestCheck = false,
    /// Write the receipt to a file the operator picks (with the name pre-filled)
    /// instead of sending it to a printer. Same bytes either way.
    bool saveToFile = false,
    // Loyalty
    double pointsUsed = 0,
    double pointsEarned = 0,
    double pointsBalance = 0,
    double pointValue = 1.0,
  }) async {
    // Print item prices tax-inclusive when the shop is configured that way
    // (matches the cart + payment screen). Tax base follows the discount rule.
    final taxIncluded =
        roleSettings[SettingKeys.displayAndPrintTaxIncluded]?.toLowerCase() !=
        'false';
    final discountBeforeTax =
        roleSettings[SettingKeys.discountApplyRule] == 'Before tax';
    final fmt = _paperFmt(roleSettings['$role.PaperSize']);
    final margins = _margins(roleSettings, role);
    final copies = _copies(roleSettings, role);
    final fontScale = _fontScale(roleSettings, role);
    final font = await _font(roleSettings, role);
    final boldFont = await _fontBold(roleSettings, role);
    final arabicRegular = await PdfFonts.arabic();
    final arabicBold = await PdfFonts.arabic(bold: true);
    final rtl = _flag(roleSettings, '$role.RightToLeft');
    final logoFull = _flag(roleSettings, '$role.LogoFullWidth');
    final showBarcode = _flag(roleSettings, '$role.PrintBarcode');
    final printerName = roleSettings['$role.PrinterName'];

    // Receipt content toggles. The default-ON ones treat a missing key as 'show'
    // (so an un-synced install isn't unexpectedly blanked); the measurement-unit
    // toggle defaults OFF, matching kSettingDefaults.
    bool onToggle(String key) =>
        (roleSettings[key] ?? 'true').toLowerCase() != 'false';
    final printOrderNumber = onToggle(SettingKeys.receiptPrintOrderNumber);
    final printTaxTotals = onToggle(SettingKeys.receiptPrintTaxTotals);
    final printItemsCount = onToggle(SettingKeys.receiptPrintItemsCount);
    final printUnit = _flag(roleSettings, SettingKeys.receiptPrintMeasurementUnit);

    // Customer detail toggles (all default OFF, matching kSettingDefaults).
    final showCustName = _flag(roleSettings, SettingKeys.receiptCustomerName);
    final showCustCode = _flag(roleSettings, SettingKeys.receiptCustomerCode);
    final showCustTax = _flag(roleSettings, SettingKeys.receiptCustomerTaxNumber);
    final showCustPhone = _flag(roleSettings, SettingKeys.receiptCustomerPhone);
    final showCustEmail = _flag(roleSettings, SettingKeys.receiptCustomerEmail);
    final showCustAddr = _flag(roleSettings, SettingKeys.receiptCustomerAddress);

    final printLargeOrderNo =
        _flag(roleSettings, SettingKeys.printLargeOrderNumberInReceipt); // default OFF
    final printBalance =
        _flag(roleSettings, SettingKeys.receiptPrintOutstandingBalance); // default OFF
    final printTotalQty = onToggle(SettingKeys.receiptPrintTotalQuantity); // default ON
    final printTaxName = onToggle(SettingKeys.receiptPrintTaxName); // default ON

    // Company header block, printed under the logo/name. All default ON so
    // existing receipts are unchanged; toggle in Printer Settings → Customize.
    final showCompanyTax = onToggle(SettingKeys.receiptShowCompanyTaxNumber);
    final showCompanyAddress = onToggle(SettingKeys.receiptShowCompanyAddress);
    final showCompanyPhone = onToggle(SettingKeys.receiptShowCompanyPhone);

    // Per-tax breakdown for Receipt.PrintTaxName: sum each named tax over items
    // (mirrors the per-line tax math used below).
    final taxByName = <String, double>{};
    if (printTaxName) {
      for (final item in items) {
        final unitNet = item.price - item.discount - item.promotionalDiscount;
        final taxBase =
            (discountBeforeTax ? unitNet : item.price) * item.quantity;
        for (final t in item.appliedTaxes) {
          final amt =
              t.isFixed ? t.rate * item.quantity : taxBase * (t.rate / 100);
          taxByName[t.name] = (taxByName[t.name] ?? 0) + amt;
        }
      }
    }

    // Dual currency — same three keys the cart totals panel reads, so the
    // receipt and the on-screen "≈ …" line always agree.
    final dualEnabled =
        roleSettings[SettingKeys.dualCurrencyEnabled]?.toLowerCase() == 'true';
    final dualSym = roleSettings[SettingKeys.dualCurrencySymbol] ?? '€';
    final dualRate =
        double.tryParse(roleSettings[SettingKeys.dualCurrencyRate] ?? '1.0') ??
            1.0;

    // Outstanding balance for Receipt.PrintOutstandingBalance.
    final owedAmount =
        (grandTotal - pointsUsed * pointValue).clamp(0.0, double.infinity);
    final balanceDue =
        (owedAmount - (amountPaid ?? owedAmount)).clamp(0.0, double.infinity);

    // Receipt.MergeItems: collapse identical lines into one (summing qty). Totals
    // are unaffected — this only changes the per-line DISPLAY.
    final mergeItems = onToggle(SettingKeys.mergeItemsOnReceipt); // default ON
    final renderItems = mergeItems ? _mergeReceiptItems(items) : items;

    final headerText = (roleSettings['$role.Header'] ?? '').isNotEmpty
        ? roleSettings['$role.Header']!
        : company.name;
    // Footer is exactly what the operator configured (Printer Settings → Footer).
    // No hardcoded default — an empty footer simply prints nothing.
    final footerText = roleSettings['$role.Footer'] ?? '';

    pw.TextStyle ts(double size, {bool bold = false}) => pw.TextStyle(
      font: bold ? boldFont : font,
      fontFallback: [bold ? arabicBold : arabicRegular],
      fontWeight: bold ? pw.FontWeight.bold : null,
      fontSize: size * fontScale,
    );

    final dir = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    pw.Widget center(String text, {double size = 10, bool bold = false}) =>
        pw.Center(
          child: pw.Text(
            text,
            style: ts(size, bold: bold),
            textAlign: pw.TextAlign.center,
            textDirection: dir,
          ),
        );

    final itemCount = items.fold<double>(0, (s, i) => s + i.quantity);
    final itemCountStr = itemCount % 1 == 0
        ? itemCount.toInt().toString()
        : itemCount.toStringAsFixed(2);

    // Localize Text: each label falls back to its current wording, so any label
    // the operator hasn't customised keeps the receipt exactly as before. The
    // master toggle (default ON) lets the operator switch back to the built-in
    // wording without clearing every field.
    final useCustomLabels =
        (roleSettings[SettingKeys.receiptUseCustomLabels] ?? 'true')
                .toLowerCase() !=
            'false';
    String lbl(String key, String fallback) {
      if (!useCustomLabels) return fallback;
      final v = roleSettings[key]?.trim();
      return (v != null && v.isNotEmpty) ? v : fallback;
    }

    // Short receipt number: print only the trailing counter segment.
    final shortNumber = _flag(roleSettings, SettingKeys.receiptShortNumber);
    String shortNo(String n) {
      if (!shortNumber) return n;
      if (n.contains('#')) return n.split('#').last.trim();
      if (n.contains('-')) return n.split('-').last.trim();
      return n;
    }

    // Money formatting honours Receipt.DecimalPlaces (default 2).
    final decimals =
        (int.tryParse(roleSettings[SettingKeys.receiptDecimalPlaces] ?? '2') ?? 2)
            .clamp(0, 6);
    String money(double v) => v.toStringAsFixed(decimals);

    pw.Widget rowW(
      String l,
      String v, {
      bool bold = false,
      double fontSize = 10,
    }) => _row(
      l,
      v,
      bold: bold,
      fontSize: fontSize,
      fontScale: fontScale,
      font: font,
      boldFont: boldFont,
      rtl: rtl,
    );

    // Optional customer block — each line gated by its receiptCustomer* toggle,
    // shown only when a customer is attached and the field has a value.
    List<pw.Widget> customerBlock() {
      final c = customer;
      if (c == null) return const [];
      final rows = <pw.Widget>[];
      void add(bool on, String label, String? val) {
        if (on && (val?.trim().isNotEmpty ?? false)) {
          rows.add(rowW('$label:', val!.trim()));
        }
      }

      add(showCustName, lbl(SettingKeys.labelCustomer, 'Customer'), c.name);
      add(showCustCode, lbl(SettingKeys.labelCustomerCode, 'Code'), c.code);
      add(showCustTax, lbl(SettingKeys.labelCompanyTaxNumber, 'Tax No'),
          c.taxNumber);
      add(showCustPhone, lbl(SettingKeys.labelCustomerPhone, 'Phone'),
          c.phoneNumber);
      add(showCustEmail, lbl(SettingKeys.labelCustomerEmail, 'Email'), c.email);
      if (showCustAddr) {
        add(true, lbl(SettingKeys.labelCustomerAddress, 'Address'),
            _formatCustomerAddress(c, roleSettings[SettingKeys.receiptAddressFormat]));
      }
      if (rows.isEmpty) return const [];
      return [
        ...rows,
        pw.SizedBox(height: 4),
        pw.Divider(borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 6),
      ];
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: fmt,
        margin: margins,
        build: (_) => pw.Column(
          crossAxisAlignment: rtl
              ? pw.CrossAxisAlignment.end
              : pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            // ── Logo ───────────────────────────────────────────────────────
            if (logoBytes != null) ...[
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(logoBytes),
                  width: logoFull ? double.infinity : 80,
                  height: logoFull ? 80 : 60,
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(height: 6),
            ],

            // ── Header ─────────────────────────────────────────────────────
            center(headerText, size: 16, bold: true),
            if (showCompanyTax && company.taxNumber?.isNotEmpty == true)
              center('${lbl(SettingKeys.labelCompanyTaxNumber, 'Tax No')}: ${company.taxNumber}', size: 9),
            if (showCompanyAddress && company.address?.isNotEmpty == true)
              center(company.address!, size: 9),
            if (showCompanyPhone && company.phoneNumber?.isNotEmpty == true)
              center('${lbl(SettingKeys.labelCompanyPhone, 'Tel')}: ${company.phoneNumber}', size: 9),
            pw.SizedBox(height: 6),
            pw.Divider(borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 4),

            // ── Guest check banner ─────────────────────────────────────────
            if (isGuestCheck) ...[
              center('*** GUEST CHECK ***', size: 13, bold: true),
              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
            ],

            // ── Large order number (optional) ──────────────────────────────
            if (printLargeOrderNo) ...[
              pw.Center(
                child: pw.Text(
                  orderNumber.contains('#')
                      ? orderNumber.split('#').last.trim()
                      : orderNumber,
                  style: ts(28, bold: true),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
            ],

            // ── Transaction info ───────────────────────────────────────────
            if (printOrderNumber)
              rowW('${lbl(SettingKeys.labelReceiptNumber, 'Receipt')}:',
                  shortNo(orderNumber)),
            rowW('Date:', _fmtDateTime(printTime)),
            if (cashier != null)
              rowW('${lbl(SettingKeys.labelUser, 'Cashier')}:',
                  cashier.displayName),
            pw.SizedBox(height: 4),
            pw.Divider(borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 6),

            ...customerBlock(),

            // ── Items ──────────────────────────────────────────────────────
            ...renderItems.map((item) {
              final qty = item.quantity % 1 == 0
                  ? item.quantity.toInt().toString()
                  : item.quantity.toStringAsFixed(2);
              final unitNet =
                  item.price - item.discount - item.promotionalDiscount;
              final taxBase =
                  (discountBeforeTax ? unitNet : item.price) * item.quantity;
              final lineTax = item.appliedTaxes.fold<double>(
                0,
                (s, t) =>
                    s +
                    (t.isFixed
                        ? t.rate * item.quantity
                        : taxBase * (t.rate / 100)),
              );
              // Tax-inclusive line/unit when configured (mirrors cart + screen).
              final unitPrice = taxIncluded && item.quantity > 0
                  ? unitNet + lineTax / item.quantity
                  : unitNet;
              final lineTotal = taxIncluded
                  ? unitNet * item.quantity + lineTax
                  : unitNet * item.quantity;
              final nameW = pw.Text(
                item.productName,
                style: ts(11, bold: true),
                textDirection: dir,
              );

              // 1. Safely grab the unit (when the toggle is on). If it exists,
              //    add a space before it (e.g. " Kg").
              final unit =
                  (printUnit &&
                      item.measurementUnit != null &&
                      item.measurementUnit!.trim().isNotEmpty)
                  ? ' ${item.measurementUnit!.trim()}'
                  : '';

              // 2. Inject $unit right after $qty. The currency remains dynamic!
              final qtyPriceW = pw.Text(
                '${rtl ? '' : '  '}$qty$unit x ${money(unitPrice)} $currencySymbol',
                style: ts(10),
                textDirection: dir,
              );
              final lineTotalW = pw.Text(
                '${money(lineTotal)} $currencySymbol',
                style: ts(10),
                textDirection: dir,
              );
              return pw.Column(
                crossAxisAlignment: rtl
                    ? pw.CrossAxisAlignment.end
                    : pw.CrossAxisAlignment.start,
                children: [
                  nameW,
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: rtl
                        ? [lineTotalW, qtyPriceW]
                        : [qtyPriceW, lineTotalW],
                  ),
                  pw.SizedBox(height: 3),
                ],
              );
            }),

            pw.Divider(borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 4),

            // ── Totals ─────────────────────────────────────────────────────
            rowW('${lbl(SettingKeys.labelSubtotal, 'Subtotal')}:',
                '${money(subtotal)} $currencySymbol'),
            // Itemized discounts when available; otherwise the single merged row.
            if (discountLines.isNotEmpty)
              ...discountLines.map(
                (d) => rowW(
                  d.hint == null ? '${d.label}:' : '${d.label} (${d.hint}):',
                  '-${money(d.amount)} $currencySymbol',
                ),
              )
            else if (totalDiscount > 0)
              rowW(
                '${lbl(SettingKeys.labelDiscount, 'Discount')}:',
                '-${money(totalDiscount)} $currencySymbol',
              ),
            if (totalTax > 0 && printTaxTotals)
              if (printTaxName && taxByName.isNotEmpty)
                ...taxByName.entries.map(
                  (e) => rowW('${e.key}:', '${money(e.value)} $currencySymbol'),
                )
              else
                rowW('${lbl(SettingKeys.labelTaxRate, 'Tax')}:',
                    '${money(totalTax)} $currencySymbol'),
            pw.SizedBox(height: 4),
            pw.Divider(),
            pw.SizedBox(height: 4),
            rowW(
              '${lbl(SettingKeys.labelTotal, 'GRAND TOTAL')}:',
              '${money(grandTotal)} $currencySymbol',
              bold: true,
              fontSize: 13,
            ),
            if (pointsUsed > 0) ...[
              pw.SizedBox(height: 2),
              rowW(
                'Points Used:',
                '-${money(pointsUsed * pointValue)} $currencySymbol'
                    ' (${pointsUsed.toInt()} pts)',
              ),
              // The actual amount owed once points are applied — otherwise the
              // receipt printed GRAND TOTAL but the cashier collected less.
              rowW(
                '${lbl(SettingKeys.labelAmountDue, 'To Pay')}:',
                '${money((grandTotal - pointsUsed * pointValue).clamp(0.0, double.infinity))} $currencySymbol',
                bold: true,
              ),
            ],
            // Dual currency — mirrors the cart's "≈ 12.34 €" line. Converts the
            // amount actually owed (points already deducted), not grandTotal,
            // so the printed conversion matches what the customer pays.
            if (dualEnabled)
              rowW(
                '',
                '≈ ${money(owedAmount * dualRate)} $dualSym',
              ),
            pw.Divider(),
            pw.SizedBox(height: 6),

            // ── Payment ────────────────────────────────────────────────────
            if (!isGuestCheck && paymentTypeName != null) ...[
              rowW(
                '$paymentTypeName:',
                '${money(amountPaid ?? grandTotal)} $currencySymbol',
              ),
              // Change due, so the receipt is self-explanatory at the till.
              if (amountPaid != null &&
                  amountPaid >
                      (grandTotal - pointsUsed * pointValue).clamp(
                        0.0,
                        double.infinity,
                      ))
                rowW(
                  '${lbl(SettingKeys.labelChange, 'Change')}:',
                  '${money(amountPaid - (grandTotal - pointsUsed * pointValue).clamp(0.0, double.infinity))} $currencySymbol',
                ),
            ],
            // Outstanding balance — always printed when the customer still owes
            // money (a credit / partial payment), so a credit receipt clearly
            // states what is due. `receiptPrintOutstandingBalance` additionally
            // forces the row even when the sale is fully settled (balance 0).
            if (balanceDue > 0.005 || printBalance)
              rowW(
                  '${lbl(SettingKeys.labelOutstandingBalance, 'Balance Due')}:',
                  '${money(balanceDue)} $currencySymbol',
                  bold: true),
            if (printItemsCount)
              rowW('${lbl(SettingKeys.labelItemsCount, 'Items')}:',
                  renderItems.length.toString()),
            if (printTotalQty) rowW('Total Qty:', itemCountStr),
            if (!isGuestCheck && pointsEarned > 0)
              rowW('Points Earned:', '+${pointsEarned.toInt()} pts'),
            if (!isGuestCheck && (pointsEarned > 0 || pointsUsed > 0))
              rowW('Points Balance:', '${pointsBalance.toInt()} pts'),
            pw.SizedBox(height: 10),
            pw.Divider(borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 6),

            // ── Footer ─────────────────────────────────────────────────────
            if (footerText.isNotEmpty) center(footerText, size: 9),

            // ── Barcode ────────────────────────────────────────────────────
            if (showBarcode && !isGuestCheck) ...[
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: orderNumber,
                  width: 120,
                  height: 35,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // A guest check is always an order — it prints before the sale is banked,
    // so it never has a document number even when the caller knows one.
    final name = (!isGuestCheck && (documentNumber?.trim().isNotEmpty ?? false))
        ? documentPdfName(documentNumber!)
        : orderPdfName(orderNumber, printTime);

    if (saveToFile) {
      await savePdfAs(
        bytes: await pdf.save(),
        suggestedName: name,
        dialogTitle: isGuestCheck ? 'Save Guest Check' : 'Save Receipt',
      );
      return;
    }
    await _dispatch(pdf, name, copies, printerName);
  }

  // ── Kitchen Ticket ────────────────────────────────────────────────────────

  Future<void> printKitchenTicket({
    required String orderNumber,
    required String cashierName,
    required String serviceType,
    /// The table this order is seated at, when it has one.
    ///
    /// 🚨 Printed on its own line. It used to reach the kitchen ONLY by accident,
    /// embedded in `orderNumber` ("ORD- Table 1") — so any change to the order
    /// naming scheme silently stopped telling the kitchen where to take the
    /// food, with nothing failing anywhere. Null for takeaway/delivery.
    String? tableName,
    required DateTime printTime,
    required List<CartItem> items,
    List<List<String>> itemComments = const [],
    Map<String, String> roleSettings = const {},
    // Settings-key prefix for the target printer's hardware keys. Defaults to
    // 'Kitchen'; group routing passes a specific station printer's prefix.
    String role = 'Kitchen',
  }) async {
    final fmt = _paperFmt(roleSettings['$role.PaperSize']);
    final margins = _margins(roleSettings, role);
    final copies = _copies(roleSettings, role);
    final fontScale = _fontScale(roleSettings, role);
    final font = await _font(roleSettings, role);
    final boldFont = await _fontBold(roleSettings, role);
    final arabicRegular = await PdfFonts.arabic();
    final arabicBold = await PdfFonts.arabic(bold: true);
    final printerName = roleSettings['$role.PrinterName'];

    pw.TextStyle ts(double size, {bool bold = false, bool italic = false}) =>
        pw.TextStyle(
          font: bold ? boldFont : font,
          fontFallback: [bold ? arabicBold : arabicRegular],
          fontWeight: bold ? pw.FontWeight.bold : null,
          fontStyle: italic ? pw.FontStyle.italic : null,
          fontSize: size * fontScale,
        );

    // Show just the counter portion (e.g. "005") large at the top.
    final ticketNum = orderNumber.contains('#')
        ? orderNumber.split('#').last.trim()
        : orderNumber;

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: fmt,
        margin: margins,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            // ── Big order number ──────────────────────────────────────
            pw.Center(child: pw.Text(ticketNum, style: ts(40, bold: true))),
            pw.SizedBox(height: 4),
            pw.Divider(borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 4),

            // ── Meta info ─────────────────────────────────────────────
            // `Round:` was removed here — nothing in the app ever incremented
            // CartItem.roundNumber, so it printed a constant "1" on every
            // ticket and told the kitchen nothing. Reinstate it only alongside
            // real course tracking.
            pw.Text('User: $cashierName', style: ts(10)),
            pw.Text('Order: $orderNumber', style: ts(10)),
            pw.Text('Time: ${_fmtDateTime(printTime)}', style: ts(10)),
            pw.SizedBox(height: 6),

            // ── Table + service type ──────────────────────────────────
            // The table is the single most operationally useful line on a
            // dine-in ticket, so it gets the larger type; omitted entirely when
            // the order has no table (takeaway/delivery) rather than printing
            // an empty label.
            if (tableName != null && tableName.trim().isNotEmpty) ...[
              pw.Center(
                child: pw.Text(tableName.trim(), style: ts(18, bold: true)),
              ),
              pw.SizedBox(height: 2),
            ],
            pw.Center(child: pw.Text(serviceType, style: ts(13, bold: true))),
            pw.SizedBox(height: 6),
            pw.Divider(borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 8),

            // ── Items ─────────────────────────────────────────────────
            ...List.generate(items.length, (i) {
              final item = items[i];
              final qty = item.quantity % 1 == 0
                  ? item.quantity.toInt().toString()
                  : item.quantity.toStringAsFixed(2);

              // Gather all comment lines for this item:
              // 1. CartItem.comment split by newline (supports multi-line selections)
              // 2. Extra structured comments from the caller's itemComments list
              final commentLines = <String>[
                if (item.comment?.isNotEmpty == true)
                  ...item.comment!
                      .split('\n')
                      .where((l) => l.trim().isNotEmpty),
                if (i < itemComments.length) ...itemComments[i],
              ];

              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '$qty x ${item.productName}',
                      style: ts(16, bold: true),
                    ),
                    ...commentLines.map(
                      (c) => pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 12, top: 2),
                        child: pw.Text(c, style: ts(10, italic: true)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );

    // Always an order — a kitchen ticket prints long before the sale is banked.
    await _dispatch(
        pdf, orderPdfName(orderNumber, printTime), copies, printerName);
  }

  // ── Z-Report ──────────────────────────────────────────────────────────────

  Future<void> printZReport(
    ZReportModel report,
    String currencySymbol, {
    required Map<String, String> roleSettings,
  }) async {
    final font = await PdfFonts.latin();
    final boldFont = await PdfFonts.latin(bold: true);
    final arabicRegular = await PdfFonts.arabic();
    final arabicBold = await PdfFonts.arabic(bold: true);
    final pdf = pw.Document();

    // Standard 80mm thermal receipt format
    const format = PdfPageFormat.roll80;

    pw.TextStyle ts(double size, {bool bold = false}) => pw.TextStyle(
      font: bold ? boldFont : font,
      fontFallback: [bold ? arabicBold : arabicRegular],
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontSize: size,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'Z-REPORT',
                textAlign: pw.TextAlign.center,
                style: ts(16, bold: true),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Report #${report.number}',
                textAlign: pw.TextAlign.center,
                style: ts(12),
              ),
              pw.Text(
                'Date: ${report.dateCreated.toIso8601String().split('T').first}'
                '  Time: ${report.dateCreated.toIso8601String().split('T').last.split('.').first}',
                textAlign: pw.TextAlign.center,
                style: ts(10),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),

              pw.Text(
                'SHIFT SUMMARY',
                textAlign: pw.TextAlign.center,
                style: ts(12, bold: true),
              ),
              pw.SizedBox(height: 8),
              _buildReceiptRow(
                'Documents:',
                report.documentCount?.toString() ?? '-',
                font: font,
                boldFont: boldFont,
              ),
              if (report.fromDocumentNumber != null)
                _buildReceiptRow(
                  'Range:',
                  report.fromDocumentNumber == report.toDocumentNumber
                      ? report.fromDocumentNumber!
                      : '${report.fromDocumentNumber} - ${report.toDocumentNumber}',
                  font: font,
                  boldFont: boldFont,
                ),
              _buildReceiptRow(
                'Cash in:',
                '${report.totalCashIn.toStringAsFixed(2)} $currencySymbol',
                font: font,
                boldFont: boldFont,
              ),
              _buildReceiptRow(
                'Cash out:',
                '-${report.totalCashOut.toStringAsFixed(2)} $currencySymbol',
                font: font,
                boldFont: boldFont,
              ),
              pw.SizedBox(height: 4),
              _buildReceiptRow(
                'Total Sales:',
                '${report.totalSales.toStringAsFixed(2)} $currencySymbol',
                font: font,
                boldFont: boldFont,
              ),
              _buildReceiptRow(
                'Total Returns:',
                '${report.totalReturns.toStringAsFixed(2)} $currencySymbol',
                font: font,
                boldFont: boldFont,
              ),
              _buildReceiptRow(
                'Discounts:',
                '${report.discountsGranted.toStringAsFixed(2)} $currencySymbol',
                font: font,
                boldFont: boldFont,
              ),
              _buildReceiptRow(
                'Taxable Total:',
                '${report.taxableTotal.toStringAsFixed(2)} $currencySymbol',
                font: font,
                boldFont: boldFont,
              ),
              _buildReceiptRow(
                'Total Tax:',
                '${report.totalTax.toStringAsFixed(2)} $currencySymbol',
                font: font,
                boldFont: boldFont,
              ),

              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),

              pw.Text(
                'TENDER TYPES',
                textAlign: pw.TextAlign.center,
                style: ts(12, bold: true),
              ),
              pw.SizedBox(height: 8),
              if (report.paymentSummaries.isEmpty)
                pw.Text(
                  'No payments recorded.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: font,
                    fontStyle: pw.FontStyle.italic,
                    fontSize: 10,
                  ),
                )
              else
                ...report.paymentSummaries.map(
                  (p) => _buildReceiptRow(
                    p.paymentTypeName ?? 'Unknown',
                    '${p.totalAmount.toStringAsFixed(2)} $currencySymbol',
                    font: font,
                    boldFont: boldFont,
                  ),
                ),

              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),

              _buildReceiptRow(
                'GRAND TOTAL:',
                '${report.grandTotal.toStringAsFixed(2)} $currencySymbol',
                isBold: true,
                size: 14,
                font: font,
                boldFont: boldFont,
              ),

              pw.SizedBox(height: 24),
              pw.Text(
                '*** END OF REPORT ***',
                textAlign: pw.TextAlign.center,
                style: ts(10),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Z_Report_${report.number}',
    );
  }

  pw.Widget _buildReceiptRow(
    String label,
    String value, {
    bool isBold = false,
    double size = 10,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    final style = pw.TextStyle(
      font: isBold ? boldFont : font,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontSize: size,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}
