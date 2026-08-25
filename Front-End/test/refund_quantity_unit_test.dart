// What the refund dialog shows, and what one tap of its +/- does.
//
// A document line stores a bare number — 100 — and the unit lives on the
// product, so the dialog has to look it up or it renders a weighed refund
// through the money formatter as a flat "100.00" and steps it a KILOGRAM at a
// time. On a 0.350 kg line that stepper could do exactly two things: empty the
// line, or overfill it past what was actually sold, because `enabled:
// value < max` gated the tap but nothing bounded its result.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/refund/refund_dialog.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

void main() {
  group('how far one tap moves', () {
    test('a gram product steps by ONE GRAM', () {
      // The user's requirement, stated exactly: 1 g, not 1 kg.
      expect(quantityStepFor(kUomGram), 1);
    });

    test('pieces are unchanged — one whole piece, as before', () {
      expect(quantityStepFor(kUomPieces), 1);
    });

    test('a fractional unit steps by a tenth, not by its rounding', () {
      // 0.001 kg would be 350 taps to clear a 0.350 kg line; a flat 1 kg could
      // only clear or refill it. A tenth puts every figure on that line within
      // four taps.
      expect(quantityStepFor(kUomKilogram), 0.1);
      expect(quantityStepFor(kUomLitre), 0.1);
    });

    test('millilitres and centimetres count in whole units', () {
      expect(quantityStepFor(kUomMillilitre), 1);
      expect(quantityStepFor(31), 1);
    });

    test('an unknown unit falls back to whole pieces rather than throwing', () {
      expect(quantityStepFor(9999), 1);
      expect(quantityStepFor(null), 1);
    });
  });

  group('the gram line from the report', () {
    // Saffron sold 100 g; the dialog opens with all 100 selected for refund.
    const sold = 100.0;

    test('it reads "100 g", not "100.00"', () {
      expect(formatQuantity(sold, kUomGram), '100 g');
    });

    test('one tap down is 99 g', () {
      expect(
        steppedRefundQuantity(value: sold, max: sold, uomId: kUomGram, up: false),
        99,
      );
    });

    test('tapping up at the maximum cannot exceed what was sold', () {
      expect(
        steppedRefundQuantity(value: sold, max: sold, uomId: kUomGram, up: true),
        sold,
      );
    });

    test('tapping down never runs past zero into a negative refund', () {
      expect(
        steppedRefundQuantity(value: 0, max: sold, uomId: kUomGram, up: false),
        0,
      );
    });

    test('ten taps down lands on exactly 90 g, with no drift', () {
      var qty = sold;
      for (var i = 0; i < 10; i++) {
        qty = steppedRefundQuantity(
            value: qty, max: sold, uomId: kUomGram, up: false);
      }
      expect(qty, 90);
    });
  });

  group('a kilogram line', () {
    const sold = 0.350;

    test('it reads "0.350 kg" at full precision', () {
      expect(formatQuantity(sold, kUomKilogram), '0.350 kg');
    });

    test('one tap down is 0.250 kg — the line is no longer all-or-nothing', () {
      expect(
        steppedRefundQuantity(
            value: sold, max: sold, uomId: kUomKilogram, up: false),
        0.250,
      );
    });

    test('the old ±1 could not have produced that figure', () {
      // Pinning the actual regression: 0.350 − 1 is −0.650, a negative refund
      // the dialog happily accepted and priced.
      expect(sold - 1, lessThan(0));
      expect(
        steppedRefundQuantity(
            value: sold, max: sold, uomId: kUomKilogram, up: false),
        greaterThan(0),
      );
    });

    test('stepping down to empty stops at zero and stays there', () {
      var qty = sold;
      for (var i = 0; i < 10; i++) {
        qty = steppedRefundQuantity(
            value: qty, max: sold, uomId: kUomKilogram, up: false);
      }
      expect(qty, 0);
    });

    test('stepping back up stops at what was sold', () {
      var qty = 0.0;
      for (var i = 0; i < 10; i++) {
        qty = steppedRefundQuantity(
            value: qty, max: sold, uomId: kUomKilogram, up: true);
      }
      expect(qty, sold, reason: 'never more than the receipt line held');
    });

    test('a partial step leaves a figure that still formats cleanly', () {
      // The stepper writes straight into the refund payload, so a value
      // carrying binary residue would reach the document and the receipt.
      final qty = steppedRefundQuantity(
          value: sold, max: sold, uomId: kUomKilogram, up: false);
      expect(formatQuantityValue(qty, kUomKilogram), '0.250');
    });
  });

  group('a pieces line behaves exactly as it always did', () {
    test('one tap is one piece', () {
      expect(
        steppedRefundQuantity(value: 3, max: 5, uomId: kUomPieces, up: false),
        2,
      );
      expect(
        steppedRefundQuantity(value: 3, max: 5, uomId: kUomPieces, up: true),
        4,
      );
    });

    test('but it can no longer be pushed past the quantity sold', () {
      expect(
        steppedRefundQuantity(value: 5, max: 5, uomId: kUomPieces, up: true),
        5,
      );
    });
  });
}
