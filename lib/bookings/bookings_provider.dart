import 'package:drift/drift.dart' show OrderingTerm;
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
final allRoomsProvider = StreamProvider.autoDispose<List<FloorPlanTable>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const []);

  final query = db.select(db.floorPlanTablesTable)
    ..where((t) => t.companyId.equals(companyId));

  return query.watch().map((rows) => rows.map(FloorPlanTable.fromDrift).toList());
});
