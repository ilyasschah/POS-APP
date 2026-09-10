import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

/// The quantity the receipt, the guest check and the kitchen ticket print.
///
/// 🚨 Why this exists: all four documents printed "1 x Saffron" for a kilo of
/// saffron. The receipt showed a unit only for weighed items or behind an
/// off-by-default toggle, and the kitchen ticket never showed one — so a
/// product SOLD by the kilo but not weighed at the till lost its unit on paper.
void main() {
  group('every unit except pieces prints its code', () {
    test('a kilo', () {
      expect(formatPrintedQuantity(1, kUomKilogram), '1.000 kg');
    });

    test('grams, litres and boxes', () {
      expect(formatPrintedQuantity(250, kUomGram), '250 g');
      expect(formatPrintedQuantity(1.5, kUomLitre), '1.500 L');
      expect(formatPrintedQuantity(2, kUomBox), '2 box');
    });

    test('the unit shows even when the pieces toggle is off', () {
      expect(formatPrintedQuantity(0.125, kUomKilogram, showPieces: false),
          '0.125 kg');
    });
  });

  group('pieces', () {
    test('a bare number by default — "2 pcs x Burger" is noise', () {
      expect(formatPrintedQuantity(2, kUomPieces), '2');
      expect(formatPrintedQuantity(2, null), '2');
    });

    test('with the toggle on, the code', () {
      expect(formatPrintedQuantity(2, kUomPieces, showPieces: true), '2 pcs');
    });

    test('with the toggle on, a custom label prints in place of pcs', () {
      expect(
        formatPrintedQuantity(2, kUomPieces,
            legacyUnit: 'portion', showPieces: true),
        '2 portion',
      );
    });

    test('a fractional piece is never printed as a whole one', () {
      expect(formatPrintedQuantity(0.5, kUomPieces), '0.5');
    });
  });

  group('an older line with only the legacy text', () {
    test('pieces id + "kg" text is a kilo line', () {
      expect(formatPrintedQuantity(1.5, kUomPieces, legacyUnit: 'kg'),
          '1.500 kg');
    });

    test('a real id wins over stale text', () {
      expect(formatPrintedQuantity(3, kUomGram, legacyUnit: 'kg'), '3 g');
    });
  });
}
