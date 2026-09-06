/// `createVoidReason` — one entry in the list a cashier picks from when voiding.
///
/// ```dart
/// await createVoidReason(tester, ctx, name: 'Customer changed mind');
/// ```
///
/// ## Why the list has to exist before voiding can be tested
///
/// `Order.RequireReasonOnVoid` makes the reason mandatory, and the void dialog
/// offers exactly what this screen holds. A company with an empty list therefore
/// cannot void at all with that setting on — so R36/R37 are unreachable until
/// something puts rows here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/void_reason/void_reason_screen.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Creates a void reason and returns its name.
///
/// Returns without creating anything if one of that name already exists, so the
/// test is safe to re-run.
///
/// Assumes `loginToCompany` has already run; navigates to the section itself.
Future<String> createVoidReason(
  WidgetTester tester,
  E2EContext ctx, {
  required String name,
  String rank = '1',
}) async {
  await ensureManagementSection(tester, ctx.l, ctx.l.voidReasonsLower);
  await clearSearch(tester);

  final existing = ctx.container.read(voidReasonsProvider).value ?? const [];
  if (existing.any((r) => r.name == name)) {
    step('Void reason "$name" already exists');
    return name;
  }

  // 🚨 The FAB and the dialog's SAVE button carry the SAME label — `l.addReason`
  // is `fabLabel` on the list and the FilledButton's text in the editor. So
  // `find.text(addReason)` matches permanently and cannot be waited on in either
  // direction; the payment-type editor failed exactly this way. Told apart by
  // WIDGET, and the dialog itself is what gets waited on.
  await tapVisible(
    tester,
    find.widgetWithText(FloatingActionButton, ctx.l.addReason),
  );

  final dialog = find.byType(AlertDialog);
  await waitFor(
    tester,
    dialog,
    timeout: const Duration(seconds: 30),
    because: 'The void-reason editor never opened.',
  );

  await fillField(tester, ctx.l.nameRequired, name, within: dialog);
  await fillField(tester, ctx.l.rankDisplayOrderLower, rank, within: dialog);

  await tapVisible(
    tester,
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(FilledButton, ctx.l.addReason),
    ),
  );

  await waitForGone(
    tester,
    dialog,
    timeout: const Duration(seconds: 60),
    because: 'The void-reason editor stayed open — the save did not complete. '
        'An empty name is refused with "Name is required" and looks like this.',
  );

  // Read back from the provider the VOID DIALOG itself reads, not from the
  // table — a row the list shows but that provider filters out would be
  // useless to the cashier who has to pick from it.
  await waitUntil(
    tester,
    () async => (ctx.container.read(voidReasonsProvider).value ?? const [])
        .any((r) => r.name == name),
    describe: '"$name" reaches the void-reason list',
    timeout: const Duration(seconds: 60),
  );

  ctx.record(E2EArtifact(
    table: 'VoidReason',
    name: name,
    extra: {'Rank': int.tryParse(rank)},
  ));
  step('Void reason created: $name (rank $rank)');
  return name;
}
