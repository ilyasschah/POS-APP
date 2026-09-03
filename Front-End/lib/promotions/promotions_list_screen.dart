import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/core/ilyass_list_scaffold.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/promotions/promotion_provider.dart';
import 'package:pos_app/promotions/promotion_edit_screen.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/api/promotion_models.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/sync/sync_provider.dart';

/// Which promotions the list is narrowed to. Stored as a value rather than
/// three booleans so "what am I filtering on" has one answer.
enum _PromotionFilter { all, active, inactive, disabled }

class PromotionsListScreen extends ConsumerStatefulWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const PromotionsListScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<PromotionsListScreen> createState() =>
      _PromotionsListScreenState();
}

class _PromotionsListScreenState extends ConsumerState<PromotionsListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _PromotionFilter _filter = _PromotionFilter.all;

  /// Ticked rows, by promotion id.
  final Set<int> _selectedIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Selection is by id and survives filtering, so a row the filter hid would
  /// still be deleted by the ⋮ menu while showing as unselected.
  void _setFilter({String? query, _PromotionFilter? filter}) {
    setState(() {
      if (query != null) _query = query;
      if (filter != null) _filter = filter;
      _selectedIds.clear();
    });
  }

  String _formatDaysOfWeek(BuildContext context, int bitmask) {
    final l10n = AppLocalizations.of(context);
    if (bitmask == 0 || bitmask == 127) return l10n.everyDay;
    final days = l10n.weekdayAbbreviations.split(',');
    final activeDays = <String>[];
    for (int i = 0; i < 7; i++) {
      if ((bitmask & (1 << i)) != 0) activeDays.add(days[i]);
    }
    return activeDays.join(", ");
  }

  /// 🚨 Was hardcoded `yyyy-MM-dd`. ISO belongs in exports and file names, not
  /// on screen — a promotion's start and end dates are read by an operator, so
  /// they follow `Application.DateFormat` like every other displayed date.
  /// A promotion window is a calendar day, so no timezone conversion.
  String _formatDate(DateTime? date) =>
      date == null ? "-" : ref.read(appDateFormatProvider).day(date);

  /// Disabled (switched off), Active (live right now), or Inactive (enabled but
  /// outside its date / day / time window).
  (String, Color) _status(BuildContext context, PromotionDto p) {
    final l = AppLocalizations.of(context);
    if (!p.isEnabled) return (l.statusDisabled, context.dangerColor);
    if (isPromotionActiveNow(p)) return (l.statusActive, context.successColor);
    return (l.statusInactive, context.warningColor);
  }

  bool _matchesFilter(PromotionDto p) => switch (_filter) {
        _PromotionFilter.all => true,
        _PromotionFilter.disabled => !p.isEnabled,
        _PromotionFilter.active => p.isEnabled && isPromotionActiveNow(p),
        _PromotionFilter.inactive => p.isEnabled && !isPromotionActiveNow(p),
      };

  List<PromotionDto> _visible(List<PromotionDto> all) {
    final q = _query.trim().toLowerCase();
    return all
        .where((p) =>
            _matchesFilter(p) &&
            (q.isEmpty || p.name.toLowerCase().contains(q)))
        .toList();
  }

  // ── chrome ────────────────────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context) {
    final l = AppLocalizations.of(context);

    String label(_PromotionFilter f) => switch (f) {
          _PromotionFilter.all => l.filterAll,
          _PromotionFilter.active => l.statusActive,
          _PromotionFilter.inactive => l.statusInactive,
          _PromotionFilter.disabled => l.statusDisabled,
        };

    return UnifiedSearchBar(
      controller: _searchCtrl,
      singleLine: true,
      hintText: l.actionSearch,
      chips: [
        if (_filter != _PromotionFilter.all)
          SearchBarChip(
            id: 'status',
            label: label(_filter),
            icon: Icons.flag_outlined,
            onRemove: () => _setFilter(filter: _PromotionFilter.all),
          ),
      ],
      sectionsBuilder: (_) => [
        FilterMenuSection(
          title: l.statusLabel,
          icon: Icons.flag_outlined,
          options: [
            for (final f in _PromotionFilter.values)
              FilterMenuOption(
                label: label(f),
                selected: _filter == f,
                onSelected: () => _setFilter(filter: f),
              ),
          ],
        ),
      ],
      onQueryChanged: (v) => _setFilter(query: v),
      onClearAll: () {
        _searchCtrl.clear();
        _setFilter(query: '', filter: _PromotionFilter.all);
      },
    );
  }

  List<IlyassMenuAction> _menuActions(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasSelection = _selectedIds.isNotEmpty;

    return [
      IlyassMenuAction(
        icon: Icons.delete_outline_rounded,
        label: hasSelection
            ? l.deleteWithCount(_selectedIds.length)
            : l.actionDelete,
        color: hasSelection ? context.dangerColor : null,
        enabled: hasSelection,
        onSelected: _bulkDelete,
      ),
      IlyassMenuAction(
        icon: Icons.refresh,
        label: l.refresh,
        dividerBefore: true,
        // The list streams live from Drift, so it needs no provider refresh —
        // this pulls the latest from the server (best-effort) and the stream
        // reflects the new rows.
        onSelected: () async {
          final companyId = ref.read(selectedCompanyProvider)?.id;
          if (companyId == null) return;
          try {
            await ref.read(syncManagerProvider).pullPromotions(companyId);
          } catch (_) {
            // Offline — the local stream is already current.
          }
        },
      ),
    ];
  }

  // ── delete ────────────────────────────────────────────────────────────────

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final all = ref.read(allPromotionsProvider).value ?? const <PromotionDto>[];
    final targets = all.where((p) => _selectedIds.contains(p.id)).toList();
    if (targets.isEmpty) return;

    final l = AppLocalizations.of(context);
    // ONE confirmation for the batch — looping the per-row dialog would put
    // nine prompts in front of someone deleting nine rows.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(targets.length == 1
            ? l.deleteQuotedConfirm(targets.first.name)
            : l.deleteProductsConfirm(targets.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.actionCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.dangerColor,
              foregroundColor: ctx.onStatusColor,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;
    for (final promotion in targets) {
      await _delete(promotion, companyId);
    }
    if (mounted) setState(_selectedIds.clear);
  }

  Future<void> _delete(PromotionDto promotion, int companyId) async {
    final db = ref.read(appDatabaseProvider);

    if (promotion.isPendingCreate) {
      // Never reached the server — hard-delete locally.
      await (db.delete(db.promotionItemsTable)
            ..where((t) => t.promotionId.equals(promotion.id)))
          .go();
      await (db.delete(db.promotionsTable)
            ..where((t) => t.id.equals(promotion.id)))
          .go();
      return;
    }

    // Soft-delete: hidden by the provider filter immediately.
    await (db.update(db.promotionsTable)
          ..where((t) => t.id.equals(promotion.id)))
        .write(const PromotionsTableCompanion(
      syncStatus: Value('pending_delete'),
    ));
    // Try the API inline while online.
    try {
      await ApiClient().deletePromotion(companyId, promotion.id);
      await (db.delete(db.promotionItemsTable)
            ..where((t) => t.promotionId.equals(promotion.id)))
          .go();
      await (db.delete(db.promotionsTable)
            ..where((t) => t.id.equals(promotion.id)))
          .go();
    } catch (_) {
      // Offline — SyncManager's pushPendingPromotionOps retries.
    }
  }

  void _openEditor([PromotionDto? promotion]) {
    // No post-pop refresh needed: allPromotionsProvider streams live from Drift
    // and updates the instant the editor writes.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PromotionEditScreen(promotion: promotion),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final promotionsAsync = ref.watch(allPromotionsProvider);

    return IlyassListScaffold(
      title: l.promotions,
      onMenuPressed: widget.onMenuPressed,
      searchBar: _buildSearchBar(context),
      actions: _menuActions(context),
      fabLabel: l.addPromotion,
      onFabPressed: _openEditor,
      body: promotionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text(l.errorWithMessage(err.toString()))),
        data: (all) {
          final promotions = _visible(all);
          final selected =
              _selectedIds.intersection(promotions.map((p) => p.id).toSet());

          return IlyassTable<PromotionDto>(
            tableId: 'promotions',
            rows: promotions,
            rowHeight: 64,
            onRowTap: _openEditor,
            isRowSelected: (p) => selected.contains(p.id),
            // A switched-off promotion reads as switched off at a glance.
            rowColor: (p) => p.isEnabled
                ? null
                : theme.disabledColor.withValues(alpha: 0.05),
            columns: [
              ilyassSelectionColumn<PromotionDto, int>(
                rows: promotions,
                selected: selected,
                idOf: (p) => p.id,
                onChanged: (ids) => setState(() {
                  _selectedIds
                    ..clear()
                    ..addAll(ids);
                }),
              ),
              IlyassColumn<PromotionDto>(
                key: 'name',
                label: l.fieldName,
                width: 240,
                // The one column that absorbs surplus width — a promotion name
                // varies far more than a time does.
                flexible: true,
                cell: (context, p) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.isPendingSync)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: Icon(Icons.cloud_upload_outlined,
                            size: 16, color: theme.colorScheme.tertiary),
                      ),
                    Flexible(
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              IlyassColumn<PromotionDto>(
                key: 'status',
                label: l.statusLabel,
                width: 130,
                cell: (context, p) {
                  final (label, color) = _status(context, p);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  );
                },
              ),
              IlyassColumn<PromotionDto>(
                key: 'days',
                label: l.days,
                width: 170,
                cell: (context, p) => Text(
                  _formatDaysOfWeek(context, p.daysOfWeek),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IlyassColumn<PromotionDto>(
                key: 'startDate',
                label: l.startDate,
                width: 130,
                cell: (context, p) => Text(_formatDate(p.startDate)),
              ),
              IlyassColumn<PromotionDto>(
                key: 'startTime',
                label: l.startTime,
                width: 110,
                cell: (context, p) => Text(p.startTime ?? '-'),
              ),
              IlyassColumn<PromotionDto>(
                key: 'endDate',
                label: l.endDate,
                width: 130,
                cell: (context, p) => Text(_formatDate(p.endDate)),
              ),
              IlyassColumn<PromotionDto>(
                key: 'endTime',
                label: l.endTime,
                width: 110,
                cell: (context, p) => Text(p.endTime ?? '-'),
              ),
            ],
            emptyState: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_offer_outlined,
                        size: 64,
                        color: theme.disabledColor.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      all.isEmpty ? l.noPromotionsYet : l.noResultsForFilters,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.hintColor, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
