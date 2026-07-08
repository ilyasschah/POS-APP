library phosphor_flutter;

import 'package:flutter/widgets.dart';

// Dart 3.12 made IconData final, so subclassing is no longer allowed.
// We use type aliases so the public API (PhosphorIconData, PhosphorFlatIconData,
// PhosphorDuotoneIconData as types and return-type annotations) keeps compiling.
// All icon constants were regenerated to use IconData(...) directly.
typedef PhosphorIconData = IconData;
typedef PhosphorFlatIconData = IconData;
typedef PhosphorDuotoneIconData = IconData;
