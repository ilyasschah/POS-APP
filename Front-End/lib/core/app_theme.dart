import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/core/device_theme_mode_provider.dart';

/// Central theme construction, shared by [MyApp] (the live app theme) and the
/// customer display (which mirrors the same colours). Keeping it in one place
/// means the customer-facing screen can never drift from the operator's theme.

/// Parses a `#RRGGBB` accent hex into a [Color], defaulting to blue.
Color parseAccentColor(String? hex) {
  if (hex == null) return Colors.blue;
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return Colors.blue;
  }
}

/// Builds the app [ThemeData] for a given [mode] (light/dark/dimmed/night/
/// gray/high_contrast) seeded from [seed]. This is the single source of truth
/// for every theme mode in the app.
ThemeData buildAppTheme(String mode, Color seed) {
  switch (mode) {
    case 'light':
      return ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
      );

    case 'dimmed':
      final cs = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: cs.copyWith(
          surface: const Color(0xFF1C2333),
          surfaceContainerLowest: const Color(0xFF111927),
          surfaceContainerLow: const Color(0xFF1A2030),
          surfaceContainer: const Color(0xFF202736),
          surfaceContainerHigh: const Color(0xFF263040),
          surfaceContainerHighest: const Color(0xFF283045),
        ),
        scaffoldBackgroundColor: const Color(0xFF15202B),
        cardColor: const Color(0xFF1C2333),
      );

    case 'night':
      final cs = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: cs.copyWith(
          surface: const Color(0xFF080808),
          surfaceContainerLowest: Colors.black,
          surfaceContainerLow: const Color(0xFF0D0D0D),
          surfaceContainer: const Color(0xFF111111),
          surfaceContainerHigh: const Color(0xFF161616),
          surfaceContainerHighest: const Color(0xFF1C1C1C),
          onSurface: Colors.white,
          onSurfaceVariant: const Color(0xFFCCCCCC),
        ),
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF0D0D0D),
      );

    case 'gray':
      final cs = ColorScheme.fromSeed(
        seedColor: const Color(0xFF808080),
        brightness: Brightness.dark,
      ).copyWith(primary: seed, secondary: seed, tertiary: seed);
      return ThemeData(
        useMaterial3: true,
        colorScheme: cs,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardColor: const Color(0xFF262626),
      );

    case 'high_contrast':
      final cs = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: cs.copyWith(
          surface: Colors.black,
          surfaceContainerLowest: Colors.black,
          surfaceContainerLow: const Color(0xFF0A0A0A),
          surfaceContainer: const Color(0xFF0F0F0F),
          surfaceContainerHigh: const Color(0xFF1A1A1A),
          surfaceContainerHighest: const Color(0xFF222222),
          onSurface: Colors.white,
          onSurfaceVariant: const Color(0xFFE0E0E0),
          outline: const Color(0xFF777777),
          outlineVariant: const Color(0xFF444444),
        ),
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF111111),
      );

    default: // 'dark'
      return ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      );
  }
}

/// Resolves the theme currently in effect from a provider, using the same
/// precedence as [MyApp]: the device-local overrides (boot cache) win over the
/// cloud-synced per-company settings. For code without a [BuildContext] that
/// still needs the app's colours (e.g. the customer-display web payload).
ThemeData currentAppTheme(Ref ref) {
  final settings = ref.read(appSettingsProvider);
  final hex = ref.read(deviceAccentColorProvider) ??
      settings[SettingKeys.themeAccentColor];
  final mode = ref.read(deviceThemeModeProvider) ??
      settings[SettingKeys.themeMode] ??
      'dark';
  return buildAppTheme(mode, parseAccentColor(hex));
}

/// Semantic "success" green that adapts to brightness — mirrors
/// `BuildContext.successColor` in `status_colors.dart` for code paths that only
/// have a [ThemeData] (the customer-display theme payload).
Color themeSuccessColor(ThemeData theme) => theme.brightness == Brightness.dark
    ? const Color(0xFF66BB6A)
    : const Color(0xFF2E7D32);

/// Serialises the theme colours the customer-display **web** page needs into a
/// `{token: '#rrggbb'}` map, broadcast over the WebSocket so a browser on a
/// second monitor / other device renders in the operator's exact theme. The
/// native Flutter display reads `Theme.of(context)` directly and does not use
/// this.
Map<String, String> customerDisplayThemeMap(ThemeData theme) {
  final cs = theme.colorScheme;
  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  return {
    'bg': hex(theme.scaffoldBackgroundColor),
    'surface': hex(cs.surface),
    'surfaceAlt': hex(cs.surfaceContainerHigh),
    'onSurface': hex(cs.onSurface),
    'onSurfaceVariant': hex(cs.onSurfaceVariant),
    'primary': hex(cs.primary),
    'onPrimary': hex(cs.onPrimary),
    'outline': hex(cs.outlineVariant),
    'success': hex(themeSuccessColor(theme)),
  };
}
