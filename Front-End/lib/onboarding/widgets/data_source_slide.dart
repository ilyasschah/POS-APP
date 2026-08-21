import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/database/restore_flow.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/onboarding/widgets/onboarding_scaffold.dart';

/// Asks where this terminal's data should come from.
///
/// Placed early, right after the welcome, because the answer decides whether
/// the rest of onboarding is worth showing at all: restoring a backup brings
/// its own settings, layout and theme with it, and restarts the app.
///
/// "Sync with the cloud" is not a mode, it is the normal path — the operator
/// signs in and the data downloads. The real choice here is **restore instead
/// of starting empty**, which is the only way to recover work a dead terminal
/// never managed to sync.
class DataSourceSlide extends ConsumerWidget {
  /// Advances to the next slide. Restoring never calls this — it stages the
  /// file and restarts the app instead.
  final VoidCallback onUseCloud;

  const DataSourceSlide({super.key, required this.onUseCloud});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    return OnboardingSlideLayout(
      illustration: const OnboardingIllustration(Icons.cloud_sync_outlined),
      title: l.onboardingDataTitle,
      body: l.onboardingDataSubtitle,
      extra: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Choice(
            icon: Icons.cloud_download_outlined,
            title: l.onboardingCloudTitle,
            body: l.onboardingCloudBody,
            primary: true,
            onTap: onUseCloud,
          ),
          const SizedBox(height: 12),
          _Choice(
            icon: Icons.restore,
            title: l.onboardingRestoreTitle,
            body: l.onboardingRestoreBody,
            primary: false,
            onTap: () => runRestoreFlow(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool primary;
  final VoidCallback onTap;

  const _Choice({
    required this.icon,
    required this.title,
    required this.body,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Material(
        color: primary ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: primary ? cs.onPrimaryContainer : cs.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: primary ? cs.onPrimaryContainer : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: (primary ? cs.onPrimaryContainer : cs.onSurface)
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: primary ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
