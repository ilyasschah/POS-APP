import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/dashboard/dashboard_model.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/refund/refund_service.dart' show kRefundDocumentTypeId;

class DashboardDateRange {
  final DateTime start;
  final DateTime end;

  const DashboardDateRange({required this.start, required this.end});
}

class DashboardDateNotifier extends Notifier<DashboardDateRange> {
  @override
  DashboardDateRange build() {
    final now = DateTime.now();
    return DashboardDateRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  void update(DashboardDateRange range) => state = range;
}

final dashboardDateProvider =
    NotifierProvider<DashboardDateNotifier, DashboardDateRange>(
        () => DashboardDateNotifier());

/// Offline-first reactive source: re-computes the dashboard whenever the local
/// `documents` table changes (e.g. after a sync pulls fresh sales). Reads are
/// always local — the sync engine (button / connectivity / writes) keeps the
/// mirror fresh, and `pullDocuments(includeItems)` now stores line items +
/// customerId so the local aggregation matches the server.
Stream<DashboardData> _localStream(
    Ref ref, int companyId, DateTime start, DateTime end) {
  final db = ref.watch(appDatabaseProvider);
  final watch = (db.select(db.documentsTable)
        ..where((t) => t.companyId.equals(companyId)))
      .watch();
  return watch.asyncMap((_) => _computeLocalDashboard(db, companyId, start, end));
}

/// Computes the dashboard metrics from the local Drift tables. Totals / monthly
/// / hourly come from the `documents` headers; top products / groups / customers
/// from `document_items` + `customers`. With `pullDocuments(includeItems)`
/// storing pulled items + customerId, this matches the server view across all
/// devices' sales within the pulled window (~90 days).
Future<DashboardData> _computeLocalDashboard(
    AppDatabase db, int companyId, DateTime start, DateTime end) async {
  // Sales (documentTypeId 2) AND refunds (4) for the company. Refunds are
  // netted out below so the dashboard reflects money actually kept, not gross
  // sales — a fully-refunded sale nets to zero.
  final docs = await (db.select(db.documentsTable)
        ..where((t) => t.companyId.equals(companyId))
        ..where((t) => t.documentTypeId.isIn([2, kRefundDocumentTypeId])))
      .get();

  // Range filter in Dart (robust against stored UTC vs local range bounds).
  final inRange = docs.where((d) {
    final dt = d.date;
    return !dt.isBefore(start) && !dt.isAfter(end);
  }).toList();

  double totalSales = 0;
  final monthlyMap = <int, double>{}; // key = year * 100 + month
  final hourlyMap = <int, double>{};
  final customerTotals = <int, double>{};
  final docIds = <String>{};
  // Track which in-range documents are refunds so the line-item aggregation
  // below can subtract their quantities/totals too.
  final refundDocIds = <String>{};

  for (final d in inRange) {
    docIds.add(d.localId);
    final isRefund = d.documentTypeId == kRefundDocumentTypeId;
    if (isRefund) refundDocIds.add(d.localId);
    // Normalize by type, not by the stored sign: a refund total is negative
    // locally but positive once pulled from the server, so always treat a
    // refund as a deduction (−|total|) and a sale as an addition (+|total|).
    final signed = isRefund ? -d.total.abs() : d.total.abs();
    totalSales += signed;
    final dt = d.date.toLocal();
    final mKey = dt.year * 100 + dt.month;
    monthlyMap[mKey] = (monthlyMap[mKey] ?? 0) + signed;
    hourlyMap[dt.hour] = (hourlyMap[dt.hour] ?? 0) + signed;
    final cid = d.customerId;
    if (cid != null) {
      customerTotals[cid] = (customerTotals[cid] ?? 0) + signed;
    }
  }

  // Line items for the in-range documents (present for local-origin orders).
  // Refund line items are subtracted (again normalized by parent doc type, not
  // stored sign) so top products/groups reflect net quantities and revenue.
  final allItems = await db.select(db.documentItemsTable).get();
  final productQty = <int, double>{};
  final productTotal = <int, double>{};
  for (final it in allItems) {
    if (!docIds.contains(it.documentId)) continue;
    final isRefund = refundDocIds.contains(it.documentId);
    final qty   = isRefund ? -it.quantity.abs() : it.quantity.abs();
    final total = isRefund ? -it.total.abs()    : it.total.abs();
    productQty[it.productId]   = (productQty[it.productId] ?? 0) + qty;
    productTotal[it.productId] = (productTotal[it.productId] ?? 0) + total;
  }

  // Name + group lookups.
  final products = await (db.select(db.productsTable)
        ..where((t) => t.companyId.equals(companyId)))
      .get();
  final productName = {for (final p in products) p.id: p.name};
  final productGroupId = {
    for (final p in products)
      if (p.productGroupId != null) p.id: p.productGroupId!
  };

  final groups = await (db.select(db.productGroupsTable)
        ..where((t) => t.companyId.equals(companyId)))
      .get();
  final groupName = {for (final g in groups) g.id: g.name};

  final customers = await (db.select(db.customersTable)
        ..where((t) => t.companyId.equals(companyId)))
      .get();
  final customerName = {for (final c in customers) c.id: c.name};

  // Roll product totals up into their groups.
  final groupTotal = <int, double>{};
  productTotal.forEach((pid, total) {
    final gid = productGroupId[pid];
    if (gid != null) groupTotal[gid] = (groupTotal[gid] ?? 0) + total;
  });

  // ── Build sorted result lists ──────────────────────────────────────────
  final monthlySales = monthlyMap.entries
      .map((e) => MonthlySale(
            year: e.key ~/ 100,
            month: e.key % 100,
            total: e.value,
          ))
      .toList()
    ..sort((a, b) =>
        (a.year * 100 + a.month).compareTo(b.year * 100 + b.month));

  final hourlySales = hourlyMap.entries
      .map((e) => HourlySale(hour: e.key, total: e.value))
      .toList()
    ..sort((a, b) => a.hour.compareTo(b.hour));

  final topProducts = (productTotal.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .take(5)
      .map((e) => TopProduct(
            productName: productName[e.key] ?? 'Product #${e.key}',
            quantity: productQty[e.key] ?? 0,
            total: e.value,
          ))
      .toList();

  final topProductGroups = (groupTotal.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .take(5)
      .map((e) => TopProductGroup(
            groupName: groupName[e.key] ?? 'Group #${e.key}',
            total: e.value,
          ))
      .toList();

  final topCustomers = (customerTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .take(5)
      .map((e) => TopCustomer(
            customerName: customerName[e.key] ?? 'Customer #${e.key}',
            total: e.value,
          ))
      .toList();

  return DashboardData(
    totalSales: totalSales,
    monthlySales: monthlySales,
    hourlySales: hourlySales,
    topProducts: topProducts,
    topProductGroups: topProductGroups,
    topCustomers: topCustomers,
  );
}

// Full current year — used by the yearly overview bar chart. Local-first +
// reactive (recomputes when a sync writes fresh documents).
final yearlyDashboardProvider =
    StreamProvider.autoDispose<DashboardData>((ref) {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return Stream.value(DashboardData.empty);
  final year = DateTime.now().year;
  return _localStream(ref, company.id, DateTime(year, 1, 1),
      DateTime(year, 12, 31, 23, 59, 59));
});

// User-selected date range — used by the 5 periodic cards. Local-first +
// reactive.
final periodicDashboardProvider =
    StreamProvider.autoDispose<DashboardData>((ref) {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return Stream.value(DashboardData.empty);
  final range = ref.watch(dashboardDateProvider);
  return _localStream(ref, company.id, range.start, range.end);
});
