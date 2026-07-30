import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/document.dart';
import '../../widgets/list_panel.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';
import 'document_detail_screen.dart';
import 'documents_controller.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentsProvider);
    final tier = LayoutTier.watch(context);
    final reload = ref.read(documentsProvider.notifier).load;

    return Padding(
      padding: Layout.pagePadding(tier),
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Documents',
              onRefresh: reload,
              isRefreshing: state.isRefreshing,
            ),
            if (state.hasError && state.hasData)
              RefreshErrorBanner(message: state.error!, onRetry: reload),
            Expanded(
              child: ScreenStateBuilder<List<SalesDocument>>(
                state: state,
                onRetry: reload,
                builder: (context, documents) {
                  if (documents.isEmpty) {
                    return const EmptyView(
                      icon: Icons.description_outlined,
                      message: 'No sales documents yet.',
                    );
                  }
                  return ListPanel(
                    itemCount: documents.length,
                    itemBuilder: (context, index) => _DocumentRow(
                      document: documents[index],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DocumentDetailScreen(document: documents[index]),
                        ),
                      ),
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

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document, required this.onTap});

  final SalesDocument document;
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
                  document.number,
                  style: AppText.bodyStrong(palette.primaryText).weighted(700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  document.customerName,
                  style: AppText.caption(palette.dim(0.7)).copyWith(
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  Fmt.date(document.date),
                  style: AppText.caption(palette.dim(0.5)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            Fmt.currency(document.total),
            style: AppText.bodyStrong(palette.accent),
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
