import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/core/responsive.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/document/document_editor_screen.dart';
import 'package:pos_app/document/documents_screen.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/session/closing_register_dialog.dart';
import 'package:pos_app/session/opening_control_dialog.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/session/session_list_screen.dart';
import 'package:pos_app/session/session_provider.dart';
import 'package:pos_app/session/session_reconciliation.dart';
import 'package:pos_app/session/session_summary_provider.dart';
import 'package:pos_app/settings/device_identity.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// The POS session screen: the whole lifecycle, visible.
///
/// Phase 6's purpose is to make the round trip observable on two real devices
/// before any selling is gated on it — so everything the operator needs to
/// verify is on one page: which register, which session, what state, what the
/// drawer should hold, and crucially **whether this device still holds sales
/// the server has not seen**. That last one is the device's own knowledge and
/// nothing else can report it.
///
/// 🚨 A CLOSED session shows MORE here, not less. Closing is the moment the
/// figures stop moving, which is exactly when someone has to be able to audit
/// them: who counted, when, against what, and where any difference came from.
class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key, this.sessionLocalId});

  /// Which session to show. Null = whatever this register is running now.
  ///
  /// A specific id is how the list opens a row, INCLUDING a closed one or one
  /// belonging to another register — those are read-only here, because a
  /// terminal has no business closing a drawer it cannot count.
  final String? sessionLocalId;

  /// The current session on THIS device.
  static Future<void> show(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SessionScreen()),
      );

  /// A specific session, from the list.
  static Future<void> showFor(BuildContext context, ShiftsTableData session) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionScreen(sessionLocalId: session.localId),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final active = ref.watch(activeSessionRowProvider).value;
    final ShiftsTableData? session = sessionLocalId == null
        ? active
        : (ref.watch(allSessionsProvider).value ?? const [])
            .where((s) => s.localId == sessionLocalId)
            .firstOrNull;

    // Only the register's OWN live session can be acted on. Everything else —
    // a closed session, another till's — is a record to read.
    final isLive =
        session != null && active != null && session.localId == active.localId;

    if (session == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(l.posSession),
          backgroundColor: theme.colorScheme.surface,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxReadableWidth),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [_NoSessionCard()],
            ),
          ),
        ),
      );
    }

    final blockers = ref.watch(closeBlockersProvider(session.localId));
    final compact = context.isCompact;

    // Three tabs, not one long scroll: the figures are what a close is signed
    // off against, while the document and payment lists are the evidence
    // behind them — and wanting the evidence usually means wanting to open the
    // sale it belongs to, which is a different task from reading a total.
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          titleSpacing: 8,
          // 🚨 Plain widgets only in this slot. A MenuAnchor or a
          // LayoutBuilder-based overflow bar in an AppBar title crashes the POS
          // with `_dependents.isEmpty` on rebuild — handoff.md §Flutter/UI.
          title: Row(
            children: [
              Flexible(
                child: Text(
                  sessionDisplayId(session),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              SessionStatusPill(status: session.status),
            ],
          ),
          // The two things you can DO with a session live in the header, where
          // they are reachable from either tab and from any scroll position —
          // rather than at the bottom of a list that grows with every payment.
          actions: [
            if (isLive && PosSessionStatus.canSell(session.status))
              _HeaderAction(
                icon: Icons.point_of_sale,
                label: l.continueSelling,
                compact: compact,
                filled: true,
                onPressed: () => _continueSelling(context, ref),
              ),
            if (isLive)
              _HeaderAction(
                icon: Icons.lock_outline,
                label:
                    blockers.isEmpty ? l.closeRegister : l.sessionCannotClose,
                compact: compact,
                onPressed: blockers.isEmpty
                    // ⚠️ Blocked while the DEVICE knows about work the server
                    // does not. Closing then would produce a Z-report missing
                    // sales that really happened — requirement §14, and the
                    // reason this check cannot live on the server.
                    ? () => _startClosing(context, ref, session)
                    : null,
              ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            // Documents before Payments: it is the order the overview states
            // them in, and "what was sold" is the coarser question.
            tabs: [
              Tab(text: l.sessionOverviewTab),
              Tab(text: l.sessionDocuments),
              Tab(text: l.sessionPaymentsTab),
            ],
          ),
        ),
        // Capped and centred so an ultra-wide monitor does not stretch a
        // label to one edge and its amount to the other. Both tabs share the
        // cap, so switching between them does not shift the column width.
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxReadableWidth),
            child: TabBarView(
              children: [
                _SessionDetail(session: session, isLive: isLive),
                _SessionDocumentsTab(session: session),
                _SessionPaymentsTab(session: session),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Back to selling — the POS tab, not "back one screen".
  ///
  /// 🚨 `Navigator.pop` was wrong here: this screen is opened from the sessions
  /// LIST as often as from the till, and popping there leaves the cashier
  /// staring at a table when what they asked for was to go and sell. Setting
  /// the shell's tab and unwinding to it lands on the POS from either entry
  /// point.
  void _continueSelling(BuildContext context, WidgetRef ref) {
    ref.read(mainNavigationIndexProvider.notifier).state = 0;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Close Register → CLOSING_CONTROL (selling stops) → the counting dialog.
  ///
  /// The transition happens BEFORE the dialog opens, deliberately: the expected
  /// figure is frozen at that moment, and a sale landing while the cashier is
  /// counting would invalidate the number they are about to sign off.
  Future<void> _startClosing(
      BuildContext context, WidgetRef ref, ShiftsTableData session) async {
    final summary = ref.read(sessionSummaryProvider(session.localId)).value;
    if (summary == null) return;

    if (session.status == PosSessionStatus.opened) {
      await ref.read(sessionNotifierProvider.notifier).enterClosingControl(
            localId: session.localId,
            expectedCash: summary.expectedCash,
          );
    }
    if (!context.mounted) return;
    final fresh = ref.read(activeSessionRowProvider).value ?? session;
    await ClosingRegisterDialog.show(context, fresh);
  }
}

/// A header button that keeps its label on a roomy screen and drops to an icon
/// on a tablet, where two labelled buttons would eat the title.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.compact,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      return IconButton(
        icon: Icon(icon),
        tooltip: label,
        onPressed: onPressed,
        style: filled
            ? IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              )
            : null,
      );
    }

    final child = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed, icon: Icon(icon, size: 18), label: child)
          : OutlinedButton.icon(
              onPressed: onPressed, icon: Icon(icon, size: 18), label: child),
    );
  }
}

/// No live session — the register is not trading.
class _NoSessionCard extends ConsumerStatefulWidget {
  const _NoSessionCard();

  @override
  ConsumerState<_NoSessionCard> createState() => _NoSessionCardState();
}

class _NoSessionCardState extends ConsumerState<_NoSessionCard> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.point_of_sale_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l.sessionNoneTitle,
                      style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.sessionNoneBody,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            const _DeviceRow(),
            const SizedBox(height: 16),
            // The float is entered in Opening Control, which is the step that
            // makes it a verified number — so there is deliberately no second
            // place to type it.
            FilledButton.icon(
              onPressed: () => OpeningControlDialog.show(context),
              icon: const Icon(Icons.lock_open),
              label: Text(l.openRegister),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One session in full: identity, takings, drawer, movements, notes, sync.
class _SessionDetail extends ConsumerWidget {
  const _SessionDetail({required this.session, this.isLive = true});

  final ShiftsTableData session;

  /// False for a closed session or another register's — read-only.
  final bool isLive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Sales banked before `sessionLocalId` was stamped at checkout carry no
    // session at all; this attaches them once, so an existing till's history
    // is not permanently blank. No-op on every later build.
    ref.watch(sessionLinkRepairProvider(session.localId));

    // 🚨 Keyed on THIS session, not on "the active one" — that is what makes a
    // closed session render its figures instead of an empty card.
    final localSummary =
        ref.watch(sessionSummaryProvider(session.localId)).value;

    // A session this terminal never ran has no orders or payments in local
    // Drift, so its takings have to come from the server. Own sessions stay on
    // local rows: complete, instant, and correct with the network down.
    final ownedHere = session.posDeviceUid != null;
    final remoteSummary = (!ownedHere && session.serverId != null)
        ? ref.watch(remoteSessionSummaryProvider(session.serverId!)).value
        : null;
    final base = remoteSummary ?? localSummary;
    // The counted drawer always comes off the session row — it is what was
    // signed off, and the server summary does not carry it.
    final summary = base?.withCountedCash(session.actualEndingCash);
    final movements =
        ref.watch(sessionCashMovementsProvider(session.localId)).value ??
            const <StartingCashTableData>[];
    final blockers = ref.watch(closeBlockersProvider(session.localId));
    final users = ref.watch(allUsersProvider).value ?? const <User>[];
    final sym = ref.watch(currencySymbolProvider);

    String money(double v) => '${v.toStringAsFixed(2)} $sym';
    final closed = session.status == PosSessionStatus.closed;
    final difference = summary?.cashDifference;

    return ListView(
      padding: EdgeInsets.all(context.isCompact ? 12 : 20),
      children: [
        _HeroCard(
          session: session,
          openedBy: _userLabel(users, session.userId),
          closedBy: session.closedByUserId == null
              ? null
              : _userLabel(users, session.closedByUserId),
        ),
        const SizedBox(height: 16),

        // ── The figures a close is judged on, before the detail behind them ──
        if (summary != null)
          _StatGrid(
            tiles: [
              _StatTile(
                icon: Icons.receipt_long,
                label: l.sessionDocuments,
                value: '${summary.documentCount}',
              ),
              _StatTile(
                icon: Icons.account_balance_wallet_outlined,
                label: l.sessionTotalTaken,
                value: money(summary.totalTaken),
              ),
              _StatTile(
                icon: Icons.savings_outlined,
                label: closed ? l.sessionColTheoretical : l.sessionExpectedCash,
                value: money(summary.expectedCash),
                accent: theme.colorScheme.primary,
              ),
              if (summary.countedCash != null)
                _StatTile(
                  icon: (difference ?? 0) == 0
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  label: l.sessionDifference,
                  value: money(difference ?? 0),
                  accent: (difference ?? 0) == 0
                      ? context.successColor
                      : context.dangerColor,
                )
              else
                _StatTile(
                  icon: Icons.timer_outlined,
                  label: l.sessionDuration,
                  value: _fmtDuration(
                      (session.closedAt ?? DateTime.now().toUtc())
                          .difference(session.openedAt)),
                ),
            ],
          ),

        if (session.forceClosed) ...[
          const SizedBox(height: 14),
          _Banner(
            icon: Icons.gavel,
            color: theme.colorScheme.error,
            text: '${l.sessionForceClosed}'
                '${session.forceCloseReason != null ? ' — ${session.forceCloseReason}' : ''}',
          ),
        ],
        if (session.hasLateArrivals) ...[
          const SizedBox(height: 14),
          _Banner(
            icon: Icons.schedule,
            color: context.warningColor,
            text: l.sessionLateArrivals,
          ),
        ],
        const SizedBox(height: 16),

        // ── Takings ───────────────────────────────────────────────────────
        if (summary != null)
          _SectionCard(
            icon: Icons.payments_outlined,
            title: l.sessionPaymentTotals,
            children: [
              for (final m in summary.methods)
                _MethodRow(
                  name: m.paymentTypeName,
                  isCash: m.isCash,
                  amount: money(m.expected),
                ),
              if (summary.methods.isEmpty)
                _Row(label: l.sessionNoPayments, value: '—'),
              const Divider(height: 20),
              _Row(
                  label: l.sessionTotalTaken,
                  value: money(summary.totalTaken),
                  bold: true),
              if (!ownedHere && remoteSummary == null) ...[
                const SizedBox(height: 10),
                _Banner(
                  icon: Icons.cloud_off,
                  color: context.warningColor,
                  text: l.sessionRemoteFiguresOffline,
                ),
              ],
              if (!summary.cashMethodsConfigured) ...[
                const SizedBox(height: 10),
                _Banner(
                  icon: Icons.info_outline,
                  color: context.warningColor,
                  text: l.sessionCashInferred,
                ),
              ],
            ],
          ),

        // ── The drawer, and how the expected figure was arrived at ─────────
        // Without the makeup the operator is handed a number with no way to see
        // where it came from — the same reason the closing dialog expands it.
        if (summary != null)
          _SectionCard(
            icon: Icons.point_of_sale_outlined,
            title: l.cashDrawer,
            children: [
              _Row(
                  label: l.sessionOpeningRow,
                  value: money(summary.openingCash)),
              _Row(
                  label: l.sessionCashPaymentsRow,
                  value: '+ ${money(summary.cashPayments)}'),
              if (summary.cashIn != 0)
                _Row(label: l.cashIn, value: '+ ${money(summary.cashIn)}'),
              if (summary.cashOut != 0)
                _Row(label: l.cashOut, value: '− ${money(summary.cashOut)}'),
              const Divider(height: 20),
              _Row(
                  label:
                      closed ? l.sessionColTheoretical : l.sessionExpectedCash,
                  value: money(summary.expectedCash),
                  bold: true),
              if (summary.countedCash != null) ...[
                _Row(
                    label: closed ? l.sessionColEnding : l.sessionCountedCash,
                    value: money(summary.countedCash!),
                    bold: true),
                const SizedBox(height: 10),
                _DifferenceBanner(
                  label: l.sessionDifference,
                  value: money(difference ?? 0),
                  isZero: (difference ?? 0) == 0,
                ),
              ],
            ],
          ),

        // ── Cash in / out ─────────────────────────────────────────────────
        // "Cash In / Out + 0.00" answers a different question from "who took
        // 200 out of the drawer at 18:40, and why".
        if (movements.isNotEmpty)
          _SectionCard(
            icon: Icons.swap_vert,
            title: l.sessionCashMovements,
            children: [
              for (final m in movements)
                _MovementRow(
                  movement: m,
                  who: _userLabel(users, m.userId),
                  money: money,
                ),
            ],
          ),

        // ── What was written down at each end ─────────────────────────────
        if ((session.openingNote ?? '').trim().isNotEmpty ||
            (session.closingNote ?? '').trim().isNotEmpty)
          _SectionCard(
            icon: Icons.sticky_note_2_outlined,
            title: l.sessionNotes,
            children: [
              if ((session.openingNote ?? '').trim().isNotEmpty)
                _NoteBlock(
                    label: l.openingNote, text: session.openingNote!.trim()),
              if ((session.closingNote ?? '').trim().isNotEmpty)
                _NoteBlock(
                    label: l.closingNote, text: session.closingNote!.trim()),
            ],
          ),

        // ── Sync + blockers ───────────────────────────────────────────────
        _SectionCard(
          icon: Icons.cloud_sync_outlined,
          title: l.sessionSyncStatus,
          children: [
            _Row(
              label: session.serverId != null
                  ? l.sessionSynced
                  : l.sessionNotSyncedYet,
              value: session.serverId != null ? '✓' : '…',
              color: session.serverId != null
                  ? context.successColor
                  : context.warningColor,
            ),
            for (final b in blockers)
              _Row(
                label: switch (b.kind) {
                  SessionCloseBlockerKind.openOrders =>
                    l.sessionOpenOrders(b.count),
                  SessionCloseBlockerKind.unsyncedSales =>
                    l.sessionUnsyncedSales(b.count),
                  SessionCloseBlockerKind.wrongState => l.sessionCannotClose,
                },
                value: '${b.count}',
                color: context.warningColor,
              ),
          ],
        ),
      ],
    );
  }
}

/// Who, where, when — and where the session stands in its lifecycle.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.session,
    required this.openedBy,
    this.closedBy,
  });

  final ShiftsTableData session;
  final String openedBy;
  final String? closedBy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final closed = session.status == PosSessionStatus.closed;
    final accent = closed ? context.successColor : theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A colour-coded spine rather than a full gradient: it reads the
            // session's state at a glance and still obeys the theme in both
            // light and dark.
            Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: accent.withValues(alpha: 0.15),
                          child: Icon(Icons.point_of_sale,
                              size: 20, color: accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.serverId != null
                                    ? '${l.sessionNumber} #${session.serverId}'
                                    : '${l.sessionNumber} '
                                        '${_shortLocal(session.localId)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _fmt(session.openedAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Chips WRAP, so a long cashier name in French pushes the
                    // rest onto a second line instead of overflowing the row.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(
                          icon: Icons.storefront,
                          text: (session.posDeviceName ?? '').trim().isEmpty
                              ? 'POS'
                              : session.posDeviceName!.trim(),
                        ),
                        _MetaChip(icon: Icons.person_outline, text: openedBy),
                        _MetaChip(
                          icon: Icons.timer_outlined,
                          text: _fmtDuration(
                              (session.closedAt ?? DateTime.now().toUtc())
                                  .difference(session.openedAt)),
                        ),
                        if (session.closedAt != null)
                          _MetaChip(
                            icon: Icons.lock_clock,
                            text: _fmt(session.closedAt!),
                          ),
                        if (closedBy != null)
                          _MetaChip(
                              icon: Icons.how_to_reg_outlined, text: closedBy!),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SessionStepper(status: session.status),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurface)),
        ],
      ),
    );
  }
}

/// The headline figures: two per row on a tablet, four on a monitor.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;

        // How many tiles fit at a readable width, measured against the space
        // this grid actually got rather than the window size. A desktop window
        // dragged narrower — or the same grid inside a split pane — collapses
        // 4 → 3 → 2 → 1 on its own, instead of staying on one breakpoint until
        // the figures are squeezed into ellipses.
        const minTileWidth = 230.0;
        final fits = ((constraints.maxWidth + gap) / (minTileWidth + gap))
            .floor();
        final perRow = fits.clamp(1, tiles.length);

        final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in tiles) SizedBox(width: width, child: t),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Scales the figure down rather than clipping it: a six-figure total
          // in a two-per-row layout is the case that would otherwise ellipsis
          // away the digits that matter.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled block of rows. Sections rather than one long card because a closed
/// session has four distinct things to say, and running them together is how
/// the important one gets missed.
class _SectionCard extends StatelessWidget {
  const _SectionCard({this.title, this.icon, required this.children});

  final String? title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

/// One payment method's total, with the drawer/electronic distinction shown
/// rather than written — the cash rows are the ones that get counted.
class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.name,
    required this.isCash,
    required this.amount,
  });

  final String name;
  final bool isCash;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isCash ? context.successColor : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(isCash ? Icons.payments : Icons.credit_card,
                size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: 8),
          Text(amount,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// The one number a manager looks for. Given its own band because "0.00" and
/// "−61.00" must not read the same at a glance.
class _DifferenceBanner extends StatelessWidget {
  const _DifferenceBanner({
    required this.label,
    required this.value,
    required this.isZero,
  });

  final String label;
  final String value;
  final bool isZero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isZero ? context.successColor : context.dangerColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(isZero ? Icons.check_circle : Icons.error_outline,
              size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: color)),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

/// Every payment the session took, newest first.
///
/// 🚨 Payments, not documents. One sale can be settled in several tenders and a
/// document can be topped up later, so the payment is the smallest thing that
/// is actually true about the drawer — and it is what the closing count is
/// reconciled against. The document it belongs to is one tap away.
class _SessionPaymentsTab extends ConsumerWidget {
  const _SessionPaymentsTab({required this.session});

  final ShiftsTableData session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entries = ref.watch(sessionPaymentsProvider(session.localId)).value ??
        const <SessionPaymentEntry>[];
    final users = ref.watch(allUsersProvider).value ?? const <User>[];
    final sym = ref.watch(currencySymbolProvider);

    String money(double v) => '${v.toStringAsFixed(2)} $sym';

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 40, color: theme.disabledColor),
              const SizedBox(height: 12),
              Text(
                l.sessionNoPayments,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final total = entries.fold<double>(0, (s, e) => s + e.payment.amount);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entries.length} · ${l.sessionPaymentsTab}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge),
                    Text(
                      l.sessionOpenDocumentHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(money(total),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = entries[i];
              final refund = e.isRefund;
              final color = refund ? context.dangerColor : null;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: (e.isCash
                          ? context.successColor
                          : theme.colorScheme.primary)
                      .withValues(alpha: 0.15),
                  child: Icon(
                    refund
                        ? Icons.undo
                        : (e.isCash ? Icons.payments : Icons.credit_card),
                    size: 18,
                    color: e.isCash
                        ? context.successColor
                        : theme.colorScheme.primary,
                  ),
                ),
                title: Text(e.documentNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${_fmt(e.payment.date)} · ${e.paymentTypeName} · '
                  '${_userLabel(users, e.payment.userId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                trailing: Text(
                  money(e.payment.amount),
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.bold, color: color),
                ),
                onTap: () => _openDocument(
                    context, ref, e, _userLabel(users, e.payment.userId)),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Opens the payment's document straight on its Payments tab — arriving from
  /// a payment and landing on the header would make the operator hunt for the
  /// row they just tapped.
  ///
  /// Built from the LOCAL row rather than the documents list: the session
  /// screen already holds it, so the editor opens with the network down and
  /// with no dependency on a list provider that may have been disposed.
  Future<void> _openDocument(BuildContext context, WidgetRef ref,
      SessionPaymentEntry entry, String userName) async {
    final l = AppLocalizations.of(context);
    final local = entry.document;
    if (local == null) {
      showAppSnackbar(context, ref, l.sessionDocumentUnavailable,
          isError: true);
      return;
    }

    await showDocumentEditor(
      context,
      ref,
      existingDocument: documentFromRow(local, userName: userName),
      initialTabIndex: kDocumentEditorPaymentsTab,
    );
  }
}

/// Every document the session banked, newest first.
///
/// 🚨 Not a duplicate of the Payments tab. One sale can be settled in several
/// tenders and a document can be topped up later, so "what was sold" and "what
/// went into the drawer" are different lists with different totals. These rows
/// are exactly what the Documents figure on the overview counts.
class _SessionDocumentsTab extends ConsumerWidget {
  const _SessionDocumentsTab({required this.session});

  final ShiftsTableData session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entries =
        ref.watch(sessionDocumentsProvider(session.localId)).value ??
            const <SessionDocumentEntry>[];
    final users = ref.watch(allUsersProvider).value ?? const <User>[];
    final sym = ref.watch(currencySymbolProvider);

    String money(double v) => '${v.toStringAsFixed(2)} $sym';

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined,
                  size: 40, color: theme.disabledColor),
              const SizedBox(height: 12),
              Text(
                // A session this register never ran has no documents in local
                // Drift; the overview says so with its own banner, so this
                // stays a plain empty state rather than repeating it.
                l.sessionNoDocuments,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    // Sums the documents themselves, so a refund pulls the band down the same
    // way it pulls the takings down.
    final total = entries.fold<double>(0, (s, e) => s + e.document.total);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entries.length} · ${l.sessionDocuments}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge),
                    Text(
                      l.sessionDocumentsHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(money(total),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = entries[i];
              final refund = e.isRefund;
              final accent =
                  refund ? context.dangerColor : theme.colorScheme.primary;
              final who = _userLabel(users, e.document.userId);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.15),
                  child: Icon(refund ? Icons.undo : Icons.receipt_long,
                      size: 18, color: accent),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(_documentNumber(context, e),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    if (e.isUnpaid) ...[
                      const SizedBox(width: 8),
                      _MiniTag(text: l.unpaid, color: context.warningColor),
                    ],
                  ],
                ),
                subtitle: Text(
                  [
                    _fmt(e.document.date),
                    if ((e.customerName ?? '').trim().isNotEmpty)
                      e.customerName!.trim(),
                    who,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                trailing: Text(
                  money(e.document.total),
                  style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: refund ? context.dangerColor : null),
                ),
                onTap: () => _openDocument(context, ref, e, who),
              );
            },
          ),
        ),
      ],
    );
  }

  /// The number, or why there isn't one yet. A blank where a document number
  /// belongs reads as data loss.
  String _documentNumber(BuildContext context, SessionDocumentEntry e) {
    final number = (e.document.number ?? '').trim();
    if (number.isNotEmpty) return number;
    return e.isPendingSync
        ? '(${AppLocalizations.of(context).pendingSync})'
        : '—';
  }

  /// Opens the document on its header tab — arriving from a document row, the
  /// header is what was tapped, unlike the payments list which lands on
  /// Payments.
  Future<void> _openDocument(BuildContext context, WidgetRef ref,
      SessionDocumentEntry entry, String userName) {
    return showDocumentEditor(
      context,
      ref,
      existingDocument: documentFromRow(
        entry.document,
        userName: userName,
        customerName: entry.customerName,
      ),
    );
  }
}

/// A small inline status tag — "Unpaid" beside a document number.
class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.bold)),
    );
  }
}

/// Which register the session belongs to.
///
/// 🚨 Prefers the name stored ON the session: this screen also shows sessions
/// pulled from OTHER tills, and reporting the local terminal's name for one of
/// those would quietly mislabel someone else's drawer.
class _DeviceRow extends ConsumerWidget {
  const _DeviceRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<String>(
      future: getDeviceName(),
      builder: (context, snap) => _Row(
        label: l.sessionColPos,
        value: (snap.data?.isNotEmpty ?? false) ? snap.data! : 'POS',
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: bold ? FontWeight.bold : null,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🚨 BOTH sides loose-Flexible, never Expanded on the label.
          // `Expanded` is a TIGHT flex child: it takes its whole share of the
          // free space whether the label needs it or not, so on a wide window
          // the value began at the midpoint and read as centred rather than
          // right-aligned. Loose children size to their own text and
          // `spaceBetween` pushes the slack between them — label hard left,
          // value hard right, at every width.
          Flexible(
            flex: 3,
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 12),
          // Still capped at its share: a long device name or a cashier's full
          // name would otherwise overflow the row on a 10-inch tablet.
          Flexible(
            flex: 2,
            child: Text(value, textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}

/// One cash in / out: direction, when, who, why, how much.
class _MovementRow extends StatelessWidget {
  const _MovementRow({
    required this.movement,
    required this.who,
    required this.money,
  });

  final StartingCashTableData movement;
  final String who;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIn = movement.type == 'in';
    final color = isIn ? context.successColor : context.dangerColor;
    final reason = (movement.note ?? movement.description ?? '').trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(isIn ? Icons.south_west : Icons.north_east,
                size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_fmt(movement.createdAt)} · $who',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                if (reason.isNotEmpty)
                  Text(reason, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${isIn ? '+' : '−'} ${money(movement.amount)}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  const _NoteBlock({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

String _shortLocal(String localId) =>
    localId.length <= 8 ? localId : '${localId.substring(0, 8)}…';

/// A person's name, falling back to `#id` for a user this device has not synced
/// (or one that has since been disabled) — an id is still an answer, and
/// blanking it would hide who touched the drawer.
String _userLabel(List<User> users, int? id) {
  if (id == null) return '—';
  for (final u in users) {
    if (u.id == id) return u.displayName;
  }
  return '#$id';
}

String _fmt(DateTime dt) {
  final local = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _fmtDuration(Duration d) {
  if (d.isNegative) return '—';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

/// The Odoo status stepper: **In Progress → Closing Control → Closed & Posted**.
///
/// A stepper rather than a single chip because a cashier needs to see not just
/// where the session is but what comes next — "Closing Control" only means
/// something as a stage between two others. Steps already passed are ticked,
/// which is what turns three labels into a sense of progress.
///
/// OPENING_CONTROL deliberately shares the first step with OPENED: to the
/// cashier it is one stage ("the register is being opened / is open"), while
/// internally they stay distinct because only one of them may take money.
class _SessionStepper extends StatelessWidget {
  const _SessionStepper({required this.status});

  final int status;

  int get _index => switch (status) {
        PosSessionStatus.openingControl => 0,
        PosSessionStatus.opened => 0,
        PosSessionStatus.closingControl => 1,
        _ => 2,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final labels = [
      l.sessionInProgress,
      l.sessionClosingControl,
      l.sessionClosedPosted,
    ];
    final accent =
        _index == 2 ? context.successColor : theme.colorScheme.primary;

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Container(
              width: 16,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: i <= _index
                  ? accent.withValues(alpha: 0.6)
                  : theme.dividerColor.withValues(alpha: 0.4),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              decoration: BoxDecoration(
                color: i == _index
                    ? accent.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: i <= _index
                      ? accent.withValues(alpha: 0.5)
                      : theme.dividerColor.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    i < _index
                        ? Icons.check_circle
                        : (i == _index
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                    size: 14,
                    color:
                        i <= _index ? accent : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: i <= _index
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: i == _index ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
