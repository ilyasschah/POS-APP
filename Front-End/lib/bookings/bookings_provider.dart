import 'package:drift/drift.dart'
    show BooleanExpressionOperators, OrderingTerm, leftOuterJoin;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:pos_app/bookings/booking_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/floor_plan/floor_plan_table.dart';

final selectedBookingDateProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

/// Live booking list for the current company, streamed from the local Drift
/// cache so the calendar renders offline. The server set is kept fresh by
/// [SyncManager.pullBookings] (called on screen open and after every mutation).
final allBookingsProvider = StreamProvider.autoDispose<List<Booking>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const []);

  final query = db.select(db.bookingsTable)
    ..where((t) => t.companyId.equals(companyId))
    // Hide rows tombstoned for an offline delete (pending_delete) so they
    // disappear from the calendar instantly, before the server delete syncs.
    ..where((t) => t.syncStatus.isNotIn(const ['pending_delete']))
    ..orderBy([(t) => OrderingTerm.asc(t.startTime)]);

  return query.watch().map((rows) => rows.map(Booking.fromDrift).toList());
});

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Whether [tableId] is currently held by a booking — its reservation window
/// covers [at] and it hasn't finished. Completed (4) and No Show (5) release the
/// table; Scheduled (1), Arrived (2) and In Service (3) still hold it.
///
/// Used to enforce `Order.AllowWalkInTableOrders`. Pure so it stays testable and
/// callable from any screen holding a booking list.
/// The live booking currently holding [tableId] at [at], or null when there is
/// none. "Live" = a Scheduled / Arrived / In-Service booking (status 1-3) whose
/// window contains [at]. When several overlap, the earliest-starting one wins so
/// a table with back-to-back reservations resolves deterministically.
Booking? liveBookingForTable(
  List<Booking> bookings,
  int tableId,
  DateTime at,
) {
  final matches = bookings
      .where(
        (b) =>
            b.tableIds.contains(tableId) &&
            const {1, 2, 3}.contains(b.status) &&
            !at.isBefore(b.startTime) &&
            !at.isAfter(b.endTime),
      )
      .toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  return matches.isEmpty ? null : matches.first;
}

bool hasLiveBookingForTable(
  List<Booking> bookings,
  int tableId,
  DateTime at,
) =>
    liveBookingForTable(bookings, tableId, at) != null;

/// Table ids a booking claims the MOMENT it exists — no time window. A booked
/// table is held (shown Reserved, hidden from the transfer + new-booking pickers)
/// until its booking is Completed (4), No-Show (5), or deleted; statuses 1-3
/// (Scheduled / Arrived / In Service) all hold it. This is the "occupied on
/// create" rule, distinct from the window-based [liveBookingForTable] used only
/// by the walk-in gate.
Set<int> tablesHeldByBookings(List<Booking> bookings) => {
      for (final b in bookings)
        if (const {1, 2, 3}.contains(b.status)) ...b.tableIds,
    };

/// The active booking holding [tableId] regardless of time (see
/// [tablesHeldByBookings]); earliest-starting wins when several stack. Null when
/// none. Drives the Reserved table's tap → open that reservation.
Booking? heldBookingForTable(List<Booking> bookings, int tableId) {
  final matches = bookings
      .where((b) =>
          const {1, 2, 3}.contains(b.status) && b.tableIds.contains(tableId))
      .toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  return matches.isEmpty ? null : matches.first;
}

/// The `localId` of the still-open order this booking already has, or null when
/// it has none. Drives the booking's primary action: "Open Service" (resume the
/// existing order) vs "Start Service" (create one).
///
/// Deliberately reads `pos_orders` rather than `Booking.posOrderId`. That field
/// holds a *server* id the backend only assigns at checkout, so it stays null
/// for the entire life of an offline order — which is exactly why the button
/// kept saying "Start Service" for a booking already in service, and why
/// pressing it opened a second order alongside the first.
final openOrderForBookingProvider = StreamProvider.autoDispose
    .family<String?, int>((ref, bookingId) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(null);

  final query = db.select(db.posOrdersTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.bookingId.equals(bookingId))
    ..where((t) => t.status.equals(0))
    ..limit(1);

  return query.watch().map((rows) => rows.firstOrNull?.localId);
});

/// All floor-plan tables across every floor plan for the company, streamed
/// from the local Drift cache. Used by the booking calendar (table/room mode)
/// and the booking dialog's table picker. Floor-plan tables are populated by
/// [SyncManager.pullFloorPlanTables] during master-data sync.
///
/// Previously this awaited `allFloorPlansProvider.future` then fanned out a
/// Dio call per plan — which crashed the screen once `allFloorPlansProvider`
/// became a `StreamProvider` (awaiting `.future` on a stream that emits no
/// value while the company is resolving throws "disposed during loading
/// state"). Reading the tables directly from Drift removes both the network
/// dependency and the crash.
/// `status`/`assignedUserId` are derived from open `pos_orders`, NOT from
/// `floor_plan_tables.status` — that column is dead (only `pullFloorPlanTables`
/// writes it, and the server only ever assigns 0), so `FloorPlanTable.fromDrift`
/// reports EVERY table as free. Filtering this list on `status == 0` without
/// this join is a silent no-op: it compiles, runs, and excludes nothing. Same
/// derivation as [tablesByFloorPlanProvider], minus its active-plan filter.
final allRoomsProvider = StreamProvider.autoDispose<List<FloorPlanTable>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const []);

  // A table is also held by an active booking, from the moment it's created —
  // watched so the reservation appearing/clearing re-derives occupancy live.
  final heldByBooking =
      tablesHeldByBookings(ref.watch(allBookingsProvider).value ?? const []);

  // Left join: a table with no open order must still be listed (as free).
  final query = db.select(db.floorPlanTablesTable).join([
    leftOuterJoin(
      db.posOrdersTable,
      db.posOrdersTable.tableId.equalsExp(db.floorPlanTablesTable.id) &
          db.posOrdersTable.companyId.equals(companyId) &
          db.posOrdersTable.status.equals(0),
    ),
  ])..where(db.floorPlanTablesTable.companyId.equals(companyId));

  return query.watch().map((rows) {
    // The join yields one row per (table, open order); a table carrying more
    // than one open order must still appear exactly once.
    final byId = <int, FloorPlanTable>{};
    for (final row in rows) {
      final table = FloorPlanTable.fromDrift(
        row.readTable(db.floorPlanTablesTable),
      );
      final existing = byId.putIfAbsent(table.id, () => table);
      final order = row.readTableOrNull(db.posOrdersTable);
      if (order == null) continue;
      // serviceStatus 1..3 = Occupied / In Preparation / In Kitchen. Guard the
      // 0 case: an order whose status is unset would otherwise paint its table
      // "Free" while still holding items.
      existing.status = order.serviceStatus > 0 ? order.serviceStatus : 1;
      existing.assignedUserId = order.userId;
    }
    // Reserved (4): a booking claims the table until it's completed/deleted. An
    // in-progress order (status 1-3, set above) always wins over the reservation.
    for (final tableId in heldByBooking) {
      final t = byId[tableId];
      if (t != null && t.status == 0) t.status = 4;
    }
    return byId.values.toList();
  });
});

/// [allRoomsProvider] filtered to tables nobody is currently sitting at.
///
/// For pickers that must not offer an occupied table (transfer target, booking
/// creation). Kept as its own provider so the unfiltered list stays available to
/// the booking calendar and the cart header's table-name lookup, which must see
/// every table regardless of occupancy.
final freeRoomsProvider = Provider.autoDispose<AsyncValue<List<FloorPlanTable>>>(
  (ref) => ref
      .watch(allRoomsProvider)
      .whenData((rooms) => rooms.where((r) => r.status == 0).toList()),
);
