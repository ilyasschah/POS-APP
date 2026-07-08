import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';

// 1. Synchronous Shared Preferences Provider (Initialized in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
      'sharedPreferencesProvider must be overridden in main.dart');
});

// 2. Theme Mode Notifier — driven by appSettingsProvider (Theme_Mode key)
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final settings = ref.watch(appSettingsProvider);
    final mode = settings[SettingKeys.themeMode] ?? 'dark';
    return mode == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  void toggleTheme() {
    final next = state == ThemeMode.light ? 'dark' : 'light';
    ref.read(appSettingsProvider.notifier).set(SettingKeys.themeMode, next);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});

// 3. Default Company ID Notifier
class DefaultCompanyNotifier extends Notifier<int?> {
  static const _companyKey = 'default_company_id';

  @override
  int? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    // Returns null if the user has never set a default company
    return prefs.getInt(_companyKey);
  }

  void setDefaultCompany(int companyId) {
    state = companyId;
    ref.read(sharedPreferencesProvider).setInt(_companyKey, companyId);
  }
}

final defaultCompanyIdProvider =
    NotifierProvider<DefaultCompanyNotifier, int?>(() {
  return DefaultCompanyNotifier();
});
