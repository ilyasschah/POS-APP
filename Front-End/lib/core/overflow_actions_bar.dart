import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A horizontal bar of action buttons that shows as many as fit and collapses
/// the rest into an overflow menu — the Windows-taskbar "show hidden icons"
/// pattern. Each action occupies a fixed [slotWidth], so the fit is exact and
/// the inline row can never RenderFlex-overflow (the reason the POS header ran
/// off a 7" screen). Hidden actions appear in a popup that closes when one is
/// tapped.
///
/// Give this a **bounded width** (e.g. an `AppBar` `title:` slot with
/// `titleSpacing: 0`, or an `Expanded`) — it fills the available width via a
/// `LayoutBuilder` and splits the actions against it.
class OverflowActionsBar extends StatelessWidget {
  /// The action widgets, in priority order (earlier ones stay visible longest).
  final List<Widget> actions;

  /// Fixed width of every action slot. Sized for an icon over a short label.
  final double slotWidth;

  /// Row height (matches the header action buttons).
  final double height;

  const OverflowActionsBar({
    super.key,
    required this.actions,
    this.slotWidth = 100,
    this.height = 60,
  });

  static const double _chevronWidth = 48;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return SizedBox(height: height);

    return LayoutBuilder(
      builder: (context, c) {
        final maxW =
            c.maxWidth.isFinite ? c.maxWidth : actions.length * slotWidth;
        final n = actions.length;

        Widget slot(Widget w) =>
            SizedBox(width: slotWidth, height: height, child: w);

        // Everything fits — no overflow menu needed.
        if (n * slotWidth <= maxW) {
          return SizedBox(
            height: height,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final a in actions) slot(a)],
            ),
          );
        }

        // Reserve a slot for the chevron, then show what fits.
        final visibleCount =
            math.max(0, ((maxW - _chevronWidth) / slotWidth).floor());
        final visible = actions.take(visibleCount).toList();
        final hidden = actions.skip(visibleCount).toList();

        return SizedBox(
          height: height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final a in visible) slot(a),
              _OverflowMenuButton(
                hidden: hidden,
                slotWidth: slotWidth,
                itemHeight: height,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OverflowMenuButton extends StatelessWidget {
  final List<Widget> hidden;
  final double slotWidth;
  final double itemHeight;
  const _OverflowMenuButton({
    required this.hidden,
    required this.slotWidth,
    required this.itemHeight,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // PopupMenuButton (not MenuAnchor): MenuAnchor keeps an inherited scope in
    // the tree and throws `_dependents.isEmpty` when the header rebuilds (e.g.
    // renaming the POS). PopupMenuButton builds its menu imperatively as a
    // route, so nothing persistent is torn down. The hidden buttons render in
    // their exact form inside one non-selectable item; the menu dismisses on an
    // outside tap. Each button keeps its own tap handler.
    return PopupMenuButton<int>(
      icon: Icon(Icons.more_horiz, color: cs.onSurface),
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      color: cs.surfaceContainerHigh,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          enabled: false,
          padding: const EdgeInsets.all(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: slotWidth * 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final a in hidden)
                  SizedBox(width: slotWidth, height: itemHeight, child: a),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
