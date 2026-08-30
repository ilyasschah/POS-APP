/// Composes what a 2-line pole display shows, and the bytes that say it.
///
/// Deliberately free of Flutter and of any plugin: the layout decisions here
/// are the half worth testing and the half worth driving from a command-line
/// probe against real hardware (`tool/probe_display.dart`). The Windows plumbing
/// lives in `windows_device_write.dart`, the settings and cart wiring in
/// `customer_display_service.dart`.
library;

import 'dart:typed_data';

/// What the display's firmware can actually render.
///
/// 🚨 **This describes the HARDWARE, not the app's language.** A pole display
/// carries one byte per character and decodes those bytes with whatever
/// codepage its firmware was built with. Switching the app to Arabic does not
/// give a Latin-only display Arabic glyphs — it only changes which bytes we
/// send it, and a display that cannot decode them shows worse garbage than the
/// `?` it would otherwise have shown.
///
/// So the default stays [ascii], the option that is legible on every display
/// ever made, and an operator with Arabic hardware opts in to [cp1256]. There
/// is no autodetect: nothing in the protocol lets us ask the display what it
/// supports, and guessing wrong is invisible until a customer complains.
enum DisplayCharset {
  /// Plain ASCII. Accented Latin folds (`Café` -> `Cafe`), anything else
  /// becomes `?`. Works on every display; the safe default.
  ascii('ascii'),

  /// Latin-1 / CP1252 — accents survive as themselves on a Western display.
  latin1('latin1'),

  /// Windows-1256, the usual Arabic codepage on VFDs that have one. Arabic is
  /// sent as BASE letters in logical order and the display's firmware joins
  /// them; Latin passes through unchanged, since CP1256 keeps ASCII in place.
  cp1256('cp1256'),

  /// Windows-1256 with each Arabic run reversed before sending, for a display
  /// that has the glyphs but does no bidi of its own and would otherwise print
  /// the word backwards. Try [cp1256] first; if the text reads right-to-left
  /// backwards, this is the one.
  cp1256Visual('cp1256-visual');

  const DisplayCharset(this.settingValue);

  /// Stored in settings. Stable — do not translate or rename.
  final String settingValue;

  static DisplayCharset fromSetting(String? value) =>
      DisplayCharset.values.firstWhere(
        (c) => c.settingValue == value?.trim().toLowerCase(),
        orElse: () => DisplayCharset.ascii,
      );
}

/// Bytes for one write: form feed, line 1, CR, line 2, CR.
///
/// `0x0C` clears the display first — without it a shorter line leaves the tail
/// of the previous one on screen, so `Sandwich` after `Sandwich Poulet` reads
/// as `SandwichPoulet`.
Uint8List poleDisplayFrame({
  required String line1,
  required String line2,
  required int width,
  DisplayCharset charset = DisplayCharset.ascii,
}) {
  final lines =
      poleDisplayLines(line1: line1, line2: line2, width: width, charset: charset);
  return Uint8List.fromList([
    0x0C,
    ...encodeForDisplay(lines.line1, charset),
    0x0D,
    ...encodeForDisplay(lines.line2, charset),
    0x0D,
  ]);
}

/// The two lines as the customer reads them — same composition as
/// [poleDisplayFrame], without the control bytes. For tests and probes.
({String line1, String line2}) poleDisplayLines({
  required String line1,
  required String line2,
  required int width,
  DisplayCharset charset = DisplayCharset.ascii,
}) =>
    (
      line1: padOrTrim(prepareForDisplay(line1, charset), width),
      line2: padOrTrim(prepareForDisplay(line2, charset), width),
    );

/// Rewrites text into the characters [charset] can carry, before padding.
///
/// Folding happens HERE rather than at encode time so the padding counts the
/// characters that will actually be shown: `Café` folded to `Cafe` is four
/// columns either way, but a `?` substitution can change the length when a
/// rune folds to more or fewer characters.
String prepareForDisplay(String raw, DisplayCharset charset) =>
    switch (charset) {
      DisplayCharset.ascii => foldToDisplayText(raw),
      DisplayCharset.latin1 => _keepWhat(raw, (r) => r <= 0xFF),
      DisplayCharset.cp1256 => _keepWhat(raw, _cp1256.containsKey),
      DisplayCharset.cp1256Visual =>
        _reverseArabicRuns(_keepWhat(raw, _cp1256.containsKey)),
    };

/// One byte per character, in [charset]. The string must already have been
/// through [prepareForDisplay].
List<int> encodeForDisplay(String prepared, DisplayCharset charset) {
  final out = <int>[];
  for (final rune in prepared.runes) {
    out.add(switch (charset) {
      DisplayCharset.ascii ||
      DisplayCharset.latin1 =>
        rune <= 0xFF ? rune : 0x3F, // '?'
      DisplayCharset.cp1256 ||
      DisplayCharset.cp1256Visual =>
        _cp1256[rune] ?? 0x3F,
    });
  }
  return out;
}

/// Replaces every rune the charset cannot carry with `?`.
///
/// `?` and not silence: a missing character is a fact the operator needs to
/// see. A dropped one just makes a word look misspelt.
String _keepWhat(String raw, bool Function(int rune) canCarry) {
  final out = StringBuffer();
  for (final rune in raw.runes) {
    if (rune == 0x0A || rune == 0x0D) continue; // control, never displayable
    out.write(canCarry(rune) ? String.fromCharCode(rune) : '?');
  }
  return out.toString();
}

/// Reverses each run of Arabic characters, leaving Latin and digits alone.
///
/// For a display that has Arabic glyphs but no bidi of its own. Digits stay in
/// their written order inside an Arabic run — a reversed price is not a
/// rendering quirk, it is a different number.
String _reverseArabicRuns(String s) {
  bool isArabic(int r) => r >= 0x0600 && r <= 0x06FF;
  final out = <int>[];
  final run = <int>[];
  void flush() {
    out.addAll(run.reversed);
    run.clear();
  }

  for (final rune in s.runes) {
    if (isArabic(rune)) {
      run.add(rune);
    } else {
      flush();
      out.add(rune);
    }
  }
  flush();
  return String.fromCharCodes(out);
}

/// Line 2 of a rung item: what was rung on the left, the running total on the
/// right.
///
/// 🚨 The candidates are tried longest-first and a clause is given up WHOLE.
/// Truncating turned `0.125 kg x 50.00` into `0.125 kg x 50.` — which does not
/// read as a shortened line, it reads as a price of fifty-something. Dropping
/// the `x price` clause leaves `0.125 kg`, which is true and complete.
String lineItemRow({
  required double quantity,
  required double unitPrice,
  required double runningTotal,
  required int width,
  String unitLabel = '',
}) {
  final unit = unitLabel.trim().isEmpty ? '' : ' ${unitLabel.trim()}';
  final qty = formatDisplayQuantity(quantity);
  return leftRight(
    [
      '$qty$unit x ${unitPrice.toStringAsFixed(2)}',
      '$qty$unit',
      qty,
    ],
    runningTotal.toStringAsFixed(2),
    width,
  );
}

/// Packs a left half and [right] onto one line of [width], right-aligning
/// [right].
///
/// [leftCandidates] are tried longest-first; the first that leaves room for
/// [right] plus a space wins. [right] is money and is never shortened while
/// anything else can give — a half-printed total (`25.0`) reads as a real
/// price. Only when [right] alone exceeds the display does it lose characters,
/// and then it keeps its LAST digits: a display too narrow for the amount
/// cannot be honest, and the pennies are what gets checked.
String leftRight(List<String> leftCandidates, String right, int width) {
  if (right.length >= width) return right.substring(right.length - width);
  final room = width - right.length - 1; // at least one space between
  final left = leftCandidates.firstWhere(
    (c) => c.length <= room,
    orElse: () => leftCandidates.last.length > room
        ? leftCandidates.last.substring(0, room)
        : leftCandidates.last,
  );
  return left.padRight(width - right.length) + right;
}

/// `2`, not `2.0`; `0.125`, not `0.13`. A weighed quantity is the figure a
/// customer is most likely to dispute, so it prints as it was rung.
String formatDisplayQuantity(double q) {
  if (q == q.roundToDouble()) return q.toStringAsFixed(0);
  return q
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Folds text into the single byte per character the wire actually carries.
///
/// 🚨 The frame is built from `String.codeUnits`, which are UTF-16. Anything
/// above `0xFF` is silently truncated to its low byte on the way out, so a
/// product called `شاي` did not render as boxes — it rendered as whatever
/// letters those low bytes happen to be. Garbage that reads as a display fault.
///
/// A common accented letter folds to its base form first, so a French menu is
/// legible even on a display shipped with a bare-ASCII codepage; the rest of
/// Latin-1 passes through for a display whose codepage can take it; everything
/// else becomes `?`, which reads as "cannot show this" rather than as broken
/// hardware.
String foldToDisplayText(String raw) {
  final out = StringBuffer();
  for (final rune in raw.runes) {
    if (rune >= 0x20 && rune <= 0x7E) {
      out.writeCharCode(rune);
    } else if (_fold.containsKey(rune)) {
      out.write(_fold[rune]);
    } else if (rune >= 0xA0 && rune <= 0xFF) {
      out.writeCharCode(rune);
    } else {
      out.write('?');
    }
  }
  return out.toString();
}

const Map<int, String> _fold = {
  0xE0: 'a', 0xE1: 'a', 0xE2: 'a', 0xE4: 'a', 0xE7: 'c', // à á â ä ç
  0xE8: 'e', 0xE9: 'e', 0xEA: 'e', 0xEB: 'e', //           è é ê ë
  0xEE: 'i', 0xEF: 'i', 0xF4: 'o', 0xF6: 'o', //           î ï ô ö
  0xF9: 'u', 0xFB: 'u', 0xFC: 'u', //                      ù û ü
  0xC0: 'A', 0xC7: 'C', 0xC8: 'E', 0xC9: 'E', 0xCA: 'E', // À Ç È É Ê
  0xD4: 'O', 0xDB: 'U', //                                 Ô Û
};

/// Pads with spaces or cuts to exactly [len] characters.
String padOrTrim(String s, int len) {
  final padded = s.padRight(len);
  return padded.length > len ? padded.substring(0, len) : padded;
}

/// Windows-1256 (Arabic), Unicode code point -> byte.
///
/// Generated from the codec rather than typed: 256 hand-copied hex pairs is a
/// transcription error waiting to happen, and one wrong byte is one wrong
/// letter on a customer's receipt display. ASCII is left in place by the
/// codepage itself, which is why Latin text needs no special case here.
const Map<int, int> _cp1256 = {
  0x0020: 0x20, 0x0021: 0x21, 0x0022: 0x22, 0x0023: 0x23, 0x0024: 0x24, 0x0025: 0x25,
  0x0026: 0x26, 0x0027: 0x27, 0x0028: 0x28, 0x0029: 0x29, 0x002A: 0x2A, 0x002B: 0x2B,
  0x002C: 0x2C, 0x002D: 0x2D, 0x002E: 0x2E, 0x002F: 0x2F, 0x0030: 0x30, 0x0031: 0x31,
  0x0032: 0x32, 0x0033: 0x33, 0x0034: 0x34, 0x0035: 0x35, 0x0036: 0x36, 0x0037: 0x37,
  0x0038: 0x38, 0x0039: 0x39, 0x003A: 0x3A, 0x003B: 0x3B, 0x003C: 0x3C, 0x003D: 0x3D,
  0x003E: 0x3E, 0x003F: 0x3F, 0x0040: 0x40, 0x0041: 0x41, 0x0042: 0x42, 0x0043: 0x43,
  0x0044: 0x44, 0x0045: 0x45, 0x0046: 0x46, 0x0047: 0x47, 0x0048: 0x48, 0x0049: 0x49,
  0x004A: 0x4A, 0x004B: 0x4B, 0x004C: 0x4C, 0x004D: 0x4D, 0x004E: 0x4E, 0x004F: 0x4F,
  0x0050: 0x50, 0x0051: 0x51, 0x0052: 0x52, 0x0053: 0x53, 0x0054: 0x54, 0x0055: 0x55,
  0x0056: 0x56, 0x0057: 0x57, 0x0058: 0x58, 0x0059: 0x59, 0x005A: 0x5A, 0x005B: 0x5B,
  0x005C: 0x5C, 0x005D: 0x5D, 0x005E: 0x5E, 0x005F: 0x5F, 0x0060: 0x60, 0x0061: 0x61,
  0x0062: 0x62, 0x0063: 0x63, 0x0064: 0x64, 0x0065: 0x65, 0x0066: 0x66, 0x0067: 0x67,
  0x0068: 0x68, 0x0069: 0x69, 0x006A: 0x6A, 0x006B: 0x6B, 0x006C: 0x6C, 0x006D: 0x6D,
  0x006E: 0x6E, 0x006F: 0x6F, 0x0070: 0x70, 0x0071: 0x71, 0x0072: 0x72, 0x0073: 0x73,
  0x0074: 0x74, 0x0075: 0x75, 0x0076: 0x76, 0x0077: 0x77, 0x0078: 0x78, 0x0079: 0x79,
  0x007A: 0x7A, 0x007B: 0x7B, 0x007C: 0x7C, 0x007D: 0x7D, 0x007E: 0x7E, 0x007F: 0x7F,
  0x00A0: 0xA0, 0x00A2: 0xA2, 0x00A3: 0xA3, 0x00A4: 0xA4, 0x00A5: 0xA5, 0x00A6: 0xA6,
  0x00A7: 0xA7, 0x00A8: 0xA8, 0x00A9: 0xA9, 0x00AB: 0xAB, 0x00AC: 0xAC, 0x00AD: 0xAD,
  0x00AE: 0xAE, 0x00AF: 0xAF, 0x00B0: 0xB0, 0x00B1: 0xB1, 0x00B2: 0xB2, 0x00B3: 0xB3,
  0x00B4: 0xB4, 0x00B5: 0xB5, 0x00B6: 0xB6, 0x00B7: 0xB7, 0x00B8: 0xB8, 0x00B9: 0xB9,
  0x00BB: 0xBB, 0x00BC: 0xBC, 0x00BD: 0xBD, 0x00BE: 0xBE, 0x00D7: 0xD7, 0x00E0: 0xE0,
  0x00E2: 0xE2, 0x00E7: 0xE7, 0x00E8: 0xE8, 0x00E9: 0xE9, 0x00EA: 0xEA, 0x00EB: 0xEB,
  0x00EE: 0xEE, 0x00EF: 0xEF, 0x00F4: 0xF4, 0x00F7: 0xF7, 0x00F9: 0xF9, 0x00FB: 0xFB,
  0x00FC: 0xFC, 0x0152: 0x8C, 0x0153: 0x9C, 0x0192: 0x83, 0x02C6: 0x88, 0x060C: 0xA1,
  0x061B: 0xBA, 0x061F: 0xBF, 0x0621: 0xC1, 0x0622: 0xC2, 0x0623: 0xC3, 0x0624: 0xC4,
  0x0625: 0xC5, 0x0626: 0xC6, 0x0627: 0xC7, 0x0628: 0xC8, 0x0629: 0xC9, 0x062A: 0xCA,
  0x062B: 0xCB, 0x062C: 0xCC, 0x062D: 0xCD, 0x062E: 0xCE, 0x062F: 0xCF, 0x0630: 0xD0,
  0x0631: 0xD1, 0x0632: 0xD2, 0x0633: 0xD3, 0x0634: 0xD4, 0x0635: 0xD5, 0x0636: 0xD6,
  0x0637: 0xD8, 0x0638: 0xD9, 0x0639: 0xDA, 0x063A: 0xDB, 0x0640: 0xDC, 0x0641: 0xDD,
  0x0642: 0xDE, 0x0643: 0xDF, 0x0644: 0xE1, 0x0645: 0xE3, 0x0646: 0xE4, 0x0647: 0xE5,
  0x0648: 0xE6, 0x0649: 0xEC, 0x064A: 0xED, 0x064B: 0xF0, 0x064C: 0xF1, 0x064D: 0xF2,
  0x064E: 0xF3, 0x064F: 0xF5, 0x0650: 0xF6, 0x0651: 0xF8, 0x0652: 0xFA, 0x0679: 0x8A,
  0x067E: 0x81, 0x0686: 0x8D, 0x0688: 0x8F, 0x0691: 0x9A, 0x0698: 0x8E, 0x06A9: 0x98,
  0x06AF: 0x90, 0x06BA: 0x9F, 0x06BE: 0xAA, 0x06C1: 0xC0, 0x06D2: 0xFF, 0x200C: 0x9D,
  0x200D: 0x9E, 0x200E: 0xFD, 0x200F: 0xFE, 0x2013: 0x96, 0x2014: 0x97, 0x2018: 0x91,
  0x2019: 0x92, 0x201A: 0x82, 0x201C: 0x93, 0x201D: 0x94, 0x201E: 0x84, 0x2020: 0x86,
  0x2021: 0x87, 0x2022: 0x95, 0x2026: 0x85, 0x2030: 0x89, 0x2039: 0x8B, 0x203A: 0x9B,
  0x20AC: 0x80, 0x2122: 0x99,
};
