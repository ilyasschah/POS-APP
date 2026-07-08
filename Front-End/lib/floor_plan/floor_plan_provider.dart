import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/floor_plan/floor_plan.dart';
import 'package:pos_app/sync/sync_provider.dart';

/// Live floor-plan list from the local Drift DB. Mutations below write
/// through to the API and then trigger a targeted re-sync so the local
/// stream re-emits with the new row.
final allFloorPlansProvider =
    StreamProvider.autoDispose<List<FloorPlan>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const Stream.empty();

  final query = db.select(db.floorPlansTable)
    ..where((t) => t.companyId.equals(companyId));

  return query.watch().map((rows) => rows.map(FloorPlan.fromDrift).toList());
});

class FloorPlanState {
  final int? activeFloorPlanId;
  final bool showGrid;
  final bool snapToGrid;
  final double gridSize;
  final bool isEditMode;

  FloorPlanState({
    this.activeFloorPlanId,
    this.showGrid = true,
    this.snapToGrid = false,
    this.gridSize = 20.0,
    this.isEditMode = false,
  });

  FloorPlanState copyWith({
    int? activeFloorPlanId,
    bool? showGrid,
    bool? snapToGrid,
    double? gridSize,
    bool? isEditMode,
  }) {
    return FloorPlanState(
      activeFloorPlanId: activeFloorPlanId ?? this.activeFloorPlanId,
      showGrid: showGrid ?? this.showGrid,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      gridSize: gridSize ?? this.gridSize,
      isEditMode: isEditMode ?? this.isEditMode,
    );
  }
}

class FloorPlanNotifier extends Notifier<FloorPlanState> {
  @override
  FloorPlanState build() => FloorPlanState();

  void setActiveFloorPlan(int id) =>
      state = state.copyWith(activeFloorPlanId: id);

  void toggleShowGrid(bool value) => state = state.copyWith(showGrid: value);
  void toggleSnapToGrid(bool value) =>
      state = state.copyWith(snapToGrid: value);
  void setGridSize(double size) => state = state.copyWith(gridSize: size);
  void toggleEditMode(bool value) => state = state.copyWith(isEditMode: value);

  /// After a successful API mutation, pull the floor-plan delta back into
  /// the local Drift DB. The Drift stream then re-emits and the UI updates.
  /// Errors are swallowed — the mutation already succeeded server-side; the
  /// row will sync on the next pullMasterData.
  Future<void> _refreshLocal() async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;
    try {
      await ref.read(syncManagerProvider).pullFloorPlans(companyId);
    } catch (_) {/* row will appear on next sync */}
  }

  Future<void> addFloorPlan(String name, String color) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;
    final dio = createDio();
    await dio.post('/FloorPlans/Add',
        queryParameters: {'companyId': companyId},
        data: {'name': name, 'color': color});
    await _refreshLocal();
  }

  Future<void> updateFloorPlan(int id, String name, String color) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;
    final dio = createDio();
    await dio.patch('/FloorPlans/Update',
        queryParameters: {'companyId': companyId},
        data: {'id': id, 'name': name, 'color': color});
    await _refreshLocal();
  }

  Future<void> deleteFloorPlan(int id) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;
    final dio = createDio();
    await dio.delete('/FloorPlans/Delete',
        queryParameters: {'id': id, 'companyId': companyId});
    if (state.activeFloorPlanId == id) {
      state = FloorPlanState(activeFloorPlanId: null);
    }
    // Deletion isn't reflected by `modifiedAfter` pulls — the deleted row
    // simply won't be in subsequent responses, but the existing local row
    // sticks. Wipe it directly here.
    final db = ref.read(appDatabaseProvider);
    await (db.delete(db.floorPlansTable)..where((t) => t.id.equals(id))).go();
  }
}

final floorPlanProvider = NotifierProvider<FloorPlanNotifier, FloorPlanState>(
    () => FloorPlanNotifier());
