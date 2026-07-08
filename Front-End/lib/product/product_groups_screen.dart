import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
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
class ProductGroupsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onMenuPressed;
  const ProductGroupsScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<ProductGroupsScreen> createState() =>
      _ProductGroupsScreenState();
}

class _ProductGroupsScreenState extends ConsumerState<ProductGroupsScreen> {
  // null = nothing selected, non-null = group being edited
  ProductGroup? _editingGroup;
  // true = panel / dialog should be visible
  bool _panelOpen = false;
  // true = creating a new group (editingGroup will be null)
  bool _creatingNew = false;
  // Mirrors the body LayoutBuilder's wide/narrow decision so the AppBar button
  // (built outside that LayoutBuilder) can pick the matching create path.
  bool _isWide = false;

  void _openNew() => setState(() {
        _editingGroup = null;
        _creatingNew = true;
        _panelOpen = true;
      });

  /// Create flow that works regardless of layout/empty state: on a wide screen
  /// it opens the inline right-hand editor panel; otherwise (narrow, or the
  /// empty state where no inline panel is rendered) it opens the editor dialog.
  void _createGroup() {
    if (_isWide) {
      _openNew();
    } else {
      showDialog(
        context: context,
        builder: (_) => _GroupEditorDialog(onSaved: () {}),
      );
    }
  }

  void _openEdit(ProductGroup group) => setState(() {
        _editingGroup = group;
        _creatingNew = false;
        _panelOpen = true;
      });

  void _closePanel() => setState(() => _panelOpen = false);

  Future<void> _attemptDelete(ProductGroup group) async {
    final ctx = context;
    final db = ref.read(appDatabaseProvider);

    // Check for children and assigned products locally (works offline).
    final childCount = await (db.select(db.productGroupsTable)
          ..where((t) => t.parentGroupId.equals(group.id))
          ..where((t) => t.syncStatus.isNotIn(['pending_delete'])))
        .get()
        .then((r) => r.length);

    final productCount = await (db.select(db.productsTable)
          ..where((t) => t.productGroupId.equals(group.id))
          ..where((t) => t.syncStatus.isNotIn(['pending_delete'])))
        .get()
        .then((r) => r.length);

    if (childCount > 0 || productCount > 0) {
      if (ctx.mounted) {
        showDialog(
          context: ctx,
          builder: (c) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text("Cannot Delete"),
            ]),
            content: const Text(
                "This group has products or sub-groups and cannot be deleted."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text("OK"))
            ],
          ),
        );
      }
      return;
    }

    if (!ctx.mounted) return;
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text("Delete Group"),
        content: Text("Are you sure you want to delete '${group.name}'?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text("Cancel")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(c).colorScheme.error,
                foregroundColor: Theme.of(c).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(c, true),
              child: const Text("Delete")),
        ],
      ),
    );

    if (confirm != true) return;

    if (group.isPendingCreate) {
      // Never reached the server — hard-delete locally.
      await (db.delete(db.productGroupsTable)
            ..where((t) => t.id.equals(group.id)))
          .go();
    } else {
      // Soft-delete so SyncManager can push it to the server on next sync.
      await (db.update(db.productGroupsTable)
            ..where((t) => t.id.equals(group.id)))
          .write(const ProductGroupsTableCompanion(
        syncStatus: Value('pending_delete'),
      ));
      // Try API inline while online.
      try {
        await ProductGroupService(createDio())
            .delete(group.id, group.companyId);
        await (db.delete(db.productGroupsTable)
              ..where((t) => t.id.equals(group.id)))
            .go();
      } on DioException {
        // Offline — row stays pending_delete; SyncManager retries later.
      }
    }

    if (_editingGroup?.id == group.id) _closePanel();
    if (ctx.mounted) {
      showAppSnackbar(ctx, ref, "Group deleted");
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncGroups = ref.watch(allProductGroupsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        // Suppress the auto back-arrow — ManagementLayout controls navigation.
        automaticallyImplyLeading: false,
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onMenuPressed,
              )
            : null,
        title: const Text("Product Groups"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _createGroup,
              icon: const Icon(Icons.add, size: 18),
              label: const Text("New Group"),
            ),
          ),
        ],
      ),
      body: asyncGroups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(error: parseApiError(e)),
        data: (groups) {
          final roots = _buildTree(groups);
          return LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            // Cache for the AppBar "New Group" button, which lives outside this
            // LayoutBuilder and so can't see `isWide` directly.
            _isWide = isWide;

            // Empty state has no tree to render. On a wide screen we still let
            // the inline create panel show once "New Group" is pressed
            // (_panelOpen); otherwise fall back to the friendly empty view whose
            // button routes through _createGroup (dialog on narrow).
            if (groups.isEmpty && !(isWide && _panelOpen)) {
              return _EmptyView(onAdd: _createGroup);
            }

            if (isWide) {
              return _WideLayout(
                roots: roots,
                panelOpen: _panelOpen,
                editingGroup: _editingGroup,
                creatingNew: _creatingNew,
                onSelect: _openEdit,
                onDelete: _attemptDelete,
                onClose: _closePanel,
                onSaved: _closePanel,
              );
            } else {
              return _NarrowLayout(
                roots: roots,
                onSelect: (group) {
                  _openEdit(group);
                  showDialog(
                    context: context,
                    builder: (_) => _GroupEditorDialog(
                      existingGroup: group,
                      onDelete: () => _attemptDelete(group),
                      onSaved: () {},
                    ),
                  );
                },
                onAdd: () => showDialog(
                  context: context,
                  builder: (_) => _GroupEditorDialog(
                    onSaved: () {},
                  ),
                ),
                onDelete: _attemptDelete,
              );
            }
          });
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wide layout: tree left + editor right
// ---------------------------------------------------------------------------
class _WideLayout extends StatelessWidget {
  final List<_TreeNode> roots;
  final bool panelOpen;
  final ProductGroup? editingGroup;
  final bool creatingNew;
  final void Function(ProductGroup) onSelect;
  final void Function(ProductGroup) onDelete;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  const _WideLayout({
    required this.roots,
    required this.panelOpen,
    required this.editingGroup,
    required this.creatingNew,
    required this.onSelect,
    required this.onDelete,
    required this.onClose,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Left tree panel ---
        Container(
          width: 340,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: _TreePanel(
            roots: roots,
            selectedId: panelOpen ? editingGroup?.id : null,
            onSelect: onSelect,
            onDelete: onDelete,
          ),
        ),
        // --- Right editor panel ---
        Expanded(
          child: panelOpen
              ? _GroupEditorPanel(
                  key: ValueKey(editingGroup?.id ?? 'new'),
                  existingGroup: editingGroup,
                  onClose: onClose,
                  onDelete: editingGroup != null
                      ? () => onDelete(editingGroup!)
                      : null,
                  onSaved: onSaved,
                )
              : const _SelectionPlaceholder(
                  message: "Select a group to edit, or create a new one."),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Narrow layout: tree only, dialogs for edit
// ---------------------------------------------------------------------------
class _NarrowLayout extends StatelessWidget {
  final List<_TreeNode> roots;
  final void Function(ProductGroup) onSelect;
  final void Function(ProductGroup) onDelete;
  final VoidCallback onAdd;

  const _NarrowLayout({
    required this.roots,
    required this.onSelect,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return _TreePanel(
      roots: roots,
      selectedId: null,
      onSelect: onSelect,
      onDelete: onDelete,
    );
  }
}

// ---------------------------------------------------------------------------
// Tree panel widget
// ---------------------------------------------------------------------------
class _TreePanel extends StatelessWidget {
  final List<_TreeNode> roots;
  final int? selectedId;
  final void Function(ProductGroup) onSelect;
  final void Function(ProductGroup) onDelete;

  const _TreePanel({
    required this.roots,
    required this.selectedId,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: roots
          .map((node) => _TreeNodeTile(
                node: node,
                depth: 0,
                selectedId: selectedId,
                onSelect: onSelect,
                onDelete: onDelete,
              ))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Recursive tree tile
// ---------------------------------------------------------------------------
class _TreeNodeTile extends StatefulWidget {
  final _TreeNode node;
  final int depth;
  final int? selectedId;
  final void Function(ProductGroup) onSelect;
  final void Function(ProductGroup) onDelete;

  const _TreeNodeTile({
    required this.node,
    required this.depth,
    required this.selectedId,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  State<_TreeNodeTile> createState() => _TreeNodeTileState();
}

class _TreeNodeTileState extends State<_TreeNodeTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = widget.node.group;
    final hasChildren = widget.node.children.isNotEmpty;
    final isSelected = widget.selectedId == group.id;
    final groupColor = group.flutterColor;
    final indent = widget.depth * 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          child: InkWell(
            onTap: () => widget.onSelect(group),
            child: Padding(
              padding: EdgeInsets.only(
                  left: 12 + indent, right: 8, top: 4, bottom: 4),
              child: Row(
                children: [
                  // Expand/collapse toggle
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: hasChildren
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              _expanded
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                              size: 18,
                              color: theme.colorScheme.onSurface
                                  .withAlpha(160),
                            ),
                            onPressed: () =>
                                setState(() => _expanded = !_expanded),
                          )
                        : null,
                  ),
                  const SizedBox(width: 4),
                  // Group icon — Drift groups keep the icon on disk
                  // (imageFile); base64 imageBytes only exists for API-sourced.
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
                              hasChildren
                                  ? Icons.folder
                                  : Icons.folder_outlined,
                              size: 22,
                              color: groupColor,
                            ),
                  const SizedBox(width: 10),
                  // Name
                  Expanded(
                    child: Row(
                      children: [
                        if (group.isPendingSync)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.cloud_upload_outlined,
                                size: 14,
                                color: theme.colorScheme.tertiary),
                          ),
                        Flexible(
                          child: Text(
                            group.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Delete button
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18,
                        color:
                            theme.colorScheme.onSurface.withAlpha(100)),
                    onPressed: () => widget.onDelete(group),
                    tooltip: "Delete",
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Children
        if (hasChildren && _expanded)
          ...widget.node.children.map((child) => _TreeNodeTile(
                node: child,
                depth: widget.depth + 1,
                selectedId: widget.selectedId,
                onSelect: widget.onSelect,
                onDelete: widget.onDelete,
              )),
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
    super.key,
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
        }
      }
    } on DioException {
      // Offline — row stays pending until SyncManager pushPendingProductGroupOps.
    } catch (_) {}
  }

  Future<void> _saveAssignments() async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null || !_isEditing) return;
    setState(() => _assignLoading = true);
    try {
      final service = ref.read(productGroupServiceProvider);
      await service.assignProducts(
          company.id, widget.existingGroup!.id, _assignedProductIds.toList());
      ref.invalidate(productsByGroupProvider);
      if (mounted) {
        showAppSnackbar(context, ref, "Products assigned successfully");
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
                          : "New Product Group",
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
                      tooltip: "Delete group",
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
                  tabs: const [
                    Tab(text: "Details"),
                    Tab(text: "Products"),
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
            const _SectionLabel("Group Name"),
            const SizedBox(height: 8),
            TextFormField(
              controller: nameCtrl,
              decoration: _inputDecoration(context, "e.g., Beverages, Desserts"),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 20),

            // Parent
            const _SectionLabel("Parent Folder"),
            const SizedBox(height: 8),
            allGroupsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text("Failed to load groups",
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
                    const DropdownMenuItem(
                        value: null, child: Text("None (Root)")),
                    ...validParents.map((g) => DropdownMenuItem(
                        value: g.id, child: Text(g.name))),
                  ],
                  onChanged: onParentChanged,
                );
              },
            ),
            const SizedBox(height: 20),

            // Rank
            const _SectionLabel("Display Rank"),
            const SizedBox(height: 8),
            TextFormField(
              controller: rankCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(context, "0"),
            ),
            const SizedBox(height: 20),

            // Image
            const _SectionLabel("Folder Image"),
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
                    label: const Text("Choose Image"),
                  ),
                  if (selectedImageBase64 != null &&
                      selectedImageBase64!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onRemoveImage,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text("Remove"),
                      style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ]),
            const SizedBox(height: 20),

            // Color palette
            const _SectionLabel("Folder Color"),
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
                label: Text(isEditing ? "Save Changes" : "Create Group"),
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
              hintText: "Search products…",
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
                child: Text("Failed to load products",
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
                return const Center(child: Text("No products found"));
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
                            ? Colors.green
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
              label: Text(
                  "Save Assignments (${assignedIds.length} selected)"),
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
        constraints: BoxConstraints(
          maxWidth: 520,
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

class _SelectionPlaceholder extends StatelessWidget {
  final String message;
  const _SelectionPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open,
              size: 72,
              color: theme.colorScheme.primary.withAlpha(60)),
          const SizedBox(height: 20),
          Text(message,
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(128))),
        ],
      ),
    );
  }
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
          Text("No product groups yet",
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text("Create one to organize your products",
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(128))),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text("Create Group"),
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
          Text("Error loading groups",
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
