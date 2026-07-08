import 'package:flutter/material.dart';

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

  /// Foreground (text/icon) that reads on top of a filled status colour — e.g.
  /// white on the green "Pay" button. Centralised so it's one deliberate choice.
  Color get onStatusColor => Colors.white;
}
