import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/barcode/nomenclature/barcode_matcher.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rule.dart';

/// The decode half of sell-by-weight, mirroring
/// `Back-End/Web-POS.Api.Tests/BarcodeNomenclatureTests.cs`. The POS decodes
/// scale labels offline with its own copy of the matcher, so these exist to
/// prove the two ports still agree — a divergence means the till and the server
/// read the same label as different weights.
void main() {
  BarcodeRule rule(
    BarcodeRuleType type,
    BarcodeEncoding encoding,
    String pattern, {
    int sequence = 10,
    int id = 1,
  }) =>
      BarcodeRule(
        id: id,
        name: '$type rule',
        sequence: sequence,
        type: type,
        encoding: encoding,
        pattern: pattern,
      );

  group('weight decoding', () {
    test('a weighted barcode decodes the embedded weight at three decimals', () {
      // 22 + product 10001 + 00350 + check digit. {NNDDD} => 3 decimals.
      final barcode = withCheckDigit('221000100350');
      final match = matchBarcode(barcode, kDefaultBarcodeRules);

      expect(match, isNotNull);
      expect(match!.rule.type, BarcodeRuleType.weighted);
      expect(match.value, closeTo(0.350, 1e-9));
    });

    test('two weights of one product resolve to the same product key', () {
      // Otherwise every label on the shelf looks like a new product.
      final light = withCheckDigit('221000100350');
      final heavy = withCheckDigit('221000102750');

      final a = matchBarcode(light, kDefaultBarcodeRules);
      final b = matchBarcode(heavy, kDefaultBarcodeRules);

      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(a!.productKey, b!.productKey);
      expect(a.value, isNot(closeTo(b.value, 1e-9)));
    });

    test('a priced barcode decodes a total at two decimals', () {
      // 25 prefix, {NNNDD} => 5 digits, 2 decimals. 01250 => 12.50.
      final match =
          matchBarcode(withCheckDigit('251000101250'), kDefaultBarcodeRules);

      expect(match!.rule.type, BarcodeRuleType.priced);
      expect(match.value, closeTo(12.50, 1e-9));
    });
  });

  group('label building (the debug simulator)', () {
    // 🚨 These are the guarantee the simulator rests on: a barcode it hands
    // the till must decode back to the amount that was asked for. A generator
    // that drifts from the matcher produces labels the POS rejects, which is
    // indistinguishable from a broken scanner at the counter.
    test('a built weight label decodes back to that weight', () {
      final weightRule = kDefaultBarcodeRules
          .firstWhere((r) => r.type == BarcodeRuleType.weighted);
      final productKey = withCheckDigit('221000100000');

      final label = buildBarcodeForRule(weightRule, productKey, 1.250);

      expect(label, isNotNull);
      final match = matchBarcode(label, kDefaultBarcodeRules);
      expect(match!.rule.type, BarcodeRuleType.weighted);
      expect(match.value, closeTo(1.250, 1e-9));
      // And it still points at the same product as the zeroed key.
      expect(match.productKey, productKey);
    });

    test('a built price label decodes back to that total', () {
      final priceRule = kDefaultBarcodeRules
          .firstWhere((r) => r.type == BarcodeRuleType.priced);
      final productKey = withCheckDigit('251000100000');

      final label = buildBarcodeForRule(priceRule, productKey, 12.50);

      expect(label, isNotNull);
      final match = matchBarcode(label, kDefaultBarcodeRules);
      expect(match!.rule.type, BarcodeRuleType.priced);
      expect(match.value, closeTo(12.50, 1e-9));
      expect(match.productKey, productKey);
    });

    test('the check digit is recomputed, not copied from the key', () {
      // The failure this catches: reusing the key's digit over a body that has
      // changed, which makes every weight but one fail the EAN-13 gate.
      final weightRule = kDefaultBarcodeRules
          .firstWhere((r) => r.type == BarcodeRuleType.weighted);
      final productKey = withCheckDigit('221000100000');

      for (final weight in [0.350, 1.250, 2.750, 12.345]) {
        final label = buildBarcodeForRule(weightRule, productKey, weight)!;
        expect(hasValidCheckDigit(label), isTrue, reason: 'weight $weight');
      }
    });

    test('a value too big for the reserved digits is refused, not truncated', () {
      // {NNDDD} holds 99.999 at most. Silently wrapping to 0.001 would put a
      // wrong quantity in the cart with no error anywhere.
      final weightRule = kDefaultBarcodeRules
          .firstWhere((r) => r.type == BarcodeRuleType.weighted);
      final productKey = withCheckDigit('221000100000');

      expect(buildBarcodeForRule(weightRule, productKey, 100.0), isNull);
    });

    test('a unit rule embeds nothing, so nothing can be built from it', () {
      final unitRule = kDefaultBarcodeRules
          .firstWhere((r) => r.type == BarcodeRuleType.unit);

      expect(buildBarcodeForRule(unitRule, '2210001000005', 1.0), isNull);
    });
  });

  group('product keys (the editor generators)', () {
    test('a generated key decodes under its rule with no embedded value', () {
      for (final r in kDefaultBarcodeRules.where((r) =>
          r.type == BarcodeRuleType.weighted ||
          r.type == BarcodeRuleType.priced)) {
        final key = buildProductKeyForRule(r, 42);

        expect(key, isNotNull, reason: r.name);
        final match = tryMatchRule(key!, r);
        expect(match, isNotNull, reason: r.name);
        // Zero, or it is a label for one weight rather than a product key.
        expect(match!.value, 0, reason: r.name);
        expect(match.productKey, key, reason: r.name);
        expect(hasValidCheckDigit(key), isTrue, reason: r.name);
      }
    });

    test('every label built on a generated key resolves back to it', () {
      // The round trip the whole scale flow depends on: one product key, many
      // labels, all of them finding the same product.
      final weightRule = kDefaultBarcodeRules
          .firstWhere((r) => r.type == BarcodeRuleType.weighted);
      final key = buildProductKeyForRule(weightRule, 42)!;

      for (final weight in [0.005, 0.350, 1.250, 99.999]) {
        final label = buildBarcodeForRule(weightRule, key, weight)!;
        final match = matchBarcode(label, kDefaultBarcodeRules)!;

        expect(match.productKey, key, reason: 'weight $weight');
        expect(match.value, closeTo(weight, 1e-9));
      }
    });

    test('two products get two different keys', () {
      final rule = kDefaultBarcodeRules
          .firstWhere((r) => r.type == BarcodeRuleType.priced);

      expect(buildProductKeyForRule(rule, 1),
          isNot(buildProductKeyForRule(rule, 2)));
    });

    test('a plain in-store EAN-13 is valid and is NOT a scale label', () {
      // Prefix 20: never a manufacturer's code, never mistaken for 22/25.
      for (final id in [1, 42, 99999]) {
        final code = buildInternalEan13(id);

        expect(code.length, 13);
        expect(hasValidCheckDigit(code), isTrue);
        // The Unit rule may claim it; a weight or price rule must not.
        expect(matchBarcode(code, kDefaultBarcodeRules)!.rule.type,
            BarcodeRuleType.unit,
            reason: code);
      }
    });

    test('a rule with no wildcard positions cannot address a catalogue', () {
      const fixed = BarcodeRule(
          id: 9,
          name: 'one product only',
          sequence: 1,
          type: BarcodeRuleType.weighted,
          encoding: BarcodeEncoding.any,
          pattern: '22{NNDDD}');

      expect(buildProductKeyForRule(fixed, 42), isNull);
    });
  });

  group('rule ordering', () {
    test('the first matching rule wins even when a later rule also matches', () {
      final rules = [
        rule(BarcodeRuleType.weighted, BarcodeEncoding.ean13, '22.....{NNDDD}',
            sequence: 10, id: 1),
        rule(BarcodeRuleType.unit, BarcodeEncoding.any, '.*',
            sequence: 20, id: 2),
      ];

      final match = matchBarcode(withCheckDigit('221000100350'), rules);

      expect(match!.rule.type, BarcodeRuleType.weighted);
    });

    test('a catch-all placed first swallows the scale label', () {
      // Documents WHY the seeder pins the Unit rule last: reversed, a weighed
      // item silently rings up as a single unit at full price.
      final rules = [
        rule(BarcodeRuleType.unit, BarcodeEncoding.any, '.*',
            sequence: 10, id: 1),
        rule(BarcodeRuleType.weighted, BarcodeEncoding.ean13, '22.....{NNDDD}',
            sequence: 20, id: 2),
      ];

      final match = matchBarcode(withCheckDigit('221000100350'), rules);

      expect(match!.rule.type, BarcodeRuleType.unit);
      expect(match.value, 0);
    });

    test('disabled rules are skipped', () {
      final rules = [
        rule(BarcodeRuleType.weighted, BarcodeEncoding.ean13, '22.....{NNDDD}',
                sequence: 10, id: 1)
            .copyWith(isEnabled: false),
        rule(BarcodeRuleType.unit, BarcodeEncoding.any, '.*',
            sequence: 20, id: 2),
      ];

      final match = matchBarcode(withCheckDigit('221000100350'), rules);

      expect(match!.rule.type, BarcodeRuleType.unit);
    });
  });

  group('encoding gates', () {
    test('an EAN-13 rule rejects a bad check digit', () {
      final rules = [
        rule(BarcodeRuleType.weighted, BarcodeEncoding.ean13, '22.....{NNDDD}')
      ];

      final good = withCheckDigit('221000100350');
      final bad = good.substring(0, 12) + (good[12] == '0' ? '1' : '0');

      expect(matchBarcode(good, rules), isNotNull);
      expect(matchBarcode(bad, rules), isNull);
    });

    test('an EAN-13 rule rejects the wrong length', () {
      final rules = [
        rule(BarcodeRuleType.weighted, BarcodeEncoding.ean13, '22.....{NNDDD}')
      ];

      expect(matchBarcode('22100010035', rules), isNull);
    });

    test('Any encoding skips length and check-digit validation', () {
      final rules = [
        rule(BarcodeRuleType.weighted, BarcodeEncoding.any, '22.....{NNDDD}')
      ];

      final match = matchBarcode('221000100350', rules);

      expect(match, isNotNull);
      expect(match!.value, closeTo(0.350, 1e-9));
    });

    test('known good EAN-13 codes pass the check digit', () {
      expect(hasValidCheckDigit('4006381333931'), isTrue);
      expect(hasValidCheckDigit('5901234123457'), isTrue);
    });

    test('UPC-A uses the same check-digit rule as EAN-13', () {
      expect(hasValidCheckDigit('036000291452'), isTrue);
    });
  });

  group('non-matches', () {
    test('a barcode matching no rule returns null', () {
      final rules = [
        rule(BarcodeRuleType.weighted, BarcodeEncoding.any, '22.....{NNDDD}')
      ];

      expect(matchBarcode('9912345678901', rules), isNull);
    });

    test('an empty nomenclature returns null rather than throwing', () {
      expect(matchBarcode('221000100350', const []), isNull);
    });

    test('a malformed placeholder never matches', () {
      // "{NNXDD}" is not a legal placeholder — refusing beats decoding the X
      // as a digit position and billing the wrong weight.
      final rules = [
        rule(BarcodeRuleType.weighted, BarcodeEncoding.any, '22.....{NNXDD}')
      ];

      expect(matchBarcode('221000100350', rules), isNull);
    });

    test('a barcode too short for the pattern never matches', () {
      final rules = [
        rule(BarcodeRuleType.weighted, BarcodeEncoding.any, '22.....{NNDDD}')
      ];

      expect(matchBarcode('2210001', rules), isNull);
    });

    test('a null or blank barcode returns null', () {
      expect(matchBarcode(null, kDefaultBarcodeRules), isNull);
      expect(matchBarcode('   ', kDefaultBarcodeRules), isNull);
    });
  });

  group('cross-implementation parity', () {
    // These exact values are asserted in the C# suite too. If one side changes,
    // one of the two suites fails rather than both quietly agreeing on a bug.
    test('the shipped defaults decode the shipped example labels', () {
      final weighed =
          matchBarcode(withCheckDigit('221000100350'), kDefaultBarcodeRules)!;
      expect(weighed.value, closeTo(0.350, 1e-9));
      expect(weighed.productKey, withCheckDigit('221000100000'));

      final priced =
          matchBarcode(withCheckDigit('251000101250'), kDefaultBarcodeRules)!;
      expect(priced.value, closeTo(12.50, 1e-9));
    });

    test('a plain retail barcode falls through to the Unit rule', () {
      final match = matchBarcode('4006381333931', kDefaultBarcodeRules);

      expect(match!.rule.type, BarcodeRuleType.unit);
      expect(match.productKey, '4006381333931');
      expect(match.value, 0);
    });
  });
}
