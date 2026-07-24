import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// The "what do I do first" slide: the three steps to a first sale. Kept short so
/// a new operator (or the reseller training them) sees the path at a glance.
class QuickStartSlide extends StatelessWidget {
  const QuickStartSlide({super.key});

  static const _steps = <(IconData, String, String)>[
    (
      Icons.category_outlined,
      'Create a product group',
      'Group your items — Drinks, Food, Sides…',
    ),
    (
      Icons.inventory_2_outlined,
      'Add your products',
      'Set a name, price and barcode — or bulk-import a CSV.',
    ),
    (
      Icons.groups_outlined,
      'Add your team',
      'Create cashiers, each with their own PIN.',
    ),
    (
      Icons.print_outlined,
      'Set up your printer',
      'Print receipts and send tickets to the kitchen.',
    ),
    (
      Icons.table_restaurant_outlined,
      'Arrange your tables',
      'Lay out your floor plan for dine-in orders.',
    ),
    (
      Icons.point_of_sale,
      'Start selling',
      'Tap items onto the ticket and take payment.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context).getGoingInThreeSteps,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < _steps.length; i++)
                _StepTile(
                  number: i + 1,
                  icon: _steps[i].$1,
                  title: _steps[i].$2,
                  body: _steps[i].$3,
                  isLast: i == _steps.length - 1,
                )
                    .animate(delay: (i * 120).ms)
                    .fadeIn(duration: 320.ms)
                    .slideX(begin: 0.12, end: 0, curve: Curves.easeOut),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
    required this.isLast,
  });

  final int number;
  final IconData icon;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number badge + connector line to the next step.
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: cs.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Row(
                children: [
                  Icon(icon, color: cs.primary, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
