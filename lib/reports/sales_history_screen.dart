import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/document/document_model.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/refund/refund_dialog.dart';
import 'package:pos_app/security/security_guard.dart';
import 'package:pos_app/security/security_keys.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/printer/invoice_pdf_service.dart';
import 'package:pos_app/cart/discount_display.dart';
import 'package:pos_app/printer/receipt_printer_service.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class SalesHistoryDocument {
  final int id;
  final String? localId;
  final String number;
  final String? userName;
  final String? customerName;
  final String? warehouseName;
  final String? orderNumber;
  final String? referenceDocumentNumber;
  final String date;
  final String stockDate;
  final String dateCreated;
  final double total;
  final double totalBeforeTax;
  final double taxTotal;
  final double discount;
  // 0 = Percentage, 1 = Fixed. The header discount is stored as-entered (unlike
  // item discounts which are pre-converted to an absolute amount), so the type
  // decides whether to render it as a '%' or a currency amount.
  final int discountType;
  final int paidStatus;
  final String? paymentSummary;

  SalesHistoryDocument({
    required this.id,
    this.localId,
    required this.number,
    this.userName,
    this.customerName,
    this.warehouseName,
    this.orderNumber,
    this.referenceDocumentNumber,
    required this.date,
    required this.stockDate,
    required this.dateCreated,
    required this.total,
    required this.totalBeforeTax,
    required this.taxTotal,
    required this.discount,
    this.discountType = 0,
    required this.paidStatus,
    this.paymentSummary,
  });

  factory SalesHistoryDocument.fromJson(Map<String, dynamic> j) {
    return SalesHistoryDocument(
      id: j['id'] ?? 0,
      number: j['number'] ?? '',
      userName: j['userName'],
      customerName: j['customerName'],
      warehouseName: j['warehouseName'],
      orderNumber: j['orderNumber'],
      referenceDocumentNumber: j['referenceDocumentNumber'],
      date: j['date'] ?? '',
      stockDate: j['stockDate'] ?? '',
      dateCreated: j['dateCreated'] ?? '',
      total: (j['total'] as num?)?.toDouble() ?? 0,
      totalBeforeTax: (j['totalBeforeTax'] as num?)?.toDouble() ?? 0,
      taxTotal: (j['taxTotal'] as num?)?.toDouble() ?? 0,
      discount: (j['discount'] as num?)?.toDouble() ?? 0,
      discountType: (j['discountType'] as num?)?.toInt() ?? 0,
      paidStatus: j['paidStatus'] ?? 0,
      paymentSummary: j['paymentSummary'],
    );
  }
}

// ── Responsive table helpers ──────────────────────────────────────────────────

class _ColDef {
  final String label;
  final double flex;
  final bool numeric;
  const _ColDef(this.label, {this.flex = 1.0, this.numeric = false});
}

class _FlexTable extends StatelessWidget {
  final List<_ColDef> columns;
  final int rowCount;
  // Builds one row's cells on demand. Called from the ListView's itemBuilder so
  // cells are only constructed for visible rows — a large sales history no
  // longer instantiates every cell widget up front on each rebuild.
  final List<Widget> Function(int index) rowBuilder;
  final bool Function(int index)? isRowSelected;
  final void Function(int index)? onRowTap;
  final Widget? emptyWidget;

  const _FlexTable({
    required this.columns,
    required this.rowCount,
    required this.rowBuilder,
    this.isRowSelected,
    this.onRowTap,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Sticky header ──────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 0.5),
            ),
          ),
          child: _buildRow(
            columns
                .map(
                  (c) => Text(
                    c.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.55),
                      letterSpacing: 0.4,
                    ),
                    textAlign: c.numeric ? TextAlign.right : TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                )
                .toList(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          ),
        ),
        // ── Body ──────────────────────────────────────────────────────────
        Expanded(
          child: rowCount == 0
              ? (emptyWidget ?? const SizedBox.shrink())
              : ListView.separated(
                  itemCount: rowCount,
                  separatorBuilder: (_, __) => Divider(
                    height: 0.5,
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                  itemBuilder: (ctx, i) {
                    final selected = isRowSelected?.call(i) ?? false;
                    return InkWell(
                      onTap: onRowTap == null ? null : () => onRowTap!(i),
                      mouseCursor: onRowTap == null
                          ? null
                          : SystemMouseCursors.click,
                      child: Container(
                        color: selected
                            ? cs.primary.withValues(alpha: 0.14)
                            : null,
                        child: _buildRow(
                          rowBuilder(i),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRow(List<Widget> cells, {required EdgeInsets padding}) {
    return Padding(
      padding: padding,
      child: Row(
        children: List.generate(columns.length, (i) {
          return Expanded(
            flex: (columns[i].flex * 10).round(),
            child: Padding(
              padding: EdgeInsets.only(right: i < columns.length - 1 ? 10 : 0),
              child: Align(
                alignment: columns[i].numeric
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: cells[i],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  // ── filter state ──────────────────────────────────────────────────────────
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _showAllUsers = true;
  Customer? _filterCustomer;
  final _docNumCtrl = TextEditingController();

  // ── data state ────────────────────────────────────────────────────────────
  List<SalesHistoryDocument> _documents = [];
  List<DocumentItem> _items = [];
  String? _selectedDocLocalId;
  bool _loading = false;
  bool _itemsLoading = false;
  String? _error;

  // ── split pane ────────────────────────────────────────────────────────────
  double _splitFraction = 0.55;

  // ── column visibility (per-device, persisted in SharedPreferences) ──────────
  // Which columns each table shows. Seeded from prefs (falling back to "all");
  // the "Columns" pickers toggle entries and at least one column always stays
  // visible (the picker forbids clearing the last one).
  static const _prefsMasterColsKey = 'sales_history_master_cols';
  static const _prefsDetailColsKey = 'sales_history_detail_cols';
  late Set<String> _visibleMasterColIds;
  late Set<String> _visibleDetailColIds;

  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _numFmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    tz_data.initializeTimeZones();
    _visibleMasterColIds = _loadCols(
      _prefsMasterColsKey,
      _masterColumns.map((c) => c.id),
    );
    _visibleDetailColIds = _loadCols(
      _prefsDetailColsKey,
      _detailColumns.map((c) => c.id),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDocuments());
  }

  /// Reads a persisted set of visible column ids, dropping any stale ids no
  /// longer present in [allIds] and falling back to "all visible" when nothing
  /// valid is stored (first run, or a saved set that's been fully invalidated).
  Set<String> _loadCols(String prefsKey, Iterable<String> allIds) {
    final all = allIds.toSet();
    final stored = ref.read(sharedPreferencesProvider).getStringList(prefsKey);
    if (stored == null || stored.isEmpty) return all;
    final valid = stored.where(all.contains).toSet();
    return valid.isEmpty ? all : valid;
  }

  void _saveCols(String prefsKey, Set<String> ids) {
    ref.read(sharedPreferencesProvider).setStringList(prefsKey, ids.toList());
  }

  @override
  void dispose() {
    _docNumCtrl.dispose();
    super.dispose();
  }

  // ── date formatting ───────────────────────────────────────────────────────

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso);
      final isTs = iso.contains('T') || iso.contains(' ');
      if (isTs) {
        final utc = dt.isUtc
            ? dt
            : DateTime.utc(
                dt.year,
                dt.month,
                dt.day,
                dt.hour,
                dt.minute,
                dt.second,
              );
        final tzId =
            ref.read(appSettingsProvider)[SettingKeys.timezone] ?? 'UTC';
        DateTime disp;
        try {
          disp = tz.TZDateTime.from(utc, tz.getLocation(tzId));
        } catch (_) {
          disp = utc;
        }
        return '${_pad(disp.day)}/${_pad(disp.month)}/${disp.year} '
            '${_pad(disp.hour)}:${_pad(disp.minute)}';
      }
      return '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> _fetchDocuments() async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _selectedDocLocalId = null;
      _items = [];
    });

    try {
      // Offline-first: read sales documents straight from the local Drift store
      // (kept fresh by SyncManager.pullDocuments). No network needed.
      final db = ref.read(appDatabaseProvider);
      final user = ref.read(currentUserProvider);

      // Lookup maps for name resolution + payment summaries.
      final userRows = await db.select(db.usersTable).get();
      final customerRows = await db.select(db.customersTable).get();
      final warehouseRows = await db.select(db.warehousesTable).get();
      final payTypeRows = await db.select(db.paymentTypesTable).get();
      final userMap = {for (final u in userRows) u.id: u.name};
      final customerMap = {for (final c in customerRows) c.id: c.name};
      final warehouseMap = {for (final w in warehouseRows) w.id: w.name};
      final payTypeMap = {for (final p in payTypeRows) p.id: p.name};

      // Inclusive end-of-day bound for the date filter.
      final from = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final to = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        23,
        59,
        59,
      );

      final rows = await db.getDocuments(
        companyId: company.id,
        from: from,
        to: to,
        userId: _showAllUsers ? null : user?.id,
        customerId: _filterCustomer?.id,
      );

      final docs = <SalesHistoryDocument>[];
      for (final row in rows) {
        final items = await db.getActiveDocumentItems(row.localId);
        final taxTotal = items.fold<double>(0, (s, i) => s + i.taxAmount);

        final payments = await db.getPayments(row.localId);
        final visiblePayments = payments.where(
          (p) => p.syncStatus != 'pending_delete',
        );
        final paymentSummary = visiblePayments.isEmpty
            ? null
            : visiblePayments
                  .map(
                    (p) =>
                        '${payTypeMap[p.paymentTypeId] ?? 'Payment'}: ${p.amount.toStringAsFixed(2)}',
                  )
                  .join(', ');

        docs.add(
          SalesHistoryDocument(
            id: row.serverId ?? 0,
            localId: row.localId,
            number: row.number?.isNotEmpty == true
                ? row.number!
                : (row.syncStatus == 'pending' ||
                          row.syncStatus == 'pending_create'
                      ? '(Pending sync)'
                      : '—'),
            userName: userMap[row.userId],
            customerName: row.customerId != null
                ? customerMap[row.customerId]
                : null,
            warehouseName: warehouseMap[row.warehouseId],
            orderNumber: row.orderNumber,
            referenceDocumentNumber: row.referenceDocumentNumber,
            date: row.date.toIso8601String(),
            stockDate: (row.stockDate ?? row.date).toIso8601String(),
            dateCreated: (row.stockDate ?? row.date).toIso8601String(),
            total: row.total,
            totalBeforeTax: row.total - taxTotal,
            taxTotal: taxTotal,
            discount: row.discount,
            discountType: row.discountType,
            paidStatus: row.paidStatus,
            paymentSummary: paymentSummary,
          ),
        );
      }

      var filtered = docs;
      final search = _docNumCtrl.text.trim().toLowerCase();
      if (search.isNotEmpty) {
        filtered = filtered
            .where((d) => d.number.toLowerCase().contains(search))
            .toList();
      }
      setState(() {
        _documents = filtered;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchItems(SalesHistoryDocument doc) async {
    final localId = doc.localId;
    if (localId == null) {
      setState(() {
        _items = [];
      });
      return;
    }

    setState(() {
      _itemsLoading = true;
      _items = [];
    });
    try {
      // Offline-first: line items from the local Drift store, with product
      // names resolved from the local product cache.
      final db = ref.read(appDatabaseProvider);
      final rows = await db.getActiveDocumentItems(localId);
      final productRows = await db.select(db.productsTable).get();
      final pById = {for (final p in productRows) p.id: p};
      setState(() {
        _items = rows.map((r) {
          final p = pById[r.productId];
          return DocumentItem(
            id: r.serverId ?? 0,
            localId: r.localId,
            companyId: doc.id,
            documentId: doc.id,
            productId: r.productId,
            productName: p?.name,
            productCode: p?.code,
            measurementUnit: p?.measurementUnit,
            quantity: r.quantity,
            expectedQuantity: r.quantity,
            priceBeforeTax: r.priceBeforeTax,
            price: r.unitPrice,
            discount: r.discount,
            discountType: r.discountType,
            productCost: p?.cost ?? 0,
            priceBeforeTaxAfterDiscount: r.taxRate > 0
                ? r.total / (1 + r.taxRate / 100)
                : r.total,
            priceAfterDiscount: r.unitPrice,
            total: r.total,
            totalAfterDocumentDiscount: r.total,
            discountApplyRule: true,
          );
        }).toList();
      });
    } catch (_) {
      setState(() {
        _items = [];
      });
    } finally {
      setState(() {
        _itemsLoading = false;
      });
    }
  }

  Future<void> _deleteDocument(SalesHistoryDocument doc) async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text("Delete '${doc.number}'? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      // Offline-first: soft/hard-delete locally; the sync queue issues
      // /Document/Delete on the next sync.
      final db = ref.read(appDatabaseProvider);
      var localId = doc.localId;
      if (localId == null && doc.id > 0) {
        localId = (await db.getDocumentByServerId(doc.id))?.localId;
      }
      if (localId != null) {
        await db.deleteDocumentLocal(localId);
        ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      } else if (doc.id > 0) {
        await createDio().delete(
          '/Document/Delete',
          queryParameters: {'id': doc.id, 'companyId': company.id},
        );
      }
      if (!mounted) return;
      showAppSnackbar(context, ref, 'Document deleted');
      _fetchDocuments();
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final msg =
          (data is Map ? data['message'] : data?.toString()) ?? 'Delete failed';
      showAppSnackbar(context, ref, msg, isError: true);
    }
  }

  Future<void> _ensureItemsLoaded(SalesHistoryDocument doc) async {
    if (_items.isEmpty && !_itemsLoading) {
      await _fetchItems(doc);
    }
  }

  Map<String, dynamic> _invoiceArgs(SalesHistoryDocument doc) {
    Uint8List? logoBytes;
    final logoBase64 = ref.read(selectedCompanyProvider)?.logo;
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        logoBytes = base64Decode(logoBase64);
      } catch (_) {}
    }
    return {
      'company': ref.read(selectedCompanyProvider)!,
      'invoiceNumber': doc.number,
      'date': doc.stockDate,
      'customerName': doc.customerName,
      'isPaid': doc.paidStatus != 0,
      'items': _items,
      'total': doc.total,
      'totalBeforeTax': doc.totalBeforeTax,
      'taxTotal': doc.taxTotal,
      'discount': doc.discount,
      'paymentSummary': doc.paymentSummary,
      'currencySymbol': ref.read(currencySymbolProvider),
      'logoBytes': logoBytes,
    };
  }

  /// Itemized discount lines for a history document, resolved from local Drift
  /// by document number (offline-first sales carry a discount_lines record).
  /// Empty for cloud-only/legacy docs — surfaces just fall back to no breakdown.
  Future<List<ReceiptDiscountLine>> _discountLinesFor(
    SalesHistoryDocument doc, {
    bool includeLoyalty = true,
  }) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return const [];
    final db = ref.read(appDatabaseProvider);
    final row =
        await (db.select(db.documentsTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where((t) => t.number.equals(doc.number))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return const [];
    return toReceiptDiscountLines(
      await db.getDiscountLinesForDocument(row.localId),
      ref.read(currencySymbolProvider),
      includeLoyalty: includeLoyalty,
    );
  }

  Future<void> _printInvoice(SalesHistoryDocument doc) async {
    if (ref.read(selectedCompanyProvider) == null) return;
    await _ensureItemsLoaded(doc);
    final a = _invoiceArgs(doc);
    final discountLines = await _discountLinesFor(doc);
    await InvoicePdfService.printDocument(
      company: a['company'],
      invoiceNumber: a['invoiceNumber'],
      date: a['date'],
      customerName: a['customerName'],
      isPaid: a['isPaid'],
      items: a['items'],
      total: a['total'],
      totalBeforeTax: a['totalBeforeTax'],
      taxTotal: a['taxTotal'],
      discount: a['discount'],
      paymentSummary: a['paymentSummary'],
      currencySymbol: a['currencySymbol'],
      discountLines: discountLines,
      logoBytes: a['logoBytes'],
      settings: ref.read(appSettingsProvider),
    );
  }

  Future<void> _saveInvoicePdf(SalesHistoryDocument doc) async {
    if (ref.read(selectedCompanyProvider) == null) return;
    await _ensureItemsLoaded(doc);
    final a = _invoiceArgs(doc);
    final discountLines = await _discountLinesFor(doc);
    await InvoicePdfService.saveAsPdf(
      company: a['company'],
      invoiceNumber: a['invoiceNumber'],
      date: a['date'],
      customerName: a['customerName'],
      isPaid: a['isPaid'],
      items: a['items'],
      total: a['total'],
      totalBeforeTax: a['totalBeforeTax'],
      taxTotal: a['taxTotal'],
      discount: a['discount'],
      paymentSummary: a['paymentSummary'],
      currencySymbol: a['currencySymbol'],
      discountLines: discountLines,
      logoBytes: a['logoBytes'],
      settings: ref.read(appSettingsProvider),
    );
  }

  Future<void> _reprintReceipt(SalesHistoryDocument doc) async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;

    // Ensure items are loaded for the selected document
    if (_items.isEmpty && !_itemsLoading) {
      await _fetchItems(doc);
    }
    final items = _items;

    // Convert DocumentItems → CartItems
    final cartItems = <CartItem>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      cartItems.add(
        CartItem(
          cartItemId: '${item.productId}_$i',
          posOrderId: 0,
          productId: item.productId,
          productName: item.productName ?? '-',
          quantity: item.quantity,
          price: item.price,
          discount: item.discount,
          discountType: item.discountType,
          promotionalDiscount: 0,
          appliedTaxes: [],
          measurementUnit: item.measurementUnit,
          isService: false,
        ),
      );
    }

    // Decode logo
    Uint8List? logoBytes;
    final logoBase64 = company.logo;
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        logoBytes = base64Decode(logoBase64);
      } catch (_) {}
    }

    // Parse stockDate for printTime
    DateTime printTime;
    try {
      printTime = DateTime.parse(doc.stockDate);
    } catch (_) {
      printTime = DateTime.now();
    }

    // Item-level discount total. An item's `discount` is always stored as an
    // absolute currency amount (the entry dialog converts a % to money before
    // saving), so sum it directly — interpreting it as a % (the old type==0
    // branch) under-counted any percentage-entered discount.
    final totalDiscount = items.fold<double>(
      0,
      (sum, item) => sum + item.discount * item.quantity,
    );

    final sym = ref.read(currencySymbolProvider);
    final discountLines = await _discountLinesFor(doc, includeLoyalty: false);

    await ReceiptPrinterService().printCartReceipt(
      company: company,
      cashier: ref.read(currentUserProvider),
      orderNumber: doc.number,
      printTime: printTime,
      items: cartItems,
      subtotal: doc.totalBeforeTax,
      totalDiscount: totalDiscount,
      discountLines: discountLines,
      totalTax: doc.taxTotal,
      grandTotal: doc.total,
      currencySymbol: sym,
      paymentTypeName: doc.paymentSummary,
      amountPaid: doc.total,
      logoBytes: logoBytes,
      roleSettings: ref.read(appSettingsProvider),
    );
  }

  Future<void> _showCustomerPicker() async {
    final selected = await showDialog<_CustomerPickerResult>(
      context: context,
      builder: (_) => _CustomerPickerDialog(current: _filterCustomer),
    );
    if (selected == null) return; // dialog dismissed
    setState(() => _filterCustomer = selected.customer);
    _fetchDocuments();
  }

  void _notImplemented(String action) {
    showAppSnackbar(context, ref, '$action — coming soon');
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sym = ref.watch(currencySymbolProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          PosTopBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Sales history',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildToolbar(theme, cs),
          Expanded(child: _buildBody(theme, cs, sym)),
          _buildFooter(theme, cs, sym),
        ],
      ),
    );
  }

  // ── toolbar ───────────────────────────────────────────────────────────────

  Widget _buildToolbar(ThemeData theme, ColorScheme cs) {
    final sel = _selectedDocLocalId != null && _documents.isNotEmpty
        ? _documents.where((d) => d.localId == _selectedDocLocalId).firstOrNull
        : null;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Doc number search
          SizedBox(
            width: 160,
            child: TextField(
              controller: _docNumCtrl,
              decoration: InputDecoration(
                hintText: 'Document nu...',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 16),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              style: TextStyle(fontSize: 13, color: cs.onSurface),
              onSubmitted: (_) => _fetchDocuments(),
            ),
          ),
          const Gap(8),

          // Date range
          InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 15,
                    color: cs.primary,
                  ),
                  const Gap(6),
                  Text(
                    '${_dateFmt.format(_startDate)} – ${_dateFmt.format(_endDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(6),

          const VerticalDivider(width: 1),
          const Gap(2),

          _toolBtn(
            _showAllUsers ? Icons.group : Icons.person_outline,
            _showAllUsers ? 'All users' : 'My sales',
            () {
              setState(() => _showAllUsers = !_showAllUsers);
              _fetchDocuments();
            },
            active: !_showAllUsers,
          ),
          _toolBtn(
            Icons.person,
            _filterCustomer != null ? _filterCustomer!.name : 'Customer',
            () => _showCustomerPicker(),
            active: _filterCustomer != null,
          ),

          const VerticalDivider(width: 1),
          const Gap(2),

          _toolBtn(
            Icons.print_outlined,
            'Print',
            sel == null ? null : () => _printInvoice(sel),
          ),
          _toolBtn(
            Icons.picture_as_pdf_outlined,
            'Save as PDF',
            sel == null ? null : () => _saveInvoicePdf(sel),
          ),
          _toolBtn(
            Icons.receipt_outlined,
            'Receipt',
            sel == null
                ? null
                : () => ref
                      .read(securityGuardProvider)
                      .guard(
                        context,
                        SecurityKeys.reprintReceipt,
                        () => _reprintReceipt(sel),
                      ),
          ),
          _toolBtn(
            Icons.mail_outline,
            'Send email',
            sel == null ? null : () => _notImplemented('Send email'),
          ),

          const VerticalDivider(width: 1),
          const Gap(2),

          _toolBtn(
            Icons.undo_outlined,
            'Refund',
            sel == null
                ? null
                : () => ref
                      .read(securityGuardProvider)
                      .guard(
                        context,
                        SecurityKeys.refund,
                        () => showDialog(
                          context: context,
                          builder: (_) =>
                              RefundDialog(initialDocumentNumber: sel.number),
                        ),
                      ),
          ),
          _toolBtn(
            Icons.delete_outline,
            'Delete',
            sel == null
                ? null
                : () => ref
                      .read(securityGuardProvider)
                      .guard(
                        context,
                        SecurityKeys.invoicesDelete,
                        () => _deleteDocument(sel),
                      ),
            color: Colors.redAccent,
          ),

          // Right-aligned utilities: Documents column picker + refresh.
          const Spacer(),
          _toolBtn(
            Icons.view_column_outlined,
            'Columns',
            () => _pickColumns(
              title: 'Documents columns',
              columns: _masterColumns
                  .map((c) => (id: c.id, label: c.label))
                  .toList(),
              visible: _visibleMasterColIds,
              prefsKey: _prefsMasterColsKey,
              onApply: (s) => setState(() => _visibleMasterColIds = s),
            ),
          ),
          _toolBtn(Icons.sync, 'Refresh', () => _fetchDocuments()),
        ],
      ),
    );
  }

  // ── column selector ─────────────────────────────────────────────────────────

  /// Shared picker for either table. Persists the chosen set to SharedPreferences
  /// and pushes it back into state via [onApply].
  Future<void> _pickColumns({
    required String title,
    required List<({String id, String label})> columns,
    required Set<String> visible,
    required String prefsKey,
    required ValueChanged<Set<String>> onApply,
  }) async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _ColumnSelectorDialog(
        title: title,
        columns: columns,
        visible: visible,
      ),
    );
    if (result != null && result.isNotEmpty) {
      _saveCols(prefsKey, result);
      onApply(result);
    }
  }

  Widget _toolBtn(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool active = false,
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final col = onTap == null
        ? cs.onSurface.withValues(alpha: 0.28)
        : (active ? cs.primary : (color ?? cs.onSurface));

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: col),
              const Gap(2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: col,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDateRange() async {
    final range = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) =>
          _DateRangePickerDialog(startDate: _startDate, endDate: _endDate),
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
      _fetchDocuments();
    }
  }

  // ── body (split pane) ─────────────────────────────────────────────────────

  Widget _buildBody(ThemeData theme, ColorScheme cs, String sym) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const Gap(12),
            Text(_error!, style: TextStyle(color: cs.error)),
            const Gap(16),
            FilledButton.icon(
              onPressed: _fetchDocuments,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalH = constraints.maxHeight;
        final masterH = (totalH * _splitFraction).clamp(120.0, totalH - 120.0);
        const dividerH = 12.0;
        const headerH = 28.0;
        final detailH = totalH - masterH - dividerH - (headerH * 2);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(theme, cs, 'Documents'),
            SizedBox(
              height: masterH - headerH,
              child: _buildMasterTable(theme, cs, sym),
            ),

            // Draggable divider
            GestureDetector(
              onVerticalDragUpdate: (d) => setState(() {
                _splitFraction = (_splitFraction + d.delta.dy / totalH).clamp(
                  0.25,
                  0.75,
                );
              }),
              child: Container(
                height: dividerH,
                color: cs.surfaceContainerHighest,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

            _sectionHeader(
              theme,
              cs,
              'Document items',
              trailing: _columnsHeaderButton(
                cs,
                () => _pickColumns(
                  title: 'Document items columns',
                  columns: _detailColumns
                      .map((c) => (id: c.id, label: c.label))
                      .toList(),
                  visible: _visibleDetailColIds,
                  prefsKey: _prefsDetailColsKey,
                  onApply: (s) => setState(() => _visibleDetailColIds = s),
                ),
              ),
            ),
            SizedBox(height: detailH, child: _buildDetailTable(theme, cs, sym)),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(
    ThemeData theme,
    ColorScheme cs,
    String title, {
    Widget? trailing,
  }) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.65),
              letterSpacing: 0.4,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// Compact "Columns" affordance used inside a section header.
  Widget _columnsHeaderButton(ColorScheme cs, VoidCallback onTap) {
    return Tooltip(
      message: 'Choose columns',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.view_column_outlined,
                size: 14,
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
              const Gap(4),
              Text(
                'Columns',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── master table ──────────────────────────────────────────────────────────

  // Master-table column metadata (stable id + display label + layout). The
  // "Columns" picker toggles these on/off; the cell builders in
  // [_buildMasterTable] are keyed by the same ids so header and body stay in
  // lock-step regardless of which columns are hidden.
  static const _masterColumns =
      <({String id, String label, double flex, bool numeric})>[
        (id: 'id', label: 'ID', flex: 0.4, numeric: true),
        (id: 'type', label: 'Document type', flex: 0.8, numeric: false),
        (id: 'user', label: 'User', flex: 0.7, numeric: false),
        (id: 'number', label: 'Number', flex: 1.2, numeric: false),
        (id: 'external', label: 'External ref', flex: 0.7, numeric: false),
        (id: 'customer', label: 'Customer', flex: 1.1, numeric: false),
        (id: 'date', label: 'Date', flex: 1.0, numeric: false),
        (id: 'created', label: 'Created', flex: 1.3, numeric: false),
        (id: 'pos', label: 'POS', flex: 0.9, numeric: false),
        (id: 'order', label: 'Order #', flex: 0.9, numeric: false),
        (id: 'payment', label: 'Payment', flex: 0.9, numeric: false),
        (id: 'discount', label: 'Discount', flex: 0.5, numeric: true),
        (
          id: 'totalBefore',
          label: 'Total before tax',
          flex: 0.7,
          numeric: true,
        ),
        (id: 'tax', label: 'Tax', flex: 0.5, numeric: true),
        (id: 'total', label: 'Total', flex: 0.7, numeric: true),
      ];

  Widget _buildMasterTable(ThemeData theme, ColorScheme cs, String sym) {
    const ts = TextStyle(fontSize: 12);
    final dimTs = TextStyle(
      fontSize: 12,
      color: cs.onSurface.withValues(alpha: 0.45),
    );

    // Per-column cell builders, keyed to the metadata ids above.
    final cellBuilders = <String, Widget Function(SalesHistoryDocument)>{
      'id': (doc) => Text('${doc.id}', style: dimTs),
      'type': (doc) => const Text('Sales', style: ts),
      'user': (doc) => Text(doc.userName ?? '-', style: ts),
      'number': (doc) => Text(
        doc.number,
        style: ts.copyWith(fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
      'external': (doc) => Text(doc.referenceDocumentNumber ?? '-', style: ts),
      'customer': (doc) => Text(
        doc.customerName ?? 'Unknown',
        style: ts,
        overflow: TextOverflow.ellipsis,
      ),
      'date': (doc) => Text(_fmt(doc.date), style: ts),
      'created': (doc) => Text(_fmt(doc.stockDate), style: ts),
      'pos': (doc) => Text(
        doc.warehouseName ?? 'N/A',
        style: ts,
        overflow: TextOverflow.ellipsis,
      ),
      'order': (doc) => Text(
        doc.orderNumber ?? 'N/A',
        style: ts,
        overflow: TextOverflow.ellipsis,
      ),
      'payment': (doc) => Text(
        doc.paymentSummary ?? 'N/A',
        style: ts,
        overflow: TextOverflow.ellipsis,
      ),
      'discount': (doc) => Text(
        doc.discount <= 0
            ? '-'
            : (doc.discountType == 1
                  ? '-${_numFmt.format(doc.discount)}'
                  : '${doc.discount.toStringAsFixed(0)}%'),
        style: ts,
      ),
      'totalBefore': (doc) =>
          Text(_numFmt.format(doc.totalBeforeTax), style: ts),
      'tax': (doc) => Text(_numFmt.format(doc.taxTotal), style: ts),
      'total': (doc) => Text(
        '${_numFmt.format(doc.total)} $sym',
        style: ts.copyWith(fontWeight: FontWeight.w900, color: cs.primary),
      ),
    };

    final visibleCols = _masterColumns
        .where((c) => _visibleMasterColIds.contains(c.id))
        .toList();
    final columns = visibleCols
        .map((c) => _ColDef(c.label, flex: c.flex, numeric: c.numeric))
        .toList();

    return _FlexTable(
      columns: columns,
      rowCount: _documents.length,
      rowBuilder: (i) {
        final doc = _documents[i];
        return visibleCols.map((c) => cellBuilders[c.id]!(doc)).toList();
      },
      isRowSelected: (i) => _documents[i].localId == _selectedDocLocalId,
      onRowTap: (i) {
        final doc = _documents[i];
        setState(() {
          _selectedDocLocalId = doc.localId;
          _items = [];
        });
        _fetchItems(doc);
      },
      emptyWidget: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: cs.onSurface.withValues(alpha: 0.18),
            ),
            const Gap(12),
            Text(
              'No sales documents for the selected period.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── detail table ──────────────────────────────────────────────────────────

  // Document-items column metadata — same id-keyed pattern as the master table
  // so the "Columns" picker can hide any of them.
  static const _detailColumns =
      <({String id, String label, double flex, bool numeric})>[
        (id: 'id', label: 'ID', flex: 0.35, numeric: true),
        (id: 'code', label: 'Code', flex: 0.7, numeric: false),
        (id: 'name', label: 'Name', flex: 1.6, numeric: false),
        (id: 'unit', label: 'Unit of measure', flex: 0.8, numeric: false),
        (id: 'qty', label: 'Quantity', flex: 0.7, numeric: true),
        (
          id: 'priceBeforeTax',
          label: 'Price before tax',
          flex: 0.9,
          numeric: true,
        ),
        (id: 'tax', label: 'Tax', flex: 0.45, numeric: true),
        (id: 'price', label: 'Price', flex: 0.7, numeric: true),
        (
          id: 'totalBeforeDiscount',
          label: 'Total bef. discount',
          flex: 1.0,
          numeric: true,
        ),
        (id: 'discount', label: 'Discount', flex: 0.55, numeric: true),
        (id: 'total', label: 'Total', flex: 0.7, numeric: true),
      ];

  Widget _buildDetailTable(ThemeData theme, ColorScheme cs, String sym) {
    if (_selectedDocLocalId == null) {
      return Center(
        child: Text(
          'Select a document above to view its items.',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.38),
            fontSize: 13,
          ),
        ),
      );
    }
    if (_itemsLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    const ts = TextStyle(fontSize: 12);
    final dimTs = TextStyle(
      fontSize: 12,
      color: cs.onSurface.withValues(alpha: 0.45),
    );

    // Per-column cell builders, keyed to [_detailColumns]. taxPct and the
    // pre-discount total are derived per item inside their builders.
    final cellBuilders = <String, Widget Function(DocumentItem)>{
      'id': (item) => Text('${item.id}', style: dimTs),
      'code': (item) => Text(item.productCode ?? '-', style: ts),
      'name': (item) => Text(
        item.productName ?? '-',
        style: ts,
        overflow: TextOverflow.ellipsis,
      ),
      'unit': (item) => Text(item.measurementUnit ?? '-', style: ts),
      'qty': (item) => Text(_numFmt.format(item.quantity), style: ts),
      'priceBeforeTax': (item) =>
          Text(_numFmt.format(item.priceBeforeTax), style: ts),
      'tax': (item) {
        final taxPct = item.priceBeforeTax > 0
            ? ((item.price - item.priceBeforeTax) / item.priceBeforeTax * 100)
            : 0.0;
        return Text('${taxPct.toStringAsFixed(0)}%', style: ts);
      },
      'price': (item) => Text(_numFmt.format(item.price), style: ts),
      'totalBeforeDiscount': (item) =>
          Text(_numFmt.format(item.price * item.quantity), style: ts),
      // Item discounts are always stored as an absolute currency amount (the
      // entry dialog converts a % to money before saving), so show the money
      // taken off — never a '%', which would misrepresent a fixed -5.
      'discount': (item) => Text(
        item.discount > 0
            ? '-${_numFmt.format(item.discount * item.quantity)}'
            : '-',
        style: ts,
      ),
      'total': (item) => Text(
        _numFmt.format(item.total),
        style: ts.copyWith(fontWeight: FontWeight.w700, color: cs.primary),
      ),
    };

    final visibleCols = _detailColumns
        .where((c) => _visibleDetailColIds.contains(c.id))
        .toList();
    final columns = visibleCols
        .map((c) => _ColDef(c.label, flex: c.flex, numeric: c.numeric))
        .toList();
    return _FlexTable(
      columns: columns,
      rowCount: _items.length,
      rowBuilder: (i) {
        final item = _items[i];
        return visibleCols.map((c) => cellBuilders[c.id]!(item)).toList();
      },
      emptyWidget: Center(
        child: Text(
          'No items found for this document.',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.38),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ── footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter(ThemeData theme, ColorScheme cs, String sym) {
    final totalAmount = _documents.fold<double>(0, (sum, d) => sum + d.total);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            'Documents count: ${_documents.length}',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const Gap(24),
          Text(
            'Total amount: ${_numFmt.format(totalAmount)} $sym',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Column selector dialog ──────────────────────────────────────────────────
// Lets the user pick which Documents-table columns are shown. Toggles a local
// working set and returns it on "Apply"; the last remaining column can't be
// unchecked so the table is never left with zero columns.
class _ColumnSelectorDialog extends StatefulWidget {
  final String title;
  final List<({String id, String label})> columns;
  final Set<String> visible;
  const _ColumnSelectorDialog({
    required this.title,
    required this.columns,
    required this.visible,
  });

  @override
  State<_ColumnSelectorDialog> createState() => _ColumnSelectorDialogState();
}

class _ColumnSelectorDialogState extends State<_ColumnSelectorDialog> {
  late final Set<String> _sel = {...widget.visible};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 320,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.view_column_outlined, size: 18, color: cs.primary),
                  const Gap(8),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Column checklist
            Expanded(
              child: ListView(
                children: widget.columns.map((c) {
                  final checked = _sel.contains(c.id);
                  // Forbid clearing the final column.
                  final lockLast = checked && _sel.length == 1;
                  return CheckboxListTile(
                    dense: true,
                    value: checked,
                    title: Text(c.label, style: const TextStyle(fontSize: 13)),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: lockLast
                        ? null
                        : (v) => setState(() {
                            if (v == true) {
                              _sel.add(c.id);
                            } else {
                              _sel.remove(c.id);
                            }
                          }),
                  );
                }).toList(),
              ),
            ),

            Divider(height: 1, color: theme.dividerColor),

            // Footer actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(
                      () => _sel
                        ..clear()
                        ..addAll(widget.columns.map((c) => c.id)),
                    ),
                    child: const Text('Select all'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _sel),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Customer picker helpers ────────────────────────────────────────────────────

/// Wraps the selected customer (null = "All customers" / clear filter).
class _CustomerPickerResult {
  final Customer? customer;
  const _CustomerPickerResult(this.customer);
}

class _CustomerPickerDialog extends ConsumerStatefulWidget {
  final Customer? current;
  const _CustomerPickerDialog({this.current});

  @override
  ConsumerState<_CustomerPickerDialog> createState() =>
      _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends ConsumerState<_CustomerPickerDialog> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final customersAsync = ref.watch(allCustomersProvider);

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 360,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_search_outlined,
                    size: 18,
                    color: cs.primary,
                  ),
                  const Gap(8),
                  Text(
                    'Filter by customer',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search customer...',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 16),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                style: TextStyle(fontSize: 13, color: cs.onSurface),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),

            // "All customers" clear row
            if (widget.current != null)
              InkWell(
                onTap: () =>
                    Navigator.pop(context, const _CustomerPickerResult(null)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.clear,
                        size: 16,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                      const Gap(10),
                      Text(
                        'All customers',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Divider(height: 1, color: theme.dividerColor),

            // Customer list
            Expanded(
              child: customersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Failed to load customers',
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ),
                data: (customers) {
                  final filtered = _query.isEmpty
                      ? customers
                      : customers
                            .where(
                              (c) =>
                                  c.name.toLowerCase().contains(_query) ||
                                  (c.code?.toLowerCase().contains(_query) ??
                                      false),
                            )
                            .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No customers found',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.45),
                          fontSize: 13,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 0.5,
                      color: theme.dividerColor.withValues(alpha: 0.4),
                    ),
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      final isActive = c.id == widget.current?.id;
                      return InkWell(
                        onTap: () =>
                            Navigator.pop(context, _CustomerPickerResult(c)),
                        child: Container(
                          color: isActive
                              ? cs.primary.withValues(alpha: 0.1)
                              : null,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 16,
                                color: isActive
                                    ? cs.primary
                                    : cs.onSurface.withValues(alpha: 0.45),
                              ),
                              const Gap(10),
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isActive ? cs.primary : cs.onSurface,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (c.code != null)
                                Text(
                                  c.code!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              if (isActive) ...[
                                const Gap(6),
                                Icon(Icons.check, size: 16, color: cs.primary),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date range picker dialog ───────────────────────────────────────────────────

class _DatePreset {
  final String label;
  final DateTime start;
  final DateTime end;
  const _DatePreset(this.label, this.start, this.end);
}

class _DateRangePickerDialog extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  const _DateRangePickerDialog({
    required this.startDate,
    required this.endDate,
  });

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  late DateTime _start;
  late DateTime? _end;
  late DateTime _viewMonth;
  bool _pickingEnd = false;

  static const _dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  static DateTime _d(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  static DateTime _today() => _d(DateTime.now());

  static DateTime _weekStart(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));
  static DateTime _weekEnd(DateTime d) => d.add(Duration(days: 7 - d.weekday));

  @override
  void initState() {
    super.initState();
    _start = _d(widget.startDate);
    _end = _d(widget.endDate);
    _viewMonth = DateTime(_start.year, _start.month);
  }

  List<_DatePreset> _presets() {
    final now = _today();
    final wS = _weekStart(now);
    final lwS = _weekStart(now.subtract(const Duration(days: 7)));
    return [
      _DatePreset('Today', now, now),
      _DatePreset(
        'Yesterday',
        now.subtract(const Duration(days: 1)),
        now.subtract(const Duration(days: 1)),
      ),
      _DatePreset('This week', wS, _weekEnd(now)),
      _DatePreset('Last week', lwS, _weekEnd(lwS)),
      _DatePreset(
        'This month',
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 0),
      ),
      _DatePreset(
        'Last month',
        DateTime(now.year, now.month - 1, 1),
        DateTime(now.year, now.month, 0),
      ),
      _DatePreset(
        'This year',
        DateTime(now.year, 1, 1),
        DateTime(now.year, 12, 31),
      ),
      _DatePreset(
        'Last year',
        DateTime(now.year - 1, 1, 1),
        DateTime(now.year - 1, 12, 31),
      ),
    ];
  }

  void _applyPreset(_DatePreset p) => setState(() {
    _start = p.start;
    _end = p.end;
    _pickingEnd = false;
    _viewMonth = DateTime(p.start.year, p.start.month);
  });

  void _onDayTap(DateTime day) => setState(() {
    if (!_pickingEnd || _end != null) {
      _start = day;
      _end = null;
      _pickingEnd = true;
    } else {
      if (day.isBefore(_start)) {
        _start = day;
        _end = null;
      } else {
        _end = day;
        _pickingEnd = false;
      }
    }
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final presets = _presets();
    final fmt = DateFormat('dd/MM/yyyy');
    final endForOk = _end ?? _start;

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Main row ────────────────────────────────────────────────────
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left – predefined periods
                  SizedBox(
                    width: 238,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Predefined period',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate((presets.length / 2).ceil(), (row) {
                            final a = presets[row * 2];
                            final b = row * 2 + 1 < presets.length
                                ? presets[row * 2 + 1]
                                : null;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(child: _presetBtn(cs, a)),
                                  if (b != null) ...[
                                    const SizedBox(width: 6),
                                    Expanded(child: _presetBtn(cs, b)),
                                  ] else
                                    const Expanded(child: SizedBox()),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  VerticalDivider(
                    width: 1,
                    color: theme.dividerColor,
                    thickness: 0.5,
                  ),

                  // Right – calendar
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Month navigation
                          Row(
                            children: [
                              _navBtn(
                                Icons.chevron_left,
                                () => setState(() {
                                  _viewMonth = DateTime(
                                    _viewMonth.year,
                                    _viewMonth.month - 1,
                                  );
                                }),
                              ),
                              Expanded(
                                child: Text(
                                  DateFormat('MMMM yyyy').format(_viewMonth),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              _navBtn(
                                Icons.chevron_right,
                                () => setState(() {
                                  _viewMonth = DateTime(
                                    _viewMonth.year,
                                    _viewMonth.month + 1,
                                  );
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Day-name row
                          Row(
                            children: _dayLabels
                                .map(
                                  (d) => Expanded(
                                    child: Center(
                                      child: Text(
                                        d,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface.withValues(
                                            alpha: 0.45,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 4),

                          // Day grid
                          _buildGrid(cs),
                          const SizedBox(height: 10),

                          // Selected range display
                          Center(
                            child: Text(
                              _end != null
                                  ? '${fmt.format(_start)}  →  ${fmt.format(_end!)}'
                                  : _pickingEnd
                                  ? 'Now select an end date'
                                  : fmt.format(_start),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _end != null || !_pickingEnd
                                    ? cs.onSurface
                                    : cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────────
            Divider(height: 1, color: theme.dividerColor, thickness: 0.5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      DateTimeRange(start: _start, end: endForOk),
                    ),
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('OK'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetBtn(ColorScheme cs, _DatePreset p) {
    final isActive = _start == p.start && _end == p.end;
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: () => _applyPreset(p),
        style: OutlinedButton.styleFrom(
          foregroundColor: isActive ? cs.onPrimary : cs.onSurface,
          backgroundColor: isActive ? cs.primary : null,
          side: BorderSide(
            color: isActive ? cs.primary : cs.outlineVariant,
            width: 0.8,
          ),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          p.label,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(icon, size: 18),
    ),
  );

  Widget _buildGrid(ColorScheme cs) {
    final now = _today();
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final lastDay = DateTime(_viewMonth.year, _viewMonth.month + 1, 0);
    final startOff = firstDay.weekday - 1;
    final totalCells = startOff + lastDay.day;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(
        rows,
        (r) => Row(
          children: List.generate(7, (c) {
            final idx = r * 7 + c;
            final dayNum = idx - startOff + 1;
            if (dayNum < 1 || dayNum > lastDay.day) {
              return const Expanded(child: SizedBox(height: 32));
            }
            final date = DateTime(_viewMonth.year, _viewMonth.month, dayNum);
            return Expanded(child: _buildDay(cs, date, now));
          }),
        ),
      ),
    );
  }

  Widget _buildDay(ColorScheme cs, DateTime date, DateTime now) {
    final isStart = date == _start;
    final isEnd = _end != null && date == _end;
    final inRange =
        _end != null && date.isAfter(_start) && date.isBefore(_end!);
    final isToday = date == now;
    final isSel = isStart || isEnd;

    // Range band decoration (fills between start and end)
    BoxDecoration rangeDeco = const BoxDecoration();
    if (inRange) {
      rangeDeco = BoxDecoration(color: cs.primary.withValues(alpha: 0.15));
    } else if (_end != null && (isStart || isEnd)) {
      rangeDeco = BoxDecoration(
        color: cs.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.horizontal(
          left: isStart ? const Radius.circular(16) : Radius.zero,
          right: isEnd ? const Radius.circular(16) : Radius.zero,
        ),
      );
    }

    return GestureDetector(
      onTap: () => _onDayTap(date),
      child: Container(
        height: 32,
        decoration: rangeDeco,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSel ? cs.primary : null,
              border: isToday && !isSel
                  ? Border.all(color: cs.primary, width: 1.2)
                  : null,
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.bold : null,
                  color: isSel
                      ? cs.onPrimary
                      : isToday
                      ? cs.primary
                      : cs.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
