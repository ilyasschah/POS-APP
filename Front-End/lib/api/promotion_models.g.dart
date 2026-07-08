// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'promotion_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PromotionDtoToJson(PromotionDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'companyId': instance.companyId,
      'name': instance.name,
      'startDate': instance.startDate?.toIso8601String(),
      'startTime': instance.startTime,
      'endDate': instance.endDate?.toIso8601String(),
      'endTime': instance.endTime,
      'daysOfWeek': instance.daysOfWeek,
      'isEnabled': instance.isEnabled,
      'items': instance.items,
      'syncStatus': instance.syncStatus,
      'isPendingSync': instance.isPendingSync,
      'isPendingCreate': instance.isPendingCreate,
    };

Map<String, dynamic> _$PromotionItemDtoToJson(PromotionItemDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'promotionId': instance.promotionId,
      'productId': instance.productId,
      'discountType': instance.discountType,
      'priceType': instance.priceType,
      'value': instance.value,
      'isConditional': instance.isConditional,
      'quantity': instance.quantity,
      'conditionType': instance.conditionType,
      'quantityLimit': instance.quantityLimit,
    };

CreatePromotionRequest _$CreatePromotionRequestFromJson(
  Map<String, dynamic> json,
) => CreatePromotionRequest(
  name: json['name'] as String,
  daysOfWeek: (json['daysOfWeek'] as num).toInt(),
  startDate: json['startDate'] == null
      ? null
      : DateTime.parse(json['startDate'] as String),
  startTime: json['startTime'] as String?,
  endDate: json['endDate'] == null
      ? null
      : DateTime.parse(json['endDate'] as String),
  endTime: json['endTime'] as String?,
  items:
      (json['items'] as List<dynamic>?)
          ?.map(
            (e) =>
                CreatePromotionItemRequest.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$CreatePromotionRequestToJson(
  CreatePromotionRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'daysOfWeek': instance.daysOfWeek,
  'startDate': instance.startDate?.toIso8601String(),
  'startTime': instance.startTime,
  'endDate': instance.endDate?.toIso8601String(),
  'endTime': instance.endTime,
  'items': instance.items,
};

CreatePromotionItemRequest _$CreatePromotionItemRequestFromJson(
  Map<String, dynamic> json,
) => CreatePromotionItemRequest(
  productId: (json['productId'] as num).toInt(),
  discountType: (json['discountType'] as num).toInt(),
  priceType: (json['priceType'] as num).toInt(),
  value: (json['value'] as num).toDouble(),
  isConditional: json['isConditional'] as bool,
  quantity: (json['quantity'] as num).toDouble(),
  conditionType: (json['conditionType'] as num).toInt(),
  quantityLimit: (json['quantityLimit'] as num).toDouble(),
);

Map<String, dynamic> _$CreatePromotionItemRequestToJson(
  CreatePromotionItemRequest instance,
) => <String, dynamic>{
  'productId': instance.productId,
  'discountType': instance.discountType,
  'priceType': instance.priceType,
  'value': instance.value,
  'isConditional': instance.isConditional,
  'quantity': instance.quantity,
  'conditionType': instance.conditionType,
  'quantityLimit': instance.quantityLimit,
};

UpdatePromotionRequest _$UpdatePromotionRequestFromJson(
  Map<String, dynamic> json,
) => UpdatePromotionRequest(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  daysOfWeek: (json['daysOfWeek'] as num).toInt(),
  isEnabled: json['isEnabled'] as bool,
  startDate: json['startDate'] == null
      ? null
      : DateTime.parse(json['startDate'] as String),
  startTime: json['startTime'] as String?,
  endDate: json['endDate'] == null
      ? null
      : DateTime.parse(json['endDate'] as String),
  endTime: json['endTime'] as String?,
  items:
      (json['items'] as List<dynamic>?)
          ?.map(
            (e) =>
                UpdatePromotionItemRequest.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$UpdatePromotionRequestToJson(
  UpdatePromotionRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'daysOfWeek': instance.daysOfWeek,
  'isEnabled': instance.isEnabled,
  'startDate': instance.startDate?.toIso8601String(),
  'startTime': instance.startTime,
  'endDate': instance.endDate?.toIso8601String(),
  'endTime': instance.endTime,
  'items': instance.items,
};

UpdatePromotionItemRequest _$UpdatePromotionItemRequestFromJson(
  Map<String, dynamic> json,
) => UpdatePromotionItemRequest(
  id: (json['id'] as num).toInt(),
  productId: (json['productId'] as num).toInt(),
  discountType: (json['discountType'] as num).toInt(),
  priceType: (json['priceType'] as num).toInt(),
  value: (json['value'] as num).toDouble(),
  isConditional: json['isConditional'] as bool,
  quantity: (json['quantity'] as num).toDouble(),
  conditionType: (json['conditionType'] as num).toInt(),
  quantityLimit: (json['quantityLimit'] as num).toDouble(),
);

Map<String, dynamic> _$UpdatePromotionItemRequestToJson(
  UpdatePromotionItemRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'productId': instance.productId,
  'discountType': instance.discountType,
  'priceType': instance.priceType,
  'value': instance.value,
  'isConditional': instance.isConditional,
  'quantity': instance.quantity,
  'conditionType': instance.conditionType,
  'quantityLimit': instance.quantityLimit,
};
