import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/tax/tax_model.dart';

/// Live stream of taxes for the currently-selected company, sourced from the
/// local Drift DB. Updates automatically when SyncManager pulls fresh rows.
final allTaxesProvider = StreamProvider.autoDispose<List<Tax>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const Stream.empty();

  final query = db.select(db.taxesTable)
    ..where((t) => t.companyId.equals(companyId))
    // Hide rows tombstoned offline — they're gone from the user's POV and a
    // pending server delete is queued.
    ..where((t) => t.syncStatus.isNotIn(['pending_delete']));

  return query.watch().map((rows) => rows.map(Tax.fromDrift).toList());
});
