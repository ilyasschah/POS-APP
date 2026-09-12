import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/sync/sync_provider.dart';
import 'package:pos_app/utils/error_handler.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// Tells the operator how each sync ended — above all, when the server REFUSED
/// a change (deleting a tax a product still uses, a product a sale still
/// references). The local row is reverted, so without a word the change just
/// quietly undoes itself.
///
/// 🚨 This used to live inside `SyncButton`. The button sits in the POS
/// sidebar, which is a `Drawer` — and a closed drawer is not built, so the
/// listener existed only while the sidebar happened to be open. Refusals,
/// partial failures and hard errors were effectively never shown, in either
/// shell, and the reason lived only in the API log.
///
/// Mounted once, in MainLayout's body. That covers Management too: it is pushed
/// OVER MainLayout, which stays mounted beneath it, and the toast is inserted
/// on the root overlay, above every route. It unmounts on sign-out, so nothing
/// is reported over the login screen.
class SyncOutcomeListener extends ConsumerStatefulWidget {
  const SyncOutcomeListener({super.key});

  @override
  ConsumerState<SyncOutcomeListener> createState() =>
      _SyncOutcomeListenerState();
}

class _SyncOutcomeListenerState extends ConsumerState<SyncOutcomeListener> {
  /// The last failure reported. Auto-sync runs every 30 seconds, so a server
  /// that is down would otherwise repeat the same toast twice a minute: a
  /// BACKGROUND failure is reported once, and again only when it changes or
  /// after a clean run. A sync the operator asked for always gets its answer.
  String? _lastFailure;

  void _reportFailure(String message, {required bool manual}) {
    if (!manual && message == _lastFailure) return;
    _lastFailure = message;
    showAppSnackbar(context, ref, message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<String>>>(syncStateProvider, (prev, next) {
      if (prev is! AsyncLoading || next is AsyncLoading) return;
      // Null = no sync has run: this is the notifier's own first build leaving
      // loading, which would otherwise read as a clean run at sign-in.
      final manual = ref.read(syncStateProvider.notifier).lastRunWasManual;
      if (manual == null) return;
      final l = AppLocalizations.of(context);

      if (next is AsyncError) {
        // Hard failure — the whole run threw before completing.
        _reportFailure(
          friendlyErrorMessage(next.error ?? l.syncFailed),
          manual: manual,
        );
        return;
      }

      // Server-refused changes (resolved, won't retry). Reported every time,
      // background runs included: each one is something the operator did that
      // did not stick.
      final rejections = ref.read(syncManagerProvider).rejectionNotices;
      if (rejections.isNotEmpty) {
        showAppSnackbar(
          context,
          ref,
          rejections.length == 1
              ? rejections.first
              : l.changesRejected(rejections.length, rejections.join(' · ')),
          isError: true,
        );
      }

      // Partial failures: the run finished but some entities didn't sync.
      final failed = next.value ?? const <String>[];
      if (failed.isNotEmpty) {
        _reportFailure(
          l.syncFinishedWithFailures(failed.join(', ')),
          manual: manual,
        );
        return;
      }

      // A clean run: the next failure is news again.
      _lastFailure = null;

      // The success toast is opt-in (AUTO SYNC → "Show sync notification").
      final showToast = ref
              .read(appSettingsProvider)[SettingKeys.autoSyncShowNotification]
              ?.toLowerCase() ==
          'true';
      if (showToast) showAppSnackbar(context, ref, l.syncComplete);
    });

    return const SizedBox.shrink();
  }
}
