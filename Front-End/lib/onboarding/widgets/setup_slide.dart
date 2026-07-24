import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/core/device_theme_mode_provider.dart';
import 'package:pos_app/onboarding/onboarding_seed.dart';
import 'package:pos_app/onboarding/widgets/onboarding_scaffold.dart';
import 'package:pos_app/settings/local_ui_prefs.dart';

/// "Quick setup" slide — look & feel plus the on-screen keyboard. Appearance is
/// device-local and applies LIVE; the keyboard is a per-company setting parked
/// in the onboarding seed and applied on first login. Tables / booking are no
/// longer here — they're driven by the activity slide that follows.
class SetupSlide extends ConsumerWidget {
  const SetupSlide({super.key});

  static const _accents = <String>[
    '#3B82F6', // blue
    '#8B5CF6', // violet
    '#EF4444', // red
    '#F59E0B', // amber
    '#10B981', // green
    '#EC4899', // pink
  ];

  static Color _hex(String h) =>
      Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isLight = (ref.watch(deviceThemeModeProvider) ?? 'dark') == 'light';
    final accent = (ref.watch(deviceAccentColorProvider) ?? '').toUpperCase();
    final fontScale = ref.watch(fontScaleProvider);
    final seed = ref.watch(onboardingFeatureSeedProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context).setUpYourTerminal,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).changeThisLaterInSettings,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              const _SectionLabel('APPEARANCE'),
              _Row(
                label: AppLocalizations.of(context).theme,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(AppLocalizations.of(context).themeLight),
                      icon: const Icon(Icons.light_mode, size: 18),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(AppLocalizations.of(context).themeDark),
                      icon: const Icon(Icons.dark_mode, size: 18),
                    ),
                  ],
                  selected: {isLight},
                  onSelectionChanged: (s) => ref
                      .read(deviceThemeModeProvider.notifier)
                      .set(s.first ? 'light' : 'dark'),
                ),
              ),
              _Row(
                label: AppLocalizations.of(context).accent,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (final hex in _accents)
                      _Swatch(
                        color: _hex(hex),
                        selected: accent == hex.toUpperCase(),
                        onTap: () => ref
                            .read(deviceAccentColorProvider.notifier)
                            .set(hex),
                      ),
                  ],
                ),
              ),
              _Row(
                label: AppLocalizations.of(context).textSize,
                child: Row(
                  children: [
                    const Text('A', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Slider(
                        min: kFontScaleMin,
                        max: kFontScaleMax,
                        divisions: 5,
                        value: fontScale.clamp(kFontScaleMin, kFontScaleMax),
                        label: '${(fontScale * 100).round()}%',
                        onChanged: (v) =>
                            ref.read(fontScaleProvider.notifier).set(v),
                        onChangeEnd: (v) => ref
                            .read(fontScaleProvider.notifier)
                            .setAndPersist(v),
                      ),
                    ),
                    const Text('A', style: TextStyle(fontSize: 22)),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const _SectionLabel('INPUT'),
              OnboardingSwitchRow(
                icon: Icons.keyboard,
                title: AppLocalizations.of(context).onScreenKeyboard,
                subtitle: AppLocalizations.of(context).touchKeyboardHint,
                // Company setting → defaults off; parked until first login.
                value: seed.virtualKeyboard ?? false,
                onChanged: (v) => ref
                    .read(onboardingFeatureSeedProvider.notifier)
                    .setVirtualKeyboard(v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
          color: cs.primary,
        ),
      ),
    );
  }
}

/// A labelled config row: label on the left, control on the right, wrapping
/// under the label on very narrow widths.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                child,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 96,
                child: Text(label, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? cs.onSurface : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
