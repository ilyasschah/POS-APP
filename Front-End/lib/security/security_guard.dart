import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
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

  /// True when this terminal has no RBAC rules at all for a non-admin user.
  ///
  /// A provisioned company always carries the full seeded key set, so an empty
  /// list never means "everything is admin-only" — it means the rules have not
  /// reached this device yet (first sync incomplete, or still loading). Access
  /// is still refused, but the operator is told *why*: a cashier on a freshly
  /// enrolled terminal was otherwise locked out of every guarded screen with a
  /// plain "access denied", which reads as a permissions bug rather than a sync
  /// one. Toggling a rule in Settings then "fixed" it only because that writes
  /// the row straight into local Drift.
  bool get rulesUnavailable =>
      _user != null && _user.accessLevel != 0 && _keys.isEmpty;

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
      rulesUnavailable
          ? AppLocalizations.of(context).accessRulesNotSynced
          : AppLocalizations.of(context).accessDeniedNoPermission,
      isError: true,
      duration: _duration,
      position: _position,
    );
  }

  /// [guard], but a refusal is a dialog the cashier has to dismiss instead of a
  /// toast that slides away.
  ///
  /// Use it where the denied action has NO other visible effect and the cashier
  /// is standing in front of a customer waiting for something to happen — the
  /// cash drawer being the case this was written for. A toast next to a drawer
  /// that did not move reads as "the hardware is broken"; a dialog saying to
  /// fetch a manager tells them what to actually do. Everywhere the refusal is
  /// self-evident (a screen that simply does not open), keep using [guard].
  Future<void> guardWithDialog(
    BuildContext context,
    String keyName,
    VoidCallback onAllowed,
  ) async {
    if (canAccess(keyName)) {
      onAllowed();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.navSidebarBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ctx.navDivider, width: 1),
        ),
        icon: Icon(Icons.lock_outline, color: cs.error, size: 32),
        title: Text(l10n.accessDenied),
        content: Text(
          rulesUnavailable ? l10n.accessRulesNotSynced : l10n.accessDeniedAskAdmin,
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
            color: ctx.navMuted,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionOk),
          ),
        ],
      ),
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
