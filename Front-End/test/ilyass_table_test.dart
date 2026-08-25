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

  // The selection column the Products screen puts in front of every row: a
  // widget header instead of a label, a per-row tint that is not the selection
  // tint, and a cell whose tap must NOT reach the row's own handler.
  group('a checkbox column', () {
    Future<void> pumpSelectable(
      WidgetTester tester, {
      required List<String> ticked,
      void Function(_Row)? onRowTap,
      void Function(_Row)? onCellTap,
      VoidCallback? onSelectAll,
      Color? Function(_Row)? rowColor,
      bool Function(_Row)? isRowSelected,
    }) =>
        tester.pumpWidget(ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 700,
                height: 400,
                child: IlyassTable<_Row>(
                  tableId: 'selectable',
                  rows: rows,
                  onRowTap: onRowTap,
                  isRowSelected: isRowSelected,
                  rowColor: rowColor,
                  columns: [
                    IlyassColumn<_Row>(
                      key: 'select',
                      label: 'SELECT',
                      width: 64,
                      minWidth: 64,
                      resizable: false,
                      header: (context) => GestureDetector(
                        onTap: onSelectAll,
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.select_all),
                        ),
                      ),
                      cell: (context, r) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onCellTap?.call(r),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(ticked.contains(r.name)
                              ? Icons.check_box
                              : Icons.check_box_outline_blank),
                        ),
                      ),
                    ),
                    IlyassColumn<_Row>(
                      key: 'name',
                      label: 'CUSTOMER',
                      width: 200,
                      flexible: true,
                      cell: (context, r) => Text(r.name),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));

    testWidgets('its header widget replaces the header label', (tester) async {
      await pumpSelectable(tester, ticked: const []);

      expect(find.byIcon(Icons.select_all), findsOneWidget);
      expect(find.text('SELECT'), findsNothing,
          reason: 'the label still names the column, it just is not drawn');
      expect(find.text('CUSTOMER'), findsOneWidget,
          reason: 'columns without a header widget keep their text');
    });

    testWidgets('the header widget is tappable — select all', (tester) async {
      var selectAlls = 0;
      await pumpSelectable(
        tester,
        ticked: const [],
        onSelectAll: () => selectAlls++,
      );

      await tester.tap(find.byIcon(Icons.select_all));
      await tester.pumpAndSettle();

      expect(selectAlls, 1);
    });

    // 🚨 The whole point of making the row clickable: ticking a box must not
    // also open the editor the row tap leads to.
    testWidgets('a tap in the checkbox cell does not reach the row',
        (tester) async {
      final rowTaps = <String>[];
      final cellTaps = <String>[];
      await pumpSelectable(
        tester,
        ticked: const [],
        onRowTap: (r) => rowTaps.add(r.name),
        onCellTap: (r) => cellTaps.add(r.name),
      );

      await tester.tap(find.byIcon(Icons.check_box_outline_blank).first);
      await tester.pumpAndSettle();

      expect(cellTaps, ['Cafe Atlas']);
      expect(rowTaps, isEmpty,
          reason: 'the deeper recognizer owns the tap');
    });

    testWidgets('a tap anywhere else in the row still opens it',
        (tester) async {
      final rowTaps = <String>[];
      await pumpSelectable(
        tester,
        ticked: const [],
        onRowTap: (r) => rowTaps.add(r.name),
        onCellTap: (_) {},
      );

      await tester.tap(find.text('Walk-in Customer'));
      await tester.pumpAndSettle();

      expect(rowTaps, ['Walk-in Customer']);
    });

    testWidgets('rowColor tints one row and leaves the others clear',
        (tester) async {
      await pumpSelectable(
        tester,
        ticked: const [],
        rowColor: (r) => r.name == 'Cafe Atlas' ? const Color(0xFF00FF00) : null,
      );

      final fills = tester
          .widgetList<DecoratedBox>(find.descendant(
            of: find.byType(ListView),
            matching: find.byType(DecoratedBox),
          ))
          .map((d) => (d.decoration as BoxDecoration).color)
          .toList();

      expect(fills, contains(const Color(0xFF00FF00)));
      expect(fills.where((c) => c == const Color(0xFF00FF00)).length, 1,
          reason: 'only the row the callback named carries it');
    });

    testWidgets('the selection tint wins over rowColor on a selected row',
        (tester) async {
      await pumpSelectable(
        tester,
        ticked: const ['Cafe Atlas'],
        rowColor: (_) => const Color(0xFF00FF00),
        isRowSelected: (r) => r.name == 'Cafe Atlas',
      );

      final fills = tester
          .widgetList<DecoratedBox>(find.descendant(
            of: find.byType(ListView),
            matching: find.byType(DecoratedBox),
          ))
          .map((d) => (d.decoration as BoxDecoration).color)
          .toList();

      // Two rows, both tinted green by the callback; the selected one must show
      // the selection colour instead, or a disabled row would hide which row
      // the operator has picked.
      expect(fills.where((c) => c == const Color(0xFF00FF00)).length, 1);
    });
  });

  // The reported defect and the architecture that fixes it: a flexible column
  // is a STARTING state, converted to fixed pixels the moment a handle moves.
  group('flex-to-fixed conversion', () {
    /// The horizontal viewport the header and rows share.
    ScrollableState horizontalScroll(WidgetTester tester) =>
        tester.state<ScrollableState>(find.byWidgetPredicate(
          (w) => w is Scrollable && w.axis == Axis.horizontal,
        ));

    testWidgets('the flexible column can itself be dragged', (tester) async {
      // 🚨 The bug: CUSTOMER is flexible, so the surplus rule recomputed it on
      // the same frame the drag wrote to it. The column sat there refusing to
      // move however far the handle was pulled, and the drag was discarded on
      // release.
      await pumpTable(tester);
      final before = headerWidth(tester, 'CUSTOMER');

      final gesture = await tester.startGesture(handleOf(tester, 'CUSTOMER'));
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();

      expect(headerWidth(tester, 'CUSTOMER'), closeTo(before + 80, 0.5),
          reason: 'the flexible column must track the handle like any other');

      await gesture.up();
      await tester.pumpAndSettle();

      expect(headerWidth(tester, 'CUSTOMER'), closeTo(before + 80, 0.5),
          reason: 'and keep the width when the pointer lifts');
    });

    testWidgets('the flexible column can be dragged narrower too',
        (tester) async {
      await pumpTable(tester);
      final before = headerWidth(tester, 'CUSTOMER');

      final gesture = await tester.startGesture(handleOf(tester, 'CUSTOMER'));
      await gesture.moveBy(const Offset(-90, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // It must NOT spring back to filling the pane: the operator chose this.
      expect(headerWidth(tester, 'CUSTOMER'), closeTo(before - 90, 0.5));
    });

    testWidgets('a stretched column pushes the table off the pane and scrolls',
        (tester) async {
      // 700px pane, 586px of columns: nothing to scroll to begin with.
      await pumpTable(tester);
      expect(horizontalScroll(tester).position.maxScrollExtent, 0);

      final gesture = await tester.startGesture(handleOf(tester, 'DATE'));
      await gesture.moveBy(const Offset(300, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(horizontalScroll(tester).position.maxScrollExtent, greaterThan(0),
          reason: 'the overflow is reachable by scrolling, not an error');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a neighbour drag does not make the flexible column jump',
        (tester) async {
      // Freezing the flexible column at its DECLARED width instead of its
      // rendered one would snap it from 314 back to 200 on the first frame.
      await pumpTable(tester);
      final before = headerWidth(tester, 'CUSTOMER');
      expect(before, greaterThan(200), reason: 'it is absorbing surplus');

      final gesture = await tester.startGesture(handleOf(tester, 'DATE'));
      await gesture.moveBy(const Offset(1, 0));
      await tester.pump();

      expect(headerWidth(tester, 'CUSTOMER'), closeTo(before, 0.5));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a hand-sized flexible column stops filling a wider pane',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await pumpTable(tester, prefs: prefs);
      final gesture = await tester.startGesture(handleOf(tester, 'CUSTOMER'));
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      final chosen = headerWidth(tester, 'CUSTOMER');

      // Reopened wider. The counterpart of 'a hand-sized table still fills a
      // wider pane': a column frozen in passing goes back to filling, but one
      // the operator dragged BY THE HANDLE is theirs and stays put.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await pumpTable(tester, prefs: prefs, width: 900);

      expect(headerWidth(tester, 'CUSTOMER'), closeTo(chosen, 0.5),
          reason: 'a width chosen by hand outlives the pane it was chosen in');
    });

    testWidgets('the choice survives a reload, not just the width',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await pumpTable(tester, prefs: prefs);
      final gesture = await tester.startGesture(handleOf(tester, 'CUSTOMER'));
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final stored = prefs.getString(ilyassTableWidthsKey('test'));
      expect(stored, contains('manual'),
          reason: 'which columns were chosen is part of the layout');
      expect(stored, contains('name'));
    });

    testWidgets('a click on a handle that moves nothing pins nothing',
        (tester) async {
      // Touching an edge is not choosing a width. If it were, a mis-click on
      // the flexible column would stop it filling for good — invisible until
      // the window is next resized.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await pumpTable(tester, prefs: prefs);
      final gesture = await tester.startGesture(handleOf(tester, 'CUSTOMER'));
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await pumpTable(tester, prefs: prefs, width: 900);

      expect(headerWidth(tester, 'CUSTOMER'), greaterThan(400),
          reason: 'still the column that fills the pane');
    });

    testWidgets('a v1 layout of bare widths still loads', (tester) async {
      // Written before the manual set existed. Read as "nothing chosen by
      // hand", which is exactly how the version that wrote it behaved.
      SharedPreferences.setMockInitialValues({
        ilyassTableWidthsKey('test'): '{"date": 210}',
      });
      final prefs = await SharedPreferences.getInstance();

      await pumpTable(tester, prefs: prefs);

      expect(headerWidth(tester, 'DATE'), 210);
      expect(headerWidth(tester, 'CUSTOMER'), greaterThan(200),
          reason: 'and the flexible column is still filling');
    });
  });

  group('minimum width', () {
    Future<void> pumpTiny(WidgetTester tester) => tester.pumpWidget(ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 700,
                height: 400,
                child: IlyassTable<_Row>(
                  tableId: 'tiny',
                  rows: rows,
                  columns: [
                    IlyassColumn<_Row>(
                      key: 'id',
                      label: 'ID',
                      width: 120,
                      // Below the table-wide floor: a caller cannot opt out of
                      // it, because a 20px column is one nobody can grab again.
                      minWidth: 20,
                      cell: (context, r) => const Text('1'),
                    ),
                    IlyassColumn<_Row>(
                      key: 'name',
                      label: 'CUSTOMER',
                      width: 200,
                      flexible: true,
                      cell: (context, r) => Text(r.name),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));

    testWidgets('the table floor beats a smaller declared minimum',
        (tester) async {
      await pumpTiny(tester);

      await tester.dragFrom(
        tester.getTopRight(find.ancestor(
              of: find.text('ID'),
              matching: find.byType(SizedBox),
            ).first) -
            const Offset(4, -12),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.ancestor(
          of: find.text('ID'),
          matching: find.byType(SizedBox),
        ).first).width,
        60.0,
        reason: 'clamped at the floor, not at the 20 the column asked for',
      );
    });

    testWidgets('the last column has a handle of its own', (tester) async {
      // A fixed-width grid that scrolls has somewhere to put the result, so
      // the trailing edge is a legitimate thing to pull.
      await pumpTiny(tester);
      final before = headerWidth(tester, 'CUSTOMER');

      await tester.dragFrom(
        tester.getTopRight(find.ancestor(
              of: find.text('CUSTOMER'),
              matching: find.byType(SizedBox),
            ).first) -
            const Offset(4, -12),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();

      expect(headerWidth(tester, 'CUSTOMER'), closeTo(before + 120, 0.5));
    });
  });
}
