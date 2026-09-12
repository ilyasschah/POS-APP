import 'package:flutter/material.dart';

import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/stock/stock_move_labels.dart';
import 'package:pos_app/stock/stock_move_line.dart';
import 'package:pos_app/product/product_visuals.dart';
import 'package:pos_app/stock/stock_moves_columns.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

/// The columns of a table of stock moves — ONE definition for every such
/// table, so the Stock Moves screen and a product's own Stock History tab can
/// never draw the same move two different ways.
///
/// Drawn the way Odoo's Moves History reads: the document number in the
/// accent colour, an inventory adjustment named `Product Quantity Updated
/// (…)` in amber so a correction stands out from the trade around it, the
/// virtual locations muted against the warehouse they feed, and the quantity
/// coloured by which way it crossed the wall.
///
/// All of [kStockMoveColumns], in declared order; a caller drops the ones it
/// hides. The product name takes the surplus width (Ilyass Style §4).
List<IlyassColumn<StockMoveLine>> stockMoveTableColumns(
  AppLocalizations l,
  AppDateFormat dates,
) {
  return [
    IlyassColumn<StockMoveLine>(
      key: 'date',
      label: stockMoveColumnLabel(l, 'date'),
      width: 150,
      cell: (context, m) => Text(stockMoveDateLabel(l, dates, m.date),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    IlyassColumn<StockMoveLine>(
      key: 'reference',
      label: stockMoveColumnLabel(l, 'reference'),
      // Wide enough for `Product Quantity Updated (Gérant)` unclipped.
      width: 280,
      cell: (context, m) => StockMoveReference(move: m),
    ),
    IlyassColumn<StockMoveLine>(
      key: 'product',
      label: stockMoveColumnLabel(l, 'product'),
      width: 220,
      flexible: true,
      cell: (context, m) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The glyph, never the photo — moves are read by name. And always
          // the PRODUCT glyph: the history query leaves services out, since
          // they move no goods (`COALESCE(p.is_service, 0) = 0`).
          CircleAvatar(
            radius: 12,
            child: Icon(productPlaceholderIcon(isService: false), size: 13),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              stockMoveProductLabel(m),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
    IlyassColumn<StockMoveLine>(
      key: 'from',
      label: stockMoveColumnLabel(l, 'from'),
      width: 190,
      cell: (context, m) =>
          StockMoveLocation(kind: m.from, warehouseName: m.warehouseName),
    ),
    IlyassColumn<StockMoveLine>(
      key: 'to',
      label: stockMoveColumnLabel(l, 'to'),
      width: 190,
      cell: (context, m) =>
          StockMoveLocation(kind: m.to, warehouseName: m.warehouseName),
    ),
    IlyassColumn<StockMoveLine>(
      key: 'quantity',
      label: stockMoveColumnLabel(l, 'quantity'),
      width: 130,
      numeric: true,
      cell: (context, m) => StockMoveQuantity(move: m),
    ),
    IlyassColumn<StockMoveLine>(
      key: 'status',
      label: stockMoveColumnLabel(l, 'status'),
      width: 140,
      cell: (context, m) => StockMoveStatusBadge(status: m.status),
    ),
  ];
}

/// Where a move came from: the document number in the accent colour, or —
/// for an inventory adjustment — `Product Quantity Updated (…)` in amber,
/// since it corrects the stock rather than trading it.
class StockMoveReference extends StatelessWidget {
  const StockMoveReference({super.key, required this.move});

  final StockMoveLine move;

  @override
  Widget build(BuildContext context) {
    final color = isStockAdjustment(move)
        ? context.warningColor
        : Theme.of(context).colorScheme.primary;
    return Text(
      stockMoveReferenceLabel(AppLocalizations.of(context), move),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

/// A location's name. The warehouse — where stock actually sits — reads at
/// full strength; the virtual ends (Vendors, Customers, Inventory adjustment,
/// Scrap) are muted, so the eye finds the warehouse side of every move.
class StockMoveLocation extends StatelessWidget {
  const StockMoveLocation({
    super.key,
    required this.kind,
    required this.warehouseName,
  });

  final StockLocationKind kind;
  final String? warehouseName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      stockLocationLabel(AppLocalizations.of(context), kind, warehouseName),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: kind == StockLocationKind.warehouse
            ? cs.onSurface
            : cs.onSurfaceVariant,
      ),
    );
  }
}

/// The moved quantity, coloured by which way it crossed the warehouse wall:
/// green in, red out. No sign on screen — From and To already say which way,
/// and the colour carries it at a glance. (Paper keeps the sign; see
/// `stockMoveQuantityLabel`.)
class StockMoveQuantity extends StatelessWidget {
  const StockMoveQuantity({super.key, required this.move});

  final StockMoveLine move;

  @override
  Widget build(BuildContext context) {
    final color = move.isIncoming ? context.successColor : context.dangerColor;
    return Text(
      formatQuantity(move.quantity, move.uomId),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        // A column of quantities is read by its last digits.
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// A rounded, solid status pill: green once the server has the move, amber
/// while it only exists on this terminal.
///
/// The text takes the theme's surface colour: each status colour is tuned to
/// stand out against that surface in its theme (dark green on light, light
/// green on dark), so the surface colour is what reads on top of it in both.
class StockMoveStatusBadge extends StatelessWidget {
  const StockMoveStatusBadge({super.key, required this.status});

  final StockMoveStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      StockMoveStatus.done => context.successColor,
      StockMoveStatus.pendingSync => context.warningColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        stockMoveStatusLabel(AppLocalizations.of(context), status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.surface,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
