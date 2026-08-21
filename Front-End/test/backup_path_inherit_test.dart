// Pins which device-scoped settings a terminal is allowed to INHERIT from the
// cloud, and specifically that a backup path from another kind of machine is
// dropped rather than shown.
//
// 🚨 The reported symptom (2026-08-16): a fresh WINDOWS install opened
// Settings → Database and found an Android storage path already sitting in the
// backup box, on a machine that had never seen a tablet. `Database.BackupPath`
// is device-scoped, so a terminal with no override of its own falls back to
// whatever the cloud holds — which was the tablet's managed folder. Windows
// cannot write there, so the operator's first backup would have failed or
// landed somewhere absurd.
//
// The guard existed already, but only in ONE direction (desktop path → mobile).
// These tests pin both directions, because the missing half is exactly the kind
// of asymmetry that reads as complete.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/settings/device_scoped_settings.dart';

void main() {
  String? inherit(String value) =>
      DeviceScopedSettings.sanitizeInherited('Database.BackupPath', value);

  group('a backup path from another machine', () {
    test('an Android storage path is dropped on Windows', () {
      // Exactly what the operator saw in the box.
      const android = '/storage/emulated/0/Android/data/com.example.pos_app/files/POS_Backups';
      expect(inherit(android), Platform.isWindows ? isNull : android,
          reason: 'dropping it falls through to the empty default');
    });

    test('a SAF content:// URI is dropped on any desktop', () {
      const saf = 'content://com.android.externalstorage.documents/tree/primary';
      if (Platform.isAndroid || Platform.isIOS) return;
      expect(inherit(saf), isNull);
    });

    test('a Windows path survives on Windows', () {
      // The other half of the same rule — this is a perfectly good value here,
      // and over-filtering would empty a working configuration.
      const win = r'D:\POS_Backups';
      expect(inherit(win), Platform.isAndroid || Platform.isIOS ? isNull : win);
    });

    test('a UNC share survives on Windows', () {
      const unc = r'\\nas\backups\pos';
      expect(inherit(unc), Platform.isAndroid || Platform.isIOS ? isNull : unc);
    });

    test('an empty value is passed through untouched', () {
      expect(inherit(''), '');
    });
  });

  group('the other device-scoped keys are unaffected', () {
    test('a printer queue name is dropped only on mobile', () {
      final r = DeviceScopedSettings.sanitizeInherited(
          'Receipt.PrinterName', 'EPSON TM-T20');
      expect(r, Platform.isAndroid || Platform.isIOS ? isNull : 'EPSON TM-T20');
    });

    test('a COM port is dropped off Windows', () {
      final r = DeviceScopedSettings.sanitizeInherited('Scale.Port', 'COM3');
      expect(r, Platform.isWindows ? 'COM3' : isNull);
    });

    test('the backup path IS device-scoped — the whole guard depends on it', () {
      expect(DeviceScopedSettings.isDeviceScoped('Database.BackupPath'), isTrue);
      expect(DeviceScopedSettings.isDeviceScoped('Database.AutoBackup'), isFalse,
          reason: 'the toggle is a company preference; only the PATH is local');
    });
  });
}
