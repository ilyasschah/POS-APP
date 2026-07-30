import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/document.dart';
import '../../widgets/list_panel.dart';
import 'documents_controller.dart';

/// Full page (not a dialog) — there's enough content here to warrant its own
/// route, especially at compact widths.
class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({super.key, required this.document});

  final SalesDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tier = LayoutTier.watch(context);
    final items = ref.watch(documentItemsProvider(document.id));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          document.number,
          style: AppText.title(palette.primaryText).copyWith(fontSize: 19),
        ),
        iconTheme: IconThemeData(color: palette.primaryText),
      ),
      body: ListView(
        padding: Layout.pagePadding(tier).copyWith(bottom: 32),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Section(
                  title: 'Document',
                  child: Column(
                    children: [
                      _DetailRow(label: 'Number', value: document.number),
                      _DetailRow(
                        label: 'Type',
                        value: document.documentTypeName,
                      ),
                      _DetailRow(
                        label: 'Date',
                        value: Fmt.dateTime(document.date),
                      ),
                      _DetailRow(
                        label: 'Customer',
                        value: document.customerName,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Totals',
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total',
                          style: AppText.body(palette.dim(0.7)),
                        ),
                      ),
                      Text(
                        Fmt.currency(document.total),
                        style: AppText.bodyStrong(palette.accent).weighted(700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Line Items',
                  child: items.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.6),
                        ),
                      ),
                    ),
                    // Surface the fetch's own error text, and offer a retry by
                    // invalidating this document's provider.
                    error: (error, _) => _InlineError(
                      message: error is ApiException
                          ? error.message
                          : 'Could not load line items. $error',
                      onRetry: () =>
                          ref.invalidate(documentItemsProvider(document.id)),
                    ),
                    data: (lines) {
                      if (lines.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No line items for this document.',
                            style: AppText.body(palette.dim(0.6)),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < lines.length; i++) ...[
                            _LineItemRow(item: lines[i]),
                            if (i != lines.length - 1)
                              Divider(
                                height: 1,
                                color: palette.primaryText.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                          ],
                        ],
                      );
                    },
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: AppText.eyebrow(palette.dim(0.55)),
          ),
        ),
        GlassCard(child: child),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: AppText.body(palette.dim(0.7))),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppText.bodyStrong(palette.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({required this.item});

  final DocumentLineItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.productName,
                  style: AppText.body(palette.primaryText),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${Fmt.quantity(item.quantity)} × ${Fmt.currency(item.price)}',
                  style: AppText.caption(palette.dim(0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            Fmt.currency(item.total),
            style: AppText.bodyStrong(palette.primaryText).weighted(600),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: palette.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: AppText.body(palette.primaryText)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
