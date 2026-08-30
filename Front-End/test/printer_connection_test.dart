// Which route a print job takes, and what a tablet inherits from a Windows
// till. The bytes and the socket are covered by escpos_raster_test.dart and
// network_printer_test.dart; this is the wiring in front of them.
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/settings/device_scoped_settings.dart';
import 'package:pos_app/settings/printer_settings_screen.dart';

void main() {
  group('routing', () {
    test('a printer is on the network only when it says so', () {
      expect(printerIsNetwork({'Receipt.Connection': 'network'}, 'Receipt'),
          isTrue);
      expect(printerIsNetwork({'Receipt.Connection': 'system'}, 'Receipt'),
          isFalse);
    });

    test('🚨 an unset connection is SYSTEM, never network', () {
      // Defaulting to network with no address would turn every print on every
      // existing Windows till into an error on the first launch after upgrade.
      expect(printerIsNetwork(const {}, 'Receipt'), isFalse);
      expect(printerIsNetwork({'Receipt.Connection': ''}, 'Receipt'), isFalse);
      expect(printerIsNetwork({'Receipt.Connection': '  '}, 'Receipt'), isFalse);
    });

    test('case and padding do not decide where a receipt prints', () {
      expect(printerIsNetwork({'Receipt.Connection': ' NETWORK '}, 'Receipt'),
          isTrue);
    });

    test('each printer is routed on its own, not on the receipt printer', () {
      // A venue with the till on USB and the kitchen printer on the LAN is the
      // ordinary case, not an exotic one.
      const settings = {
        'Receipt.Connection': 'system',
        'Kitchen.Connection': 'network',
      };
      expect(printerIsNetwork(settings, 'Receipt'), isFalse);
      expect(printerIsNetwork(settings, 'Kitchen'), isTrue);
    });

    test('the keys are per role', () {
      expect(SettingKeys.roleConnection('Kitchen'), 'Kitchen.Connection');
      expect(SettingKeys.roleHost('Bar'), 'Bar.Host');
      expect(SettingKeys.roleTcpPort('Receipt'), 'Receipt.TcpPort');
    });

    test('every printer ships defaulted to the system route', () {
      expect(kSettingDefaults['Receipt.Connection'], 'system');
      expect(kSettingDefaults['Kitchen.Connection'], 'system');
      expect(kSettingDefaults['Receipt.TcpPort'], '9100');
      expect(kSettingDefaults['Receipt.Host'], '');
    });
  });

  group('what a tablet may inherit from a Windows till', () {
    test('🚨 the connection, address and port stay on their own terminal', () {
      // The same physical printer is a USB queue to the till and an IP address
      // to the tablet. A cloud-synced value would have each overwrite the
      // other's, which is how the drawer wiring was already scoped.
      for (final key in [
        'Receipt.Connection',
        'Receipt.Host',
        'Receipt.TcpPort',
        'Kitchen.Connection',
        'Kitchen.Host',
        'Kitchen.TcpPort',
      ]) {
        expect(DeviceScopedSettings.isDeviceScoped(key), isTrue,
            reason: '$key must not travel between terminals');
      }
    });

    test('what the TICKET says still travels', () {
      // Only the wiring is local. Paper size, margins and the footer describe
      // the document, which the venue wants identical everywhere.
      for (final key in [
        'Receipt.PaperSize',
        'Receipt.Footer',
        'Receipt.RightToLeft',
        'Receipt.CashDrawer.Command',
      ]) {
        expect(DeviceScopedSettings.isDeviceScoped(key), isFalse,
            reason: '$key describes the ticket, not this terminal');
      }
    });
  });
}
