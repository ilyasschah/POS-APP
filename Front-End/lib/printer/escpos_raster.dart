/// Turns a rendered page of pixels into the bytes a thermal printer prints.
///
/// ## Why a RASTER and not ESC/POS text commands
///
/// The obvious way to print ESC/POS is to emit text commands — align, bold,
/// feed, a line at a time. It is also the wrong way here, and expensively so:
/// this app already lays out every document as a PDF, with the company logo,
/// the barcode, per-role margins, right-to-left mirroring and — the one that
/// settles it — **Arabic shaping**. `printer/printed_text.dart` exists because
/// getting Arabic onto paper took a fortnight and three separate bugs. A text
/// command stream would have to reproduce all of it against a printer's
/// built-in font, which has no Arabic at all on most units.
///
/// So the page is rendered exactly as it is today, rasterised, and sent as a
/// bitmap. What the customer gets is pixel-for-pixel the PDF — Arabic, logo,
/// barcode and all — on a printer that never sees a font.
///
/// ## The command
///
/// `GS v 0` (`1D 76 30 m xL xH yL yH [data]`) prints a raster bitmap:
/// * `m = 0` — normal size, one dot per bit.
/// * `xL xH` — **bytes** per row, little-endian. Eight pixels to a byte, MSB
///   leftmost.
/// * `yL yH` — rows in this band.
/// * `data` — `bytesPerRow * rows`, **1 = black**. (The opposite of every image
///   format, and the first thing to check when a receipt comes out inverted.)
///
/// 🚨 **A tall image must be split into bands.** `yL yH` is 16-bit, so 65535
/// rows is the format's limit — but the real limit is the printer's input
/// buffer, which on cheap units is a few kilobytes. A single 2000-row band
/// overruns it and prints garbage from the middle of the receipt onward, which
/// looks like a corrupt document rather than a flow-control problem. Bands of
/// [kDefaultBandRows] keep each write small enough to swallow.
library;

import 'dart:typed_data';

/// Dot width of the printable area, by paper size, at 203 dpi — the resolution
/// of essentially every 58/80 mm thermal head.
///
/// Not the paper width: an 80 mm roll prints 72 mm of it. Sending more dots
/// than the head has does not widen the print, it wraps the overflow onto the
/// next line and shears the whole receipt diagonally.
const int kDots80mm = 576;
const int kDots58mm = 384;

/// Rows per `GS v 0` band. Small enough for a modest printer buffer, large
/// enough that the per-band header is noise.
const int kDefaultBandRows = 128;

/// Luminance below which a pixel is printed black.
///
/// 128 is the midpoint and wrong for receipts: anti-aliased text renders its
/// edge pixels around 55–60% grey, and dropping them thins strokes until small
/// Arabic diacritics vanish. Biased light so an edge pixel survives.
const int kDefaultThreshold = 200;

/// Dot width for a paper size string as the settings store it (`'80mm'`).
int dotsForPaperSize(String? paperSize) =>
    paperSize?.trim() == '58mm' ? kDots58mm : kDots80mm;

/// Packs an RGBA image into `GS v 0` raster bands.
///
/// [rgba] is `width * height * 4` bytes, as `PdfRaster.pixels` hands them over.
/// The image is used as-is: scale it to the head's dot width BEFORE calling,
/// because scaling here would mean resampling text twice.
///
/// Returns the command bytes only — no init, no cut. [escPosDocument] wraps it.
Uint8List escPosRaster({
  required Uint8List rgba,
  required int width,
  required int height,
  int threshold = kDefaultThreshold,
  int bandRows = kDefaultBandRows,
}) {
  if (width <= 0 || height <= 0) return Uint8List(0);
  if (rgba.length < width * height * 4) {
    throw ArgumentError(
      'rgba holds ${rgba.length} bytes; $width x $height needs '
      '${width * height * 4}',
    );
  }

  final bytesPerRow = (width + 7) >> 3;
  final out = BytesBuilder(copy: false);

  for (var top = 0; top < height; top += bandRows) {
    final rows = (top + bandRows > height) ? height - top : bandRows;
    final band = Uint8List(bytesPerRow * rows);

    for (var y = 0; y < rows; y++) {
      final srcRow = (top + y) * width * 4;
      final dstRow = y * bytesPerRow;
      for (var x = 0; x < width; x++) {
        final i = srcRow + x * 4;
        final a = rgba[i + 3];
        // Transparent is paper, not black. A PDF page rasterises with an
        // opaque white background, but a caller handing over a cropped or
        // composited image would otherwise print its transparent margin solid.
        if (a == 0) continue;
        // Rec. 601 luma, integer: the eye weights green most, and a flat
        // average turns a red logo into a grey smear.
        final lum =
            (rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) ~/ 1000;
        if (lum < threshold) {
          band[dstRow + (x >> 3)] |= 0x80 >> (x & 7); // 1 = black
        }
      }
    }

    out.add(<int>[
      0x1D, 0x76, 0x30, 0x00, // GS v 0, mode 0
      bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF,
      rows & 0xFF, (rows >> 8) & 0xFF,
    ]);
    out.add(band);
  }

  return out.takeBytes();
}

/// A complete job: initialise, print the raster, feed clear of the head, cut.
///
/// The trailing feed is not padding. The cutter sits ~4 mm above the print
/// head, so cutting immediately slices through the last lines of the receipt —
/// the total, usually.
Uint8List escPosDocument({
  required Uint8List raster,
  bool cut = true,
  int feedLines = 4,
  bool openDrawer = false,
  List<int>? drawerCommand,
}) {
  final out = BytesBuilder(copy: false);
  out.add(escPosInit);
  out.add(raster);
  if (feedLines > 0) out.add([0x1B, 0x64, feedLines.clamp(0, 255)]); // ESC d n
  if (openDrawer) out.add(drawerCommand ?? escPosDrawerKick);
  if (cut) out.add(escPosPartialCut);
  return out.takeBytes();
}

/// `ESC @` — reset. Clears whatever the last job left set (double height, an
/// inverted mode, a stray codepage), which is why every job starts with it.
const List<int> escPosInit = [0x1B, 0x40];

/// `GS V 1` — partial cut, the one that leaves a small tab so the receipt does
/// not fall on the floor. A full cut (`GS V 0`) is a worse default for a till.
const List<int> escPosPartialCut = [0x1D, 0x56, 0x01];

/// `ESC p 0 25 250` — the standard drawer kick on pin 2.
const List<int> escPosDrawerKick = [0x1B, 0x70, 0x00, 0x19, 0xFA];
