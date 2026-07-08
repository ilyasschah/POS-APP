import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/database/database_provider.dart';

/// Live count of orders waiting to be pushed to the server. Updates
/// automatically as `pos_orders.sync_status` rows flip between
/// `pending` / `synced` / `failed` — the SyncButton badge subscribes to
/// this stream so the number self-heals after every push.
final pendingOrdersCountProvider = StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.posOrdersTable)
    ..where((t) => t.syncStatus.equals('pending'));
  return query.watch().map((rows) => rows.length);
});
