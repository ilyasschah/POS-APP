import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:pos_app/database/app_database.dart';

class ProductGroup {
  final int id;
  final int companyId;
  final String name;
  final int? parentGroupId;
  final String? parentGroupName;
  final String color;
  final String? image; // The raw base64 string from DB (JSON-sourced)
  final String? localImagePath; // Absolute path on disk (Drift-sourced)
  final int rank;
  final String syncStatus;

  bool get isPendingSync => syncStatus != 'synced';
  bool get isPendingCreate => syncStatus == 'pending_create';

  ProductGroup({
    required this.id,
    required this.companyId,
    required this.name,
    this.parentGroupId,
    this.parentGroupName,
    required this.color,
    this.image,
    this.localImagePath,
    required this.rank,
    this.syncStatus = 'synced',
  });

  factory ProductGroup.fromJson(Map<String, dynamic> json) {
    return ProductGroup(
      id: json['id'] ?? 0,
      companyId: json['companyId'] ?? 0,
      name: json['name'] ?? '',
      parentGroupId: json['parentGroupId'],
      parentGroupName: json['parentGroupName'],
      color: json['color'] ?? 'Transparent',
      image: json['image'], // Map the image from JSON
      rank: json['rank'] ?? 0,
    );
  }

  /// Reconstruct from a Drift row. `image` (base64) stays null; the icon
  /// lives at `localImagePath` on disk. UI consumers should prefer the
  /// `imageFile` getter below over `imageBytes` — Flutter caches `FileImage`
  /// by path so the same icon decodes once across the whole category bar.
  factory ProductGroup.fromDrift(ProductGroupsTableData row) {
    return ProductGroup(
      id: row.id,
      companyId: row.companyId,
      name: row.name,
      parentGroupId: row.parentGroupId,
      color: row.colorHex,
      localImagePath: row.localImagePath,
      rank: row.rank,
      syncStatus: row.syncStatus,
    );
  }

  // Parses the hex string into a Flutter Color
  Color get flutterColor {
    if (color.startsWith('#') && color.length == 7) {
      try {
        return Color(int.parse(color.substring(1, 7), radix: 16) + 0xFF000000);
      } catch (_) {}
    }
    return Colors.blueGrey;
  }

  // Decodes the base64 string into readable Image Bytes
  Uint8List? get imageBytes {
    if (image == null || image!.isEmpty) return null;
    try {
      return base64Decode(image!);
    } catch (_) {
      return null;
    }
  }

  /// Returns a `File` handle when the icon lives on disk (Drift-sourced
  /// groups). Use with `Image.file(g.imageFile!)` — Flutter caches decoded
  /// `FileImage`s by path so the same icon only decodes once across the
  /// whole category bar.
  File? get imageFile {
    if (localImagePath == null || localImagePath!.isEmpty) return null;
    final f = File(localImagePath!);
    return f.existsSync() ? f : null;
  }
}
