import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../core/breakpoints.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/product.dart';
import 'products_controller.dart';

const _productColorPalette = <Color>[
  Colors.blueGrey,
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
  Colors.amber,
  Colors.orange,
  Colors.deepOrange,
  Colors.brown,
  Colors.black,
];

String _colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

Color _hexToColor(String value) {
  final hex = value.trim();
  if (hex.startsWith('#') && hex.length == 7) {
    final rgb = int.tryParse(hex.substring(1), radix: 16);
    if (rgb != null) return Color(0xFF000000 | rgb);
  }
  return Colors.transparent;
}

Future<void> showProductForm(BuildContext context, {Product? product}) {
  final child = ProductForm(product: product);
  if (LayoutTier.watch(context).prefersDialog) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Layout.maxDialogWidth),
          child: GlassCard.overlay(
            padding: const EdgeInsets.all(24),
            child: child,
          ),
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
        child: GlassCard.overlay(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    ),
  );
}

class ProductForm extends ConsumerStatefulWidget {
  const ProductForm({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<ProductForm> {
  late final _name = TextEditingController(text: widget.product?.name);
  late final _price = TextEditingController(text: _number(widget.product?.price));
  late final _cost = TextEditingController(text: _number(widget.product?.cost));
  String _selectedColor = 'Transparent';
  int? _groupId;
  bool _busy = false;
  String? _error;

  static String _number(double? value) =>
      value == null ? '' : (value == value.roundToDouble()
          ? value.toStringAsFixed(2)
          : value.toString());

  @override
  void initState() {
    super.initState();
    _groupId = widget.product?.productGroupId;
    _selectedColor = widget.product?.color ?? 'Transparent';
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _cost.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = _parse(_price);
    final cost = _parse(_cost);
    if (name.isEmpty || price == null || cost == null || price < 0 || cost < 0) {
      setState(() => _error = 'Enter a name and valid non-negative prices.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(productsProvider.notifier);
      if (widget.product == null) {
        await controller.createProduct(
          name: name,
          price: price,
          cost: cost,
          productGroupId: _groupId,
          color: _selectedColor,
        );
      } else {
        await controller.updateProduct(
          product: widget.product!,
          name: name,
          price: price,
          cost: cost,
          productGroupId: _groupId,
          color: _selectedColor,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (e.isCancelled) return;
      if (mounted) setState(() { _busy = false; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = 'Could not save: $e'; });
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('This will permanently delete "${widget.product!.displayName}".'),
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
      await ref.read(productsProvider.notifier).deleteProduct(widget.product!);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (e.isCancelled) return;
      if (mounted) setState(() { _busy = false; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = 'Could not delete: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final groups = ref.watch(productGroupsProvider);
    final title = widget.product == null ? 'New product' : 'Edit product';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppText.headline(palette.primaryText)),
          const SizedBox(height: 18),
          _Field(label: 'Name', controller: _name, enabled: !_busy),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Field(label: 'Sale price', controller: _price, enabled: !_busy, numeric: true)),
              const SizedBox(width: 12),
              Expanded(child: _Field(label: 'Cost', controller: _cost, enabled: !_busy, numeric: true)),
            ],
          ),
          const SizedBox(height: 14),
          Text('Group', style: AppText.caption(palette.dim(0.8)).weighted(600)),
          const SizedBox(height: 8),
          groups.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Could not load groups: $error', style: AppText.caption(palette.negative)),
            data: (items) => DropdownMenuFormField<int?>(
              key: ValueKey<(Object?, int)>((_groupId, items.length)),
              initialSelection: _groupId,
              hintText: 'No group',
              dropdownMenuEntries: [
                const DropdownMenuEntry<int?>(
                  value: null,
                  label: 'No group',
                ),
                for (final group in items)
                  DropdownMenuEntry<int?>(
                    value: group.id,
                    label: group.name,
                    leadingIcon: Icon(
                      Icons.circle,
                      size: 16,
                      color: _hexToColor(group.color),
                    ),
                  ),
              ],
              onSelected: _busy
                  ? null
                  : (value) => setState(() => _groupId = value),
              enabled: !_busy,
              selectOnly: true,
              enableSearch: false,
              enableFilter: false,
              requestFocusOnTap: false,
              expandedInsets: EdgeInsets.zero,
              trailingIcon: const Icon(Icons.keyboard_arrow_down_rounded),
              selectedTrailingIcon: Icon(
                Icons.keyboard_arrow_up_rounded,
                color: palette.accent,
              ),
              menuStyle: MenuStyle(
                backgroundColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.surface,
                ),
                elevation: const WidgetStatePropertyAll(8),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _ColorPicker(
            value: _selectedColor,
            enabled: !_busy,
            onChanged: (value) => setState(() => _selectedColor = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: AppText.caption(palette.negative)),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              if (widget.product != null)
                IconButton(
                  tooltip: 'Delete product',
                  onPressed: _busy ? null : _delete,
                  icon: Icon(Icons.delete_outline_rounded, color: palette.negative),
                ),
              if (widget.product != null) const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppTheme.onAccent(palette.accent),
                          ))
                        : const Text('Save'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product color',
          style: AppText.caption(palette.dim(0.8)).weighted(600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in _productColorPalette)
              _ColorSwatch(
                color: color,
                selected: value.toUpperCase() == _colorToHex(color),
                enabled: enabled,
                onTap: () => onChanged(_colorToHex(color)),
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final checkColor =
        color.computeLuminance() > 0.4 ? const Color(0xFF1A1A1A) : const Color(0xFFFAFAFA);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Select ${_colorToHex(color)}',
      child: InkWell(
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
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: selected
              ? Icon(Icons.check_rounded, size: 22, color: checkColor)
              : null,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.enabled,
    this.numeric = false,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption(palette.dim(0.8)).weighted(600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
          inputFormatters: numeric
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
              : null,
          decoration: InputDecoration(hintText: numeric ? '0.00' : null),
        ),
      ],
    );
  }
}
