import '../core/json_utils.dart';

/// A row from `GET /Users/GetAllUsers`.
///
/// The server has no `role` string and no `isBlocked` flag — both are derived
/// client-side from [accessLevel] and [isEnabled].
class StaffUser {
  const StaffUser({
    required this.id,
    required this.accessLevel,
    required this.isEnabled,
    this.firstName,
    this.lastName,
    this.username,
    this.email,
  });

  final int id;

  /// 0 = Admin/Manager, anything else = Cashier. No other tiers exist.
  final int accessLevel;

  /// Shown directly as Active/Disabled — not inverted.
  final bool isEnabled;

  final String? firstName;
  final String? lastName;
  final String? username;
  final String? email;

  bool get isAdmin => accessLevel == 0;

  String get roleName => isAdmin ? 'Admin' : 'Cashier';

  /// Prefer username, fall back to "first last", then email, then "Unknown".
  String get displayName {
    final u = username?.trim();
    if (u != null && u.isNotEmpty) return u;

    final full = [
      firstName?.trim(),
      lastName?.trim(),
    ].where((p) => p != null && p.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;

    final e = email?.trim();
    if (e != null && e.isNotEmpty) return e;

    return 'Unknown';
  }

  factory StaffUser.fromJson(Map<String, dynamic> json) => StaffUser(
    id: asInt(json['id']),
    accessLevel: asInt(json['accessLevel'], -1),
    isEnabled: asBool(json['isEnabled'], true),
    firstName: asStringOrNull(json['firstName']),
    lastName: asStringOrNull(json['lastName']),
    username: asStringOrNull(json['username']),
    email: asStringOrNull(json['email']),
  );
}
