/// The COM and LPT ports this machine **actually has**.
///
/// ## Why this file exists
///
/// Every port picker in the app used to offer a written-down list — `COM1`
/// through `COM10`, plus `LPT1`–`LPT3` whether or not the machine had a
/// parallel port at all. On a till whose Windows exposes exactly one port that
/// is nine or twelve wrong answers and one right one, and picking a wrong one
/// fails **silently**: the write goes to a device that is not there, the sale
/// completes, and the customer display stays dark. The operator has no way to
/// tell a mis-set port from dead hardware.
///
/// The fix is to stop guessing. Windows records the ports it has under
/// `HKLM\HARDWARE\DEVICEMAP`, written by the port drivers as they load:
///
/// ```
/// HARDWARE\DEVICEMAP\SERIALCOMM        \Device\Serial0 = COM2
/// HARDWARE\DEVICEMAP\PARALLEL PORTS    \Device\ParallelPort0 = LPT1
/// ```
///
/// That is the same key `System.IO.Ports.SerialPort.GetPortNames()` reads,
/// which matters more than it sounds: it is why this app now offers the
/// operator the *same* list as the other POS software already installed on
/// their till. "Aronium shows COM2 and you show ten ports" is not a difference
/// anyone should have to adjudicate.
///
/// 🚨 **A key that does not exist means zero ports, not an error.** A machine
/// with no parallel port has no `PARALLEL PORTS` key at all — the common case
/// on anything made this century. Treat the miss as an empty list; never
/// substitute a default, because a substituted default is exactly the bug this
/// file removes.
library;

import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// Serial and parallel ports, read from the Windows device map.
abstract final class WindowsPorts {
  /// `HKLM\HARDWARE\DEVICEMAP\SERIALCOMM` — every COM port with a loaded
  /// driver, built-in and USB-adapter alike.
  static const serialKeyPath = r'HARDWARE\DEVICEMAP\SERIALCOMM';

  /// `HKLM\HARDWARE\DEVICEMAP\PARALLEL PORTS` — absent on a machine with no
  /// parallel port, which is most of them.
  static const parallelKeyPath = r'HARDWARE\DEVICEMAP\PARALLEL PORTS';

  /// The COM ports this machine has. Empty off Windows.
  static List<String> serial() => _deviceMap(serialKeyPath);

  /// The LPT ports this machine has. Empty off Windows, and empty on the many
  /// Windows machines that have no parallel port.
  static List<String> parallel() => _deviceMap(parallelKeyPath);

  /// Reads one device-map key and returns its **values**, not its value names.
  ///
  /// The name is the kernel device path (`\Device\Serial0`); the port name the
  /// operator knows is the data (`COM2`).
  static List<String> _deviceMap(String path) {
    if (!Platform.isWindows) return const [];
    RegistryKey? key;
    try {
      key = Registry.openPath(RegistryHive.localMachine, path: path);
      final out = <String>[];
      for (final value in key.values) {
        // Device-map entries are REG_SZ. Anything else in there is not a port.
        if (value is! StringValue) continue;
        final port = normalizePortName(value.value);
        if (port.isEmpty || out.contains(port)) continue;
        out.add(port);
      }
      return out;
    } catch (_) {
      // Missing key (no ports of this kind) or no read access. Either way the
      // honest answer is "none", never a fabricated default.
      return const [];
    } finally {
      key?.close();
    }
  }
}

/// Trims and upper-cases a port name so `com2`, `COM2 ` and `COM2` are one
/// entry. Windows port names are case-insensitive; a settings file written by
/// an earlier build is not guaranteed to agree on case.
String normalizePortName(String raw) => raw.trim().toUpperCase();

/// Orders port names the way a human reads them: `COM2` before `COM10`.
///
/// A plain string sort puts `COM10` above `COM2`, which in a dropdown of a
/// dozen ports reads as a list in no order at all. Compares the alphabetic
/// prefix first, then the trailing number as a number.
int comparePortNames(String a, String b) {
  final ma = _portPattern.firstMatch(a);
  final mb = _portPattern.firstMatch(b);
  if (ma == null || mb == null) return a.compareTo(b);
  final prefix = ma.group(1)!.compareTo(mb.group(1)!);
  if (prefix != 0) return prefix;
  return int.parse(ma.group(2)!).compareTo(int.parse(mb.group(2)!));
}

final RegExp _portPattern = RegExp(r'^([A-Za-z]+)(\d+)$');

/// Builds the list a port dropdown shows, from the sources that reported
/// something.
///
/// Split out from the registry read so it can be tested off Windows — the
/// merge is where the judgement lives, and it is the half that used to be
/// wrong.
///
/// * [detected] sources are unioned and de-duplicated: a USB adapter can be
///   reported by both the device map and `libserialport`, and neither is a
///   superset of the other.
/// * [saved] is folded in **only when the machine no longer reports it**, so a
///   display whose cable is out for the afternoon keeps its configured port
///   instead of the field silently rewriting itself to some other device. It
///   sorts to the front because it is the current answer, not a suggestion.
List<String> mergePortLists({
  required List<List<String>> detected,
  String? saved,
}) {
  final ports = <String>{};
  for (final source in detected) {
    for (final raw in source) {
      final port = normalizePortName(raw);
      if (port.isNotEmpty) ports.add(port);
    }
  }
  final out = ports.toList()..sort(comparePortNames);
  final current = normalizePortName(saved ?? '');
  if (current.isNotEmpty && !out.contains(current)) out.insert(0, current);
  return out;
}
