import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/sync/sync_manager.dart';

/// SyncManager singleton. The Dio instance is built via the same `createDio()`
/// factory the rest of the app uses, so the baseUrl/timeouts/cert handling
/// stays consistent.
final syncManagerProvider = Provider<SyncManager>((ref) {
  return SyncManager(
    db: ref.watch(appDatabaseProvider),
    dio: createDio(),
    authStorage: ref.watch(authStorageProvider),
  );
});
