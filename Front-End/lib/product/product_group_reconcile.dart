import 'package:pos_app/database/app_database.dart';

/// Outcome of reconciling deleted product groups.
typedef GroupReconcileResult = ({int removed, List<String> iconPaths});

/// Removes locally-`synced` product groups the server no longer returns — i.e.
/// groups deleted on another device — and returns how many went + their cached
/// icon paths so the caller can delete the files.
///
/// Why it's needed: a delta (watermark) pull is structurally blind to deletions —
/// a deleted row is simply absent from a "changed since" response, so it would
/// linger on this device forever. So this runs on a FULL pass (see
/// `SyncManager.pullProductGroups`, `forceReconcile`).
///
/// Only `synced` rows are ever removed. Rows with pending local ops
/// (`pending_create` / `pending_update` / `pending_delete`) are left to the
/// pusher — a group this device created/edited/deleted offline must never be
/// wiped just because the server hasn't heard about it yet.
Future<GroupReconcileResult> retireDeletedProductGroups(
  AppDatabase db, {
  required int companyId,
  required Set<int> serverIds,
}) async {
  final localSynced = await (db.select(db.productGroupsTable)
        ..where((t) => t.companyId.equals(companyId))
        ..where((t) => t.syncStatus.equals('synced')))
      .get();

  var removed = 0;
  final iconPaths = <String>[];
  for (final g in localSynced) {
    if (serverIds.contains(g.id)) continue;
    await (db.delete(db.productGroupsTable)..where((t) => t.id.equals(g.id)))
        .go();
    if (g.localImagePath != null && g.localImagePath!.isNotEmpty) {
      iconPaths.add(g.localImagePath!);
    }
    removed++;
  }
  return (removed: removed, iconPaths: iconPaths);
}
