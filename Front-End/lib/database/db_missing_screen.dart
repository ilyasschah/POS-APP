import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/database/restore_flow.dart';
import 'package:pos_app/l10n/app_localizations.dart';

/// Shown at boot when the terminal's `pos_app.sqlite` has vanished — deleted,
/// moved, or sitting on a drive that did not come back.
///
/// This screen exists because SQLite's behaviour here is actively misleading:
/// open a path that isn't there and it CREATES an empty database, no error. So
/// a terminal whose file was deleted comes up looking like it lost every
/// product, price and sale, with nothing on screen explaining why — and the
/// operator's natural next move (start ringing up sales) writes into the empty
/// database and makes it worse.
///
/// Two ways out, and the difference matters:
///  • **Restore a backup** keeps work that never reached the cloud.
///  • **Start fresh** re-downloads from the cloud, which cannot bring back
///    anything this terminal never managed to sync.
class DbMissingScreen extends ConsumerWidget {
  /// Called when the operator chooses to continue with an empty database.
  final VoidCallback onStartFresh;

  const DbMissingScreen({super.key, required this.onStartFresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.storage_outlined,
                    size: 56, color: context.warningColor),
                const SizedBox(height: 20),
                Text(
                  l.dbMissingTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  l.dbMissingBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.restore),
                  label: Text(l.dbMissingRestore),
                  onPressed: () => runRestoreFlow(context, ref),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(l.dbMissingFresh),
                  // Confirmed, because it is the irreversible half of the
                  // choice: unsynced work cannot come back from the cloud.
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l.dbMissingFresh),
                        content: Text(l.dbMissingFreshConfirm),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l.actionCancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l.dbMissingFresh),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) onStartFresh();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
