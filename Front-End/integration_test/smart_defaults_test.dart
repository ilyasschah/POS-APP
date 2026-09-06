// smart_defaults — the "Index 0" rule, exercised against the real app.
//
// `setup_catalog` builds everything and names every relationship. This is the
// opposite case, and the one the modular rule exists for: a test that cares
// about ONE thing and lets the UI supply the rest.
//
//   await createProduct(tester, ctx);   // no group, no tax, no name
//
// 🚨 It needs a company that ALREADY has a group and a tax — run `setup_catalog`
// against this terminal once first. That is not a limitation, it is the point:
// the helper falls back to what the company already has, and when there is
// nothing to fall back to it fails saying so rather than quietly creating an
// uncategorized, untaxed product.
//
//   cd Front-End
//   flutter test integration_test/smart_defaults_test.dart -d windows
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/create_product_helper.dart';
import 'helpers/create_tax_helper.dart';
import 'helpers/e2e_context.dart';
import 'helpers/login_helper.dart';
import 'helpers/verify_persisted_helper.dart';
import 'helpers/verify_product_helper.dart';
import 'support/e2e_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ───────────────────────────────────────────────────────────────────────────
  // Level 3 of the resolution rule: nothing named, nothing built.
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('product only — everything resolved from the UI', (tester) async {
    final ctx = E2EContext();

    await loginToCompany(tester, ctx);

    // The helper takes the first REAL option out of each dropdown — skipping
    // "None (Uncategorized)" and "No Tax", which are what a literal index 0
    // would have selected and which would make this test pass while proving
    // nothing.
    final product = await createProduct(tester, ctx, name: tagged('Smart Default'));

    await exitManagement(tester, ctx.l);
    await syncNow(tester, ctx.l);

    // 🚨 The assertion that gives this test its teeth. `verifyProduct` reopens
    // the product and reads the group and tax back OUT OF THE DROPDOWNS — so a
    // fallback that had silently landed on the placeholder shows up here as
    // "came back with no tax rate attached", not as a green run.
    await verifyProduct(tester, ctx, product, price: '18');
    await verifyPersisted(tester, ctx);

    step('smart defaults PASSED — group and tax resolved from the catalogue');
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Level 2: one dependency built in-run, the other left to the UI.
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('mixed — a new tax, an existing group', (tester) async {
    final ctx = E2EContext();

    await loginToCompany(tester, ctx);

    // Creating the tax records it on the context, so the product picks it up
    // without being told — the chain the modular rule describes.
    final tax = await createTax(tester, ctx, ratePercent: '7');

    // No group is named and none was created, so that one still falls back to
    // the catalogue while the tax comes from this run.
    final product = await createProduct(
      tester,
      ctx,
      name: tagged('Mixed Default'),
      price: '42',
      cost: '11',
    );

    await exitManagement(tester, ctx.l);
    await syncNow(tester, ctx.l);

    await verifyProduct(tester, ctx, product, taxName: tax, price: '42');
    await verifyPersisted(tester, ctx);

    step('mixed defaults PASSED — tax from this run, group from the catalogue');
  });
}
