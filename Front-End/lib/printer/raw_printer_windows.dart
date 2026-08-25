/// Sends bytes to a Windows print queue **verbatim**, with no driver rendering
/// in between.
///
/// ## Why this file exists
///
/// The whole print pipeline goes through `package:printing`, which is a PDF
/// pipeline: you hand it a rendered document and the driver rasterises it. That
/// is right for receipts and wrong for the two things a thermal printer is also
/// asked to do — a **cash-drawer kick** and any other ESC/POS control code.
/// Those are not a document; they are five bytes the printer must receive
/// unmodified. Pushed through `directPrintPdf` they would either be rasterised
/// into an image of the characters or dropped, which is exactly why
/// `Print.CashDrawer.*` has existed as configuration for months with nothing
/// behind it (handoff.md ⭐8).
///
/// The escape hatch Windows provides for this is the spooler's **RAW** datatype:
/// `OpenPrinter` → `StartDocPrinter` with `DOC_INFO_1.pDatatype = "RAW"` →
/// `StartPagePrinter` → `WritePrinter` → close everything in reverse. Bytes
/// written this way reach the device untouched, which is how every Windows POS
/// pops a drawer wired into the printer's RJ11 port.
///
/// ## Platform
///
/// Windows only, by construction — [kRawWindowsPrintingSupported] gates it, and
/// the `package:win32` bindings resolve `winspool.drv` lazily, so nothing here
/// is touched on Android. The network and serial drawer transports in
/// `cash_drawer_service.dart` are what a tablet uses instead.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// True where [sendRawToWindowsPrinter] can run at all.
final bool kRawWindowsPrintingSupported = Platform.isWindows;

/// Windows' per-thread last-error, bound here rather than taken from
/// `package:win32`.
///
/// 🚨 Not a stylistic choice. `win32` exposes `GetLastError()` as a wrapper over
/// a lazily-initialised `final`, so the FIRST call resolves the symbol — real
/// work that **clears the very error it is about to read**. A missing printer
/// reported `(error 0)` instead of 1801 (`ERROR_INVALID_PRINTER_NAME`), and
/// only on the first failure of the process, which is the worst kind of bug to
/// meet on a customer's till. Resolving this binding *before* the spooler call
/// (see [sendRawToWindowsPrinter]) puts the lookup where it can do no harm.
final int Function() _getLastError = DynamicLibrary.open('kernel32.dll')
    .lookupFunction<Uint32 Function(), int Function()>(
  'GetLastError',
  isLeaf: true,
);

/// A raw spooler write failed. [message] is written to be shown to an operator.
class RawPrintException implements Exception {
  final String message;
  const RawPrintException(this.message);
  @override
  String toString() => message;
}

/// Writes [bytes] to the Windows print queue named [printerName] as a RAW job.
///
/// Throws [RawPrintException] with the Win32 error code on any failure — the
/// caller (the drawer service) turns that into a message on screen rather than
/// letting a silent no-op look like working hardware.
void sendRawToWindowsPrinter({
  required String printerName,
  required Uint8List bytes,
  String jobName = 'POS control',
}) {
  if (!kRawWindowsPrintingSupported) {
    throw const RawPrintException(
      'Raw printing is only available on Windows.',
    );
  }
  if (printerName.trim().isEmpty) {
    throw const RawPrintException('No printer is selected for this station.');
  }
  if (bytes.isEmpty) {
    throw const RawPrintException('Nothing to send — the command is empty.');
  }

  final namePtr = printerName.toNativeUtf16();
  final handlePtr = calloc<IntPtr>();
  final docInfo = calloc<DOC_INFO_1>();
  final docNamePtr = jobName.toNativeUtf16();
  final dataTypePtr = 'RAW'.toNativeUtf16();
  final buffer = calloc<Uint8>(bytes.length);
  final written = calloc<Uint32>();

  // Resolve the last-error binding BEFORE the first spooler call: reading the
  // lazy final is what performs the symbol lookup, and doing that between the
  // failing call and the read is exactly what loses the error code.
  final lastError = _getLastError;

  int handle = 0;
  var docOpen = false;
  var pageOpen = false;
  try {
    // Every call reads the error into a local on the very next line, before
    // anything else runs. Windows' last-error survives only until the next
    // thing that sets it, so the read has to be adjacent — nothing between the
    // call and the read, and never inside the exception message.
    final opened = OpenPrinter(namePtr, handlePtr, nullptr);
    final openError = lastError();
    if (opened == 0) {
      throw RawPrintException(
        'Windows could not open the printer "$printerName" '
        '(error $openError).',
      );
    }
    handle = handlePtr.value;

    docInfo.ref
      ..pDocName = docNamePtr
      ..pOutputFile = nullptr
      ..pDatatype = dataTypePtr;

    final job = StartDocPrinter(handle, 1, docInfo);
    final jobError = lastError();
    if (job == 0) {
      throw RawPrintException(
        'The printer "$printerName" refused a raw job (error $jobError). '
        'Its driver may not allow RAW pass-through.',
      );
    }
    docOpen = true;

    final pageStarted = StartPagePrinter(handle);
    final pageError = lastError();
    if (pageStarted == 0) {
      throw RawPrintException('StartPagePrinter failed (error $pageError).');
    }
    pageOpen = true;

    buffer.asTypedList(bytes.length).setAll(0, bytes);
    final wrote = WritePrinter(handle, buffer, bytes.length, written);
    final writeError = lastError();
    if (wrote == 0) {
      throw RawPrintException('WritePrinter failed (error $writeError).');
    }
    if (written.value != bytes.length) {
      throw RawPrintException(
        'The printer accepted only ${written.value} of ${bytes.length} bytes.',
      );
    }
  } finally {
    // Unwind in the exact reverse order, and only what was actually opened —
    // calling EndPagePrinter on a handle whose StartPagePrinter failed leaves
    // the spooler with a stuck job.
    if (pageOpen) EndPagePrinter(handle);
    if (docOpen) EndDocPrinter(handle);
    if (handle != 0) ClosePrinter(handle);
    calloc.free(namePtr);
    calloc.free(handlePtr);
    calloc.free(docInfo);
    calloc.free(docNamePtr);
    calloc.free(dataTypePtr);
    calloc.free(buffer);
    calloc.free(written);
  }
}
