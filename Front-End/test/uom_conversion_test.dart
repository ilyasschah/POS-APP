import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

/// The conversion half of sell-by-weight, mirroring
/// `Back-End/Web-POS.Api.Tests/UnitOfMeasureTests.cs`. The two implementations
/// convert independently, so these exist to keep them from drifting apart —
/// a divergence would show up as stock that disagrees with the server.
void main() {
  group('the worked example', () {
    test('selling half a kilo leaves 257.500', () {
      var stock = 258.000;
      stock -= uomToReference(0.500, kUomKilogram);
      expect(stock, closeTo(257.500, 1e-9));
    });

    test('selling a quarter kilo leaves 257.750', () {
      var stock = 258.000;
      stock -= uomToReference(0.250, kUomKilogram);
      expect(stock, closeTo(257.750, 1e-9));
    });

    test('selling 100 g deducts a tenth of a kilo, not a hundred', () {
      // The single most expensive mistake this layer can make.
      var stock = 258.000;
      stock -= uomToReference(100, kUomGram);
      expect(stock, closeTo(257.900, 1e-9));
    });
  });

  group('conversion', () {
    test('grams convert to kilograms', () {
      expect(uomToReference(100, kUomGram), closeTo(0.100, 1e-9));
      expect(uomToReference(250, kUomGram), closeTo(0.250, 1e-9));
      expect(uomToReference(1000, kUomGram), closeTo(1.000, 1e-9));
      expect(uomToReference(1, kUomGram), closeTo(0.001, 1e-9));
    });

    test('millilitres convert to litres', () {
      expect(uomToReference(500, kUomMillilitre), closeTo(0.500, 1e-9));
      expect(uomToReference(1500, kUomMillilitre), closeTo(1.500, 1e-9));
    });

    test('a reference unit converts to itself', () {
      expect(uomToReference(0.125, kUomKilogram), closeTo(0.125, 1e-9));
    });

    test('pieces convert one to one', () {
      expect(uomToReference(3, kUomPieces), closeTo(3, 1e-9));
    });

    test('conversion round-trips', () {
      expect(uomFromReference(uomToReference(250, kUomGram), kUomGram),
          closeTo(250, 1e-9));
    });

    test('a negative delta converts symmetrically', () {
      // Voids and removed order lines hand back negative deltas; an asymmetric
      // rounding rule here would leak stock a fraction at a time.
      expect(uomToReference(-100, kUomGram), closeTo(-0.100, 1e-9));
    });
  });

  group('rounding', () {
    test("a scale's floating noise is snapped away", () {
      // A serial scale reporting 0.4999999996 kg must not shave a fraction
      // off stock on every single sale. Snapped at the storage precision, so
      // the noise dies without the real quantity being touched.
      expect(uomToReference(0.4999999996, kUomKilogram), closeTo(0.500, 1e-9));
    });

    test('a real quantity is NOT quantised to the unit step', () {
      // The bug this replaces: snapping to the UNIT's rounding turned a
      // deliberate 0.5 on a pcs product into 1, on the line AND in the stock
      // deduction. Conversion snaps at the storage precision instead, so a
      // genuine fraction survives whatever unit it is expressed in.
      expect(uomToReference(0.5, kUomPieces), closeTo(0.5, 1e-9));
      expect(uomToReference(88.5, kUomPieces), closeTo(88.5, 1e-9));
      expect(uomToReference(0.1234, kUomKilogram), closeTo(0.1234, 1e-9));
    });

    test('selling half a unit deducts half a unit', () {
      var stock = 88.5;
      stock -= uomToReference(0.5, kUomPieces);
      expect(stock, closeTo(88.0, 1e-9));
    });
  });

  group('catalog integrity', () {
    test('an unknown unit id falls back to pieces rather than throwing', () {
      expect(uomById(9999).code, 'pcs');
      expect(uomById(null).code, 'pcs');
      expect(uomToReference(5, 9999), closeTo(5, 1e-9));
    });

    test('every category has exactly one reference unit', () {
      for (final entry in uomsByCategory().entries) {
        expect(entry.value.where((u) => u.isReference).length, 1,
            reason: '${entry.key} must have exactly one reference unit');
      }
    });

    test('unit ids are unique', () {
      final ids = kUnitsOfMeasure.map((u) => u.id).toSet();
      expect(ids.length, kUnitsOfMeasure.length);
    });

    test('conversion never crosses categories', () {
      expect(referenceUomOf(uomById(kUomGram)).code, 'kg');
      expect(referenceUomOf(uomById(kUomMillilitre)).code, 'L');
    });
  });

  group('display formatting', () {
    test('a weight keeps every decimal its unit carries', () {
      // Trailing zeros are the point on a weighed product: 88 kg of sugar reads
      // 88.000, so a scale figure never looks like a whole-unit count.
      expect(formatQuantity(1.5, kUomKilogram), '1.500 kg');
      expect(formatQuantity(0.25, kUomKilogram), '0.250 kg');
      expect(formatQuantity(2.0, kUomKilogram), '2.000 kg');
    });

    test('a digit the quantity actually holds is never hidden', () {
      // The regression this pins: formatting strictly at the unit's precision
      // printed a real 0.25 on a pcs line as "0" — in the cart, on the receipt,
      // and on the customer display. A quantity that renders as zero when it is
      // not zero is worse than an ugly one, and it survives onto paper.
      expect(formatQuantityValue(0.25, kUomPieces), '0.25');
      expect(formatQuantityValue(0.001, kUomPieces), '0.001');

      // A person typed this into the stock field. Rendering 88.5 as "89" reads
      // as the app having corrected their count — and the inline editor seeds
      // itself from this text, so the rounded figure would be written back on
      // the next save.
      expect(formatQuantityValue(88.5, kUomPieces), '88.5');

      // But a whole number on a whole-number unit still reads clean.
      expect(formatQuantityValue(88.0, kUomPieces), '88');

      // And a weighed unit still keeps its trailing zeros.
      expect(formatQuantityValue(88.0, kUomKilogram), '88.000');
      expect(formatQuantityValue(257.5, kUomKilogram), '257.500');
      expect(formatQuantityValue(0.125, kUomKilogram), '0.125');
    });

    test('a whole-number unit never shows a decimal point', () {
      expect(formatQuantity(3, kUomPieces), '3 pcs');
      expect(formatQuantity(250, kUomGram), '250 g');
    });
  });

  group('a stale unit id heals from the legacy text', () {
    // The exact shape of the bug: the server's read path dropped `uomId`, so
    // every product came back as the pieces DEFAULT while `measurementUnit`
    // still said 'kg'. The two then disagreed on screen — stock read
    // "88.25 pcs" on a product whose editor showed kg — and the cart printed
    // "0 kg" for a real 0.250. `Product.fromDrift` resolves it the same way
    // this does, so the reasoning is pinned here rather than in a widget test.
    int heal(int storedUomId, String? legacyText) => storedUomId == kUomPieces
        ? uomFromLegacyText(legacyText)
        : storedUomId;

    test('the legacy text wins when the id is the bare default', () {
      expect(heal(kUomPieces, 'kg'), kUomKilogram);
      expect(heal(kUomPieces, 'g'), kUomGram);
      expect(heal(kUomPieces, 'L'), kUomLitre);
    });

    test('a genuinely chosen unit id is never overridden', () {
      // A gram product must not be dragged to kg by a stale 'kg' string.
      expect(heal(kUomGram, 'kg'), kUomGram);
      expect(heal(kUomKilogram, 'pcs'), kUomKilogram);
    });

    test('a real pieces product stays pieces', () {
      expect(heal(kUomPieces, 'pcs'), kUomPieces);
      expect(heal(kUomPieces, null), kUomPieces);
      expect(heal(kUomPieces, 'widget'), kUomPieces);
    });

    test('the healed unit is what makes the figures agree again', () {
      final healed = heal(kUomPieces, 'kg');

      expect(formatQuantityValue(0.25, healed), '0.250');
      expect(uomById(healed).code, 'kg');
    });
  });

  group('legacy text mapping', () {
    test('known unit text maps onto the catalog', () {
      expect(uomFromLegacyText('kg'), kUomKilogram);
      expect(uomFromLegacyText('KG'), kUomKilogram);
      expect(uomFromLegacyText(' Kg '), kUomKilogram);
      expect(uomFromLegacyText('kilogram'), kUomKilogram);
      expect(uomFromLegacyText('g'), kUomGram);
      expect(uomFromLegacyText('grams'), kUomGram);
      expect(uomFromLegacyText('L'), kUomLitre);
      expect(uomFromLegacyText('litre'), kUomLitre);
      expect(uomFromLegacyText('ml'), kUomMillilitre);
      expect(uomFromLegacyText('pcs'), kUomPieces);
    });

    test('unrecognised text falls back to pieces', () {
      expect(uomFromLegacyText('widget'), kUomPieces);
      expect(uomFromLegacyText(''), kUomPieces);
      expect(uomFromLegacyText('   '), kUomPieces);
      expect(uomFromLegacyText(null), kUomPieces);
    });
  });
}
