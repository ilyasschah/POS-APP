// Column ORDER: the half of the layout that is not width.
//
// The ordering rule that matters is what happens to a column the saved order
// has never heard of. Appending those to the end looks harmless until a new app
// version adds a column — every operator with a saved layout finds it exiled to
// the far right — or until a table with a leading checkbox column has that
// checkbox flung to the end of the row, because the picker's catalogue never
// contained it in the first place.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/ilyass_column_order.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Row {
  const _Row(this.name);
  final String name;
}

void main() {
  group('ilyassApplyColumnOrder', () {
    List<String> apply(List<String> items, List<String> order) =>
        ilyassApplyColumnOrder(items, order, (k) => k);

    test('an empty order leaves the declared order alone', () {
      expect(apply(['a', 'b', 'c'], []), ['a', 'b', 'c']);
    });

    test('items follow the saved order', () {
      expect(apply(['a', 'b', 'c'], ['c', 'a', 'b']), ['c', 'a', 'b']);
    });

    test('a key the order never heard of keeps its declared index', () {
      // 'select' is index 0 and absent from the order — the checkbox column.
      expect(
        apply(['select', 'a', 'b'], ['b', 'a']),
        ['select', 'b', 'a'],
        reason: 'a leading column the picker cannot see must stay leading',
      );
    });

    test('a new column lands where the screen declares it, not at the end', () {
      // 'cost' is declared at index 1 and was added after this layout was
      // saved. Appending it would put it after 'name'.
      expect(apply(['name', 'cost', 'price'], ['price', 'name']),
          ['price', 'cost', 'name']);
    });

    test('an order naming a column that is switched off is skipped', () {
      expect(apply(['a', 'c'], ['c', 'b', 'a']), ['c', 'a']);
    });

    test('a duplicated key is placed once', () {
      expect(apply(['a', 'b'], ['b', 'b', 'a']), ['b', 'a']);
    });
  });

  group('the order store', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<ProviderContainer> container() async {
      final prefs = await SharedPreferences.getInstance();
      return ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    }

    test('an order is written to preferences under its own key', () async {
      final c = await container();
      addTearDown(c.dispose);

      c
          .read(ilyassColumnOrderProvider.notifier)
          .setOrder('products', ['price', 'name']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(ilyassTableOrderKey('products')),
          ['price', 'name']);
    });

    test('a saved order is picked up on the next launch', () async {
      SharedPreferences.setMockInitialValues({
        ilyassTableOrderKey('products'): ['price', 'name'],
        ilyassTableOrderKey('documents'): ['Total'],
        'unrelated.pref': 'ignored',
      });
      final c = await container();
      addTearDown(c.dispose);

      final orders = c.read(ilyassColumnOrderProvider);
      expect(orders['products'], ['price', 'name']);
      expect(orders['documents'], ['Total']);
      expect(orders.containsKey('unrelated.pref'), isFalse,
          reason: 'the sweep must only claim its own key prefix');
    });

    test('reset forgets the table, on disk as well as in memory', () async {
      final c = await container();
      addTearDown(c.dispose);
      final notifier = c.read(ilyassColumnOrderProvider.notifier);

      notifier.setOrder('products', ['price', 'name']);
      notifier.reset('products');

      expect(c.read(ilyassColumnOrderProvider)['products'], isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(ilyassTableOrderKey('products')), isNull);
    });

    test('one table\'s order does not disturb another\'s', () async {
      final c = await container();
      addTearDown(c.dispose);
      final notifier = c.read(ilyassColumnOrderProvider.notifier);

      notifier.setOrder('products', ['a']);
      notifier.setOrder('documents', ['b']);
      notifier.reset('products');

      expect(c.read(ilyassColumnOrderProvider)['documents'], ['b']);
    });
  });

  group('IlyassTable renders in the saved order', () {
    Future<void> pump(WidgetTester tester, SharedPreferences prefs) =>
        tester.pumpWidget(ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 400,
                child: IlyassTable<_Row>(
                  tableId: 'ordered',
                  rows: const [_Row('Cafe Atlas')],
                  columns: [
                    IlyassColumn<_Row>(
                      key: 'select',
                      label: 'SELECT',
                      width: 64,
                      cell: (context, r) => const Icon(Icons.check_box),
                    ),
                    IlyassColumn<_Row>(
                      key: 'name',
                      label: 'CUSTOMER',
                      width: 200,
                      flexible: true,
                      cell: (context, r) => Text(r.name),
                    ),
                    IlyassColumn<_Row>(
                      key: 'total',
                      label: 'TOTAL',
                      width: 140,
                      numeric: true,
                      cell: (context, r) => const Text('84 MAD'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));

    /// Header labels left to right.
    List<String> headerOrder(WidgetTester tester) {
      final labels = <(double, String)>[];
      for (final text in ['CUSTOMER', 'TOTAL']) {
        labels.add((tester.getTopLeft(find.text(text)).dx, text));
      }
      labels.sort((a, b) => a.$1.compareTo(b.$1));
      return [for (final l in labels) l.$2];
    }

    testWidgets('with no saved order, the declared order stands',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester, await SharedPreferences.getInstance());

      expect(headerOrder(tester), ['CUSTOMER', 'TOTAL']);
    });

    testWidgets('a saved order moves the columns', (tester) async {
      SharedPreferences.setMockInitialValues({
        ilyassTableOrderKey('ordered'): ['total', 'name'],
      });
      await pump(tester, await SharedPreferences.getInstance());

      expect(headerOrder(tester), ['TOTAL', 'CUSTOMER']);
    });

    testWidgets('the checkbox column stays leading whatever the order',
        (tester) async {
      // 'select' is never in the picker's catalogue, so it is never in a saved
      // order — and must not drift to the end because of it.
      SharedPreferences.setMockInitialValues({
        ilyassTableOrderKey('ordered'): ['total', 'name'],
      });
      await pump(tester, await SharedPreferences.getInstance());

      expect(
        tester.getTopLeft(find.byIcon(Icons.check_box)).dx,
        lessThan(tester.getTopLeft(find.text('TOTAL')).dx),
      );
    });

    testWidgets('reordering rebuilds the table underneath the picker',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await pump(tester, prefs);
      expect(headerOrder(tester), ['CUSTOMER', 'TOTAL']);

      // What the picker does when a row is dropped.
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(IlyassTable<_Row>)),
      );
      scope
          .read(ilyassColumnOrderProvider.notifier)
          .setOrder('ordered', ['total', 'name']);
      await tester.pump();

      expect(headerOrder(tester), ['TOTAL', 'CUSTOMER'],
          reason: 'the table watches the order, it does not read it once');
    });

    testWidgets('a dragged width follows its column to the new position',
        (tester) async {
      // Widths are keyed by column key, not by index — reordering must not
      // hand a column its neighbour's width.
      SharedPreferences.setMockInitialValues({
        ilyassTableWidthsKey('ordered'): '{"widths":{"total":300},"manual":["total"]}',
        ilyassTableOrderKey('ordered'): ['total', 'name'],
      });
      await pump(tester, await SharedPreferences.getInstance());

      final totalWidth = tester
          .getSize(find.ancestor(
            of: find.text('TOTAL'),
            matching: find.byType(SizedBox),
          ).first)
          .width;
      expect(totalWidth, 300);
    });
  });

  group('the column picker', () {
    late Map<String, bool> visible;

    /// Opens the picker over a bare screen and settles it.
    Future<void> openPicker(
      WidgetTester tester,
      SharedPreferences prefs, {
      List<IlyassPickerColumn>? columns,
      VoidCallback? onReset,
    }) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showIlyassColumnPicker(
                  context: context,
                  tableId: 'picker',
                  columns: columns ??
                      const [
                        IlyassPickerColumn(
                            key: 'name', label: 'Name', mandatory: true),
                        IlyassPickerColumn(key: 'code', label: 'Code'),
                        IlyassPickerColumn(key: 'price', label: 'Price'),
                      ],
                  isVisible: (key) => visible[key] ?? false,
                  onVisibleChanged: (key, value) => visible[key] = value,
                  onReset: onReset,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    setUp(() {
      visible = {'name': true, 'code': true, 'price': true};
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('every row carries a drag handle', (tester) async {
      await openPicker(tester, await SharedPreferences.getInstance());

      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));
    });

    // 🚨 The point of the whole feature for a locked column: an operator who
    // cannot HIDE the product name must still be able to MOVE it.
    testWidgets('a mandatory column is locked but still draggable',
        (tester) async {
      await openPicker(tester, await SharedPreferences.getInstance());

      final nameRow = find.ancestor(
        of: find.text('Name'),
        matching: find.byType(ListTile),
      );

      final nameCheckbox = tester.widget<Checkbox>(find.descendant(
        of: nameRow,
        matching: find.byType(Checkbox),
      ));
      expect(nameCheckbox.onChanged, isNull,
          reason: 'Name cannot be switched off');

      // It has a handle of its own all the same.
      expect(
        find.descendant(
            of: nameRow, matching: find.byIcon(Icons.drag_indicator)),
        findsOneWidget,
      );
    });

    testWidgets('the last visible column cannot be switched off',
        (tester) async {
      visible = {'name': false, 'code': true, 'price': false};
      await openPicker(
        tester,
        await SharedPreferences.getInstance(),
        columns: const [
          IlyassPickerColumn(key: 'name', label: 'Name'),
          IlyassPickerColumn(key: 'code', label: 'Code'),
          IlyassPickerColumn(key: 'price', label: 'Price'),
        ],
      );

      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();

      expect(visible['code'], isTrue,
          reason: 'a table with no columns is not a table');
    });

    testWidgets('toggling one column redraws the checkboxes', (tester) async {
      await openPicker(tester, await SharedPreferences.getInstance());

      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();

      expect(visible['code'], isFalse);
      final codeCheckbox = tester.widget<Checkbox>(find.descendant(
        of: find.ancestor(
            of: find.text('Code'), matching: find.byType(ListTile)),
        matching: find.byType(Checkbox),
      ));
      expect(codeCheckbox.value, isFalse,
          reason: 'the dialog re-reads the caller\'s state after a toggle');
    });

    testWidgets('dropping a row writes the whole catalogue, hidden included',
        (tester) async {
      visible = {'name': true, 'code': false, 'price': true};
      final prefs = await SharedPreferences.getInstance();
      await openPicker(tester, prefs);

      // Drag Price (last) up above Name (first).
      final handle = find
          .descendant(
            of: find.ancestor(
                of: find.text('Price'), matching: find.byType(ListTile)),
            matching: find.byIcon(Icons.drag_indicator),
          )
          .first;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 200));
      for (var i = 0; i < 14; i++) {
        await gesture.moveBy(const Offset(0, -10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final saved = prefs.getStringList(ilyassTableOrderKey('picker'));
      expect(saved, isNotNull);
      expect(saved!.first, 'price');
      expect(saved, contains('code'),
          reason: 'a hidden column keeps its place for when it comes back');
      expect(saved.length, 3);
    });

    testWidgets('reset clears the order and calls the caller back',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        ilyassTableOrderKey('picker'): ['price', 'code', 'name'],
      });
      final prefs = await SharedPreferences.getInstance();
      var resets = 0;
      await openPicker(tester, prefs, onReset: () => resets++);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(resets, 1);
      expect(prefs.getStringList(ilyassTableOrderKey('picker')), isNull,
          reason: 'reset means the whole layout, not half of it');
    });
  });
}
