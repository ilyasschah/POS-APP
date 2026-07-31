import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

/// Overridden in `main()` with an instance resolved before the first frame, so
/// the very first paint already uses the persisted theme — no flash of the
/// wrong mode on load.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

@immutable
class AppSettings {
  const AppSettings({
    required this.darkMode,
    required this.glassEnabled,
    required this.glassOpacity,
    required this.language,
  });

  /// Dark is the default — this is a dark-mode-first design.
  final bool darkMode;

  /// When off, panels become flat and opaque and all backdrop blurring is
  /// skipped (a "reduce transparency" mode that is also the cheapest to
  /// render).
  final bool glassEnabled;

  /// Tint strength of translucent panels, 0.05–0.50.
  final double glassOpacity;
  final String language;

  AppSettings copyWith({
    bool? darkMode,
    bool? glassEnabled,
    double? glassOpacity,
    String? language,
  }) => AppSettings(
    darkMode: darkMode ?? this.darkMode,
    glassEnabled: glassEnabled ?? this.glassEnabled,
    glassOpacity: glassOpacity ?? this.glassOpacity,
    language: language ?? this.language,
  );

  static const double minOpacity = 0.05;
  static const double maxOpacity = 0.50;
  static const double defaultOpacity = 0.20;
}

/// Appearance preferences, persisted to localStorage via shared_preferences.
///
/// Unlike the iOS original — where the glass toggle and transparency slider
/// were inert — these actually drive rendering (see [GlassCard]).
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      darkMode: prefs.getBool(PrefKeys.darkMode) ?? true,
      glassEnabled: prefs.getBool(PrefKeys.glassEnabled) ?? true,
      glassOpacity:
          prefs.getDouble(PrefKeys.glassOpacity) ?? AppSettings.defaultOpacity,
      language: prefs.getString(PrefKeys.language) ?? 'en',
    );
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  void setLanguage(String code) {
    state = state.copyWith(language: code);
    _prefs.setString(PrefKeys.language, code);
  }

  void setDarkMode(bool value) {
    state = state.copyWith(darkMode: value);
    _prefs.setBool(PrefKeys.darkMode, value);
  }

  void setGlassEnabled(bool value) {
    state = state.copyWith(glassEnabled: value);
    _prefs.setBool(PrefKeys.glassEnabled, value);
  }

  void setGlassOpacity(double value) {
    final clamped = value.clamp(AppSettings.minOpacity, AppSettings.maxOpacity);
    state = state.copyWith(glassOpacity: clamped);
    _prefs.setDouble(PrefKeys.glassOpacity, clamped);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
