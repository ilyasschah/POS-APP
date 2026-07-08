import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Static helpers for backing up and pruning the local SQLite database.
class BackupService {
  BackupService._();

  // ── Path helpers ──────────────────────────────────────────────────────────

  /// Absolute path of the live Drift SQLite file.
  static Future<String> dbFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'pos_app.sqlite');
  }

  /// Resolves the backup directory.
  /// Falls back to <Documents>/POS_Backups when [backupDir] is empty.
  static Future<String> resolveBackupDir(String backupDir) async {
    final dir = backupDir.trim();
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

    await src.copy(destPath);
    return destPath;
  }

  /// Deletes .sqlite files in [backupDir] that are older than [retentionDays].
  /// Returns the count of deleted files.
  static Future<int> pruneOldBackups({
    required String backupDir,
    required int retentionDays,
  }) async {
    final dir = Directory(backupDir.trim());
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
