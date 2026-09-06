// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
// 04_setup_stock — puts the catalogue on a shelf and gives it reorder rules.
//
// Reads the products `03_setup_catalog` recorded into
// `e2e/output/pos-credentials.json`, assigns each one an opening quantity in a
// warehouse, and sets its stock-control rules.
//
//   cd Front-End
//   flutter test integration_test/04_setup_stock_test.dart -d windows
//
// ── It depends on 03 ────────────────────────────────────────────────────────
//
// 🚨 Not on "whatever is in the catalogue" — on the exact products THIS chain
// created. A company accumulates products run after run, so picking them off the
// screen would mean stocking a stale row from a fortnight ago and reporting
// success. `loadE2ECatalog()` reads the newest run recorded against the company
// this terminal is LINKED to, and names the actual problem when there is none.
//
// ── Services are skipped, deliberately ──────────────────────────────────────
//
// A service has no stock: it is not a thing on a shelf, and `IsService` is
// exactly what the inventory logic checks before it deducts anything (see
// CLAUDE.md's inventory rules). Assigning it a quantity would be inventing data
// the app would never produce.
//
// ── The quantities are random, on purpose ───────────────────────────────────
//
// Seeded from the run tag so a failure is reproducible from the run that made
// it, but varied so the rules are not always in the same relationship to the
// stock on hand — a fixed 100/10/15 would never once produce a product that is
// already below its reorder point, which is the state the warnings exist for.
//
// ── It does NOT register a device ───────────────────────────────────────────
//
// Signs in to the terminal as it already is, so it never spends a licence seat.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e_context.dart';
import 'helpers/login_helper.dart';
import 'helpers/record_catalog_helper.dart';
import 'helpers/setup_stock_helper.dart';
import 'helpers/verify_persisted_helper.dart';
import 'support/e2e_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('setup_stock', (tester) async {
    final ctx = E2EContext();

    // Read the catalogue BEFORE booting the app: a missing one should fail in
    // two seconds naming the reason, not after a two-minute sign-in.
    //
    // 🚨 It resolves the LINKED company, not the newest in the file — the same
    // distinction `loadLinkedCompany()` exists for. Reading the newest would
    // hand this test a product list belonging to a shop this till has never
    // seen. `linkedCompanyId()` reads SharedPreferences, which is available
    // before `app.main()`, so this still runs before the boot.
    final catalogue = await loadE2ECatalog();
    final products = catalogue.stockable;
    expect(
      products,
      isNotEmpty,
      reason: 'The recorded catalogue (run ${catalogue.runTag}) holds nothing '
          'that takes stock — every product in it is a service.',
    );
    step('Catalogue from run ${catalogue.runTag}: '
        '${products.length} stockable of ${catalogue.products.length}');

    await loginToCompany(tester, ctx);

    // Seeded from the run tag so the same run always produces the same numbers.
    final random = Random(int.tryParse(kRunDigits) ?? 7);

    for (final product in products) {
      // Stock is held in the CATEGORY'S REFERENCE unit, so a `kg` product is
      // counted in kilograms and a `pcs` product in pieces. Weighed goods get a
      // fractional quantity because that is what a real shelf holds — and it is
      // the case a whole-number-only assumption would quietly break.
      final onHand = product.isToWeigh
          ? (5 + random.nextInt(45) + random.nextDouble()).toStringAsFixed(3)
          : '${20 + random.nextInt(180)}';

      // The reorder point sits BELOW what is on hand about half the time and
      // above it the rest, so this leaves a shop with some products already
      // flagged for reorder — which is the state the stock screen's warnings
      // exist to show, and which a fixed set of numbers would never reach.
      final reorder = (double.parse(onHand) * (0.2 + random.nextDouble()))
          .toStringAsFixed(product.isToWeigh ? 3 : 0);
      final preferred =
          (double.parse(onHand) * 1.5).toStringAsFixed(product.isToWeigh ? 3 : 0);
      final lowStockAt = (double.parse(reorder) * 1.2)
          .toStringAsFixed(product.isToWeigh ? 3 : 0);

      await assignStock(tester, ctx, product.name, quantity: onHand);
      await setStockRules(
        tester,
        ctx,
        product.name,
        reorderPoint: reorder,
        preferredQuantity: preferred,
        lowStockAt: lowStockAt,
      );
      step('${product.name}: $onHand ${product.uom ?? 'pcs'} on hand, '
          'reorder at $reorder, warn at $lowStockAt');
    }

    // ── Prove the server has it ───────────────────────────────────────────────
    //
    // Stock is written to Drift and pushed, exactly like the catalogue, so the
    // same rule applies: the UI saying "saved" is the app's word for it, and a
    // server-issued id is the server's.
    await exitManagement(tester, ctx.l);
    await syncNow(tester, ctx.l);
    await verifyPersisted(tester, ctx);

    step('setup_stock PASSED — ${products.length} products stocked and ruled');
  });
}
