import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/barcode/barcode_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';

/// Streams barcodes for a product from the local Drift table.
///
/// The tab triggers a background server pull when it opens (online) to keep
/// the local cache fresh. Pending adds/deletes are reflected immediately via
/// the stream; 'pending_delete' rows are filtered out of the UI.
final barcodesByProductIdProvider = StreamProvider.autoDispose
    .family<List<BarcodeModel>, int>((ref, productId) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const Stream.empty();

  final query = db.select(db.barcodesTable)
    ..where((t) => t.productId.equals(productId))
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.syncStatus.isNotIn(['pending_delete']));

  return query
      .watch()
      .map((rows) => rows.map(BarcodeModel.fromDrift).toList());
});

/// Every barcode in the company, grouped by product id.
///
/// A product's barcodes live in TWO places: the single `products.barcode`
/// column (which is what `Product.fromDrift` exposes as `Product.barcodes`) and
/// this `barcodes` table, where the product editor's Barcodes tab adds the rest.
/// Anything searching by barcode across the whole catalogue therefore needs both
/// — see `productMatchesSearch`'s `extraBarcodes`.
///
/// One stream for the whole list, deliberately: the per-product family above
/// would mean one subscription per row on a screen showing hundreds.
final allBarcodesByProductIdProvider =
    StreamProvider.autoDispose<Map<int, List<String>>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const Stream.empty();

  final query = db.select(db.barcodesTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.syncStatus.isNotIn(['pending_delete']));

  return query.watch().map((rows) {
    final byProduct = <int, List<String>>{};
    for (final row in rows) {
      byProduct.putIfAbsent(row.productId, () => []).add(row.value);
    }
    return byProduct;
  });
});
