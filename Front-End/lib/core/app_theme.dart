import 'package:flutter/material.dart';
import 'ilyass_dropdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/core/device_theme_mode_provider.dart';

/// Central theme construction, shared by [MyApp] (the live app theme) and the
/// customer display (which mirrors the same colours). Keeping it in one place
/// means the customer-facing screen can never drift from the operator's theme.

/// The product's own accent: octopus blue.
///
/// The exact flat blue `assets/icon.svg` is drawn in — one value, shared by the
/// mark and the interface, so nothing has to be kept in step by eye. It
/// replaces the blood red `#A4161A`, which came with the navy-plated mark the
/// brand no longer uses.
///
/// It measures **3.06:1** on white. That is over the WCAG bar for a large
/// graphic shape and UNDER it for text, which is the opposite of the red it
/// replaced, and it is why [buildAppTheme] never paints with this value raw on
/// a light ground: [_solidAccent] darkens it (same hue) until small text in it
/// clears 4.5:1. On the dark grounds it already clears, and paints as-is.
const Color kBrandAccent = Color(0xFF389DCB);

/// The accent swatches — ONE list, read by both the Settings picker and the
/// onboarding picker, so the two cannot drift apart again.
///
/// Brand first, on purpose: it is what the client defaults and the server seed
/// a new company with. It was once missing from the onboarding list, so anyone
/// who touched that picker moved the app AWAY from its own branding with no
/// way back. The rest are spread round the colour wheel, and in lightness, so
/// no two read as the same colour once applied (see [_solidAccent]). `name` is
/// a stable key the pickers translate — never shown raw.
const List<({String name, Color color})> kAccentPalette = [
  (name: 'Sky', color: kBrandAccent),
  (name: 'Blue', color: Color(0xFF2563EB)),
  (name: 'Teal', color: Color(0xFF00897B)),
  (name: 'Green', color: Color(0xFF43A047)),
  (name: 'Gold', color: Color(0xFFF9A825)),
  (name: 'Orange', color: Color(0xFFEF6C00)),
  (name: 'Red', color: Color(0xFFD32F2F)),
  (name: 'Pink', color: Color(0xFFD81B60)),
  (name: 'Purple', color: Color(0xFF8E24AA)),
  (name: 'Brown', color: Color(0xFF6D4C41)),
  (name: 'Slate', color: Color(0xFF546E7A)),
];

/// `#RRGGBB` for [color] — the form the accent settings store.
String accentHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

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
/// more lenient than WCAG: for the coral this brand shipped at the time it
/// answers "dark", which puts
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

/// The operator's accent kept SOLID: their hue and saturation, with only the
/// lightness moved — darker on a light ground, lighter on a dark one — until it
/// clears [target] against every one of [grounds].
///
/// Every mode used to hand the accent to `ColorScheme.fromSeed`, whose tonal
/// palette caps the primary's chroma at 36. That is what made a picked red come
/// out brick in the light theme and pastel pink in the dark ones — the same
/// pink the Pink swatch became — so the warm accents all looked alike and none
/// looked like its swatch. Hue is what the operator picked; lightness is what
/// the theme has to be able to move.
///
/// The gray theme has always painted this way (grey everything, one colour
/// showing through undiluted): the blood red the brand once used measured
/// **2.25:1** on the gray ground and all but vanished until it was lifted.
Color _solidAccent(Color seed, List<Color> grounds, double target) {
  bool clears(Color c) =>
      grounds.every((g) => _contrastBetween(c, g) >= target);
  if (clears(seed)) return seed;
  final hsl = HSLColor.fromColor(seed);
  final step = grounds.first.computeLuminance() > 0.18 ? -0.02 : 0.02;
  for (var l = hsl.lightness + step; l >= 0 && l <= 1; l += step) {
    final candidate = hsl.withLightness(l).toColor();
    if (clears(candidate)) return candidate;
  }
  return step < 0 ? Colors.black : Colors.white;
}

/// [cs] with its primary replaced by the solid accent. 4.5 so the accent can
/// carry small text (links, text buttons) on the grounds it sits on, not just
/// shapes. `copyWith(primary:)` does not move `onPrimary`, so it is re-derived
/// here, and `surfaceTint` follows so elevated surfaces tint to the same hue.
ColorScheme _withSolidAccent(ColorScheme cs, Color seed, List<Color> grounds) {
  final accent = _solidAccent(seed, grounds, 4.5);
  return cs.copyWith(
    primary: accent,
    onPrimary: readableOn(accent),
    surfaceTint: accent,
  );
}

/// Black or white, whichever contrasts more with [background] (WCAG). The
/// better of the two always clears 4.5:1, whatever the background.
Color readableOn(Color background) {
  final l = background.computeLuminance();
  final whiteRatio = 1.05 / (l + 0.05);
  final blackRatio = (l + 0.05) / 0.05;
  return blackRatio >= whiteRatio ? Colors.black : Colors.white;
}

/// Builds the app [ThemeData] for a given [mode] (light/dark/dimmed/night/
/// gray/high_contrast) seeded from [seed]. This is the single source of truth
/// for every theme mode in the app.
ThemeData buildAppTheme(String mode, Color seed) =>
    _withHouseMenus(_buildBaseTheme(mode, seed));

/// Rounded, elevated menus in every theme mode — the same surface the house
/// dropdown (`IlyassDropdown`) opens, so a plain menu or a ⋮ popup matches it
/// instead of falling back to Material's squarer defaults.
ThemeData _withHouseMenus(ThemeData theme) {
  final cs = theme.colorScheme;
  final menuStyle = ilyassMenuStyle(cs);
  return theme.copyWith(
    dropdownMenuTheme: DropdownMenuThemeData(menuStyle: menuStyle),
    menuTheme: MenuThemeData(style: menuStyle),
    popupMenuTheme: PopupMenuThemeData(
      color: cs.surfaceContainerHigh,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
  );
}

ThemeData _buildBaseTheme(String mode, Color seed) {
  switch (mode) {
    case 'light':
      final cs = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
      );
      // No scaffold override: Material 3 grounds the page on `surface`.
      return ThemeData(
        useMaterial3: true,
        colorScheme: _withSolidAccent(cs, seed, [cs.surface]),
      );

    case 'dimmed':
      const ground = Color(0xFF15202B);
      final cs = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF1C2333),
        surfaceContainerLowest: const Color(0xFF111927),
        surfaceContainerLow: const Color(0xFF1A2030),
        surfaceContainer: const Color(0xFF202736),
        surfaceContainerHigh: const Color(0xFF263040),
        surfaceContainerHighest: const Color(0xFF283045),
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: _withSolidAccent(cs, seed, [cs.surface, ground]),
        scaffoldBackgroundColor: ground,
        cardColor: const Color(0xFF1C2333),
      );

    case 'night':
      final cs = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF080808),
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0D0D0D),
        surfaceContainer: const Color(0xFF111111),
        surfaceContainerHigh: const Color(0xFF161616),
        surfaceContainerHighest: const Color(0xFF1C1C1C),
        onSurface: Colors.white,
        onSurfaceVariant: const Color(0xFFCCCCCC),
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: _withSolidAccent(cs, seed, [cs.surface, Colors.black]),
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF0D0D0D),
      );

    case 'gray':
      // Grey neutrals with the accent showing through — the one mode that
      // paints secondary and tertiary with it too. `copyWith(primary:)` does
      // not update `onPrimary`: the grey scheme's partner once labelled a
      // coral button at 3.90:1, under AA, so every partner is re-derived.
      const grayGround = Color(0xFF1A1A1A);
      // Lifted against the SCAFFOLD, not the surface: the scaffold is the
      // lighter of the two grounds and therefore the harder test for a dark
      // accent, so clearing it clears the surface as well. 3.5 rather than a
      // bare 3.0 leaves margin for the accent used as a hairline.
      final accent = _solidAccent(seed, [grayGround], 3.5);
      final onAccent = readableOn(accent);
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
      ).copyWith(
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
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: _withSolidAccent(cs, seed, [cs.surface]),
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF111111),
      );

    default: // 'dark'
      final cs = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: _withSolidAccent(cs, seed, [cs.surface]),
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
      'light';
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
