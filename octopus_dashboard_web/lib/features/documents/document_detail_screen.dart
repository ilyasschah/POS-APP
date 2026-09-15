import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/glass.dart';
import '../../core/ilyass_form.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/document.dart';
import '../../widgets/list_panel.dart';
import 'document_editor_screen.dart';
import 'documents_controller.dart';

/// Full page (not a dialog) — there's enough content here to warrant its own
/// route, especially at compact widths.
///
/// A document created by hand can be edited or deleted from here. One rung up
/// on a register cannot: its stock and payments belong to the flow that wrote
/// it, so the page says where to change it instead.
class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({super.key, required this.document});

  final SalesDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tier = LayoutTier.watch(context);
    // The list's copy, once it has one — so an edit made from this page shows
    // here as soon as the list reloads.
    final current =
        ref.watch(
          documentsProvider.select(
            (s) => s.data?.where((d) => d.id == document.id).firstOrNull,
          ),
        ) ??
        document;
    final items = ref.watch(documentItemsProvider(current.id));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          current.number,
          style: AppText.title(palette.primaryText).copyWith(fontSize: 19),
        ),
        iconTheme: IconThemeData(color: palette.primaryText),
        actions: [
          if (!current.isPosDocument) ...[
            IconButton(
              tooltip: 'Edit document',
              icon: Icon(Icons.edit_outlined, color: palette.primaryText),
              onPressed: () async {
                final saved = await openDocumentEditor(
                  context,
                  document: current,
                );
                if (saved == true) {
                  ref.invalidate(documentItemsProvider(current.id));
                }
              },
            ),
            IconButton(
              tooltip: 'Delete document',
              icon: Icon(Icons.delete_outline_rounded, color: palette.negative),
              onPressed: () => _delete(context, current),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: ListView(
        padding: Layout.pagePadding(tier).copyWith(bottom: 32),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (current.isPosDocument) ...[
                  const _RegisterNotice(),
                  const SizedBox(height: 16),
                ],
                _Section(
                  title: 'Document',
                  child: Column(
                    children: [
                      IlyassValueRow(label: 'Number', value: current.number),
                      IlyassValueRow(
                        label: 'Type',
                        value: current.documentTypeName,
                      ),
                      IlyassValueRow(
                        label: 'Date',
                        value: Fmt.dateTime(current.date),
                      ),
                      IlyassValueRow(
                        label: 'Customer',
                        value: current.customerName,
                      ),
                      if (current.warehouseName != null)
                        IlyassValueRow(
                          label: 'Warehouse',
                          value: current.warehouseName!,
                        ),
                      if (current.userName != null)
                        IlyassValueRow(
                          label: 'Handled by',
                          value: current.userName!,
                        ),
                      if ((current.referenceDocumentNumber ?? '').isNotEmpty)
                        IlyassValueRow(
                          label: 'Reference',
                          value: current.referenceDocumentNumber!,
                        ),
                      if ((current.note ?? '').isNotEmpty)
                        IlyassValueRow(label: 'Note', value: current.note!),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Totals',
                  child: IlyassValueRow(
                    label: 'Total',
                    value: Fmt.currency(current.total),
                    emphasis: true,
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
                          ref.invalidate(documentItemsProvider(current.id)),
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

  Future<void> _delete(BuildContext context, SalesDocument current) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDocumentDialog(document: current),
    );
    if (deleted != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await Navigator.of(context).maybePop();
    messenger.showSnackBar(
      SnackBar(content: Text('Deleted ${current.number}.')),
    );
  }
}

/// Confirms a delete and runs it, staying open with the server's message if
/// the delete is refused.
class _DeleteDocumentDialog extends ConsumerStatefulWidget {
  const _DeleteDocumentDialog({required this.document});

  final SalesDocument document;

  @override
  ConsumerState<_DeleteDocumentDialog> createState() =>
      _DeleteDocumentDialogState();
}

class _DeleteDocumentDialogState extends ConsumerState<_DeleteDocumentDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(documentsProvider.notifier)
          .deleteDocument(widget.document);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted && !e.isCancelled) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Layout.maxDialogWidth),
        child: GlassCard.overlay(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Delete ${widget.document.number}?',
                style: AppText.headline(palette.primaryText),
              ),
              const SizedBox(height: 10),
              Text(
                'Its lines, taxes and payments go with it, and any stock its '
                "lines moved is given back. This can't be undone.",
                style: AppText.body(palette.dim(0.8)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppText.body(palette.negative).weighted(600),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        foregroundColor: palette.dim(0.85),
                      ),
                      child: const Text('Keep document'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _delete,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        backgroundColor: palette.negative,
                        foregroundColor: AppTheme.onAccent(palette.negative),
                      ),
                      child: _busy
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppTheme.onAccent(palette.negative),
                              ),
                            )
                          : const Text('Delete document'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterNotice extends StatelessWidget {
  const _RegisterNotice();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: palette.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.point_of_sale_rounded, size: 20, color: palette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Rung up on a register. Change or remove it from the POS, which '
              'keeps its stock and payments in step.',
              style: AppText.body(palette.primaryText),
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
