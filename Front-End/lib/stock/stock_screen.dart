import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/product/product_group_provider.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/stock/warehouses_screen.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/sync/sync_provider.dart';
import 'package:pos_app/stock/stock_model.dart';
import 'package:pos_app/stock/stock_control_model.dart';
import 'package:pos_app/stock/stock_control_provider.dart';
import 'package:pos_app/product/product_model.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/security/security_guard.dart';
import 'package:pos_app/security/security_keys.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class StockMasterItem {
  final Product product;
  final List<StockItem> stocks;

  StockMasterItem({required this.product, required this.stocks});

  double get totalQuantity => stocks.fold(0, (sum, s) => sum + s.quantity);
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Offline-first: products + stocks read from the local Drift cache (kept fresh
/// by SyncManager.pullProducts / pullStocks). No network round-trip.
final stockMasterProvider =
    FutureProvider.autoDispose<List<StockMasterItem>>((ref) async {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return [];

  final db = ref.watch(appDatabaseProvider);
  final productRows = await db.getStocksForCompany(company.id); // stocks
  final products = await (db.select(db.productsTable)
        ..where((t) => t.companyId.equals(company.id))
        ..where((t) => t.syncStatus.isNotIn(['pending_delete'])))
      .get();
  final warehouseRows = await (db.select(db.warehousesTable)
        ..where((t) => t.companyId.equals(company.id)))
      .get();
  final warehouseNames = {for (final w in warehouseRows) w.id: w.name};

  // Group stock rows by product, resolving warehouse + product display fields.
  final stocksByProduct = <int, List<StockItem>>{};
  final productById = {for (final p in products) p.id: p};
  for (final s in productRows) {
    final p = productById[s.productId];
    (stocksByProduct[s.productId] ??= []).add(StockItem(
      id: s.id,
      quantity: s.quantity,
      warehouseId: s.warehouseId,
      warehouseName: warehouseNames[s.warehouseId] ?? '',
      productId: s.productId,
      productName: p?.name ?? '',
      companyId: s.companyId,
      cost: p?.cost,
      price: p?.price,
      productCode: p?.code,
    ));
  }

  return products
      .map((p) => StockMasterItem(
            product: Product.fromDrift(p),
            stocks: stocksByProduct[p.id] ?? const [],
          ))
      .toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class StockScreen extends ConsumerStatefulWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const StockScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  int? _selectedWarehouseId;
  int? _selectedProductId;
  String _searchQuery = '';
  bool _showUnassigned = false;
  bool _showLowStock = false;
  bool _showReorder = false;

  // Per-product stock-control rules (productId → rule), seeded from Drift in
  // build() so the filters/rows/badges evaluate against the configured rules.
  Map<int, StockControl> _rules = const {};

  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<StockMasterItem> _applyFilters(List<StockMasterItem> all) {
    var items = all;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((s) =>
              s.product.name.toLowerCase().contains(q) ||
              (s.product.code?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    if (_selectedWarehouseId != null) {
      items = items
          .where((m) =>
              m.stocks.any((s) => s.warehouseId == _selectedWarehouseId))
          .toList();
    }
    if (_showUnassigned) {
      items = items.where((m) => m.stocks.isEmpty).toList();
    }
    if (_showLowStock) {
      // Rule-driven: a product is low when its configured low-stock warning
      // threshold is reached. Products without a rule are out of scope.
      items = items.where((m) {
        final rule = _rules[m.product.id];
        return rule != null && rule.isLowStockAt(m.totalQuantity);
      }).toList();
    }
    if (_showReorder) {
      items = items.where((m) {
        final rule = _rules[m.product.id];
        return rule != null && rule.needsReorderAt(m.totalQuantity);
      }).toList();
    }
    return items;
  }

  StockMasterItem? _findSelected(List<StockMasterItem> list) {
    if (_selectedProductId == null) return null;
    for (final i in list) {
      if (i.product.id == _selectedProductId) return i;
    }
    return null;
  }

  // ── PDF Generation ──────────────────────────────────────────────────────────

  Future<void> _printPdf(
    List<StockMasterItem> items,
    String? warehouseName,
  ) async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;

    Map<int, String> groupMap = {};
    try {
      final groups = await ref.read(allProductGroupsProvider.future);
      groupMap = {for (final g in groups) g.id: g.name};
    } catch (_) {}

    // ── Colours ──────────────────────────────────────────────────────────────
    const headerBg   = PdfColor.fromInt(0xFF37474F); // blueGrey 800
    const headerFg   = PdfColors.white;
    const rowEvenBg  = PdfColors.white;
    const rowOddBg   = PdfColor.fromInt(0xFFF5F7FA);
    const totalsBg   = PdfColor.fromInt(0xFFECEFF1);
    const borderClr  = PdfColor.fromInt(0xFFCFD8DC);
    const accentClr  = PdfColor.fromInt(0xFF00897B); // teal 600

    final font      = await PdfGoogleFonts.notoSansRegular();
    final bold      = await PdfGoogleFonts.notoSansBold();
    final moneyFmt  = NumberFormat('#,##0.00');
    final qtyFmt    = NumberFormat('#,##0.##');
    final now       = DateTime.now();

    // ── Data rows ────────────────────────────────────────────────────────────
    double totalCostBT = 0, totalCostIT = 0, totalSaleBT = 0, totalSaleIT = 0;
    final rows = <List<String>>[];
    int num = 1;

    for (final item in items) {
      final p    = item.product;
      final qty  = item.totalQuantity;
      final costBT  = qty * p.cost;
      final saleBT  = p.isTaxInclusivePrice ? qty * p.price / 1.15 : qty * p.price;
      final saleIT  = p.isTaxInclusivePrice ? qty * p.price : qty * p.price * 1.15;

      totalCostBT  += costBT;
      totalCostIT  += costBT; // cost incl tax == cost bef tax (no cost tax rate)
      totalSaleBT  += saleBT;
      totalSaleIT  += saleIT;

      rows.add([
        '$num',
        p.code ?? '',
        p.productGroupId != null ? (groupMap[p.productGroupId!] ?? '(none)') : '(none)',
        p.name,
        qtyFmt.format(qty),
        p.measurementUnit ?? '',
        moneyFmt.format(p.cost),
        moneyFmt.format(costBT),
        moneyFmt.format(costBT),
        moneyFmt.format(saleBT),
        moneyFmt.format(saleIT),
      ]);
      num++;
    }

    // ── Address (avoid duplication) ──────────────────────────────────────────
    final address = (company.address != null && company.address!.isNotEmpty)
        ? company.address!
        : [company.streetName, company.city]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');

    // ── Cell builder ─────────────────────────────────────────────────────────
    const numericCols = {4, 6, 7, 8, 9, 10};

    pw.Widget cell(
      String text, {
      pw.TextStyle? style,
      bool rightAlign = false,
      PdfColor? color,
    }) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: pw.Text(
            text,
            textAlign: rightAlign ? pw.TextAlign.right : pw.TextAlign.left,
            style: (style ?? pw.TextStyle(font: font, fontSize: 8))
                .copyWith(color: color),
            overflow: pw.TextOverflow.clip,
            maxLines: 2,
          ),
        );

    pw.TableRow buildRow(
      List<String> cells, {
      PdfColor? bg,
      pw.TextStyle? style,
      bool isHeader = false,
    }) {
      final s = style ??
          pw.TextStyle(font: isHeader ? bold : font, fontSize: isHeader ? 7.5 : 8);
      final fg = isHeader ? headerFg : null;
      return pw.TableRow(
        decoration: bg != null ? pw.BoxDecoration(color: bg) : null,
        children: cells.asMap().entries.map((e) {
          final isNum = numericCols.contains(e.key);
          return cell(e.value,
              style: s, rightAlign: isNum, color: fg);
        }).toList(),
      );
    }

    // ── PDF document ─────────────────────────────────────────────────────────
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 40),
        build: (ctx) => [
          // ── Report header ─────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(0, 0, 0, 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: accentClr, width: 2),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'STOCK REPORT',
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 22,
                          color: const PdfColor.fromInt(0xFF263238),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.RichText(
                        text: pw.TextSpan(children: [
                          pw.TextSpan(
                            text: 'Company:  ',
                            style: pw.TextStyle(
                                font: bold,
                                fontSize: 9,
                                color: PdfColors.grey700),
                          ),
                          pw.TextSpan(
                            text: company.name,
                            style: pw.TextStyle(
                                font: font, fontSize: 9),
                          ),
                        ]),
                      ),
                      if (address.isNotEmpty)
                        pw.RichText(
                          text: pw.TextSpan(children: [
                            pw.TextSpan(
                              text: 'Address:  ',
                              style: pw.TextStyle(
                                  font: bold,
                                  fontSize: 9,
                                  color: PdfColors.grey700),
                            ),
                            pw.TextSpan(
                              text: address,
                              style: pw.TextStyle(
                                  font: font, fontSize: 9),
                            ),
                          ]),
                        ),
                      if (warehouseName != null)
                        pw.RichText(
                          text: pw.TextSpan(children: [
                            pw.TextSpan(
                              text: 'Warehouse:  ',
                              style: pw.TextStyle(
                                  font: bold,
                                  fontSize: 9,
                                  color: PdfColors.grey700),
                            ),
                            pw.TextSpan(
                              text: warehouseName,
                              style: pw.TextStyle(
                                  font: font, fontSize: 9),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      DateFormat('dd/MM/yyyy').format(now),
                      style: pw.TextStyle(
                          font: bold,
                          fontSize: 11,
                          color: const PdfColor.fromInt(0xFF263238)),
                    ),
                    pw.Text(
                      '${rows.length} product${rows.length == 1 ? '' : 's'}',
                      style: pw.TextStyle(
                          font: font,
                          fontSize: 9,
                          color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 14),

          // ── Data table ────────────────────────────────────────────────────
          pw.Table(
            border: const pw.TableBorder(
              top:    pw.BorderSide(color: borderClr, width: 0.5),
              bottom: pw.BorderSide(color: borderClr, width: 0.5),
              left:   pw.BorderSide(color: borderClr, width: 0.5),
              right:  pw.BorderSide(color: borderClr, width: 0.5),
              horizontalInside: pw.BorderSide(
                  color: borderClr, width: 0.4),
              verticalInside: pw.BorderSide(
                  color: borderClr, width: 0.4),
            ),
            columnWidths: {
              0: const pw.FixedColumnWidth(20),   // #
              1: const pw.FixedColumnWidth(56),   // Code
              2: const pw.FixedColumnWidth(70),   // Product group
              3: const pw.FlexColumnWidth(2.4),   // Product name (largest)
              4: const pw.FixedColumnWidth(40),   // Qty
              5: const pw.FixedColumnWidth(34),   // UOM
              6: const pw.FixedColumnWidth(62),   // Cost price
              7: const pw.FixedColumnWidth(70),   // Cost bef. tax
              8: const pw.FixedColumnWidth(70),   // Cost incl. tax
              9: const pw.FixedColumnWidth(80),   // Total bef. tax
              10: const pw.FixedColumnWidth(70),  // Total
            },
            children: [
              // Header
              buildRow(
                ['#', 'Code', 'Product group', 'Product',
                 'Qty.', 'UOM', 'Cost price',
                 'Cost bef. tax', 'Cost incl. tax',
                 'Total bef. tax', 'Total'],
                bg: headerBg,
                isHeader: true,
              ),
              // Data rows (banded)
              ...rows.asMap().entries.map((e) => buildRow(
                    e.value,
                    bg: e.key % 2 == 0 ? rowEvenBg : rowOddBg,
                  )),
              // Totals row
              buildRow(
                ['', '', '', 'TOTALS', '', '', '',
                 moneyFmt.format(totalCostBT),
                 moneyFmt.format(totalCostIT),
                 moneyFmt.format(totalSaleBT),
                 moneyFmt.format(totalSaleIT)],
                bg: totalsBg,
                style: pw.TextStyle(font: bold, fontSize: 8),
              ),
            ],
          ),
        ],

        // ── Footer ────────────────────────────────────────────────────────
        footer: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
                top: pw.BorderSide(color: borderClr, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                DateFormat('dd/MM/yyyy HH:mm:ss').format(now),
                style: pw.TextStyle(
                    font: font, fontSize: 7.5, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(
                    font: font, fontSize: 7.5, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Stock-${DateFormat('yyyy-MM-dd').format(now)}.pdf',
      format: PdfPageFormat.a4.landscape,
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final asyncMaster = ref.watch(stockMasterProvider);
    final asyncWarehouses = ref.watch(allWarehousesProvider);
    final sym = ref.watch(currencySymbolProvider);
    final theme = Theme.of(context);

    // Seed the rules map from Drift (offline-first) so filters/rows react to it.
    _rules = ref.watch(stockControlsMapProvider).value ?? const {};

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Inventory Master List"),
        // Suppress the auto back-arrow — ManagementLayout controls navigation.
        automaticallyImplyLeading: false,
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Show navigation',
                onPressed: widget.onMenuPressed,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.warehouse_outlined),
            tooltip: "Manage Warehouses",
            onPressed: () => ref.read(securityGuardProvider).guard(
              context,
              SecurityKeys.warehouses,
              () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WarehousesScreen()),
                );
                // Warehouses may have changed — refresh the list + stock views.
                ref.invalidate(allWarehousesProvider);
                ref.invalidate(stockMasterProvider);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: "Print Stock Report (PDF)",
            onPressed: () {
              final masterList =
                  ref.read(stockMasterProvider).asData?.value;
              if (masterList == null) return;
              final filtered = _applyFilters(masterList);
              String? warehouseName;
              if (_selectedWarehouseId != null) {
                final whs =
                    ref.read(allWarehousesProvider).asData?.value ??
                        [];
                for (final w in whs) {
                  if (w.id == _selectedWarehouseId) {
                    warehouseName = w.name;
                    break;
                  }
                }
              }
              _printPdf(filtered, warehouseName);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(stockMasterProvider),
          ),
        ],
      ),
      body: asyncMaster.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
        data: (masterList) {
          final filtered = _applyFilters(masterList);
          final selectedItem = _findSelected(masterList);

          return Column(
            children: [
              // ── Filter bar ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                      bottom: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  children: [
                    // Search
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: "Search product name or code…",
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onChanged: (v) =>
                            setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Warehouse dropdown
                    asyncWarehouses.when(
                      loading: () => const SizedBox(
                          width: 200,
                          child: LinearProgressIndicator()),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (warehouses) => DropdownMenu<int?>(
                        key: ValueKey(_selectedWarehouseId),
                        initialSelection: _selectedWarehouseId,
                        width: 210,
                        leadingIcon: const Icon(
                            Icons.warehouse_outlined,
                            size: 18),
                        label: const Text("Warehouse"),
                        onSelected: (v) => setState(
                            () => _selectedWarehouseId = v),
                        dropdownMenuEntries: [
                          const DropdownMenuEntry<int?>(
                              value: null,
                              label: "All Warehouses"),
                          ...warehouses.map((w) =>
                              DropdownMenuEntry<int?>(
                                  value: w.id, label: w.name)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Filter chips
                    FilterChip(
                      label: const Text("Unassigned"),
                      selected: _showUnassigned,
                      onSelected: (v) =>
                          setState(() => _showUnassigned = v),
                      selectedColor:
                          context.warningColor.withValues(alpha: 0.2),
                      checkmarkColor: context.warningColor,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text("Low Stock"),
                      selected: _showLowStock,
                      onSelected: (v) =>
                          setState(() => _showLowStock = v),
                      selectedColor:
                          context.dangerColor.withValues(alpha: 0.2),
                      checkmarkColor: context.dangerColor,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text("Needs Reorder"),
                      selected: _showReorder,
                      onSelected: (v) =>
                          setState(() => _showReorder = v),
                      selectedColor:
                          context.warningColor.withValues(alpha: 0.2),
                      checkmarkColor: context.warningColor,
                    ),
                  ],
                ),
              ),

              // ── Content row ────────────────────────────────────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Table ─────────────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: SingleChildScrollView(
                            child: DataTable(
                              showCheckboxColumn: false,
                              headingRowColor: WidgetStateProperty.all(
                                theme.colorScheme
                                    .surfaceContainerHighest,
                              ),
                              columnSpacing: 12,
                              horizontalMargin: 12,
                              columns: const [
                                DataColumn(label: Text("Product")),
                                DataColumn(label: Text("Code")),
                                DataColumn(label: Text("Quantity")),
                                DataColumn(
                                    label: Text("Value (Total)")),
                                DataColumn(label: Text("Actions")),
                              ],
                              rows: filtered
                                  .map((item) => _buildRow(
                                      context, item, sym))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Detail panel ──────────────────────────────────
                    if (selectedItem != null)
                      _ProductDetailPanel(
                        key: ValueKey(_selectedProductId),
                        item: selectedItem,
                        warehouseId: _selectedWarehouseId,
                        onClose: () =>
                            setState(() => _selectedProductId = null),
                        onRefresh: () =>
                            ref.invalidate(stockMasterProvider),
                        onShowAssignDialog: () => _showAssignDialog(
                            context, selectedItem.product),
                        onShowControlDialog: () =>
                            _showStockControlDialog(
                                context, selectedItem.product),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  DataRow _buildRow(
      BuildContext context, StockMasterItem item, String sym) {
    final product = item.product;
    final stocks = _selectedWarehouseId == null
        ? item.stocks
        : item.stocks
            .where((s) => s.warehouseId == _selectedWarehouseId)
            .toList();
    final double totalQty = stocks.fold(0, (sum, s) => sum + s.quantity);
    final double totalValue = totalQty * product.price;
    final bool isSelected = _selectedProductId == product.id;

    // Stock-control rule status (offline-first, from _rules).
    final rule = _rules[product.id];
    final bool isLow = rule != null && rule.isLowStockAt(totalQty);
    final bool needsReorder = rule != null && rule.needsReorderAt(totalQty);

    return DataRow(
      selected: isSelected,
      onSelectChanged: (_) =>
          setState(() => _selectedProductId =
              isSelected ? null : product.id),
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.4);
        }
        if (states.contains(WidgetState.hovered)) {
          return Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5);
        }
        return null;
      }),
      cells: [
        DataCell(
          Row(
            children: [
              // FileImage → MemoryImage → placeholder. FileImage is cached
              // by path so the avatar decodes once per product per session.
              product.imageFile != null
                  ? CircleAvatar(
                      radius: 14,
                      backgroundImage: FileImage(product.imageFile!),
                    )
                  : product.imageBytes != null
                      ? CircleAvatar(
                          radius: 14,
                          backgroundImage: MemoryImage(product.imageBytes!),
                        )
                      : const CircleAvatar(
                          radius: 14,
                          child: Icon(Icons.inventory_2, size: 14),
                        ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (product.isService) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.infoColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('SVC',
                      style: TextStyle(
                          color: context.infoColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
        DataCell(Text(product.code ?? "-")),
        DataCell(
          stocks.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.dangerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: context.dangerColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber,
                          size: 14, color: context.dangerColor),
                      const SizedBox(width: 4),
                      Text("Unassigned",
                          style: TextStyle(
                              color: context.dangerColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      totalQty.toStringAsFixed(totalQty % 1 == 0 ? 0 : 2),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isLow
                            ? Colors.red
                            : needsReorder
                                ? Colors.orange
                                : Colors.green,
                      ),
                    ),
                    if (isLow || needsReorder) ...[
                      const SizedBox(width: 6),
                      _StockFlag(
                        label: isLow ? 'LOW' : 'REORDER',
                        color: isLow ? Colors.red : Colors.orange,
                      ),
                    ],
                  ],
                ),
        ),
        DataCell(
            Text("${totalValue.toStringAsFixed(2)} $sym")),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tblBtn(Icons.add_box, context.successColor, "Assign / Add Stock",
                  () => _showAssignDialog(context, product)),
              const SizedBox(width: 4),
              _tblBtn(Icons.tune, context.warningColor, "Stock Control Rules",
                  () => _showStockControlDialog(context, product)),
            ],
          ),
        ),
      ],
    );
  }

  void _showAssignDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => _AssignStockDialog(product: product),
    ).then((success) {
      if (success == true) {
        ref.invalidate(stockMasterProvider);
        // Stock edits go through the API; refresh the local Drift `stocks`
        // cache so the POS menu's offline-first availability check reflects the
        // change immediately (the menu streams from Drift, not the API).
        final companyId = ref.read(selectedCompanyProvider)?.id;
        if (companyId != null) {
          ref.read(syncManagerProvider).pullStocks(companyId).catchError((_) {});
        }
      }
    });
  }

  void _showStockControlDialog(
      BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => _StockControlDialog(product: product),
    );
  }

  Widget _tblBtn(IconData icon, Color color, String tooltip,
      VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

// ── Small low-stock / reorder flag chip ───────────────────────────────────────

class _StockFlag extends StatelessWidget {
  final String label;
  final Color color;
  const _StockFlag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Assign Stock Dialog ───────────────────────────────────────────────────────

class _AssignStockDialog extends ConsumerStatefulWidget {
  final Product product;
  const _AssignStockDialog({required this.product});

  @override
  ConsumerState<_AssignStockDialog> createState() =>
      _AssignStockDialogState();
}

class _AssignStockDialogState
    extends ConsumerState<_AssignStockDialog> {
  int? _selectedWarehouseId;
  final _qtyCtrl = TextEditingController(text: "0");
  bool _isSaving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncWarehouses = ref.watch(allWarehousesProvider);

    return AlertDialog(
      title: Text("Assign ${widget.product.name} to Warehouse"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          asyncWarehouses.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text("Error: $e"),
            data: (warehouses) => DropdownButtonFormField<int>(
              decoration:
                  const InputDecoration(labelText: "Warehouse"),
              items: warehouses
                  .map((w) => DropdownMenuItem(
                      value: w.id, child: Text(w.name)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedWarehouseId = v),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qtyCtrl,
            decoration:
                const InputDecoration(labelText: "Initial Quantity"),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2))
              : const Text("Save"),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_selectedWarehouseId == null) return;
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;

    setState(() => _isSaving = true);
    try {
      // Offline-first: write the stock row to local Drift; SyncManager pushes
      // /Stocks/Add on the next sync.
      await ref.read(appDatabaseProvider).addStockLocal(
            companyId: company.id,
            productId: widget.product.id,
            warehouseId: _selectedWarehouseId!,
            quantity: qty,
          );
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, "Error: $e", isError: true);
        setState(() => _isSaving = false);
      }
    }
  }
}

// ── Stock Control Dialog ──────────────────────────────────────────────────────

class _StockControlDialog extends ConsumerStatefulWidget {
  final Product product;
  const _StockControlDialog({required this.product});

  @override
  ConsumerState<_StockControlDialog> createState() =>
      _StockControlDialogState();
}

class _StockControlDialogState
    extends ConsumerState<_StockControlDialog> {
  StockControl? _existing;
  bool _isSaving = false;
  bool _lowStockEnabled = true;

  final _reorderCtrl = TextEditingController();
  final _preferredCtrl = TextEditingController();
  final _lowStockQtyCtrl = TextEditingController();

  @override
  void dispose() {
    _reorderCtrl.dispose();
    _preferredCtrl.dispose();
    _lowStockQtyCtrl.dispose();
    super.dispose();
  }

  void _populate(StockControl? control) {
    _existing = control;
    _reorderCtrl.text = (control?.reorderPoint ?? 0).toString();
    _preferredCtrl.text = (control?.preferredQuantity ?? 0).toString();
    _lowStockEnabled = control?.isLowStockWarningEnabled ?? true;
    _lowStockQtyCtrl.text =
        (control?.lowStockWarningQuantity ?? 0).toString();
  }

  Future<void> _save() async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;
    final reorder = double.tryParse(_reorderCtrl.text) ?? 0;
    final preferred = double.tryParse(_preferredCtrl.text) ?? 0;
    final lowQty = double.tryParse(_lowStockQtyCtrl.text) ?? 0;

    setState(() => _isSaving = true);
    try {
      // Offline-first: upsert the rule in local Drift (keyed by product);
      // SyncManager pushes /StockControls/Add or /Update on the next sync.
      await ref.read(appDatabaseProvider).saveStockControlLocal(
            companyId: company.id,
            productId: widget.product.id,
            reorderPoint: reorder,
            preferredQuantity: preferred,
            isLowStockWarningEnabled: _lowStockEnabled,
            lowStockWarningQuantity: lowQty,
          );
      if (!mounted) return;
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      ref.invalidate(stockControlByProductIdProvider(widget.product.id));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, ref, "Error: $e", isError: true);
      setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    if (_existing == null) return;
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(appDatabaseProvider).deleteStockControlLocal(widget.product.id);
      if (!mounted) return;
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      ref.invalidate(stockControlByProductIdProvider(widget.product.id));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, ref, "Error: $e", isError: true);
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncControl =
        ref.watch(stockControlByProductIdProvider(widget.product.id));

    return asyncControl.when(
      loading: () => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => AlertDialog(
        title: const Text("Error"),
        content: Text("$e"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close")),
        ],
      ),
      data: (control) {
        if (_existing != control && !_isSaving) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _populate(control));
          });
        }

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.tune, color: context.warningColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Stock Rules — ${widget.product.name}",
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (control != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Chip(
                      label: const Text("Rule exists — editing"),
                      backgroundColor:
                          context.successColor.withValues(alpha: 0.15),
                      side: BorderSide(
                          color: context.successColor.withValues(alpha: 0.4)),
                    ),
                  ),
                TextField(
                  controller: _reorderCtrl,
                  decoration: const InputDecoration(
                    labelText: "Reorder Point",
                    helperText:
                        "Trigger reorder when stock drops below this level",
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _preferredCtrl,
                  decoration: const InputDecoration(
                    labelText: "Preferred Quantity",
                    helperText:
                        "Target quantity to maintain in stock",
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Low Stock Warning"),
                  subtitle: const Text(
                      "Alert when stock falls below threshold"),
                  value: _lowStockEnabled,
                  onChanged: (v) =>
                      setState(() => _lowStockEnabled = v),
                ),
                if (_lowStockEnabled) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _lowStockQtyCtrl,
                    decoration: const InputDecoration(
                      labelText: "Warning Threshold",
                      helperText:
                          "Show warning when quantity is below this value",
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (control != null)
              TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: context.dangerColor),
                onPressed: _isSaving ? null : _delete,
                child: const Text("Delete Rule"),
              ),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2))
                  : Text(control != null ? "Update" : "Create"),
            ),
          ],
        );
      },
    );
  }
}

// ── Product Detail Panel ──────────────────────────────────────────────────────

class _ProductDetailPanel extends ConsumerStatefulWidget {
  final StockMasterItem item;
  final int? warehouseId;
  final VoidCallback onClose;
  final VoidCallback onRefresh;
  final VoidCallback onShowAssignDialog;
  final VoidCallback onShowControlDialog;

  const _ProductDetailPanel({
    super.key,
    required this.item,
    required this.warehouseId,
    required this.onClose,
    required this.onRefresh,
    required this.onShowAssignDialog,
    required this.onShowControlDialog,
  });

  @override
  ConsumerState<_ProductDetailPanel> createState() =>
      _ProductDetailPanelState();
}

class _ProductDetailPanelState
    extends ConsumerState<_ProductDetailPanel> {
  int? _editingStockId;
  final _editQtyCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _editQtyCtrl.dispose();
    super.dispose();
  }

  List<StockItem> get _visibleStocks {
    final s = widget.item.stocks;
    if (widget.warehouseId == null) return s;
    return s.where((x) => x.warehouseId == widget.warehouseId).toList();
  }

  Future<void> _saveEdit(StockItem stock) async {
    final newQty = double.tryParse(_editQtyCtrl.text);
    if (newQty == null) return;
    if (ref.read(selectedCompanyProvider) == null) return;

    setState(() => _isSaving = true);
    try {
      // Offline-first: update the local stock row; SyncManager pushes
      // /Stocks/Update on the next sync.
      await ref.read(appDatabaseProvider).updateStockLocal(
            id: stock.id,
            productId: stock.productId,
            warehouseId: stock.warehouseId,
            quantity: newQty,
          );
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      if (!mounted) return;
      setState(() {
        _editingStockId = null;
        _isSaving = false;
      });
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, ref, "Error: $e", isError: true);
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteStock(StockItem stock) async {
    if (ref.read(selectedCompanyProvider) == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Stock"),
        content: Text(
            "Remove ${stock.productName} from ${stock.warehouseName}?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: ctx.dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      // Offline-first: remove the local stock row; SyncManager pushes
      // /Stocks/Delete on the next sync.
      await ref.read(appDatabaseProvider).deleteStockLocal(stock.id);
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      if (!mounted) return;
      setState(() => _isSaving = false);
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, ref, "Error: $e", isError: true);
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.item.product;
    final stocks = _visibleStocks;
    final sym = ref.watch(currencySymbolProvider);
    final asyncControl =
        ref.watch(stockControlByProductIdProvider(product.id));

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border:
            Border(left: BorderSide(color: theme.dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Product Header ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                product.imageFile != null
                    ? CircleAvatar(
                        radius: 24,
                        backgroundImage: FileImage(product.imageFile!),
                      )
                    : product.imageBytes != null
                        ? CircleAvatar(
                            radius: 24,
                            backgroundImage:
                                MemoryImage(product.imageBytes!),
                          )
                        : CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                theme.colorScheme.primaryContainer,
                            child: Icon(Icons.inventory_2,
                                color: theme.colorScheme.primary,
                                size: 22),
                          ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.code != null)
                        Text(
                          "Code: ${product.code}",
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme
                                  .colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: "Close",
                ),
              ],
            ),
          ),

          // ── Scrollable body ───────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags
                  Wrap(spacing: 6, children: [
                    if (product.isService)
                      _tag("Service", context.infoColor),
                    if (product.measurementUnit != null)
                      _tag("UOM: ${product.measurementUnit}",
                          Colors.teal),
                  ]),
                  const SizedBox(height: 10),
                  _infoRow("Selling Price",
                      "${product.price.toStringAsFixed(2)} $sym"),
                  _infoRow("Cost Price",
                      "${product.cost.toStringAsFixed(2)} $sym"),

                  const Divider(height: 28),

                  // ── Stock entries ─────────────────────────────────
                  _sectionLabel(
                    context,
                    widget.warehouseId != null
                        ? "STOCK IN WAREHOUSE"
                        : "ALL STOCK ENTRIES",
                  ),
                  const SizedBox(height: 8),

                  if (stocks.isEmpty)
                    _emptyBox(
                      context,
                      icon: Icons.warning_amber,
                      color: context.warningColor,
                      message: "No stock assigned to this"
                          "${widget.warehouseId != null ? " warehouse" : " product"}",
                    )
                  else
                    ...stocks.map((stock) {
                      final isEditing = _editingStockId == stock.id;
                      return _StockEntry(
                        key: ValueKey(stock.id),
                        stock: stock,
                        product: product,
                        sym: sym,
                        isEditing: isEditing,
                        isSaving: _isSaving,
                        editCtrl: _editQtyCtrl,
                        onEditTap: () => setState(() {
                          _editingStockId = stock.id;
                          _editQtyCtrl.text = stock.quantity
                              .toStringAsFixed(
                                  stock.quantity % 1 == 0 ? 0 : 2);
                        }),
                        onSave: () => _saveEdit(stock),
                        onCancel: () =>
                            setState(() => _editingStockId = null),
                        onDelete: () => _deleteStock(stock),
                      );
                    }),

                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_box_outlined,
                          size: 18),
                      label: const Text("Assign to Warehouse"),
                      onPressed: widget.onShowAssignDialog,
                    ),
                  ),

                  const Divider(height: 28),

                  // ── Stock control rules ───────────────────────────
                  _sectionLabel(context, "STOCK CONTROL RULES"),
                  const SizedBox(height: 10),

                  asyncControl.when(
                    loading: () => const Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))),
                    error: (_, __) =>
                        const Text("Could not load rules"),
                    data: (control) {
                      if (control == null) {
                        return _emptyBox(
                          context,
                          icon: Icons.tune,
                          color: Colors.grey,
                          message: "No stock control rules configured",
                        );
                      }
                      // Evaluate the rules against the current (warehouse-
                      // filtered) quantity — this is what makes the rules "work".
                      final stocks = widget.warehouseId == null
                          ? widget.item.stocks
                          : widget.item.stocks
                              .where((s) => s.warehouseId == widget.warehouseId)
                              .toList();
                      final qty =
                          stocks.fold<double>(0, (a, s) => a + s.quantity);
                      final low = control.isLowStockAt(qty);
                      final reorder = control.needsReorderAt(qty);
                      final suggest = control.suggestedReorderQty(qty);

                      final (statusColor, statusText) = low
                          ? (Colors.red, "Low stock — at/below warning level")
                          : reorder
                              ? (Colors.orange, "At/below reorder point")
                              : (Colors.green, "Stock healthy");

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(children: [
                          Row(children: [
                            Icon(
                              low || reorder
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              size: 16,
                              color: statusColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(statusText,
                                  style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          _infoRow("Reorder Point", "${control.reorderPoint}"),
                          _infoRow("Preferred Qty",
                              "${control.preferredQuantity}"),
                          _infoRow(
                            "Low Stock Warning",
                            control.isLowStockWarningEnabled
                                ? "On — below ${control.lowStockWarningQuantity}"
                                : "Disabled",
                          ),
                          if ((low || reorder) && suggest > 0)
                            _infoRow(
                              "Suggested Order",
                              "+${suggest.toStringAsFixed(suggest % 1 == 0 ? 0 : 2)} to reach ${control.preferredQuantity}",
                            ),
                        ]),
                      );
                    },
                  ),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text("Edit Rules"),
                      onPressed: widget.onShowControlDialog,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Widget _sectionLabel(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );

  Widget _emptyBox(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String message,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: color, fontSize: 13))),
        ]),
      );

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Colors.grey)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

// ── Stock Entry Row (in detail panel) ────────────────────────────────────────

class _StockEntry extends StatelessWidget {
  final StockItem stock;
  final Product product;
  final String sym;
  final bool isEditing;
  final bool isSaving;
  final TextEditingController editCtrl;
  final VoidCallback onEditTap;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _StockEntry({
    super.key,
    required this.stock,
    required this.product,
    required this.sym,
    required this.isEditing,
    required this.isSaving,
    required this.editCtrl,
    required this.onEditTap,
    required this.onSave,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEditing
              ? theme.colorScheme.primary
              : theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.warehouse,
                size: 15,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(stock.warehouseName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            if (!isEditing) ...[
              _iconBtn(Icons.edit_outlined, theme.colorScheme.primary,
                  "Edit quantity", onEditTap),
              const SizedBox(width: 2),
              _iconBtn(Icons.delete_outline, context.dangerColor,
                  "Remove", isSaving ? null : onDelete),
            ],
          ]),
          const SizedBox(height: 8),
          if (isEditing)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: editCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "New Quantity",
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (isSaving)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2))
              else ...[
                _iconBtn(Icons.check, context.successColor, "Save",
                    onSave),
                _iconBtn(Icons.close, context.dangerColor, "Cancel",
                    onCancel),
              ],
            ])
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  stock.quantity
                      .toStringAsFixed(stock.quantity % 1 == 0 ? 0 : 2),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: stock.quantity < 5
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
                Text(
                  "${(stock.quantity * product.price).toStringAsFixed(2)} $sym",
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback? onPressed,
  ) =>
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(icon, size: 18, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
      );
}
