import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/core/app_date_picker.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/dashboard/dashboard_model.dart';
import 'package:pos_app/dashboard/dashboard_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _kTeal = Color(0xFF00C896);
const _kTealDim = Color(0xFF008F6B);
const _kAmber = Color(0xFFFFB347);
const _kBlue = Color(0xFF4F9EFF);

const _kPieColors = [
  Color(0xFF00C896),
  Color(0xFF4F9EFF),
  Color(0xFFFFB347),
  Color(0xFFFF6B8A),
  Color(0xFF9F7AEA),
];

/// Month abbreviations for the chart axis, 1-indexed (`[0]` is a filler so
/// `_months(context)[month]` works directly against `DateTime.month`).
///
/// Read from the `monthAbbreviations` .arb key rather than `intl`'s
/// `DateFormat.MMM(locale)` — that needs `initializeDateFormatting` at boot,
/// which this app never calls. Same source the document screens use.
List<String> _months(BuildContext context) =>
    ['', ...AppLocalizations.of(context).monthAbbreviations.split(',')];

TextStyle _mono({
  double size = 13,
  FontWeight weight = FontWeight.w600,
  Color? color,
}) =>
    TextStyle(
      fontFamily: 'Roboto Mono',
      fontSize: size,
      fontWeight: weight,
      color: color,
    );

TextStyle _sans({
  double size = 13,
  FontWeight weight = FontWeight.w500,
  Color? color,
}) =>
    TextStyle(
      fontFamily: 'Roboto',
      fontSize: size,
      fontWeight: weight,
      color: color,
    );

// ── Screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const DashboardScreen({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Suppress the auto back-arrow — ManagementLayout controls navigation.
        automaticallyImplyLeading: false,
        leading: onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: AppLocalizations.of(context).showNavigation,
                onPressed: onMenuPressed,
              )
            : null,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _kTeal,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context).dashboard,
              style: _sans(
                size: 18,
                weight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: AppLocalizations.of(context).refreshAll,
            onPressed: () {
              ref.invalidate(yearlyDashboardProvider);
              ref.invalidate(periodicDashboardProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _YearlyOverviewCard(),
            SizedBox(height: 28),
            _PeriodicFilterBar(),
            SizedBox(height: 16),
            _PeriodicGrid(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Yearly Overview Card ──────────────────────────────────────────────────────

class _YearlyOverviewCard extends ConsumerWidget {
  const _YearlyOverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final sym = ref.watch(currencySymbolProvider);
    final async = ref.watch(yearlyDashboardProvider);
    final year = DateTime.now().year;

    return Container(
      height: 272,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Gradient accent stripe
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_kTeal, _kBlue]),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  AppLocalizations.of(context).failedToLoadYearlyData,
                  style: _sans(color: cs.error),
                ),
              ),
              data: (data) => _YearlyContent(data: data, sym: sym, year: year),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearlyContent extends StatelessWidget {
  final DashboardData data;
  final String sym;
  final int year;

  const _YearlyContent({
    required this.data,
    required this.sym,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Sorted months for top-month detection
    final sorted = List<MonthlySale>.from(data.monthlySales)
      ..sort((a, b) => b.total.compareTo(a.total));
    final topMonth = sorted.isNotEmpty ? sorted.first : null;

    // Max Y with headroom. Floor at a positive value: once refunds are netted
    // out the top month can be 0 (or negative), and fl_chart asserts if the
    // grid's horizontalInterval (maxY / 4) is zero.
    final rawMaxY = data.monthlySales.isEmpty ? 0.0 : sorted.first.total * 1.4;
    final maxY = rawMaxY <= 0 ? 100.0 : rawMaxY;

    final tooltipBg = cs.inverseSurface;
    final tooltipFg = cs.onInverseSurface;
    final fmt = NumberFormat.currency(symbol: sym, decimalDigits: 2);
    final gridColor = cs.outlineVariant.withValues(alpha: 0.25);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Bar chart (65%) ──────────────────────────────────────────────────
        Expanded(
          flex: 65,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).monthlySalesYear('$year'),
                  style: _sans(
                    size: 11,
                    weight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ).copyWith(letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: BarChart(
                    BarChartData(
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: gridColor, strokeWidth: 0.5),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx > 11) {
                                return const SizedBox.shrink();
                              }
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  _months(context)[idx + 1],
                                  style: _sans(
                                    size: 9,
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(12, (index) {
                        final month = index + 1;
                        final monthTotal = data.monthlySales
                            .where((s) => s.month == month)
                            .fold<double>(0, (sum, s) => sum + s.total);
                        final isTop = topMonth?.month == month;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: monthTotal,
                              gradient: LinearGradient(
                                colors: isTop
                                    ? [_kAmber, _kAmber.withValues(alpha: 0.6)]
                                    : [_kTeal, _kTealDim],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: 13,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => tooltipBg,
                          getTooltipItem: (group, _, rod, __) {
                            final label = _months(context)[group.x + 1];
                            return BarTooltipItem(
                              '$label\n',
                              _sans(
                                size: 11,
                                weight: FontWeight.w700,
                                color: tooltipFg,
                              ),
                              children: [
                                TextSpan(
                                  text: fmt.format(rod.toY),
                                  style: _mono(size: 11, color: _kTeal),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Hairline divider
        VerticalDivider(
          width: 1,
          thickness: 0.5,
          color: cs.outlineVariant.withValues(alpha: 0.4),
          indent: 16,
          endIndent: 16,
        ),

        // ── Summary panel (35%) ──────────────────────────────────────────────
        Expanded(
          flex: 35,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppLocalizations.of(context).yearTotal,
                  style: _sans(
                    size: 10,
                    weight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ).copyWith(letterSpacing: 1.2),
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: data.totalSales),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      fmt.format(value),
                      style: _mono(
                        size: 26,
                        weight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (topMonth != null) ...[
                  Text(
                    AppLocalizations.of(context).topMonth,
                    style: _sans(
                      size: 10,
                      weight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.38),
                    ).copyWith(letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _kAmber.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _kAmber.withValues(alpha: 0.35),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _months(context)[topMonth.month].toUpperCase(),
                          style: _sans(
                            size: 13,
                            weight: FontWeight.w800,
                            color: _kAmber,
                          ).copyWith(letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fmt.format(topMonth.total),
                          style: _mono(size: 12, color: _kAmber),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(
                    context,
                  ).activeMonthsCount(data.monthlySales.length),
                  style: _sans(
                    size: 11,
                    color: cs.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Periodic filter bar ───────────────────────────────────────────────────────

class _PeriodicFilterBar extends ConsumerWidget {
  const _PeriodicFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final range = ref.watch(dashboardDateProvider);
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).periodicReports,
              style: _sans(
                size: 20,
                weight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              AppLocalizations.of(context).selectDateRangeToFilter,
              style: _sans(
                size: 12,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const Spacer(),
        // Date range button
        OutlinedButton.icon(
          icon: Icon(
            Icons.date_range_outlined,
            size: 15,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
          label: Text(
            '${dateFmt.format(range.start)}  –  ${dateFmt.format(range.end)}',
            style: _mono(
              size: 11,
              weight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.85),
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            side: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.6),
              width: 0.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () async {
            final result = await showAppDateRangePicker(
              context,
              initialStart: range.start,
              initialEnd: range.end,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (result != null) {
              ref
                  .read(dashboardDateProvider.notifier)
                  .update(
                    DashboardDateRange(
                      start: result.start,
                      end: DateTime(
                        result.end.year,
                        result.end.month,
                        result.end.day,
                        23,
                        59,
                        59,
                      ),
                    ),
                  );
            }
          },
        ),
      ],
    );
  }
}

// ── Periodic grid (4 cards) ───────────────────────────────────────────────────

class _PeriodicGrid extends StatelessWidget {
  const _PeriodicGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 1100 ? 3 : (w >= 680 ? 2 : 1);
        const gap = 16.0;
        final cardW = (w - gap * (cols - 1)) / cols;

        Widget sized(Widget child) =>
            SizedBox(width: cardW, height: 310, child: child);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            sized(const _TopProductsCard()),
            sized(const _TotalSalesCard()),
            sized(const _TopGroupsCard()),
            sized(const _TopCustomersCard()),
          ],
        );
      },
    );
  }
}

// ── Shared card shell ─────────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color accent;

  const _DashCard({
    required this.title,
    required this.child,
    this.accent = _kTeal,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent stripe
          Container(
            height: 2.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.0)],
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 0),
            child: Row(
              children: [
                Text(
                  title,
                  style: _sans(
                    size: 10,
                    weight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ).copyWith(letterSpacing: 1.0),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Content
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  /// Null falls back to the localized "no data" copy. It cannot be a default
  /// parameter value: those must be `const`, and `AppLocalizations` needs a
  /// BuildContext — which only exists once [build] runs.
  final String? message;
  const _EmptyState({this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 36,
            color: cs.onSurface.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 10),
          Text(
            message ?? AppLocalizations.of(context).noDataToDisplay,
            style: _sans(size: 12, color: cs.onSurface.withValues(alpha: 0.32)),
          ),
        ],
      ),
    );
  }
}

// ── Card A: Top Products ──────────────────────────────────────────────────────

class _TopProductsCard extends ConsumerWidget {
  const _TopProductsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(periodicDashboardProvider);
    final sym = ref.watch(currencySymbolProvider);
    final cs = Theme.of(context).colorScheme;

    return _DashCard(
      title: AppLocalizations.of(context).topProducts,
      accent: _kTeal,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _EmptyState(message: AppLocalizations.of(context).errorLoadingData),
        data: (data) {
          if (data.topProducts.isEmpty) return const _EmptyState();
          final maxT = data.topProducts.first.total;
          final fmt = NumberFormat.currency(symbol: sym, decimalDigits: 2);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Column(
              children: data.topProducts.take(5).map((p) {
                final ratio = maxT > 0 ? (p.total / maxT).clamp(0.0, 1.0) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.productName,
                              style: _sans(size: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '×${p.quantity.toStringAsFixed(0)}',
                            style: _mono(
                              size: 10,
                              color: cs.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fmt.format(p.total),
                            style: _mono(
                              size: 10,
                              weight: FontWeight.w700,
                              color: _kTeal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 3,
                          backgroundColor: cs.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                          valueColor: AlwaysStoppedAnimation(
                            _kTeal.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

// ── Card C: Total Sales (period) ──────────────────────────────────────────────

class _TotalSalesCard extends ConsumerWidget {
  const _TotalSalesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(periodicDashboardProvider);
    final sym = ref.watch(currencySymbolProvider);
    final cs = Theme.of(context).colorScheme;

    return _DashCard(
      title: AppLocalizations.of(context).totalRevenue,
      accent: _kTeal,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _EmptyState(message: AppLocalizations.of(context).errorLoadingData),
        data: (data) {
          final fmt = NumberFormat.currency(symbol: sym, decimalDigits: 2);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: data.totalSales),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) => FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        fmt.format(value),
                        style: _mono(
                          size: 34,
                          weight: FontWeight.w800,
                          color: _kTeal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _kTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _kTeal.withValues(alpha: 0.25),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context).selectedPeriod,
                      style: _sans(
                        size: 11,
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  if (data.topProducts.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Divider(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                      thickness: 0.5,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _MiniStat(
                          label: AppLocalizations.of(context).products,
                          value: '${data.topProducts.length}',
                        ),
                        _MiniStat(
                          label: AppLocalizations.of(context).customersLabel,
                          value: '${data.topCustomers.length}',
                        ),
                        _MiniStat(
                          label: AppLocalizations.of(context).categoriesLabel,
                          value: '${data.topProductGroups.length}',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: _mono(size: 16, weight: FontWeight.w700, color: cs.onSurface),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: _sans(size: 10, color: cs.onSurface.withValues(alpha: 0.4)),
        ),
      ],
    );
  }
}

// ── Card D: Top Product Groups (Pie) ──────────────────────────────────────────

class _TopGroupsCard extends ConsumerStatefulWidget {
  const _TopGroupsCard();

  @override
  ConsumerState<_TopGroupsCard> createState() => _TopGroupsCardState();
}

class _TopGroupsCardState extends ConsumerState<_TopGroupsCard> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(periodicDashboardProvider);
    final cs = Theme.of(context).colorScheme;

    return _DashCard(
      title: AppLocalizations.of(context).productGroupsUpper,
      accent: _kPieColors[1],
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _EmptyState(message: AppLocalizations.of(context).errorLoadingData),
        data: (data) {
          final total = data.topProductGroups.fold<double>(
            0,
            (s, g) => s + g.total,
          );
          // No data, or everything netted out by refunds → nothing to chart.
          // A zero total would make the pie compute value/total = NaN angles.
          if (data.topProductGroups.isEmpty || total <= 0) {
            return const _EmptyState();
          }
          final fmt = NumberFormat.compact(locale: 'en');

          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(
              children: [
                // Pie chart
                SizedBox(
                  width: 120,
                  child: PieChart(
                    PieChartData(
                      sections: data.topProductGroups.asMap().entries.map((e) {
                        final i = e.key;
                        final group = e.value;
                        final pct = total > 0
                            ? (group.total / total * 100)
                            : 0.0;
                        final isTouched = _touched == i;
                        return PieChartSectionData(
                          // Clamp: a net-negative group (more refunded than
                          // sold) must not feed a negative slice into the pie.
                          value: group.total > 0 ? group.total : 0,
                          color: _kPieColors[i % _kPieColors.length],
                          radius: isTouched ? 52 : 42,
                          showTitle: isTouched,
                          title: '${pct.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFFFFF),
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 1.5,
                      centerSpaceRadius: 22,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            _touched =
                                response?.touchedSection?.touchedSectionIndex ??
                                -1;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Legend
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: data.topProductGroups.asMap().entries.map((e) {
                      final i = e.key;
                      final group = e.value;
                      final color = _kPieColors[i % _kPieColors.length];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.5),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                group.groupName,
                                style: _sans(
                                  size: 11,
                                  color: cs.onSurface.withValues(alpha: 0.75),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              fmt.format(group.total),
                              style: _mono(
                                size: 10,
                                weight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Card E: Top Customers ─────────────────────────────────────────────────────

class _TopCustomersCard extends ConsumerWidget {
  const _TopCustomersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(periodicDashboardProvider);
    final sym = ref.watch(currencySymbolProvider);
    final cs = Theme.of(context).colorScheme;

    return _DashCard(
      title: AppLocalizations.of(context).topCustomers,
      accent: _kAmber,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _EmptyState(message: AppLocalizations.of(context).errorLoadingData),
        data: (data) {
          if (data.topCustomers.isEmpty) return const _EmptyState();
          final fmt = NumberFormat.currency(symbol: sym, decimalDigits: 2);
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: Column(
              children: data.topCustomers.take(5).toList().asMap().entries.map((
                e,
              ) {
                final rank = e.key + 1;
                final customer = e.value;
                final isFirst = rank == 1;
                final rankColor = isFirst
                    ? _kAmber
                    : cs.onSurface.withValues(alpha: 0.35);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      // Rank badge
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: isFirst
                              ? _kAmber.withValues(alpha: 0.15)
                              : cs.outlineVariant.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: rankColor.withValues(alpha: 0.4),
                            width: 0.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '#$rank',
                            style: _mono(
                              size: 9,
                              weight: FontWeight.w800,
                              color: rankColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Name
                      Expanded(
                        child: Text(
                          customer.customerName,
                          style: _sans(size: 12, weight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Total
                      Text(
                        fmt.format(customer.total),
                        style: _mono(
                          size: 11,
                          weight: FontWeight.w700,
                          color: isFirst
                              ? _kAmber
                              : cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
