import 'package:flutter/widgets.dart';

/// One feature-showcase slide. Declarative so slides can be reordered, added, or
/// localized without touching layout code — the Phase 2 widgets render a list of
/// these. [icon] is a plain [IconData] so either Material or phosphor_flutter
/// icons can be dropped in.
class OnboardingSlide {
  final IconData icon;
  final String title;
  final String body;

  const OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
  });
}
