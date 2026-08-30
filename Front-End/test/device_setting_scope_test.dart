// Which settings belong to THIS terminal and which belong to the company.
//
// 🚨 The reported symptom (2026-08-29): installing on a second device and
// signing into the same account carried the LANGUAGE and the on-screen
// KEYBOARD across with it. `app_properties` is company-scoped and mirrored to
// every device, so anything describing the person or the hardware in front of
// one screen fights with every other terminal that shares the account.
//
// This file is the written-down half of that audit. Both directions are pinned
// on purpose: a key that must NOT travel, and a key that must — because the
// mistake is symmetric. Making receipt text or tax defaults per-device would
// quietly give one venue several different receipts.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/settings/device_scoped_settings.dart';

void main() {
  bool local(String key) => DeviceScopedSettings.isDeviceScoped(key);

  group('the operator in front of this screen', () {
    test('language and writing direction stay on the device', () {
      // A French-speaking waiter's tablet and an Arabic front till are both
      // correct at the same time.
      expect(local(SettingKeys.language), isTrue);
      expect(local(SettingKeys.writingDirection), isTrue);
    });

    test('the virtual keyboard stays on the device', () {
      // A touch-only tablet needs it; a Windows till with a real keyboard is
      // covered by one permanently, for no reason.
      expect(local(SettingKeys.enableVirtualKeyboard), isTrue);
    });
  });

  group('hardware wired to one terminal', () {
    test('the whole customer display is per-terminal, not just its port', () {
      // `Enabled` and the serial parameters already were; these two describe
      // the SAME second screen and were left behind.
      expect(local(SettingKeys.customerDisplayEnabled), isTrue);
      expect(local(SettingKeys.customerDisplayPort), isTrue);
      expect(local(SettingKeys.customerDisplayWebEnabled), isTrue);
      expect(local(SettingKeys.customerDisplayNumChars), isTrue);
    });

    test('kitchen display groups follow the IPs they are keyed by', () {
      // Cloud-syncing the mapping while the IPs it refers to are local leaves a
      // device holding assignments for displays it cannot reach.
      expect(local(SettingKeys.kitchenDisplayIps), isTrue);
      expect(local(SettingKeys.kitchenDisplayGroups), isTrue);
    });

    test('both auto-print switches are per-terminal, for the same reason', () {
      // The front till may fire tickets and receipts automatically while a
      // manager's tablet, on the same account and with no printer, must not.
      expect(local(SettingKeys.autoKitchenPrintOnCheckout), isTrue);
      expect(local(SettingKeys.autoprint), isTrue);
    });
  });

  group('what must KEEP travelling between devices', () {
    test('money, tax and catalogue rules are company-wide', () {
      for (final key in [
        SettingKeys.currencySymbol,
        SettingKeys.taxIncludedByDefault,
        SettingKeys.defaultTaxRateIds,
        SettingKeys.roundingMode,
        SettingKeys.allowPriceChange,
        SettingKeys.allowNegativeStock,
        SettingKeys.maxCashDifference,
        SettingKeys.cashPaymentTypeIds,
      ]) {
        expect(local(key), isFalse, reason: key);
      }
    });

    test('what the TICKET says is company-wide, even where the printer is not',
        () {
      // The dividing line inside the printer settings: the queue name and the
      // drawer wiring are local, everything describing the printed page is not.
      expect(local(SettingKeys.rolePrinterName('Receipt')), isTrue);
      for (final key in [
        SettingKeys.receiptFooter,
        SettingKeys.rolePaperSize('Receipt'),
        SettingKeys.roleHeader('Receipt'),
        SettingKeys.roleFooter('Receipt'),
        SettingKeys.roleFontSize('Receipt'),
        SettingKeys.roleRightToLeft('Receipt'),
        SettingKeys.roleCashDrawerCommand('Receipt'),
        SettingKeys.kitchenPrinterGroups,
      ]) {
        expect(local(key), isFalse, reason: key);
      }
    });

    test('the backup SCHEDULE is company policy; only the path is local', () {
      // A deliberate earlier decision, re-checked here rather than reversed:
      // an empty path resolves to a managed per-platform directory
      // (`BackupService.resolveBackupDir`), so the schedule is portable even
      // though the folder is not.
      expect(local(SettingKeys.dbBackupPath), isTrue);
      for (final key in [
        SettingKeys.dbAutoBackup,
        SettingKeys.dbBackupOnStart,
        SettingKeys.dbBackupOnClose,
        SettingKeys.dbBackupIntervalHours,
        SettingKeys.dbBackupRetentionDays,
      ]) {
        expect(local(key), isFalse, reason: key);
      }
    });
  });

  group('a device-scoped key is still SEEDED by the company value', () {
    test('an inherited language is usable, not dropped', () {
      // The fallback is what makes a new terminal open in the venue's language
      // instead of English. Only hardware- and filesystem-shaped values are
      // filtered, because those are the ones that are actively wrong here.
      expect(
        DeviceScopedSettings.sanitizeInherited(SettingKeys.language, 'fr'),
        'fr',
      );
      expect(
        DeviceScopedSettings.sanitizeInherited(
            SettingKeys.enableVirtualKeyboard, 'true'),
        'true',
      );
    });
  });
}
