import 'dart:convert';
import 'dart:io';

import 'package:pos_app/database/app_database.dart';

class Company {
  final int id;
  final String name;
  final int? countryId;
  final String? countryName;
  final String? address;
  final String? postalCode;
  final String? city;
  final String? taxNumber;
  final String? email;
  final String? phoneNumber;
  final String? bankAccountNumber;
  final String? bankDetails;
  final String? streetName;
  final String? additionalStreetName;
  final String? buildingNumber;
  final String? plotIdentification;
  final String? citySubdivisionName;
  final String? countrySubentity;
  final String? logo;

  Company({
    required this.id,
    required this.name,
    this.countryId,
    this.countryName,
    this.address,
    this.postalCode,
    this.city,
    this.taxNumber,
    this.email,
    this.phoneNumber,
    this.bankAccountNumber,
    this.bankDetails,
    this.streetName,
    this.additionalStreetName,
    this.buildingNumber,
    this.plotIdentification,
    this.citySubdivisionName,
    this.countrySubentity,
    this.logo,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      countryId: json['countryId'],
      countryName: json['countryName'],
      address: json['address'],
      postalCode: json['postalCode'],
      city: json['city'],
      taxNumber: json['taxNumber'],
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      bankAccountNumber: json['bankAccountNumber'],
      bankDetails: json['bankDetails'],
      streetName: json['streetName'],
      additionalStreetName: json['additionalStreetName'],
      buildingNumber: json['buildingNumber'],
      plotIdentification: json['plotIdentification'],
      citySubdivisionName: json['citySubdivisionName'],
      countrySubentity: json['countrySubentity'],
      logo: json['logo'],
    );
  }

  /// Build a Company from the lean Drift cache. The logo column on disk is
  /// re-encoded as base64 here so existing consumers (notably the receipt
  /// printer which calls `base64Decode(company.logo!)`) keep working with
  /// zero call-site changes. One small file read per `fromDrift` call —
  /// fine for the singleton-ish Company.
  ///
  /// All editable fields are now persisted by pullCompany, so the My Company
  /// edit screen reads/writes this cache offline-first. Only `countryName` is
  /// null here (it's a server-side join) — the screen resolves it from the
  /// cached countries list.
  factory Company.fromDrift(CompaniesTableData row) {
    String? logoBase64;
    final logoPath = row.localLogoPath;
    if (logoPath != null && logoPath.isNotEmpty) {
      try {
        final f = File(logoPath);
        if (f.existsSync()) {
          logoBase64 = base64Encode(f.readAsBytesSync());
        }
      } catch (_) {/* missing file → null logo, receipt prints without it */}
    }

    return Company(
      id: row.id,
      name: row.name,
      countryId: row.countryId,
      taxNumber: row.taxNumber,
      address: row.address,
      postalCode: row.postalCode,
      city: row.city,
      email: row.email,
      phoneNumber: row.phone,
      bankAccountNumber: row.bankAccountNumber,
      bankDetails: row.bankDetails,
      streetName: row.streetName,
      additionalStreetName: row.additionalStreetName,
      buildingNumber: row.buildingNumber,
      plotIdentification: row.plotIdentification,
      citySubdivisionName: row.citySubdivisionName,
      countrySubentity: row.countrySubentity,
      logo: logoBase64,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'countryId': countryId,
        'countryName': countryName,
        'address': address,
        'postalCode': postalCode,
        'city': city,
        'taxNumber': taxNumber,
        'email': email,
        'phoneNumber': phoneNumber,
        'bankAccountNumber': bankAccountNumber,
        'bankDetails': bankDetails,
        'streetName': streetName,
        'additionalStreetName': additionalStreetName,
        'buildingNumber': buildingNumber,
        'plotIdentification': plotIdentification,
        'citySubdivisionName': citySubdivisionName,
        'countrySubentity': countrySubentity,
        'logo': logo,
      };

  Company copyWith({
    String? logo,
    String? countryName,
  }) => Company(
        id: id,
        name: name,
        countryId: countryId,
        countryName: countryName ?? this.countryName,
        address: address,
        postalCode: postalCode,
        city: city,
        taxNumber: taxNumber,
        email: email,
        phoneNumber: phoneNumber,
        bankAccountNumber: bankAccountNumber,
        bankDetails: bankDetails,
        streetName: streetName,
        additionalStreetName: additionalStreetName,
        buildingNumber: buildingNumber,
        plotIdentification: plotIdentification,
        citySubdivisionName: citySubdivisionName,
        countrySubentity: countrySubentity,
        logo: logo ?? this.logo,
      );
}
