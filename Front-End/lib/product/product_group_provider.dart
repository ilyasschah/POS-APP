import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/product/product_group_model.dart';

/// Live list of product groups for the current company, streamed from Drift.
/// Sorted by `rank` ascending to match what the menu grid expects.
final allProductGroupsProvider =
    StreamProvider.autoDispose<List<ProductGroup>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const Stream.empty();

  final query = db.select(db.productGroupsTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.syncStatus.isNotIn(['pending_delete']))
    ..orderBy([(t) => OrderingTerm.asc(t.rank)]);

  return query
      .watch()
      .map((rows) => rows.map(ProductGroup.fromDrift).toList());
});

/// Which columns the product-groups table shows, keyed by the untranslated
/// column id. Order is the picker's starting order; `ilyassColumnOrderProvider`
/// overrides it once anyone drags a row.
final productGroupVisibleColumnsProvider =
    StateProvider<Map<String, bool>>((ref) {
  return {
    'Name': true,
    'Parent': true,
    'Products': true,
    'Rank': true,
    'Color': false,
  };
});
