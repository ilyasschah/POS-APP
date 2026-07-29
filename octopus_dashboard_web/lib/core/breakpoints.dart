import 'package:flutter/widgets.dart';

/// The three responsive layout tiers the whole app switches on.
enum LayoutTier {
  /// < 600px — phone, or the installed home-screen PWA. Bottom navigation.
  compact,

  /// 600–1024px — tablet portrait / small laptop window. Navigation rail.
  medium,

  /// > 1024px — desktop browser. Full sidebar with icons + labels.
  expanded;

  bool get isCompact => this == LayoutTier.compact;
  bool get isExpanded => this == LayoutTier.expanded;

  /// True where a modal *dialog* reads better than a bottom sheet.
  bool get prefersDialog => this != LayoutTier.compact;

  static LayoutTier of(double width) {
    if (width < compactMaxWidth) return LayoutTier.compact;
    if (width <= mediumMaxWidth) return LayoutTier.medium;
    return LayoutTier.expanded;
  }

  /// Resolves the tier from the enclosing media query.
  static LayoutTier watch(BuildContext context) =>
      LayoutTier.of(MediaQuery.sizeOf(context).width);

  static const double compactMaxWidth = 600;
  static const double mediumMaxWidth = 1024;
}

abstract final class Layout {
  /// Caps line length on ultra-wide monitors so content stays readable
  /// instead of stretching to 1920px.
  static const double maxContentWidth = 1100;

  /// Login card width cap.
  static const double maxFormWidth = 460;

  /// Modal dialog width cap.
  static const double maxDialogWidth = 520;

  /// Horizontal page padding per tier.
  static EdgeInsets pagePadding(LayoutTier tier) => EdgeInsets.symmetric(
    horizontal: tier.isCompact ? 16 : 24,
    vertical: tier.isCompact ? 12 : 16,
  );
}
