// The Stock Moves filter: the period rides along with the other filters, any
// change reads from the top again, and loading more keeps every filter.
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/stock/stock_moves_provider.dart';

void main() {
  late ProviderContainer c;
  StockMovesFilterNotifier notifier() =>
      c.read(stockMovesFilterProvider.notifier);
  StockMovesFilter filter() => c.read(stockMovesFilterProvider);

  final september =
      DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30));

  setUp(() {
    c = ProviderContainer();
    addTearDown(c.dispose);
  });

  test('starts unfiltered, one page deep', () {
    expect(filter().period, isNull);
    expect(filter().isFiltered, isFalse);
    expect(filter().limit, StockMovesFilter.pageSize);
  });

  test('a period filters, and survives the other filters changing', () {
    notifier().setPeriod(september);
    expect(filter().isFiltered, isTrue);

    notifier()
      ..setSearch('tea')
      ..setWarehouse(10);

    expect(filter().period, september);
    expect(filter().search, 'tea');
    expect(filter().warehouseId, 10);
  });

  test('loading more keeps every filter, the period included', () {
    notifier()
      ..setPeriod(september)
      ..setWarehouse(10)
      ..loadMore();

    expect(filter().limit, StockMovesFilter.pageSize * 2);
    expect(filter().period, september);
    expect(filter().warehouseId, 10);
  });

  test('a new period reads from the top again', () {
    notifier()
      ..loadMore()
      ..loadMore()
      ..setPeriod(september);

    expect(filter().limit, StockMovesFilter.pageSize);
  });

  test('clearing drops the period with the rest', () {
    notifier()
      ..setPeriod(september)
      ..setSearch('tea')
      ..clear();

    expect(filter(), const StockMovesFilter());
  });
}
