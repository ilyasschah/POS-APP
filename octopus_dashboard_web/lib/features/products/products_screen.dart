import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/product.dart';
import '../../widgets/list_panel.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';
import 'edit_price_dialog.dart';
import 'products_controller.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider);
    final tier = LayoutTier.watch(context);
    final reload = ref.read(productsProvider.notifier).load;

    return Padding(
      padding: Layout.pagePadding(tier),
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Products & Prices',
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
              child: ScreenStateBuilder<List<Product>>(
                state: state,
                onRetry: reload,
                builder: (context, products) {
                  final filtered = products
                      .where((p) => p.matches(_query))
                      .toList(growable: false);

                  if (filtered.isEmpty) {
                    return EmptyView(
                      icon: Icons.sell_outlined,
                      message: products.isEmpty
                          ? 'No products found for this company.'
                          : 'No products match "$_query".',
                    );
                  }

                  return ListPanel(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _ProductRow(
                      product: filtered[index],
                      onTap: () =>
                          showEditPriceSheet(context, filtered[index]),
                    ),
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

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListRow(
      onTap: onTap,
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
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Fmt.currency(product.price),
                style: AppText.bodyStrong(palette.accent),
              ),
              const SizedBox(height: 2),
              Text(
                'Cost ${Fmt.currency(product.cost)}',
                style: AppText.caption(palette.dim(0.55)),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: palette.dim(0.3),
          ),
        ],
      ),
    );
  }
}
