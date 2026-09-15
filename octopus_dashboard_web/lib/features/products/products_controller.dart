import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_controller.dart';
import '../../core/screen_state.dart';
import '../auth/auth_controller.dart';
import '../../models/product.dart';
import '../../models/product_group.dart';

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

  Future<void> createProduct({
    required String name,
    required double price,
    required double cost,
    required int? productGroupId,
    required String color,
  }) async {
    await api.createProduct(
      name: name,
      price: price,
      cost: cost,
      productGroupId: productGroupId,
      color: color,
    );
    await load();
  }

  Future<void> updateProduct({
    required Product product,
    required String name,
    required double price,
    required double cost,
    required int? productGroupId,
    required String color,
  }) async {
    await api.updateProduct(
      product: product,
      name: name,
      price: price,
      cost: cost,
      productGroupId: productGroupId,
      color: color,
    );
    await load();
  }

  Future<void> deleteProduct(Product product) async {
    await api.deleteProduct(id: product.id);
    await load();
  }
}

final productGroupsProvider = FutureProvider<List<ProductGroup>>(
  (ref) => ref.watch(apiProvider).fetchProductGroups(),
);

final productsProvider =
    NotifierProvider<ProductsController, ScreenState<List<Product>>>(
      ProductsController.new,
    );
