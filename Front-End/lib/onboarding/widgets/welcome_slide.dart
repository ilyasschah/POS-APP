import 'package:flutter/material.dart';

import 'package:pos_app/onboarding/widgets/onboarding_scaffold.dart';

/// First slide: brand + one-line value proposition.
class WelcomeSlide extends StatelessWidget {
  const WelcomeSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingSlideLayout(
      illustration: OnboardingIllustration(Icons.point_of_sale),
      title: 'Welcome to your POS',
      body: 'A fast, offline-first point of sale for your counter and your '
          'tablets. Set it up in a few quick taps.',
    );
  }
}
