import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/stock/warehouse_provider.dart';

/// productId → { warehouseId → quantity } for every warehouse in the company,
/// streamed from the local Drift `stocks` table so the POS menu's availability
/// checks work fully offline. `SyncManager.pullStocks` keeps the table fresh.
final stockByWarehouseProvider =
    StreamProvider<Map<int, Map<int, double>>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return Stream.value(const {});

  final query =
      db.select(db.stocksTable)..where((t) => t.companyId.equals(company.id));

  return query.watch().map((rows) {
    final map = <int, Map<int, double>>{};
    for (final s in rows) {
      final byWh = map.putIfAbsent(s.productId, () => {});
      byWh[s.warehouseId] = (byWh[s.warehouseId] ?? 0) + s.quantity;
    }
    return map;
  });
});

/// productId → stock quantity for the currently selected warehouse, derived
/// from [stockByWarehouseProvider]. When no warehouse is selected it sums every
/// warehouse (matches the previous behaviour).
final stockQuantitiesProvider = StreamProvider<Map<int, double>>((ref) {
  final selected = ref.watch(selectedWarehouseProvider);
  final byWarehouse = ref.watch(stockByWarehouseProvider).value ?? const {};

  final map = <int, double>{};
  byWarehouse.forEach((productId, byWh) {
    byWh.forEach((warehouseId, quantity) {
      if (selected == null || warehouseId == selected.id) {
        map[productId] = (map[productId] ?? 0) + quantity;
      }
    });
  });
  return Stream.value(map);
});
