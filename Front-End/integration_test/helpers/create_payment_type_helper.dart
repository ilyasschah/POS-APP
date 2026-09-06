/// `createPaymentType` — the tender kinds a till can take money on.
///
/// ```dart
/// await createPaymentType(tester, ctx, name: 'Card', markAsPaid: true);
/// await createPaymentType(tester, ctx, name: 'Account',
///     markAsPaid: false, customerRequired: true);
/// ```
///
/// ## The two flags that change what a sale IS
///
/// | flag | off | on |
/// |---|---|---|
/// | `markAsPaid` | the sale banks **UNPAID** with an outstanding balance — a credit/tab | the money is taken now |
/// | `isCustomerRequired` | anyone, walk-in included | the checkout **refuses** `C000` by name |
///
/// 🚨 Neither is cosmetic, and getting them wrong makes a test assert the wrong
/// thing without failing. A credit type completes with nothing tendered, so a
/// payment assertion written for cash passes against a sale that took no money
/// at all. That is why `makeSale` deliberately picks
/// `markAsPaid && !isCustomerRequired` when the caller does not name a type.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/cart/payment_type_provider.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Creates one payment type and returns its name.
///
/// Returns without creating anything if one of that name already exists, so the
/// test is safe to re-run.
///
/// Assumes `loginToCompany` has already run; navigates to the section itself.
Future<String> createPaymentType(
  WidgetTester tester,
  E2EContext ctx, {
  required String name,
  String? code,
  bool markAsPaid = true,
  bool customerRequired = false,
  bool quickPay = false,
  bool opensCashDrawer = false,
}) async {
  await ensureManagementSection(tester, ctx.l, ctx.l.paymentTypesLower);
  step('Payment types opened');
  await clearSearch(tester);

  final existing = ctx.container.read(allPaymentTypesProvider).value ?? const [];
  if (existing.any((t) => t.name == name)) {
    step('Payment type "$name" already exists');
    return name;
  }

  // 🚨 Two buttons open the same editor and only one exists at a time: the
  // scaffold's FAB, and an "Add first payment type" button that an EMPTY list
  // shows instead. A finder pinned to either alone fails on one of the two
  // states — and a company always has at least one type, so the empty state is
  // rare enough to go unnoticed until it happens.
  final addFirst = find.widgetWithText(ElevatedButton, ctx.l.addFirstPaymentType);
  if (addFirst.evaluate().isNotEmpty) {
    await tapVisible(tester, addFirst.first);
  } else {
    await tapVisible(
      tester,
      find.widgetWithText(FloatingActionButton, ctx.l.newPaymentType),
    );
  }

  // 🚨 Waited on the DIALOG, never on its title text — and this is not
  // defensive style, it is the only thing that works here.
  //
  // The list screen's FAB carries `l.newPaymentType` as its LABEL, and the
  // editor uses the same string as its TITLE. So `find.text(newPaymentType)` is
  // matched permanently by the FAB, whether the dialog is open or not. That
  // breaks in both directions and only one of them is loud:
  //
  //   * waiting for it to APPEAR passes instantly — even if the editor never
  //     opened, which would then fail much later on a missing field;
  //   * waiting for it to GO can never succeed, so a save that worked perfectly
  //     times out after 60s with the new row plainly visible in the table
  //     behind. That is exactly how this helper failed its first real run.
  //
  // It is the same trap `create_modifier_group_helper` documents, where a FAB
  // and a save button share a label and are told apart by WIDGET.
  final dialog = find.byType(AlertDialog);
  await waitFor(
    tester,
    dialog,
    timeout: const Duration(seconds: 30),
    because: 'The payment-type editor never opened.',
  );

  // 🚨 Every control below is scoped to that dialog, per the standing rule in
  // this suite. The table behind carries column headers reading "Name", "Code",
  // "Enabled" and "Quick Pay" — close enough to the field labels that an
  // unscoped finder is one rename away from hitting a header instead.
  await fillField(tester, ctx.l.fieldNameRequired, name, within: dialog);
  await fillField(tester, ctx.l.fieldCode, code ?? _codeFor(name),
      within: dialog);

  // 🚨 These are bare `Switch`es beside a `Text`, NOT `SwitchListTile`s — the
  // editor builds them with its own `_switchRow`. `setSwitch` handles both
  // shapes; a finder that assumed the tile would report "no switch labelled X"
  // about a switch plainly on screen.
  await setSwitch(tester, ctx.l.markAsPaid, markAsPaid, within: dialog);
  await setSwitch(tester, ctx.l.customerRequiredLabel, customerRequired,
      within: dialog);
  await setSwitch(tester, ctx.l.quickPayment, quickPay, within: dialog);
  await setSwitch(tester, ctx.l.openCashDrawerLower, opensCashDrawer,
      within: dialog);

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
    because: 'The payment-type editor stayed open — the save did not complete. '
        'A duplicate name or code on this company fails exactly like this.',
  );

  // 🚨 Read the provider back rather than the table. `allPaymentTypesProvider`
  // is what the CHECKOUT reads, and a type the table shows but that provider
  // filters out is useless to every sale test downstream.
  await waitUntil(
    tester,
    () async => (ctx.container.read(allPaymentTypesProvider).value ?? const [])
        .any((t) => t.name == name),
    describe: '"$name" reaches the payment-type list',
    timeout: const Duration(seconds: 60),
  );

  final saved = (ctx.container.read(allPaymentTypesProvider).value ?? const [])
      .firstWhere((t) => t.name == name);
  expect(
    saved.markAsPaid,
    markAsPaid,
    reason: '"$name" did not keep markAsPaid=$markAsPaid — a credit type and a '
        'cash type are different features, and the sale tests branch on this.',
  );
  expect(saved.isCustomerRequired, customerRequired,
      reason: '"$name" did not keep isCustomerRequired=$customerRequired.');

  ctx.record(E2EArtifact(
    table: 'PaymentType',
    name: name,
    code: code ?? _codeFor(name),
    extra: {
      'MarkAsPaid': markAsPaid,
      'CustomerRequired': customerRequired,
    },
  ));
  step('Payment type created: $name '
      '(markAsPaid: $markAsPaid, customerRequired: $customerRequired)');
  return name;
}

/// A short code derived from the name, kept unique per run.
String _codeFor(String name) {
  final letters = name.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
  final stem = letters.length >= 3 ? letters.substring(0, 3) : letters;
  return '$stem$kRunDigits';
}
