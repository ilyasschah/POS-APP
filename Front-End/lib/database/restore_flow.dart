import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/core/app_restart.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/restore_service.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/onboarding/onboarding_prefs.dart';

/// The one restore journey, shared by every entry point that offers it:
/// Settings → Database, the onboarding "restore instead of starting fresh"
/// branch, and the missing-database recovery screen. Keeping it in one place
/// is what stops the validation rules drifting apart between them.
///
/// Steps: pick a file → inspect it → explain any rejection → confirm → stage →
/// restart. The actual swap happens on the next boot in
/// [RestoreService.applyStagedRestore]; see there for why it cannot happen now.
///
/// Returns true when a restore was staged (the app is about to restart).
Future<bool> runRestoreFlow(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);

  final picked = await FilePicker.platform.pickFiles(
    dialogTitle: l.restorePickTitle,
    type: FileType.any,
  );
  final path = picked?.files.single.path;
  if (path == null || !context.mounted) return false;

  // Read-only inspection: never trust a file chosen off disk. It could be any
  // file at all, a database from a NEWER build this one cannot migrate down to,
  // or an encrypted backup from another machine (the key is per-device).
  final check = RestoreService.inspect(
    path,
    currentSchemaVersion: AppDatabase.expectedSchemaVersion,
  );

  if (!check.ok) {
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.error_outline,
            color: Theme.of(ctx).colorScheme.error, size: 30),
        title: Text(l.restoreRejectedTitle),
        content: Text(_rejectionMessage(ctx, check)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.actionClose),
          ),
        ],
      ),
    );
    return false;
  }

  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded,
          color: ctx.warningColor, size: 30),
      title: Text(l.restoreConfirmTitle),
      content: Text(l.restoreConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.restoreConfirmAction),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  try {
    await RestoreService.stage(path);

    // 🚨 THE INFINITE LOOP FIX — and the reason it has to happen HERE.
    //
    // Onboarding-complete is a device flag in SharedPreferences, deliberately
    // NOT in the database (a new terminal must see onboarding even when the
    // company is already running elsewhere). So restoring a database changed
    // nothing about it: the app restarted, found the flag still false, showed
    // onboarding, the operator picked "restore from backup" again… forever.
    //
    // Setting it before the restart is what decouples app state from the
    // .sqlite file. A restored terminal is by definition already set up — the
    // backup carries its settings, layout and theme.
    //
    // Registration is deliberately NOT faked. A restore onto a REPLACEMENT
    // machine is a new device that must take its own seat, so it still goes
    // through master login — which is the intended flow ("restore, then ask
    // him to master login"), and is now a single sign-in rather than a loop.
    await ref.read(onboardingCompleteProvider.notifier).complete();
  } catch (e) {
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.restoreRejectedTitle),
        content: Text('$e'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.actionClose),
          ),
        ],
      ),
    );
    return false;
  }

  if (!context.mounted) return true;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _RestartCountdownDialog(),
  );
  return true;
}

String _rejectionMessage(BuildContext context, RestoreCheck check) {
  final l = AppLocalizations.of(context);
  switch (check.reason) {
    case RestoreRejection.missing:
      return l.restoreErrMissing;
    case RestoreRejection.notSqlite:
      return l.restoreErrNotSqlite;
    case RestoreRejection.encrypted:
      // The most confusing failure, so it gets the most specific advice: the
      // file is fine, it just belongs to a different machine.
      return l.restoreErrEncrypted;
    case RestoreRejection.notAPosBackup:
      return l.restoreErrNotPosBackup;
    case RestoreRejection.newerSchema:
      return l.restoreErrNewerSchema(check.schemaVersion ?? 0,
          AppDatabase.expectedSchemaVersion);
    case null:
      return '';
  }
}

/// Counts down, then relaunches. Identical shape to the reset flow's ending so
/// the two destructive operations feel like the same app.
class _RestartCountdownDialog extends StatefulWidget {
  const _RestartCountdownDialog();

  @override
  State<_RestartCountdownDialog> createState() =>
      _RestartCountdownDialogState();
}

class _RestartCountdownDialogState extends State<_RestartCountdownDialog> {
  int _seconds = 5;
  bool _manual = false;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    while (_seconds > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _seconds--);
    }
    final ok = await AppRestart.restart();
    // restart() only returns on failure — on success the process is gone.
    if (!ok && mounted) setState(() => _manual = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      icon: Icon(Icons.check_circle, color: context.successColor, size: 34),
      title: Text(l.restoreStagedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.restoreStagedBody, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (_manual)
            Text(
              l.resetRestartManually,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.warningColor),
            )
          else ...[
            TweenAnimationBuilder<double>(
              key: ValueKey(_seconds),
              tween: Tween(begin: 1, end: 0),
              duration: const Duration(seconds: 1),
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 10),
            Text(l.resetRestartingIn(_seconds)),
          ],
        ],
      ),
    );
  }
}
