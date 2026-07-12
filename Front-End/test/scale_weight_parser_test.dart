import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/scale/scale_weight_parser.dart';

void main() {
  group('parseScaleWeight', () {
    test('parses the CAS/Toledo continuous frame with a padded sign', () {
      final r = parseScaleWeight('ST,GS,+  1.234kg')!;
      expect(r.weight, 1.234);
      expect(r.unit, 'kg');
      expect(r.stable, isTrue);
    });

    test('US status marks the reading unstable', () {
      final r = parseScaleWeight('US,GS,+  1.234kg')!;
      expect(r.stable, isFalse);
    });

    test('honours a negative sign separated from the digits', () {
      final r = parseScaleWeight('US,NT,-  0.100 kg')!;
      expect(r.weight, -0.100);
      expect(r.stable, isFalse);
      expect(r.unit, 'kg');
    });

    test('a bare number is stable and unitless', () {
      final r = parseScaleWeight('1.234')!;
      expect(r.weight, 1.234);
      expect(r.unit, isNull);
      expect(r.stable, isTrue, reason: 'no status token means no instability');
    });

    test('parses a unit with no separating space', () {
      expect(parseScaleWeight('1.234kg')!.unit, 'kg');
      expect(parseScaleWeight('850g')!.unit, 'g');
      expect(parseScaleWeight('2.5LB')!.unit, 'lb');
      expect(parseScaleWeight('12 oz')!.unit, 'oz');
    });

    test('strips STX/ETX/CR/LF framing', () {
      final r = parseScaleWeight('\x02ST,GS,+  0.500kg\r\n\x03')!;
      expect(r.weight, 0.500);
      expect(r.unit, 'kg');
      expect(r.stable, isTrue);
    });

    test('leading whitespace-padded weight parses', () {
      final r = parseScaleWeight('     1.234 kg')!;
      expect(r.weight, 1.234);
    });

    test('zero is a valid reading, not a falsy miss', () {
      final r = parseScaleWeight('ST,GS,+  0.000kg')!;
      expect(r.weight, 0.0);
      expect(r.stable, isTrue);
    });

    test('does not convert units — grams stay grams', () {
      final r = parseScaleWeight('1234 g')!;
      expect(r.weight, 1234);
      expect(r.unit, 'g');
    });

    test('returns null for frames carrying no number', () {
      expect(parseScaleWeight(''), isNull);
      expect(parseScaleWeight('   '), isNull);
      expect(parseScaleWeight('\r\n'), isNull);
      expect(parseScaleWeight('ST,GS,'), isNull);
      expect(parseScaleWeight('----'), isNull);
    });

    test('the "st" inside a word is not read as a status token', () {
      // Must stay stable: only a standalone US token means unstable.
      expect(parseScaleWeight('fastest 1.5kg')!.stable, isTrue);
    });
  });
}
