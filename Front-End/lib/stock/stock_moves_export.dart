import 'dart:typed_data';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/core/xlsx_writer.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/printer/pdf_fonts.dart';
import 'package:pos_app/printer/printed_text.dart';
import 'package:pos_app/stock/stock_move_labels.dart';
import 'package:pos_app/stock/stock_move_line.dart';
import 'package:pos_app/stock/stock_moves_columns.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

/// The Stock Moves exports. Both write [columns] — the ones the operator has
/// on screen, in their order — for the moves they are handed: the ticked rows,
/// or every move the filter matches when none is ticked
/// ([selectedStockMoves] decides which).

/// What an export writes when rows are ticked: exactly those, in the order on
/// screen. Null when nothing on screen is ticked — the export then covers
/// every move the filter matches, not just the pages scrolled into view.
List<StockMoveLine>? selectedStockMoves(
  List<StockMoveLine> onScreen,
  Set<String> selectedIds,
) {
  if (selectedIds.isEmpty) return null;
  final picked = [
    for (final m in onScreen)
      if (selectedIds.contains(m.itemLocalId)) m,
  ];
  return picked.isEmpty ? null : picked;
}

/// The Stock Moves spreadsheet, with typed cells: a real date the sheet can
/// sort, a signed quantity it can sum (negative where goods left stock), and
/// the unit in its own column beside it, since a number alone cannot say
/// whether it counts pieces or kilograms.
Uint8List buildStockMovesXlsx({
  required AppLocalizations l,
  required AppDateFormat dates,
  required List<StockMoveLine> moves,
  required List<String> columns,
}) {
  final header = <String>[];
  final widths = <double>[];
  for (final column in columns) {
    header.add(stockMoveColumnLabel(l, column));
    widths.add(_sheetWidths[column] ?? 16);
    if (column == 'quantity') {
      header.add(l.rptColUom);
      widths.add(8);
    }
  }

  final rows = [
    for (final m in moves)
      <XlsxCell?>[
        for (final column in columns)
          ...switch (column) {
            'date' => <XlsxCell>[XlsxDateTime(dates.toDisplayZone(m.date))],
            'quantity' => <XlsxCell>[
                XlsxNumber(m.isIncoming ? m.quantity : -m.quantity),
                XlsxText(uomById(m.uomId).code),
              ],
            _ => <XlsxCell>[XlsxText(stockMoveCellText(l, dates, m, column))],
          },
      ],
  ];

  return encodeXlsx(
    sheetName: l.stockMoves,
    header: header,
    rows: rows,
    columnWidths: widths,
  );
}

const _sheetWidths = <String, double>{
  'date': 18,
  'reference': 18,
  'product': 40,
  'from': 22,
  'to': 22,
  'quantity': 12,
  'status': 14,
  'doneBy': 22,
};

/// The Stock Moves report as a landscape A4 PDF — header with the company and
/// the active filters, the table, and a page footer. Print and Save render
/// the same bytes.
Future<Uint8List> buildStockMovesPdf({
  required AppLocalizations l,
  required AppDateFormat dates,
  required List<StockMoveLine> moves,
  required List<String> columns,
  required String companyName,
  String? warehouseName,
  String? search,
  DateTimeRange? period,
}) async {
  const headerBg = PdfColor.fromInt(0xFF37474F);
  const headerFg = PdfColors.white;
  const rowEvenBg = PdfColors.white;
  const rowOddBg = PdfColor.fromInt(0xFFF5F7FA);
  const borderClr = PdfColor.fromInt(0xFFCFD8DC);
  const accentClr = PdfColor.fromInt(0xFF00897B);
  const inClr = PdfColor.fromInt(0xFF2E7D32);
  const outClr = PdfColor.fromInt(0xFFC62828);
  const inkClr = PdfColor.fromInt(0xFF263238);

  final font = await PdfFonts.latin();
  final bold = await PdfFonts.latin(bold: true);
  // Named per STYLE, not only in the page theme: Arabic shaping resolves only
  // when the Arabic face is on the run's own style. See printer/printed_text.dart.
  final arabic = await PdfFonts.arabic();
  final arabicBold = await PdfFonts.arabic(bold: true);
  pw.TextStyle style({double size = 8, bool isBold = false}) => pw.TextStyle(
        font: isBold ? bold : font,
        fontFallback: [isBold ? arabicBold : arabic],
        fontWeight: isBold ? pw.FontWeight.bold : null,
        fontSize: size,
      );
  final now = DateTime.now();

  pw.Widget cell(String text,
          {bool header = false, bool end = false, PdfColor? color}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: printedText(
          text,
          textAlign: end ? pw.TextAlign.right : pw.TextAlign.left,
          style: style(size: header ? 7.5 : 8, isBold: header)
              .copyWith(color: color),
          overflow: pw.TextOverflow.clip,
          maxLines: 2,
        ),
      );

  // Label and ':' are separate runs: a colon is bidi-neutral, and at the end
  // of an Arabic label it would otherwise print detached on the far side.
  pw.Widget pair(String label, String value) => pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          printedText(label,
              style: style(size: 9, isBold: true)
                  .copyWith(color: PdfColors.grey700)),
          printedText(': ',
              style: style(size: 9, isBold: true)
                  .copyWith(color: PdfColors.grey700)),
          pw.Flexible(child: printedText(value, style: style(size: 9))),
        ],
      );

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: pw.ThemeData.withFont(
        base: font,
        bold: bold,
        fontFallback: [arabic],
      ),
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 40),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: accentClr, width: 2)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    printedText(l.stockMoves,
                        style: style(size: 22, isBold: true)
                            .copyWith(color: inkClr)),
                    pw.SizedBox(height: 6),
                    pair(l.rptColCompany, companyName),
                    if (period != null)
                      pair(l.periodLabel, stockPeriodLabel(dates, period)),
                    if (warehouseName != null) pair(l.warehouse, warehouseName),
                    if (search != null && search.isNotEmpty)
                      pair(l.filterLabel, search),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  printedText(dates.date.format(dates.toDisplayZone(now)),
                      style: style(size: 11, isBold: true)
                          .copyWith(color: inkClr)),
                  printedText(l.stockMovesCount(moves.length),
                      style: style(size: 9).copyWith(color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Table(
          border: const pw.TableBorder(
            top: pw.BorderSide(color: borderClr, width: 0.5),
            bottom: pw.BorderSide(color: borderClr, width: 0.5),
            left: pw.BorderSide(color: borderClr, width: 0.5),
            right: pw.BorderSide(color: borderClr, width: 0.5),
            horizontalInside: pw.BorderSide(color: borderClr, width: 0.4),
            verticalInside: pw.BorderSide(color: borderClr, width: 0.4),
          ),
          columnWidths: {
            for (var i = 0; i < columns.length; i++)
              i: _pdfWidths[columns[i]] ?? const pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: headerBg),
              children: [
                for (final column in columns)
                  cell(stockMoveColumnLabel(l, column),
                      header: true,
                      end: column == 'quantity',
                      color: headerFg),
              ],
            ),
            for (var i = 0; i < moves.length; i++)
              pw.TableRow(
                decoration:
                    pw.BoxDecoration(color: i.isEven ? rowEvenBg : rowOddBg),
                children: [
                  for (final column in columns)
                    cell(
                      stockMoveCellText(l, dates, moves[i], column),
                      end: column == 'quantity',
                      color: column == 'quantity'
                          ? (moves[i].isIncoming ? inClr : outClr)
                          : null,
                    ),
                ],
              ),
          ],
        ),
      ],
      footer: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: borderClr, width: 0.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            printedText(dates.dateTimeSeconds.format(dates.toDisplayZone(now)),
                style: style(size: 7.5).copyWith(color: PdfColors.grey600)),
            printedText(
                l.rptPageOf('${ctx.pageNumber}', '${ctx.pagesCount}'),
                style: style(size: 7.5).copyWith(color: PdfColors.grey600)),
          ],
        ),
      ),
    ),
  );
  return pdf.save();
}

const _pdfWidths = <String, pw.TableColumnWidth>{
  'date': pw.FixedColumnWidth(72),
  // Flexible: an adjustment's `Product Quantity Updated (…)` is long.
  'reference': pw.FlexColumnWidth(1.8),
  'product': pw.FlexColumnWidth(2.2),
  'from': pw.FlexColumnWidth(1.2),
  'to': pw.FlexColumnWidth(1.2),
  'quantity': pw.FixedColumnWidth(64),
  'status': pw.FixedColumnWidth(62),
};
