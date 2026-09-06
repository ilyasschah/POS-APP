// Proves the "Index 0" rule skips the placeholder — without needing a device.
//
// The smart default is only safe because `dropdownOptions` filters on each
// item's VALUE. Every dropdown these helpers touch is built as a null-valued
// placeholder followed by the real rows:
//
//   items: [
//     DropdownMenuItem(value: null, child: Text('No Tax')),   // <- index 0
//     ...taxes.map((t) => DropdownMenuItem(value: t.id, ...)),
//   ]
//
// So a helper that took a literal `items[0]` would save an UNTAXED,
// UNCATEGORIZED product and report success. That is one of the bugs this suite
// already shipped once (ProductGroupId NULL, invisible in a green run), so the
// guard against it gets a test of its own rather than a comment.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/e2e_support.dart';

void main() {
  /// Mounts one dropdown shaped exactly like the app's, and returns nothing —
  /// the assertions read it back through the production finder.
  Future<void> pumpDropdown(
    WidgetTester tester, {
    required String label,
    required String placeholder,
    required List<String> options,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DropdownButtonFormField<int?>(
            decoration: InputDecoration(labelText: label),
            items: [
              DropdownMenuItem(value: null, child: Text(placeholder)),
              for (var i = 0; i < options.length; i++)
                DropdownMenuItem(value: i + 1, child: Text(options[i])),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('skips the null-valued placeholder', (tester) async {
    await pumpDropdown(
      tester,
      label: 'Primary Tax Rate',
      placeholder: 'No Tax',
      options: ['VAT 20% [E2E 1] (20.0%)', 'Reduced 7% [E2E 1] (7.0%)'],
    );

    final options = dropdownOptions(tester, 'Primary Tax Rate');

    expect(
      options,
      ['VAT 20% [E2E 1] (20.0%)', 'Reduced 7% [E2E 1] (7.0%)'],
      reason: 'The placeholder must never be offered as a smart default',
    );
    // The assertion that actually matters: "first available" is a real tax.
    expect(options.first, isNot('No Tax'));
  });

  testWidgets('includes the placeholder when asked', (tester) async {
    await pumpDropdown(
      tester,
      label: 'Parent Folder',
      placeholder: 'None (Root)',
      options: ['Beverages'],
    );

    expect(
      dropdownOptions(tester, 'Parent Folder', includePlaceholder: true),
      ['None (Root)', 'Beverages'],
    );
  });

  testWidgets('reports an empty menu rather than picking the placeholder',
      (tester) async {
    await pumpDropdown(
      tester,
      label: 'Category / Group',
      placeholder: 'None (Uncategorized)',
      options: [],
    );

    // A company with no groups at all must FAIL the smart default, not fall
    // through to "None (Uncategorized)" — that is the ProductGroupId NULL bug.
    expect(dropdownOptions(tester, 'Category / Group'), isEmpty);
    expect(
      () => pickDropdownAt(tester, 'Category / Group'),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('filters by value, not by localised text', (tester) async {
    // 🚨 The placeholder is identified by its null VALUE. A text-based check
    // ("skip anything reading 'No Tax'") would work in English and silently
    // select an untaxed product on a French or Arabic terminal, which is the
    // language trap this suite is built around.
    await pumpDropdown(
      tester,
      label: 'Taux de TVA principal',
      placeholder: 'Aucune taxe',
      options: ['TVA 20% [E2E 1] (20.0%)'],
    );

    expect(
      dropdownOptions(tester, 'Taux de TVA principal'),
      ['TVA 20% [E2E 1] (20.0%)'],
    );
  });

  _headerGroupTests();
}

// ─────────────────────────────────────────────────────────────────────────────
// Disabled category headers — the unit picker's shape.
// ─────────────────────────────────────────────────────────────────────────────

void _headerGroupTests() {
  testWidgets('skips disabled category headers', (tester) async {
    // The measurement-unit picker's real shape: a non-selectable header per
    // category, carrying a NEGATIVE value rather than a null one, followed by
    // the units in it. `index: 0` must reach "pcs", never "UNIT".
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Measurement Unit'),
            items: const [
              DropdownMenuItem(enabled: false, value: -1, child: Text('UNIT')),
              DropdownMenuItem(value: 1, child: Text('pcs')),
              DropdownMenuItem(enabled: false, value: -2, child: Text('WEIGHT')),
              DropdownMenuItem(value: 10, child: Text('kg  ·  Stock unit')),
              DropdownMenuItem(value: 11, child: Text('g')),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final options = dropdownOptions(tester, 'Measurement Unit');

    expect(options, ['pcs', 'kg  ·  Stock unit', 'g']);
    expect(
      options.first,
      isNot('UNIT'),
      reason: 'A disabled header cannot be selected — tapping it does nothing, '
          'so choosing it as the smart default hangs the picker.',
    );
  });
}
