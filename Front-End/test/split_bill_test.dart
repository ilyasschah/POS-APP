// The money of a split bill — one table's cart, divided between guests who
// each pay their share of ONE document.
//
// What this pins:
//   • the shares add up to the bill, order-level discounts included;
//   • a line can be split by quantity, and never over-allocated;
//   • the last share to be paid absorbs the cent that per-share rounding
//     loses — otherwise three thirds of 100.00 bank as 99.99 "Partially paid";
//   • a paid split is locked until its payment is undone;
//   • the document's paid status follows the same rule as the server.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/cart/split_bill.dart';

CartItem _line(String id, {required double qty, required double price}) =>
    CartItem(
      cartItemId: id,
      posOrderId: 0,
      productId: id.hashCode,
      quantity: qty,
      price: price,
      productName: id,
      appliedTaxes: const [],
      isTaxInclusive: false,
    );

/// A bill whose lines carry 20% tax on their net and share
/// [orderLevelDiscount] — the cart notifier's figures, faked.
SplitBill _bill(
  List<CartItem> items, {
  double orderLevelDiscount = 0,
  int splits = 2,
}) {
  final money = splitUnitMoney(
    items: items,
    netUnitPrice: (i) => i.price,
    lineNet: (i) => i.price * i.quantity,
    lineTax: (i) => i.price * i.quantity * 0.2,
    orderLevelDiscount: orderLevelDiscount,
  );
  final grand = items.fold<double>(0, (s, i) => s + i.price * i.quantity * 1.2) -
      orderLevelDiscount;
  return SplitBill(items: items, money: money, grandTotal: grand, splits: splits);
}

void main() {
  test('the shares add up to the bill, order-level discount included', () {
    final bill = _bill(
      [_line('tagine', qty: 1, price: 80), _line('tea', qty: 2, price: 10)],
      orderLevelDiscount: 12,
    );
    final a = bill.splits[0], b = bill.splits[1];
    bill.assign('tagine', a, 1);
    bill.assign('tea', b, 2);

    // 80 + 16 tax − 9.60 share, and 20 + 4 tax − 2.40 share.
    expect(bill.totalsOf(a).total, closeTo(86.40, 1e-9));
    expect(bill.totalsOf(b).total, closeTo(21.60, 1e-9));
    expect(bill.dueOf(a) + bill.dueOf(b), closeTo(bill.grandTotal, 1e-9));
  });

  test('a line splits by quantity and is never over-allocated', () {
    final bill = _bill([_line('tea', qty: 3, price: 10)]);
    final a = bill.splits[0], b = bill.splits[1];

    bill.assign('tea', a, 2);
    bill.assign('tea', b, 5); // only one is left

    expect(a.allocations['tea'], 2);
    expect(b.allocations['tea'], 1);
    expect(bill.poolEmpty, isTrue);
    expect(bill.itemsOf(a).single.quantity, 2);
    expect(bill.itemsOf(a).single.price, 10, reason: 'per-unit, unchanged');

    bill.unassign('tea', a);
    expect(bill.unassigned('tea'), 2);
  });

  test('the last share to be paid absorbs the rounding cent', () {
    // Three guests sharing one 100.00 bill evenly: 33.333… each.
    final items = [
      _line('x', qty: 1, price: 100 / 3 / 1.2),
      _line('y', qty: 1, price: 100 / 3 / 1.2),
      _line('z', qty: 1, price: 100 / 3 / 1.2),
    ];
    final even = _bill(items, splits: 3);
    expect(even.grandTotal, closeTo(100, 1e-9));

    even.assign('x', even.splits[0], 1);
    even.assign('y', even.splits[1], 1);
    even.assign('z', even.splits[2], 1);

    even.markPaid(even.splits[0], paymentTypeId: 1, collectsMoney: true);
    even.markPaid(even.splits[1], paymentTypeId: 1, collectsMoney: true);
    expect(even.dueOf(even.splits[0]), 33.33);
    expect(even.dueOf(even.splits[2]), 33.34);

    even.markPaid(even.splits[2], paymentTypeId: 2, collectsMoney: true);
    final paid = even.tenders.fold<double>(0, (s, t) => s + t.amount);
    expect(paid, closeTo(100, 1e-9));
  });

  test('a paid split is locked until its payment is undone', () {
    final bill = _bill([_line('tea', qty: 2, price: 10)]);
    final a = bill.splits[0];
    bill.assign('tea', a, 1);
    bill.markPaid(a, paymentTypeId: 1, collectsMoney: true);

    expect(() => bill.assign('tea', a, 1), throwsStateError);
    expect(() => bill.unassign('tea', a), throwsStateError);
    expect(bill.canRemove(a), isFalse);

    bill.undoPayment(a);
    bill.assign('tea', a, 1);
    expect(a.allocations['tea'], 2);
  });

  test('settled only when every item is on a split and every split is paid',
      () {
    final bill = _bill([_line('a', qty: 1, price: 10), _line('b', qty: 1, price: 10)]);
    final s1 = bill.splits[0];
    bill.assign('a', s1, 1);
    bill.markPaid(s1, paymentTypeId: 1, collectsMoney: true);
    expect(bill.isSettled, isFalse, reason: '"b" is still unassigned');

    bill.assign('b', bill.splits[1], 1);
    expect(bill.isSettled, isFalse, reason: 'split 2 is unpaid');

    bill.markPaid(bill.splits[1], paymentTypeId: 1, collectsMoney: true);
    expect(bill.isSettled, isTrue);
  });

  test('an empty split is ignored, and can be removed', () {
    final bill = _bill([_line('a', qty: 1, price: 10)], splits: 3);
    bill.assign('a', bill.splits[0], 1);
    bill.markPaid(bill.splits[0], paymentTypeId: 1, collectsMoney: true);

    expect(bill.isSettled, isTrue);
    expect(bill.canRemove(bill.splits[2]), isTrue);
    bill.removeSplit(bill.splits[2]);
    expect(bill.splits.map((s) => s.number), [1, 2]);
    expect(bill.addSplit().number, 4, reason: 'numbers are never reused');
  });

  group('paid status', () {
    SplitBill settled(List<(int type, bool collects)> tenders) {
      final items = [
        for (var i = 0; i < tenders.length; i++) _line('l$i', qty: 1, price: 10),
      ];
      final bill = _bill(items, splits: tenders.length);
      for (var i = 0; i < tenders.length; i++) {
        bill.assign('l$i', bill.splits[i], 1);
        bill.markPaid(bill.splits[i],
            paymentTypeId: tenders[i].$1, collectsMoney: tenders[i].$2);
      }
      return bill;
    }

    bool marksAsPaid(int type) => type != 9; // 9 = on account

    test('every share collected → paid', () {
      expect(settled([(1, true), (2, true)]).paidStatus(marksAsPaid: marksAsPaid), 1);
    });

    test('one share on account → partly paid', () {
      final bill = settled([(1, true), (9, false)]);
      expect(bill.tenders.last.amount, 0, reason: 'nothing changed hands');
      expect(bill.paidStatus(marksAsPaid: marksAsPaid), 2);
    });

    test('every share on account → unpaid', () {
      expect(settled([(9, false), (9, false)]).paidStatus(marksAsPaid: marksAsPaid), 0);
    });
  });
}
