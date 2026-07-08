import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/security/security_key_model.dart';

/// Live stream of security key rules for the current company, sourced from
/// the local Drift cache rather than the API.
///
/// SyncManager.pullSecurityKeys() refreshes the cache on every master-data
/// sync, so changes made in UsersScreen are visible after the next sync
/// without requiring a network call here. This means SecurityGuard works
/// fully offline from the moment the first sync has run.
final allSecurityKeysProvider = StreamProvider<List<SecurityKeyModel>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const Stream.empty();

  return (db.select(
    db.securityKeysTable,
  )..where((t) => t.companyId.equals(companyId))).watch().map(
    (rows) => rows
        .map((r) => SecurityKeyModel(name: r.name, level: r.level))
        .toList(),
  );
});
