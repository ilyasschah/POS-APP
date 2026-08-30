// ignore_for_file: avoid_print
//
// Sends one pole-display frame the way the POS now does, so the write path can
// be proved without launching the app.
//
//   dart run tool/probe_write.dart COM8
//
// Pair it with the listener on the other end of a com0com pair:
//   .\tool\pole_display_listener.ps1 -Port COM9
import 'dart:typed_data';

import 'package:pos_app/utils/windows_device_write.dart';
import 'package:pos_app/utils/windows_ports.dart';

String pad(String s, int n) =>
    s.padRight(n).substring(0, n < s.length ? s.length : n).substring(0, n);

void main(List<String> args) {
  final port = args.isEmpty ? 'COM1' : args.first.toUpperCase();
  const width = 20;

  print('device map serial : ${WindowsPorts.serial()}');
  print('device map lpt    : ${WindowsPorts.parallel()}');
  print('');

  // The exact frame CustomerDisplayService._send builds:
  //   0x0C  +  line1 padded  +  0x0D  +  line2 padded  +  0x0D
  final bytes = Uint8List.fromList([
    0x0C,
    ...pad('TOTAL DUE', width).codeUnits,
    0x0D,
    ...pad('MAD 42.50', width).codeUnits,
    0x0D,
  ]);

  final path = windowsDevicePath(port);
  print('writing ${bytes.length} bytes to $path ...');
  try {
    writeToWindowsDevice(devicePath: path, bytes: bytes);
    print('OK — the listener on the far end should now read:');
    print('  [${pad('TOTAL DUE', width)}]');
    print('  [${pad('MAD 42.50', width)}]');
  } on WindowsDeviceException catch (e) {
    print('FAILED: ${e.message}  (code ${e.errorCode})');
  }
}
