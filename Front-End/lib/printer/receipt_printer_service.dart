import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/uom/unit_of_measure.dart';
import 'package:pos_app/cart/discount_display.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/l10n/app_locale.dart';
import 'package:pos_app/modifier/modifier_models.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/printer/pdf_fonts.dart';
import 'package:pos_app/printer/pdf_file_name.dart';
import 'package:pos_app/printer/printed_text.dart';
import 'package:pos_app/printer/pdf_save_service.dart';
import 'package:pos_app/printer/printer_platform.dart';
import 'package:pos_app/reports/z_report_model.dart';
import 'package:printing/printing.dart';

/// Which wording a receipt label prints in: the operator's own, or the app's
/// translation of the shipped default.
///
/// 🚨 The `== shippedDefault` test is the whole point, and without it the
/// feature does nothing. Receipt labels are SETTINGS with English values in
/// `kSettingDefaults` ('Cashier', 'Items', 'Balance Due'…), and those defaults
/// are seeded into `app_properties` on every install — so [stored] is almost
/// never empty. A plain "use the stored value, else the translation" rule would
/// therefore leave every receipt in English forever, on every terminal.
///
/// A value still equal to the shipped default is not a choice anybody made; it
/// is what seeding put there, so the translation wins. A value the operator
/// actually typed is theirs and is printed verbatim — including when it happens
/// to be English on an Arabic till, which is a legitimate thing to want.
///
/// [useCustomLabels] is the master toggle (`Receipt.UseCustomLabels`, default
/// on): off means "ignore my wording", which now yields the TRANSLATED built-in
/// wording rather than the English one.
String resolveReceiptLabel({
  required String? stored,
  required String? shippedDefault,
  required String localized,
  required bool useCustomLabels,
}) {
  if (!useCustomLabels) return localized;
  final v = stored?.trim();
  if (v == null || v.isEmpty) return localized;
  if (v == shippedDefault?.trim()) return localized;
  return v;
}

class ReceiptPrinterService {
  // ── Settings helpers ──────────────────────────────────────────────────────

  /// Strings for the printed document, in the company's selected language.
  ///
  /// Resolved from the settings map every caller already passes (they all hand
  /// over the whole `appSettingsProvider` map), so nothing has to be threaded
  /// through six call sites — and a caller that forgets cannot silently fall
  /// back to English for everything.
  ///
  /// `lookupAppLocalizations` is synchronous and needs no BuildContext, which
  /// matters: printing happens from services and fire-and-forget callbacks that
  /// have no widget tree to read from.
  static AppLocalizations _l10n(Map<String, String> s) =>
      lookupAppLocalizations(resolveAppLocale(s[SettingKeys.language]));

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
  /// (product, price, discounts, taxes, unit, comment, MODIFIERS), so the line
  /// math stays correct. Copies are made so the live cart is never mutated.
  ///
  /// 🚨 The modifier selection is part of the key. Without it a plain burger
  /// and a burger with Extra Cheese collapse into "2 x Burger" — one printed
  /// line for two different things the kitchen has to make differently.
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
        modifierSelectionKey(it.selectedModifiers),
      ].join('|');
      final existing = map[key];
      if (existing == null) {
        map[key] = CartItem(
          cartItemId: it.cartItemId,
          posOrderId: it.posOrderId,
          productId: it.productId,
          roundNumber: it.roundNumber,
          quantity: it.quantity,
          uomId: it.uomId,
          isToWeigh: it.isToWeigh,
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
          // Merged rows must keep the tax mode, or the printed line reverts to
          // the `true` default and an exclusive product prints the wrong total.
          isTaxInclusive: it.isTaxInclusive,
          // 🚨 And the choices. A copy that drops them prints a plain burger
          // for a line the cart, the kitchen and the customer all agree has
          // Extra Cheese on it — and whose price already includes it.
          selectedModifiers: it.selectedModifiers,
          basePrice: it.basePrice,
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

  /// Every text style on a printed document, built in ONE place.
  ///
  /// 🚨 `fontFallback` is the whole reason this exists. None of the Latin faces
  /// carry Arabic glyphs, so a style that omits the fallback prints Arabic as
  /// **solid black boxes** — and only on paper, which is where it was found
  /// (2026-08-16, first Arabic receipt): the company header rendered correctly
  /// because it went through the page's `ts()`, while every label row went
  /// through a second, hand-rolled `TextStyle` that had no fallback. Two ways to
  /// build a style is what let one of them rot. Build styles here, or the next
  /// widget added to a receipt reintroduces the same invisible bug.
  static pw.TextStyle printedTextStyle({
    required pw.Font? font,
    required pw.Font? arabic,
    pw.Font? boldFont,
    pw.Font? arabicBold,
    bool bold = false,
    bool italic = false,
    double size = 10,
  }) {
    final fallback = bold ? (arabicBold ?? arabic) : arabic;
    return pw.TextStyle(
      font: bold ? (boldFont ?? font) : font,
      fontFallback: [if (fallback != null) fallback],
      fontWeight: bold ? pw.FontWeight.bold : null,
      fontStyle: italic ? pw.FontStyle.italic : null,
      fontSize: size,
    );
  }

  static pw.Widget _row(
    String label,
    String value, {
    bool bold = false,
    double fontSize = 10,
    double fontScale = 1.0,
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? arabic,
    pw.Font? arabicBold,
    bool rtl = false,
  }) {
    final size = fontSize * fontScale;
    final style = printedTextStyle(
      font: font,
      boldFont: boldFont,
      arabic: arabic,
      arabicBold: arabicBold,
      bold: bold,
      size: size,
    );
    final dir = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    // 🚨 FLEXIBLE, not Expanded, and not bare. Bare, each side sizes to its own
    // text and a long pair can overrun the paper — which only shows up on an
    // RTL receipt, where the label sits flush against the edge instead of
    // spilling into empty space. Expanded fixes that but caps each side at half
    // the width, so `POS1-200-000014` wraps mid-number next to a short label.
    // Flexible caps without reserving: each side takes what it needs and only
    // shrinks when the pair genuinely does not fit.
    final labelW = pw.Flexible(
      child: printedText(label,
          style: style,
          layout: dir,
          textAlign: rtl ? pw.TextAlign.right : pw.TextAlign.left),
    );
    final valueW = pw.Flexible(
      child: printedText(value,
          style: style,
          layout: dir,
          textAlign: rtl ? pw.TextAlign.left : pw.TextAlign.right),
    );
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

  /// Builds the receipt / guest-check document WITHOUT printing it.
  ///
  /// Split out from [printCartReceipt] so the rendered page can be produced in
  /// a test and looked at. Four consecutive Arabic bugs on this document were
  /// invisible to the analyzer and to every unit test and only showed up on
  /// paper (boxes → unshaped letters → wrong glyphs → a silent no-op fix), so
  /// being able to render a real receipt headless is worth the seam.
  Future<pw.Document> buildCartReceipt({
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
    final fontScale = _fontScale(roleSettings, role);
    final font = await _font(roleSettings, role);
    final boldFont = await _fontBold(roleSettings, role);
    final arabicRegular = await PdfFonts.arabic();
    final arabicBold = await PdfFonts.arabic(bold: true);
    final rtl = _flag(roleSettings, '$role.RightToLeft');
    final logoFull = _flag(roleSettings, '$role.LogoFullWidth');
    final showBarcode = _flag(roleSettings, '$role.PrintBarcode');

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
        // Via the shared basis so a tax-inclusive line reports the tax carved
        // OUT of its price rather than a second one added on top — the receipt
        // has to agree with the cart totals to the cent.
        final b = lineTaxBasis(item, discountBeforeTax: discountBeforeTax);
        final unitNet = b.unitPrice - b.unitDiscount - b.unitPromo;
        final taxBase =
            (discountBeforeTax ? unitNet : b.unitPrice) * item.quantity;
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

    pw.TextStyle ts(double size, {bool bold = false, bool italic = false}) =>
        printedTextStyle(
          font: font,
          boldFont: boldFont,
          arabic: arabicRegular,
          arabicBold: arabicBold,
          bold: bold,
          italic: italic,
          size: size * fontScale,
        );

    final dir = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    pw.Widget center(String text, {double size = 10, bool bold = false}) =>
        pw.Center(
          child: printedText(
            text,
            style: ts(size, bold: bold),
            textAlign: pw.TextAlign.center,
            layout: dir,
          ),
        );

    final itemCount = items.fold<double>(0, (s, i) => s + i.quantity);
    final itemCountStr = itemCount % 1 == 0
        ? itemCount.toInt().toString()
        : itemCount.toStringAsFixed(2);

    final l = _l10n(roleSettings);

    final useCustomLabels =
        (roleSettings[SettingKeys.receiptUseCustomLabels] ?? 'true')
                .toLowerCase() !=
            'false';
    String lbl(String key, String localized) => resolveReceiptLabel(
          stored: roleSettings[key],
          shippedDefault: kSettingDefaults[key],
          localized: localized,
          useCustomLabels: useCustomLabels,
        );

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
      arabic: arabicRegular,
      arabicBold: arabicBold,
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

      add(showCustName, lbl(SettingKeys.labelCustomer, l.customerLabel), c.name);
      add(showCustCode, lbl(SettingKeys.labelCustomerCode, l.fieldCode), c.code);
      add(showCustTax, lbl(SettingKeys.labelCompanyTaxNumber, l.setTaxNo),
          c.taxNumber);
      add(showCustPhone, lbl(SettingKeys.labelCustomerPhone, l.setPhone),
          c.phoneNumber);
      add(showCustEmail, lbl(SettingKeys.labelCustomerEmail, l.fieldEmail), c.email);
      if (showCustAddr) {
        add(true, lbl(SettingKeys.labelCustomerAddress, l.setAddress),
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
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
          fontFallback: [arabicRegular, arabicBold],
        ),
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
            // With no logo the name IS the branding, so it prints at the size
            // the logo would have occupied. A shop that never uploaded one was
            // otherwise handing out receipts headed by 16pt body text.
            center(headerText, size: logoBytes == null ? 24 : 16, bold: true),
            if (showCompanyTax && company.taxNumber?.isNotEmpty == true)
              center('${lbl(SettingKeys.labelCompanyTaxNumber, l.setTaxNo)}: ${company.taxNumber}', size: 9),
            if (showCompanyAddress && company.address?.isNotEmpty == true)
              center(company.address!, size: 9),
            if (showCompanyPhone && company.phoneNumber?.isNotEmpty == true)
              center('${lbl(SettingKeys.labelCompanyPhone, l.telLabel)}: ${company.phoneNumber}', size: 9),
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
                child: printedText(
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
              rowW('${lbl(SettingKeys.labelReceiptNumber, l.receiptLabel)}:',
                  shortNo(orderNumber)),
            rowW('${l.dateLabel}:', _fmtDateTime(printTime)),
            if (cashier != null)
              rowW('${lbl(SettingKeys.labelUser, l.roleCashier)}:',
                  cashier.displayName),
            pw.SizedBox(height: 4),
            pw.Divider(borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 6),

            ...customerBlock(),

            // ── Items ──────────────────────────────────────────────────────
            ...renderItems.map((item) {
              final qty = formatQuantityValue(item.quantity, item.uomId);
              // Shared ex-tax basis: for a tax-inclusive product the printed
              // unit price and line total must come back to the shelf price,
              // not the shelf price plus tax again.
              final b =
                  lineTaxBasis(item, discountBeforeTax: discountBeforeTax);
              final unitNet = b.unitPrice - b.unitDiscount - b.unitPromo;
              final taxBase =
                  (discountBeforeTax ? unitNet : b.unitPrice) * item.quantity;
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
              final nameW = printedText(
                item.productName,
                style: ts(11, bold: true),
                layout: dir,
              );

              // The unit, when there is one to print. On a WEIGHED line it is
              // not decoration and not optional: "0.125 x 50.00" does not say
              // 0.125 of what, and kg / g / L are not interchangeable. So a
              // weighed item always carries its unit; everything else stays
              // behind the Receipt.PrintMeasurementUnit toggle.
              final unitLabel = item.measurementUnit?.trim() ?? '';
              final unit = (unitLabel.isNotEmpty && (printUnit || item.isToWeigh))
                  ? ' $unitLabel'
                  : '';

              // A modifier's surcharge lives INSIDE `price` (see CartItem's
              // basePrice invariant), so a 20.00 product with a 5.00 option
              // printed as "1 x 25.00" — neither the shelf price nor the
              // supplement was legible, only their sum. Print the product's own
              // price here; each option prints its own "+ Name 5.00" line
              // below, and the line total still carries the whole 25.00.
              final surcharge = item.price - item.basePrice;
              final shownUnitPrice =
                  surcharge > 0 ? unitPrice - surcharge : unitPrice;

              final qtyPriceW = printedText(
                '${rtl ? '' : '  '}$qty$unit x ${money(shownUnitPrice)} $currencySymbol',
                style: ts(10),
                layout: dir,
              );
              final lineTotalW = printedText(
                '${money(lineTotal)} $currencySymbol',
                style: ts(10),
                layout: dir,
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
                  // Each choice on its own indented line, with what it added.
                  // The surcharge is already inside the unit price above, so
                  // this is the breakdown of a total the customer can otherwise
                  // only take on trust.
                  ...item.selectedModifiers.map(
                    (m) => printedText(
                      '${rtl ? '' : '    '}+ ${m.name}'
                      '${m.additionalPrice == 0 ? '' : ' '
                          '${money(m.additionalPrice)} $currencySymbol'}',
                      style: ts(9, italic: true),
                      layout: dir,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                ],
              );
            }),

            pw.Divider(borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 4),

            // ── Totals ─────────────────────────────────────────────────────
            rowW('${lbl(SettingKeys.labelSubtotal, l.subtotal)}:',
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
                '${lbl(SettingKeys.labelDiscount, l.discountLabel)}:',
                '-${money(totalDiscount)} $currencySymbol',
              ),
            if (totalTax > 0 && printTaxTotals)
              if (printTaxName && taxByName.isNotEmpty)
                ...taxByName.entries.map(
                  (e) => rowW('${e.key}:', '${money(e.value)} $currencySymbol'),
                )
              else
                rowW('${lbl(SettingKeys.labelTaxRate, l.fieldTax)}:',
                    '${money(totalTax)} $currencySymbol'),
            pw.SizedBox(height: 4),
            pw.Divider(),
            pw.SizedBox(height: 4),
            rowW(
              '${lbl(SettingKeys.labelTotal, l.grandTotalUpper)}:',
              '${money(grandTotal)} $currencySymbol',
              bold: true,
              fontSize: 13,
            ),
            if (pointsUsed > 0) ...[
              pw.SizedBox(height: 2),
              rowW(
                '${l.pointsUsed}:',
                '-${money(pointsUsed * pointValue)} $currencySymbol'
                    ' (${pointsUsed.toInt()} pts)',
              ),
              // The actual amount owed once points are applied — otherwise the
              // receipt printed GRAND TOTAL but the cashier collected less.
              rowW(
                '${lbl(SettingKeys.labelAmountDue, l.amountDue)}:',
                '${money((grandTotal - pointsUsed * pointValue).clamp(0.0, double.infinity))} $currencySymbol',
                bold: true,
              ),
            ],
            // Dual currency — mirrors the cart's "≈ 12.34 €" line. Converts the
            // amount actually owed (points already deducted), not grandTotal,
            // so the printed conversion matches what the customer pays.
            //
            // Prints "~" rather than the on-screen "≈": the bundled PDF font
            // has no glyph for U+2248, so every receipt with dual currency on
            // logged `Unable to find a font to draw "≈"`. Plain ASCII "~" is
            // in every Latin font and reads the same. The SCREEN keeps "≈" —
            // Flutter's system font renders it fine there.
            if (dualEnabled)
              rowW(
                '',
                '~ ${money(owedAmount * dualRate)} $dualSym',
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
                  '${lbl(SettingKeys.labelChange, l.change)}:',
                  '${money(amountPaid - (grandTotal - pointsUsed * pointValue).clamp(0.0, double.infinity))} $currencySymbol',
                ),
            ],
            // Outstanding balance — always printed when the customer still owes
            // money (a credit / partial payment), so a credit receipt clearly
            // states what is due. `receiptPrintOutstandingBalance` additionally
            // forces the row even when the sale is fully settled (balance 0).
            if (balanceDue > 0.005 || printBalance)
              rowW(
                  '${lbl(SettingKeys.labelOutstandingBalance, l.balanceDue)}:',
                  '${money(balanceDue)} $currencySymbol',
                  bold: true),
            if (printItemsCount)
              rowW('${lbl(SettingKeys.labelItemsCount, l.itemsLabel)}:',
                  renderItems.length.toString()),
            if (printTotalQty) rowW('${l.totalQty}:', itemCountStr),
            if (!isGuestCheck && pointsEarned > 0)
              rowW('${l.pointsEarned}:', '+${pointsEarned.toInt()} ${l.ptsShort}'),
            if (!isGuestCheck && (pointsEarned > 0 || pointsUsed > 0))
              rowW('${l.pointsBalance}:', '${pointsBalance.toInt()} ${l.ptsShort}'),
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
                  // The document number, not the order it came from. The
                  // barcode exists so a returned receipt can be scanned back
                  // into a refund, and refunds are looked up by document.
                  // Orders are transient; documents are the permanent record.
                  data: (documentNumber?.trim().isNotEmpty ?? false)
                      ? documentNumber!.trim()
                      : orderNumber,
                  width: 120,
                  height: 35,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return pdf;
  }



  /// Prints (or saves) the receipt / guest check built by [buildCartReceipt].
  Future<void> printCartReceipt({
    required Company company,
    required User? cashier,
    Customer? customer,
    required String orderNumber,
    String? documentNumber,
    required DateTime printTime,
    required List<CartItem> items,
    required double subtotal,
    required double totalDiscount,
    required double totalTax,
    required double grandTotal,
    required String currencySymbol,
    List<ReceiptDiscountLine> discountLines = const [],
    String? paymentTypeName,
    double? amountPaid,
    Uint8List? logoBytes,
    Map<String, String> roleSettings = const {},
    String role = 'Receipt',
    bool isGuestCheck = false,
    bool saveToFile = false,
    double pointsUsed = 0,
    double pointsEarned = 0,
    double pointsBalance = 0,
    double pointValue = 1.0,
  }) async {
    final pdf = await buildCartReceipt(
      company: company,
      cashier: cashier,
      customer: customer,
      orderNumber: orderNumber,
      documentNumber: documentNumber,
      printTime: printTime,
      items: items,
      subtotal: subtotal,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      grandTotal: grandTotal,
      currencySymbol: currencySymbol,
      discountLines: discountLines,
      paymentTypeName: paymentTypeName,
      amountPaid: amountPaid,
      logoBytes: logoBytes,
      roleSettings: roleSettings,
      role: role,
      isGuestCheck: isGuestCheck,
      pointsUsed: pointsUsed,
      pointsEarned: pointsEarned,
      pointsBalance: pointsBalance,
      pointValue: pointValue,
    );

    final l = _l10n(roleSettings);
    // A guest check is always an order — it prints before the sale is banked,
    // so it never has a document number even when the caller knows one.
    final name = (!isGuestCheck && (documentNumber?.trim().isNotEmpty ?? false))
        ? documentPdfName(documentNumber!)
        : orderPdfName(orderNumber, printTime);

    if (saveToFile) {
      await savePdfAs(
        bytes: await pdf.save(),
        suggestedName: name,
        dialogTitle: isGuestCheck ? l.saveGuestCheckTitle : l.saveReceiptTitle,
      );
      return;
    }
    await _dispatch(pdf, name, _copies(roleSettings, role),
        roleSettings['$role.PrinterName']);
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
    final fontScale = _fontScale(roleSettings, role);
    final font = await _font(roleSettings, role);
    final boldFont = await _fontBold(roleSettings, role);
    final arabicRegular = await PdfFonts.arabic();
    final arabicBold = await PdfFonts.arabic(bold: true);
    final l = _l10n(roleSettings);

    pw.TextStyle ts(double size, {bool bold = false, bool italic = false}) =>
        printedTextStyle(
          font: font,
          boldFont: boldFont,
          arabic: arabicRegular,
          arabicBold: arabicBold,
          bold: bold,
          italic: italic,
          size: size * fontScale,
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
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
          fontFallback: [arabicRegular, arabicBold],
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            // ── Big order number ──────────────────────────────────────
            pw.Center(child: printedText(ticketNum, style: ts(40, bold: true))),
            pw.SizedBox(height: 4),
            pw.Divider(borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 4),

            // ── Meta info ─────────────────────────────────────────────
            // `Round:` was removed here — nothing in the app ever incremented
            // CartItem.roundNumber, so it printed a constant "1" on every
            // ticket and told the kitchen nothing. Reinstate it only alongside
            // real course tracking.
            printedPair('${l.userLabel}:', cashierName, style: ts(10)),
            printedPair('${l.posOrder}:', orderNumber, style: ts(10)),
            printedPair('${l.timeLabel}:', _fmtDateTime(printTime), style: ts(10)),
            pw.SizedBox(height: 6),

            // ── Table + service type ──────────────────────────────────
            // The table is the single most operationally useful line on a
            // dine-in ticket, so it gets the larger type; omitted entirely when
            // the order has no table (takeaway/delivery) rather than printing
            // an empty label.
            if (tableName != null && tableName.trim().isNotEmpty) ...[
              pw.Center(
                child: printedText(tableName.trim(), style: ts(18, bold: true)),
              ),
              pw.SizedBox(height: 2),
            ],
            pw.Center(child: printedText(serviceType, style: ts(13, bold: true))),
            pw.SizedBox(height: 6),
            pw.Divider(borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 8),

            // ── Items ─────────────────────────────────────────────────
            ...List.generate(items.length, (i) {
              final item = items[i];
              final qty = formatQuantityValue(item.quantity, item.uomId);

              // Gather every instruction line for this item:
              // 1. the chosen MODIFIERS — what the kitchen actually has to do
              //    differently, and the reason this ticket exists
              // 2. CartItem.comment split by newline (multi-line selections)
              // 3. extra structured comments from the caller's itemComments
              //
              // 🚨 Modifiers first and without prices. A ticket is a work
              // instruction, not a bill — "+ Extra Cheese" is the whole point,
              // and "+3.00" on it is noise to whoever is at the grill.
              final commentLines = <String>[
                for (final m in item.selectedModifiers) '+ ${m.name}',
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
                    printedText(
                      '$qty x ${item.productName}',
                      style: ts(16, bold: true),
                    ),
                    ...commentLines.map(
                      (c) => pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 12, top: 2),
                        child: printedText(c, style: ts(10, italic: true)),
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
    await _dispatch(pdf, orderPdfName(orderNumber, printTime),
        _copies(roleSettings, role), roleSettings['$role.PrinterName']);
  }

  // ── Z-Report ──────────────────────────────────────────────────────────────

  /// Builds the Z-report document without printing it — same testing seam as
  /// [buildCartReceipt].
  Future<pw.Document> buildZReport(
    ZReportModel report,
    String currencySymbol, {
    required Map<String, String> roleSettings,
    // Which configured printer this goes to. Defaults to the receipt printer —
    // a Z-report is an end-of-shift till roll, not a document.
    String role = 'Receipt',
  }) async {
    // 🚨 This used to hardcode roll80, a 10pt margin and the bundled Latin face,
    // ignoring the printer configuration entirely: a 58mm till printed a report
    // laid out for 80mm, the margin and font-size settings did nothing, Copies
    // was ignored and it always went to the default printer instead of the one
    // the operator chose. Everything below now comes from the same helpers the
    // receipt uses, so one printer setup covers both.
    final format = _paperFmt(roleSettings['$role.PaperSize']);
    final margins = _margins(roleSettings, role);
    final fontScale = _fontScale(roleSettings, role);
    final font = await _font(roleSettings, role);
    final boldFont = await _fontBold(roleSettings, role);
    final rtl = _flag(roleSettings, SettingKeys.roleRightToLeft(role));
    final arabicRegular = await PdfFonts.arabic();
    final arabicBold = await PdfFonts.arabic(bold: true);
    final l = _l10n(roleSettings);
    final pdf = pw.Document();

    pw.TextStyle ts(double size, {bool bold = false}) => printedTextStyle(
          font: font,
          boldFont: boldFont,
          arabic: arabicRegular,
          arabicBold: arabicBold,
          bold: bold,
          size: size * fontScale,
        );

    // Same label/value row the receipt uses, so the two cannot drift — and so
    // the Z-report inherits its RTL handling and overflow protection.
    pw.Widget zRow(String label, String value,
            {bool bold = false, double fontSize = 10}) =>
        _row(
          label,
          value,
          bold: bold,
          fontSize: fontSize,
          fontScale: fontScale,
          font: font,
          boldFont: boldFont,
          arabic: arabicRegular,
          arabicBold: arabicBold,
          rtl: rtl,
        );

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: margins,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
          fontFallback: [arabicRegular, arabicBold],
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              printedText(
                l.zReportUpper,
                textAlign: pw.TextAlign.center,
                style: ts(16, bold: true),
              ),
              pw.SizedBox(height: 8),
              printedText(
                l.zReportNumber('${report.number}'),
                textAlign: pw.TextAlign.center,
                style: ts(12),
              ),
              printedText(
                '${l.dateLabel}: ${report.dateCreated.toIso8601String().split('T').first}'
                '  ${l.timeLabel}: ${report.dateCreated.toIso8601String().split('T').last.split('.').first}',
                textAlign: pw.TextAlign.center,
                style: ts(10),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),

              printedText(
                l.shiftSummaryUpper,
                textAlign: pw.TextAlign.center,
                style: ts(12, bold: true),
              ),
              pw.SizedBox(height: 8),
              zRow(
                '${l.documents}:',
                report.documentCount?.toString() ?? '-',
              ),
              if (report.fromDocumentNumber != null)
                zRow(
                  '${l.rangeLabel}:',
                  report.fromDocumentNumber == report.toDocumentNumber
                      ? report.fromDocumentNumber!
                      : '${report.fromDocumentNumber} - ${report.toDocumentNumber}',
                ),
              // 🚨 Read off the REPORT, not passed in by whoever happened to
              // print it. It used to be an argument only the session-closing
              // screen supplied, so the identical report printed from End of
              // Day came out with no opening cash at all. Printed, never summed:
              // expectedCash already adds the float once.
              if (report.openingCash != null)
                zRow(
                  '${l.sessionOpeningCash}:',
                  '${report.openingCash!.toStringAsFixed(2)} $currencySymbol',
                ),
              zRow(
                '${l.cashIn}:',
                '${report.totalCashIn.toStringAsFixed(2)} $currencySymbol',
              ),
              zRow(
                '${l.cashOut}:',
                '-${report.totalCashOut.toStringAsFixed(2)} $currencySymbol',
              ),
              pw.SizedBox(height: 4),
              zRow(
                '${l.totalSales}:',
                '${report.totalSales.toStringAsFixed(2)} $currencySymbol',
              ),
              zRow(
                '${l.totalReturns}:',
                '${report.totalReturns.toStringAsFixed(2)} $currencySymbol',
              ),
              zRow(
                '${l.discountsLabel}:',
                '${report.discountsGranted.toStringAsFixed(2)} $currencySymbol',
              ),
              zRow(
                '${l.taxableTotal}:',
                '${report.taxableTotal.toStringAsFixed(2)} $currencySymbol',
              ),
              zRow(
                '${l.totalTax}:',
                '${report.totalTax.toStringAsFixed(2)} $currencySymbol',
              ),

              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),

              printedText(
                l.tenderTypesUpper,
                textAlign: pw.TextAlign.center,
                style: ts(12, bold: true),
              ),
              pw.SizedBox(height: 8),
              if (report.paymentSummaries.isEmpty)
                printedText(
                  l.noPaymentsRecorded,
                  textAlign: pw.TextAlign.center,
                  style: printedTextStyle(
                    font: font,
                    arabic: arabicRegular,
                    italic: true,
                    size: 10,
                  ),
                )
              else
                ...report.paymentSummaries.map(
                  (p) => zRow(
                    p.paymentTypeName ?? l.unknownLabel,
                    '${p.totalAmount.toStringAsFixed(2)} $currencySymbol',
                  ),
                ),

              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),

              zRow(
                '${l.grandTotalUpper}:',
                '${report.grandTotal.toStringAsFixed(2)} $currencySymbol',
                bold: true,
                fontSize: 14,
              ),

              pw.SizedBox(height: 24),
              printedText(
                l.endOfReport,
                textAlign: pw.TextAlign.center,
                style: ts(10),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Prints the Z-report on the configured printer.
  ///
  /// Was `Printing.layoutPdf`, which always opens the system print dialog on the
  /// default printer — so the chosen printer and Copies were both ignored.
  /// `_dispatch` is what every other document uses.
  Future<void> printZReport(
    ZReportModel report,
    String currencySymbol, {
    required Map<String, String> roleSettings,
    String role = 'Receipt',
  }) async {
    final pdf = await buildZReport(report, currencySymbol,
        roleSettings: roleSettings, role: role);
    await _dispatch(pdf, 'Z_Report_${report.number}',
        _copies(roleSettings, role), roleSettings['$role.PrinterName']);
  }

}
