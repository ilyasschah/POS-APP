import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:pos_app/onboarding/onboarding_model.dart';

/// One slide that showcases everything the POS ships with — a staggered grid of
/// feature tiles. Built for first-time training: the reseller can point at each
/// tile to explain what the customer already has.
class FeaturesSlide extends StatelessWidget {
  const FeaturesSlide({super.key});

  // Built per-frame: the titles are localized, so they need a BuildContext.
  static List<OnboardingSlide> _featuresFor(BuildContext context) =>
      <OnboardingSlide>[
    OnboardingSlide(
      icon: Icons.qr_code_scanner,
      title: AppLocalizations.of(context).barcodeScanning,
      body: AppLocalizations.of(context).featBarcodeBody,
    ),
    OnboardingSlide(
      icon: Icons.tv,
      title: AppLocalizations.of(context).customerDisplayLower,
      body: AppLocalizations.of(context).featCustomerDisplayBody,
    ),
    OnboardingSlide(
      icon: Icons.kitchen,
      title: AppLocalizations.of(context).kitchenDisplayLower,
      body: AppLocalizations.of(context).featKitchenBody,
    ),
    OnboardingSlide(
      icon: Icons.backup,
      title: AppLocalizations.of(context).backups,
      body: AppLocalizations.of(context).featBackupsBody,
    ),
    OnboardingSlide(
      icon: Icons.monitor_weight,
      title: AppLocalizations.of(context).weighingScaleLower,
      body: AppLocalizations.of(context).featScaleBody,
    ),
    OnboardingSlide(
      icon: Icons.local_offer,
      title: AppLocalizations.of(context).promotions,
      body: AppLocalizations.of(context).featPromotionsBody,
    ),
    OnboardingSlide(
      icon: Icons.card_membership,
      title: AppLocalizations.of(context).loyaltyCardsLower,
      body: AppLocalizations.of(context).featLoyaltyBody,
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
            AppLocalizations.of(context).everythingYouGet,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).everythingBuiltIn,
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
                for (var i = 0; i < _featuresFor(context).length; i++)
                  _FeatureTile(_featuresFor(context)[i])
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
