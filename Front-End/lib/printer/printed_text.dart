import 'package:pdf/widgets.dart' as pw;

/// Codepoint ranges that need right-to-left rendering: Arabic (incl. supplement
/// and extended-A), the Arabic presentation forms, and Hebrew. Matching one
/// character is enough — a line like `الرقم الضريبي: 27272727` is mixed and must
/// still be laid out right-to-left.
final RegExp _rtlScript = RegExp(
  r'[֐-׿؀-ۿݐ-ݿࢠ-ࣿיִ-﷿ﹰ-﻿]',
);

/// Whether [text] contains any right-to-left script.
bool hasRtlScript(String text) => _rtlScript.hasMatch(text);

/// The direction a text run must be rendered with, which is NOT the same thing
/// as the direction the page is laid out in.
///
/// 🚨 This distinction is the whole file. The `pdf` package applies Arabic
/// SHAPING (contextual letter forms) and the bidi reordering pass **only when a
/// Text's direction is rtl** — see `pdf/src/widgets/text.dart`:
/// `useBidi && _textDirection == TextDirection.rtl ? bidi.logicalToVisual(...)`.
/// Give it Arabic with the default ltr and every letter comes out in its
/// isolated form, in logical order — which on paper reads as disconnected
/// letters running backwards. That is exactly what the first Arabic receipt did
/// (2026-08-16): the glyphs were right, the shaping was absent.
///
/// [layout] is the page's own direction (the operator's per-printer
/// `{Role}.RightToLeft` toggle). It applies to Latin runs and to widget
/// ordering; it must NOT be what decides whether Arabic gets shaped, because
/// the user's item-7 decision is that choosing Arabic does not flip the layout.
/// Shaping is a property of the script; layout is a property of the setting.
/// ⚠️ A run WITHOUT RTL script gets `ltr`, not the page's [layout]. Handing a
/// Latin run the rtl direction sends it through the bidi pass too, which
/// reorders it — on an RTL receipt the company's wrapped Latin address came out
/// with its lines in the wrong order. Direction here is about how a run reads;
/// WHERE it sits on the page is the layout's job (row order and alignment),
/// and that still follows [layout].
pw.TextDirection? scriptDirection(String text, {pw.TextDirection? layout}) =>
    hasRtlScript(text)
        ? pw.TextDirection.rtl
        : (layout == null ? null : pw.TextDirection.ltr);

/// Promotes the Arabic face from `fontFallback` to the BASE font when [text]
/// needs it, demoting the Latin face to the fallback list.
///
/// 🚨 Not cosmetic — with the Arabic face left as a *fallback*, shaped Arabic
/// renders as **repeated wrong glyphs** (verified 2026-08-16 by rendering both
/// ways and looking at the PDFs). The reason: shaping rewrites the text into
/// Arabic presentation forms (U+FE70–FEFF), and the package's per-rune fallback
/// resolution does not map those correctly — while the very same codepoints
/// resolve fine when the Arabic font is the base. Noto Naskh carries all of
/// them (141 of the FE70 block, 631 of FB50), so nothing is missing; only the
/// lookup path differs.
///
/// The Latin face moves to the fallback so a MIXED line — `الرقم الضريبي:
/// 27272727`, or an Arabic label beside a Latin customer name — still draws its
/// Latin characters. Verified rendering correctly as a single widget.
/// ⚠️ The four `fontNormal/fontBold/fontItalic/fontBoldItalic` SLOTS are set,
/// not `font:`. `TextStyle.font` is a getter that picks a slot from the current
/// weight/style, and `copyWith(font: …)` loses to any slot the original style
/// already filled (`fontNormal = fontNormal ?? (… font …)` in its constructor).
/// Passing `font:` alone therefore silently does nothing — which is exactly how
/// the second attempt at this fix still printed boxes.
pw.TextStyle? styleForScript(pw.TextStyle? style, String text) {
  if (style == null || !hasRtlScript(text)) return style;
  final fallback = style.fontFallback;
  if (fallback.isEmpty) return style;
  // fontFallback[0] is the Arabic face already matched to this style's weight
  // by `ReceiptPrinterService.printedTextStyle`.
  final arabic = fallback.first;
  final latin = style.font;
  return style.copyWith(
    fontNormal: arabic,
    fontBold: arabic,
    fontItalic: arabic,
    fontBoldItalic: arabic,
    fontFallback: [
      if (latin != null) latin,
      ...fallback.skip(1),
    ],
  );
}

/// A translated LABEL followed by a data VALUE, as two separate runs.
///
/// 🚨 Use this instead of `'${l.something}: $value'` whenever the value can
/// contain Latin LETTERS. A single run holding Arabic and Latin letters comes
/// out with the Latin **reversed** (`ilyasschah18@gmail.com` →
/// `moc.liamg@81hahcssayli`) — the bidi pass treats the whole run as one
/// right-to-left line. Digits survive it, which is why `الرقم الضريبي: 27272727`
/// looks fine and `أُنشئت بواسطة FUTUR3` does not; that difference is exactly
/// what makes the bug easy to miss.
///
/// Two runs means each picks its own direction and neither touches the other.
/// 🚨 Pass [separator] rather than writing the ':' into [label]. A colon is a
/// NEUTRAL character: at the end of an Arabic label the bidi pass moves it to
/// that run's visual LEFT end, so `'أمين الصندوق:'` prints as `:أمين الصندوق`
/// — the colon detached on the far side of the label instead of introducing
/// the value. As its own run it stays between the two in either script.
pw.Widget printedPair(
  String label,
  String value, {
  pw.TextStyle? style,
  pw.TextDirection? layout,
  String separator = '',
}) =>
    pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        printedText(label, style: style, layout: layout),
        if (separator.isNotEmpty)
          printedText(separator, style: style, layout: layout),
        pw.SizedBox(width: 3),
        pw.Flexible(child: printedText(value, style: style, layout: layout)),
      ],
    );

/// A [pw.Text] that renders its own script correctly whichever way the page is
/// laid out. Use this instead of `pw.Text` on every printed document.
pw.Widget printedText(
  String text, {
  pw.TextStyle? style,
  pw.TextAlign? textAlign,
  pw.TextDirection? layout,
  pw.TextOverflow? overflow,
  int? maxLines,
}) =>
    pw.Text(
      text,
      style: styleForScript(style, text),
      textAlign: textAlign,
      textDirection: scriptDirection(text, layout: layout),
      overflow: overflow,
      maxLines: maxLines,
    );
