/// CSV reading and writing for the catalogue import/export.
///
/// Written for the files operators actually have, not the ones RFC 4180
/// describes. The import used to split the file on newlines BEFORE looking at
/// quotes, understand only commas, and read only UTF-8 — so it broke on:
///
///  * a description with a line break in it — which our own export writes;
///  * a file saved by Excel in French, which uses `;` between columns and a
///    decimal comma (`12,50`), so every row came in as one column and every
///    price as blank;
///  * "CSV UTF-8" from Excel, whose byte-order mark glued itself to the first
///    header — `﻿Name` — so the required Name column stopped auto-mapping;
///  * plain "CSV" from Excel on Windows, which is Windows-1252, so the first
///    accented product name threw and nothing said why.
library;

import 'dart:convert';

const String _bom = '﻿';

/// A parsed CSV file: its header row, its data rows, and what it was split on.
class CsvTable {
  const CsvTable({
    required this.headers,
    required this.rows,
    required this.delimiter,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final String delimiter;
}

/// A file's bytes as text: UTF-8 when they are valid UTF-8 (with or without a
/// byte-order mark), Windows-1252 otherwise — which is what Excel's plain
/// "CSV (comma delimited)" writes on a French or English Windows.
String decodeCsvBytes(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return _decodeCp1252(bytes);
  }
}

/// Splits CSV text into a header row and data rows.
///
/// The delimiter is taken from an Excel `sep=;` hint line when there is one,
/// otherwise from whichever of `,` `;` or tab occurs most in the header line.
/// Quoted fields may contain the delimiter, doubled quotes and line breaks.
/// Fully blank lines are dropped.
CsvTable parseCsv(String content) {
  var text = content.startsWith(_bom) ? content.substring(1) : content;

  final lineEnd = RegExp(r'\r\n|\n|\r');
  final firstMatch = lineEnd.firstMatch(text);
  final firstLine = firstMatch == null ? text : text.substring(0, firstMatch.start);

  String? delimiter;
  final hint =
      RegExp(r'^sep=(.)$', caseSensitive: false).firstMatch(firstLine.trim());
  if (hint != null) {
    delimiter = hint.group(1);
    text = firstMatch == null ? '' : text.substring(firstMatch.end);
  }
  final resolved = delimiter ?? _sniffDelimiter(firstLine);

  final records = _readRecords(text, resolved)
      .where((r) => r.any((cell) => cell.trim().isNotEmpty))
      .toList();
  if (records.isEmpty) {
    return CsvTable(headers: const [], rows: const [], delimiter: resolved);
  }

  return CsvTable(
    headers: records.first.map((h) => h.trim()).toList(),
    rows: records.skip(1).toList(),
    delimiter: resolved,
  );
}

/// A number as a spreadsheet may have written it — `12.5`, `12,5`,
/// `1 234,50`, `1.234,50`, `1,234.50`. Null when blank or unreadable.
///
/// With a single comma and no dot the comma is read as the DECIMAL separator,
/// because that is what a French spreadsheet means by `12,5`; a file that
/// groups thousands with a lone comma (`1,234`) is ambiguous and reads as 1.234.
double? parseCsvNumber(String? raw) {
  if (raw == null) return null;
  var s = raw.trim().replaceAll(RegExp(r'[\s  ]'), '');
  if (s.isEmpty) return null;

  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma >= 0 && lastDot >= 0) {
    // Both present: the LAST one is the decimal point, the other groups digits.
    s = lastComma > lastDot
        ? s.replaceAll('.', '').replaceAll(',', '.')
        : s.replaceAll(',', '');
  } else if (lastComma >= 0) {
    s = ','.allMatches(s).length > 1
        ? s.replaceAll(',', '') // 1,234,567 can only be grouping
        : s.replaceAll(',', '.');
  }
  return double.tryParse(s);
}

/// A yes/no cell, in the spellings an operator types. Null when blank or not
/// recognisable, so an absent value never overwrites a real one with `false`.
bool? parseCsvBool(String? raw) {
  final s = raw?.trim().toLowerCase();
  if (s == null || s.isEmpty) return null;
  const yes = {'1', 'true', 'yes', 'y', 'x', 'oui', 'vrai'};
  const no = {'0', 'false', 'no', 'n', 'non', 'faux'};
  if (yes.contains(s)) return true;
  if (no.contains(s)) return false;
  return null;
}

/// Writes rows as a CSV file Excel opens correctly.
///
/// UTF-8 WITH a byte-order mark: without one Excel reads UTF-8 as the machine's
/// ANSI code page and every accented or Arabic name turns to mojibake. CRLF line
/// ends, and any cell holding the delimiter, a quote or a line break is quoted.
String encodeCsv(List<List<Object?>> rows, {String delimiter = ','}) {
  final sb = StringBuffer(_bom);
  for (final row in rows) {
    sb
      ..write(row.map((v) => _encodeCell(v, delimiter)).join(delimiter))
      ..write('\r\n');
  }
  return sb.toString();
}

// ── internals ───────────────────────────────────────────────────────────────

String _encodeCell(Object? value, String delimiter) {
  final s = switch (value) {
    null => '',
    double d => _formatNumber(d),
    bool b => b ? '1' : '0',
    _ => value.toString(),
  };
  final needsQuotes = s.contains(delimiter) ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r');
  return needsQuotes ? '"${s.replaceAll('"', '""')}"' : s;
}

/// `12` rather than `12.0`, and never an exponent (`1e-7`) a spreadsheet would
/// read as text.
String _formatNumber(double v) {
  if (v == v.truncateToDouble() && v.abs() < 1e15) return v.toInt().toString();
  final s = v.toString();
  if (!s.contains('e')) return s;
  return v
      .toStringAsFixed(8)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// The header decides: whichever of `,` `;` or tab occurs most outside quotes.
/// A tie — including a one-column file — is a comma.
String _sniffDelimiter(String headerLine) {
  final counts = <String, int>{',': 0, ';': 0, '\t': 0};
  var inQuotes = false;
  for (var i = 0; i < headerLine.length; i++) {
    final ch = headerLine[i];
    if (ch == '"') {
      inQuotes = !inQuotes;
    } else if (!inQuotes && counts.containsKey(ch)) {
      counts[ch] = counts[ch]! + 1;
    }
  }
  var best = ',';
  counts.forEach((ch, n) {
    if (n > counts[best]!) best = ch;
  });
  return best;
}

/// RFC 4180 across the WHOLE text, so a quoted field may span lines. A quote
/// opens a quoted field only at the start of a cell; one in the middle of an
/// unquoted cell (`5" screen`) is kept literally.
List<List<String>> _readRecords(String text, String delimiter) {
  final records = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  var cellStarted = false;

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(ch);
      }
      continue;
    }
    if (ch == '"' && !cellStarted) {
      inQuotes = true;
      cellStarted = true;
    } else if (ch == delimiter) {
      row.add(cell.toString());
      cell.clear();
      cellStarted = false;
    } else if (ch == '\r' || ch == '\n') {
      row.add(cell.toString());
      cell.clear();
      cellStarted = false;
      records.add(row);
      row = <String>[];
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
    } else {
      cell.write(ch);
      cellStarted = true;
    }
  }
  if (cellStarted || row.isNotEmpty) {
    row.add(cell.toString());
    records.add(row);
  }
  return records;
}

String _decodeCp1252(List<int> bytes) {
  final out = StringBuffer();
  for (final b in bytes) {
    out.writeCharCode(b >= 0x80 && b <= 0x9F ? _cp1252High[b - 0x80] : b);
  }
  return out.toString();
}

/// 0x80–0x9F in Windows-1252; the five undefined slots map to their C1 control,
/// as Windows itself does. Everything else is identical to Latin-1.
const List<int> _cp1252High = [
  0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F,
  0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178,
];
