import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/app_date_picker.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/shift/shift_provider.dart';
import 'package:pos_app/time_clock/time_clock_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class ShiftManagementScreen extends ConsumerWidget {
  const ShiftManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).shiftManagement),
          bottom: TabBar(
            tabs: [
              Tab(
                  icon: const Icon(Icons.timer_outlined),
                  text: AppLocalizations.of(context).myShift),
              Tab(
                  icon: const Icon(Icons.bar_chart_outlined),
                  text: AppLocalizations.of(context).hoursReport),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ShiftTab(),
            _HoursTab(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB A — Existing shift management logic
// ─────────────────────────────────────────────────────────────────────────────

class _ShiftTab extends ConsumerWidget {
  const _ShiftTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(activeShiftProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(AppLocalizations.of(context).errorWithMessage(e.toString()))),
      data: (shift) =>
          shift == null ? _NoShiftView() : _ActiveShiftView(shift: shift),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BRANCH A — No active shift
// ─────────────────────────────────────────────────────────────────────────────

class _NoShiftView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NoShiftView> createState() => _NoShiftViewState();
}

class _NoShiftViewState extends ConsumerState<_NoShiftView> {
  bool _saving = false;

  Future<void> _startShift() async {
    setState(() => _saving = true);
    try {
      // Float tracking is deprecated; pass a static 0 so the underlying
      // shift row stays schema-valid without a cash-drawer step. This is the
      // station's master drawer shift (distinct from kiosk attendance rows).
      await ref
          .read(shiftNotifierProvider.notifier)
          .startShift(0, isDrawerShift: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final user = ref.watch(currentUserProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Card(
          color: theme.cardColor,
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock_clock,
                    size: 56, color: context.navAccent.withValues(alpha: 0.7)),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).noActiveShift,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  [user?.firstName, user?.lastName]
                      .whereType<String>()
                      .join(' ')
                      .trim(),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).beginTrackingSession,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _saving ? null : _startShift,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(AppLocalizations.of(context).startShift),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BRANCH B — Active shift dashboard
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveShiftView extends ConsumerStatefulWidget {
  final ShiftsTableData shift;
  const _ActiveShiftView({required this.shift});

  @override
  ConsumerState<_ActiveShiftView> createState() => _ActiveShiftViewState();
}

class _ActiveShiftViewState extends ConsumerState<_ActiveShiftView> {
  bool _closing = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Low-overhead live elapsed-time tracker: a single lightweight setState
    // once per minute is enough to advance the "Xh Ym" display, and costs
    // virtually nothing on low-spec tablets.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // Guarantee zero background processing once this view is gone.
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _endShift() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        title: Text(AppLocalizations.of(context).endShift),
        content: Text(AppLocalizations.of(context).endShiftConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(AppLocalizations.of(context).actionConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _closing = true);
    try {
      await ref.read(shiftNotifierProvider.notifier).closeShift(widget.shift);
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final shift = widget.shift;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    final duration = DateTime.now().difference(shift.openedAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Shift summary card ─────────────────────────────────────────
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_open,
                          color: cs.onPrimaryContainer, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).shiftOpen,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_closing)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimaryContainer),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${hours}h ${minutes}m',
                            style: TextStyle(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    label: AppLocalizations.of(context).openedAt,
                    value: fmt.format(shift.openedAt.toLocal()),
                    color: cs.onPrimaryContainer,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── End shift ──────────────────────────────────────────────────
          FilledButton.icon(
            onPressed: _closing ? null : _endShift,
            icon: const Icon(Icons.lock),
            label: Text(AppLocalizations.of(context).endShift),
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB B — Hours report
// ─────────────────────────────────────────────────────────────────────────────

class _HoursTab extends ConsumerStatefulWidget {
  const _HoursTab();

  @override
  ConsumerState<_HoursTab> createState() => _HoursTabState();
}

class _HoursTabState extends ConsumerState<_HoursTab> {
  late DateTimeRange _range;
  int? _selectedUserId;
  int _page = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
  }

  Future<void> _pickRange() async {
    final result = await showAppDateRangePicker(
      context,
      initialStart: _range.start,
      initialEnd: _range.end,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (result != null && mounted) {
      setState(() {
        _range = result;
        _page = 0;
      });
    }
  }

  void _doExport(
      BuildContext context, List<ShiftSessionRow> rows, String storeName) {
    if (rows.isEmpty) {
      showAppSnackbarRaw(
          context, AppLocalizations.of(context).nothingToExportInRange);
      return;
    }
    final openLabel = AppLocalizations.of(context).shiftStillOpen;
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    // CSV header stays English on purpose — it is a machine-readable column
    // header pasted into a spreadsheet, not screen text.
    final sb = StringBuffer('Clock in,Clock out,Employee,Store,Total Hours\n');
    for (final r in rows) {
      final emp = r.employeeName.contains(',')
          ? '"${r.employeeName}"'
          : r.employeeName;
      final store = storeName.contains(',') ? '"$storeName"' : storeName;
      final inStr = fmt.format(r.clockIn);
      final outStr = r.isOpen ? openLabel : fmt.format(r.clockOut!);
      final hrs = r.isOpen ? openLabel : _fmtHours(r.totalMinutes);
      sb.writeln('$inStr,$outStr,$emp,$store,$hrs');
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    showAppSnackbarRaw(
        context, AppLocalizations.of(context).reportCopiedAsCsv);
  }

  Future<void> _addTimeCard() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddTimeCardDialog(),
    );
    // The list is a live stream off shiftsTable, so the new row appears
    // instantly — no manual refresh needed.
    if (saved == true && mounted) {
      showAppSnackbarRaw(context, AppLocalizations.of(context).timeCardAdded);
    }
  }

  HoursQueryParams get _params {
    final companyId = ref.read(selectedCompanyProvider)?.id ?? 0;
    final start = _range.start;
    final end = _range.end;
    return (
      rangeStart: DateTime(start.year, start.month, start.day).toUtc(),
      rangeEnd:
          DateTime(end.year, end.month, end.day, 23, 59, 59).toUtc(),
      userId: _selectedUserId,
      companyId: companyId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final company = ref.watch(selectedCompanyProvider);
    final storeName = company?.name ?? '';
    final sessionsAsync = ref.watch(shiftSessionsProvider(_params));
    final allUsersAsync = ref.watch(allUsersProvider);

    final dateFmt = DateFormat('MMM d, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Unified filter + action bar (single horizontal line) ───────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Date range picker chip
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _pickRange,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: cs.outline.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        '${dateFmt.format(_range.start)}  –  ${dateFmt.format(_range.end)}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Employee dropdown — flexes to fill the gap before the actions
              Flexible(
                child: allUsersAsync.when(
                  loading: () => const SizedBox(
                      height: 44, child: LinearProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (users) => Container(
                    height: 44,
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: cs.outline.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedUserId,
                        isExpanded: true,
                        dropdownColor: theme.cardColor,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurface),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(AppLocalizations.of(context).allEmployees,
                                style: TextStyle(color: cs.onSurface)),
                          ),
                          ...users.map((u) {
                            final name = [u.firstName, u.lastName]
                                .whereType<String>()
                                .where((s) => s.isNotEmpty)
                                .join(' ')
                                .trim();
                            return DropdownMenuItem<int?>(
                              value: u.id,
                              child: Text(
                                name.isEmpty
                                    ? (u.username ??
                                        AppLocalizations.of(context)
                                            .userNumbered('${u.id}'))
                                    : name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: cs.onSurface),
                              ),
                            );
                          }),
                        ],
                        onChanged: (id) => setState(() {
                          _selectedUserId = id;
                          _page = 0;
                        }),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // ADD TIME CARD — framed admin action, mirrors EXPORT's frame.
              _FramedAction(
                icon: Icons.add_circle_outline,
                label: AppLocalizations.of(context).addTimeCardUpper,
                onPressed: _addTimeCard,
              ),

              const SizedBox(width: 12),

              // EXPORT — framed, touch-sized action pinned to the right
              _FramedAction(
                icon: Icons.file_download_outlined,
                label: AppLocalizations.of(context).colExport,
                onPressed: () => _doExport(context,
                    sessionsAsync.asData?.value ?? const [], storeName),
              ),
            ],
          ),
        ),

        // ── Report card ────────────────────────────────────────────────
        Expanded(
          child: sessionsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(AppLocalizations.of(context).errorWithMessage(e.toString()))),
            data: (rows) => _SessionsReportCard(
              rows: rows,
              page: _page,
              rowsPerPage: _rowsPerPage,
              onPageChanged: (p) => setState(() => _page = p),
              onRowsPerPageChanged: (r) =>
                  setState(() { _rowsPerPage = r; _page = 0; }),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOURS REPORT CARD (table + export + pagination)
// ─────────────────────────────────────────────────────────────────────────────

/// Formats raw minutes as hh:mm (e.g. 90 → "01:30").
/// Shared by the report table and the CSV export. Hours are not capped at 24 —
/// a range total legitimately runs into the hundreds (e.g. "168:45").
String _fmtHours(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Framed flat action button — the shared frame style for EXPORT and
/// ADD TIME CARD (thin navAccent outline, rounded, touch-sized, flat hover).
class _FramedAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _FramedAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: context.navAccent),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: context.navAccent,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: context.navAccent, width: 1.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        foregroundColor: context.navAccent,
      ).copyWith(
        overlayColor: WidgetStatePropertyAll(context.navHover),
      ),
    );
  }
}

class _SessionsReportCard extends StatelessWidget {
  final List<ShiftSessionRow> rows;
  final int page;
  final int rowsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onRowsPerPageChanged;

  const _SessionsReportCard({
    required this.rows,
    required this.page,
    required this.rowsPerPage,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
  });

  int get _totalPages =>
      rows.isEmpty ? 1 : (rows.length / rowsPerPage).ceil();

  int get _safePage => page.clamp(0, _totalPages - 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final labelStyle = theme.textTheme.bodySmall
        ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500);
    final dividerColor = cs.outline.withValues(alpha: 0.22);
    final fmt = DateFormat('MMM d, yyyy h:mm a');

    final pageRows =
        rows.skip(_safePage * rowsPerPage).take(rowsPerPage).toList();
    // Total = completed sessions only; open (in-progress) rows are excluded.
    final totalMinutes = rows
        .where((r) => !r.isOpen)
        .fold(0, (sum, r) => sum + r.totalMinutes);

    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              children: [
                Expanded(flex: 5, child: Text(AppLocalizations.of(context).clockIn, style: labelStyle)),
                Expanded(flex: 5, child: Text(AppLocalizations.of(context).clockOut, style: labelStyle)),
                Expanded(flex: 4, child: Text(AppLocalizations.of(context).employee, style: labelStyle)),
                Expanded(
                  flex: 2,
                  child: Text(
                    AppLocalizations.of(context).totalHours,
                    textAlign: TextAlign.end,
                    style: labelStyle?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: dividerColor),

          // Data rows — one per clock-in/out session
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_off_outlined,
                            size: 40,
                            color: cs.onSurfaceVariant
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context).noTimeEntriesInRange,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: pageRows.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: dividerColor),
                    itemBuilder: (_, i) {
                      final row = pageRows[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                fmt.format(row.clockIn),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: row.isOpen
                                  ? Text(
                                      AppLocalizations.of(context)
                                          .shiftStillOpen,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: cs.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : Text(
                                      fmt.format(row.clockOut!),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                row.employeeName,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                row.isOpen
                                    ? AppLocalizations.of(context).shiftStillOpen
                                    : _fmtHours(row.totalMinutes),
                                textAlign: TextAlign.end,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: row.isOpen
                                      ? cs.error
                                      : cs.onSurface.withValues(alpha: 0.85),
                                  fontWeight: row.isOpen
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Total row (completed sessions only)
          if (rows.isNotEmpty) ...[
            Divider(height: 1, color: dividerColor),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    flex: 14,
                    child: Text(
                      AppLocalizations.of(context).totalCompleted,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _fmtHours(totalMinutes),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Pagination footer
          Divider(height: 1, color: dividerColor),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                // Prev arrow
                IconButton(
                  icon: Icon(Icons.chevron_left,
                      color: _safePage > 0
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.25)),
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: _safePage > 0
                      ? () => onPageChanged(_safePage - 1)
                      : null,
                ),
                // Next arrow
                IconButton(
                  icon: Icon(Icons.chevron_right,
                      color: _safePage < _totalPages - 1
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.25)),
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: _safePage < _totalPages - 1
                      ? () => onPageChanged(_safePage + 1)
                      : null,
                ),
                const SizedBox(width: 4),
                Text(AppLocalizations.of(context).pageLabel,
                    style: labelStyle),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: cs.outline.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_safePage + 1}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                Text(AppLocalizations.of(context).ofPagesLabel(_totalPages.toString()), style: labelStyle),
                const Spacer(),
                Text(AppLocalizations.of(context).rowsPerPage, style: labelStyle),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: rowsPerPage,
                    isDense: true,
                    dropdownColor: theme.cardColor,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurface),
                    items: [10, 25, 50]
                        .map((n) => DropdownMenuItem<int>(
                              value: n,
                              child: Text('$n'),
                            ))
                        .toList(),
                    onChanged: (n) {
                      if (n != null) onRowsPerPageChanged(n);
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _InfoRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        color: color ?? Theme.of(context).colorScheme.onSurface);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(AppLocalizations.of(context).labelWithColon(label),
              style: style.copyWith(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: style)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD TIME CARD — admin override dialog (manual clock-in/out entry)
// ─────────────────────────────────────────────────────────────────────────────

class _AddTimeCardDialog extends ConsumerStatefulWidget {
  const _AddTimeCardDialog();

  @override
  ConsumerState<_AddTimeCardDialog> createState() => _AddTimeCardDialogState();
}

class _AddTimeCardDialogState extends ConsumerState<_AddTimeCardDialog> {
  int? _userId;
  late DateTime _clockIn;
  late DateTime _clockOut;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // To the minute; clock-in defaults to an hour before clock-out (correct
    // across midnight, unlike a separate date+time-of-day that would invert).
    _clockOut = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _clockIn = _clockOut.subtract(const Duration(hours: 1));
  }

  // Independent in/out date+time so a session can span any window (even
  // different days), per the admin override requirement.
  Future<void> _pickDateTime(bool isIn) async {
    final picked = await showAppDateTimePicker(
      context,
      initialDateTime: isIn ? _clockIn : _clockOut,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isIn) {
          _clockIn = picked;
        } else {
          _clockOut = picked;
        }
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_userId == null) {
      setState(() =>
          _error = AppLocalizations.of(context).selectAnEmployeeError);
      return;
    }
    if (!_clockOut.isAfter(_clockIn)) {
      setState(() =>
          _error = AppLocalizations.of(context).clockOutMustBeAfterClockIn);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(shiftNotifierProvider.notifier).addManualTimeCard(
            userId: _userId!,
            clockInUtc: _clockIn.toUtc(),
            clockOutUtc: _clockOut.toUtc(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final usersAsync = ref.watch(allUsersProvider);
    final dateFmt = DateFormat('MMM d, yyyy');
    String dtLabel(DateTime dt) =>
        '${dateFmt.format(dt)}  ${TimeOfDay.fromDateTime(dt).format(context)}';

    final minutes = _clockOut.isAfter(_clockIn)
        ? _clockOut.difference(_clockIn).inMinutes
        : 0;

    return AlertDialog(
      backgroundColor: theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
      ),
      title: Text(AppLocalizations.of(context).addTimeCard),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FieldLabel(AppLocalizations.of(context).employee),
            usersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text(AppLocalizations.of(context).couldNotLoadEmployees,
                  style: TextStyle(color: cs.error)),
              data: (users) => Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: cs.outline.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _userId,
                    isExpanded: true,
                    hint: Text(AppLocalizations.of(context).selectEmployee,
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    dropdownColor: theme.cardColor,
                    items: users.map((u) {
                      final name = [u.firstName, u.lastName]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' ')
                          .trim();
                      return DropdownMenuItem<int?>(
                        value: u.id,
                        child: Text(
                          name.isEmpty
                              ? (u.username ??
                                  AppLocalizations.of(context)
                                      .userNumbered('${u.id}'))
                              : name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurface),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() {
                      _userId = v;
                      _error = null;
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _FieldLabel(AppLocalizations.of(context).clockIn),
            Row(children: [
              Expanded(
                child: _PickerChip(
                  icon: Icons.login,
                  label: dtLabel(_clockIn),
                  onTap: () => _pickDateTime(true),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            _FieldLabel(AppLocalizations.of(context).clockOut),
            Row(children: [
              Expanded(
                child: _PickerChip(
                  icon: Icons.logout,
                  label: dtLabel(_clockOut),
                  onTap: () => _pickDateTime(false),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            Text(
              AppLocalizations.of(context)
                  .totalHoursWithValue(_fmtHours(minutes)),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: cs.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context).saveUpper),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PickerChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerChip(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurface)),
            ),
          ],
        ),
      ),
    );
  }
}
