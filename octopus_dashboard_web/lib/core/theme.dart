import 'package:flutter/material.dart';

import 'typography.dart';

/// Semantic colors that Material's [ColorScheme] doesn't model.
///
/// Exposed as a [ThemeExtension] so widgets never hardcode a literal color and
/// every value automatically flips with the active brightness.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.accent,
    required this.indigo,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.neutral,
    required this.primaryText,
    required this.base,
  });

  /// Teal. Primary buttons, currency figures, active nav tint.
  final Color accent;

  /// Secondary chart/accent hue: hourly chart line and Top Customers totals.
  final Color indigo;

  /// "Active" status pill.
  final Color positive;

  /// Zero/negative stock, "Disabled" pill, login errors.
  final Color negative;

  /// Error-state warning icon.
  final Color warning;

  /// "Unassigned" stock label.
  final Color neutral;

  /// Equivalent of SwiftUI's `.primary` — white on dark, black on light.
  final Color primaryText;

  /// The literal page background: black in dark mode, white in light mode.
  final Color base;

  /// [primaryText] at a reduced opacity, for secondary/caption text.
  Color dim([double opacity = 0.65]) => primaryText.withValues(alpha: opacity);

  static const AppPalette dark = AppPalette(
    accent: Color(0xFF40C8E0),
    indigo: Color(0xFF7986CB),
    positive: Color(0xFF4ADE80),
    negative: Color(0xFFFF6B6B),
    warning: Color(0xFFFFB020),
    neutral: Color(0xFF8E8E93),
    primaryText: Color(0xFFFFFFFF),
    base: Color(0xFF000000),
  );

  static const AppPalette light = AppPalette(
    accent: Color(0xFF30B0C7),
    indigo: Color(0xFF3F51B5),
    positive: Color(0xFF1E8E3E),
    negative: Color(0xFFD93025),
    warning: Color(0xFFE07C00),
    neutral: Color(0xFF6E6E73),
    primaryText: Color(0xFF000000),
    base: Color(0xFFFFFFFF),
  );

  @override
  AppPalette copyWith({
    Color? accent,
    Color? indigo,
    Color? positive,
    Color? negative,
    Color? warning,
    Color? neutral,
    Color? primaryText,
    Color? base,
  }) {
    return AppPalette(
      accent: accent ?? this.accent,
      indigo: indigo ?? this.indigo,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      warning: warning ?? this.warning,
      neutral: neutral ?? this.neutral,
      primaryText: primaryText ?? this.primaryText,
      base: base ?? this.base,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      accent: Color.lerp(accent, other.accent, t)!,
      indigo: Color.lerp(indigo, other.indigo, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      base: Color.lerp(base, other.base, t)!,
    );
  }
}

/// Convenient `context.palette` access.
extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

abstract final class AppTheme {
  /// Card / sheet corner radius — large and soft, matching the iOS original.
  static const double cardRadius = 24;
  static const double sheetRadius = 28;

  /// Buttons and inputs.
  static const double controlRadius = 12;

  static ThemeData build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final textTheme = AppText.textTheme(palette.primaryText);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.accent,
          brightness: brightness,
        ).copyWith(
          primary: palette.accent,
          // The design layers translucent glass over a literally black/white
          // base rather than Material's tinted surfaces.
          surface: palette.base,
          onSurface: palette.primaryText,
          error: palette.negative,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.base,
      canvasColor: palette.base,
      fontFamily: AppText.family,
      textTheme: textTheme,
      extensions: [palette],
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(
        color: palette.primaryText.withValues(alpha: 0.1),
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: palette.primaryText),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.accent),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF1C1C1E)
            : const Color(0xFF2C2C2E),
        contentTextStyle: AppText.body(Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: _onAccent(palette.accent),
          textStyle: AppText.style(size: 15, weight: 700),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          textStyle: AppText.style(size: 15, weight: 600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.primaryText.withValues(alpha: 0.08),
        hintStyle: AppText.body(palette.dim(0.4)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(palette.accent),
        errorBorder: _inputBorder(palette.negative),
        focusedErrorBorder: _inputBorder(palette.negative),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(sheetRadius),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      // Web/desktop: dragging with a mouse should still scroll lists.
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          palette.primaryText.withValues(alpha: 0.25),
        ),
        radius: const Radius.circular(8),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(controlRadius),
    borderSide: BorderSide(
      color: color,
      width: color == Colors.transparent ? 0 : 1.5,
    ),
  );

  /// Picks black or white for text sitting on the accent color, whichever
  /// gives better contrast.
  static Color _onAccent(Color accent) =>
      accent.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  static Color onAccent(Color accent) => _onAccent(accent);
}
