// The pole display was written on `dart:io`'s File, which CANNOT open a
// Windows device path — so it never worked, on any port, on any machine. These
// pin the replacement.
//
// What is testable here is the path form and the failure reporting; a
// successful write needs a real (or virtual) port, which
// `dart run tool/probe_write.dart COM8` does against a com0com pair.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/utils/windows_device_write.dart';

void main() {
  group('windowsDevicePath', () {
    test('always produces the device-namespace form', () {
      // The bare name is resolved against the working directory first, which is
      // how a "write to COM1" can silently create a FILE called COM1.
      expect(windowsDevicePath('COM8'), r'\\.\COM8');
      expect(windowsDevicePath('LPT1'), r'\\.\LPT1');
    });

    test('normalises case and padding, so a saved value cannot miss', () {
      expect(windowsDevicePath('  com8 '), r'\\.\COM8');
    });

    test('handles COM10 and above, which the bare form cannot address', () {
      expect(windowsDevicePath('COM10'), r'\\.\COM10');
      expect(windowsDevicePath('COM255'), r'\\.\COM255');
    });
  });

  group('writeToWindowsDevice', () {
    final bytes = Uint8List.fromList(const [0x0C, 0x41, 0x0D]);

    test('a port that does not exist names the port and where to look', () {
      if (!Platform.isWindows) return;
      // COM255 is a legal name that no machine has. The old code reported this
      // as errno 161 "path is invalid", which reads as a bug in the app rather
      // than a setting the operator can fix.
      try {
        writeToWindowsDevice(
          devicePath: windowsDevicePath('COM255'),
          bytes: bytes,
        );
        fail('writing to a nonexistent port should throw');
      } on WindowsDeviceException catch (e) {
        expect(e.message, contains('COM255'));
        expect(e.message.toLowerCase(), contains('device manager'));
        expect(e.errorCode, kErrorFileNotFound);
      }
    });

    test('a malformed device name is reported, not swallowed', () {
      if (!Platform.isWindows) return;
      expect(
        () => writeToWindowsDevice(devicePath: r'\\.\', bytes: bytes),
        throwsA(isA<WindowsDeviceException>()),
      );
    });

    test('off Windows it refuses rather than pretending to write', () {
      if (Platform.isWindows) return;
      expect(
        () => writeToWindowsDevice(devicePath: r'\\.\COM1', bytes: bytes),
        throwsA(isA<WindowsDeviceException>()),
      );
    });
  });
}

/// `ERROR_FILE_NOT_FOUND`, spelled out so the test does not depend on a win32
/// import just for a constant.
const kErrorFileNotFound = 2;
