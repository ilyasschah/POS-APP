import 'package:flutter/material.dart';

import 'package:pos_app/core/app_theme.dart';

/// Semantic status colours (success / warning / danger / info) that adapt to the
/// active theme's brightness, so they stay legible across every theme mode
/// (light, dimmed, dark, night, gray, high-contrast) instead of the hardcoded
/// `Colors.green/red/amber/blue` literals scattered through the UI — which look
/// wrong in the dark/"Night" themes.
///
/// Mirrors the `context.navSidebarBg` token pattern in `navigation/nav_widgets.dart`
/// (a `BuildContext` extension, NOT a Flutter `ThemeExtension`, so nothing needs
/// registering on `ThemeData`). Usage: `color: context.successColor`.
extension StatusColors on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  /// Positive / success (replaces `Colors.green`). Lighter in dark themes so it
  /// keeps contrast on dark surfaces.
  Color get successColor =>
      _isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);

  /// Warning / caution / loyalty accent (replaces `Colors.amber` / `Colors.orange`).
  Color get warningColor =>
      _isDark ? const Color(0xFFFFB74D) : const Color(0xFFEF6C00);

  /// Danger / error / destructive (replaces `Colors.red`). Reuses the theme's
  /// error role so it tracks the colour scheme.
  Color get dangerColor => Theme.of(this).colorScheme.error;

  /// Informational accent (replaces `Colors.blue`).
  Color get infoColor =>
      _isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);

  /// Foreground (text/icons) ON a filled status colour — black or white,
  /// whichever actually reads (WCAG).
  ///
  /// There used to be one blanket white `onStatusColor` for every fill. On the
  /// dark themes' success green (#66BB6A) that is ~2.4:1, and on their pastel
  /// error red ~1.8:1 — labels nobody can read. Pair the foreground with the
  /// fill it sits on, always.
  Color onStatus(Color fill) => readableOn(fill);

  Color get onSuccessColor => onStatus(successColor);
  Color get onWarningColor => onStatus(warningColor);
  Color get onInfoColor => onStatus(infoColor);

  /// The theme's own partner for its error role, which [dangerColor] reuses.
  Color get onDangerColor => Theme.of(this).colorScheme.onError;
}
