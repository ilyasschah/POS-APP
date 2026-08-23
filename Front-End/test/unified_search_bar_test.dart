// The unified search bar's mechanics.
//
// The overlay is the fragile part: it lives outside the page's own tree, so
// nothing in the widget hierarchy forces it to close, and an entry left behind
// paints over whatever screen comes next. These tests pin the open/close paths
// and the chip round trip.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/unified_search_bar.dart';

void main() {
  late TextEditingController controller;
  late List<String> removed;
  late List<String> selected;

  setUp(() {
    controller = TextEditingController();
    removed = [];
    selected = [];
  });

  tearDown(() => controller.dispose());

  List<FilterMenuSection> sections(String query) => [
        FilterMenuSection(
          title: 'Status',
          icon: Icons.payments_outlined,
          options: [
            FilterMenuOption(
              label: 'Paid',
              selected: true,
              onSelected: () => selected.add('Paid'),
            ),
            FilterMenuOption(
              label: 'Unpaid',
              onSelected: () => selected.add('Unpaid'),
            ),
          ],
        ),
        if (query.isNotEmpty)
          FilterMenuSection(
            title: 'Search for',
            options: [
              FilterMenuOption(
                label: 'Number contains "$query"',
                onSelected: () => selected.add('number:$query'),
              ),
            ],
          ),
      ];

  Future<void> pumpBar(
    WidgetTester tester, {
    List<SearchBarChip> chips = const [],
    VoidCallback? onClearAll,
    bool singleLine = false,
  }) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: UnifiedSearchBar(
              singleLine: singleLine,
              controller: controller,
              chips: chips,
              sectionsBuilder: sections,
              hintText: 'Search documents',
              onClearAll: onClearAll,
            ),
          ),
        ),
      ));

  SearchBarChip chip(String id, String label) => SearchBarChip(
        id: id,
        label: label,
        icon: Icons.person_outline,
        onRemove: () => removed.add(id),
      );

  testWidgets('shows the hint when nothing is applied', (tester) async {
    await pumpBar(tester);
    expect(find.text('Search documents'), findsOneWidget);
  });

  testWidgets('renders one chip per active filter, before the input',
      (tester) async {
    await pumpBar(tester, chips: [chip('customer', 'Cafe Atlas'), chip('user', 'ilyass')]);

    expect(find.text('Cafe Atlas'), findsOneWidget);
    expect(find.text('ilyass'), findsOneWidget);
    // The hint gives way to the chips — they are the statement of what is on.
    expect(find.text('Search documents'), findsNothing);

    final chipX = tester.getTopLeft(find.text('Cafe Atlas')).dx;
    final fieldX = tester.getTopLeft(find.byType(TextField)).dx;
    expect(chipX, lessThan(fieldX));
  });

  testWidgets('the chip X removes just that filter', (tester) async {
    await pumpBar(tester, chips: [chip('customer', 'Cafe Atlas')]);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(removed, ['customer']);
  });

  testWidgets('the filter button opens the menu under the bar',
      (tester) async {
    await pumpBar(tester);
    expect(find.text('STATUS'), findsNothing);

    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();

    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);

    // Anchored below the bar, not over it.
    final barBottom = tester.getBottomLeft(find.byType(TextField)).dy;
    expect(tester.getTopLeft(find.text('STATUS')).dy, greaterThan(barBottom));
  });

  testWidgets('an already-applied option is checked', (tester) async {
    await pumpBar(tester);
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('picking an option applies it and closes the menu',
      (tester) async {
    await pumpBar(tester);
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unpaid'));
    await tester.pumpAndSettle();

    expect(selected, ['Unpaid']);
    expect(find.text('STATUS'), findsNothing);
  });

  testWidgets('tapping outside closes the menu', (tester) async {
    await pumpBar(tester);
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();
    expect(find.text('STATUS'), findsOneWidget);

    await tester.tapAt(const Offset(20, 580));
    await tester.pumpAndSettle();

    expect(find.text('STATUS'), findsNothing);
  });

  testWidgets('typing opens the menu and offers the query as a filter',
      (tester) async {
    await pumpBar(tester);

    await tester.enterText(find.byType(TextField), 'INV-2');
    await tester.pumpAndSettle();

    expect(find.text('SEARCH FOR'), findsOneWidget);
    expect(find.text('Number contains "INV-2"'), findsOneWidget);
  });

  testWidgets('clear-all appears only with something to clear',
      (tester) async {
    var cleared = 0;
    await pumpBar(tester, onClearAll: () => cleared++);
    // Nothing applied: no clear button (the only close icon would be a chip's).
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.enterText(find.byType(TextField), 'x');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(cleared, 1);
  });

  testWidgets('the overlay is torn down with the widget', (tester) async {
    await pumpBar(tester);
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();
    expect(find.text('STATUS'), findsOneWidget);

    // Navigating away must not leave the menu painting over the next screen.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pumpAndSettle();

    expect(find.text('STATUS'), findsNothing);
  });

  group('single-line mode', () {
    // A PosTopBar is a fixed 62px: a bar that grows a second row of chips
    // overflows it rather than expanding, so the chips have to share the row.
    testWidgets('the bar does not grow when chips are added', (tester) async {
      await pumpBar(tester, singleLine: true);
      final empty = tester.getSize(find.byType(UnifiedSearchBar)).height;

      await pumpBar(
        tester,
        singleLine: true,
        chips: [chip('customer', 'A Very Long Customer Name Indeed'),
                chip('user', 'Another Long Cashier Name')],
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(UnifiedSearchBar)).height, empty);
      expect(empty, lessThan(62),
          reason: 'it has to clear the top bar it lives in');
    });

    testWidgets('chips stay on the same row as the input', (tester) async {
      await pumpBar(
        tester,
        singleLine: true,
        chips: [chip('customer', 'Cafe Atlas')],
      );

      final chipY = tester.getCenter(find.text('Cafe Atlas')).dy;
      final fieldY = tester.getCenter(find.byType(TextField)).dy;
      expect((chipY - fieldY).abs(), lessThan(8));
    });

    testWidgets('the input keeps room to type in', (tester) async {
      await pumpBar(
        tester,
        singleLine: true,
        chips: [chip('a', 'A Very Long Customer Name That Runs On'),
                chip('b', 'Another Extremely Long Cashier Name')],
      );

      expect(tester.getSize(find.byType(TextField)).width, greaterThan(60));
    });
  });
}
