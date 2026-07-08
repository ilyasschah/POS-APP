import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/database/database_provider.dart';

/// Live list of customers for the current company, streamed from Drift.
/// Sorted alphabetically by name to match the picker's expected order.
final allCustomersProvider = StreamProvider.autoDispose<List<Customer>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const Stream.empty();

  final query = db.select(db.customersTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.syncStatus.isNotIn(['pending_delete']))
    ..orderBy([(t) => OrderingTerm.asc(t.name)]);

  return query.watch().map((rows) => rows.map(Customer.fromDrift).toList());
});

class CurrentCustomerNotifier extends Notifier<Customer?> {
  @override
  Customer? build() => null;

  void setCustomer(Customer c) => state = c;

  void setDefault(List<Customer> customers) {
    state = customers.firstWhere(
      (c) => c.code == 'C000',
      orElse: () => customers.first,
    );
  }
}

final currentCustomerProvider =
    NotifierProvider<CurrentCustomerNotifier, Customer?>(
        () => CurrentCustomerNotifier());
