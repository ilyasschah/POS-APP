import 'dart:convert';

/// A "printer group" (a.k.a. display group) — a named station (e.g. "Kitchen",
/// "Barman") that owns a set of product categories. When an order is pushed to
/// a paired Kitchen Display, only the items whose product category belongs to
/// one of the display's assigned groups are shown there — so the food station
/// never sees the drinks, and vice-versa.
///
/// Persisted as a JSON array under `SettingKeys.kitchenPrinterGroups` (an
/// application property), so the definitions sync across devices.
class PrinterGroup {
  final int id;
  final String name;

  /// Product-category ids included in this group. The sentinel [noCategoryId]
  /// (0) represents items that have no product group.
  final List<int> productGroupIds;

  const PrinterGroup({
    required this.id,
    required this.name,
    this.productGroupIds = const [],
  });

  /// Sentinel id for "No category" items (product.productGroupId == null).
  static const int noCategoryId = 0;

  PrinterGroup copyWith({int? id, String? name, List<int>? productGroupIds}) =>
      PrinterGroup(
        id: id ?? this.id,
        name: name ?? this.name,
        productGroupIds: productGroupIds ?? this.productGroupIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'productGroupIds': productGroupIds,
      };

  factory PrinterGroup.fromJson(Map<String, dynamic> j) => PrinterGroup(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        productGroupIds: ((j['productGroupIds'] ?? const []) as List<dynamic>)
            .map((e) => (e as num).toInt())
            .toList(),
      );

  /// Always returns a GROWABLE list — callers append to it (adding a new
  /// group), so an unmodifiable `const []` here would throw on the first add.
  static List<PrinterGroup> listFromJson(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return <PrinterGroup>[];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((j) => PrinterGroup.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <PrinterGroup>[];
    }
  }

  static String listToJson(List<PrinterGroup> groups) =>
      jsonEncode(groups.map((g) => g.toJson()).toList());

  /// Next free id given the current list (max + 1, starting at 1).
  static int nextId(List<PrinterGroup> groups) =>
      groups.isEmpty ? 1 : (groups.map((g) => g.id).reduce((a, b) => a > b ? a : b) + 1);
}

/// Parses the per-display assignment map `{ "<ip>": [groupId,...] }` stored
/// under `SettingKeys.kitchenDisplayGroups`.
Map<String, List<int>> parseDisplayGroups(String? jsonStr) {
  if (jsonStr == null || jsonStr.isEmpty) return {};
  try {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return map.map((ip, ids) => MapEntry(
          ip,
          (ids as List<dynamic>).map((e) => (e as num).toInt()).toList(),
        ));
  } catch (_) {
    return {};
  }
}

String encodeDisplayGroups(Map<String, List<int>> map) => jsonEncode(map);
