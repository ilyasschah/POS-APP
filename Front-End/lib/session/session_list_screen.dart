import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/ilyass_screen.dart';
import 'package:pos_app/core/responsive.dart';
import 'package:pos_app/core/status_colors.dart';
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

class _SessionListScreenState extends ConsumerState<SessionListScreen> {
  final _search = TextEditingController();
  String _query = '';

  // The card/table switch uses the app-wide `context.isCompact` (<1000 dp)
  // rather than a breakpoint of its own — see lib/core/responsive.dart. On a
  // 7-to-10-inch till, a nine-column DataTable is unreadable and unhittable;
  // a card per session keeps every field legible and gives the row a tap
  // target a finger can actually land on.

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _showColumnPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final l = AppLocalizations.of(context);
          final visible = ref.watch(sessionVisibleColumnsProvider);
          final notifier = ref.read(sessionVisibleColumnsProvider.notifier);
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Text(l.showHideColumns),
            content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: kSessionColumns.map((col) {
                    final isOn = visible[col.key] ?? col.defaultVisible;
                    return CheckboxListTile(
                      dense: true,
                      title: Text(sessionColumnLabel(context, col.key)),
                      // The session id stays locked on: a row nothing identifies
                      // is not a row anyone can act on.
                      subtitle: col.mandatory ? Text(l.alwaysShown) : null,
                      value: isOn,
                      onChanged: col.mandatory
                          ? null
                          : (val) => notifier.setVisible(col.key, val ?? false),
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => notifier.resetToDefaults(),
                child: Text(l.actionReset),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.actionClose),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
    final rows = q.isEmpty
        ? all
        : all
              .where(
                (s) =>
                    sessionDisplayId(s).toLowerCase().contains(q) ||
                    (s.posDeviceName ?? '').toLowerCase().contains(q) ||
                    who(s.userId).toLowerCase().contains(q),
              )
              .toList();

    // Only the columns this terminal has chosen to keep, in catalogue order.
    final activeCols = kSessionColumns
        .where((c) => visibleCols[c.key] ?? c.defaultVisible)
        .toList();

    final compact = context.isCompact;

    return IlyassScreen(
      title: l.sessionsTitle,
      onMenuPressed: widget.onMenuPressed,
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: l.sessionSearchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainer,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
      ),
      body: rows.isEmpty
          ? Center(
              child: Text(
                l.sessionNoHistory,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) => compact
                  ? _SessionCards(
                      rows: rows,
                      columns: activeCols,
                      activeLocalId: activeLocalId,
                      who: who,
                    )
                  : _SessionTable(
                      rows: rows,
                      columns: activeCols,
                      activeLocalId: activeLocalId,
                      who: who,
                      maxWidth: constraints.maxWidth,
                    ),
            ),
      // No "current session on this device" FAB: this register's live session
      // is already the top row of the list and carries its own marker, so the
      // button was a second door onto the same screen — and it sat on top of
      // the row it duplicated.
    );
  }
}

/// The wide layout: a DataTable of whichever columns are enabled.
class _SessionTable extends StatelessWidget {
  const _SessionTable({
    required this.rows,
    required this.columns,
    required this.activeLocalId,
    required this.who,
    required this.maxWidth,
  });

  final List<ShiftsTableData> rows;
  final List<SessionColumnDef> columns;
  final String? activeLocalId;
  final String Function(int?) who;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Horizontal scroll lets the grid grow past the viewport as more columns
    // are enabled, while ConstrainedBox keeps it filling the width when only a
    // few are shown. Same construction as the Products grid.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: maxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.1),
              ),
            ),
            color: theme.cardColor,
            clipBehavior: Clip.antiAlias,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                theme.colorScheme.surfaceContainerHighest,
              ),
              showCheckboxColumn: false,
              dataRowMaxHeight: 56,
              // With no flex column `RenderTable` spreads the surplus width
              // EQUALLY, so a balance column stretches as far as a name. Give
              // the slack to the first TEXT column instead.
              columns: () {
                final flexKey = columns
                    .where((c) => !c.numeric)
                    .firstOrNull
                    ?.key;
                return columns
                    .map(
                      (c) => DataColumn(
                        label: Text(sessionColumnLabel(context, c.key)),
                        numeric: c.numeric,
                        columnWidth: c.key == flexKey
                            ? const IntrinsicColumnWidth(flex: 1)
                            : null,
                      ),
                    )
                    .toList();
              }(),
              rows: [
                for (final s in rows)
                  DataRow(
                    // Tapping a row opens the detail — the screen that used to
                    // BE this menu entry.
                    onSelectChanged: (_) => SessionScreen.showFor(context, s),
                    cells: [
                      for (final c in columns)
                        DataCell(
                          _sessionCell(
                            context,
                            column: c,
                            session: s,
                            isActive: s.localId == activeLocalId,
                            who: who,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The compact layout: one tappable card per session, showing the same columns
/// the table would — so hiding a column hides it in both places rather than the
/// preference silently applying to only half the app.
class _SessionCards extends StatelessWidget {
  const _SessionCards({
    required this.rows,
    required this.columns,
    required this.activeLocalId,
    required this.who,
  });

  final List<ShiftsTableData> rows;
  final List<SessionColumnDef> columns;
  final String? activeLocalId;
  final String Function(int?) who;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // The id and the status are the card's header, so they are not repeated as
    // rows in its body.
    final bodyCols = columns
        .where((c) => c.key != 'id' && c.key != 'status')
        .toList();
    final showsStatus = columns.any((c) => c.key == 'status');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final s = rows[i];
        final isActive = s.localId == activeLocalId;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          color: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => SessionScreen.showFor(context, s),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                sessionDisplayId(s),
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: l.sessionCurrentOnThisDevice,
                                child: Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: context.successColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (showsStatus) SessionStatusPill(status: s.status),
                    ],
                  ),
                  if (bodyCols.isNotEmpty) const Divider(height: 18),
                  for (final c in bodyCols)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              sessionColumnLabel(context, c.key),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: _sessionCell(
                              context,
                              column: c,
                              session: s,
                              isActive: isActive,
                              who: who,
                              alignEnd: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One column's rendering for one session — shared by the table and the cards
/// so a value can never read one way in the grid and another on a tablet.
Widget _sessionCell(
  BuildContext context, {
  required SessionColumnDef column,
  required ShiftsTableData session,
  required bool isActive,
  required String Function(int?) who,
  bool alignEnd = false,
}) {
  final l = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final align = alignEnd ? TextAlign.end : TextAlign.start;

  String money(double? v) => v == null ? '—' : v.toStringAsFixed(2);

  Widget text(String value, {TextStyle? style}) => Text(
    value,
    textAlign: align,
    overflow: TextOverflow.ellipsis,
    style: style ?? theme.textTheme.bodyMedium,
  );

  switch (column.key) {
    case 'id':
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sessionDisplayId(session),
            style: const TextStyle(fontWeight: FontWeight.bold),
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
      return text(fmtSessionDate(session.openedAt));
    case 'closing':
      return text(
        session.closedAt == null ? '—' : fmtSessionDate(session.closedAt!),
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

String fmtSessionDate(DateTime dt) {
  final d = dt.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  return '${months[d.month - 1]} ${d.day}, $h:'
      '${d.minute.toString().padLeft(2, '0')} $ampm';
}

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
