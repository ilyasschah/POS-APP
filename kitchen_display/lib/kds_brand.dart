import 'package:flutter/material.dart';

/// The two brand values this app paints with.
///
/// The KDS used to run on blueGrey — `Colors.blueGrey` as the Material seed and
/// a literal `#546E7A` repeated in three places for the chrome. It was never
/// the brand, just a colour that read well in a kitchen. Now it is the brand,
/// and it is declared once.

/// Octopus blue — the flat colour the logo is drawn in, and `kBrandAccent` in
/// the POS (`Front-End/lib/core/app_theme.dart`).
///
/// This is the Material SEED, not a paint. It measures 3.06:1 on white, which
/// is over the bar for a shape and under it for text, so `ColorScheme.fromSeed`
/// derives the tones that actually carry content.
const Color kKdsBrand = Color(0xFF389DCB);

/// The same blue darkened until WHITE text on it clears WCAG AA — 4.67:1.
///
/// Every solid brand-coloured surface in this app carries white content: the
/// app bar, the onboarding hero, the boot splash. [kKdsBrand] under white
/// measures 3.06:1 and fails, so those three use this instead. It is the same
/// value the marketing site derives as `--accent-strong`, from the same seed.
///
/// 🚨 A kitchen screen is the worst viewing environment the product ships to —
/// glare, steam, and a cook reading it from two metres away mid-service. This
/// is the one surface where the contrast bar is a floor, not a target.
const Color kKdsBrandInk = Color(0xFF2A7CA1);
