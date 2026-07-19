import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:pos_app/onboarding/onboarding_model.dart';

/// One slide that showcases everything the POS ships with — a staggered grid of
/// feature tiles. Built for first-time training: the reseller can point at each
/// tile to explain what the customer already has.
class FeaturesSlide extends StatelessWidget {
  const FeaturesSlide({super.key});

  static const _features = <OnboardingSlide>[
    OnboardingSlide(
      icon: Icons.qr_code_scanner,
      title: 'Barcode scanning',
      body: 'Scan to ring up or find any product instantly.',
    ),
    OnboardingSlide(
      icon: Icons.tv,
      title: 'Customer display',
      body: 'Show the order and total on a second screen.',
    ),
    OnboardingSlide(
      icon: Icons.kitchen,
      title: 'Kitchen display',
      body: 'Send orders straight to the kitchen (KDS).',
    ),
    OnboardingSlide(
      icon: Icons.backup,
      title: 'Backups',
      body: 'Automatic local backups keep your data safe.',
    ),
    OnboardingSlide(
      icon: Icons.monitor_weight,
      title: 'Weighing scale',
      body: 'Sell by weight over a connected serial scale.',
    ),
    OnboardingSlide(
      icon: Icons.local_offer,
      title: 'Promotions',
      body: 'Automatic discounts and special pricing.',
    ),
    OnboardingSlide(
      icon: Icons.card_membership,
      title: 'Loyalty cards',
      body: 'Points and rewards that bring guests back.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        children: [
          Text(
            'Everything you get',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'All of this is built in — no add-ons to buy.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: [
                for (var i = 0; i < _features.length; i++)
                  _FeatureTile(_features[i])
                      .animate(delay: (i * 70).ms)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.14, end: 0, curve: Curves.easeOut),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile(this.data);

  final OnboardingSlide data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Fixed size so every tile matches regardless of body length; the body fills
    // the remaining space and ellipsizes rather than pushing the tile taller.
    return Container(
      width: 168,
      height: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.14),
            ),
            child: Icon(data.icon, size: 24, color: cs.primary),
          ),
          const SizedBox(height: 10),
          Text(
            data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              data.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
