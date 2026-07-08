import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/product/product_model.dart';

final selectedProductGroupIdProvider = StateProvider<int?>((ref) => null);

/// Primary product list — every consumer (menu, reports, promotions, document
/// editor, admin grid) now streams from Drift. Schema v2 covers the full
/// admin field set, so productsByGroupProvider / productByIdProvider below
/// also stream offline.
final allProductsListProvider =
    StreamProvider.autoDispose<List<Product>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const Stream.empty();

  final query = db.select(db.productsTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.syncStatus.isNotIn(['pending_delete']));

  return query.watch().map((rows) => rows.map(Product.fromDrift).toList());
});

/// Streams products for the active group. When `selectedProductGroupIdProvider`
/// is null, returns ALL products for the company — preserving the original
/// "no filter → show everything" behaviour the admin screen relies on.
final productsByGroupProvider =
    StreamProvider.autoDispose<List<Product>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  final groupId = ref.watch(selectedProductGroupIdProvider);

  if (companyId == null) return const Stream.empty();

  final query = db.select(db.productsTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.syncStatus.isNotIn(['pending_delete']));

  if (groupId != null) {
    query.where((t) => t.productGroupId.equals(groupId));
  }

  return query.watch().map((rows) => rows.map(Product.fromDrift).toList());
});

/// Single-product stream. Emits null while the row is absent (e.g. between
/// a fresh install and the first pull) and then re-emits whenever the row
/// is upserted by SyncManager.
final productByIdProvider =
    StreamProvider.autoDispose.family<Product?, int>((ref, productId) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(null);

  final query = db.select(db.productsTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.id.equals(productId))
    ..where((t) => t.syncStatus.isNotIn(['pending_delete']));

  return query
      .watchSingleOrNull()
      .map((row) => row == null ? null : Product.fromDrift(row));
});

/// Derived map for O(1) lookup by id. Updates automatically as Drift fires.
final productMapProvider = Provider.autoDispose<Map<int, Product>>((ref) {
  final products = ref.watch(allProductsListProvider).value ?? const [];
  return {for (final p in products) p.id: p};
});
