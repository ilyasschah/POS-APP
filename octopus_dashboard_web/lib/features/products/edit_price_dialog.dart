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

/// Opens the price editor: modal dialog on wide viewports, bottom sheet on
/// compact ones.
Future<void> showEditPriceSheet(BuildContext context, Product product) {
  final tier = LayoutTier.watch(context);

  if (tier.prefersDialog) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Layout.maxDialogWidth),
          child: GlassCard.overlay(
            padding: const EdgeInsets.all(24),
            child: EditPriceForm(product: product),
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: EditPriceForm(product: product),
        ),
      ),
    ),
  );
}

class EditPriceForm extends ConsumerStatefulWidget {
  const EditPriceForm({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<EditPriceForm> createState() => _EditPriceFormState();
}

class _EditPriceFormState extends ConsumerState<EditPriceForm> {
  late final TextEditingController _priceController = TextEditingController(
    text: _initialText(widget.product.price),
  );
  late final TextEditingController _costController = TextEditingController(
    text: _initialText(widget.product.cost),
  );

  bool _isSaving = false;
  String? _error;

  /// Renders with a dot decimal separator regardless of browser locale, so the
  /// value round-trips through `double.parse` unchanged.
  static String _initialText(double value) =>
      value == value.roundToDouble() && value.abs() < 1e15
      ? value.toStringAsFixed(2)
      : value.toString();

  @override
  void dispose() {
    _priceController.dispose();
    _costController.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) {
    // Accept a comma as the decimal separator — common on Moroccan/French
    // keyboards — but always parse as a dot.
    final raw = controller.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  Future<void> _save() async {
    final price = _parse(_priceController);
    final cost = _parse(_costController);

    if (price == null || cost == null) {
      setState(() => _error = 'Enter a valid number for both prices.');
      return;
    }
    if (price < 0 || cost < 0) {
      setState(() => _error = 'Prices cannot be negative.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref
          .read(productsProvider.notifier)
          .updatePricing(
            product: widget.product,
            price: price,
            cost: cost,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      // A cancelled save is not a failure worth reporting.
      if (e.isCancelled) return;
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = 'Could not save: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final product = widget.product;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Edit Price', style: AppText.headline(palette.primaryText)),
          const SizedBox(height: 16),
          _ReadOnlyRow(label: 'Name', value: product.displayName),
          const SizedBox(height: 8),
          _ReadOnlyRow(label: 'Code', value: product.code ?? '—'),
          const SizedBox(height: 20),
          _PriceField(
            label: 'Sale Price',
            controller: _priceController,
            enabled: !_isSaving,
          ),
          const SizedBox(height: 14),
          _PriceField(
            label: 'Cost Price',
            controller: _costController,
            enabled: !_isSaving,
            onSubmitted: _save,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: AppText.caption(palette.negative).copyWith(fontSize: 13),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: palette.dim(0.8),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppTheme.onAccent(palette.accent),
                            ),
                          )
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

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.label,
    required this.controller,
    required this.enabled,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onSubmitted;

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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: AppText.body(palette.primaryText),
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          decoration: const InputDecoration(hintText: '0.00'),
        ),
      ],
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: AppText.caption(palette.dim(0.6))),
        ),
        Expanded(
          child: Text(value, style: AppText.body(palette.primaryText)),
        ),
      ],
    );
  }
}
