// The pole display now shows each line as it is rung, not just the total at
// payment time. These pin the two things that decide whether a customer can
// read it: how the two halves of line 2 share 20 characters, and what happens
// to a name the wire cannot carry.
//
// The frames are captured through `debugCustomerDisplayFrames`, so what is
// asserted is exactly the text that would reach the port.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/utils/customer_display_service.dart';

void main() {
  final settings = <String, String>{
    SettingKeys.customerDisplayEnabled: 'true',
    SettingKeys.customerDisplayNumChars: '20',
    SettingKeys.customerDisplayPort: 'COM1',
  };

  setUp(debugCustomerDisplayFrames.clear);
  tearDown(() => debugCaptureCustomerDisplay = false);

  Future<DisplayFrame> ring({
    String name = 'Cafe au lait',
    double quantity = 2,
    double unitPrice = 12.5,
    double runningTotal = 25,
    String unit = '',
    Map<String, String>? overrides,
  }) async {
    debugCaptureCustomerDisplay = true;
    await CustomerDisplayService.showLineItem(
      settings: {...settings, ...?overrides},
      name: name,
      quantity: quantity,
      unitPrice: unitPrice,
      runningTotal: runningTotal,
      unitLabel: unit,
    );
    return debugCustomerDisplayFrames.last;
  }

  group('layout', () {
    test('product on line 1, what was rung and the running total on line 2',
        () async {
      final f = await ring();
      expect(f.line1, 'Cafe au lait        ');
      expect(f.line2, '2 x 12.50      25.00');
      expect(f.line1.length, 20);
      expect(f.line2.length, 20);
    });

    test('the total is right-aligned to the last column', () async {
      final f = await ring(runningTotal: 7);
      expect(f.line2.endsWith('7.00'), isTrue);
      expect(f.line2.trimRight(), f.line2, reason: 'no trailing pad after money');
    });

    test('a long name loses its tail rather than overflowing', () async {
      final f = await ring(name: 'Grand Cafe Creme Double Extra Large');
      expect(f.line1.length, 20);
      expect(f.line1, 'Grand Cafe Creme Dou');
    });

    test('🚨 when the halves collide the LEFT is trimmed, never the money',
        () async {
      // A half-printed total reads as a real price. This is the one thing on
      // the display that must never be shortened.
      final f = await ring(
        quantity: 12.5,
        unit: 'kg',
        unitPrice: 1234.56,
        runningTotal: 15432.0,
      );
      expect(f.line2.endsWith('15432.00'), isTrue);
      expect(f.line2.length, 20);
    });

    test('a total too wide for the display keeps its last digits', () async {
      final f = await ring(runningTotal: 123456789.99, overrides: {
        SettingKeys.customerDisplayNumChars: '8',
      });
      // Better to show the low digits than the high ones: an 8-character
      // display cannot be honest here, and the pennies are what is checked.
      expect(f.line2.length, 8);
      expect(f.line2.endsWith('789.99'), isTrue);
    });

    test('honours a display that is not 20 characters wide', () async {
      final f = await ring(overrides: {
        SettingKeys.customerDisplayNumChars: '16',
      });
      expect(f.line1.length, 16);
      expect(f.line2.length, 16);
      expect(f.line2.endsWith('25.00'), isTrue);
    });
  });

  group('quantity', () {
    test('a whole quantity has no decimal tail', () async {
      final f = await ring(quantity: 3);
      expect(f.line2.startsWith('3 x '), isTrue);
    });

    test('a weighed quantity prints as rung, with its unit', () async {
      // 24 chars: everything fits, so nothing is given up.
      final f = await ring(
        quantity: 0.125,
        unit: 'kg',
        unitPrice: 50,
        overrides: {SettingKeys.customerDisplayNumChars: '24'},
      );
      expect(f.line2, '0.125 kg x 50.00   25.00');
    });

    test('🚨 a clause is dropped whole, never cut in the middle of a number',
        () async {
      // `0.125 kg x 50.00` needs 16 of the 14 columns left over at 20 chars.
      // Truncating gave `0.125 kg x 50.` — which does not read as a shortened
      // line, it reads as a price of fifty-something. The `x price` clause goes
      // as a unit instead, leaving something true and complete.
      final f = await ring(quantity: 0.125, unit: 'kg', unitPrice: 50);
      expect(f.line2, '0.125 kg       25.00');
      expect(f.line2.contains('50.'), isFalse);
    });

    test('trailing zeros are dropped, so 0.500 kg is 0.5 kg', () async {
      final f = await ring(quantity: 0.5, unit: 'kg');
      expect(f.line2.startsWith('0.5 kg x '), isTrue);
    });
  });

  group('character set', () {
    test('accented Latin folds to its base letter', () async {
      // The wire carries one byte per character. A display shipped with a bare
      // ASCII codepage must still show a French menu legibly.
      final f = await ring(name: 'Café Crème à l\'Orange');
      expect(f.line1.trim(), startsWith('Cafe Creme a l'));
    });

    test('🚨 a name the wire cannot carry becomes ?, not random letters',
        () async {
      // codeUnits are UTF-16; anything over 0xFF was silently truncated to its
      // low byte, so Arabic rendered as unrelated Latin letters — garbage that
      // reads as a broken display rather than an unsupported name.
      final f = await ring(name: 'شاي');
      expect(f.line1.trim(), '???');
      for (final unit in f.line1.codeUnits) {
        expect(unit, lessThanOrEqualTo(0xFF));
      }
    });

    test('every byte of every frame fits in one byte', () async {
      final f = await ring(name: 'Thé 日本 Café');
      for (final unit in [...f.line1.codeUnits, ...f.line2.codeUnits]) {
        expect(unit, lessThanOrEqualTo(0xFF));
      }
    });
  });

  group('gates', () {
    test('a switched-off display is not written to at all', () async {
      debugCaptureCustomerDisplay = true;
      await CustomerDisplayService.showLineItem(
        settings: {...settings, SettingKeys.customerDisplayEnabled: 'false'},
        name: 'Coffee',
        quantity: 1,
        unitPrice: 10,
        runningTotal: 10,
      );
      expect(debugCustomerDisplayFrames, isEmpty);
    });
  });
}
