import 'package:pos_app/database/app_database.dart';

class FloorPlanTable {
  final int id;
  final int floorPlanId;
  String name;
  double positionX;
  double positionY;
  double width;
  double height;
  bool isRound;
  int status;
  int? assignedUserId;

  FloorPlanTable({
    required this.id,
    required this.floorPlanId,
    required this.name,
    required this.positionX,
    required this.positionY,
    required this.width,
    required this.height,
    required this.isRound,
    this.status = 0,
    this.assignedUserId,
  });

  factory FloorPlanTable.fromJson(Map<String, dynamic> json) {
    return FloorPlanTable(
      id: json['id'],
      floorPlanId: json['floorPlanId'],
      name: json['name'],
      positionX: (json['positionX'] as num).toDouble(),
      positionY: (json['positionY'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      isRound: json['isRound'],
      status: json['status'] ?? 0,
      assignedUserId: json['assignedUserId'] as int?,
    );
  }

  /// `assignedUserId` is derived from the latest PosOrder for this table —
  /// it's NOT on the FloorPlanTable entity itself, so it isn't in the Drift
  /// schema. After Phase 4 (when orders move to Drift) we can compute it
  /// from a join. For now it stays null when sourced from Drift.
  factory FloorPlanTable.fromDrift(FloorPlanTablesTableData row) {
    return FloorPlanTable(
      id: row.id,
      floorPlanId: row.floorPlanId,
      name: row.name,
      positionX: row.positionX,
      positionY: row.positionY,
      width: row.width,
      height: row.height,
      isRound: row.isRound,
      status: row.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'floorPlanId': floorPlanId,
      'name': name,
      'positionX': positionX,
      'positionY': positionY,
      'width': width,
      'height': height,
      'isRound': isRound,
      'status': status,
    };
  }
}
