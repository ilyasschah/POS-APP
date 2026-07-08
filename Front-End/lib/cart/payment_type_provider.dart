import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:pos_app/cart/payment_type_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';

/// Live list of payment types for the current company, streamed from Drift.
/// Ordered by `ordinal` ascending to match the admin grid sort.
final allPaymentTypesProvider =
    StreamProvider.autoDispose<List<PaymentType>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const Stream.empty();

  final query = db.select(db.paymentTypesTable)
    ..where((t) => t.companyId.equals(companyId))
    // Hide rows tombstoned offline (pending server delete queued).
    ..where((t) => t.syncStatus.isNotIn(['pending_delete']))
    ..orderBy([(t) => OrderingTerm.asc(t.ordinal)]);

  return query
      .watch()
      .map((rows) => rows.map(PaymentType.fromDrift).toList());
});

final paymentTypeVisibleColumnsProvider = StateProvider<Map<String, bool>>((
  ref,
) {
  return {
    'Name': true,
    'Code': true,
    'Position': true,
    'Enabled': true,
    'Quick Pay': true,
    'Actions': true,
    'Customer Req.': false,
    'Change': false,
    'Mark Paid': false,
    'Cash Drawer': false,
    'Fiscal': false,
    'Slip': false,
    'Shortcut': false,
  };
});
