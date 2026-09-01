/// The single source of truth for WHERE the live SQLite database lives.
///
/// 🚨 It is the app-SUPPORT directory — on Windows
/// `…\AppData\Roaming\com.example\pos_app` — and deliberately NOT the Documents
/// directory this app used to open it from.
///
/// Documents is redirected into OneDrive by Windows' Known Folder Move on most
/// managed machines, so `getApplicationDocumentsDirectory()` returned a path
/// inside a cloud-synced folder. Drift opens the database on the UI isolate
/// (a same-isolate `NativeDatabase` is required for SQLCipher — see
/// `app_database.dart`), so any stall on that file — OneDrive holding the
/// handle to hydrate a placeholder, or a second terminal instance contending
/// for the lock — froze the whole UI thread. That is the "app hangs right after
/// login" AppHang: login fires a large sync write, and the write blocked on the
/// cloud-synced file. The app-support directory is local, per-app and never
/// synced, which removes the contention at the source.
///
/// [RestoreService] and [BackupService] resolve the live database through here
/// too, so the staged-restore swap and the backup copy can never point at a
/// different directory than the one Drift actually opens.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

const String _dbName = 'pos_app.sqlite';

// Mirrors the companion filenames RestoreService stages beside the live DB.
// Kept here (not imported) so the migration below has no dependency on the
// restore layer, which in turn depends on this file.
const String _stagedName = 'pos_app.restore.sqlite';
const String _supersededName = 'pos_app.superseded.sqlite';

/// The directory that holds the live database and its restore companions.
/// Created if missing (path_provider does not guarantee it exists).
Future<Directory> posDatabaseDirectory() async {
  final dir = await getApplicationSupportDirectory();
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir;
}

/// Absolute path of the live `pos_app.sqlite`.
Future<String> posDatabaseFilePath() async =>
    p.join((await posDatabaseDirectory()).path, _dbName);

/// One-time relocation of an existing database out of the (possibly
/// OneDrive-synced) Documents directory into [posDatabaseDirectory].
///
/// **Must run before anything opens the database** — both `_decideBoot` (before
/// its "database missing" check) and `_openConnection` call it first. A no-op
/// once the database is in its new home, and on a fresh install (nothing in the
/// old location to move).
///
/// Data safety: the WAL is folded back into the main file first, so moving the
/// single `.sqlite` cannot drop committed-but-uncheckpointed transactions. The
/// restore/superseded companions come across too; the emptied `-wal`/`-shm`
/// sidecars are discarded rather than carried.
///
/// 🚨 After the move, the old Documents copy is swept — and swept again on every
/// later boot while one is present. OneDrive, if it is running, re-downloads its
/// cloud copy into Documents the moment the local file is renamed away, so a
/// single delete does not make it stay gone; the repeated best-effort sweep lets
/// the deletion propagate to the cloud over a boot or two. The app never opens
/// that copy either way — it is pure hygiene, so a locked/failed delete is
/// ignored and simply retried next launch.
Future<void> migrateDatabaseOutOfDocumentsIfNeeded() async {
  final newDir = await posDatabaseDirectory();

  Directory? oldDir;
  try {
    oldDir = await getApplicationDocumentsDirectory();
  } catch (_) {
    oldDir = null; // no Documents directory on this platform
  }
  final hasOldLocation =
      oldDir != null && !p.equals(oldDir.path, newDir.path);

  // Already migrated (or a fresh install that started life here). Sweep any
  // stale copy OneDrive may have resurrected in Documents, then done.
  if (File(p.join(newDir.path, _dbName)).existsSync()) {
    if (hasOldLocation) _sweepOldDbFiles(oldDir.path);
    return;
  }

  if (!hasOldLocation) return;
  final oldDb = File(p.join(oldDir.path, _dbName));
  if (!oldDb.existsSync()) return; // nothing there to move

  try {
    // Fold the WAL into the main file so a single-file move can't lose data.
    try {
      final db = sqlite3.open(oldDb.path);
      db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      db.close();
    } catch (_) {
      // Encrypted (would need the key) or busy — fall through and still move
      // the sidecars alongside the main file below, which is also correct.
    }

    // Move the database and its restore companions across. Both directories are
    // under the user profile (same volume), so rename is instant; copy+delete
    // is only the cross-device fallback.
    for (final name in const [_dbName, _stagedName, _supersededName]) {
      final src = File(p.join(oldDir.path, name));
      if (!src.existsSync()) continue;
      final dst = p.join(newDir.path, name);
      try {
        src.renameSync(dst);
      } on FileSystemException {
        src.copySync(dst);
        try {
          src.deleteSync();
        } catch (_) {}
      }
    }

    // Carry any surviving WAL/SHM sidecars for the main DB (present only if the
    // checkpoint above could not run), then they are consistent with the moved
    // main file; otherwise drop the stale, emptied ones.
    for (final sfx in const ['-wal', '-shm']) {
      final src = File(p.join(oldDir.path, '$_dbName$sfx'));
      if (!src.existsSync()) continue;
      final dst = p.join(newDir.path, '$_dbName$sfx');
      try {
        src.renameSync(dst);
      } catch (_) {
        try {
          src.deleteSync();
        } catch (_) {}
      }
    }

    // A OneDrive resurrection races with the rename above, so sweep once more.
    _sweepOldDbFiles(oldDir.path);
    debugPrint('DB: migrated database from ${oldDir.path} to ${newDir.path}');
  } catch (e) {
    // Leave the old files untouched on any failure: the next launch retries,
    // and the terminal keeps opening the old copy in the meantime.
    debugPrint('DB: migration out of Documents failed — $e');
  }
}

/// Best-effort delete of every database file in the OLD (Documents) location.
/// Called after a migration, and on later boots while a resurrected copy lingers
/// there. Never throws — a file held open by OneDrive is simply retried next
/// launch, and the live database is elsewhere so nothing here is load-bearing.
void _sweepOldDbFiles(String oldDirPath) {
  for (final name in const [
    _dbName,
    '$_dbName-wal',
    '$_dbName-shm',
    _stagedName,
    _supersededName,
  ]) {
    final f = File(p.join(oldDirPath, name));
    if (!f.existsSync()) continue;
    try {
      f.deleteSync();
    } catch (_) {}
  }
}
