import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/core/ilyass_list_scaffold.dart';
import 'package:pos_app/stock/warehouse_model.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/uom/unit_of_measure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pos_app/printer/pdf_fonts.dart';
import 'package:pos_app/printer/printed_text.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/tax/tax_provider.dart';
import 'package:pos_app/printer/pdf_file_name.dart';
import 'package:pos_app/printer/pdf_save_service.dart';
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

/// A bold label and its value as two runs, for the stock sheet's header.
///
/// One run holding an Arabic label and a Latin company name comes out with the
/// Latin reversed; see printer/printed_text.dart.
pw.Widget _sheetPair(
  String label,
  String value,
  pw.TextStyle labelStyle,
  pw.TextStyle valueStyle,
) =>
    pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        printedText(label, style: labelStyle),
        // 🚨 The ':' is a separate run and [label] must arrive without one. A
        // colon is neutral, so at the end of an Arabic label the bidi pass
        // moves it to that run's visual LEFT end and it prints detached on the
        // far side of the label (`:الشركة FUTUR3`).
        printedText(': ', style: labelStyle),
        pw.Flexible(child: printedText(value, style: valueStyle)),
      ],
    );

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

  // ── PDF Generation ──────────────────────────────────────────────────────────

  /// Resolves what the report covers — the filtered rows + the selected
  /// warehouse's name — so Print and Save always render the same sheet.
  void _withReportArgs(
    Future<void> Function(List<StockMasterItem>, String?) action,
  ) {
    final masterList = ref.read(stockMasterProvider).asData?.value;
    if (masterList == null) return;
    String? warehouseName;
    if (_selectedWarehouseId != null) {
      final whs = ref.read(allWarehousesProvider).asData?.value ?? [];
      for (final w in whs) {
        if (w.id == _selectedWarehouseId) {
          warehouseName = w.name;
          break;
        }
      }
    }
    action(_applyFilters(masterList), warehouseName);
  }

  /// Builds the stock sheet. Split from dispatch so Print and Save as PDF
  /// render byte-identical documents. Returns null when there is no company.
  Future<Uint8List?> _buildStockPdf(
    AppLocalizations l,
    List<StockMasterItem> items,
    String? warehouseName,
  ) async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return null;
    // The company's display date format — this sheet is a PRINTED document, so
    // it follows the setting like every other one.
    final dates = ref.read(appDateFormatProvider);

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

    final font      = await PdfFonts.latin();
    final bold      = await PdfFonts.latin(bold: true);
    // Named per STYLE, not just in the page theme: Arabic shaping rewrites the
    // text into presentation forms that resolve only when the Arabic face is
    // the run's base font, and `styleForScript` can only swap it in if the
    // style lists it. See printer/printed_text.dart.
    final arabic    = await PdfFonts.arabic();
    final arabicBold = await PdfFonts.arabic(bold: true);
    pw.TextStyle sheetStyle({double size = 8, bool isBold = false}) =>
        pw.TextStyle(
          font: isBold ? bold : font,
          fontFallback: [isBold ? arabicBold : arabic],
          fontWeight: isBold ? pw.FontWeight.bold : null,
          fontSize: size,
        );
    final moneyFmt  = NumberFormat('#,##0.00');
    final now       = DateTime.now();

    // ── Tax rates ────────────────────────────────────────────────────────────
    // This valuation used to split before/after tax with a HARDCODED 1.15 — a
    // 15% assumption that is simply wrong for a company on TVA 20%, silently
    // mis-stating the value of the whole stock. Resolve each product's real
    // rate the same way the cart does: its own assignment first, then the
    // configured default (only while the tax-inclusive feature is on).
    final ratesByProduct = <int, double>{};
    double defaultPctRate = 0;
    try {
      final db = ref.read(appDatabaseProvider);
      final companyId = ref.read(selectedCompanyProvider)?.id;
      final taxes = await ref.read(allTaxesProvider.future);
      final rateById = {
        for (final t in taxes)
          if (t.isEnabled && !t.isFixed) t.id: t.rate,
      };

      final settings = ref.read(appSettingsProvider);
      if (settings[SettingKeys.taxIncludedByDefault]?.toLowerCase() == 'true') {
        for (final id
            in parseDefaultTaxRateIds(settings[SettingKeys.defaultTaxRateIds])) {
          defaultPctRate += rateById[id] ?? 0;
        }
      }

      if (companyId != null) {
        final assignments = await (db.select(db.productTaxesTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where((t) => t.syncStatus.isNotValue('pending_delete')))
            .get();
        for (final a in assignments) {
          ratesByProduct[a.productId] =
              (ratesByProduct[a.productId] ?? 0) + (rateById[a.taxId] ?? 0);
        }
      }
    } catch (_) {
      // Offline/edge failure: fall through with 0% rather than a wrong 15%.
    }

    // ── Data rows ────────────────────────────────────────────────────────────
    double totalCostBT = 0, totalCostIT = 0, totalSaleBT = 0, totalSaleIT = 0;
    final rows = <List<String>>[];
    int num = 1;

    for (final item in items) {
      final p    = item.product;
      final qty  = item.totalQuantity;
      // 🚨 `qty` is a STOCK figure — in the category's reference unit — while
      // `cost` and `price` are quoted per SALE unit. Multiplying them directly
      // valued 400 g of a 30 MAD/g product at 12 MAD instead of 12 000, because
      // it charged the gram price for a whole kilogram. Both money figures are
      // restated per reference unit first; for a product sold in its own
      // reference unit this is the identity and nothing changes.
      final unitCost  = pricePerReferenceUnit(p.cost, p.uomId);
      final unitPrice = pricePerReferenceUnit(p.price, p.uomId);
      final costBT  = qty * unitCost;
      // A product with no assignment of its own inherits the configured
      // default, exactly like the cart's fallback.
      final pct     = ratesByProduct[p.id] ?? defaultPctRate;
      final divisor = 1 + pct / 100;
      final saleBT  = p.isTaxInclusivePrice ? qty * unitPrice / divisor : qty * unitPrice;
      final saleIT  = p.isTaxInclusivePrice ? qty * unitPrice : qty * unitPrice * divisor;

      totalCostBT  += costBT;
      totalCostIT  += costBT; // cost incl tax == cost bef tax (no cost tax rate)
      totalSaleBT  += saleBT;
      totalSaleIT  += saleIT;

      rows.add([
        '$num',
        p.code ?? '',
        p.productGroupId != null ? (groupMap[p.productGroupId!] ?? l.rptNoGroup) : l.rptNoGroup,
        p.name,
        formatQuantityValue(qty, referenceUomOf(uomById(p.uomId)).id),
        referenceUomOf(uomById(p.uomId)).code,
        moneyFmt.format(unitCost),
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
          child: printedText(
            text,
            textAlign: rightAlign ? pw.TextAlign.right : pw.TextAlign.left,
            style: (style ?? sheetStyle()).copyWith(color: color),
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
      final s = style ?? sheetStyle(size: isHeader ? 7.5 : 8, isBold: isHeader);
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
        // The per-style `font:` below only sets the BASE face. The fallback has
        // to come from the page theme, or Arabic product names print as empty
        // boxes — Noto Sans carries no Arabic glyphs.
        theme: pw.ThemeData.withFont(
          base: font,
          bold: bold,
          fontFallback: [await PdfFonts.arabic()],
        ),
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
                      printedText(
                        l.rptTitleStockReport,
                        style: sheetStyle(size: 22, isBold: true)
                            .copyWith(color: const PdfColor.fromInt(0xFF263238)),
                      ),
                      pw.SizedBox(height: 6),
                      _sheetPair(
                        l.rptColCompany,
                        company.name,
                        sheetStyle(size: 9, isBold: true)
                            .copyWith(color: PdfColors.grey700),
                        sheetStyle(size: 9),
                      ),
                      if (address.isNotEmpty)
                        _sheetPair(
                          l.setAddress,
                          address,
                          sheetStyle(size: 9, isBold: true)
                              .copyWith(color: PdfColors.grey700),
                          sheetStyle(size: 9),
                        ),
                      if (warehouseName != null)
                        _sheetPair(
                          l.warehouse,
                          warehouseName,
                          sheetStyle(size: 9, isBold: true)
                              .copyWith(color: PdfColors.grey700),
                          sheetStyle(size: 9),
                        ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    printedText(
                      dates.date.format(now),
                      style: sheetStyle(size: 11, isBold: true)
                          .copyWith(color: const PdfColor.fromInt(0xFF263238)),
                    ),
                    printedText(
                      l.rptProductCount(rows.length),
                      style: sheetStyle(size: 9)
                          .copyWith(color: PdfColors.grey600),
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
                ['#', l.fieldCode, l.fieldProductGroup, l.productLabel,
                 l.rptColQtyShort, l.rptColUom, l.rptColCostPrice,
                 l.rptColCostBeforeTax, l.rptColCostInclTax,
                 l.rptColTotalBefTax, l.totalLabel],
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
                ['', '', '', l.rptTotalsRow, '', '', '',
                 moneyFmt.format(totalCostBT),
                 moneyFmt.format(totalCostIT),
                 moneyFmt.format(totalSaleBT),
                 moneyFmt.format(totalSaleIT)],
                bg: totalsBg,
                style: sheetStyle(isBold: true),
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
              printedText(
                dates.dateTimeSeconds.format(now),
                style: sheetStyle(size: 7.5)
                    .copyWith(color: PdfColors.grey600),
              ),
              printedText(
                l.rptPageOf('${ctx.pageNumber}', '${ctx.pagesCount}'),
                style: sheetStyle(size: 7.5)
                    .copyWith(color: PdfColors.grey600),
              ),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  Future<void> _printPdf(
    List<StockMasterItem> items,
    String? warehouseName,
  ) async {
    final bytes =
        await _buildStockPdf(AppLocalizations.of(context), items, warehouseName);
    if (bytes == null) return;
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      // No '.pdf' — the platform appends the extension to the job name, so
      // spelling it here produced 'Stock-2026-07-16.pdf.pdf'.
      name: stockPdfName(DateTime.now()),
      format: PdfPageFormat.a4.landscape,
    );
  }

  Future<void> _savePdf(
    List<StockMasterItem> items,
    String? warehouseName,
  ) async {
    final l = AppLocalizations.of(context);
    final bytes = await _buildStockPdf(l, items, warehouseName);
    if (bytes == null) return;
    try {
      final path = await savePdfAs(
        bytes: bytes,
        suggestedName: stockPdfName(DateTime.now()),
        dialogTitle: l.saveStockReportTitle,
      );
      if (!mounted || path == null) return;
      showAppSnackbar(
          context, ref, AppLocalizations.of(context).savedToPath(path));
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(
          context, ref, AppLocalizations.of(context).saveFailed(e.toString()),
          isError: true);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  // ── search & filters ──────────────────────────────────────────────────────

  /// Every filter this screen carries, in the header's one bar: the typed
  /// query, the warehouse, and the three flags. They were a 60px strip of
  /// dropdowns and chips above the table, which cost that height on every
  /// screen to state what three chips now say inside the bar.
  Widget _buildSearchBar(BuildContext context, List<Warehouse> warehouses) {
    final l = AppLocalizations.of(context);
    final warehouse =
        warehouses.where((w) => w.id == _selectedWarehouseId).firstOrNull;

    void clearSelection() {
      // Selection is by id and survives filtering, so a row a filter hid must
      // not stay selected behind it.
      _selectedProductId = null;
    }

    return UnifiedSearchBar(
      controller: _searchCtrl,
      singleLine: true,
      hintText: l.searchProductNameOrCode,
      chips: [
        if (warehouse != null)
          SearchBarChip(
            id: 'warehouse',
            label: warehouse.name,
            icon: Icons.warehouse_outlined,
            onRemove: () => setState(() {
              _selectedWarehouseId = null;
              clearSelection();
            }),
          ),
        if (_showUnassigned)
          SearchBarChip(
            id: 'unassigned',
            label: l.unassigned,
            icon: Icons.warning_amber,
            color: context.warningColor,
            onRemove: () => setState(() => _showUnassigned = false),
          ),
        if (_showLowStock)
          SearchBarChip(
            id: 'low',
            label: l.lowStock,
            icon: Icons.trending_down,
            color: context.dangerColor,
            onRemove: () => setState(() => _showLowStock = false),
          ),
        if (_showReorder)
          SearchBarChip(
            id: 'reorder',
            label: l.needsReorder,
            icon: Icons.replay,
            color: context.warningColor,
            onRemove: () => setState(() => _showReorder = false),
          ),
      ],
      sectionsBuilder: (_) => [
        FilterMenuSection(
          title: l.warehouse,
          icon: Icons.warehouse_outlined,
          options: [
            FilterMenuOption(
              label: l.allWarehousesCap,
              icon: Icons.all_inbox,
              selected: _selectedWarehouseId == null,
              onSelected: () => setState(() {
                _selectedWarehouseId = null;
                clearSelection();
              }),
            ),
            for (final w in warehouses)
              FilterMenuOption(
                label: w.name,
                icon: Icons.warehouse_outlined,
                selected: _selectedWarehouseId == w.id,
                onSelected: () => setState(() {
                  _selectedWarehouseId = w.id;
                  clearSelection();
                }),
              ),
          ],
        ),
        FilterMenuSection(
          title: l.statusLabel,
          icon: Icons.flag_outlined,
          options: [
            FilterMenuOption(
              label: l.unassigned,
              icon: Icons.warning_amber,
              selected: _showUnassigned,
              onSelected: () =>
                  setState(() => _showUnassigned = !_showUnassigned),
            ),
            FilterMenuOption(
              label: l.lowStock,
              icon: Icons.trending_down,
              selected: _showLowStock,
              onSelected: () => setState(() => _showLowStock = !_showLowStock),
            ),
            FilterMenuOption(
              label: l.needsReorder,
              icon: Icons.replay,
              selected: _showReorder,
              onSelected: () => setState(() => _showReorder = !_showReorder),
            ),
          ],
        ),
      ],
      onQueryChanged: (v) => setState(() {
        _searchQuery = v;
        clearSelection();
      }),
      onClearAll: () {
        _searchCtrl.clear();
        setState(() {
          _searchQuery = '';
          _selectedWarehouseId = null;
          _showUnassigned = false;
          _showLowStock = false;
          _showReorder = false;
          clearSelection();
        });
      },
    );
  }

  List<IlyassMenuAction> _menuActions(BuildContext context) {
    final l = AppLocalizations.of(context);

    return [
      IlyassMenuAction(
        icon: Icons.warehouse_outlined,
        label: l.manageWarehouses,
        onSelected: () => ref.read(securityGuardProvider).guard(
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
      IlyassMenuAction(
        icon: Icons.picture_as_pdf_outlined,
        label: l.printStockReportPdf,
        dividerBefore: true,
        onSelected: () => _withReportArgs(_printPdf),
      ),
      IlyassMenuAction(
        icon: Icons.save_alt,
        label: l.saveStockReportPdf,
        onSelected: () => _withReportArgs(_savePdf),
      ),
      IlyassMenuAction(
        icon: Icons.refresh,
        label: l.refresh,
        onSelected: () => ref.invalidate(stockMasterProvider),
      ),
    ];
  }

  /// 🚨 The details are a MODAL now, not a 340px pane welded to the right of
  /// the table. The pane cost that width on every screen whether or not a
  /// product was selected, which is the whole reason the table had nowhere to
  /// put its columns.
  void _showDetails(StockMasterItem item) {
    setState(() => _selectedProductId = item.product.id);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.85,
          ),
          child: _ProductDetailPanel(
            item: item,
            warehouseId: _selectedWarehouseId,
            onClose: () => Navigator.of(dialogContext).maybePop(),
            onRefresh: () => ref.invalidate(stockMasterProvider),
            onShowAssignDialog: () =>
                _showAssignDialog(context, item.product),
            onShowControlDialog: () =>
                _showStockControlDialog(context, item.product),
          ),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _selectedProductId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final asyncMaster = ref.watch(stockMasterProvider);
    final warehouses = ref.watch(allWarehousesProvider).value ?? const [];
    final sym = ref.watch(currencySymbolProvider);
    final theme = Theme.of(context);

    // Seed the rules map from Drift (offline-first) so filters/rows react to it.
    _rules = ref.watch(stockControlsMapProvider).value ?? const {};

    return IlyassListScaffold(
      title: l.inventoryMasterList,
      onMenuPressed: widget.onMenuPressed,
      searchBar: _buildSearchBar(context, warehouses),
      actions: _menuActions(context),
      body: asyncMaster.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l.errorWithMessage(e.toString()))),
        data: (masterList) {
          final filtered = _applyFilters(masterList);

          return IlyassTable<StockMasterItem>(
            tableId: 'stock',
            rows: filtered,
            rowHeight: 64,
            onRowTap: _showDetails,
            isRowSelected: (item) => item.product.id == _selectedProductId,
            columns: [
              IlyassColumn<StockMasterItem>(
                key: 'product',
                label: l.productLabel,
                width: 300,
                // The one column that absorbs surplus — a product name varies
                // far more than a code or a quantity does.
                flexible: true,
                cell: (context, item) => _productCell(context, item.product),
              ),
              IlyassColumn<StockMasterItem>(
                key: 'code',
                label: l.fieldCode,
                width: 140,
                cell: (context, item) => Text(item.product.code ?? '-',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              IlyassColumn<StockMasterItem>(
                key: 'quantity',
                label: l.fieldQuantity,
                width: 200,
                cell: (context, item) => _quantityCell(context, item),
              ),
              IlyassColumn<StockMasterItem>(
                key: 'value',
                label: l.valueTotal,
                width: 150,
                numeric: true,
                cell: (context, item) =>
                    Text('${_totalValue(item).toStringAsFixed(2)} $sym'),
              ),
            ],
            emptyState: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 64,
                        color: theme.disabledColor.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      masterList.isEmpty
                          ? l.noProductsFound
                          : l.noResultsForFilters,
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

  /// The stock rows for one product under the active warehouse filter.
  List<StockItem> _stocksOf(StockMasterItem item) => _selectedWarehouseId == null
      ? item.stocks
      : item.stocks
          .where((s) => s.warehouseId == _selectedWarehouseId)
          .toList();

  double _totalQty(StockMasterItem item) =>
      _stocksOf(item).fold(0, (sum, s) => sum + s.quantity);

  /// Priced per SALE unit, counted in the STOCK unit — see the note in the
  /// report builder. 0.400 kg of a 30 MAD/g product is 12 000 MAD.
  double _totalValue(StockMasterItem item) =>
      _totalQty(item) *
      pricePerReferenceUnit(item.product.price, item.product.uomId);

  Widget _productCell(BuildContext context, Product product) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FileImage → MemoryImage → placeholder. FileImage is cached by path
          // so the avatar decodes once per product per session.
          product.imageFile != null
              ? CircleAvatar(
                  radius: 14, backgroundImage: FileImage(product.imageFile!))
              : product.imageBytes != null
                  ? CircleAvatar(
                      radius: 14,
                      backgroundImage: MemoryImage(product.imageBytes!))
                  : const CircleAvatar(
                      radius: 14, child: Icon(Icons.inventory_2, size: 14)),
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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: context.infoColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(AppLocalizations.of(context).colSvc,
                  style: TextStyle(
                      color: context.infoColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      );

  Widget _quantityCell(BuildContext context, StockMasterItem item) {
    final product = item.product;
    final stocks = _stocksOf(item);
    final totalQty = _totalQty(item);

    // Stock-control rule status (offline-first, from _rules).
    final rule = _rules[product.id];
    final isLow = rule != null && rule.isLowStockAt(totalQty);
    final needsReorder = rule != null && rule.needsReorderAt(totalQty);

    if (stocks.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.dangerColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: context.dangerColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, size: 14, color: context.dangerColor),
            const SizedBox(width: 4),
            Text(AppLocalizations.of(context).unassigned,
                style: TextStyle(
                    color: context.dangerColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            '${formatQuantityValue(totalQty, product.stockUom.id)} '
            '${product.stockUom.code}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isLow
                  ? context.dangerColor
                  : needsReorder
                      ? context.warningColor
                      : context.successColor,
            ),
          ),
        ),
        if (isLow || needsReorder) ...[
          const SizedBox(width: 6),
          _StockFlag(
            label: isLow
                ? AppLocalizations.of(context).flagLow
                : AppLocalizations.of(context).flagReorder,
            color: isLow ? context.dangerColor : context.warningColor,
          ),
        ],
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
      title: Text(AppLocalizations.of(context).assignProductToWarehouse(widget.product.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          asyncWarehouses.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text(AppLocalizations.of(context).errorWithMessage(e.toString())),
            data: (warehouses) => DropdownButtonFormField<int>(
              decoration:
                  InputDecoration(labelText: AppLocalizations.of(context).warehouse),
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
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).initialQuantity,
              // Stock is counted in the category's reference unit, so a
              // gram-priced product still takes kilograms here.
              suffixText: referenceUomOf(uomById(widget.product.uomId)).code,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).actionCancel)),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2))
              : Text(AppLocalizations.of(context).actionSave),
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
        showAppSnackbar(
          context, ref, AppLocalizations.of(context).errorWithMessage(e.toString()),
          isError: true);
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
      showAppSnackbar(
          context, ref, AppLocalizations.of(context).errorWithMessage(e.toString()),
          isError: true);
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
      showAppSnackbar(
          context, ref, AppLocalizations.of(context).errorWithMessage(e.toString()),
          isError: true);
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
        title: Text(AppLocalizations.of(context).errorLabel),
        content: Text("$e"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).actionClose)),
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
                  AppLocalizations.of(context)
                      .stockRulesForProduct(widget.product.name),
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
                      label: Text(AppLocalizations.of(context).ruleExistsEditing),
                      backgroundColor:
                          context.successColor.withValues(alpha: 0.15),
                      side: BorderSide(
                          color: context.successColor.withValues(alpha: 0.4)),
                    ),
                  ),
                TextField(
                  controller: _reorderCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).reorderPoint,
                    helperText:
                        AppLocalizations.of(context).reorderPointHelp,
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _preferredCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).preferredQuantity,
                    helperText:
                        AppLocalizations.of(context).preferredQuantityHelp,
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(AppLocalizations.of(context).lowStockWarning),
                  subtitle:
                      Text(AppLocalizations.of(context).lowStockWarningHelp),
                  value: _lowStockEnabled,
                  onChanged: (v) =>
                      setState(() => _lowStockEnabled = v),
                ),
                if (_lowStockEnabled) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _lowStockQtyCtrl,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).warningThreshold,
                      helperText:
                          AppLocalizations.of(context).warningThresholdHelp,
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
                child: Text(AppLocalizations.of(context).deleteRule),
              ),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).actionCancel)),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2))
                  : Text(control != null
                      ? AppLocalizations.of(context).actionUpdate
                      : AppLocalizations.of(context).actionCreate),
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

  // No `key`: the panel used to be a persistent pane that had to be rebuilt
  // when the selected product changed. Each one is its own dialog now, so it
  // is fresh by construction.
  const _ProductDetailPanel({
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
      showAppSnackbar(
          context, ref, AppLocalizations.of(context).errorWithMessage(e.toString()),
          isError: true);
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteStock(StockItem stock) async {
    if (ref.read(selectedCompanyProvider) == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).removeStock),
        content: Text(
            AppLocalizations.of(context).removeStockFromWarehouseConfirm(
                stock.productName, stock.warehouseName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context).actionCancel)),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: ctx.dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).actionRemove),
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
      showAppSnackbar(
          context, ref, AppLocalizations.of(context).errorWithMessage(e.toString()),
          isError: true);
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
      // No width, border or drop shadow: those dressed this as a pane welded to
      // the right edge of the table. It is a dialog now — the Dialog draws the
      // surface and caps the width, and this fills it.
      decoration: BoxDecoration(color: theme.colorScheme.surface),
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
                          AppLocalizations.of(context)
                              .codeWithValue(product.code!),
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
                  tooltip: AppLocalizations.of(context).actionClose,
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
                      _tag(AppLocalizations.of(context).serviceTag,
                          context.infoColor),
                    _tag(
                        AppLocalizations.of(context)
                            .uomWithValue(product.uom.code),
                        Colors.teal),
                    // Only worth saying when the two differ: a gram-priced
                    // product is counted in kilograms, and the number in this
                    // panel is the kilogram one.
                    if (product.uom.id != product.stockUom.id)
                      _tag(
                          AppLocalizations.of(context)
                              .uomStockHeldIn(product.stockUom.code),
                          Colors.blueGrey),
                  ]),
                  const SizedBox(height: 10),
                  _infoRow(AppLocalizations.of(context).sellingPrice,
                      "${product.price.toStringAsFixed(2)} $sym"),
                  _infoRow(AppLocalizations.of(context).costPrice,
                      "${product.cost.toStringAsFixed(2)} $sym"),

                  const Divider(height: 28),

                  // ── Stock entries ─────────────────────────────────
                  _sectionLabel(
                    context,
                    widget.warehouseId != null
                        ? AppLocalizations.of(context).stockInWarehouseUpper
                        : AppLocalizations.of(context).allStockEntriesUpper,
                  ),
                  const SizedBox(height: 8),

                  if (stocks.isEmpty)
                    _emptyBox(
                      context,
                      icon: Icons.warning_amber,
                      color: context.warningColor,
                      message: widget.warehouseId != null
                          ? AppLocalizations.of(context).noStockAssignedWarehouse
                          : AppLocalizations.of(context).noStockAssignedProduct,
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
                          _editQtyCtrl.text = formatQuantityValue(
                              stock.quantity, product.stockUom.id);
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
                      label: Text(AppLocalizations.of(context).assignToWarehouse),
                      onPressed: widget.onShowAssignDialog,
                    ),
                  ),

                  const Divider(height: 28),

                  // ── Stock control rules ───────────────────────────
                  _sectionLabel(
                      context, AppLocalizations.of(context).stockControlRulesUpper),
                  const SizedBox(height: 10),

                  asyncControl.when(
                    loading: () => const Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))),
                    error: (_, __) =>
                        Text(AppLocalizations.of(context).couldNotLoadRules),
                    data: (control) {
                      if (control == null) {
                        return _emptyBox(
                          context,
                          icon: Icons.tune,
                          color: Colors.grey,
                          message: AppLocalizations.of(context).noStockControlRules,
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
                          ? (
                              Colors.red,
                              AppLocalizations.of(context).stockStatusLow
                            )
                          : reorder
                              ? (
                                  Colors.orange,
                                  AppLocalizations.of(context)
                                      .stockStatusReorder
                                )
                              : (
                                  Colors.green,
                                  AppLocalizations.of(context)
                                      .stockStatusHealthy
                                );

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
                          _infoRow(AppLocalizations.of(context).reorderPoint,
                              "${control.reorderPoint}"),
                          _infoRow(
                              AppLocalizations.of(context).preferredQty,
                              "${control.preferredQuantity}"),
                          _infoRow(
                            AppLocalizations.of(context).lowStockWarning,
                            control.isLowStockWarningEnabled
                                ? AppLocalizations.of(context).onBelowValue(
                                    control.lowStockWarningQuantity)
                                : AppLocalizations.of(context).statusDisabled,
                          ),
                          if ((low || reorder) && suggest > 0)
                            _infoRow(
                              AppLocalizations.of(context).suggestedOrder,
                              AppLocalizations.of(context).suggestedOrderValue(
                                  '${formatQuantityValue(suggest, product.stockUom.id)}'
                                      ' ${product.stockUom.code}',
                                  control.preferredQuantity),
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
                      label: Text(AppLocalizations.of(context).editRules),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Both sides flex so a long French value (e.g. "Activé — en dessous
            // de 10") wraps/shrinks instead of overflowing the narrow panel.
            Flexible(
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
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
              _iconBtn(
                  Icons.edit_outlined,
                  theme.colorScheme.primary,
                  AppLocalizations.of(context).editQuantity,
                  onEditTap),
              const SizedBox(width: 2),
              _iconBtn(
                  Icons.delete_outline,
                  context.dangerColor,
                  AppLocalizations.of(context).actionRemove,
                  isSaving ? null : onDelete),
            ],
          ]),
          const SizedBox(height: 8),
          if (isEditing)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: editCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).newQuantity,
                    isDense: true,
                    border: const OutlineInputBorder(),
                    // Stock is counted in the category's reference unit, so a
                    // gram-priced product still takes kilograms here.
                    suffixText: referenceUomOf(uomById(product.uomId)).code,
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
                _iconBtn(Icons.check, context.successColor,
                    AppLocalizations.of(context).actionSave, onSave),
                _iconBtn(Icons.close, context.dangerColor,
                    AppLocalizations.of(context).actionCancel, onCancel),
              ],
            ])
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formatQuantityValue(stock.quantity, product.stockUom.id)} ${product.stockUom.code}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: stock.quantity < 5
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
                Text(
                  "${(stock.quantity * pricePerReferenceUnit(product.price, product.uomId)).toStringAsFixed(2)} $sym",
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
