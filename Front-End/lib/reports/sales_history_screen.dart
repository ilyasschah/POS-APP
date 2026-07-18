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
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/core/app_date_picker.dart';
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
  final int discountType;
  final int paidStatus;
  final String? paymentSummary;
  final int? customerId;

  SalesHistoryDocument({
    required this.id,
    this.localId,
    required this.number,
    this.userName,
    this.customerName,
    this.customerId,
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
      customerId: j['customerId'],
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
                      fontSize: 14, // Increased size for touch targets
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.65),
                      letterSpacing: 0.4,
                    ),
                    textAlign: c.numeric ? TextAlign.right : TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                )
                .toList(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            horizontal: 16,
                            vertical: 14, // Fatter rows for easier tapping
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
      final db = ref.read(appDatabaseProvider);
      final user = ref.read(currentUserProvider);

      final userRows = await db.select(db.usersTable).get();
      final customerRows = await db.select(db.customersTable).get();
      final warehouseRows = await db.select(db.warehousesTable).get();
      final payTypeRows = await db.select(db.paymentTypesTable).get();
      final userMap = {for (final u in userRows) u.id: u.name};
      final customerMap = {for (final c in customerRows) c.id: c.name};
      final warehouseMap = {for (final w in warehouseRows) w.id: w.name};
      final payTypeMap = {for (final p in payTypeRows) p.id: p.name};

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
            customerId: row.customerId,
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
      final db = ref.read(appDatabaseProvider);
      final rows = await db.getActiveDocumentItems(localId);
      final productRows = await db.select(db.productsTable).get();
      final pById = {for (final p in productRows) p.id: p};
      final docRow = await db.getDocumentByLocalId(localId);
      final isCheckoutDoc =
          docRow?.orderNumber != null && docRow!.orderNumber!.isNotEmpty;
      setState(() {
        _items = rows
            .map(
              (r) => DocumentItem.fromDrift(
                r,
                isCheckoutDoc: isCheckoutDoc,
                companyId: ref.read(selectedCompanyProvider)?.id ?? 0,
                documentId: doc.id,
                product: pById[r.productId],
              ),
            )
            .toList();
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
        title: const Text('Delete Document', style: TextStyle(fontSize: 20)),
        content: Text(
          "Delete '${doc.number}'? This cannot be undone.",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.dangerColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
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

  Future<double> _amountPaidFor(SalesHistoryDocument doc) async {
    final localId = doc.localId;
    if (localId == null) return doc.paidStatus == 0 ? 0.0 : doc.total;
    final db = ref.read(appDatabaseProvider);
    final payments = (await db.getPayments(
      localId,
    )).where((p) => p.syncStatus != 'pending_delete').toList();
    if (payments.isEmpty) return doc.paidStatus == 0 ? 0.0 : doc.total;
    return payments.fold<double>(0.0, (s, p) => s + p.amount);
  }

  Future<void> _printInvoice(SalesHistoryDocument doc) async {
    if (ref.read(selectedCompanyProvider) == null) return;
    await _ensureItemsLoaded(doc);
    final a = _invoiceArgs(doc);
    final discountLines = await _discountLinesFor(doc);
    final amountPaid = await _amountPaidFor(doc);
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
      amountPaid: amountPaid,
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
    final amountPaid = await _amountPaidFor(doc);
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
      amountPaid: amountPaid,
      discountLines: discountLines,
      logoBytes: a['logoBytes'],
      settings: ref.read(appSettingsProvider),
    );
  }

  Future<void> _reprintReceipt(SalesHistoryDocument doc) async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;

    if (_items.isEmpty && !_itemsLoading) {
      await _fetchItems(doc);
    }
    final items = _items;
    final db = ref.read(appDatabaseProvider);

    final taxRows = await db.select(db.taxesTable).get();
    final taxNameById = {for (final t in taxRows) t.id: t.name};

    final cartItems = <CartItem>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final unitTax = item.quantity > 0 ? item.taxAmount / item.quantity : 0.0;
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
          appliedTaxes: item.taxAmount > 0
              ? [
                  MenuTax(
                    id: item.taxId ?? 0,
                    name: taxNameById[item.taxId] ?? 'Tax',
                    rate: unitTax,
                    isFixed: true,
                    isTaxOnTotal: false,
                  ),
                ]
              : const [],
          measurementUnit: item.measurementUnit,
          isService: false,
        ),
      );
    }

    Uint8List? logoBytes;
    final logoBase64 = company.logo;
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        logoBytes = base64Decode(logoBase64);
      } catch (_) {}
    }

    DateTime printTime;
    try {
      printTime = DateTime.parse(doc.stockDate);
    } catch (_) {
      printTime = DateTime.now();
    }

    final totalDiscount = items.fold<double>(0, (sum, item) {
      final perUnit = item.discountType == 0
          ? item.priceBeforeTax * item.discount / 100
          : item.discount;
      return sum + perUnit * item.quantity;
    });

    final sym = ref.read(currencySymbolProvider);
    final discountLines = await _discountLinesFor(doc, includeLoyalty: false);

    Customer? customer;
    if (doc.customerId != null) {
      final cRow = await (db.select(
        db.customersTable,
      )..where((t) => t.id.equals(doc.customerId!))).getSingleOrNull();
      if (cRow != null) customer = Customer.fromDrift(cRow);
    }

    final amountPaid = await _amountPaidFor(doc);
    String? paymentTypeName = doc.paymentSummary;
    final localId = doc.localId;
    if (localId != null) {
      final payments = (await db.getPayments(
        localId,
      )).where((p) => p.syncStatus != 'pending_delete').toList();
      if (payments.isNotEmpty) {
        final payTypeRows = await db.select(db.paymentTypesTable).get();
        final payTypeMap = {for (final t in payTypeRows) t.id: t.name};
        final names = payments
            .map((p) => payTypeMap[p.paymentTypeId] ?? 'Payment')
            .toSet()
            .toList();
        if (names.isNotEmpty) paymentTypeName = names.join(' / ');
      }
    }

    await ReceiptPrinterService().printCartReceipt(
      company: company,
      cashier: ref.read(currentUserProvider),
      customer: customer,
      orderNumber: doc.number,
      documentNumber: doc.number,
      printTime: printTime,
      items: cartItems,
      subtotal: doc.totalBeforeTax,
      totalDiscount: totalDiscount,
      discountLines: discountLines,
      totalTax: doc.taxTotal,
      grandTotal: doc.total,
      currencySymbol: sym,
      paymentTypeName: paymentTypeName,
      amountPaid: amountPaid,
      logoBytes: logoBytes,
      roleSettings: ref.read(appSettingsProvider),
    );
  }

  Future<void> _showCustomerPicker() async {
    final selected = await showDialog<_CustomerPickerResult>(
      context: context,
      builder: (_) => _CustomerPickerDialog(current: _filterCustomer),
    );
    if (selected == null) return;
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
              icon: const Icon(
                Icons.arrow_back,
                size: 28,
              ), // Larger icon for touch
              tooltip: 'Back',
              onPressed: () => Navigator.pop(context),
            ),
            // Header content: Replaced generic Text title with a comprehensive Row
            title: Row(
              children: [
                const Text(
                  'Sales history',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),

                // Date picker moved to the header
                InkWell(
                  onTap: _pickDateRange,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 20,
                          color: cs.primary,
                        ),
                        const Gap(8),
                        Text(
                          '${_dateFmt.format(_startDate)} – ${_dateFmt.format(_endDate)}',
                          style: TextStyle(
                            fontSize: 15, // Larger font
                            color: cs.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(16),

                // Search bar moved to the header and made wider for POS
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _docNumCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search document...',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 22),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14, // Fatter target
                      ),
                    ),
                    style: TextStyle(fontSize: 16, color: cs.onSurface),
                    onSubmitted: (_) => _fetchDocuments(),
                  ),
                ),
                const Gap(8),
              ],
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
      height: 80, // Increased height for POS touch buttons
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
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

          const Gap(12),
          const VerticalDivider(width: 1, indent: 16, endIndent: 16),
          const Gap(12),

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

          const Gap(12),
          const VerticalDivider(width: 1, indent: 16, endIndent: 16),
          const Gap(12),

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
            color: context.dangerColor,
          ),

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

  // Expanded ToolButton with touch-pad sizing
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: active
              ? BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: col), // Scaled up icon
              const Gap(6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14, // Scaled up text
                  color: col,
                  fontWeight: FontWeight.w600,
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
    final range = await showAppDateRangePicker(
      context,
      initialStart: _startDate,
      initialEnd: _endDate,
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
            Icon(Icons.error_outline, size: 56, color: cs.error),
            const Gap(16),
            Text(_error!, style: TextStyle(color: cs.error, fontSize: 16)),
            const Gap(24),
            FilledButton.icon(
              onPressed: _fetchDocuments,
              icon: const Icon(Icons.refresh, size: 24),
              label: const Text('Retry', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalH = constraints.maxHeight;
        final masterH = (totalH * _splitFraction).clamp(150.0, totalH - 150.0);
        const dividerH = 16.0; // Slightly thicker divider handle
        const headerH = 36.0;
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
                    width: 60,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
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
      height: 36, // Scaled up
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15, // Made larger
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _columnsHeaderButton(ColorScheme cs, VoidCallback onTap) {
    return Tooltip(
      message: 'Choose columns',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.view_column_outlined,
                size: 20, // Larger icon
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
              const Gap(6),
              Text(
                'Columns',
                style: TextStyle(
                  fontSize: 14, // Larger text
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── master table ──────────────────────────────────────────────────────────

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
    const ts = TextStyle(fontSize: 15); // Scaled up table row font
    final dimTs = TextStyle(
      fontSize: 15,
      color: cs.onSurface.withValues(alpha: 0.5),
    );

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
              size: 64,
              color: cs.onSurface.withValues(alpha: 0.18),
            ),
            const Gap(16),
            Text(
              'No sales documents for the selected period.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── detail table ──────────────────────────────────────────────────────────

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
            color: cs.onSurface.withValues(alpha: 0.45),
            fontSize: 16,
          ),
        ),
      );
    }
    if (_itemsLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }

    const ts = TextStyle(fontSize: 15); // Scaled up table font
    final dimTs = TextStyle(
      fontSize: 15,
      color: cs.onSurface.withValues(alpha: 0.45),
    );

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
      'tax': (item) => Text(
        item.taxRate > 0
            ? '${item.taxRate.toStringAsFixed(item.taxRate % 1 == 0 ? 0 : 1)}%'
            : '—',
        style: ts,
      ),
      'price': (item) => Text(_numFmt.format(item.price), style: ts),
      'totalBeforeDiscount': (item) =>
          Text(_numFmt.format(item.price * item.quantity), style: ts),
      'discount': (item) => Text(
        item.discount <= 0
            ? '-'
            : item.discountType == 0
            ? '-${item.discount.toStringAsFixed(item.discount % 1 == 0 ? 0 : 2)}%'
            : '-${_numFmt.format(item.discount * item.quantity)}',
        style: ts,
      ),
      'total': (item) => Text(
        _numFmt.format(item.totalWithTax),
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
            color: cs.onSurface.withValues(alpha: 0.45),
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // ── footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter(ThemeData theme, ColorScheme cs, String sym) {
    final totalAmount = _documents.fold<double>(0, (sum, d) => sum + d.total);

    return Container(
      height: 60, // Scaled up Footer
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            'Documents count: ${_documents.length}',
            style: TextStyle(
              fontSize: 16, // Larger font
              color: cs.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            'Total amount: ${_numFmt.format(totalAmount)} $sym',
            style: TextStyle(
              fontSize: 20, // Highlight the final total
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Column selector dialog ──────────────────────────────────────────────────
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 380, // Made wider for easier tapping
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.view_column_outlined, size: 24, color: cs.primary),
                  const Gap(12),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: widget.columns.map((c) {
                  final checked = _sel.contains(c.id);
                  final lockLast = checked && _sel.length == 1;
                  return CheckboxListTile(
                    dense: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    value: checked,
                    title: Text(
                      c.label,
                      style: const TextStyle(fontSize: 16),
                    ), // Bigger Font
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(
                      () => _sel
                        ..clear()
                        ..addAll(widget.columns.map((c) => c.id)),
                    ),
                    child: const Text(
                      'Select all',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _sel),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Apply', style: TextStyle(fontSize: 16)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 420,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_search_outlined,
                    size: 24,
                    color: cs.primary,
                  ),
                  const Gap(12),
                  Text(
                    'Filter by customer',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search customer...',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 22),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: TextStyle(fontSize: 16, color: cs.onSurface),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            if (widget.current != null)
              InkWell(
                onTap: () =>
                    Navigator.pop(context, const _CustomerPickerResult(null)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.clear,
                        size: 20,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                      const Gap(12),
                      Text(
                        'All customers',
                        style: TextStyle(
                          fontSize: 16,
                          color: cs.onSurface.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: customersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Failed to load customers',
                    style: TextStyle(color: cs.error, fontSize: 16),
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
                          fontSize: 16,
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
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 22,
                                color: isActive
                                    ? cs.primary
                                    : cs.onSurface.withValues(alpha: 0.45),
                              ),
                              const Gap(12),
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: TextStyle(
                                    fontSize: 16,
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
                                    fontSize: 14,
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              if (isActive) ...[
                                const Gap(8),
                                Icon(Icons.check, size: 22, color: cs.primary),
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
