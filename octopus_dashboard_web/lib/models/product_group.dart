import '../core/json_utils.dart';

class ProductGroup {
  const ProductGroup({
    required this.id,
    required this.name,
    this.color = 'Transparent',
  });

  final int id;
  final String name;
  final String color;

  factory ProductGroup.fromJson(Map<String, dynamic> json) => ProductGroup(
    id: asInt(json['id']),
    name: asString(json['name'], 'Unnamed group'),
    color: asString(json['color'], 'Transparent'),
  );
}
