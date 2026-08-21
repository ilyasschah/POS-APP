import 'package:drift/drift.dart';

import 'package:pos_app/database/app_database.dart';

/// How many product rows a membership apply moved in / removed out.
typedef GroupMembershipResult = ({int moved, int removed});

/// Applies the Product-Groups editor's product selection to the LOCAL Drift
/// store, offline-first — the fix for "changing a product's group doesn't take
/// effect". Every screen (menu grid, group editor, reports) streams products
/// from Drift, so the reassignment has to land there, not only on the API.
///
///   • products in [checkedIds] whose group differs are moved to [groupId];
///   • products currently in [groupId] but NOT in [checkedIds] are unassigned
///     (`productGroupId = null`).
///
/// Both sets are marked `pending_update`, so `SyncManager.pushPendingProductOps`
/// PATCHes `productGroupId` (including `null`) to the server on the next sync —
/// the server's `Product.Update` assigns the group unconditionally, so a null
/// sticks and isn't reverted on the next pull. Only rows that ACTUALLY change are
/// touched (diff computed in Dart), so unrelated products aren't re-pushed.
/// Returns how many were moved in / removed out.
Future<GroupMembershipResult> applyGroupMembershipLocally(
  AppDatabase db, {
  required int companyId,
  required int groupId,
  required List<int> checkedIds,
}) async {
  final now = DateTime.now().toUtc();
  var moved = 0;
  var removed = 0;

  // ── Checked IN — products newly assigned to this group. `!= groupId` also
  // catches a product that had no group yet.
  if (checkedIds.isNotEmpty) {
    final current = await (db.select(db.productsTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.id.isIn(checkedIds)))
        .get();
    final toMove = current
        .where((p) => p.productGroupId != groupId)
        .map((p) => p.id)
        .toList();
    if (toMove.isNotEmpty) {
      moved = await (db.update(db.productsTable)
            ..where((t) => t.id.isIn(toMove)))
          .write(ProductsTableCompanion(
        productGroupId: Value(groupId),
        syncStatus: const Value('pending_update'),
        lastModified: Value(now),
      ));
    }
  }

  // ── Un-checked OUT — products that WERE in this group but are no longer ticked.
  final inGroup = await (db.select(db.productsTable)
        ..where((t) => t.companyId.equals(companyId))
        ..where((t) => t.productGroupId.equals(groupId))
        ..where((t) => t.syncStatus.isNotIn(['pending_delete'])))
      .get();
  final toRemove =
      inGroup.where((p) => !checkedIds.contains(p.id)).map((p) => p.id).toList();
  if (toRemove.isNotEmpty) {
    removed = await (db.update(db.productsTable)
          ..where((t) => t.id.isIn(toRemove)))
        .write(ProductsTableCompanion(
      productGroupId: const Value<int?>(null),
      syncStatus: const Value('pending_update'),
      lastModified: Value(now),
    ));
  }

  return (moved: moved, removed: removed);
}
