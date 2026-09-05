// Pins the brand accent to ONE value, and pins every theme mode built from it
// to the WCAG AA contrast bar.
//
// Two bugs live here, and neither is caught by `flutter analyze`.
//
// 1. The accent is declared in four places — `kBrandAccent`, the settings
//    default, the onboarding colour picker, and the backend's company seeder.
//    Three of them agreeing is not enough: a terminal reads its accent from the
//    server, falls back to the settings default, and falls back again to
//    `kBrandAccent`, so a drift between them shows up only on whichever of
//    those three paths the operator happens to take.
//
// 2. `ColorScheme.copyWith(primary:)` does NOT update `onPrimary`. The `gray`
//    mode overrode primary/secondary/tertiary with the raw accent and left the
//    grey scheme's partners behind, so a coral-filled button was labelled in a
//    dark teal at 3.90:1 — under the 4.5:1 AA bar, and invisible to any test
//    that only asks "does the theme build?". Recolouring the app from blue to
//    coral is exactly the kind of change that walks into this.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/core/app_theme.dart';

/// The WCAG 2.1 contrast ratio between two opaque colours.
double _ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

const _modes = ['light', 'dark', 'dimmed', 'night', 'gray', 'high_contrast'];

void main() {
  group('the brand accent is declared once', () {
    test('kBrandAccent is the brand blood red', () {
      expect(_hex(kBrandAccent), '#A4161A');
    });

    test('the settings default matches the compiled-in constant', () {
      // A terminal with no server-supplied accent falls back to this string;
      // if it drifts from kBrandAccent the app changes colour depending on
      // which fallback fired.
      expect(
        parseAccentColor(kSettingDefaults[SettingKeys.themeAccentColor]),
        kBrandAccent,
      );
    });

    test('a null or unparseable accent falls back to the brand, not to blue',
        () {
      expect(parseAccentColor(null), kBrandAccent);
      expect(parseAccentColor('not a colour'), kBrandAccent);
    });

    test('a short or empty accent falls back instead of parsing to garbage',
        () {
      // None of these throw, which is why guarding only against an exception
      // was not enough. '' and '#' both left 'FF', parsing as 0x000000FF — a
      // fully TRANSPARENT colour, so the app painted invisible buttons.
      for (final bad in ['', '#', 'F00', '#F00', 'FF41', '#A4161AFF']) {
        expect(parseAccentColor(bad), kBrandAccent,
            reason: '"$bad" must fall back, not parse');
        expect(parseAccentColor(bad).a, 1.0,
            reason: '"$bad" must never yield a transparent accent');
      }
    });

    test('a real hex still wins — the operator keeps their own choice', () {
      expect(parseAccentColor('#2196F3'), const Color(0xFF2196F3));
      expect(parseAccentColor('2196F3'), const Color(0xFF2196F3));
      expect(parseAccentColor('  #2196f3  '), const Color(0xFF2196F3));
    });
  });

  group('every theme mode stays legible on the brand accent', () {
    for (final mode in _modes) {
      test('$mode clears WCAG AA', () {
        final theme = buildAppTheme(mode, kBrandAccent);
        final cs = theme.colorScheme;

        // A button label sits on the primary fill. This is the one that broke.
        expect(
          _ratio(cs.onPrimary, cs.primary),
          greaterThanOrEqualTo(4.5),
          reason: '$mode: ${_hex(cs.onPrimary)} on ${_hex(cs.primary)} — '
              'a label on an accent-filled button must clear AA',
        );

        // Body text on the surface it sits on.
        expect(_ratio(cs.onSurface, cs.surface), greaterThanOrEqualTo(4.5),
            reason: '$mode: body text on surface');
        expect(
            _ratio(cs.onSurfaceVariant, cs.surface), greaterThanOrEqualTo(4.5),
            reason: '$mode: secondary text on surface');

        // The accent used as a shape — an icon, a border, a selected indicator.
        // 3:1 is the bar for a UI component rather than for text.
        expect(_ratio(cs.primary, cs.surface), greaterThanOrEqualTo(3.0),
            reason: '$mode: the accent as an icon or border on surface');
        expect(
            _ratio(cs.primary, theme.scaffoldBackgroundColor),
            greaterThanOrEqualTo(3.0),
            reason: '$mode: the accent against the page ground');

        // Errors must stay findable in every mode, accent or no accent.
        expect(_ratio(cs.error, cs.surface), greaterThanOrEqualTo(3.0),
            reason: '$mode: the error colour on surface');
      });
    }

    test('the dark modes keep their own surfaces rather than tinting to red',
        () {
      // The dimmed and night grounds are deliberate values, not generated from
      // the seed. Changing the accent must not move them.
      expect(_hex(buildAppTheme('dimmed', kBrandAccent).scaffoldBackgroundColor),
          '#15202B');
      expect(_hex(buildAppTheme('night', kBrandAccent).scaffoldBackgroundColor),
          '#000000');
      expect(
          _hex(buildAppTheme('high_contrast', kBrandAccent)
              .scaffoldBackgroundColor),
          '#000000');
      expect(_hex(buildAppTheme('gray', kBrandAccent).scaffoldBackgroundColor),
          '#1A1A1A');
    });

    test('an operator-chosen accent is held to the same bar', () {
      // The bug was found with coral, but nothing about it was coral-specific:
      // any mid-tone seed can strand a copyWith'd partner. These are the seeds
      // the onboarding picker offers, so they are the ones that ship.
      for (final seed in const [
        Color(0xFF2196F3), // the old blue
        Color(0xFF4CAF50),
        Color(0xFFFFEB3B), // a light seed — the black/white choice flips here
        Color(0xFF9C27B0),
      ]) {
        for (final mode in _modes) {
          final cs = buildAppTheme(mode, seed).colorScheme;
          expect(
            _ratio(cs.onPrimary, cs.primary),
            greaterThanOrEqualTo(4.5),
            reason: '$mode with seed ${_hex(seed)}: '
                '${_hex(cs.onPrimary)} on ${_hex(cs.primary)}',
          );
        }
      }
    });
  });
}
