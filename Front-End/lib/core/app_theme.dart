import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/core/device_theme_mode_provider.dart';

/// Central theme construction, shared by [MyApp] (the live app theme) and the
/// customer display (which mirrors the same colours). Keeping it in one place
/// means the customer-facing screen can never drift from the operator's theme.

/// The product's own accent: blood red.
///
/// It replaces the coral `#FF416C` the icon was drawn in. That colour measured
/// 3.37:1 on white, which is under the WCAG AA bar for text, so every surface
/// carrying it needed a darkened partner generated alongside. This one measures
/// **7.75:1** and clears the bar on its own.
///
/// `assets/icon.svg` carries a LIGHTER pair of the same red (`#F0353B` →
/// `#D62828`), because the mark sits on the navy plate where this value
/// measures 2.20:1 and vanishes. Same hue, different ground, different
/// lightness — the rule the rest of the palette runs on too.
const Color kBrandAccent = Color(0xFFA4161A);

/// Matches exactly six hex digits — a full `RRGGBB`, nothing shorter.
final RegExp _sixHexDigits = RegExp(r'^[0-9a-fA-F]{6}$');

/// Parses a `#RRGGBB` accent hex into a [Color], defaulting to the brand accent.
///
/// The length check is the point. The previous version only guarded against
/// `int.parse` THROWING, and the dangerous inputs do not throw: an empty
/// string — which is what a cleared settings field sends — left `'FF'`, which
/// parses happily as `0x000000FF`, a **fully transparent** blue. That paints
/// invisible buttons rather than obviously wrong ones, so nobody reports it as
/// a colour bug. A three-digit shorthand like `#F00` fails the same way.
Color parseAccentColor(String? hex) {
  final clean = hex?.trim().replaceAll('#', '') ?? '';
  if (!_sixHexDigits.hasMatch(clean)) return kBrandAccent;
  return Color(int.parse('FF$clean', radix: 16));
}

/// Black or white — whichever actually contrasts with [background], measured
/// the way WCAG measures it.
///
/// Flutter ships [ThemeData.estimateBrightnessForColor], but its threshold is
/// more lenient than WCAG: for the brand coral it answers "dark", which puts
/// WHITE on `#FF416C` at 3.37:1 and fails AA for a button label. Comparing both
/// candidates outright cannot make that mistake, and it adapts if an operator
/// picks some other accent entirely.
/// WCAG 2.1 contrast ratio between two opaque colours.
double _contrastBetween(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Lightens [colour] until it is actually VISIBLE on [background].
///
/// The gray theme paints with the accent raw, which is its whole character —
/// grey everything, one colour showing through undiluted. That only ever worked
/// because the brand accent happened to be light: the coral measured 5.16:1 on
/// the gray ground, so nobody had to think about it. The blood red that
/// replaced it measures **2.25:1** and all but vanishes.
///
/// Lifting the lightness keeps the operator's hue and saturation — it is still
/// recognisably their colour — while making it something you can see. Hue is
/// what they picked; luminance is what the theme has to be able to move.
Color _liftOnto(Color colour, Color background, double target) {
  if (_contrastBetween(colour, background) >= target) return colour;
  final hsl = HSLColor.fromColor(colour);
  for (var l = hsl.lightness; l <= 1.0; l += 0.02) {
    final candidate = hsl.withLightness(l).toColor();
    if (_contrastBetween(candidate, background) >= target) return candidate;
  }
  return Colors.white;
}

Color _readableOn(Color background) {
  final l = background.computeLuminance();
  final whiteRatio = 1.05 / (l + 0.05);
  final blackRatio = (l + 0.05) / 0.05;
  return blackRatio >= whiteRatio ? Colors.black : Colors.white;
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
      // Grey neutrals with the accent showing through RAW — that is the whole
      // point of this mode, so `primary` stays the seed rather than the tone
      // Material would generate from it.
      //
      // But `copyWith(primary:)` does not update `onPrimary`, so the label on
      // an accent-filled button kept the GREY scheme's partner: a dark teal
      // that measured 3.90:1 against the brand coral, under the 4.5:1 AA bar.
      // The partner has to be derived from the accent actually in force.
      const grayGround = Color(0xFF1A1A1A);
      // Lifted against the SCAFFOLD, not the surface: the scaffold is the
      // lighter of the two grounds and therefore the harder test for a dark
      // accent, so clearing it clears the surface as well. 3.5 rather than a
      // bare 3.0 leaves margin for the accent used as a hairline.
      final accent = _liftOnto(seed, grayGround, 3.5);
      final onAccent = _readableOn(accent);
      final cs = ColorScheme.fromSeed(
        seedColor: const Color(0xFF808080),
        brightness: Brightness.dark,
      ).copyWith(
        primary: accent,
        onPrimary: onAccent,
        secondary: accent,
        onSecondary: onAccent,
        tertiary: accent,
        onTertiary: onAccent,
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: cs,
        scaffoldBackgroundColor: grayGround,
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
