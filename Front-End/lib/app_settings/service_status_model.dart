import 'dart:convert';

import 'package:flutter/material.dart';

class CustomServiceStatus {
  final int id;
  final String name;
  final int colorValue;

  const CustomServiceStatus({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  CustomServiceStatus copyWith({int? id, String? name, int? colorValue}) =>
      CustomServiceStatus(
        id: id ?? this.id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'colorValue': colorValue};

  factory CustomServiceStatus.fromJson(Map<String, dynamic> json) =>
      CustomServiceStatus(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        colorValue: (json['colorValue'] as num).toInt(),
      );

  static List<CustomServiceStatus> listFromJson(String jsonStr) {
    if (jsonStr.isEmpty) return List.from(defaults);
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((j) => CustomServiceStatus.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return List.from(defaults);
    }
  }

  static String listToJson(List<CustomServiceStatus> statuses) =>
      jsonEncode(statuses.map((s) => s.toJson()).toList());

  static const List<CustomServiceStatus> defaults = [
    CustomServiceStatus(id: 1, name: 'Seated',       colorValue: 0xFF2196F3),
    CustomServiceStatus(id: 2, name: 'In Kitchen',   colorValue: 0xFFFF9800),
    CustomServiceStatus(id: 3, name: 'Ready to Pay', colorValue: 0xFF4CAF50),
  ];
}
