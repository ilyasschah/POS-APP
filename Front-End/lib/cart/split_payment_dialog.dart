// The split bill: one table's cart, divided between guests who each pay their
// own share of ONE document.
//
// Left, the items nobody has taken yet; right, one card per guest. Tap an item
// then a card — or drag it there — to hand it over; a line of several can be
// split by quantity. Each card prints its own guest check, takes its own
// payment method, and is paid on its own. Nothing is banked until the pool is
// empty and every card is paid; then the sale is written once, offline, with a
// payment per guest on the one document (see `sale_banking.dart`).
//
// Ilyass Style: cards wrap by arithmetic on the width they actually get, never
// by a device breakpoint; label/value rows share the width with loose Flexibles.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/cart/payment_type_model.dart';
import 'package:pos_app/cart/payment_type_provider.dart';
import 'package:pos_app/cart/sale_banking.dart';
import 'package:pos_app/cart/split_bill.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/ilyass_form.dart';
import 'package:pos_app/core/sound_service.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/customer_display/customer_display_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/printer/cash_drawer_service.dart';
import 'package:pos_app/printer/printer_routing_service.dart';
import 'package:pos_app/printer/receipt_printer_service.dart';
import 'package:pos_app/session/session_gate.dart';
import 'package:pos_app/uom/unit_of_measure.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// Cuts the live cart into a [SplitBill].
///
/// Every figure comes from the cart notifier — the single source of truth for
/// line money — so the shares can never disagree with the total the checkout
/// showed. [pointsDiscount] is a loyalty redemption already chosen in the
/// checkout: it belongs to the whole bill, so it is shared like the other
/// order-level discounts.
SplitBill splitBillForCart(
  CartNotifier cart,
  List<CartItem> items, {
  required double grandTotal,
  double pointsDiscount = 0,
}) {
  final orderLevel = cart.customerDiscountAmount +
      cart.manualCartDiscountAmount +
      pointsDiscount;
  return SplitBill(
    items: items,
    grandTotal: (grandTotal - pointsDiscount).clamp(0.0, double.infinity),
    money: splitUnitMoney(
      items: items,
      netUnitPrice: cart.netUnitPriceFor,
      lineNet: (i) => cart.grossLineTotal(i) - cart.taxForItem(i),
      lineTax: cart.taxForItem,
      orderLevelDiscount: orderLevel,
    ),
  );
}

/// Pops `true` once the sale is banked, so the checkout underneath can close
/// and hand back to the till; `false` when the operator backs out.
class SplitPaymentDialog extends ConsumerStatefulWidget {
  const SplitPaymentDialog({
    super.key,
    required this.bill,
    required this.loyaltyBaseTotal,
    this.pointsUsed = 0,
    this.pointsDiscount = 0,
  });

  final SplitBill bill;

  /// The bill BEFORE any points were redeemed — what loyalty points are
  /// earned on, exactly as in the ordinary checkout.
  final double loyaltyBaseTotal;

  final double pointsUsed;
  final double pointsDiscount;

  @override
  ConsumerState<SplitPaymentDialog> createState() => _SplitPaymentDialogState();
}

class _SplitPaymentDialogState extends ConsumerState<SplitPaymentDialog> {
  SplitBill get _bill => widget.bill;

  /// The pool line picked, waiting for the card it goes to.
  String? _selected;
  bool _banking = false;

  /// Split numbers whose guest check is on its way to the printer.
  final Set<int> _printing = {};

  static const double _gap = 12;
  static const double _minCardWidth = 300;

  /// Pool beside the cards once each keeps a usable width; stacked below.
  static const double _twoPaneWidth = 760;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sym = ref.watch(currencySymbolProvider);
    final types =
        (ref.watch(allPaymentTypesProvider).value ?? const <PaymentType>[])
            .where((t) => t.isEnabled)
            .toList();
    final size = MediaQuery.sizeOf(context);

    return PopScope(
      canPop: false,
      // Escape / the system back gesture ask first — they must never throw
      // away payments already taken.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: size.width - 24,
          height: size.height - 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, sym),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final pool = _poolPanel(context, sym);
                    final cards = _splitsArea(context, types, sym);
                    if (c.maxWidth >= _twoPaneWidth) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: (c.maxWidth * 0.3).clamp(280.0, 380.0),
                            child: pool,
                          ),
                          VerticalDivider(
                            width: 1,
                            color: theme.colorScheme.outlineVariant,
                          ),
                          Expanded(child: cards),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: (c.maxHeight * 0.38).clamp(160.0, 360.0),
                          child: pool,
                        ),
                        Divider(
                          height: 1,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        Expanded(child: cards),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String sym) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final settled = _bill.splits
        .where((s) => s.isPaid)
        .fold<double>(0, (sum, s) => sum + s.tender!.due);
    final remaining = (_bill.grandTotal - settled).clamp(0.0, double.infinity);

    Widget figure(String label, double value, {Color? color}) => Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label  ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              TextSpan(
                text: '$sym ${value.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );

    return Container(
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 20,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_split, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      l.splitBillTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                figure(l.totalLabel, _bill.grandTotal),
                figure(
                  l.remainingLabel,
                  remaining,
                  color: remaining > 0.005
                      ? context.warningColor
                      : context.successColor,
                ),
              ],
            ),
          ),
          if (_banking)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            )
          // Only after a failed save: banking starts by itself the moment the
          // last share is paid, so this is the retry, not a second step.
          else if (_bill.isSettled)
            FilledButton.icon(
              onPressed: _bank,
              icon: const Icon(Icons.save_outlined),
              label: Text(l.splitFinish),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: _banking ? null : _close,
            icon: const Icon(Icons.close),
            label: Text(l.actionCancel),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              minimumSize: const Size(0, 48),
            ),
          ),
        ],
      ),
    );
  }

  // ── Unassigned pool ───────────────────────────────────────────────────────

  Widget _poolPanel(BuildContext context, String sym) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);
    final pool = _bill.pool;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  l.splitUnassigned,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              IlyassCountBadge(pool.length),
            ],
          ),
        ),
        if (pool.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l.splitSelectHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: pool.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 40,
                          color: context.successColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.splitAllAssigned,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: pool.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: cs.outlineVariant),
                  itemBuilder: (context, i) =>
                      _poolRow(context, pool[i], sym),
                ),
        ),
      ],
    );
  }

  Widget _poolRow(BuildContext context, CartItem item, String sym) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final left = _bill.unassigned(item.cartItemId);
    final unit = _bill.money[item.cartItemId]!.total;
    final selected = _selected == item.cartItemId;
    final onColor = selected ? cs.onPrimaryContainer : null;

    final row = Material(
      color: selected ? cs.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: _banking
            ? null
            : () => setState(
                  () => _selected = selected ? null : item.cartItemId,
                ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.productName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: onColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_qtyText(item, left)} × $sym ${unit.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onColor ?? cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 2,
                  child: Text(
                    '$sym ${(unit * left).toStringAsFixed(2)}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: onColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return LongPressDraggable<String>(
      data: item.cartItemId,
      delay: const Duration(milliseconds: 200),
      maxSimultaneousDrags: _banking ? 0 : 1,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        color: cs.primaryContainer,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              '${_qtyText(item, left)} × ${item.productName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: row),
      child: row,
    );
  }

  // ── Split cards ───────────────────────────────────────────────────────────

  Widget _splitsArea(
    BuildContext context,
    List<PaymentType> types,
    String sym,
  ) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth - _gap * 2;
        // As many cards per row as keep their minimum width — measured on the
        // space the cards actually get, never the window.
        final perRow =
            ((width + _gap) / (_minCardWidth + _gap)).floor().clamp(1, 4);
        final cardWidth = (width - _gap * (perRow - 1)) / perRow;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(_gap),
          child: Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (final split in _bill.splits)
                SizedBox(
                  key: ValueKey('split-${split.number}'),
                  width: cardWidth,
                  child: _splitCard(context, split, types, sym),
                ),
              SizedBox(width: cardWidth, child: _addSplitTile(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _splitCard(
    BuildContext context,
    BillSplit split,
    List<PaymentType> types,
    String sym,
  ) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final paid = split.isPaid;
    final totals = _bill.totalsOf(split);
    final due = _bill.dueOf(split);
    final typeId =
        split.paymentTypeId ?? (types.isNotEmpty ? types.first.id : null);
    final type = types.where((t) => t.id == typeId).firstOrNull;
    final awaitingItem = !paid && !_banking && _selected != null;

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => !paid && !_banking,
      onAcceptWithDetails: (d) => _assign(d.data, split),
      builder: (context, candidates, _) {
        final highlight = candidates.isNotEmpty || awaitingItem;
        final border = paid
            ? context.successColor
            : highlight
                ? cs.primary
                : cs.outlineVariant;
        return Material(
          color: paid
              ? context.successColor.withValues(alpha: 0.06)
              : cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: border, width: highlight || paid ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: awaitingItem ? () => _assign(_selected!, split) : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _cardHeader(context, split),
                  const SizedBox(height: 8),
                  if (split.isEmpty)
                    _dropHint(context)
                  else
                    ..._cardLines(context, split, sym),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: cs.outlineVariant),
                  const SizedBox(height: 8),
                  _moneyRow(
                    context,
                    l.subtotalLabel,
                    '$sym ${totals.subtotal.toStringAsFixed(2)}',
                  ),
                  if (totals.discount > 0.005)
                    _moneyRow(
                      context,
                      l.discountLabel,
                      '- $sym ${totals.discount.toStringAsFixed(2)}',
                      color: context.successColor,
                    ),
                  _moneyRow(
                    context,
                    l.taxesLabel,
                    '$sym ${totals.tax.toStringAsFixed(2)}',
                  ),
                  _moneyRow(
                    context,
                    l.totalLabel,
                    '$sym ${due.toStringAsFixed(2)}',
                    bold: true,
                  ),
                  const SizedBox(height: 12),
                  if (paid)
                    ..._paidFooter(context, split, types, sym)
                  else
                    ..._openFooter(context, split, types, type, due, sym),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cardHeader(BuildContext context, BillSplit split) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            l.splitName(split.number),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (split.isPaid)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.lock_outline, size: 20, color: context.successColor),
          )
        else if (_bill.canRemove(split))
          IconButton(
            tooltip: l.splitRemove,
            icon: const Icon(Icons.delete_outline),
            onPressed: _banking
                ? null
                : () => setState(() => _bill.removeSplit(split)),
          ),
      ],
    );
  }

  Widget _dropHint(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pan_tool_alt_outlined, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              AppLocalizations.of(context).splitDropHere,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _cardLines(BuildContext context, BillSplit split, String sym) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return [
      for (final e in split.allocations.entries)
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 3,
                child: Text(
                  '${_qtyText(_bill.itemById(e.key), e.value)} × '
                  '${_bill.itemById(e.key).productName}',
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        '$sym ${(_bill.money[e.key]!.total * e.value).toStringAsFixed(2)}',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!split.isPaid)
                      IconButton(
                        tooltip: l.splitReturnItem,
                        icon: const Icon(Icons.undo),
                        onPressed: _banking
                            ? null
                            : () => setState(() => _bill.unassign(e.key, split)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _moneyRow(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final labelStyle = bold
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyMedium;
    final valueStyle = labelStyle?.copyWith(
      color: color ?? (bold ? theme.colorScheme.primary : null),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 3,
            child: Text(
              label,
              style: labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Scaled, never ellipsised: a clipped amount is a wrong amount.
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(value, style: valueStyle),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _openFooter(
    BuildContext context,
    BillSplit split,
    List<PaymentType> types,
    PaymentType? type,
    double due,
    String sym,
  ) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final printing = _printing.contains(split.number);
    return [
      Text(l.paymentMethod, style: theme.textTheme.labelLarge),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in types)
            ChoiceChip(
              label: Text(t.name),
              selected: type?.id == t.id,
              onSelected: _banking
                  ? null
                  : (_) => setState(() => split.paymentTypeId = t.id),
            ),
        ],
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: context.successColor,
          foregroundColor: context.onStatusColor,
        ),
        onPressed: split.isEmpty || type == null || _banking
            ? null
            : () => _pay(split, type),
        icon: const Icon(Icons.check_circle_outline),
        label: Text(l.splitPayAmount('$sym ${due.toStringAsFixed(2)}')),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: split.isEmpty || printing || _banking
            ? null
            : () => _printGuestCheck(split),
        icon: printing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.receipt_long_outlined),
        label: Text(
          l.splitPrintGuestCheck,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ];
  }

  List<Widget> _paidFooter(
    BuildContext context,
    BillSplit split,
    List<PaymentType> types,
    String sym,
  ) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final tender = split.tender!;
    final type = types.where((t) => t.id == tender.paymentTypeId).firstOrNull;
    final name = type?.name ?? '';
    final collected = type?.markAsPaid ?? true;
    return [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.successColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: context.successColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                collected
                    ? l.splitPaidWith(
                        name, '$sym ${tender.amount.toStringAsFixed(2)}')
                    : l.splitOnAccount(name),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      if (!_banking) ...[
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => setState(() => _bill.undoPayment(split)),
          icon: const Icon(Icons.undo),
          label: Text(l.splitUndoPayment),
        ),
      ],
    ];
  }

  Widget _addSplitTile(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _banking ? null : () => setState(() => _bill.addSplit()),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 120),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, size: 32, color: cs.primary),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).splitAddSplit,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Hands a pool line to [split] — asking how many when the line holds
  /// several whole units. A weighed line is one cut of meat however many
  /// grams it weighs, so it moves whole.
  Future<void> _assign(String cartItemId, BillSplit split) async {
    if (split.isPaid || _banking) return;
    final left = _bill.unassigned(cartItemId);
    if (left <= 0) return;
    final item = _bill.itemById(cartItemId);

    var quantity = left;
    if (!item.isToWeigh && left > 1 && left == left.roundToDouble()) {
      final picked = await showDialog<int>(
        context: context,
        builder: (_) => _QuantityPickerDialog(
          productName: item.productName,
          max: left.toInt(),
        ),
      );
      if (picked == null || !mounted) return;
      quantity = picked.toDouble();
    }

    setState(() {
      _bill.assign(cartItemId, split, quantity);
      // Keep the line picked while some of it is left, so the rest can go
      // straight to the next guest.
      if (!_bill.pool.any((i) => i.cartItemId == cartItemId)) _selected = null;
    });
  }

  /// Settles one guest's share. The money is taken now — the drawer opens as
  /// it is handed over — but nothing is banked until every share is settled.
  Future<void> _pay(BillSplit split, PaymentType type) async {
    if (split.isPaid || split.isEmpty || _banking) return;
    final l = AppLocalizations.of(context);

    // 🚨 No money changes hands without an open session — the same
    // last-moment check the ordinary checkout makes.
    if (!await SessionGuard.ensureCanSell(context, ref)) return;
    if (!mounted) return;

    // A credit type is refused for the walk-in customer, by name, as in the
    // ordinary checkout.
    if (type.isCustomerRequired) {
      final customer = ref.read(cartProvider).selectedCustomer;
      if (customer == null || customer.code == 'C000') {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            icon: Icon(Icons.block, color: context.dangerColor, size: 36),
            title: Text(l.transactionBlocked),
            content: Text(l.creditNeedsCustomer),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(c),
                child: Text(l.actionOk),
              ),
            ],
          ),
        );
        return;
      }
    }

    setState(() {
      _bill.markPaid(
        split,
        paymentTypeId: type.id,
        collectsMoney: type.markAsPaid,
      );
    });

    final settings = ref.read(appSettingsProvider);
    final allTypes = ref.read(allPaymentTypesProvider).value ?? const [];
    if (shouldOpenDrawerForSale(
      paymentTypeOpensDrawer: type.openCashDrawer,
      anyPaymentTypeOpensDrawer: allTypes.any((t) => t.openCashDrawer),
    )) {
      unawaited(
        openEnabledDrawers(settings).then((failures) {
          if (failures.isEmpty || !mounted) return;
          showAppSnackbar(
            context,
            ref,
            AppLocalizations.of(context).cashDrawerFailed(failures.first),
            isError: true,
          );
        }),
      );
    }

    if (_bill.isSettled) await _bank();
  }

  /// Writes the whole sale once: one order, one document with every item, a
  /// payment per guest. Then the receipts, and back to the checkout.
  Future<void> _bank() async {
    if (_banking || !_bill.isSettled) return;
    final company = ref.read(selectedCompanyProvider);
    final user = ref.read(currentUserProvider);
    if (company == null || user == null) return;

    final l = AppLocalizations.of(context);
    final settings = ref.read(appSettingsProvider);
    final sym = ref.read(currencySymbolProvider);
    final types = ref.read(allPaymentTypesProvider).value ?? const <PaymentType>[];
    bool marksAsPaid(int id) =>
        types.where((t) => t.id == id).firstOrNull?.markAsPaid ?? true;

    setState(() => _banking = true);
    try {
      final banked = await bankCartSale(
        ref,
        company: company,
        user: user,
        items: _bill.items,
        total: _bill.grandTotal,
        tenders: [
          for (final t in _bill.tenders)
            SaleTender(paymentTypeId: t.paymentTypeId, amount: t.amount),
        ],
        paidStatus: _bill.paidStatus(marksAsPaid: marksAsPaid),
        currencySymbol: sym,
        pointsUsed: widget.pointsUsed,
        pointsDiscount: widget.pointsDiscount,
      );

      await settleLoyaltyPoints(
        ref,
        settings: settings,
        customer: banked.cartState.selectedCustomer,
        grandTotal: widget.loyaltyBaseTotal,
        pointsUsed: widget.pointsUsed,
      );

      final collected = _bill.tenders.fold<double>(0, (s, t) => s + t.amount);
      ref.read(customerDisplayProvider.notifier).completeCheckout(
            total: _bill.grandTotal,
            amountPaid: collected,
            changeDue: 0,
          );
      SoundService.instance.play(settings, PosSound.checkout);

      _fireKitchenTickets(banked, settings, user, l);
      await _printReceipts(banked, settings, company, user, types, sym, l);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _banking = false);
      showAppSnackbar(context, ref, l.checkoutError('$e'), isError: true);
    }
  }

  /// The station tickets the ordinary checkout fires on completion, when this
  /// terminal opted in. Fire-and-forget: a dead kitchen printer must never
  /// disturb an already-banked sale.
  void _fireKitchenTickets(
    BankedSale banked,
    Map<String, String> settings,
    User user,
    AppLocalizations l,
  ) {
    if ((settings[SettingKeys.autoKitchenPrintOnCheckout] ?? 'false')
            .toLowerCase() !=
        'true') {
      return;
    }
    final routing = ref.read(printerRoutingProvider);
    if (!routing.hasKitchenStations) return;
    unawaited(
      routing
          .printStationTicketsForCart(
            items: _bill.items,
            serviceType: banked.cartState.serviceType,
            floorPlanTableId: banked.cartState.floorPlanTableId,
            orderNumber: banked.cartState.orderNumber ?? 'WALK-IN',
            cashierName: user.displayName,
            serviceFallback: l.posOrder,
          )
          .catchError((_) => 0),
    );
  }

  /// One receipt per guest — their items, their share, their payment — all
  /// under the one document number. Same print rule as the ordinary checkout:
  /// the dialog setting decides HOW, never WHETHER.
  Future<void> _printReceipts(
    BankedSale banked,
    Map<String, String> settings,
    Company company,
    User user,
    List<PaymentType> types,
    String sym,
    AppLocalizations l,
  ) async {
    final autoprint =
        (settings[SettingKeys.autoprint] ?? '').toLowerCase() == 'true';
    final showPrintDialog =
        (settings[SettingKeys.displayReceiptPrintDialog] ?? '').toLowerCase() ==
            'true';
    final logo = _logoBytes(company);
    final shares = [
      for (final s in _bill.splits)
        if (s.isPaid)
          (
            split: s,
            items: _bill.itemsOf(s),
            totals: _bill.totalsOf(s),
          ),
    ];

    void printAll({bool saveToFile = false}) {
      for (final share in shares) {
        final tender = share.split.tender!;
        unawaited(
          ReceiptPrinterService()
              .printCartReceipt(
                saveToFile: saveToFile,
                company: company,
                cashier: user,
                customer: banked.cartState.selectedCustomer,
                orderNumber: '${banked.cartState.orderNumber ?? 'WALK-IN'}'
                    ' · ${l.splitName(share.split.number)}',
                documentNumber: banked.documentNumber,
                printTime: DateTime.now(),
                items: share.items,
                subtotal: share.totals.subtotal,
                totalDiscount: share.totals.discount,
                totalTax: share.totals.tax,
                grandTotal: tender.due,
                currencySymbol: sym,
                paymentTypeName: types
                    .where((t) => t.id == tender.paymentTypeId)
                    .firstOrNull
                    ?.name,
                amountPaid: tender.amount,
                logoBytes: logo,
                roleSettings: settings,
              )
              // Reported, not swallowed — a printer that is off must not look
              // like a printer that printed.
              .catchError((Object e) {
                if (mounted) {
                  showAppSnackbar(context, ref, l.printFailed('$e'),
                      isError: true);
                }
              }),
        );
      }
    }

    if (autoprint || !showPrintDialog) {
      printAll();
      return;
    }
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: Icon(
          Icons.check_circle_outline,
          color: context.successColor,
          size: 36,
        ),
        title: Text(l.transactionSuccessful),
        content: Text(l.printReceiptPrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'no'),
            child: Text(l.actionNo),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'save'),
            child: Text(l.saveAsPdf),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'print'),
            child: Text(l.printReceipt),
          ),
        ],
      ),
    );
    if (choice == 'print') printAll();
    if (choice == 'save') printAll(saveToFile: true);
  }

  /// The bill for ONE guest's share, before they pay. Banks nothing — like
  /// the menu's Addition, pressing it twice is harmless.
  Future<void> _printGuestCheck(BillSplit split) async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null || split.isEmpty) return;
    final l = AppLocalizations.of(context);
    final cart = ref.read(cartProvider);
    final totals = _bill.totalsOf(split);

    setState(() => _printing.add(split.number));
    try {
      await ReceiptPrinterService().printGuestCheck(
        company: company,
        cashier: ref.read(currentUserProvider),
        customer: cart.selectedCustomer,
        orderNumber:
            '${cart.orderNumber ?? 'WALK-IN'} · ${l.splitName(split.number)}',
        printTime: DateTime.now(),
        items: _bill.itemsOf(split),
        subtotal: totals.subtotal,
        totalDiscount: totals.discount,
        totalTax: totals.tax,
        grandTotal: _bill.dueOf(split),
        currencySymbol: ref.read(currencySymbolProvider),
        logoBytes: _logoBytes(company),
        // The role-based printer settings: which printer, paper, margins,
        // font — read from the same map every receipt prints with.
        roleSettings: ref.read(appSettingsProvider),
      );
      if (mounted) showAppSnackbar(context, ref, l.splitGuestCheckPrinted);
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, l.printFailed('$e'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _printing.remove(split.number));
    }
  }

  /// Backs out. Payments already taken were never saved, so the operator is
  /// told to hand the money back before they vanish with the dialog.
  Future<void> _close() async {
    if (_banking) return;
    if (!_bill.anyPaid) {
      Navigator.of(context).pop(false);
      return;
    }
    final l = AppLocalizations.of(context);
    final paidCount = _bill.splits.where((s) => s.isPaid).length;
    final discard = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            color: context.warningColor, size: 36),
        title: Text(l.splitDiscardTitle),
        content: Text(l.splitDiscardBody(paidCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.dangerColor),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.splitDiscardConfirm),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop(false);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Uint8List? _logoBytes(Company company) {
    final b64 = company.logo;
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  /// A weighed line reads `0.125 kg`, never `0.13` — the checkout summary's
  /// rule, so the same line reads the same on both screens.
  static String _qtyText(CartItem it, double quantity) {
    final label = (it.measurementUnit?.trim().isNotEmpty ?? false)
        ? it.measurementUnit!.trim()
        : uomById(it.uomId).code;
    final value = formatQuantityValue(quantity, it.uomId);
    return it.uomId == kUomPieces && (it.measurementUnit?.isEmpty ?? true)
        ? value
        : '$value $label';
  }
}

/// How many of a line go to one guest: a − / + stepper, finger-sized, with a
/// shortcut for the whole line.
class _QuantityPickerDialog extends StatefulWidget {
  const _QuantityPickerDialog({required this.productName, required this.max});

  final String productName;
  final int max;

  @override
  State<_QuantityPickerDialog> createState() => _QuantityPickerDialogState();
}

class _QuantityPickerDialogState extends State<_QuantityPickerDialog> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.splitHowMany(widget.productName)),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filledTonal(
            iconSize: 28,
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            onPressed:
                _quantity > 1 ? () => setState(() => _quantity--) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 96,
            child: Text(
              '$_quantity',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton.filledTonal(
            iconSize: 28,
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            onPressed: _quantity < widget.max
                ? () => setState(() => _quantity++)
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.actionCancel),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, widget.max),
          child: Text(l.splitAllQuantity(widget.max)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _quantity),
          child: Text(l.splitAssign),
        ),
      ],
    );
  }
}
