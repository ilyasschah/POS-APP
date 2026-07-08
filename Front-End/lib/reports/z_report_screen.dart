import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/cart/payment_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/reports/z_report_model.dart';
import 'package:pos_app/reports/z_report_provider.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/printer/receipt_printer_service.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class EndOfDayScreen extends ConsumerStatefulWidget {
  /// Opens the POS navigation drawer. Supplied by MainLayout; when null the
  /// app-bar menu button is hidden (e.g. if the screen is ever pushed as a
  /// standalone route).
  final VoidCallback? onMenuPressed;

  const EndOfDayScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<EndOfDayScreen> createState() => _EndOfDayScreenState();
}

class _EndOfDayScreenState extends ConsumerState<EndOfDayScreen> {
  bool _isGenerating = false;

  Future<void> _closeRegister() async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    final currentUser = ref.read(currentUserProvider);

    if (companyId == null || currentUser == null) {
      showAppSnackbar(context, ref, "Error: Missing company or user context.",
          isError: true);
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // OFFLINE-FIRST: aggregate the Z-report from local Drift right now so the
      // cashier sees the result + print button instantly — no server wait. The
      // sync engine still pushes /ZReports/Generate later; the server's
      // authoritative number backfills into history on the next pull.
      final db = ref.read(appDatabaseProvider);
      final now = DateTime.now().toUtc();

      // Tender breakdown from unreported payments (read BEFORE we flag them).
      final payments = await ref.read(unreportedPaymentsProvider.future);
      final byType = <int, ({String name, double amount})>{};
      double totalSales = 0;
      for (final p in payments) {
        totalSales += p.amount;
        final cur = byType[p.paymentTypeId];
        byType[p.paymentTypeId] = (
          name: p.paymentTypeName ?? 'Unknown',
          amount: (cur?.amount ?? 0) + p.amount,
        );
      }

      // Cash in/out from the active (unfinalized) drawer movements.
      final cashRows = await db.getActiveStartingCash(companyId);
      double totalCashIn = 0, totalCashOut = 0;
      for (final c in cashRows) {
        if (c.type == 'in') {
          totalCashIn += c.amount;
        } else if (c.type == 'out') {
          totalCashOut += c.amount;
        }
      }

      final breakdownJson = jsonEncode(byType.entries
          .map((e) => {
                'paymentTypeId': e.key,
                'paymentTypeName': e.value.name,
                'totalAmount': e.value.amount,
              })
          .toList());

      await db.insertOfflineZReport(
        ZReportsTableCompanion.insert(
          localId: '', // helper fills a UUID when blank
          companyId: companyId,
          userId: currentUser.id,
          totalSales: totalSales,
          totalCashIn: totalCashIn,
          totalCashOut: totalCashOut,
          paymentBreakdownJson: breakdownJson,
          closedAt: now,
        ),
      );

      // Optimistic local finalization: flag the just-reported payments and the
      // active cash movements so they drop out of the "current shift" view
      // immediately. The next pull swaps the -1 placeholder for the server's
      // real Z-report number.
      await db.assignUnreportedPaymentsToZReport(companyId);
      await db.optimisticallyFinalizeActiveStartingCash(companyId);

      ref.invalidate(unreportedPaymentsProvider);
      ref.invalidate(allZReportsProvider);
      // Best-effort push so the server-authoritative Z-report syncs when online.
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});

      // Show the freshly-computed report (result + print button) instantly.
      if (mounted) {
        _showReceiptDialog(ZReportModel(
          id: 0,
          companyId: companyId,
          number: 0, // server assigns the real number on sync
          dateCreated: now,
          fromDocumentId: 0,
          toDocumentId: 0,
          totalSales: totalSales,
          totalReturns: 0,
          discountsGranted: 0,
          taxableTotal: 0,
          totalTax: 0,
          grandTotal: totalSales,
          totalCashIn: totalCashIn,
          totalCashOut: totalCashOut,
          paymentSummaries: byType.entries
              .map((e) => ZReportPaymentSummaryModel(
                    id: 0,
                    zReportId: 0,
                    paymentTypeId: e.key,
                    paymentTypeName: e.value.name,
                    totalAmount: e.value.amount,
                  ))
              .toList(),
        ));
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Failed to queue Z-Report: $e',
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _showReceiptDialog(ZReportModel report) {
    final sym = ref.read(currencySymbolProvider);
    final theme = Theme.of(context);

    showDialog(
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
              "Z-Report #${report.number}",
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
                  "SHIFT SUMMARY",
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
                _receiptRow(
                  "Date/Time",
                  report.dateCreated
                      .toIso8601String()
                      .split('.')[0]
                      .replaceFirst('T', ' '),
                  theme,
                ),
                _receiptRow(
                  "Documents",
                  "#${report.fromDocumentId} to #${report.toDocumentId}",
                  theme,
                ),
                const SizedBox(height: 8),
                Divider(color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 8),
                _receiptRow(
                  "Total Sales",
                  "${report.totalSales.toStringAsFixed(2)} $sym",
                  theme,
                ),
                _receiptRow(
                  "Total Returns",
                  "${report.totalReturns.toStringAsFixed(2)} $sym",
                  theme,
                ),
                _receiptRow(
                  "Discounts",
                  "${report.discountsGranted.toStringAsFixed(2)} $sym",
                  theme,
                ),
                _receiptRow(
                  "Taxable Total",
                  "${report.taxableTotal.toStringAsFixed(2)} $sym",
                  theme,
                ),
                _receiptRow(
                  "Total Tax",
                  "${report.totalTax.toStringAsFixed(2)} $sym",
                  theme,
                ),
                const SizedBox(height: 8),
                Divider(color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 8),
                Text(
                  "CASH MOVEMENTS",
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
                _receiptRow(
                  "Cash In",
                  "+${report.totalCashIn.toStringAsFixed(2)} $sym",
                  theme,
                ),
                _receiptRow(
                  "Cash Out",
                  "-${report.totalCashOut.toStringAsFixed(2)} $sym",
                  theme,
                ),
                const SizedBox(height: 16),
                Text(
                  "TENDER TYPES",
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
                    "No payments recorded.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ...report.paymentSummaries.map(
                  (p) => _receiptRow(
                    p.paymentTypeName ?? "Unknown",
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
                  child: _receiptRow(
                    "GRAND TOTAL",
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
            child: const Text("Close"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text("Print Receipt"),
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

  Widget _receiptRow(
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: widget.onMenuPressed != null
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: "Menu",
                  onPressed: widget.onMenuPressed,
                )
              : null,
          title: const Text("End of Day"),
          centerTitle: false,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            tabs: const [
              Tab(text: "Current Shift (Open)"),
              Tab(text: "History (Z-Reports)"),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: _isGenerating
                  ? Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.lock_clock),
                      label: const Text("Close Register"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.errorContainer,
                        foregroundColor: theme.colorScheme.onErrorContainer,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _closeRegister,
                    ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _CurrentShiftTab(),
            _ZReportHistoryTab(onViewReceipt: _showReceiptDialog),
          ],
        ),
      ),
    );
  }
}

// --- TAB 1: CURRENT SHIFT PREVIEW ---
class _CurrentShiftTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUnreported = ref.watch(unreportedPaymentsProvider);
    final theme = Theme.of(context);

    return asyncUnreported.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          "Error: $e",
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
      data: (payments) {
        if (payments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  "No open transactions.\nThe register is balanced.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        final Map<String, double> totalsByType = {};
        double grandTotal = 0;

        for (var p in payments) {
          final typeName = p.paymentTypeName ?? "Unknown";
          totalsByType[typeName] = (totalsByType[typeName] ?? 0) + p.amount;
          grandTotal += p.amount;
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT PANEL: Breakdown Card
              Expanded(
                flex: 1,
                child: Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Tender Breakdown",
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ...totalsByType.entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  e.key,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  e.value.toStringAsFixed(2),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "EXPECTED IN DRAWER",
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                grandTotal.toStringAsFixed(2),
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // RIGHT PANEL: Details Card
              Expanded(
                flex: 1,
                child: Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Shift Details",
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildDetailRow(
                          "Cashier on Duty",
                          ref.watch(currentUserProvider)?.displayName ??
                              "UNKNOWN USER",
                          Icons.person_outline,
                          theme,
                        ),
                        const SizedBox(height: 24),
                        _buildDetailRow(
                          "Transactions",
                          "${payments.length} open payment(s)",
                          Icons.receipt_long,
                          theme,
                        ),
                        const SizedBox(height: 24),
                        _buildDetailRow(
                          "Status",
                          "Shift is Open",
                          Icons.lock_open,
                          theme,
                          iconColor: Colors.green,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          "Closing the register will finalize these transactions, generate a Z-Report, and reset the day's totals. Ensure cash drops are complete before proceeding.",
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    ThemeData theme, {
    Color? iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (iconColor ?? theme.colorScheme.primary).withValues(
              alpha: 0.1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor ?? theme.colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- TAB 2: Z-REPORT HISTORY ---
class _ZReportHistoryTab extends ConsumerWidget {
  final Function(ZReportModel) onViewReceipt;

  const _ZReportHistoryTab({required this.onViewReceipt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sym = ref.watch(currencySymbolProvider);
    final asyncReports = ref.watch(allZReportsProvider);
    final theme = Theme.of(context);

    return asyncReports.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          "Error: $e",
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
      data: (reports) {
        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "No Z-Reports generated yet.",
                  style: TextStyle(
                    fontSize: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return Card(
              elevation: 0,
              color: theme.colorScheme.surface,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "#${report.number}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Text(
                  "Z-Report • ${report.dateCreated.toIso8601String().split('T').first}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    "Documents: #${report.fromDocumentId} - #${report.toDocumentId}  •  Grand Total: ${report.grandTotal.toStringAsFixed(2)} $sym",
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                trailing: Tooltip(
                  message: "View & Print Receipt",
                  child: IconButton(
                    icon: Icon(
                      Icons.receipt_long,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () => onViewReceipt(report),
                    splashRadius: 24,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
