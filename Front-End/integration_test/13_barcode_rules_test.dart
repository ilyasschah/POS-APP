// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
//
// 13_barcode_rules — the nomenclature that decides what a scan MEANS.
//
//   cd Front-End
//   flutter test integration_test/13_barcode_rules_test.dart -d windows
//
// ── Why this is not "just another list screen" ──────────────────────────────
//
// Every other setup test adds a row somebody later reads. This one changes how
// the till INTERPRETS thirteen digits. The same barcode rings up as one item, as
// 1.234 kg, or as a fixed amount — purely on which rule catches it first:
//
//   unit        no embedded value — a plain product barcode
//   weighted    the embedded value is a QUANTITY in the product's own unit
//   priced      the embedded value is a line TOTAL; qty = value ÷ unit price
//   discounted  the embedded value is a percentage off the line
//
// ── 🚨 The company already HAS a nomenclature ───────────────────────────────
//
// Every provisioned company is seeded with four rules, and they matter to this
// test because they own prefixes and they win on order:
//
//   seq 10  Price Barcodes 2 Decimals   priced      25.....{NNNDD}
//   seq 20  Weight Barcodes 3 Decimals  weighted    22.....{NNDDD}
//   seq 30  Discount Barcodes           discounted  22{NN}
//   seq 40  Product Barcodes            unit        .*
//
// Two consequences this test is built around, both verified against the live
// database rather than assumed:
//
//   * **22 is taken, and it means WEIGHT.** A new rule reusing that prefix is
//     appended after seq 20 and can never fire — the seeded rule catches the
//     code first. This test uses 21 and 23, which nothing owns.
//   * **Nothing ever fails to match.** `Product Barcodes` is `.*`, so an
//     ordinary EAN-13 is not "unmatched" — it is matched as a plain product.
//     Asserting a null match here would fail against a perfectly correct shop.
//
// ── It asserts through the app's OWN matcher ────────────────────────────────
//
// The editor ships a barcode tester: type a code, press play, and it reports
// which rule caught it. This test drives that rather than reimplementing the
// pattern language — a test that parsed `21.....{NNDDD}` itself would agree with
// itself forever and notice nothing when the real `matchBarcode` changed.
//
// ── It does NOT register a device ───────────────────────────────────────────
//
// Signs in to the terminal as it already is, so it never spends a licence seat.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:pos_app/barcode/nomenclature/barcode_rule.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rules_provider.dart';

import 'helpers/barcode_rule_helper.dart';
import 'helpers/e2e_context.dart';
import 'helpers/login_helper.dart';
import 'support/e2e_support.dart';

/// A scale label: prefix 21, a 5-digit product key, then the weight.
///
/// `{NNDDD}` is two whole units and three decimals, so `01234` reads as
/// 1.234 kg — which is why `03_setup_catalog` pins the weighed product to `kg`.
const String kWeightRuleName = 'E2E scale weight';
const String kWeightPattern = '21.....{NNDDD}';

/// A price-embedded label on prefix 23.
///
/// 🚨 NOT 22. That prefix is already the seeded WEIGHT rule at sequence 20, and
/// a rule appended below it would never fire.
const String kPriceRuleName = 'E2E scale price';
const String kPricePattern = '23.....{NNDDD}';

/// The seeded rules this test relies on being left alone.
const String kSeededWeightRule = 'Weight Barcodes 3 Decimals';
const String kSeededProductRule = 'Product Barcodes';

// 🚨 The rule names are NOT run-tagged. A rule name is read by whoever
// configures the shop, and the helper is idempotent by it — so a re-run reuses
// these instead of stacking near-identical rules that would then compete for
// every scan. Same reasoning as the stable usernames in `10`.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('barcode_rules', (tester) async {
    final ctx = E2EContext();

    await loginToCompany(tester, ctx);

    // ── 1 · A weight format and a price format, on free prefixes ──────────────
    await addBarcodeRule(
      tester,
      ctx,
      name: kWeightRuleName,
      type: BarcodeRuleType.weighted,
      encoding: BarcodeEncoding.ean13,
      pattern: kWeightPattern,
    );

    await addBarcodeRule(
      tester,
      ctx,
      name: kPriceRuleName,
      type: BarcodeRuleType.priced,
      encoding: BarcodeEncoding.ean13,
      pattern: kPricePattern,
    );

    // ── 2 · The app's own matcher agrees ──────────────────────────────────────
    //
    // 🚨 Codes that differ ONLY in their prefix. That is the assertion that
    // matters: a rule list catching both with the same rule would look identical
    // to a working one on a single test code, and every weighed sale in the shop
    // would then ring up as a price.
    expect(
      await testBarcodeMatch(tester, ctx, '2100001012345'),
      kWeightRuleName,
      reason: 'A 21-prefixed label must be read as a WEIGHT by the new rule.',
    );
    expect(
      await testBarcodeMatch(tester, ctx, '2300001012345'),
      kPriceRuleName,
      reason: 'A 23-prefixed label must be read as a PRICE. Matching the weight '
          'rule instead means the patterns overlap and the first one wins.',
    );

    // ── 3 · The seeded rules still own what they owned ────────────────────────
    //
    // 🚨 This is the assertion that catches a new rule written too loosely. A
    // pattern like `2......{NNDDD}` would happily swallow the shop's existing
    // 22 weight labels, and every one of them would start ringing up wrong —
    // silently, because the sale still completes.
    expect(
      await testBarcodeMatch(tester, ctx, '2200001012345'),
      kSeededWeightRule,
      reason: 'The shop\'s existing 22 weight format was hijacked by a rule '
          'this test added.',
    );

    // An ordinary EAN-13 falls through to the catch-all and is read as a plain
    // product. NOT null: `Product Barcodes` is `.*`, so nothing is ever
    // unmatched — asserting otherwise would fail against a correct shop.
    expect(
      await testBarcodeMatch(tester, ctx, '4001234567890'),
      kSeededProductRule,
      reason: 'An ordinary barcode must stay a plain product. Matching a scale '
          'rule here means one of them is too loose.',
    );

    // ── 4 · Both survived to the company's rule list ──────────────────────────
    //
    // Read from `barcodeRulesProvider`, which is what `_handleBarcodeSubmit`
    // reads at the till — a rule the editor shows but that provider filters out
    // would never affect a real scan.
    final rules = ctx.container.read(barcodeRulesProvider).value ?? const [];

    final weight = rules.firstWhere(
      (r) => r.name == kWeightRuleName,
      orElse: () => throw TestFailure('"$kWeightRuleName" is not in the list'),
    );
    final price = rules.firstWhere(
      (r) => r.name == kPriceRuleName,
      orElse: () => throw TestFailure('"$kPriceRuleName" is not in the list'),
    );

    // 🚨 The type dropdown is unlabelled and addressed by POSITION, which is
    // exactly the shape where a mis-picked option saves silently. Without this
    // check a weight rule saved as `unit` would pass every assertion above —
    // the tester reports which rule matched, not what it did with the digits.
    expect(
      weight.type,
      BarcodeRuleType.weighted,
      reason: '"$kWeightRuleName" saved as ${weight.type.name}, not weighted.',
    );
    expect(
      price.type,
      BarcodeRuleType.priced,
      reason: '"$kPriceRuleName" saved as ${price.type.name}, not priced.',
    );
    expect(weight.pattern, kWeightPattern);
    expect(price.pattern, kPricePattern);

    // The seeded set must still be there — this test appends, never replaces.
    expect(
      rules.map((r) => r.name),
      containsAll(<String>[kSeededWeightRule, kSeededProductRule]),
      reason: 'The seeded nomenclature was lost. Saving the editor rewrites the '
          'whole list, so a helper that dropped rows would show up here.',
    );

    step('barcode_rules PASSED — weight and price formats added alongside the '
        'seeded set, ${rules.length} rules on the company');
  });
}
