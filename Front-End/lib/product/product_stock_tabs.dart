import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/core/app_date_picker.dart';
import 'package:pos_app/core/ilyass_form.dart';
import 'package:pos_app/core/ilyass_list_scaffold.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/product/product_model.dart';
import 'package:pos_app/stock/stock_control_model.dart';
import 'package:pos_app/stock/stock_control_provider.dart';
import 'package:pos_app/stock/stock_move_labels.dart';
import 'package:pos_app/stock/stock_move_line.dart';
import 'package:pos_app/stock/stock_move_table.dart';
import 'package:pos_app/stock/stock_moves_export.dart';
import 'package:pos_app/stock/stock_moves_export_runner.dart';
import 'package:pos_app/stock/stock_moves_provider.dart';
import 'package:pos_app/stock/stock_provider.dart';
import 'package:pos_app/stock/warehouse_model.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

/// The product editor's two stock tabs, beside Barcodes.
///
/// Widgets of their own rather than builder methods on the editor: a builder
/// runs whenever the editor builds, so its streams would open the moment the
/// dialog did. As widgets they are built only when their tab is shown.

/// **Stock** — what every warehouse holds of this product, and the rules that
/// watch it.
///
/// Every warehouse is listed, one holding no stock row for the product
/// included: shown as Unassigned, never left out (the stock UI lists all).
/// Quantities are in the product's STOCK unit — the one stock is held in, and
/// the one its rules' thresholds are set in.
class ProductStockTab extends ConsumerWidget {
  const ProductStockTab({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final warehouses =
        ref.watch(allWarehousesProvider).value ?? const <Warehouse>[];
    final held = ref.watch(stockByWarehouseProvider).value?[product.id] ??
        const <int, double>{};
    final rule = ref.watch(stockControlByProductIdProvider(product.id)).value;
    final unitId = product.stockUom.id;
    final total = held.values.fold<double>(0, (sum, q) => sum + q);
    final listed = {for (final w in warehouses) w.id};

    return IlyassTabBody(
      children: [
        IlyassFormSection(
          icon: Icons.inventory_2_outlined,
          title: l.stockOnHand,
          subtitle: l.stockOnHandHint,
          child: Column(
            children: [
              for (final w in warehouses)
                _QuantityRow(label: w.name, quantity: held[w.id], unitId: unitId),
              // Stock in a warehouse this till no longer lists (deleted on
              // another) still counts toward the total, so it is shown too.
              for (final entry in held.entries)
                if (!listed.contains(entry.key))
                  _QuantityRow(
                      label: '#${entry.key}',
                      quantity: entry.value,
                      unitId: unitId),
              const Divider(height: 24),
              _QuantityRow(
                label: l.totalLabel,
                quantity: total,
                unitId: unitId,
                emphasised: true,
              ),
            ],
          ),
        ),
        IlyassFormSection(
          icon: Icons.rule_outlined,
          title: l.stockControlRules,
          child: rule == null
              ? Text(
                  l.noStockRuleSet,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                )
              : _Rules(rule: rule, onHand: total, unitId: unitId),
        ),
      ],
    );
  }
}

/// The rule's thresholds, and where the stock on hand sits against them.
class _Rules extends StatelessWidget {
  const _Rules({required this.rule, required this.onHand, required this.unitId});

  final StockControl rule;
  final double onHand;
  final int unitId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // A threshold of 0 is "not set", not "zero" — shown as a dash.
    String threshold(double value) =>
        value > 0 ? formatQuantity(value, unitId) : '—';

    final (status, color, icon) = rule.isLowStockAt(onHand)
        ? (l.stockStatusLow, context.dangerColor, Icons.error_outline)
        : rule.needsReorderAt(onHand)
            ? (l.stockStatusReorder, context.warningColor, Icons.replay)
            : (l.stockStatusHealthy, context.successColor,
                Icons.check_circle_outline);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                status,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ValueRow(label: l.reorderPoint, value: threshold(rule.reorderPoint)),
        _ValueRow(
            label: l.preferredQuantity,
            value: threshold(rule.preferredQuantity)),
        _ValueRow(
          label: l.lowStockWarning,
          value: rule.isLowStockWarningEnabled
              ? threshold(rule.lowStockWarningQuantity)
              : '—',
        ),
      ],
    );
  }
}

/// One warehouse's stock, label hard left and figure hard right (Ilyass Style
/// §1). A warehouse with no stock row reads Unassigned rather than a
/// fabricated 0 — nothing was ever put there.
class _QuantityRow extends StatelessWidget {
  const _QuantityRow({
    required this.label,
    required this.quantity,
    required this.unitId,
    this.emphasised = false,
  });

  final String label;
  final double? quantity;
  final int unitId;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final q = quantity;
    return _ValueRow(
      label: label,
      value: q == null ? l.unassigned : formatQuantity(q, unitId),
      valueColor: (q == null || q < 0) ? context.dangerColor : null,
      emphasised: emphasised,
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final weight = emphasised ? FontWeight.bold : FontWeight.w500;
    return Padding(
      // Finger-spaced: this list is read on a 10-inch tablet at arm's length.
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 3,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: weight)),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: weight,
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The columns of a product's own history — Odoo's Moves History set, the
/// same as the Stock Moves screen's, so a product's story reads the same in
/// both places and exports the same way.
const List<String> kProductStockHistoryColumns = [
  'date',
  'reference',
  'product',
  'from',
  'to',
  'quantity',
  'status',
];

/// **Stock History** — this product's moves, newest first, over a period the
/// app's own range picker chooses: the Stock Moves table narrowed to one
/// product, with the same ticks and the same Print / Save / Export.
class ProductStockHistoryTab extends ConsumerStatefulWidget {
  const ProductStockHistoryTab({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ProductStockHistoryTab> createState() =>
      _ProductStockHistoryTabState();
}

class _ProductStockHistoryTabState
    extends ConsumerState<ProductStockHistoryTab> {
  DateTimeRange? _period;
  int _limit = StockMovesFilter.pageSize;

  /// The last page read, kept on screen while a deeper one reads — a deeper
  /// page is a new query, and blanking the table for it would lose the scroll.
  StockMovePage? _shown;
  StockMovePage? _askedMoreFrom;

  /// Ticked rows, by line id — cleared with every change of period.
  Set<String> _selectedIds = {};

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final range = await showAppDateRangePicker(
      context,
      initialStart: _period?.start ?? DateTime(now.year, now.month, 1),
      initialEnd: _period?.end ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (range == null || !mounted) return;
    _setPeriod(range);
  }

  /// A new period is a new result set: read it from the top, never show the
  /// old period's rows while it loads, and let go of the old ticks.
  void _setPeriod(DateTimeRange? period) => setState(() {
        _period = period;
        _limit = StockMovesFilter.pageSize;
        _shown = null;
        _selectedIds = {};
      });

  bool _onScroll(ScrollNotification n, StockMovePage page, bool reading) {
    if (n.metrics.axis == Axis.vertical &&
        page.hasMore &&
        !reading &&
        !identical(page, _askedMoreFrom) &&
        n.metrics.extentAfter < 600) {
      _askedMoreFrom = page;
      setState(() => _limit += StockMovesFilter.pageSize);
    }
    return false;
  }

  void _toggle(String id) => setState(() {
        _selectedIds = _selectedIds.contains(id)
            ? ({..._selectedIds}..remove(id))
            : {..._selectedIds, id};
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = ref.watch(appDateFormatProvider);
    final moves = ref.watch(productStockMovesProvider(
        (productId: widget.product.id, period: _period, limit: _limit)));
    final page = moves.value ?? _shown;
    if (moves.value != null) _shown = moves.value;

    final lines = page?.lines ?? const <StockMoveLine>[];
    final selected = {
      for (final m in lines)
        if (_selectedIds.contains(m.itemLocalId)) m.itemLocalId,
    };

    return Container(
      margin: const EdgeInsets.all(kIlyassTabPadding),
      padding: kIlyassSectionInsets,
      decoration: ilyassSectionDecoration(theme.colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IlyassSectionHeader(
            icon: Icons.history,
            title: l.stockHistoryTab,
            subtitle: l.stockHistoryHint,
            actions: [
              OutlinedButton.icon(
                // Finger-sized: the header bar's main control.
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(_period == null
                    ? l.periodAllTime
                    : stockPeriodLabel(dates, _period!)),
                onPressed: _pickPeriod,
              ),
              if (_period != null)
                IconButton(
                  tooltip: l.periodAllTime,
                  icon: const Icon(Icons.close),
                  onPressed: () => _setPeriod(null),
                ),
              IlyassActionsMenu(
                actions: stockMovesExportActions(
                  l,
                  selectedCount: selected.length,
                  dividerBefore: false,
                  onExport: (format) => runStockMovesExport(
                    context: context,
                    ref: ref,
                    format: format,
                    selected: selectedStockMoves(lines, selected),
                    loadAll: (companyId) =>
                        ref.read(stockMovesExportLoaderProvider)(
                      companyId: companyId,
                      productId: widget.product.id,
                      period: _period,
                    ),
                    columns: kProductStockHistoryColumns,
                    search: widget.product.name,
                    period: _period,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: page == null
                ? (moves.hasError
                    ? Center(child: Text(l.errorWithMessage('${moves.error}')))
                    : const Center(child: CircularProgressIndicator()))
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) =>
                        _onScroll(n, page, moves.isLoading),
                    child: IlyassTable<StockMoveLine>(
                      tableId: 'product_stock_moves',
                      rows: lines,
                      onRowTap: (m) => _toggle(m.itemLocalId),
                      isRowSelected: (m) => selected.contains(m.itemLocalId),
                      columns: [
                        ilyassSelectionColumn<StockMoveLine, String>(
                          rows: lines,
                          selected: selected,
                          idOf: (m) => m.itemLocalId,
                          onChanged: (next) =>
                              setState(() => _selectedIds = next),
                        ),
                        for (final column in stockMoveTableColumns(l, dates))
                          if (kProductStockHistoryColumns.contains(column.key))
                            column,
                      ],
                      emptyState: Center(
                        child: Text(
                          _period == null
                              ? l.noStockMoves
                              : l.noResultsForFilters,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.hintColor),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
