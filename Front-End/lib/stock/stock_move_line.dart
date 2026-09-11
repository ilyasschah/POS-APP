import 'package:flutter/foundation.dart';

import 'package:pos_app/document/document_type_constants.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

/// One end of a stock move, in Odoo's double-entry sense.
///
/// This app records inventory as DOCUMENTS whose lines carry quantities; Odoo
/// records it as goods travelling from one LOCATION to another, most of them
/// virtual. [warehouse] is the only location where the company actually holds
/// stock — every other kind is where goods come from or go to.
///
/// An enum, never a string. The labels are translated when they are drawn, and
/// a warehouse location is drawn with that warehouse's own name (`Main/Stock`),
/// because a company can have several.
enum StockLocationKind { vendors, customers, inventoryAdjustment, scrap, warehouse }

/// Whether a move has reached the server yet.
enum StockMoveStatus { done, pendingSync }

/// Where one document line moved goods, and how many.
///
/// [quantity] is always positive: the direction lives in `from` and `to`, as it
/// does in Odoo, rather than in a sign the reader has to interpret.
typedef StockMoveRoute = ({
  StockLocationKind from,
  StockLocationKind to,
  double quantity,
});

/// The mapping from a document line to a location-to-location move.
///
/// | Type | Moves goods |
/// |---|---|
/// | 1 Purchase | Vendors → Stock |
/// | 2 Sales | Stock → Customers |
/// | 3 Inventory Count | Inventory adj. → Stock when the count found more, Stock → Inventory adj. when it found less |
/// | 4 Refund | Customers → Stock |
/// | 5 Stock Return | Stock → Vendors |
/// | 6 Loss And Damage | Stock → Scrap |
/// | 7 Proforma | nothing — a quote moves no goods |
///
/// Agrees with the server's seeded `DocumentType.StockDirection` (1 in, 2 out,
/// 0 none); `test/stock_move_matrix_test.dart` holds the two together.
abstract final class StockMoveMatrix {
  /// Every document type that moves stock. The history's query selects exactly
  /// these, so a type missing here is a type the history never shows.
  static const List<int> movingDocumentTypes = [
    DocumentTypes.purchase,
    DocumentTypes.sales,
    DocumentTypes.inventoryCount,
    DocumentTypes.refund,
    DocumentTypes.stockReturn,
    DocumentTypes.lossAndDamage,
  ];

  /// The day inventory counts started recording, in `ExpectedQuantity`, the
  /// stock they were counted against.
  ///
  /// Before it, every writer copied `Quantity` into that column, so a count line
  /// with the two equal says nothing about a variance. Such a line is read as
  /// an opening balance — goods entering stock — which is what the only count
  /// path that moved stock at the time (the product import, into stock it then
  /// overwrote) amounted to. From this day on, equal means the count agreed with
  /// the system, and that moves nothing.
  static final DateTime countVarianceRecordedSince = DateTime.utc(2026, 9, 12);

  /// The move one document line made, or null when it made none — a Proforma,
  /// a zero quantity, or a count that agreed with the system.
  ///
  /// A negative quantity turns the route around rather than producing a
  /// negative move, which is also how a count that came up short becomes
  /// Stock → Inventory adjustment.
  static StockMoveRoute? resolve({
    required int documentTypeId,
    required double quantity,
    required double? expectedQuantity,
    required DateTime date,
  }) {
    final route = _routeOf(documentTypeId);
    if (route == null) return null;

    final moved = documentTypeId == DocumentTypes.inventoryCount
        ? countVariance(
            counted: quantity, expected: expectedQuantity, date: date)
        : quantity;
    if (moved == 0) return null;

    return moved > 0
        ? (from: route.from, to: route.to, quantity: moved)
        : (from: route.to, to: route.from, quantity: -moved);
  }

  /// How far an inventory count moved stock: what was counted minus what the
  /// system held when it was counted.
  ///
  /// A line that never recorded an expected quantity, or a legacy line that
  /// copied its quantity into one (see [countVarianceRecordedSince]), is an
  /// opening balance: the whole count entered stock.
  static double countVariance({
    required double counted,
    required double? expected,
    required DateTime date,
  }) {
    if (expected == null) return counted;
    if (expected == counted && date.isBefore(countVarianceRecordedSince)) {
      return counted;
    }
    // Snapped, so 0.1 + 0.2 counted against 0.3 expected is no move rather
    // than a phantom one of 0.00000000000000004.
    return snapToStorage(counted - expected);
  }

  /// The direction a POSITIVE quantity of [documentTypeId] moves goods.
  static ({StockLocationKind from, StockLocationKind to})? _routeOf(
          int documentTypeId) =>
      switch (documentTypeId) {
        DocumentTypes.purchase => (
            from: StockLocationKind.vendors,
            to: StockLocationKind.warehouse,
          ),
        DocumentTypes.sales => (
            from: StockLocationKind.warehouse,
            to: StockLocationKind.customers,
          ),
        DocumentTypes.inventoryCount => (
            from: StockLocationKind.inventoryAdjustment,
            to: StockLocationKind.warehouse,
          ),
        DocumentTypes.refund => (
            from: StockLocationKind.customers,
            to: StockLocationKind.warehouse,
          ),
        DocumentTypes.stockReturn => (
            from: StockLocationKind.warehouse,
            to: StockLocationKind.vendors,
          ),
        DocumentTypes.lossAndDamage => (
            from: StockLocationKind.warehouse,
            to: StockLocationKind.scrap,
          ),
        _ => null,
      };
}

/// One row of the Stock Moves history: a document line, read as a move.
@immutable
class StockMoveLine {
  const StockMoveLine({
    required this.itemLocalId,
    required this.documentLocalId,
    required this.documentNumber,
    required this.documentTypeId,
    required this.date,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.uomId,
    required this.warehouseId,
    required this.warehouseName,
    required this.from,
    required this.to,
    required this.quantity,
    required this.status,
    required this.userId,
    required this.userName,
  });

  /// The document line's local id — stable across syncs, so a row keeps its
  /// identity when its document is given a server number.
  final String itemLocalId;
  final String documentLocalId;

  /// Null while a manual document has not been numbered yet.
  final String? documentNumber;
  final int documentTypeId;

  /// When the goods moved — the document's stock date, else its date — as a
  /// UTC instant.
  final DateTime date;

  final int productId;

  /// Null when the product is no longer in this terminal's catalogue.
  final String? productName;
  final String? barcode;

  /// The unit [quantity] is counted in: the product's own, as on the line.
  final int? uomId;

  final int warehouseId;
  final String? warehouseName;

  final StockLocationKind from;
  final StockLocationKind to;

  /// Always positive — see [StockMoveRoute].
  final double quantity;

  final StockMoveStatus status;
  final int userId;
  final String? userName;

  /// True when goods entered the warehouse, false when they left it.
  bool get isIncoming => to == StockLocationKind.warehouse;
}

/// One read of the history.
@immutable
class StockMovePage {
  const StockMovePage({required this.lines, required this.hasMore});

  static const empty = StockMovePage(lines: [], hasMore: false);

  final List<StockMoveLine> lines;

  /// Whether the read stopped at its limit, so more lines may lie behind it.
  final bool hasMore;
}
