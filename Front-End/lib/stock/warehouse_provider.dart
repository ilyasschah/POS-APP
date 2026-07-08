import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/stock/stock_model.dart';
import 'package:pos_app/stock/warehouse_model.dart';

final selectedWarehouseProvider = StateProvider<Warehouse?>((ref) => null);

/// Live warehouse list for the current company, streamed from local Drift so it
/// works fully offline. Rows queued for deletion are hidden. The server set is
/// kept fresh by `SyncManager.pullWarehouses`; local CRUD (below) writes here
/// first and syncs in the background.
final allWarehousesProvider =
    StreamProvider.autoDispose<List<Warehouse>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  // Watched (not read) so that if the default setting loads/changes AFTER the
  // warehouse list, this provider re-runs and the seed below re-evaluates.
  final defaultId = int.tryParse(
      ref.watch(appSettingsProvider)[SettingKeys.defaultWarehouseId] ?? '');
  if (companyId == null) return Stream.value(const []);

  final query = db.select(db.warehousesTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.syncStatus.isNotIn(['pending_delete']))
    ..orderBy([(t) => OrderingTerm.asc(t.name)]);

  return query.watch().map((rows) {
    final list = rows.map(Warehouse.fromDrift).toList();
    // Seed the active warehouse so the POS sources stock from a known location.
    // If a default IS configured but isn't in the list yet, do NOT fall back to
    // the first warehouse — leave the selection unset and wait, so a load-order
    // race can't lock it onto the wrong warehouse. Deferred to a microtask so we
    // never mutate another provider mid-emit.
    if (list.isNotEmpty && ref.read(selectedWarehouseProvider) == null) {
      final toSeed = defaultId == null
          ? list.first
          : list.where((w) => w.id == defaultId).firstOrNull;
      if (toSeed != null) {
        Future.microtask(() {
          if (ref.read(selectedWarehouseProvider) == null) {
            ref.read(selectedWarehouseProvider.notifier).state = toSeed;
          }
        });
      }
    }
    return list;
  });
});

final warehouseRepositoryProvider =
    Provider<WarehouseRepository>((ref) => WarehouseRepository(ref));

/// Offline-first warehouse CRUD. Every mutation writes local Drift first (so the
/// UI updates instantly and the change survives offline) with a `syncStatus`
/// the sync engine drains later. Brand-new warehouses use a temporary NEGATIVE
/// id until the server assigns a real one.
class WarehouseRepository {
  WarehouseRepository(this.ref);
  final Ref ref;

  AppDatabase get _db => ref.read(appDatabaseProvider);
  int? get _companyId => ref.read(selectedCompanyProvider)?.id;

  Future<void> add(String name) async {
    final companyId = _companyId;
    if (companyId == null) return;
    await _ensureUniqueName(companyId, name);
    final tempId = await _nextTempId();
    await _db.into(_db.warehousesTable).insert(
          WarehousesTableCompanion(
            id: Value(tempId),
            companyId: Value(companyId),
            name: Value(name.trim()),
            lastModified: Value(DateTime.now().toUtc()),
            syncStatus: const Value('pending_create'),
          ),
        );
  }

  /// Throws when another (non-deleted) warehouse already uses [name] — matches
  /// the server's uniqueness rule so an offline create can't get stuck forever
  /// failing server validation.
  Future<void> _ensureUniqueName(int companyId, String name, {int? excludeId}) async {
    final trimmed = name.trim().toLowerCase();
    final rows = await (_db.select(_db.warehousesTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.syncStatus.isNotIn(['pending_delete'])))
        .get();
    final clash = rows.any(
        (w) => w.id != excludeId && w.name.trim().toLowerCase() == trimmed);
    if (clash) {
      throw Exception("A warehouse named '${name.trim()}' already exists.");
    }
  }

  Future<void> rename(int id, String name) async {
    final companyId = _companyId;
    if (companyId == null) return;
    await _ensureUniqueName(companyId, name, excludeId: id);
    final existing = await (_db.select(_db.warehousesTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    // A not-yet-synced create stays a create (just with the new name).
    final status =
        existing?.syncStatus == 'pending_create' ? 'pending_create' : 'pending_update';
    await (_db.update(_db.warehousesTable)..where((t) => t.id.equals(id))).write(
      WarehousesTableCompanion(
        name: Value(name.trim()),
        lastModified: Value(DateTime.now().toUtc()),
        syncStatus: Value(status),
      ),
    );
  }

  /// Stock rows a warehouse currently holds, read from local Drift (offline).
  Future<List<StockItem>> stocksFor(int warehouseId) async {
    final companyId = _companyId;
    if (companyId == null) return const [];
    final rows = await (_db.select(_db.stocksTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.warehouseId.equals(warehouseId)))
        .get();
    return rows
        .map((r) => StockItem(
              id: r.id,
              quantity: r.quantity,
              warehouseId: r.warehouseId,
              warehouseName: '',
              productId: r.productId,
              productName: '',
              companyId: r.companyId,
            ))
        .toList();
  }

  /// Deletes a warehouse offline-first, handling any stock it holds:
  ///   • [stockAction] == 'move' → reassign its stock to [targetWarehouseId]
  ///   • [stockAction] == 'revoke' (or null) → delete its stock
  /// All local edits happen in one transaction; the matching server ops are
  /// queued (`pending_stock_ops` + the warehouse's `pending_delete`).
  Future<void> delete(int id,
      {String? stockAction, int? targetWarehouseId}) async {
    final companyId = _companyId;
    if (companyId == null) return;

    await _db.transaction(() async {
      final stocks = await (_db.select(_db.stocksTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.warehouseId.equals(id)))
          .get();

      for (final s in stocks) {
        if (stockAction == 'move' && targetWarehouseId != null) {
          await (_db.update(_db.stocksTable)..where((t) => t.id.equals(s.id)))
              .write(StocksTableCompanion(
            warehouseId: Value(targetWarehouseId),
            lastModified: Value(DateTime.now().toUtc()),
          ));
          await _db.into(_db.pendingStockOpsTable).insert(
                PendingStockOpsTableCompanion(
                  operation: const Value('move'),
                  companyId: Value(companyId),
                  stockId: Value(s.id),
                  targetWarehouseId: Value(targetWarehouseId),
                  quantity: Value(s.quantity),
                  productId: Value(s.productId),
                ),
              );
        } else {
          await (_db.delete(_db.stocksTable)..where((t) => t.id.equals(s.id)))
              .go();
          // Only queue a server delete for already-synced (positive id) stock.
          if (s.id > 0) {
            await _db.into(_db.pendingStockOpsTable).insert(
                  PendingStockOpsTableCompanion(
                    operation: const Value('delete'),
                    companyId: Value(companyId),
                    stockId: Value(s.id),
                  ),
                );
          }
        }
      }

      final existing = await (_db.select(_db.warehousesTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (existing != null && existing.syncStatus == 'pending_create') {
        // Never reached the server — just drop it locally.
        await (_db.delete(_db.warehousesTable)..where((t) => t.id.equals(id)))
            .go();
      } else {
        await (_db.update(_db.warehousesTable)..where((t) => t.id.equals(id)))
            .write(WarehousesTableCompanion(
          syncStatus: const Value('pending_delete'),
          lastModified: Value(DateTime.now().toUtc()),
        ));
      }
    });
  }

  /// Next free temporary (negative) id for an offline-created warehouse.
  Future<int> _nextTempId() async {
    final rows = await (_db.select(_db.warehousesTable)
          ..where((t) => t.id.isSmallerThanValue(0)))
        .get();
    if (rows.isEmpty) return -1;
    final minId = rows.map((w) => w.id).reduce((a, b) => a < b ? a : b);
    return minId - 1;
  }
}
