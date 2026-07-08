// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PosOrder _$PosOrderFromJson(Map<String, dynamic> json) => PosOrder(
  id: (json['id'] as num).toInt(),
  number: json['number'] as String,
  total: (json['total'] as num).toDouble(),
  customerName: json['customerName'] as String,
);

Map<String, dynamic> _$PosOrderToJson(PosOrder instance) => <String, dynamic>{
  'id': instance.id,
  'number': instance.number,
  'total': instance.total,
  'customerName': instance.customerName,
};

PosOrderItem _$PosOrderItemFromJson(Map<String, dynamic> json) => PosOrderItem(
  id: (json['id'] as num).toInt(),
  posOrderId: (json['posOrderId'] as num).toInt(),
  productName: json['productName'] as String,
  quantity: (json['quantity'] as num).toDouble(),
  price: (json['price'] as num).toDouble(),
  comment: json['comment'] as String?,
);

Map<String, dynamic> _$PosOrderItemToJson(PosOrderItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'posOrderId': instance.posOrderId,
      'productName': instance.productName,
      'quantity': instance.quantity,
      'price': instance.price,
      'comment': instance.comment,
    };
