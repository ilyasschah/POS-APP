import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:pos_app/onboarding/onboarding_seed.dart';
import 'package:pos_app/onboarding/widgets/onboarding_scaffold.dart';

enum ActivityType { shop, restaurant, barber, hotel, other }

/// The business type picked during onboarding. Transient (it drives the
/// tables/booking seed, it isn't itself persisted) but a StateProvider so it
/// survives the PageView rebuilding this page.
final onboardingActivityProvider = StateProvider<ActivityType?>((ref) => null);

class _Activity {
  const _Activity(
    this.type,
    this.icon,
    this.label,
    this.description, {
    required this.asksFeatures,
    required this.resource,
  });

  final ActivityType type;
  final IconData icon;
  final String label;
  final String description;

  /// Whether to show the tables/booking toggles after selecting this type.
  final bool asksFeatures;

  /// What the floor-plan resource is called for this trade (tables / chairs /
  /// rooms) — the underlying setting is the same, only the wording changes.
  final String resource;
}

const _activities = <_Activity>[
  _Activity(
    ActivityType.shop,
    Icons.storefront,
    'Shop',
    'Retail counter — no tables or bookings.',
    asksFeatures: false,
    resource: 'tables',
  ),
  _Activity(
    ActivityType.restaurant,
    Icons.restaurant,
    'Fast food / Restaurant',
    'Dine-in with tables and reservations.',
    asksFeatures: true,
    resource: 'tables',
  ),
  _Activity(
    ActivityType.barber,
    Icons.content_cut,
    'Barber shop',
    'Chairs and appointment bookings.',
    asksFeatures: true,
    resource: 'chairs',
  ),
  _Activity(
    ActivityType.hotel,
    Icons.hotel,
    'Hotel',
    'Rooms and reservations — switched on for you.',
    asksFeatures: false,
    resource: 'rooms',
  ),
  _Activity(
    ActivityType.other,
    Icons.tune,
    'Other',
    'Choose which features you want.',
    asksFeatures: true,
    resource: 'tables',
  ),
];

class ActivitySlide extends ConsumerWidget {
  const ActivitySlide({super.key});

  void _select(WidgetRef ref, _Activity a) {
    ref.read(onboardingActivityProvider.notifier).state = a.type;
    final seed = ref.read(onboardingFeatureSeedProvider.notifier);
    // Shop is the only type with the features OFF; everyone else starts ON
    // (restaurant / barber / other can still turn them off below).
    final on = a.type != ActivityType.shop;
    seed.setTables(on);
    seed.setBooking(on);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selected = ref.watch(onboardingActivityProvider);
    final seed = ref.watch(onboardingFeatureSeedProvider);
    final selectedInfo =
        selected == null ? null : _activities.firstWhere((a) => a.type == selected);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "What's your business?",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'We will switch on the right features for you.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              for (final a in _activities) ...[
                _ActivityCard(
                  a: a,
                  selected: selected == a.type,
                  onTap: () => _select(ref, a),
                ),
                const SizedBox(height: 10),
              ],
              if (selectedInfo != null && selectedInfo.asksFeatures) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      OnboardingSwitchRow(
                        icon: Icons.table_restaurant,
                        title: 'Enable ${selectedInfo.resource}',
                        subtitle:
                            'Open an order for each ${_singular(selectedInfo.resource)}.',
                        value: seed.tables ?? true,
                        onChanged: (v) => ref
                            .read(onboardingFeatureSeedProvider.notifier)
                            .setTables(v),
                      ),
                      OnboardingSwitchRow(
                        icon: Icons.event_seat,
                        title: 'Enable bookings',
                        subtitle: 'Take reservations in advance.',
                        value: seed.booking ?? true,
                        onChanged: (v) => ref
                            .read(onboardingFeatureSeedProvider.notifier)
                            .setBooking(v),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _singular(String plural) =>
      plural.endsWith('s') ? plural.substring(0, plural.length - 1) : plural;
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.a,
    required this.selected,
    required this.onTap,
  });

  final _Activity a;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.10) : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.14),
              ),
              child: Icon(a.icon, color: cs.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    a.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.description,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? cs.primary : cs.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}
