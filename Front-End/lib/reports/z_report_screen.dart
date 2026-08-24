import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/cart/payment_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/reports/z_report_model.dart';
import 'package:pos_app/reports/z_report_provider.dart';
import 'package:pos_app/reports/z_report_receipt_dialog.dart';
import 'package:pos_app/reports/z_report_service.dart';
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
      showAppSnackbar(
          context, ref, AppLocalizations.of(context).errorMissingCompanyContext,
          isError: true);
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // One implementation, shared with Close Register — see
      // `reports/z_report_service.dart`. It aggregates from local Drift, writes
      // the row, stamps what it reported and hands back the slip, all offline.
      final report = await ZReportService.generate(
        db: ref.read(appDatabaseProvider),
        companyId: companyId,
        userId: currentUser.id,
        scope: ZReportScope.company,
      );

      ref.invalidate(unreportedPaymentsProvider);
      ref.invalidate(allZReportsProvider);

      if (report == null) {
        if (mounted) {
          showAppSnackbar(
              context, ref, AppLocalizations.of(context).nothingToReport);
        }
        return;
      }

      // Best-effort push so the server-authoritative Z-report syncs when online.
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});

      // Show the freshly-computed report (result + print button) instantly.
      if (mounted) await showZReportDialog(context, ref, report);
    } catch (e) {
      if (mounted) {
        showAppSnackbar(
            context, ref, AppLocalizations.of(context).failedToQueueZReport('$e'),
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
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
                  tooltip: AppLocalizations.of(context).menuLabel,
                  onPressed: widget.onMenuPressed,
                )
              : null,
          title: Text(AppLocalizations.of(context).endOfDay),
          centerTitle: false,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            tabs: [
              Tab(text: AppLocalizations.of(context).currentShiftOpen),
              Tab(text: AppLocalizations.of(context).historyZReports),
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
                      label: Text(AppLocalizations.of(context).closeRegister),
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
            _ZReportHistoryTab(
              onViewReceipt: (report) =>
                  showZReportDialog(context, ref, report),
            ),
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
    final l = AppLocalizations.of(context);

    return asyncUnreported.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          l.errorWithMessage('$e'),
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
                  l.noOpenTransactions,
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
          final typeName = p.paymentTypeName ?? l.unknownLabel;
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
                          l.tenderBreakdown,
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
                                l.expectedInDrawer,
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
                          l.shiftDetails,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildDetailRow(
                          l.cashierOnDuty,
                          ref.watch(currentUserProvider)?.displayName ??
                              l.unknownUser,
                          Icons.person_outline,
                          theme,
                        ),
                        const SizedBox(height: 24),
                        _buildDetailRow(
                          l.transactionsLabel,
                          l.openPaymentsCount(payments.length),
                          Icons.receipt_long,
                          theme,
                        ),
                        const SizedBox(height: 24),
                        _buildDetailRow(
                          l.statusLabel,
                          l.shiftIsOpen,
                          Icons.lock_open,
                          theme,
                          iconColor: context.successColor,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          l.closeRegisterExplain,
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
    final l = AppLocalizations.of(context);

    return asyncReports.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          l.errorWithMessage('$e'),
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
                  l.noZReportsYet,
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
                  l.zReportOnDate(
                    report.dateCreated.toIso8601String().split('T').first,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    l.zReportSubtitle(
                      report.documentCount?.toString() ?? '—',
                      "${report.grandTotal.toStringAsFixed(2)} $sym",
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                trailing: Tooltip(
                  message: l.viewPrintReceipt,
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
