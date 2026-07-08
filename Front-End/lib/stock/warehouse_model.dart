import 'package:pos_app/database/app_database.dart';

class Warehouse {
  final int id;
  final String name;

  Warehouse({required this.id, required this.name});

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }

  factory Warehouse.fromDrift(WarehousesTableData row) =>
      Warehouse(id: row.id, name: row.name);
}
