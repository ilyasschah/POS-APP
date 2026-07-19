import 'package:flutter/material.dart';

/// Width at/above which onboarding uses the wide (Windows / tablet-landscape)
/// two-pane layout instead of the narrow (phone / narrow window) stacked one.
/// We branch on WIDTH, never on Platform: a Windows window can be dragged narrow
/// and an Android tablet can be very wide.
const double kOnboardingWideBreakpoint = 900;

/// Body shared by every onboarding slide. Narrow: illustration stacked above the
/// text, centered, scrollable so a short landscape phone never overflows. Wide:
/// illustration and text side-by-side, centered within a comfortable max width.
class OnboardingSlideLayout extends StatelessWidget {
  const OnboardingSlideLayout({
    super.key,
    required this.illustration,
    required this.title,
    required this.body,
    this.extra,
  });

  final Widget illustration;
  final String title;
  final String body;

  /// Optional widget under the copy — e.g. the theme picker cards.
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kOnboardingWideBreakpoint;
        final align = wide ? TextAlign.start : TextAlign.center;

        final textBlock = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: align,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: align,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (extra != null) ...[
              const SizedBox(height: 28),
              extra!,
            ],
          ],
        );

        if (wide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: Row(
                  children: [
                    Expanded(child: Center(child: illustration)),
                    const SizedBox(width: 56),
                    Expanded(child: SingleChildScrollView(child: textBlock)),
                  ],
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              illustration,
              const SizedBox(height: 40),
              textBlock,
            ],
          ),
        );
      },
    );
  }
}

/// A large icon in a soft tinted disc — the placeholder "illustration" for a
/// slide. Swap for an asset image later without touching the layouts.
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 148,
      height: 148,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.20),
            cs.secondaryContainer.withValues(alpha: 0.40),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(icon, size: 68, color: cs.primary),
    );
  }
}

/// A labelled switch row (icon · title/subtitle · Switch) shared by the setup
/// and activity slides.
class OnboardingSwitchRow extends StatelessWidget {
  const OnboardingSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: cs.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
