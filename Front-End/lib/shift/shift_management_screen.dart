import 'dart:async';
import 'dart:io' show Directory, File, Platform, Process;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/core/app_date_picker.dart';
import 'package:pos_app/core/ilyass_column_order.dart';
import 'package:pos_app/core/ilyass_dropdown.dart';
import 'package:pos_app/core/ilyass_screen.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/period_presets.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/shift/shift_provider.dart';
import 'package:pos_app/time_clock/time_clock_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// The table's columns, in catalogue order. Keys are identities — never
/// translated, or the widths and the order reset when the language changes.
const _kShiftColumns = ['clockIn', 'clockOut', 'employee', 'hours'];

/// Which columns this terminal shows. Same shape as the Z-report's.
final _shiftVisibleColumnsProvider = StateProvider<Map<String, bool>>(
  (ref) => {for (final key in _kShiftColumns) key: true},
);

String _shiftColumnLabel(AppLocalizations l, String key) => switch (key) {
  'clockIn' => l.clockIn,
  'clockOut' => l.clockOut,
  'employee' => l.employee,
  'hours' => l.totalHours,
  _ => key,
};

/// Shift Management — an Ilyass Screen (`lib/core/ilyass_screen.dart`), and
/// ONE screen.
///
/// It used to be two tabs: "My shift", a card with one button, and "Hours
/// report", the table. Now the table IS the screen, and the card's one job —
/// starting or ending the operator's own shift — is the floating button, which
/// also shows how long the shift has been running:
///
///  * the header search carries the filters: a Period (presets or any range
///    from the date picker) and an Employee, each a dismissible chip;
///  * the ⋮ holds Add time card, Export and Columns;
///  * the completed-hours total sits beside the search, where it answers
///    "how much is this filter worth" without a footer row.
class ShiftManagementScreen extends ConsumerStatefulWidget {
  /// Opens the POS navigation drawer. Supplied by MainLayout; null when the
  /// screen is pushed standalone, which turns the hamburger into a back arrow.
  final VoidCallback? onMenuPressed;

  const ShiftManagementScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<ShiftManagementScreen> createState() =>
      _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends ConsumerState<ShiftManagementScreen> {
  /// One id for the table AND the column picker: the picker writes the order
  /// the table reads.
  static const _tableId = 'shifts';
  static const _maxPerSection = 8;

  final _search = TextEditingController();
  String _query = '';

  /// The Period filter. Opens on this month — the range the old Hours tab
  /// defaulted to. Removing the chip means all time.
  DateTimeRange? _period;
  String? _periodLabel;

  int? _userId;
  String? _userLabel;

  bool _busy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _period = DateTimeRange(
      start: DateTime(now.year, now.month),
      end: DateTime(now.year, now.month, now.day),
    );
    // One setState a minute advances the running shift's elapsed time and the
    // open rows' hours — negligible even on a low-spec tablet.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// The query the stream runs. No period = all time.
  HoursQueryParams _params(int companyId) {
    final p = _period;
    return (
      rangeStart: p == null
          ? DateTime.utc(2000)
          : DateTime(p.start.year, p.start.month, p.start.day).toUtc(),
      rangeEnd: p == null
          ? DateTime.utc(2100)
          : DateTime(p.end.year, p.end.month, p.end.day, 23, 59, 59).toUtc(),
      userId: _userId,
      companyId: companyId,
    );
  }

  // ── my shift ──────────────────────────────────────────────────────────────

  Future<void> _startShift() async {
    setState(() => _busy = true);
    try {
      // Float tracking is deprecated; pass a static 0 so the underlying shift
      // row stays schema-valid without a cash-drawer step. This is the
      // station's master drawer shift (distinct from kiosk attendance rows).
      await ref
          .read(shiftNotifierProvider.notifier)
          .startShift(0, isDrawerShift: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _endShift(ShiftsTableData shift) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        title: Text(l.endShift),
        content: Text(l.endShiftConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: ctx.dangerColor,
              foregroundColor: ctx.onDangerColor,
            ),
            child: Text(l.actionConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(shiftNotifierProvider.notifier).closeShift(shift);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── actions ───────────────────────────────────────────────────────────────

  Future<void> _addTimeCard() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddTimeCardDialog(),
    );
    // The table is a live stream off shiftsTable, so the new row appears
    // instantly — no manual refresh needed.
    if (saved == true && mounted) {
      showAppSnackbarRaw(context, AppLocalizations.of(context).timeCardAdded);
    }
  }

  /// The rows ON SCREEN — filtered exactly as shown, so the file is what the
  /// operator was looking at.
  ///
  /// Windows gets a real file, opened in the spreadsheet app, like the Reports
  /// export. Android has no `explorer.exe` to hand a file to, so the tablet
  /// keeps the clipboard copy it always had.
  Future<void> _export(List<ShiftSessionRow> rows, String storeName) async {
    final l = AppLocalizations.of(context);
    if (rows.isEmpty) {
      showAppSnackbarRaw(context, l.nothingToExportInRange);
      return;
    }
    final csv = _buildCsv(rows, storeName, l.shiftStillOpen);

    if (Platform.isWindows) {
      try {
        final file = File(
          '${Directory.systemTemp.path}\\Shifts_'
          '${DateTime.now().millisecondsSinceEpoch}.csv',
        );
        await file.writeAsString(csv);
        await Process.start('explorer.exe', [file.path]);
        if (mounted) showAppSnackbarRaw(context, l.savedToPath(file.path));
      } catch (e) {
        if (mounted) showAppSnackbarRaw(context, l.exportFailed('$e'));
      }
      return;
    }

    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) showAppSnackbarRaw(context, l.reportCopiedAsCsv);
  }

  void _showColumnPicker() {
    final l = AppLocalizations.of(context);
    showIlyassColumnPicker(
      context: context,
      tableId: _tableId,
      columns: [
        for (final key in _kShiftColumns)
          IlyassPickerColumn(
            key: key,
            label: _shiftColumnLabel(l, key),
            // A row with no clock-in is a row nobody can place in time.
            mandatory: key == 'clockIn',
          ),
      ],
      isVisible: (key) => ref.read(_shiftVisibleColumnsProvider)[key] ?? false,
      onVisibleChanged: (key, value) => ref
          .read(_shiftVisibleColumnsProvider.notifier)
          .update((s) => {...s, key: value}),
    );
  }

  // ── filters ───────────────────────────────────────────────────────────────

  Future<void> _pickPeriod(AppDateFormat dates) async {
    final now = DateTime.now();
    final range = await showAppDateRangePicker(
      context,
      initialStart: _period?.start ?? DateTime(now.year, now.month, 1),
      initialEnd: _period?.end ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (range == null || !mounted) return;
    setState(() {
      _period = range;
      _periodLabel = '${dates.day(range.start)} - ${dates.day(range.end)}';
    });
  }

  void _clearAll() {
    _search.clear();
    setState(() {
      _query = '';
      _period = null;
      _periodLabel = null;
      _userId = null;
      _userLabel = null;
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dates = ref.watch(appDateFormatProvider);
    final company = ref.watch(selectedCompanyProvider);
    final storeName = company?.name ?? '';
    final sessionsAsync = ref.watch(
      shiftSessionsProvider(_params(company?.id ?? 0)),
    );
    final users = ref.watch(allUsersProvider).value ?? const <User>[];
    final activeShift = ref.watch(activeShiftProvider).value;
    final visible = ref.watch(_shiftVisibleColumnsProvider);

    String nameOf(User u) =>
        _employeeName(context, u.firstName, u.lastName, u.username, u.id);

    // The typed text narrows the rows by employee AND the Employee section of
    // the menu, so a long staff list is still one tap away.
    final q = _query.trim().toLowerCase();
    final all = sessionsAsync.value ?? const <ShiftSessionRow>[];
    final rows = q.isEmpty
        ? all
        : all.where((r) => r.employeeName.toLowerCase().contains(q)).toList();
    final matchedUsers = q.isEmpty
        ? users
        : users.where((u) => nameOf(u).toLowerCase().contains(q)).toList();

    // Completed sessions only: an open one has no total yet.
    final totalMinutes = rows
        .where((r) => !r.isOpen)
        .fold(0, (sum, r) => sum + r.totalMinutes);

    final columns = <IlyassColumn<ShiftSessionRow>>[
      if (visible['clockIn'] ?? true)
        IlyassColumn(
          key: 'clockIn',
          label: l.clockIn,
          width: 180,
          cell: (_, r) => Text(
            dates.dateTime.format(r.clockIn),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (visible['clockOut'] ?? true)
        IlyassColumn(
          key: 'clockOut',
          label: l.clockOut,
          width: 180,
          cell: (context, r) => r.isOpen
              ? Text(
                  l.shiftStillOpen,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.successColor,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : Text(
                  dates.dateTime.format(r.clockOut!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      if (visible['employee'] ?? true)
        IlyassColumn(
          key: 'employee',
          label: l.employee,
          width: 220,
          flexible: true,
          cell: (_, r) => Text(
            r.employeeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      if (visible['hours'] ?? true)
        IlyassColumn(
          key: 'hours',
          label: l.totalHours,
          width: 130,
          numeric: true,
          // Running hours for an open shift, in the "live" colour — so a
          // shift nobody closed stands out rather than hiding as a blank.
          cell: (context, r) => Text(
            _fmtHours(r.totalMinutes),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: r.isOpen ? context.successColor : null,
            ),
          ),
        ),
    ];

    return IlyassScreen(
      title: l.shiftManagement,
      onMenuPressed: widget.onMenuPressed,
      searchBar: UnifiedSearchBar(
        controller: _search,
        singleLine: true,
        hintText: l.shiftSearchHint,
        chips: [
          if (_period != null)
            SearchBarChip(
              id: 'period',
              label: _periodLabel ?? l.thisMonth,
              icon: Icons.date_range_outlined,
              onRemove: () => setState(() {
                _period = null;
                _periodLabel = null;
              }),
            ),
          if (_userId != null)
            SearchBarChip(
              id: 'user',
              label: _userLabel ?? '',
              icon: Icons.person_outline,
              onRemove: () => setState(() {
                _userId = null;
                _userLabel = null;
              }),
            ),
        ],
        sectionsBuilder: (_) => [
          FilterMenuSection(
            title: l.periodLabel,
            icon: Icons.date_range_outlined,
            options: [
              for (final (label, range) in periodPresets(l))
                FilterMenuOption(
                  label: label,
                  icon: Icons.today_outlined,
                  selected: _period == range,
                  onSelected: () => setState(() {
                    _period = range;
                    _periodLabel = label;
                  }),
                ),
              FilterMenuOption(
                label: l.filterCustomRange,
                icon: Icons.edit_calendar_outlined,
                onSelected: () => _pickPeriod(dates),
              ),
            ],
          ),
          FilterMenuSection(
            title: l.employee,
            icon: Icons.badge_outlined,
            footnote: matchedUsers.length > _maxPerSection
                ? l.filterKeepTyping
                : null,
            options: [
              for (final u in matchedUsers.take(_maxPerSection))
                FilterMenuOption(
                  label: nameOf(u),
                  icon: Icons.person_outline,
                  selected: _userId == u.id,
                  onSelected: () => setState(() {
                    _userId = u.id;
                    _userLabel = nameOf(u);
                  }),
                ),
            ],
          ),
        ],
        onQueryChanged: (v) => setState(() => _query = v),
        onClearAll: _clearAll,
      ),
      // A display, not an action: what the filtered rows add up to.
      trailing: [
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  l.totalHoursWithValue(_fmtHours(totalMinutes)),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      actions: [
        IlyassMenuAction(
          icon: Icons.more_time_rounded,
          label: l.addTimeCard,
          onSelected: _addTimeCard,
        ),
        IlyassMenuAction(
          icon: Icons.file_download_outlined,
          label: l.exportCsvAction,
          dividerBefore: true,
          onSelected: () => _export(rows, storeName),
        ),
        IlyassMenuAction(
          icon: Icons.view_column_rounded,
          label: l.columns,
          onSelected: _showColumnPicker,
        ),
      ],
      floatingActionButton: _myShiftButton(context, l, activeShift),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l.errorWithMessage(e.toString()))),
        data: (_) => IlyassTable<ShiftSessionRow>(
          tableId: _tableId,
          columns: columns,
          rows: rows,
          emptyState: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_off_outlined,
                  size: 48,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  l.noTimeEntriesInRange,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The operator's OWN shift: Start in green, or End in red with the time it
  /// has been running — what the old "My shift" tab was for, one tap away.
  Widget _myShiftButton(
    BuildContext context,
    AppLocalizations l,
    ShiftsTableData? active,
  ) {
    final running = active != null;
    final fill = running ? context.dangerColor : context.successColor;
    final fg = running ? context.onDangerColor : context.onSuccessColor;

    String elapsed() {
      final d = DateTime.now().difference(active!.openedAt);
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }

    return FloatingActionButton.extended(
      // 🚨 A tag of its own: MainLayout keeps every visited tab mounted, and
      // two FABs on the default tag throw "multiple heroes share the same tag".
      heroTag: 'shift-my-shift',
      backgroundColor: fill,
      foregroundColor: fg,
      onPressed: _busy
          ? null
          : (running ? () => _endShift(active) : _startShift),
      icon: _busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          : Icon(running ? Icons.stop_circle_outlined : Icons.play_arrow_rounded),
      label: Text(running ? l.endShiftWithElapsed(elapsed()) : l.startShift),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Formats raw minutes as hh:mm (e.g. 90 → "01:30"). Hours are not capped at
/// 24 — a range total legitimately runs into the hundreds (e.g. "168:45").
String _fmtHours(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// One CSV cell: quoted when it holds a comma, a quote or a line break, with
/// inner quotes doubled — a name like `Smith, "Jo"` must not split a row.
String _csvCell(String value) {
  if (!value.contains(RegExp(r'[",\r\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

String _buildCsv(List<ShiftSessionRow> rows, String storeName, String open) {
  // 🚨 ISO, and NOT the company's date setting. This file is parsed by a
  // spreadsheet, and a date column that changes shape when somebody picks a
  // different display format breaks every import written against the old
  // shape, silently, because both shapes are valid dates.
  final fmt = AppDateFormat.isoDateTime;
  // The header stays English on purpose — it is a machine-readable column
  // header pasted into a spreadsheet, not screen text.
  final sb = StringBuffer('Clock in,Clock out,Employee,Store,Total Hours\n');
  for (final r in rows) {
    sb.writeln([
      fmt.format(r.clockIn),
      r.isOpen ? open : fmt.format(r.clockOut!),
      _csvCell(r.employeeName),
      _csvCell(storeName),
      r.isOpen ? open : _fmtHours(r.totalMinutes),
    ].join(','));
  }
  return sb.toString();
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
    final dateFmt = ref.watch(appDateFormatProvider).date;
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
              data: (users) => IlyassDropdown<int?>(
                value: _userId,
                hint: AppLocalizations.of(context).selectEmployee,
                prefixIcon: Icons.person_outline,
                items: [
                  for (final u in users)
                    IlyassDropdownItem<int?>(
                      value: u.id,
                      label: _employeeName(
                          context, u.firstName, u.lastName, u.username, u.id),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _userId = v;
                  _error = null;
                }),
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

/// An employee's display name for the pickers: "First Last", else the
/// username, else "User #id".
String _employeeName(BuildContext context, String? firstName,
    String? lastName, String? username, Object? id) {
  final name = [firstName, lastName]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' ')
      .trim();
  if (name.isNotEmpty) return name;
  return username ?? AppLocalizations.of(context).userNumbered('$id');
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
