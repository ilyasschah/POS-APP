// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as imgpath;
import 'package:path_provider/path_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:file_picker/file_picker.dart';
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
import 'package:pos_app/product/product_export_model.dart';
import 'package:pos_app/product/product_group_model.dart';
import 'package:pos_app/product/product_provider.dart';
import 'package:pos_app/tax/tax_provider.dart';
import 'package:pos_app/product/product_comment_provider.dart';
import 'package:pos_app/sync/sync_provider.dart';
import 'package:pos_app/barcode/barcode_provider.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/product/product_import_screen.dart';
import 'package:pos_app/settings/local_ui_prefs.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// EXPORT HELPERS
// ---------------------------------------------------------------------------

String _xmlEsc(String? s) => (s ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _csvCell(String? v) {
  final s = v ?? '';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String _buildCsvExport(List<ProductExportRow> rows) {
  const header =
      'Name,ProductGroup,SKU,Barcode,MeasurementUnit,Cost,Markup,Price,'
      'Tax,IsTaxInclusivePrice,IsPriceChangeAllowed,IsUsingDefaultQuantity,'
      'IsService,IsEnabled,Description,Quantity,Supplier,ReorderPoint,'
      'PreferredQuantity,LowStockWarning,WarningQuantity';
  final lines = [header];
  for (final p in rows) {
    lines.add([
      _csvCell(p.name),
      _csvCell(p.productGroupName),
      _csvCell(p.code),
      _csvCell(p.barcodes.isNotEmpty ? p.barcodes.first : ''),
      _csvCell(p.measurementUnit),
      p.cost,
      p.markup ?? '',
      p.price,
      p.taxes.isNotEmpty ? p.taxes.first.rate : '',
      p.isTaxInclusivePrice ? 1 : 0,
      p.isPriceChangeAllowed ? 1 : 0,
      p.isUsingDefaultQuantity ? 1 : 0,
      p.isService ? 1 : 0,
      p.isEnabled ? 1 : 0,
      _csvCell(p.description),
      p.totalStock,
      _csvCell(p.supplierName),
      p.reorderPoint,
      p.preferredQuantity,
      p.isLowStockWarningEnabled ? 1 : 0,
      p.lowStockWarningQuantity,
    ].join(','));
  }
  return lines.join('\n');
}

String _buildXmlExport(List<ProductExportRow> rows) {
  // Group by productGroupName (preserve insertion order)
  final groups = <String?, List<ProductExportRow>>{};
  for (final p in rows) {
    (groups[p.productGroupName] ??= []).add(p);
  }

  final sb = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln(
        '<ProductGroup xmlns:xsd="http://www.w3.org/2001/XMLSchema" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">')
    ..writeln('  <Color>Transparent</Color>')
    ..writeln('  <Rank>0</Rank>')
    ..writeln('  <Items>');

  groups.forEach((groupName, products) {
    final indent = groupName != null ? '    ' : '  ';
    if (groupName != null) {
      sb
        ..writeln('    <PosItem xsi:type="ProductGroup">')
        ..writeln('      <Name>${_xmlEsc(groupName)}</Name>')
        ..writeln('      <Color>Transparent</Color>')
        ..writeln('      <Rank>0</Rank>')
        ..writeln('      <Items>');
    }

    int barcodeId = 1;
    for (final p in products) {
      sb
        ..writeln('$indent  <PosItem xsi:type="Product">')
        ..writeln(
            '$indent    <Id xsi:type="xsd:long">${p.id}</Id>')
        ..writeln('$indent    <Name>${_xmlEsc(p.name)}</Name>')
        ..writeln('$indent    <Color>${_xmlEsc(p.color)}</Color>')
        ..writeln('$indent    <Rank>${p.rank ?? 0}</Rank>');
      if (p.code != null) sb.writeln('$indent    <Code>${_xmlEsc(p.code)}</Code>');
      if (p.plu != null) sb.writeln('$indent    <PLU>${p.plu}</PLU>');
      sb
        ..writeln('$indent    <Price>${p.price}</Price>')
        ..writeln('$indent    <Taxes>');
      for (final t in p.taxes) {
        sb
          ..writeln('$indent      <Tax>')
          ..writeln('$indent        <Id xsi:type="xsd:long">${t.id}</Id>')
          ..writeln('$indent        <Name>${_xmlEsc(t.name)}</Name>')
          ..writeln('$indent        <Rate>${t.rate}</Rate>')
          ..writeln('$indent        <Code>${_xmlEsc(t.code)}</Code>')
          ..writeln(
              '$indent        <IsFixed>${t.isFixed.toString().toLowerCase()}</IsFixed>')
          ..writeln(
              '$indent        <IsTaxOnTotal>${t.isTaxOnTotal.toString().toLowerCase()}</IsTaxOnTotal>')
          ..writeln(
              '$indent        <IsEnabled>${t.isEnabled.toString().toLowerCase()}</IsEnabled>')
          ..writeln('$indent      </Tax>');
      }
      sb
        ..writeln('$indent    </Taxes>')
        ..writeln(
            '$indent    <IsTaxInclusivePrice>${p.isTaxInclusivePrice.toString().toLowerCase()}</IsTaxInclusivePrice>')
        ..writeln('$indent    <Excise>0</Excise>');
      if (p.measurementUnit != null) {
        sb
          ..writeln('$indent    <MeasurementUnit>')
          ..writeln('$indent      <Name>${_xmlEsc(p.measurementUnit)}</Name>')
          ..writeln('$indent    </MeasurementUnit>');
      }
      sb
        ..writeln('$indent    <Package><Quantity>1</Quantity></Package>')
        ..writeln('$indent    <Barcodes>');
      for (final barcode in p.barcodes) {
        sb
          ..writeln('$indent      <Barcode>')
          ..writeln(
              '$indent        <Id xsi:type="xsd:long">${barcodeId++}</Id>')
          ..writeln('$indent        <Value>${_xmlEsc(barcode)}</Value>')
          ..writeln('$indent      </Barcode>');
      }
      sb
        ..writeln('$indent    </Barcodes>')
        ..writeln('$indent    <IsUsingSerialNumbers>false</IsUsingSerialNumbers>')
        ..writeln('$indent    <IsDiscountAllowed>true</IsDiscountAllowed>')
        ..writeln('$indent    <MaxDiscount>100</MaxDiscount>')
        ..writeln(
            '$indent    <IsPriceChangeAllowed>${p.isPriceChangeAllowed.toString().toLowerCase()}</IsPriceChangeAllowed>')
        ..writeln('$indent    <IsManufactureRequired>false</IsManufactureRequired>')
        ..writeln(
            '$indent    <IsService>${p.isService.toString().toLowerCase()}</IsService>')
        ..writeln(
            '$indent    <IsUsingDefaultQuantity>${p.isUsingDefaultQuantity.toString().toLowerCase()}</IsUsingDefaultQuantity>')
        ..writeln('$indent    <Comments>');
      for (final c in p.comments) {
        sb.writeln('$indent      <string>${_xmlEsc(c)}</string>');
      }
      sb
        .writeln('$indent    </Comments>');
      if (p.description != null && p.description!.isNotEmpty) {
        sb.writeln(
            '$indent    <Description>${_xmlEsc(p.description)}</Description>');
      }
      sb
        ..writeln(
            '$indent    <IsEnabled>${p.isEnabled.toString().toLowerCase()}</IsEnabled>')
        ..writeln('$indent    <Cost>${p.cost}</Cost>');
      if (p.lastPurchasePrice != null) {
        sb.writeln(
            '$indent    <LastPurchasePrice>${p.lastPurchasePrice}</LastPurchasePrice>');
      }
      if (p.markup != null) {
        sb.writeln('$indent    <Markup>${p.markup}</Markup>');
      }
      if (p.ageRestriction != null) {
        sb.writeln(
            '$indent    <AgeRestriction>${p.ageRestriction}</AgeRestriction>');
      } else {
        sb.writeln(
            '$indent    <AgeRestriction xsi:nil="true" />');
      }
      if (p.dateCreated != null) {
        sb.writeln('$indent    <DateCreated>${p.dateCreated}</DateCreated>');
      }
      if (p.dateUpdated != null) {
        sb.writeln('$indent    <DateUpdated>${p.dateUpdated}</DateUpdated>');
      }
      sb.writeln('$indent  </PosItem>');
    }

    if (groupName != null) {
      sb
        ..writeln('      </Items>')
        ..writeln('    </PosItem>');
    }
  });

  sb
    ..writeln('  </Items>')
    ..writeln('</ProductGroup>');
  return sb.toString();
}

Future<void> _runExport(
    BuildContext context, WidgetRef ref, String format) async {
  final company = ref.read(selectedCompanyProvider);
  if (company == null) return;

  try {
    final dio = createDio();
    final response = await dio.get(
      '/Products/GetForExport',
      queryParameters: {'companyId': company.id},
    );
    final rows = (response.data as List<dynamic>)
        .map((e) => ProductExportRow.fromJson(e as Map<String, dynamic>))
        .toList();

    final content =
        format == 'csv' ? _buildCsvExport(rows) : _buildXmlExport(rows);
    final ext = format == 'csv' ? 'csv' : 'xml';

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save export file',
      fileName: 'products_export.$ext',
      type: FileType.custom,
      allowedExtensions: [ext],
    );
    if (path == null) return;

    await File(path).writeAsString(content, encoding: const Utf8Codec());

    if (context.mounted) {
      showAppSnackbar(context, ref,
          AppLocalizations.of(context).exportedProductsTo(rows.length, path));
    }
  } catch (e) {
    if (context.mounted) {
      showAppSnackbar(
          context, ref, AppLocalizations.of(context).exportFailed(e.toString()),
          isError: true);
    }
  }
}

Future<void> _showExportDialog(BuildContext context, WidgetRef ref) async {
  String selected = 'csv';
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(AppLocalizations.of(context).selectExportType),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'csv',
              groupValue: selected,
              onChanged: (v) => setState(() => selected = v!),
              title: Row(children: [
                Icon(Icons.table_chart, color: ctx.successColor, size: 20),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(context).exportCsv),
              ]),
            ),
            RadioListTile<String>(
              value: 'xml',
              groupValue: selected,
              onChanged: (v) => setState(() => selected = v!),
              title: Row(children: [
                Icon(Icons.code, color: ctx.infoColor, size: 20),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(context).exportXml),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).actionCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runExport(context, ref, selected);
            },
            child: Text(AppLocalizations.of(context).actionContinue),
          ),
        ],
      ),
    ),
  );
}

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

// --- MAIN SCREEN ---
class ProductsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onMenuPressed;
  const ProductsScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final Set<int> _selectedIds = {};

  void _updateSelection(Set<int> ids) {
    setState(() {
      _selectedIds.clear();
      _selectedIds.addAll(ids);
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final products = ref.read(productsByGroupProvider).value ?? [];
    final effectiveIds =
        _selectedIds.intersection(products.map((p) => p.id).toSet());
    if (effectiveIds.isEmpty) return;

    final count = effectiveIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteProducts),
        content: Text(
            AppLocalizations.of(context).deleteProductsConfirm(count)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context).actionCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ctx.dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).actionDelete, style: TextStyle(color: ctx.onStatusColor)),
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
        await (db.update(db.productsTable)..where((t) => t.id.equals(id)))
            .write(ProductsTableCompanion(
          syncStatus: const Value('pending_delete'),
          lastModified: Value(DateTime.now().toUtc()),
        ));
      }
      deleted++;
    }

    // Fire sync in the background so online deletes propagate immediately.
    if (deleted > 0) {
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
    }

    if (mounted) {
      // Keep blocked products selected so the user sees what wasn't deleted.
      setState(() => _selectedIds
        ..clear()
        ..addAll(blocked));
      if (blocked.isNotEmpty) {
        final n = blocked.length;
        showAppSnackbar(
          context,
          ref,
          deleted > 0
              ? AppLocalizations.of(context)
                  .deletedSomeProductsBlocked(deleted, n)
              : AppLocalizations.of(context).cannotDeleteProductsLinked(n),
          isError: true,
        );
      } else {
        showAppSnackbar(context, ref,
            AppLocalizations.of(context).productsDeletedCount(deleted));
      }
    }
  }

  /// Returns true if [productId] is referenced by any local order line or
  /// document line — the same constraint the backend enforces on delete.
  Future<bool> _isProductReferenced(AppDatabase db, int productId) async {
    final inOrder = await (db.select(db.posOrderItemsTable)
          ..where((t) => t.productId.equals(productId))
          ..limit(1))
        .getSingleOrNull();
    if (inOrder != null) return true;
    final inDoc = await (db.select(db.documentItemsTable)
          ..where((t) => t.productId.equals(productId))
          ..limit(1))
        .getSingleOrNull();
    return inDoc != null;
  }

  void _showColumnPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(builder: (context, ref, _) {
        final visible = ref.watch(productVisibleColumnsProvider);
        final notifier = ref.read(productVisibleColumnsProvider.notifier);
        return AlertDialog(
          title: Text(AppLocalizations.of(context).showHideColumns),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: kProductColumns.map((col) {
                  final isOn = visible[col.key] ?? col.defaultVisible;
                  return CheckboxListTile(
                    dense: true,
                    title: Text(productColumnLabel(context, col.key)),
                    // Mandatory columns (Name, Edit) stay locked on.
                    subtitle: col.mandatory ? Text(AppLocalizations.of(context).alwaysShown) : null,
                    value: isOn,
                    onChanged: col.mandatory
                        ? null
                        : (val) => notifier.setVisible(col.key, val ?? false),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => notifier.resetToDefaults(),
              child: Text(AppLocalizations.of(context).actionReset),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).actionClose),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = _selectedIds.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onMenuPressed,
              )
            : null,
        title: Text(AppLocalizations.of(context).products),
        backgroundColor: theme.colorScheme.surface,
        actions: [
          TextButton.icon(
            icon: Icon(Icons.delete_rounded,
                color: hasSelection ? context.dangerColor : theme.disabledColor),
            label: Text(
              hasSelection
                  ? AppLocalizations.of(context)
                      .deleteWithCount(_selectedIds.length)
                  : AppLocalizations.of(context).actionDelete,
              style: TextStyle(
                  color:
                      hasSelection ? context.dangerColor : theme.disabledColor),
            ),
            onPressed: hasSelection ? _bulkDelete : null,
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            icon: const Icon(Icons.view_column_rounded),
            label: Text(AppLocalizations.of(context).columns),
            onPressed: () => _showColumnPicker(context),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            icon: const Icon(Icons.download_rounded),
            label: Text(AppLocalizations.of(context).importLabel),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductImportScreen()),
            ).then((_) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.invalidate(productsByGroupProvider);
              });
            }),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            icon: const Icon(Icons.upload_rounded),
            label: Text(AppLocalizations.of(context).exportLabel),
            onPressed: () => _showExportDialog(context, ref),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context).addProduct),
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary),
            onPressed: () async {
              final result = await showDialog(
                context: context,
                builder: (_) =>
                    const _ProductEditorDialog(isPostCreation: false),
              );
              ref.invalidate(productsByGroupProvider);
              if (result is Product && context.mounted) {
                if (result.isPendingCreate) {
                  // Product has a temp id — it doesn't exist on the server yet.
                  // Tax/barcode/stock setup requires a real server id; skip Phase 2
                  // and tell the user to sync first.
                  showAppSnackbar(context, ref,
                      AppLocalizations.of(context).productSavedLocallySyncFirst);
                } else {
                  showDialog(
                    context: context,
                    builder: (_) => _ProductEditorDialog(
                        existingProduct: result, isPostCreation: true),
                  ).then((_) => ref.invalidate(productsByGroupProvider));
                }
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDEBAR
          Container(
            width: ref.watch(groupSidebarWidthProvider),
            color: theme.colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Text(AppLocalizations.of(context).categoriesHeader,
                      style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
                const Expanded(child: _GroupTreeSidebar()),
              ],
            ),
          ),
          // Drag handle — same interaction as the cart panel on the menu
          // screen: live resize on drag, one write to on-device storage when
          // the drag settles. Local only, so it never affects another terminal.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              final maxWidth = MediaQuery.of(context).size.width * 0.5;
              // Sidebar is on the LEFT, so dragging right grows it.
              final newWidth =
                  ref.read(groupSidebarWidthProvider) + details.delta.dx;
              ref.read(groupSidebarWidthProvider.notifier).set(
                  newWidth > maxWidth ? maxWidth : newWidth);
            },
            onHorizontalDragEnd: (_) {
              ref.read(groupSidebarWidthProvider.notifier).persist();
            },
            child: const MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: SizedBox(
                width: 8,
                child: VerticalDivider(width: 8, thickness: 1),
              ),
            ),
          ),
          // RIGHT AREA
          Expanded(
            child: _ProductListContent(
              selectedIds: Set.from(_selectedIds),
              onSelectionChanged: _updateSelection,
            ),
          ),
        ],
      ),
    );
  }
}

// --- CUSTOM TREE SIDEBAR WIDGET ---
class _GroupTreeSidebar extends ConsumerWidget {
  const _GroupTreeSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGroups = ref.watch(allProductGroupsProvider);

    return asyncGroups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppLocalizations.of(context).errorLoadingGroups)),
        data: (groups) {
          final rootGroups = groups
              .where((g) => g.parentGroupId == null)
              .toList()
            ..sort((a, b) => a.rank.compareTo(b.rank));

          return ListView(
            children: [
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(Icons.all_inbox, color: Theme.of(context).colorScheme.primary),
                  title: Text(AppLocalizations.of(context).allProducts,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  selected: ref.watch(selectedProductGroupIdProvider) == null,
                  selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  onTap: () => ref
                      .read(selectedProductGroupIdProvider.notifier)
                      .state = null,
                ),
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              ...rootGroups.map((g) =>
                  _TreeNode(group: g, allGroups: groups, depth: 0, ref: ref)),
            ],
          );
        });
  }
}

// --- RECURSIVE TREE NODE ---
class _TreeNode extends StatefulWidget {
  final ProductGroup group;
  final List<ProductGroup> allGroups;
  final int depth;
  final WidgetRef ref;

  const _TreeNode(
      {required this.group,
      required this.allGroups,
      required this.depth,
      required this.ref});

  @override
  State<_TreeNode> createState() => _TreeNodeState();
}

class _TreeNodeState extends State<_TreeNode> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final children = widget.allGroups
        .where((g) => g.parentGroupId == widget.group.id)
        .toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final hasChildren = children.isNotEmpty;
    final isSelected =
        widget.ref.watch(selectedProductGroupIdProvider) == widget.group.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => widget.ref
              .read(selectedProductGroupIdProvider.notifier)
              .state = widget.group.id,
          child: Container(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            padding: EdgeInsets.only(
                left: 8.0 + (widget.depth * 16.0),
                right: 8.0,
                top: 6,
                bottom: 6),
            child: Row(
              children: [
                if (hasChildren)
                  InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                          _isExpanded
                              ? Icons.arrow_drop_down
                              : Icons.arrow_right,
                          size: 22,
                          color: Colors.grey[700]),
                    ),
                  )
                else
                  const SizedBox(width: 30),
                Icon(
                    hasChildren
                        ? (_isExpanded ? Icons.folder_open : Icons.folder)
                        : Icons.folder_outlined,
                    color: widget.group.flutterColor,
                    size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.group.name,
                      style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded && hasChildren)
          ...children.map((c) => _TreeNode(
              group: c,
              allGroups: widget.allGroups,
              depth: widget.depth + 1,
              ref: widget.ref)),
      ],
    );
  }
}

// --- PRODUCT DATA TABLE WIDGET ---
class _ProductListContent extends ConsumerWidget {
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onSelectionChanged;

  const _ProductListContent({
    required this.selectedIds,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sym = ref.watch(currencySymbolProvider);
    final asyncProducts = ref.watch(productsByGroupProvider);
    final groups = ref.watch(allProductGroupsProvider).value ?? [];

    // Clear selection whenever the category filter changes.
    ref.listen(selectedProductGroupIdProvider, (_, __) {
      onSelectionChanged({});
    });

    return asyncProducts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppLocalizations.of(context).errorWithMessage(_parseApiError(context, e)))),
        data: (products) {
          if (products.isEmpty) {
            return Center(
                child: Text(AppLocalizations.of(context).noProductsFound,
                    style: TextStyle(
                        color: Theme.of(context).hintColor, fontSize: 18)));
          }

          final effectiveSelected =
              selectedIds.intersection(products.map((p) => p.id).toSet());

          // Only the columns the user has chosen to keep, in catalogue order.
          final visibleCols = ref.watch(productVisibleColumnsProvider);
          final activeCols = kProductColumns
              .where((c) => visibleCols[c.key] ?? c.defaultVisible)
              .toList();

          String groupNameFor(Product p) =>
              groups.where((g) => g.id == p.productGroupId).firstOrNull?.name ??
              '-';

          Widget boolCell(bool v) => Icon(
                v ? Icons.check_circle : Icons.remove_circle_outline,
                size: 18,
                color: v ? context.successColor : theme.disabledColor,
              );

          DataCell cellFor(ProductColumnDef col, Product p) {
            switch (col.key) {
              case 'image':
                // Prefer FileImage over MemoryImage — Flutter caches FileImage
                // by path so the same thumbnail decodes once across the grid.
                final ImageProvider? provider = p.imageFile != null
                    ? FileImage(p.imageFile!)
                    : (p.imageBytes != null ? MemoryImage(p.imageBytes!) : null);
                // No image → tint the placeholder with the colour marker so a
                // coloured product reads as coloured here too, not grey.
                final marker = p.markerColor;
                return DataCell(Container(
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
                      ? PhosphorIcon(PhosphorIconsRegular.forkKnife,
                          color: marker != null
                              ? marker.withValues(alpha: 0.9)
                              : theme.hintColor)
                      : null,
                ));
              case 'color':
                final marker = p.markerColor;
                return DataCell(marker == null
                    ? const Text('-')
                    : Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: marker,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                              width: 1),
                        ),
                      ));
              case 'code':
                return DataCell(Text(p.code ?? '-'));
              case 'name':
                return DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: p.isEnabled
                                  ? null
                                  : TextDecoration.lineThrough),
                        ),
                      ),
                      if (p.isPendingSync) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: p.isPendingCreate
                              ? AppLocalizations.of(context).pendingSyncNew
                              : AppLocalizations.of(context).pendingSyncUpdate,
                          child: Icon(Icons.cloud_upload_outlined,
                              size: 14, color: theme.colorScheme.tertiary),
                        ),
                      ],
                    ],
                  ),
                ));
              case 'category':
                return DataCell(Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(groupNameFor(p),
                      style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ));
              case 'price':
                return DataCell(Text("${p.price.toStringAsFixed(2)} $sym",
                    style: TextStyle(
                        color: context.successColor,
                        fontWeight: FontWeight.bold)));
              case 'cost':
                return DataCell(Text("${p.cost.toStringAsFixed(2)} $sym",
                    style: TextStyle(color: context.dangerColor)));
              case 'plu':
                return DataCell(Text(p.plu?.toString() ?? '-'));
              case 'unit':
                return DataCell(Text(p.measurementUnit ?? '-'));
              case 'markup':
                return DataCell(Text(
                    p.markup != null ? '${p.markup!.toStringAsFixed(1)}%' : '-'));
              case 'lastPurchase':
                return DataCell(Text(p.lastPurchasePrice != null
                    ? '${p.lastPurchasePrice!.toStringAsFixed(2)} $sym'
                    : '-'));
              case 'ageRestriction':
                return DataCell(Text(p.ageRestriction?.toString() ?? '-'));
              case 'rank':
                return DataCell(Text(p.rank?.toString() ?? '-'));
              case 'taxInclusive':
                return DataCell(boolCell(p.isTaxInclusivePrice));
              case 'service':
                return DataCell(boolCell(p.isService));
              case 'priceChange':
                return DataCell(boolCell(p.isPriceChangeAllowed));
              case 'enabled':
                return DataCell(boolCell(p.isEnabled));
              case 'description':
                return DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(p.description ?? '-',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ));
              case 'created':
                return DataCell(Text(p.dateCreated ?? '-'));
              case 'updated':
                return DataCell(Text(p.dateUpdated ?? '-'));
              case 'actions':
                return DataCell(IconButton(
                  icon: Icon(Icons.edit,
                      color: theme.colorScheme.primary, size: 20),
                  onPressed: () => showDialog(
                          context: context,
                          builder: (_) =>
                              _ProductEditorDialog(existingProduct: p))
                      .then((_) => ref.invalidate(productsByGroupProvider)),
                ));
              default:
                return const DataCell(Text('-'));
            }
          }

          // Horizontal scroll lets the grid grow past the viewport as more
          // columns are enabled, while ConstrainedBox keeps it filling the
          // width when only a few are shown.
          return LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.1)),
                    ),
                    color: theme.cardColor,
                    clipBehavior: Clip.antiAlias,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                          theme.colorScheme.surfaceContainerHighest),
                      dataRowMaxHeight: 65,
                      onSelectAll: (val) => onSelectionChanged(
                          val == true ? products.map((p) => p.id).toSet() : {}),
                      columns: activeCols
                          .map((c) => DataColumn(
                              label: Text(productColumnLabel(context, c.key)),
                              numeric: c.numeric))
                          .toList(),
                      rows: products.map((p) {
                        return DataRow(
                          selected: effectiveSelected.contains(p.id),
                          onSelectChanged: (val) {
                            final next = Set<int>.from(selectedIds);
                            if (val == true) {
                              next.add(p.id);
                            } else {
                              next.remove(p.id);
                            }
                            onSelectionChanged(next);
                          },
                          color: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return theme.colorScheme.primary
                                  .withValues(alpha: 0.08);
                            }
                            return p.isEnabled
                                ? Colors.transparent
                                : theme.disabledColor.withValues(alpha: 0.05);
                          }),
                          cells:
                              activeCols.map((c) => cellFor(c, p)).toList(),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            );
          });
        });
  }
}

// --- ADD/EDIT TABBED DIALOG ---
class _ProductEditorDialog extends ConsumerStatefulWidget {
  final Product? existingProduct;
  final bool isPostCreation; // Determines if we are in "Phase 2" of creation

  const _ProductEditorDialog(
      {this.existingProduct, this.isPostCreation = false});

  @override
  ConsumerState<_ProductEditorDialog> createState() =>
      _ProductEditorDialogState();
}

class _ProductEditorDialogState extends ConsumerState<_ProductEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pluCtrl = TextEditingController();
  final _measurementUnitCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '');
  final _costCtrl = TextEditingController(text: '');
  final _markupCtrl = TextEditingController();
  final _rankCtrl = TextEditingController(text: '');
  final _ageRestrictionCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _newCommentCtrl = TextEditingController();
  final _newBarcodeCtrl = TextEditingController();
  // Toggles
  bool _isTaxInclusive = true;
  bool _isService = false;
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
      _measurementUnitCtrl.text = p.measurementUnit ?? '';
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
        } catch (_) {/* leave _selectedImageBase64 null — UI shows placeholder */}
      }
      _selectedHexColor = p.color.isNotEmpty ? p.color : '#000000';

      // Only fetch server-side tax assignment for real (synced) products.
      if (p.id > 0) _fetchAssignedTax(p.id);
    } else {
      _selectedGroupId = ref.read(selectedProductGroupIdProvider);
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
      final taxes = await ref.read(appDatabaseProvider).getProductTaxes(productId);
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
    _measurementUnitCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _markupCtrl.dispose();
    _rankCtrl.dispose();
    _ageRestrictionCtrl.dispose();
    _descriptionCtrl.dispose();
    _newCommentCtrl.dispose();
    _newBarcodeCtrl.dispose();

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
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;

    // SCENARIO 1: We are in "Phase 1" of creation (Only General Tab)
    if (widget.existingProduct == null && !widget.isPostCreation) {
      if (_nameCtrl.text.trim().isEmpty) {
        setState(() =>
            _errorMessage = AppLocalizations.of(context).pleaseEnterProductName);
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
          } catch (_) { /* best-effort */ }
        }

        await db.into(db.productsTable).insert(ProductsTableCompanion(
          id: Value(tempId),
          companyId: Value(companyId),
          name: Value(_nameCtrl.text.trim()),
          price: Value(double.tryParse(_priceCtrl.text) ?? 0),
          cost: Value(double.tryParse(_costCtrl.text) ?? 0),
          productGroupId: Value(_selectedGroupId),
          isService: Value(_isService),
          colorHex: Value(_selectedHexColor == 'Transparent' ? '#000000' : _selectedHexColor),
          localImagePath: Value(localImgPath),
          code: Value(_codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim()),
          plu: Value(int.tryParse(_pluCtrl.text.trim())),
          measurementUnit: Value(_measurementUnitCtrl.text.trim().isEmpty ? null : _measurementUnitCtrl.text.trim()),
          description: Value(_descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim()),
          markup: Value(double.tryParse(_markupCtrl.text.trim())),
          rank: Value(int.tryParse(_rankCtrl.text.trim()) ?? 0),
          ageRestriction: Value(int.tryParse(_ageRestrictionCtrl.text.trim())),
          isPriceChangeAllowed: Value(_isPriceChangeAllowed),
          isUsingDefaultQuantity: Value(_isUsingDefaultQuantity),
          isTaxInclusivePrice: Value(_isTaxInclusive),
          isEnabled: Value(_isEnabled),
          syncStatus: const Value('pending_create'),
          lastModified: Value(now),
        ));

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
          color: _selectedHexColor == 'Transparent' ? '#000000' : _selectedHexColor,
          localImagePath: localImgPath,
          code: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
          plu: int.tryParse(_pluCtrl.text.trim()),
          measurementUnit: _measurementUnitCtrl.text.trim().isEmpty ? null : _measurementUnitCtrl.text.trim(),
          description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
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
          'measurementUnit': _measurementUnitCtrl.text.trim().isEmpty
              ? null
              : _measurementUnitCtrl.text.trim(),
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
          } catch (_) { /* best-effort */ }
        }
        await db.into(db.productsTable).insertOnConflictUpdate(
          ProductsTableCompanion(
            id: Value(savedProductId),
            companyId: Value(companyId),
            name: Value(_nameCtrl.text.trim()),
            price: Value(double.tryParse(_priceCtrl.text) ?? 0),
            cost: Value(double.tryParse(_costCtrl.text) ?? 0),
            productGroupId: Value(_selectedGroupId),
            isService: Value(_isService),
            colorHex: Value(_selectedHexColor == 'Transparent' ? '#000000' : _selectedHexColor),
            localImagePath: Value(localImgPath),
            code: Value(_codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim()),
            plu: Value(int.tryParse(_pluCtrl.text.trim())),
            measurementUnit: Value(_measurementUnitCtrl.text.trim().isEmpty ? null : _measurementUnitCtrl.text.trim()),
            description: Value(_descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim()),
            markup: Value(double.tryParse(_markupCtrl.text.trim())),
            rank: Value(int.tryParse(_rankCtrl.text.trim()) ?? 0),
            ageRestriction: Value(int.tryParse(_ageRestrictionCtrl.text.trim())),
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
          await dio.patch('/Products/Update',
              queryParameters: {'id': savedProductId, 'companyId': companyId},
              data: payload);
          // API succeeded — clear the pending flag.
          await (db.update(db.productsTable)
                ..where((t) => t.id.equals(savedProductId)))
              .write(const ProductsTableCompanion(
                syncStatus: Value('synced'),
                syncError: Value(null),
              ));
        } on DioException {
          // API unreachable — local write is queued. Will sync when online.
          if (mounted) {
            showAppSnackbar(context, ref,
                AppLocalizations.of(context).savedLocallyWillSyncOnline);
            Navigator.of(context).pop();
          }
          return;
        }
      }

      // Handle Taxes (offline-first): write the assignment change to local
      // Drift; SyncManager pushes /ProductTaxes/Add+Delete on the next sync.
      if (_selectedTaxId != _originalTaxId) {
        await ref.read(appDatabaseProvider).setProductTaxLocal(
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
                : AppLocalizations.of(context).productUpdatedSuccessfully);
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

    // Add Advanced Tabs (If creating Phase 2, OR if normal editing)
    if (_isEditing || widget.isPostCreation) {
      dialogTabs.addAll([
        Tab(text: l10n.taxesLabel),
        Tab(text: l10n.barcodesTab),
        Tab(text: l10n.commentsTab),
      ]);
      dialogTabViews.addAll([
        _buildTaxesTab(),
        _buildBarcodesTab(),
        _buildCommentsTab(),
      ]);
    }

    // Appearance sits last (right after Comments when editing). Tied to the
    // same condition as General so creating a product still exposes it.
    if (!widget.isPostCreation) {
      dialogTabs.add(Tab(text: l10n.setAppearance));
      dialogTabViews.add(_buildAppearanceTab());
    }

    return DefaultTabController(
      length: dialogTabs.length,
      child: AlertDialog(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: 950,
            height: 650,
            child: Column(
              children: [
                TabBar(
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.disabledColor,
                  indicatorColor: theme.colorScheme.primary,
                  tabs: dialogTabs,
                ),
                Expanded(child: TabBarView(children: dialogTabViews)),
                if (_errorMessage != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(_errorMessage!,
                        style: TextStyle(
                            color: context.dangerColor,
                            fontWeight: FontWeight.bold)),
                  )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).actionCancel)),
          if (_isLoading)
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
              onPressed: _submit,
              child: Text(buttonText),
            ),
        ],
      ),
    );
  }

  // --- SUB-WIDGETS TO KEEP THE BUILD TREE CLEAN ---

  Widget _buildGeneralTab() {
    final theme = Theme.of(context);
    final allGroupsAsync = ref.watch(allProductGroupsProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: TextFormField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                                labelText: AppLocalizations.of(context).productNameRequired,
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                                border: const OutlineInputBorder()))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: allGroupsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => Text(AppLocalizations.of(context).errorLoadingGroups),
                        data: (groups) => DropdownButtonFormField<int?>(
                          initialValue: _selectedGroupId,
                          decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).categoryGroup,
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: const OutlineInputBorder()),
                          items: [
                            DropdownMenuItem(
                                value: null,
                                child: Text(AppLocalizations.of(context).noneUncategorized)),
                            ...groups.map((g) => DropdownMenuItem(
                                value: g.id, child: Text(g.name))),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedGroupId = v),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: TextFormField(
                            controller: _codeCtrl,
                            decoration: InputDecoration(
                                labelText: AppLocalizations.of(context).productCodeSku,
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                                border: const OutlineInputBorder()))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: TextFormField(
                            controller: _pluCtrl,
                            decoration: InputDecoration(
                                labelText: AppLocalizations.of(context).plu,
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                                border: const OutlineInputBorder()),
                            keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: TextFormField(
                            controller: _measurementUnitCtrl,
                            decoration: InputDecoration(
                                labelText: AppLocalizations.of(context).measurementUnit,
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                                border: const OutlineInputBorder(),
                                hintText: AppLocalizations.of(context).measurementUnitHint))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: TextFormField(
                            controller: _ageRestrictionCtrl,
                            decoration: InputDecoration(
                                labelText: AppLocalizations.of(context).ageRestriction,
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                                border: const OutlineInputBorder(),
                                hintText: AppLocalizations.of(context).ageRestrictionHint),
                            keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: TextFormField(
                            controller: _priceCtrl,
                            decoration: InputDecoration(
                                labelText: AppLocalizations.of(context).sellingPriceRequired,
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                                border: const OutlineInputBorder(),
                                prefixText: "$currencySymbol "),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: TextFormField(
                            controller: _costCtrl,
                            decoration: InputDecoration(
                                labelText: AppLocalizations.of(context).purchaseCost,
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                                border: const OutlineInputBorder(),
                                prefixText: "$currencySymbol "),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_costPriceMarkupEnabled) ...[
                      Expanded(
                          child: TextFormField(
                              controller: _markupCtrl,
                              decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context).marginMarkup,
                                  filled: true,
                                  fillColor: theme.colorScheme.surface,
                                  border: const OutlineInputBorder(),
                                  suffixText: "%"),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true))),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                        child: TextFormField(
                            controller: _rankCtrl,
                            decoration: InputDecoration(
                                labelText: AppLocalizations.of(context).rankDisplayOrder,
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                                border: const OutlineInputBorder()),
                            keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _descriptionCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).description,
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true)),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      SwitchListTile(
                          title: Text(AppLocalizations.of(context).priceIsTaxInclusive),
                          value: _isTaxInclusive,
                          onChanged: (v) => setState(() => _isTaxInclusive = v),
                          visualDensity: VisualDensity.compact),
                      SwitchListTile(
                          title: Text(AppLocalizations.of(context).isServiceNotPhysical),
                          value: _isService,
                          onChanged: (v) => setState(() => _isService = v),
                          visualDensity: VisualDensity.compact),
                      SwitchListTile(
                          title: Text(AppLocalizations.of(context).changePriceAllowed),
                          value: _isPriceChangeAllowed,
                          onChanged: (v) =>
                              setState(() => _isPriceChangeAllowed = v),
                          visualDensity: VisualDensity.compact),
                      SwitchListTile(
                          title: Text(AppLocalizations.of(context).isEnabledVisible),
                          value: _isEnabled,
                          onChanged: (v) => setState(() => _isEnabled = v),
                          visualDensity: VisualDensity.compact),
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

  // Colour marker + image live in their own tab so the General tab stays a
  // pure data form. Shown whenever General is (i.e. not in post-creation),
  // otherwise a new product could never be given a colour or picture.
  Widget _buildAppearanceTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context).productColorMarker,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: theme.hintColor)),
                const SizedBox(height: 4),
                Text(
                    AppLocalizations.of(context).colorMarkerHint,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 12),
                Wrap(
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
                                ? Border.all(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    width: 3)
                                : null,
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    spreadRadius: 1)
                            ]),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context).productImage,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: theme.hintColor)),
                const SizedBox(height: 4),
                Text(AppLocalizations.of(context).productImageHint,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.dividerColor)),
                      child: _selectedImageBase64 != null &&
                              _selectedImageBase64!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                  base64Decode(_selectedImageBase64!),
                                  fit: BoxFit.cover))
                          : PhosphorIcon(PhosphorIconsRegular.forkKnife,
                              color: theme.hintColor, size: 44),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton.icon(
                            icon: const Icon(Icons.upload, size: 18),
                            label: Text(AppLocalizations.of(context).actionUpload),
                            onPressed: _pickImage),
                        if (_selectedImageBase64 != null &&
                            _selectedImageBase64!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                              onPressed: () =>
                                  setState(() => _selectedImageBase64 = null),
                              child: Text(AppLocalizations.of(context).removeImage,
                                  style: TextStyle(color: context.dangerColor))),
                        ]
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxesTab() {
    final theme = Theme.of(context);
    final allTaxesAsync = ref.watch(allTaxesProvider);
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).applyTaxes,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          allTaxesAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => Text(AppLocalizations.of(context).failedToLoadTaxes),
              data: (taxes) {
                return DropdownButtonFormField<int?>(
                  initialValue: _selectedTaxId,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).primaryTaxRate,
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: null, child: Text(AppLocalizations.of(context).noTax)),
                    ...taxes.map((t) => DropdownMenuItem(
                        value: t.id, child: Text("${t.name} (${t.rate}%)"))),
                  ],
                  onChanged: (v) => setState(() => _selectedTaxId = v),
                );
              }),
        ],
      ),
    );
  }

  Widget _buildCommentsTab() {
    final theme = Theme.of(context);
    // Safety check - we know the product exists because this tab is only shown in Edit/Phase 2 mode!
    if (widget.existingProduct == null) return const SizedBox();

    final productId = widget.existingProduct!.id;
    final asyncComments = ref.watch(productCommentsProvider(productId));
    final companyId = ref.read(selectedCompanyProvider)?.id;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).productModifiersComments,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(
              AppLocalizations.of(context).modifiersHint,
              style: TextStyle(color: theme.hintColor)),
          const SizedBox(height: 24),

          // INPUT ROW
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newCommentCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).newModifierComment,
                    hintText: AppLocalizations.of(context).newModifierHint,
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(AppLocalizations.of(context).actionAdd),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                  ),
                  onPressed: () async {
                    if (_newCommentCtrl.text.trim().isEmpty ||
                        companyId == null) {
                      return;
                    }

                    try {
                      final commentText = _newCommentCtrl.text.trim();
                      // Offline-first: write to local Drift immediately (temp id
                      // + pending_create). The menu's modifier popup sees it at
                      // once, online or offline; the sync pushes it later and
                      // swaps in the server id. Works even on an offline-created
                      // product (its temp productId is remapped before the push).
                      await ref
                          .read(appDatabaseProvider)
                          .createProductCommentLocal(
                            companyId: companyId,
                            productId: productId,
                            comment: commentText,
                          );
                      _newCommentCtrl.clear();
                      ref.invalidate(productCommentsProvider(productId));
                      // Push promptly when online (no-op/queued when offline).
                      unawaited(ref
                          .read(syncManagerProvider)
                          .sync(companyId)
                          .catchError((Object _) => <String>[]));
                    } catch (e) {
                      if (mounted) {
                        showAppSnackbar(context, ref, _parseApiError(context, e),
                            isError: true);
                      }
                    }
                  })
            ],
          ),

          const SizedBox(height: 32),

          // LIST OF COMMENTS
          Expanded(
            child: asyncComments.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text(AppLocalizations.of(context).errorWithMessage(_parseApiError(context, e)),
                        style: TextStyle(color: context.dangerColor))),
                data: (comments) {
                  if (comments.isEmpty) {
                    return Center(
                        child: Text(AppLocalizations.of(context).noCommentsYet,
                            style:
                                TextStyle(color: theme.hintColor, fontSize: 16)));
                  }

                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final c = comments[index];
                        return ListTile(
                          leading:
                              const Icon(Icons.comment, color: Colors.blueGrey),
                          title: Text(c.comment,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: context.dangerColor),
                            tooltip: AppLocalizations.of(context).deleteComment,
                            onPressed: () async {
                              if (companyId == null) return;
                              try {
                                // Offline-first: drop it locally now (temp rows
                                // vanish; server rows are flagged pending_delete
                                // and hidden from reads). The sync issues the
                                // server DELETE when online.
                                await ref
                                    .read(appDatabaseProvider)
                                    .deleteProductCommentLocal(c.id);
                                ref.invalidate(
                                    productCommentsProvider(productId));
                                unawaited(ref
                                    .read(syncManagerProvider)
                                    .sync(companyId)
                                    .catchError((Object _) => <String>[]));
                              } catch (e) {
                                if (context.mounted) {
                                  showAppSnackbar(context, ref, _parseApiError(context, e),
                                      isError: true);
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
                  );
                }),
          )
        ],
      ),
    );
  }

  Widget _buildBarcodesTab() {
    final theme = Theme.of(context);
    if (widget.existingProduct == null) return const SizedBox();

    final productId = widget.existingProduct!.id;
    final companyId = ref.read(selectedCompanyProvider)?.id;

    // Barcodes are seeded in bulk by SyncManager.pullBarcodes and read straight
    // from Drift here — no per-open /Barcodes/GetByProductId fetch.
    final asyncBarcodes = ref.watch(barcodesByProductIdProvider(productId));

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).productBarcodes,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(
              AppLocalizations.of(context).barcodesHint,
              style: TextStyle(color: theme.hintColor)),
          const SizedBox(height: 24),

          // INPUT ROW WITH GENERATOR
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
                        hintText:
                            _isBarcodeChipActive
                                ? ""
                                : AppLocalizations.of(context)
                                    .scanOrEnterBarcode,
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.qr_code_scanner),
                        prefix: _isBarcodeChipActive
                            ? Padding(
                                padding:
                                    const EdgeInsetsDirectional.only(end: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD81B60),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _newBarcodeCtrl.text,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => setState(() {
                                          _newBarcodeCtrl.clear();
                                          _isBarcodeChipActive = false;
                                        }),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 16),
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
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => setState(() {
                        _newBarcodeCtrl.text =
                            DateTime.now().millisecondsSinceEpoch.toString();
                        _isBarcodeChipActive = true;
                      }),
                      child: Text(AppLocalizations.of(context).generateBarcode,
                          style: TextStyle(color: context.infoColor)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                ),
                onPressed: () async {
                  final barcodeValue = _newBarcodeCtrl.text.trim();
                  if (barcodeValue.isEmpty || companyId == null) return;

                  final db = ref.read(appDatabaseProvider);
                  final localId = const Uuid().v4();

                  // Write locally first — appears in the list immediately.
                  await db.into(db.barcodesTable).insert(
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
                    final res = await dio.post('/Barcodes/Add',
                        queryParameters: {'companyId': companyId},
                        data: {'productId': productId, 'value': barcodeValue});
                    final serverId =
                        (res.data is Map ? res.data['id'] : null) as int?;
                    await (db.update(db.barcodesTable)
                          ..where((t) => t.localId.equals(localId)))
                        .write(BarcodesTableCompanion(
                      serverId: Value(serverId),
                      syncStatus: const Value('synced'),
                    ));
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
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text(AppLocalizations.of(context).errorWithMessage(e.toString()),
                      style: TextStyle(color: context.dangerColor))),
              data: (barcodes) {
                if (barcodes.isEmpty) {
                  return Center(
                      child: Text(AppLocalizations.of(context).noBarcodesYet,
                          style: TextStyle(
                              color: theme.hintColor, fontSize: 16)));
                }
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    itemCount: barcodes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final b = barcodes[index];
                      return ListTile(
                        leading: Icon(Icons.qr_code,
                            color: b.isPendingSync
                                ? theme.colorScheme.tertiary
                                : Colors.blueGrey),
                        title: Text(b.value,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5)),
                        subtitle: b.isPendingSync
                            ? Text(AppLocalizations.of(context).pendingSync,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.tertiary))
                            : null,
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: context.dangerColor),
                          tooltip: AppLocalizations.of(context).deleteBarcode,
                          onPressed: () async {
                            if (companyId == null) return;
                            final db = ref.read(appDatabaseProvider);

                            if (b.id == 0) {
                              // Never synced — hard-delete locally.
                              await (db.delete(db.barcodesTable)
                                    ..where((t) =>
                                        t.localId.equals(b.localId)))
                                  .go();
                            } else {
                              // Soft-delete so SyncManager can push the
                              // DELETE to the server on next sync.
                              await (db.update(db.barcodesTable)
                                    ..where((t) =>
                                        t.localId.equals(b.localId)))
                                  .write(const BarcodesTableCompanion(
                                syncStatus: Value('pending_delete'),
                              ));
                              // Try API immediately while online.
                              try {
                                final dio = createDio();
                                await dio.delete('/Barcodes/Delete',
                                    queryParameters: {
                                      'id': b.id,
                                      'companyId': companyId,
                                    });
                                await (db.delete(db.barcodesTable)
                                      ..where((t) =>
                                          t.localId.equals(b.localId)))
                                    .go();
                              } on DioException {
                                // Offline — row stays pending_delete
                                // (already hidden by the provider filter).
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
