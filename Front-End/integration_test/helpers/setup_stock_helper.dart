/// `assignStock` / `setStockRules` — putting a product on a shelf and telling
/// the till when to reorder it.
///
/// ```dart
/// await assignStock(tester, ctx, product, quantity: '120');
/// await setStockRules(tester, ctx, product,
///     reorderPoint: '20', preferredQuantity: '150', lowStockAt: '30');
/// ```
///
/// Two calls rather than one because they are two different dialogs behind two
/// different buttons, and they answer different questions: how much is there,
/// versus when to worry about it. A test can want either without the other.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Opens the Stock screen and the detail modal for [productName].
///
/// 🚨 The Stock list shows **ALL** products, not only those with a stock row —
/// a product with none reads "Unassigned" (see CLAUDE.md). So finding the row
/// proves nothing about whether stock exists; that is what the dialogs are for.
Future<void> openStockFor(
  WidgetTester tester,
  E2EContext ctx,
  String productName,
) async {
  await ensureManagementSection(tester, ctx.l, ctx.l.stock);
  await searchList(tester, productName);

  await waitFor(
    tester,
    find.textContaining(productName),
    timeout: const Duration(seconds: 60),
    because: 'The Stock list never showed "$productName". It lists every '
        'product, so a missing row means the product itself is missing — run '
        '03_setup_catalog against this terminal.',
  );
  await tapVisible(tester, find.textContaining(productName));

  // The details are a MODAL, not a side pane. Waiting for one of its own
  // buttons is what proves it opened, rather than a title that also appears in
  // the table behind it.
  await waitFor(
    tester,
    find.widgetWithText(OutlinedButton, ctx.l.assignToWarehouse),
    timeout: const Duration(seconds: 30),
    because: 'The stock detail modal never opened for "$productName".',
  );
}

/// Assigns [productName] to a warehouse with an opening [quantity].
///
/// [warehouseName] follows the smart-default rule: named, it uses that
/// warehouse; omitted, it takes the first the dropdown offers.
///
/// 🚨 The warehouse picker has NO placeholder row — unlike Category and Primary
/// Tax Rate, every entry is a real warehouse. `pickDropdownAt` is still the
/// right call: it filters on value and would skip a placeholder if one were ever
/// added, which is exactly the kind of change that otherwise breaks a test
/// silently months later.
///
/// 🚨 The quantity is in the CATEGORY'S REFERENCE UNIT, not the selling unit.
/// A product priced per gram still has its stock counted in kilograms — the
/// dialog says so in its suffix — so "500" on a gram-priced product means 500
/// KILOS. That is the Odoo model the app follows, and the reason
/// `03_setup_catalog` pins the weighed product to `kg`.
Future<String> assignStock(
  WidgetTester tester,
  E2EContext ctx,
  String productName, {
  String quantity = '100',
  String? warehouseName,
}) async {
  await openStockFor(tester, ctx, productName);

  await tapVisible(
    tester,
    find.widgetWithText(OutlinedButton, ctx.l.assignToWarehouse),
  );
  await waitFor(
    tester,
    find.byType(AlertDialog),
    timeout: const Duration(seconds: 30),
    because: 'The "Assign to warehouse" dialog never opened.',
  );

  final dialog = find.byType(AlertDialog);

  // The warehouse list is a provider that loads on open — while it is loading
  // the dialog shows a spinner where the dropdown goes, so the field is
  // genuinely absent for the first moment of every open.
  await waitFor(
    tester,
    find.descendant(of: dialog, matching: anyDropdownField),
    timeout: const Duration(seconds: 30),
    because: 'The warehouse dropdown never finished loading. A company with no '
        'warehouse at all will also look like this.',
  );

  final String warehouse;
  if (warehouseName != null) {
    await pickDropdown(tester, ctx.l.warehouse, warehouseName, within: dialog);
    warehouse = warehouseName;
  } else {
    warehouse = await pickDropdownAt(tester, ctx.l.warehouse, within: dialog);
    step('Warehouse: "$warehouse" (first available)');
  }

  await fillField(tester, ctx.l.initialQuantity, quantity, within: dialog);

  await tapVisible(
    tester,
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(ElevatedButton, ctx.l.actionSave),
    ),
  );

  // 🚨 Wait for the DIALOG to go, not for a snackbar. The save writes to Drift
  // and kicks off a sync in the background, so a snackbar is not guaranteed and
  // racing its dismissal is how this step goes flaky.
  await waitForGone(
    tester,
    dialog,
    timeout: const Duration(seconds: 60),
    because: 'The assign dialog stayed open — the save did not complete.',
  );
  await pumpFor(tester, const Duration(seconds: 2));

  ctx.record(E2EArtifact(
    table: 'Stock',
    name: productName,
    extra: {'Warehouse': warehouse, 'Quantity': double.tryParse(quantity)},
  ));
  step('Stock assigned: $productName -> $quantity in "$warehouse"');

  await _closeDetailModal(tester, ctx);
  return warehouse;
}

/// Sets the reorder rules on [productName].
///
/// All three are optional and default to a sensible set. The low-stock switch is
/// flipped BEFORE its threshold is typed, because the threshold field only
/// exists while the switch is on — `if (_lowStockEnabled) ...[` in the dialog —
/// so filling it first would look for a field that is not in the tree.
Future<void> setStockRules(
  WidgetTester tester,
  E2EContext ctx,
  String productName, {
  String reorderPoint = '10',
  String preferredQuantity = '100',
  String? lowStockAt = '15',
}) async {
  await openStockFor(tester, ctx, productName);

  await tapVisible(tester, find.widgetWithText(OutlinedButton, ctx.l.editRules));
  await waitFor(
    tester,
    find.byType(AlertDialog),
    timeout: const Duration(seconds: 30),
    because: 'The stock-rules dialog never opened.',
  );

  final dialog = find.byType(AlertDialog);

  await fillField(tester, ctx.l.reorderPoint, reorderPoint, within: dialog);
  await fillField(
      tester, ctx.l.preferredQuantity, preferredQuantity, within: dialog);

  // Switch first, threshold second — the field is conditional on the switch.
  await setSwitch(tester, ctx.l.lowStockWarning, lowStockAt != null);
  if (lowStockAt != null) {
    await pumpFor(tester, const Duration(milliseconds: 500));
    await fillField(tester, ctx.l.warningThreshold, lowStockAt, within: dialog);
  }

  // 🚨 The save button is labelled "Create" for a product with no rule yet and
  // "Update" for one that already has one — `control != null ? actionUpdate :
  // actionCreate`. A finder pinned to either fails on the other, and which one
  // it is depends on whether this test has run before. Both are accepted.
  final save = find.descendant(
    of: dialog,
    matching: find.byWidgetPredicate(
      (w) =>
          w is ElevatedButton &&
          w.child is Text &&
          ((w.child as Text).data == ctx.l.actionCreate ||
              (w.child as Text).data == ctx.l.actionUpdate),
    ),
  );
  expect(
    save,
    findsOneWidget,
    reason: 'No Create/Update button on the stock-rules dialog.',
  );
  await tapVisible(tester, save);

  await waitForGone(
    tester,
    dialog,
    timeout: const Duration(seconds: 60),
    because: 'The stock-rules dialog stayed open — the save did not complete.',
  );
  await pumpFor(tester, const Duration(seconds: 2));

  ctx.record(E2EArtifact(
    table: 'StockControl',
    name: productName,
    extra: {
      'ReorderPoint': double.tryParse(reorderPoint),
      'PreferredQuantity': double.tryParse(preferredQuantity),
      'LowStockAt': lowStockAt == null ? null : double.tryParse(lowStockAt),
    },
  ));
  step('Stock rules: $productName — reorder at $reorderPoint, '
      'prefer $preferredQuantity, warn at ${lowStockAt ?? 'off'}');

  await _closeDetailModal(tester, ctx);
}

/// Closes the stock detail modal if it is still open.
///
/// The assign dialog pops back to it rather than to the table, so leaving it up
/// would put the next helper's finders behind a modal barrier.
Future<void> _closeDetailModal(WidgetTester tester, E2EContext ctx) async {
  final panel = find.widgetWithText(OutlinedButton, ctx.l.assignToWarehouse);
  if (panel.evaluate().isEmpty) return;

  final close = find.byTooltip(ctx.l.actionClose);
  if (close.evaluate().isNotEmpty) {
    await tapVisible(tester, close.first);
  } else {
    // No close button on this layout — dismiss through the barrier instead.
    await tester.tapAt(const Offset(20, 20));
  }
  await waitForGone(tester, panel, timeout: const Duration(seconds: 30));
  await pumpFor(tester, const Duration(seconds: 1));
}
