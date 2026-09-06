/// `createProduct` — one product, through Management → Products.
///
/// The helper the smart-default rule exists for. A test that only cares whether
/// a product can be created writes one line and lets the UI supply the rest:
///
/// ```dart
/// await createProduct(tester, ctx);
/// ```
///
/// A test that cares about a RELATIONSHIP names it:
///
/// ```dart
/// await createTax(tester, ctx, name: 'Reduced 7%', ratePercent: '7');
/// await createProduct(tester, ctx, taxName: 'Reduced 7%');
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../config/test_config.dart';
import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// What the product IS, which decides two switches and nothing else.
enum ProductKind { normal, service, weighed }

/// Creates a product and records it on [ctx] as `productName`.
///
/// Assumes `loginToCompany` has already run; navigates to the section itself.
///
/// ## Resolving the group and the tax
///
/// Both follow the three-level rule from [E2EContext]: the explicit argument
/// wins, then whatever this run created, then the UI's first REAL option.
///
/// 🚨 "First real option" is not `items[0]`. Both of these dropdowns are built
/// as a null-valued placeholder followed by the rows — index 0 of Category is
/// **None (Uncategorized)** and index 0 of Primary Tax Rate is **No Tax**. A
/// naive index-0 default would therefore create an uncategorized, untaxed
/// product and report success, which is precisely the pair of bugs the README
/// records as "found by querying SQL Server, invisible in a green run".
/// [pickDropdownAt] filters on the item's VALUE — never on its text, which is
/// localised — so the placeholder can never be chosen by accident.
///
/// Pass [taxName] as the empty string to deliberately create an UNTAXED
/// product; that is a real scenario, and it has to be asked for explicitly.
Future<String> createProduct(
  WidgetTester tester,
  E2EContext ctx, {
  String? name,
  String? groupName,
  String? taxName,
  String? price,
  String? cost,
  ProductKind kind = ProductKind.normal,
  int swatch = 2,
  String? code,
  String? ageRestriction = '18',
  String? uom,
}) async {
  final productName = name ?? tagged('Product ${kind.name}');
  final sellingPrice = price ?? '18';
  final purchaseCost = cost ?? '6';
  final productCode = code ?? 'P$kRunDigits${kind.index}';

  // 🚨 A weighed product defaults to KILOGRAMS, and leaving it on `pcs` is not a
  // cosmetic difference. The unit decides what the till asks the cashier for and
  // what the stock screen counts: `showWeighItemDialog` reads `uomId` to label
  // its keypad, and stock is held in the CATEGORY'S REFERENCE unit — so a
  // product sold by weight but left in pieces is counted in pieces, and every
  // stock figure downstream is wrong in a way no screen flags.
  final unit = uom ?? (kind == ProductKind.weighed ? 'kg' : null);

  await ensureManagementSection(tester, ctx.l, ctx.l.products);
  step('Products opened');
  await clearSearch(tester);

  await tapVisible(tester, find.text(ctx.l.addProduct));
  await waitFor(tester, find.text(ctx.l.generalLabel));

  // ── General ────────────────────────────────────────────────────────────────
  //
  // 🚨 These are the PRODUCT form's labels. `nameRequired` and `codeRequired`
  // exist too and read almost the same on screen, but they belong to the TAX
  // dialog — using them here compiles perfectly and finds nothing at run time.
  await fillField(tester, ctx.l.productNameRequired, productName);

  final resolvedGroup = await _resolveGroup(tester, ctx, groupName);

  await fillField(tester, ctx.l.productCodeSku, productCode);
  await fillField(tester, ctx.l.plu, '${kind.index + 1}00');
  await fillField(tester, ctx.l.rankDisplayOrder, kDisplayRank);
  if (ageRestriction != null) {
    await fillField(tester, ctx.l.ageRestriction, ageRestriction);
  }
  await fillField(
      tester, ctx.l.description, 'Created by an E2E helper on $kRunTag');

  // 🚨 Service BEFORE weight. A service has no stock to weigh, so the UI
  // disables "sell by weight" while "is service" is on — setting weight first
  // and service second silently drops the weight flag.
  await setSwitch(
      tester, ctx.l.isServiceNotPhysical, kind == ProductKind.service);
  if (kind != ProductKind.service) {
    await setSwitch(tester, ctx.l.sellByWeight, kind == ProductKind.weighed);
  }

  // ── Pricing ────────────────────────────────────────────────────────────────
  await tapVisible(tester, find.text(ctx.l.pricingTab));
  await pumpFor(tester, const Duration(milliseconds: 800));

  // 🚨 The unit is set FIRST, before cost and price, and the order is not
  // arbitrary. Picking a weight or volume unit turns "sell by weight" ON by
  // itself (`_buildUomDropdown`'s onChanged), so doing it after the switches
  // would silently re-enable a flag a caller had just chosen to leave off.
  //
  // Matched on a SUBSTRING because a reference unit renders as "kg  ·  Stock
  // unit" — the note is part of the label, and an exact match on "kg" finds
  // nothing at all.
  if (unit != null) {
    await pickDropdown(tester, ctx.l.measurementUnit, unit,
        matchSubstring: true);
    step('Unit: $unit');
  }

  // 🚨 COST FIRST, PRICE SECOND. The order is load-bearing.
  //
  // `Products.CostPriceBasedMarkup` is seeded TRUE, which wires a listener that
  // recomputes the selling price from cost x markup the moment the cost field
  // changes. Filling price then cost throws the price away: a product entered at
  // 18 with a cost of 6 reached the database priced at 6, and nothing on screen
  // or in the run output said so. (Only the product whose cost was "0" kept its
  // price, because the recalc guards on `cost > 0` — which is why two of three
  // looked fine and it read like a fluke.)
  await fillField(tester, ctx.l.purchaseCost, purchaseCost);
  await fillField(tester, ctx.l.sellingPriceRequired, sellingPrice);

  // Read both back. This is the assertion that would have caught the above.
  expect(
    tester
        .widget<TextFormField>(
            find.widgetWithText(TextFormField, ctx.l.sellingPriceRequired).first)
        .controller
        ?.text,
    sellingPrice,
    reason: 'The selling price did not survive the cost-based markup recalc',
  );
  expect(
    tester
        .widget<TextFormField>(
            find.widgetWithText(TextFormField, ctx.l.purchaseCost).first)
        .controller
        ?.text,
    purchaseCost,
    reason: 'The purchase cost was not recorded',
  );

  final resolvedTax = await _resolveTax(tester, ctx, taxName);

  // ── Appearance ─────────────────────────────────────────────────────────────
  await tapVisible(tester, find.text(ctx.l.setAppearance));
  await pumpFor(tester, const Duration(milliseconds: 800));
  await pickSwatch(tester, swatch);

  // 🚨 Phase 1 does not say "Save" — it says "Next: Taxes & Stock", because
  // saving here is a step in a TWO-PHASE flow rather than the end of one.
  await tapVisible(
    tester,
    find.widgetWithText(ElevatedButton, ctx.l.nextTaxesAndStock),
  );
  await pumpFor(tester, const Duration(seconds: 4));

  // Phase 2 (Taxes / Barcodes / Modifiers) only opens for a product that already
  // reached the server. A fresh one is `pending_create` with no server id, so it
  // does not — a barcode would have nothing to attach to. `addBarcode` handles
  // that later, after a sync.
  if (find.text(ctx.l.finishSetup).evaluate().isNotEmpty) {
    await tapVisible(
      tester,
      find.widgetWithText(ElevatedButton, ctx.l.finishSetup),
    );
    await pumpFor(tester, const Duration(seconds: 3));
  }

  await searchList(tester, productName);
  await waitFor(
    tester,
    find.textContaining(productName),
    timeout: const Duration(seconds: 60),
    because: 'The saved product never appeared in the list.',
  );
  await clearSearch(tester);

  ctx.productName = productName;
  ctx.record(E2EArtifact(
    table: 'Product',
    name: productName,
    code: productCode,
    extra: {
      'Price': double.parse(sellingPrice),
      'Cost': double.parse(purchaseCost),
      'Group': resolvedGroup,
      'Tax': resolvedTax,
      'IsService': kind == ProductKind.service,
      'IsToWeigh': kind == ProductKind.weighed,
      if (unit != null) 'Uom': unit,
    },
  ));

  step('Product created: ${kind.name} — $productName @ $sellingPrice '
      '(group "$resolvedGroup", tax "${resolvedTax ?? 'none'}")');
  return productName;
}

/// Explicit argument → this run's group → the first real folder in the menu.
Future<String> _resolveGroup(
  WidgetTester tester,
  E2EContext ctx,
  String? requested,
) async {
  final named = requested ?? ctx.groupName;
  if (named != null) {
    await pickDropdown(tester, ctx.l.categoryGroup, named);
    final origin = requested != null ? 'named by the caller' : 'created by this run';
    step('Group: "$named" ($origin)');
    return named;
  }

  final chosen = await pickDropdownAt(tester, ctx.l.categoryGroup);
  step('Group: "$chosen" (first available — nothing was named)');
  return chosen;
}

/// Explicit argument → this run's tax → the first real rate in the menu.
///
/// The empty string means "deliberately untaxed" and picks the placeholder.
Future<String?> _resolveTax(
  WidgetTester tester,
  E2EContext ctx,
  String? requested,
) async {
  if (requested != null && requested.isEmpty) {
    await pickDropdown(tester, ctx.l.primaryTaxRate, ctx.l.noTax);
    step('Tax: none (asked for explicitly)');
    return null;
  }

  final named = requested ?? ctx.taxName;
  final String chosen;
  if (named != null) {
    // 🚨 Matched on a SUBSTRING. The option is rendered as "$name ($rate%)"
    // from a double, so a tax entered as "20" comes back as "(20.0%)" and an
    // exact match on the name alone finds nothing. The run tag inside the name
    // is what keeps the substring unique.
    await pickDropdown(tester, ctx.l.primaryTaxRate, named,
        matchSubstring: true);
    chosen = named;
    final origin = requested != null ? 'named by the caller' : 'created by this run';
    step('Tax: "$named" ($origin)');
  } else {
    chosen = await pickDropdownAt(tester, ctx.l.primaryTaxRate);
    step('Tax: "$chosen" (first available — nothing was named)');
  }

  // Confirm it actually took. The picker falls back to "No Tax" for a stale or
  // disabled id, so a silent failure here would ship an untaxed product that
  // nothing downstream would notice.
  expect(
    find.descendant(
      of: findDropdown(ctx.l.primaryTaxRate),
      matching: find.textContaining(chosen),
    ),
    findsWidgets,
    reason: 'The Primary Tax Rate did not stay set to "$chosen"',
  );
  return chosen;
}
