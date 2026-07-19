import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/settings/settings_provider.dart';

/// Device-local theme override, stored in the same SharedPreferences key MyApp
/// already reads first to avoid the boot theme-flash — now exposed reactively so
/// a change (the onboarding theme picker) restyles the whole app at once. Takes
/// precedence over the cloud-synced, per-company [SettingKeys.themeMode]; null
/// means "no device override, fall back to the company setting".
const _kBootThemeModeKey = 'boot_theme_mode';

final deviceThemeModeProvider =
    NotifierProvider<DeviceThemeModeNotifier, String?>(
        DeviceThemeModeNotifier.new);

class DeviceThemeModeNotifier extends Notifier<String?> {
  @override
  String? build() =>
      ref.watch(sharedPreferencesProvider).getString(_kBootThemeModeKey);

  Future<void> set(String mode) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kBootThemeModeKey, mode);
    state = mode;
  }
}

/// Device-local accent colour (`#RRGGBB` hex), stored in the boot theme-colour
/// cache MyApp already seeds the [ColorScheme] from — reactive so the onboarding
/// picker recolours the app live. Wins over the cloud [SettingKeys.themeAccentColor].
const _kBootThemeColorKey = 'boot_theme_color';

final deviceAccentColorProvider =
    NotifierProvider<DeviceAccentColorNotifier, String?>(
        DeviceAccentColorNotifier.new);

class DeviceAccentColorNotifier extends Notifier<String?> {
  @override
  String? build() =>
      ref.watch(sharedPreferencesProvider).getString(_kBootThemeColorKey);

  Future<void> set(String hex) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kBootThemeColorKey, hex);
    state = hex;
  }
}
