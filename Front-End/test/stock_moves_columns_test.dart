// The Stock Moves column choice: which columns show, that the choice survives
// a restart, that the product can never be hidden, and that the export sees
// exactly the columns — and the order — the screen shows.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:pos_app/stock/stock_moves_columns.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> launch([Map<String, Object>? stored]) async {
    if (stored != null) SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every column shows until the operator hides one', () async {
    final c = await launch();

    expect(c.read(stockMoveVisibleColumnsProvider).values, everyElement(true));
    expect(c.read(stockMoveVisibleColumnsProvider).keys, kStockMoveColumns);
  });

  test('a hidden column stays hidden on the next launch', () async {
    final first = await launch();
    first
        .read(stockMoveVisibleColumnsProvider.notifier)
        .setVisible('status', false);

    // A fresh container over the same store is the next launch.
    final next = await launch();

    expect(next.read(stockMoveVisibleColumnsProvider)['status'], isFalse);
    expect(next.read(stockMoveVisibleColumnsProvider)['date'], isTrue);
  });

  test('the product cannot be hidden — not by a toggle, not by a stored value',
      () async {
    final c = await launch({
      'stockMoves.visibleColumns': '{"product": false, "to": false}',
    });

    expect(c.read(stockMoveVisibleColumnsProvider)['product'], isTrue);
    expect(c.read(stockMoveVisibleColumnsProvider)['to'], isFalse);

    c
        .read(stockMoveVisibleColumnsProvider.notifier)
        .setVisible('product', false);
    expect(c.read(stockMoveVisibleColumnsProvider)['product'], isTrue);
  });

  test('a corrupt stored value falls back to showing everything', () async {
    final c = await launch({'stockMoves.visibleColumns': 'not json'});

    expect(c.read(stockMoveVisibleColumnsProvider).values, everyElement(true));
  });

  test('reset shows every column again, on this launch and the next',
      () async {
    final c = await launch();
    c.read(stockMoveVisibleColumnsProvider.notifier)
      ..setVisible('status', false)
      ..setVisible('doneBy', false)
      ..reset();

    expect(c.read(stockMoveVisibleColumnsProvider).values, everyElement(true));
    final next = await launch();
    expect(
        next.read(stockMoveVisibleColumnsProvider).values, everyElement(true));
  });

  test('the export sees the visible columns in the order on screen', () {
    const saved = [
      'quantity',
      'product',
      'date',
      'reference',
      'from',
      'to',
      'status',
      'doneBy',
    ];

    expect(
      visibleStockMoveColumns({'status': false, 'doneBy': false}, saved),
      ['quantity', 'product', 'date', 'reference', 'from', 'to'],
    );
    // Never reordered: the declared order.
    expect(visibleStockMoveColumns(const {}, const []), kStockMoveColumns);
  });
}
