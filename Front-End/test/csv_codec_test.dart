// The CSV reader and writer behind the catalogue import/export.
//
// Each case is a file an operator really has. The old reader split on newlines
// before it looked at quotes, knew only commas, and read only UTF-8 — so our OWN
// export broke it (a description with a line break), and so did every file
// Excel saves in French (`;` and `12,50`), in "CSV UTF-8" (a byte-order mark
// glued to the first header, so Name stopped auto-mapping), or in plain "CSV"
// on Windows (Windows-1252: the first é threw).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/product/csv_codec.dart';

void main() {
  group('reading', () {
    test('a quoted field may span lines — our own export writes those', () {
      final t = parseCsv('Name,Description\r\n"Tea","Line one\nline two"\r\nCoffee,x\r\n');

      expect(t.rows, hasLength(2));
      expect(t.rows.first[1], 'Line one\nline two');
    });

    test('a byte-order mark does not become part of the first header', () {
      final t = parseCsv('﻿Name,Price\nTea,2\n');

      expect(t.headers.first, 'Name');
    });

    test('a French Excel file splits on semicolons', () {
      final t = parseCsv('Name;Price;Description\nThé;12,50;"a; b"\n');

      expect(t.delimiter, ';');
      expect(t.rows.single, ['Thé', '12,50', 'a; b']);
    });

    test('an Excel sep= hint line sets the delimiter and is not a row', () {
      final t = parseCsv('sep=;\nName;Price\nTea;2\n');

      expect(t.headers, ['Name', 'Price']);
      expect(t.rows.single, ['Tea', '2']);
    });

    test('doubled quotes inside a quoted field are one quote', () {
      final t = parseCsv('Name\n"The ""big"" one"\n');

      expect(t.rows.single.single, 'The "big" one');
    });

    test('a quote in the middle of an unquoted cell is kept literally', () {
      final t = parseCsv('Name,Size\nScreen,5" wide\n');

      expect(t.rows.single, ['Screen', '5" wide']);
    });

    test('blank lines and a trailing line break add no rows', () {
      final t = parseCsv('Name\n\nTea\n\n\n');

      expect(t.rows, [
        ['Tea'],
      ]);
    });

    test('an empty file is an empty table, not a crash', () {
      final t = parseCsv('');

      expect(t.headers, isEmpty);
      expect(t.rows, isEmpty);
    });
  });

  group('decoding bytes', () {
    test('UTF-8 is read as UTF-8', () {
      expect(decodeCsvBytes(utf8.encode('Thé,شاي')), 'Thé,شاي');
    });

    test('Windows-1252 falls back instead of throwing', () {
      // "Thé 5€" as Excel's plain CSV writes it: é = 0xE9, € = 0x80.
      final bytes = [0x54, 0x68, 0xE9, 0x20, 0x35, 0x80];

      expect(decodeCsvBytes(bytes), 'Thé 5€');
    });
  });

  group('numbers', () {
    test('every way a spreadsheet writes one', () {
      expect(parseCsvNumber('12.5'), 12.5);
      expect(parseCsvNumber('12,5'), 12.5);
      expect(parseCsvNumber('1 234,50'), 1234.5);
      expect(parseCsvNumber('1 234,50'), 1234.5); // non-breaking space
      expect(parseCsvNumber('1.234,50'), 1234.5);
      expect(parseCsvNumber('1,234.50'), 1234.5);
      expect(parseCsvNumber('1,234,567'), 1234567);
      expect(parseCsvNumber('-3'), -3);
    });

    test('blank or unreadable is null, never zero', () {
      // A zero would import every unreadable price as free.
      expect(parseCsvNumber(null), isNull);
      expect(parseCsvNumber(''), isNull);
      expect(parseCsvNumber('  '), isNull);
      expect(parseCsvNumber('twelve'), isNull);
    });
  });

  group('yes/no', () {
    test('the spellings an operator types', () {
      for (final yes in ['1', 'true', 'TRUE', 'yes', 'oui', 'Vrai', 'x']) {
        expect(parseCsvBool(yes), isTrue, reason: yes);
      }
      for (final no in ['0', 'false', 'no', 'non', 'faux']) {
        expect(parseCsvBool(no), isFalse, reason: no);
      }
    });

    test('blank or unknown is null, so it never overwrites a real value', () {
      expect(parseCsvBool(null), isNull);
      expect(parseCsvBool(''), isNull);
      expect(parseCsvBool('maybe'), isNull);
    });
  });

  group('writing', () {
    test('starts with a byte-order mark and ends lines with CRLF', () {
      final csv = encodeCsv([
        ['Name'],
        ['Tea'],
      ]);

      expect(csv, '﻿Name\r\nTea\r\n');
    });

    test('quotes exactly the cells that need it', () {
      final csv = encodeCsv([
        ['a,b', 'say "hi"', 'two\nlines', 'plain', null],
      ]);

      expect(csv.substring(1), '"a,b","say ""hi""","two\nlines",plain,\r\n');
    });

    test('numbers without a trailing .0 or an exponent, flags as 1/0', () {
      final csv = encodeCsv([
        [12.0, 0.1, 0.00000001, true, false],
      ]);

      expect(csv.substring(1), '12,0.1,0.00000001,1,0\r\n');
    });

    test('what it writes, it reads back cell for cell', () {
      final rows = [
        ['Name', 'Description', 'Price'],
        ['Thé à la menthe', 'Hot, sweet\n"Moroccan"', '12.5'],
        ['شاي', '', '3'],
      ];

      final t = parseCsv(encodeCsv(rows));

      expect(t.headers, rows.first);
      expect(t.rows, rows.skip(1).toList());
    });
  });
}
