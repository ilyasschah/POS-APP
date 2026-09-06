/// `addBarcode` — gives a synced product a generated EAN-13.
///
/// ```dart
/// await syncNow(tester, ctx.l);          // the product needs a server id first
/// await addBarcode(tester, ctx, product);
/// ```
///
/// 🚨 This cannot be folded into `createProduct`, and the reason is structural
/// rather than stylistic. Creating a product is a TWO-PHASE dialog: phase 1
/// carries General, Pricing and Appearance, and phase 2 (Taxes / Barcodes /
/// Modifiers) opens only for a product that already reached the server. A newly
/// saved product is `pending_create` with no server id, so a barcode has nothing
/// to belong to — the app says "saved locally, sync first" and skips phase 2
/// entirely.
///
/// So the sequence is the one an operator would use: create, sync, then edit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Adds a generated EAN-13 to [productName] and returns the code it produced.
///
/// Records it on [ctx] under `barcodes[productName]`, so a later verification
/// pass can assert on the exact string rather than merely that a barcode exists.
///
/// Assumes the product exists and HAS SYNCED. Navigates to Products itself.
Future<String> addBarcode(
  WidgetTester tester,
  E2EContext ctx,
  String productName,
) async {
  await ensureManagementSection(tester, ctx.l, ctx.l.products);
  await openProductEditor(tester, ctx.l, productName);

  await tapVisible(tester, find.text(ctx.l.barcodesTab));
  await pumpFor(tester, const Duration(seconds: 1));

  // 🚨 "EAN-13" builds the code from the COMPANY'S OWN barcode nomenclature.
  // Anything hand-rolled — a timestamp, say — is 13 digits and so LOOKS like an
  // EAN-13 while passing its check digit only by luck, which means it never
  // scans on a real terminal and never matches a scale rule.
  await tapVisible(tester, find.text('EAN-13'));
  await pumpFor(tester, const Duration(milliseconds: 800));

  // Read back what the generator actually produced. Asserting on this exact
  // string later is the difference between "the Add button was clickable" and
  // "this code is on this product".
  final field = find.widgetWithText(TextField, ctx.l.barcode);
  final barcode = tester.widget<TextField>(field.first).controller?.text ?? '';
  expect(
    barcode,
    isNotEmpty,
    reason: 'The EAN-13 generator left the barcode field empty',
  );

  // 🚨 Tapped WITHOUT ensureVisible, unlike everything else in this suite.
  //
  // `ensureVisible` scrolls the nearest enclosing Scrollable, and inside this
  // dialog that is the TabBarView's own PageView. So asking to "make the Add
  // button visible" SCROLLS THE TABS — the dialog slides from Barcodes to
  // Modifiers, the tap lands on nothing, and the failure surfaces 30 seconds
  // later as "the barcode was not added" while the app sits on a tab the test
  // never asked for.
  //
  // The button is on screen already; it shares the barcode field's row. Scoping
  // to that row keeps the finder honest even though only one "Add" exists today.
  final addButton = find.descendant(
    of: find.ancestor(of: field, matching: find.byType(Row)).first,
    matching: find.widgetWithText(ElevatedButton, ctx.l.actionAdd),
  );
  expect(
    addButton,
    findsOneWidget,
    reason: 'No Add button beside the barcode field',
  );
  await tester.tap(addButton, warnIfMissed: false);
  await pumpFor(tester, const Duration(seconds: 3));

  // It has to be LISTED before the dialog is closed — that list is the only
  // place the app confirms the barcode was accepted at all.
  await waitFor(
    tester,
    find.text(barcode),
    timeout: const Duration(seconds: 30),
    because: 'The barcode was not added to the product\'s list.',
  );

  await tapVisible(
    tester,
    find.widgetWithText(ElevatedButton, ctx.l.actionSaveChanges),
  );
  await pumpFor(tester, const Duration(seconds: 3));

  ctx.barcodes[productName] = barcode;
  ctx.record(E2EArtifact(
    table: 'Barcode',
    name: barcode,
    extra: {'Product': productName},
  ));

  step('Barcode added: $productName -> $barcode');
  return barcode;
}
