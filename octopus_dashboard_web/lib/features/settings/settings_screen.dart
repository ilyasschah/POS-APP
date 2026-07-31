import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/breakpoints.dart';
import '../../core/glass.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/list_panel.dart';
import '../../widgets/page_header.dart';
import '../auth/auth_controller.dart';

/// Account and appearance preferences.
///
/// Note: there is deliberately no currency setting — currency is always "DH".
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final palette = context.palette;
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: GlassCard.overlay(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sign out?', style: AppText.headline(palette.primaryText)),
                const SizedBox(height: 10),
                Text(
                  "You'll need to sign in again to view your dashboard.",
                  style: AppText.body(palette.dim(0.7)),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: palette.dim(0.8),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.negative,
                            foregroundColor: AppTheme.onAccent(
                              palette.negative,
                            ),
                          ),
                          child: const Text('Sign Out'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (shouldSignOut == true) {
      ref.read(authProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tier = LayoutTier.watch(context);
    final settings = ref.watch(settingsProvider);
    final settingsController = ref.read(settingsProvider.notifier);
    final email = ref.watch(authProvider.select((s) => s.email));

    return ListView(
      padding: Layout.pagePadding(tier).copyWith(bottom: 32),
      children: [
        PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHeader(title: 'Settings'),

              _SectionLabel('Account'),
              GlassCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                          color: palette.dim(0.6),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Signed in as',
                                style: AppText.caption(palette.dim(0.6)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: AppText.body(palette.primaryText),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () => _confirmSignOut(context, ref),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Sign Out'),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.negative.withValues(
                            alpha: 0.15,
                          ),
                          foregroundColor: palette.negative,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel('Language / اللغة'),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'fr', label: Text('Français')),
                      ButtonSegment(value: 'ar', label: Text('العربية')),
                    ],
                    selected: {settings.language},
                    onSelectionChanged: (Set<String> newSelection) {
                      settingsController.setLanguage(newSelection.first);
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: palette.accent.withValues(
                        alpha: 0.2,
                      ),
                      selectedForegroundColor: palette.accent,
                    ),
                  ),
                ),
              ),
              _SectionLabel('Appearance & UI'),
              GlassCard(
                child: Column(
                  children: [
                    _SwitchRow(
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark Mode',
                      subtitle: 'Use the dark theme',
                      value: settings.darkMode,
                      onChanged: settingsController.setDarkMode,
                    ),
                    _Separator(),
                    _SwitchRow(
                      icon: Icons.blur_on_rounded,
                      title: 'Liquid Glass Effect',
                      subtitle: 'Translucent frosted panels',
                      value: settings.glassEnabled,
                      onChanged: settingsController.setGlassEnabled,
                    ),
                    // The slider is only meaningful while the glass effect is
                    // on, so it's revealed conditionally.
                    if (settings.glassEnabled) ...[
                      _Separator(),
                      _SliderRow(
                        icon: Icons.opacity_rounded,
                        title: 'Glass Transparency',
                        value: settings.glassOpacity,
                        onChanged: settingsController.setGlassOpacity,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: AppText.eyebrow(context.palette.dim(0.55)),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
    height: 24,
    color: context.palette.primaryText.withValues(alpha: 0.08),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
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
    final palette = context.palette;
    return Row(
      children: [
        Icon(icon, size: 20, color: palette.dim(0.6)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppText.body(palette.primaryText)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppText.caption(palette.dim(0.55))),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.onAccent(palette.accent),
          activeTrackColor: palette.accent,
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: palette.dim(0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: AppText.body(palette.primaryText)),
            ),
            Text(
              '${(value * 100).round()}%',
              style: AppText.label(palette.accent),
            ),
          ],
        ),
        Slider(
          value: value,
          min: AppSettings.minOpacity,
          max: AppSettings.maxOpacity,
          // 5% steps across the 5–50% range.
          divisions: 9,
          activeColor: palette.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
