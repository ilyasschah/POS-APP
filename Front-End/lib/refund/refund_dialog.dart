import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/cart/payment_type_model.dart';
import 'package:pos_app/cart/payment_type_provider.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/refund/refund_service.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart' show ProductsTableData;
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/document/documents_screen.dart' show allDocumentsProvider;

class RefundDialog extends ConsumerStatefulWidget {
  final String? initialDocumentNumber;
  const RefundDialog({super.key, this.initialDocumentNumber});

  @override
  ConsumerState<RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends ConsumerState<RefundDialog> {
  final _receiptCtrl = TextEditingController();
  final _focusNode   = FocusNode();

  FetchedDocument? _document;
  bool _loading    = false;
  bool _submitting = false;
  String? _error;
  int? _selectedPaymentTypeId;
  // productId → quantity the cashier wants to refund
  Map<int, double> _refundQty = {};
  final _fmt = NumberFormat('#,##0.00');

  // ── Blind-return state ──────────────────────────────────────────────────
  // A blind return refunds goods this terminal never sold (no local receipt,
  // both POS offline). It requires a manager PIN and the cashier picks the
  // items manually; prices come from the product's current selling price.
  bool _blindMode = false;
  int? _approverUserId;
  final List<_BlindLine> _blindLines = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialDocumentNumber != null) {
      _receiptCtrl.text = widget.initialDocumentNumber!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookupReceipt());
    }
    _seedFromSelectedCartItem();
  }

  /// Pre-loads the line the operator had selected in the cart so a blind return
  /// opens with it already listed instead of making them find it in the picker.
  ///
  /// This only fills the LIST — it deliberately does not set [_blindMode], which
  /// still requires the manager PIN in [_authoriseBlind]. Seeding here is a
  /// convenience, never a way around that authorisation.
  void _seedFromSelectedCartItem() {
    final cart = ref.read(cartProvider);
    final selectedId = cart.selectedCartItemId;
    if (selectedId == null) return;
    final item =
        cart.items.where((i) => i.cartItemId == selectedId).firstOrNull;
    if (item == null) return;
    _blindLines.add(_BlindLine(
      productId: item.productId,
      name: item.productName,
      // The cart's per-unit price already nets item discounts out; the blind
      // line is priced the same way the picker would price it.
      price: item.price,
      qty: item.quantity,
    ));
  }

  @override
  void dispose() {
    _receiptCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _lookupReceipt() async {
    final number = _receiptCtrl.text.trim();
    if (number.isEmpty) return;

    setState(() { _loading = true; _error = null; _document = null; _refundQty = {}; });

    try {
      final service = ref.read(refundServiceProvider);
      final doc     = await service.fetchDocument(number);

      if (doc != null) {
        // Offline-first double-refund lock: block if a refund document already
        // references this receipt locally (synced or still pending sync).
        final db        = ref.read(appDatabaseProvider);
        final companyId = ref.read(selectedCompanyProvider)?.id ?? 0;
        // Match on the document's canonical number — that's what gets stored as
        // referenceDocumentNumber on the refund, regardless of what was typed.
        final existingRefund = await db.findRefundByReference(
          companyId:      companyId,
          originalNumber: doc.number,
        );
        if (existingRefund != null) {
          final ref0 = existingRefund.number ?? '(pending sync)';
          setState(() {
            _document  = null;
            _refundQty = {};
            _error     =
                'This receipt has already been refunded (Ref: $ref0).';
          });
          return;
        }
      }

      setState(() {
        _document = doc;
        _error    = doc == null ? 'Receipt "$number" not found.' : null;
        if (doc != null) {
          // default: refund full quantity of every item
          _refundQty = {for (final i in doc.items) i.productId: i.quantity};
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  double get _totalRefund {
    if (_blindMode) {
      return _blindLines.fold(0.0, (sum, l) => sum + l.qty * l.price);
    }
    if (_document == null) return 0.0;
    return _document!.items.fold(0.0, (sum, item) {
      final qty = _refundQty[item.productId] ?? 0.0;
      return sum + qty * item.price;
    });
  }

  /// Manager-authorised entry into blind-return mode. Asks for a manager PIN,
  /// verifies it offline against the cached admin PIN hashes, and on success
  /// switches the dialog into blind mode (manual item picking).
  Future<void> _startBlindReturn() async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _ManagerPinDialog(),
    );
    if (pin == null || !mounted) return;

    final approver = await ref.read(refundServiceProvider).verifyManagerPin(pin);
    if (!mounted) return;
    if (approver == null) {
      _showSnack('Manager PIN not recognised. Blind return needs an admin.');
      return;
    }
    setState(() {
      _blindMode      = true;
      _approverUserId = approver;
      _document       = null;
      _refundQty      = {};
      _error          = null;
      _blindLines.clear();
    });
  }

  void _exitBlindReturn() {
    setState(() {
      _blindMode      = false;
      _approverUserId = null;
      _blindLines.clear();
      _error          = null;
    });
  }

  /// Opens the product picker and adds (or increments) a blind-return line at
  /// the product's current selling price.
  Future<void> _addBlindProduct() async {
    final picked = await showDialog<_PickedProduct>(
      context: context,
      builder: (_) => const _ProductPickerDialog(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final idx = _blindLines.indexWhere((l) => l.productId == picked.id);
      if (idx >= 0) {
        _blindLines[idx].qty += 1;
      } else {
        _blindLines.add(_BlindLine(
          productId: picked.id,
          name:      picked.name,
          price:     picked.price,
          qty:       1,
        ));
      }
    });
  }

  Future<void> _submitBlind() async {
    final lines = _blindLines.where((l) => l.qty > 0).toList();
    if (lines.isEmpty) { _showSnack('Add at least one item to return.'); return; }
    if (_selectedPaymentTypeId == null) {
      _showSnack('Select a refund payment type.');
      return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      final service = ref.read(refundServiceProvider);
      final warehouseId = ref.read(selectedWarehouseProvider)?.id ??
          ref.read(allWarehousesProvider).value?.firstOrNull?.id ??
          0;

      final result = await service.submitRefund(
        RefundPayload(
          // The customer's claimed paper-receipt number (optional). Stored as
          // the reference; the server marks it BLIND when blank.
          originalDocumentNumber: _receiptCtrl.text.trim(),
          refundPaymentTypeId:    _selectedPaymentTypeId!,
          warehouseId:            warehouseId,
          isBlind:                true,
          approvedByUserId:       _approverUserId,
          items: lines
              .map((l) => {
                    'productId': l.productId,
                    'quantity':  l.qty,
                    'price':     l.price,
                  })
              .toList(),
        ),
      );

      if (!mounted) return;
      ref.invalidate(allDocumentsProvider);
      if (result.queued) {
        _showSnack('Blind refund queued — will sync automatically.', success: true);
      } else {
        _showSnack('Blind refund ${result.refundNumber} processed.', success: true);
      }
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _submit() async {
    if (_blindMode) { await _submitBlind(); return; }
    if (_document == null)             { _showSnack('Look up a receipt first.'); return; }
    if (_selectedPaymentTypeId == null) { _showSnack('Select a refund payment type.'); return; }

    final selectedItems = _document!.items
        .where((i) => (_refundQty[i.productId] ?? 0) > 0)
        .toList();
    if (selectedItems.isEmpty) {
      _showSnack('Select at least one item to refund.');
      return;
    }

    setState(() { _submitting = true; _error = null; });

    try {
      final service = ref.read(refundServiceProvider);

      // Restore stock to the document's original source warehouse, falling back
      // to the active warehouse only if the receipt didn't record one.
      final warehouseId = _document!.warehouseId > 0
          ? _document!.warehouseId
          : (ref.read(allWarehousesProvider).value?.firstOrNull?.id ?? 0);

      final result = await service.submitRefund(
        RefundPayload(
          originalDocumentNumber: _document!.number,
          refundPaymentTypeId:    _selectedPaymentTypeId!,
          warehouseId:            warehouseId,
          items: selectedItems
              .map((i) => {
                    'productId': i.productId,
                    'quantity':  _refundQty[i.productId] ?? i.quantity,
                  })
              .toList(),
        ),
        source: _document!,
      );

      if (!mounted) return;

      // The refund is now a local Document — refresh the Documents screen so it
      // appears instantly without waiting for a server round-trip.
      ref.invalidate(allDocumentsProvider);

      if (result.queued) {
        _showSnack('Refund queued — will sync automatically.', success: true);
      } else {
        _showSnack('Refund ${result.refundNumber} processed.', success: true);
      }
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    showAppSnackbar(context, ref, msg, isError: !success);
  }

  /// Left panel content: the manually-picked blind-return lines, or the looked-up
  /// receipt's items, or an empty-state hint.
  Widget _buildLeftList(ColorScheme cs) {
    if (_blindMode) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addBlindProduct,
                icon: const Icon(Icons.add, size: 16),
                label: Text(AppLocalizations.of(context).addProductLower),
              ),
            ),
          ),
          Expanded(
            child: _blindLines.isEmpty
                ? Center(
                    child: Text(AppLocalizations.of(context).addReturnedProducts,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 13)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: cs.outlineVariant),
                    itemCount: _blindLines.length,
                    itemBuilder: (_, i) {
                      final line = _blindLines[i];
                      final lineTotal = line.qty * line.price;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(line.name,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface)),
                                  Text(_fmt.format(line.price),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            _QtyStepper(
                              value: line.qty,
                              max:   9999,
                              onChanged: (v) => setState(() {
                                if (v <= 0) {
                                  _blindLines.removeAt(i);
                                } else {
                                  line.qty = v;
                                }
                              }),
                            ),
                            const Gap(6),
                            SizedBox(
                              width: 64,
                              child: Text(
                                _fmt.format(lineTotal),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: cs.error),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  setState(() => _blindLines.removeAt(i)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    if (_document == null) {
      return Center(
        child: Text(AppLocalizations.of(context).searchReceiptToSeeItems,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(10),
      separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant),
      itemCount: _document!.items.length,
      itemBuilder: (_, i) {
        final item = _document!.items[i];
        final qty  = _refundQty[item.productId] ?? 0.0;
        final lineTotal = qty * item.price;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface)),
                    Text(
                      '${_fmt.format(item.price)} × max ${_fmt.format(item.quantity)}',
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _QtyStepper(
                value: qty,
                max:   item.quantity,
                onChanged: (v) =>
                    setState(() => _refundQty[item.productId] = v),
              ),
              const Gap(6),
              SizedBox(
                width: 68,
                child: Text(
                  _fmt.format(lineTotal),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: qty > 0 ? cs.error : cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs           = Theme.of(context).colorScheme;
    final paymentTypes = ref.watch(allPaymentTypesProvider).value ?? [];

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width:  860,
        height: 560,
        child: Column(
          children: [
            // ── Title bar ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: cs.surfaceContainerHighest,
              child: Row(
                children: [
                  Icon(Icons.undo, color: cs.primary),
                  const Gap(10),
                  Text(AppLocalizations.of(context).refundItems,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Left: item list with qty steppers ──────────────────
                  SizedBox(
                    width: 360,
                    child: Column(
                      children: [
                        Expanded(child: _buildLeftList(cs)),
                        // Total refund amount
                        Container(
                          color: cs.surfaceContainerHighest,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(AppLocalizations.of(context).totalRefundAmount,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurfaceVariant,
                                      letterSpacing: 0.8)),
                              const Gap(2),
                              Text(
                                (!_blindMode && _document == null)
                                    ? '0.00'
                                    : '-${_fmt.format(_totalRefund)}',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: cs.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  VerticalDivider(width: 1, color: cs.outlineVariant),

                  // ── Right: receipt search (fixed top) + payment types ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Receipt search — always visible at top
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            border: Border(
                                bottom: BorderSide(color: cs.outlineVariant)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  _blindMode
                                      ? "Customer's receipt # (optional)"
                                      : 'Receipt number',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600)),
                              const Gap(6),
                              KeyboardListener(
                                focusNode: FocusNode(),
                                onKeyEvent: (e) {
                                  if (e is KeyDownEvent &&
                                      e.logicalKey ==
                                          LogicalKeyboardKey.enter) {
                                    _lookupReceipt();
                                  }
                                },
                                child: TextField(
                                  controller: _receiptCtrl,
                                  focusNode:  _focusNode,
                                  autofocus:  true,
                                  textAlign:  TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface),
                                  decoration: InputDecoration(
                                    hintText: _blindMode
                                        ? 'optional — from paper receipt'
                                        : 'e.g. 26-200-000001',
                                    isDense: true,
                                    filled: true,
                                    fillColor: cs.surface,
                                    border: const OutlineInputBorder(),
                                    suffixIcon: _loading
                                        ? const Padding(
                                            padding: EdgeInsets.all(10),
                                            child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                    strokeWidth: 2)),
                                          )
                                        : IconButton(
                                            icon: const Icon(Icons.search),
                                            onPressed: _lookupReceipt,
                                          ),
                                  ),
                                  onSubmitted: (_) => _lookupReceipt(),
                                ),
                              ),
                              if (_error != null) ...[
                                const Gap(6),
                                Text(
                                  _error!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: cs.error, fontSize: 11),
                                ),
                              ],
                              // Blind-return entry / status.
                              if (!_blindMode) ...[
                                const Gap(8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: _submitting ? null : _startBlindReturn,
                                    icon: const Icon(Icons.shield_outlined, size: 16),
                                    label: Text(AppLocalizations.of(context).blindReturn,
                                        style: const TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        visualDensity: VisualDensity.compact),
                                  ),
                                ),
                              ] else ...[
                                const Gap(8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: cs.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.verified_user,
                                          size: 16, color: cs.onTertiaryContainer),
                                      const Gap(8),
                                      Expanded(
                                        child: Text(
                                          'Blind return — manager authorised. No original receipt.',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: cs.onTertiaryContainer),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: _submitting ? null : _exitBlindReturn,
                                        child: Icon(Icons.close,
                                            size: 16, color: cs.onTertiaryContainer),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Payment type selector — scrollable
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppLocalizations.of(context).refundPaymentType,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w600)),
                                const Gap(10),
                                paymentTypes.isEmpty
                                    ? Text(AppLocalizations.of(context).loadingPaymentTypes,
                                        style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 12))
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: paymentTypes
                                            .where((pt) => pt.isEnabled)
                                            .map((pt) => _PaymentTypeButton(
                                                  paymentType: pt,
                                                  selected:
                                                      _selectedPaymentTypeId ==
                                                          pt.id,
                                                  onTap: () => setState(() =>
                                                      _selectedPaymentTypeId =
                                                          pt.id),
                                                ))
                                            .toList(),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom buttons ─────────────────────────────────────────────
            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(AppLocalizations.of(context).actionCancel),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Gap(10),
                  FilledButton.icon(
                    icon: _submitting
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: context.onStatusColor))
                        : const Icon(Icons.check, size: 16),
                    label: Text(AppLocalizations.of(context).actionOk),
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                        backgroundColor: context.successColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Qty stepper ───────────────────────────────────────────────────────────────

class _QtyStepper extends StatelessWidget {
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  const _QtyStepper(
      {required this.value, required this.max, required this.onChanged});

  String _label(double v) =>
      v.truncateToDouble() == v ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon:    Icons.remove,
          enabled: value > 0,
          onTap:   () => onChanged(value - 1),
          cs:      cs,
        ),
        Container(
          width: 34,
          alignment: Alignment.center,
          child: Text(_label(value),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
        ),
        _StepBtn(
          icon:    Icons.add,
          enabled: value < max,
          onTap:   () => onChanged(value + 1),
          cs:      cs,
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _StepBtn(
      {required this.icon,
      required this.enabled,
      required this.onTap,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 16,
            color: enabled ? cs.onPrimaryContainer : cs.onSurfaceVariant),
      ),
    );
  }
}

// ── Payment type button ───────────────────────────────────────────────────────

class _PaymentTypeButton extends StatelessWidget {
  final PaymentType paymentType;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentTypeButton({
    required this.paymentType,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 90,
        height: 60,
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHigh,
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                paymentType.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? cs.onPrimary : cs.onSurface,
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 4,
                right: 4,
                child:
                    Icon(Icons.check_circle, size: 14, color: cs.onPrimary),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Blind-return models & dialogs ───────────────────────────────────────────────

/// One line of a blind return: a manually-picked product at its current price.
class _BlindLine {
  final int productId;
  final String name;
  final double price;
  double qty;
  _BlindLine({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
  });
}

/// Lightweight result of the product picker.
class _PickedProduct {
  final int id;
  final String name;
  final double price;
  const _PickedProduct({required this.id, required this.name, required this.price});
}

/// Manager-PIN prompt. Returns the entered PIN (verification happens in the
/// caller against the cached admin PIN hashes — fully offline), or null if
/// cancelled.
class _ManagerPinDialog extends StatefulWidget {
  const _ManagerPinDialog();
  @override
  State<_ManagerPinDialog> createState() => _ManagerPinDialogState();
}

class _ManagerPinDialogState extends State<_ManagerPinDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(AppLocalizations.of(context).managerAuthorisation),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A blind return refunds goods with no receipt. A manager must approve it.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const Gap(14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).managerPin,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: Text(AppLocalizations.of(context).authorise),
        ),
      ],
    );
  }
}

/// Product picker for blind returns. Lists the company's enabled products from
/// the local Drift cache (offline-first) with a name/barcode search. Returns a
/// [_PickedProduct] at the product's current selling price, or null.
class _ProductPickerDialog extends ConsumerStatefulWidget {
  const _ProductPickerDialog();
  @override
  ConsumerState<_ProductPickerDialog> createState() =>
      _ProductPickerDialogState();
}

class _ProductPickerDialogState extends ConsumerState<_ProductPickerDialog> {
  final _searchCtrl = TextEditingController();
  final _fmt = NumberFormat('#,##0.00');
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final db = ref.read(appDatabaseProvider);
    final companyId = ref.read(selectedCompanyProvider)?.id ?? 0;

    return Dialog(
      child: SizedBox(
        width: 460,
        height: 560,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).searchProductEllipsis,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Expanded(
              child: FutureBuilder<List<ProductsTableData>>(
                future: (db.select(db.productsTable)
                      ..where((t) => t.companyId.equals(companyId))
                      ..where((t) => t.isEnabled.equals(true)))
                    .get(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var products = snap.data!;
                  if (_query.isNotEmpty) {
                    products = products
                        .where((p) =>
                            p.name.toLowerCase().contains(_query) ||
                            (p.barcode ?? '').toLowerCase().contains(_query))
                        .toList();
                  }
                  products.sort((a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                  if (products.isEmpty) {
                    return Center(
                      child: Text(AppLocalizations.of(context).noProductsFoundShort,
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    );
                  }
                  return ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: cs.outlineVariant),
                    itemBuilder: (_, i) {
                      final p = products[i];
                      return ListTile(
                        dense: true,
                        title: Text(p.name,
                            style: TextStyle(color: cs.onSurface)),
                        trailing: Text(
                          _fmt.format(p.price),
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: cs.primary),
                        ),
                        onTap: () => Navigator.of(context).pop(
                          _PickedProduct(
                              id: p.id, name: p.name, price: p.price),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context).actionCancel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
