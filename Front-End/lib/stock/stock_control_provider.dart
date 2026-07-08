import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/stock/stock_control_model.dart';

/// Offline-first per-product stock-control rule, read straight from the local
/// Drift cache (seeded by SyncManager.pullStockControls). No network round-trip.
final stockControlByProductIdProvider = FutureProvider.autoDispose
    .family<StockControl?, int>((ref, productId) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return null;

  final db = ref.watch(appDatabaseProvider);
  final row = await db.getStockControl(productId);
  // A row queued for deletion offline should read as "no rule".
  if (row == null || row.syncStatus == 'pending_delete') return null;

  final products = await (db.select(db.productsTable)
        ..where((t) => t.id.equals(productId)))
      .get();
  final productName = products.isNotEmpty ? products.first.name : '';

  return StockControl(
    id: row.serverId ?? 0,
    productId: row.productId,
    productName: productName,
    customerId: row.customerId,
    reorderPoint: row.reorderPoint,
    preferredQuantity: row.preferredQuantity,
    isLowStockWarningEnabled: row.isLowStockWarningEnabled,
    lowStockWarningQuantity: row.lowStockWarningQuantity,
  );
});

/// All stock-control rules for the company keyed by productId, read from local
/// Drift (offline-first). Lets the stock list evaluate low-stock / reorder
/// status for every row without a per-product async lookup.
final stockControlsMapProvider =
    FutureProvider.autoDispose<Map<int, StockControl>>((ref) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const {};

  final db = ref.watch(appDatabaseProvider);
  final rows = await db.getStockControlsForCompany(companyId);
  return {
    for (final r in rows)
      r.productId: StockControl(
        id: r.serverId ?? 0,
        productId: r.productId,
        productName: '',
        customerId: r.customerId,
        reorderPoint: r.reorderPoint,
        preferredQuantity: r.preferredQuantity,
        isLowStockWarningEnabled: r.isLowStockWarningEnabled,
        lowStockWarningQuantity: r.lowStockWarningQuantity,
      ),
  };
});

/// Evaluates the configured rules against a current quantity. Centralised so
/// the stock list, badges and detail panel all agree on what "low" / "reorder"
/// mean.
extension StockRuleEval on StockControl {
  /// Low-stock when the warning is enabled, a threshold is set, and the current
  /// quantity has dropped to/below it.
  bool isLowStockAt(double qty) =>
      isLowStockWarningEnabled &&
      lowStockWarningQuantity > 0 &&
      qty <= lowStockWarningQuantity;

  /// Needs reordering when a reorder point is set and quantity is at/below it.
  bool needsReorderAt(double qty) => reorderPoint > 0 && qty <= reorderPoint;

  /// How much to order to reach the preferred level (0 if already at/above it).
  double suggestedReorderQty(double qty) {
    final s = preferredQuantity - qty;
    return s > 0 ? s : 0;
  }
}
