// The product-groups screen after it became an Ilyass Style table.
//
// The screen shows a TREE inside a flat grid, which is the whole risk: the
// hierarchy now lives in one column's indentation and in an expand toggle that
// shares a row with the table's own tap handler. Each test below is one way
// that arrangement can quietly break — a collapsed branch that still renders,
// a chevron that opens the editor instead of the branch, and a search that
// hides a match because its parent is closed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/product/product_group_model.dart';
import 'package:pos_app/product/product_group_provider.dart';
import 'package:pos_app/product/product_groups_screen.dart';
import 'package:pos_app/product/product_model.dart';
import 'package:pos_app/product/product_provider.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProductGroup group(int id, String name, {int? parent, int rank = 0}) =>
    ProductGroup(
      id: id,
      companyId: 1,
      name: name,
      parentGroupId: parent,
      color: '#607D8B',
      rank: rank,
    );

Product product(int id, {int? groupId}) => Product(
      id: id,
      companyId: 1,
      name: 'Product $id',
      productGroupId: groupId,
      price: 10,
      cost: 5,
      color: '#607D8B',
      isTaxInclusivePrice: true,
      isPriceChangeAllowed: false,
      isService: false,
      isUsingDefaultQuantity: true,
      isEnabled: true,
    );

void main() {
  // Beverages ─┬ Hot drinks
  //             └ Cold drinks
  // Desserts
  final tree = <ProductGroup>[
    group(1, 'Beverages'),
    group(2, 'Hot drinks', parent: 1),
    group(3, 'Cold drinks', parent: 1, rank: 1),
    group(4, 'Desserts', rank: 1),
  ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<ProductGroup>? data,
    List<Product> products = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        allProductGroupsProvider
            .overrideWith((ref) => Stream.value(data ?? tree)),
        allProductsListProvider.overrideWith((ref) => Stream.value(products)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProductGroupsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The group's own Name cell, not the Parent cell of one of its children —
  /// "Beverages" is painted three times on this fixture, and only one of them
  /// is the row. The name cell is the one carrying the row's emphasis.
  Finder nameCell(String name) => find.byWidgetPredicate((w) =>
      w is Text && w.data == name && w.style?.fontWeight == FontWeight.w600);

  testWidgets('the tree renders as table rows, children under their parent',
      (tester) async {
    await pumpScreen(tester);

    for (final name in ['Beverages', 'Hot drinks', 'Cold drinks', 'Desserts']) {
      expect(nameCell(name), findsOneWidget);
    }

    // A child sits to the RIGHT of its parent — the indentation IS the
    // hierarchy once the tree is flat.
    final parentX = tester.getTopLeft(nameCell('Beverages')).dx;
    final childX = tester.getTopLeft(nameCell('Hot drinks')).dx;
    expect(childX, greaterThan(parentX));

    // ...and below it, in rank order.
    expect(tester.getTopLeft(nameCell('Hot drinks')).dy,
        greaterThan(tester.getTopLeft(nameCell('Beverages')).dy));
    expect(tester.getTopLeft(nameCell('Cold drinks')).dy,
        greaterThan(tester.getTopLeft(nameCell('Hot drinks')).dy));
  });

  testWidgets('the expand toggle collapses a branch without opening the editor',
      (tester) async {
    await pumpScreen(tester);

    // Only Beverages has children, so it owns the only toggle.
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(nameCell('Hot drinks'), findsNothing);
    expect(nameCell('Cold drinks'), findsNothing);
    expect(nameCell('Beverages'), findsOneWidget);
    expect(nameCell('Desserts'), findsOneWidget);

    // 🚨 The toggle sits inside a row that is itself tappable. If it ever loses
    // the gesture arena, collapsing a branch also opens the group editor.
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(nameCell('Hot drinks'), findsOneWidget);
  });

  testWidgets('search goes flat, so a match under a closed parent still shows',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(nameCell('Cold drinks'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'cold');
    await tester.pumpAndSettle();

    // The match is its own row now — and "Beverages" survives only as that
    // row's Parent cell, never as a row of its own.
    expect(nameCell('Cold drinks'), findsOneWidget);
    expect(nameCell('Beverages'), findsNothing);
    expect(nameCell('Desserts'), findsNothing);
  });

  testWidgets('the products column counts what each group holds',
      (tester) async {
    await pumpScreen(tester, products: [
      product(10, groupId: 1),
      product(11, groupId: 2),
      product(12, groupId: 2),
      product(13), // unassigned — belongs to no group's count
    ]);

    /// Every Text in the same table row as [groupName] — the count is read off
    /// the row itself, so a reordered column cannot make this pass by accident.
    List<String?> rowTexts(String groupName) => tester
        .widgetList<Text>(find.descendant(
          // The outermost Row above the cell is the table row.
          of: find.ancestor(of: nameCell(groupName), matching: find.byType(Row))
              .last,
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
        .toList();

    expect(rowTexts('Beverages'), contains('1'));
    expect(rowTexts('Hot drinks'), contains('2'));
    // The unassigned product counts for nobody.
    expect(rowTexts('Desserts'), contains('0'));
  });

  testWidgets('an empty catalogue offers the create path instead of a grid',
      (tester) async {
    await pumpScreen(tester, data: const []);

    // No grid at all: no selection checkboxes, no rows to tick.
    expect(find.byType(Checkbox), findsNothing);
    expect(
        find.text(AppLocalizations.of(tester.element(find.byType(Scaffold)))
            .noProductGroupsYet),
        findsOneWidget);
  });
}
