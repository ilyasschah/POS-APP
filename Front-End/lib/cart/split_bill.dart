// A split bill: one cart, divided between guests, each paying their own share
// of ONE document.
//
// Pure Dart on purpose — no Riverpod, no widgets — so the money can be tested
// on its own. The dialog (`split_payment_dialog.dart`) only draws this state.
//
// 🚨 Nothing here banks anything. A split marked paid is a tender held in
// memory, exactly like the numpad of the ordinary checkout until Complete: the
// sale is written once, when every item is on a split and every split is paid.
import 'package:pos_app/cart/checkout_models.dart';

/// Money to the cent. Via the string form, because `(v * 100).round() / 100`
/// turns 1.005 into 1.00 on a binary double.
double roundMoney(double v) => double.parse(v.toStringAsFixed(2));

/// Quantities to the gram/millilitre, so moving a line back and forth never
/// leaves 0.30000000000000004 of it stranded in the pool.
double _snapQty(double v) => double.parse(v.toStringAsFixed(3));

const double _qtyEpsilon = 0.0005;

/// What ONE unit of a cart line costs once every discount is on it.
class SplitUnitMoney {
  const SplitUnitMoney({
    required this.subtotal,
    required this.discount,
    required this.tax,
  });

  /// Ex-tax price of the unit before any discount — the cart's `subtotal`
  /// basis, so a split's figures read like the whole bill's.
  final double subtotal;

  /// Everything taken off the unit: its own discount and promotion, plus its
  /// share of the order-level discounts.
  final double discount;

  final double tax;

  double get total => subtotal - discount + tax;
}

/// The cart's figures, brought down to one unit of each line.
///
/// Order-level discounts (customer profile, manual cart discount, loyalty
/// points) belong to the whole bill, so each line carries a share in
/// proportion to its own net — the same split the server makes when it banks
/// the document (`ApportionDocumentDiscount`). It is what makes the shares add
/// up to the grand total.
///
/// Each figure is passed in rather than re-derived: line tax has exactly one
/// source of truth, the cart notifier, and a second formula here is how a
/// split would come to disagree with the bill it was cut from.
Map<String, SplitUnitMoney> splitUnitMoney({
  required List<CartItem> items,
  required double Function(CartItem) netUnitPrice,
  required double Function(CartItem) lineNet,
  required double Function(CartItem) lineTax,
  required double orderLevelDiscount,
}) {
  final nets = {for (final i in items) i.cartItemId: lineNet(i)};
  final netSum = nets.values.fold<double>(0, (s, n) => s + n);

  return {
    for (final i in items)
      i.cartItemId: () {
        if (i.quantity <= 0) {
          return const SplitUnitMoney(subtotal: 0, discount: 0, tax: 0);
        }
        final net = nets[i.cartItemId]!;
        final share = netSum > 0 ? orderLevelDiscount * net / netSum : 0.0;
        final unitSubtotal = netUnitPrice(i);
        // Own discounts = the undiscounted line minus its net.
        final ownDiscount = unitSubtotal * i.quantity - net;
        return SplitUnitMoney(
          subtotal: unitSubtotal,
          discount: (ownDiscount + share) / i.quantity,
          tax: lineTax(i) / i.quantity,
        );
      }(),
  };
}

/// One guest's settled share.
class SplitTender {
  const SplitTender({
    required this.paymentTypeId,
    required this.amount,
    required this.due,
  });

  final int paymentTypeId;

  /// Money actually collected. Zero for a share put on account (a payment
  /// type that does not mark the sale paid): nothing changed hands.
  final double amount;

  /// What the share came to when it was settled.
  final double due;
}

/// One guest's part of the bill.
class BillSplit {
  BillSplit(this.number);

  /// "Split 1", "Split 2"… Never reused after a removal, so a guest check
  /// already printed for "Split 3" never comes to mean somebody else's share.
  final int number;

  /// cartItemId → quantity, in the order the items arrived.
  final Map<String, double> allocations = {};

  int? paymentTypeId;
  SplitTender? tender;

  bool get isPaid => tender != null;
  bool get isEmpty => allocations.isEmpty;
}

class SplitBill {
  SplitBill({
    required List<CartItem> items,
    required this.money,
    required this.grandTotal,
    int splits = 2,
  })  : items = List.unmodifiable(items),
        _pool = {for (final i in items) i.cartItemId: i.quantity} {
    for (var n = 0; n < splits; n++) {
      addSplit();
    }
  }

  final List<CartItem> items;
  final Map<String, SplitUnitMoney> money;

  /// What the whole bill comes to — the document total the shares must meet.
  final double grandTotal;

  final Map<String, double> _pool;
  final List<BillSplit> splits = [];
  int _nextNumber = 1;

  CartItem itemById(String cartItemId) =>
      items.firstWhere((i) => i.cartItemId == cartItemId);

  /// How much of a line is still on nobody's split.
  double unassigned(String cartItemId) => _pool[cartItemId] ?? 0;

  /// The lines with something left to allocate, in cart order.
  List<CartItem> get pool => [
        for (final i in items)
          if (unassigned(i.cartItemId) > _qtyEpsilon) i,
      ];

  bool get poolEmpty => pool.isEmpty;

  BillSplit addSplit() {
    final split = BillSplit(_nextNumber++);
    splits.add(split);
    return split;
  }

  bool canRemove(BillSplit split) =>
      split.isEmpty && !split.isPaid && splits.length > 1;

  void removeSplit(BillSplit split) {
    if (canRemove(split)) splits.remove(split);
  }

  /// Moves [quantity] of a line from the pool onto [split], clamped to what
  /// the pool still holds.
  void assign(String cartItemId, BillSplit split, double quantity) {
    if (split.isPaid) throw StateError('A paid split is locked.');
    final left = unassigned(cartItemId);
    final q = quantity > left ? left : quantity;
    if (q <= _qtyEpsilon) return;
    _pool[cartItemId] = _snapQty(left - q);
    split.allocations[cartItemId] =
        _snapQty((split.allocations[cartItemId] ?? 0) + q);
  }

  /// Hands a line on [split] back to the pool, whole.
  void unassign(String cartItemId, BillSplit split) {
    if (split.isPaid) throw StateError('A paid split is locked.');
    final q = split.allocations.remove(cartItemId);
    if (q == null) return;
    _pool[cartItemId] = _snapQty(unassigned(cartItemId) + q);
  }

  ({double subtotal, double discount, double tax, double total}) totalsOf(
    BillSplit split,
  ) {
    var subtotal = 0.0, discount = 0.0, tax = 0.0;
    split.allocations.forEach((id, q) {
      final m = money[id]!;
      subtotal += m.subtotal * q;
      discount += m.discount * q;
      tax += m.tax * q;
    });
    return (
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      total: subtotal - discount + tax,
    );
  }

  /// What [split] is asked to pay, to the cent.
  ///
  /// 🚨 The LAST share to be settled takes whatever the others leave of the
  /// grand total. Every share rounds to the cent on its own, so three thirds
  /// of 100.00 come to 99.99 — and a document whose payments fall a cent short
  /// reads as "Partially paid" for ever after.
  double dueOf(BillSplit split) {
    if (split.isPaid) return split.tender!.due;
    if (split.isEmpty) return 0;
    final open = splits.where((s) => !s.isPaid && !s.isEmpty).toList();
    if (poolEmpty && open.length == 1 && identical(open.single, split)) {
      final settled = splits
          .where((s) => s.isPaid)
          .fold<double>(0, (sum, s) => sum + s.tender!.due);
      return roundMoney(grandTotal - settled);
    }
    return roundMoney(totalsOf(split).total);
  }

  /// Settles [split]. [collectsMoney] is the payment type's `markAsPaid`: a
  /// share put on account records a zero payment and stays owed.
  void markPaid(
    BillSplit split, {
    required int paymentTypeId,
    required bool collectsMoney,
  }) {
    if (split.isEmpty) throw StateError('An empty split has nothing to pay.');
    final due = dueOf(split);
    split.paymentTypeId = paymentTypeId;
    split.tender = SplitTender(
      paymentTypeId: paymentTypeId,
      amount: collectsMoney ? due : 0,
      due: due,
    );
  }

  /// Unlocks a settled split. Only ever before the sale banks — the money is
  /// still in the operator's hand, not in a document.
  void undoPayment(BillSplit split) => split.tender = null;

  bool get anyPaid => splits.any((s) => s.isPaid);

  /// Every item is on a split, and every split holding items is settled.
  bool get isSettled =>
      poolEmpty &&
      splits.any((s) => !s.isEmpty) &&
      splits.every((s) => s.isEmpty || s.isPaid);

  /// The settled shares, in split order — the document's payments.
  List<SplitTender> get tenders => [
        for (final s in splits)
          if (s.isPaid) s.tender!,
      ];

  /// [split]'s lines as cart items of the allocated quantities — what its
  /// guest check and its receipt print.
  List<CartItem> itemsOf(BillSplit split) => [
        for (final e in split.allocations.entries)
          itemById(e.key).withQuantity(e.value),
      ];

  /// The document's paid status once these tenders bank: 1 paid, 2 partly
  /// paid, 0 unpaid. The rule `recomputePaidStatus` and the server's checkout
  /// both apply, so the three never disagree about the same sale.
  int paidStatus({required bool Function(int paymentTypeId) marksAsPaid}) {
    final all = tenders;
    if (all.every((t) => marksAsPaid(t.paymentTypeId))) return 1;
    final collected = all.fold<double>(0, (s, t) => s + t.amount);
    if (collected >= grandTotal - 0.005) return 1;
    return collected > 0.005 ? 2 : 0;
  }
}
