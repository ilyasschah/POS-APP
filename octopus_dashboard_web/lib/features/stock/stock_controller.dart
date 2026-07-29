import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_controller.dart';
import '../../core/screen_state.dart';
import '../../models/product.dart';
import '../../models/stock.dart';

class StockController extends AsyncController<List<ProductStock>> {
  @override
  Future<List<ProductStock>> fetch(CancelToken cancelToken) async {
    // The stock endpoint only returns rows for products that *have* stock, so
    // the full product list is fetched alongside it and stock is left-joined
    // on. Products with no stock row anywhere still get a row, labelled
    // "Unassigned" — a stock screen must never silently hide a product.
    //
    // `Future.wait` rethrows the first error unchanged (so ApiException, and
    // its cancellation flag, survive) while still issuing both requests in
    // parallel.
    final results = await Future.wait<Object>([
      api.fetchProducts(cancelToken: cancelToken),
      api.fetchStocks(cancelToken: cancelToken),
    ]);

    return ProductStock.join(
      results[0] as List<Product>,
      results[1] as List<StockEntry>,
    );
  }
}

final stockProvider =
    NotifierProvider<StockController, ScreenState<List<ProductStock>>>(
      StockController.new,
    );
