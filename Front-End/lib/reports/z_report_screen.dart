import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/cart/payment_model.dart';
import 'package:pos_app/cart/payment_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/app_date_picker.dart';
import 'package:pos_app/core/ilyass_column_order.dart';
import 'package:pos_app/core/ilyass_list_scaffold.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/reports/z_report_model.dart';
import 'package:pos_app/reports/z_report_provider.dart';
import 'package:pos_app/reports/z_report_receipt_dialog.dart';
import 'package:pos_app/reports/z_report_service.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// End of Day: the Z-report HISTORY is the screen, and closing the register is
/// one red button on top of it.
///
/// It used to be two tabs — a "Current Shift" preview nobody could act on
/// directly, and the history behind it. The preview only ever said one thing
/// that mattered ("there is money still to report"), and the button that acted
/// on it lived in the app bar, far from the numbers. Now:
///
///  * The history IS the body, as an `IlyassTable` with the unified search bar
///    and the app's date-range picker.
///  * Close Register is a red FAB that **only exists when there is something to
///    close**. An empty till has no button to press, so the "Nothing to report"
///    dead end is unreachable rather than merely handled.
///  * The old preview's numbers are not lost: they are the confirmation sheet
///    the FAB opens, which is where an operator actually wants them — right
///    before committing, not on a tab beside it.
String _zColumnLabel(BuildContext context, String id) {
  final l = AppLocalizations.of(context);
  switch (id) {
    case 'Number':
      return l.numberLabel;
    case 'Date':
      return l.dateLabel;
    case 'Documents':
      return l.documents;
    case 'Range':
      return l.rangeLabel;
    case 'Sales':
      return l.totalSales;
    case 'Returns':
      return l.totalReturns;
    case 'Discounts':
      return l.totalDiscounts;
    case 'Tax':
      return l.totalTax;
    case 'Cash In':
      return l.cashIn;
    case 'Cash Out':
      return l.cashOut;
    case 'Total':
      return l.totalLabel;
    case 'Actions':
      return l.actions;
    default:
      return id;
  }
}

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
  final _searchCtrl = TextEditingController();
  final _dateFmt = DateFormat('dd/MM/yy');
  final _stampFmt = DateFormat('dd/MM/yy HH:mm');

  String _query = '';
  DateTimeRange? _period;
  bool _isGenerating = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── filtering ─────────────────────────────────────────────────────────────

  List<ZReportModel> _visible(List<ZReportModel> all) {
    final q = _query.trim().toLowerCase();
    return all.where((r) {
      final period = _period;
      if (period != null) {
        final day = DateTime(
            r.dateCreated.year, r.dateCreated.month, r.dateCreated.day);
        final from =
            DateTime(period.start.year, period.start.month, period.start.day);
        final to = DateTime(period.end.year, period.end.month, period.end.day);
        if (day.isBefore(from) || day.isAfter(to)) return false;
      }
      if (q.isEmpty) return true;
      // Number and date, because those are the two things written on the slip
      // an operator is holding when they come looking for one.
      return '${r.number}'.contains(q) ||
          _stampFmt.format(r.dateCreated).toLowerCase().contains(q) ||
          (r.fromDocumentNumber?.toLowerCase().contains(q) ?? false) ||
          (r.toDocumentNumber?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void _setPeriod(DateTimeRange? range) => setState(() => _period = range);

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final range = await showAppDateRangePicker(
      context,
      initialStart: _period?.start ?? DateTime(now.year, now.month, 1),
      initialEnd: _period?.end ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (range == null || !mounted) return;
    _setPeriod(range);
  }

  List<FilterMenuSection> _filterSections() {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTimeRange monthOf(int monthsBack) {
      final first = DateTime(now.year, now.month - monthsBack, 1);
      final last = DateTime(now.year, now.month - monthsBack + 1, 0);
      return DateTimeRange(start: first, end: last);
    }

    bool isCurrent(DateTimeRange r) =>
        _period != null &&
        _period!.start.difference(r.start).inDays == 0 &&
        _period!.end.difference(r.end).inDays == 0;

    final ranges = <String, DateTimeRange>{
      l.today: DateTimeRange(start: today, end: today),
      l.thisMonth: monthOf(0),
      l.lastMonth: monthOf(1),
    };

    return [
      FilterMenuSection(
        title: l.periodLabel,
        icon: Icons.date_range_outlined,
        options: [
          for (final entry in ranges.entries)
            FilterMenuOption(
              label: entry.key,
              icon: Icons.event,
              selected: isCurrent(entry.value),
              // Re-picking the active period clears it, so the same row both
              // sets and unsets — there is no separate "all dates" entry to
              // hunt for.
              onSelected: () =>
                  _setPeriod(isCurrent(entry.value) ? null : entry.value),
            ),
          FilterMenuOption(
            label: l.filterCustomRange,
            icon: Icons.edit_calendar_outlined,
            onSelected: _pickPeriod,
          ),
        ],
      ),
    ];
  }

  // ── closing the register ──────────────────────────────────────────────────

  /// Shows what is about to be reported, then generates on confirmation.
  Future<void> _closeRegister(List<PaymentModel> unreported) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _CloseRegisterSheet(payments: unreported),
    );
    if (confirmed != true || !mounted) return;

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
        // Only reachable if the last payment was reported by another terminal
        // between the FAB appearing and this tap.
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
        showAppSnackbar(context, ref,
            AppLocalizations.of(context).failedToQueueZReport('$e'),
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  // ── columns ───────────────────────────────────────────────────────────────

  void _showColumnPicker() {
    final catalogue = ref.read(zReportVisibleColumnsProvider).keys.toList();

    showIlyassColumnPicker(
      context: context,
      tableId: 'zReports',
      columns: [
        for (final key in catalogue)
          IlyassPickerColumn(
            key: key,
            label: _zColumnLabel(context, key),
            mandatory: key == 'Number',
          ),
      ],
      isVisible: (key) => ref.read(zReportVisibleColumnsProvider)[key] ?? false,
      onVisibleChanged: (key, value) => ref
          .read(zReportVisibleColumnsProvider.notifier)
          .update((s) => {...s, key: value}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sym = ref.watch(currencySymbolProvider);
    final asyncReports = ref.watch(allZReportsProvider);
    final visibleColumns = ref.watch(zReportVisibleColumnsProvider);

    // 🚨 The FAB's whole existence hangs off this: no unreported payment means
    // no Z-report to write, so there is no button to press.
    final unreported =
        ref.watch(unreportedPaymentsProvider).value ?? const <PaymentModel>[];

    String money(double v) => '${v.toStringAsFixed(2)} $sym';

    return IlyassListScaffold(
      title: l.endOfDay,
      onMenuPressed: widget.onMenuPressed,
      searchBar: UnifiedSearchBar(
        controller: _searchCtrl,
        singleLine: true,
        hintText: l.actionSearch,
        chips: [
          if (_period != null)
            SearchBarChip(
              id: 'period',
              label:
                  '${_dateFmt.format(_period!.start)} - ${_dateFmt.format(_period!.end)}',
              icon: Icons.date_range_outlined,
              onRemove: () => _setPeriod(null),
            ),
        ],
        sectionsBuilder: (_) => _filterSections(),
        onQueryChanged: (value) => setState(() => _query = value),
        onClearAll: () {
          _searchCtrl.clear();
          setState(() {
            _query = '';
            _period = null;
          });
        },
      ),
      actions: [
        IlyassMenuAction(
          icon: Icons.date_range_outlined,
          label: l.filterCustomRange,
          onSelected: _pickPeriod,
        ),
        IlyassMenuAction(
          icon: Icons.view_column_rounded,
          label: l.columnsTooltip,
          dividerBefore: true,
          onSelected: _showColumnPicker,
        ),
        IlyassMenuAction(
          icon: Icons.refresh,
          label: l.refreshTooltip,
          onSelected: () {
            ref.invalidate(allZReportsProvider);
            ref.invalidate(unreportedPaymentsProvider);
          },
        ),
      ],
      floatingActionButton: unreported.isEmpty
          ? null
          : FloatingActionButton.extended(
              // Its own tag: MainLayout keeps screens alive side by side, and
              // the default tag is a shared constant.
              heroTag: 'eod-close-register',
              backgroundColor: context.dangerColor,
              foregroundColor: context.onStatusColor,
              onPressed:
                  _isGenerating ? null : () => _closeRegister(unreported),
              icon: _isGenerating
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.onStatusColor,
                      ),
                    )
                  : const Icon(Icons.lock_clock),
              label: Text(l.closeRegister),
            ),
      body: asyncReports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            l.errorWithMessage('$e'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
        data: (all) {
          final reports = _visible(all);

          // One entry per toggleable column, in the order the provider declares
          // them — the picker reorders this list, so widths and cells live with
          // their key rather than in a parallel chain.
          final catalogue = <String, IlyassColumn<ZReportModel>>{
            'Number': IlyassColumn<ZReportModel>(
              key: 'Number',
              label: _zColumnLabel(context, 'Number'),
              width: 100,
              minWidth: 80,
              cell: (context, r) => Text(
                '#${r.number}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            'Date': IlyassColumn<ZReportModel>(
              key: 'Date',
              label: _zColumnLabel(context, 'Date'),
              width: 150,
              cell: (context, r) => Text(_stampFmt.format(r.dateCreated),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            'Documents': IlyassColumn<ZReportModel>(
              key: 'Documents',
              label: _zColumnLabel(context, 'Documents'),
              width: 120,
              numeric: true,
              cell: (context, r) => Text(r.documentCount?.toString() ?? '—'),
            ),
            'Range': IlyassColumn<ZReportModel>(
              key: 'Range',
              label: _zColumnLabel(context, 'Range'),
              width: 260,
              minWidth: 140,
              flexible: true,
              cell: (context, r) {
                // Server-sourced rows carry only the int id range, which means
                // nothing to an operator, so they show a dash rather than a lie.
                final from = r.fromDocumentNumber;
                final to = r.toDocumentNumber;
                return Text(
                  from == null || to == null ? '—' : '$from → $to',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                );
              },
            ),
            'Sales': IlyassColumn<ZReportModel>(
              key: 'Sales',
              label: _zColumnLabel(context, 'Sales'),
              width: 140,
              numeric: true,
              cell: (context, r) => Text(money(r.totalSales)),
            ),
            'Returns': IlyassColumn<ZReportModel>(
              key: 'Returns',
              label: _zColumnLabel(context, 'Returns'),
              width: 140,
              numeric: true,
              cell: (context, r) => Text(money(r.totalReturns)),
            ),
            'Discounts': IlyassColumn<ZReportModel>(
              key: 'Discounts',
              label: _zColumnLabel(context, 'Discounts'),
              width: 140,
              numeric: true,
              cell: (context, r) => Text(money(r.discountsGranted)),
            ),
            'Tax': IlyassColumn<ZReportModel>(
              key: 'Tax',
              label: _zColumnLabel(context, 'Tax'),
              width: 130,
              numeric: true,
              cell: (context, r) => Text(money(r.totalTax)),
            ),
            'Cash In': IlyassColumn<ZReportModel>(
              key: 'Cash In',
              label: _zColumnLabel(context, 'Cash In'),
              width: 130,
              numeric: true,
              cell: (context, r) => Text(money(r.totalCashIn)),
            ),
            'Cash Out': IlyassColumn<ZReportModel>(
              key: 'Cash Out',
              label: _zColumnLabel(context, 'Cash Out'),
              width: 130,
              numeric: true,
              cell: (context, r) => Text(money(r.totalCashOut)),
            ),
            'Total': IlyassColumn<ZReportModel>(
              key: 'Total',
              label: _zColumnLabel(context, 'Total'),
              width: 150,
              numeric: true,
              cell: (context, r) => Text(
                money(r.grandTotal),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          };

          return IlyassTable<ZReportModel>(
            tableId: 'zReports',
            rows: reports,
            rowHeight: 56,
            onRowTap: (r) => showZReportDialog(context, ref, r),
            columns: [
              for (final entry in catalogue.entries)
                if (visibleColumns[entry.key] == true) entry.value,
              IlyassColumn<ZReportModel>(
                key: 'Actions',
                label: _zColumnLabel(context, 'Actions'),
                width: 80,
                minWidth: 80,
                resizable: false,
                cell: (context, r) => IconButton(
                  icon: const Icon(Icons.receipt_long, size: 20),
                  color: theme.colorScheme.primary,
                  tooltip: l.viewPrintReceipt,
                  onPressed: () => showZReportDialog(context, ref, r),
                ),
              ),
            ],
            emptyState: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history,
                        size: 64,
                        color: theme.disabledColor.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      all.isEmpty ? l.noZReportsYet : l.noResultsForFilters,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.hintColor, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The confirmation sheet — the old "Current Shift" tab, moved to where it acts
// ---------------------------------------------------------------------------
class _CloseRegisterSheet extends ConsumerWidget {
  const _CloseRegisterSheet({required this.payments});

  final List<PaymentModel> payments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final sym = ref.watch(currencySymbolProvider);

    final totalsByType = <String, double>{};
    var grandTotal = 0.0;
    for (final p in payments) {
      final typeName = p.paymentTypeName ?? l.unknownLabel;
      totalsByType[typeName] = (totalsByType[typeName] ?? 0) + p.amount;
      grandTotal += p.amount;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Icon(Icons.lock_clock, color: context.dangerColor),
        const SizedBox(width: 12),
        Expanded(child: Text(l.closeRegister)),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SectionLabel(l.tenderBreakdown),
              const SizedBox(height: 12),
              for (final e in totalsByType.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  // Ilyass Style: loose on both sides, spaceBetween — the
                  // amount reaches the right edge instead of stranding at the
                  // middle.
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        flex: 3,
                        child: Text(e.key,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Flexible(
                        flex: 2,
                        child: Text(
                          '${e.value.toStringAsFixed(2)} $sym',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 3,
                      child: Text(
                        l.expectedInDrawer,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Flexible(
                      flex: 2,
                      child: Text(
                        '${grandTotal.toStringAsFixed(2)} $sym',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(l.shiftDetails),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.person_outline,
                label: l.cashierOnDuty,
                value: ref.watch(currentUserProvider)?.displayName ??
                    l.unknownUser,
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.receipt_long,
                label: l.transactionsLabel,
                value: l.openPaymentsCount(payments.length),
              ),
              const SizedBox(height: 20),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.actionCancel),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: context.dangerColor,
            foregroundColor: context.onStatusColor,
          ),
          icon: const Icon(Icons.lock_clock, size: 18),
          label: Text(l.closeRegister),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 3,
          child: Text(label,
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
        ),
        const Spacer(),
        Flexible(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
