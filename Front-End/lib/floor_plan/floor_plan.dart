import 'package:pos_app/database/app_database.dart';

class FloorPlan {
  final int id;
  final String name;
  final String color;

  FloorPlan({
    required this.id,
    required this.name,
    this.color = "Transparent",
  });

  factory FloorPlan.fromJson(Map<String, dynamic> json) {
    return FloorPlan(
      id: json['id'],
      name: json['name'],
      color: json['color'] ?? "Transparent",
    );
  }

  factory FloorPlan.fromDrift(FloorPlansTableData row) {
    return FloorPlan(
      id: row.id,
      name: row.name,
      color: row.color,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }
}
