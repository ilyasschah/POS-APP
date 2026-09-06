// Pins the sibling-vs-ancestor trap, which has now cost two debugging sessions.
//
// Several editors in this app lay a control out BESIDE its caption rather than
// around it:
//
//   Row(children: [Text(label), Switch(...)])                  payment types
//   Row(children: [Tooltip(Text(label)), SegmentedButton(...)]) security rules
//
// The obvious finder — "the control that has this label inside it" — describes a
// containment that does not exist, so it matches nothing. Both failures were
// misleading in different ways: once as "no switch labelled X" on a screen
// plainly showing one, and once as an internal `'_found != null'` assertion from
// inside the matcher, because `.first` had been chained onto the empty result
// before anything checked it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/navigation/nav_widgets.dart';

import '../integration_test/support/e2e_support.dart';

void main() {
  /// The shape both editors use: caption and control side by side.
  Future<void> pumpSiblingRow(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Row(
                  children: [
                    const Text('Mark As Paid'),
                    Switch(value: false, onChanged: (_) {}),
                  ],
                ),
                Row(
                  children: [
                    const Text('Quick Payment'),
                    Switch(value: true, onChanged: (_) {}),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  testWidgets('find.ancestor CANNOT reach a sibling control', (tester) async {
    await pumpSiblingRow(tester);

    // This is the finder that looks right and silently finds nothing. Keeping it
    // asserted here is what stops someone "simplifying" the helpers back to it.
    expect(
      find.ancestor(
        of: find.text('Mark As Paid'),
        matching: find.byType(Switch),
      ),
      findsNothing,
      reason: 'The Switch is beside the label, not around it. If this ever '
          'starts matching, the layout changed and the helpers can be '
          'simplified.',
    );
  });

  testWidgets('enclosingRow reaches it, and picks the RIGHT row',
      (tester) async {
    await pumpSiblingRow(tester);

    final row = enclosingRow(
      tester,
      find.text('Quick Payment'),
      describe: 'the Quick Payment label',
    );

    final control = find.descendant(of: row, matching: find.byType(Switch));
    expect(control, findsOneWidget);

    // The value proves it found the SECOND row's switch, not the first one's.
    // A finder that grabbed a wider ancestor Row would see both and `.first`
    // would silently return the wrong control.
    expect(
      tester.widget<Switch>(control.first).value,
      isTrue,
      reason: 'Picked up the wrong row\'s control — the innermost Row is the '
          'one that pairs this label with its own widget.',
    );
  });

  testWidgets('enclosingRow names what was missing instead of crashing',
      (tester) async {
    await pumpSiblingRow(tester);

    // 🚨 The whole point of the primitive. Chaining `.first` onto an empty
    // finder does not fail where it is written — it fails later inside the
    // matcher's mismatch description, with a message about Flutter internals
    // and no mention of what was being looked for.
    expect(
      () => enclosingRow(
        tester,
        find.text('Not On This Screen'),
        describe: 'the Not On This Screen label',
      ),
      throwsA(
        isA<TestFailure>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('Not On This Screen'),
            contains('On screen now'),
          ),
        ),
      ),
    );
  });

  _ambiguousIconTests();
}

// ─────────────────────────────────────────────────────────────────────────────
// The other ambiguous-finder trap: one icon, two screens.
// ─────────────────────────────────────────────────────────────────────────────

void _ambiguousIconTests() {
  /// The till's real shape while the sidebar is open: the BODY draws
  /// `Icons.tune` on a Modifiers button (disabled whenever no cart line is
  /// selected), and the SIDEBAR draws the same icon on Quick Settings. The body
  /// comes first in tree order.
  late bool sidebarTapped;

  Future<void> pumpTillWithSidebar(WidgetTester tester) async {
    sidebarTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              // Body — FIRST in tree order, and dead: the Modifiers button is
              // `onTap: null` whenever no cart line is selected.
              const IconButton(icon: Icon(Icons.tune), onPressed: null),
              // Sidebar — the one a test actually means.
              NavIconButton(
                icon: Icons.tune,
                tooltip: 'Quick Settings',
                onTap: () => sidebarTapped = true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('find.byIcon alone is ambiguous', (tester) async {
    await pumpTillWithSidebar(tester);

    expect(
      find.byIcon(Icons.tune),
      findsNWidgets(2),
      reason: 'Two controls share this icon. That is why `.first` on it taps the '
          'disabled one in the body and the run then waits for a screen nobody '
          'asked to open.',
    );
  });

  testWidgets('sidebarIconButton reaches the LIVE sidebar control',
      (tester) async {
    await pumpTillWithSidebar(tester);

    final finder = sidebarIconButton(Icons.tune);
    expect(finder, findsOneWidget);

    // The assertion that matters: tapping what this finder returns actually
    // fires a handler. Tapping the body's button would leave this false, which
    // is precisely the silent failure the finder exists to prevent.
    await tester.tap(finder);
    await tester.pump();
    expect(
      sidebarTapped,
      isTrue,
      reason: 'The finder returned a control whose tap does nothing.',
    );
  });
}
