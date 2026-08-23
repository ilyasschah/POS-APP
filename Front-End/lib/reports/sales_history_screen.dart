import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/uom/unit_of_measure.dart';
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
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/user_model.dart';
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

/// The terminal that rang a sale, read off the document number's own prefix
/// (`POS1-200-000026` → `POS1`).
///
/// It is deliberately **not** read from `deviceNameProvider`: that setting is
/// device-local and never synced, so using it would label every document
/// pulled from another terminal with *this* terminal's name.
///
/// Manual-editor documents are numbered by the server
/// (`/Document/GetNextNumber`, e.g. `26-100-000001`) and have no terminal at
/// all. They are told apart by [orderNumber] — the checkout-vs-manual
/// discriminator used throughout this codebase — and **not** by the number's
/// shape, which the two formats share.
String? posNameFromDocumentNumber(String number, String? orderNumber) {
  if (orderNumber == null || orderNumber.isEmpty) return null;
  final match = RegExp(r'^([A-Z0-9]{1,12})-\d+-\d+$').firstMatch(number);
  return match?.group(1);
}

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

/// Narrows the fetched rows by the search bar's free text.
///
/// Matches the number, the customer, the order number and the external
/// reference — the four things anyone types into this screen. Deliberately a
/// plain function rather than a method: it is the one piece of this screen
/// that decides whether a sale the operator KNOWS exists is visible, so it is
/// worth testing without standing up a database.
List<SalesHistoryDocument> salesHistorySearch(
  List<SalesHistoryDocument> documents,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return documents;

  bool has(String? value) => (value ?? '').toLowerCase().contains(q);
  return documents
      .where(
        (d) =>
            has(d.number) ||
            has(d.customerName) ||
            has(d.orderNumber) ||
            has(d.referenceDocumentNumber),
      )
      .toList();
}

/// Height of one pane's section header ("Documents" / "Document items").
const double kSalesHistorySectionHeaderHeight = 36.0;

/// Height of the draggable handle between the two panes.
const double kSalesHistoryDividerHeight = 16.0;

/// Splits the body between the master and detail panes.
///
/// 🚨 Every bound here is COMPUTED. The first version clamped to a hardcoded
/// `(150, totalHeight - 150)`, which on a short viewport — an on-screen
/// keyboard is the usual cause — asks for `clamp(150, 40)`. Dart throws
/// ArgumentError on a crossed range, once per frame, and the screen turns into
/// a red rectangle. A pane squeezed small is a bad layout; a pane that throws
/// is no screen at all.
///
/// Returns the two BODY heights, their section headers already deducted and
/// both guaranteed non-negative — a SizedBox cannot take a negative height
/// either.
({double master, double detail}) salesHistorySplit(
  double totalHeight,
  double fraction, {
  double headerHeight = kSalesHistorySectionHeaderHeight,
  double dividerHeight = kSalesHistoryDividerHeight,
}) {
  if (totalHeight <= 0 || !totalHeight.isFinite) {
    return (master: 0, detail: 0);
  }

  final minPane = math.min(150.0, totalHeight / 3);
  final maxMaster = math.max(minPane, totalHeight - minPane);
  final master = (totalHeight * fraction).clamp(minPane, maxMaster);

  // `master` is the pane INCLUDING its own section header, so only the detail
  // pane's header is deducted here. The original subtracted two and left a
  // 36px strip of nothing under the detail table on every screen.
  return (
    master: math.max(0.0, master - headerHeight),
    detail: math.max(0.0, totalHeight - master - dividerHeight - headerHeight),
  );
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

  /// Null = every user's sales. Otherwise the one user whose sales to show —
  /// "My sales" is simply this set to the signed-in user, so the quick preset
  /// and the per-user pick are the same filter rather than two ideas.
  int? _filterUserId;

  Customer? _filterCustomer;

  /// Free text in the search bar. Client-side and live, unlike the period /
  /// user / customer filters, which are worth a round trip to Drift.
  final _searchCtrl = TextEditingController();
  String _query = '';

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
    _visibleMasterColIds = _loadCols(_prefsMasterColsKey, _masterColumnIds);
    _visibleDetailColIds = _loadCols(_prefsDetailColsKey, _detailColumnIds);
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
    _searchCtrl.dispose();
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
        userId: _filterUserId,
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

      setState(() {
        _documents = docs;
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
        title: Text(
          AppLocalizations.of(context).deleteDocument,
          style: const TextStyle(fontSize: 20),
        ),
        content: Text(
          AppLocalizations.of(
            context,
          ).deleteDocumentConfirmPermanent(doc.number),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              AppLocalizations.of(context).actionCancel,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.dangerColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppLocalizations.of(context).actionDelete,
              style: const TextStyle(fontSize: 16),
            ),
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
      showAppSnackbar(
        context,
        ref,
        AppLocalizations.of(context).documentDeleted,
      );
      _fetchDocuments();
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final msg =
          (data is Map ? data['message'] : data?.toString()) ??
          AppLocalizations.of(context).deleteFailed;
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
          // A reprint REPLAYS banked figures, it does not re-price. The line
          // above rebuilds the tax as a fixed per-unit amount to be added to
          // `price`, so this must stay exclusive — inheriting the `true`
          // default would divide the tax back out of a price that never
          // contained it and under-report an already-closed sale.
          isTaxInclusive: false,
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

  /// What the table and the footer actually show: the fetched set narrowed by
  /// the free text. Everything else has already been applied by the query.
  List<SalesHistoryDocument> get _visibleDocuments =>
      salesHistorySearch(_documents, _query);

  /// Chips for the two filters that survive a fetch. The period keeps its own
  /// pill in the header — it is the one filter an operator changes constantly,
  /// and burying it in a menu would cost a click every time.
  List<SearchBarChip> _searchChips(List<User> users) {
    final l = AppLocalizations.of(context);
    return [
      if (_filterUserId != null)
        SearchBarChip(
          id: 'user',
          icon: Icons.badge_outlined,
          label: _userLabel(users, _filterUserId!) ?? l.userLabel,
          onRemove: () => _setUserFilter(null),
        ),
      if (_filterCustomer != null)
        SearchBarChip(
          id: 'customer',
          icon: Icons.person_outline,
          label: _filterCustomer!.name,
          onRemove: () => _setCustomerFilter(null),
        ),
    ];
  }

  String? _userLabel(List<User> users, int id) {
    for (final u in users) {
      final full = '${u.firstName ?? ''} ${u.lastName ?? ''}'.trim();
      if (u.id == id) return full.isNotEmpty ? full : (u.username ?? '#$id');
    }
    return null;
  }

  /// Both of these re-query Drift: user and customer are server-side filters,
  /// so a chip going on or off has to reload rather than hide rows.
  void _setUserFilter(int? userId) {
    setState(() => _filterUserId = userId);
    _fetchDocuments();
  }

  void _setCustomerFilter(Customer? customer) {
    setState(() => _filterCustomer = customer);
    _fetchDocuments();
  }

  /// The filter menu: who rang the sale up, and who it was for.
  List<FilterMenuSection> _filterSections(
    String query,
    List<User> users,
    List<Customer> customers,
  ) {
    final l = AppLocalizations.of(context);
    final lower = query.trim().toLowerCase();
    const maxPerSection = 8;
    final me = ref.read(currentUserProvider);

    (List<T>, bool) narrow<T>(List<T> all, String Function(T) label) {
      final matched = lower.isEmpty
          ? all
          : all.where((e) => label(e).toLowerCase().contains(lower)).toList();
      return (
        matched.take(maxPerSection).toList(),
        matched.length > maxPerSection,
      );
    }

    String nameOf(User u) {
      final full = '${u.firstName ?? ''} ${u.lastName ?? ''}'.trim();
      return full.isNotEmpty ? full : (u.username ?? '#${u.id}');
    }

    final (staff, staffTruncated) = narrow(users, nameOf);
    final (people, peopleTruncated) = narrow(customers, (c) => c.name);

    return [
      FilterMenuSection(
        title: l.userLabel,
        icon: Icons.badge_outlined,
        footnote: staffTruncated ? l.filterKeepTyping : null,
        options: [
          FilterMenuOption(
            label: l.allUsers,
            icon: Icons.group_outlined,
            selected: _filterUserId == null,
            onSelected: () => _setUserFilter(null),
          ),
          if (me != null)
            FilterMenuOption(
              label: l.mySales,
              icon: Icons.person_outline,
              selected: _filterUserId == me.id,
              onSelected: () => _setUserFilter(me.id),
            ),
          for (final u in staff)
            if (u.id != me?.id)
              FilterMenuOption(
                label: nameOf(u),
                icon: Icons.badge_outlined,
                selected: _filterUserId == u.id,
                onSelected: () =>
                    _setUserFilter(_filterUserId == u.id ? null : u.id),
              ),
        ],
      ),
      FilterMenuSection(
        title: l.customerLabel,
        icon: Icons.person_outline,
        footnote: peopleTruncated ? l.filterKeepTyping : null,
        options: [
          FilterMenuOption(
            label: l.allCustomers,
            icon: Icons.groups_outlined,
            selected: _filterCustomer == null,
            onSelected: () => _setCustomerFilter(null),
          ),
          for (final c in people)
            FilterMenuOption(
              label: c.name,
              icon: Icons.person_outline,
              selected: _filterCustomer?.id == c.id,
              onSelected: () =>
                  _setCustomerFilter(_filterCustomer?.id == c.id ? null : c),
            ),
          // The full picker stays reachable: a shop with thousands of accounts
          // cannot be served by eight quick picks.
          FilterMenuOption(
            label: l.selectCustomer,
            icon: Icons.manage_search,
            onSelected: _showCustomerPicker,
          ),
        ],
      ),
    ];
  }

  Future<void> _showCustomerPicker() async {
    final selected = await showDialog<_CustomerPickerResult>(
      context: context,
      builder: (_) => _CustomerPickerDialog(current: _filterCustomer),
    );
    if (selected == null) return;
    _setCustomerFilter(selected.customer);
  }

  void _notImplemented(String action) {
    showAppSnackbar(
      context,
      ref,
      AppLocalizations.of(context).featureComingSoon(action),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sym = ref.watch(currencySymbolProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // 🚨 The on-screen keyboard OVERLAYS this screen instead of resizing it.
      // Resizing left the split panes barely 150px tall, which both reflowed
      // two tables on every keystroke and drove the split maths into an
      // inverted clamp. The search bar lives in the top bar, so it stays above
      // the keyboard either way.
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          PosTopBar(
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                size: 28,
              ), // Larger icon for touch
              tooltip: AppLocalizations.of(context).back,
              onPressed: () => Navigator.pop(context),
            ),
            // Header: the title and the search bar. The search is what an
            // operator reaches for first, so it gets the most prominent slot
            // on the screen; the period moved down to the toolbar band, where
            // it sits beside the actions.
            //
            // `singleLine` matters here: PosTopBar is a fixed 62px and cannot
            // grow, so the chips share the row rather than wrapping under it.
            title: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                const titleWidth = 170.0;
                const barMin = 280.0;

                // The title is the first thing to go: it names a screen the
                // operator already navigated to, while the search box is the
                // one they came to use.
                final showTitle =
                    constraints.maxWidth >= titleWidth + barMin + gap;

                return Row(
                  children: [
                    if (showTitle) ...[
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context).salesHistoryTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Gap(gap),
                    ],
                    Expanded(child: _searchBar(singleLine: true)),
                    const Gap(8),
                  ],
                );
              },
            ),
          ),
          _buildToolbar(theme, cs),
          Expanded(child: _buildBody(theme, cs, sym)),
          _buildFooter(theme, cs, sym),
        ],
      ),
    );
  }

  /// A touch-sized header control: icon, and a label only when the header has
  /// the room for one.
  Widget _headerPill(
    ColorScheme cs, {
    required IconData icon,
    required VoidCallback onTap,
    String? label,
    String? tooltip,
  }) {
    final pill = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: label == null ? 12 : 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: cs.primary),
            if (label != null) ...[
              const Gap(8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip, child: pill);
  }

  /// The unified search bar: the free text plus the user and customer filters
  /// as chips. Built here rather than inline so the header can host it while
  /// the filters it drives belong to the whole screen.
  ///
  /// Filters live in the bar, actions in the toolbar. That split is what freed
  /// the room: "All users" and "Customer" used to be buttons whose labels
  /// doubled as their own state readout.
  Widget _searchBar({bool singleLine = false}) {
    final users = ref.watch(allUsersProvider).value ?? const <User>[];
    final customers =
        ref.watch(allCustomersProvider).value ?? const <Customer>[];

    return UnifiedSearchBar(
      singleLine: singleLine,
      controller: _searchCtrl,
      hintText: AppLocalizations.of(context).searchDocument,
      chips: _searchChips(users),
      sectionsBuilder: (query) => _filterSections(query, users, customers),
      onQueryChanged: (value) => setState(() => _query = value),
      onClearAll: () {
        _searchCtrl.clear();
        setState(() {
          _query = '';
          _filterCustomer = null;
          _filterUserId = null;
        });
        _fetchDocuments();
      },
    );
  }

  // ── toolbar ───────────────────────────────────────────────────────────────

  Widget _buildToolbar(ThemeData theme, ColorScheme cs) {
    final sel = _selectedDocLocalId != null && _documents.isNotEmpty
        ? _documents.where((d) => d.localId == _selectedDocLocalId).firstOrNull
        : null;

    final actions = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _toolBtn(
            Icons.print_outlined,
            AppLocalizations.of(context).setPrint,
            sel == null ? null : () => _printInvoice(sel),
          ),
          _toolBtn(
            Icons.picture_as_pdf_outlined,
            AppLocalizations.of(context).saveAsPdf,
            sel == null ? null : () => _saveInvoicePdf(sel),
          ),
          _toolBtn(
            Icons.receipt_outlined,
            AppLocalizations.of(context).receiptLabel,
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
            AppLocalizations.of(context).sendEmail,
            sel == null
                ? null
                : () => _notImplemented(AppLocalizations.of(context).sendEmail),
          ),

          const Gap(12),
          const VerticalDivider(width: 1, indent: 16, endIndent: 16),
          const Gap(12),

          _toolBtn(
            Icons.undo_outlined,
            AppLocalizations.of(context).posRefund,
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
            AppLocalizations.of(context).actionDelete,
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
        ],
      ),
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Math, not a breakpoint: the period pill needs its label, the
          // actions need room to be tappable; when both cannot have it, the
          // pill drops to icon-only rather than the row overflowing.
          const pillFull = 240.0;
          const actionsMin = 340.0;
          const gap = 12.0;
          final showRangeLabel =
              constraints.maxWidth >= pillFull + actionsMin + gap;

          return Row(
            children: [
              _headerPill(
                cs,
                icon: Icons.calendar_month_outlined,
                onTap: _pickDateRange,
                label: showRangeLabel
                    ? '${_dateFmt.format(_startDate)} - ${_dateFmt.format(_endDate)}'
                    : null,
                tooltip:
                    '${_dateFmt.format(_startDate)} - ${_dateFmt.format(_endDate)}',
              ),
              const Gap(gap),
              const VerticalDivider(width: 1, indent: 16, endIndent: 16),
              const Gap(gap),
              Expanded(child: actions),
              ..._bandTrailing(cs),
            ],
          );
        },
      ),
    );
  }

  /// Columns + Refresh — pinned to the trailing edge of the toolbar band.
  List<Widget> _bandTrailing(ColorScheme cs) => [
    const Gap(12),
    const VerticalDivider(width: 1, indent: 16, endIndent: 16),
    const Gap(12),
    _toolBtn(
      Icons.view_column_outlined,
      AppLocalizations.of(context).columns,
      () => _pickColumns(
        title: AppLocalizations.of(context).documentsColumns,
        columns: _masterColumns(
          context,
        ).map((c) => (id: c.id, label: c.label)).toList(),
        visible: _visibleMasterColIds,
        prefsKey: _prefsMasterColsKey,
        onApply: (s) => setState(() => _visibleMasterColIds = s),
      ),
    ),
    _toolBtn(
      Icons.sync,
      AppLocalizations.of(context).refresh,
      () => _fetchDocuments(),
    ),
  ];

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
              label: Text(
                AppLocalizations.of(context).actionRetry,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalH = constraints.maxHeight;
        const dividerH = kSalesHistoryDividerHeight;

        final split = salesHistorySplit(totalH, _splitFraction);
        final masterBodyH = split.master;
        final detailH = split.detail;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(theme, cs, AppLocalizations.of(context).documents),
            SizedBox(
              height: masterBodyH,
              child: _buildMasterTable(context, theme, cs, sym),
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
              AppLocalizations.of(context).documentItems,
              trailing: _columnsHeaderButton(
                cs,
                () => _pickColumns(
                  title: AppLocalizations.of(context).documentItemsColumns,
                  columns: _detailColumns(
                    context,
                  ).map((c) => (id: c.id, label: c.label)).toList(),
                  visible: _visibleDetailColIds,
                  prefsKey: _prefsDetailColsKey,
                  onApply: (s) => setState(() => _visibleDetailColIds = s),
                ),
              ),
            ),
            SizedBox(
              height: detailH,
              child: _buildDetailTable(context, theme, cs, sym),
            ),
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
      message: AppLocalizations.of(context).chooseColumns,
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
                AppLocalizations.of(context).columns,
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

  // Ids only — needed in initState, where AppLocalizations.of(context) is not
  // yet usable. Must stay in sync with _masterColumns below.
  static const _masterColumnIds = <String>[
    'id',
    'type',
    'user',
    'number',
    'external',
    'customer',
    'date',
    'created',
    'pos',
    'order',
    'payment',
    'discount',
    'totalBefore',
    'tax',
    'total',
  ];

  // Built per-frame rather than const: the labels are localized, so they can
  // only be resolved once a BuildContext exists.
  //
  // `width` is a STARTING width, not a share: every column is draggable by its
  // header edge (Ilyass Style), and `customer` is the one that absorbs surplus
  // width on a wide monitor. The old flex shares squeezed all fifteen columns
  // into the pane, so on a till every one of them was truncated at once.
  static List<({String id, String label, double width, bool numeric})>
  _masterColumns(BuildContext context) =>
      <({String id, String label, double width, bool numeric})>[
        (
          id: 'id',
          label: AppLocalizations.of(context).idLabel,
          width: 70,
          numeric: true,
        ),
        (
          id: 'type',
          label: AppLocalizations.of(context).documentType,
          width: 110,
          numeric: false,
        ),
        (
          id: 'user',
          label: AppLocalizations.of(context).userLabel,
          width: 120,
          numeric: false,
        ),
        (
          id: 'number',
          label: AppLocalizations.of(context).numberLabel,
          width: 170,
          numeric: false,
        ),
        (
          id: 'external',
          label: AppLocalizations.of(context).externalRef,
          width: 120,
          numeric: false,
        ),
        (
          id: 'customer',
          label: AppLocalizations.of(context).customerLabel,
          width: 180,
          numeric: false,
        ),
        (
          id: 'date',
          label: AppLocalizations.of(context).dateLabel,
          width: 150,
          numeric: false,
        ),
        (
          id: 'created',
          label: AppLocalizations.of(context).created,
          width: 165,
          numeric: false,
        ),
        (
          id: 'pos',
          label: AppLocalizations.of(context).posLabel,
          width: 110,
          numeric: false,
        ),
        (
          id: 'order',
          label: AppLocalizations.of(context).orderNoLabel,
          width: 130,
          numeric: false,
        ),
        (
          id: 'payment',
          label: AppLocalizations.of(context).paymentLabel,
          width: 140,
          numeric: false,
        ),
        (
          id: 'discount',
          label: AppLocalizations.of(context).posDiscount,
          width: 95,
          numeric: true,
        ),
        (
          id: 'totalBefore',
          label: AppLocalizations.of(context).totalBeforeTax,
          width: 130,
          numeric: true,
        ),
        (
          id: 'tax',
          label: AppLocalizations.of(context).fieldTax,
          width: 95,
          numeric: true,
        ),
        (
          id: 'total',
          label: AppLocalizations.of(context).totalLabel,
          width: 135,
          numeric: true,
        ),
      ];

  Widget _buildMasterTable(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    String sym,
  ) {
    const ts = TextStyle(fontSize: 15); // Scaled up table row font
    final dimTs = TextStyle(
      fontSize: 15,
      color: cs.onSurface.withValues(alpha: 0.5),
    );

    final cellBuilders = <String, Widget Function(SalesHistoryDocument)>{
      'id': (doc) => Text('${doc.id}', style: dimTs),
      'type': (doc) => Text(AppLocalizations.of(context).sales, style: ts),
      'user': (doc) => Text(doc.userName ?? '-', style: ts),
      'number': (doc) => Text(
        doc.number,
        style: ts.copyWith(fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
      'external': (doc) => Text(doc.referenceDocumentNumber ?? '-', style: ts),
      'customer': (doc) => Text(
        doc.customerName ?? AppLocalizations.of(context).unknownLabel,
        style: ts,
        overflow: TextOverflow.ellipsis,
      ),
      'date': (doc) => Text(_fmt(doc.date), style: ts),
      'created': (doc) => Text(_fmt(doc.stockDate), style: ts),
      'pos': (doc) => Text(
        posNameFromDocumentNumber(doc.number, doc.orderNumber) ?? '-',
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

    final visibleCols = _masterColumns(
      context,
    ).where((c) => _visibleMasterColIds.contains(c.id)).toList();

    return IlyassTable<SalesHistoryDocument>(
      tableId: 'salesHistoryMaster',
      rows: _visibleDocuments,
      rowHeight: 52,
      columns: [
        for (final c in visibleCols)
          IlyassColumn<SalesHistoryDocument>(
            key: c.id,
            label: c.label,
            width: c.width,
            numeric: c.numeric,
            flexible: c.id == 'customer',
            cell: (context, doc) => cellBuilders[c.id]!(doc),
          ),
      ],
      isRowSelected: (doc) => doc.localId == _selectedDocLocalId,
      onRowTap: (doc) {
        setState(() {
          _selectedDocLocalId = doc.localId;
          _items = [];
        });
        _fetchItems(doc);
      },
      emptyState: Center(
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
              AppLocalizations.of(context).noSalesDocumentsForPeriod,
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

  // Ids only — see the note on _masterColumnIds.
  static const _detailColumnIds = <String>[
    'id',
    'code',
    'name',
    'unit',
    'qty',
    'priceBeforeTax',
    'tax',
    'price',
    'totalBeforeDiscount',
    'discount',
    'total',
  ];

  static List<({String id, String label, double width, bool numeric})>
  _detailColumns(BuildContext context) =>
      <({String id, String label, double width, bool numeric})>[
        (
          id: 'id',
          label: AppLocalizations.of(context).idLabel,
          width: 70,
          numeric: true,
        ),
        (
          id: 'code',
          label: AppLocalizations.of(context).fieldCode,
          width: 115,
          numeric: false,
        ),
        (
          id: 'name',
          label: AppLocalizations.of(context).fieldName,
          width: 240,
          numeric: false,
        ),
        (
          id: 'unit',
          label: AppLocalizations.of(context).unitOfMeasure,
          width: 110,
          numeric: false,
        ),
        (
          id: 'qty',
          label: AppLocalizations.of(context).fieldQuantity,
          width: 100,
          numeric: true,
        ),
        (
          id: 'priceBeforeTax',
          label: AppLocalizations.of(context).priceBeforeTax,
          width: 135,
          numeric: true,
        ),
        (
          id: 'tax',
          label: AppLocalizations.of(context).fieldTax,
          width: 85,
          numeric: true,
        ),
        (
          id: 'price',
          label: AppLocalizations.of(context).priceLabel,
          width: 115,
          numeric: true,
        ),
        (
          id: 'totalBeforeDiscount',
          label: AppLocalizations.of(context).totalBeforeDiscount,
          width: 155,
          numeric: true,
        ),
        (
          id: 'discount',
          label: AppLocalizations.of(context).posDiscount,
          width: 105,
          numeric: true,
        ),
        (
          id: 'total',
          label: AppLocalizations.of(context).totalLabel,
          width: 125,
          numeric: true,
        ),
      ];

  Widget _buildDetailTable(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    String sym,
  ) {
    if (_selectedDocLocalId == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context).selectDocumentToViewItems,
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
      // The line carries its unit as text, so the quantity can be shown at
      // that unit's real precision — 0.002 kg reads 0.002, not 0.00.
      'qty': (item) => Text(
        formatQuantityValue(
          item.quantity,
          uomFromLegacyText(item.measurementUnit),
        ),
        style: ts,
      ),
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

    final visibleCols = _detailColumns(
      context,
    ).where((c) => _visibleDetailColIds.contains(c.id)).toList();

    return IlyassTable<DocumentItem>(
      tableId: 'salesHistoryDetail',
      rows: _items,
      rowHeight: 52,
      columns: [
        for (final c in visibleCols)
          IlyassColumn<DocumentItem>(
            key: c.id,
            label: c.label,
            width: c.width,
            numeric: c.numeric,
            // The product name is the widest-varying field on a line, so it
            // takes the slack rather than stretching the unit column.
            flexible: c.id == 'name',
            cell: (context, item) => cellBuilders[c.id]!(item),
          ),
      ],
      emptyState: Center(
        child: Text(
          AppLocalizations.of(context).noItemsForDocument,
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
    final visible = _visibleDocuments;
    final totalAmount = visible.fold<double>(0, (sum, d) => sum + d.total);

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
            AppLocalizations.of(context).documentsCountValue(visible.length),
            style: TextStyle(
              fontSize: 16, // Larger font
              color: cs.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            AppLocalizations.of(
              context,
            ).totalAmountWithValue(_numFmt.format(totalAmount), sym),
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
                    child: Text(
                      AppLocalizations.of(context).selectAll,
                      style: const TextStyle(fontSize: 16),
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
                    child: Text(
                      AppLocalizations.of(context).actionApply,
                      style: const TextStyle(fontSize: 16),
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
                    AppLocalizations.of(context).filterByCustomer,
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
                  hintText: AppLocalizations.of(context).searchCustomer,
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
                        AppLocalizations.of(context).allCustomers,
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
                    AppLocalizations.of(context).failedToLoadCustomers,
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
                        AppLocalizations.of(context).noCustomersFound,
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
