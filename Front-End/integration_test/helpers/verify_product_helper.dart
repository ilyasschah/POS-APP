/// `verifyProduct` — reopens a product and proves what came BACK from the server.
///
/// ```dart
/// await syncNow(tester, ctx.l);
/// await verifyProduct(tester, ctx, productName,
///     groupName: child, taxName: tax, price: '18');
/// ```
///
/// 🚨 It has to run AFTER a second sync, and that is the whole point. Adding a
/// barcode writes it locally with `isPendingSync` set and pushes it in the
/// background — so the list showing it a second later proves only that the APP
/// accepted it, not that the SERVER did. A row still marked "Pending sync" here
/// never left the terminal, which is exactly the failure that would otherwise go
/// unnoticed until a scanner met an unknown code.
///
/// Separate from `verify_persisted_helper.dart` because it is a different
/// question. That one asks the DATABASE whether the row exists and carries a
/// server-issued id; this one drives the UI to ask what the row's CONTENTS came
/// back as. Both are needed: the first catches a row that never arrived, the
/// second catches one that arrived wrong.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Reopens [productName] and asserts the tax, group, price and barcode survived.
///
/// Each expectation falls back to what this run recorded on [ctx], so the common
/// case needs no arguments at all:
///
/// ```dart
/// await verifyProduct(tester, ctx, productName);
/// ```
///
/// Navigates to Products itself; leaves the editor closed.
Future<void> verifyProduct(
  WidgetTester tester,
  E2EContext ctx,
  String productName, {
  String? groupName,
  String? taxName,
  String? price,
  String? barcode,
}) async {
  final expectedGroup = groupName ?? ctx.groupName;
  final expectedTax = taxName ?? ctx.taxName;
  final expectedBarcode = barcode ?? ctx.barcodes[productName];

  await ensureManagementSection(tester, ctx.l, ctx.l.products);
  await openProductEditor(tester, ctx.l, productName);

  // ── Barcode: present, and no longer pending ────────────────────────────────
  if (expectedBarcode != null) {
    await tapVisible(tester, find.text(ctx.l.barcodesTab));
    await pumpFor(tester, const Duration(seconds: 1));

    await waitFor(
      tester,
      find.text(expectedBarcode),
      timeout: const Duration(seconds: 30),
      because: '"$productName" lost the barcode $expectedBarcode after syncing.',
    );

    // 🚨 Scoped to THIS barcode's own ListTile. An unscoped search for the
    // "Pending sync" label would match a different barcode's badge on the same
    // screen and fail — or, worse, miss this one's because another row happened
    // to be clean.
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, expectedBarcode),
        matching: find.text(ctx.l.pendingSync),
      ),
      findsNothing,
      reason: 'Barcode $expectedBarcode is still marked "${ctx.l.pendingSync}" '
          'after a sync — it was written locally but never reached the server.',
    );
  }

  // ── Tax: still attached ────────────────────────────────────────────────────
  if (expectedTax != null) {
    await tapVisible(tester, find.text(ctx.l.pricingTab));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(
      find.descendant(
        of: findDropdown(ctx.l.primaryTaxRate),
        matching: find.textContaining(expectedTax),
      ),
      findsWidgets,
      reason: '"$productName" came back with no tax rate attached.',
    );
  }

  // ── Group: as entered ──────────────────────────────────────────────────────
  //
  // 🚨 Scoped to the DROPDOWN, for the same reason the picker is. The products
  // table behind this dialog has a Category column showing these very names, so
  // an unscoped `find.textContaining(groupName)` matches a row belonging to some
  // OTHER product and passes while this one's dropdown never changed at all.
  // That is not hypothetical — it is the third of the three bugs in the README,
  // the verification that was itself wrong.
  if (expectedGroup != null) {
    await tapVisible(tester, find.text(ctx.l.generalLabel));
    await pumpFor(tester, const Duration(seconds: 1));
    await waitFor(
      tester,
      find.descendant(
        of: findDropdown(ctx.l.categoryGroup),
        matching: find.textContaining(expectedGroup),
      ),
      timeout: const Duration(seconds: 30),
      because: '"$productName" came back in the wrong group '
          '(expected "$expectedGroup").',
    );
  }

  // ── Price: as entered ──────────────────────────────────────────────────────
  if (price != null) {
    await tapVisible(tester, find.text(ctx.l.pricingTab));
    await pumpFor(tester, const Duration(seconds: 1));

    // 🚨 Compared as a NUMBER. A reloaded product fills the field from a double,
    // so a price typed as "18" comes back as "18.0" — equal in every way that
    // matters, and a string comparison would fail on the formatting alone.
    final shown = tester
        .widget<TextFormField>(
            find.widgetWithText(TextFormField, ctx.l.sellingPriceRequired).first)
        .controller
        ?.text;
    expect(
      double.tryParse(shown ?? ''),
      double.parse(price),
      reason: '"$productName" came back at the wrong selling price '
          '(field reads "$shown").',
    );
  }

  await tapVisible(
    tester,
    find.widgetWithText(TextButton, ctx.l.actionCancel),
  );
  await pumpFor(tester, const Duration(seconds: 2));

  step('Verified after sync: $productName — '
      'tax ${expectedTax == null ? 'n/a' : 'attached'}, '
      'group ${expectedGroup ?? 'n/a'}, '
      'barcode ${expectedBarcode ?? 'n/a'}');
}
