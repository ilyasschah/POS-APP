import 'dart:io';

/// What the `printing` package can actually do on the current platform.
///
/// ## Why this is a file and not an inline `Platform.isWindows`
///
/// The POS treats "pick a printer, then print to it silently" as the normal
/// path. That is a **desktop-only** capability:
///
/// * `Printing.listPrinters()` has no Android implementation at all — the call
///   fails with a `MissingPluginException`, which `_dispatch` and the two
///   Printer Settings tabs each swallowed in a bare `catch (_)`. The result was
///   an empty printer dropdown that reads as *"no printers installed"* rather
///   than *"this platform cannot enumerate printers"*, while the
///   `<Role>.PrinterName` a Windows terminal had already saved sat in the field
///   above it looking configured.
/// * `Printing.directPrintPdf()` likewise: the Android plugin reports
///   `directPrint: false` (`PrintingJob.java`), so every print — including
///   autoprint at checkout — fell through to `Printing.layoutPdf()`, which opens
///   the **Android system print dialog**. A cashier closing a sale does not want
///   a modal asking which printer to use, which is the concrete meaning of
///   "printers are not working at all" on the tablets.
///
/// Capability-gate on these instead of guessing, exactly as
/// `scale_service.dart` does with `kScaleSupported`.
abstract final class PrinterPlatform {
  /// True where `Printing.listPrinters()` returns a real list.
  static final bool canListSystemPrinters =
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// True where a job can be sent to a named queue without a dialog.
  /// Same set today; kept separate because they are different plugin calls and
  /// a future platform could gain one without the other.
  static final bool canPrintSilently = canListSystemPrinters;

  /// True where the only available route is the OS print dialog.
  static bool get requiresSystemPrintDialog => !canPrintSilently;
}
