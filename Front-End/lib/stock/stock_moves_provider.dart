import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/stock/stock_move_line.dart';

/// What the Stock Moves screen is showing: its filters, and how deep into the
/// history it has scrolled.
@immutable
class StockMovesFilter {
  const StockMovesFilter({
    this.warehouseId,
    this.search = '',
    this.period,
    this.limit = pageSize,
  });

  /// Lines read per page. About twenty screens of rows on a 10-inch tablet —
  /// enough that scrolling rarely waits, few enough that the first read is
  /// instant.
  static const int pageSize = 200;

  final int? warehouseId;
  final String search;

  /// Whole days, both ends included — the app's range picker hands back
  /// calendar days, not instants.
  final DateTimeRange? period;

  /// Document lines to read. Grows by [pageSize] as the table nears its end.
  final int limit;

  bool get isFiltered =>
      warehouseId != null || search.isNotEmpty || period != null;

  @override
  bool operator ==(Object other) =>
      other is StockMovesFilter &&
      other.warehouseId == warehouseId &&
      other.search == search &&
      other.period == period &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(warehouseId, search, period, limit);
}

class StockMovesFilterNotifier extends Notifier<StockMovesFilter> {
  @override
  StockMovesFilter build() {
    // A new company is a new history: a warehouse id carried over from the last
    // one would filter this one down to nothing.
    ref.watch(selectedCompanyProvider.select((c) => c?.id));
    return const StockMovesFilter();
  }

  // A filter change reads from the top again. How deep the operator had
  // scrolled into one result set means nothing for the next.

  void setSearch(String search) {
    if (search == state.search) return;
    state = StockMovesFilter(
        warehouseId: state.warehouseId, search: search, period: state.period);
  }

  void setWarehouse(int? warehouseId) {
    if (warehouseId == state.warehouseId) return;
    state = StockMovesFilter(
        warehouseId: warehouseId, search: state.search, period: state.period);
  }

  void setPeriod(DateTimeRange? period) {
    if (period == state.period) return;
    state = StockMovesFilter(
        warehouseId: state.warehouseId, search: state.search, period: period);
  }

  void clear() => state = const StockMovesFilter();

  void loadMore() => state = StockMovesFilter(
        warehouseId: state.warehouseId,
        search: state.search,
        period: state.period,
        limit: state.limit + StockMovesFilter.pageSize,
      );
}

/// Kept alive with the shell rather than the screen, so switching to another
/// management tab and back finds the history filtered as it was left.
final stockMovesFilterProvider =
    NotifierProvider<StockMovesFilterNotifier, StockMovesFilter>(
        StockMovesFilterNotifier.new);

/// Reads every move matching some filters, unpaged — what the exports write
/// when no row is ticked.
typedef StockMovesLoader = Future<List<StockMoveLine>> Function({
  required int companyId,
  int? warehouseId,
  int? productId,
  String? search,
  DateTimeRange? period,
});

/// A provider rather than a direct database call so the exports can be
/// exercised in a widget test without a database behind them.
final stockMovesExportLoaderProvider = Provider<StockMovesLoader>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ({
    required int companyId,
    int? warehouseId,
    int? productId,
    String? search,
    DateTimeRange? period,
  }) =>
      db.getStockMoves(
        companyId: companyId,
        warehouseId: warehouseId,
        productId: productId,
        search: search,
        dateRange: period,
      );
});

/// The Stock Moves history, offline-first: a Drift stream over the local
/// documents, so a sale rung up on this till is listed the moment it is
/// written — before it has synced — and every later write re-emits.
final stockMovesProvider = StreamProvider.autoDispose<StockMovePage>((ref) {
  final companyId = ref.watch(selectedCompanyProvider.select((c) => c?.id));
  if (companyId == null) return Stream.value(StockMovePage.empty);

  final filter = ref.watch(stockMovesFilterProvider);
  return ref.watch(appDatabaseProvider).watchStockMoves(
        companyId: companyId,
        limit: filter.limit,
        warehouseId: filter.warehouseId,
        search: filter.search,
        dateRange: filter.period,
      );
});

/// What a product's own Stock History tab asks for.
typedef ProductStockMovesQuery = ({
  int productId,
  DateTimeRange? period,
  int limit,
});

/// One product's moves — the product editor's Stock History tab. The same
/// query as the main history, narrowed to [ProductStockMovesQuery.productId],
/// which `idx_document_items_product_id` answers without scanning the rest.
final productStockMovesProvider = StreamProvider.autoDispose
    .family<StockMovePage, ProductStockMovesQuery>((ref, query) {
  final companyId = ref.watch(selectedCompanyProvider.select((c) => c?.id));
  if (companyId == null) return Stream.value(StockMovePage.empty);

  return ref.watch(appDatabaseProvider).watchStockMoves(
        companyId: companyId,
        limit: query.limit,
        productId: query.productId,
        dateRange: query.period,
      );
});
