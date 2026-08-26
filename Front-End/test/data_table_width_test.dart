// Pins that the app's DataTable grids FILL their pane instead of leaving a dead
// gap down the right-hand side.
//
// 🚨 The screens this was written for — stock, documents, products — have since
// moved to `IlyassTable`, which solves the same problem its own way (see
// `ilyass_table_test.dart`). What still runs a DataTable, and so still depends
// on the two behaviours below, is the IMPORT PREVIEW
// (`product_import_screen`) and the SESSION LIST (`session_list_screen`) —
// both of which use exactly the `IntrinsicColumnWidth(flex: 1)` +
// `ConstrainedBox(minWidth: c.maxWidth)` pair this pins.
//
// Reported 2026-08-06 with a screenshot: the table hugged the left ~58% of the
// window. Two independent causes, and fixing either alone leaves the gap:
//
//   1. A horizontal `SingleChildScrollView` hands its child UNBOUNDED width, so
//      `DataTable` sized itself to its intrinsic content.
//   2. Even given a width, `DataTable` only stretches a column that is the
//      *single* text column (all others `numeric`) — that one gets
//      `IntrinsicColumnWidth(flex: 1.0)` and every other column gets a plain
//      `IntrinsicColumnWidth()`. All five columns here are text, so NONE had
//      flex and the table stayed hugged no matter how much width it was offered.
//
// This reproduces the exact widget shape rather than pumping the whole screen
// (which needs Riverpod, Drift and a company). Nothing else in the suite can
// catch it: the layout is legal, renders without overflow, and `dart analyze` is
// clean either way.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _paneWidth = 900.0;

/// The table as the stock screen builds it. [flexProductColumn] and
/// [constrainToPane] toggle the two fixes so the test can prove each is needed.
Widget _table({
  required bool flexProductColumn,
  required bool constrainToPane,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: _paneWidth,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constrainToPane ? c.maxWidth : 0,
                ),
                child: DataTable(
                  showCheckboxColumn: false,
                  columnSpacing: 12,
                  horizontalMargin: 12,
                  columns: [
                    DataColumn(
                      label: const Text('Produit'),
                      columnWidth: flexProductColumn
                          ? const IntrinsicColumnWidth(flex: 1)
                          : null,
                    ),
                    const DataColumn(label: Text('Code')),
                    const DataColumn(label: Text('Quantité')),
                    const DataColumn(label: Text('Valeur (total)')),
                    const DataColumn(label: Text('Actions')),
                  ],
                  rows: const [
                    DataRow(cells: [
                      DataCell(Text('Pepsi')),
                      DataCell(Text('0001')),
                      DataCell(Text('477')),
                      DataCell(Text('4770.00 MAD')),
                      DataCell(Icon(Icons.add)),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('Shwarma')),
                      DataCell(Text('0002')),
                      DataCell(Text('7')),
                      DataCell(Text('245.00 MAD')),
                      DataCell(Icon(Icons.add)),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

double _tableWidth(WidgetTester tester) =>
    tester.getSize(find.byType(DataTable)).width;

void main() {
  testWidgets('the table fills the pane — no dead space on the right',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
        _table(flexProductColumn: true, constrainToPane: true));

    expect(_tableWidth(tester), _paneWidth,
        reason: 'the table must occupy the whole pane');
  });

  testWidgets('without the width constraint it collapses — the original bug',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Unbounded width: the table still collapses to its content.
    await tester.pumpWidget(
        _table(flexProductColumn: true, constrainToPane: false));
    expect(_tableWidth(tester), lessThan(_paneWidth),
        reason: 'this is the original bug — unbounded width wins');
  });

  testWidgets('the flex column decides WHERE the surplus goes', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Measured, not assumed: with no flex column `RenderTable` still fills the
    // offered width, but spreads the surplus EQUALLY across all five — so the
    // 4-character "Code" column gets as much slack as the product name, which
    // is the wrong-looking layout even though the gap is gone. The flex column
    // is what makes the product name absorb it.
    Future<double> productColumnWidth({required bool flex}) async {
      await tester.pumpWidget(
          _table(flexProductColumn: flex, constrainToPane: true));
      await tester.pumpAndSettle();
      // Distance between the two headings = the product column's width.
      return tester.getTopLeft(find.text('Code')).dx -
          tester.getTopLeft(find.text('Produit')).dx;
    }

    final withoutFlex = await productColumnWidth(flex: false);
    final withFlex = await productColumnWidth(flex: true);

    expect(withFlex, greaterThan(withoutFlex),
        reason: 'the product name should take the slack, not every column '
            'equally');
  });

  testWidgets('a long product name is never squeezed by the stretch',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
        _table(flexProductColumn: true, constrainToPane: true));
    await tester.pumpAndSettle();

    // IntrinsicColumnWidth(flex:) keeps the intrinsic width as the FLOOR — a
    // FlexColumnWidth would have allowed the name to be crushed instead.
    expect(tester.takeException(), isNull);
    expect(find.text('Shwarma'), findsOneWidget);
  });

  testWidgets('a pane narrower than the content still scrolls, not overflows',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: c.maxWidth),
                  child: DataTable(
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    columns: const [
                      DataColumn(
                        label: Text('Produit'),
                        columnWidth: IntrinsicColumnWidth(flex: 1),
                      ),
                      DataColumn(label: Text('Code')),
                      DataColumn(label: Text('Quantité')),
                      DataColumn(label: Text('Valeur (total)')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: const [
                      DataRow(cells: [
                        DataCell(Text('Sparkling Water 500ml')),
                        DataCell(Text('0007')),
                        DataCell(Text('150')),
                        DataCell(Text('900.00 MAD')),
                        DataCell(Icon(Icons.add)),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));

    // `minWidth` only — never a max — so the table grows past a cramped pane and
    // the scroll view handles it. A RenderFlex overflow here would be the
    // regression this guards (tablets are 10-inch).
    expect(tester.takeException(), isNull);
    expect(_tableWidth(tester), greaterThan(300));
  });

  // ── The same shape in the other grids ─────────────────────────────────────
  //
  // `product_import_screen` and `session_list_screen` both put a DataTable
  // inside a horizontal SingleChildScrollView. These pin the two behaviours
  // their fixes rely on: a numeric column must not steal the slack, and a
  // single text column must absorb it.

  testWidgets('a numeric column never steals the slack from a text column',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The import preview's shape: mixed numeric/text, flex on the first text
    // column.
    Widget build({required bool flex}) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: _paneWidth,
              child: LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: c.maxWidth),
                    child: DataTable(
                      columns: [
                        DataColumn(
                          label: const Text('Nom'),
                          columnWidth: flex
                              ? const IntrinsicColumnWidth(flex: 1)
                              : null,
                        ),
                        const DataColumn(label: Text('Code')),
                        const DataColumn(label: Text('Prix'), numeric: true),
                        const DataColumn(label: Text('Stock'), numeric: true),
                      ],
                      rows: const [
                        DataRow(cells: [
                          DataCell(Text('Coca-Cola 330ml')),
                          DataCell(Text('0003')),
                          DataCell(Text('10.00')),
                          DataCell(Text('297')),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    Future<double> nameWidth({required bool flex}) async {
      await tester.pumpWidget(build(flex: flex));
      await tester.pumpAndSettle();
      return tester.getTopLeft(find.text('Code')).dx -
          tester.getTopLeft(find.text('Nom')).dx;
    }

    expect(await nameWidth(flex: true),
        greaterThan(await nameWidth(flex: false)),
        reason: 'the product name must absorb the width, not the price column');
  });

  testWidgets('a table with many columns still fills without overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // documents_screen can show 15 user-toggled columns; the import preview is
    // driven entirely by the user's CSV. Neither may overflow.
    final keys = List.generate(12, (i) => 'C$i');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: _paneWidth,
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: c.maxWidth),
                child: DataTable(
                  columnSpacing: 24,
                  columns: [
                    for (var i = 0; i < keys.length; i++)
                      DataColumn(
                        label: Text(keys[i]),
                        columnWidth:
                            i == 0 ? const IntrinsicColumnWidth(flex: 1) : null,
                      ),
                  ],
                  rows: [
                    DataRow(
                      cells: [for (final k in keys) DataCell(Text('$k-value'))],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Wider than the pane → it scrolls, which is correct; the guarantee is
    // simply that it never renders an overflow.
    expect(_tableWidth(tester), greaterThanOrEqualTo(_paneWidth));
  });
}
