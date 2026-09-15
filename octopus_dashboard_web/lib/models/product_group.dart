import '../core/json_utils.dart';

class ProductGroup {
  const ProductGroup({
    required this.id,
    required this.name,
    this.color = 'Transparent',
    this.parentGroupId,
    this.parentGroupName,
    this.rank = 0,
  });

  final int id;
  final String name;
  final String color;
  final int? parentGroupId;
  final String? parentGroupName;
  final int rank;

  factory ProductGroup.fromJson(Map<String, dynamic> json) => ProductGroup(
    id: asInt(json['id']),
    name: asString(json['name'], 'Unnamed group'),
    color: asString(json['color'], 'Transparent'),
    parentGroupId: asIntOrNull(json['parentGroupId']),
    parentGroupName: asStringOrNull(json['parentGroupName']),
    rank: asInt(json['rank']),
  );
}
