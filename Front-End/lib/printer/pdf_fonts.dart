import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Fonts for generated PDFs (receipts, kitchen tickets, invoices, Z-reports).
///
/// Everything is loaded from `assets/fonts/`, deliberately NOT from
/// `PdfGoogleFonts`: that helper downloads the face over the network on first
/// use, so on an offline-first POS the very first print after a fresh install
/// could fail to render — precisely when a till cannot wait. Bundling costs
/// ~1.1 MB in the installer and removes the failure mode entirely.
///
/// Parsed faces are cached per file: each TTF is 150–430 KB and re-parsing one
/// on every print is pure waste.
class PdfFonts {
  PdfFonts._();

  static final Map<String, pw.Font> _cache = {};

  static Future<pw.Font> bundled(String file) async =>
      _cache[file] ??= pw.Font.ttf(await rootBundle.load('assets/fonts/$file'));

  /// Default Latin face — replaces `PdfGoogleFonts.notoSans*`.
  static Future<pw.Font> latin({bool bold = false}) =>
      bundled(bold ? 'NotoSans-Bold.ttf' : 'NotoSans-Regular.ttf');

  /// Arabic face, attached as a `fontFallback` rather than as the base font.
  ///
  /// NONE of the Latin faces carry Arabic glyphs — the PDF standard-14 faces
  /// (Courier/Times) are Latin-1 and Noto Sans is the Latin subset. Because the
  /// per-printer `{Role}.RightToLeft` flag already flips the LAYOUT, an Arabic
  /// receipt printed without this comes out shaped perfectly with every word
  /// rendered as an empty box — a failure only visible on paper.
  ///
  /// Used as a fallback (not the base) so the operator's chosen face still
  /// drives Latin text and only the glyphs it cannot draw come from Noto Naskh.
  /// A mixed receipt — Latin company name, Arabic item names, `12,50 MAD` —
  /// then needs no language detection at all.
  static Future<pw.Font> arabic({bool bold = false}) => bundled(
        bold ? 'NotoNaskhArabic-Bold.ttf' : 'NotoNaskhArabic-Regular.ttf',
      );
}
