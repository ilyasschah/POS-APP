import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';

import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/document/document_type_constants.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/stock/stock_move_line.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

/// What a Stock Moves column says about one move, as text.
///
/// The table's cells, the PDF and the spreadsheet all read their words from
/// here, so an export can never describe a move differently from the screen.

/// `Sep 10, 9:44 PM`, in the company's timezone.
///
/// The month comes from the `.arb` abbreviations like every other screen's,
/// because `intl`'s `MMM` needs locale data this app never initialises.
String stockMoveDateLabel(
    AppLocalizations l, AppDateFormat dates, DateTime instant) {
  final local = dates.toDisplayZone(instant);
  final months = l.monthAbbreviations.split(',');
  return '${months[local.month - 1]} ${local.day}, ${_clock.format(local)}';
}

final DateFormat _clock = DateFormat('h:mm a');

/// A location's name as the operator reads it. A warehouse is named after
/// itself — `Main/Stock` — because a company can hold stock in several.
String stockLocationLabel(
  AppLocalizations l,
  StockLocationKind kind,
  String? warehouseName,
) =>
    switch (kind) {
      StockLocationKind.vendors => l.stockLocationVendors,
      StockLocationKind.customers => l.stockLocationCustomers,
      StockLocationKind.inventoryAdjustment =>
        l.stockLocationInventoryAdjustment,
      StockLocationKind.scrap => l.stockLocationScrap,
      StockLocationKind.warehouse =>
        l.stockLocationWarehouse(warehouseName ?? l.warehouse),
    };

/// The product's name, as Odoo's Moves History shows it. Its barcodes stay
/// searchable (see `AppDatabase.watchStockMoves`) without crowding the column.
String stockMoveProductLabel(StockMoveLine move) =>
    move.productName ?? '#${move.productId}';

/// `+5 pcs` into stock, `-2 pcs` out of it. The sign carries the direction as
/// well as the colour does, so it survives a colour-blind operator and a
/// monochrome printer.
String stockMoveQuantityLabel(StockMoveLine move) =>
    '${move.isIncoming ? '+' : '-'}${formatQuantity(move.quantity, move.uomId)}';

String stockMoveStatusLabel(AppLocalizations l, StockMoveStatus status) =>
    switch (status) {
      StockMoveStatus.done => l.moveStatusDone,
      StockMoveStatus.pendingSync => l.pendingSync,
    };

/// `01/09/2026 – 11/09/2026` in the company's date format, or the one day when
/// the period starts and ends on it. Calendar days, so no timezone shift —
/// see `AppDateFormat.day`.
String stockPeriodLabel(AppDateFormat dates, DateTimeRange period) {
  final start = dates.day(period.start);
  final end = dates.day(period.end);
  return start == end ? start : '$start – $end';
}

/// Whether a move is an inventory adjustment — a correction of the stock,
/// not a trade — which the history names and colours apart.
bool isStockAdjustment(StockMoveLine move) =>
    move.documentTypeId == DocumentTypes.inventoryCount;

/// What the Reference column says. A trade is named by its document number
/// (`WH/POS/00888`); an inventory adjustment by what it did and who did it —
/// `Product Quantity Updated (Alice)` — as Odoo names it, since the count's
/// number tells an operator nothing about why the stock changed.
String stockMoveReferenceLabel(AppLocalizations l, StockMoveLine move) =>
    isStockAdjustment(move)
        ? l.productQuantityUpdated(move.userName ?? '—')
        : move.documentNumber ?? '—';

/// One column of one move, by the column's key (see `kStockMoveColumns`).
String stockMoveCellText(
  AppLocalizations l,
  AppDateFormat dates,
  StockMoveLine move,
  String column,
) =>
    switch (column) {
      'date' => stockMoveDateLabel(l, dates, move.date),
      'reference' => stockMoveReferenceLabel(l, move),
      'product' => stockMoveProductLabel(move),
      'from' => stockLocationLabel(l, move.from, move.warehouseName),
      'to' => stockLocationLabel(l, move.to, move.warehouseName),
      'quantity' => stockMoveQuantityLabel(move),
      'status' => stockMoveStatusLabel(l, move.status),
      _ => '',
    };
