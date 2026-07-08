import 'package:pos_app/database/app_database.dart';

class User {
  final int id;
  final int companyId;
  final String? firstName;
  final String? lastName;
  final String? username;
  final int accessLevel;
  final bool isEnabled;
  final String? email;
  final bool hasPinForThisDevice;
  final String? hashedPin;

  User({
    required this.id,
    required this.companyId,
    this.firstName,
    this.lastName,
    this.username,
    required this.accessLevel,
    required this.isEnabled,
    this.email,
    this.hasPinForThisDevice = false,
    this.hashedPin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['Id'] ?? 0,
      companyId: json['companyId'] ?? json['CompanyId'] ?? 0,
      firstName: json['firstName'] ?? json['FirstName'],
      lastName: json['lastName'] ?? json['LastName'],
      username: json['username'] ?? json['Username'],
      accessLevel: json['accessLevel'] ?? json['AccessLevel'] ?? 0,
      isEnabled: json['isEnabled'] ?? json['IsEnabled'] ?? false,
      email: json['email'] ?? json['Email'],
      hasPinForThisDevice:
          json['hasPinForThisDevice'] ?? json['HasPinForThisDevice'] ?? false,
      hashedPin: json['hashedPin'] ?? json['HashedPin'],
    );
  }

  /// Reconstruct a full User from a Drift row.
  /// `hasPinForThisDevice` is derived from `pinHash` (non-null/non-empty ==
  /// this device is enrolled). Rows created before schema v18 will have null
  /// for firstName/lastName/username/email — `displayName` falls back to the
  /// legacy `name` column in that case so nothing breaks on upgrade.
  factory User.fromDrift(UsersTableData row) {
    final hasPin = row.pinHash != null && row.pinHash!.isNotEmpty;
    return User(
      id: row.id,
      companyId: row.companyId,
      firstName: row.firstName,
      lastName: row.lastName,
      username: row.username ?? row.name, // v18 fallback for old rows
      email: row.email,
      accessLevel: row.role,
      isEnabled: row.isEnabled,
      hasPinForThisDevice: hasPin,
      hashedPin: row.pinHash,
    );
  }

  /// The name shown in the users list and login picker.
  /// Priority: non-empty parts of firstName + lastName → username → 'Unknown User'.
  /// Empty strings are treated the same as null so a blank firstName never
  /// produces a "  " display string.
  String get displayName {
    final first = (firstName ?? '').trim();
    final last  = (lastName  ?? '').trim();
    final full  = [first, last].where((s) => s.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    final u = (username ?? '').trim();
    return u.isNotEmpty ? u : 'Unknown User';
  }
}
