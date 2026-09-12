import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/core/app_date_picker.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/ilyass_column_order.dart';
import 'package:pos_app/core/ilyass_screen.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/period_presets.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/session/session_columns_provider.dart';
import 'package:pos_app/session/session_provider.dart';
import 'package:pos_app/session/session_screen.dart';

/// Every session ever recorded, newest first — the landing screen for
/// **POS Session**, modelled on Odoo's Sessions list.
///
/// 🚨 Shows ALL registers, not just this one. A device only ever creates its own
/// sessions, so a list built purely from local rows would show one register's
/// history on a two-till shop and read as data loss. `SyncManager.pullSessions`
/// brings the others in; rows from another device carry a `srvs_<id>` local id
/// and are never pushed back.
final allSessionsProvider = StreamProvider<List<ShiftsTableData>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const []);

  return (db.select(db.shiftsTable)
        ..where((t) => t.companyId.equals(companyId))
        ..orderBy([(t) => OrderingTerm.desc(t.openedAt)]))
      .watch()
      // The discriminator: attendance shifts live in this table too and are a
      // different concept entirely. A POS session has either a device uid (this
      // terminal opened it) or a device name (it was pulled from another one).
      .map(
        (rows) => rows
            .where((r) => r.posDeviceUid != null || r.posDeviceName != null)
            .toList(),
      );
});

class SessionListScreen extends ConsumerStatefulWidget {
  /// Opens the POS navigation drawer. Supplied by MainLayout when this is the
  /// active tab; null when [show] pushes it as its own route, which turns the
  /// hamburger into a back arrow. See `lib/core/ilyass_screen.dart`.
  final VoidCallback? onMenuPressed;

  const SessionListScreen({super.key, this.onMenuPressed});

  /// Pushes the list as a route. Kept for the session gate, which asks for it
  /// mid-flow (from a dialog, over whatever screen the operator was on) and
  /// genuinely does want a back arrow. Reaching it from the SIDEBAR goes
  /// through the tab instead — see MainLayout.
  static Future<void> show(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SessionListScreen()),
  );

  @override
  ConsumerState<SessionListScreen> createState() => _SessionListScreenState();
}

/// The Status filter's three buckets — the same three the status pill shows,
/// so a filter chip and a pill never disagree about what a session is.
enum _StatusBucket { inProgress, closingControl, closed }

/// Starting widths. The operator's drags override them, per device.
const _kSessionColumnWidths = <String, double>{
  'id': 150,
  'pos': 140,
  'openedBy': 170,
  'opening': 170,
  'closing': 170,
  'closedBy': 160,
  'duration': 110,
  'starting': 140,
  'ending': 140,
  'theoretical': 150,
  'difference': 130,
  'status': 170,
};

class _SessionListScreenState extends ConsumerState<SessionListScreen> {
  /// One id for the table AND the column picker: the picker writes the order
  /// the table reads.
  static const _tableId = 'sessions';

  final _search = TextEditingController();
  String _query = '';

  // Active filters — each one is a chip in the search bar; null = not applied.
  DateTimeRange? _period;
  String? _periodLabel;
  String? _pos;
  _StatusBucket? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The shared Ilyass column picker. Visibility still lives in
  /// [sessionVisibleColumnsProvider], so a terminal's saved choice carries over.
  void _showColumnPicker(BuildContext context) {
    showIlyassColumnPicker(
      context: context,
      tableId: _tableId,
      columns: [
        for (final c in kSessionColumns)
          IlyassPickerColumn(
            key: c.key,
            label: sessionColumnLabel(context, c.key),
            // The session id stays locked on: a row nothing identifies is not a
            // row anyone can act on.
            mandatory: c.mandatory,
          ),
      ],
      isVisible: (key) {
        final def = kSessionColumns.firstWhere((c) => c.key == key);
        return ref.read(sessionVisibleColumnsProvider)[key] ??
            def.defaultVisible;
      },
      onVisibleChanged: (key, visible) => ref
          .read(sessionVisibleColumnsProvider.notifier)
          .setVisible(key, visible),
      onReset: () =>
          ref.read(sessionVisibleColumnsProvider.notifier).resetToDefaults(),
    );
  }

  // ── filters ───────────────────────────────────────────────────────────────

  bool _inBucket(_StatusBucket bucket, int status) => switch (bucket) {
    _StatusBucket.inProgress =>
      status == PosSessionStatus.openingControl ||
          status == PosSessionStatus.opened,
    _StatusBucket.closingControl => status == PosSessionStatus.closingControl,
    _StatusBucket.closed => status == PosSessionStatus.closed,
  };

  String _statusLabel(AppLocalizations l, _StatusBucket bucket) =>
      switch (bucket) {
        _StatusBucket.inProgress => l.sessionInProgress,
        _StatusBucket.closingControl => l.sessionClosingControl,
        _StatusBucket.closed => l.sessionClosedPosted,
      };

  IconData _statusIcon(_StatusBucket bucket) => switch (bucket) {
    _StatusBucket.inProgress => Icons.play_circle_outline,
    _StatusBucket.closingControl => Icons.hourglass_bottom,
    _StatusBucket.closed => Icons.lock_outline,
  };

  /// Whether a session OPENED inside the period, read on the company's wall
  /// clock — "today" is the shop's today, not UTC's. The range's end day is
  /// inclusive: a range ending on the 5th includes a session opened at 17:40
  /// on the 5th.
  bool _inPeriod(DateTime openedAt, AppDateFormat dates) {
    final range = _period;
    if (range == null) return true;
    final z = dates.toDisplayZone(openedAt);
    final at = DateTime(z.year, z.month, z.day, z.hour, z.minute);
    final end = DateTime(range.end.year, range.end.month, range.end.day + 1);
    return !at.isBefore(range.start) && at.isBefore(end);
  }

  Future<void> _pickPeriod(AppDateFormat dates) async {
    final now = DateTime.now();
    final range = await showAppDateRangePicker(
      context,
      initialStart: _period?.start ?? DateTime(now.year, now.month, 1),
      initialEnd: _period?.end ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
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
      _pos = null;
      _status = null;
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = ref.watch(appDateFormatProvider);
    final all = ref.watch(allSessionsProvider).value ?? const [];
    final activeLocalId = ref.watch(activeSessionProvider).value?.localId;
    final users = ref.watch(allUsersProvider).value ?? const <User>[];
    final visibleCols = ref.watch(sessionVisibleColumnsProvider);

    // A cashier's NAME, falling back to the id for a user this device has not
    // synced — "#9" is an answer, just not a useful one to read all day.
    String who(int? id) {
      if (id == null) return '—';
      for (final u in users) {
        if (u.id == id) return u.displayName;
      }
      return '#$id';
    }

    final q = _query.trim().toLowerCase();
    final rows = all.where((s) {
      if (_status != null && !_inBucket(_status!, s.status)) return false;
      if (_pos != null && (s.posDeviceName ?? '').trim() != _pos) return false;
      if (!_inPeriod(s.openedAt, dates)) return false;
      if (q.isEmpty) return true;
      return sessionDisplayId(s).toLowerCase().contains(q) ||
          (s.posDeviceName ?? '').toLowerCase().contains(q) ||
          who(s.userId).toLowerCase().contains(q);
    }).toList();

    // The registers this history actually contains, for the Point of Sale
    // filter — never a hardcoded list that goes stale when a till is renamed.
    final registers = {
      for (final s in all)
        if ((s.posDeviceName ?? '').trim().isNotEmpty) s.posDeviceName!.trim(),
    }.toList()..sort();

    // Only the columns this terminal has chosen to keep, in catalogue order;
    // the operator's own ORDER is applied by the table.
    final activeDefs = kSessionColumns
        .where((c) => visibleCols[c.key] ?? c.defaultVisible)
        .toList();
    // The surplus goes to ONE text column — a name, never a balance.
    final flexKey = const ['openedBy', 'pos', 'id'].firstWhere(
      (k) => activeDefs.any((c) => c.key == k),
      orElse: () => 'id',
    );
    final columns = [
      for (final def in activeDefs)
        IlyassColumn<ShiftsTableData>(
          key: def.key,
          label: sessionColumnLabel(context, def.key),
          numeric: def.numeric,
          flexible: def.key == flexKey,
          width: _kSessionColumnWidths[def.key] ?? 150,
          cell: (context, s) => _sessionCell(
            context,
            column: def,
            session: s,
            isActive: s.localId == activeLocalId,
            who: who,
            dates: dates,
          ),
        ),
    ];

    return IlyassScreen(
      title: l.sessionsTitle,
      onMenuPressed: widget.onMenuPressed,
      searchBar: UnifiedSearchBar(
        controller: _search,
        // The header is a fixed-height toolbar: chips share the row with the
        // field rather than wrapping onto a second line.
        singleLine: true,
        hintText: l.sessionSearchHint,
        chips: [
          if (_period != null)
            SearchBarChip(
              id: 'period',
              label: _periodLabel ?? '',
              icon: Icons.date_range_outlined,
              onRemove: () => setState(() {
                _period = null;
                _periodLabel = null;
              }),
            ),
          if (_pos != null)
            SearchBarChip(
              id: 'pos',
              label: _pos!,
              icon: Icons.point_of_sale_outlined,
              onRemove: () => setState(() => _pos = null),
            ),
          if (_status != null)
            SearchBarChip(
              id: 'status',
              label: _statusLabel(l, _status!),
              icon: _statusIcon(_status!),
              onRemove: () => setState(() => _status = null),
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
          if (registers.isNotEmpty)
            FilterMenuSection(
              title: l.sessionColPos,
              icon: Icons.point_of_sale_outlined,
              options: [
                for (final r in registers)
                  FilterMenuOption(
                    label: r,
                    icon: Icons.point_of_sale_outlined,
                    selected: _pos == r,
                    onSelected: () => setState(() => _pos = r),
                  ),
              ],
            ),
          FilterMenuSection(
            title: l.sessionColStatus,
            icon: Icons.flag_outlined,
            options: [
              for (final b in _StatusBucket.values)
                FilterMenuOption(
                  label: _statusLabel(l, b),
                  icon: _statusIcon(b),
                  selected: _status == b,
                  onSelected: () => setState(() => _status = b),
                ),
            ],
          ),
        ],
        onQueryChanged: (v) => setState(() => _query = v),
        onClearAll: _clearAll,
      ),
      // Displays, not actions: the count says how much of the list the search
      // is hiding, which only means anything beside the search box.
      trailing: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text(
              l.sessionCountOf(rows.length, all.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
      actions: [
        IlyassMenuAction(
          icon: Icons.view_column_rounded,
          label: l.columns,
          onSelected: () => _showColumnPicker(context),
        ),
      ],
      body: IlyassTable<ShiftsTableData>(
        tableId: _tableId,
        columns: columns,
        rows: rows,
        // Tapping a row opens the detail — the screen that used to BE this
        // menu entry.
        onRowTap: (s) => SessionScreen.showFor(context, s),
        emptyState: Center(
          child: Text(
            // "No sessions yet" would be a lie with filters hiding them.
            all.isEmpty ? l.sessionNoHistory : l.sessionNoMatches,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      // No "current session on this device" FAB: this register's live session
      // is already in the list and carries its own marker, so the button was a
      // second door onto the same screen — and it sat on top of the row it
      // duplicated.
    );
  }
}

/// One column's rendering for one session.
Widget _sessionCell(
  BuildContext context, {
  required SessionColumnDef column,
  required ShiftsTableData session,
  required bool isActive,
  required String Function(int?) who,
  required AppDateFormat dates,
}) {
  final l = AppLocalizations.of(context);
  final theme = Theme.of(context);

  String money(double? v) => v == null ? '—' : v.toStringAsFixed(2);

  Widget text(String value, {TextStyle? style}) => Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: style ?? theme.textTheme.bodyMedium,
  );

  switch (column.key) {
    case 'id':
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              sessionDisplayId(session),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: l.sessionCurrentOnThisDevice,
              child: Icon(Icons.circle, size: 8, color: context.successColor),
            ),
          ],
        ],
      );
    case 'pos':
      return text(session.posDeviceName ?? '—');
    case 'openedBy':
      return text(who(session.userId));
    case 'opening':
      return text(fmtSessionDate(dates, session.openedAt));
    case 'closing':
      return text(
        session.closedAt == null ? '—' : fmtSessionDate(dates, session.closedAt!),
      );
    case 'closedBy':
      return text(
        session.closedByUserId == null ? '—' : who(session.closedByUserId),
      );
    case 'duration':
      return text(
        fmtSessionDuration(
          (session.closedAt ?? DateTime.now().toUtc()).difference(
            session.openedAt,
          ),
        ),
      );
    case 'starting':
      return text(money(session.startingCash));
    case 'ending':
      return text(money(session.actualEndingCash));
    case 'theoretical':
      // Odoo's "Theoretical Closing" is our expected cash — the same number
      // under its name.
      return text(money(session.expectedCash));
    case 'difference':
      final d = session.cashDifference;
      return text(
        money(d),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: d == null || d == 0 ? null : FontWeight.bold,
          color: d == null
              ? null
              : (d == 0 ? context.successColor : context.dangerColor),
        ),
      );
    case 'status':
      return SessionStatusPill(status: session.status);
    default:
      return const SizedBox.shrink();
  }
}

/// `POS1/00089` — the register's name plus its session number, matching how
/// this app already numbers documents and how Odoo names sessions.
///
/// Falls back to the short local id while a session opened offline has no
/// server number yet: it HAS an identity, it just has not been given a number,
/// and showing nothing would make it look unsaved.
String sessionDisplayId(ShiftsTableData s) {
  final device = (s.posDeviceName ?? '').trim();
  if (s.serverId == null) {
    final short = s.localId.length <= 8 ? s.localId : s.localId.substring(0, 8);
    return device.isEmpty ? short : '$device/$short';
  }
  final num = s.serverId!.toString().padLeft(5, '0');
  return device.isEmpty ? '#$num' : '$device/$num';
}

/// 🚨 Was `Sep 3, 11:42 PM` — a hardcoded English month table and a 12-hour
/// clock, with no reference to `Application.DateFormat` or the company's
/// timezone. Both are now the caller's, via [AppDateFormat].
String fmtSessionDate(AppDateFormat dates, DateTime dt) => dates.stamp(dt);

/// `7h 18m` — how long the register traded.
String fmtSessionDuration(Duration d) {
  if (d.isNegative) return '—';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

/// The session's state as a coloured pill. Public because the detail screen
/// puts the same pill in its header — one vocabulary for one concept.
class SessionStatusPill extends StatelessWidget {
  const SessionStatusPill({super.key, required this.status});

  final int status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final closed = status == PosSessionStatus.closed;
    final color = closed ? context.successColor : theme.colorScheme.primary;
    final label = switch (status) {
      PosSessionStatus.closingControl => l.sessionClosingControl,
      PosSessionStatus.closed => l.sessionClosedPosted,
      _ => l.sessionInProgress,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
