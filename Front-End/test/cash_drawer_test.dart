// Pins the cash-drawer kick (handoff.md ⭐8), which had every layer EXCEPT the
// one that touches hardware: settings, a per-payment-type flag, a permission,
// and a "Test drawer open" button that was a 700 ms `Future.delayed` reporting
// success without sending a byte.
//
// The transports themselves need real hardware, so what is pinned here is
// everything that decides WHAT is sent, WHERE, and WHETHER — the parts that
// silently misbehave.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/printer/cash_drawer_service.dart';
import 'package:pos_app/printer/raw_printer_windows.dart';
import 'package:pos_app/settings/device_scoped_settings.dart';

void main() {
  group('parseKickCommand', () {
    test('reads the shipped escaped-hex default', () {
      expect(parseKickCommand(r'\x1B\x70\x00\x19\xFA'),
          [0x1B, 0x70, 0x00, 0x19, 0xFA]);
    });

    test('reads bare hex, spaced or comma-separated', () {
      expect(parseKickCommand('1B 70 00 19 FA'),
          [0x1B, 0x70, 0x00, 0x19, 0xFA]);
      expect(parseKickCommand('0x1B,0x70,0x00,0x19,0xFA'),
          [0x1B, 0x70, 0x00, 0x19, 0xFA]);
    });

    test('reads decimal — the other notation printer manuals print', () {
      expect(parseKickCommand('27,112,0,25,250'),
          [0x1B, 0x70, 0x00, 0x19, 0xFA]);
    });

    test('a hex letter anywhere makes the whole string hex', () {
      // "27 70" alone is decimal, but "1B 70" cannot be: reading token-by-token
      // would give 27 for the first and 70 for the second out of one command.
      expect(parseKickCommand('1B 70'), [0x1B, 0x70]);
      expect(parseKickCommand('27 112'), [27, 112]);
    });

    test('lower case and odd separators are accepted', () {
      expect(parseKickCommand(r'\x1b\x70'), [0x1B, 0x70]);
      expect(parseKickCommand('1B;70;00'), [0x1B, 0x70, 0x00]);
    });

    test('rejects junk instead of sending half a command', () {
      expect(() => parseKickCommand(''), throwsFormatException);
      expect(() => parseKickCommand('   '), throwsFormatException);
      expect(() => parseKickCommand('open sesame'), throwsFormatException);
      expect(() => parseKickCommand('300,1'), throwsFormatException);
      expect(() => parseKickCommand(r'\x1B junk \x70'), throwsFormatException);
    });
  });

  group('resolveKickBytes — the forgiving path used at checkout', () {
    test('blank or unparseable falls back to the standard ESC p kick', () {
      expect(resolveKickBytes(null), kDefaultKickCommand);
      expect(resolveKickBytes(''), kDefaultKickCommand);
      expect(resolveKickBytes('nonsense'), kDefaultKickCommand);
    });

    test('a valid command is used verbatim', () {
      expect(resolveKickBytes(r'\x1B\x70\x01\x32\x32'),
          [0x1B, 0x70, 0x01, 0x32, 0x32]);
    });
  });

  group('CashDrawerTransport', () {
    test('parses the stored value, unknown falls back to printer', () {
      expect(CashDrawerTransport.fromSetting('network'),
          CashDrawerTransport.network);
      expect(CashDrawerTransport.fromSetting('SERIAL'),
          CashDrawerTransport.serial);
      expect(CashDrawerTransport.fromSetting(null),
          CashDrawerTransport.printer);
      expect(CashDrawerTransport.fromSetting('carrier pigeon'),
          CashDrawerTransport.printer);
    });

    test('setting values are stable identifiers, not display text', () {
      expect(CashDrawerTransport.values.map((t) => t.settingValue),
          ['printer', 'network', 'serial']);
    });

    test('network is the one transport available everywhere', () {
      expect(CashDrawerTransport.network.isSupportedHere, isTrue);
    });
  });

  group('CashDrawerConfig.fromSettings', () {
    test('reads one station out of the flat settings map', () {
      final config = CashDrawerConfig.fromSettings({
        'Receipt.CashDrawer.Enabled': 'true',
        'Receipt.CashDrawer.Transport': 'network',
        'Receipt.CashDrawer.Host': '192.168.1.50',
        'Receipt.CashDrawer.TcpPort': '9100',
        'Receipt.CashDrawer.Command': r'\x1B\x70\x00\x19\xFA',
        'Receipt.PrinterName': 'EPSON TM-T20II',
      }, 'Receipt');

      expect(config.enabled, isTrue);
      expect(config.transport, CashDrawerTransport.network);
      expect(config.host, '192.168.1.50');
      expect(config.tcpPort, 9100);
      expect(config.printerName, 'EPSON TM-T20II');
      expect(config.kick, [0x1B, 0x70, 0x00, 0x19, 0xFA]);
    });

    test('stations are independent — Kitchen is not Receipt', () {
      final settings = {
        'Receipt.CashDrawer.Enabled': 'true',
        'Kitchen.CashDrawer.Enabled': 'false',
      };
      expect(
          CashDrawerConfig.fromSettings(settings, 'Receipt').enabled, isTrue);
      expect(
          CashDrawerConfig.fromSettings(settings, 'Kitchen').enabled, isFalse);
    });

    test('an empty map still yields a usable config from the defaults', () {
      final config = CashDrawerConfig.fromSettings(const {}, 'Receipt');
      expect(config.enabled, isFalse);
      expect(config.transport, CashDrawerTransport.printer);
      expect(config.tcpPort, kDefaultDrawerTcpPort);
      expect(config.baudRate, 9600);
      expect(config.kick, kDefaultKickCommand);
    });

    test('a garbled port number does not crash the sale', () {
      final config = CashDrawerConfig.fromSettings({
        'Receipt.CashDrawer.TcpPort': 'nine thousand',
        'Receipt.CashDrawer.BaudRate': '',
      }, 'Receipt');
      expect(config.tcpPort, kDefaultDrawerTcpPort);
      expect(config.baudRate, 9600);
    });
  });

  group('enabledCashDrawers', () {
    test('finds the seeded stations without a stored printer list', () {
      final drawers = enabledCashDrawers({
        'Receipt.CashDrawer.Enabled': 'true',
      });
      expect(drawers, hasLength(1));
      expect(drawers.single.transport, CashDrawerTransport.printer);
    });

    test('a drawer wired to a non-receipt station is still found', () {
      final drawers = enabledCashDrawers({
        'Kitchen.CashDrawer.Enabled': 'true',
        'Kitchen.CashDrawer.Transport': 'serial',
        'Kitchen.CashDrawer.SerialPort': 'COM4',
      });
      expect(drawers, hasLength(1));
      expect(drawers.single.serialPort, 'COM4');
    });

    test('nothing enabled means nothing is fired', () {
      expect(enabledCashDrawers(const {}), isEmpty);
    });
  });

  group('shouldOpenDrawerForSale', () {
    test('a till that never configured payment types still opens', () {
      // The trap: turning the station switch on and never visiting Payment
      // Types leaves every openCashDrawer false, which would look exactly like
      // the drawer never being wired.
      expect(
        shouldOpenDrawerForSale(
          paymentTypeOpensDrawer: false,
          anyPaymentTypeOpensDrawer: false,
        ),
        isTrue,
      );
    });

    test('once any type opts in, the flags decide', () {
      expect(
        shouldOpenDrawerForSale(
          paymentTypeOpensDrawer: true,
          anyPaymentTypeOpensDrawer: true,
        ),
        isTrue,
      );
      // Card sale in a venue that flagged cash — the drawer stays shut.
      expect(
        shouldOpenDrawerForSale(
          paymentTypeOpensDrawer: false,
          anyPaymentTypeOpensDrawer: true,
        ),
        isFalse,
      );
    });
  });

  group('the drawer wiring is per-terminal, not company-wide', () {
    test('transport and endpoints are device-scoped', () {
      for (final key in [
        'Receipt.CashDrawer.Transport',
        'Receipt.CashDrawer.Host',
        'Receipt.CashDrawer.TcpPort',
        'Receipt.CashDrawer.SerialPort',
        'Receipt.CashDrawer.BaudRate',
      ]) {
        expect(DeviceScopedSettings.isDeviceScoped(key), isTrue, reason: key);
      }
    });

    test('the switch and the command bytes stay company-wide', () {
      // These describe the printer model and the venue policy, not the cabling
      // in front of one till, so they must keep syncing.
      expect(
        DeviceScopedSettings.isDeviceScoped('Receipt.CashDrawer.Enabled'),
        isFalse,
      );
      expect(
        DeviceScopedSettings.isDeviceScoped('Receipt.CashDrawer.Command'),
        isFalse,
      );
    });
  });

  group('shipped defaults', () {
    test('both seed printers carry a complete drawer configuration', () {
      for (final role in ['Receipt', 'Kitchen']) {
        expect(kSettingDefaults['$role.CashDrawer.Transport'], 'printer');
        expect(kSettingDefaults['$role.CashDrawer.TcpPort'], '9100');
        expect(kSettingDefaults['$role.CashDrawer.BaudRate'], '9600');
      }
    });
  });
  group('the Windows RAW spooler path', () {
    // Reaching a real drawer needs real hardware, but the FFI itself is
    // testable: a queue that does not exist exercises the whole binding —
    // library load, UTF-16 marshalling, OpenPrinter, and the error read.
    test('a missing print queue fails with the Win32 reason, not silence', () {
      expect(
        () => sendRawToWindowsPrinter(
          printerName: 'NO SUCH PRINTER 12345',
          bytes: Uint8List.fromList([0x1B, 0x70]),
        ),
        throwsA(isA<RawPrintException>().having(
          (e) => e.message,
          'message',
          // 1801 is ERROR_INVALID_PRINTER_NAME. Pinned as a NUMBER because it
          // read 0 until the GetLastError binding was resolved ahead of the
          // spooler call — "it threw" alone would not have caught that.
          contains('1801'),
        )),
      );
    }, skip: !Platform.isWindows);

    test('an empty printer name is refused before any FFI call', () {
      expect(
        () => sendRawToWindowsPrinter(
          printerName: '   ',
          bytes: Uint8List.fromList([0x1B]),
        ),
        throwsA(isA<RawPrintException>()),
      );
    });
  });
}
