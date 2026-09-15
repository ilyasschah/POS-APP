import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/breakpoints.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/glass.dart';
import '../../core/ilyass_dropdown.dart';
import '../../core/ilyass_form.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/document_lookups.dart';
import '../../models/product.dart';
import '../../models/unit_of_measure.dart';
import 'document_draft.dart';

/// Opens the line editor — a dialog on a wide screen, a bottom sheet on a
/// phone, the dashboard's rule for every form. Resolves to the new or edited
/// line, or null when cancelled.
Future<DraftLine?> showDocumentLineSheet(
  BuildContext context, {
  required DocumentLookups lookups,
  required DocumentTypeOption type,
  required int? warehouseId,
  DraftLine? line,
}) {
  final form = DocumentLineForm(
    lookups: lookups,
    type: type,
    warehouseId: warehouseId,
    line: line,
  );

  if (LayoutTier.watch(context).prefersDialog) {
    return showDialog<DraftLine>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: GlassCard.overlay(
            padding: const EdgeInsets.all(24),
            child: form,
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<DraftLine>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 48,
        bottom: 12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: GlassCard.overlay(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: form,
        ),
      ),
    ),
  );
}

/// The fields of one document line, with its money worked out as they are
/// typed — so the operator sees the line total before committing it.
class DocumentLineForm extends StatefulWidget {
  const DocumentLineForm({
    super.key,
    required this.lookups,
    required this.type,
    required this.warehouseId,
    this.line,
  });

  final DocumentLookups lookups;
  final DocumentTypeOption type;
  final int? warehouseId;

  /// The line being edited; null when adding one.
  final DraftLine? line;

  @override
  State<DocumentLineForm> createState() => _DocumentLineFormState();
}

class _DocumentLineFormState extends State<DocumentLineForm> {
  /// The "No tax" choice — the dropdown needs a real value for it.
  static const int _noTax = 0;

  int? _productId;
  int _taxId = _noTax;
  int _discountType = DiscountKind.percent;
  double? _expected;
  String? _error;

  late final TextEditingController _quantity;
  late final TextEditingController _price;
  late final TextEditingController _discount;

  /// The price this form filled in. While the field still shows it, a change
  /// of product or tax fills it in again; a price the operator typed is kept.
  String? _autoPrice;

  @override
  void initState() {
    super.initState();
    final line = widget.line;
    _productId = line?.productId;
    _taxId = line?.tax?.id ?? _noTax;
    _discountType = line?.discountType ?? DiscountKind.percent;
    _expected = line?.expectedQuantity;
    _quantity = TextEditingController(
      text: line == null ? '' : _plain(line.quantity),
    );
    _price = TextEditingController(
      text: line == null ? '' : _plain(line.priceBeforeTax),
    );
    _discount = TextEditingController(
      text: line == null || line.discount == 0 ? '' : _plain(line.discount),
    );
    for (final controller in [_quantity, _price, _discount]) {
      // Rebuild on every keystroke: the preview below the fields is live.
      controller.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() => _error = null);
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _discount.dispose();
    super.dispose();
  }

  TaxOption? get _tax => _taxId == _noTax ? null : widget.lookups.taxById(_taxId);
  Product? get _product => widget.lookups.productById(_productId);

  static double? _parse(String text) {
    // A comma is a decimal separator on French and Moroccan keyboards.
    final raw = text.trim().replaceAll(',', '.');
    return raw.isEmpty ? null : double.tryParse(raw);
  }

  static String _plain(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  void _selectProduct(int? id) {
    setState(() {
      _productId = id;
      _error = null;
      final product = _product;
      if (product == null) return;
      if (_price.text.trim().isEmpty || _price.text == _autoPrice) {
        _fillPrice(product);
      }
      final warehouseId = widget.warehouseId;
      if (widget.type.isInventoryCount && warehouseId != null) {
        _expected = stockInProductUnit(
          widget.lookups.stockOf(product.id, warehouseId),
          product,
        );
      }
    });
  }

  void _selectTax(int? id) {
    setState(() {
      _taxId = id ?? _noTax;
      final product = _product;
      if (product != null && _price.text == _autoPrice) _fillPrice(product);
    });
  }

  /// Cost for anything bought, counted or written off; the selling price for
  /// a sale — taken back to BEFORE tax when the product's price includes it,
  /// because that is what this field holds.
  void _fillPrice(Product product) {
    var price = widget.type.pricesAtCost ? product.cost : product.price;
    final tax = _tax;
    if (!widget.type.pricesAtCost && product.isTaxInclusivePrice && tax != null) {
      price = tax.isFixed
          ? math.max(0, price - tax.rate)
          : price / (1 + tax.rate / 100);
    }
    final text = _plain(double.parse(price.toStringAsFixed(4)));
    _autoPrice = text;
    _price.text = text;
  }

  void _submit() {
    final product = _product;
    final quantity = _parse(_quantity.text);
    final price = _parse(_price.text);
    final discount = _parse(_discount.text) ?? 0;
    final counting = widget.type.isInventoryCount;

    String? error;
    if (product == null) {
      error = 'Choose a product.';
    } else if (quantity == null || quantity < 0 || (!counting && quantity == 0)) {
      error = counting
          ? 'Enter the quantity you counted.'
          : 'Enter a quantity above zero.';
    } else if (price == null || price < 0) {
      error = 'Enter a price of zero or more.';
    } else if (discount < 0) {
      error = 'Enter a discount of zero or more.';
    } else if (_discountType == DiscountKind.percent && discount > 100) {
      error = 'Enter a percentage discount of 100 or less.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final base = widget.line;
    final fields = (
      productId: product!.id,
      productName: product.displayName,
      uomId: product.effectiveUomId,
      quantity: quantity!,
      expected: counting ? _expected : null,
      price: price!,
    );
    final result = base == null
        ? DraftLine(
            productId: fields.productId,
            productName: fields.productName,
            uomId: fields.uomId,
            quantity: fields.quantity,
            expectedQuantity: fields.expected,
            priceBeforeTax: fields.price,
            discount: discount,
            discountType: _discountType,
            tax: _tax,
            productCost: product.cost,
          )
        : base.copyWith(
            productId: fields.productId,
            productName: fields.productName,
            uomId: fields.uomId,
            quantity: fields.quantity,
            expectedQuantity: fields.expected,
            priceBeforeTax: fields.price,
            discount: discount,
            discountType: _discountType,
            tax: _tax,
            productCost: product.cost,
          );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final type = widget.type;
    final counting = type.isInventoryCount;
    final product = _product;
    final unit = product?.saleUnit;
    final quantity = _parse(_quantity.text);
    final price = _parse(_price.text);
    final discount = _parse(_discount.text) ?? 0;
    final money = quantity == null || price == null
        ? null
        : lineMoney(
            priceBeforeTax: price,
            quantity: quantity,
            discount: discount,
            discountType: _discountType,
            tax: _tax,
          );
    final warehouse = widget.lookups.warehouseById(widget.warehouseId);
    final products = [...widget.lookups.products]
      ..sort(
        (a, b) => a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        ),
      );
    final expected = _expected;
    final difference = counting && expected != null && quantity != null
        ? double.parse((quantity - expected).toStringAsFixed(4))
        : null;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.line == null ? 'Add a line' : 'Edit line',
            style: AppText.headline(palette.primaryText),
          ),
          const SizedBox(height: 4),
          Text(
            counting && warehouse != null
                ? 'Counting stock in ${warehouse.name}.'
                : type.label,
            style: AppText.caption(palette.dim(0.65)).copyWith(fontSize: 13),
          ),
          const SizedBox(height: 20),
          IlyassDropdown<int>(
            label: 'Product',
            searchable: true,
            value: _productId,
            hasError: _error != null && product == null,
            items: [
              for (final p in products)
                IlyassDropdownItem(
                  value: p.id,
                  label: p.displayName,
                  caption: [
                    if (p.code != null) p.code!,
                    p.saleUnit.code,
                  ].join('  '),
                ),
            ],
            onChanged: _selectProduct,
          ),
          const SizedBox(height: kIlyassFieldGap),
          IlyassFieldRow(
            minFieldWidth: 180,
            children: [
              _NumberField(
                controller: _quantity,
                label: counting ? 'Counted quantity' : 'Quantity',
                suffix: unit?.code,
              ),
              _NumberField(
                controller: _price,
                label: 'Unit price before tax',
                suffix: AppConfig.currencySuffix,
                helper: _price.text.isNotEmpty && _price.text == _autoPrice
                    ? (type.pricesAtCost
                          ? 'From the cost price.'
                          : 'From the selling price.')
                    : null,
              ),
            ],
          ),
          const SizedBox(height: kIlyassFieldGap),
          IlyassDropdown<int>(
            label: 'Tax',
            value: _taxId,
            items: [
              const IlyassDropdownItem(value: _noTax, label: 'No tax'),
              for (final tax in widget.lookups.taxes)
                IlyassDropdownItem(value: tax.id, label: tax.label),
            ],
            onChanged: _selectTax,
          ),
          const SizedBox(height: kIlyassFieldGap),
          IlyassFieldRow(
            minFieldWidth: 150,
            flexes: const [3, 2],
            children: [
              _NumberField(
                controller: _discount,
                label: 'Discount',
                hint: '0',
              ),
              IlyassSegmented<int>(
                segments: [
                  (DiscountKind.percent, '%'),
                  (DiscountKind.amount, AppConfig.currencySuffix),
                ],
                value: _discountType,
                onChanged: (v) => setState(() => _discountType = v),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (counting && expected != null && unit != null) ...[
            IlyassValueRow(
              label: 'In stock when counted',
              value: formatUomQuantity(expected, unit),
            ),
            if (difference != null)
              IlyassValueRow(
                label: 'Difference that moves',
                value: difference == 0
                    ? 'None'
                    : '${difference > 0 ? '+' : '−'}'
                          '${formatUomQuantity(difference.abs(), unit)}',
                valueColor: difference > 0
                    ? palette.positive
                    : difference < 0
                    ? palette.negative
                    : null,
              ),
          ],
          if (money != null) ...[
            IlyassValueRow(
              label: 'Unit price with tax',
              value: Fmt.currency(money.unitPrice),
            ),
            if (money.unitDiscount > 0)
              IlyassValueRow(
                label: 'Discount per unit',
                value: '−${Fmt.currency(money.unitDiscount)}',
              ),
            IlyassValueRow(
              label: 'Line total',
              value: Fmt.currency(money.total),
              emphasis: true,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
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
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    foregroundColor: palette.dim(0.85),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                  child: Text(widget.line == null ? 'Add line' : 'Save line'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.suffix,
    this.helper,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;
  final String? helper;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      style: AppText.body(palette.primaryText),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        helperText: helper,
        labelStyle: AppText.label(palette.dim(0.7)),
        helperStyle: AppText.caption(palette.dim(0.6)),
        suffixStyle: AppText.body(palette.dim(0.6)),
      ),
    );
  }
}
