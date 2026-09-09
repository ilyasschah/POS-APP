/// `refundSale` — returns a receipt's items through the till's Refund dialog.
///
/// ```dart
/// await refundSale(tester, ctx, documentNumber: 'POS1-200-000004');
/// ```
///
/// ## Why this is the trigger audit's other half
///
/// `verifySaleChildRowsOnServer` covers one direction: a sale's lines and
/// payments reaching SQL Server, which an OUTPUT-clause refusal would break.
///
/// A refund covers the other. `ProcessRefundCommand` moves stock back with an
/// **explicit reversal block**, and the audit's conclusion — that this is the
/// ONLY thing moving stock on a refund — rests on `sys.triggers` holding no
/// trigger on `DocumentItem` or `Stock`.
///
/// 🚨 That conclusion is true today and nothing enforces it. Add a stock trigger
/// on `DocumentItem` — one hand-run `trg_*.sql` away on any live database — and
/// every refund returns stock TWICE: once from the trigger, once from the
/// explicit block. Neither errors. The shop simply grows inventory it never
/// bought, and the first sign is a stock count that will not reconcile.
///
/// So the assertion that matters is not "stock came back" but "stock came back
/// **exactly once**".
///
/// ## The receipt path, not the blind one
///
/// The dialog has two modes. This drives the RECEIPT one — look the document up
/// by number, pick quantities off its real lines. The BLIND mode (manual item
/// picking with no receipt) is gated behind a manager PIN and is a different
/// feature; it belongs in its own test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/cart/payment_type_provider.dart';
import 'package:pos_app/refund/refund_dialog.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Refunds every line of [documentNumber] and returns the payment type used.
///
/// [quantityPerLine] is how many units to return from each line, stepped up from
/// zero. `null` returns the whole line.
///
/// Assumes the till is signed in with the register open.
Future<String> refundSale(
  WidgetTester tester,
  E2EContext ctx, {
  required String documentNumber,
  int quantityPerLine = 1,
}) async {
  // ── Open the dialog ────────────────────────────────────────────────────────
  //
  // 🚨 `Icons.undo` on the till's own header bar, gated by `SecurityKeys.refund`
  // and by `ButtonBar.ShowRefund`. A company with either turned off shows no
  // button at all, which is why this says so rather than timing out on a finder.
  final refundButton = find.byIcon(Icons.undo);
  if (refundButton.evaluate().isEmpty) {
    throw TestFailure(
      'No Refund button on the till.\n'
      '  `ButtonBar.ShowRefund` is off for this company, or the current user is '
      'refused `SecurityKeys.refund`.\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }
  await tapVisible(tester, refundButton.first);

  await waitFor(
    tester,
    find.byType(RefundDialog),
    timeout: const Duration(seconds: 30),
    because: 'The Refund dialog never opened. A denied `SecurityKeys.refund` '
        'shows a toast and nothing else.',
  );
  ctx.refreshL10n(tester);

  final dialog = find.byType(RefundDialog);

  // ── Look the receipt up ────────────────────────────────────────────────────
  final search = find.descendant(of: dialog, matching: find.byType(TextField));
  if (search.evaluate().isEmpty) {
    throw TestFailure(
      'No receipt-lookup field in the Refund dialog.\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }
  await tester.enterText(search.first, documentNumber);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await pumpFor(tester, const Duration(seconds: 3));

  // 🚨 Two named refusals, and both are ordinary states rather than bugs — so
  // they are reported as themselves instead of as a missing widget later.
  if (find.text(ctx.l.receiptNotFound(documentNumber)).evaluate().isNotEmpty) {
    throw TestFailure(
      'The server does not know receipt "$documentNumber".\n'
      '  A sale that has not synced yet has a LOCAL number and no server row, '
      'so sync before refunding it.',
    );
  }

  // 🚨 Matched on the invariant HEAD, because the message embeds a reference
  // this caller does not know: "This receipt has already been refunded (Ref:
  // …)". Rendering the template with a sentinel and taking what precedes it
  // keeps the match correct in every language, without hardcoding English.
  if (find.textContaining(_headOf(ctx.l.receiptAlreadyRefunded)).evaluate()
      .isNotEmpty) {
    throw TestFailure(
      'Receipt "$documentNumber" has already been refunded. Ring up a fresh '
      'sale — a refund is not repeatable, which is the point of that guard.',
    );
  }

  // ── Step each line up to the quantity being returned ───────────────────────
  //
  // 🚨 The quantity is a STEPPER, not a field — `_QtyStepper` draws a `-`, a
  // `Text`, and a `+`, with no box to type into. It also starts at ZERO: a
  // refund with nothing stepped up is refused with "select at least one item",
  // so this is not an optional flourish.
  final plus = find.descendant(of: dialog, matching: find.byIcon(Icons.add));
  if (plus.evaluate().isEmpty) {
    throw TestFailure(
      'Receipt "$documentNumber" came back with no refundable lines.\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }

  final lines = plus.evaluate().length;
  for (var line = 0; line < lines; line++) {
    for (var i = 0; i < quantityPerLine; i++) {
      await tester.ensureVisible(plus.at(line));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(plus.at(line), warnIfMissed: false);
      await pumpFor(tester, const Duration(milliseconds: 250));
    }
  }
  step('Stepped $quantityPerLine unit(s) on each of $lines line(s)');

  // ── Pick what the money goes back on ───────────────────────────────────────
  //
  // Submitting without one is refused with "select a refund payment type", so
  // this is required rather than a default.
  final payType = (ctx.container.read(allPaymentTypesProvider).value ?? const [])
      .where((t) => t.isEnabled && t.markAsPaid && !t.isCustomerRequired)
      .firstOrNull;
  if (payType == null) {
    throw TestFailure(
      'No enabled payment type that can carry a refund. A credit type '
      '(`markAsPaid: false`) cannot give money back, and one requiring a '
      'customer is refused for the walk-in.',
    );
  }

  await tapVisible(
    tester,
    find.descendant(of: dialog, matching: find.text(payType.name)),
  );
  await pumpFor(tester, const Duration(milliseconds: 500));

  // ── Submit ─────────────────────────────────────────────────────────────────
  await tapVisible(
    tester,
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(FilledButton, ctx.l.actionOk),
    ),
  );

  await waitForGone(
    tester,
    dialog,
    timeout: const Duration(seconds: 120),
    because: 'The Refund dialog stayed open — the refund was not accepted.',
  );
  await pumpFor(tester, const Duration(seconds: 2));

  // 🚨 `refundQueued` is NOT success for a test that is about to read the
  // SERVER's stock. It means the refund was written locally and will sync later,
  // so the reversal has not run yet and every stock assertion would be early.
  if (find.text(ctx.l.refundQueued).evaluate().isNotEmpty) {
    step('Refund was QUEUED offline — the server has not processed it yet');
  }

  ctx.record(E2EArtifact(
    table: 'Refund',
    name: documentNumber,
    extra: {'PaymentType': payType.name, 'QtyPerLine': quantityPerLine},
  ));
  step('Refunded $documentNumber on "${payType.name}"');
  return payType.name;
}

/// The part of a one-placeholder message that comes BEFORE the placeholder.
///
/// Used to recognise a message whose embedded value this caller does not know.
/// Rendering the template with a sentinel and taking the head keeps the match
/// language-correct — hardcoding "This receipt has already been refunded" would
/// work in English and silently stop recognising the state in French.
String _headOf(String Function(String) template) {
  const sentinel = '<<X>>';
  final rendered = template(sentinel);
  final head = rendered.substring(0, rendered.indexOf(sentinel)).trim();

  // A template whose placeholder comes FIRST leaves nothing in front of it; fall
  // back to the tail rather than matching the empty string, which would match
  // every Text on screen.
  if (head.isNotEmpty) return head;
  return rendered.substring(rendered.indexOf(sentinel) + sentinel.length).trim();
}
