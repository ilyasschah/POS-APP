// The bytes that decide whether a receipt prints or comes out as noise.
//
// Every assertion here is against the ESC/POS spec rather than against what the
// code happens to emit, because there is no printer in CI to correct a wrong
// guess — and a wrong guess in the header (bytes-per-row swapped for pixels,
// rows counted per document instead of per band) prints a diagonal smear that
// looks like broken hardware.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/printer/escpos_raster.dart';

/// An RGBA buffer from a callback returning true where a pixel is BLACK.
Uint8List _rgba(int w, int h, bool Function(int x, int y) black) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final v = black(x, y) ? 0 : 255;
      out[i] = v;
      out[i + 1] = v;
      out[i + 2] = v;
      out[i + 3] = 255;
    }
  }
  return out;
}

void main() {
  group('the GS v 0 header', () {
    test('is bytes-per-row and rows, little-endian — not pixels', () {
      // 16 px wide is TWO bytes per row. Sending 16 here would make the printer
      // expect eight times the data and eat the rest of the receipt.
      final bytes = escPosRaster(
        rgba: _rgba(16, 3, (x, y) => false),
        width: 16,
        height: 3,
      );
      expect(bytes.sublist(0, 4), [0x1D, 0x76, 0x30, 0x00]);
      expect(bytes[4], 2, reason: 'xL = bytes per row');
      expect(bytes[5], 0, reason: 'xH');
      expect(bytes[6], 3, reason: 'yL = rows');
      expect(bytes[7], 0, reason: 'yH');
      expect(bytes.length, 8 + 2 * 3);
    });

    test('a width that is not a multiple of 8 rounds the row UP', () {
      // 578 dots needs 73 bytes, not 72: truncating drops the last two dots of
      // every row, which shaves a column off the right edge of the receipt.
      final bytes = escPosRaster(
        rgba: _rgba(578, 1, (x, y) => false),
        width: 578,
        height: 1,
      );
      expect(bytes[4] | (bytes[5] << 8), 73);
    });

    test('a wide row carries its high byte', () {
      // 80mm at 203dpi is 576 dots = 72 bytes; a 4000px image is 500 bytes per
      // row, which does not fit in xL alone.
      final bytes = escPosRaster(
        rgba: _rgba(4000, 1, (x, y) => false),
        width: 4000,
        height: 1,
      );
      expect(bytes[4] | (bytes[5] << 8), 500);
      expect(bytes[5], greaterThan(0), reason: 'xH must be used');
    });
  });

  group('pixel packing', () {
    test('🚨 1 means BLACK — the opposite of every image format', () {
      final bytes = escPosRaster(
        rgba: _rgba(8, 1, (x, y) => x == 0),
        width: 8,
        height: 1,
      );
      expect(bytes[8], 0x80, reason: 'leftmost pixel is the HIGH bit');
    });

    test('bits run left to right, MSB first', () {
      final bytes = escPosRaster(
        rgba: _rgba(8, 1, (x, y) => x == 7),
        width: 8,
        height: 1,
      );
      expect(bytes[8], 0x01, reason: 'rightmost pixel is the LOW bit');
    });

    test('white paper emits zero bits, not blank space', () {
      final bytes = escPosRaster(
        rgba: _rgba(8, 2, (x, y) => false),
        width: 8,
        height: 2,
      );
      expect(bytes.sublist(8), [0x00, 0x00]);
    });

    test('the row stride is padded, so a row cannot bleed into the next', () {
      // 9 px = 2 bytes per row with 7 bits of padding. A packer that wrote a
      // continuous bit stream would shift every row one pixel further right —
      // the classic diagonal smear.
      final bytes = escPosRaster(
        rgba: _rgba(9, 2, (x, y) => x == 0),
        width: 9,
        height: 2,
      );
      final data = bytes.sublist(8);
      expect(data, [0x80, 0x00, 0x80, 0x00]);
    });
  });

  group('luminance', () {
    test('mid grey prints, because anti-aliased text is mid grey', () {
      // Threshold 200, not 128: a glyph edge sits around 55-60% grey and
      // dropping it thins strokes until Arabic diacritics disappear.
      final grey = Uint8List.fromList([150, 150, 150, 255]);
      final bytes = escPosRaster(rgba: grey, width: 1, height: 1);
      expect(bytes[8], 0x80, reason: '150 is below the 200 threshold');
    });

    test('near-white does not print', () {
      final bytes = escPosRaster(
        rgba: Uint8List.fromList([250, 250, 250, 255]),
        width: 1,
        height: 1,
      );
      expect(bytes[8], 0x00);
    });

    test('weights green most — a flat average smears a coloured logo', () {
      // Rec. 601 luma: blue 29, red 76, green 150. A flat (r+g+b)/3 puts all
      // three at 85, so a two-colour logo comes out as one solid blob.
      // Threshold 100 separates them; it could not if the weights were flat.
      bool prints(int r, int g, int b) =>
          escPosRaster(
            rgba: Uint8List.fromList([r, g, b, 255]),
            width: 1,
            height: 1,
            threshold: 100,
          )[8] ==
          0x80;

      expect(prints(0, 0, 255), isTrue, reason: 'blue reads dark (luma 29)');
      expect(prints(255, 0, 0), isTrue, reason: 'red reads dark (luma 76)');
      expect(prints(0, 255, 0), isFalse, reason: 'green reads light (luma 150)');
    });

    test('a fully transparent pixel is paper, not ink', () {
      // A composited or cropped image would otherwise print its margin solid
      // black — several metres of it.
      final bytes = escPosRaster(
        rgba: Uint8List.fromList([0, 0, 0, 0]),
        width: 1,
        height: 1,
      );
      expect(bytes[8], 0x00);
    });

    test('the threshold is tunable', () {
      final grey = Uint8List.fromList([150, 150, 150, 255]);
      expect(escPosRaster(rgba: grey, width: 1, height: 1, threshold: 100)[8],
          0x00);
    });
  });

  group('banding', () {
    test('🚨 a tall image is split, or it overruns the printer buffer', () {
      // One 300-row band is ~21KB on an 80mm head. Cheap printers have a few
      // KB of input buffer and print garbage from the overrun onward — which
      // reads as a corrupt receipt, not as a flow-control problem.
      final bytes = escPosRaster(
        rgba: _rgba(8, 300, (x, y) => false),
        width: 8,
        height: 300,
        bandRows: 128,
      );
      // 128 + 128 + 44
      var offset = 0;
      final rowsSeen = <int>[];
      while (offset < bytes.length) {
        expect(bytes.sublist(offset, offset + 4), [0x1D, 0x76, 0x30, 0x00]);
        final bpr = bytes[offset + 4] | (bytes[offset + 5] << 8);
        final rows = bytes[offset + 6] | (bytes[offset + 7] << 8);
        rowsSeen.add(rows);
        offset += 8 + bpr * rows;
      }
      expect(rowsSeen, [128, 128, 44]);
      expect(rowsSeen.reduce((a, b) => a + b), 300);
    });

    test('every band carries its own header', () {
      final bytes = escPosRaster(
        rgba: _rgba(8, 20, (x, y) => false),
        width: 8,
        height: 20,
        bandRows: 10,
      );
      var headers = 0;
      for (var i = 0; i + 3 < bytes.length; i++) {
        if (bytes[i] == 0x1D &&
            bytes[i + 1] == 0x76 &&
            bytes[i + 2] == 0x30 &&
            bytes[i + 3] == 0x00) {
          headers++;
        }
      }
      expect(headers, 2);
    });

    test('an image shorter than one band is a single command', () {
      final bytes = escPosRaster(
        rgba: _rgba(8, 5, (x, y) => false),
        width: 8,
        height: 5,
        bandRows: 128,
      );
      expect(bytes.length, 8 + 5);
    });
  });

  group('guards', () {
    test('an empty image produces no bytes, not a malformed command', () {
      expect(escPosRaster(rgba: Uint8List(0), width: 0, height: 0), isEmpty);
    });

    test('a buffer too small for its dimensions is refused, not truncated', () {
      // Printing half an image and stopping mid-row is indistinguishable from a
      // hardware fault. Fail where it can be reported.
      expect(
        () => escPosRaster(rgba: Uint8List(10), width: 100, height: 100),
        throwsArgumentError,
      );
    });
  });

  group('the whole job', () {
    final raster = escPosRaster(
      rgba: _rgba(8, 1, (x, y) => true),
      width: 8,
      height: 1,
    );

    test('starts with ESC @, so the last job cannot leak into this one', () {
      final job = escPosDocument(raster: raster);
      expect(job.sublist(0, 2), escPosInit);
    });

    test('feeds before cutting — the cutter sits above the head', () {
      // Without the feed the blade slices through the last lines, which on a
      // receipt is the total.
      final job = escPosDocument(raster: raster, feedLines: 4);
      final tail = job.sublist(job.length - 6);
      expect(tail.sublist(0, 3), [0x1B, 0x64, 4], reason: 'ESC d 4');
      expect(tail.sublist(3), escPosPartialCut);
    });

    test('partial cut by default — a full cut drops the receipt', () {
      expect(escPosDocument(raster: raster).sublist(
            escPosDocument(raster: raster).length - 3,
          ),
          escPosPartialCut);
    });

    test('the cut can be turned off for a job that continues', () {
      final job = escPosDocument(raster: raster, cut: false, feedLines: 0);
      expect(job, escPosInit + raster);
    });

    test('the drawer kick rides on the same job, before the cut', () {
      final job = escPosDocument(
        raster: raster,
        openDrawer: true,
        feedLines: 0,
      );
      expect(job.sublist(job.length - 8, job.length - 3), escPosDrawerKick);
    });

    test('a venue can supply its own drawer command', () {
      final job = escPosDocument(
        raster: raster,
        openDrawer: true,
        drawerCommand: const [0x1B, 0x70, 0x01, 0x32, 0x32],
        feedLines: 0,
      );
      expect(job.sublist(job.length - 8, job.length - 3),
          [0x1B, 0x70, 0x01, 0x32, 0x32]);
    });
  });

  group('paper width', () {
    test('80mm prints 576 dots, not the paper width', () {
      // 80mm of paper, 72mm of printable head. Sending more dots than the head
      // has wraps the overflow and shears the receipt.
      expect(dotsForPaperSize('80mm'), 576);
      expect(dotsForPaperSize(null), 576, reason: '80mm is the default');
    });

    test('58mm prints 384 dots', () {
      expect(dotsForPaperSize('58mm'), 384);
      expect(dotsForPaperSize(' 58mm '), 384);
    });
  });

  group('round trip', () {
    // The strongest check available without a printer: encode a known image,
    // then DECODE the command stream the way a printer's firmware does and
    // rebuild the pixels. Every field has to be right for this to close —
    // header order, endianness, row stride, bit order, band boundaries. A
    // hand-checked byte or two cannot cover that.
    List<List<bool>> decode(Uint8List job, int width) {
      final rows = <List<bool>>[];
      var i = 0;
      while (i < job.length) {
        expect(job.sublist(i, i + 4), [0x1D, 0x76, 0x30, 0x00],
            reason: 'a band must start with GS v 0 at byte $i');
        final bytesPerRow = job[i + 4] | (job[i + 5] << 8);
        final bandRows = job[i + 6] | (job[i + 7] << 8);
        i += 8;
        for (var y = 0; y < bandRows; y++) {
          final row = <bool>[];
          for (var x = 0; x < width; x++) {
            final byte = job[i + (x >> 3)];
            row.add((byte & (0x80 >> (x & 7))) != 0);
          }
          rows.add(row);
          i += bytesPerRow;
        }
      }
      return rows;
    }

    test('an arbitrary pattern survives encode -> decode intact', () {
      // Deliberately awkward: a width that is not a byte multiple, a height
      // that straddles three bands, and a pattern with no symmetry to hide a
      // transposition behind.
      const w = 37;
      const h = 70;
      bool black(int x, int y) => ((x * 7 + y * 13) % 11) < 4;

      final job = escPosRaster(
        rgba: _rgba(w, h, black),
        width: w,
        height: h,
        bandRows: 32,
      );
      final decoded = decode(job, w);

      expect(decoded.length, h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          expect(decoded[y][x], black(x, y),
              reason: 'pixel ($x, $y) came back wrong');
        }
      }
    });

    test('a band boundary does not shift the image', () {
      // The failure this catches is an off-by-one in the band loop: the image
      // reassembles with a seam, which on paper is a receipt that jumps
      // sideways a third of the way down.
      const w = 16;
      const h = 9;
      bool black(int x, int y) => x == y; // a diagonal, so any shift shows
      final job = escPosRaster(
        rgba: _rgba(w, h, black),
        width: w,
        height: h,
        bandRows: 4, // 4 + 4 + 1
      );
      final decoded = decode(job, w);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          expect(decoded[y][x], black(x, y), reason: 'seam at row $y');
        }
      }
    });
  });
}
