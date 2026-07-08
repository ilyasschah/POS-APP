import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/product/product_comment_model.dart';

/// Streams comment suggestions for a specific product from the local Drift
/// `product_comments` table. Read on every product tap by the menu grid —
/// instant (microseconds) whether the device is online or offline.
///
/// Comments are pulled in bulk during sync via SyncManager.pullProductComments,
/// so first-install requires one online sync to populate the cache; after that
/// they're permanently available offline. The previous version of this
/// provider hit /ProductComments/GetByProductId on every tap and lagged the
/// cart by ~2s when the server was unreachable — Drift sidesteps both the
/// latency and the network dependency.
final productCommentsProvider = StreamProvider.autoDispose
    .family<List<ProductComment>, int>((ref, productId) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const []);

  final query = db.select(db.productCommentsTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.productId.equals(productId))
    // Hide rows the user is locally deleting (not yet pushed).
    ..where((t) => t.syncStatus.isNotIn(['pending_delete']));

  return query
      .watch()
      .map((rows) => rows.map(ProductComment.fromDrift).toList());
});
