// Proves the "Index 0" rule skips the placeholder — without needing a device.
//
// The smart default is only safe because `dropdownOptions` filters on each
// item's VALUE. Every dropdown these helpers touch is built as a null-valued
// placeholder followed by the real rows:
//
//   items: [
//     IlyassDropdownItem(value: null, label: l10n.noTax),      // <- index 0
//     for (final t in taxes) IlyassDropdownItem(value: t.id, ...),
//   ]
//
// So a helper that took a literal `items[0]` would save an UNTAXED,
// UNCATEGORIZED product and report success. That is one of the bugs this suite
// already shipped once (ProductGroupId NULL, invisible in a green run), so the
// guard against it gets a test of its own rather than a comment.
//
// The second half drives the real menu through the production primitives —
// `pickDropdown` and its read-back — so a change to the dropdown widget that
// would blind the E2E suite fails here first, not on a device an hour in.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/ilyass_dropdown.dart';

import '../integration_test/support/e2e_support.dart';

/// One dropdown shaped exactly like the app's — a null-valued placeholder,
/// then the real rows — that keeps what is picked, as the app's screens do.
class _Picker extends StatefulWidget {
  const _Picker({
    required this.label,
    required this.placeholder,
    required this.options,
  });

  final String label;
  final String placeholder;
  final List<String> options;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  int? _value;

  @override
  Widget build(BuildContext context) => IlyassDropdown<int?>(
        label: widget.label,
        value: _value,
        items: [
          IlyassDropdownItem<int?>(value: null, label: widget.placeholder),
          for (var i = 0; i < widget.options.length; i++)
            IlyassDropdownItem<int?>(value: i + 1, label: widget.options[i]),
        ],
        onChanged: (v) => setState(() => _value = v),
      );
}

void main() {
  /// Mounts one [_Picker]; the assertions read it back through the production
  /// finders.
  Future<void> pumpDropdown(
    WidgetTester tester, {
    required String label,
    required String placeholder,
    required List<String> options,
    List<Widget> behind = const [],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _Picker(
                  label: label,
                  placeholder: placeholder,
                  options: options,
                ),
                ...behind,
              ],
            ),
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
  _menuDrivingTests(pumpDropdown);
}

// ─────────────────────────────────────────────────────────────────────────────
// Category headers — the unit picker's shape.
// ─────────────────────────────────────────────────────────────────────────────

void _headerGroupTests() {
  testWidgets('skips category headers and disabled entries', (tester) async {
    // The measurement-unit picker's real shape: a non-selectable header per
    // category, carrying a NEGATIVE value rather than a null one, followed by
    // the units in it. `index: 0` must reach "pcs", never "UNIT".
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IlyassDropdown<int>(
            label: 'Measurement Unit',
            value: 1,
            items: const [
              IlyassDropdownItem(header: true, value: -1, label: 'Unit'),
              IlyassDropdownItem(value: 1, label: 'pcs'),
              IlyassDropdownItem(header: true, value: -2, label: 'Weight'),
              IlyassDropdownItem(value: 10, label: 'kg  ·  Stock unit'),
              IlyassDropdownItem(value: 11, label: 'g'),
              IlyassDropdownItem(value: 12, label: 'mg', enabled: false),
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
      isNot('Unit'),
      reason: 'A header cannot be selected — tapping it does nothing, so '
          'choosing it as the smart default hangs the picker.',
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Driving the real menu — what the E2E helpers actually do on a device.
// ─────────────────────────────────────────────────────────────────────────────

void _menuDrivingTests(
  Future<void> Function(
    WidgetTester, {
    required String label,
    required String placeholder,
    required List<String> options,
    List<Widget> behind,
  }) pumpDropdown,
) {
  testWidgets('pickDropdownAt selects the first REAL option and reads it back',
      (tester) async {
    await pumpDropdown(
      tester,
      label: 'Primary Tax Rate',
      placeholder: 'No Tax',
      options: ['VAT 20% [E2E 1] (20.0%)', 'Reduced 7% [E2E 1] (7.0%)'],
    );
    expect(dropdownSelection(tester, 'Primary Tax Rate'), 'No Tax');

    final chosen = await pickDropdownAt(tester, 'Primary Tax Rate');

    expect(chosen, 'VAT 20% [E2E 1] (20.0%)');
    expect(dropdownSelection(tester, 'Primary Tax Rate'), chosen);
  });

  testWidgets('pickDropdown reaches an option below the fold of a long menu',
      (tester) async {
    // A company that has run the suite for weeks: more groups than the menu
    // shows at once. The wanted one must be scrolled to INSIDE the menu.
    await pumpDropdown(
      tester,
      label: 'Category / Group',
      placeholder: 'None (Uncategorized)',
      options: [for (var i = 1; i <= 40; i++) 'Group $i'],
    );

    await pickDropdown(tester, 'Category / Group', 'Group 37');

    expect(dropdownSelection(tester, 'Category / Group'), 'Group 37');
  });

  testWidgets('pickDropdown ignores the same text elsewhere on the screen',
      (tester) async {
    // The products table behind the editor shows these very group names. A
    // tap on that copy would land on the barrier and pick nothing.
    await pumpDropdown(
      tester,
      label: 'Category / Group',
      placeholder: 'None (Uncategorized)',
      options: ['Beverages', 'Snacks'],
      behind: const [Text('Snacks'), Text('Beverages')],
    );

    await pickDropdown(tester, 'Category / Group', 'Snacks');

    expect(dropdownSelection(tester, 'Category / Group'), 'Snacks');
  });

  testWidgets('the read-back is not fooled by an unselected option',
      (tester) async {
    // Every option's label lives inside the dropdown's subtree, so a "text
    // inside the dropdown" check would pass for ANY option. The read-back
    // must report only what the field shows.
    await pumpDropdown(
      tester,
      label: 'Category / Group',
      placeholder: 'None (Uncategorized)',
      options: ['Beverages', 'Snacks'],
    );

    expect(dropdownSelection(tester, 'Category / Group'),
        'None (Uncategorized)');
    expect(dropdownSelection(tester, 'Category / Group'), isNot('Snacks'));
  });

  testWidgets('an absent option fails loudly instead of picking nothing',
      (tester) async {
    await pumpDropdown(
      tester,
      label: 'Category / Group',
      placeholder: 'None (Uncategorized)',
      options: ['Beverages'],
    );

    await expectLater(
      pickDropdown(tester, 'Category / Group', 'Nope', attempts: 1),
      throwsA(isA<TestFailure>()),
    );
  });
}
