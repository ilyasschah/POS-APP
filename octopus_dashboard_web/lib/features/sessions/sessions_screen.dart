import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/pos_session.dart';
import '../../widgets/list_panel.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';
import 'session_detail_screen.dart';
import 'session_widgets.dart';
import 'sessions_controller.dart';

/// Which slice of the history the list is showing.
enum SessionFilter {
  all('All', Icons.layers_rounded),
  live('Live', Icons.sensors_rounded),
  closed('Closed', Icons.verified_rounded),
  attention('Attention', Icons.warning_amber_rounded);

  const SessionFilter(this.label, this.icon);

  final String label;
  final IconData icon;

  Color color(AppPalette palette) => switch (this) {
    SessionFilter.all => palette.accent,
    SessionFilter.live => palette.positive,
    SessionFilter.closed => palette.indigo,
    SessionFilter.attention => palette.warning,
  };
}

/// Every POS session the company has recorded, newest first — the owner-side
/// mirror of the till's Session list.
///
/// Strictly read-only. There is no open/close/force-close affordance anywhere
/// on this screen: the drawer is counted on the register that owns it, and an
/// owner closing a session from a browser would strand a till mid-count.
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  final TextEditingController _search = TextEditingController();

  String _query = '';
  SessionFilter _filter = SessionFilter.all;

  /// Register name to restrict to, or null for every register.
  String? _register;

  int _depth = 50;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// A refresh drops the cached per-session figures too — otherwise a live
  /// register would keep showing the takings it had when its row first
  /// appeared.
  void _reload() {
    ref.invalidate(sessionSummaryProvider);
    ref.invalidate(cashierNamesProvider);
    ref.read(sessionsProvider.notifier).load();
  }

  void _setDepth(int depth) {
    setState(() => _depth = depth);
    ref.invalidate(sessionSummaryProvider);
    ref.read(sessionsProvider.notifier).loadWithTake(depth);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionsProvider);
    final tier = LayoutTier.watch(context);
    final names = ref.watch(cashierNamesProvider).value ?? const {};

    return Padding(
      padding: Layout.pagePadding(tier),
      child: PageBody(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                eyebrow: 'REGISTERS',
                title: 'POS Sessions',
                onRefresh: _reload,
                isRefreshing: state.isRefreshing,
                actions: [
                  _RegisterMenu(
                    sessions: state.data ?? const [],
                    selected: _register,
                    compact: tier.isCompact,
                    onSelected: (value) => setState(() => _register = value),
                  ),
                  const SizedBox(width: 8),
                  _DepthMenu(
                    depth: _depth,
                    compact: tier.isCompact,
                    onSelected: _setDepth,
                  ),
                ],
              ),
            ),
            if (state.hasError && state.hasData)
              SliverToBoxAdapter(
                child: RefreshErrorBanner(
                  message: state.error!,
                  onRetry: _reload,
                ),
              ),
            if (state.isInitialLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingView(),
              )
            else if (state.hasError && !state.hasData)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(message: state.error!, onRetry: _reload),
              )
            else if (state.hasData)
              ..._contentSlivers(state.data!, names, tier),
          ],
        ),
      ),
    );
  }

  // --- Content ------------------------------------------------------------

  List<Widget> _contentSlivers(
    List<PosSession> sessions,
    Map<int, String> names,
    LayoutTier tier,
  ) {
    if (sessions.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            icon: Icons.point_of_sale_outlined,
            message: 'No POS sessions have been recorded yet.',
          ),
        ),
      ];
    }

    // Register + search first, so the chip counts describe what the other
    // controls have already narrowed the list to.
    final base = sessions.where(_matchesRegister).where(_matchesQuery).toList();
    final live = base.where((s) => s.isLive).toList();
    final visible = base.where((s) => _matchesFilter(s, _filter)).toList();

    return [
      if (live.isNotEmpty)
        SliverToBoxAdapter(child: _LiveStrip(sessions: live, names: names)),
      SliverToBoxAdapter(child: _StatsRow(sessions: base, depth: _depth)),
      SliverToBoxAdapter(child: _filterBar(base, tier)),
      if (visible.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyView(
            icon: Icons.filter_alt_off_rounded,
            message: 'No sessions match this filter.',
          ),
        )
      else
        SliverList.builder(
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final session = visible[index];
            return _SessionRow(
              session: session,
              names: names,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SessionDetailScreen(session: session),
                ),
              ),
            );
          },
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          child: Text(
            'Read-only. Sessions are opened, counted and closed on the '
            'register that owns the drawer.',
            textAlign: TextAlign.center,
            style: AppText.caption(context.palette.dim(0.4)),
          ),
        ),
      ),
    ];
  }

  Widget _filterBar(List<PosSession> base, LayoutTier tier) {
    final palette = context.palette;
    final chips = [
      for (final option in SessionFilter.values)
        SessionFilterChip(
          label: option.label,
          icon: option.icon,
          count: base.where((s) => _matchesFilter(s, option)).length,
          selected: _filter == option,
          color: option.color(palette),
          onTap: () => setState(() => _filter = option),
        ),
    ];

    final search = SearchField(
      controller: _search,
      hintText: 'Search register, cashier or #id',
      onChanged: (value) => setState(() => _query = value),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: tier.isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The chips scroll rather than wrap on a phone, so the search
                // box stays on the first screenful.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final chip in chips) ...[
                        chip,
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                search,
              ],
            )
          // A Wrap, not a Row: four chips plus a search box do not fit beside
          // a navigation rail at 768px, and a Row would simply overflow.
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...chips,
                SizedBox(width: 260, child: search),
              ],
            ),
    );
  }

  // --- Filtering ----------------------------------------------------------

  bool _matchesRegister(PosSession session) =>
      _register == null || session.registerName == _register;

  bool _matchesQuery(PosSession session) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;

    final names = ref.read(cashierNamesProvider).value ?? const {};
    final haystack = [
      '#${session.id}',
      session.registerName,
      session.state.title,
      session.statusName ?? '',
      cashierLabel(names, session.openedByUserId),
      cashierLabel(names, session.closedByUserId),
    ].join(' ').toLowerCase();

    return haystack.contains(query);
  }

  bool _matchesFilter(PosSession session, SessionFilter filter) =>
      switch (filter) {
        SessionFilter.all => true,
        SessionFilter.live => session.isLive,
        SessionFilter.closed => !session.isLive,
        SessionFilter.attention => session.needsAttention,
      };
}

// --- Header controls ------------------------------------------------------

/// Restricts the list to one register. `''` is the "all registers" value —
/// [PopupMenuButton] cannot carry a null value.
class _RegisterMenu extends StatelessWidget {
  const _RegisterMenu({
    required this.sessions,
    required this.selected,
    required this.compact,
    required this.onSelected,
  });

  final List<PosSession> sessions;
  final String? selected;
  final bool compact;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final registers =
        sessions.map((s) => s.registerName).toSet().toList()..sort();

    return PopupMenuButton<String>(
      tooltip: 'Filter by register',
      position: PopupMenuPosition.under,
      onSelected: (value) => onSelected(value.isEmpty ? null : value),
      itemBuilder: (context) => [
        const PopupMenuItem(value: '', child: Text('All registers')),
        for (final register in registers)
          PopupMenuItem(value: register, child: Text(register)),
      ],
      child: GlassPill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_rounded,
              size: 15,
              color: palette.primaryText,
            ),
            if (!compact) ...[
              const SizedBox(width: 7),
              Text(
                selected ?? 'All registers',
                style: AppText.label(palette.primaryText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// How deep into the history to read — the API's `take`.
class _DepthMenu extends StatelessWidget {
  const _DepthMenu({
    required this.depth,
    required this.compact,
    required this.onSelected,
  });

  final int depth;
  final bool compact;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopupMenuButton<int>(
      tooltip: 'How many sessions to load',
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in kSessionHistoryDepths)
          PopupMenuItem(value: option, child: Text('Last $option')),
      ],
      child: GlassPill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 15, color: palette.primaryText),
            if (!compact) ...[
              const SizedBox(width: 7),
              Text('Last $depth', style: AppText.label(palette.primaryText)),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Live strip -----------------------------------------------------------

class _LiveStrip extends StatelessWidget {
  const _LiveStrip({required this.sessions, required this.names});

  final List<PosSession> sessions;
  final Map<int, String> names;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SessionSectionLabel(text: 'Live now', showPulse: true),
        SizedBox(
          // Tall enough for the card's tallest content (pill, register, two
          // figures and the float line). Any slack lands above the float row,
          // which a Spacer pins to the bottom of the card.
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sessions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _LiveSessionCard(
              session: sessions[index],
              names: names,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _LiveSessionCard extends ConsumerWidget {
  const _LiveSessionCard({required this.session, required this.names});

  final PosSession session;
  final Map<int, String> names;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final color = sessionTint(palette, session.state);
    final summary = ref.watch(sessionSummaryProvider(session.id)).value;

    return Container(
      width: 258,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SessionDetailScreen(session: session),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SessionStatusPill(state: session.state),
                    const Spacer(),
                    Text(
                      '#${session.id}',
                      style: AppText.caption(palette.dim(0.4)).weighted(700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  session.registerName,
                  style: AppText.style(
                    size: 19,
                    weight: 800,
                    color: palette.primaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${cashierLabel(names, session.openedByUserId)} · open '
                  '${Fmt.duration(session.elapsed)}',
                  style: AppText.caption(palette.dim(0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: palette.primaryText.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'Taken',
                        value: summary == null
                            ? null
                            : Fmt.currency(summary.totalTaken),
                      ),
                    ),
                    _MiniStat(
                      label: 'Orders',
                      value: summary == null ? null : '${summary.orderCount}',
                      alignEnd: true,
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      size: 13,
                      color: palette.dim(0.45),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Float ${Fmt.currency(session.openingCash)}',
                        style: AppText.caption(palette.dim(0.5)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, this.value, this.alignEnd = false});

  final String label;

  /// Null renders a skeleton — the figure is still being fetched.
  final String? value;

  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AppText.caption(palette.dim(0.45)).weighted(700),
        ),
        const SizedBox(height: 2),
        if (value == null)
          _SkeletonBar(width: alignEnd ? 34 : 88)
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignEnd
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Text(
              value!,
              style: AppText.style(
                size: 17,
                weight: 800,
                color: palette.primaryText,
              ),
              maxLines: 1,
            ),
          ),
      ],
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width, this.height = 15});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.primaryText.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

// --- Headline figures -----------------------------------------------------

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.sessions, required this.depth});

  final List<PosSession> sessions;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final live = sessions.where((s) => s.isLive).toList();
    final flagged = sessions.where((s) => s.needsAttention).length;
    final variance = sessions
        .where((s) => s.cashDifference != null)
        .fold<double>(0, (sum, s) => sum + s.cashDifference!);
    final balanced = variance.abs() < 0.005;

    final cards = <Widget>[
      SessionStatCard(
        label: 'Live now',
        value: '${live.length}',
        caption: live.isEmpty
            ? 'No register trading'
            : live.map((s) => s.registerName).join(', '),
        icon: Icons.sensors_rounded,
        color: palette.positive,
      ),
      SessionStatCard(
        label: 'Sessions',
        value: '${sessions.length}',
        caption: 'Last $depth loaded',
        icon: Icons.layers_rounded,
        color: palette.accent,
      ),
      SessionStatCard(
        label: 'Cash variance',
        value: Fmt.signedCurrency(variance),
        caption: balanced
            ? 'Drawers balanced'
            : (variance < 0 ? 'Short over this window' : 'Over this window'),
        icon: Icons.swap_vert_rounded,
        color: balanced
            ? palette.neutral
            : (variance < 0 ? palette.negative : palette.positive),
      ),
      SessionStatCard(
        label: 'Needs attention',
        value: '$flagged',
        caption: flagged == 0
            ? 'All clean'
            : 'Variance, force-close or late sales',
        icon: Icons.warning_amber_rounded,
        color: flagged == 0 ? palette.neutral : palette.warning,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Four across on a desktop window, two-by-two once that would squeeze
          // the currency figures.
          final columns = constraints.maxWidth >= 760 ? 4 : 2;
          const gap = 12.0;
          final width =
              (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final card in cards) SizedBox(width: width, child: card),
            ],
          );
        },
      ),
    );
  }
}

// --- Rows -----------------------------------------------------------------

class _SessionRow extends ConsumerWidget {
  const _SessionRow({
    required this.session,
    required this.names,
    required this.onTap,
  });

  final PosSession session;
  final Map<int, String> names;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final summary = ref.watch(sessionSummaryProvider(session.id));

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          SessionStateGlyph(state: session.state),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.registerName,
                        style: AppText.bodyStrong(
                          palette.primaryText,
                        ).weighted(700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '#${session.id}',
                        style: AppText.caption(palette.dim(0.45)).weighted(600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (session.forceClosed) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.bolt_rounded,
                        size: 14,
                        color: palette.negative,
                      ),
                    ],
                    if (session.hasLateArrivals) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: palette.warning,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _timeline,
                  style: AppText.caption(palette.dim(0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  cashierLabel(names, session.openedByUserId),
                  style: AppText.caption(palette.dim(0.45)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RowFigures(session: session, summary: summary),
          const SizedBox(width: 2),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: palette.dim(0.3),
          ),
        ],
      ),
    );
  }

  String get _timeline {
    final opened = Fmt.shortDateTime(session.openedAt);
    if (session.closedAt != null) {
      return '$opened → ${Fmt.time(session.closedAt)} · '
          '${Fmt.duration(session.elapsed)}';
    }
    return '$opened · open ${Fmt.duration(session.elapsed)}';
  }
}

class _RowFigures extends StatelessWidget {
  const _RowFigures({required this.session, required this.summary});

  final PosSession session;
  final AsyncValue<PosSessionSummary> summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final data = summary.value;

    // Capped so the register name beside it always keeps a readable share of a
    // 360px row; the figure scales down inside the cap rather than overflowing.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (data != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                Fmt.currency(data.totalTaken),
                style: AppText.bodyStrong(palette.accent).weighted(700),
                maxLines: 1,
              ),
            ),
          )
        else if (summary.hasError)
          Text('—', style: AppText.bodyStrong(palette.dim(0.5)))
        else
          const _SkeletonBar(width: 84),
        const SizedBox(height: 3),
        if (data != null)
          Text(
            '${data.orderCount} orders',
            style: AppText.caption(palette.dim(0.5)),
          )
        else if (summary.hasError)
          Text('no figures', style: AppText.caption(palette.dim(0.4)))
        else
          const _SkeletonBar(width: 52, height: 11),
        if (session.hasCashDifference) ...[
          const SizedBox(height: 5),
          _DifferenceChip(value: session.cashDifference!),
        ],
      ],
    );
  }
}

class _DifferenceChip extends StatelessWidget {
  const _DifferenceChip({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = value < 0 ? palette.negative : palette.positive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        Fmt.signedCurrency(value),
        style: AppText.caption(color).weighted(700),
      ),
    );
  }
}
