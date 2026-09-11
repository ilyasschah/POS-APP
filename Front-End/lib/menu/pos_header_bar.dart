import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Width of one header button's slot. Every button gets exactly this much,
/// which is what lets the row snap to whole buttons. Wide enough for the label
/// cap the buttons already had (84px of text), so nothing new gets ellipsized.
const double kPosHeaderSlotWidth = 100;

/// Width of the soft fade on an edge that hides buttons.
const double _kFadeWidth = 28;

/// The POS header's order-control buttons as a finger-driven slider.
///
///  * **Left-aligned.** One button sits at the far left; more add to the
///    right, and the ones that do not fit wait past the right edge — under the
///    cart, which is where the header strip ends.
///  * **Snaps to whole buttons.** Every child gets a fixed [slotWidth] slot and
///    a swipe settles on a slot boundary: `1 2 3 4 5 6` → swipe →
///    `3 4 5 6 7 8`, never on half a button.
///  * **No scrollbar.** The only hint that buttons are hidden is a soft fade and
///    a small chevron on that side; tapping the chevron pages by a screenful.
///  * **Every pointer drags it.** Finger, stylus, trackpad — and the MOUSE,
///    which Flutter's desktop default refuses to drag with. Windows touch tills
///    commonly report a finger as a mouse, so without it the slider was dead on
///    exactly the hardware it exists for. A vertical wheel steps it too.
class PosHeaderBar extends StatefulWidget {
  const PosHeaderBar({
    super.key,
    required this.children,
    this.slotWidth = kPosHeaderSlotWidth,
  });

  /// The buttons, in display order.
  final List<Widget> children;
  final double slotWidth;

  @override
  State<PosHeaderBar> createState() => _PosHeaderBarState();
}

class _PosHeaderBarState extends State<PosHeaderBar> {
  final ScrollController _controller = ScrollController();

  /// Whether buttons are hidden past the start / the end edge.
  bool _hiddenBefore = false;
  bool _hiddenAfter = false;

  static const _moveDuration = Duration(milliseconds: 260);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateEdges);
    // The first read of which edges hide buttons, once the list has a size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateEdges();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateEdges);
    _controller.dispose();
    super.dispose();
  }

  void _updateEdges() {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    if (!p.hasContentDimensions) return;
    final before = p.pixels > p.minScrollExtent + 0.5;
    final after = p.pixels < p.maxScrollExtent - 0.5;
    if (before != _hiddenBefore || after != _hiddenAfter) {
      setState(() {
        _hiddenBefore = before;
        _hiddenAfter = after;
      });
    }
  }

  /// Moves by [slots] whole buttons from the current (snapped) position.
  void _moveBy(int slots) {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final slot = widget.slotWidth;
    final from = (p.pixels / slot).roundToDouble() * slot;
    final to = (from + slots * slot).clamp(p.minScrollExtent, p.maxScrollExtent);
    _controller.animateTo(
      to,
      duration: _moveDuration,
      curve: Curves.easeOutCubic,
    );
  }

  /// One screenful of whole buttons — never less than one.
  int get _pageSlots {
    if (!_controller.hasClients) return 1;
    final visible =
        _controller.position.viewportDimension / widget.slotWidth;
    return math.max(1, visible.floor());
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // Only the wheel the list itself ignores — a plain vertical one. A
    // horizontal wheel or a trackpad is already the list's own business.
    if (event.scrollDelta.dy == 0 || event.scrollDelta.dx != 0) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final dy = (e as PointerScrollEvent).scrollDelta.dy;
      _moveBy(dy > 0 ? 1 : -1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slotWidth;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxWidth;
        final content = widget.children.length * slot;
        // Pad the end so the furthest scroll position is a whole number of
        // slots — then the row starts on a whole button even at the very end.
        final endPad =
            content > viewport ? (slot - viewport % slot) % slot : 0.0;

        final list = ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            overscroll: false,
            dragDevices: PointerDeviceKind.values.toSet(),
          ),
          child: ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: _SlotSnapPhysics(slot: slot),
            padding: EdgeInsetsDirectional.only(end: endPad),
            itemExtent: slot,
            itemCount: widget.children.length,
            // Centred in its slot at its own size, so a highlighted button's
            // box stays the button's rather than a full-height stripe.
            itemBuilder: (context, i) => Center(child: widget.children[i]),
          ),
        );

        return NotificationListener<ScrollMetricsNotification>(
          // Content or viewport changed (a button switched on, the cart
          // resized): re-read which edges hide buttons once this frame is done.
          onNotification: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updateEdges();
            });
            return false;
          },
          child: Listener(
            onPointerSignal: _onPointerSignal,
            child: Stack(
              children: [
                Positioned.fill(child: _fadeEdges(context, list)),
                if (_hiddenBefore)
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    bottom: 0,
                    child: _chevron(context, before: true),
                  ),
                if (_hiddenAfter)
                  PositionedDirectional(
                    end: 0,
                    top: 0,
                    bottom: 0,
                    child: _chevron(context, before: false),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// A soft fade on each edge that hides buttons — the "there is more" signal,
  /// since there is deliberately no scrollbar.
  ///
  /// 🚨 The ShaderMask is ALWAYS in the tree, fully opaque when nothing is
  /// hidden. Inserting it only once buttons hide re-parented the list mid-
  /// gesture: Flutter rebuilt the Scrollable from scratch, the drag or fling
  /// under the finger was lost, and the row jumped back to the start.
  Widget _fadeEdges(BuildContext context, Widget child) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final f = rect.width <= 0
            ? 0.0
            : (_kFadeWidth / rect.width).clamp(0.0, 0.5);
        // An alpha mask, not a colour anyone sees: opaque keeps the button,
        // transparent fades it — which is why these are not theme colours.
        return LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [
            _hiddenBefore ? Colors.transparent : Colors.black,
            Colors.black,
            Colors.black,
            _hiddenAfter ? Colors.transparent : Colors.black,
          ],
          stops: [0, f, 1 - f, 1],
        ).createShader(rect, textDirection: Directionality.of(context));
      },
      child: child,
    );
  }

  Widget _chevron(BuildContext context, {required bool before}) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Material(
        color: cs.surfaceContainerHighest,
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _moveBy(before ? -_pageSlots : _pageSlots),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              before ? Icons.chevron_left : Icons.chevron_right,
              size: 20,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Settles every swipe on a whole slot.
///
/// A plain page snap moves one slot per fling, which makes a hard flick feel
/// broken. This lets the fling travel as far as it naturally would, then snaps
/// that resting point to the nearest whole button — a nudge moves one, a flick
/// moves several, and neither ever stops half-way.
class _SlotSnapPhysics extends ScrollPhysics {
  const _SlotSnapPhysics({required this.slot, super.parent});

  final double slot;

  @override
  _SlotSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _SlotSnapPhysics(slot: slot, parent: buildParent(ancestor));

  double _snap(ScrollMetrics position, double pixels) =>
      ((pixels / slot).roundToDouble() * slot)
          .clamp(position.minScrollExtent, position.maxScrollExtent);

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Dragged past an edge: the parent brings it back.
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    // Where a free fling would have come to rest (10s is far past the end of
    // any fling), then the nearest whole button to that.
    final free = super.createBallisticSimulation(position, velocity);
    final rest = free?.x(10.0) ?? position.pixels;
    final target = _snap(position, rest);
    if ((target - position.pixels).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}
