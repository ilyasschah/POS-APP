// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as imgpath;
import 'package:path_provider/path_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/uom/unit_of_measure.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/product/product_group_provider.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/product/product_model.dart';
import 'package:pos_app/product/product_columns_provider.dart';
import 'package:pos_app/product/catalog_export.dart';
import 'package:pos_app/product/product_group_model.dart';
import 'package:pos_app/product/product_provider.dart';
import 'package:pos_app/product/product_sort.dart';
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';
import 'package:pos_app/core/responsive.dart';
import 'package:pos_app/core/ilyass_form.dart';
import 'package:pos_app/core/ilyass_column_order.dart';
import 'package:pos_app/core/ilyass_list_scaffold.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/modifier/modifier_models.dart';
import 'package:pos_app/modifier/modifier_groups_screen.dart'
    show selectionRuleLabel;
import 'package:pos_app/modifier/modifier_provider.dart';
import 'package:pos_app/sync/sync_provider.dart';
import 'package:pos_app/barcode/barcode_provider.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rules_provider.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rule.dart';
import 'package:pos_app/barcode/nomenclature/barcode_matcher.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/product/product_import_screen.dart';
import 'package:pos_app/product/product_search.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:uuid/uuid.dart';

// --- HELPER ---
String _parseApiError(BuildContext context, dynamic e) {
  if (e is DioException && e.response?.data != null) {
    final data = e.response!.data;
    if (data is Map && data.containsKey('message')) {
      return data['message'].toString();
    }
    if (data is String && !data.contains('<html') && data.length < 150) {
      return data;
    }
  }
  return AppLocalizations.of(context).serverErrorCheckInputs;
}

/// The product editor's description field. It has no floating label — the
/// DESCRIPTION section header above it names it — so the E2E helpers find it
/// by this key, an untranslated handle, rather than by a label.
const kProductDescriptionFieldKey = ValueKey('product-description');

// --- MAIN SCREEN ---
class ProductsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onMenuPressed;
  const ProductsScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final Set<int> _selectedIds = {};

  // Search state is LOCAL, not a provider: leaving the screen must clear the
  // filter. A global provider would have the admin come back to a silently
  // filtered catalogue and read it as missing products. It is also separate
  // from the POS menu's `searchQueryProvider` on purpose — the two screens are
  // used at the same time on the same terminal.
  //
  // It lives on the SCREEN rather than on the table because the bar now sits
  // in the header, above every `when` branch: an operator whose query matched
  // nothing must still have the box they just typed into in front of them.
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Defaults to the widest scope. Unlike the POS menu this is NOT driven by
  // `Menu.DefaultSearch`: that setting is about the cashier's till, and an admin
  // hunting for a product should not have to guess which field it lives in.
  String _scope = ProductSearchScope.allFields;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _updateSelection(Set<int> ids) {
    setState(() {
      _selectedIds.clear();
      _selectedIds.addAll(ids);
    });
  }

  /// Selection is by id and survives filtering, so a row hidden by the search
  /// would still be deleted by the Actions menu's Delete while showing as
  /// unselected. Clearing on every filter change is the same rule the category
  /// filter follows.
  void _setFilter({String? query, String? scope}) {
    setState(() {
      if (query != null) _query = query;
      if (scope != null) _scope = scope;
      _selectedIds.clear();
    });
  }

  /// The category filter is the same provider the removed sidebar drove, so
  /// `productsByGroupProvider` still does the filtering in Drift rather than in
  /// the widget — only the control that sets it has moved into the search bar.
  void _setCategory(int? groupId) {
    ref.read(selectedProductGroupIdProvider.notifier).state = groupId;
    if (_selectedIds.isNotEmpty) setState(() => _selectedIds.clear());
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final products = ref.read(productsByGroupProvider).value ?? [];
    final effectiveIds = _selectedIds.intersection(
      products.map((p) => p.id).toSet(),
    );
    if (effectiveIds.isEmpty) return;

    final count = effectiveIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteProducts),
        content: Text(
          AppLocalizations.of(context).deleteProductsConfirm(count),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).actionCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ctx.dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppLocalizations.of(context).actionDelete,
              style: TextStyle(color: ctx.onStatusColor),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final db = ref.read(appDatabaseProvider);
    int deleted = 0;
    final blocked = <int>{}; // referenced by an order/document → cannot delete

    for (final id in effectiveIds) {
      if (id < 0) {
        // Temp product never reached the server — hard-delete locally.
        await (db.delete(db.productsTable)..where((t) => t.id.equals(id))).go();
      } else {
        // Pre-flight: mirror the server rule. A product linked to any order or
        // document line can't be deleted server-side, so deleting it locally
        // would only get reverted on the next sync (the row reappears). Refuse
        // up front instead of showing a false "deleted" then un-deleting.
        if (await _isProductReferenced(db, id)) {
          blocked.add(id);
          continue;
        }
        // Real server product — soft-delete so SyncManager can push the
        // DELETE to the server on the next sync.
        await (db.update(
          db.productsTable,
        )..where((t) => t.id.equals(id))).write(
          ProductsTableCompanion(
            syncStatus: const Value('pending_delete'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
      }
      deleted++;
    }

    // Fire sync in the background so online deletes propagate immediately.
    if (deleted > 0) {
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
    }

    if (mounted) {
      // Keep blocked products selected so the user sees what wasn't deleted.
      setState(
        () => _selectedIds
          ..clear()
          ..addAll(blocked),
      );
      if (blocked.isNotEmpty) {
        final n = blocked.length;
        showAppSnackbar(
          context,
          ref,
          deleted > 0
              ? AppLocalizations.of(
                  context,
                ).deletedSomeProductsBlocked(deleted, n)
              : AppLocalizations.of(context).cannotDeleteProductsLinked(n),
          isError: true,
        );
      } else {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).productsDeletedCount(deleted),
        );
      }
    }
  }

  /// Returns true if [productId] is referenced by any local order line or
  /// document line — the same constraint the backend enforces on delete.
  Future<bool> _isProductReferenced(AppDatabase db, int productId) async {
    final inOrder =
        await (db.select(db.posOrderItemsTable)
              ..where((t) => t.productId.equals(productId))
              ..limit(1))
            .getSingleOrNull();
    if (inOrder != null) return true;
    final inDoc =
        await (db.select(db.documentItemsTable)
              ..where((t) => t.productId.equals(productId))
              ..limit(1))
            .getSingleOrNull();
    return inDoc != null;
  }

  void _showColumnPicker(BuildContext context) {
    final notifier = ref.read(productVisibleColumnsProvider.notifier);
    showIlyassColumnPicker(
      context: context,
      // Same id the table registers under, so the picker and the grid are
      // talking about one layout.
      tableId: 'products',
      columns: [
        for (final col in kProductColumns)
          IlyassPickerColumn(
            key: col.key,
            label: productColumnLabel(context, col.key),
            // Name stays locked on — and stays draggable.
            mandatory: col.mandatory,
          ),
      ],
      isVisible: (key) => ref.read(productVisibleColumnsProvider)[key] ?? false,
      onVisibleChanged: notifier.setVisible,
      onReset: notifier.resetToDefaults,
    );
  }

  void _openImport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductImportScreen()),
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(productsByGroupProvider);
      });
    });
  }

  /// Two-phase create: taxes, barcodes and stock all need a REAL server id, so
  /// phase 2 only opens for a product that actually reached the server.
  Future<void> _addProduct() async {
    final result = await showDialog(
      context: context,
      builder: (_) => const _ProductEditorDialog(isPostCreation: false),
    );
    ref.invalidate(productsByGroupProvider);
    if (result is Product && mounted) {
      if (result.isPendingCreate) {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).productSavedLocallySyncFirst,
        );
      } else {
        showDialog(
          context: context,
          builder: (_) => _ProductEditorDialog(
            existingProduct: result,
            isPostCreation: true,
          ),
        ).then((_) => ref.invalidate(productsByGroupProvider));
      }
    }
  }

  // ── header ────────────────────────────────────────────────────────────────

  /// The unified bar, in the header rather than the body: the table is the
  /// screen now, and a search row stacked above it cost a full strip of height
  /// on a 10" tablet for a control that is one field tall.
  Widget _buildSearchBar(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groups =
        ref.watch(allProductGroupsProvider).value ?? const <ProductGroup>[];
    final selectedGroupId = ref.watch(selectedProductGroupIdProvider);
    final selectedGroup = groups
        .where((g) => g.id == selectedGroupId)
        .firstOrNull;

    return UnifiedSearchBar(
      controller: _searchCtrl,
      // The bar lives in a fixed-height toolbar, so chips share the row with
      // the field instead of wrapping onto a second one it has no room for.
      singleLine: true,
      hintText: l.searchProductsHint,
      chips: [
        if (selectedGroupId != null)
          SearchBarChip(
            id: 'category',
            label: selectedGroup?.name ?? l.categoryLabel,
            icon: Icons.folder_outlined,
            onRemove: () => _setCategory(null),
          ),
      ],
      sectionsBuilder: (query) => _filterSections(context, query, groups),
      onQueryChanged: (v) => _setFilter(query: v),
      onClearAll: () {
        _searchCtrl.clear();
        _setFilter(query: '');
        _setCategory(null);
      },
      trailing: _buildScopeToggles(context),
    );
  }

  /// The category dropdown, as an inline filter section rather than a control
  /// of its own — the same shape Documents and Sales History use, so one chip
  /// in the bar says what the catalogue is narrowed to.
  List<FilterMenuSection> _filterSections(
    BuildContext context,
    String query,
    List<ProductGroup> groups,
  ) {
    final l = AppLocalizations.of(context);
    final lower = query.trim().toLowerCase();
    final selectedGroupId = ref.read(selectedProductGroupIdProvider);

    // Capped so a catalogue with 300 categories still opens the menu instantly;
    // typing narrows it, which is what the footnote tells the operator.
    const maxOptions = 8;
    final flat = _flattenGroups(groups);
    final matched = lower.isEmpty
        ? flat
        : flat.where((e) => e.$1.name.toLowerCase().contains(lower)).toList();

    return [
      FilterMenuSection(
        title: l.categoryLabel,
        icon: Icons.folder_outlined,
        footnote: matched.length > maxOptions ? l.filterKeepTyping : null,
        options: [
          FilterMenuOption(
            label: l.allProducts,
            icon: Icons.all_inbox,
            selected: selectedGroupId == null,
            onSelected: () => _setCategory(null),
          ),
          for (final (group, depth) in matched.take(maxOptions))
            FilterMenuOption(
              // Indented rather than flattened: a child category called
              // "Small" means nothing without the parent above it.
              label: '${'    ' * depth}${group.name}',
              icon: depth == 0
                  ? Icons.folder_outlined
                  : Icons.subdirectory_arrow_right,
              selected: selectedGroupId == group.id,
              onSelected: () => _setCategory(group.id),
            ),
        ],
      ),
    ];
  }

  /// Depth-first walk of the category tree, roots first and each level by rank
  /// — the order the removed sidebar rendered, kept so the menu reads the way
  /// the tree did.
  List<(ProductGroup, int)> _flattenGroups(List<ProductGroup> all) {
    final byParent = <int?, List<ProductGroup>>{};
    for (final g in all) {
      (byParent[g.parentGroupId] ??= []).add(g);
    }
    for (final list in byParent.values) {
      list.sort((a, b) => a.rank.compareTo(b.rank));
    }

    final out = <(ProductGroup, int)>[];
    // A group whose parent chain loops back on itself would otherwise recurse
    // forever — this comes off a server that does not enforce acyclicity.
    final seen = <int>{};
    void walk(int? parentId, int depth) {
      for (final g in byParent[parentId] ?? const <ProductGroup>[]) {
        if (!seen.add(g.id)) continue;
        out.add((g, depth));
        walk(g.id, depth + 1);
      }
    }

    walk(null, 0);
    return out;
  }

  /// The scope toggles, INSIDE the bar's border: all fields, barcode, code,
  /// name. Not filters — they change what the typed text is matched against,
  /// so they carry no chip.
  Widget _buildScopeToggles(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const icons = <String, IconData>{
      ProductSearchScope.allFields: PhosphorIconsRegular.asterisk,
      ProductSearchScope.barcode: PhosphorIconsRegular.barcode,
      ProductSearchScope.code: PhosphorIconsRegular.hash,
      ProductSearchScope.name: PhosphorIconsRegular.tag,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final mode in ProductSearchScope.all)
          Tooltip(
            message: productSearchScopeLabel(context, mode),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _setFilter(scope: mode),
              child: Container(
                // Finger-sized inside a bar that cannot grow taller — wider
                // than it is tall rather than shorter than it is wide.
                constraints: const BoxConstraints(minWidth: 42, minHeight: 34),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _scope == mode
                      ? cs.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PhosphorIcon(
                  icons[mode] ?? PhosphorIconsRegular.tag,
                  size: 19,
                  color: _scope == mode ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Delete / Columns / Import / Export, which were four loose buttons eating
  /// the header. None of them is what an operator came to this screen to do —
  /// that is Add Product, and it is the FAB now.
  List<IlyassMenuAction> _menuActions(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasSelection = _selectedIds.isNotEmpty;

    return [
      IlyassMenuAction(
        icon: Icons.delete_rounded,
        label: hasSelection
            ? l.deleteWithCount(_selectedIds.length)
            : l.actionDelete,
        color: hasSelection ? context.dangerColor : null,
        enabled: hasSelection,
        onSelected: _bulkDelete,
      ),
      IlyassMenuAction(
        icon: Icons.view_column_rounded,
        label: l.columns,
        dividerBefore: true,
        onSelected: () => _showColumnPicker(context),
      ),
      IlyassMenuAction(
        icon: Icons.download_rounded,
        label: l.importLabel,
        onSelected: _openImport,
      ),
      IlyassMenuAction(
        icon: Icons.upload_rounded,
        label: l.exportLabel,
        onSelected: () =>
            showCatalogExportDialog(context, ref, CatalogExportKind.products),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return IlyassListScaffold(
      title: l.products,
      onMenuPressed: widget.onMenuPressed,
      searchBar: _buildSearchBar(context),
      actions: _menuActions(context),
      fabLabel: l.addProduct,
      onFabPressed: _addProduct,
      // Full width — no sidebar, no drag handle, no reserved gutter.
      body: _ProductListContent(
        query: _query,
        scope: _scope,
        selectedIds: Set.from(_selectedIds),
        onSelectionChanged: _updateSelection,
      ),
    );
  }
}

// --- PRODUCT DATA TABLE WIDGET ---

/// Starting widths per column key. Every one of them is draggable from its
/// header edge and persisted per device by [IlyassTable], so these are only
/// what an operator who has never touched a handle sees.
const _kProductColumnWidths = <String, double>{
  'image': 78,
  'color': 72,
  'code': 130,
  'name': 260,
  'category': 160,
  'price': 120,
  'cost': 120,
  'plu': 90,
  'unit': 100,
  'markup': 110,
  'lastPurchase': 140,
  'ageRestriction': 120,
  'rank': 90,
  'taxInclusive': 120,
  'service': 100,
  'priceChange': 130,
  'enabled': 110,
  'description': 280,
  'created': 140,
  'updated': 140,
};

class _ProductListContent extends ConsumerWidget {
  const _ProductListContent({
    required this.query,
    required this.scope,
    required this.selectedIds,
    required this.onSelectionChanged,
  });

  final String query;
  final String scope;
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onSelectionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final sym = ref.watch(currencySymbolProvider);
    final asyncProducts = ref.watch(productsByGroupProvider);
    final groups = ref.watch(allProductGroupsProvider).value ?? [];
    // Secondary barcodes (the `barcodes` table) so a barcode added in the
    // product editor's Barcodes tab is findable from the screen that added it.
    final extraBarcodes =
        ref.watch(allBarcodesByProductIdProvider).value ?? const {};

    // Only the columns the user has chosen to keep, in catalogue order.
    final visibleCols = ref.watch(productVisibleColumnsProvider);
    final activeCols = kProductColumns
        .where((c) => visibleCols[c.key] ?? c.defaultVisible)
        .toList();

    return asyncProducts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(l.errorWithMessage(_parseApiError(context, e)))),
      data: (allProducts) {
        // Copy either way — `allProducts` is the provider's own cached list,
        // and sortProductsBy below sorts in place. Mutating it directly would
        // reorder the POS menu's copy of the same data out from under it.
        final products = query.trim().isEmpty
            ? List<Product>.of(allProducts)
            : allProducts
                  .where(
                    (p) => productMatchesSearch(
                      p,
                      query,
                      scope,
                      extraBarcodes: extraBarcodes[p.id] ?? const [],
                    ),
                  )
                  .toList();

        // Products.Sorting: same setting the POS menu grid honors, so the
        // management table lists products in the order the cashier expects.
        final sortBy =
            ref.watch(appSettingsProvider)[SettingKeys.productSorting] ??
            'Name';
        sortProductsBy(products, sortBy);

        final effectiveSelected = selectedIds.intersection(
          products.map((p) => p.id).toSet(),
        );

        String groupNameFor(Product p) =>
            groups.where((g) => g.id == p.productGroupId).firstOrNull?.name ??
            '-';

        // Every product row opens the editor. The pencil column was a 40px
        // target on a screen driven by fingers; the row is 900 of them.
        void openEditor(Product p) => showDialog(
          context: context,
          builder: (_) => _ProductEditorDialog(existingProduct: p),
        ).then((_) => ref.invalidate(productsByGroupProvider));

        return IlyassTable<Product>(
          tableId: 'products',
          rows: products,
          // Comfortably past the 56px touch minimum, and enough for the 45px
          // product thumbnail to sit in with air around it.
          rowHeight: 64,
          columns: [
            ilyassSelectionColumn<Product, int>(
              rows: products,
              selected: effectiveSelected,
              idOf: (p) => p.id,
              onChanged: onSelectionChanged,
            ),
            for (final col in activeCols)
              IlyassColumn<Product>(
                key: col.key,
                label: productColumnLabel(context, col.key),
                width: _kProductColumnWidths[col.key] ?? 140,
                numeric: col.numeric,
                // Name is mandatory, so there is always exactly one column to
                // hand the surplus to and never a dead zone on the right.
                flexible: col.key == 'name',
                cell: (context, p) => _cell(
                  context: context,
                  theme: theme,
                  key: col.key,
                  product: p,
                  sym: sym,
                  groupNameFor: groupNameFor,
                ),
              ),
          ],
          onRowTap: openEditor,
          isRowSelected: (p) => effectiveSelected.contains(p.id),
          // A disabled product still reads as one at a glance, the way the
          // struck-through name and the Enabled column already say it.
          rowColor: (p) =>
              p.isEnabled ? null : theme.disabledColor.withValues(alpha: 0.05),
          emptyState: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: theme.disabledColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    query.trim().isEmpty
                        ? l.noProductsFound
                        : l.noProductsMatchSearch(query.trim()),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.hintColor, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cell({
    required BuildContext context,
    required ThemeData theme,
    required String key,
    required Product product,
    required String sym,
    required String Function(Product) groupNameFor,
  }) {
    final p = product;

    Widget boolCell(bool v) => Icon(
      v ? Icons.check_circle : Icons.remove_circle_outline,
      size: 18,
      color: v ? context.successColor : theme.disabledColor,
    );

    switch (key) {
      case 'image':
        // Prefer FileImage over MemoryImage — Flutter caches FileImage by path
        // so the same thumbnail decodes once across the grid.
        final ImageProvider? provider = p.imageFile != null
            ? FileImage(p.imageFile!)
            : (p.imageBytes != null ? MemoryImage(p.imageBytes!) : null);
        // No image → tint the placeholder with the colour marker so a coloured
        // product reads as coloured here too, not grey.
        final marker = p.markerColor;
        return Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: provider == null && marker != null
                ? marker.withValues(alpha: 0.20)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
            image: provider != null
                ? DecorationImage(image: provider, fit: BoxFit.cover)
                : null,
          ),
          child: provider == null
              ? PhosphorIcon(
                  PhosphorIconsRegular.forkKnife,
                  color: marker != null
                      ? marker.withValues(alpha: 0.9)
                      : theme.hintColor,
                )
              : null,
        );
      case 'color':
        final marker = p.markerColor;
        return marker == null
            ? const Text('-')
            : Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: marker,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              );
      case 'code':
        return Text(
          p.code ?? '-',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case 'name':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Loose Flexible, not Expanded: the sync badge stays welded to the
            // end of the name instead of being stranded at the column's edge.
            Flexible(
              child: Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: p.isEnabled ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            if (p.isPendingSync) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: p.isPendingCreate
                    ? AppLocalizations.of(context).pendingSyncNew
                    : AppLocalizations.of(context).pendingSyncUpdate,
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 14,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ],
        );
      case 'category':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            groupNameFor(p),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case 'price':
        return Text(
          "${p.price.toStringAsFixed(2)} $sym",
          style: TextStyle(
            color: context.successColor,
            fontWeight: FontWeight.bold,
          ),
        );
      case 'cost':
        return Text(
          "${p.cost.toStringAsFixed(2)} $sym",
          style: TextStyle(color: context.dangerColor),
        );
      case 'plu':
        return Text(p.plu?.toString() ?? '-');
      case 'unit':
        return Text(
          p.measurementUnit ?? '-',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case 'markup':
        return Text(
          p.markup != null ? '${p.markup!.toStringAsFixed(1)}%' : '-',
        );
      case 'lastPurchase':
        return Text(
          p.lastPurchasePrice != null
              ? '${p.lastPurchasePrice!.toStringAsFixed(2)} $sym'
              : '-',
        );
      case 'ageRestriction':
        return Text(p.ageRestriction?.toString() ?? '-');
      case 'rank':
        return Text(p.rank?.toString() ?? '-');
      case 'taxInclusive':
        return boolCell(p.isTaxInclusivePrice);
      case 'service':
        return boolCell(p.isService);
      case 'priceChange':
        return boolCell(p.isPriceChangeAllowed);
      case 'enabled':
        return boolCell(p.isEnabled);
      case 'description':
        return Text(
          p.description ?? '-',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      case 'created':
        return Text(
          p.dateCreated ?? '-',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case 'updated':
        return Text(
          p.dateUpdated ?? '-',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      default:
        return const Text('-');
    }
  }
}

/// The product editor on its own, for widget tests — the dialog class is
/// private, and reaching it through [ProductsScreen] drags in the whole
/// catalogue stack just to check a layout.
@visibleForTesting
Widget productEditorDialogForTest({
  Product? existingProduct,
  bool isPostCreation = false,
}) => _ProductEditorDialog(
  existingProduct: existingProduct,
  isPostCreation: isPostCreation,
);

// --- ADD/EDIT TABBED DIALOG ---
class _ProductEditorDialog extends ConsumerStatefulWidget {
  final Product? existingProduct;
  final bool isPostCreation; // Determines if we are in "Phase 2" of creation

  const _ProductEditorDialog({
    this.existingProduct,
    this.isPostCreation = false,
  });

  @override
  ConsumerState<_ProductEditorDialog> createState() =>
      _ProductEditorDialogState();
}

/// The barcode id out of a `/Barcodes/Add` response.
///
/// 🚨 The id is under `data`, not at the top level — the endpoint answers
/// `{ message, data: { id, value, … } }`. Reading `id` off the root returned
/// null every time, so a freshly added barcode was stored `synced` with **no
/// server id**, and `BarcodeModel.id` (`serverId ?? 0`) then read 0. Delete
/// treats 0 as "never synced" and hard-deletes it locally without telling the
/// server — so the next `pullBarcodes` fetched it straight back. That is the
/// barcode that reappears a second after you delete it, and it made a sold
/// product impossible to switch over to sell-by-weight.
///
/// Both shapes are accepted so a server that later hoists `id` to the root
/// keeps working.
int? _barcodeIdFromResponse(dynamic body) {
  if (body is! Map) return null;
  final direct = body['id'];
  if (direct is num) return direct.toInt();
  final data = body['data'];
  if (data is Map) {
    final nested = data['id'] ?? data['Id'];
    if (nested is num) return nested.toInt();
  }
  return null;
}

/// Looks a barcode's server id up by its value, for rows that were stored
/// without one. Returns null when offline or when the server does not have it
/// (in which case dropping the local row really is correct).
Future<int?> _resolveBarcodeServerId({
  required int productId,
  required int companyId,
  required String value,
}) async {
  try {
    final res = await createDio().get<List<dynamic>>(
      '/Barcodes/GetByProductId',
      queryParameters: {'productId': productId, 'companyId': companyId},
    );
    for (final row in res.data ?? const []) {
      if (row is Map && (row['value'] as String?)?.trim() == value.trim()) {
        final id = row['id'];
        if (id is num) return id.toInt();
      }
    }
  } on DioException {
    // Offline — leave it pending and let the sync push resolve it.
  }
  return null;
}

class _ProductEditorDialogState extends ConsumerState<_ProductEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pluCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '');
  final _costCtrl = TextEditingController(text: '');
  final _markupCtrl = TextEditingController();
  final _rankCtrl = TextEditingController(text: '');
  final _ageRestrictionCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _newBarcodeCtrl = TextEditingController();
  /// Pieces in one box / one pack. Empty means "the catalogue's nominal
  /// 12 / 6", which is what every product meant before the field existed.
  final _packSizeCtrl = TextEditingController();
  // Toggles
  // Seeded from General.TaxIncludedByDefault in initState for NEW products —
  // it was hardcoded `true`, which is why the setting had no observable effect.
  // An EXISTING product always wins with its own stored value.
  bool _isTaxInclusive = true;
  bool _isService = false;

  /// The unit this product is priced and sold in. Backs the Pricing tab's
  /// dropdown; `measurementUnit` is written from it so the legacy free-text
  /// column (receipts, document lines, exports) stays in step.
  int _uomId = kUomPieces;

  /// What the pack-size field actually stores.
  ///
  /// Null on anything that is not a box or a pack, and null for an empty or
  /// non-positive entry — both mean "the catalogue's nominal 12 / 6". Mirrors
  /// `UnitOfMeasure.NormalisePackSize` on the server, which normalises again on
  /// arrival: a value left over from a unit the admin has since changed must
  /// never sit on the row waiting to be believed.
  double? get _packSize =>
      normalisePackSize(_uomId, double.tryParse(_packSizeCtrl.text.trim()));

  /// Sold by weight. Drives the POS scale/keypad flow.
  bool _isToWeigh = false;
  bool _isPriceChangeAllowed = false;
  bool _isUsingDefaultQuantity = true;
  bool _isEnabled = true;
  bool _isBarcodeChipActive = false;
  bool _costPriceMarkupEnabled = false;
  bool _isRecalculating = false;

  // State
  int? _selectedGroupId;
  String? _selectedImageBase64;
  int? _selectedTaxId;
  int? _originalTaxId;
  String _selectedHexColor = '#000000';

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing =>
      widget.existingProduct != null && !widget.isPostCreation;

  final List<Color> _colorPalette = [
    Colors.blueGrey,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.black,
  ];

  String _colorToHex(Color color) =>
      '#${color.value.toRadixString(16).substring(2).toUpperCase()}';

  void _recalcPrice() {
    if (_isRecalculating) return;
    _isRecalculating = true;
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    final markup = double.tryParse(_markupCtrl.text) ?? 0;
    if (cost > 0) {
      _priceCtrl.text = (cost * (1 + markup / 100)).toStringAsFixed(2);
    }
    _isRecalculating = false;
  }

  @override
  void initState() {
    super.initState();

    final settings = ref.read(appSettingsProvider);
    _costPriceMarkupEnabled =
        settings[SettingKeys.costPriceBasedMarkup]?.toLowerCase() == 'true';

    if (widget.existingProduct != null) {
      final p = widget.existingProduct!;
      _nameCtrl.text = p.name;
      _codeCtrl.text = p.code ?? '';
      _pluCtrl.text = p.plu?.toString() ?? '';
      _uomId = p.uomId;
      _isToWeigh = p.isToWeigh;
      _packSizeCtrl.text =
          p.packSize == null ? '' : formatQuantityValue(p.packSize!, kUomPieces);
      _priceCtrl.text = p.price.toString();
      _costCtrl.text = p.cost.toString();
      _markupCtrl.text = p.markup?.toString() ?? '';
      _rankCtrl.text = p.rank?.toString() ?? '0';
      _ageRestrictionCtrl.text = p.ageRestriction?.toString() ?? '';
      _descriptionCtrl.text = p.description ?? '';

      _isTaxInclusive = p.isTaxInclusivePrice;
      _isService = p.isService;
      _isPriceChangeAllowed = p.isPriceChangeAllowed;
      _isUsingDefaultQuantity = p.isUsingDefaultQuantity;
      _isEnabled = p.isEnabled;

      _selectedGroupId = p.productGroupId;
      // Image source priority:
      //   1. p.image          — base64 from API (legacy path, still used for
      //                         products fetched fresh from the server)
      //   2. p.localImagePath — file on disk (Drift-sourced products after
      //                         Phase 3.5; ImageSyncHelper wrote the file
      //                         during the master-data pull)
      // The edit form uploads back as base64, so we read the file synchronously
      // here and encode it once. For the typical 600x600/85-quality JPEGs
      // ImageSyncHelper saves, this is a few KB and a single open-modal cost.
      if (p.image != null && p.image!.isNotEmpty) {
        _selectedImageBase64 = p.image;
      } else if (p.localImagePath != null && p.localImagePath!.isNotEmpty) {
        try {
          final f = File(p.localImagePath!);
          if (f.existsSync()) {
            _selectedImageBase64 = base64Encode(f.readAsBytesSync());
          }
        } catch (_) {
          /* leave _selectedImageBase64 null — UI shows placeholder */
        }
      }
      _selectedHexColor = p.color.isNotEmpty ? p.color : '#000000';

      // Deliberately NOT gated on `p.id > 0` any more. The guard dated from
      // when this hit the API; the lookup is now pure Drift, and a product in
      // Phase 2 of creation still carries its NEGATIVE temp id — so the guard
      // hid the tax that Phase 1 had just assigned. That mattered for more
      // than display: with `_originalTaxId` left null, picking a different tax
      // in Phase 2 wrote the new assignment without retiring the old one, and
      // the product ended up carrying two taxes.
      _fetchAssignedTax(p.id);
    } else {
      _selectedGroupId = ref.read(selectedProductGroupIdProvider);

      // NEW product: follow the configured tax defaults. Both are pre-fills,
      // not locks — the admin can still change either before saving (the lock
      // is at the till, not here).
      _isTaxInclusive =
          settings[SettingKeys.taxIncludedByDefault]?.toLowerCase() == 'true';

      // Only pre-select a tax when the feature is actually on; the picker is
      // greyed out in Settings while the switch is off, so honouring a stale
      // selection here would apply a tax the operator believes is disabled.
      if (_isTaxInclusive) {
        // `_selectedTaxId` is a single id while the setting holds a list — the
        // product editor's Taxes tab has always been one-tax-per-product. Take
        // the first configured rate; the cart still applies the full list to
        // any product that carries no assignment of its own.
        final defaults = parseDefaultTaxRateIds(
          settings[SettingKeys.defaultTaxRateIds],
        );
        if (defaults.isNotEmpty) {
          _selectedTaxId = (defaults.toList()..sort()).first;
        }
      }
    }

    if (_costPriceMarkupEnabled) {
      _costCtrl.addListener(_recalcPrice);
      _markupCtrl.addListener(_recalcPrice);
    }
  }

  Future<void> _fetchAssignedTax(int productId) async {
    if (ref.read(selectedCompanyProvider)?.id == null) return;
    try {
      // Offline-first: read the assigned tax from the local Drift cache
      // (seeded by SyncManager.pullProductTaxes).
      final taxes = await ref
          .read(appDatabaseProvider)
          .getProductTaxes(productId);
      if (taxes.isNotEmpty && mounted) {
        setState(() {
          _selectedTaxId = taxes.first.taxId;
          _originalTaxId = _selectedTaxId;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _costCtrl.removeListener(_recalcPrice);
    _markupCtrl.removeListener(_recalcPrice);
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _pluCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _markupCtrl.dispose();
    _rankCtrl.dispose();
    _ageRestrictionCtrl.dispose();
    _descriptionCtrl.dispose();
    _newBarcodeCtrl.dispose();
    _packSizeCtrl.dispose();

    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (xFile != null) {
      final bytes = await xFile.readAsBytes();
      setState(() => _selectedImageBase64 = base64Encode(bytes));
    }
  }

  Future<void> _submit() async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;

    // SCENARIO 1: We are in "Phase 1" of creation (Only General Tab)
    if (widget.existingProduct == null && !widget.isPostCreation) {
      if (_nameCtrl.text.trim().isEmpty) {
        setState(
          () => _errorMessage = AppLocalizations.of(
            context,
          ).pleaseEnterProductName,
        );
        return;
      }
      if (_formKey.currentState?.validate() == false) return;

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        final db = ref.read(appDatabaseProvider);
        // Temp id — negative millisecond timestamp, always unique and clearly
        // distinguishable from a server-assigned (positive) id.
        final tempId = -(DateTime.now().millisecondsSinceEpoch);
        final now = DateTime.now().toUtc();

        // Best-effort: save the picked image to disk so Phase 2 can preview it
        // and SyncManager can re-encode it when pushing to the server.
        String? localImgPath;
        if (_selectedImageBase64 != null && _selectedImageBase64!.isNotEmpty) {
          try {
            final raw = _selectedImageBase64!.contains(',')
                ? _selectedImageBase64!.split(',').last
                : _selectedImageBase64!;
            final bytes = base64Decode(raw);
            final docs = await getApplicationDocumentsDirectory();
            final dir = Directory(imgpath.join(docs.path, 'product_images'));
            if (!await dir.exists()) await dir.create(recursive: true);
            final file = File(imgpath.join(dir.path, 'tmp_$tempId.jpg'));
            await file.writeAsBytes(bytes, flush: true);
            await FileImage(file).evict();
            localImgPath = file.path;
          } catch (_) {
            /* best-effort */
          }
        }

        await db
            .into(db.productsTable)
            .insert(
              ProductsTableCompanion(
                id: Value(tempId),
                companyId: Value(companyId),
                name: Value(_nameCtrl.text.trim()),
                price: Value(double.tryParse(_priceCtrl.text) ?? 0),
                cost: Value(double.tryParse(_costCtrl.text) ?? 0),
                productGroupId: Value(_selectedGroupId),
                isService: Value(_isService),
                colorHex: Value(
                  _selectedHexColor == 'Transparent'
                      ? '#000000'
                      : _selectedHexColor,
                ),
                localImagePath: Value(localImgPath),
                code: Value(
                  _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
                ),
                plu: Value(int.tryParse(_pluCtrl.text.trim())),
                measurementUnit: Value(uomById(_uomId).code),
                uomId: Value(_uomId),
                isToWeigh: Value(_isToWeigh),
                packSize: Value(_packSize),
                description: Value(
                  _descriptionCtrl.text.trim().isEmpty
                      ? null
                      : _descriptionCtrl.text.trim(),
                ),
                markup: Value(double.tryParse(_markupCtrl.text.trim())),
                rank: Value(int.tryParse(_rankCtrl.text.trim()) ?? 0),
                ageRestriction: Value(
                  int.tryParse(_ageRestrictionCtrl.text.trim()),
                ),
                isPriceChangeAllowed: Value(_isPriceChangeAllowed),
                isUsingDefaultQuantity: Value(_isUsingDefaultQuantity),
                isTaxInclusivePrice: Value(_isTaxInclusive),
                isEnabled: Value(_isEnabled),
                syncStatus: const Value('pending_create'),
                lastModified: Value(now),
              ),
            );

        // Persist the tax assignment NOW, against the temp id.
        //
        // This is the half that was missing: Phase 1 wrote the product but
        // never its tax, so the configured default silently evaporated and the
        // product reopened showing "No Tax". Only Phase 2 / Edit ever wrote a
        // tax row, and by then `_selectedTaxId` had been re-read from a
        // `product_taxes` table that had nothing in it.
        //
        // Writing against a NEGATIVE product id is safe and already the
        // established pattern here: `remapProductId` repoints
        // `product_taxes.productId` temp → real when the product push gets its
        // server id, and `pushPendingProductTaxes` is deliberately ordered
        // after `pushPendingProductOps`, so /ProductTaxes/Add never sees an id
        // the server doesn't know.
        if (_selectedTaxId != null) {
          await db.setProductTaxLocal(
            companyId: companyId,
            productId: tempId,
            oldTaxId: null,
            newTaxId: _selectedTaxId,
          );
        }

        // Build a Product from the fields we just stored so Phase 2 can be
        // optionally launched by the parent. id < 0 signals "pending sync".
        final newProduct = Product(
          id: tempId,
          companyId: companyId,
          name: _nameCtrl.text.trim(),
          price: double.tryParse(_priceCtrl.text) ?? 0,
          cost: double.tryParse(_costCtrl.text) ?? 0,
          productGroupId: _selectedGroupId,
          isService: _isService,
          color: _selectedHexColor == 'Transparent'
              ? '#000000'
              : _selectedHexColor,
          localImagePath: localImgPath,
          code: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
          plu: int.tryParse(_pluCtrl.text.trim()),
          measurementUnit: uomById(_uomId).code,
          uomId: _uomId,
          isToWeigh: _isToWeigh,
          packSize: _packSize,
          description: _descriptionCtrl.text.trim().isEmpty
              ? null
              : _descriptionCtrl.text.trim(),
          markup: double.tryParse(_markupCtrl.text.trim()),
          rank: int.tryParse(_rankCtrl.text.trim()) ?? 0,
          ageRestriction: int.tryParse(_ageRestrictionCtrl.text.trim()),
          isPriceChangeAllowed: _isPriceChangeAllowed,
          isUsingDefaultQuantity: _isUsingDefaultQuantity,
          isTaxInclusivePrice: _isTaxInclusive,
          isEnabled: _isEnabled,
          syncStatus: 'pending_create',
        );

        if (mounted) Navigator.of(context).pop(newProduct);
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
      return;
    }

    // SCENARIO 2 & 3: We are in "Phase 2" of creation, OR normal Editing
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dio = createDio();
      final savedProductId = widget.existingProduct!.id;

      // Only update the General properties if we are in normal Edit mode
      if (_isEditing) {
        if (_formKey.currentState?.validate() == false) {
          setState(() => _isLoading = false);
          return;
        }
        final payload = {
          'id': savedProductId,
          'name': _nameCtrl.text.trim(),
          'productGroupId': _selectedGroupId,
          'code': _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
          'plu': int.tryParse(_pluCtrl.text.trim()),
          'measurementUnit': uomById(_uomId).code,
          'uomId': _uomId,
          'isToWeigh': _isToWeigh,
          'packSize': _packSize,
          'price': double.tryParse(_priceCtrl.text) ?? 0,
          'cost': double.tryParse(_costCtrl.text) ?? 0,
          'markup': double.tryParse(_markupCtrl.text.trim()),
          'rank': int.tryParse(_rankCtrl.text.trim()) ?? 0,
          'ageRestriction': int.tryParse(_ageRestrictionCtrl.text.trim()),
          'description': _descriptionCtrl.text.trim().isEmpty
              ? null
              : _descriptionCtrl.text.trim(),
          'isTaxInclusivePrice': _isTaxInclusive,
          'isService': _isService,
          'isPriceChangeAllowed': _isPriceChangeAllowed,
          'isUsingDefaultQuantity': _isUsingDefaultQuantity,
          'isEnabled': _isEnabled,
          'imageBase64': _selectedImageBase64 ?? "",
          'color': _selectedHexColor == 'Transparent'
              ? '#000000'
              : _selectedHexColor,
        };
        // ── Optimistic local write ──────────────────────────────────────
        // Save image to disk and upsert the product row in Drift so the
        // change is immediately visible even if the API call fails offline.
        final db = ref.read(appDatabaseProvider);
        String? localImgPath = widget.existingProduct!.localImagePath;
        if (_selectedImageBase64 != null && _selectedImageBase64!.isNotEmpty) {
          try {
            final raw = _selectedImageBase64!.contains(',')
                ? _selectedImageBase64!.split(',').last
                : _selectedImageBase64!;
            final bytes = base64Decode(raw);
            final docs = await getApplicationDocumentsDirectory();
            final dir = Directory(imgpath.join(docs.path, 'product_images'));
            if (!await dir.exists()) await dir.create(recursive: true);
            final file = File(imgpath.join(dir.path, '$savedProductId.jpg'));
            await file.writeAsBytes(bytes, flush: true);
            await FileImage(file).evict();
            localImgPath = file.path;
          } catch (_) {
            /* best-effort */
          }
        }
        await db
            .into(db.productsTable)
            .insertOnConflictUpdate(
              ProductsTableCompanion(
                id: Value(savedProductId),
                companyId: Value(companyId),
                name: Value(_nameCtrl.text.trim()),
                price: Value(double.tryParse(_priceCtrl.text) ?? 0),
                cost: Value(double.tryParse(_costCtrl.text) ?? 0),
                productGroupId: Value(_selectedGroupId),
                isService: Value(_isService),
                colorHex: Value(
                  _selectedHexColor == 'Transparent'
                      ? '#000000'
                      : _selectedHexColor,
                ),
                localImagePath: Value(localImgPath),
                code: Value(
                  _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
                ),
                plu: Value(int.tryParse(_pluCtrl.text.trim())),
                measurementUnit: Value(uomById(_uomId).code),
                uomId: Value(_uomId),
                isToWeigh: Value(_isToWeigh),
                packSize: Value(_packSize),
                description: Value(
                  _descriptionCtrl.text.trim().isEmpty
                      ? null
                      : _descriptionCtrl.text.trim(),
                ),
                markup: Value(double.tryParse(_markupCtrl.text.trim())),
                rank: Value(int.tryParse(_rankCtrl.text.trim()) ?? 0),
                ageRestriction: Value(
                  int.tryParse(_ageRestrictionCtrl.text.trim()),
                ),
                isPriceChangeAllowed: Value(_isPriceChangeAllowed),
                isUsingDefaultQuantity: Value(_isUsingDefaultQuantity),
                isTaxInclusivePrice: Value(_isTaxInclusive),
                isEnabled: Value(_isEnabled),
                syncStatus: const Value('pending_update'),
                lastModified: Value(DateTime.now().toUtc()),
              ),
            );

        // ── Try server sync ─────────────────────────────────────────────
        try {
          await dio.patch(
            '/Products/Update',
            queryParameters: {'id': savedProductId, 'companyId': companyId},
            data: payload,
          );
          // API succeeded — clear the pending flag.
          await (db.update(
            db.productsTable,
          )..where((t) => t.id.equals(savedProductId))).write(
            const ProductsTableCompanion(
              syncStatus: Value('synced'),
              syncError: Value(null),
            ),
          );
        } on DioException {
          // API unreachable — local write is queued. Will sync when online.
          if (mounted) {
            showAppSnackbar(
              context,
              ref,
              AppLocalizations.of(context).savedLocallyWillSyncOnline,
            );
            Navigator.of(context).pop();
          }
          return;
        }
      }

      // Handle Taxes (offline-first): write the assignment change to local
      // Drift; SyncManager pushes /ProductTaxes/Add+Delete on the next sync.
      if (_selectedTaxId != _originalTaxId) {
        await ref
            .read(appDatabaseProvider)
            .setProductTaxLocal(
              companyId: companyId,
              productId: savedProductId,
              oldTaxId: _originalTaxId,
              newTaxId: _selectedTaxId,
            );
      }

      if (mounted) {
        showAppSnackbar(
          context,
          ref,
          widget.isPostCreation
              ? AppLocalizations.of(context).setupComplete
              : AppLocalizations.of(context).productUpdatedSuccessfully,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = _parseApiError(context, e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 1. Determine Dialog Title and Button Text
    final l10n = AppLocalizations.of(context);
    String title = l10n.newProduct;
    String buttonText = l10n.nextTaxesAndStock;

    if (_isEditing) {
      title = l10n.editProduct;
      buttonText = l10n.actionSaveChanges;
    } else if (widget.isPostCreation) {
      title = l10n.setTaxesAndInventoryFor(widget.existingProduct?.name ?? '');
      buttonText = l10n.finishSetup;
    }

    // 2. Build Tabs Based on Current Mode
    final List<Widget> dialogTabs = [];
    final List<Widget> dialogTabViews = [];

    // Add General Tab (If creating Phase 1, OR if normal editing)
    if (!widget.isPostCreation) {
      dialogTabs.add(Tab(text: l10n.generalLabel));
      dialogTabViews.add(_buildGeneralTab());
    }

    // Pricing sits right after General, and — unlike the old layout — exists
    // during Phase 1 of creation. That is the point: it is where the price is
    // set AND where the configured default tax becomes visible, at the moment
    // the product is being created rather than a dialog later.
    if (!widget.isPostCreation) {
      dialogTabs.add(Tab(text: l10n.pricingTab));
      dialogTabViews.add(_buildPricingTab());
    }

    // Add Advanced Tabs (If creating Phase 2, OR if normal editing)
    if (_isEditing || widget.isPostCreation) {
      dialogTabs.addAll([
        Tab(text: l10n.barcodesTab),
        Tab(text: l10n.posModifiers),
      ]);
      dialogTabViews.addAll([_buildBarcodesTab(), _buildModifiersTab()]);
    }

    // The standalone Taxes tab survives ONLY for Phase 2, which has no Pricing
    // tab to host the picker. Showing both at once would put two dropdowns for
    // the same field in one dialog.
    if (widget.isPostCreation) {
      dialogTabs.insert(0, Tab(text: l10n.taxesLabel));
      dialogTabViews.insert(0, _buildTaxesTab());
    }

    // Appearance sits last (right after Comments when editing). Tied to the
    // same condition as General so creating a product still exposes it.
    if (!widget.isPostCreation) {
      dialogTabs.add(Tab(text: l10n.setAppearance));
      dialogTabViews.add(_buildAppearanceTab());
    }

    // Sized to the screen it is on rather than a fixed 950×650, which ran off
    // a 7" tablet sideways and off a 768-high till downwards. The designed
    // size stays the cap on anything larger. ~220dp is the dialog's own chrome
    // (title, footer, inset) that the body has to leave room for.
    final dialogWidth = context.dialogWidth(960);
    final bodyHeight = math.max(
      360.0,
      math.min(650.0, context.screenHeight - 220),
    );
    final danger = context.dangerColor;

    return DefaultTabController(
      length: dialogTabs.length,
      child: AlertDialog(
        contentPadding: EdgeInsets.zero,
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
        actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: dialogWidth,
            height: bodyHeight,
            child: Column(
              children: [
                // Left-aligned, directly under the title, so the tabs read as
                // part of the header rather than a bar across the middle.
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  indicatorColor: theme.colorScheme.primary,
                  labelStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: dialogTabs,
                ),
                Expanded(child: TabBarView(children: dialogTabViews)),
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: danger.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 18, color: danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // The footer's top edge. The actions below sit outside the
                // scrolling tab body, so this line is what makes them read as a
                // fixed bar instead of buttons floating under the form.
                const Divider(height: 1),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(96, 48)),
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).actionCancel),
          ),
          if (_isLoading)
            const SizedBox(
              width: 140,
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                minimumSize: const Size(140, 48),
                padding: const EdgeInsets.symmetric(horizontal: 32),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: _submit,
              child: Text(buttonText),
            ),
        ],
      ),
    );
  }

  // --- SUB-WIDGETS TO KEEP THE BUILD TREE CLEAN ---

  /// The house field style (lib/core/ilyass_form.dart), shared with the
  /// document editor.
  InputDecoration _fieldDecoration({
    String? label,
    String? hint,
    String? prefix,
    String? suffix,
  }) => ilyassFieldDecoration(
    context,
    label: label,
    hint: hint,
    prefix: prefix,
    suffix: suffix,
  );

  /// The frame every editor tab shares — see [IlyassTabBody].
  Widget _tabBody(List<Widget> sections) => IlyassTabBody(children: sections);

  /// Three stacked sections — PRODUCT INFORMATION, DESCRIPTION, PRODUCT
  /// BEHAVIOR — in that order of importance. It used to be a 3:2 split with
  /// the switches floating in a box on the right, which left the lower half of
  /// the tab empty and gave no field any more weight than another.
  Widget _buildGeneralTab() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final allGroupsAsync = ref.watch(allProductGroupsProvider);
    // No currency here any more — every money field moved to the Pricing tab.

    // The name is THE field of this form, so it is set a weight above the rest.
    final nameField = TextFormField(
      controller: _nameCtrl,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      decoration: _fieldDecoration(label: l10n.productNameRequired),
    );
    final groupField = allGroupsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => Text(l10n.errorLoadingGroups),
      data: (groups) => DropdownButtonFormField<int?>(
        initialValue: _selectedGroupId,
        isExpanded: true,
        decoration: _fieldDecoration(label: l10n.categoryGroup),
        items: [
          DropdownMenuItem(value: null, child: Text(l10n.noneUncategorized)),
          ...groups.map(
            (g) => DropdownMenuItem(
              value: g.id,
              child: Text(g.name, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (v) => setState(() => _selectedGroupId = v),
      ),
    );
    final codeField = TextFormField(
      controller: _codeCtrl,
      decoration: _fieldDecoration(label: l10n.productCodeSku),
    );
    final pluField = TextFormField(
      controller: _pluCtrl,
      decoration: _fieldDecoration(label: l10n.plu),
      keyboardType: TextInputType.number,
    );
    final ageField = TextFormField(
      controller: _ageRestrictionCtrl,
      decoration: _fieldDecoration(
        label: l10n.ageRestriction,
        hint: l10n.ageRestrictionHint,
      ),
      keyboardType: TextInputType.number,
    );
    final rankField = TextFormField(
      controller: _rankCtrl,
      decoration: _fieldDecoration(label: l10n.rankDisplayOrder),
      keyboardType: TextInputType.number,
    );
    // Named by its section header, so a placeholder instead of a second label.
    // Two lines to start, growing to four — a short note should not claim the
    // space of an essay.
    final descriptionField = TextFormField(
      key: kProductDescriptionFieldKey,
      controller: _descriptionCtrl,
      minLines: 2,
      maxLines: 4,
      decoration: _fieldDecoration(hint: l10n.productDescriptionPlaceholder),
    );

    // "Price is tax inclusive" moved to the Pricing tab — it qualifies the
    // price, so it belongs next to it. Service comes before weight because it
    // decides whether weight is available at all.
    final behaviors = <Widget>[
      IlyassOptionSwitch(
        title: l10n.isServiceNotPhysical,
        subtitle: l10n.isServiceHint,
        value: _isService,
        onChanged: (v) => setState(() => _isService = v),
      ),
      // A service has no stock to weigh, so the switch is disabled there
      // rather than silently ignored at the till.
      IlyassOptionSwitch(
        title: l10n.sellByWeight,
        subtitle: l10n.sellByWeightHint,
        value: _isToWeigh && !_isService,
        onChanged: _isService ? null : (v) => setState(() => _isToWeigh = v),
      ),
      IlyassOptionSwitch(
        title: l10n.changePriceAllowed,
        subtitle: l10n.changePriceAllowedHint,
        value: _isPriceChangeAllowed,
        onChanged: (v) => setState(() => _isPriceChangeAllowed = v),
      ),
      IlyassOptionSwitch(
        title: l10n.isEnabledVisible,
        subtitle: l10n.isEnabledHint,
        value: _isEnabled,
        onChanged: (v) => setState(() => _isEnabled = v),
      ),
    ];

    // 3:2 on every row, so the columns line up down the whole section and the
    // name gets the wider one.
    const split = [3, 2];
    return _tabBody([
      IlyassFormSection(
        icon: Icons.inventory_2_outlined,
        title: l10n.productInformationSection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IlyassFieldRow(flexes: split, children: [nameField, groupField]),
            const SizedBox(height: 16),
            IlyassFieldRow(flexes: split, children: [codeField, pluField]),
            const SizedBox(height: 16),
            // Measurement unit, price, cost and markup live on the Pricing
            // tab; age restriction and rank stayed here because they are
            // compliance/menu-ordering fields.
            IlyassFieldRow(flexes: split, children: [ageField, rankField]),
          ],
        ),
      ),
      IlyassFormSection(
        icon: Icons.notes_outlined,
        title: l10n.description,
        child: descriptionField,
      ),
      IlyassFormSection(
        // Not Icons.tune: the E2E helpers find Quick Settings by that icon,
        // and a second one on screen would confuse them.
        icon: Icons.toggle_on_outlined,
        title: l10n.productBehaviorSection,
        // Two per row at most, so a switch never drifts far from its label.
        child: IlyassTileGrid(children: behaviors),
      ),
    ]);
  }

  /// Everything that decides what the product COSTS: unit, cost, selling
  /// price, markup, the tax-inclusive flag, and the tax itself.
  ///
  /// The tax picker is here — not only on the Taxes tab — because the Taxes
  /// tab does not exist during Phase 1 of creation, which is exactly when the
  /// configured default gets applied and is worth seeing. Both controls bind
  /// to the same `_selectedTaxId`, so they can never disagree.
  /// Grouped unit picker, replacing the free-text field this screen used to
  /// carry. Grouping by category is what makes the "you cannot sell kg from a
  /// litre product" rule visible before it can be broken.
  Widget _buildUomDropdown() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final grouped = uomsByCategory();

    final items = <DropdownMenuItem<int>>[];
    for (final entry in grouped.entries) {
      items.add(
        DropdownMenuItem<int>(
          // A header is not selectable — `enabled: false` keeps a tap from
          // assigning a category id that is not in the catalog.
          enabled: false,
          value: -entry.key.index - 1,
          child: Text(
            _uomCategoryLabel(entry.key, l10n).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      );

      for (final u in entry.value) {
        items.add(
          DropdownMenuItem<int>(
            value: u.id,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: Text(
                u.isReference ? '${u.code}  ·  ${l10n.uomStockUnit}' : u.code,
              ),
            ),
          ),
        );
      }
    }

    return DropdownButtonFormField<int>(
      initialValue: uomById(_uomId).id,
      decoration: _fieldDecoration(label: l10n.measurementUnit),
      isExpanded: true,
      items: items,
      onChanged: (v) {
        if (v == null || v < 0) return;
        setState(() {
          _uomId = v;
          // Picking a weight or volume unit is the whole reason to weigh, so
          // offer it rather than making the switch a second thing to remember.
          // Never turned OFF here: an admin who deliberately weighs a piece
          // product would lose that on one unrelated unit change.
          final category = uomById(v).category;
          if (category == UomCategory.weight ||
              category == UomCategory.volume) {
            _isToWeigh = true;
          }
        });
      },
    );
  }

  /// How many pieces are in one box / one pack of THIS product.
  ///
  /// Shown only for the two units whose catalogue factor is a nominal default
  /// rather than a physical fact — a box of tuna and a box of water are not both
  /// 12, which is what this field exists to say.
  ///
  /// EMPTY IS A REAL ANSWER and means the nominal: a catalogue where nobody has
  /// ever stated a box size must keep converting exactly as it did before the
  /// field existed, so the hint spells out what that number is.
  Widget _buildPackSizeField() {
    final l10n = AppLocalizations.of(context);
    final unit = uomById(_uomId);
    final stockUnit = referenceUomOf(unit);
    final nominal = formatQuantity(
      uomToReference(1, unit.id, packSize: null),
      stockUnit.id,
    );

    return TextFormField(
      controller: _packSizeCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      // Redraws the conversion note beside it as the number is typed.
      onChanged: (_) => setState(() {}),
      decoration: _fieldDecoration(
        label: l10n.uomPackSize(unit.code),
        hint: l10n.uomPackSizeHint(nominal),
        suffix: stockUnit.code,
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return null;

        final parsed = double.tryParse(text);
        // A zero would divide the whole conversion by nothing, and a negative
        // one would ADD stock on a sale.
        return parsed == null || parsed <= 0 ? l10n.uomPackSizeInvalid : null;
      },
    );
  }

  /// Spells out the unit stock actually moves in, which is the part of the Odoo
  /// model that surprises people: a product priced per gram still has its stock
  /// counted in kilograms.
  Widget _buildStockUnitNote() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final unit = uomById(_uomId);
    final stockUnit = referenceUomOf(unit);

    // One panel either way, at a field's height, so it sits level with the
    // unit dropdown beside it instead of floating as a stray line of text.
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            unit.isReference ? Icons.inventory_2_outlined : Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              unit.isReference
                  ? l10n.uomStockHeldIn(stockUnit.code)
                  : l10n.uomStockConversionNote(
                      unit.code,
                      formatQuantityValue(
                        uomToReference(1, unit.id, packSize: _packSize),
                        stockUnit.id,
                      ),
                      stockUnit.code,
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _uomCategoryLabel(UomCategory category, AppLocalizations l10n) =>
      switch (category) {
        UomCategory.unit => l10n.uomCategoryUnit,
        UomCategory.weight => l10n.uomCategoryWeight,
        UomCategory.volume => l10n.uomCategoryVolume,
        UomCategory.length => l10n.uomCategoryLength,
      };

  /// PRICE & COST, TAXES, UNIT & STOCK — what the till charges first, then
  /// what is added to it, then what one unit of it is.
  Widget _buildPricingTab() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final allTaxesAsync = ref.watch(allTaxesProvider);

    // The price is what the till charges, so — like the name on General — it
    // is set a weight above the rest. The "/ kg" suffix says what one unit of
    // it buys, so a price never reads as per piece on a product sold by weight.
    final priceField = TextFormField(
      controller: _priceCtrl,
      // Rebuilds the breakdown below as the price is typed.
      onChanged: (_) => setState(() {}),
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      decoration: _fieldDecoration(
        label: l10n.sellingPriceRequired,
        prefix: '$currencySymbol ',
        suffix: '/ ${uomById(_uomId).code}',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    final costField = TextFormField(
      controller: _costCtrl,
      decoration: _fieldDecoration(
        label: l10n.purchaseCost,
        prefix: '$currencySymbol ',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    final markupField = TextFormField(
      controller: _markupCtrl,
      decoration: _fieldDecoration(label: l10n.marginMarkup, suffix: '%'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );

    // Directly under the price, per the request: you can see WHICH tax applies
    // while creating the product, not two dialogs later.
    final taxContent = allTaxesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => Text(l10n.failedToLoadTaxes),
      data: (taxes) {
        final enabled = taxes.where((t) => t.isEnabled).toList();
        // A stale id (tax disabled or deleted since) must not be handed to the
        // dropdown — Material asserts on a value with no item.
        final safeValue = enabled.any((t) => t.id == _selectedTaxId)
            ? _selectedTaxId
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IlyassFieldRow(
              flexes: const [3, 2],
              children: [
                DropdownButtonFormField<int?>(
                  initialValue: safeValue,
                  isExpanded: true,
                  decoration: _fieldDecoration(label: l10n.primaryTaxRate),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l10n.noTax)),
                    ...enabled.map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(
                          "${t.name} (${t.rate}${t.isFixed ? '' : '%'})",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedTaxId = v),
                ),
                // Same card as General's options: it qualifies the price, so
                // it sits beside the tax that would be added to it.
                IlyassOptionSwitch(
                  title: l10n.priceIsTaxInclusive,
                  value: _isTaxInclusive,
                  onChanged: (v) => setState(() => _isTaxInclusive = v),
                ),
              ],
            ),
            _buildTaxBreakdown(enabled, currencySymbol),
          ],
        );
      },
    );

    // Only box and pack can carry a pack size; every other unit is a physical
    // fact, not a packaging choice. Beside the unit goes whichever says more:
    // the pack size when there is one, otherwise the stock note.
    final packSized = isPackSizedUom(_uomId);
    final unitContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IlyassFieldRow(
          flexes: const [3, 2],
          children: [
            _buildUomDropdown(),
            packSized ? _buildPackSizeField() : _buildStockUnitNote(),
          ],
        ),
        if (packSized) ...[const SizedBox(height: 12), _buildStockUnitNote()],
      ],
    );

    return _tabBody([
      IlyassFormSection(
        icon: Icons.payments_outlined,
        title: l10n.priceAndCostSection,
        // The dialog's usual 3:2 split; a company that prices from cost gets
        // the markup as a third column rather than a half-empty row of its own.
        child: IlyassFieldRow(
          flexes: _costPriceMarkupEnabled ? const [3, 2, 2] : const [3, 2],
          minFieldWidth: _costPriceMarkupEnabled ? 180 : 240,
          children: [
            priceField,
            costField,
            if (_costPriceMarkupEnabled) markupField,
          ],
        ),
      ),
      IlyassFormSection(
        icon: Icons.receipt_long_outlined,
        title: l10n.taxesLabel,
        child: taxContent,
      ),
      // Backed by catalog ids rather than free text so the POS can convert a
      // sale into a stock movement — see lib/uom/unit_of_measure.dart.
      IlyassFormSection(
        icon: Icons.straighten,
        title: l10n.unitAndStockSection,
        child: unitContent,
      ),
    ]);
  }

  /// Live "the tax IS being applied" confirmation under the price.
  ///
  /// ⚠️ Deliberately shows the tax being ADDED to the price, even when the
  /// "Price is tax inclusive" switch is on — because that is what the till
  /// actually charges. `Product.isTaxInclusivePrice` is stored, synced,
  /// exported and served in the menu payload, but NO pricing code reads it on
  /// either side: the cart does `taxableBase * (rate / 100)` unconditionally
  /// (`cart_provider` line ~1292, mirrored in `_grossLineTotal` and the
  /// receipt service), and the backend only ever persists the column. The one
  /// consumer, `stock_screen`, divides by a hardcoded 1.15.
  ///
  /// So backing the tax out here would print a split the POS does not honour —
  /// a 120 "inclusive" product rings up at 144, not 120. Until the inclusive
  /// math is actually implemented, this shows the real number and
  /// [_buildTaxInclusiveWarning] says so out loud.
  Widget _buildTaxBreakdown(List<Tax> enabledTaxes, String currencySymbol) {
    if (_selectedTaxId == null) return const SizedBox.shrink();
    final tax = enabledTaxes.where((t) => t.id == _selectedTaxId).firstOrNull;
    if (tax == null) return const SizedBox.shrink();

    final price = double.tryParse(_priceCtrl.text) ?? 0;
    if (price <= 0) return const SizedBox.shrink();

    // A fixed tax is a flat amount, not a percentage of anything.
    final amount = tax.isFixed ? tax.rate : price * tax.rate / 100;

    String money(double v) => '$currencySymbol ${v.toStringAsFixed(2)}';
    final l10n = AppLocalizations.of(context);

    final cs = Theme.of(context).colorScheme;

    // A quiet panel under the tax row: what the till will actually charge.
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.calculate_outlined, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.taxBreakdownAdded(
                    money(price),
                    money(amount),
                    money(price + amount),
                  ),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                _buildTaxInclusiveWarning(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Surfaces the gap above where it can actually mislead someone into
  /// mispricing stock: the switch is on, so the operator believes the price
  /// already contains the tax, but the till will add it again.
  Widget _buildTaxInclusiveWarning() {
    if (!_isTaxInclusive || _selectedTaxId == null) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: cs.tertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AppLocalizations.of(context).taxInclusiveNotAppliedNote,
              style: TextStyle(fontSize: 11, color: cs.tertiary),
            ),
          ),
        ],
      ),
    );
  }

  // Colour marker + image live in their own tab so the General tab stays a
  // pure data form. Shown whenever General is (i.e. not in post-creation),
  // otherwise a new product could never be given a colour or picture.
  Widget _buildAppearanceTab() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasImage =
        _selectedImageBase64 != null && _selectedImageBase64!.isNotEmpty;

    // 🚨 The swatches must stay the ONLY Wrap on this tab: the E2E `pickSwatch`
    // takes the Nth InkWell inside any Wrap, so a button laid out in a second
    // Wrap would shift every index it picks.
    final colorSection = IlyassFormSection(
      icon: Icons.palette_outlined,
      title: l10n.productColorMarker,
      subtitle: l10n.colorMarkerHint,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _colorPalette.map((color) {
          final hex = _colorToHex(color);
          final isSelected =
              _selectedHexColor.toUpperCase() == hex.toUpperCase();
          return InkWell(
            onTap: () => setState(() => _selectedHexColor = hex),
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: theme.colorScheme.primary, width: 3)
                    : null,
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          );
        }).toList(),
      ),
    );

    final imageSection = IlyassFormSection(
      icon: Icons.image_outlined,
      title: l10n.productImage,
      subtitle: l10n.productImageHint,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            height: 140,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: hasImage
                ? Image.memory(
                    base64Decode(_selectedImageBase64!),
                    fit: BoxFit.cover,
                  )
                : PhosphorIcon(
                    PhosphorIconsRegular.forkKnife,
                    color: theme.hintColor,
                    size: 44,
                  ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.upload, size: 18),
                  label: Text(l10n.actionUpload),
                  onPressed: _pickImage,
                ),
                if (hasImage) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: context.dangerColor,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () =>
                        setState(() => _selectedImageBase64 = null),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(l10n.removeImage),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    // Side by side while both fit at 340dp, one height so neither card ends
    // short; stacked below that.
    return _tabBody([
      IlyassTileGrid(
        minTileWidth: 340,
        children: [colorSection, imageSection],
      ),
    ]);
  }

  Widget _buildTaxesTab() {
    final l10n = AppLocalizations.of(context);
    final allTaxesAsync = ref.watch(allTaxesProvider);
    return _tabBody([
      IlyassFormSection(
        icon: Icons.receipt_long_outlined,
        title: l10n.applyTaxes,
        // One picker does not need the full width of a desktop dialog.
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: allTaxesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text(l10n.failedToLoadTaxes),
              data: (taxes) {
                return DropdownButtonFormField<int?>(
                  initialValue: _selectedTaxId,
                  isExpanded: true,
                  decoration: _fieldDecoration(label: l10n.primaryTaxRate),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l10n.noTax)),
                    ...taxes.map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text("${t.name} (${t.rate}%)"),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedTaxId = v),
                );
              },
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildModifiersTab() {
    // Safety check - we know the product exists because this tab is only shown in Edit/Phase 2 mode!
    if (widget.existingProduct == null) return const SizedBox();

    final productId = widget.existingProduct!.id;

    // 🚨 Scrollable, and it has to be. This was a fixed Column with the comment
    // list in an Expanded, which works only while everything above it is short.
    // Attaching a handful of groups on a 10-inch tablet overflowed the tab —
    // the exact RenderFlex failure the house rules call out. Capped at the
    // readable width too, so the fields do not stretch across a desktop.
    // The section carries the heading and hint; the picker is only the list
    // and its button, so the title is said once.
    return _tabBody([
      IlyassFormSection(
        icon: Icons.playlist_add_check,
        title: AppLocalizations.of(context).productModifierGroups,
        subtitle: AppLocalizations.of(context).productModifierGroupsHint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Modifier groups ──────────────────────────────────────────────
            // 🚨 The free-text comment catalogue that used to sit under this is
            // RETIRED (backlog 38, phase 6). It offered an unpriced, ungrouped,
            // unruled list of strings that the till joined with ", " — modifiers
            // answer the same question with prices, pick-one/pick-many rules and
            // a reporting row per choice. The table, its endpoints and its
            // sync step are gone as of backlog 43 — this database held zero
            // rows, so there was nothing to convert.
            //
            // A per-line NOTE is not the catalogue and did not go with it: it is
            // still on the till's Comment button, and a group can ask for one
            // itself (`ModifierGroup.allowsFreeText`).
            _ProductModifierGroupsPicker(productId: productId),
          ],
        ),
      ),
    ]);
  }

  /// Puts a generated code in the field, and says so when another product
  /// already owns it — nothing in either database rejects a duplicate barcode,
  /// it simply makes one of the two products unscannable.
  void _fillGeneratedBarcode(String code) {
    final owner = ref
        .read(allProductsListProvider)
        .value
        ?.where(
          (p) =>
              p.id != widget.existingProduct?.id &&
              p.barcodes.any((b) => b.trim() == code),
        )
        .firstOrNull;

    setState(() {
      _newBarcodeCtrl.text = code;
      _isBarcodeChipActive = true;
    });

    if (owner != null) {
      showAppSnackbar(
        context,
        ref,
        AppLocalizations.of(context).barcodeAlreadyUsedBy(code, owner.name),
        isError: true,
      );
    }
  }

  Widget _buildBarcodesTab() {
    final theme = Theme.of(context);
    if (widget.existingProduct == null) return const SizedBox();

    final productId = widget.existingProduct!.id;
    final companyId = ref.read(selectedCompanyProvider)?.id;

    // Barcodes are seeded in bulk by SyncManager.pullBarcodes and read straight
    // from Drift here — no per-open /Barcodes/GetByProductId fetch.
    final asyncBarcodes = ref.watch(barcodesByProductIdProvider(productId));

    final barcodeCount = asyncBarcodes.value?.length ?? 0;

    // One card filling the tab: the entry row on top, the list taking the
    // height that is left. 🚨 Deliberately NOT a scroll view: the E2E
    // `addBarcode` taps Add without ensureVisible (inside this dialog that
    // would scroll the TabBarView instead), so the entry row has to be on
    // screen the moment the tab opens.
    return Container(
      margin: const EdgeInsets.all(kIlyassTabPadding),
      padding: kIlyassSectionInsets,
      decoration: ilyassSectionDecoration(theme.colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IlyassSectionHeader(
            icon: Icons.qr_code_2,
            title: AppLocalizations.of(context).productBarcodes,
            subtitle: AppLocalizations.of(context).barcodesHint,
            trailing: barcodeCount == 0 ? null : IlyassCountBadge(barcodeCount),
          ),
          const SizedBox(height: 14),

          // INPUT ROW WITH GENERATOR. The field and Add share THIS Row on
          // purpose — `addBarcode` finds the button through the field's
          // innermost Row ancestor.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _newBarcodeCtrl,
                      readOnly: _isBarcodeChipActive,
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          setState(() => _isBarcodeChipActive = true);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).barcode,
                        hintText: _isBarcodeChipActive
                            ? ""
                            : AppLocalizations.of(context).scanOrEnterBarcode,
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.qr_code_scanner),
                        prefix: _isBarcodeChipActive
                            ? Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: 8.0,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    // Was a hardcoded pink — unreadable in the
                                    // dark theme, and against the project rule
                                    // on sourcing colours from the theme.
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _newBarcodeCtrl.text,
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => setState(() {
                                          _newBarcodeCtrl.clear();
                                          _isBarcodeChipActive = false;
                                        }),
                                        child: Icon(
                                          Icons.close,
                                          color: theme.colorScheme.onPrimary,
                                          size: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : null,
                      ),
                      style: TextStyle(
                        color: _isBarcodeChipActive
                            ? Colors.transparent
                            : theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 🚨 Generators, not a timestamp. The old button emitted
                    // `millisecondsSinceEpoch`, which is 13 digits and so LOOKS
                    // like an EAN-13 while passing its check digit only by
                    // luck — unprintable as a real barcode, and never matching
                    // a scale rule. These two produce codes the company's own
                    // nomenclature defines.
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            // Finger-sized; 30 was a mouse target.
                            minimumSize: const Size(50, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(
                            Icons.qr_code_2,
                            size: 16,
                            color: context.infoColor,
                          ),
                          label: Text(
                            'EAN-13',
                            style: TextStyle(color: context.infoColor),
                          ),
                          onPressed: () => _fillGeneratedBarcode(
                            buildInternalEan13(productId),
                          ),
                        ),
                        // One entry per priced/weighted rule the company
                        // actually has. Hidden entirely when it has none —
                        // there would be nothing to encode.
                        Builder(
                          builder: (context) {
                            final scaleRules =
                                (ref.watch(barcodeRulesProvider).value ??
                                        kDefaultBarcodeRules)
                                    .where(
                                      (r) =>
                                          r.isEnabled &&
                                          (r.type == BarcodeRuleType.weighted ||
                                              r.type == BarcodeRuleType.priced),
                                    )
                                    .toList();
                            if (scaleRules.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return PopupMenuButton<BarcodeRule>(
                              tooltip: AppLocalizations.of(
                                context,
                              ).generateScaleBarcode,
                              onSelected: (rule) {
                                final key = buildProductKeyForRule(
                                  rule,
                                  productId,
                                );
                                if (key == null) {
                                  showAppSnackbar(
                                    context,
                                    ref,
                                    AppLocalizations.of(
                                      context,
                                    ).scaleBarcodeRuleUnusable(rule.pattern),
                                    isError: true,
                                  );
                                  return;
                                }
                                _fillGeneratedBarcode(key);
                              },
                              itemBuilder: (context) => [
                                for (final r in scaleRules)
                                  PopupMenuItem(
                                    value: r,
                                    child: Text('${r.name}  ·  ${r.pattern}'),
                                  ),
                              ],
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.scale,
                                    size: 16,
                                    color: context.infoColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    ).generateScaleBarcode,
                                    style: TextStyle(color: context.infoColor),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context).actionAdd),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  // The field's own height, so the two read as one control.
                  minimumSize: const Size(0, 56),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  final barcodeValue = _newBarcodeCtrl.text.trim();
                  if (barcodeValue.isEmpty || companyId == null) return;

                  final db = ref.read(appDatabaseProvider);
                  final localId = const Uuid().v4();

                  // Write locally first — appears in the list immediately.
                  await db
                      .into(db.barcodesTable)
                      .insert(
                        BarcodesTableCompanion(
                          localId: Value(localId),
                          productId: Value(productId),
                          companyId: Value(companyId),
                          value: Value(barcodeValue),
                          syncStatus: const Value('pending_create'),
                        ),
                      );

                  setState(() {
                    _newBarcodeCtrl.clear();
                    _isBarcodeChipActive = false;
                  });

                  // Try API — stamp serverId + clear pending on success.
                  try {
                    final dio = createDio();
                    final res = await dio.post(
                      '/Barcodes/Add',
                      queryParameters: {'companyId': companyId},
                      data: {'productId': productId, 'value': barcodeValue},
                    );
                    final serverId = _barcodeIdFromResponse(res.data);
                    await (db.update(
                      db.barcodesTable,
                    )..where((t) => t.localId.equals(localId))).write(
                      BarcodesTableCompanion(
                        serverId: Value(serverId),
                        syncStatus: const Value('synced'),
                      ),
                    );
                  } on DioException {
                    // Offline — stays pending_create until next sync.
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          Expanded(
            child: asyncBarcodes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  AppLocalizations.of(context).errorWithMessage(e.toString()),
                  style: TextStyle(color: context.dangerColor),
                ),
              ),
              data: (barcodes) {
                if (barcodes.isEmpty) {
                  // Scrolls rather than overflows when a short screen leaves
                  // the list only a sliver of height.
                  return Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            size: 44,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context).noBarcodesYet,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.hintColor,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.separated(
                    itemCount: barcodes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final b = barcodes[index];
                      return ListTile(
                        leading: Icon(
                          Icons.qr_code,
                          color: b.isPendingSync
                              ? theme.colorScheme.tertiary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          b.value,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        subtitle: b.isPendingSync
                            ? Text(
                                AppLocalizations.of(context).pendingSync,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.tertiary,
                                ),
                              )
                            : null,
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: context.dangerColor),
                          tooltip: AppLocalizations.of(context).deleteBarcode,
                          onPressed: () async {
                            if (companyId == null) return;
                            final db = ref.read(appDatabaseProvider);

                            // A row with no server id is only safe to drop
                            // locally when it never reached the server. A
                            // SYNCED row with no id is a row whose id we simply
                            // failed to record — deleting it locally leaves it
                            // on the server, and the next pull brings it back.
                            // Ask the server for its id by value first.
                            var serverId = b.id;
                            if (serverId == 0 && !b.isPendingSync) {
                              serverId =
                                  await _resolveBarcodeServerId(
                                    productId: b.productId,
                                    companyId: companyId,
                                    value: b.value,
                                  ) ??
                                  0;
                            }

                            if (serverId == 0) {
                              // Never reached the server — hard-delete locally.
                              await (db.delete(db.barcodesTable)
                                    ..where((t) => t.localId.equals(b.localId)))
                                  .go();
                            } else {
                              // Soft-delete so SyncManager can push the
                              // DELETE to the server on next sync. The id we
                              // just resolved is written back too, or the push
                              // would hit the same missing-id path.
                              await (db.update(db.barcodesTable)
                                    ..where((t) => t.localId.equals(b.localId)))
                                  .write(
                                    BarcodesTableCompanion(
                                      serverId: Value(serverId),
                                      syncStatus: const Value('pending_delete'),
                                    ),
                                  );
                              // Try API immediately while online.
                              try {
                                final dio = createDio();
                                await dio.delete(
                                  '/Barcodes/Delete',
                                  queryParameters: {
                                    'id': serverId,
                                    'companyId': companyId,
                                  },
                                );
                                await (db.delete(db.barcodesTable)..where(
                                      (t) => t.localId.equals(b.localId),
                                    ))
                                    .go();
                              } on DioException catch (e) {
                                // 🚨 Say what happened. This used to be an
                                // empty catch, so a server that REFUSED the
                                // delete looked exactly like a server that
                                // accepted it: the row vanished from the list
                                // (the provider hides pending_delete) and came
                                // back a second later when the next pull
                                // fetched it again. "I delete it and it comes
                                // back" is that silence, and no amount of
                                // reading the code tells you which of the two
                                // it was — only the server's answer does.
                                //
                                // Offline is not a failure: the row stays
                                // pending_delete and the next sync pushes it.
                                if (!context.mounted) return;
                                final offline =
                                    e.type ==
                                        DioExceptionType.connectionError ||
                                    e.type ==
                                        DioExceptionType.connectionTimeout ||
                                    e.type == DioExceptionType.sendTimeout ||
                                    e.type == DioExceptionType.receiveTimeout;
                                if (offline) return;
                                showAppSnackbar(
                                  context,
                                  ref,
                                  '${AppLocalizations.of(context).deleteBarcode}: '
                                  '${e.response?.statusCode ?? ''} '
                                  '${e.response?.data ?? e.message ?? ''}',
                                  isError: true,
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Attaches shared modifier groups to one product, in the order the cashier
/// will be asked for them.
///
/// Only ATTACHES — a group's own name, choices and rules are edited once in
/// Management → Modifier Groups. Letting a product edit a shared group here
/// would mean changing a burger's "Toppings" silently rewrote every other
/// product that offers it.
class _ProductModifierGroupsPicker extends ConsumerWidget {
  const _ProductModifierGroupsPicker({required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final attached =
        ref.watch(productModifierGroupIdsProvider(productId)).value ??
        const <int>[];
    final all =
        ref.watch(allModifierGroupsProvider).value ?? const <ModifierGroup>[];
    final byId = {for (final g in all) g.id: g};
    final available = all.where((g) => !attached.contains(g.id)).toList();

    Future<void> write(List<int> ids) async {
      final companyId = ref.read(selectedCompanyProvider)?.id;
      if (companyId == null) return;
      await ref
          .read(appDatabaseProvider)
          .setProductModifierGroupsLocal(
            companyId: companyId,
            productId: productId,
            groupIds: ids,
          );
      unawaited(
        ref
            .read(syncManagerProvider)
            .sync(companyId)
            .catchError((Object _) => <String>[]),
      );
    }

    // The heading and hint are the enclosing section's header now.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attached.isEmpty)
          _HintCard(
            icon: Icons.info_outline,
            // Two different empty states, because they need different actions:
            // "nothing attached" is a choice, "no groups exist" is a dead end
            // unless the operator is told where to go.
            text: all.isEmpty
                ? l10n.noModifierGroupsExistYet
                : l10n.noGroupsAttached,
          )
        else ...[
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: attached.length,
            onReorder: (oldIndex, newIndex) =>
                write(reorderedForDrag(attached, oldIndex, newIndex)),
            itemBuilder: (context, i) {
              final id = attached[i];
              final g = byId[id];
              // A link whose group is not cached locally still has to be
              // removable, so it renders by id rather than being skipped.
              return Card(
                key: ValueKey(id),
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: ListTile(
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: Tooltip(
                      message: l10n.dragToReorderGroups,
                      child: Padding(
                        // Finger-sized: the handle is the control this list is
                        // driven by on a touch screen.
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                        child: Icon(Icons.drag_indicator, color: cs.outline),
                      ),
                    ),
                  ),
                  title: Text(
                    g?.name ?? '#$id',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: g == null
                      ? null
                      : Text(
                          '${selectionRuleLabel(context, g)} · '
                          '${l10n.optionCount(g.options.length)}',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                  trailing: IconButton(
                    icon: Icon(Icons.close, color: cs.error),
                    tooltip: l10n.actionDelete,
                    onPressed: () => write([...attached]..removeAt(i)),
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.dragToReorderGroups,
              style: TextStyle(color: theme.hintColor, fontSize: 11),
            ),
          ),
        ],

        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            // A real button with a real callback. It was previously a
            // TextButton with onPressed: null nested inside a PopupMenuButton,
            // which rendered permanently greyed out and looked broken — the
            // popup worked, but nothing about the control said so.
            onPressed: available.isEmpty
                ? null
                : () async {
                    final picked = await showDialog<int>(
                      context: context,
                      builder: (_) =>
                          _ModifierGroupPickerDialog(groups: available),
                    );
                    if (picked != null) await write([...attached, picked]);
                  },
            icon: const Icon(Icons.add),
            label: Text(
              // Says WHY it is unavailable instead of sitting silently dead.
              all.isEmpty
                  ? l10n.noModifierGroupsYet
                  : available.isEmpty
                  ? l10n.allModifierGroupsAttached
                  : l10n.attachModifierGroup,
            ),
          ),
        ),
      ],
    );
  }
}

/// Picks one group to attach, showing enough of it to choose without leaving.
///
/// A bare list of names is not enough: two groups called "Extras" differ only
/// by their rule and their prices, and attaching the wrong one is discovered at
/// the till. Each row therefore carries its selection rule and its choices.
class _ModifierGroupPickerDialog extends StatefulWidget {
  const _ModifierGroupPickerDialog({required this.groups});

  final List<ModifierGroup> groups;

  @override
  State<_ModifierGroupPickerDialog> createState() =>
      _ModifierGroupPickerDialogState();
}

class _ModifierGroupPickerDialogState
    extends State<_ModifierGroupPickerDialog> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// Below this the search box is noise; above it, scrolling for a group is.
  static const int _searchThreshold = 6;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final shown = _query.isEmpty
        ? widget.groups
        : widget.groups
              .where(
                (g) =>
                    g.name.toLowerCase().contains(_query) ||
                    g.options.any((o) => o.name.toLowerCase().contains(_query)),
              )
              .toList();

    return AlertDialog(
      title: Text(l10n.chooseAModifierGroup),
      content: SizedBox(
        width: 460,
        height: 420,
        child: Column(
          children: [
            if (widget.groups.length >= _searchThreshold) ...[
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchProductEllipsis,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noModifierGroupsYet,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final g = shown[i];
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: cs.outlineVariant),
                          ),
                          child: ListTile(
                            onTap: () => Navigator.pop(context, g.id),
                            title: Row(
                              children: [
                                Flexible(
                                  flex: 3,
                                  child: Text(
                                    g.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (!g.isEnabled) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    flex: 2,
                                    child: Text(
                                      l10n.groupIsDisabled,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${selectionRuleLabel(context, g)} · '
                                  '${l10n.optionCount(g.options.length)}',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                                if (g.options.isNotEmpty)
                                  Text(
                                    g.options.map((o) => o.name).join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
      ],
    );
  }
}

/// A quiet informational block — used where an empty state needs a sentence
/// rather than a control.
class _HintCard extends StatelessWidget {
  const _HintCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
