/// `createModifierGroup` — one modifier group and its options.
///
/// ```dart
/// await createModifierGroup(tester, ctx,
///   name: 'Extras', min: 0, max: 3, freeText: true,
///   options: [E2EModifierOption('Extra shot', '3.00')]);
/// ```
///
/// The min/max pair is not decoration — it is the ONLY thing deciding the
/// control the cashier is handed, so the two shapes are genuinely different
/// features:
///
/// | | rule | control | behaviour |
/// |---|---|---|---|
/// | optional-many | min 0 / max 3 | checkboxes | take none, take three |
/// | required-one  | min 1 / max 1 | radios     | the sale is BLOCKED until one is chosen |
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/modifier/modifier_models.dart';
import 'package:pos_app/modifier/modifier_provider.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// One choice inside a modifier group, as a test describes it.
///
/// 🚨 Named `E2EModifierOption`, not `ModifierOption`, and that is not fussiness.
/// The app ships its own `ModifierOption` in `modifier_models.dart` — the one a
/// verification reads back off a saved group. A test importing both would get
/// THIS class shadowing that one, and `option.price` would fail to compile
/// against a model whose field is actually `additionalPrice`.
class E2EModifierOption {
  const E2EModifierOption(this.name, this.price);

  final String name;

  /// A NEGATIVE surcharge is legitimate — a smaller cup costs less — and is the
  /// reason the price field lets a minus sign through at all.
  final String price;
}

/// Creates a modifier group and records it on [ctx].
///
/// Assumes `loginToCompany` has already run; navigates to the section itself.
///
/// 🚨 A new group's local id is NEGATIVE. `modifier_groups.id` is "positive =
/// server id, negative = temp local id", and the push swaps it — so asserting
/// `id > 0` before a sync would only be asserting that the sync had already
/// happened. Verify content locally, sync, and only then require a real id.
///
/// 🚨 The push RE-KEYS the row. `remapModifierGroupId` deletes the negative row
/// and writes a new one under the server's id, so after a sync the group has to
/// be found BY NAME again — a test holding the old id is looking for a row that
/// no longer exists.
Future<String> createModifierGroup(
  WidgetTester tester,
  E2EContext ctx, {
  required String name,
  required int min,
  required int max,
  required List<E2EModifierOption> options,
  bool freeText = false,
  String? ruleLabel,
}) async {
  await ensureManagementSection(tester, ctx.l, ctx.l.modifierGroups);
  step('Modifier Groups opened');

  // 🚨 The editor is a PUSHED PAGE, not a dialog — a group and its options go to
  // `/Modifiers/SaveGroup` in one transaction, so the form is too long to hide
  // in a dialog. That matters to the finders: the list screen behind stays in
  // the tree, and its FAB carries the SAME label as the save button ("Add
  // Modifier Group"). They are told apart by WIDGET — `FloatingActionButton`
  // versus `FilledButton` — never by text.
  await tapVisible(
    tester,
    find.widgetWithText(FloatingActionButton, ctx.l.addModifierGroup),
  );
  await waitFor(
    tester,
    find.widgetWithText(TextField, ctx.l.nameRequired),
    timeout: const Duration(seconds: 30),
    because: 'The group editor never opened.',
  );

  await fillField(tester, ctx.l.nameRequired, name);

  // ── Selection rule ─────────────────────────────────────────────────────────
  //
  // 🚨 Stepped, not typed. `_NumberField` renders a `-`/`+` pair around a plain
  // `Text` — despite its own doc comment promising typed entry — so there is no
  // field to `enterText` into. The steppers also CLAMP each other (raising Min
  // above Max drags Max up), which is why Min is set before Max: doing it the
  // other way round pushes Max somewhere neither value asked for.
  //
  // A new group opens on the editor's defaults — min 0, max 1.
  await _step(tester, ctx.l.minSelections, from: 0, to: min);
  await _step(tester, ctx.l.maxSelections, from: 1, to: max);

  // The rule is what the operator actually reads — "Required · pick one" rather
  // than "min 1 max 1" — so assert the sentence, not just the numbers.
  if (ruleLabel != null) {
    expect(
      find.text(ruleLabel),
      findsWidgets,
      reason: 'The editor does not describe this group as "$ruleLabel".\n'
          '  On screen now: ${visibleTexts(tester)}',
    );
  }

  await setSwitch(tester, ctx.l.allowFreeText, freeText);

  // ── Options ────────────────────────────────────────────────────────────────
  for (var i = 0; i < options.length; i++) {
    // The editor opens with one empty row already; every one after it is added.
    if (i > 0) {
      await tapVisible(tester, find.text(ctx.l.addModifierOption));
      await pumpFor(tester, const Duration(milliseconds: 400));
    }
    await _fillOption(tester, ctx, options[i], row: i);
  }

  await tapVisible(
    tester,
    find.widgetWithText(FilledButton, ctx.l.addModifierGroup),
  );

  // Saving pops the editor route, so the save button going away IS the save
  // landing. Waiting on a snackbar instead would race its own dismissal.
  await waitForGone(
    tester,
    find.widgetWithText(FilledButton, ctx.l.addModifierGroup),
    timeout: const Duration(seconds: 60),
    because: 'The modifier group editor never closed — the save did not land.',
  );
  await pumpFor(tester, const Duration(seconds: 2));

  ctx.record(E2EArtifact(
    table: 'ModifierGroup',
    name: name,
    extra: {
      'Min': min,
      'Max': max,
      'FreeText': freeText,
      'Options': options.length,
    },
  ));
  step('Modifier group created: $name (min $min / max $max, '
      '${options.length} options)');
  return name;
}

/// Waits for the group named [name] to reach the local database, and returns it.
Future<ModifierGroup> awaitModifierGroup(
  WidgetTester tester,
  E2EContext ctx,
  String name,
) async {
  late ModifierGroup found;
  await waitUntil(
    tester,
    () async {
      final all = ctx.container.read(allModifierGroupsProvider).value ?? const [];
      final match = all.where((g) => g.name == name).firstOrNull;
      if (match == null) return false;
      found = match;
      return true;
    },
    describe: '"$name" reaches the local database',
    timeout: const Duration(seconds: 60),
  );
  return found;
}

/// Types one option's name and price into option row [row], counting from 0.
///
/// 🚨 Addressed by POSITION, and the alternative is a trap worth spelling out.
/// The option rows are identical widgets with identical hints, so the obvious
/// idea is to target "the row still showing its hint", on the reasoning that a
/// filled field stops advertising one.
///
/// It does not. Flutter's `InputDecorator` keeps the hint `Text` MOUNTED and
/// merely fades it to zero opacity, so `find.widgetWithText(TextField, hint)`
/// matches every row whether or not it has text in it. `.first` is therefore
/// always row 0 — three options got typed one over another into the same box,
/// and the group saved with a single choice named after the LAST one. Nothing
/// failed at the time; an assertion three steps later reported one option where
/// three were expected.
Future<void> _fillOption(
  WidgetTester tester,
  E2EContext ctx,
  E2EModifierOption option, {
  required int row,
}) async {
  Future<void> type(Finder fields, String value, String what) async {
    if (fields.evaluate().length <= row) {
      throw TestFailure(
        'Wanted the $what box of option row $row but found only '
        '${fields.evaluate().length} of them\n'
        '  On screen now: ${visibleTexts(tester)}',
      );
    }
    // The editor is a ListView, so a later row is genuinely off-screen.
    await tester.ensureVisible(fields.at(row));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(fields.at(row), value);
    await pumpFor(tester, const Duration(milliseconds: 300));
  }

  await type(
    find.widgetWithText(TextField, ctx.l.optionNameHint),
    option.name,
    'name',
  );
  await type(find.widgetWithText(TextField, '0.00'), option.price, 'price');
}

/// Walks a `_NumberField` stepper from [from] to [to] one tap at a time.
///
/// Scoped to the field's own `InputDecorator` — both steppers draw the same
/// `Icons.add`, so an unscoped finder would raise whichever came first in the
/// tree regardless of which one was asked for.
Future<void> _step(
  WidgetTester tester,
  String label, {
  required int from,
  required int to,
}) async {
  if (from == to) return;

  final field = find.ancestor(
    of: find.text(label),
    matching: find.byType(InputDecorator),
  );
  if (field.evaluate().isEmpty) {
    throw TestFailure(
      'No stepper labelled "$label"\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }

  final icon = to > from ? Icons.add : Icons.remove;
  for (var i = 0; i < (to - from).abs(); i++) {
    await tapVisible(
      tester,
      find.descendant(of: field.first, matching: find.byIcon(icon)),
    );
    await pumpFor(tester, const Duration(milliseconds: 250));
  }
}
