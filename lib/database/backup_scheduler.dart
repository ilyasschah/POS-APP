import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/backup_service.dart';

/// Drives the automatic DB backups configured under Settings → Database:
///   • Database.AutoBackup        — master on/off gate
///   • Database.Backup.OnStart    — back up once per session at startup
///   • Database.Backup.IntervalHours — periodic backup while running
///   • Database.Backup.OnClose    — back up when the desktop window is closed
/// (Manual "Backup Now" + retention pruning were already wired in the settings
/// screen; this adds the missing automation. On-close is driven by
/// [runCloseBackup], awaited from MainLayout's window-close hook on desktop.)
///
/// Kept alive by reading [backupSchedulerProvider] from MainLayout, so it lives
/// for the whole post-login session. Reads settings reactively so toggling
/// auto-backup takes effect without a restart.
class BackupScheduler extends Notifier<void> {
  Timer? _interval;
  bool _didStartupBackup = false;

  @override
  void build() {
    // React to settings changes (enable/disable, interval edits).
    final settings = ref.watch(appSettingsProvider);
    final enabled =
        settings[SettingKeys.dbAutoBackup]?.toLowerCase() == 'true';

    _interval?.cancel();
    ref.onDispose(() => _interval?.cancel());

    if (!enabled) return;

    // On-start: once per session, deferred off the build frame.
    if (!_didStartupBackup &&
        settings[SettingKeys.dbBackupOnStart]?.toLowerCase() == 'true') {
      _didStartupBackup = true;
      Future.microtask(_runBackup);
    }

    // Interval: schedule a periodic backup when a positive hour count is set.
    final hours =
        int.tryParse(settings[SettingKeys.dbBackupIntervalHours] ?? '0') ?? 0;
    if (hours > 0) {
      _interval = Timer.periodic(Duration(hours: hours), (_) => _runBackup());
    }
  }

  /// Copies the DB (best-effort) and prunes old backups when retention is on.
  /// Re-reads settings at run time so a disable between scheduling and firing is
  /// honoured.
  Future<void> _runBackup() async {
    final s = ref.read(appSettingsProvider);
    if (s[SettingKeys.dbAutoBackup]?.toLowerCase() != 'true') return;

    final companyName = ref.read(selectedCompanyProvider)?.name ?? 'POS';
    final dir = s[SettingKeys.dbBackupPath] ?? '';
    try {
      final dest = await BackupService.backupNow(
        backupDir: dir,
        companyName: companyName,
      );
      if (s[SettingKeys.dbBackupAutoDelete]?.toLowerCase() == 'true') {
        final days =
            int.tryParse(s[SettingKeys.dbBackupRetentionDays] ?? '10') ?? 10;
        await BackupService.pruneOldBackups(
          backupDir: p.dirname(dest),
          retentionDays: days,
        );
      }
    } catch (_) {
      // Best-effort — a backup failure must never disrupt the session.
    }
  }

  /// Runs a backup when the desktop window is closing, if both the master gate
  /// (Database.AutoBackup) and Database.Backup.OnClose are on. Awaited by the
  /// window-close hook so the copy finishes before the app exits. Best-effort:
  /// [_runBackup] swallows failures, so a backup problem never blocks the close.
  Future<void> runCloseBackup() async {
    final s = ref.read(appSettingsProvider);
    if (s[SettingKeys.dbAutoBackup]?.toLowerCase() != 'true') return;
    if (s[SettingKeys.dbBackupOnClose]?.toLowerCase() != 'true') return;
    await _runBackup();
  }
}

final backupSchedulerProvider =
    NotifierProvider<BackupScheduler, void>(BackupScheduler.new);
