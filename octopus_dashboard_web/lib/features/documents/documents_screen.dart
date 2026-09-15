import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/ilyass_list_scaffold.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/document.dart';
import '../../widgets/list_panel.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';
import 'document_detail_screen.dart';
import 'document_editor_screen.dart';
import 'documents_controller.dart';

/// Every document the company holds, newest as the server orders them, with a
/// search and the one way to start a new one.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentsProvider);
    final reload = ref.read(documentsProvider.notifier).load;

    return IlyassListScaffold(
      title: 'Documents',
      searchBar: SearchField(
        controller: _search,
        hintText: 'Search number, customer or type',
        onChanged: (value) => setState(() => _query = value),
      ),
      onRefresh: reload,
      isRefreshing: state.isRefreshing,
      banner: state.hasError && state.hasData
          ? RefreshErrorBanner(message: state.error!, onRetry: reload)
          : null,
      fabLabel: 'New document',
      onFabPressed: () => openDocumentEditor(context),
      body: ScreenStateBuilder<List<SalesDocument>>(
        state: state,
        onRetry: reload,
        builder: (context, documents) {
          if (documents.isEmpty) {
            return const EmptyView(
              icon: Icons.description_outlined,
              message: 'No documents yet. Start one with New document.',
            );
          }
          final shown = [
            for (final document in documents)
              if (document.matches(_query)) document,
          ];
          if (shown.isEmpty) {
            return EmptyView(
              icon: Icons.search_off_rounded,
              message: 'No documents match "${_query.trim()}".',
            );
          }
          return ListPanel(
            // Room under the last row for the New document button.
            padding: const EdgeInsets.only(top: 4, bottom: 88),
            itemCount: shown.length,
            itemBuilder: (context, index) => _DocumentRow(
              document: shown[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DocumentDetailScreen(document: shown[index]),
                ),
              ),
            ),
          );
        },
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
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Tag(label: document.documentTypeName),
                    if (document.isPosDocument)
                      _Tag(label: 'Register', color: palette.accent),
                    Text(
                      Fmt.date(document.date),
                      style: AppText.caption(palette.dim(0.5)),
                    ),
                  ],
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = color ?? palette.primaryText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tint.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.style(
          size: 12,
          weight: 600,
          color: color ?? palette.dim(0.75),
        ),
      ),
    );
  }
}
