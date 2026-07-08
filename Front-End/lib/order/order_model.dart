import 'package:json_annotation/json_annotation.dart';

part 'order_model.g.dart';

@JsonSerializable()
class PosOrder {
  final int id;
  // backend uses "number" for the order string like "ORD-2025..."
  final String number;
  final double total;
  final String customerName;

  // We will manually fill this list after fetching items
  @JsonKey(includeFromJson: false)
  List<PosOrderItem> items;

  PosOrder({
    required this.id,
    required this.number,
    required this.total,
    required this.customerName,
    this.items = const [],
  });

  factory PosOrder.fromJson(Map<String, dynamic> json) =>
      _$PosOrderFromJson(json);

  Map<String, dynamic> toJson() => _$PosOrderToJson(this);
}

@JsonSerializable()
class PosOrderItem {
  final int id;
  final int posOrderId; // This connects to the order.id
  final String productName;
  final double quantity;
  final double price;
  final String? comment;

  PosOrderItem({
    required this.id,
    required this.posOrderId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.comment,
  });

  factory PosOrderItem.fromJson(Map<String, dynamic> json) =>
      _$PosOrderItemFromJson(json);

  Map<String, dynamic> toJson() => _$PosOrderItemToJson(this);
}
