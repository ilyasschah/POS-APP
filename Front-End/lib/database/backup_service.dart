import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pos_app/database/app_database.dart' show kPillar3Encryption;
import 'package:pos_app/database/db_location.dart';
import 'package:pos_app/database/device_key_service.dart';
import 'package:pos_app/database/restore_service.dart';

/// Static helpers for backing up and pruning the local SQLite database.
class BackupService {
  BackupService._();

  // ── Path helpers ──────────────────────────────────────────────────────────

  /// Absolute path of the live Drift SQLite file.
  ///
  /// Resolved through [posDatabaseFilePath] so the backup copies the database
  /// Drift actually opens — the app-support directory, not Documents. See
  /// `db_location.dart`.
  static Future<String> dbFilePath() => posDatabaseFilePath();

  /// True when this platform has no operator-browsable filesystem for the
  /// operator to point a backup at. On Android every "folder" the system picker
  /// returns is a Storage Access Framework tree URI (`content://…`), which is
  /// NOT a path: `Directory(uri)` and `File.copy(uri)` both fail. That is why
  /// backups "did not work at all" on the tablets — the picker handed back a
  /// URI and every subsequent file operation threw.
  static bool get usesManagedBackupDir => Platform.isAndroid || Platform.isIOS;

  /// Resolves the backup directory.
  ///
  /// On Android/iOS a configured [backupDir] is honoured only when it sits
  /// inside the app's own external files directory — the one place it can write
  /// without SAF plumbing, reachable over USB / a file manager at
  /// `Android/data/<package>/files/POS_Backups`. Anything else falls back to
  /// that managed location. Elsewhere it falls back to `<Documents>/POS_Backups`.

  static Future<String> resolveBackupDir(String backupDir) async {
    final dir = backupDir.trim();

    if (usesManagedBackupDir) {
      // The one place this platform can write with no extra permission: the
      // app's own external files dir (Android) / documents dir (iOS). Both the
      // managed default and any operator override have to live under it.
      // getExternalStorageDirectory is Android-only and may be null; app
      // documents always exists and needs no permission on either platform.
      Directory? base;
      if (Platform.isAndroid) {
        try {
          base = await getExternalStorageDirectory();
        } catch (_) {
          base = null;
        }
      }
      base ??= await getApplicationDocumentsDirectory();
      final managed = p.join(base.path, 'POS_Backups');

      // Accept a configured path ONLY when it sits inside that writable sandbox.
      //
      // 🚨 Everything else is a value that made sense wherever it was set and is
      // unwritable here, so `Directory(...).createSync()` in `backupNow` throws
      // and the backup fails silently. `p.isWithin` rejects all three at once:
      //   • a Windows path (`D:\POS_Backups`) inherited from a POS till;
      //   • a SAF `content://` URI the folder picker returned (not a path);
      //   • a PUBLIC shared-storage path (`/storage/emulated/0/Documents`,
      //     `/sdcard/…`) inherited from another device or left as a legacy
      //     default — it needs MANAGE_EXTERNAL_STORAGE this app does not hold.
      //     This last one used to slip through (non-empty, no `://`, not
      //     Windows-shaped) and is the "Android path in the cloud settings" that
      //     broke tablet backups outright.
      // `Database.BackupPath` is device-scoped now (see DeviceScopedSettings),
      // so new values never travel — this is the guard for one already stored.
      if (dir.isNotEmpty && p.isWithin(base.path, dir)) {
        return dir;
      }
      return managed;
    }

    if (dir.isNotEmpty) return dir;
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'POS_Backups');
  }

  // ── Core operations ───────────────────────────────────────────────────────

  /// Copies the live database to [backupDir] with the filename:
  ///   {companyName}_{YYYY-MM-DD_HH-mm-ss}.sqlite
  ///
  /// Returns the full path of the created backup file.
  static Future<String> backupNow({
    required String backupDir,
    required String companyName,
  }) async {
    final src = File(await dbFilePath());
    if (!src.existsSync()) {
      throw Exception('Database file not found at ${src.path}');
    }

    final destDir = await resolveBackupDir(backupDir);
    final dir = Directory(destDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final now = DateTime.now();
    final ts = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}-'
        '${now.second.toString().padLeft(2, '0')}';

    // Strip characters forbidden in filenames on Windows / macOS / Linux
    final safeName = companyName
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final filename =
        '${safeName.isNotEmpty ? safeName : 'POS'}_$ts.sqlite';
    final destPath = p.join(destDir, filename);

    // A backup MUST be portable, because the case it exists for is "this
    // machine died, restore onto a new one". The SQLCipher key is derived per
    // device (DeviceKeyService: "different on any other device"), so a straight
    // byte copy of an encrypted database would only ever restore onto the
    // terminal that is no longer working — i.e. never.
    //
    // While kPillar3Encryption is false the live file is already plaintext and
    // the copy below is the whole job. When it is turned on (production
    // prerequisite, backlog item 11) the copy is re-keyed to plaintext instead.
    //
    // ⚠️ Explicit trade-off: the backup file is readable by anyone who gets
    // hold of it. It holds the customer list, prices and full sales history.
    if (kPillar3Encryption) {
      final key = await DeviceKeyService().getDatabaseKey();
      RestoreService.exportPlaintext(
        encryptedPath: src.path,
        destPath: destPath,
        hexKey: key,
      );
      return destPath;
    }

    await src.copy(destPath);
    return destPath;
  }

  /// Deletes .sqlite files in [backupDir] that are older than [retentionDays].
  /// Returns the count of deleted files.
  ///
  /// [backupDir] goes through [resolveBackupDir] first. It used to be used raw,
  /// so on Android — where the configured value is ignored in favour of the
  /// managed folder — this pointed at a directory that does not exist and
  /// pruning silently never ran. Same on a desktop with the setting left blank.
  static Future<int> pruneOldBackups({
    required String backupDir,
    required int retentionDays,
  }) async {
    final dir = Directory(await resolveBackupDir(backupDir));
    if (!dir.existsSync()) return 0;

    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    var count = 0;
    await for (final e in dir.list()) {
      if (e is File && e.path.toLowerCase().endsWith('.sqlite')) {
        if ((await e.stat()).modified.isBefore(cutoff)) {
          await e.delete();
          count++;
        }
      }
    }
    return count;
  }

  // ── OS integration ────────────────────────────────────────────────────────

  /// Opens [dirPath] in the native file manager. Silent on unsupported platforms.
  static void openDirectory(String dirPath) {
    final resolved = dirPath.trim();
    if (resolved.isEmpty) return;
    try {
      if (Platform.isWindows) {
        Process.run('explorer.exe', [resolved]);
      } else if (Platform.isMacOS) {
        Process.run('open', [resolved]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [resolved]);
      }
    } catch (_) {}
  }
}
