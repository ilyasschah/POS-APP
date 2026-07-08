import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This terminal's POS name + the prefix used in offline document numbers
/// (`<DeviceName>-<DocTypeCode>-<Seq>`).
///
/// It is stored **device-locally** (shared_preferences) and is **never synced**:
/// every terminal must keep its own name, otherwise two POS sharing a name would
/// produce colliding document numbers — the exact thing the prefix exists to
/// prevent. Set/edited in Settings.
const _kDeviceNameKey = 'pos.device.name';

/// Sanitizes a raw, user-typed name into the form used as a document-number
/// prefix: uppercase, letters + digits only, max 12 chars. Empty → 'POS'.
/// Keeping it clean means it always fits in a Code128/QR barcode.
String sanitizeDeviceName(String raw) {
  final cleaned = raw.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  if (cleaned.isEmpty) return 'POS';
  return cleaned.length > 12 ? cleaned.substring(0, 12) : cleaned;
}

/// Authoritative read of the stored device name (already sanitized on write).
/// Used by checkout so numbering never depends on provider load timing.
Future<String> getDeviceName() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kDeviceNameKey) ?? '';
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
  }
}

final deviceNameProvider =
    NotifierProvider<DeviceNameNotifier, String>(DeviceNameNotifier.new);
