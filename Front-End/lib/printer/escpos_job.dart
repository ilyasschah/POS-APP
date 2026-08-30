/// Turns a finished PDF document into the bytes a network thermal printer
/// prints, and sends them.
///
/// This is the join between the two halves that already existed: the receipt
/// layout (`receipt_printer_service.dart`, which produces a `pw.Document`) and
/// the raw TCP socket (`network_printer.dart`, proven by the cash-drawer kick).
///
/// 🚨 **The page is rasterised, not re-described.** See the note at the top of
/// `escpos_raster.dart`: emitting ESC/POS text commands would mean rebuilding
/// the logo, the barcode, the margins, the right-to-left mirroring and the
/// Arabic shaping against a printer's built-in font that has no Arabic in it.
/// Rasterising prints the document that was already laid out, exactly as the
/// PDF shows it.
///
/// ⚠️ **`Printing.raster` needs a Flutter engine.** It goes through the plugin's
/// pdfium binding, so it cannot run in a plain `dart run` or an unmocked unit
/// test. Everything decidable without it — the dot width, the band packing, the
/// job envelope, the socket — is factored into `escpos_raster.dart` and
/// `network_printer.dart`, which are tested. What is left here is the glue, and
/// it is deliberately thin.
library;

import 'dart:typed_data';

import 'package:printing/printing.dart';

import 'package:pos_app/printer/escpos_raster.dart';
import 'package:pos_app/printer/network_printer.dart';

/// Renders [pdfBytes] to ESC/POS raster commands at the head's dot width.
///
/// [dots] is the printable width in dots — [dotsForPaperSize] gives it from the
/// paper-size setting. The DPI handed to `Printing.raster` is derived from it
/// rather than fixed, so the rasteriser produces the exact pixel width the head
/// wants and nothing is resampled afterwards: a receipt scaled twice loses the
/// hairlines in a barcode, and a barcode that will not scan is worse than no
/// barcode.
Future<Uint8List> rasteriseForEscPos({
  required Uint8List pdfBytes,
  required int dots,
  int threshold = kDefaultThreshold,
  int bandRows = kDefaultBandRows,
}) async {
  final out = BytesBuilder(copy: false);
  var pages = 0;

  await for (final page in Printing.raster(pdfBytes, dpi: _dpiFor(dots))) {
    pages++;
    out.add(escPosRaster(
      rgba: page.pixels,
      width: page.width,
      height: page.height,
      threshold: threshold,
      bandRows: bandRows,
    ));
  }

  if (pages == 0) {
    throw const NetworkPrinterException(
      'The document could not be rendered for the printer.',
    );
  }
  return out.takeBytes();
}

/// The DPI that makes an 80 mm page rasterise to exactly [dots] pixels wide.
///
/// A roll page is `PdfPageFormat.roll80`, 80 mm across; the printable head is
/// narrower, and [dotsForPaperSize] already carries that. Working back from the
/// dot count keeps the two in step: change the head width and the render
/// follows, with no second constant to forget.
double _dpiFor(int dots) {
  final widthInches = (dots == kDots58mm ? 58.0 : 80.0) / 25.4;
  return dots / widthInches;
}

/// Renders [pdfBytes] and sends it to the printer at [host]:[port].
///
/// Throws [NetworkPrinterException] on anything that stops paper coming out.
/// The caller decides who hears about it — the test button says it out loud,
/// a sale in progress does not.
Future<void> printPdfToNetworkPrinter({
  required Uint8List pdfBytes,
  required String host,
  int port = kDefaultPrinterTcpPort,
  String? paperSize,
  int copies = 1,
  bool cut = true,
  bool openDrawer = false,
  List<int>? drawerCommand,
}) async {
  final problem = printerHostProblem(host);
  if (problem != null) throw NetworkPrinterException(problem);

  final raster = await rasteriseForEscPos(
    pdfBytes: pdfBytes,
    dots: dotsForPaperSize(paperSize),
  );

  // Rasterise once, send N times. The expensive half is the render; a second
  // copy is the same bytes down the same socket.
  final job = escPosDocument(
    raster: raster,
    cut: cut,
    openDrawer: openDrawer,
    drawerCommand: drawerCommand,
  );

  for (var i = 0; i < copies.clamp(1, 10); i++) {
    await sendToNetworkPrinter(host: host, port: port, bytes: job);
  }
}

/// A one-page "the wiring works" slip, for the Test button.
///
/// Deliberately not a receipt: a test print exists to prove the address, the
/// port and the paper width, so it prints a ruler the full width of the head.
/// A short line cannot show that the paper size is wrong.
Uint8List escPosTestPage({String? paperSize}) {
  final dots = dotsForPaperSize(paperSize);
  // A full-width rule, then alternating bands: if the paper size is set to
  // 80 mm on a 58 mm printer the rule wraps and the bands shear, which is
  // visible at a glance and needs no measuring.
  final raster = escPosRaster(
    rgba: _testPagePixels(dots),
    width: dots,
    height: 64,
  );
  return escPosDocument(raster: raster);
}

Uint8List _testPagePixels(int dots) {
  final px = Uint8List(dots * 64 * 4);
  for (var y = 0; y < 64; y++) {
    for (var x = 0; x < dots; x++) {
      final i = (y * dots + x) * 4;
      // Top and bottom rules run the full width; the middle is a comb whose
      // teeth are 16 dots apart, so a wrapped row is obvious.
      final ink = y < 4 || y >= 60 || (y >= 24 && y < 40 && (x ~/ 16).isEven);
      final v = ink ? 0 : 255;
      px[i] = v;
      px[i + 1] = v;
      px[i + 2] = v;
      px[i + 3] = 255;
    }
  }
  return px;
}
