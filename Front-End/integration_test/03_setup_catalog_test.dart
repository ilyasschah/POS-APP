// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
// setup_catalog — signs in to an ALREADY-REGISTERED terminal and builds a
// catalogue through the real UI, against the real dev server and database.
//
// 🚨 The whole point is that it does NOT register a device.
//
// `login_new_company_test.dart` proves the first-install path, and to do that it
// has to wipe the terminal and register it again — which is the one thing that
// consumes a licence seat. This test deliberately skips all of that: it boots
// the app exactly as an operator finds it in the morning, signs in with the PIN
// and gets to work. Run it as often as you like; it costs nothing.
//
// It expects the terminal to already be linked to a company recorded in
// `e2e/output/pos-credentials.json`. Run `login_new_company` once first.
//
// ── The recipe ──────────────────────────────────────────────────────────────
//
// Every step below is a helper in `helpers/`, one file each. This file holds the
// DATA and the ORDER and nothing else — if you are looking for why a step does
// what it does, it is documented in that step's own file.
//
//   1 · loginToCompany        PIN sign-in, then wait for the locale to settle
//   2 · createProductGroup    a parent folder and a child of it
//   3 · createTax             20%, created BEFORE the products that carry it
//   4 · createProduct         a normal product, a service, a weighed item
//   5 · syncNow               a barcode needs a server id to attach to
//   6 · addBarcode            a generated EAN-13 each
//   7 · syncNow + verify      prove the SERVER has all of it, not just the app
//   8 · recordE2ECatalog      hand the catalogue to 04_setup_stock
//
// ── Running it ──────────────────────────────────────────────────────────────
//
//   cd Front-End
//   flutter test integration_test/setup_catalog_test.dart -d windows
//
// The app opens in a real window and every step is visible.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/add_barcode_helper.dart';
import 'helpers/create_group_helper.dart';
import 'helpers/create_product_helper.dart';
import 'helpers/create_tax_helper.dart';
import 'helpers/e2e_context.dart';
import 'helpers/login_helper.dart';
import 'helpers/record_catalog_helper.dart';
import 'helpers/verify_persisted_helper.dart';
import 'helpers/verify_product_helper.dart';
import 'support/e2e_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('setup_catalog', (tester) async {
    final ctx = E2EContext();

    // ── 1 · Sign in on the terminal as it already is ──────────────────────────
    //
    // No wipe, no re-registration, no new device id. The saved device token and
    // the subscription lease are exactly what the app should be starting from.
    //
    // The language is NOT pinned here. Every finder downstream reads `ctx.l`, so
    // the run follows whatever language the terminal is in — and `loginToCompany`
    // waits for that language to stop moving, because the company's setting
    // arrives with the post-sign-in sync. To pin it, run `set_language_test.dart`
    // once against this terminal.
    await loginToCompany(tester, ctx);

    // ── 2 · Product groups ────────────────────────────────────────────────────
    final parentGroup =
        await createProductGroup(tester, ctx, name: tagged('Beverages'));
    final childGroup = await createProductGroup(
      tester,
      ctx,
      name: tagged('Hot Drinks'),
      parent: parentGroup,
      swatch: 6,
    );

    // ── 3 · Tax rate ──────────────────────────────────────────────────────────
    //
    // Created before any product exists, because the products are saved with it
    // attached. A catalogue of untaxed products is not what this suite is meant
    // to leave behind for `make_sale` to sell.
    final tax = await createTax(tester, ctx);

    // ── 4 · Products ──────────────────────────────────────────────────────────
    //
    // Three kinds, because they take three different paths through the editor: a
    // service disables the weight switch, and a weighed item asks the cashier
    // for a quantity at the till.
    final espresso = await createProduct(
      tester,
      ctx,
      name: tagged('Espresso'),
      groupName: childGroup,
      taxName: tax,
      price: '18',
      cost: '6',
    );
    final tableService = await createProduct(
      tester,
      ctx,
      name: tagged('Table Service'),
      groupName: parentGroup,
      taxName: tax,
      price: '25',
      cost: '0',
      kind: ProductKind.service,
      swatch: 4,
    );
    final coffeeBeans = await createProduct(
      tester,
      ctx,
      name: tagged('Loose Coffee Beans'),
      groupName: parentGroup,
      taxName: tax,
      price: '140',
      cost: '95',
      kind: ProductKind.weighed,
      swatch: 8,
      // 🚨 Explicit even though `weighed` already defaults to it, because this
      // is the value the rest of the suite depends on. Stock is counted in the
      // category's REFERENCE unit, so a product sold by weight but left on
      // `pcs` is stocked in pieces — and 04_setup_stock would then be assigning
      // "120 pieces" of loose coffee to a shelf that holds kilograms, with
      // nothing on any screen flagging it.
      uom: 'kg',
    );

    // What each product should look like when it comes back off the server.
    final expected = <String, ({String group, String price})>{
      espresso: (group: childGroup, price: '18'),
      tableService: (group: parentGroup, price: '25'),
      coffeeBeans: (group: parentGroup, price: '140'),
    };

    // ── 5 · Sync, so the products have server ids ─────────────────────────────
    //
    // 🚨 A barcode cannot be added during creation. A newly saved product is
    // `pending_create` with no server id, so the editor's second phase (Taxes /
    // Barcodes / Modifiers) never opens — a barcode would have nothing to belong
    // to. The fix is the one an operator would use: sync, then edit.
    await exitManagement(tester, ctx.l);
    await syncNow(tester, ctx.l);

    // ── 6 · Barcodes ──────────────────────────────────────────────────────────
    for (final name in expected.keys) {
      await addBarcode(tester, ctx, name);
    }

    // ── 7 · Prove it all survived the round trip ──────────────────────────────
    //
    // 🚨 A barcode is written locally with `isPendingSync` and pushed in the
    // background, so the list showing it a second after Add proves only that the
    // app accepted it. Syncing again and reopening each product is what proves
    // the SERVER has it — and that the tax chosen during creation came back too.
    await exitManagement(tester, ctx.l);
    await syncNow(tester, ctx.l);

    // ── 8 · Hand it to the next test — BEFORE the verification pass ───────────
    //
    // Each numbered test is its own `flutter test` process against its own fresh
    // app boot, so nothing survives in memory. The catalogue goes into
    // `pos-credentials.json` under this company, exactly as the customer does,
    // and `04_setup_stock` reads it back from there.
    //
    // 🚨 Recorded HERE, not at the end, and the ordering is deliberate. By this
    // line the products are created, synced and carry server ids — the handoff
    // is already true. Everything below is verification, and a verification
    // failure on the third product would otherwise throw away a twenty-minute
    // run that had genuinely built a working catalogue, forcing the whole thing
    // to be repeated to give 04 something to read.
    //
    // Recording early means a partial failure still leaves 04 runnable, and the
    // failure itself is still red.
    await recordE2ECatalog(ctx);

    for (final entry in expected.entries) {
      await verifyProduct(
        tester,
        ctx,
        entry.key,
        groupName: entry.value.group,
        price: entry.value.price,
      );
    }

    // The database's own answer, on top of the UI's: every row created above now
    // carries a server-issued id, and the manifest carries the SQL that reads
    // their real columns back out of SQL Server.
    await verifyPersisted(tester, ctx);

    step('setup_catalog PASSED — 2 groups, 1 tax, '
        '3 taxed products (1 in kg), 3 barcodes verified after sync');
  });
}
