import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/breakpoints.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/product.dart';
import '../../models/stock.dart';
import '../../models/unit_of_measure.dart';
import '../../widgets/list_panel.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';
import '../sessions/session_widgets.dart' show SessionFilterChip;
import 'stock_controller.dart';

/// Which rows the list shows. Counted within the current search.
enum _StockFilter {
  all('All', Icons.inventory_2_outlined),
  low('Low', Icons.warning_amber_rounded),
  reorder('Reorder', Icons.shopping_cart_outlined),
  unassigned('Unassigned', Icons.help_outline_rounded);

  const _StockFilter(this.label, this.icon);

  final String label;
  final IconData icon;

  bool accepts(ProductStock s) => switch (this) {
    _StockFilter.all => true,
    _StockFilter.low => s.isLow,
    _StockFilter.reorder => s.needsReorder,
    _StockFilter.unassigned => s.isUnassigned,
  };
}

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _StockFilter _filter = _StockFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockProvider);
    final tier = LayoutTier.watch(context);
    final reload = ref.read(stockProvider.notifier).load;
    final palette = context.palette;

    return Padding(
      padding: Layout.pagePadding(tier),
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Stock',
              onRefresh: reload,
              isRefreshing: state.isRefreshing,
            ),
            SearchField(
              controller: _searchController,
              hintText: 'Search by name or code',
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 14),
            if (state.hasError && state.hasData)
              RefreshErrorBanner(message: state.error!, onRetry: reload),
            Expanded(
              child: ScreenStateBuilder<List<ProductStock>>(
                state: state,
                onRetry: reload,
                builder: (context, rows) {
                  final searched = rows
                      .where((r) => r.product.matches(_query))
                      .toList(growable: false);
                  final filtered = searched
                      .where(_filter.accepts)
                      .toList(growable: false);

                  Color tint(_StockFilter f) => switch (f) {
                    _StockFilter.all => palette.accent,
                    _StockFilter.low => palette.negative,
                    _StockFilter.reorder => palette.warning,
                    _StockFilter.unassigned => palette.neutral,
                  };

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in _StockFilter.values)
                            SessionFilterChip(
                              label: f.label,
                              icon: f.icon,
                              count: searched.where(f.accepts).length,
                              selected: _filter == f,
                              color: tint(f),
                              onTap: () => setState(() => _filter = f),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: filtered.isEmpty
                            ? EmptyView(
                                icon: Icons.inventory_2_outlined,
                                message: rows.isEmpty
                                    ? 'No products found for this company.'
                                    : _query.isEmpty
                                    ? 'No products in "${_filter.label}".'
                                    : 'No products match "$_query".',
                              )
                            : ListPanel(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) =>
                                    _StockRow(entry: filtered[index]),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only row — the Stock screen never edits quantities or rules.
class _StockRow extends StatelessWidget {
  const _StockRow({required this.entry});

  final ProductStock entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final product = entry.product;

    final details = [
      if (product.code != null && product.code!.isNotEmpty) product.code!,
      _unitLine(product),
    ].join('  •  ');

    return ListRow(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.displayName,
                  style: AppText.bodyStrong(palette.primaryText).weighted(700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  style: AppText.caption(palette.dim(0.6)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Per-warehouse breakdown, only when split across more than
                // one warehouse.
                if (entry.isMultiWarehouse) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.entries
                        .map((e) => '${e.warehouseName}: ${entry.format(e.quantity)}')
                        .join('  •  '),
                    style: AppText.caption(palette.dim(0.5)),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _ruleTags(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _QuantityLabel(entry: entry),
        ],
      ),
    );
  }

  /// "Sold by kg", "Sold by box of 12 pcs", "Sold by g · stock in kg".
  static String _unitLine(Product p) {
    final sale = p.saleUnit;
    final stock = p.stockUnit;
    final weighed = p.isToWeigh ? ' · weighed' : '';
    if (sale.id == stock.id) return 'Sold by ${sale.code}$weighed';
    if (sale.id == kUomBox || sale.id == kUomPack) {
      final size = p.packSize ?? (sale.id == kUomBox ? 12 : 6);
      return 'Sold by ${sale.code} of ${formatUomQuantity(size, stock)}$weighed';
    }
    return 'Sold by ${sale.code} · stock in ${stock.code}$weighed';
  }

  List<Widget> _ruleTags(BuildContext context) {
    final palette = context.palette;
    final rule = entry.rule;
    if (rule == null || rule.isEmpty) {
      return [
        _Tag(
          icon: Icons.rule_rounded,
          text: 'No stock rules',
          color: palette.dim(0.45),
        ),
      ];
    }

    final supplier = rule.supplierName?.trim() ?? '';
    return [
      if (rule.hasLowStockWarning)
        _Tag(
          icon: Icons.notifications_active_outlined,
          text: 'Warn at ${entry.format(rule.lowStockWarningQuantity)}',
          color: entry.isLow ? palette.negative : palette.dim(0.65),
        )
      else if (rule.lowStockWarningQuantity > 0)
        _Tag(
          icon: Icons.notifications_off_outlined,
          text: 'Warning off',
          color: palette.dim(0.45),
        ),
      if (rule.hasReorderPoint)
        _Tag(
          icon: Icons.autorenew_rounded,
          text: 'Reorder at ${entry.format(rule.reorderPoint)}',
          color: entry.needsReorder ? palette.warning : palette.dim(0.65),
        ),
      if (rule.preferredQuantity > 0)
        _Tag(
          icon: Icons.flag_outlined,
          text: 'Target ${entry.format(rule.preferredQuantity)}',
          color: palette.dim(0.65),
        ),
      // The one thing to DO about a reorder flag: how much, from whom.
      if (entry.needsReorder && entry.suggestedOrder > 0)
        _Tag(
          icon: Icons.shopping_cart_outlined,
          text: 'Order ${entry.format(entry.suggestedOrder)}',
          color: palette.warning,
        ),
      if (supplier.isNotEmpty)
        _Tag(
          icon: Icons.local_shipping_outlined,
          text: supplier,
          color: palette.dim(0.65),
        ),
    ];
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: AppText.caption(color).weighted(600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityLabel extends StatelessWidget {
  const _QuantityLabel({required this.entry});

  final ProductStock entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (entry.isUnassigned) {
      return Text('Unassigned', style: AppText.bodyStrong(palette.neutral));
    }

    final total = entry.totalQuantity;
    final color = entry.isLow
        ? palette.negative
        : entry.needsReorder
        ? palette.warning
        : total > 0
        ? palette.accent
        : palette.negative;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          entry.format(total),
          style: AppText.bodyStrong(color).weighted(700),
        ),
        if (entry.isLow || entry.needsReorder) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              entry.isLow ? 'LOW' : 'REORDER',
              style: AppText.style(
                size: 10,
                weight: 800,
                color: color,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
