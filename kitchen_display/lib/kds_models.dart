import 'package:flutter/material.dart';

/// A single line on a kitchen ticket. `isDone` is local-only UI state (the cook
/// striking through a line); it is never sent anywhere.
class KitchenItem {
  final int id;
  final String name;
  final double quantity;
  final String? comment;

  /// The chosen options, NAMES ONLY ("Extra Cheese", "No Sugar").
  ///
  /// 🚨 No prices, deliberately: this screen is a work instruction, not a bill.
  /// What the option cost is the cashier's business and "+3.00" beside it is
  /// noise to whoever is at the grill — the same rule the printed kitchen
  /// ticket follows.
  ///
  /// Empty from a POS that predates modifiers, so an older till pairs with a
  /// newer display without either of them noticing.
  final List<String> modifiers;

  bool isDone;

  KitchenItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.comment,
    this.modifiers = const [],
    this.isDone = false,
  });

  factory KitchenItem.fromJson(Map<String, dynamic> j) => KitchenItem(
        id: (j['id'] ?? 0) as int,
        name: (j['productName'] ?? j['name'] ?? 'Unknown Item') as String,
        quantity: ((j['quantity'] ?? 1) as num).toDouble(),
        comment: j['comment'] as String?,
        modifiers: [
          for (final m in (j['modifiers'] as List?) ?? const [])
            if (m is String && m.trim().isNotEmpty) m.trim(),
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'productName': name,
        'quantity': quantity,
        'comment': comment,
        'modifiers': modifiers,
      };
}

/// A kitchen ticket pushed from a paired POS over the LAN. `orderRef` is the
/// POS's own identifier for the order (server id, or a local UUID) — the KDS
/// echoes it back verbatim when the cook marks the order ready so the POS can
/// match it to its own record.
class KitchenOrder {
  final String orderRef;
  final String number;
  final String? tableName;
  final int serviceType;
  final int serviceStatus;
  final DateTime? dateCreated;
  final List<KitchenItem> items;

  KitchenOrder({
    required this.orderRef,
    required this.number,
    this.tableName,
    required this.serviceType,
    required this.serviceStatus,
    this.dateCreated,
    required this.items,
  });

  String get typeString {
    if (serviceType == 1) return 'Dine in';
    if (serviceType == 2) return 'Takeaway';
    if (serviceType == 3) return 'Delivery';
    return 'Order';
  }

  /// Age-based header colour — green (fresh) → yellow (>5 min) → orange (>15 min).
  Color get headerColor {
    if (dateCreated == null) return const Color(0xFFAED581);
    final minutesOld = DateTime.now().difference(dateCreated!).inMinutes;
    if (minutesOld > 15) return const Color(0xFFFF8A65);
    if (minutesOld > 5) return const Color(0xFFFFF176);
    return const Color(0xFFAED581);
  }

  factory KitchenOrder.fromJson(Map<String, dynamic> j) {
    final rawItems = (j['items'] ?? const []) as List<dynamic>;
    DateTime? created;
    final rawDate = j['dateCreated'];
    if (rawDate != null) {
      created = DateTime.tryParse(rawDate.toString())?.toLocal();
    }
    return KitchenOrder(
      // Accept either `orderRef` (new) or `id` (legacy) as the echo key.
      orderRef: (j['orderRef'] ?? j['id'] ?? '').toString(),
      number: (j['number'] ?? 'Order') as String,
      tableName: j['tableName'] as String?,
      serviceType: (j['serviceType'] ?? j['ServiceType'] ?? 1) as int,
      serviceStatus: (j['serviceStatus'] ?? 2) as int,
      dateCreated: created,
      items: rawItems
          .map((i) => KitchenItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'orderRef': orderRef,
        'number': number,
        'tableName': tableName,
        'serviceType': serviceType,
        'serviceStatus': serviceStatus,
        'dateCreated': dateCreated?.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
      };
}
