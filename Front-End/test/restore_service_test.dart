// Pins the restore VALIDATION rules.
//
// `RestoreService.inspect` is the only thing standing between a file the
// operator picked off disk and the live database. Everything it rejects is a
// real way to break a terminal:
//   • any old file — the picker lets them choose a photo;
//   • a database from a NEWER build — Drift migrates forward only, so opening
//     it with an older schema corrupts it;
//   • an encrypted backup from another machine — the SQLCipher key is derived
//     per device, so it simply cannot be read here.
//
// ⚠️ NOT covered here: the staged swap itself (`applyStagedRestore`). It
// resolves paths through `posDatabaseDirectory` (the app-support directory —
// see db_location.dart), which needs platform channels a unit test does not
// have. It stays a manual check — see POS_Manual_tests_NOTES item 28.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:pos_app/database/restore_service.dart';

/// Writes a plausible POS backup: the two tables `inspect` looks for, plus a
/// `user_version` so the schema check has something to read.
String _makePosBackup(Directory dir, {required int userVersion, String name = 'backup.sqlite'}) {
  final path = '${dir.path}${Platform.pathSeparator}$name';
  final db = sqlite3.open(path);
  db.execute('CREATE TABLE pos_orders (local_id TEXT PRIMARY KEY);');
  db.execute('CREATE TABLE app_properties (id INTEGER PRIMARY KEY);');
  db.execute('PRAGMA user_version = $userVersion;');
  db.close();
  return path;
}

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('restore_test'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('inspect', () {
    test('accepts a backup at the current schema version', () {
      final path = _makePosBackup(tmp, userVersion: 57);

      final check = RestoreService.inspect(path, currentSchemaVersion: 57);

      expect(check.ok, isTrue);
      expect(check.schemaVersion, 57);
    });

    test('accepts an OLDER backup — Drift migrates it forward', () {
      final path = _makePosBackup(tmp, userVersion: 42);

      final check = RestoreService.inspect(path, currentSchemaVersion: 57);

      expect(check.ok, isTrue, reason: 'an old backup is the normal case');
    });

    test('rejects a backup from a NEWER build', () {
      // The dangerous one: Drift only migrates forward, so an older app opening
      // a newer file would run migrations that do not apply and wreck it.
      final path = _makePosBackup(tmp, userVersion: 99);

      final check = RestoreService.inspect(path, currentSchemaVersion: 57);

      expect(check.ok, isFalse);
      expect(check.reason, RestoreRejection.newerSchema);
      // The UI reports both numbers, so the version has to survive the failure.
      expect(check.schemaVersion, 99);
    });

    test('rejects a SQLite file that is not a POS backup', () {
      final path = '${tmp.path}${Platform.pathSeparator}other.sqlite';
      final db = sqlite3.open(path);
      db.execute('CREATE TABLE something_else (id INTEGER);');
      db.close();

      final check = RestoreService.inspect(path, currentSchemaVersion: 57);

      expect(check.ok, isFalse);
      expect(check.reason, RestoreRejection.notAPosBackup);
    });

    test('rejects a file that is not a database at all', () {
      final path = '${tmp.path}${Platform.pathSeparator}holiday.jpg';
      File(path).writeAsBytesSync(List<int>.filled(2048, 7));

      final check = RestoreService.inspect(path, currentSchemaVersion: 57);

      expect(check.ok, isFalse);
      expect(
        check.reason,
        anyOf(RestoreRejection.notSqlite, RestoreRejection.encrypted),
        reason: 'both mean "unreadable here"; the UI wording differs',
      );
    });

    test('rejects a path that does not exist', () {
      final check = RestoreService.inspect(
        '${tmp.path}${Platform.pathSeparator}nope.sqlite',
        currentSchemaVersion: 57,
      );

      expect(check.ok, isFalse);
      expect(check.reason, RestoreRejection.missing);
    });

    test('leaves the inspected file untouched', () {
      // It is opened read-only on purpose — validation must never be able to
      // damage the operator's only copy of their data.
      final path = _makePosBackup(tmp, userVersion: 57);
      final before = File(path).lengthSync();

      RestoreService.inspect(path, currentSchemaVersion: 57);

      expect(File(path).lengthSync(), before);
    });
  });
}
