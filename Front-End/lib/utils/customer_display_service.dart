import 'dart:io';
import 'package:pos_app/app_settings/app_settings_model.dart';

/// Sends text to a serial VFD / LCD pole display connected via COM port.
///
/// Protocol: plain ASCII + CR.  Works with the vast majority of 2-line pole
/// displays (Epson, Logic Controls, Partner, Bixolon, etc.).
///
/// Port configuration is applied via the Windows `mode` command before every
/// write, so the Flutter app does not need a third-party serial package.
/// On Android the methods are silent no-ops.
class CustomerDisplayService {
  CustomerDisplayService._();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Show [total] on line 2, "TOTAL DUE" on line 1.
  static Future<void> showTotal({
    required Map<String, String> settings,
    required double total,
    required String currencySymbol,
  }) async {
    final numChars =
        int.tryParse(settings[SettingKeys.customerDisplayNumChars] ?? '20') ??
        20;
    final totalStr = '$currencySymbol ${total.toStringAsFixed(2)}';
    await _send(
      settings: settings,
      line1: 'TOTAL DUE',
      line2: totalStr,
      numChars: numChars,
    );
  }

  /// Show the configured welcome message (called when the payment dialog closes).
  static Future<void> showWelcome({
    required Map<String, String> settings,
  }) async {
    final numChars =
        int.tryParse(settings[SettingKeys.customerDisplayNumChars] ?? '20') ??
        20;
    await _send(
      settings: settings,
      line1: settings[SettingKeys.customerDisplayWelcomeMessage] ?? 'WELCOME!',
      line2: settings[SettingKeys.customerDisplayWelcomeBottom] ?? '',
      numChars: numChars,
    );
  }

  // ── Internals ───────────────────────────────────────────────────────────────

  static Future<void> _send({
    required Map<String, String> settings,
    required String line1,
    required String line2,
    required int numChars,
  }) async {
    if (!Platform.isWindows) return;
    final enabled =
        settings[SettingKeys.customerDisplayEnabled]?.toLowerCase() == 'true';
    if (!enabled) return;

    final port = settings[SettingKeys.customerDisplayPort] ?? 'COM1';
    await _configurePort(port, settings);

    // Pad/trim both lines to exactly numChars characters
    final l1 = _pad(line1, numChars);
    final l2 = _pad(line2, numChars);

    // 0x0C = Form Feed — clears most VFD displays before writing
    final bytes = [0x0C, ...l1.codeUnits, 0x0D, ...l2.codeUnits, 0x0D];

    try {
      // Windows exposes COM ports as special files: COM1–COM9 directly,
      // COM10+ via the \\.\COMn device path.
      final portPath = _portPath(port);
      final raf = await File(portPath).open(mode: FileMode.write);
      await raf.writeFrom(bytes);
      await raf.close();
    } catch (_) {
      // Display errors must never crash the POS session.
    }
  }

  /// Applies baud rate / parity / data-bits / stop-bits via Windows `mode`.
  static Future<void> _configurePort(
    String port,
    Map<String, String> settings,
  ) async {
    try {
      final baud = settings[SettingKeys.customerDisplayBaudRate] ?? '9600';
      final parity =
          (settings[SettingKeys.customerDisplayParity] ?? 'None')
              .substring(0, 1)
              .toUpperCase(); // N / E / O
      final data = settings[SettingKeys.customerDisplayDataBits] ?? '8';
      final stop = settings[SettingKeys.customerDisplayStopBits] ?? '1';
      await Process.run('mode', [
        '$port:',
        'BAUD=$baud',
        'PARITY=$parity',
        'DATA=$data',
        'STOP=$stop',
      ]);
    } catch (_) {}
  }

  static String _portPath(String port) {
    final n = int.tryParse(port.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    return n > 9 ? '\\\\.\\$port' : port;
  }

  static String _pad(String s, int len) {
    final padded = s.padRight(len);
    return padded.length > len ? padded.substring(0, len) : padded;
  }
}
