import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/security/security_key_model.dart';
import 'package:pos_app/security/security_key_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// Synchronous RBAC enforcer.
///
/// Access level mapping:
///   User.accessLevel  0 = Admin   → universal access
///   User.accessLevel  1 = Cashier → access only when SecurityKey.level == 0
///
/// Toast appearance (duration + position) is read from app settings at
/// provider construction time and cached here so [guard] needs no [WidgetRef].
class SecurityGuard {
  const SecurityGuard(this._user, this._keys, this._duration, this._position);

  final User? _user;
  final List<SecurityKeyModel> _keys;
  final int _duration;
  final String _position;

  /// Returns true if the current user may access [keyName].
  ///
  /// Fail-secure defaults:
  ///   - No logged-in user → deny.
  ///   - Key not found in the configured list → deny (unknown = admin-only).
  ///   - Admin (accessLevel == 0) → always allow, key not checked.
  bool canAccess(String keyName) {
    final user = _user;
    if (user == null) return false;
    if (user.accessLevel == 0) return true; // Admin: universal access

    // Cashier: look up the configured level for this key.
    final key = _keys.cast<SecurityKeyModel?>().firstWhere(
      (k) => k!.name == keyName,
      orElse: () => null,
    );
    if (key == null) return false; // Unknown key → deny
    return key.level == 0; // 0 = Cashier-accessible
  }

  /// Executes [onAllowed] if [canAccess] returns true.
  /// Shows the app's premium toast (respecting position + duration settings)
  /// if access is denied — no raw SnackBar.
  void guard(BuildContext context, String keyName, VoidCallback onAllowed) {
    if (canAccess(keyName)) {
      onAllowed();
      return;
    }
    showAppSnackbarRaw(
      context,
      'Access Denied: You do not have permission for this action.',
      isError: true,
      duration: _duration,
      position: _position,
    );
  }
}

/// Rebuilds automatically when the logged-in user, security key rules,
/// or app settings change. [guard] is synchronous so tap handlers need no async.
///
/// Keys fall back to an empty list while the Drift stream is loading → non-admin
/// users are denied everything until the first DB emit (fail-secure on cold launch).
final securityGuardProvider = Provider<SecurityGuard>((ref) {
  final user = ref.watch(currentUserProvider);
  final keys = ref.watch(allSecurityKeysProvider).value ?? const [];
  final settings = ref.watch(appSettingsProvider);
  final duration =
      int.tryParse(settings[SettingKeys.messageDuration] ?? '3') ?? 3;
  final position = settings[SettingKeys.messagePosition] ?? 'Bottom';
  return SecurityGuard(user, keys, duration, position);
});
