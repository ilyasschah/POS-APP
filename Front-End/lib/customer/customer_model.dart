import 'package:pos_app/database/app_database.dart';

class Customer {
  final int id;
  final String name;
  final String? code;
  final String? taxNumber;
  final String? address;
  final String? postalCode;
  final String? city;
  final int? countryId;
  final String? email;
  final String? phoneNumber;
  final bool isEnabled;
  final bool isCustomer;
  final bool isSupplier;
  final int? dueDatePeriod;
  final String? streetName;
  final String? additionalStreetName;
  final String? buildingNumber;
  final String? plotIdentification;
  final String? citySubdivisionName;
  final bool isTaxExempt;

  Customer({
    required this.id,
    required this.name,
    this.code,
    this.taxNumber,
    this.address,
    this.postalCode,
    this.city,
    this.countryId,
    this.email,
    this.phoneNumber,
    this.isEnabled = true,
    this.isCustomer = true,
    this.isSupplier = false,
    this.dueDatePeriod,
    this.streetName,
    this.additionalStreetName,
    this.buildingNumber,
    this.plotIdentification,
    this.citySubdivisionName,
    this.isTaxExempt = false,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      code: json['code'],
      taxNumber: json['taxNumber'],
      address: json['address'],
      postalCode: json['postalCode'],
      city: json['city'],
      countryId: json['countryId'],
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      isEnabled: json['isEnabled'] ?? true,
      isCustomer: json['isCustomer'] ?? true,
      isSupplier: json['isSupplier'] ?? false,
      dueDatePeriod: json['dueDatePeriod'],
      streetName: json['streetName'],
      additionalStreetName: json['additionalStreetName'],
      buildingNumber: json['buildingNumber'],
      plotIdentification: json['plotIdentification'],
      citySubdivisionName: json['citySubdivisionName'],
      isTaxExempt: json['isTaxExempt'] ?? false,
    );
  }

  // Identity by primary key. The customers list is a Drift stream that re-emits
  // fresh Customer instances on every change, so without this a value held in a
  // DropdownButton / Set (e.g. a selected customer) would no longer match any
  // emitted item and trip "exactly one item" assertions. Two Customers are the
  // same iff they share an id.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Customer && other.id == id);

  @override
  int get hashCode => id.hashCode;

  factory Customer.fromDrift(CustomersTableData row) {
    return Customer(
      id: row.id,
      name: row.name,
      code: row.code,
      taxNumber: row.taxNumber,
      address: row.address,
      postalCode: row.postalCode,
      city: row.city,
      countryId: row.countryId,
      email: row.email,
      phoneNumber: row.phoneNumber,
      isEnabled: row.isEnabled,
      isCustomer: row.isCustomer,
      isSupplier: row.isSupplier,
      dueDatePeriod: row.dueDatePeriod,
      streetName: row.streetName,
      additionalStreetName: row.additionalStreetName,
      buildingNumber: row.buildingNumber,
      plotIdentification: row.plotIdentification,
      citySubdivisionName: row.citySubdivisionName,
      isTaxExempt: row.isTaxExempt,
    );
  }
}