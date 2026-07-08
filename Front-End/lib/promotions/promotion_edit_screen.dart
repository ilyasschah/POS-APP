import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/promotion_models.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/product/product_provider.dart';
import 'package:pos_app/product/product_group_provider.dart';
import 'package:pos_app/product/product_group_model.dart';
import 'package:pos_app/product/product_model.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class EditablePromoItem {
  int id;
  int productId;
  int discountType;
  int priceType;
  double value;
  bool isConditional;
  double quantity;
  int conditionType;
  double quantityLimit;
  String? productName;

  EditablePromoItem({
    required this.id,
    required this.productId,
    required this.discountType,
    required this.priceType,
    required this.value,
    required this.isConditional,
    required this.quantity,
    required this.conditionType,
    required this.quantityLimit,
    this.productName,
  });
}

class PromotionEditScreen extends ConsumerStatefulWidget {
  final PromotionDto? promotion;

  const PromotionEditScreen({super.key, this.promotion});

  @override
  ConsumerState<PromotionEditScreen> createState() =>
      _PromotionEditScreenState();
}

class _PromotionEditScreenState extends ConsumerState<PromotionEditScreen> {
  late TextEditingController _nameController;
  late int _daysOfWeek;
  late bool _isEnabled;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  List<EditablePromoItem> _items = [];

  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.promotion?.name ?? '');
    _daysOfWeek = widget.promotion?.daysOfWeek ?? 127;
    _isEnabled = widget.promotion?.isEnabled ?? true;
    _startDate = widget.promotion?.startDate;

    if (widget.promotion?.startTime != null &&
        widget.promotion!.startTime!.isNotEmpty) {
      final parts = widget.promotion!.startTime!.split(':');
      if (parts.length >= 2) {
        _startTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    _endDate = widget.promotion?.endDate;

    if (widget.promotion?.endTime != null &&
        widget.promotion!.endTime!.isNotEmpty) {
      final parts = widget.promotion!.endTime!.split(':');
      if (parts.length >= 2) {
        _endTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    if (widget.promotion != null) {
      _items = widget.promotion!.items
          .map(
            (i) => EditablePromoItem(
              id: i.id,
              productId: i.productId,
              discountType: i.discountType,
              priceType: i.priceType,
              value: i.value,
              isConditional: i.isConditional,
              quantity: i.quantity,
              conditionType: i.conditionType,
              quantityLimit: i.quantityLimit,
            ),
          )
          .toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppSnackbar(context, ref, 'Name is required', isError: true);
      return;
    }
    if (_daysOfWeek == 0) {
      showAppSnackbar(context, ref, 'Select at least one day of the week',
          isError: true);
      return;
    }
    if (_items.isEmpty) {
      showAppSnackbar(context, ref, 'Add at least one product to the promotion',
          isError: true);
      return;
    }
    // A finite window must not end before it starts.
    if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
      showAppSnackbar(context, ref, 'End date is before the start date',
          isError: true);
      return;
    }

    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;

    final db = ref.read(appDatabaseProvider);
    final isCreate = widget.promotion == null;
    final tempId = isCreate
        ? -(DateTime.now().millisecondsSinceEpoch)
        : widget.promotion!.id;

    final startStr = _startTime != null
        ? "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}"
        : null;
    final endStr = _endTime != null
        ? "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}"
        : null;

    // Capture mutable state before any async gap.
    final itemsSnapshot = List<EditablePromoItem>.from(_items);

    // ── 1. Write to Drift first ──────────────────────────────────────────────
    await db.transaction(() async {
      await db.into(db.promotionsTable).insertOnConflictUpdate(
            PromotionsTableCompanion(
              id: Value(tempId),
              companyId: Value(companyId),
              name: Value(name),
              daysOfWeek: Value(_daysOfWeek),
              isEnabled: Value(_isEnabled),
              startDate: Value(_startDate?.toUtc()),
              startTime: Value(startStr),
              endDate: Value(_endDate?.toUtc()),
              endTime: Value(endStr),
              lastModified: Value(DateTime.now().toUtc()),
              syncStatus: Value(isCreate ? 'pending_create' : 'pending_update'),
            ),
          );
      // Replace items wholesale — simpler than diffing adds/removes.
      await (db.delete(db.promotionItemsTable)
            ..where((t) => t.promotionId.equals(tempId)))
          .go();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < itemsSnapshot.length; i++) {
        final item = itemsSnapshot[i];
        // Positive ids are existing server items; negatives are local-only.
        final localItemId = item.id > 0 ? item.id : -(now + i);
        await db.into(db.promotionItemsTable).insertOnConflictUpdate(
              PromotionItemsTableCompanion(
                id: Value(localItemId),
                promotionId: Value(tempId),
                productId: Value(item.productId),
                discountType: Value(item.discountType),
                priceType: Value(item.priceType),
                value: Value(item.value),
                isConditional: Value(item.isConditional),
                quantity: Value(item.quantity),
                conditionType: Value(item.conditionType),
                quantityLimit: Value(item.quantityLimit),
              ),
            );
      }
    });

    // ── 2. Navigate back immediately — UI reflects the Drift write ───────────
    if (mounted) Navigator.pop(context);

    // ── 3. Try API inline (no context needed after pop) ──────────────────────
    try {
      if (isCreate) {
        final request = CreatePromotionRequest(
          name: name,
          daysOfWeek: _daysOfWeek,
          startDate: _startDate,
          startTime: startStr,
          endDate: _endDate,
          endTime: endStr,
          items: itemsSnapshot
              .map((i) => CreatePromotionItemRequest(
                    productId: i.productId,
                    discountType: i.discountType,
                    priceType: i.priceType,
                    value: i.value,
                    isConditional: i.isConditional,
                    quantity: i.quantity,
                    conditionType: i.conditionType,
                    quantityLimit: i.quantityLimit,
                  ))
              .toList(),
        );
        final created = await ApiClient().createPromotion(companyId, request);
        // Swap temp row for the server-assigned row atomically.
        await db.transaction(() async {
          await (db.delete(db.promotionsTable)
                ..where((t) => t.id.equals(tempId)))
              .go();
          await (db.delete(db.promotionItemsTable)
                ..where((t) => t.promotionId.equals(tempId)))
              .go();
          await db.into(db.promotionsTable).insertOnConflictUpdate(
                PromotionsTableCompanion(
                  id: Value(created.id),
                  companyId: Value(created.companyId),
                  name: Value(created.name),
                  daysOfWeek: Value(created.daysOfWeek),
                  isEnabled: Value(created.isEnabled),
                  startDate: Value(created.startDate?.toUtc()),
                  startTime: Value(created.startTime),
                  endDate: Value(created.endDate?.toUtc()),
                  endTime: Value(created.endTime),
                  lastModified: Value(DateTime.now().toUtc()),
                  syncStatus: const Value('synced'),
                ),
              );
          for (final item in created.items) {
            await db.into(db.promotionItemsTable).insertOnConflictUpdate(
                  PromotionItemsTableCompanion(
                    id: Value(item.id),
                    promotionId: Value(created.id),
                    productId: Value(item.productId),
                    discountType: Value(item.discountType),
                    priceType: Value(item.priceType),
                    value: Value(item.value),
                    isConditional: Value(item.isConditional),
                    quantity: Value(item.quantity),
                    conditionType: Value(item.conditionType),
                    quantityLimit: Value(item.quantityLimit),
                  ),
                );
          }
        });
      } else {
        final request = UpdatePromotionRequest(
          id: tempId,
          name: name,
          daysOfWeek: _daysOfWeek,
          isEnabled: _isEnabled,
          startDate: _startDate,
          startTime: startStr,
          endDate: _endDate,
          endTime: endStr,
          items: itemsSnapshot
              .map((i) => UpdatePromotionItemRequest(
                    id: i.id > 0 ? i.id : 0, // 0 = new item to the server
                    productId: i.productId,
                    discountType: i.discountType,
                    priceType: i.priceType,
                    value: i.value,
                    isConditional: i.isConditional,
                    quantity: i.quantity,
                    conditionType: i.conditionType,
                    quantityLimit: i.quantityLimit,
                  ))
              .toList(),
        );
        await ApiClient().updatePromotion(companyId, request);
        await (db.update(db.promotionsTable)
              ..where((t) => t.id.equals(tempId)))
            .write(const PromotionsTableCompanion(
          syncStatus: Value('synced'),
        ));
      }
    } on DioException {
      // Offline — row stays pending_create/pending_update for SyncManager.
    } catch (_) {
      // Unexpected error; pending row will be retried on next sync.
    }
  }

  bool _isAdded(int productId) => _items.any((i) => i.productId == productId);

  /// Compact numeric display: drop the trailing `.0` so a whole number reads as
  /// "10" rather than "10.0" in the editable fields.
  String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// Add the product to the promotion if absent, remove it if already present.
  /// Tapping a tile (or its trailing button) toggles membership so the cashier
  /// can both pick and un-pick from the same list.
  void _toggleProduct(Product p) {
    setState(() {
      final existing = _items.indexWhere((i) => i.productId == p.id);
      if (existing >= 0) {
        _items.removeAt(existing);
      } else {
        _items.add(
          EditablePromoItem(
            id: 0,
            productId: p.id,
            discountType: 0,
            priceType: 0,
            value: 0,
            isConditional: false,
            quantity: 1,
            conditionType: 0,
            quantityLimit: 0,
            productName: p.name,
          ),
        );
      }
    });
  }

  /// A single selectable product row, shared by the category tree and the flat
  /// search results. Reflects whether the product is already in the promotion.
  Widget _buildProductTile(Product p) {
    final cs = Theme.of(context).colorScheme;
    final added = _isAdded(p.id);
    return ListTile(
      dense: true,
      onTap: () => _toggleProduct(p),
      leading: Icon(Icons.inventory_2, color: cs.onSurfaceVariant, size: 20),
      title: Text(
        p.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: added ? cs.primary : null,
          fontWeight: added ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: IconButton(
        tooltip: added ? 'Remove from promotion' : 'Add to promotion',
        icon: Icon(
          added ? Icons.check_circle : Icons.add_circle_outline,
          color: added ? cs.primary : cs.onSurfaceVariant,
        ),
        onPressed: () => _toggleProduct(p),
      ),
    );
  }

  Widget _buildTree(
    List<ProductGroup> groups,
    List<Product> products,
    int? parentId,
  ) {
    final childGroups = groups
        .where((g) => g.parentGroupId == parentId)
        .toList();
    final childProducts = products
        .where((p) => p.productGroupId == parentId && p.isEnabled)
        .toList();

    if (childGroups.isEmpty && childProducts.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...childGroups.map(
          (g) => ExpansionTile(
            // Open the top-level categories by default so products are visible
            // immediately instead of behind a collapsed folder.
            initiallyExpanded: parentId == null,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.only(left: 16),
            title: Text(
              g.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            leading: Icon(Icons.folder,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            children: [_buildTree(groups, products, g.id)],
          ),
        ),
        ...childProducts.map(_buildProductTile),
      ],
    );
  }

  /// Flat, alphabetical list of products whose name matches the search box —
  /// replaces the category tree while a query is active so a product can be
  /// found without knowing its category.
  Widget _buildSearchResults(List<Product> products) {
    final q = _search.trim().toLowerCase();
    final matches =
        products.where((p) => p.isEnabled && p.name.toLowerCase().contains(q)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No products match "$_search"',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: matches.map(_buildProductTile).toList(),
    );
  }

  /// One-tap day-of-week preset (e.g. Weekdays / Weekends). [mask] is the packed
  /// bitmask written straight to [_daysOfWeek].
  Widget _dayPreset(String label, int mask) {
    final selected = _daysOfWeek == mask;
    return ActionChip(
      label: Text(label),
      backgroundColor: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      onPressed: () => setState(() => _daysOfWeek = mask),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(allProductGroupsProvider);
    final productsAsync = ref.watch(allProductsListProvider);
    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final cs = Theme.of(context).colorScheme;
    // Used as the suffix on a fixed-amount discount field.
    final currencySymbol =
        ref.watch(appSettingsProvider)[SettingKeys.currencySymbol] ?? '\$';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.promotion == null ? 'Create Promotion' : 'Edit Promotion',
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            onPressed: _save,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Promotion Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Row(
                        children: [
                          const Text('Is Active'),
                          const Spacer(),
                          Switch(
                            value: _isEnabled,
                            onChanged: (v) => setState(() => _isEnabled = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      "Days of Week: ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...List.generate(7, (i) {
                      bool isSelected = (_daysOfWeek & (1 << i)) != 0;
                      return FilterChip(
                        label: Text(days[i]),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _daysOfWeek |= (1 << i);
                            } else {
                              _daysOfWeek &= ~(1 << i);
                            }
                          });
                        },
                      );
                    }),
                    const SizedBox(width: 8),
                    _dayPreset('All', 127),
                    _dayPreset('Weekdays', 31),
                    _dayPreset('Weekends', 96),
                    _dayPreset('None', 0),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _startDate == null
                            ? "Start Date"
                            : "${_startDate!.toLocal()}".split(' ')[0],
                      ),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) setState(() => _startDate = date);
                      },
                    ),
                    if (_startDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _startDate = null),
                      ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        _startTime == null
                            ? "Start Time"
                            : _startTime!.format(context),
                      ),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _startTime ?? TimeOfDay.now(),
                        );
                        if (time != null) setState(() => _startTime = time);
                      },
                    ),
                    if (_startTime != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _startTime = null),
                      ),
                    const SizedBox(width: 32),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _endDate == null
                            ? "End Date"
                            : "${_endDate!.toLocal()}".split(' ')[0],
                      ),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) setState(() => _endDate = date);
                      },
                    ),
                    if (_endDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _endDate = null),
                      ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        _endTime == null
                            ? "End Time"
                            : _endTime!.format(context),
                      ),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _endTime ?? TimeOfDay.now(),
                        );
                        if (time != null) setState(() => _endTime = time);
                      },
                    ),
                    if (_endTime != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _endTime = null),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Split Pane
          Expanded(
            child: Row(
              children: [
                // Left Pane: Hierarchy
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _search = v),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Search products...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _search.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.clear),
                                      tooltip: 'Clear',
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _search = '');
                                      },
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: groupsAsync.when(
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                            error: (err, stack) =>
                                Center(child: Text('Error: $err')),
                            data: (groups) => productsAsync.when(
                              loading: () => const Center(
                                  child: CircularProgressIndicator()),
                              error: (err, stack) =>
                                  Center(child: Text('Error: $err')),
                              data: (products) {
                                // Update product names in items list for display
                                for (var item in _items) {
                                  if (item.productName == null) {
                                    final match = products
                                        .where((p) => p.id == item.productId)
                                        .firstOrNull;
                                    if (match != null) {
                                      item.productName = match.name;
                                    }
                                  }
                                }
                                return SingleChildScrollView(
                                  child: _search.trim().isEmpty
                                      ? _buildTree(groups, products, null)
                                      : _buildSearchResults(products),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Right Pane: Selected Items
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                        child: Row(
                          children: [
                            Text(
                              'Selected Products',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            if (_items.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_items.length}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            if (_items.isNotEmpty)
                              TextButton.icon(
                                icon: const Icon(Icons.clear_all, size: 18),
                                label: const Text('Clear all'),
                                onPressed: () =>
                                    setState(() => _items.clear()),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _items.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_offer_outlined,
                                      size: 56,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.25),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Select products from the left to add to the promotion.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _items.length,
                                separatorBuilder: (ctx, i) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (ctx, i) {
                                  final item = _items[i];
                            return Card(
                              margin: EdgeInsets.zero,
                              elevation: 0,
                              color: cs.surfaceContainerHighest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 6, 6, 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // ── Header: product + remove ──────────
                                    Row(
                                      children: [
                                        Icon(Icons.inventory_2,
                                            size: 18,
                                            color: cs.onSurfaceVariant),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item.productName ??
                                                'Product ID: ${item.productId}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity:
                                              VisualDensity.compact,
                                          tooltip: 'Remove',
                                          icon: Icon(Icons.delete_outline,
                                              color: cs.error),
                                          onPressed: () => setState(
                                              () => _items.removeAt(i)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // ── Discount value + type ─────────────
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: _fmtNum(item.value),
                                            decoration: InputDecoration(
                                              labelText: 'Discount',
                                              isDense: true,
                                              border:
                                                  const OutlineInputBorder(),
                                              suffixText:
                                                  item.discountType == 0
                                                      ? '%'
                                                      : currencySymbol,
                                            ),
                                            keyboardType: TextInputType.number,
                                            onChanged: (v) => item.value =
                                                double.tryParse(v) ?? 0,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child:
                                              DropdownButtonFormField<int>(
                                            initialValue: item.discountType,
                                            isDense: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Type',
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 0,
                                                child: Text('Percentage'),
                                              ),
                                              DropdownMenuItem(
                                                value: 1,
                                                child: Text('Fixed Amount'),
                                              ),
                                            ],
                                            onChanged: (v) => setState(
                                              () => item.discountType = v!,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // ── Conditional toggle ────────────────
                                    SwitchListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      title: const Text(
                                        'Conditional (e.g. Buy 2, get discount)',
                                      ),
                                      value: item.isConditional,
                                      onChanged: (v) => setState(
                                        () => item.isConditional = v,
                                      ),
                                    ),
                                    if (item.isConditional)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              initialValue:
                                                  _fmtNum(item.quantity),
                                              decoration:
                                                  const InputDecoration(
                                                labelText: 'Required Qty',
                                                isDense: true,
                                                border: OutlineInputBorder(),
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                              onChanged: (v) =>
                                                  item.quantity =
                                                      double.tryParse(v) ?? 1,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child:
                                                DropdownButtonFormField<int>(
                                              initialValue:
                                                  item.conditionType,
                                              isDense: true,
                                              decoration:
                                                  const InputDecoration(
                                                labelText: 'Applies To',
                                                isDense: true,
                                                border: OutlineInputBorder(),
                                              ),
                                              items: const [
                                                DropdownMenuItem(
                                                  value: 0,
                                                  child: Text('Same Product'),
                                                ),
                                              ],
                                              onChanged: (v) => setState(
                                                () => item.conditionType = v!,
                                              ),
                                            ),
                                          ),
                                        ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
