import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

/// Per-product pack sizes, mirroring
/// `Back-End/Web-POS.Api.Tests/ProductPackSizeTests.cs` case for case. The two
/// implementations convert independently — the till deducts local stock while
/// the server deducts its own — so a divergence here is stock that disagrees
/// with the server on every sale of a boxed product.
///
/// Before `packSize`, box and pack carried a hardcoded 1/12 and 1/6, so a box of
/// anything was 12: a 24-can box restocked 12 cans and lost the other 12.
///
/// The rule underneath all of it: **null must behave exactly like the old
/// hardcoded factor.** Every product in an existing catalogue upgrades to null,
/// and null has to mean "carry on as before".
void main() {
  group('the reason the field exists', () {
    test('a box of 24 moves 24 pieces of stock', () {
      var stock = 100.0;
      stock -= uomToReference(2, kUomBox, packSize: 24);
      expect(stock, closeTo(52, 1e-9));
    });

    test('the same two boxes moved only 24 before it existed', () {
      var stock = 100.0;
      stock -= uomToReference(2, kUomBox, packSize: null);
      expect(stock, closeTo(76, 1e-9));
    });
  });

  group('a null pack size is the catalogue nominal', () {
    test('a box is 12', () {
      expect(uomToReference(1, kUomBox, packSize: null), closeTo(12, 1e-9));
    });

    test('a pack is 6', () {
      expect(uomToReference(1, kUomPack, packSize: null), closeTo(6, 1e-9));
    });

    test('zero and negative fall back rather than divide by nothing', () {
      // A zero would divide the conversion by nothing; a negative one would ADD
      // stock on a sale.
      expect(uomToReference(1, kUomBox, packSize: 0), closeTo(12, 1e-9));
      expect(uomToReference(1, kUomBox, packSize: -5), closeTo(12, 1e-9));
      expect(normalisePackSize(kUomBox, 0), isNull);
      expect(normalisePackSize(kUomBox, -5), isNull);
    });
  });

  group('which units listen to it', () {
    test('a dozen is twelve whatever the product claims', () {
      expect(isPackSizedUom(kUomDozen), isFalse);
      expect(uomToReference(1, kUomDozen, packSize: 10), closeTo(12, 1e-9));
    });

    test('a physical unit ignores it entirely', () {
      for (final uomId in [kUomKilogram, kUomGram, kUomPieces]) {
        expect(isPackSizedUom(uomId), isFalse);
        expect(
          uomToReference(500, uomId, packSize: 24),
          closeTo(uomToReference(500, uomId, packSize: null), 1e-9),
        );
      }
    });

    test('only box and pack are pack-sized', () {
      expect(isPackSizedUom(kUomBox), isTrue);
      expect(isPackSizedUom(kUomPack), isTrue);
    });
  });

  group('the two directions agree', () {
    test('converting out and back returns the same quantity', () {
      for (final packSize in [24.0, 6.0, 1.0]) {
        final pieces = uomToReference(3, kUomBox, packSize: packSize);
        expect(uomFromReference(pieces, kUomBox, packSize: packSize),
            closeTo(3, 1e-9));
      }
    });

    test('stock on hand reads back as the boxes it makes', () {
      // Changing a pack size never rewrites stock; it restates what the pieces
      // already on the shelf add up to.
      expect(uomFromReference(120, kUomBox, packSize: 24), closeTo(5, 1e-9));
      expect(uomFromReference(120, kUomBox, packSize: null), closeTo(10, 1e-9));
    });
  });

  group('money follows the same factor', () {
    test('a box priced at 240 is 10 per piece when it holds 24', () {
      expect(pricePerReferenceUnit(240, kUomBox, packSize: 24),
          closeTo(10, 1e-9));
    });

    test('and 20 per piece on the nominal 12', () {
      expect(pricePerReferenceUnit(240, kUomBox, packSize: null),
          closeTo(20, 1e-9));
    });
  });

  group('what gets stored', () {
    test('kept only on a unit that can use one', () {
      expect(normalisePackSize(kUomBox, 24), 24);
      expect(normalisePackSize(kUomPack, 4), 4);

      // Dropped, so it cannot sit on the row waiting to be believed if the
      // unit ever moves back to box.
      expect(normalisePackSize(kUomKilogram, 24), isNull);
      expect(normalisePackSize(kUomPieces, 24), isNull);
      expect(normalisePackSize(kUomDozen, 10), isNull);
    });

    test('a null entry stays null', () {
      expect(normalisePackSize(kUomBox, null), isNull);
    });
  });

  test('a pack size of one makes a box a single piece', () {
    expect(effectiveUomFactor(kUomBox, 1), closeTo(1, 1e-9));
    expect(uomToReference(7, kUomBox, packSize: 1), closeTo(7, 1e-9));
  });

  test('a fractional pack size survives the storage precision', () {
    expect(uomToReference(2, kUomPack, packSize: 2.5), closeTo(5, 1e-9));
  });
}
