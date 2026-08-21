// Phase 8 — the closing dialog's money logic.
//
// The dialog is where a cashier signs off a drawer, so what is tested here is
// the arithmetic and the gate: the difference the screen shows, the tolerance
// that decides whether they may close alone, and the cash-row breakdown that
// justifies the expected figure to them.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/session/session_reconciliation.dart';

void main() {
  SessionReconciliation build({
    double opening = 2000,
    double cashPayments = 8500,
    double cashIn = 500,
    double cashOut = 200,
    double? counted,
    double tolerance = 10,
    List<SessionMethodTotal>? methods,
  }) =>
      SessionReconciliation(
        openingCash: opening,
        cashPayments: cashPayments,
        cashIn: cashIn,
        cashOut: cashOut,
        documentCount: 5,
        countedCash: counted,
        maxCashDifference: tolerance,
        methods: methods ??
            const [
              SessionMethodTotal(
                paymentTypeId: 1,
                paymentTypeName: 'Espèces',
                isCash: true,
                expected: 8500,
              ),
              SessionMethodTotal(
                paymentTypeId: 2,
                paymentTypeName: 'TPE',
                isCash: false,
                expected: 4137.70,
              ),
            ],
      );

  group('the header figure', () {
    test('totals EVERY method, not just cash', () {
      // The dialog header reads "N orders: X" — that is everything taken, so a
      // card-heavy day must not appear to have taken only its cash.
      expect(build().totalTaken, closeTo(12637.70, 0.001));
    });
  });

  group('the cash row breakdown justifies the expected figure', () {
    test('opening + cash in − cash out + cash payments reconciles', () {
      final r = build();
      final fromParts =
          r.openingCash + (r.cashIn - r.cashOut) + r.cashPayments;
      expect(fromParts, r.expectedCash,
          reason: 'the sub-rows must add up to the number above them');
      expect(r.expectedCash, 10800);
    });

    test('a cash-out larger than cash-in still reconciles', () {
      final r = build(cashIn: 100, cashOut: 400);
      expect(r.openingCash + (r.cashIn - r.cashOut) + r.cashPayments,
          r.expectedCash);
      expect(r.expectedCash, 10200);
    });
  });

  group('the difference column', () {
    test('is counted − expected, signed', () {
      expect(build(counted: 10750).cashDifference, -50);
      expect(build(counted: 10850).cashDifference, 50);
      expect(build(counted: 10800).cashDifference, 0);
    });

    test('a non-cash row computes its own difference independently', () {
      const m = SessionMethodTotal(
        paymentTypeId: 2,
        paymentTypeName: 'TPE',
        isCash: false,
        expected: 4137.70,
      );
      expect(m.withCounted(4137.70).difference, 0);
      expect(m.withCounted(4000).difference, closeTo(-137.70, 0.001));
      // Not confirmed at all is NOT the same as confirmed-and-equal.
      expect(m.difference, isNull);
    });
  });

  group('the tolerance gate', () {
    test('within tolerance closes without a manager', () {
      expect(build(counted: 10795).needsManagerAuthorisation, isFalse);
      expect(build(counted: 10805).needsManagerAuthorisation, isFalse);
    });

    test('exactly at the limit is allowed — the rule is "greater than"', () {
      expect(build(counted: 10790).needsManagerAuthorisation, isFalse);
      expect(build(counted: 10810).needsManagerAuthorisation, isFalse);
    });

    test('one dirham past the limit needs a manager, either direction', () {
      expect(build(counted: 10789).needsManagerAuthorisation, isTrue);
      expect(build(counted: 10811).needsManagerAuthorisation, isTrue);
    });

    test('the tolerance is configurable per company', () {
      expect(build(counted: 10750, tolerance: 100).needsManagerAuthorisation,
          isFalse);
      expect(build(counted: 10799, tolerance: 0).needsManagerAuthorisation,
          isTrue, reason: 'zero tolerance means every discrepancy escalates');
    });

    test('an uncounted drawer does not trip the gate', () {
      // Opening the dialog must not immediately demand a manager.
      expect(build().needsManagerAuthorisation, isFalse);
      expect(build().cashDifference, isNull);
    });
  });

  test('a non-cash method never moves the expected cash', () {
    // 🚨 The mistake `OpenCashDrawer` would have caused: TPE is 4,137.70 and
    // must stay out of the drawer figure entirely.
    final r = build();
    expect(r.expectedCash, 10800);
    expect(r.totalTaken - r.expectedCash, closeTo(1837.70, 0.001));
  });
}
