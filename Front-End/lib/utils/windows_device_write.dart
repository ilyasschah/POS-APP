/// Writes raw bytes to a Windows **device**, such as `\\.\COM8` or `\\.\LPT1`.
///
/// ## Why this file exists
///
/// 🚨 **`dart:io`'s `File` cannot open a Windows device path — at all.** It is
/// not a permissions problem, not a "port in use" problem, and not affected by
/// whether the port exists:
///
/// ```
/// File(r'\\.\COM8').openSync(mode: FileMode.write)
///   -> PathNotFoundException: errno = 161 (ERROR_BAD_PATHNAME)
/// ```
///
/// COM8 was present and writable at that moment — the same byte sent through
/// `CreateFile`/`WriteFile` on the same path in the same second succeeded.
/// `File` validates the path as a *filesystem* path before it ever reaches the
/// device namespace, so `\\.\anything` is rejected on its face.
///
/// The customer display was built on `File`, which means **the serial pole
/// display never worked on any port, on any machine, since it was written**.
/// It looked like a wiring fault because the failure was caught and swallowed
/// on the sale path (deliberately — a dead display must not disturb a sale),
/// so the only symptom was a display that stayed dark.
///
/// ⚠️ The bare name (`File('COM8')`) is not a workaround: it fails with the
/// same errno, and on the paths where it does not, it CREATES A FILE called
/// `COM8` in the working directory. A write that appears to succeed and
/// produces a stray file is worse than one that throws.
///
/// So the device namespace has to be addressed the way Windows expects, which
/// means Win32 directly. This is the same reason `printer/raw_printer_windows.dart`
/// exists for the spooler.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// True where [writeToWindowsDevice] can run at all.
final bool kWindowsDeviceWriteSupported = Platform.isWindows;

/// Windows' per-thread last-error, bound here rather than taken from
/// `package:win32`.
///
/// 🚨 The same trap `raw_printer_windows.dart` documents: `win32` exposes
/// `GetLastError()` over a lazily-initialised `final`, so the FIRST call
/// resolves the symbol — work that **clears the error it is about to read**.
/// It cost a real diagnosis here too: probing this fix, a failed open on COM1
/// reported `error 0` instead of the true code, purely because that was the
/// process's first `GetLastError`. Binding it directly puts the lookup
/// somewhere it cannot eat the answer.
final int Function() _getLastError = DynamicLibrary.open('kernel32.dll')
    .lookupFunction<Uint32 Function(), int Function()>(
  'GetLastError',
  isLeaf: true,
);

/// A device write failed. [message] is written to be shown to an operator.
class WindowsDeviceException implements Exception {
  const WindowsDeviceException(this.message, [this.errorCode]);

  final String message;
  final int? errorCode;

  @override
  String toString() => message;
}

/// The Win32 device path for a port name.
///
/// Always the `\\.\` form. The bare `COM1` is resolved relative to the working
/// directory before it is treated as a device, and it is the only form COM10+
/// and LPT accept in any case.
String windowsDevicePath(String port) => r'\\.' '\\${port.trim().toUpperCase()}';

/// Opens [devicePath], writes [bytes], closes it.
///
/// Throws [WindowsDeviceException] carrying the Win32 code on any failure. The
/// caller decides whether an operator sees it — the display's test button does,
/// a sale in progress does not.
void writeToWindowsDevice({
  required String devicePath,
  required Uint8List bytes,
}) {
  if (!kWindowsDeviceWriteSupported) {
    throw const WindowsDeviceException(
      'Writing to a COM or LPT device is only supported on Windows.',
    );
  }

  // Resolve the error binding BEFORE the call that might fail, so the lookup
  // cannot clear the error it is meant to report. See [_getLastError].
  _getLastError();

  final path = devicePath.toNativeUtf16();
  final buffer = calloc<Uint8>(bytes.length);
  final written = calloc<Uint32>();
  var handle = INVALID_HANDLE_VALUE;

  try {
    handle = CreateFile(
      path,
      GENERIC_WRITE,
      0, // no sharing: a port held by another program must fail loudly here
      nullptr,
      OPEN_EXISTING, // a device is never "created"
      FILE_ATTRIBUTE_NORMAL,
      NULL,
    );
    if (handle == INVALID_HANDLE_VALUE) {
      final code = _getLastError();
      throw WindowsDeviceException(_openMessage(devicePath, code), code);
    }

    buffer.asTypedList(bytes.length).setAll(0, bytes);
    final ok = WriteFile(handle, buffer, bytes.length, written, nullptr);
    if (ok == 0) {
      final code = _getLastError();
      throw WindowsDeviceException(
        'Opened $devicePath but could not write to it (Windows error $code).',
        code,
      );
    }
    if (written.value != bytes.length) {
      throw WindowsDeviceException(
        'Only ${written.value} of ${bytes.length} bytes reached $devicePath.',
      );
    }
  } finally {
    if (handle != INVALID_HANDLE_VALUE) CloseHandle(handle);
    calloc.free(path);
    calloc.free(buffer);
    calloc.free(written);
  }
}

/// Turns a Win32 open failure into a sentence that names the fix.
///
/// The three codes below are the ones an operator actually hits; anything else
/// keeps its number so it can be looked up rather than guessed at.
String _openMessage(String devicePath, int code) => switch (code) {
      ERROR_FILE_NOT_FOUND => // 2
        '$devicePath does not exist on this machine. Check the port in '
            'Device Manager.',
      ERROR_ACCESS_DENIED => // 5
        '$devicePath is already open in another program. Close whatever is '
            'holding it (a terminal, another POS, a printer driver).',
      ERROR_BAD_PATHNAME => // 161
        '$devicePath is not a valid device name.',
      _ => 'Could not open $devicePath (Windows error $code).',
    };
