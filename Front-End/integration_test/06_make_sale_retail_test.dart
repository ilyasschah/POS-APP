// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
//
// 06_make_sale_retail — the money path for a COUNTER-SERVICE shop.
//
//   PIN → retail mode → open the register → SCAN → PAY
//     → verify in local SQLite → sync → verify on the SERVER
//
//   cd Front-End
//   flutter test integration_test/06_make_sale_retail_test.dart -d windows
//
// ── What "retail" means here ────────────────────────────────────────────────
//
// A shop with a counter and a scanner: no floor plan, no bookings, and no order
// to park and reopen. `configureRetailMode` sets that up; the table in
// `helpers/retail_mode_helper.dart` says which flags and why.
//
// 🚨 "No saving orders" is a property of this SCENARIO, not of the settings.
// The SAVE button on the till is gated only by `cartItems.isNotEmpty` — there is
// no feature flag and no `ButtonBar.ShowSave`, and a tableless order parks
// perfectly well as an open ticket. So this flow simply scans and pays and never
// touches SAVE; the app still offers it. If a shop must genuinely not have it,
// that is a missing setting rather than something a test can arrange.
//
// ── It sells by SCANNING ────────────────────────────────────────────────────
//
// 🚨 The barcode is submitted into the search field, which is exactly what a USB
// scanner does — type the digits, send Enter. That drives the app's real
// `_handleBarcodeSubmit`, nomenclature rules and all. Tapping the product card
// instead would prove the cart works while proving nothing about scanning, and
// scanning is the whole point of a retail till.
//
// The barcode comes from the catalogue `03_setup_catalog` recorded, so this test
// sells a product it can name rather than whatever happens to sort first.
//
// ── Nothing here is mocked ──────────────────────────────────────────────────
//
// It boots the shipping `main()`, lets every request go out, and then asks the
// server itself. When it passes, the Document is really in both databases with
// the same money on it.
//
// ── What it leaves behind ───────────────────────────────────────────────────
//
// One real sale on that company, and the company configured for retail. Both are
// the point on an E2E company, and both are reasons never to point this at a
// real till.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e_context.dart';
import 'helpers/login_helper.dart';
import 'helpers/make_sale_helper.dart';
import 'helpers/open_register_helper.dart';
import 'helpers/record_catalog_helper.dart';
import 'helpers/retail_mode_helper.dart';
import 'helpers/verify_sale_helper.dart';
import 'support/e2e_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('make_sale_retail', (tester) async {
    final ctx = E2EContext();

    // Pick the product to scan BEFORE booting: a catalogue with no barcode on it
    // should fail in two seconds naming the reason, not after a full sign-in.
    final catalogue = await loadE2ECatalog();
    final scannable =
        catalogue.products.where((p) => p.barcode != null).toList();
    expect(
      scannable,
      isNotEmpty,
      reason: 'No product in the recorded catalogue (run ${catalogue.runTag}) '
          'carries a barcode. 03_setup_catalog adds one to each after a sync — '
          'run it against this terminal first.',
    );
    final target = scannable.first;
    step('Will scan ${target.barcode} → ${target.name}');

    // ── 1 · Sign in ───────────────────────────────────────────────────────────
    await loginToCompany(tester, ctx);

    // ── 2 · Make this shop a retail shop ──────────────────────────────────────
    await configureRetailMode(tester, ctx);

    // ── 3 · A till that can actually trade ────────────────────────────────────
    //
    // A closed register renders SessionBlockedScreen instead of the grid — no
    // search field to scan into, which would surface here as "no search field on
    // the till" rather than as a session problem.
    await ensureRegisterOpen(tester, ctx);
    await ensureTablelessAllowed(tester, ctx);

    // ── 4 · Scan it and take the money ────────────────────────────────────────
    final sale = await makeSale(
      tester,
      ctx,
      productName: target.name,
      barcode: target.barcode,
    );

    // ── 5 · Saved LOCALLY ─────────────────────────────────────────────────────
    final doc = await verifySaleBanked(tester, ctx, sale);

    // ── 6 · Saved ONLINE ──────────────────────────────────────────────────────
    //
    // Checkout already kicked off a background push. Running the manual one is
    // idempotent and makes the wait bounded and visible.
    await syncNow(tester, ctx.l);
    await verifySaleOnServer(tester, ctx, sale, doc);

    step('make_sale_retail PASSED — scanned ${target.barcode}, '
        'sold ${sale.productName} for ${sale.total}');
  });
}
