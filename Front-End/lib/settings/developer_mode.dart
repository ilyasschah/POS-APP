import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kDeveloperModeKey = 'dev.developerMode';

/// Developer mode for THIS terminal, persisted on-device.
///
/// 🚨 Device-local, never a synced app property: it decides whether a floating
/// debug button sits on top of the till's UI, and switching it on to diagnose
/// one shop's scanner must not put a bug icon over every other shop's checkout
/// button. Same rule as the printer name and the backup path.
///
/// Off by default, and the only thing it currently gates is the barcode
/// simulator — a tool that injects scans into the real handler, which is
/// exactly the kind of thing that must not be reachable by accident on a live
/// till.
final developerModeProvider =
    NotifierProvider<DeveloperModeNotifier, bool>(DeveloperModeNotifier.new);

class DeveloperModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Seed synchronously so the first frame renders, then hydrate from disk.
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_kDeveloperModeKey);
    if (stored != null) state = stored;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDeveloperModeKey, value);
  }

  Future<void> toggle() => set(!state);
}
