library phosphor_flutter;

import 'package:flutter/material.dart';

// Duotone secondary rendering removed: PhosphorDuotoneIconData is now a typedef
// for IconData, so runtime `is` checks are meaningless. The app has no duotone
// icon usage, so this is a no-op loss of functionality.
class PhosphorIcon extends Icon {
  const PhosphorIcon(
    IconData super.icon, {
    super.key,
    super.size,
    super.fill,
    super.weight,
    super.grade,
    super.opticalSize,
    super.color,
    super.shadows,
    super.semanticLabel,
    super.textDirection,
    this.duotoneSecondaryOpacity = 0.20,
    this.duotoneSecondaryColor,
  });

  final double duotoneSecondaryOpacity;
  final Color? duotoneSecondaryColor;
}
