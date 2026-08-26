import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/ilyass_column_order.dart';
import 'package:pos_app/core/ilyass_list_scaffold.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/product/product_group_assignment.dart';
import 'package:pos_app/product/product_group_model.dart';
import 'package:pos_app/product/product_group_provider.dart';
import 'package:pos_app/product/product_group_service.dart';
import 'package:pos_app/product/product_model.dart';
import 'package:pos_app/product/product_provider.dart';
import 'package:pos_app/utils/api_error_parser.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

// ---------------------------------------------------------------------------
// Tree node helper
// ---------------------------------------------------------------------------
class _TreeNode {
  final ProductGroup group;
  final List<_TreeNode> children;
  _TreeNode({required this.group, List<_TreeNode>? children})
      : children = children ?? [];
}

List<_TreeNode> _buildTree(List<ProductGroup> flat) {
  final map = <int, _TreeNode>{};
  for (final g in flat) {
    map[g.id] = _TreeNode(group: g);
  }
  final roots = <_TreeNode>[];
  for (final g in flat) {
    final node = map[g.id]!;
    if (g.parentGroupId == null || !map.containsKey(g.parentGroupId)) {
      roots.add(node);
    } else {
      map[g.parentGroupId]!.children.add(node);
    }
  }
  void sort(List<_TreeNode> nodes) {
    nodes.sort((a, b) => a.group.rank.compareTo(b.group.rank));
    for (final n in nodes) {
      sort(n.children);
    }
  }
  sort(roots);
  return roots;
}

// ---------------------------------------------------------------------------
// Main Screen
// ---------------------------------------------------------------------------

/// One flattened line of the group tree, as [IlyassTable] wants it.
///
/// The nesting is real — a sub-group inherits its parent's place on the till's
/// category bar — but a table wants ROWS, so the tree is flattened on every
/// build and the depth travels with the row. The Name cell indents by it and
/// hangs the expand toggle off it, which is how a tree survives inside a flat,
/// resizable, horizontally scrolling grid.
@immutable
class _GroupRow {
  const _GroupRow({
    required this.group,
    required this.depth,
    required this.hasChildren,
    required this.expanded,
  });

  final ProductGroup group;
  final int depth;
  final bool hasChildren;
  final bool expanded;
}

/// Display label for a `productGroupVisibleColumnsProvider` key.
///
/// 🚨 The keys (`'Name'`, `'Parent'`, …) are the map's **identity** — they gate
/// every column and are what the picker writes back. Translating the map itself
/// would break the grid the moment the language changed, exactly as in
/// `payment_types_screen._paymentColumnLabel`.
String _groupColumnLabel(BuildContext context, String id) {
  final l10n = AppLocalizations.of(context);
  switch (id) {
    case 'Name':
      return l10n.fieldName;
    case 'Parent':
      return l10n.parentFolder;
    case 'Products':
      return l10n.products;
    case 'Rank':
      return l10n.fieldRank;
    case 'Color':
      return l10n.setColor;
    case 'Actions':
      return l10n.actions;
    default:
      return id;
  }
}

class ProductGroupsScreen extends ConsumerStatefulWidget {
  /// Passed by ManagementLayout when the sidebar is hidden, so the AppBar shows
  /// a menu icon rather than a back arrow.
  final VoidCallback? onMenuPressed;
  const ProductGroupsScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<ProductGroupsScreen> createState() =>
      _ProductGroupsScreenState();
}

class _ProductGroupsScreenState extends ConsumerState<ProductGroupsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// Ticked rows, by group id.
  final Set<int> _selectedIds = {};

  /// Groups whose children are hidden. Held as COLLAPSED rather than expanded
  /// so a group pulled down by the next sync appears where it belongs instead
  /// of staying invisible until somebody thinks to open its parent.
  final Set<int> _collapsed = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    setState(() {
      _query = value;
      // Selection is by id and survives filtering, so a row the search hid must
      // drop out of it.
      _selectedIds.clear();
    });
  }

  void _toggleExpanded(int groupId) => setState(() {
        if (!_collapsed.remove(groupId)) _collapsed.add(groupId);
      });

  /// The rows the table renders: the tree flattened, or — while searching — a
  /// flat list of matches. A filtered tree has to go flat: a match three levels
  /// down must be reachable without first guessing which parent to open.
  List<_GroupRow> _rowsFor(List<ProductGroup> groups) {
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      return [
        for (final g in groups)
          if (g.name.toLowerCase().contains(q))
            _GroupRow(group: g, depth: 0, hasChildren: false, expanded: false),
      ];
    }

    final rows = <_GroupRow>[];
    void walk(List<_TreeNode> nodes, int depth) {
      for (final node in nodes) {
        final hasChildren = node.children.isNotEmpty;
        final expanded = !_collapsed.contains(node.group.id);
        rows.add(_GroupRow(
          group: node.group,
          depth: depth,
          hasChildren: hasChildren,
          expanded: expanded,
        ));
        if (hasChildren && expanded) walk(node.children, depth + 1);
      }
    }

    walk(_buildTree(groups), 0);
    return rows;
  }

  /// The editor is a dialog at every width now. It used to be a permanent
  /// right-hand panel beside a 340px tree, which spent most of the screen on a
  /// group nobody was editing — the same trade `modifier_groups_screen` made.
  void _openEditor([ProductGroup? group]) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _GroupEditorDialog(
        existingGroup: group,
        onDelete: group == null
            ? null
            : () {
                // Close the editor FIRST: confirming on top of it would leave a
                // dialog describing a group that no longer exists.
                Navigator.pop(dialogCtx);
                _confirmDelete(group);
              },
        onSaved: () {},
      ),
    );
  }

  void _showColumnPicker() {
    final catalogue =
        ref.read(productGroupVisibleColumnsProvider).keys.toList();

    showIlyassColumnPicker(
      context: context,
      tableId: 'productGroups',
      columns: [
        for (final key in catalogue)
          IlyassPickerColumn(
            key: key,
            label: _groupColumnLabel(context, key),
            // The name IS the row — hiding it leaves an unreadable grid.
            mandatory: key == 'Name',
          ),
      ],
      isVisible: (key) =>
          ref.read(productGroupVisibleColumnsProvider)[key] ?? false,
      onVisibleChanged: (key, value) {
        final updated = Map<String, bool>.from(
            ref.read(productGroupVisibleColumnsProvider));
        updated[key] = value;
        ref.read(productGroupVisibleColumnsProvider.notifier).state = updated;
      },
    );
  }

  /// True when the group still holds products or sub-groups. Answered from the
  /// local database so it works offline, and asked BEFORE the confirm prompt so
  /// an operator is never asked to confirm something the server will refuse.
  Future<bool> _isBlocked(ProductGroup group) async {
    final db = ref.read(appDatabaseProvider);

    final children = await (db.select(db.productGroupsTable)
          ..where((t) => t.parentGroupId.equals(group.id))
          ..where((t) => t.syncStatus.isNotIn(['pending_delete'])))
        .get();
    if (children.isNotEmpty) return true;

    final products = await (db.select(db.productsTable)
          ..where((t) => t.productGroupId.equals(group.id))
          ..where((t) => t.syncStatus.isNotIn(['pending_delete'])))
        .get();
    return products.isNotEmpty;
  }

  /// Deletes one group without prompting. Returns null on success, or the
  /// reason the server refused. Callers must clear [_isBlocked] first.
  Future<String?> _deleteOne(ProductGroup group) async {
    final db = ref.read(appDatabaseProvider);
    final l10n = AppLocalizations.of(context);

    if (group.isPendingCreate) {
      // Never reached the server — hard-delete locally.
      await (db.delete(db.productGroupsTable)
            ..where((t) => t.id.equals(group.id)))
          .go();
      return null;
    }

    // Soft-delete so SyncManager can push it to the server on the next sync.
    await (db.update(db.productGroupsTable)
          ..where((t) => t.id.equals(group.id)))
        .write(const ProductGroupsTableCompanion(
      syncStatus: Value('pending_delete'),
    ));

    // Try the API inline while online.
    try {
      await ProductGroupService(createDio()).delete(group.id, group.companyId);
      await (db.delete(db.productGroupsTable)
            ..where((t) => t.id.equals(group.id)))
          .go();
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status >= 400 && status < 500) {
        // The server refused (e.g. still referenced by products/sub-groups).
        // Undo the local soft-delete so the group doesn't disappear from the
        // table only to reappear on the next sync, and say why.
        final msg = parseApiError(e);
        await (db.update(db.productGroupsTable)
              ..where((t) => t.id.equals(group.id)))
            .write(const ProductGroupsTableCompanion(
          syncStatus: Value('synced'),
        ));
        return l10n.couldNotDeleteNamed(group.name, msg);
      }
      // Offline — the row stays pending_delete; SyncManager retries later.
    }
    return null;
  }

  Future<void> _confirmDelete(ProductGroup group) async {
    final l10n = AppLocalizations.of(context);

    if (await _isBlocked(group)) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(children: [
            Icon(Icons.warning_amber_rounded, color: c.warningColor),
            const SizedBox(width: 8),
            Text(l10n.cannotDelete),
          ]),
          content: Text(l10n.groupHasChildrenCannotDelete),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: Text(l10n.actionOk)),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirm = await _confirmDialog(l10n.deleteGroupConfirm(group.name));
    if (confirm != true || !mounted) return;

    final error = await _deleteOne(group);
    if (!mounted) return;
    setState(() => _selectedIds.remove(group.id));
    showAppSnackbar(context, ref, error ?? l10n.groupDeleted,
        isError: error != null);
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final all =
        ref.read(allProductGroupsProvider).value ?? const <ProductGroup>[];
    final targets = all.where((g) => _selectedIds.contains(g.id)).toList();
    if (targets.isEmpty) return;

    // ONE confirmation for the batch — looping the per-row prompt would put
    // nine dialogs in front of someone deleting nine groups.
    final confirm = await _confirmDialog(
        l10n.deleteGroupConfirm(targets.map((g) => g.name).join(', ')));
    if (confirm != true || !mounted) return;

    var blocked = 0;
    String? firstError;
    for (final group in targets) {
      if (await _isBlocked(group)) {
        // A parent and its child can both be ticked: deleting the child first
        // frees the parent, so a blocked group is skipped, not fatal.
        blocked++;
        continue;
      }
      final error = await _deleteOne(group);
      firstError ??= error;
      if (!mounted) return;
    }

    if (!mounted) return;
    setState(_selectedIds.clear);
    showAppSnackbar(
      context,
      ref,
      firstError ??
          (blocked > 0 ? l10n.groupHasChildrenCannotDelete : l10n.groupDeleted),
      isError: firstError != null || blocked > 0,
    );
  }

  Future<bool?> _confirmDialog(String message) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.deleteGroup),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l10n.actionCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.dangerColor,
              foregroundColor: c.onStatusColor,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final asyncGroups = ref.watch(allProductGroupsProvider);
    final visibleColumns = ref.watch(productGroupVisibleColumnsProvider);
    final products =
        ref.watch(allProductsListProvider).value ?? const <Product>[];
    final hasSelection = _selectedIds.isNotEmpty;

    return IlyassListScaffold(
      title: l10n.productGroups,
      onMenuPressed: widget.onMenuPressed,
      searchBar: UnifiedSearchBar(
        controller: _searchCtrl,
        singleLine: true,
        hintText: l10n.actionSearch,
        chips: const [],
        sectionsBuilder: (_) => const [],
        onQueryChanged: _setQuery,
        onClearAll: () {
          _searchCtrl.clear();
          _setQuery('');
        },
      ),
      actions: [
        IlyassMenuAction(
          icon: Icons.delete_outline_rounded,
          label: hasSelection
              ? l10n.deleteWithCount(_selectedIds.length)
              : l10n.actionDelete,
          color: hasSelection ? context.dangerColor : null,
          enabled: hasSelection,
          onSelected: _bulkDelete,
        ),
        IlyassMenuAction(
          icon: Icons.view_column_rounded,
          label: l10n.columnsTooltip,
          dividerBefore: true,
          onSelected: _showColumnPicker,
        ),
      ],
      fabLabel: l10n.newGroup,
      onFabPressed: _openEditor,
      body: asyncGroups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(error: parseApiError(e)),
        data: (groups) {
          if (groups.isEmpty) return _EmptyView(onAdd: _openEditor);

          final rows = _rowsFor(groups);
          final selected =
              _selectedIds.intersection(rows.map((r) => r.group.id).toSet());

          // Parent NAMES: `parentGroupName` only ever arrives on JSON-sourced
          // groups and this list is Drift-sourced, so the label is resolved
          // from the very list the table is showing.
          final names = {for (final g in groups) g.id: g.name};

          final productCounts = <int, int>{};
          for (final p in products) {
            final id = p.productGroupId;
            if (id != null) productCounts[id] = (productCounts[id] ?? 0) + 1;
          }

          // One entry per toggleable column, in the order the provider declares
          // them — the picker reorders this list, so widths and cells live with
          // their key rather than in a parallel chain.
          final catalogue = <String, IlyassColumn<_GroupRow>>{
            'Name': IlyassColumn<_GroupRow>(
              key: 'Name',
              label: _groupColumnLabel(context, 'Name'),
              width: 300,
              minWidth: 160,
              flexible: true,
              cell: (context, row) => _NameCell(
                row: row,
                onToggle: () => _toggleExpanded(row.group.id),
              ),
            ),
            'Parent': IlyassColumn<_GroupRow>(
              key: 'Parent',
              label: _groupColumnLabel(context, 'Parent'),
              width: 180,
              cell: (context, row) => Text(
                names[row.group.parentGroupId] ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            'Products': IlyassColumn<_GroupRow>(
              key: 'Products',
              label: _groupColumnLabel(context, 'Products'),
              width: 120,
              numeric: true,
              cell: (context, row) =>
                  Text('${productCounts[row.group.id] ?? 0}'),
            ),
            'Rank': IlyassColumn<_GroupRow>(
              key: 'Rank',
              label: _groupColumnLabel(context, 'Rank'),
              width: 100,
              numeric: true,
              cell: (context, row) => Text('${row.group.rank}'),
            ),
            'Color': IlyassColumn<_GroupRow>(
              key: 'Color',
              label: _groupColumnLabel(context, 'Color'),
              width: 100,
              cell: (context, row) => Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: row.group.flutterColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
              ),
            ),
          };

          return IlyassTable<_GroupRow>(
            tableId: 'productGroups',
            rows: rows,
            rowHeight: 56,
            onRowTap: (row) => _openEditor(row.group),
            isRowSelected: (row) => selected.contains(row.group.id),
            columns: [
              ilyassSelectionColumn<_GroupRow, int>(
                rows: rows,
                selected: selected,
                idOf: (row) => row.group.id,
                onChanged: (ids) => setState(() {
                  _selectedIds
                    ..clear()
                    ..addAll(ids);
                }),
              ),
              for (final entry in catalogue.entries)
                if (visibleColumns[entry.key] == true) entry.value,
              IlyassColumn<_GroupRow>(
                key: 'Actions',
                label: _groupColumnLabel(context, 'Actions'),
                width: 80,
                minWidth: 80,
                resizable: false,
                cell: (context, row) => IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: theme.colorScheme.onSurfaceVariant,
                  tooltip: l10n.actionDelete,
                  onPressed: () => _confirmDelete(row.group),
                ),
              ),
            ],
            emptyState: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.noResultsForFilters,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.hintColor, fontSize: 16),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Name cell: the tree, rendered inside one table column
// ---------------------------------------------------------------------------
class _NameCell extends StatelessWidget {
  const _NameCell({required this.row, required this.onToggle});

  final _GroupRow row;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = row.group;

    return Row(
      // The cell is laid out by an Align with loose constraints, so the Row
      // sizes to its children and the NAME takes whatever is left.
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: row.depth * 18.0),
        SizedBox(
          width: 26,
          height: 26,
          // The toggle sits deeper in the hit test than the row's own tap
          // handler, so opening a branch never opens the editor.
          child: row.hasChildren
              ? IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    row.expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onToggle,
                )
              : null,
        ),
        const SizedBox(width: 4),
        // Drift groups keep the icon on disk (imageFile); base64 imageBytes
        // only exists for API-sourced ones.
        group.imageFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(group.imageFile!,
                    width: 24, height: 24, fit: BoxFit.cover),
              )
            : group.imageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(group.imageBytes!,
                        width: 24, height: 24, fit: BoxFit.cover),
                  )
                : Icon(
                    row.hasChildren ? Icons.folder : Icons.folder_outlined,
                    size: 22,
                    color: group.flutterColor,
                  ),
        const SizedBox(width: 10),
        if (group.isPendingSync)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: Icon(Icons.cloud_upload_outlined,
                size: 14, color: theme.colorScheme.tertiary),
          ),
        Flexible(
          child: Text(
            group.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Group editor panel (right side on wide, or inside dialog on narrow)
// ---------------------------------------------------------------------------
class _GroupEditorPanel extends ConsumerStatefulWidget {
  final ProductGroup? existingGroup;
  final VoidCallback? onClose;
  final VoidCallback? onDelete;
  final VoidCallback onSaved;

  const _GroupEditorPanel({
    this.existingGroup,
    this.onClose,
    this.onDelete,
    required this.onSaved,
  });

  @override
  ConsumerState<_GroupEditorPanel> createState() => _GroupEditorPanelState();
}

class _GroupEditorPanelState extends ConsumerState<_GroupEditorPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _rankCtrl = TextEditingController(text: '0');

  String _selectedHexColor = '#607D8B';
  int? _selectedParentId;
  String? _selectedImageBase64;
  bool _isLoading = false;
  String? _errorMessage;

  // Products tab state
  Set<int> _assignedProductIds = {};
  bool _assignmentsInitialized = false;
  String _productSearch = '';
  bool _assignLoading = false;

  bool get _isEditing => widget.existingGroup != null;

  final List<Color> _colorPalette = [
    Colors.blueGrey, Colors.red, Colors.pink, Colors.purple,
    Colors.deepPurple, Colors.indigo, Colors.blue, Colors.lightBlue,
    Colors.cyan, Colors.teal, Colors.green, Colors.lightGreen,
    Colors.lime, Colors.amber, Colors.orange, Colors.deepOrange,
    Colors.brown, Colors.grey,
  ];

  String _colorToHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  void _initAssignedProducts(List<dynamic> products) {
    final groupId = widget.existingGroup!.id;
    _assignedProductIds = products
        .where((p) => p.productGroupId == groupId)
        .map<int>((p) => p.id as int)
        .toSet();
    _assignmentsInitialized = true;
  }

  void _populateFields(ProductGroup g) {
    _nameCtrl.text = g.name;
    _selectedHexColor = g.color;
    _rankCtrl.text = g.rank.toString();
    _selectedParentId = g.parentGroupId;
    // Drift-sourced groups keep the icon on disk (localImagePath), not as a
    // base64 `image`. Load it into the preview so the existing icon shows — and
    // so saving other fields re-sends it instead of wiping the server image.
    _selectedImageBase64 = g.image;
    if ((g.image == null || g.image!.isEmpty) &&
        g.localImagePath != null &&
        g.localImagePath!.isNotEmpty) {
      try {
        final f = File(g.localImagePath!);
        if (f.existsSync()) {
          _selectedImageBase64 = base64Encode(f.readAsBytesSync());
        }
      } catch (_) {}
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isEditing ? 2 : 1, vsync: this);
    if (_isEditing) {
      _populateFields(widget.existingGroup!);
      // Seed from cache immediately if products are already loaded
      final cached = ref.read(allProductsListProvider).value;
      if (cached != null) _initAssignedProducts(cached);
    }
  }

  @override
  void didUpdateWidget(_GroupEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.existingGroup?.id != widget.existingGroup?.id) {
      _assignedProductIds = {};
      _assignmentsInitialized = false;
      _productSearch = '';
      _errorMessage = null;
      if (widget.existingGroup != null) {
        _populateFields(widget.existingGroup!);
        final cached = ref.read(allProductsListProvider).value;
        if (cached != null) _initAssignedProducts(cached);
      }
      _tabController.animateTo(0);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _rankCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85);
    if (xFile != null) {
      final bytes = await xFile.readAsBytes();
      setState(() => _selectedImageBase64 = base64Encode(bytes));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;

    // Capture all mutable state before any async gap.
    final db = ref.read(appDatabaseProvider);
    final isEditing = _isEditing;
    final tempId = isEditing
        ? widget.existingGroup!.id
        : -(DateTime.now().millisecondsSinceEpoch);
    final name = _nameCtrl.text.trim();
    final rank = int.tryParse(_rankCtrl.text.trim()) ?? 0;
    final color = _selectedHexColor;
    final parentId = _selectedParentId;
    final imageBase64 = _selectedImageBase64;
    final existingImagePath =
        isEditing ? widget.existingGroup!.localImagePath : null;

    // The panel/dialog is closed before the API call, so its own context and
    // `ref` are gone by the time a failure comes back. Capture the ROOT
    // navigator's context (which outlives the dialog) and the toast prefs now,
    // so errors can still be surfaced with the app's normal styling.
    final rootCtx = Navigator.of(context, rootNavigator: true).context;
    // Resolved before the panel closes — `notify` runs after the async gap,
    // when this widget's own context is already gone.
    final l10n = AppLocalizations.of(context);
    final toastSettings = ref.read(appSettingsProvider);
    final toastSeconds =
        int.tryParse(toastSettings[SettingKeys.messageDuration] ?? '3') ?? 3;
    final toastPosition =
        toastSettings[SettingKeys.messagePosition] ?? 'Bottom';

    void notify(String message, {bool isError = false}) {
      if (!rootCtx.mounted) return;
      showAppSnackbarRaw(rootCtx, message,
          isError: isError, duration: toastSeconds, position: toastPosition);
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    // ── 1. Save image to disk (if user picked one) ───────────────────────────
    String? localImagePath = existingImagePath;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final folder = Directory('${dir.path}/group_images');
        if (!folder.existsSync()) folder.createSync(recursive: true);
        final file = File('${folder.path}/${tempId}_image.png');
        await file.writeAsBytes(base64Decode(imageBase64));
        // Evict any stale cached decode for this reused path so the new icon
        // shows immediately (Flutter caches FileImage by path).
        await FileImage(file).evict();
        localImagePath = file.path;
      } catch (_) {}
    }

    // ── 2. Write to Drift first ───────────────────────────────────────────────
    await db.into(db.productGroupsTable).insertOnConflictUpdate(
          ProductGroupsTableCompanion(
            id: Value(tempId),
            companyId: Value(company.id),
            name: Value(name),
            parentGroupId: Value(parentId),
            colorHex: Value(color),
            rank: Value(rank),
            localImagePath: Value(localImagePath),
            lastModified: Value(DateTime.now().toUtc()),
            syncStatus:
                Value(isEditing ? 'pending_update' : 'pending_create'),
          ),
        );

    setState(() => _isLoading = false);
    widget.onSaved(); // Close panel/dialog immediately.

    // ── 3. Try API inline (no context or ref needed after onSaved) ────────────
    try {
      final dio = createDio();
      final payload = <String, dynamic>{
        'name': name,
        'parentGroupId': parentId,
        'color': color,
        'image': imageBase64 ?? '',
        'rank': rank,
      };

      if (isEditing) {
        payload['id'] = tempId;
        await dio.patch('/ProductGroups/Update',
            queryParameters: {'companyId': company.id}, data: payload);
        await (db.update(db.productGroupsTable)
              ..where((t) => t.id.equals(tempId)))
            .write(const ProductGroupsTableCompanion(
          syncStatus: Value('synced'),
        ));
      } else {
        final res = await dio.post<dynamic>('/ProductGroups/Add',
            queryParameters: {'companyId': company.id}, data: payload);
        final serverId = (res.data is Map
                ? (res.data as Map)['id']
                : null) as int?;
        if (serverId != null) {
          // Rename temp image file to the real server ID.
          String? newPath = localImagePath;
          if (localImagePath != null) {
            try {
              final renamed = localImagePath.replaceAll(
                  '${tempId}_image', '${serverId}_image');
              await File(localImagePath).rename(renamed);
              newPath = renamed;
            } catch (_) {}
          }
          await db.transaction(() async {
            await (db.delete(db.productGroupsTable)
                  ..where((t) => t.id.equals(tempId)))
                .go();
            await db.into(db.productGroupsTable).insertOnConflictUpdate(
                  ProductGroupsTableCompanion(
                    id: Value(serverId),
                    companyId: Value(company.id),
                    name: Value(name),
                    parentGroupId: Value(parentId),
                    colorHex: Value(color),
                    rank: Value(rank),
                    localImagePath: Value(newPath),
                    lastModified: Value(DateTime.now().toUtc()),
                    syncStatus: const Value('synced'),
                  ),
                );
          });
        } else {
          // 2xx but no id came back — the row stays pending_create and the next
          // sync would POST it again. Surface it instead of failing silently.
          notify(
            l10n.savedLocallyNoServerId(name),
            isError: true,
          );
        }
      }
    } on DioException catch (e) {
      // Tell "the server refused it" apart from "the server wasn't reachable" —
      // they need very different handling, and silently swallowing both is what
      // made a rejected save look identical to a successful one.
      final status = e.response?.statusCode ?? 0;
      if (status >= 400 && status < 500) {
        // Rejected (validation, duplicate name, invalid parent…). Keep the local
        // edit, flag the row so the tree shows it as unsynced, and say why. The
        // pull skips non-synced rows, so the change is preserved, not reverted.
        final msg = parseApiError(e);
        await (db.update(db.productGroupsTable)
              ..where((t) => t.id.equals(tempId)))
            .write(ProductGroupsTableCompanion(
          syncStatus: const Value('sync_failed'),
          syncError: Value(msg),
        ));
        notify(l10n.couldNotSaveNamed(name, msg), isError: true);
      } else {
        // Unreachable/timeout — expected offline. The row stays pending and
        // SyncManager.pushPendingProductGroupOps retries it later.
        notify(l10n.savedOfflineWillSyncNamed(name));
      }
    } catch (e) {
      notify(l10n.couldNotSaveNamed(name, parseApiError(e)), isError: true);
    }
  }

  Future<void> _saveAssignments() async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null || !_isEditing) return;
    setState(() => _assignLoading = true);

    final db = ref.read(appDatabaseProvider);
    final groupId = widget.existingGroup!.id;
    final ids = _assignedProductIds.toList();

    try {
      // THE FIX (offline-first): stamp the new group onto the LOCAL product rows
      // and queue them for push. Every screen — the menu grid, this editor, the
      // reports — streams products from Drift, so writing Drift is what actually
      // makes a reassignment show up. The old code only POSTed
      // /ProductGroups/AssignProducts and never touched Drift, so the local cache
      // (and thus every screen) stayed stale until a full product pull: the
      // reported "changing a product's group doesn't take effect". The Drift +
      // pending_update logic lives in applyGroupMembershipLocally so it can be
      // unit-tested end-to-end (test/product_group_assignment_test.dart).
      await applyGroupMembershipLocally(
        db,
        companyId: company.id,
        groupId: groupId,
        checkedIds: ids,
      );

      if (mounted) {
        showAppSnackbar(
            context, ref, AppLocalizations.of(context).productsAssigned);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, parseApiError(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _assignLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allGroupsAsync = ref.watch(allProductGroupsProvider);
    final allProductsAsync = _isEditing ? ref.watch(allProductsListProvider) : null;

    // When the products list first loads (cache miss on initState), seed assignments
    if (_isEditing) {
      ref.listen<AsyncValue<List<Product>>>(allProductsListProvider, (_, next) {
        next.whenData((products) {
          if (!_assignmentsInitialized && mounted) {
            setState(() => _initAssignedProducts(products));
          }
        });
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Header ---
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
          color: theme.colorScheme.surfaceContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _isEditing ? Icons.edit_rounded : Icons.add_circle_rounded,
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing
                          ? widget.existingGroup!.name
                          : AppLocalizations.of(context).newProductGroup,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onDelete != null)
                    IconButton(
                      icon: Icon(Icons.delete_rounded,
                          color: theme.colorScheme.error),
                      onPressed: widget.onDelete,
                      tooltip: AppLocalizations.of(context).deleteGroupTooltip,
                    ),
                  if (widget.onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                ],
              ),
              if (_isEditing) ...[
                const SizedBox(height: 8),
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: AppLocalizations.of(context).detailsTab),
                    Tab(text: AppLocalizations.of(context).products),
                  ],
                ),
              ],
            ],
          ),
        ),

        // --- Body ---
        Expanded(
          child: _isEditing
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    _DetailsTab(
                      formKey: _formKey,
                      nameCtrl: _nameCtrl,
                      rankCtrl: _rankCtrl,
                      selectedHexColor: _selectedHexColor,
                      selectedParentId: _selectedParentId,
                      selectedImageBase64: _selectedImageBase64,
                      isLoading: _isLoading,
                      errorMessage: _errorMessage,
                      isEditing: _isEditing,
                      colorPalette: _colorPalette,
                      existingGroupId: widget.existingGroup?.id,
                      allGroupsAsync: allGroupsAsync,
                      onColorChanged: (hex) =>
                          setState(() => _selectedHexColor = hex),
                      onParentChanged: (id) =>
                          setState(() => _selectedParentId = id),
                      onPickImage: _pickImage,
                      onRemoveImage: () =>
                          setState(() => _selectedImageBase64 = null),
                      onSubmit: _submit,
                      colorToHex: _colorToHex,
                    ),
                    _ProductsTab(
                      groupId: widget.existingGroup!.id,
                      allProductsAsync: allProductsAsync!,
                      assignedIds: _assignedProductIds,
                      searchQuery: _productSearch,
                      isLoading: _assignLoading,
                      onSearchChanged: (q) =>
                          setState(() => _productSearch = q),
                      onToggle: (id, val) => setState(() {
                        if (val) {
                          _assignedProductIds.add(id);
                        } else {
                          _assignedProductIds.remove(id);
                        }
                      }),
                      onSave: _saveAssignments,
                    ),
                  ],
                )
              : SingleChildScrollView(
                  child: _DetailsTab(
                    formKey: _formKey,
                    nameCtrl: _nameCtrl,
                    rankCtrl: _rankCtrl,
                    selectedHexColor: _selectedHexColor,
                    selectedParentId: _selectedParentId,
                    selectedImageBase64: _selectedImageBase64,
                    isLoading: _isLoading,
                    errorMessage: _errorMessage,
                    isEditing: _isEditing,
                    colorPalette: _colorPalette,
                    existingGroupId: widget.existingGroup?.id,
                    allGroupsAsync: allGroupsAsync,
                    onColorChanged: (hex) =>
                        setState(() => _selectedHexColor = hex),
                    onParentChanged: (id) =>
                        setState(() => _selectedParentId = id),
                    onPickImage: _pickImage,
                    onRemoveImage: () =>
                        setState(() => _selectedImageBase64 = null),
                    onSubmit: _submit,
                    colorToHex: _colorToHex,
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Details tab
// ---------------------------------------------------------------------------
class _DetailsTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController rankCtrl;
  final String selectedHexColor;
  final int? selectedParentId;
  final String? selectedImageBase64;
  final bool isLoading;
  final String? errorMessage;
  final bool isEditing;
  final List<Color> colorPalette;
  final int? existingGroupId;
  final AsyncValue<List<ProductGroup>> allGroupsAsync;
  final void Function(String) onColorChanged;
  final void Function(int?) onParentChanged;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSubmit;
  final String Function(Color) colorToHex;

  const _DetailsTab({
    required this.formKey,
    required this.nameCtrl,
    required this.rankCtrl,
    required this.selectedHexColor,
    required this.selectedParentId,
    required this.selectedImageBase64,
    required this.isLoading,
    required this.errorMessage,
    required this.isEditing,
    required this.colorPalette,
    required this.existingGroupId,
    required this.allGroupsAsync,
    required this.onColorChanged,
    required this.onParentChanged,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onSubmit,
    required this.colorToHex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name
            _SectionLabel(AppLocalizations.of(context).groupName),
            const SizedBox(height: 8),
            TextFormField(
              controller: nameCtrl,
              decoration: _inputDecoration(
                  context, AppLocalizations.of(context).groupNameHint),
              validator: (v) => v == null || v.trim().isEmpty
                  ? AppLocalizations.of(context).requiredField
                  : null,
            ),
            const SizedBox(height: 20),

            // Parent
            _SectionLabel(AppLocalizations.of(context).parentFolder),
            const SizedBox(height: 8),
            allGroupsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text(AppLocalizations.of(context).failedToLoadGroups,
                  style: TextStyle(color: theme.colorScheme.error)),
              data: (groups) {
                final validParents = groups
                    .where((g) =>
                        existingGroupId == null || g.id != existingGroupId)
                    .toList();
                return DropdownButtonFormField<int?>(
                  initialValue: selectedParentId,
                  decoration: _inputDecoration(context, null),
                  items: [
                    DropdownMenuItem(
                        value: null,
                        child: Text(AppLocalizations.of(context).noneRoot)),
                    ...validParents.map((g) => DropdownMenuItem(
                        value: g.id, child: Text(g.name))),
                  ],
                  onChanged: onParentChanged,
                );
              },
            ),
            const SizedBox(height: 20),

            // Rank
            _SectionLabel(AppLocalizations.of(context).displayRank),
            const SizedBox(height: 8),
            TextFormField(
              controller: rankCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(context, "0"),
            ),
            const SizedBox(height: 20),

            // Image
            _SectionLabel(AppLocalizations.of(context).folderImage),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: primary.withAlpha(60), width: 2),
                ),
                child: selectedImageBase64 != null &&
                        selectedImageBase64!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                            base64Decode(selectedImageBase64!),
                            fit: BoxFit.cover),
                      )
                    : Icon(Icons.image,
                        color: primary.withAlpha(100), size: 36),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: onPickImage,
                    icon: const Icon(Icons.upload, size: 16),
                    label: Text(AppLocalizations.of(context).chooseImage),
                  ),
                  if (selectedImageBase64 != null &&
                      selectedImageBase64!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onRemoveImage,
                      icon: const Icon(Icons.close, size: 16),
                      label: Text(AppLocalizations.of(context).actionRemove),
                      style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ]),
            const SizedBox(height: 20),

            // Color palette
            _SectionLabel(AppLocalizations.of(context).folderColor),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: colorPalette.map((color) {
                final hex = colorToHex(color);
                final isSelected =
                    selectedHexColor.toUpperCase() == hex.toUpperCase();
                return InkWell(
                  onTap: () => onColorChanged(hex),
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: primary, width: 3)
                          : Border.all(
                              color: primary.withAlpha(40), width: 1),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: color.withAlpha(100),
                                  blurRadius: 8,
                                  spreadRadius: 1)
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(Icons.check,
                            size: 22,
                            color: color.computeLuminance() > 0.4
                                ? const Color(0xFF1A1A1A)
                                : const Color(0xFFFAFAFA))
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Error
            if (errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: theme.colorScheme.error.withAlpha(60)),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(errorMessage!,
                          style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 13))),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isLoading ? null : onSubmit,
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white),
                      )
                    : Icon(isEditing ? Icons.save : Icons.add),
                label: Text(isEditing
                    ? AppLocalizations.of(context).actionSaveChanges
                    : AppLocalizations.of(context).createGroup),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Products assignment tab
// ---------------------------------------------------------------------------
class _ProductsTab extends StatelessWidget {
  final int groupId;
  final AsyncValue allProductsAsync;
  final Set<int> assignedIds;
  final String searchQuery;
  final bool isLoading;
  final void Function(String) onSearchChanged;
  final void Function(int id, bool val) onToggle;
  final VoidCallback onSave;

  const _ProductsTab({
    required this.groupId,
    required this.allProductsAsync,
    required this.assignedIds,
    required this.searchQuery,
    required this.isLoading,
    required this.onSearchChanged,
    required this.onToggle,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).searchProductsEllipsis,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),

        // Product list
        Expanded(
          child: allProductsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
                child: Text(AppLocalizations.of(context).failedToLoadProducts,
                    style:
                        TextStyle(color: theme.colorScheme.error))),
            data: (products) {
              final filtered = (products as List).where((p) {
                if (searchQuery.isEmpty) return true;
                return (p.name as String)
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase());
              }).toList();

              if (filtered.isEmpty) {
                return Center(child: Text(AppLocalizations.of(context).noProductsFoundShort));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final product = filtered[index];
                  final isAssigned = assignedIds.contains(product.id as int);
                  return CheckboxListTile(
                    value: isAssigned,
                    title: Text(product.name as String,
                        style: theme.textTheme.bodyMedium),
                    subtitle: product.code != null
                        ? Text(product.code as String,
                            style: theme.textTheme.bodySmall)
                        : null,
                    secondary: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: (product.isEnabled as bool)
                            ? context.successColor
                            : theme.colorScheme.outline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    onChanged: (val) =>
                        onToggle(product.id as int, val ?? false),
                    dense: true,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  );
                },
              );
            },
          ),
        ),

        // Save bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                  color: theme.colorScheme.outlineVariant, width: 1),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isLoading ? null : onSave,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(AppLocalizations.of(context)
                  .saveAssignmentsCount(assignedIds.length)),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Narrow-screen dialog wrapper
// ---------------------------------------------------------------------------
class _GroupEditorDialog extends ConsumerWidget {
  final ProductGroup? existingGroup;
  final VoidCallback? onDelete;
  final VoidCallback onSaved;

  const _GroupEditorDialog({
    this.existingGroup,
    this.onDelete,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        // Wider than the old narrow-only dialog: it is now the editor at EVERY
        // width, and its Products tab is a checklist of the whole catalogue.
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: _GroupEditorPanel(
          existingGroup: existingGroup,
          onClose: () => Navigator.pop(context),
          onDelete: onDelete,
          onSaved: () {
            onSaved();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontWeight: FontWeight.w600),
      );
}

InputDecoration _inputDecoration(BuildContext context, String? hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open,
              size: 80, color: theme.colorScheme.primary.withAlpha(64)),
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context).noProductGroupsYet,
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context).createOneToOrganize,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(128))),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context).createGroup),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error.withAlpha(128)),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context).errorLoadingGroups,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error)),
        ],
      ),
    );
  }
}
