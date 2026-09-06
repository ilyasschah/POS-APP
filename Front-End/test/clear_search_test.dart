// Guards the asymmetry between `clearSearch` and `searchList`.
//
// Not every list screen has a search box. Products, Product Groups, Taxes,
// Payment Types and Security Rules do; **Users does not** — it renders cards
// with no filter at all. A blanket `searchList(tester, '')` therefore failed
// there with "No UnifiedSearchBar on this screen" against a screen that was
// working perfectly.
//
// The fix has to keep two behaviours apart, and this test is what stops them
// being collapsed back together:
//
//   * `clearSearch` — "reset any leftover filter". Nothing to clear is not a
//     problem, so a missing search box is a no-op.
//   * `searchList` — "filter to this row". A missing search box IS a problem,
//     because the caller is about to look for a row it believes has been
//     filtered into view; skipping quietly would leave an unfiltered list and
//     fail much later as "the row was never created".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/core/unified_search_bar.dart';

import '../integration_test/support/e2e_support.dart';

void main() {
  /// A screen with no search box at all — the Users screen's shape.
  Future<void> pumpWithoutSearch(WidgetTester tester) => tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('Jordon Quitzon'))),
        ),
      );

  /// A screen carrying a real `UnifiedSearchBar`.
  Future<void> pumpWithSearch(WidgetTester tester, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnifiedSearchBar(
            controller: controller,
            chips: const [],
            sectionsBuilder: (_) => const [],
            hintText: 'Search',
            onQueryChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('clearSearch is a no-op where there is no search box',
      (tester) async {
    await pumpWithoutSearch(tester);

    // The assertion is that this does NOT throw.
    await clearSearch(tester);
  });

  testWidgets('searchList still fails loudly where there is no search box',
      (tester) async {
    await pumpWithoutSearch(tester);

    await expectLater(
      searchList(tester, 'Amina'),
      throwsA(
        isA<TestFailure>().having(
          (e) => e.message,
          'message',
          contains('UnifiedSearchBar'),
        ),
      ),
      reason: 'A real query on a screen with no filter must fail here, not '
          'several steps later on a row that was never filtered into view.',
    );
  });

  testWidgets('clearSearch empties a box that has text in it', (tester) async {
    await pumpWithSearch(tester, initial: 'leftover filter');

    await clearSearch(tester);

    final field = find.descendant(
      of: find.byType(UnifiedSearchBar),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(field.first).controller?.text, isEmpty);
  });
}
