import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/product/product_tax_model.dart';

/// Offline-first: a product's tax assignments read from the local Drift cache
/// (seeded by SyncManager.pullProductTaxes). Tax/product names are resolved
/// locally. No network round-trip.
final productTaxesByProductIdProvider = FutureProvider.autoDispose
    .family<List<ProductTax>, int>((ref, productId) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final db = ref.watch(appDatabaseProvider);
  final rows = await db.getProductTaxes(productId);
  if (rows.isEmpty) return [];

  final taxes = await db.select(db.taxesTable).get();
  final taxById = {for (final t in taxes) t.id: t};
  final products = await (db.select(db.productsTable)
        ..where((t) => t.id.equals(productId)))
      .get();
  final productName = products.isNotEmpty ? products.first.name : '';

  return rows.map((r) {
    final tax = taxById[r.taxId];
    return ProductTax(
      productId: r.productId,
      productName: productName,
      taxId: r.taxId,
      taxName: tax?.name ?? '',
      taxRate: tax?.rate ?? 0,
    );
  }).toList();
});
