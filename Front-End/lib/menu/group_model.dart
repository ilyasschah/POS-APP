// import 'package:flutter/material.dart';

// class ProductGroup {
//   final int id;
//   final int companyId;
//   final String name;
//   final int? parentGroupId;
//   final String? parentGroupName;
//   final String color;
//   final int rank;

//   ProductGroup({
//     required this.id,
//     required this.companyId,
//     required this.name,
//     this.parentGroupId,
//     this.parentGroupName,
//     required this.color,
//     required this.rank,
//   });

//   factory ProductGroup.fromJson(Map<String, dynamic> json) {
//     return ProductGroup(
//       id: json['id'] ?? 0,
//       companyId: json['companyId'] ?? 0,
//       name: json['name'] ?? '',
//       parentGroupId: json['parentGroupId'],
//       parentGroupName: json['parentGroupName'],
//       color: json['color'] ?? 'Transparent',
//       rank: json['rank'] ?? 0,
//     );
//   }

//   Color get flutterColor {
//     if (color.startsWith('#') && color.length == 7) {
//       try {
//         return Color(int.parse(color.substring(1, 7), radix: 16) + 0xFF000000);
//       } catch (_) {}
//     }
//     return Colors.blueGrey;
//   }
// }
