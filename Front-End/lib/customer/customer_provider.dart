import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/database/database_provider.dart';

/// Live list of customers for the current company, streamed from Drift.
/// Sorted alphabetically by name to match the picker's expected order.
///
/// Includes DISABLED customers. Use this only to display or resolve records that
/// already reference a customer (the management screen, report/document filters,
/// reopening a saved order) — otherwise a customer disabled today would erase the
/// name on last month's invoice. To offer a customer for a NEW selection, use
/// [selectableCustomersProvider] instead.
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

/// Customers that may be attached to NEW business — the POS customer button,
/// checkout, credit/payment dialogs, bookings, documents, loyalty cards.
/// Disabling a customer withdraws them from every such picker.
///
/// Derived from [allCustomersProvider] rather than running its own query, so both
/// share a single Drift watch and stay consistent. It keeps the same AsyncValue
/// shape, so it is a drop-in swap at call sites.
final selectableCustomersProvider =
    Provider.autoDispose<AsyncValue<List<Customer>>>((ref) {
  return ref.watch(allCustomersProvider).whenData(
        (customers) => customers.where((c) => c.isEnabled).toList(),
      );
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
