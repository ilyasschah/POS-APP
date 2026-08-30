import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/l10n/app_locale.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/utils/pole_display_frame.dart';
import 'package:pos_app/utils/windows_device_write.dart';
import 'package:pos_app/utils/windows_ports.dart';

/// The ports the machine is reporting right now, for the settings picker.
///
/// A provider rather than a bare call so the Refresh button has something to
/// invalidate: a USB-serial adapter plugged in while this screen is open must
/// be able to appear without restarting the app.
final customerDisplayPortsProvider = Provider<List<String>>(
  (ref) => CustomerDisplayService.detectedPorts(),
);

/// Sends text to a serial VFD / LCD pole display connected via COM port.
///
/// Protocol: plain ASCII + CR.  Works with the vast majority of 2-line pole
/// displays (Epson, Logic Controls, Partner, Bixolon, etc.).
///
/// Baud / parity / bits are applied via the Windows `mode` command before every
/// write; the bytes themselves go through `utils/windows_device_write.dart`,
/// because 🚨 **`dart:io`'s `File` cannot open `\\.\COM8` at all** — which is
/// why this display never worked on any machine until 2026-08-30.
/// On Android the methods are silent no-ops.
///
/// The line composition itself — padding, the two halves of line 2, the
/// character folding — lives in `pole_display_frame.dart`, which carries no
/// Flutter dependency so `tool/probe_display.dart` can drive real hardware with
/// the same code the till uses.

/// One write as it would reach the port: both lines already padded to the
/// display's width.
class DisplayFrame {
  const DisplayFrame(this.port, this.line1, this.line2);

  final String port;
  final String line1;
  final String line2;

  @override
  String toString() => '[$port] "$line1" / "$line2"';
}

/// Captures frames instead of writing them, so a test can assert the exact text
/// a customer would read. A serial port is not available under `flutter test`,
/// and asserting the composed string one layer up would miss the padding and
/// the character folding — which is where the bugs are.
bool debugCaptureCustomerDisplay = false;

/// Frames captured while [debugCaptureCustomerDisplay] is set. Test-only.
final List<DisplayFrame> debugCustomerDisplayFrames = <DisplayFrame>[];

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
  /// 🚨 **Nothing here is written down.** The picker used to offer a hardcoded
  /// `COM1`–`COM10` plus `LPT1`–`LPT3` whatever the hardware was, so a till
  /// whose Windows exposes one port offered thirteen and twelve of them wrote
  /// to nothing — silently, because a write to an absent device fails the same
  /// way a display with a loose cable does. Every name below comes from the
  /// machine:
  ///
  /// * [WindowsPorts.serial] / [WindowsPorts.parallel] read Windows' own
  ///   device map, the same key `SerialPort.GetPortNames()` reads — which is
  ///   why this list now agrees with the other POS software on the till.
  /// * `libserialport` is unioned in because it enumerates the *Ports* device
  ///   class instead, and the two disagree at the edges (a USB-serial adapter
  ///   whose driver has not written a device-map entry yet).
  ///
  /// An empty result is a real answer — this machine has no ports — and the
  /// caller must render it as such rather than falling back to a default.
  ///
  /// [saved] is folded in only when the machine no longer reports it, so a
  /// display unplugged for the afternoon keeps its configured port instead of
  /// the field quietly rewriting itself to another device.
  static List<String> availablePorts({String? saved}) =>
      mergePortLists(detected: _sources(), saved: saved);

  /// Only the ports the machine is reporting — no saved value folded in.
  ///
  /// The picker needs both lists: [availablePorts] to populate the dropdown,
  /// this one to tell a real port from a configured-but-absent one so it can
  /// label the difference instead of showing a phantom that looks as real as
  /// the rest.
  static List<String> detectedPorts() => mergePortLists(detected: _sources());

  static List<List<String>> _sources() => Platform.isWindows
      ? [WindowsPorts.serial(), _libSerialPorts(), WindowsPorts.parallel()]
      : const [];

  static List<String> _libSerialPorts() {
    try {
      return SerialPort.availablePorts;
    } catch (_) {
      // Native library missing or unloadable. The device map still answered.
      return const [];
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Show [total] on line 2, the localized "TOTAL DUE" on line 1.
  ///
  /// The label follows the operator's language — a French counter should not be
  /// showing its customers an English word, and this was the last string on the
  /// display still written into the source.
  ///
  /// ⚠️ Language is a different question from [DisplayCharset]. Switching the
  /// app to Arabic does not give a Latin-only display Arabic glyphs: the label
  /// arrives as `?` until the hardware's codepage is set too. That is the honest
  /// outcome — it says the display cannot show this, rather than showing
  /// nonsense that looks like a fault.
  static Future<void> showTotal({
    required Map<String, String> settings,
    required double total,
    required String currencySymbol,
  }) async {
    final numChars = _numChars(settings);
    final totalStr = '$currencySymbol ${total.toStringAsFixed(2)}';
    await _send(
      settings: settings,
      line1: _l10n(settings).poleDisplayTotalDue,
      line2: totalStr,
      numChars: numChars,
    );
  }

  /// Show a line the cashier just rang: the product on line 1, what it cost and
  /// the running total on line 2.
  ///
  /// This is what a pole display is FOR. Until now it lit up only when the
  /// payment dialog opened, so a customer watched a blank display through the
  /// whole scan and got one number at the end — which is precisely the moment
  /// it is too late to query an item. The point of the thing is that they can
  /// check each item as it is rung.
  ///
  /// Layout at 20 characters:
  ///
  /// ```
  /// +--------------------+
  /// | Cafe au lait       |   <- product name, trimmed to fit
  /// | 2 x 12.50     25.00|   <- what was rung .... running TOTAL
  /// +--------------------+
  /// ```
  ///
  /// 🚨 **When the two halves do not fit, the LEFT is trimmed and the total is
  /// never touched.** The right-hand number is the one the customer is checking
  /// and a half-printed total is worse than no total — `25.0` reads as a real
  /// price. A long product name loses its tail; the money does not.
  static Future<void> showLineItem({
    required Map<String, String> settings,
    required String name,
    required double quantity,
    required double unitPrice,
    required double runningTotal,
    String unitLabel = '',
  }) async {
    final numChars = _numChars(settings);
    await _send(
      settings: settings,
      line1: name,
      line2: lineItemRow(
        quantity: quantity,
        unitPrice: unitPrice,
        runningTotal: runningTotal,
        width: numChars,
        unitLabel: unitLabel,
      ),
      numChars: numChars,
    );
  }

  /// Show the configured welcome message (called when the payment dialog closes).
  static Future<void> showWelcome({
    required Map<String, String> settings,
  }) async {
    final numChars = _numChars(settings);
    // The operator's own words win; only the fallback follows their language.
    final configured =
        settings[SettingKeys.customerDisplayWelcomeMessage]?.trim() ?? '';
    await _send(
      settings: settings,
      line1: configured.isNotEmpty
          ? configured
          : _l10n(settings).poleDisplayWelcome,
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
    final enabled =
        settings[SettingKeys.customerDisplayEnabled]?.toLowerCase() == 'true';

    // The capture seam sits AFTER the enabled gate and BEFORE the platform gate
    // on purpose: "switched off writes nothing" is behaviour worth testing, and
    // a test host is not Windows.
    if (debugCaptureCustomerDisplay) {
      if (!enabled) return;
      debugCustomerDisplayFrames.add(DisplayFrame(
        (settings[SettingKeys.customerDisplayPort] ?? 'COM1').trim(),
        padOrTrim(foldToDisplayText(line1), numChars),
        padOrTrim(foldToDisplayText(line2), numChars),
      ));
      return;
    }

    if (!Platform.isWindows) {
      if (throwOnError) {
        throw const CustomerDisplayException(
            'A serial customer display is only supported on Windows.');
      }
      return;
    }
    if (!enabled) {
      if (throwOnError) {
        throw const CustomerDisplayException(
            'The customer display is switched off. Turn it on first.');
      }
      return;
    }

    final port = (settings[SettingKeys.customerDisplayPort] ?? 'COM1').trim();

    // Only the Test button checks this, and deliberately so. A port that is not
    // on the machine fails exactly like a display with a loose cable — silence
    // — and the default is a written-down `COM1` that many tills do not have.
    // The operator pressing Test is asking "why is nothing happening?", so the
    // answer names the ports that DO exist rather than making them go and look.
    // The live sale path skips it: a per-write registry read is work a sale
    // does not need, and a mid-sale warning helps nobody.
    if (throwOnError) {
      final detected = detectedPorts();
      if (!detected.contains(normalizePortName(port))) {
        throw CustomerDisplayException(
          detected.isEmpty
              ? 'This machine reports no COM or LPT port at all, so $port '
                  'cannot exist. Check the cable and Device Manager.'
              : '$port is not on this machine. Ports detected: '
                  '${detected.join(', ')}.',
        );
      }
    }

    await _configurePort(port, settings);

    // Pad/trim both lines to exactly numChars characters
    final bytes = poleDisplayFrame(
      line1: line1,
      line2: line2,
      width: numChars,
      charset: _charset(settings),
    );

    try {
      // 🚨 NOT `dart:io`. `File(r'\\.\COM8')` throws errno 161 on a port that
      // is present and writable — it validates the path as a filesystem path
      // before the device namespace is ever reached, so this display never
      // worked on any port since it was written. See windows_device_write.dart.
      writeToWindowsDevice(
        devicePath: windowsDevicePath(port),
        bytes: Uint8List.fromList(bytes),
      );
    } on WindowsDeviceException catch (e) {
      // A dead display must never disturb a sale — but a silent failure is
      // exactly why a display that was never wired up looked configured. The
      // test path says so out loud; the live path stays quiet.
      //
      // The message is passed through rather than wrapped: it already names the
      // port and what to do about it, and the old wrapper appended a raw
      // exception that told the operator nothing they could act on.
      if (throwOnError) throw CustomerDisplayException(e.message);
    } catch (e) {
      if (throwOnError) {
        throw CustomerDisplayException('Could not write to $port. ($e)');
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

  /// Localized strings with no BuildContext — the same resolution the printers
  /// use, read from the settings map every caller already passes.
  static AppLocalizations _l10n(Map<String, String> s) =>
      lookupAppLocalizations(resolveAppLocale(s[SettingKeys.language]));

  /// What this counter's display can actually render. Hardware, not language.
  static DisplayCharset _charset(Map<String, String> s) =>
      DisplayCharset.fromSetting(s[SettingKeys.customerDisplayCharset]);

  static int _numChars(Map<String, String> settings) =>
      int.tryParse(settings[SettingKeys.customerDisplayNumChars] ?? '20') ?? 20;
}
