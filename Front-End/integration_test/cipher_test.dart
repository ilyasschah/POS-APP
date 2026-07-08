// Pillar 3 on-device verification: proves the local Drift database is opened
// with SQLCipher (encryption-at-rest) on the real platform's native library.
// Run on a connected device/emulator:
//   flutter test integration_test/cipher_test.dart -d <deviceId>
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('local database is opened with SQLCipher and is encrypted at rest',
      (tester) async {
    final db = AppDatabase();

    // The first query opens the LazyDatabase connection, which derives the
    // hardware-bound key and applies `PRAGMA key` in setup.
    final cipher = await db.customSelect('PRAGMA cipher_version;').get();
    expect(cipher, isNotEmpty,
        reason: 'PRAGMA cipher_version must return a version → SQLCipher active');
    final version = cipher.first.data.values.first;
    debugPrint('PILLAR3 cipher_version=$version');

    // The key worked: the schema is readable.
    final count = await db
        .customSelect('SELECT count(*) AS c FROM sqlite_master;')
        .getSingle();
    debugPrint('PILLAR3 sqlite_master_count=${count.data['c']}');

    await db.close();

    // On disk, the file must NOT start with the plaintext SQLite magic header.
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'pos_app.sqlite'));
    expect(file.existsSync(), isTrue, reason: 'DB file should exist');
    final header = await file.openRead(0, 16).expand((b) => b).toList();
    final headerStr = String.fromCharCodes(header);
    debugPrint('PILLAR3 header="$headerStr"');
    expect(headerStr.startsWith('SQLite format 3'), isFalse,
        reason: 'encrypted DB must not have the plaintext SQLite header');
  });
}
