import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/core/ilyass_screen.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/printer/pdf_file_name.dart';
import 'package:pos_app/printer/pdf_save_service.dart';
import 'package:pos_app/stock/stock_move_line.dart';
import 'package:pos_app/stock/stock_moves_export.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// Print / Save as PDF / Export to Excel for any table of stock moves — the
/// Stock Moves screen and a product's Stock History tab run the same code, so
/// the two can never write a different report of the same moves.

enum StockMovesExportFormat { print, pdf, excel }

/// The three export actions for a ⋮ menu. The labels say what will be
/// written: the ticked rows, by count, or — with none ticked — everything the
/// view's filters match.
List<IlyassMenuAction> stockMovesExportActions(
  AppLocalizations l, {
  required int selectedCount,
  required void Function(StockMovesExportFormat format) onExport,
  bool dividerBefore = true,
}) =>
    [
      IlyassMenuAction(
        icon: Icons.print_outlined,
        label: selectedCount == 0
            ? l.printPdf
            : l.printSelectedPdf(selectedCount),
        dividerBefore: dividerBefore,
        onSelected: () => onExport(StockMovesExportFormat.print),
      ),
      IlyassMenuAction(
        icon: Icons.picture_as_pdf_outlined,
        label: selectedCount == 0
            ? l.saveAsPdf
            : l.saveSelectedAsPdf(selectedCount),
        onSelected: () => onExport(StockMovesExportFormat.pdf),
      ),
      IlyassMenuAction(
        icon: Icons.table_view_outlined,
        label: selectedCount == 0
            ? l.exportToExcel
            : l.exportSelectedToExcel(selectedCount),
        onSelected: () => onExport(StockMovesExportFormat.excel),
      ),
    ];

/// Writes [selected] when rows are ticked; otherwise whatever [loadAll] reads
/// — every move the view's filters match, not just the pages scrolled into
/// view. Either way in [columns], the columns and order on screen.
///
/// The filters are printed on the PDF's header so a sheet says what it
/// covers. Every outcome — saved, cancelled, nothing to write, failed — ends
/// in a snackbar or in silence, never in an exception.
Future<void> runStockMovesExport({
  required BuildContext context,
  required WidgetRef ref,
  required StockMovesExportFormat format,
  required List<StockMoveLine>? selected,
  required Future<List<StockMoveLine>> Function(int companyId) loadAll,
  required List<String> columns,
  String? warehouseName,
  String? search,
  DateTimeRange? period,
}) async {
  final l = AppLocalizations.of(context);
  final company = ref.read(selectedCompanyProvider);
  if (company == null) return;
  final dates = ref.read(appDateFormatProvider);

  try {
    final moves = selected ?? await loadAll(company.id);
    if (!context.mounted) return;
    if (moves.isEmpty) {
      showAppSnackbar(context, ref, l.noStockMovesToExport);
      return;
    }

    final name = stockMovesFileName(DateTime.now());
    String? savedTo;
    switch (format) {
      case StockMovesExportFormat.excel:
        savedTo = await saveFileAs(
          bytes: buildStockMovesXlsx(
              l: l, dates: dates, moves: moves, columns: columns),
          fileName: '$name.xlsx',
          extension: 'xlsx',
          dialogTitle: l.saveExportFileTitle,
        );
      case StockMovesExportFormat.pdf || StockMovesExportFormat.print:
        final bytes = await buildStockMovesPdf(
          l: l,
          dates: dates,
          moves: moves,
          columns: columns,
          companyName: company.name,
          warehouseName: warehouseName,
          search: search,
          period: period,
        );
        if (format == StockMovesExportFormat.print) {
          await Printing.layoutPdf(
            onLayout: (_) async => bytes,
            // No '.pdf' — the platform appends the extension to a job name.
            name: name,
            format: PdfPageFormat.a4.landscape,
          );
        } else {
          savedTo = await savePdfAs(
              bytes: bytes, suggestedName: name, dialogTitle: l.saveAsPdf);
        }
    }
    if (!context.mounted || savedTo == null) return;
    showAppSnackbar(context, ref, l.savedToPath(savedTo));
  } catch (e) {
    if (!context.mounted) return;
    showAppSnackbar(context, ref, l.exportFailed('$e'), isError: true);
  }
}
