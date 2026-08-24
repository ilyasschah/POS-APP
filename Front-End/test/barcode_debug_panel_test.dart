// The barcode simulator has to survive the setup it exists to explain.
//
// It lists every product whose stored barcode decodes under the selected rule,
// in a dropdown keyed on the barcode string. The catalogue holds barcodes in
// TWO places — `Product.barcode`, exposed as `Product.barcodes`, and the
// separate `barcodes` table the product editor's Barcodes tab writes to — and
// adding a code through the editor can put the same string in both. Two
// DropdownMenuItems sharing a value is a hard assertion in Flutter, so the
// duplicate did not merely look untidy: it red-screened the whole panel. The
// person hitting it is by definition someone whose barcode setup is already
// confusing them, and the diagnostic tool died in their hands.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/barcode/barcode_debug_widget.dart';
import 'package:pos_app/barcode/barcode_provider.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rule.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rules_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/product/product_model.dart';
import 'package:pos_app/product/product_provider.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

class _FakeSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {...kSettingDefaults};
}

void main() {
  // The scale rule from the seeded nomenclature: prefix 25, five product
  // digits, then a five-digit weight with three decimals.
  const weightedRule = BarcodeRule(
    id: 1,
    name: 'Weighted',
    sequence: 10,
    type: BarcodeRuleType.weighted,
    encoding: BarcodeEncoding.ean13,
    pattern: '25.....{NNDDD}',
  );

  /// The exact code from the report: added to Sugar through the product
  /// editor, which left it in the product row AND in the barcodes table.
  const sharedBarcode = '2510001000001';

  /// A second base key, for product 10002. The check digit is real — the
  /// matcher recomputes it, so an invented one silently matches nothing.
  const otherBarcode = '2510002000000';

  Product product({
    int id = 1,
    String name = 'Sugar',
    List<String> barcodes = const [sharedBarcode],
    bool isEnabled = true,
  }) =>
      Product(
        id: id,
        companyId: 1,
        name: name,
        price: 12,
        isTaxInclusivePrice: true,
        isPriceChangeAllowed: false,
        isService: false,
        isUsingDefaultQuantity: true,
        isEnabled: isEnabled,
        cost: 0,
        color: 'Transparent',
        uomId: kUomKilogram,
        isToWeigh: true,
        barcodes: barcodes,
      );

  group('the candidate list', () {
    test('a barcode held in BOTH sources is listed once', () {
      // The crash's actual cause, stated as data: two entries, one value.
      final candidates = barcodeCandidatesFor(
        rule: weightedRule,
        products: [product()],
        extraBarcodes: const {
          1: [sharedBarcode]
        },
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.barcode, sharedBarcode);
    });

    test('one barcode claimed by two products is listed once', () {
      // The dropdown keys on the barcode alone, so a code duplicated ACROSS
      // products asserts just as hard as one duplicated within a product.
      final candidates = barcodeCandidatesFor(
        rule: weightedRule,
        products: [
          product(),
          product(id: 2, name: 'Saffron'),
        ],
        extraBarcodes: const {},
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.product.name, 'Sugar',
          reason: 'first writer wins, so the listing is stable across builds');
    });

    test('distinct barcodes are all kept', () {
      // De-duplication must not swallow real entries — showing which products
      // a rule matches is the panel's whole job.
      final candidates = barcodeCandidatesFor(
        rule: weightedRule,
        products: [product(barcodes: const [sharedBarcode])],
        extraBarcodes: const {
          1: [otherBarcode]
        },
      );

      expect(candidates.map((c) => c.barcode).toSet(),
          {sharedBarcode, otherBarcode});
    });

    test('a barcode the rule does not match is not a candidate', () {
      final candidates = barcodeCandidatesFor(
        rule: weightedRule,
        products: [product(barcodes: const ['2000001000006'])],
        extraBarcodes: const {},
      );

      expect(candidates, isEmpty);
    });

    test('a disabled product is not offered', () {
      final candidates = barcodeCandidatesFor(
        rule: weightedRule,
        products: [product(isEnabled: false)],
        extraBarcodes: const {},
      );

      expect(candidates, isEmpty);
    });

    test('no rule selected means nothing to build', () {
      expect(
        barcodeCandidatesFor(
          rule: null,
          products: [product()],
          extraBarcodes: const {},
        ),
        isEmpty,
      );
    });

    test('blank and padded codes are handled, not listed twice', () {
      final candidates = barcodeCandidatesFor(
        rule: weightedRule,
        products: [
          product(barcodes: const ['  $sharedBarcode  ', '', '   '])
        ],
        extraBarcodes: const {
          1: [sharedBarcode]
        },
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.barcode, sharedBarcode,
          reason: 'trimmed, so the padded copy is recognised as the same code');
    });
  });

  group('the panel itself', () {
    Future<void> pumpPanel(
      WidgetTester tester, {
      required List<Product> products,
      required Map<int, List<String>> extraBarcodes,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith(_FakeSettings.new),
            barcodeRulesProvider
                .overrideWith((ref) => Stream.value(const [weightedRule])),
            allProductsListProvider
                .overrideWith((ref) => Stream.value(products)),
            allBarcodesByProductIdProvider
                .overrideWith((ref) => Stream.value(extraBarcodes)),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: [Locale('en')],
            home: Scaffold(body: BarcodeDebugPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a duplicated barcode no longer red-screens it',
        (tester) async {
      // The reported failure, end to end: BarcodeDebugPanel threw
      // "There should be exactly one item with [DropdownButton]'s value:
      // 2510001000001" during build, so the dialog never rendered at all.
      await pumpPanel(
        tester,
        products: [product()],
        extraBarcodes: const {
          1: [sharedBarcode]
        },
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(BarcodeDebugPanel), findsOneWidget);
      expect(find.text('Barcode simulator'), findsOneWidget);
    });

    testWidgets('the product dropdown renders with a selection',
        (tester) async {
      await pumpPanel(
        tester,
        products: [product()],
        extraBarcodes: const {
          1: [sharedBarcode]
        },
      );

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.textContaining(sharedBarcode), findsWidgets);
    });

    testWidgets('a catalogue with no matching barcode says so instead',
        (tester) async {
      await pumpPanel(
        tester,
        products: [product(barcodes: const ['2000001000006'])],
        extraBarcodes: const {},
      );

      expect(tester.takeException(), isNull);
      expect(
          find.textContaining('No product carries a barcode'), findsOneWidget);
    });
  });
}
