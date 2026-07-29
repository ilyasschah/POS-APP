import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/stock.dart';
import '../../widgets/list_panel.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';
import 'stock_controller.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  final _searchController = TextEditingController();
  String _query = '';

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
                  final filtered = rows
                      .where((r) => r.product.matches(_query))
                      .toList(growable: false);

                  if (filtered.isEmpty) {
                    return EmptyView(
                      icon: Icons.inventory_2_outlined,
                      message: rows.isEmpty
                          ? 'No products found for this company.'
                          : 'No products match "$_query".',
                    );
                  }

                  return ListPanel(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _StockRow(entry: filtered[index]),
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

/// Read-only row — the Stock screen never edits quantities.
class _StockRow extends StatelessWidget {
  const _StockRow({required this.entry});

  final ProductStock entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final product = entry.product;

    return ListRow(
      child: Row(
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
                if (product.code != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    product.code!,
                    style: AppText.caption(palette.dim(0.6)),
                  ),
                ],
                // Per-warehouse breakdown, only when split across more than
                // one warehouse.
                if (entry.isMultiWarehouse) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.entries
                        .map(
                          (e) =>
                              '${e.warehouseName}: ${Fmt.quantity(e.quantity)}',
                        )
                        .join('  •  '),
                    style: AppText.caption(palette.dim(0.5)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _QuantityLabel(entry: entry),
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
      return Text(
        'Unassigned',
        style: AppText.bodyStrong(palette.neutral),
      );
    }

    final total = entry.totalQuantity;
    return Text(
      Fmt.quantity(total),
      style: AppText.bodyStrong(
        total > 0 ? palette.accent : palette.negative,
      ).weighted(700),
    );
  }
}
