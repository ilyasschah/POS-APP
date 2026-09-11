import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/core/ilyass_column_order.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/settings/settings_provider.dart';

/// The Stock Moves table's id — it keys the column widths, the saved column
/// order, and so the export that follows both.
const String kStockMovesTableId = 'stock_moves';

/// Every column the Stock Moves table can show, in the order it declares them.
///
/// 🚨 These keys are identities: they key the widths, the saved order and the
/// saved visibility, so they are never translated — [stockMoveColumnLabel] is.
///
/// Odoo's Moves History set. There is no Done By column: who made a move only
/// changes how it reads for an inventory adjustment, and there it is part of
/// the reference — `Product Quantity Updated (Alice)`.
const List<String> kStockMoveColumns = [
  'date',
  'reference',
  'product',
  'from',
  'to',
  'quantity',
  'status',
];

/// The product is what makes a row mean anything; it cannot be switched off.
const Set<String> kStockMoveMandatoryColumns = {'product'};

String stockMoveColumnLabel(AppLocalizations l, String key) => switch (key) {
      'date' => l.colDate,
      'reference' => l.colReference,
      'product' => l.colProduct,
      'from' => l.colFrom,
      'to' => l.colTo,
      'quantity' => l.colQuantity,
      'status' => l.colStatus,
      'doneBy' => l.colDoneBy,
      _ => key,
    };

/// The columns the operator sees, in the order they see them.
///
/// What the table renders and — deliberately — exactly what an export writes:
/// a sheet that brings back a column the operator hid, or puts them in another
/// order, is not the report they were looking at.
List<String> visibleStockMoveColumns(
  Map<String, bool> visible,
  List<String> order,
) =>
    ilyassApplyColumnOrder(
      [
        for (final key in kStockMoveColumns)
          if (kStockMoveMandatoryColumns.contains(key) || (visible[key] ?? true))
            key,
      ],
      order,
      (key) => key,
    );

const String _kPrefsKey = 'stockMoves.visibleColumns';

/// Which Stock Moves columns this terminal shows, persisted on the device.
///
/// Device-local like every other grid's: which columns a 10-inch tablet shows
/// is a property of that screen, not company data. The ORDER lives beside it in
/// `ilyassColumnOrderProvider`, which the column picker writes.
final stockMoveVisibleColumnsProvider =
    NotifierProvider<StockMoveVisibleColumnsNotifier, Map<String, bool>>(
        StockMoveVisibleColumnsNotifier.new);

class StockMoveVisibleColumnsNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    final result = _defaults();
    try {
      final raw = ref.read(sharedPreferencesProvider).getString(_kPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        final stored = (jsonDecode(raw) as Map).cast<String, dynamic>();
        // Merged over the defaults: a column added in a later version shows,
        // and a mandatory one stays on whatever was stored.
        for (final key in kStockMoveColumns) {
          if (kStockMoveMandatoryColumns.contains(key)) continue;
          if (stored[key] is bool) result[key] = stored[key] as bool;
        }
      }
    } catch (_) {
      // No store (a test, a preview) or a corrupt blob — the defaults stand.
    }
    return result;
  }

  static Map<String, bool> _defaults() =>
      {for (final key in kStockMoveColumns) key: true};

  void setVisible(String key, bool visible) {
    if (!kStockMoveColumns.contains(key) ||
        kStockMoveMandatoryColumns.contains(key)) {
      return;
    }
    state = {...state, key: visible};
    try {
      ref
          .read(sharedPreferencesProvider)
          .setString(_kPrefsKey, jsonEncode(state));
    } catch (_) {
      // Holds for this sitting.
    }
  }

  void reset() {
    state = _defaults();
    try {
      ref.read(sharedPreferencesProvider).remove(_kPrefsKey);
    } catch (_) {
      // Nothing to forget.
    }
  }
}
