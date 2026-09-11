// The .xlsx writer: the parts Excel needs, typed cells, and the inputs that
// would otherwise make Excel refuse the file.
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/xlsx_writer.dart';
import 'package:xml/xml.dart';

Map<String, String> unzip(List<int> bytes) => {
      for (final f in ZipDecoder().decodeBytes(bytes).files)
        f.name: utf8.decode(f.content),
    };

String sheetOf(List<int> bytes) => unzip(bytes)['xl/worksheets/sheet1.xml']!;

void main() {
  test('column letters run A to Z, then AA', () {
    expect(xlsxColumnLetters(0), 'A');
    expect(xlsxColumnLetters(25), 'Z');
    expect(xlsxColumnLetters(26), 'AA');
    expect(xlsxColumnLetters(27), 'AB');
    expect(xlsxColumnLetters(701), 'ZZ');
    expect(xlsxColumnLetters(702), 'AAA');
  });

  test('a workbook holds the six parts Excel needs, each well-formed', () {
    final parts = unzip(encodeXlsx(
      sheetName: 'Moves',
      header: const ['A'],
      rows: const [],
    ));

    expect(parts.keys.toSet(), {
      '[Content_Types].xml',
      '_rels/.rels',
      'xl/workbook.xml',
      'xl/_rels/workbook.xml.rels',
      'xl/styles.xml',
      'xl/worksheets/sheet1.xml',
    });
    for (final xml in parts.values) {
      expect(() => XmlDocument.parse(xml), returnsNormally);
    }
    expect(parts['xl/workbook.xml'], contains('name="Moves"'));
  });

  test('the header is bold and frozen; cells keep their types', () {
    final sheet = sheetOf(encodeXlsx(
      sheetName: 'Moves',
      header: const ['Name', 'Qty', 'When'],
      rows: [
        [
          const XlsxText('R&D <x>'),
          const XlsxNumber(-2.5),
          XlsxDateTime(DateTime(2026, 9, 10, 21, 44)),
        ],
        const [null, XlsxNumber(3), null],
      ],
    ));

    expect(sheet, contains('<c r="A1" t="inlineStr" s="1">'));
    expect(sheet, contains('state="frozen"'));
    expect(sheet, contains('R&amp;D &lt;x&gt;'));
    expect(sheet, contains('<c r="B2"><v>-2.5</v></c>'));
    // 2026-09-10 is day 46275 counted from 1899-12-30; 21:44 is 0.90555… of it.
    expect(sheet, contains('<c r="C2" s="2"><v>46275.90555556</v></c>'));
    expect(sheet, contains('<c r="B3"><v>3</v></c>'));
    expect(sheet, isNot(contains('r="A3"')), reason: 'a null cell is empty');
  });

  test('a number is never written with an exponent or a trailing .0', () {
    final sheet = sheetOf(encodeXlsx(
      sheetName: 'N',
      header: const ['n'],
      rows: const [
        [XlsxNumber(12.0)],
        [XlsxNumber(0.0000001)],
        [XlsxNumber(double.nan)],
      ],
    ));

    expect(sheet, contains('<v>12</v>'));
    expect(sheet, contains('<v>0.0000001</v>'));
    expect(sheet, isNot(contains('NaN')));
  });

  test('a control character pasted into a name cannot corrupt the file', () {
    final sheet = sheetOf(encodeXlsx(
      sheetName: 'S',
      header: const ['h'],
      rows: const [
        [XlsxText('ab')],
      ],
    ));

    expect(() => XmlDocument.parse(sheet), returnsNormally);
    expect(sheet, contains('>ab<'));
  });

  test('a sheet name Excel would refuse is made safe', () {
    expect(xlsxSheetName('Stock/Moves [2026]'), 'Stock Moves  2026');
    expect(xlsxSheetName('x' * 40), hasLength(31));
    expect(xlsxSheetName("'quoted'"), 'quoted');
    expect(xlsxSheetName('  '), 'Sheet1');
  });
}
