/// `addBarcodeRule` / `testBarcodeMatch` — the company's barcode nomenclature.
///
/// ```dart
/// await addBarcodeRule(tester, ctx,
///     name: 'Scale weight', type: BarcodeRuleType.weighted,
///     encoding: BarcodeEncoding.ean13, pattern: '21.....{NNDDD}');
///
/// expect(await testBarcodeMatch(tester, ctx, '2100001012345'), 'Scale weight');
/// ```
///
/// ## What a rule decides
///
/// A scan is read through the ordered rule list, and the FIRST rule whose
/// pattern matches decides what the digits mean:
///
/// | type | the embedded value is |
/// |---|---|
/// | `unit` | nothing — a plain product barcode |
/// | `weighted` | a QUANTITY in the product's own unit |
/// | `priced` | a line TOTAL; quantity = value ÷ unit price |
/// | `discounted` | a percentage off the line |
///
/// So the same thirteen digits ring up as one item, as 1.234 kg, or as a fixed
/// amount, purely on which rule caught them. That is why order matters and why
/// this helper appends rather than inserting.
///
/// ## 🚨 The editor has no field labels
///
/// Each rule is a ROW of unlabelled controls — name, type, encoding, pattern —
/// distinguished only by position. `fillField` cannot be used: there is no label
/// to find them by. Cells are addressed by index within the row, the same way
/// `create_modifier_group_helper` addresses option rows, and for the same reason
/// (`InputDecorator` keeps a hint mounted, so "the empty one" is not a finder).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/barcode/nomenclature/barcode_rule.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rules_provider.dart';
import 'package:pos_app/settings/barcode_rules_editor.dart';
import 'package:pos_app/settings/settings_screen.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Opens Settings → Weighing Scale, where the barcode rules live.
///
/// 🚨 Not a Management destination. The nomenclature is a card on the WEIGHING
/// SCALE tab of Quick Settings — reasonable, since scale labels are what
/// weight-embedded barcodes come from, but nowhere near where a reader would
/// look for "barcodes".
Future<void> openBarcodeRules(WidgetTester tester, E2EContext ctx) async {
  if (find.byType(BarcodeRulesEditor).evaluate().isNotEmpty) return;

  await exitManagement(tester, ctx.l);
  await openSidebar(tester);

  // By WIDGET, never a bare `find.byIcon(Icons.tune)` — `MenuScreen` draws the
  // same icon on its (disabled) Modifiers button and comes first in tree order.
  await tapVisible(tester, sidebarIconButton(Icons.tune));
  await waitFor(
    tester,
    find.byType(SettingsScreen),
    timeout: const Duration(seconds: 60),
    because: 'Quick Settings did not open. A security key on '
        'SecurityKeys.settings will also look like this.',
  );
  ctx.refreshL10n(tester);

  await tapVisible(tester, find.text(ctx.l.setWeighingScale).first);
  await waitFor(
    tester,
    find.byType(BarcodeRulesEditor),
    timeout: const Duration(seconds: 30),
    because: 'The Weighing Scale tab did not show the barcode-rules editor.',
  );
  await pumpFor(tester, const Duration(seconds: 1));
}

/// Appends a rule and saves the list.
///
/// Returns without changing anything if a rule of that name already exists, so
/// the test is safe to re-run.
Future<String> addBarcodeRule(
  WidgetTester tester,
  E2EContext ctx, {
  required String name,
  required BarcodeRuleType type,
  required BarcodeEncoding encoding,
  required String pattern,
}) async {
  await openBarcodeRules(tester, ctx);

  final existing = ctx.container.read(barcodeRulesProvider).value ?? const [];
  if (existing.any((r) => r.name == name)) {
    step('Barcode rule "$name" already exists');
    return name;
  }

  // 🚨 Count the rows BEFORE adding, because the new row's index is the only
  // way to address it. Every cell in this editor is unlabelled, so "the row I
  // just made" is a position and nothing else.
  final before = _ruleRows(tester).evaluate().length;

  await tapVisible(tester, find.text(ctx.l.addRuleLine));
  await pumpFor(tester, const Duration(milliseconds: 600));

  final rows = _ruleRows(tester).evaluate().length;
  expect(
    rows,
    before + 1,
    reason: '"Add rule line" did not add a row.',
  );
  final row = rows - 1;

  // ── Cell 0: the name ───────────────────────────────────────────────────────
  //
  // Addressed by POSITION within the whole editor, not "the empty one": a
  // `TextFormField` with no text still matches every finder that a filled one
  // does, which is the trap `create_modifier_group_helper` documents at length.
  await _typeInto(tester, _nameFields(tester), row, name, 'name');

  // ── Cell 1: the type, Cell 2: the encoding ─────────────────────────────────
  //
  // Both dropdowns are unlabelled, so they cannot go through `pickDropdown`,
  // which finds a field by its decoration's label. They are opened by position
  // and the option is picked by the text the editor renders for it.
  await _pickInRow(tester, row, _typeLabelFor(ctx, type), which: 0);
  await _pickInRow(tester, row, encodingLabel(encoding), which: 1);

  // ── Cell 3: the pattern ────────────────────────────────────────────────────
  await _typeInto(tester, _patternFields(tester), row, pattern, 'pattern');

  // 🚨 Save is DISABLED until something changes (`!_dirty`), so a tap that
  // lands before the edits register does nothing at all and the run then finds
  // an unsaved list. Waiting for it to become enabled is the honest gate.
  final save = find.widgetWithText(FilledButton, ctx.l.actionSave);
  await waitUntil(
    tester,
    () async =>
        save.evaluate().isNotEmpty &&
        tester.widget<FilledButton>(save.first).onPressed != null,
    describe: 'the Save button becomes enabled',
    timeout: const Duration(seconds: 30),
  );
  await tapVisible(tester, save);

  await waitUntil(
    tester,
    () async => (ctx.container.read(barcodeRulesProvider).value ?? const [])
        .any((r) => r.name == name),
    describe: '"$name" reaches the company\'s rule list',
    timeout: const Duration(seconds: 60),
  );

  ctx.record(E2EArtifact(
    table: 'BarcodeRule',
    name: name,
    extra: {
      'Type': type.name,
      'Encoding': encoding.name,
      'Pattern': pattern,
    },
  ));
  step('Barcode rule added: $name (${type.name}, ${encoding.name}) $pattern');
  return name;
}

/// Runs [code] through the editor's own tester and returns the rule that caught
/// it, or `null` when nothing did.
///
/// 🚨 This is the app's OWN `matchBarcode`, driven through its own UI — not a
/// reimplementation of the pattern language in the test. A test that parsed the
/// pattern itself would agree with itself forever and notice nothing when the
/// real matcher changed.
Future<String?> testBarcodeMatch(
  WidgetTester tester,
  E2EContext ctx,
  String code,
) async {
  await openBarcodeRules(tester, ctx);

  // The tester's field is the one carrying that hint — the rule rows' pattern
  // cells have their own, different hint.
  final field = find.widgetWithText(TextField, '2210001003504');
  if (field.evaluate().isEmpty) {
    throw TestFailure(
      'No barcode-tester field on the editor.\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }

  await tester.ensureVisible(field.first);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.enterText(field.first, code);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await pumpFor(tester, const Duration(seconds: 1));

  if (find.text(ctx.l.testBarcodeNoMatch).evaluate().isNotEmpty) {
    step('Tester: $code -> no match');
    return null;
  }

  // 🚨 The matched message carries TWO placeholders — "Matched $rule — value
  // $value" — so the rule's name cannot be recovered by splitting a
  // one-placeholder template. It is rendered with a sentinel in each position
  // and the name is whatever sits between them, wherever a translation puts
  // them.
  const ruleMark = '<<RULE>>';
  const valueMark = '<<VALUE>>';
  final template = ctx.l.testBarcodeMatched(ruleMark, valueMark);
  final head = template.substring(0, template.indexOf(ruleMark));
  final mid = template.substring(
    template.indexOf(ruleMark) + ruleMark.length,
    template.indexOf(valueMark),
  );

  final shown = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .where((d) => d.startsWith(head) && d.contains(mid))
      .toList();

  if (shown.isEmpty) {
    throw TestFailure(
      'The tester reported neither a match nor a no-match for "$code".\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }

  final line = shown.first;
  final matched = line.substring(head.length, line.indexOf(mid, head.length));
  step('Tester: $code -> matched "$matched"');
  return matched.trim();
}

// ─────────────────────────────────────────────────────────────────────────────

/// The editor's rule rows, by their drag handle — one per row, and nothing else
/// on the screen uses that icon.
Finder _ruleRows(WidgetTester tester) => find.byIcon(Icons.drag_indicator);

/// The NAME cell of every row: a `TextFormField` with no hint at all.
Finder _nameFields(WidgetTester tester) => find.byWidgetPredicate(
      (w) => w is TextFormField,
      description: 'rule name fields',
    );

/// The PATTERN cell of every row, told apart by its hint.
Finder _patternFields(WidgetTester tester) =>
    find.widgetWithText(TextFormField, '22.....{NNDDD}');

Future<void> _typeInto(
  WidgetTester tester,
  Finder fields,
  int row,
  String value,
  String what,
) async {
  final matches = fields.evaluate().length;
  if (matches <= row) {
    throw TestFailure(
      'Wanted the $what cell of rule row $row but found only $matches.\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }
  await tester.ensureVisible(fields.at(row));
  await tester.pump(const Duration(milliseconds: 150));
  await tester.enterText(fields.at(row), value);
  await pumpFor(tester, const Duration(milliseconds: 400));
}

/// Opens the [which]-th dropdown of rule row [row] and picks [optionText].
///
/// 🚨 `pickDropdown` cannot be used: it locates a field by its decoration's
/// label, and these have none. The dropdowns are found by position instead —
/// two per row, type then encoding.
Future<void> _pickInRow(
  WidgetTester tester,
  int row,
  String optionText, {
  required int which,
}) async {
  final all = anyDropdownField;
  final index = row * 2 + which;
  if (all.evaluate().length <= index) {
    throw TestFailure(
      'Wanted dropdown $which of rule row $row but the editor has '
      '${all.evaluate().length} in total.',
    );
  }

  await tester.ensureVisible(all.at(index));
  await tester.pump(const Duration(milliseconds: 150));
  await tester.tap(all.at(index), warnIfMissed: false);
  await pumpFor(tester, const Duration(milliseconds: 700));

  // Confined to the open menu, for the reason `pickDropdown` documents: the
  // option text is also rendered on the CLOSED dropdowns of every other row.
  final menu = find.byType(Scrollable).last;
  final option = find.descendant(of: menu, matching: find.text(optionText));
  if (option.evaluate().isEmpty) {
    throw TestFailure(
      'No option "$optionText" in that dropdown.\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }
  await tester.ensureVisible(option.last);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(option.last);
  await pumpFor(tester, const Duration(milliseconds: 700));
}

/// The label the editor renders for a rule type.
String _typeLabelFor(E2EContext ctx, BarcodeRuleType type) => switch (type) {
      BarcodeRuleType.unit => ctx.l.ruleTypeUnit,
      BarcodeRuleType.weighted => ctx.l.ruleTypeWeighted,
      BarcodeRuleType.priced => ctx.l.ruleTypePriced,
      BarcodeRuleType.discounted => ctx.l.ruleTypeDiscounted,
    };
