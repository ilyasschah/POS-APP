/// The Z-report slip as a dialog — the shared "here is your report, print it"
/// surface.
///
/// Extracted from `EndOfDayScreen` when closing a POS session started producing
/// a Z-report of its own (see `z_report_service.dart`). Both entry points show
/// the identical breakdown and print through the identical call, because a
/// cashier comparing the slip from Close Register with the one from End of Day
/// must not find them laid out differently.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/printer/receipt_printer_service.dart';
import 'package:pos_app/reports/z_report_model.dart';

/// Shows [report] and offers to print it.
///
/// A report with `number == 0` is a PREVIEW (see `ZReportService.preview`) —
/// nothing has been persisted and no number has been taken from the sequence,
/// so the title says so instead of claiming to be Z-report zero.
Future<void> showZReportDialog(
  BuildContext context,
  WidgetRef ref,
  ZReportModel report,
) {
  final sym = ref.read(currencySymbolProvider);
  final theme = Theme.of(context);
  final l = AppLocalizations.of(context);

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        children: [
          Icon(
            Icons.receipt_long,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            report.number == 0
                ? l.zReportPreview
                : l.zReportNumber('${report.number}'),
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.shiftSummaryUpper,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 2,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 8),
              _row(
                l.dateTimeLabel,
                report.dateCreated
                    .toIso8601String()
                    .split('.')[0]
                    .replaceFirst('T', ' '),
                theme,
              ),
              _row(
                l.documents,
                report.documentCount?.toString() ?? "—",
                theme,
              ),
              if (report.fromDocumentNumber != null)
                _row(
                  l.rangeLabel,
                  report.fromDocumentNumber == report.toDocumentNumber
                      ? report.fromDocumentNumber!
                      : "${report.fromDocumentNumber} → ${report.toDocumentNumber}",
                  theme,
                ),
              const SizedBox(height: 8),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 8),
              _row(
                l.totalSales,
                "${report.totalSales.toStringAsFixed(2)} $sym",
                theme,
              ),
              _row(
                l.totalReturns,
                "${report.totalReturns.toStringAsFixed(2)} $sym",
                theme,
              ),
              _row(
                l.discountsLabel,
                "${report.discountsGranted.toStringAsFixed(2)} $sym",
                theme,
              ),
              _row(
                l.taxableTotal,
                "${report.taxableTotal.toStringAsFixed(2)} $sym",
                theme,
              ),
              _row(
                l.totalTax,
                "${report.totalTax.toStringAsFixed(2)} $sym",
                theme,
              ),
              const SizedBox(height: 8),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 8),
              Text(
                l.cashMovementsUpper,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 2,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 8),
              _row(
                l.cashIn,
                "+${report.totalCashIn.toStringAsFixed(2)} $sym",
                theme,
              ),
              _row(
                l.cashOut,
                "-${report.totalCashOut.toStringAsFixed(2)} $sym",
                theme,
              ),
              const SizedBox(height: 16),
              Text(
                l.tenderTypesUpper,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 2,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 8),
              if (report.paymentSummaries.isEmpty)
                Text(
                  l.noPaymentsRecorded,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ...report.paymentSummaries.map(
                (p) => _row(
                  p.paymentTypeName ?? l.unknownLabel,
                  "${p.totalAmount.toStringAsFixed(2)} $sym",
                  theme,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _row(
                  l.grandTotalUpper,
                  "${report.grandTotal.toStringAsFixed(2)} $sym",
                  theme,
                  isBold: true,
                  overrideColor: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(AppLocalizations.of(context).actionClose),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.print),
          label: Text(AppLocalizations.of(context).printReceipt),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () async {
            Navigator.of(ctx).pop();
            await ReceiptPrinterService().printZReport(
              report,
              sym,
              roleSettings: ref.read(appSettingsProvider),
            );
          },
        ),
      ],
    ),
  );
}

Widget _row(
  String label,
  String value,
  ThemeData theme, {
  bool isBold = false,
  Color? overrideColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 16 : 14,
            color: overrideColor ?? theme.colorScheme.onSurface,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 18 : 14,
            color: overrideColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    ),
  );
}
