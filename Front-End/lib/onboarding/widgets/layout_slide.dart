import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/onboarding/onboarding_seed.dart';

/// Onboarding slide: pick how products appear on the sales screen. Shows a small
/// live example of each layout and parks the choice in the onboarding seed
/// (applied to the per-company setting on first login). Defaults to List — the
/// same global default — so skipping this slide changes nothing.
class LayoutSlide extends ConsumerWidget {
  const LayoutSlide({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // null = not picked yet → show List (the global default) as selected.
    final isGrid =
        ref.watch(onboardingFeatureSeedProvider).layoutIsGrid ?? false;

    void pick(bool grid) =>
        ref.read(onboardingFeatureSeedProvider.notifier).setLayoutIsGrid(grid);

    final listCard = _LayoutCard(
      label: AppLocalizations.of(context).listView,
      description:
          'Everything scrolls in one continuous view. Set the columns.',
      paged: false,
      selected: !isGrid,
      onTap: () => pick(false),
    );
    final gridCard = _LayoutCard(
      label: AppLocalizations.of(context).gridView,
      description:
          'Fixed pages that fit the screen, with next / previous buttons. '
          'Set columns × rows.',
      paged: true,
      selected: isGrid,
      onTap: () => pick(true),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context).chooseYourMenuLayout,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).menuLayoutHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, c) {
                  if (c.maxWidth < 460) {
                    return Column(
                      children: [
                        listCard,
                        const SizedBox(height: 14),
                        gridCard,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: listCard),
                      const SizedBox(width: 14),
                      Expanded(child: gridCard),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A selectable layout option: an example mock-up on top, then label + blurb.
class _LayoutCard extends StatelessWidget {
  const _LayoutCard({
    required this.label,
    required this.description,
    required this.paged,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool paged;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.08) : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 132, child: _MenuMockup(paged: paged)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? cs.primary : cs.outlineVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// A miniature of the sales-screen menu. List shows a scrollbar hint (continuous
/// scroll); Grid shows a first/prev/page/next/last bar under a full page.
class _MenuMockup extends StatelessWidget {
  const _MenuMockup({required this.paged});

  final bool paged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget tile() => Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );

    Widget tileRow() => Expanded(
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            tile(),
          ],
        ],
      ),
    );

    // List implies "more, scrolling" with an extra denser row; Grid shows a
    // clean full page above its nav bar.
    final rowCount = paged ? 3 : 4;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Search strip.
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (int r = 0; r < rowCount; r++) ...[
                        if (r > 0) const SizedBox(height: 4),
                        tileRow(),
                      ],
                    ],
                  ),
                ),
                if (!paged) ...[
                  const SizedBox(width: 5),
                  // Scrollbar hint.
                  Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (paged) ...[const SizedBox(height: 6), _MiniPageBar(cs: cs)],
        ],
      ),
    );
  }
}

/// The tiny `|< < 1/3 > >|` bar shown in the Grid mock-up.
class _MiniPageBar extends StatelessWidget {
  const _MiniPageBar({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    Widget nav(IconData icon) =>
        Icon(icon, size: 11, color: cs.onSurfaceVariant);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        nav(Icons.first_page),
        nav(Icons.chevron_left),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '1/3',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 5),
        nav(Icons.chevron_right),
        nav(Icons.last_page),
      ],
    );
  }
}
