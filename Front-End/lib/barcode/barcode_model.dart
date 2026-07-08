import 'package:pos_app/database/app_database.dart';

class BarcodeModel {
  final int id;         // server-assigned id (0 if not yet synced)
  final String localId; // Drift UUID — used for local delete targeting
  final String value;
  final int productId;
  final String productName;
  final String syncStatus; // 'synced' | 'pending_create' | 'pending_delete'

  bool get isPendingSync => syncStatus != 'synced';

  BarcodeModel({
    required this.id,
    required this.localId,
    required this.value,
    required this.productId,
    this.productName = '',
    this.syncStatus = 'synced',
  });

  factory BarcodeModel.fromJson(Map<String, dynamic> json) {
    return BarcodeModel(
      id: json['id'] ?? 0,
      localId: '',
      value: json['value'] ?? '',
      productId: json['productId'] ?? 0,
      productName: json['productName'] ?? '',
    );
  }

  factory BarcodeModel.fromDrift(BarcodesTableData row) {
    return BarcodeModel(
      id: row.serverId ?? 0,
      localId: row.localId,
      value: row.value,
      productId: row.productId,
      syncStatus: row.syncStatus,
    );
  }
}
