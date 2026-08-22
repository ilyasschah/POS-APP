import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// The widest a column of label→value rows should be allowed to get.
///
/// On a 2560px monitor an unconstrained row puts the label against the far
/// left edge and its amount against the far right, and the eye stops reading
/// them as the same line. Cap the *content*, not the window: pair this with
/// `Center` + `ConstrainedBox`, which is a no-op on anything narrower.
const double kMaxReadableWidth = 1200;

/// Shared responsive helpers so screens adapt to smaller tablets (e.g. a 7"
/// device) without every widget re-deriving `MediaQuery` breakpoints.
///
/// The app was originally sized for 10–13" tablets. On a physically small
/// screen the layout stays *structurally* fine (Expanded / LayoutBuilder /
/// resizable panels absorb the width), but density is too high and fixed-width
/// dialogs can exceed the viewport. These helpers give one consistent set of
/// breakpoints to tighten padding, drop optional chrome, and clamp dialog
/// widths on compact devices.
///
/// Breakpoints are on the **shortest useful axis**: `width` for side-by-side
/// panels, `height` for tall dialogs. They are logical (dp), so a 1920×1200
/// panel that the OEM renders at devicePixelRatio 2.0 reports ~960×600 here —
/// which is exactly the "compact" case we want to catch.
extension Responsive on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// A 7"-class tablet or a narrow window — tighten spacing, prefer icon-only
  /// chrome, and let dialogs use most of the width.
  bool get isCompact => screenWidth < 1000;

  /// Very tight (small 7" in portrait, or a split-screen pane) — the most
  /// aggressive density reductions apply here.
  bool get isVeryCompact => screenWidth < 760;

  /// Short viewport — tall dialogs must scroll rather than assume ~800dp.
  bool get isShort => screenHeight < 680;

  /// A width for a fixed-size dialog that never exceeds the viewport: use the
  /// designed [preferred] width on roomy screens, but cap to the screen minus a
  /// small [margin] on compact ones. Prevents a 500dp dialog from running off a
  /// 480dp-wide device.
  double dialogWidth(double preferred, {double margin = 32}) =>
      math.min(preferred, screenWidth - margin);

  /// A max height for a dialog/body so it fits a short screen: at most
  /// [fraction] of the viewport height. Pair with a scroll view for the body.
  double dialogMaxHeight({double fraction = 0.85}) => screenHeight * fraction;
}
