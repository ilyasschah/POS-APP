import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A single-sheet `.xlsx` workbook, written from scratch.
///
/// Why not a CSV: Excel opens a CSV with the list separator of the machine's
/// locale, so a comma-separated file lands in ONE column on every French-locale
/// till — and a CSV has no types, so quantities and dates arrive as text that
/// neither sorts nor sums. Why not a package: what is needed here is six small
/// XML parts in a zip, and `archive` is already in the build through `pdf`.
///
/// Deliberately minimal: one sheet, a bold header row frozen at the top, and
/// text / number / date-time cells. Text is written inline (`inlineStr`), which
/// every spreadsheet program reads and which saves keeping a shared-string table.
sealed class XlsxCell {
  const XlsxCell();
}

/// Text, written as it is.
final class XlsxText extends XlsxCell {
  const XlsxText(this.value);
  final String value;
}

/// A number the sheet can sum and sort.
final class XlsxNumber extends XlsxCell {
  const XlsxNumber(this.value);
  final num value;
}

/// A wall-clock date and time. The fields are written as they read, with no
/// zone conversion — move the instant into the zone the sheet should show
/// before handing it over.
final class XlsxDateTime extends XlsxCell {
  const XlsxDateTime(this.value);
  final DateTime value;
}

/// Encodes one sheet: [header] in bold on row 1, then [rows]. A null cell is
/// left empty. [columnWidths] are in Excel's character units.
Uint8List encodeXlsx({
  required String sheetName,
  required List<String> header,
  required List<List<XlsxCell?>> rows,
  List<double>? columnWidths,
}) {
  final archive = Archive();
  void add(String name, String xml) {
    final bytes = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('[Content_Types].xml', _contentTypes);
  add('_rels/.rels', _rootRels);
  add('xl/workbook.xml', _workbook(xlsxSheetName(sheetName)));
  add('xl/_rels/workbook.xml.rels', _workbookRels);
  add('xl/styles.xml', _styles);
  add('xl/worksheets/sheet1.xml', _sheet(header, rows, columnWidths));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// `A` for column 0, `Z` for 25, `AA` for 26.
String xlsxColumnLetters(int index) {
  var n = index + 1;
  final letters = <String>[];
  while (n > 0) {
    final rem = (n - 1) % 26;
    letters.insert(0, String.fromCharCode(65 + rem));
    n = (n - 1) ~/ 26;
  }
  return letters.join();
}

/// A name Excel accepts for a sheet: none of `[ ] : * ? / \`, no apostrophe
/// at either end, at most 31 characters, never empty. Excel refuses to open a
/// workbook whose sheet breaks any of these — it does not repair it.
String xlsxSheetName(String raw) {
  var name = raw
      .replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ')
      .trim()
      .replaceAll(RegExp(r"^'+|'+$"), '');
  if (name.length > 31) name = name.substring(0, 31).trim();
  return name.isEmpty ? 'Sheet1' : name;
}

/// Excel's date serial: days since 1899-12-30, the fraction being the time of
/// day. 25569 is 1970-01-01 on that count.
String _serial(DateTime t) {
  final wall = DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second);
  final days =
      wall.millisecondsSinceEpoch / Duration.millisecondsPerDay + 25569;
  return _number(double.parse(days.toStringAsFixed(8)));
}

/// `12` rather than `12.0`, and never an exponent the sheet would read as text.
String _number(num v) {
  if (v is int) return '$v';
  final d = v.toDouble();
  if (d == d.truncateToDouble() && d.abs() < 1e15) return '${d.toInt()}';
  final s = d.toString();
  if (!s.contains('e')) return s;
  return d
      .toStringAsFixed(10)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// XML-escaped, minus the control characters XML 1.0 cannot carry at all — a
/// stray one pasted into a product name would otherwise corrupt the file.
String _escape(String s) => s
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _cell(String ref, XlsxCell cell, {required bool bold}) =>
    switch (cell) {
      XlsxText(:final value) => '<c r="$ref" t="inlineStr"'
          '${bold ? ' s="1"' : ''}><is><t xml:space="preserve">'
          '${_escape(value)}</t></is></c>',
      // NaN and infinity have no cell form; they are left empty.
      XlsxNumber(:final value) =>
        value.isFinite ? '<c r="$ref"><v>${_number(value)}</v></c>' : '',
      XlsxDateTime(:final value) =>
        '<c r="$ref" s="2"><v>${_serial(value)}</v></c>',
    };

void _row(StringBuffer sb, int r, List<XlsxCell?> cells, {bool bold = false}) {
  sb.write('<row r="$r">');
  for (var c = 0; c < cells.length; c++) {
    final cell = cells[c];
    if (cell != null) {
      sb.write(_cell('${xlsxColumnLetters(c)}$r', cell, bold: bold));
    }
  }
  sb.write('</row>');
}

String _sheet(
  List<String> header,
  List<List<XlsxCell?>> rows,
  List<double>? widths,
) {
  final sb = StringBuffer()
    ..write(_xmlDecl)
    ..write('<worksheet xmlns="$_mainNs">')
    // The header stays put while the rows scroll, like the table it came from.
    ..write('<sheetViews><sheetView workbookViewId="0">'
        '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" '
        'state="frozen"/></sheetView></sheetViews>');
  if (widths != null && widths.isNotEmpty) {
    sb.write('<cols>');
    for (var i = 0; i < widths.length; i++) {
      sb.write('<col min="${i + 1}" max="${i + 1}" '
          'width="${_number(widths[i])}" customWidth="1"/>');
    }
    sb.write('</cols>');
  }
  sb.write('<sheetData>');
  _row(sb, 1, [for (final h in header) XlsxText(h)], bold: true);
  for (var r = 0; r < rows.length; r++) {
    _row(sb, r + 2, rows[r]);
  }
  sb.write('</sheetData></worksheet>');
  return sb.toString();
}

const _xmlDecl = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
const _mainNs = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const _relNs =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _pkgRelNs =
    'http://schemas.openxmlformats.org/package/2006/relationships';

const _contentTypes = '$_xmlDecl'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" '
    'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/'
    'vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/'
    'vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/'
    'vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '</Types>';

const _rootRels = '$_xmlDecl'
    '<Relationships xmlns="$_pkgRelNs">'
    '<Relationship Id="rId1" Type="$_relNs/officeDocument" '
    'Target="xl/workbook.xml"/>'
    '</Relationships>';

String _workbook(String sheetName) => '$_xmlDecl'
    '<workbook xmlns="$_mainNs" xmlns:r="$_relNs">'
    '<sheets><sheet name="${_escape(sheetName)}" sheetId="1" r:id="rId1"/>'
    '</sheets></workbook>';

const _workbookRels = '$_xmlDecl'
    '<Relationships xmlns="$_pkgRelNs">'
    '<Relationship Id="rId1" Type="$_relNs/worksheet" '
    'Target="worksheets/sheet1.xml"/>'
    '<Relationship Id="rId2" Type="$_relNs/styles" Target="styles.xml"/>'
    '</Relationships>';

/// Three cell formats: 0 plain, 1 bold (the header), 2 date-time.
const _styles = '$_xmlDecl'
    '<styleSheet xmlns="$_mainNs">'
    '<numFmts count="1">'
    '<numFmt numFmtId="164" formatCode="yyyy-mm-dd hh:mm"/></numFmts>'
    '<fonts count="2">'
    '<font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
    '<fills count="2"><fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill></fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/>'
    '</border></borders>'
    '<cellStyleXfs count="1">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="3">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" '
    'applyFont="1"/>'
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1"/>'
    '</cellXfs>'
    '<cellStyles count="1">'
    '<cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';
