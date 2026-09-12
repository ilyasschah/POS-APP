import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/sync/pending_count_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/sync/sync_status_dialog.dart';

/// Sidebar / AppBar action that opens the Sync Status panel.
///
/// While [syncStateProvider] is loading, the icon is replaced by a small
/// spinner. How a sync ENDED is not reported here: this button lives in the
/// sidebar drawer, which is not built while closed — see `SyncOutcomeListener`,
/// which is mounted for the whole signed-in session.
class SyncButton extends ConsumerWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStateProvider);
    final isLoading = state.isLoading;
    final pendingCount = ref.watch(pendingOrdersCountProvider).value ?? 0;
    final muted = context.navMuted;

    final tooltip = isLoading
        ? AppLocalizations.of(context).syncingEllipsis
        : pendingCount > 0
            ? AppLocalizations.of(context).pendingTapForStatus(pendingCount)
            : AppLocalizations.of(context).syncStatusTooltip;

    // The badge only sits on the idle icon. While syncing we swap the icon
    // for a spinner — wrapping that in a badge would look noisy (spinner +
    // count animating together).
    final iconOrSpinner = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(muted),
                ),
              ),
            ),
          )
        : Badge.count(
            count: pendingCount,
            isLabelVisible: pendingCount > 0,
            child: Icon(
              PhosphorIcons.arrowsClockwise(),
              size: 20,
              color: muted,
            ),
          );

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        // Tap opens the Sync Status panel (per-entity pending vs synced); the
        // actual "Sync now" action lives inside it. Available even while a sync
        // is in flight so progress can be watched.
        onTap: () => showSyncStatusDialog(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: iconOrSpinner,
        ),
      ),
    );
  }
}
