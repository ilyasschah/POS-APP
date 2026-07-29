import 'package:flutter/material.dart';

import '../core/breakpoints.dart';
import '../core/glass.dart';
import '../core/theme.dart';

/// A single glass panel hosting a lazily-built, divider-separated list.
///
/// Uses [ListView.separated] rather than a `Column` of mapped children so rows
/// are only built as they scroll into view.
class ListPanel extends StatelessWidget {
  const ListPanel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        padding: padding,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: palette.primaryText.withValues(alpha: 0.08),
        ),
      ),
    );
  }
}

/// A tappable list row with a consistent hit area and hover/press feedback.
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: palette.accent.withValues(alpha: 0.1),
        highlightColor: palette.accent.withValues(alpha: 0.05),
        hoverColor: palette.primaryText.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: child,
        ),
      ),
    );
  }
}

/// Shared page chrome: centers content and caps its width on wide monitors.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.maxWidth = Layout.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
