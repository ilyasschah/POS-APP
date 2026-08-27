import 'dart:io';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';

/// Sends text to a serial VFD / LCD pole display connected via COM port.
///
/// Protocol: plain ASCII + CR.  Works with the vast majority of 2-line pole
/// displays (Epson, Logic Controls, Partner, Bixolon, etc.).
///
/// Port configuration is applied via the Windows `mode` command before every
/// write, so the Flutter app does not need a third-party serial package.
/// On Android the methods are silent no-ops.
/// The display could not be written to. [message] is operator-facing.
class CustomerDisplayException implements Exception {
  final String message;
  const CustomerDisplayException(this.message);
  @override
  String toString() => message;
}

class CustomerDisplayService {
  CustomerDisplayService._();

  /// The ports this machine actually has, for the settings picker.
  ///
  /// The picker used to offer a hardcoded COM1–COM10 whatever the hardware was,
  /// so a terminal whose Windows only has COM1–COM5 could sit configured on
  /// COM10 and quietly write to nothing. [saved] is folded in so a port that is
  /// currently unplugged still shows as the current choice instead of silently
  /// resetting.
  ///
  /// Parallel ports are appended by hand: `libserialport` enumerates serial
  /// devices only, and a pole display on LPT1 is still a display.
  static List<String> availablePorts({String? saved}) {
    final out = <String>[];
    if (Platform.isWindows) {
      try {
        out.addAll(SerialPort.availablePorts);
      } catch (_) {
        // Native library missing/unloadable — fall through to the defaults.
      }
      for (final lpt in const ['LPT1', 'LPT2', 'LPT3']) {
        if (!out.contains(lpt)) out.add(lpt);
      }
    }
    if (out.isEmpty) {
      out.addAll(const ['COM1', 'COM2', 'COM3', 'COM4']);
    }
    final current = saved?.trim();
    if (current != null && current.isNotEmpty && !out.contains(current)) {
      out.insert(0, current);
    }
    return out;
  }

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
    // The Test button wants to know WHY nothing appeared; a sale in progress
    // does not. Only the test path rethrows.
    bool throwOnError = false,
  }) async {
    if (!Platform.isWindows) {
      if (throwOnError) {
        throw const CustomerDisplayException(
            'A serial customer display is only supported on Windows.');
      }
      return;
    }
    final enabled =
        settings[SettingKeys.customerDisplayEnabled]?.toLowerCase() == 'true';
    if (!enabled) {
      if (throwOnError) {
        throw const CustomerDisplayException(
            'The customer display is switched off. Turn it on first.');
      }
      return;
    }

    final port = (settings[SettingKeys.customerDisplayPort] ?? 'COM1').trim();
    await _configurePort(port, settings);

    // Pad/trim both lines to exactly numChars characters
    final l1 = _pad(line1, numChars);
    final l2 = _pad(line2, numChars);

    // 0x0C = Form Feed — clears most VFD displays before writing
    final bytes = [0x0C, ...l1.codeUnits, 0x0D, ...l2.codeUnits, 0x0D];

    try {
      final raf = await File(_portPath(port)).open(mode: FileMode.write);
      await raf.writeFrom(bytes);
      await raf.close();
    } catch (e) {
      // A dead display must never disturb a sale — but a silent failure is
      // exactly why a display that was never wired up looked configured. The
      // test path says so out loud; the live path stays quiet.
      if (throwOnError) {
        throw CustomerDisplayException(
          'Could not write to $port. Check the port in Device Manager, and that '
          'no other program is holding it open. ($e)',
        );
      }
    }
  }

  /// Writes the welcome message and reports what actually happened.
  ///
  /// The Test button used to call [showWelcome] and then announce success
  /// unconditionally, so a wrong COM port — the commonest setup mistake by a
  /// wide margin — was indistinguishable from a working display.
  static Future<void> testWrite({
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
      throwOnError: true,
    );
  }

  /// Applies baud rate / parity / data-bits / stop-bits via Windows `mode`.
  ///
  /// A parallel port has none of those, so LPT is left alone — `mode LPT1: BAUD=…`
  /// is an error, and running it before every write turned a working parallel
  /// display into a silent one.
  static Future<void> _configurePort(
    String port,
    Map<String, String> settings,
  ) async {
    if (port.toUpperCase().startsWith('LPT')) return;
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

  /// The Win32 device path. Always the `\\.\` form: the bare `COM1` name is
  /// resolved relative to the working directory before it is treated as a
  /// device, which is how a "write" to a display can end up creating a file
  /// called COM1 instead of failing. `\\.\` addresses the device namespace
  /// directly and is the only form COM10+ and LPT accept anyway.
  static String _portPath(String port) => '\\\\.\\${port.toUpperCase()}';

  static String _pad(String s, int len) {
    final padded = s.padRight(len);
    return padded.length > len ? padded.substring(0, len) : padded;
  }
}
