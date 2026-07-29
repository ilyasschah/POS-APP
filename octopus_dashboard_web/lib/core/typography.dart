import 'package:flutter/material.dart';

/// Typography helper for the bundled Nunito **variable** font.
///
/// Nunito ships upstream only as a variable font (`Nunito[wght].ttf`), and
/// Flutter does *not* map [TextStyle.fontWeight] onto a variable font's `wght`
/// axis — a style declaring `FontWeight.bold` alone still renders at the
/// font's default instance (regular). Every weight must therefore also carry a
/// matching [FontVariation].
///
/// To make that impossible to forget, widgets must build text styles through
/// [AppText.style] (or the named helpers below) rather than constructing a raw
/// [TextStyle]. If you need to tweak an existing style, use the [WeightedText]
/// extension so the variation stays in sync with the weight.
abstract final class AppText {
  static const String family = 'Nunito';

  /// The single source of truth for building text styles in this app.
  static TextStyle style({
    double size = 14,
    int weight = 400,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: fontWeightOf(weight),
      fontVariations: [FontVariation('wght', weight.toDouble())],
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }

  /// Maps a numeric weight (100–900) to the nearest [FontWeight] constant.
  ///
  /// The [FontWeight] is kept in sync with the variation purely so that
  /// anything reading `style.fontWeight` (tests, semantics, Flutter's own
  /// fallback-font selection) sees the intended value.
  static FontWeight fontWeightOf(int weight) {
    final index = (weight ~/ 100).clamp(1, 9) - 1;
    return FontWeight.values[index];
  }

  // ---- Named roles -------------------------------------------------------
  // Sizes mirror the SwiftUI original: 32pt app title, 38pt hero figure.

  /// "Octopus Owner" login title.
  static TextStyle appTitle(Color c) => style(size: 32, weight: 800, color: c);

  /// The big Total Sales figure on the dashboard.
  static TextStyle hero(Color c) =>
      style(size: 38, weight: 800, color: c, letterSpacing: -0.5);

  /// Screen titles, e.g. "Octopus Dashboard".
  static TextStyle title(Color c) => style(size: 22, weight: 700, color: c);

  /// Glass-card section headings.
  static TextStyle headline(Color c) => style(size: 17, weight: 700, color: c);

  /// The "OVERVIEW" eyebrow above the dashboard title.
  static TextStyle eyebrow(Color c) =>
      style(size: 12, weight: 700, color: c, letterSpacing: 1.2);

  static TextStyle body(Color c) => style(size: 15, weight: 400, color: c);
  static TextStyle bodyStrong(Color c) => style(size: 15, weight: 600, color: c);
  static TextStyle label(Color c) => style(size: 13, weight: 600, color: c);
  static TextStyle caption(Color c) => style(size: 12, weight: 400, color: c);

  /// Full [TextTheme] so `Theme.of(context).textTheme` styles also carry the
  /// correct font variations.
  static TextTheme textTheme(Color primary) => TextTheme(
    displayLarge: style(size: 38, weight: 800, color: primary),
    headlineMedium: style(size: 26, weight: 700, color: primary),
    titleLarge: style(size: 22, weight: 700, color: primary),
    titleMedium: style(size: 17, weight: 700, color: primary),
    titleSmall: style(size: 15, weight: 600, color: primary),
    bodyLarge: style(size: 16, weight: 400, color: primary),
    bodyMedium: style(size: 15, weight: 400, color: primary),
    bodySmall: style(size: 13, weight: 400, color: primary),
    labelLarge: style(size: 15, weight: 700, color: primary),
    labelMedium: style(size: 13, weight: 600, color: primary),
    labelSmall: style(size: 12, weight: 500, color: primary),
  );
}

/// Keeps [TextStyle.fontWeight] and the `wght` font variation in lockstep.
extension WeightedText on TextStyle {
  /// Re-weights this style, updating the variable-font axis too.
  TextStyle weighted(int weight) => copyWith(
    fontWeight: AppText.fontWeightOf(weight),
    fontVariations: [FontVariation('wght', weight.toDouble())],
  );

  /// Recolors without touching weight/variation.
  TextStyle tinted(Color color) => copyWith(color: color);
}
