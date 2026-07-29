import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings.dart';
import 'theme.dart';

/// A translucent frosted "Liquid Glass" panel.
///
/// ## Why blur is opt-in rather than always-on
///
/// [BackdropFilter] blurs whatever is painted *behind* it. The page background
/// in this design is a literally flat black or white, and blurring a flat
/// color is a visual no-op — it costs a full-screen GPU pass and changes not a
/// single pixel. So content cards (of which the dashboard alone stacks five)
/// render as tint + border only, which looks identical over the flat base and
/// keeps scrolling smooth on web.
///
/// Blur is enabled where it genuinely reads — surfaces that float *over*
/// scrollable content: dialogs, bottom sheets and the persistent nav
/// (see [GlassCard.overlay]).
///
/// When the user turns "Liquid Glass Effect" off in Settings, panels become
/// flat and fully opaque and no blur is applied anywhere.
class GlassCard extends ConsumerWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppTheme.cardRadius,
    this.blurred = false,
    this.onTap,
    this.margin,
    this.border = true,
  });

  /// A glass surface that floats above scrollable content, where backdrop
  /// blur is actually visible: dialogs, sheets, sidebars.
  const GlassCard.overlay({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppTheme.sheetRadius,
    this.onTap,
    this.margin,
    this.border = true,
  }) : blurred = true;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool blurred;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final bool border;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);

    // The tint is white over a black base and black over a white base. Black
    // at the same alpha reads much heavier than white does, so the light
    // theme uses a softened factor to land on the same perceived weight.
    final tint = palette.primaryText;
    final alpha = isDark
        ? settings.glassOpacity
        : settings.glassOpacity * 0.4;

    final Color fill;
    if (settings.glassEnabled) {
      fill = tint.withValues(alpha: alpha);
    } else {
      // Reduce-transparency mode: pre-blend to an opaque surface so nothing
      // shows through and no compositing layer is needed.
      fill = Color.alphaBlend(tint.withValues(alpha: alpha), palette.base);
    }

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: shape,
        border: border
            ? Border.all(
                color: tint.withValues(alpha: isDark ? 0.2 : 0.12),
                width: 1,
              )
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap != null) {
      surface = Stack(
        children: [
          surface,
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: shape,
                splashColor: palette.accent.withValues(alpha: 0.12),
                highlightColor: palette.accent.withValues(alpha: 0.06),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      );
    }

    Widget result = ClipRRect(borderRadius: shape, child: surface);

    if (blurred && settings.glassEnabled) {
      result = ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: surface,
        ),
      );
    }

    if (margin != null) {
      result = Padding(padding: margin!, child: result);
    }
    return result;
  }
}

/// Pill-shaped translucent button used for the dashboard's "Filter Date"
/// control and other lightweight chrome.
class GlassPill extends ConsumerWidget {
  const GlassPill({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = palette.primaryText;
    final alpha = isDark
        ? settings.glassOpacity * 0.7
        : settings.glassOpacity * 0.3;

    Widget button = Material(
      color: settings.glassEnabled
          ? tint.withValues(alpha: alpha)
          : Color.alphaBlend(tint.withValues(alpha: alpha), palette.base),
      shape: StadiumBorder(
        side: BorderSide(
          color: tint.withValues(alpha: isDark ? 0.16 : 0.1),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
