import 'package:intl/intl.dart';

/// Default file names for every PDF the app hands to a printer.
///
/// These seed the file-name box of the "Save as PDF" dialog (and the preview's
/// share button), which is the only place a print job's name is ever visible to
/// an operator. Without one, every export lands as a generic name and a day of
/// receipts is indistinguishable on disk.
///
/// Everything here returns a name WITHOUT the `.pdf` extension: `layoutPdf` /
/// `directPrintPdf` take a job name and Windows appends the extension itself,
/// so passing `.pdf` yields `Foo.pdf.pdf`. `PdfPreview.pdfFileName` is the
/// exception — it wants the full file name, so that call site appends `.pdf`.

/// Windows rejects `\ / : * ? " < > |` in a file name, and silently discards a
/// default that contains one. Order names are operator-typed and a clock reads
/// `HH:MM`, so both have to be scrubbed before they can be used as a name.
String pdfSafeName(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      // Windows also rejects a trailing dot or space.
      .replaceAll(RegExp(r'[. ]+$'), '');
  return cleaned.isEmpty ? 'Print' : cleaned;
}

/// `TALABIA #008_14-32` — an open order has no permanent number (it is only
/// assigned one when it is banked as a document at checkout), so it is
/// identified by its name plus the print time.
String orderPdfName(String orderName, DateTime at) =>
    '${pdfSafeName(orderName)}_${DateFormat('HH-mm').format(at)}';

/// `POS1-200-000004` — a banked sale carries a document number that is already
/// unique per company, so it needs nothing else.
String documentPdfName(String number) => pdfSafeName(number);

/// `INV-2026-07-16` — the stock sheet is a snapshot of one day.
String stockPdfName(DateTime day) =>
    'INV-${DateFormat('yyyy-MM-dd').format(day)}';

/// `Sales by Product_2026-07-01_2026-07-16` — a report is only meaningful with
/// the range it covers; without it, re-exporting the same report on a different
/// range overwrites the previous file.
String reportPdfName(String label, DateTime from, DateTime to) {
  final f = DateFormat('yyyy-MM-dd');
  final range =
      f.format(from) == f.format(to) ? f.format(from) : '${f.format(from)}_${f.format(to)}';
  return '${pdfSafeName(label)}_$range';
}
