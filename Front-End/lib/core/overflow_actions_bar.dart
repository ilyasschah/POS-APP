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

class _OverflowMenuButton extends StatefulWidget {
  final List<Widget> hidden;
  final double slotWidth;
  final double itemHeight;
  const _OverflowMenuButton({
    required this.hidden,
    required this.slotWidth,
    required this.itemHeight,
  });

  @override
  State<_OverflowMenuButton> createState() => _OverflowMenuButtonState();
}

class _OverflowMenuButtonState extends State<_OverflowMenuButton> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
      ),
      menuChildren: [
        // The real action buttons, kept in their exact form so they look and
        // behave identically to the inline ones. A Listener (which sees pointer
        // events regardless of the gesture arena) closes the menu after any tap
        // inside — the tapped button's own onTap still fires first. Deferred to
        // a microtask so closing never pre-empts that tap.
        Listener(
          onPointerUp: (_) => Future.microtask(() {
            if (_controller.isOpen) _controller.close();
          }),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.slotWidth * 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final a in widget.hidden)
                  SizedBox(
                    width: widget.slotWidth,
                    height: widget.itemHeight,
                    child: a,
                  ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        return IconButton(
          icon: Icon(Icons.more_horiz, color: cs.onSurface),
          tooltip: MaterialLocalizations.of(context).showMenuTooltip,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        );
      },
    );
  }
}
