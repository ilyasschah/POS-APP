/// Opens the cash drawer — the part that was never wired (handoff.md ⭐8).
///
/// ## What was there before
///
/// `<Role>.CashDrawer.Enabled` and `<Role>.CashDrawer.Command` have existed as
/// settings for months, the payment type carries `openCashDrawer`, users have a
/// `CashDrawer.Open` permission, and Printer Settings even had a **"Test drawer
/// open"** button. Nothing sent a single byte: the test button was a 700 ms
/// `Future.delayed` followed by "Test signal sent to drawer". Every layer above
/// the hardware was finished and the hardware layer was missing.
///
/// ## Why this asks nothing about your wiring
///
/// The open question on ⭐8 was *"how is the drawer wired — printer RJ11, COM
/// port, or LAN?"*. Rather than hard-code one answer, all three are implemented
/// and the wiring is a **setting**, so the same build works on a Windows till
/// with an RJ11 drawer and on a tablet driving a network printer:
///
/// * [CashDrawerTransport.printer] — the drawer is plugged into the receipt
///   printer's RJ11/DK port (by far the most common, and the default). The kick
///   is sent to the station's own print queue as a RAW job
///   (`raw_printer_windows.dart`). Windows only, because a Windows print queue
///   is what it addresses.
/// * [CashDrawerTransport.network] — a TCP socket to `host:port` (9100 by
///   default). Covers both a **LAN printer** with the drawer on its RJ11 port
///   and a drawer with an IP of its own. The only transport that works on the
///   Android tablets, and the same socket item ⭐9 will print through.
/// * [CashDrawerTransport.serial] — bytes straight down a COM port, reusing the
///   `flutter_libserialport` dependency the weighing scale already carries.
///
/// ## Failures are loud
///
/// Every path throws [CashDrawerException] with a sentence fit to show a
/// cashier. A drawer that silently does not open is indistinguishable from a
/// drawer that is not configured, which is how ⭐8 stayed invisible for so long.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/printer/printer_config_model.dart';
import 'package:pos_app/printer/raw_printer_windows.dart';

/// The drawer could not be opened. [message] is operator-facing.
class CashDrawerException implements Exception {
  final String message;
  const CashDrawerException(this.message);
  @override
  String toString() => message;
}

/// How the kick reaches the drawer.
enum CashDrawerTransport {
  /// Through the station's receipt printer (drawer in its RJ11 port).
  printer('printer'),

  /// TCP to a printer or drawer with an IP address (ESC/POS port 9100).
  network('network'),

  /// Straight down a serial port.
  serial('serial');

  const CashDrawerTransport(this.settingValue);

  /// The string persisted in settings. Stable — never localise this.
  final String settingValue;

  static CashDrawerTransport fromSetting(String? raw) {
    final v = raw?.trim().toLowerCase();
    for (final t in CashDrawerTransport.values) {
      if (t.settingValue == v) return t;
    }
    return CashDrawerTransport.printer;
  }

  /// True where this transport can do anything on the current platform.
  bool get isSupportedHere => switch (this) {
        CashDrawerTransport.printer => kRawWindowsPrintingSupported,
        CashDrawerTransport.network => true,
        CashDrawerTransport.serial => Platform.isWindows || Platform.isLinux,
      };
}

/// The industry-standard ESC/POS kick: `ESC p 0 25 250` — pin 2, 50 ms on,
/// 500 ms off. Used when the configured command is blank or unparseable.
final Uint8List kDefaultKickCommand =
    Uint8List.fromList([0x1B, 0x70, 0x00, 0x19, 0xFA]);

/// Default ESC/POS port for a network printer.
const int kDefaultDrawerTcpPort = 9100;

/// Turns a human-written command string into the bytes to send.
///
/// Accepts the three notations these commands are published in, because every
/// printer manual picks a different one and the operator copies what they were
/// given:
///
/// * escaped hex — `\x1B\x70\x00\x19\xFA` (the shipped default)
/// * bare hex    — `1B 70 00 19 FA` or `0x1B,0x70,…`
/// * decimal     — `27,112,0,25,250`
///
/// A token is read as decimal only when it is all digits AND the string carries
/// no hex marker, so `27` means 27 and `1B` means 0x1B. Throws [FormatException]
/// on anything else — see [resolveKickBytes] for the forgiving wrapper.
Uint8List parseKickCommand(String raw) {
  final text = raw.trim();
  if (text.isEmpty) throw const FormatException('The command is empty.');

  // Escaped-hex form. Consume \xNN pairs and allow nothing else between them.
  if (text.contains(RegExp(r'\\x', caseSensitive: false))) {
    final out = <int>[];
    final pattern = RegExp(r'\\x([0-9a-fA-F]{2})', caseSensitive: false);
    var cursor = 0;
    for (final m in pattern.allMatches(text)) {
      final gap = text.substring(cursor, m.start).trim();
      if (gap.isNotEmpty) {
        throw FormatException('Unexpected "$gap" in the command.');
      }
      out.add(int.parse(m.group(1)!, radix: 16));
      cursor = m.end;
    }
    final tail = text.substring(cursor).trim();
    if (tail.isNotEmpty) {
      throw FormatException('Unexpected "$tail" at the end of the command.');
    }
    if (out.isEmpty) throw const FormatException(r'No \xNN bytes found.');
    return Uint8List.fromList(out);
  }

  final tokens = text.split(RegExp(r'[\s,;]+')).where((t) => t.isNotEmpty);
  final hasHexMarker = RegExp(r'0x|[a-fA-F]').hasMatch(text);
  final out = <int>[];
  for (final token in tokens) {
    final int? value;
    if (token.toLowerCase().startsWith('0x')) {
      value = int.tryParse(token.substring(2), radix: 16);
    } else if (hasHexMarker) {
      value = int.tryParse(token, radix: 16);
    } else {
      value = int.tryParse(token);
    }
    if (value == null || value < 0 || value > 255) {
      throw FormatException('"$token" is not a byte value (00-FF).');
    }
    out.add(value);
  }
  if (out.isEmpty) throw const FormatException('No bytes found.');
  return Uint8List.fromList(out);
}

/// [parseKickCommand] with a safety net: an unset or malformed command falls
/// back to [kDefaultKickCommand] rather than leaving the till unable to open.
/// The Printer Settings test button validates strictly instead, so a typo is
/// still reported where it can be fixed.
Uint8List resolveKickBytes(String? configured) {
  if (configured == null || configured.trim().isEmpty) {
    return kDefaultKickCommand;
  }
  try {
    return parseKickCommand(configured);
  } on FormatException {
    return kDefaultKickCommand;
  }
}

/// Reads the drawer configuration of one printer station out of the settings
/// map. [role] is the printer prefix — `Receipt`, `Kitchen`, `Printer.<uuid>`.
class CashDrawerConfig {
  final bool enabled;
  final CashDrawerTransport transport;
  final Uint8List kick;

  /// Windows print queue for [CashDrawerTransport.printer].
  final String printerName;

  /// Host/port for [CashDrawerTransport.network].
  final String host;
  final int tcpPort;

  /// Port/baud for [CashDrawerTransport.serial].
  final String serialPort;
  final int baudRate;

  const CashDrawerConfig({
    required this.enabled,
    required this.transport,
    required this.kick,
    required this.printerName,
    required this.host,
    required this.tcpPort,
    required this.serialPort,
    required this.baudRate,
  });

  factory CashDrawerConfig.fromSettings(
    Map<String, String> settings,
    String role,
  ) {
    String read(String key) =>
        (settings[key] ?? kSettingDefaults[key] ?? '').trim();

    return CashDrawerConfig(
      enabled:
          read(SettingKeys.roleCashDrawerEnabled(role)).toLowerCase() == 'true',
      transport: CashDrawerTransport.fromSetting(
        read(SettingKeys.roleCashDrawerTransport(role)),
      ),
      kick: resolveKickBytes(read(SettingKeys.roleCashDrawerCommand(role))),
      printerName: read(SettingKeys.rolePrinterName(role)),
      host: read(SettingKeys.roleCashDrawerHost(role)),
      tcpPort: int.tryParse(read(SettingKeys.roleCashDrawerTcpPort(role))) ??
          kDefaultDrawerTcpPort,
      serialPort: read(SettingKeys.roleCashDrawerSerialPort(role)),
      baudRate:
          int.tryParse(read(SettingKeys.roleCashDrawerBaudRate(role))) ?? 9600,
    );
  }
}

/// Sends the kick. Throws [CashDrawerException] when it cannot.
///
/// Does **not** consult [CashDrawerConfig.enabled] — an operator pressing "Open
/// drawer" or "Test" means it. Automatic paths (checkout) check `enabled`
/// themselves so a station with no drawer stays silent.
Future<void> kickCashDrawer(CashDrawerConfig config) async {
  if (!config.transport.isSupportedHere) {
    throw CashDrawerException(switch (config.transport) {
      CashDrawerTransport.printer =>
        'Opening the drawer through the receipt printer needs Windows. On this '
            'device use the Network transport (the printer IP, port 9100).',
      CashDrawerTransport.serial =>
        'Serial cash drawers are only reachable on Windows.',
      CashDrawerTransport.network => 'Unsupported transport.',
    });
  }

  switch (config.transport) {
    case CashDrawerTransport.printer:
      try {
        sendRawToWindowsPrinter(
          printerName: config.printerName,
          bytes: config.kick,
          jobName: 'Cash drawer',
        );
      } on RawPrintException catch (e) {
        throw CashDrawerException(e.message);
      }
    case CashDrawerTransport.network:
      await _kickOverNetwork(config);
    case CashDrawerTransport.serial:
      _kickOverSerial(config);
  }
}

/// Every printer station on this terminal whose drawer switch is on.
///
/// Scans the whole `Printers.List` rather than assuming `Receipt`: a venue can
/// wire the drawer to any station, and a till with two drawers is a real (if
/// rare) layout.
List<CashDrawerConfig> enabledCashDrawers(Map<String, String> settings) {
  return PrinterConfig.listFromJson(settings[SettingKeys.printersList])
      .where((p) => p.enabled)
      .map((p) => CashDrawerConfig.fromSettings(settings, p.prefix))
      .where((c) => c.enabled)
      .toList();
}

/// Whether a completed sale paid with [paymentTypeOpensDrawer] should pop the
/// drawer, given every payment type the company has defined.
///
/// Two switches govern this and they mean different things:
///
/// * the **station** switch (`<Role>.CashDrawer.Enabled`) says a drawer is
///   physically wired to this printer — without it nothing ever fires;
/// * the **payment type** flag (`PaymentType.openCashDrawer`) says this tender
///   takes cash out of the drawer, so a card sale leaves it shut.
///
/// The trap is a till that switched the station on and never opened the Payment
/// Types screen: every type still reads `false` and the drawer would never move,
/// which looks exactly like the bug this item fixes. So "no payment type opts
/// in anywhere" is read as "the venue has not made that distinction" and every
/// sale opens the drawer. The moment ONE type is flagged, the flags rule.
bool shouldOpenDrawerForSale({
  required bool paymentTypeOpensDrawer,
  required bool anyPaymentTypeOpensDrawer,
}) =>
    paymentTypeOpensDrawer || !anyPaymentTypeOpensDrawer;

/// Fires every enabled drawer on this terminal. **Never throws** — its two
/// callers both need that. After a sale the money is already banked and a
/// jammed drawer must not turn a completed transaction into an error; behind
/// the till's "Open Drawer" button a thrown exception would reach the cashier
/// as a crash instead of a sentence. Returns the failure messages so the caller
/// can surface them without blocking.
///
/// An empty [enabledCashDrawers] returns no failures — nothing was attempted.
/// The manual button checks for that case itself, because "no drawer is set up"
/// and "the drawer opened" must not look the same to the operator.
Future<List<String>> openEnabledDrawers(Map<String, String> settings) async {
  final failures = <String>[];
  for (final drawer in enabledCashDrawers(settings)) {
    try {
      await kickCashDrawer(drawer);
    } on CashDrawerException catch (e) {
      failures.add(e.message);
    } catch (e) {
      failures.add(e.toString());
    }
  }
  return failures;
}

Future<void> _kickOverNetwork(CashDrawerConfig config) async {
  if (config.host.isEmpty) {
    throw const CashDrawerException(
      'No address is set for the drawer. Enter the printer IP address.',
    );
  }
  Socket? socket;
  try {
    socket = await Socket.connect(
      config.host,
      config.tcpPort,
      timeout: const Duration(seconds: 4),
    );
    socket.add(config.kick);
    await socket.flush();
  } on SocketException catch (e) {
    throw CashDrawerException(
      'Could not reach ${config.host}:${config.tcpPort} — '
      '${e.osError?.message ?? e.message}.',
    );
  } on TimeoutException {
    throw CashDrawerException(
      '${config.host}:${config.tcpPort} did not answer within 4 seconds.',
    );
  } finally {
    socket?.destroy();
  }
}

void _kickOverSerial(CashDrawerConfig config) {
  if (config.serialPort.isEmpty) {
    throw const CashDrawerException(
      'No serial port is set for the drawer (for example COM3).',
    );
  }
  final port = SerialPort(config.serialPort);
  if (!port.openWrite()) {
    final reason = SerialPort.lastError?.message ?? 'port unavailable';
    port.dispose();
    throw CashDrawerException('Could not open ${config.serialPort} — $reason.');
  }
  try {
    final cfg = SerialPortConfig()
      ..baudRate = config.baudRate
      ..bits = 8
      ..parity = SerialPortParity.none
      ..stopBits = 1
      ..setFlowControl(SerialPortFlowControl.none);
    try {
      port.config = cfg;
    } finally {
      cfg.dispose();
    }
    final sent = port.write(config.kick, timeout: 1000);
    port.drain();
    if (sent != config.kick.length) {
      throw CashDrawerException(
        '${config.serialPort} accepted only $sent of ${config.kick.length} bytes.',
      );
    }
  } finally {
    port.close();
    port.dispose();
  }
}
