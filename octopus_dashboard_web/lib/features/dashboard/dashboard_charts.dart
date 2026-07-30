import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/dashboard.dart';

/// Compact axis labels: 1250 -> "1.3k", 2000000 -> "2M".
String _compactAxisLabel(double value) {
  final abs = value.abs();
  if (abs >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (abs >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toStringAsFixed(0);
}

/// Monthly Sales Trend — bar chart of month abbreviation × total.
class MonthlySalesChart extends StatelessWidget {
  const MonthlySalesChart({super.key, required this.data});

  final List<MonthlySales> data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxValue = data.fold<double>(0, (max, e) => e.total > max ? e.total : max);
    // Headroom above the tallest bar so the top label isn't clipped.
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;

    return RepaintBoundary(
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].total,
                    width: data.length > 8 ? 12 : 18,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        palette.accent.withValues(alpha: 0.55),
                        palette.accent,
                      ],
                    ),
                  ),
                ],
              ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: palette.primaryText.withValues(alpha: 0.08),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  _compactAxisLabel(value),
                  style: AppText.caption(palette.dim(0.5)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      data[index].label,
                      style: AppText.caption(palette.dim(0.6)).weighted(600),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => palette.base.withValues(alpha: 0.92),
              tooltipBorderRadius: BorderRadius.circular(10),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = data[group.x];
                return BarTooltipItem(
                  '${item.label}\n',
                  AppText.caption(palette.dim(0.7)),
                  children: [
                    TextSpan(
                      text: Fmt.currency(item.total),
                      style: AppText.label(palette.accent),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Hourly Peak Times — line chart with a filled area beneath it.
class HourlySalesChart extends StatelessWidget {
  const HourlySalesChart({super.key, required this.data});

  final List<HourlySales> data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxValue = data.fold<double>(0, (max, e) => e.total > max ? e.total : max);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;

    return RepaintBoundary(
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          minX: 0,
          maxX: (data.length - 1).toDouble().clamp(0, double.infinity),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < data.length; i++)
                  FlSpot(i.toDouble(), data[i].total),
              ],
              isCurved: true,
              // Keeps the smoothed curve from dipping below zero between
              // points, which would render a filled area under the axis.
              preventCurveOverShooting: true,
              barWidth: 3,
              color: palette.indigo,
              dotData: FlDotData(
                show: data.length <= 12,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 3,
                      color: palette.indigo,
                      strokeWidth: 1.5,
                      strokeColor: palette.base,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.indigo.withValues(alpha: 0.35),
                    palette.indigo.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: palette.primaryText.withValues(alpha: 0.08),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  _compactAxisLabel(value),
                  style: AppText.caption(palette.dim(0.5)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                // With many hours in range, label every other point so they
                // don't collide on narrow phone viewports.
                interval: data.length > 8 ? 2 : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 ||
                      index >= data.length ||
                      (value - index).abs() > 0.01) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      data[index].label,
                      style: AppText.caption(palette.dim(0.6)),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => palette.base.withValues(alpha: 0.92),
              tooltipBorderRadius: BorderRadius.circular(10),
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${data[spot.x.toInt()].label}\n',
                    AppText.caption(palette.dim(0.7)),
                    children: [
                      TextSpan(
                        text: Fmt.currency(spot.y),
                        style: AppText.label(palette.indigo),
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
