import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/utils/scale_barcode_parser.dart';

/// Builds a settings map for the scale parser, defaulting to the values from the
/// reference example (prefix "20", 5-digit code, 3 decimals, trim zeros on).
Map<String, String> settings({
  String enabled = 'true',
  String prefix = '20',
  String codeLength = '5',
  String decimals = '3',
  String trimZeros = 'true',
  String printsPrice = 'false',
}) =>
    {
      SettingKeys.scaleBarcodeEnabled: enabled,
      SettingKeys.scaleBarcodePrefix: prefix,
      SettingKeys.scaleBarcodeCodeLength: codeLength,
      SettingKeys.scaleBarcodeDecimalPlaces: decimals,
      SettingKeys.scaleBarcodeTrimZeros: trimZeros,
      SettingKeys.scaleBarcodePrintsPrice: printsPrice,
    };

void main() {
  group('parseScaleBarcode', () {
    test('decodes the reference example 2010001003502', () {
      // prefix 20 | code 10001 | value 00350 | control 2  → 0.350 kg
      final result = parseScaleBarcode('2010001003502', settings());
      expect(result, isNotNull);
      expect(result!.productCode, '10001');
      expect(result.parsedValue, closeTo(0.350, 1e-9));
      expect(result.isPrice, isFalse);
    });

    test('value width is derived, not fixed at 5 digits', () {
      // 6 value digits: prefix 20 | code 10001 | value 001234 | control 5.
      // Old (fixed-5) logic mis-sliced this; derived width yields 1.234.
      final result = parseScaleBarcode('20100010012345', settings());
      expect(result, isNotNull);
      expect(result!.productCode, '10001');
      expect(result.parsedValue, closeTo(1.234, 1e-9));
    });

    test('trims leading zeros from the product code when enabled', () {
      // code 00042 → "42"
      final result = parseScaleBarcode('2000042003505', settings());
      expect(result!.productCode, '42');
    });

    test('keeps leading zeros when trim is disabled', () {
      final result =
          parseScaleBarcode('2000042003505', settings(trimZeros: 'false'));
      expect(result!.productCode, '00042');
    });

    test('flags price mode when scale prints price', () {
      final result =
          parseScaleBarcode('2010001004200', settings(printsPrice: 'true'));
      expect(result!.isPrice, isTrue);
      expect(result.parsedValue, closeTo(0.420, 1e-9));
    });

    test('returns null when the prefix does not match', () {
      expect(parseScaleBarcode('2110001003502', settings(prefix: '20')), isNull);
    });

    test('returns null when scale barcode parsing is disabled', () {
      expect(
        parseScaleBarcode('2010001003502', settings(enabled: 'false')),
        isNull,
      );
    });

    test('returns null for a too-short body', () {
      expect(parseScaleBarcode('201', settings()), isNull);
    });
  });
}
