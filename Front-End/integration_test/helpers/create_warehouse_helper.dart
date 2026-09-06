/// `createWarehouse` — a second stock location, so sourcing has somewhere to split to.
///
/// ```dart
/// await createWarehouse(tester, ctx, name: 'Back Store');
/// ```
///
/// ## Why a SECOND warehouse matters
///
/// Warehouse allocation in this app happens at the **item level**, not the cart
/// level: one cart can take Product A from warehouse A and Product B from
/// warehouse B (the split-sourcing rule in `CLAUDE.md`). With one warehouse that
/// logic is real but untestable — every line resolves to the same place, so a
/// sourcing bug looks exactly like a working system.
///
/// The out-of-stock contract needs it too: a 400 carries `fallbackWarehouses`,
/// and a company with one warehouse can never produce a non-empty list.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/stock/warehouses_screen.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Creates a warehouse and returns its name.
///
/// Returns without creating anything if one of that name already exists, so the
/// test is safe to re-run against a company it has already configured.
///
/// Assumes `loginToCompany` has already run; navigates there itself.
Future<String> createWarehouse(
  WidgetTester tester,
  E2EContext ctx, {
  String? name,
}) async {
  final warehouseName = name ?? tagged('Back Store');

  await openWarehouses(tester, ctx);

  // Idempotent by NAME rather than by count. "There are already two warehouses"
  // would pass on a company carrying two from an unrelated run, and then the
  // sourcing test would be splitting between warehouses this run never made.
  final existing = ctx.container.read(allWarehousesProvider).value ?? const [];
  if (existing.any((w) => w.name == warehouseName)) {
    step('Warehouse "$warehouseName" already exists');
    await _leaveWarehouses(tester, ctx);
    return warehouseName;
  }

  // 🚨 Two different buttons open the SAME dialog, and which one exists depends
  // on whether the company has any warehouse yet: the app bar carries an add
  // icon, and an empty list additionally offers "Add first warehouse". A finder
  // pinned to either alone fails on exactly one of the two states — and the
  // empty state is the one a brand-new company is in.
  final addFirst = find.widgetWithText(ElevatedButton, ctx.l.addFirstWarehouse);
  if (addFirst.evaluate().isNotEmpty) {
    await tapVisible(tester, addFirst.first);
  } else {
    await tapVisible(tester, find.byTooltip(ctx.l.addWarehouse));
  }

  // 🚨 Waited on the DIALOG, not on its title text. `create_payment_type_helper`
  // documents why: a list screen whose add-button and dialog title share a
  // string makes a title-text wait match permanently, so "appeared" passes
  // instantly and "disappeared" never does. The titles here happen NOT to
  // collide today ("New Warehouse" vs "Add Warehouse") — this is written the
  // safe way so a future rename cannot quietly reintroduce it.
  final dialog = find.byType(AlertDialog);
  await waitFor(
    tester,
    dialog,
    timeout: const Duration(seconds: 30),
    because: 'The warehouse form never opened.',
  );
  await fillField(
      tester, ctx.l.warehouseNameRequired, warehouseName, within: dialog);

  await tapVisible(
    tester,
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(ElevatedButton, ctx.l.actionSave),
    ),
  );

  await waitForGone(
    tester,
    dialog,
    timeout: const Duration(seconds: 60),
    because: 'The warehouse dialog stayed open — the save did not complete. A '
        'duplicate warehouse name fails exactly like this.',
  );

  // The list is rebuilt from `allWarehousesProvider`, which the screen
  // invalidates after the dialog closes — so the row is genuinely late.
  await waitUntil(
    tester,
    () async => (ctx.container.read(allWarehousesProvider).value ?? const [])
        .any((w) => w.name == warehouseName),
    describe: '"$warehouseName" reaches the warehouse list',
    timeout: const Duration(seconds: 60),
  );

  ctx.record(E2EArtifact(table: 'Warehouse', name: warehouseName));
  step('Warehouse created: $warehouseName');

  await _leaveWarehouses(tester, ctx);
  return warehouseName;
}

/// Opens Management → Stock → Manage warehouses.
///
/// 🚨 The warehouses screen is a PUSHED route reached from the Stock screen's
/// overflow menu, not a Management rail destination — there is no tab for it.
/// It also sits behind `SecurityKeys.warehouses`, so a restricted user gets the
/// denial dialog rather than the screen.
Future<void> openWarehouses(WidgetTester tester, E2EContext ctx) async {
  if (find.byType(WarehousesScreen).evaluate().isNotEmpty) return;

  await ensureManagementSection(tester, ctx.l, ctx.l.stock);

  // 🚨 The ⋮ menu is found by its TOOLTIP, not by `Icons.more_vert`.
  // `IlyassActionsMenu` is a `PopupMenuButton<int>`, and `find.byType` on a
  // generic compares the exact type argument — the trap documented on
  // `anyDropdownField`. Its icon is also the widget's default rather than one
  // this code can see, so the tooltip is the only stable handle.
  await tapVisible(tester, find.byTooltip(ctx.l.actionsLabel).first);
  await pumpFor(tester, const Duration(milliseconds: 600));

  await tapVisible(tester, find.text(ctx.l.manageWarehouses));
  await waitFor(
    tester,
    find.byType(WarehousesScreen),
    timeout: const Duration(seconds: 30),
    because: 'Manage warehouses did not open. A security key on '
        'SecurityKeys.warehouses will also look like this.',
  );
  ctx.refreshL10n(tester);
}

/// Pops back to Stock, so the next helper starts from the Management rail.
Future<void> _leaveWarehouses(WidgetTester tester, E2EContext ctx) async {
  if (find.byType(WarehousesScreen).evaluate().isEmpty) return;
  await tester.pageBack();
  await waitForGone(
    tester,
    find.byType(WarehousesScreen),
    timeout: const Duration(seconds: 30),
  );
  await pumpFor(tester, const Duration(seconds: 1));
  ctx.refreshL10n(tester);
}
