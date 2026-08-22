import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/pos_session.dart';
import '../../widgets/list_panel.dart';
import 'session_widgets.dart';
import 'sessions_controller.dart';

/// One session, end to end: who ran it, what it took, how the drawer
/// reconciled, and every flag the server raised against it.
///
/// Read-only. The figures come from `/PosSession/Summary`, which recomputes
/// them against the database on every call — so for a CLOSED session they can
/// legitimately disagree with the frozen figures on the session row itself.
/// Where they do, **both** are shown rather than one silently winning: that
/// gap is money that reached the server after the count.
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.session});

  final PosSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tier = LayoutTier.watch(context);
    final async = ref.watch(sessionSummaryProvider(session.id));
    final summary = async.value;
    final names = ref.watch(cashierNamesProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Session #${session.id}',
          style: AppText.title(palette.primaryText).copyWith(fontSize: 19),
        ),
        iconTheme: IconThemeData(color: palette.primaryText),
        actions: [
          IconButton(
            tooltip: 'Refresh figures',
            onPressed: () =>
                ref.invalidate(sessionSummaryProvider(session.id)),
            icon: Icon(Icons.refresh_rounded, color: palette.primaryText),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: Layout.pagePadding(tier).copyWith(bottom: 32),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero(session: session, names: names),
                if (async.hasError) ...[
                  const SizedBox(height: 16),
                  _SummaryError(
                    error: async.error,
                    onRetry: () =>
                        ref.invalidate(sessionSummaryProvider(session.id)),
                  ),
                ],
                for (final flag in _flags(palette, names, summary)) ...[
                  const SizedBox(height: 12),
                  _FlagBanner(flag: flag),
                ],
                const SizedBox(height: 16),
                _Section(
                  title: 'Takings',
                  child: _Takings(summary: summary, loading: async.isLoading),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Cash reconciliation',
                  child: _CashReconciliation(
                    session: session,
                    summary: summary,
                    loading: async.isLoading,
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Payment mix',
                  child: _PaymentMix(
                    summary: summary,
                    loading: async.isLoading,
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Audit trail',
                  child: _AuditTrail(
                    session: session,
                    summary: summary,
                    names: names,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Read-only. Opening, counting and closing all happen on the '
                  'register that owns the drawer.',
                  textAlign: TextAlign.center,
                  style: AppText.caption(palette.dim(0.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Everything worth interrupting the reader for, in severity order.
  List<_Flag> _flags(
    AppPalette palette,
    Map<int, String> names,
    PosSessionSummary? summary,
  ) {
    final flags = <_Flag>[];

    if (session.forceClosed) {
      final reason = session.forceCloseReason?.trim() ?? '';
      flags.add(
        _Flag(
          icon: Icons.bolt_rounded,
          color: palette.negative,
          title:
              'Force-closed by ${cashierLabel(names, session.forceClosedByUserId)}',
          message: reason.isEmpty
              ? 'No reason recorded. A force-close never counts the drawer — '
                    'it exists for a register nobody can reach.'
              : reason,
        ),
      );
    }

    if (session.hasLateArrivals) {
      flags.add(
        _Flag(
          icon: Icons.schedule_rounded,
          color: palette.warning,
          title: 'Late sales arrived',
          message:
              'A sale reached the server after this session closed. It kept '
              'this session and a Z-report correction was raised — the closed '
              'figures were deliberately not rewritten.',
        ),
      );
    }

    final note = session.closingNote?.trim() ?? '';
    if (note.isNotEmpty) {
      flags.add(
        _Flag(
          icon: Icons.sticky_note_2_outlined,
          color: palette.indigo,
          title: 'Closing note',
          message: note,
        ),
      );
    }

    if (summary != null && !summary.cashMethodsConfigured) {
      flags.add(
        _Flag(
          icon: Icons.help_outline_rounded,
          color: palette.warning,
          title: 'Cash methods were inferred',
          message:
              'This company has no PosSession.CashPaymentTypeIds setting, so '
              'which methods come out of the drawer was guessed. That moves '
              'money between counted and merely confirmed.',
        ),
      );
    }

    if (session.state == PosSessionState.closingControl) {
      flags.add(
        _Flag(
          icon: Icons.checklist_rounded,
          color: palette.indigo,
          title: 'Counting in progress',
          message:
              'Selling has already stopped. Totals are frozen while the drawer '
              'is counted, so no sale can land between the expected figure and '
              'the count.',
        ),
      );
    }

    if (session.state == PosSessionState.openingControl) {
      flags.add(
        _Flag(
          icon: Icons.hourglass_top_rounded,
          color: palette.warning,
          title: 'Opening float not confirmed',
          message:
              'The register is claimed but not trading. Until the float is '
              'confirmed, every later expected-cash figure would be built on '
              'an unverified balance.',
        ),
      );
    }

    return flags;
  }
}

// --- Hero -----------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.session, required this.names});

  final PosSession session;
  final Map<int, String> names;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = sessionTint(palette, session.state);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SessionStatusPill(state: session.state),
              const Spacer(),
              Text(
                session.statusName ?? session.state.title,
                style: AppText.caption(palette.dim(0.4)).weighted(600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            session.registerName,
            style: AppText.style(
              size: 26,
              weight: 800,
              color: palette.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            session.state.explanation,
            style: AppText.caption(palette.dim(0.65)).copyWith(fontSize: 13),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: palette.primaryText.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          _FactRow(
            icon: Icons.north_east_rounded,
            color: palette.positive,
            label: 'Opened',
            value: Fmt.dateTime(session.openedAt),
            detail: cashierLabel(names, session.openedByUserId),
          ),
          const SizedBox(height: 10),
          _FactRow(
            icon: Icons.south_east_rounded,
            color: session.closedAt == null ? palette.warning : palette.indigo,
            label: 'Closed',
            value: session.closedAt == null
                ? 'Still open'
                : Fmt.dateTime(session.closedAt),
            detail: session.closedAt == null
                ? '—'
                : cashierLabel(names, session.closedByUserId),
          ),
          const SizedBox(height: 10),
          _FactRow(
            icon: Icons.timer_outlined,
            color: palette.accent,
            label: session.isLive ? 'Open for' : 'Duration',
            value: Fmt.duration(session.elapsed),
            detail: '',
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(label, style: AppText.caption(palette.dim(0.6)).copyWith(fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                textAlign: TextAlign.end,
                style: AppText.label(palette.primaryText).weighted(700),
              ),
              if (detail.isNotEmpty)
                Text(
                  detail,
                  textAlign: TextAlign.end,
                  style: AppText.caption(palette.dim(0.45)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Takings --------------------------------------------------------------

class _Takings extends StatelessWidget {
  const _Takings({required this.summary, required this.loading});

  final PosSessionSummary? summary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final data = summary;
    if (data == null) return _Pending(loading: loading);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StatColumn(
            label: 'Total taken',
            value: Fmt.currency(data.totalTaken),
            caption: 'All methods',
          ),
        ),
        _VerticalDivider(color: palette.primaryText.withValues(alpha: 0.1)),
        Expanded(
          child: _StatColumn(
            label: 'Orders',
            value: '${data.orderCount}',
            caption: 'Documents banked',
          ),
        ),
        _VerticalDivider(color: palette.primaryText.withValues(alpha: 0.1)),
        Expanded(
          child: _StatColumn(
            label: 'Average',
            value: Fmt.currency(data.averageSale),
            caption: 'Per order',
          ),
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppText.caption(palette.dim(0.45)).weighted(700),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppText.style(
              size: 17,
              weight: 800,
              color: palette.primaryText,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: AppText.caption(palette.dim(0.4)),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: color,
    );
  }
}

// --- Cash reconciliation --------------------------------------------------

class _CashReconciliation extends StatelessWidget {
  const _CashReconciliation({
    required this.session,
    required this.summary,
    required this.loading,
  });

  final PosSession session;
  final PosSessionSummary? summary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final data = summary;
    final difference = session.cashDifference;

    return Column(
      children: [
        _MoneyRow(
          symbol: '',
          label: 'Opening float',
          caption: 'Counted at opening control',
          value: Fmt.currency(session.openingCash),
        ),
        if (data != null) ...[
          _MoneyRow(
            symbol: '+',
            label: 'Cash payments',
            value: Fmt.currency(data.cashPayments),
          ),
          _MoneyRow(
            symbol: '+',
            label: 'Cash in',
            caption: 'Top-ups into the drawer',
            value: Fmt.currency(data.cashIn),
          ),
          _MoneyRow(
            symbol: '−',
            label: 'Cash out',
            caption: 'Drops and pay-outs',
            value: Fmt.currency(data.cashOut),
          ),
        ] else
          _Pending(loading: loading),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Divider(
            height: 1,
            color: palette.primaryText.withValues(alpha: 0.1),
          ),
        ),
        _MoneyRow(
          symbol: '=',
          label: 'Expected cash',
          caption: session.expectedCash == null
              ? 'Computed live'
              : 'Frozen when counting started',
          value: _expectedText(data),
          emphasis: true,
        ),
        _MoneyRow(
          symbol: '',
          label: 'Counted',
          caption: session.actualEndingCash == null
              ? 'The drawer has not been counted yet'
              : 'What the cashier signed off',
          value: session.actualEndingCash == null
              ? '—'
              : Fmt.currency(session.actualEndingCash),
          emphasis: true,
        ),
        if (difference != null)
          _MoneyRow(
            symbol: '',
            label: 'Difference',
            caption: difference < -0.005
                ? 'Short'
                : (difference > 0.005 ? 'Over' : 'Balanced'),
            value: Fmt.signedCurrency(difference),
            emphasis: true,
            color: difference.abs() < 0.005
                ? palette.positive
                : (difference < 0 ? palette.negative : palette.warning),
          ),
        if (data != null) ...[
          _Note(icon: Icons.shield_outlined, text: _toleranceNote(data)),
          if (_recomputedNote(data) != null)
            _Note(icon: Icons.sync_rounded, text: _recomputedNote(data)!),
        ],
      ],
    );
  }

  String _expectedText(PosSessionSummary? data) {
    final frozen = session.expectedCash;
    if (frozen != null) return Fmt.currency(frozen);
    if (data != null) return Fmt.currency(data.expectedCash);
    return '—';
  }

  String _toleranceNote(PosSessionSummary data) {
    final tolerance = Fmt.currency(data.maxCashDifference);
    final difference = session.cashDifference;
    if (difference == null) {
      return 'Tolerance ±$tolerance — beyond that, closing needs manager '
          'authorisation.';
    }
    return difference.abs() <= data.maxCashDifference
        ? 'Within the ±$tolerance tolerance.'
        : 'Beyond the ±$tolerance tolerance — this close required manager '
              'authorisation.';
  }

  /// Only worth showing when the live recomputation disagrees with what was
  /// frozen at close — which is exactly what late sales look like afterwards.
  String? _recomputedNote(PosSessionSummary data) {
    final frozen = session.expectedCash;
    if (frozen == null) return null;
    if ((data.expectedCash - frozen).abs() < 0.005) return null;
    return 'Recomputed now: ${Fmt.currency(data.expectedCash)}. The frozen '
        'figure above is what the cashier was held to; the gap is money that '
        'reached the server after the count.';
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.symbol,
    required this.label,
    required this.value,
    this.caption,
    this.emphasis = false,
    this.color,
  });

  final String symbol;
  final String label;
  final String? caption;
  final String value;
  final bool emphasis;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            child: Text(
              symbol,
              style: AppText.label(palette.dim(0.35)).weighted(700),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: emphasis
                      ? AppText.bodyStrong(palette.primaryText)
                      : AppText.body(palette.dim(0.75)),
                ),
                if (caption != null)
                  Text(caption!, style: AppText.caption(palette.dim(0.45))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: emphasis
                ? AppText.style(
                    size: 17,
                    weight: 800,
                    color: color ?? palette.primaryText,
                  )
                : AppText.body(color ?? palette.primaryText),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: palette.dim(0.4)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppText.caption(palette.dim(0.55))),
          ),
        ],
      ),
    );
  }
}

// --- Payment mix ----------------------------------------------------------

class _PaymentMix extends StatelessWidget {
  const _PaymentMix({required this.summary, required this.loading});

  final PosSessionSummary? summary;
  final bool loading;

  static const List<int> _paletteOrder = [0, 1, 2, 3, 4, 5];

  Color _colorFor(AppPalette palette, int index) {
    final colors = [
      palette.accent,
      palette.indigo,
      palette.warning,
      palette.positive,
      palette.negative,
      palette.neutral,
    ];
    return colors[_paletteOrder[index % _paletteOrder.length]];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final data = summary;
    if (data == null) return _Pending(loading: loading);

    if (data.methods.isEmpty) {
      return Text(
        'No payments were taken in this session.',
        style: AppText.body(palette.dim(0.6)),
      );
    }

    // Only positive slices go in the ring — a refund-heavy method can be
    // negative, and a negative sweep angle renders as nonsense.
    final slices = data.methods.where((m) => m.expected > 0).toList();

    return Column(
      children: [
        if (slices.isNotEmpty)
          SizedBox(
            height: 176,
            child: Stack(
              alignment: Alignment.center,
              children: [
                RepaintBoundary(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 54,
                      startDegreeOffset: -90,
                      sections: [
                        for (var i = 0; i < slices.length; i++)
                          PieChartSectionData(
                            value: slices[i].expected,
                            color: _colorFor(
                              palette,
                              data.methods.indexOf(slices[i]),
                            ),
                            radius: 22,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TAKEN',
                      style: AppText.caption(palette.dim(0.45)).weighted(700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Fmt.currency(data.totalTaken),
                      style: AppText.style(
                        size: 15,
                        weight: 800,
                        color: palette.primaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (slices.isNotEmpty) const SizedBox(height: 14),
        for (var i = 0; i < data.methods.length; i++) ...[
          _MethodRow(
            method: data.methods[i],
            color: _colorFor(palette, i),
            total: data.totalTaken,
          ),
          if (i != data.methods.length - 1)
            Divider(
              height: 12,
              color: palette.primaryText.withValues(alpha: 0.08),
            ),
        ],
      ],
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    required this.color,
    required this.total,
  });

  final PosSessionMethod method;
  final Color color;
  final double total;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final share = total.abs() < 0.005
        ? '—'
        : '${(method.expected / total * 100).toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  method.name,
                  style: AppText.body(palette.primaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  method.isCash
                      ? 'Cash — physically counted'
                      : 'Confirmed, not counted',
                  style: AppText.caption(palette.dim(0.45)),
                ),
                if (method.counted != null)
                  Text(
                    'Counted ${Fmt.currency(method.counted)}',
                    style: AppText.caption(palette.dim(0.45)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Fmt.currency(method.expected),
                style: AppText.bodyStrong(palette.primaryText).weighted(700),
              ),
              Text(share, style: AppText.caption(palette.dim(0.45))),
              if (method.difference != null &&
                  method.difference!.abs() >= 0.005)
                Text(
                  Fmt.signedCurrency(method.difference),
                  style: AppText.caption(
                    method.difference! < 0
                        ? palette.negative
                        : palette.positive,
                  ).weighted(700),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Audit ----------------------------------------------------------------

class _AuditTrail extends StatelessWidget {
  const _AuditTrail({
    required this.session,
    required this.summary,
    required this.names,
  });

  final PosSession session;
  final PosSessionSummary? summary;
  final Map<int, String> names;

  @override
  Widget build(BuildContext context) {
    final data = summary;
    return Column(
      children: [
        _KeyValue(label: 'Session id', value: '#${session.id}'),
        _KeyValue(label: 'Register', value: session.registerName),
        _KeyValue(
          label: 'Register id',
          value: session.posDeviceId?.toString() ?? '—',
        ),
        _KeyValue(label: 'Device local id', value: session.localId ?? '—'),
        _KeyValue(label: 'Company id', value: '${session.companyId}'),
        _KeyValue(
          label: 'Status',
          value:
              '${session.status} · ${session.statusName ?? session.state.title}',
        ),
        _KeyValue(
          label: 'Opened by',
          value:
              '${cashierLabel(names, session.openedByUserId)} (#${session.openedByUserId})',
        ),
        if (session.closedByUserId != null)
          _KeyValue(
            label: 'Closed by',
            value:
                '${cashierLabel(names, session.closedByUserId)} (#${session.closedByUserId})',
          ),
        if (session.forceClosedByUserId != null)
          _KeyValue(
            label: 'Force-closed by',
            value:
                '${cashierLabel(names, session.forceClosedByUserId)} (#${session.forceClosedByUserId})',
          ),
        _KeyValue(
          label: 'Last modified',
          value: Fmt.dateTime(session.lastModified),
        ),
        if (data != null) ...[
          _KeyValue(
            label: 'Cash methods',
            value: data.cashMethodsConfigured ? 'Configured' : 'Inferred',
          ),
          _KeyValue(
            label: 'Tolerance',
            value: Fmt.currency(data.maxCashDifference),
          ),
        ],
      ],
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: AppText.caption(palette.dim(0.5))),
          ),
          Expanded(
            flex: 3,
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: AppText.caption(palette.dim(0.8)),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Shared bits ----------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SessionSectionLabel(text: title),
        GlassCard(child: child),
      ],
    );
  }
}

class _Flag {
  const _Flag({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
}

class _FlagBanner extends StatelessWidget {
  const _FlagBanner({required this.flag});

  final _Flag flag;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: flag.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.controlRadius + 4),
        border: Border.all(color: flag.color.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(flag.icon, size: 18, color: flag.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  flag.title,
                  style: AppText.bodyStrong(palette.primaryText),
                ),
                const SizedBox(height: 3),
                Text(
                  flag.message,
                  style: AppText.caption(palette.dim(0.65)).copyWith(
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder for a section whose figures have not arrived (or failed).
class _Pending extends StatelessWidget {
  const _Pending({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else
            Icon(Icons.remove_rounded, size: 16, color: palette.dim(0.4)),
          const SizedBox(width: 10),
          Text(
            loading
                ? 'Reading the session figures…'
                : 'Figures unavailable for this session.',
            style: AppText.caption(palette.dim(0.55)),
          ),
        ],
      ),
    );
  }
}

class _SummaryError extends StatelessWidget {
  const _SummaryError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Could not load this session\'s figures. $error';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: palette.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: palette.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppText.caption(palette.primaryText),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
