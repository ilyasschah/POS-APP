import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/barcode/barcode_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';

/// Streams barcodes for a product from the local Drift table.
///
/// The tab triggers a background server pull when it opens (online) to keep
/// the local cache fresh. Pending adds/deletes are reflected immediately via
/// the stream; 'pending_delete' rows are filtered out of the UI.
final barcodesByProductIdProvider = StreamProvider.autoDispose
    .family<List<BarcodeModel>, int>((ref, productId) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const Stream.empty();

  final query = db.select(db.barcodesTable)
    ..where((t) => t.productId.equals(productId))
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.syncStatus.isNotIn(['pending_delete']));

  return query
      .watch()
      .map((rows) => rows.map(BarcodeModel.fromDrift).toList());
});
