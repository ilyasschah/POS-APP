import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/database/database_provider.dart';

/// Sync state of one logical data type (e.g. "Sales orders", "Products").
///
/// [pending] counts rows still queued to push (any non-`synced` working state);
/// [failed] counts rows the server rejected / that errored out. A type with
/// both at zero is fully synced.
class SyncEntityStatus {
  const SyncEntityStatus({
    required this.label,
    required this.pending,
    required this.failed,
    this.error,
  });

  final String label;
  final int pending;
  final int failed;

  /// Last stored failure reason for a non-synced row of this type, if the
  /// backing table records one (`sync_error`). Null when synced, when the table
  /// has no error column, or when nothing has been attempted yet.
  final String? error;

  bool get isSynced => pending == 0 && failed == 0;
}

/// One entry in the summary: a human label + the SQL table that backs it.
///
/// Most tables carry a `sync_status` column whose working states feed [pending]
/// / [failed]. The two op-queue tables (`pending_user_ops`, `pending_stock_ops`)
/// have no such column — every row in them *is* pending work, so we count all.
class _Entity {
  const _Entity(
    this.label,
    this.table, {
    this.hasSyncStatus = true,
    this.hasSyncError = false,
  });
  final String label;
  final String table;
  final bool hasSyncStatus;

  /// Whether the table carries a `sync_error` column we can surface as the
  /// failure reason. (Many tables don't — they fall back to a generic message.)
  final bool hasSyncError;
}

// Working states that mean "not yet on the server, will be retried".
const _pendingStates =
    "('pending','pending_create','pending_update','pending_delete')";
// Terminal failure states (server rejected / errored — won't auto-retry).
const _failedStates = "('failed','sync_failed')";

// Parent-level entities meaningful to a shop operator. Child/junction tables
// (order items, item taxes, document items) are intentionally folded into their
// parent — a pending child can't exist without a pending parent.
const _entities = <_Entity>[
  _Entity('Sales orders', 'pos_orders', hasSyncError: true),
  _Entity('Documents', 'documents'),
  _Entity('Payments', 'payments'),
  _Entity('Voids', 'pending_voids'),
  _Entity('Cash movements', 'starting_cash', hasSyncError: true),
  _Entity('Z-reports', 'z_reports', hasSyncError: true),
  _Entity('Shifts', 'shifts', hasSyncError: true),
  _Entity('Time clock', 'time_clock_entries', hasSyncError: true),
  _Entity('Products', 'products', hasSyncError: true),
  _Entity('Product groups', 'product_groups', hasSyncError: true),
  _Entity('Product comments', 'product_comments'),
  _Entity('Barcodes', 'barcodes'),
  _Entity('Taxes', 'taxes'),
  _Entity('Product taxes', 'product_taxes'),
  _Entity('Payment types', 'payment_types'),
  _Entity('Void reasons', 'void_reasons'),
  _Entity('Customers', 'customers', hasSyncError: true),
  _Entity('Customer discounts', 'customer_discounts', hasSyncError: true),
  _Entity('Loyalty cards', 'loyalty_cards', hasSyncError: true),
  _Entity('Promotions', 'promotions', hasSyncError: true),
  _Entity('Stock', 'stocks'),
  _Entity('Stock counts', 'stock_controls'),
  _Entity('Stock transfers', 'pending_stock_ops', hasSyncStatus: false),
  _Entity('Warehouses', 'warehouses', hasSyncError: true),
  _Entity('Users', 'pending_user_ops', hasSyncStatus: false),
  _Entity('Company', 'companies'),
  _Entity('Settings', 'app_properties'),
];

String _buildSql() {
  final selects = _entities.map((e) {
    if (e.hasSyncStatus) {
      // MAX(...) over the non-synced rows surfaces a stored reason if any row
      // has one (NULLs are ignored). Tables without the column select NULL.
      final errorCol = e.hasSyncError
          ? "MAX(CASE WHEN sync_status NOT IN ('synced') THEN sync_error END)"
          : 'NULL';
      return "SELECT '${e.label}' AS label, "
          'SUM(CASE WHEN sync_status IN $_pendingStates THEN 1 ELSE 0 END) AS pending, '
          'SUM(CASE WHEN sync_status IN $_failedStates THEN 1 ELSE 0 END) AS failed, '
          '$errorCol AS error '
          'FROM ${e.table}';
    }
    // Op-queue table: every row is outstanding work, none can be "failed".
    return "SELECT '${e.label}' AS label, COUNT(*) AS pending, 0 AS failed, "
        'NULL AS error FROM ${e.table}';
  });
  return selects.join('\nUNION ALL\n');
}

/// Live per-entity sync summary. Emits a fresh list whenever any of the watched
/// tables changes (a checkout, an edit, a successful push), so the Sync Status
/// panel self-heals without a manual refresh.
final syncStatusProvider =
    StreamProvider.autoDispose<List<SyncEntityStatus>>((ref) {
  final db = ref.watch(appDatabaseProvider);

  // Tables the query reads from — drift re-runs the watch when any of these
  // change. Must mirror the tables named in [_entities].
  final readsFrom = <ResultSetImplementation<dynamic, dynamic>>{
    db.posOrdersTable,
    db.documentsTable,
    db.paymentsTable,
    db.pendingVoidsTable,
    db.startingCashTable,
    db.zReportsTable,
    db.shiftsTable,
    db.timeClockEntriesTable,
    db.productsTable,
    db.productGroupsTable,
    db.productCommentsTable,
    db.barcodesTable,
    db.taxesTable,
    db.productTaxesTable,
    db.paymentTypesTable,
    db.voidReasonsTable,
    db.customersTable,
    db.customerDiscountsTable,
    db.loyaltyCardsTable,
    db.promotionsTable,
    db.stocksTable,
    db.stockControlsTable,
    db.pendingStockOpsTable,
    db.warehousesTable,
    db.pendingUserOpsTable,
    db.companiesTable,
    db.appPropertiesTable,
  };

  return db.customSelect(_buildSql(), readsFrom: readsFrom).watch().map((rows) {
    return rows
        .map((r) => SyncEntityStatus(
              label: r.read<String>('label'),
              pending: r.readNullable<int>('pending') ?? 0,
              failed: r.readNullable<int>('failed') ?? 0,
              error: r.readNullable<String>('error'),
            ))
        .toList();
  });
});

/// Convenience: total rows waiting to push across every entity (pending only,
/// not failures). Drives any "N pending" headline.
final totalPendingProvider = Provider.autoDispose<int>((ref) {
  final list = ref.watch(syncStatusProvider).value ?? const [];
  return list.fold<int>(0, (sum, e) => sum + e.pending);
});
