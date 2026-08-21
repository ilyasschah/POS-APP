import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';

/// Asks an administrator to authorise something the cashier may not do alone.
///
/// 🚨 Used for a cash difference beyond `PosSession.MaxCashDifference`. The
/// point is separation of duty: a cashier must not be able to sign off their
/// own shortfall, and a PIN prompt is the only check that works on a till with
/// no connectivity.
///
/// Verification reuses the existing offline scheme exactly — `sha256` of the
/// PIN, base64-encoded, compared against the user's stored `hashedPin`, the
/// same comparison `LoginScreen._verifyPin` does. Deliberately not a new
/// mechanism: a second way to check a PIN is a second way to get it wrong.
abstract final class ManagerAuthorisation {
  /// Returns true only when an ADMIN (`accessLevel == 0`) PIN is entered.
  static Future<bool> request(
    BuildContext context,
    WidgetRef ref, {
    required String reason,
  }) async {
    final users = ref.read(allUsersProvider).value ?? const [];
    // Only admins can authorise. A till with no admin enrolled cannot be
    // unblocked here — by design; the alternative is letting anybody wave a
    // discrepancy through, which is the thing this exists to prevent.
    final admins = users.where((u) => u.accessLevel == 0 && u.hashedPin != null);

    return await showDialog<bool>(
          context: context,
          builder: (_) => _ManagerPinDialog(
            reason: reason,
            admins: admins.toList(),
          ),
        ) ??
        false;
  }

  /// The project's PIN hash: sha256 → base64. Extracted so the comparison has
  /// one definition rather than being retyped per screen.
  static String hashPin(String pin) =>
      base64Encode(sha256.convert(utf8.encode(pin)).bytes);
}

class _ManagerPinDialog extends StatefulWidget {
  const _ManagerPinDialog({required this.reason, required this.admins});

  final String reason;
  final List<dynamic> admins;

  @override
  State<_ManagerPinDialog> createState() => _ManagerPinDialogState();
}

class _ManagerPinDialogState extends State<_ManagerPinDialog> {
  final _pin = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    final l = AppLocalizations.of(context);
    final hashed = ManagerAuthorisation.hashPin(_pin.text.trim());
    final ok = widget.admins.any((u) => u.hashedPin == hashed);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _error = l.managerPinWrong;
        _pin.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.cardColor,
      icon: Icon(Icons.admin_panel_settings_outlined,
          color: theme.colorScheme.primary, size: 30),
      title: Text(l.managerAuthorise),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.reason, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(l.managerPinPrompt,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            TextField(
              controller: _pin,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l.managerAuthorise)),
      ],
    );
  }
}
