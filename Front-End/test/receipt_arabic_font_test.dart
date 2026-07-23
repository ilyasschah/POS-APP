// Pins Arabic glyph coverage for printed receipts.
//
// Why this file exists: the per-printer `{Role}.RightToLeft` setting already
// flips the receipt LAYOUT, so an Arabic receipt printed with a Latin-only font
// comes out shaped perfectly with every Arabic word rendered as an empty box.
// Nothing else in this repo can see that — it is not a compile error, not a
// lint, and the PDF still "renders". It is only visible on paper.
//
// So this asserts both halves of the fix directly: the bundled Noto Naskh asset
// really ships and covers Arabic, and the fallback wiring is what puts those
// glyphs into the file.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show TtfParser;
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_app/printer/pdf_fonts.dart';

/// A few codepoints that must render on a Moroccan receipt.
const _arabicSamples = <String, int>{
  'ALEF': 0x0627, // ا
  'BEH': 0x0628, // ب
  'MEEM': 0x0645, // م
  'HEH': 0x0647, // ه
  'ARABIC COMMA': 0x060C, // ،
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ByteData> load(String file) => rootBundle.load('assets/fonts/$file');

  test('the Arabic font asset is bundled and parses', () async {
    final f = TtfParser(await load('NotoNaskhArabic-Regular.ttf'));
    expect(f.fontName, contains('Noto'));
  });

  test('the bundled Arabic font covers Arabic codepoints', () async {
    for (final bold in [false, true]) {
      final name =
          bold ? 'NotoNaskhArabic-Bold.ttf' : 'NotoNaskhArabic-Regular.ttf';
      final map = TtfParser(await load(name)).charToGlyphIndexMap;
      for (final entry in _arabicSamples.entries) {
        expect(
          map[entry.value] ?? 0,
          isNonZero,
          reason:
              '${entry.key} (U+${entry.value.toRadixString(16).toUpperCase()}) '
              'missing from $name',
        );
      }
    }
  });

  test('the fallback is load-bearing — without it no Arabic is embedded',
      () async {
    final arabic = await PdfFonts.arabic();

    Future<int> renderSize({required bool withFallback}) async {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          build: (_) => pw.Text(
            'مرحبا بكم في المتجر',
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontFallback: withFallback ? [arabic] : const [],
              fontSize: 10,
            ),
          ),
        ),
      );
      return (await doc.save()).length;
    }

    final withFallback = await renderSize(withFallback: true);
    final without = await renderSize(withFallback: false);

    // Courier is a PDF standard-14 face: Latin-1 only, and never embedded. With
    // no fallback there is literally nothing to draw the Arabic with, so the
    // file stays tiny. This is the whole bug, measured.
    expect(
      withFallback,
      greaterThan(without),
      reason: 'the Arabic subset was not embedded — fallback is not wired',
    );
  });
  test('the Latin face is bundled too — no PdfGoogleFonts download at print time',
      () async {
    final map = TtfParser(await load('NotoSans-Regular.ttf')).charToGlyphIndexMap;
    // Latin + the Moroccan dirham sign a receipt actually prints.
    for (final rune in <int>[0x41, 0x61, 0x30, 0x20AC]) {
      expect(map[rune] ?? 0, isNonZero,
          reason: 'U+${rune.toRadixString(16).toUpperCase()} missing from NotoSans');
    }
  });

  test('PdfFonts caches a parsed face rather than re-reading it', () async {
    final a = await PdfFonts.arabic();
    final b = await PdfFonts.arabic();
    expect(identical(a, b), isTrue, reason: 'font was parsed twice');
  });
}