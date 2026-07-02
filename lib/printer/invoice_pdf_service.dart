import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/document/document_model.dart';
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
    List<ReceiptDiscountLine> discountLines = const [],
    Uint8List? logoBytes,
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
      discountLines: discountLines,
      logoBytes: logoBytes,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: invoiceNumber);
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
    List<ReceiptDiscountLine> discountLines = const [],
    Uint8List? logoBytes,
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
      discountLines: discountLines,
      logoBytes: logoBytes,
    );
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Invoice PDF',
      fileName: '$invoiceNumber.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (path != null) {
      await File(path).writeAsBytes(bytes);
    }
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
    List<ReceiptDiscountLine> discountLines = const [],
    Uint8List? logoBytes,
  }) async {
    pw.Font font;
    pw.Font boldFont;
    try {
      font = await PdfGoogleFonts.notoSansRegular();
      boldFont = await PdfGoogleFonts.notoSansBold();
    } catch (_) {
      font = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
    }

    pw.ImageProvider? logo;
    if (logoBytes != null) {
      try {
        logo = pw.MemoryImage(logoBytes);
      } catch (_) {}
    }

    pw.TextStyle ts(double size, {bool bold = false, PdfColor? color}) =>
        pw.TextStyle(
          font: bold ? boldFont : font,
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

    // Build the totals section
    final amountDue = isPaid ? 0.0 : total;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
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
          // ── HEADER ───────────────────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: title + company info
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('INVOICE', style: ts(22, bold: true)),
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
            columnWidths: const {
              0: pw.FixedColumnWidth(26), // #
              1: pw.FlexColumnWidth(3.5), // Item
              2: pw.FixedColumnWidth(58), // Quantity
              3: pw.FixedColumnWidth(62), // Unit price
              4: pw.FixedColumnWidth(50), // Tax
              5: pw.FixedColumnWidth(55), // Discount
              6: pw.FixedColumnWidth(65), // Total
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _kHeaderBg),
                children: [
                  '#',
                  'Item',
                  'Quantity',
                  'Unit price',
                  'Tax',
                  'Discount',
                  'Total',
                ].map((h) => _cell(h, ts: ts, header: true)).toList(),
              ),
              // Rows
              ...items.asMap().entries.map((e) {
                final idx = e.key;
                final item = e.value;
                final taxPct = item.priceBeforeTax > 0
                    ? (item.price - item.priceBeforeTax) /
                          item.priceBeforeTax *
                          100
                    : 0.0;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: idx.isEven ? PdfColors.white : _kRowAlt,
                  ),
                  children: [
                    _cell('${idx + 1}', ts: ts, align: pw.Alignment.center),
                    _cell(
                      item.productName ?? '-',
                      ts: ts,
                      align: pw.Alignment.centerLeft,
                    ),
                    _cell(
                      item.measurementUnit != null &&
                              item.measurementUnit!.trim().isNotEmpty
                          ? '${_numFmt.format(item.quantity)} ${item.measurementUnit!.trim()}'
                          : _numFmt.format(item.quantity),
                      ts: ts,
                      align: pw.Alignment.centerRight,
                    ),
                    _cell(
                      _numFmt.format(item.price),
                      ts: ts,
                      align: pw.Alignment.centerRight,
                    ),
                    _cell(
                      taxPct == 0 ? '---' : '${taxPct.toStringAsFixed(0)}%',
                      ts: ts,
                      align: pw.Alignment.centerRight,
                    ),
                    _cell(
                      item.discount == 0
                          ? '0.00%'
                          : '${item.discount.toStringAsFixed(2)}%',
                      ts: ts,
                      align: pw.Alignment.centerRight,
                    ),
                    _cell(
                      _numFmt.format(item.total),
                      ts: ts,
                      align: pw.Alignment.centerRight,
                    ),
                  ],
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
                  if (paymentSummary != null && paymentSummary.isNotEmpty) ...[
                    pw.Text('Payment method:', style: ts(9, bold: true)),
                    pw.SizedBox(height: 3),
                    _summaryRow(
                      paymentSummary,
                      '$currencySymbol${_numFmt.format(total)}',
                      ts: ts,
                    ),
                  ],
                  _summaryRow(
                    'Paid amount:',
                    '$currencySymbol${_numFmt.format(total)}',
                    ts: ts,
                    bold: true,
                  ),
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
