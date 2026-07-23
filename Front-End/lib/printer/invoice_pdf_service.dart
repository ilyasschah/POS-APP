import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pos_app/printer/pdf_fonts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/document/document_model.dart';
import 'package:pos_app/printer/pdf_file_name.dart';
import 'package:pos_app/printer/pdf_save_service.dart';
import 'package:pos_app/cart/discount_display.dart';

// Orange accent matching the Aronium invoice style
const _kOrange = PdfColor(0.878, 0.482, 0.0);
const _kHeaderBg = PdfColor(1.0, 0.953, 0.878);
const _kBorder = PdfColor(0.80, 0.80, 0.80);
const _kTextMuted = PdfColor(0.333, 0.333, 0.333);
const _kRowAlt = PdfColor(0.98, 0.98, 0.98);
const _kGreen = PdfColor(0.18, 0.49, 0.196);
const _kRed = PdfColor(0.82, 0.1, 0.1);

class InvoicePdfService {
  static final _dateFmt = DateFormat('dd/MM/yyyy');
  static final _numFmt = NumberFormat('#,##0.00');

  // ── Public API ──────────────────────────────────────────────────────────────

  static Future<void> printDocument({
    required Company company,
    required String invoiceNumber,
    required String date,
    required String? customerName,
    required bool isPaid,
    required List<DocumentItem> items,
    required double total,
    required double totalBeforeTax,
    required double taxTotal,
    required double discount,
    required String? paymentSummary,
    required String currencySymbol,
    double? amountPaid,
    List<ReceiptDiscountLine> discountLines = const [],
    Uint8List? logoBytes,
    Map<String, String> settings = const {},
  }) async {
    final bytes = await generate(
      company: company,
      invoiceNumber: invoiceNumber,
      date: date,
      customerName: customerName,
      isPaid: isPaid,
      items: items,
      total: total,
      totalBeforeTax: totalBeforeTax,
      taxTotal: taxTotal,
      discount: discount,
      paymentSummary: paymentSummary,
      currencySymbol: currencySymbol,
      amountPaid: amountPaid,
      discountLines: discountLines,
      logoBytes: logoBytes,
      settings: settings,
    );
    await Printing.layoutPdf(
        onLayout: (_) async => bytes, name: documentPdfName(invoiceNumber));
  }

  static Future<void> saveAsPdf({
    required Company company,
    required String invoiceNumber,
    required String date,
    required String? customerName,
    required bool isPaid,
    required List<DocumentItem> items,
    required double total,
    required double totalBeforeTax,
    required double taxTotal,
    required double discount,
    required String? paymentSummary,
    required String currencySymbol,
    double? amountPaid,
    List<ReceiptDiscountLine> discountLines = const [],
    Uint8List? logoBytes,
    Map<String, String> settings = const {},
  }) async {
    final bytes = await generate(
      company: company,
      invoiceNumber: invoiceNumber,
      date: date,
      customerName: customerName,
      isPaid: isPaid,
      items: items,
      total: total,
      totalBeforeTax: totalBeforeTax,
      taxTotal: taxTotal,
      discount: discount,
      paymentSummary: paymentSummary,
      currencySymbol: currencySymbol,
      amountPaid: amountPaid,
      discountLines: discountLines,
      logoBytes: logoBytes,
      settings: settings,
    );
    await savePdfAs(
      bytes: bytes,
      suggestedName: documentPdfName(invoiceNumber),
      dialogTitle: 'Save Invoice PDF',
    );
  }

  // ── PDF generation ──────────────────────────────────────────────────────────

  static Future<Uint8List> generate({
    required Company company,
    required String invoiceNumber,
    required String date,
    required String? customerName,
    required bool isPaid,
    required List<DocumentItem> items,
    required double total,
    required double totalBeforeTax,
    required double taxTotal,
    required double discount,
    required String? paymentSummary,
    required String currencySymbol,
    double? amountPaid,
    List<ReceiptDiscountLine> discountLines = const [],
    Uint8List? logoBytes,
    Map<String, String> settings = const {},
  }) async {
    // ── Invoice.* settings (editable in Settings › Invoice / Templates) ────────
    // Read defensively: an empty map (a caller that passes nothing) falls back to
    // the same kSettingDefaults the AppSettingsNotifier merges in-memory, so the
    // rendered invoice matches what the settings screen shows.
    final titleRaw = (settings[SettingKeys.invoiceTitle] ?? '').trim();
    final title = titleRaw.isEmpty ? 'TAX INVOICE' : titleRaw;
    final printA5 =
        (settings[SettingKeys.invoicePrintA5] ?? 'false').trim().toLowerCase() ==
            'true';
    // Tax column defaults ON, Discount column defaults OFF (matches kSettingDefaults).
    final showTaxColumn =
        (settings[SettingKeys.invoiceColumnTax] ?? 'true').trim().toLowerCase() !=
            'false';
    final showDiscountColumn =
        (settings[SettingKeys.invoiceColumnDiscount] ?? 'false')
                .trim()
                .toLowerCase() ==
            'true';
    final globalHeader = (settings[SettingKeys.invoiceGlobalHeader] ?? '').trim();
    final globalFooter = (settings[SettingKeys.invoiceGlobalFooter] ?? '').trim();

    // Invoice.FontFamily — mirror the receipt's font handling. Courier/Times
    // are PDF core fonts; anything else uses the BUNDLED Noto Sans (not
    // PdfGoogleFonts, which downloads on first use and would leave an offline
    // terminal unable to print its first invoice).
    final fontFamily = settings[SettingKeys.invoiceFontFamily] ?? '(None)';
    pw.Font font;
    pw.Font boldFont;
    try {
      switch (fontFamily) {
        case 'Courier':
        case 'Monospace':
          font = pw.Font.courier();
          boldFont = pw.Font.courierBold();
          break;
        case 'Times New Roman':
        case 'Times':
          font = pw.Font.times();
          boldFont = pw.Font.timesBold();
          break;
        default:
          font = await PdfFonts.latin();
          boldFont = await PdfFonts.latin(bold: true);
      }
    } catch (_) {
      font = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
    }

    // Arabic glyphs: none of the faces above carry them (the standard-14 faces
    // are Latin-1, Noto Sans is the Latin subset). Attached as a FALLBACK so
    // the operator's chosen face still drives Latin text and only the glyphs it
    // cannot draw come from Noto Naskh — a mixed-script invoice then needs no
    // language detection.
    final arabicRegular = await PdfFonts.arabic();
    final arabicBold = await PdfFonts.arabic(bold: true);

    // Row visibility toggles (both default ON → unchanged output).
    final showPaymentMethods =
        (settings[SettingKeys.invoiceShowPaymentMethods] ?? 'true')
                .toLowerCase() !=
            'false';
    final showOutstanding =
        (settings[SettingKeys.invoiceShowOutstandingBalance] ?? 'true')
                .toLowerCase() !=
            'false';

    pw.ImageProvider? logo;
    if (logoBytes != null) {
      try {
        logo = pw.MemoryImage(logoBytes);
      } catch (_) {}
    }

    pw.TextStyle ts(double size, {bool bold = false, PdfColor? color}) =>
        pw.TextStyle(
          font: bold ? boldFont : font,
          fontFallback: [bold ? arabicBold : arabicRegular],
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : null,
          color: color,
        );

    String fmtDate(String? iso) {
      if (iso == null || iso.isEmpty) return '---';
      try {
        return _dateFmt.format(DateTime.parse(iso));
      } catch (_) {
        return iso;
      }
    }

    // Build the totals section. Prefer the real tendered amount (from the
    // stored payments) so a credit / partial sale shows what was actually paid
    // and what is still owed; fall back to the paid flag when it's unknown.
    final paidAmount = amountPaid ?? (isPaid ? total : 0.0);
    final amountDue = (total - paidAmount).clamp(0.0, double.infinity);

    // Item table columns — the Tax and Discount columns are toggleable, so build
    // the column set first, then derive the widths, header and body rows from it
    // (dropping a column has to re-index every row, hence the shared model).
    final columns = <_InvColumn>[
      _InvColumn(
        '#',
        const pw.FixedColumnWidth(26),
        pw.Alignment.center,
        (item, idx) => '${idx + 1}',
      ),
      _InvColumn(
        'Item',
        const pw.FlexColumnWidth(3.5),
        pw.Alignment.centerLeft,
        (item, idx) => item.productName ?? '-',
      ),
      _InvColumn(
        'Quantity',
        const pw.FixedColumnWidth(58),
        pw.Alignment.centerRight,
        (item, idx) =>
            item.measurementUnit != null &&
                    item.measurementUnit!.trim().isNotEmpty
                ? '${_numFmt.format(item.quantity)} ${item.measurementUnit!.trim()}'
                : _numFmt.format(item.quantity),
      ),
      _InvColumn(
        'Unit price',
        const pw.FixedColumnWidth(62),
        pw.Alignment.centerRight,
        (item, idx) => _numFmt.format(item.price),
      ),
      if (showTaxColumn)
        _InvColumn(
          'Tax',
          const pw.FixedColumnWidth(50),
          pw.Alignment.centerRight,
          // The line's own rate. Deriving it from (price - priceBeforeTax) read
          // 0 on every checkout row — both hold the same ex-tax price there — so
          // a taxed invoice printed "---" in the Tax column.
          (item, idx) => item.taxRate > 0
              ? '${item.taxRate.toStringAsFixed(item.taxRate % 1 == 0 ? 0 : 1)}%'
              : '---',
        ),
      if (showDiscountColumn)
        _InvColumn(
          'Discount',
          const pw.FixedColumnWidth(55),
          pw.Alignment.centerRight,
          // Type-aware: 0 = percent, 1 = fixed money. This printed a "%" sign on
          // every discount, so a 5.00 MAD item discount read "5.00%".
          (item, idx) => item.discount == 0
              ? '---'
              : item.discountType == 0
                  ? '${item.discount.toStringAsFixed(item.discount % 1 == 0 ? 0 : 2)}%'
                  : _numFmt.format(item.discount * item.quantity),
        ),
      _InvColumn(
        'Total',
        const pw.FixedColumnWidth(65),
        pw.Alignment.centerRight,
        // Tax-inclusive, so the column reconciles with the invoice Total.
        // `total` is ex-tax on checkout rows, which printed a 30.00 line under a
        // 37.00 invoice total and read as if the discount were taken twice.
        (item, idx) => _numFmt.format(item.totalWithTax),
      ),
    ];
    final columnWidths = {
      for (var i = 0; i < columns.length; i++) i: columns[i].width,
    };

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: printA5 ? PdfPageFormat.a5 : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Created with ${company.name}'
                '${company.email != null ? ' - ${company.email}' : ''}',
                style: ts(7, color: _kTextMuted),
              ),
              pw.Text(
                'Page ${ctx.pageNumber}',
                style: ts(7, color: _kTextMuted),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          // ── GLOBAL HEADER (user-defined banner, e.g. letterhead note) ─────────
          if (globalHeader.isNotEmpty) ...[
            pw.Text(globalHeader, style: ts(9, color: _kTextMuted)),
            pw.SizedBox(height: 10),
          ],

          // ── HEADER ───────────────────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: title + company info
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(title, style: ts(22, bold: true)),
                    pw.SizedBox(height: 8),
                    pw.Text(company.name, style: ts(12, bold: true)),
                    if (_companyAddress(company).isNotEmpty)
                      pw.Text(
                        _companyAddress(company),
                        style: ts(9, color: _kTextMuted),
                      ),
                    if (company.email != null)
                      pw.Text(company.email!, style: ts(9, color: _kTextMuted)),
                    if (company.phoneNumber != null)
                      pw.Text(
                        company.phoneNumber!,
                        style: ts(9, color: _kTextMuted),
                      ),
                    if (company.taxNumber != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('Tax No.:  ', style: ts(9, bold: true)),
                          pw.Text(company.taxNumber!, style: ts(9)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Right: logo
              if (logo != null)
                pw.Container(
                  width: 110,
                  height: 65,
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
            ],
          ),

          pw.SizedBox(height: 14),
          pw.Divider(color: _kBorder, thickness: 0.5),
          pw.SizedBox(height: 12),

          // ── BILL TO + INVOICE META ────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Bill to
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Bill to',
                      style: ts(10, bold: true, color: _kOrange),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(customerName ?? 'Unknown', style: ts(11)),
                  ],
                ),
              ),
              pw.SizedBox(width: 32),
              // Invoice meta
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _metaRow('Invoice No.:', invoiceNumber, ts: ts),
                  _metaRow('Date:', fmtDate(date), ts: ts),
                  _metaRow('Due date:', fmtDate(date), ts: ts),
                  // Payment status row
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 95,
                          child: pw.Text(
                            'Payment status:',
                            style: ts(10, color: _kOrange),
                          ),
                        ),
                        pw.Text(
                          isPaid ? 'Paid' : 'Unpaid',
                          style: ts(
                            10,
                            bold: true,
                            color: isPaid ? _kGreen : _kRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // ── ITEMS TABLE ───────────────────────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(color: _kBorder, width: 0.5),
            columnWidths: columnWidths,
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _kHeaderBg),
                children: columns
                    .map((c) => _cell(c.header, ts: ts, header: true))
                    .toList(),
              ),
              // Rows
              ...items.asMap().entries.map((e) {
                final idx = e.key;
                final item = e.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: idx.isEven ? PdfColors.white : _kRowAlt,
                  ),
                  children: columns
                      .map((c) =>
                          _cell(c.value(item, idx), ts: ts, align: c.align))
                      .toList(),
                );
              }),
            ],
          ),

          pw.SizedBox(height: 16),

          // ── TOTALS ────────────────────────────────────────────────────────────
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 210,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Itemized discount breakdown (each source kept on its own line
                  // with its configured value, so % and fixed never merge).
                  if (discountLines.isNotEmpty) ...[
                    ...discountLines.map(
                      (d) => _summaryRow(
                        d.hint == null ? d.label : '${d.label} (${d.hint})',
                        '-$currencySymbol${_numFmt.format(d.amount)}',
                        ts: ts,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                  ],
                  // Subtotal + tax. These were passed in and then DROPPED — a
                  // document headed "TAX INVOICE" printed no tax at all, and the
                  // Total appeared to follow from nothing (the discount line read
                  // as if it were subtracted from an already-discounted line
                  // total). Subtotal is net of tax AND of any discount above, so
                  // subtotal + tax == total on both discountApplyRule settings.
                  if (showTaxColumn) ...[
                    _summaryRow(
                      'Subtotal',
                      '$currencySymbol${_numFmt.format(totalBeforeTax)}',
                      ts: ts,
                    ),
                    _summaryRow(
                      'Tax',
                      '$currencySymbol${_numFmt.format(taxTotal)}',
                      ts: ts,
                    ),
                    pw.SizedBox(height: 6),
                  ],
                  // Total row with background
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: const pw.BoxDecoration(
                      color: _kHeaderBg,
                      border: pw.Border.fromBorderSide(
                        pw.BorderSide(color: _kBorder, width: 0.5),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total', style: ts(11, bold: true)),
                        pw.Text(
                          '$currencySymbol${_numFmt.format(total)}',
                          style: ts(11, bold: true),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  // Payment method label
                  if (showPaymentMethods &&
                      paymentSummary != null &&
                      paymentSummary.isNotEmpty) ...[
                    pw.Text('Payment method:', style: ts(9, bold: true)),
                    pw.SizedBox(height: 3),
                    _summaryRow(
                      paymentSummary,
                      '$currencySymbol${_numFmt.format(paidAmount)}',
                      ts: ts,
                    ),
                  ],
                  _summaryRow(
                    'Paid amount:',
                    '$currencySymbol${_numFmt.format(paidAmount)}',
                    ts: ts,
                    bold: true,
                  ),
                  if (showOutstanding)
                    _summaryRow(
                      'Amount due:',
                      '$currencySymbol${_numFmt.format(amountDue)}',
                      ts: ts,
                      bold: true,
                    ),
                ],
              ),
            ),
          ),

          // ── GLOBAL FOOTER (user-defined note, e.g. terms / bank details) ──────
          if (globalFooter.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Divider(color: _kBorder, thickness: 0.5),
            pw.SizedBox(height: 6),
            pw.Text(globalFooter, style: ts(9, color: _kTextMuted)),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  // ── Widget helpers ──────────────────────────────────────────────────────────

  static String _companyAddress(Company c) {
    final parts = <String>[
      if (c.streetName != null) c.streetName!,
      if (c.city != null) c.city!,
      if (c.countryName != null) c.countryName!,
    ];
    return parts.join(', ');
  }

  static pw.Widget _metaRow(
    String label,
    String value, {
    required pw.TextStyle Function(double, {bool bold, PdfColor? color}) ts,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 95,
          child: pw.Text(label, style: ts(10, color: _kOrange)),
        ),
        pw.Text(value, style: ts(10)),
      ],
    ),
  );

  static pw.Widget _cell(
    String text, {
    required pw.TextStyle Function(double, {bool bold, PdfColor? color}) ts,
    bool header = false,
    pw.Alignment align = pw.Alignment.center,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    alignment: align,
    child: pw.Text(
      text,
      style: ts(9, bold: header),
      overflow: pw.TextOverflow.clip,
    ),
  );

  static pw.Widget _summaryRow(
    String label,
    String value, {
    required pw.TextStyle Function(double, {bool bold, PdfColor? color}) ts,
    bool bold = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: ts(9, bold: bold)),
        pw.Text(value, style: ts(9, bold: bold)),
      ],
    ),
  );
}

/// One column of the invoice items table. Kept as a model (not inline widgets)
/// so optional columns (Tax, Discount) can be dropped without hand-re-indexing
/// the header, the per-row cells, and the column-width map.
class _InvColumn {
  final String header;
  final pw.TableColumnWidth width;
  final pw.Alignment align;
  final String Function(DocumentItem item, int idx) value;

  const _InvColumn(this.header, this.width, this.align, this.value);
}
