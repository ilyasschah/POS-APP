// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_discount_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CustomerDiscountDto _$CustomerDiscountDtoFromJson(Map<String, dynamic> json) =>
    CustomerDiscountDto(
      id: (json['id'] as num).toInt(),
      companyId: (json['companyId'] as num).toInt(),
      customerId: (json['customerId'] as num).toInt(),
      type: (json['type'] as num).toInt(),
      uid: (json['uid'] as num).toInt(),
      value: (json['value'] as num).toDouble(),
    );

Map<String, dynamic> _$CustomerDiscountDtoToJson(
  CustomerDiscountDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'companyId': instance.companyId,
  'customerId': instance.customerId,
  'type': instance.type,
  'uid': instance.uid,
  'value': instance.value,
};

CreateCustomerDiscountRequest _$CreateCustomerDiscountRequestFromJson(
  Map<String, dynamic> json,
) => CreateCustomerDiscountRequest(
  customerId: (json['customerId'] as num).toInt(),
  type: (json['type'] as num).toInt(),
  uid: (json['uid'] as num).toInt(),
  value: (json['value'] as num).toDouble(),
);

Map<String, dynamic> _$CreateCustomerDiscountRequestToJson(
  CreateCustomerDiscountRequest instance,
) => <String, dynamic>{
  'customerId': instance.customerId,
  'type': instance.type,
  'uid': instance.uid,
  'value': instance.value,
};

UpdateCustomerDiscountRequest _$UpdateCustomerDiscountRequestFromJson(
  Map<String, dynamic> json,
) => UpdateCustomerDiscountRequest(
  id: (json['id'] as num).toInt(),
  type: (json['type'] as num).toInt(),
  value: (json['value'] as num).toDouble(),
);

Map<String, dynamic> _$UpdateCustomerDiscountRequestToJson(
  UpdateCustomerDiscountRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'value': instance.value,
};
