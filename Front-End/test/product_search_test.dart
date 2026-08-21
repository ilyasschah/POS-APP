// Pins the ONE product-search predicate now shared by the POS menu and the
// Products management screen (backlog item 17).
//
// It is a single function on purpose. The POS menu's search was inline in
// `menu_screen`, and copying it into `products_screen` is exactly the mistake
// item 24 already paid for — `saveAndSuspend` carried its own copy of the order
// save, drifted from the original, and silently duplicated orders. These tests
// exist so the two screens can only ever disagree deliberately.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/product/product_model.dart';
import 'package:pos_app/product/product_search.dart';
import 'package:pos_app/product/product_search_bar.dart';

Product product({
  int id = 1,
  String name = 'Espresso',
  String? code = 'ESP-01',
  List<String> barcodes = const ['5901234123457'],
  bool isEnabled = true,
}) =>
    Product(
      id: id,
      companyId: 25,
      name: name,
      code: code,
      price: 12,
      isTaxInclusivePrice: true,
      isPriceChangeAllowed: false,
      isService: false,
      isUsingDefaultQuantity: false,
      isEnabled: isEnabled,
      cost: 4,
      color: 'Transparent',
      barcodes: barcodes,
      syncStatus: 'synced',
    );

void main() {
  group('scope selects the field', () {
    final p = product(name: 'Espresso', code: 'ESP-01', barcodes: ['590123']);

    test('Name matches the name only', () {
      expect(productMatchesSearch(p, 'espr', ProductSearchScope.name), isTrue);
      expect(productMatchesSearch(p, 'ESP-0', ProductSearchScope.name), isFalse);
      expect(productMatchesSearch(p, '590', ProductSearchScope.name), isFalse);
    });

    test('Code matches the code only', () {
      expect(productMatchesSearch(p, 'esp-0', ProductSearchScope.code), isTrue);
      expect(
          productMatchesSearch(p, 'espresso', ProductSearchScope.code), isFalse);
    });

    test('Barcode matches the barcode only', () {
      expect(productMatchesSearch(p, '9012', ProductSearchScope.barcode),
          isTrue);
      expect(productMatchesSearch(p, 'espresso', ProductSearchScope.barcode),
          isFalse);
    });

    test('All fields matches any of the three', () {
      for (final q in ['espresso', 'esp-01', '590123']) {
        expect(productMatchesSearch(p, q, ProductSearchScope.allFields), isTrue,
            reason: q);
      }
      expect(productMatchesSearch(p, 'croissant', ProductSearchScope.allFields),
          isFalse);
    });
  });

  test('matching is case-insensitive and ignores surrounding blanks', () {
    final p = product(name: 'Café Crème');
    expect(productMatchesSearch(p, '  CRÈME ', ProductSearchScope.name), isTrue);
  });

  test('an empty query matches everything — the list is not blanked', () {
    // Checked against a product with NO code under the Code scope, which is the
    // case the early-out actually protects: `null.contains('')` is not true, so
    // without it an empty box would hide every codeless product instead of
    // showing the whole catalogue.
    for (final q in ['', '   ']) {
      for (final scope in ProductSearchScope.all) {
        expect(
          productMatchesSearch(product(code: null, barcodes: const []), q,
              scope),
          isTrue,
          reason: 'query "$q" under $scope',
        );
      }
    }
  });

  test('a product without a code is not a match, and does not throw', () {
    final p = product(code: null);
    expect(productMatchesSearch(p, 'esp', ProductSearchScope.code), isFalse);
    expect(productMatchesSearch(p, 'espresso', ProductSearchScope.allFields),
        isTrue);
  });

  test('an unknown scope falls back to Name rather than matching nothing', () {
    // A terminal can hold a stale `Menu.DefaultSearch` value. Blanking the
    // catalogue would look like the products were deleted.
    expect(productMatchesSearch(product(), 'espresso', 'Supplier'), isTrue);
  });

  group('secondary barcodes', () {
    // `Product.barcodes` only ever carries the single `products.barcode`
    // column; the rest live in the `barcodes` table, which is what the product
    // editor's Barcodes tab writes to. The Products screen passes them in.
    final p = product(barcodes: ['111']);
    const extra = ['222', '333'];

    test('are found under Barcode and All fields when supplied', () {
      expect(
        productMatchesSearch(p, '222', ProductSearchScope.barcode,
            extraBarcodes: extra),
        isTrue,
      );
      expect(
        productMatchesSearch(p, '333', ProductSearchScope.allFields,
            extraBarcodes: extra),
        isTrue,
      );
    });

    test('are not found when not supplied — the POS menu keeps its behaviour',
        () {
      expect(productMatchesSearch(p, '222', ProductSearchScope.barcode), isFalse);
    });

    test('never leak into a Name or Code search', () {
      expect(
        productMatchesSearch(p, '222', ProductSearchScope.name,
            extraBarcodes: extra),
        isFalse,
      );
      expect(
        productMatchesSearch(p, '222', ProductSearchScope.code,
            extraBarcodes: extra),
        isFalse,
      );
    });
  });

  test('a DISABLED product still matches — that policy belongs to the caller',
      () {
    // Load-bearing: the POS menu filters `isEnabled` itself before calling, but
    // the Products management screen has to be able to find a disabled product
    // in order to re-enable it (it renders them struck through).
    final p = product(name: 'Retired item', isEnabled: false);
    expect(productMatchesSearch(p, 'retired', ProductSearchScope.name), isTrue);
  });

  group('findProductByBarcode — the scan path', () {
    // The user hit this live: 1787888632499 was added in a product's Barcodes
    // tab, the Products screen found it, and the till did nothing with it.
    final primary = product(id: 1, name: 'Coke', barcodes: ['111']);
    final secondaryOnly =
        product(id: 2, name: 'Test2', code: '000077', barcodes: []);
    final catalogue = [primary, secondaryOnly];
    const index = {
      2: ['1787888632499'],
    };

    test('finds a product by a barcode from the Barcodes tab', () {
      expect(
        findProductByBarcode(catalogue, '1787888632499',
            extraBarcodes: index)?.id,
        2,
      );
    });

    test('still finds one by its primary barcode', () {
      expect(findProductByBarcode(catalogue, '111', extraBarcodes: index)?.id,
          1);
    });

    test('matches EXACTLY — a prefix must never ring up the wrong product', () {
      // The search bar filters on substrings; the scanner must not.
      expect(findProductByBarcode(catalogue, '17878', extraBarcodes: index),
          isNull);
      expect(findProductByBarcode(catalogue, '11', extraBarcodes: index),
          isNull);
    });

    test('an unknown barcode returns null', () {
      expect(findProductByBarcode(catalogue, '999', extraBarcodes: index),
          isNull);
    });

    test('blank input never matches', () {
      for (final q in ['', '   ']) {
        expect(findProductByBarcode(catalogue, q, extraBarcodes: index), isNull,
            reason: 'query "$q"');
      }
    });

    test('a primary barcode wins over another product listing it as an alternate',
        () {
      // Nothing in either database stops two products sharing a barcode. The
      // old code took whatever Drift returned first; this is the tie-break.
      final owner = product(id: 7, name: 'Owner', barcodes: ['555']);
      final alternate = product(id: 3, name: 'Alternate', barcodes: []);
      // `alternate` comes first in the list, so a naive scan would pick it.
      final result = findProductByBarcode([alternate, owner], '555',
          extraBarcodes: const {
            3: ['555'],
          });
      expect(result?.id, 7);
    });

    test('the caller decides what is sellable — disabled products are not filtered here',
        () {
      final disabled = product(id: 9, isEnabled: false, barcodes: ['888']);
      expect(findProductByBarcode([disabled], '888')?.id, 9,
          reason: 'menu_screen passes an already-filtered list');
    });
  });

  group('ProductSearchBar', () {
    Future<void> pump(
      WidgetTester tester, {
      required String query,
      String scope = ProductSearchScope.allFields,
      bool showScopeButtons = true,
      ValueChanged<String>? onScopeChanged,
      ValueChanged<String>? onQueryChanged,
    }) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProductSearchBar(
            controller: TextEditingController(text: query),
            query: query,
            scope: scope,
            hintText: 'Search products...',
            showScopeButtons: showScopeButtons,
            onQueryChanged: onQueryChanged ?? (_) {},
            onScopeChanged: onScopeChanged ?? (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows one button per scope', (tester) async {
      await pump(tester, query: '');
      expect(find.byType(InkWell), findsNWidgets(ProductSearchScope.all.length));
    });

    testWidgets('hides the scope buttons when the caller asks it to',
        (tester) async {
      // The POS menu gates them on `Menu.ShowSearchOptions`; the Products
      // screen never does.
      await pump(tester, query: '', showScopeButtons: false);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('tapping a scope reports it back with its stored value',
        (tester) async {
      String? picked;
      await pump(tester, query: '', onScopeChanged: (s) => picked = s);
      await tester.tap(find.byType(InkWell).last);
      // Last in display order is Name — the value must be the English constant
      // that `Menu.DefaultSearch` persists, never a translated label.
      expect(picked, ProductSearchScope.name);
    });

    testWidgets('the clear button appears only with text, and empties the query',
        (tester) async {
      await pump(tester, query: '');
      expect(find.byType(IconButton), findsNothing);

      String? cleared;
      await pump(tester, query: 'esp', onQueryChanged: (v) => cleared = v);
      expect(find.byType(IconButton), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      expect(cleared, '');
    });
  });
}
