import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/auth/auth_token_cache.dart';

/// This terminal's POS name + the prefix used in offline document numbers
/// (`<DeviceName>-<DocTypeCode>-<Seq>`).
///
/// It is stored **device-locally** (shared_preferences) and is **never synced**:
/// every terminal must keep its own name, otherwise two POS sharing a name would
/// produce colliding document numbers — the exact thing the prefix exists to
/// prevent. Set/edited in Settings.
const _kDeviceNameKey = 'pos.device.name';

/// Max length of a POS name — short enough that the document-number prefix
/// always fits in a Code128/QR barcode.
const int kDeviceNameMaxLength = 12;

/// Sanitizes a raw, user-typed name into the form used as a document-number
/// prefix: uppercase, letters + digits only, max 12 chars. Empty → 'POS'.
/// Keeping it clean means it always fits in a Code128/QR barcode.
String sanitizeDeviceName(String raw) {
  final cleaned = _stripDeviceName(raw);
  return cleaned.isEmpty ? 'POS' : cleaned;
}

String _stripDeviceName(String raw) {
  final cleaned = raw.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  return cleaned.length > kDeviceNameMaxLength
      ? cleaned.substring(0, kDeviceNameMaxLength)
      : cleaned;
}

/// Applies the [sanitizeDeviceName] rules WHILE the operator types, so the field
/// always shows exactly what will be stored. Without it a name is silently
/// rewritten on save — in the one place the name is actually chosen.
///
/// It never substitutes the 'POS' fallback: an empty field must stay empty
/// (that's mid-edit), and only [sanitizeDeviceName] decides what a blank means.
class DeviceNameInputFormatter extends TextInputFormatter {
  const DeviceNameInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = _stripDeviceName(newValue.text);
    if (cleaned == newValue.text) return newValue;
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}

/// Authoritative read of the stored device name (already sanitized on write).
/// Used by checkout so numbering never depends on provider load timing.
Future<String> getDeviceName() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kDeviceNameKey) ?? '';
}

/// Reports this terminal's name to the control plane so `DeviceRegistry` — and
/// therefore the "Active devices" list — shows "POS1" instead of the raw
/// `POS-<uuid>` signature.
///
/// Fire-and-forget by design: the name is device-local truth and the server copy
/// is a label. Offline, unlinked, or a control-plane hiccup all mean "try again
/// next time", never an error in the operator's face — login and every sync
/// resend it anyway (`deviceName` on /Auth/Login, `X-Device-Name` on sync).
Future<void> pushDeviceNameToServer(String name) async {
  if (name.isEmpty) return;
  try {
    // No token = the terminal was never linked, so there is no registry row to
    // rename. The endpoint takes companyId from the token, never from us.
    final jwt = await AuthTokenCache.get();
    if (jwt == null || jwt.isEmpty) return;

    final deviceId = await AuthStorage().getOrCreateDeviceId();
    await createDio().post(
      '/Master/RenameDevice',
      queryParameters: {'deviceId': deviceId, 'deviceName': name},
    );
  } catch (e) {
    debugPrint('Device rename not pushed (will retry on next login/sync): $e');
  }
}

/// Reactive device name for the Settings UI. Empty until loaded / set.
class DeviceNameNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return '';
  }

  Future<void> _load() async {
    state = await getDeviceName();
  }

  /// Persists the sanitized name and updates the UI.
  Future<void> setName(String raw) async {
    final clean = sanitizeDeviceName(raw);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDeviceNameKey, clean);
    state = clean;
    // Local write first, then tell the server. Never awaited for the UI's sake:
    // renaming a POS must work with the network down.
    unawaited(pushDeviceNameToServer(clean));
  }
}

final deviceNameProvider =
    NotifierProvider<DeviceNameNotifier, String>(DeviceNameNotifier.new);
