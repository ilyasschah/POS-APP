import 'package:dio/dio.dart';
import 'package:drift/drift.dart'
    show BooleanExpressionOperators, InsertMode, Value, leftOuterJoin;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/floor_plan/floor_plan_provider.dart';
import 'package:pos_app/floor_plan/floor_plan_table.dart';
import 'package:pos_app/bookings/bookings_provider.dart';

/// Live list of tables for the currently-active floor plan, sourced from Drift.
///
/// **Occupancy is derived from local open orders, never from the `status`
/// column.** That column is server-only, and nothing on either side has written
/// it since the offline-first pivot dropped the `/PosOrder/Create` call that
/// used to set it (`FloorPlanTable.Status` is only ever assigned 0 at
/// construction server-side). So it reads 0 forever and every table rendered as
/// free — even one holding a parked, fully-synced order. An open `pos_orders`
/// row pointing at the table is the real, offline-first source of truth, and it
/// is what `loadExistingOrder` reopens when the table is tapped, so deriving
/// from it keeps the colour and the tap behaviour describing the same fact.
final tablesByFloorPlanProvider =
    StreamProvider.autoDispose<List<FloorPlanTable>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  final activeFloorPlanId = ref.watch(floorPlanProvider).activeFloorPlanId;

  if (companyId == null || activeFloorPlanId == null) {
    return const Stream.empty();
  }

  // A table is also held by an active booking the moment it's created — watched
  // so a reservation appearing/clearing re-derives occupancy live.
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
  ])
    ..where(db.floorPlanTablesTable.companyId.equals(companyId))
    ..where(db.floorPlanTablesTable.floorPlanId.equals(activeFloorPlanId))
    ..where(db.floorPlanTablesTable.syncStatus.isNotIn(['pending_delete']));

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

class FloorPlanTableNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void selectTable(int? id) => state = id;

  /// Lowest unused `A{n}` name on this floor plan — A1, A2, A3…
  ///
  /// The server enforces UQ_FloorPlanTable_Name_PerPlan on
  /// (CompanyId, FloorPlanId, Name), so a repeated name is a hard rejection, not
  /// a cosmetic detail — that is why the name can never be a constant.
  /// Counts **every** local row, including `pending_delete` ones: the server
  /// still holds that name until the delete is pushed, so reusing it now would
  /// collide. Reuses gaps (deleting A2 makes A2 available again) rather than
  /// tracking a high-water mark, which would drift upward forever.
  Future<String> _nextTableName(int companyId, int floorPlanId) async {
    final db = ref.read(appDatabaseProvider);
    final rows = await (db.select(db.floorPlanTablesTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.floorPlanId.equals(floorPlanId)))
        .get();
    final taken = rows.map((r) => r.name).toSet();
    for (var n = 1;; n++) {
      final candidate = 'A$n';
      if (!taken.contains(candidate)) return candidate;
    }
  }

  String _errMsg(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
    return d?.toString() ?? e.message ?? 'Server rejected the request.';
  }

  /// Adds a table to [floorPlanId] under an auto-numbered name.
  ///
  /// Offline-first: the row is written to Drift first (temp negative id,
  /// `pending_create`) so the table appears instantly and survives a restart
  /// with no network; [SyncManager.pushPendingFloorPlanTableOps] swaps in the
  /// server id later. Returns a user-facing message on a server rejection, or
  /// null when the table was saved (online or offline).
  Future<String?> addTable({
    required int floorPlanId,
    double positionX = 60,
    double positionY = 60,
    double width = 100,
    double height = 100,
    bool isRound = false,
  }) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return 'No company selected.';
    final db = ref.read(appDatabaseProvider);

    final name = await _nextTableName(companyId, floorPlanId);
    final now = DateTime.now().toUtc();
    // Microseconds, not milliseconds: two taps in the same millisecond would
    // otherwise collide on the local primary key.
    final tempId = -DateTime.now().microsecondsSinceEpoch;

    await db.into(db.floorPlanTablesTable).insert(
          FloorPlanTablesTableCompanion(
            id: Value(tempId),
            companyId: Value(companyId),
            floorPlanId: Value(floorPlanId),
            name: Value(name),
            positionX: Value(positionX),
            positionY: Value(positionY),
            width: Value(width),
            height: Value(height),
            isRound: Value(isRound),
            status: const Value(0),
            lastModified: Value(now),
            syncStatus: const Value('pending_create'),
          ),
        );

    try {
      final res = await createDio().post<dynamic>(
        '/FloorPlanTables/Add',
        queryParameters: {'companyId': companyId},
        data: {
          'floorPlanId': floorPlanId,
          'name': name,
          'positionX': positionX,
          'positionY': positionY,
          'width': width,
          'height': height,
          'isRound': isRound,
          'status': 0,
        },
      );

      final data = res.data;
      final realId = data is Map ? ((data['id'] ?? data['Id']) as num?)?.toInt() : null;
      if (realId == null || realId <= 0) return null; // push resolves it later

      await db.transaction(() async {
        await (db.delete(db.floorPlanTablesTable)
              ..where((t) => t.id.equals(tempId)))
            .go();
        await db.into(db.floorPlanTablesTable).insert(
              FloorPlanTablesTableCompanion(
                id: Value(realId),
                companyId: Value(companyId),
                floorPlanId: Value(floorPlanId),
                name: Value(name),
                positionX: Value(positionX),
                positionY: Value(positionY),
                width: Value(width),
                height: Value(height),
                isRound: Value(isRound),
                status: const Value(0),
                lastModified: Value(now),
                syncStatus: const Value('synced'),
              ),
              mode: InsertMode.insertOrReplace,
            );
        // The POST above can take seconds — long enough for the new table to be
        // tapped and referenced by an order while it still held the temp id.
        await db.remapFloorPlanTableRefs(tempId, realId, companyId);
      });
      return null;
    } on DioException catch (e) {
      // No response = offline. Keep the pending_create row; the next sync pushes it.
      if (e.response == null) return null;
      // A real rejection can't be retried — drop the optimistic row so the UI
      // doesn't show a table the server refused.
      await (db.delete(db.floorPlanTablesTable)
            ..where((t) => t.id.equals(tempId)))
          .go();
      return _errMsg(e);
    }
  }

  Future<String?> deleteTable(int id) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return 'No company selected.';
    final db = ref.read(appDatabaseProvider);
    if (state == id) state = null;

    // A temp row never reached the server — nothing to delete remotely.
    if (id < 0) {
      await (db.delete(db.floorPlanTablesTable)..where((t) => t.id.equals(id)))
          .go();
      return null;
    }

    await (db.update(db.floorPlanTablesTable)..where((t) => t.id.equals(id)))
        .write(const FloorPlanTablesTableCompanion(
      syncStatus: Value('pending_delete'),
    ));

    try {
      await createDio().delete<dynamic>(
        '/FloorPlanTables/Delete',
        queryParameters: {'id': id, 'companyId': companyId},
      );
      await (db.delete(db.floorPlanTablesTable)..where((t) => t.id.equals(id)))
          .go();
      return null;
    } on DioException catch (e) {
      if (e.response == null) return null; // offline: push completes the delete
      // Rejected — the server still has the row, so un-delete it locally.
      await (db.update(db.floorPlanTablesTable)..where((t) => t.id.equals(id)))
          .write(const FloorPlanTablesTableCompanion(
        syncStatus: Value('synced'),
      ));
      return _errMsg(e);
    }
  }

  /// Marks a locally-edited row pending. A row that hasn't been created on the
  /// server yet must STAY `pending_create` — the create push builds its payload
  /// from the local row, so the edit rides along with it. Flipping it to
  /// `pending_update` would PATCH an id the server has never seen.
  Future<void> _markPending(int id) async {
    final db = ref.read(appDatabaseProvider);
    if (id < 0) return;
    await (db.update(db.floorPlanTablesTable)..where((t) => t.id.equals(id)))
        .write(const FloorPlanTablesTableCompanion(
      syncStatus: Value('pending_update'),
    ));
  }

  Future<void> updateTableGeometry(
    int id,
    double x,
    double y,
    double width,
    double height,
  ) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;
    final db = ref.read(appDatabaseProvider);

    await (db.update(db.floorPlanTablesTable)..where((t) => t.id.equals(id)))
        .write(FloorPlanTablesTableCompanion(
      positionX: Value(x),
      positionY: Value(y),
      width: Value(width),
      height: Value(height),
      lastModified: Value(DateTime.now().toUtc()),
    ));
    await _markPending(id);
    if (id < 0) return;

    try {
      await createDio().patch<dynamic>(
        '/FloorPlanTables/UpdateGeometry',
        queryParameters: {'companyId': companyId},
        data: {
          'id': id,
          'positionX': x,
          'positionY': y,
          'width': width,
          'height': height,
        },
      );
      await (db.update(db.floorPlanTablesTable)..where((t) => t.id.equals(id)))
          .write(const FloorPlanTablesTableCompanion(
        syncStatus: Value('synced'),
      ));
    } on DioException {
      // Offline or rejected — the row stays pending_update for the next sync.
    }
  }

  Future<String?> updateTableProperties(int id, String name, bool isRound) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return 'No company selected.';
    final db = ref.read(appDatabaseProvider);

    await (db.update(db.floorPlanTablesTable)..where((t) => t.id.equals(id)))
        .write(FloorPlanTablesTableCompanion(
      name: Value(name),
      isRound: Value(isRound),
      lastModified: Value(DateTime.now().toUtc()),
    ));
    await _markPending(id);
    if (id < 0) return null;

    try {
      await createDio().patch<dynamic>(
        '/FloorPlanTables/Update',
        queryParameters: {'companyId': companyId},
        data: {'id': id, 'name': name, 'isRound': isRound},
      );
      await (db.update(db.floorPlanTablesTable)..where((t) => t.id.equals(id)))
          .write(const FloorPlanTablesTableCompanion(
        syncStatus: Value('synced'),
      ));
      return null;
    } on DioException catch (e) {
      if (e.response == null) return null;
      return _errMsg(e);
    }
  }
}

final floorPlanTableProvider = NotifierProvider<FloorPlanTableNotifier, int?>(
  () => FloorPlanTableNotifier(),
);
