// The Stock Moves exports: the sheet carries the columns on screen, in their
// order, with typed cells; the PDF renders a multi-page history; ticked rows
// are what gets written when there are any.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/document/document_type_constants.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/stock/stock_move_line.dart';
import 'package:pos_app/stock/stock_moves_columns.dart';
import 'package:pos_app/stock/stock_moves_export.dart';
import 'package:pos_app/uom/unit_of_measure.dart';
import 'package:xml/xml.dart';

StockMoveLine move({
  required bool incoming,
  double quantity = 2,
  String id = 'line',
  int? type,
}) =>
    StockMoveLine(
      itemLocalId: id,
      documentLocalId: 'doc',
      documentNumber: 'PO-1',
      documentTypeId:
          type ?? (incoming ? DocumentTypes.purchase : DocumentTypes.sales),
      date: DateTime.utc(2026, 9, 10, 21, 44),
      productId: 100,
      productName: 'Mint tea',
      barcode: '6111245',
      uomId: kUomPieces,
      warehouseId: 10,
      warehouseName: 'Main',
      from: incoming ? StockLocationKind.vendors : StockLocationKind.warehouse,
      to: incoming ? StockLocationKind.warehouse : StockLocationKind.customers,
      quantity: quantity,
      status: StockMoveStatus.done,
      userId: 7,
      userName: 'Alice Brown',
    );

/// Every row of the sheet, as the text or value each cell holds.
List<List<String>> rowsOf(Uint8List xlsx) {
  final sheet = ZipDecoder()
      .decodeBytes(xlsx)
      .files
      .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml');
  final doc = XmlDocument.parse(utf8.decode(sheet.content));
  return [
    for (final row in doc.findAllElements('row'))
      [
        for (final c in row.findElements('c'))
          c.getAttribute('t') == 'inlineStr'
              ? c.findAllElements('t').single.innerText
              : c.findElements('v').single.innerText,
      ],
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = lookupAppLocalizations(const Locale('en'));
  final dates = AppDateFormat('dd/MM/yyyy', timezone: 'Etc/UTC');

  test('the sheet writes the columns on screen, in their order, typed', () {
    final rows = rowsOf(buildStockMovesXlsx(
      l: l,
      dates: dates,
      moves: [move(incoming: true, quantity: 5), move(incoming: false)],
      columns: const ['quantity', 'date', 'from', 'product'],
    ));

    expect(rows.first,
        [l.colQuantity, l.rptColUom, l.colDate, l.colFrom, l.colProduct]);
    expect(rows[1], [
      '5',
      uomById(kUomPieces).code,
      '46275.90555556', // a real date the sheet can sort
      l.stockLocationVendors,
      'Mint tea',
    ]);
    // Goods that left stock are negative, so the column sums to the change.
    expect(rows[2][0], '-2');
    expect(rows[2][3], l.stockLocationWarehouse('Main'));
  });

  test('a column hidden on screen is not in the sheet', () {
    final rows = rowsOf(buildStockMovesXlsx(
      l: l,
      dates: dates,
      moves: [move(incoming: true)],
      columns: const ['product'],
    ));

    expect(rows.first, [l.colProduct]);
    expect(rows[1], ['Mint tea']);
  });

  test('an adjustment is written as Product Quantity Updated, like on screen',
      () {
    final rows = rowsOf(buildStockMovesXlsx(
      l: l,
      dates: dates,
      moves: [
        move(incoming: true),
        move(incoming: true, type: DocumentTypes.inventoryCount),
      ],
      columns: const ['reference'],
    ));

    expect(rows[1], ['PO-1']);
    expect(rows[2], [l.productQuantityUpdated('Alice Brown')]);
  });

  test('the PDF renders a history that runs over several pages', () async {
    final bytes = await buildStockMovesPdf(
      l: l,
      dates: dates,
      moves: [for (var i = 0; i < 120; i++) move(incoming: i.isEven)],
      columns: kStockMoveColumns,
      companyName: 'Shop',
      warehouseName: 'Main',
      search: 'mint',
      period: DateTimeRange(
          start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30)),
    );

    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    // More than one page object: the table split rather than overflowing.
    expect(RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length,
        greaterThan(1));
  });

  group('with rows ticked', () {
    final onScreen = [
      for (var i = 0; i < 5; i++) move(incoming: i.isEven, id: 'line-$i'),
    ];

    test('the export writes exactly those, in the order on screen', () {
      final picked = selectedStockMoves(onScreen, {'line-3', 'line-1'});

      expect(picked!.map((m) => m.itemLocalId), ['line-1', 'line-3']);
    });

    test('none ticked means the whole filtered history', () {
      expect(selectedStockMoves(onScreen, const {}), isNull);
    });

    test('a tick on a row no longer on screen does not count', () {
      expect(selectedStockMoves(onScreen, {'gone'}), isNull);
      expect(
          selectedStockMoves(onScreen, {'gone', 'line-4'})!
              .map((m) => m.itemLocalId),
          ['line-4']);
    });
  });
}
