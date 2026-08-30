// A pole display carries ONE BYTE per character and decodes it with whatever
// codepage its firmware has. `كرواسون` came out as `???????` because the
// default charset is plain ASCII — correct, but not what an Arabic shop wants.
//
// These pin the encoding per charset. What they cannot pin is whether any given
// display renders the result: nothing in the protocol lets us ask it. That is
// exactly why the charset is a SETTING and defaults to the safe option.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/utils/pole_display_frame.dart';

void main() {
  const croissantAr = 'كرواسون';

  group('DisplayCharset.fromSetting', () {
    test('reads the stored value', () {
      expect(DisplayCharset.fromSetting('cp1256'), DisplayCharset.cp1256);
      expect(DisplayCharset.fromSetting('latin1'), DisplayCharset.latin1);
      expect(DisplayCharset.fromSetting('cp1256-visual'),
          DisplayCharset.cp1256Visual);
    });

    test('🚨 anything unknown falls back to ASCII, never to a guess', () {
      // An unset value, a typo, or a setting written by a future build must not
      // put Arabic bytes on a Latin-only panel. Garbage is worse than `?`.
      expect(DisplayCharset.fromSetting(null), DisplayCharset.ascii);
      expect(DisplayCharset.fromSetting(''), DisplayCharset.ascii);
      expect(DisplayCharset.fromSetting('cp864'), DisplayCharset.ascii);
    });
  });

  group('ascii (the default)', () {
    test('Arabic becomes ?, one per letter — this is the reported behaviour',
        () {
      final line =
          prepareForDisplay(croissantAr, DisplayCharset.ascii);
      expect(line, '???????');
      expect(line.length, croissantAr.length);
    });

    test('accented Latin folds rather than dropping out', () {
      expect(prepareForDisplay('Café Crème', DisplayCharset.ascii),
          'Cafe Creme');
    });

    test('every byte fits in one byte', () {
      final bytes = encodeForDisplay(
        prepareForDisplay('Thé 日本', DisplayCharset.ascii),
        DisplayCharset.ascii,
      );
      expect(bytes.every((b) => b <= 0xFF), isTrue);
    });
  });

  group('latin1', () {
    test('accents survive as themselves', () {
      final text = prepareForDisplay('Café', DisplayCharset.latin1);
      expect(text, 'Café');
      expect(encodeForDisplay(text, DisplayCharset.latin1),
          [0x43, 0x61, 0x66, 0xE9]); // C a f é
    });

    test('Arabic is still out of range, so still ?', () {
      expect(prepareForDisplay(croissantAr, DisplayCharset.latin1), '???????');
    });
  });

  group('cp1256 — the answer to "كرواسون did not display"', () {
    test('every Arabic letter maps to a real byte, none to ?', () {
      final text = prepareForDisplay(croissantAr, DisplayCharset.cp1256);
      expect(text, croissantAr, reason: 'nothing should be substituted');
      final bytes = encodeForDisplay(text, DisplayCharset.cp1256);
      expect(bytes.contains(0x3F), isFalse, reason: 'no ? left');
      expect(bytes.every((b) => b >= 0x80), isTrue,
          reason: 'Arabic lives in the high half of CP1256');
    });

    test('the bytes are the real Windows-1256 values', () {
      // ك=0xDF  ر=0xD1  و=0xE6  ا=0xC7  س=0xD3  و=0xE6  ن=0xE4
      expect(
        encodeForDisplay(
          prepareForDisplay(croissantAr, DisplayCharset.cp1256),
          DisplayCharset.cp1256,
        ),
        [0xDF, 0xD1, 0xE6, 0xC7, 0xD3, 0xE6, 0xE4],
      );
    });

    test('ASCII is untouched — CP1256 keeps it in place', () {
      expect(
        encodeForDisplay(
          prepareForDisplay('Cafe 12.50', DisplayCharset.cp1256),
          DisplayCharset.cp1256,
        ),
        'Cafe 12.50'.codeUnits,
      );
    });

    test('logical order: the bytes come out in the order they were typed', () {
      final bytes = encodeForDisplay(
        prepareForDisplay(croissantAr, DisplayCharset.cp1256),
        DisplayCharset.cp1256,
      );
      expect(bytes.first, 0xDF, reason: 'first letter ك goes first');
    });
  });

  group('cp1256-visual', () {
    test('the Arabic run is reversed for a display that does no bidi', () {
      final bytes = encodeForDisplay(
        prepareForDisplay(croissantAr, DisplayCharset.cp1256Visual),
        DisplayCharset.cp1256Visual,
      );
      expect(bytes, [0xE4, 0xE6, 0xD3, 0xC7, 0xE6, 0xD1, 0xDF]);
    });

    test('🚨 a price beside an Arabic word is NOT reversed', () {
      // A reversed number is not a rendering quirk, it is a different number.
      final text =
          prepareForDisplay('شاي 12.50', DisplayCharset.cp1256Visual);
      expect(text.endsWith('12.50'), isTrue);
    });

    test('Latin runs keep their direction', () {
      expect(prepareForDisplay('Cafe', DisplayCharset.cp1256Visual), 'Cafe');
    });
  });

  group('frames', () {
    test('the charset reaches the composed lines and the bytes', () {
      final lines = poleDisplayLines(
        line1: croissantAr,
        line2: '1 x 8.00       33.00',
        width: 20,
        charset: DisplayCharset.cp1256,
      );
      expect(lines.line1.trim(), croissantAr);
      expect(lines.line1.length, 20);

      final frame = poleDisplayFrame(
        line1: croissantAr,
        line2: '',
        width: 20,
        charset: DisplayCharset.cp1256,
      );
      expect(frame.first, 0x0C, reason: 'form feed still clears the display');
      expect(frame.contains(0xDF), isTrue, reason: 'ك reached the wire');
      expect(frame.every((b) => b <= 0xFF), isTrue);
    });

    test('padding counts characters, not bytes, in every charset', () {
      for (final charset in DisplayCharset.values) {
        final lines = poleDisplayLines(
          line1: croissantAr,
          line2: 'x',
          width: 20,
          charset: charset,
        );
        expect(lines.line1.length, 20, reason: '$charset line 1');
        expect(lines.line2.length, 20, reason: '$charset line 2');
      }
    });
  });
}
