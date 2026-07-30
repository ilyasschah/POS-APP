import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_controller.dart';
import '../../core/screen_state.dart';
import '../../models/product.dart';

class ProductsController extends AsyncController<List<Product>> {
  @override
  Future<List<Product>> fetch(CancelToken cancelToken) =>
      api.fetchProducts(cancelToken: cancelToken);

  /// Saves new pricing and reloads the list.
  ///
  /// Errors propagate to the caller so the edit dialog can stay open and show
  /// the server's own message, rather than being swallowed into screen state.
  Future<void> updatePricing({
    required Product product,
    required double price,
    required double cost,
  }) async {
    await api.updateProductPricing(
      product: product,
      price: price,
      cost: cost,
    );
    await load();
  }
}

final productsProvider =
    NotifierProvider<ProductsController, ScreenState<List<Product>>>(
      ProductsController.new,
    );
