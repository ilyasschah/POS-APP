import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Why a chosen file cannot be restored. Kept as a type rather than a string so
/// the UI can explain the *specific* problem — "this is from a newer version"
/// and "this isn't a POS backup" need very different advice.
enum RestoreRejection {
  missing,
  notSqlite,
  encrypted,
  notAPosBackup,
  newerSchema,
}

class RestoreCheck {
  final bool ok;
  final RestoreRejection? reason;

  /// Drift `user_version` found in the file, when it could be read.
  final int? schemaVersion;

  const RestoreCheck.ok(this.schemaVersion) : ok = true, reason = null;
  const RestoreCheck.bad(this.reason, [this.schemaVersion]) : ok = false;
}

/// Restoring a `.sqlite` backup over the live database.
///
/// ⚠️ The swap CANNOT happen while the app is running: Drift holds the file
/// open, and on Windows an open file cannot be replaced at all. So a restore is
/// two-phase — [stage] drops the chosen file next to the live one and the app
/// restarts; [applyStagedRestore] runs at boot, before Drift opens anything,
/// and performs the swap. That ordering is the whole design, not a detail.
class RestoreService {
  RestoreService._();

  /// Filename of the staged restore. Sits beside the live DB so both are on the
  /// same volume and the swap is a rename, not a cross-device copy.
  static const _stagedName = 'pos_app.restore.sqlite';

  /// Kept as the previous database until the next successful restore, so a
  /// restore that turns out to be the wrong file is still recoverable.
  static const _supersededName = 'pos_app.superseded.sqlite';

  static Future<String> _dir() async =>
      (await getApplicationDocumentsDirectory()).path;

  static Future<File> liveFile() async =>
      File(p.join(await _dir(), 'pos_app.sqlite'));

  static Future<File> stagedFile() async =>
      File(p.join(await _dir(), _stagedName));

  /// True when the live database file is absent — a fresh install, or the file
  /// was deleted/moved out from under a configured terminal.
  ///
  /// Worth distinguishing because SQLite silently CREATES an empty database in
  /// that situation, so without this check a terminal whose file was deleted
  /// just looks like it lost every product and sale, with nothing on screen to
  /// say what happened.
  static Future<bool> liveDatabaseMissing() async =>
      !(await liveFile()).existsSync();

  // ── Validation ────────────────────────────────────────────────────────────

  /// Inspects [path] without modifying it. Never trust a file the operator
  /// picked from disk: it may be someone's holiday photos, a database from a
  /// NEWER app version that this build cannot migrate down to, or an encrypted
  /// backup taken on a different machine.
  static RestoreCheck inspect(String path, {required int currentSchemaVersion}) {
    final file = File(path);
    if (!file.existsSync()) return const RestoreCheck.bad(RestoreRejection.missing);

    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
      // A plaintext SQLite file reads sqlite_master fine. An encrypted one
      // throws here — which, given the key is hardware-bound, means it came
      // from a different device and is unreadable on this one.
      final tables = db
          .select("SELECT name FROM sqlite_master WHERE type='table';")
          .map((r) => r.columnAt(0) as String)
          .toSet();

      // Two tables this app has had since long before backups existed. Checking
      // for them is what separates "a POS backup" from "any old .sqlite".
      if (!tables.contains('pos_orders') || !tables.contains('app_properties')) {
        return const RestoreCheck.bad(RestoreRejection.notAPosBackup);
      }

      final version = db.select('PRAGMA user_version;').first.columnAt(0) as int;
      // Drift migrates FORWARD only. A file from a newer build would be opened
      // by an older schema that has no idea what changed, so refuse it rather
      // than corrupt it.
      if (version > currentSchemaVersion) {
        return RestoreCheck.bad(RestoreRejection.newerSchema, version);
      }
      return RestoreCheck.ok(version);
    } on SqliteException catch (e) {
      // "file is not a database" covers both a non-SQLite file and an encrypted
      // one; the message distinguishes them well enough to advise the operator.
      final encrypted = e.message.contains('not a database');
      return RestoreCheck.bad(
        encrypted ? RestoreRejection.encrypted : RestoreRejection.notSqlite,
      );
    } catch (_) {
      return const RestoreCheck.bad(RestoreRejection.notSqlite);
    } finally {
      db?.close();
    }
  }

  // ── Staging ───────────────────────────────────────────────────────────────

  /// Copies [sourcePath] to the staging slot. Does NOT touch the live database
  /// — the swap happens at next boot in [applyStagedRestore].
  ///
  /// Copies rather than moves so the operator keeps their backup file: if the
  /// restore turns out to be the wrong one, the original is still on disk.
  static Future<void> stage(String sourcePath) async {
    final staged = await stagedFile();
    if (staged.existsSync()) staged.deleteSync();
    await File(sourcePath).copy(staged.path);
  }

  static Future<void> cancelStaged() async {
    final staged = await stagedFile();
    if (staged.existsSync()) staged.deleteSync();
  }

  /// Swaps a staged restore into place. **Must be called before the database is
  /// opened** — `_openConnection` does exactly that.
  ///
  /// Returns true when a restore was applied. The previous database is kept as
  /// `pos_app.superseded.sqlite` rather than deleted: this operation replaces
  /// everything the terminal knows, and a one-file undo costs nothing.
  static Future<bool> applyStagedRestore() async {
    final staged = await stagedFile();
    if (!staged.existsSync()) return false;

    final live = await liveFile();
    final superseded = File(p.join(await _dir(), _supersededName));

    try {
      if (superseded.existsSync()) superseded.deleteSync();
      if (live.existsSync()) {
        // Rename, not copy: instant, and it cannot half-succeed on a full disk.
        live.renameSync(superseded.path);
      }
      staged.renameSync(live.path);
      debugPrint('Restore: staged database swapped in.');
      return true;
    } catch (e) {
      debugPrint('Restore: swap FAILED — $e');
      // Put the original back if we had already moved it aside, so a failed
      // restore leaves the terminal exactly as it was rather than with no
      // database at all.
      try {
        if (!live.existsSync() && superseded.existsSync()) {
          superseded.renameSync(live.path);
        }
      } catch (_) {}
      return false;
    }
  }

  // ── Portable (unencrypted) export ─────────────────────────────────────────

  /// Rewrites [encryptedPath] as a PLAINTEXT copy at [destPath].
  ///
  /// Backups have to stay portable across devices — restoring onto a REPLACEMENT
  /// machine after a failure is the main reason they exist, and the SQLCipher
  /// key is derived per-device (`DeviceKeyService`: "different on any other
  /// device"), so an encrypted backup would only ever restore onto the machine
  /// that no longer works.
  ///
  /// ⚠️ The trade-off is deliberate and was chosen explicitly: the backup file
  /// is readable by anyone who obtains it. Keep backups somewhere you would be
  /// willing to keep a customer list, because that is what they are.
  ///
  /// A no-op while `kPillar3Encryption` is false (the live file is already
  /// plaintext) — this exists so backups keep working when it is turned on.
  static void exportPlaintext({
    required String encryptedPath,
    required String destPath,
    required String hexKey,
  }) {
    Database? src;
    try {
      src = sqlite3.open(encryptedPath);
      src.execute("PRAGMA key = '$hexKey';");
      final userVersion =
          src.select('PRAGMA user_version;').first.columnAt(0) as int;

      final escaped = destPath.replaceAll("'", "''");
      src.execute("ATTACH DATABASE '$escaped' AS plaintext KEY '';");
      src.execute("SELECT sqlcipher_export('plaintext');");
      // sqlcipher_export copies tables and data but NOT `PRAGMA user_version`,
      // so without this the copy reports version 0 and a restore would make
      // Drift re-run onCreate over an already-populated database.
      src.execute('PRAGMA plaintext.user_version = $userVersion;');
      src.execute('DETACH DATABASE plaintext;');
    } finally {
      src?.close();
    }
  }
}
