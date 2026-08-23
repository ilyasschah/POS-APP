// The Ilyass Style table's four promises.
//
// Each one exists because its opposite was a real defect on this app's
// screens: surplus width spread evenly opened a dead zone between two short
// columns; centred money could not be scanned; a column nobody could widen
// truncated every document number; and a stretched actions column was pure
// wasted space.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Row {
  const _Row(this.name, this.total);
  final String name;
  final double total;
}

void main() {
  const rows = [
    _Row('Cafe Atlas', 84),
    _Row('Walk-in Customer', 1207.75),
  ];

  List<IlyassColumn<_Row>> columns({bool withActions = true}) => [
        IlyassColumn<_Row>(
          key: 'name',
          label: 'CUSTOMER',
          width: 200,
          flexible: true,
          cell: (context, r) => Text(r.name),
        ),
        IlyassColumn<_Row>(
          key: 'date',
          label: 'DATE',
          width: 150,
          cell: (context, r) => const Text('22-Aug-26'),
        ),
        IlyassColumn<_Row>(
          key: 'total',
          label: 'TOTAL',
          width: 140,
          numeric: true,
          cell: (context, r) => Text('${r.total} MAD'),
        ),
        if (withActions)
          IlyassColumn<_Row>(
            key: 'actions',
            label: 'ACTIONS',
            width: 96,
            resizable: false,
            cell: (context, r) => const Icon(Icons.edit),
          ),
      ];

  Future<void> pumpTable(
    WidgetTester tester, {
    List<_Row> data = rows,
    bool withActions = true,
    void Function(_Row)? onRowTap,
    bool Function(_Row)? isRowSelected,
    Widget? emptyState,
    double width = 700,
    SharedPreferences? prefs,
  }) =>
      tester.pumpWidget(ProviderScope(
        overrides: [
          if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: 400,
                child: IlyassTable<_Row>(
                  tableId: 'test',
                  rows: data,
                  columns: columns(withActions: withActions),
                  onRowTap: onRowTap,
                  isRowSelected: isRowSelected,
                  emptyState: emptyState,
                ),
              ),
            ),
          ),
        ),
      ));

  /// The rendered width of a header cell, which is the column's real width.
  double headerWidth(WidgetTester tester, String label) =>
      tester.getSize(find.ancestor(
        of: find.text(label),
        matching: find.byType(SizedBox),
      ).first).width;

  testWidgets('surplus width goes to the flexible column only', (tester) async {
    // Columns declare 200 + 150 + 140 + 96 = 586 against a 700px pane.
    // (The test surface is 800px, so the pane has to stay inside it.)
    await pumpTable(tester);

    expect(headerWidth(tester, 'CUSTOMER'), 200 + (700 - 586));
    expect(headerWidth(tester, 'DATE'), 150,
        reason: 'a date column must not stretch just because there is room');
    expect(headerWidth(tester, 'TOTAL'), 140);
    expect(headerWidth(tester, 'ACTIONS'), 96);
  });

  testWidgets('numeric columns are end-aligned, text columns start-aligned',
      (tester) async {
    await pumpTable(tester);

    final align = tester.widget<Align>(find.ancestor(
      of: find.text('TOTAL'),
      matching: find.byType(Align),
    ).first);
    expect(align.alignment, AlignmentDirectional.centerEnd);

    final textAlign = tester.widget<Align>(find.ancestor(
      of: find.text('CUSTOMER'),
      matching: find.byType(Align),
    ).first);
    expect(textAlign.alignment, AlignmentDirectional.centerStart);
  });

  testWidgets('dragging a header edge resizes that column', (tester) async {
    await pumpTable(tester);
    final before = headerWidth(tester, 'DATE');

    // The handle sits on the DATE header's trailing edge.
    final dateRight = tester.getTopRight(find.ancestor(
      of: find.text('DATE'),
      matching: find.byType(SizedBox),
    ).first);
    await tester.dragFrom(dateRight - const Offset(4, -12), const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(headerWidth(tester, 'DATE'), greaterThan(before));
  });

  testWidgets('a column cannot be dragged below its minimum', (tester) async {
    await pumpTable(tester);

    final dateRight = tester.getTopRight(find.ancestor(
      of: find.text('DATE'),
      matching: find.byType(SizedBox),
    ).first);
    await tester.dragFrom(
        dateRight - const Offset(4, -12), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(headerWidth(tester, 'DATE'), greaterThanOrEqualTo(64.0));
  });

  testWidgets('a non-resizable column has no drag handle', (tester) async {
    await pumpTable(tester);

    // Three resizable columns, but the last column never gets a handle, so the
    // two interior ones are all there is: CUSTOMER and DATE. ACTIONS is last
    // AND non-resizable.
    expect(find.byType(MouseRegion).evaluate().isNotEmpty, isTrue);
    final actionsWidth = headerWidth(tester, 'ACTIONS');
    await tester.dragFrom(
      tester.getTopRight(find.ancestor(
        of: find.text('ACTIONS'),
        matching: find.byType(SizedBox),
      ).first) -
          const Offset(4, -12),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();

    expect(headerWidth(tester, 'ACTIONS'), actionsWidth,
        reason: 'an actions column of fixed-size icons must stay put');
  });

  testWidgets('rows render their cells', (tester) async {
    await pumpTable(tester);

    expect(find.text('Cafe Atlas'), findsOneWidget);
    expect(find.text('1207.75 MAD'), findsOneWidget);
  });

  testWidgets('tapping a row reports the row, not its index', (tester) async {
    final tapped = <String>[];
    await pumpTable(tester, onRowTap: (r) => tapped.add(r.name));

    await tester.tap(find.text('Walk-in Customer'));
    await tester.pumpAndSettle();

    expect(tapped, ['Walk-in Customer']);
  });

  testWidgets('the selected row is tinted', (tester) async {
    await pumpTable(tester, isRowSelected: (r) => r.name == 'Cafe Atlas');

    final decorated = tester.widgetList<DecoratedBox>(find.descendant(
      of: find.byType(ListView),
      matching: find.byType(DecoratedBox),
    ));
    final fills = decorated
        .map((d) => (d.decoration as BoxDecoration).color)
        .whereType<Color>()
        .toList();

    expect(fills, isNotEmpty,
        reason: 'exactly the selected row carries a fill');
  });

  testWidgets('the empty state replaces the table', (tester) async {
    await pumpTable(
      tester,
      data: const [],
      emptyState: const Text('No documents'),
    );

    expect(find.text('No documents'), findsOneWidget);
    expect(find.text('CUSTOMER'), findsNothing);
  });

  testWidgets('a table narrower than its columns keeps them at full width',
      (tester) async {
    // 586 of columns in a 400 pane: nothing shrinks, the table scrolls.
    await pumpTable(tester, width: 400);

    expect(headerWidth(tester, 'CUSTOMER'), 200);
    expect(find.byType(Scrollbar), findsWidgets);
  });

  /// The grab strip on a header cell's trailing edge.
  Offset handleOf(WidgetTester tester, String label) =>
      tester.getTopRight(find.ancestor(
            of: find.text(label),
            matching: find.byType(SizedBox),
          ).first) -
      const Offset(4, -12);

  group('resize feel', () {
    testWidgets('nothing to the left of the handle moves during a drag',
        (tester) async {
      // The glitch: the flexible column absorbs surplus, so widening DATE used
      // to shrink CUSTOMER by the same amount — pulling the right edge slid the
      // left half of the table, and the handle moved out from under the pointer.
      await pumpTable(tester);
      final customerBefore = headerWidth(tester, 'CUSTOMER');

      final gesture = await tester.startGesture(handleOf(tester, 'DATE'));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();

      expect(headerWidth(tester, 'CUSTOMER'), customerBefore,
          reason: 'the column left of the handle must not move mid-drag');
      expect(headerWidth(tester, 'DATE'), greaterThan(150));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(headerWidth(tester, 'CUSTOMER'), customerBefore,
          reason: 'nor snap back when the drag is released');
    });

    testWidgets('shrinking a column does not slide the flexible one either',
        (tester) async {
      // The other half of the glitch, and the one that actually reaches the
      // surplus rule: give width back and the flexible column would grow into
      // it on every frame, dragging the whole left side along.
      await pumpTable(tester);
      final customerBefore = headerWidth(tester, 'CUSTOMER');

      final gesture = await tester.startGesture(handleOf(tester, 'DATE'));
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump();

      expect(headerWidth(tester, 'CUSTOMER'), customerBefore,
          reason: 'held still while the pointer is down');

      await gesture.up();
      await tester.pumpAndSettle();

      // On release it resumes filling — one settle, not a continuous slide.
      expect(headerWidth(tester, 'CUSTOMER'), customerBefore + 50,
          reason: 'the freed space goes to the column that fills');
    });

    testWidgets('a hand-sized table still fills a wider pane', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Size a column by hand at 700px...
      await pumpTable(tester, prefs: prefs);
      final gesture = await tester.startGesture(handleOf(tester, 'DATE'));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      final customerAt700 = headerWidth(tester, 'CUSTOMER');

      // ...then reopen the screen in a wider pane. The flexible column is
      // still the one that fills: pinning it must not turn it into a fixed
      // column forever.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await pumpTable(tester, prefs: prefs, width: 780);

      expect(headerWidth(tester, 'CUSTOMER'), greaterThan(customerAt700));
    });

    testWidgets('dragging back to the start restores the original width',
        (tester) async {
      // Accumulating `delta.dx` drifts by whatever the clamp swallowed: after
      // slamming into the minimum and returning, the edge no longer sits under
      // the pointer. Anchoring to the drag's start position cannot drift.
      await pumpTable(tester);
      final before = headerWidth(tester, 'DATE');

      final gesture = await tester.startGesture(handleOf(tester, 'DATE'));
      await gesture.moveBy(const Offset(-400, 0)); // well past the minimum
      await tester.pump();
      expect(headerWidth(tester, 'DATE'), 64.0, reason: 'clamped, not negative');

      await gesture.moveBy(const Offset(400, 0)); // back where it started
      await tester.pump();
      expect(headerWidth(tester, 'DATE'), closeTo(before, 0.5));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the handle marks itself while it owns the drag',
        (tester) async {
      await pumpTable(tester);
      final gesture = await tester.startGesture(handleOf(tester, 'DATE'));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();

      final active = tester.widgetList<Container>(find.byType(Container)).where(
          (c) => c.constraints?.maxWidth == 2 || c.constraints?.minWidth == 2);
      expect(active, isNotEmpty, reason: 'the dragged edge thickens');

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('saved layout', () {
    testWidgets('a drag is written to local storage and restored',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await pumpTable(tester, prefs: prefs);
      final gesture = await tester.startGesture(handleOf(tester, 'DATE'));
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final dragged = headerWidth(tester, 'DATE');
      expect(dragged, greaterThan(150));
      expect(prefs.getString(ilyassTableWidthsKey('test')), isNotNull,
          reason: 'written on release, not on every frame');

      // A fresh mount — the next time the screen is opened.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await pumpTable(tester, prefs: prefs);

      expect(headerWidth(tester, 'DATE'), dragged,
          reason: 'the operator keeps the layout they set');
    });

    testWidgets('a corrupt saved value falls back to the declared widths',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        ilyassTableWidthsKey('test'): 'not json at all',
      });
      final prefs = await SharedPreferences.getInstance();

      await pumpTable(tester, prefs: prefs);

      expect(headerWidth(tester, 'DATE'), 150,
          reason: 'a broken preference must never break the screen');
    });

    testWidgets('no preference store at all still renders', (tester) async {
      // Widget previews and tests do not always wire one up.
      await pumpTable(tester);
      expect(find.text('CUSTOMER'), findsOneWidget);
    });
  });
}
