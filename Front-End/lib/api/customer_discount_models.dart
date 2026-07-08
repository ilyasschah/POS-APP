import 'package:json_annotation/json_annotation.dart';

part 'customer_discount_models.g.dart';

@JsonSerializable()
class CustomerDiscountDto {
  final int id;
  final int companyId;
  final int customerId;
  final int type;
  final int uid;
  final double value;

  CustomerDiscountDto({
    required this.id,
    required this.companyId,
    required this.customerId,
    required this.type,
    required this.uid,
    required this.value,
  });

  factory CustomerDiscountDto.fromJson(Map<String, dynamic> json) =>
      _$CustomerDiscountDtoFromJson(json);
  Map<String, dynamic> toJson() => _$CustomerDiscountDtoToJson(this);
}

@JsonSerializable()
class CreateCustomerDiscountRequest {
  final int customerId;
  final int type;
  final int uid;
  final double value;

  CreateCustomerDiscountRequest({
    required this.customerId,
    required this.type,
    required this.uid,
    required this.value,
  });

  factory CreateCustomerDiscountRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCustomerDiscountRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateCustomerDiscountRequestToJson(this);
}

@JsonSerializable()
class UpdateCustomerDiscountRequest {
  final int id;
  final int type;
  final double value;

  UpdateCustomerDiscountRequest({
    required this.id,
    required this.type,
    required this.value,
  });

  factory UpdateCustomerDiscountRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateCustomerDiscountRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateCustomerDiscountRequestToJson(this);
}
