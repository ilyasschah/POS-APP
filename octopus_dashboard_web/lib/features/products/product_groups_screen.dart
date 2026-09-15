import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../core/breakpoints.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/product_group.dart';
import '../../widgets/list_panel.dart';
import '../../widgets/page_header.dart';
import '../../widgets/state_views.dart';
import 'products_controller.dart';

const _groupColors = <Color>[
  Colors.blueGrey, Colors.red, Colors.pink, Colors.purple,
  Colors.deepPurple, Colors.indigo, Colors.blue, Colors.lightBlue,
  Colors.cyan, Colors.teal, Colors.green, Colors.lightGreen,
  Colors.lime, Colors.amber, Colors.orange, Colors.deepOrange,
  Colors.brown, Colors.grey,
];

String _groupColorHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

Color _groupColor(String value) {
  final normalized = value.trim();
  if (normalized.startsWith('#') && normalized.length == 7) {
    final rgb = int.tryParse(normalized.substring(1), radix: 16);
    if (rgb != null) return Color(0xFF000000 | rgb);
  }
  return Colors.grey;
}

class ProductGroupsScreen extends ConsumerStatefulWidget {
  const ProductGroupsScreen({super.key});

  @override
  ConsumerState<ProductGroupsScreen> createState() => _ProductGroupsScreenState();
}

class _ProductGroupsScreenState extends ConsumerState<ProductGroupsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(productGroupsProvider);
    return Padding(
      padding: Layout.pagePadding(LayoutTier.watch(context)),
      child: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Product groups',
              actions: [
                FilledButton.icon(
                  onPressed: () => showProductGroupForm(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New group'),
                ),
              ],
              onRefresh: () => ref.invalidate(productGroupsProvider),
              isRefreshing: groups.isLoading,
            ),
            SearchField(
              controller: _search,
              hintText: 'Search groups',
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: groups.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorView(
                  message: '$error',
                  onRetry: () => ref.invalidate(productGroupsProvider),
                ),
                data: (items) {
                  final shown = items
                      .where((group) => group.name.toLowerCase().contains(_query.toLowerCase()))
                      .toList(growable: false);
                  if (shown.isEmpty) {
                    return EmptyView(
                      icon: Icons.folder_outlined,
                      message: items.isEmpty
                          ? 'No product groups yet.'
                          : 'No groups match "$_query".',
                    );
                  }
                  return ListPanel(
                    itemCount: shown.length,
                    itemBuilder: (_, index) => _GroupRow(
                      group: shown[index],
                      onTap: () => showProductGroupForm(context, group: shown[index]),
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

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.onTap});

  final ProductGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final groupColor = _groupColor(group.color);
    return ListRow(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: groupColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: groupColor.withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.folder_rounded, color: groupColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: AppText.bodyStrong(palette.primaryText).weighted(700)),
                if (group.parentGroupName != null) ...[
                  const SizedBox(height: 2),
                  Text(group.parentGroupName!, style: AppText.caption(palette.dim(0.6))),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: palette.dim(0.3)),
        ],
      ),
    );
  }
}

Future<void> showProductGroupForm(BuildContext context, {ProductGroup? group}) {
  final form = ProductGroupForm(group: group);
  if (LayoutTier.watch(context).prefersDialog) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Layout.maxDialogWidth),
          child: GlassCard.overlay(padding: const EdgeInsets.all(24), child: form),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: 12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: GlassCard.overlay(padding: const EdgeInsets.all(20), child: form),
      ),
    ),
  );
}

class ProductGroupForm extends ConsumerStatefulWidget {
  const ProductGroupForm({super.key, this.group});

  final ProductGroup? group;

  @override
  ConsumerState<ProductGroupForm> createState() => _ProductGroupFormState();
}

class _ProductGroupFormState extends ConsumerState<ProductGroupForm> {
  late final _name = TextEditingController(text: widget.group?.name);
  late final _rank = TextEditingController(text: '${widget.group?.rank ?? 0}');
  late String _color = widget.group?.color ?? _groupColorHex(_groupColors.first);
  late int? _parentId = widget.group?.parentGroupId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _rank.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final rank = int.tryParse(_rank.text.trim()) ?? 0;
    if (name.isEmpty || rank < 0) {
      setState(() => _error = 'Enter a group name and a valid rank.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final controller = ref.read(productsProvider.notifier);
      if (widget.group == null) {
        await controller.createProductGroup(
          name: name, parentGroupId: _parentId, color: _color, rank: rank,
        );
      } else {
        await controller.updateProductGroup(
          group: widget.group!, name: name, parentGroupId: _parentId, color: _color, rank: rank,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!error.isCancelled && mounted) setState(() { _busy = false; _error = error.message; });
    } catch (error) {
      if (mounted) setState(() { _busy = false; _error = 'Could not save: $error'; });
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text('This will permanently delete "${widget.group!.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: context.palette.negative),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(productsProvider.notifier).deleteProductGroup(widget.group!);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!error.isCancelled && mounted) setState(() { _busy = false; _error = error.message; });
    } catch (error) {
      if (mounted) setState(() { _busy = false; _error = 'Could not delete: $error'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final groups = ref.watch(productGroupsProvider).value ?? const <ProductGroup>[];
    final parents = groups.where((item) => item.id != widget.group?.id).toList(growable: false);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.group == null ? 'New group' : 'Edit group', style: AppText.headline(palette.primaryText)),
          const SizedBox(height: 18),
          _GroupField(label: 'Name', controller: _name, enabled: !_busy),
          const SizedBox(height: 14),
          DropdownMenuFormField<int?>(
            initialSelection: _parentId,
            hintText: 'No parent group',
            dropdownMenuEntries: [
              const DropdownMenuEntry<int?>(value: null, label: 'No parent group'),
              for (final item in parents)
                DropdownMenuEntry<int?>(
                  value: item.id,
                  label: item.name,
                  leadingIcon: Icon(Icons.circle, size: 16, color: _groupColor(item.color)),
                ),
            ],
            onSelected: _busy ? null : (value) => setState(() => _parentId = value),
            enabled: !_busy,
            selectOnly: true,
            enableSearch: false,
            enableFilter: false,
            requestFocusOnTap: false,
            expandedInsets: EdgeInsets.zero,
            trailingIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          const SizedBox(height: 18),
          Text('Group color', style: AppText.caption(palette.dim(0.8)).weighted(600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in _groupColors)
                _GroupSwatch(
                  color: color,
                  selected: _color.toUpperCase() == _groupColorHex(color),
                  enabled: !_busy,
                  onTap: () => setState(() => _color = _groupColorHex(color)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _GroupField(label: 'Rank', controller: _rank, enabled: !_busy, numeric: true),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: AppText.caption(palette.negative)),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              if (widget.group != null) IconButton(
                tooltip: 'Delete group',
                onPressed: _busy ? null : _delete,
                icon: Icon(Icons.delete_outline_rounded, color: palette.negative),
              ),
              if (widget.group != null) const SizedBox(width: 8),
              Expanded(child: TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 12),
              Expanded(child: SizedBox(
                height: 50,
                child: FilledButton(onPressed: _busy ? null : _save, child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save')),
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupField extends StatelessWidget {
  const _GroupField({required this.label, required this.controller, required this.enabled, this.numeric = false});
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final bool numeric;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.caption(context.palette.dim(0.8)).weighted(600)),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: numeric ? TextInputType.number : null,
        decoration: InputDecoration(hintText: numeric ? '0' : null),
      ),
    ],
  );
}

class _GroupSwatch extends StatelessWidget {
  const _GroupSwatch({required this.color, required this.selected, required this.enabled, required this.onTap});
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: palette.accent, width: 3)
              : Border.all(color: palette.primaryText.withValues(alpha: 0.16)),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
        child: selected
            ? Icon(Icons.check_rounded, size: 22, color: color.computeLuminance() > 0.4 ? const Color(0xFF1A1A1A) : const Color(0xFFFAFAFA))
            : null,
      ),
    );
  }
}
