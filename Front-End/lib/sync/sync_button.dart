import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/sync/pending_count_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/sync/sync_provider.dart';
import 'package:pos_app/sync/sync_status_dialog.dart';
import 'package:pos_app/utils/error_handler.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// Sidebar / AppBar action that triggers a full bidirectional sync
/// (push pending offline orders, then pull master data deltas).
///
/// While [syncStateProvider] is loading, the icon is replaced by a small
/// spinner and the button is disabled. Toast appears on every transition
/// out of the loading state — success or failure.
class SyncButton extends ConsumerWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Toast on every transition out of loading. Stays attached for the life
    // of this widget; ref.listen registers a one-shot callback per change.
    ref.listen<AsyncValue<List<String>>>(syncStateProvider, (prev, next) {
      if (prev is! AsyncLoading || next is AsyncLoading) return;
      if (next is AsyncError) {
        // Hard failure — the whole run threw before completing.
        showAppSnackbar(
          context,
          ref,
          friendlyErrorMessage(next.error ?? 'Sync failed'),
          isError: true,
        );
      } else {
        // Server-rejected ops (resolved, won't retry) — e.g. deleting a product
        // still linked to a document. The local row was reverted, so tell the
        // user why their action didn't stick. Surfaced regardless of the opt-in
        // toast so a silently-reappearing row is always explained.
        final rejections = ref.read(syncManagerProvider).rejectionNotices;
        if (rejections.isNotEmpty) {
          showAppSnackbar(
            context,
            ref,
            rejections.length == 1
                ? rejections.first
                : '${rejections.length} changes were rejected: '
                    '${rejections.join(' · ')}',
            isError: true,
          );
        }

        // Partial failures: some entities couldn't sync but the run finished.
        // Always surfaced (not gated by the opt-in toast) so missing cloud data
        // is never silent.
        final failed = next.value ?? const [];
        if (failed.isNotEmpty) {
          showAppSnackbar(
            context,
            ref,
            "Sync finished, but these didn't sync: ${failed.join(', ')}",
            isError: true,
          );
          return;
        }
        // Clean success toast is opt-in — the AUTO SYNC "Show sync notification"
        // setting controls it so background syncs don't spam the screen.
        final showToast = ref
                .read(appSettingsProvider)[SettingKeys.autoSyncShowNotification]
                ?.toLowerCase() ==
            'true';
        if (showToast) showAppSnackbar(context, ref, 'Sync complete');
      }
    });

    final state = ref.watch(syncStateProvider);
    final isLoading = state.isLoading;
    final pendingCount = ref.watch(pendingOrdersCountProvider).value ?? 0;
    final muted = context.navMuted;

    final tooltip = isLoading
        ? 'Syncing…'
        : pendingCount > 0
            ? '$pendingCount pending — tap for sync status'
            : 'Sync status';

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
