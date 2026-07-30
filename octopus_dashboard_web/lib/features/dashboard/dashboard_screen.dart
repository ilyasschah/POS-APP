import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/dashboard.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';
import 'dashboard_charts.dart';
import 'dashboard_controller.dart';
import 'date_filter_panel.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final palette = context.palette;
    final tier = LayoutTier.watch(context);
    final reload = ref.read(dashboardProvider.notifier).load;

    return ListView(
      padding: Layout.pagePadding(tier).copyWith(bottom: 32),
      children: [
        PageHeader(
          eyebrow: 'OVERVIEW',
          title: 'Octopus Dashboard',
          onRefresh: reload,
          isRefreshing: state.isRefreshing,
          actions: [
            GlassPill(
              onTap: () => showDateFilter(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 15,
                    color: palette.primaryText,
                  ),
                  // The label is dropped on the narrowest phones so the header
                  // never overflows; the icon still communicates the action.
                  if (!tier.isCompact ||
                      MediaQuery.sizeOf(context).width > 380) ...[
                    const SizedBox(width: 7),
                    Text(
                      'Filter Date',
                      style: AppText.label(palette.primaryText),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        if (state.hasError && state.hasData)
          RefreshErrorBanner(message: state.error!, onRetry: reload),

        if (state.isInitialLoading)
          const LoadingView()
        else if (state.hasError && !state.hasData)
          ErrorView(message: state.error!, onRetry: reload)
        else if (state.hasData)
          _DashboardContent(data: state.data!, tier: tier),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data, required this.tier});

  final DashboardData data;
  final LayoutTier tier;

  @override
  Widget build(BuildContext context) {
    final secondaryCards = <Widget>[
      if (data.monthlySales.isNotEmpty)
        _ChartCard(
          title: 'Monthly Sales Trend',
          height: 190,
          chart: MonthlySalesChart(
            key: const ValueKey('monthly-sales'),
            data: data.monthlySales,
          ),
        ),
      if (data.hourlySales.isNotEmpty)
        _ChartCard(
          title: 'Hourly Peak Times',
          height: 165,
          chart: HourlySalesChart(
            key: const ValueKey('hourly-sales'),
            data: data.hourlySales,
          ),
        ),
      if (data.topProducts.isNotEmpty)
        _RankedListCard(
          title: 'Top Products',
          rows: [
            for (final p in data.topProducts.take(5))
              _RankedRow(
                title: p.productName,
                subtitle: '${Fmt.quantity(p.quantity)} sold',
                trailing: Fmt.currency(p.total),
                useAccent: true,
              ),
          ],
        ),
      if (data.topCustomers.isNotEmpty)
        _RankedListCard(
          title: 'Top Customers',
          rows: [
            for (final c in data.topCustomers.take(5))
              _RankedRow(
                title: c.customerName,
                trailing: Fmt.currency(c.total),
                useAccent: false,
              ),
          ],
        ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Layout.maxContentWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TotalSalesCard(total: data.totalSales),
            const SizedBox(height: 16),
            if (secondaryCards.isEmpty)
              const EmptyView(
                message: 'No sales activity in the selected date range.',
                icon: Icons.query_stats_rounded,
              )
            else if (tier.isExpanded)
              _TwoColumnCards(cards: secondaryCards)
            else
              for (final card in secondaryCards) ...[
                card,
                const SizedBox(height: 16),
              ],
          ],
        ),
      ),
    );
  }
}

/// Splits cards across two columns on wide viewports. Columns are independent,
/// so cards of differing heights stack without stretching each other.
class _TwoColumnCards extends StatelessWidget {
  const _TwoColumnCards({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      (i.isEven ? left : right).add(cards[i]);
    }

    Widget column(List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items) ...[item, const SizedBox(height: 16)],
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(left)),
        const SizedBox(width: 16),
        Expanded(child: column(right)),
      ],
    );
  }
}

class _TotalSalesCard extends StatelessWidget {
  const _TotalSalesCard({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Total Sales', style: AppText.body(palette.dim(0.7))),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.currency(total),
              style: AppText.hero(palette.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.chart,
    required this.height,
  });

  final String title;
  final Widget chart;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppText.headline(palette.primaryText)),
          const SizedBox(height: 16),
          SizedBox(height: height, child: chart),
        ],
      ),
    );
  }
}

class _RankedRow {
  const _RankedRow({
    required this.title,
    this.subtitle,
    required this.trailing,
    required this.useAccent,
  });

  final String title;
  final String? subtitle;
  final String trailing;

  /// Top Products use the teal accent; Top Customers use indigo.
  final bool useAccent;
}

class _RankedListCard extends StatelessWidget {
  const _RankedListCard({required this.title, required this.rows});

  final String title;
  final List<_RankedRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppText.headline(palette.primaryText)),
          const SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rows[i].title,
                          style: AppText.bodyStrong(palette.primaryText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (rows[i].subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            rows[i].subtitle!,
                            style: AppText.caption(palette.dim(0.6)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    rows[i].trailing,
                    style: AppText.bodyStrong(
                      rows[i].useAccent ? palette.accent : palette.indigo,
                    ).weighted(700),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1)
              Divider(
                height: 1,
                color: palette.primaryText.withValues(alpha: 0.1),
              ),
          ],
        ],
      ),
    );
  }
}
