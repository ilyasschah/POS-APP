import 'package:flutter/material.dart';

/// Persistent bottom bar: Back · page dots · Next/Get Started. Kept
/// dependency-free (custom dots) rather than pulling in a page-indicator package.
class OnboardingControls extends StatelessWidget {
  const OnboardingControls({
    super.key,
    required this.pageCount,
    required this.currentPage,
    required this.onBack,
    required this.onNext,
    required this.isLastPage,
  });

  final int pageCount;
  final int currentPage;

  /// Null on the first page (nothing to go back to) — renders as blank space so
  /// the dots stay centered.
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final bool isLastPage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: onBack == null
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onBack,
                        icon: const Icon(Icons.chevron_left, size: 20),
                        label: const Text('Back'),
                      ),
                    ),
            ),
            Expanded(
              // Scale down rather than overflow when the row is tight (many dots
              // on a narrow phone between the fixed-width Back/Next buttons).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _Dots(count: pageCount, index: currentPage),
              ),
            ),
            SizedBox(
              width: 160,
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  // >= 44px touch target for the tablet build.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  onPressed: onNext,
                  child: Text(isLastPage ? 'Get Started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? cs.primary : cs.outlineVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
