import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/floor_plan/floor_plan_provider.dart';
import 'package:pos_app/floor_plan/floor_plan_table.dart';
import 'package:pos_app/sync/sync_provider.dart';

/// Live list of tables for the currently-active floor plan, sourced from Drift.
final tablesByFloorPlanProvider =
    StreamProvider.autoDispose<List<FloorPlanTable>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  final activeFloorPlanId = ref.watch(floorPlanProvider).activeFloorPlanId;

  if (companyId == null || activeFloorPlanId == null) {
    return const Stream.empty();
  }

  final query = db.select(db.floorPlanTablesTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.floorPlanId.equals(activeFloorPlanId));

  return query.watch().map(
        (rows) => rows.map(FloorPlanTable.fromDrift).toList(),
      );
});

class FloorPlanTableNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void selectTable(int? id) => state = id;

  Future<void> _refreshLocal() async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;
    try {
      await ref.read(syncManagerProvider).pullFloorPlanTables(companyId);
    } catch (_) {/* row appears on next sync */}
  }

  Future<void> addTable(FloorPlanTable table) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;
    final dio = createDio();
    await dio.post(
      '/FloorPlanTables/Add',
      queryParameters: {'companyId': companyId},
      data: table.toJson(),
    );
    await _refreshLocal();
  }

  Future<void> deleteTable(int id) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;
    final dio = createDio();
    await dio.delete(
      '/FloorPlanTables/Delete',
      queryParameters: {'id': id, 'companyId': companyId},
    );
    if (state == id) state = null;
    // Deletes don't surface via modifiedAfter — wipe the local row directly.
    final db = ref.read(appDatabaseProvider);
    await (db.delete(db.floorPlanTablesTable)..where((t) => t.id.equals(id)))
        .go();
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
    final dio = createDio();
    await dio.patch(
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
    await _refreshLocal();
  }

  Future<void> updateTableProperties(int id, String name, bool isRound) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;
    final dio = createDio();
    await dio.patch(
      '/FloorPlanTables/Update',
      queryParameters: {'companyId': companyId},
      data: {'id': id, 'name': name, 'isRound': isRound},
    );
    await _refreshLocal();
  }
}

final floorPlanTableProvider = NotifierProvider<FloorPlanTableNotifier, int?>(
  () => FloorPlanTableNotifier(),
);
