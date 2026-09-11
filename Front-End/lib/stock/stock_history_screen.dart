import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/core/app_date_picker.dart';
import 'package:pos_app/core/ilyass_column_order.dart';
import 'package:pos_app/core/ilyass_list_scaffold.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/stock/stock_move_labels.dart';
import 'package:pos_app/stock/stock_move_line.dart';
import 'package:pos_app/stock/stock_move_table.dart';
import 'package:pos_app/stock/stock_moves_columns.dart';
import 'package:pos_app/stock/stock_moves_export.dart';
import 'package:pos_app/stock/stock_moves_export_runner.dart';
import 'package:pos_app/stock/stock_moves_provider.dart';
import 'package:pos_app/stock/warehouse_model.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';

/// Stock Moves — the inventory history read the way Odoo reads it: every line
/// of every stock-moving document as goods travelling from one location to
/// another, newest first.
///
/// A projection of the local documents rather than a table of its own (see
/// `AppDatabase.watchStockMoves`), so it works offline, and a sale rung up on
/// this till is listed before it has synced — tagged Pending sync.
///
/// Rows can be ticked: Print, Save and Export then write exactly those; with
/// none ticked they write every move the filters match.
///
/// 🚨 There is no delete here, on purpose. A move IS a document line, so it
/// leaves this list exactly when its document is deleted, and never while the
/// document still stands — a history you could prune line by line would stop
/// being the record of what the documents did.
///
/// An Ilyass Screen hosted by the management shell under `Management.Stock`:
/// [onMenuPressed] comes from the shell, and there is no leave button.
class StockHistoryScreen extends ConsumerStatefulWidget {
  const StockHistoryScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  ConsumerState<StockHistoryScreen> createState() =>
      _StockHistoryScreenState();
}

class _StockHistoryScreenState extends ConsumerState<StockHistoryScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  /// The page the next one was last asked for from. A drag delivers a burst
  /// of scroll notifications before the provider has even begun reading, and
  /// each would otherwise ask again — 200 rows deeper per frame.
  StockMovePage? _askedMoreFrom;

  /// How close to the end of the loaded rows the next page is asked for —
  /// about fifteen rows, so it lands before the operator reaches the bottom.
  static const double _loadMoreExtent = 800;

  /// The rows ticked for printing or export, by line id.
  ///
  /// Only rows on screen can be ticked, and any filter change clears the lot:
  /// a selection the operator can no longer see is not one they meant to print.
  Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    // The filter outlives this State (the shell keeps it), so the field starts
    // from what the history is actually filtered by.
    _searchCtrl.text = ref.read(stockMovesFilterProvider).search;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  StockMovesFilterNotifier get _filter =>
      ref.read(stockMovesFilterProvider.notifier);

  /// Every filter change goes through here, so none can leave a stale
  /// selection behind.
  void _changeFilter(void Function(StockMovesFilterNotifier filter) change) {
    if (_selectedIds.isNotEmpty) setState(() => _selectedIds = {});
    change(_filter);
  }

  /// Debounced: each change re-runs the query and re-subscribes its stream.
  void _onQueryChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _changeFilter((f) => f.setSearch(query.trim()));
    });
  }

  /// Asks for the next page as the table nears its end.
  ///
  /// Vertical only — the table's horizontal scroll bubbles through here too.
  /// Asked at most once per page, and never while a read is in flight, or one
  /// drag would ask for several pages before the first of them had landed.
  bool _onScroll(ScrollNotification n, StockMovePage page, bool reading) {
    if (n.metrics.axis == Axis.vertical &&
        page.hasMore &&
        !reading &&
        !identical(page, _askedMoreFrom) &&
        n.metrics.extentAfter < _loadMoreExtent) {
      _askedMoreFrom = page;
      _filter.loadMore();
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
    final moves = ref.watch(stockMovesProvider);
    final filter = ref.watch(stockMovesFilterProvider);
    final visible = ref.watch(stockMoveVisibleColumnsProvider);
    final warehouses =
        ref.watch(allWarehousesProvider).value ?? const <Warehouse>[];
    final dates = ref.watch(appDateFormatProvider);

    // The last page stays on screen while the next one reads. A deeper page is
    // a new query, and swapping the table for a spinner meanwhile would throw
    // away its scroll position — the operator would land back at the top.
    final page = moves.value;
    final lines = page?.lines ?? const <StockMoveLine>[];

    // The ticked rows that are still on screen. A row that left — its document
    // deleted on another till, say — is neither counted nor printed.
    final selected = {
      for (final m in lines)
        if (_selectedIds.contains(m.itemLocalId)) m.itemLocalId,
    };

    return IlyassListScaffold(
      title: l.stockMoves,
      onMenuPressed: widget.onMenuPressed,
      searchBar: _searchBar(context, warehouses, filter, dates),
      actions: _menuActions(context, lines, selected, filter, warehouses),
      body: page == null
          ? (moves.hasError
              ? Center(child: Text(l.errorWithMessage('${moves.error}')))
              : const Center(child: CircularProgressIndicator()))
          : NotificationListener<ScrollNotification>(
              onNotification: (n) => _onScroll(n, page, moves.isLoading),
              child: IlyassTable<StockMoveLine>(
                tableId: kStockMovesTableId,
                rows: lines,
                // A tap anywhere on a row ticks it — a 64px checkbox is not
                // the only target a finger should have to find.
                onRowTap: (m) => _toggle(m.itemLocalId),
                isRowSelected: (m) => selected.contains(m.itemLocalId),
                columns: [
                  // Not in the picker's catalogue, so it stays leading whatever
                  // order the operator saves.
                  ilyassSelectionColumn<StockMoveLine, String>(
                    rows: lines,
                    selected: selected,
                    idOf: (m) => m.itemLocalId,
                    onChanged: (next) => setState(() => _selectedIds = next),
                  ),
                  // Hidden columns are filtered out here; the table applies the
                  // saved ORDER itself, from the same key the picker writes.
                  for (final column in stockMoveTableColumns(l, dates))
                    if (kStockMoveMandatoryColumns.contains(column.key) ||
                        (visible[column.key] ?? true))
                      column,
                ],
                emptyState: _emptyState(context, filter.isFiltered),
              ),
            ),
    );
  }

  // ── ⋮ actions ─────────────────────────────────────────────────────────────

  List<IlyassMenuAction> _menuActions(
    BuildContext context,
    List<StockMoveLine> onScreen,
    Set<String> selected,
    StockMovesFilter filter,
    List<Warehouse> warehouses,
  ) {
    final l = AppLocalizations.of(context);
    return [
      IlyassMenuAction(
        icon: Icons.refresh,
        label: l.syncAndRefresh,
        onSelected: _syncAndRefresh,
      ),
      IlyassMenuAction(
        icon: Icons.view_column_rounded,
        label: l.columns,
        dividerBefore: true,
        onSelected: () => _showColumnPicker(context),
      ),
      ...stockMovesExportActions(
        l,
        selectedCount: selected.length,
        onExport: (format) => runStockMovesExport(
          context: context,
          ref: ref,
          format: format,
          selected: selectedStockMoves(onScreen, selected),
          loadAll: (companyId) => ref.read(stockMovesExportLoaderProvider)(
            companyId: companyId,
            warehouseId: filter.warehouseId,
            search: filter.search,
            period: filter.period,
          ),
          columns: visibleStockMoveColumns(
            ref.read(stockMoveVisibleColumnsProvider),
            ref.read(ilyassColumnOrderProvider)[kStockMovesTableId] ??
                const <String>[],
          ),
          warehouseName: warehouses
              .where((w) => w.id == filter.warehouseId)
              .firstOrNull
              ?.name,
          search: filter.search,
          period: filter.period,
        ),
      ),
    ];
  }

  /// Pulls the cloud into this terminal's database.
  ///
  /// A MANUAL sync on purpose: only that one reconciles deletions, so a
  /// document deleted on another till — and with it its moves — leaves this
  /// list now rather than on the next six-hourly pass. Nothing to invalidate
  /// afterwards: the history is a Drift stream, and every row the sync writes
  /// re-emits it. A failure surfaces through the sync state's own snackbar.
  void _syncAndRefresh() {
    ref.read(syncStateProvider.notifier).sync(manual: true).catchError((_) {});
  }

  void _showColumnPicker(BuildContext context) {
    final l = AppLocalizations.of(context);
    showIlyassColumnPicker(
      context: context,
      tableId: kStockMovesTableId,
      columns: [
        for (final key in kStockMoveColumns)
          IlyassPickerColumn(
            key: key,
            label: stockMoveColumnLabel(l, key),
            mandatory: kStockMoveMandatoryColumns.contains(key),
          ),
      ],
      isVisible: (key) => ref.read(stockMoveVisibleColumnsProvider)[key] ?? true,
      onVisibleChanged: (key, value) => ref
          .read(stockMoveVisibleColumnsProvider.notifier)
          .setVisible(key, value),
      onReset: () => ref.read(stockMoveVisibleColumnsProvider.notifier).reset(),
    );
  }

  // ── search & filters ──────────────────────────────────────────────────────

  Future<void> _pickPeriod(StockMovesFilter filter) async {
    final now = DateTime.now();
    final range = await showAppDateRangePicker(
      context,
      initialStart: filter.period?.start ?? DateTime(now.year, now.month, 1),
      initialEnd: filter.period?.end ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (range == null || !mounted) return;
    _changeFilter((f) => f.setPeriod(range));
  }

  Widget _searchBar(
    BuildContext context,
    List<Warehouse> warehouses,
    StockMovesFilter filter,
    AppDateFormat dates,
  ) {
    final l = AppLocalizations.of(context);
    final warehouse =
        warehouses.where((w) => w.id == filter.warehouseId).firstOrNull;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonth = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
    final lastMonth = DateTimeRange(
      start: DateTime(now.year, now.month - 1, 1),
      end: DateTime(now.year, now.month, 0),
    );
    FilterMenuOption periodOption(
            String label, DateTimeRange range, IconData icon) =>
        FilterMenuOption(
          label: label,
          icon: icon,
          selected: filter.period == range,
          onSelected: () => _changeFilter((f) => f.setPeriod(range)),
        );

    return UnifiedSearchBar(
      controller: _searchCtrl,
      singleLine: true,
      hintText: l.searchStockMoves,
      onQueryChanged: _onQueryChanged,
      onClearAll: () {
        _searchDebounce?.cancel();
        _searchCtrl.clear();
        _changeFilter((f) => f.clear());
      },
      chips: [
        if (filter.period != null)
          SearchBarChip(
            id: 'period',
            label: stockPeriodLabel(dates, filter.period!),
            icon: Icons.date_range_outlined,
            onRemove: () => _changeFilter((f) => f.setPeriod(null)),
          ),
        if (warehouse != null)
          SearchBarChip(
            id: 'warehouse',
            label: warehouse.name,
            icon: Icons.warehouse_outlined,
            onRemove: () => _changeFilter((f) => f.setWarehouse(null)),
          ),
      ],
      sectionsBuilder: (_) => [
        FilterMenuSection(
          title: l.periodLabel,
          icon: Icons.date_range_outlined,
          options: [
            periodOption(l.today, DateTimeRange(start: today, end: today),
                Icons.today_outlined),
            periodOption(l.thisMonth, thisMonth, Icons.date_range_outlined),
            periodOption(l.lastMonth, lastMonth, Icons.date_range_outlined),
            FilterMenuOption(
              label: l.filterCustomRange,
              icon: Icons.edit_calendar_outlined,
              onSelected: () => _pickPeriod(filter),
            ),
          ],
        ),
        if (warehouses.isNotEmpty)
          FilterMenuSection(
            title: l.warehouse,
            icon: Icons.warehouse_outlined,
            options: [
              FilterMenuOption(
                label: l.allWarehouses,
                selected: filter.warehouseId == null,
                onSelected: () => _changeFilter((f) => f.setWarehouse(null)),
              ),
              for (final w in warehouses)
                FilterMenuOption(
                  label: w.name,
                  selected: w.id == filter.warehouseId,
                  onSelected: () => _changeFilter((f) => f.setWarehouse(w.id)),
                ),
            ],
          ),
      ],
    );
  }

  Widget _emptyState(BuildContext context, bool filtered) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz,
                size: 64, color: theme.disabledColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              filtered ? l.noResultsForFilters : l.noStockMoves,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.hintColor, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
