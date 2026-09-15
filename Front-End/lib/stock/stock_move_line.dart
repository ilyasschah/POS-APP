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

/// The mapping from a document line to a location-to-location move, driven by
/// the line's document TYPE as the `document_types` table defines it — never by
/// a list of type ids, so a type added or changed on the server moves the way
/// it says.
///
/// * **Which way** is the type's `stock_direction`: 1 brings goods into the
///   warehouse, 2 takes them out, 0 moves nothing.
/// * **The other end** is the type's category: Expenses trade with Vendors,
///   Sales with Customers, Inventory corrects against Inventory adjustment, and
///   Loss writes off to Scrap.
///
/// | Type | Category | Direction | Moves goods |
/// |---|---|---|---|
/// | 100 Purchase | Expenses | 1 | Vendors → Stock |
/// | 120 Stock Return | Expenses | 2 | Stock → Vendors |
/// | 200 Sales | Sales | 2 | Stock → Customers |
/// | 220 Refund | Sales | 1 | Customers → Stock |
/// | 230 Proforma | Sales | 0 | nothing — a quote moves no goods |
/// | 300 Inventory Count | Inventory | 1 | its variance: Adjustment → Stock when more was found, Stock → Adjustment when less |
/// | 400 Loss And Damage | Loss | 2 | Stock → Scrap |
abstract final class StockMoveMatrix {
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

  /// The move one document line made, or null when it made none — a type with
  /// no stock direction, a zero quantity, or a count that agreed with the
  /// system.
  ///
  /// 🚨 A line's SIGN is not a direction. A refund rung up on this till records
  /// its lines negative, like the money it gives back, while the same refund
  /// pulled from the server carries them positive — and both brought the goods
  /// back in. Only an inventory count's variance is signed: a shortfall goes
  /// out, a surplus comes in.
  static StockMoveRoute? resolve({
    required int documentTypeId,
    required int stockDirection,
    required int? documentCategoryId,
    required double quantity,
    required double? expectedQuantity,
    required DateTime date,
  }) {
    if (stockDirection != StockDirections.intoStock &&
        stockDirection != StockDirections.outOfStock) {
      return null;
    }
    const warehouse = StockLocationKind.warehouse;
    final counterpart = counterpartOf(documentCategoryId);
    final incoming = stockDirection == StockDirections.intoStock;
    final from = incoming ? counterpart : warehouse;
    final to = incoming ? warehouse : counterpart;

    final moved = documentTypeId == DocumentTypes.inventoryCount
        ? countVariance(
            counted: quantity, expected: expectedQuantity, date: date)
        : quantity.abs();
    if (moved == 0) return null;

    return moved > 0
        ? (from: from, to: to, quantity: moved)
        : (from: to, to: from, quantity: -moved);
  }

  /// Where a type's goods come from or go to, by its category. A category this
  /// app does not know is booked against Inventory adjustment — a virtual
  /// location — rather than a trading partner it would be guessing at.
  static StockLocationKind counterpartOf(int? documentCategoryId) =>
      switch (documentCategoryId) {
        DocumentCategories.expenses => StockLocationKind.vendors,
        DocumentCategories.sales => StockLocationKind.customers,
        DocumentCategories.loss => StockLocationKind.scrap,
        DocumentCategories.inventory => StockLocationKind.inventoryAdjustment,
        _ => StockLocationKind.inventoryAdjustment,
      };

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
