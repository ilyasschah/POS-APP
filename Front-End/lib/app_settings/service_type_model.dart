import 'dart:convert';

class CustomServiceType {
  final int id;
  final String name;
  final String prefix;

  const CustomServiceType({
    required this.id,
    required this.name,
    required this.prefix,
  });

  CustomServiceType copyWith({int? id, String? name, String? prefix}) =>
      CustomServiceType(
        id: id ?? this.id,
        name: name ?? this.name,
        prefix: prefix ?? this.prefix,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'prefix': prefix};

  factory CustomServiceType.fromJson(Map<String, dynamic> json) =>
      CustomServiceType(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        prefix: json['prefix'] as String,
      );

  static List<CustomServiceType> listFromJson(String jsonStr) {
    if (jsonStr.isEmpty) return List.from(defaults);
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((j) => CustomServiceType.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return List.from(defaults);
    }
  }

  static String listToJson(List<CustomServiceType> types) =>
      jsonEncode(types.map((t) => t.toJson()).toList());

  static const List<CustomServiceType> defaults = [
    CustomServiceType(id: 0, name: 'Dine-In',  prefix: 'ORDER'),
    CustomServiceType(id: 1, name: 'Takeaway', prefix: 'TAKEAWAY'),
    CustomServiceType(id: 2, name: 'Delivery', prefix: 'DELIVERY'),
  ];
}
