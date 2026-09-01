import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/uom/unit_of_measure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pos_app/printer/pdf_fonts.dart';
import 'package:pos_app/printer/printed_text.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/product/product_provider.dart';
import 'package:pos_app/product/product_group_provider.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/core/app_date_picker.dart';
import 'package:pos_app/printer/pdf_file_name.dart';
import 'package:pos_app/printer/pdf_save_service.dart';
import 'package:pos_app/reports/report_models.dart';
import 'package:pos_app/reports/reports_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:pos_app/settings/settings_provider.dart';

// ─── Data models ──────────────────────────────────────────────────────────────

/// Localized display label for a report. The label baked into the const
/// [_ReportType] tables stays English on purpose — those lists are top-level
/// const, so they cannot call AppLocalizations, and the English text doubles
/// as the fallback for any id added without a translation.
String _reportLabel(BuildContext context, String id) {
  final l = AppLocalizations.of(context);
  switch (id) {
    case 'sales_by_product':
    case 'purchase_products':
    case 'stock_return_products':
    case 'loss_and_damage_products':
      return l.rptSalesByProduct;
    case 'sales_by_group':
      return l.rptSalesByGroup;
    case 'sales_by_customer':
      return l.rptSalesByCustomer;
    case 'sales_tax':
    case 'purchase_tax':
      return l.rptTaxRates;
    case 'sales_users':
      return l.rptUsers;
    case 'sales_item_list':
      return l.rptItemList;
    case 'sales_payment_types':
      return l.rptPaymentTypes;
    case 'sales_payment_by_user':
      return l.rptPaymentByUser;
    case 'sales_payment_by_customer':
      return l.rptPaymentByCustomer;
    case 'sales_refunds':
      return l.rptRefunds;
    case 'sales_invoice_list':
      return l.rptInvoiceList;
    case 'sales_daily':
      return l.rptDailySales;
    case 'sales_hourly':
      return l.rptHourlySales;
    case 'sales_hourly_group':
      return l.rptHourlyByGroup;
    case 'sales_by_table':
      return l.rptByTable;
    case 'sales_profit':
      return l.rptProfitMargin;
    case 'sales_unpaid':
      return l.rptUnpaidSales;
    case 'sales_starting_cash':
      return l.rptStartingCash;
    case 'sales_voided':
      return l.rptVoidedItems;
    case 'sales_discounts':
      return l.rptDiscountsGranted;
    case 'sales_discounts_by_source':
      return l.rptDiscountsBySource;
    case 'sales_item_discounts':
      return l.rptItemDiscounts;
    case 'sales_stock_movement':
      return l.rptStockMovement;
    case 'purchase_suppliers':
      return l.rptSuppliers;
    case 'purchase_unpaid':
      return l.rptUnpaidPurchase;
    case 'purchase_discounts':
      return l.rptPurchaseDiscounts;
    case 'purchase_items_discounts':
      return l.rptPurchasedItemDiscounts;
    case 'purchase_invoice_list':
      return l.rptPurchaseInvoiceList;
    case 'purchase_expiration':
      return l.rptExpirationDate;
    case 'reorder_list':
      return l.rptReorderList;
    case 'low_stock_warning':
      return l.rptLowStockWarning;
    case 'transaction_history':
      return l.rptTransactionHistory;
    default:
      return id;
  }
}

/// Localized name of a report section (the const _allSections keys stay English
/// for the same reason as [_reportLabel]).
String _sectionName(BuildContext context, String section) {
  final l = AppLocalizations.of(context);
  switch (section) {
    case 'Sales':
      return l.secSales;
    case 'Purchase':
      return l.secPurchase;
    case 'Stock Return':
      return l.secStockReturn;
    case 'Loss and damage':
      return l.secLossAndDamage;
    case 'Stock control':
      return l.secStockControl;
    case 'Finance':
      return l.secFinance;
    default:
      return section;
  }
}

class _ReportType {
  final String id;
  final String label;
  final IconData icon;
  const _ReportType(this.id, this.label, this.icon);
}

class _OpenTab {
  final String id;
  final _ReportType reportType;
  final ReportFilter filter;
  const _OpenTab({
    required this.id,
    required this.reportType,
    required this.filter,
  });
}
// ─── Favorites Provider ───────────────────────────────────────────────────────

final favoriteReportsProvider =
    NotifierProvider<_FavoriteReportsNotifier, Set<String>>(
      _FavoriteReportsNotifier.new,
    );

class _FavoriteReportsNotifier extends Notifier<Set<String>> {
  static const _key = 'ui.favoriteReports';

  @override
  Set<String> build() {
    // Read directly from the synchronous SharedPreferences provider
    final prefs = ref.watch(sharedPreferencesProvider);
    final list = prefs.getStringList(_key) ?? <String>[];
    return list.toSet();
  }

  void toggle(String reportId) {
    final current = Set<String>.from(state);
    if (current.contains(reportId)) {
      current.remove(reportId);
    } else {
      current.add(reportId);
    }
    state = current;
    ref.read(sharedPreferencesProvider).setStringList(_key, current.toList());
  }

  void clear() {
    state = const <String>{};
    ref.read(sharedPreferencesProvider).remove(_key);
  }
}
// ─── Report catalogue ─────────────────────────────────────────────────────────

const _salesReports = [
  _ReportType('sales_by_product', 'Products', Icons.local_offer_outlined),
  _ReportType('sales_by_group', 'Product groups', Icons.folder_outlined),
  _ReportType('sales_by_customer', 'Customers', Icons.people_outline),
  _ReportType('sales_tax', 'Tax rates', Icons.percent),
  _ReportType('sales_users', 'Users', Icons.person_outline),
  _ReportType('sales_item_list', 'Item list', Icons.list_alt_outlined),
  _ReportType(
    'sales_payment_types',
    'Payment types',
    Icons.credit_card_outlined,
  ),
  _ReportType(
    'sales_payment_by_user',
    'Payment types by users',
    Icons.manage_accounts_outlined,
  ),
  _ReportType(
    'sales_payment_by_customer',
    'Payment types by customers',
    Icons.person_pin_outlined,
  ),
  _ReportType('sales_refunds', 'Refunds', Icons.undo_outlined),
  _ReportType('sales_invoice_list', 'Invoice list', Icons.receipt_outlined),
  _ReportType('sales_daily', 'Daily sales', Icons.today_outlined),
  _ReportType('sales_hourly', 'Hourly sales', Icons.schedule_outlined),
  _ReportType(
    'sales_hourly_group',
    'Hourly sales by product groups',
    Icons.bar_chart_outlined,
  ),
  _ReportType(
    'sales_by_table',
    'Table or order number',
    Icons.table_restaurant_outlined,
  ),
  _ReportType('sales_profit', 'Profit & margin', Icons.trending_up_outlined),
  _ReportType('sales_unpaid', 'Unpaid sales', Icons.money_off_outlined),
  _ReportType(
    'sales_starting_cash',
    'Starting cash entries',
    Icons.account_balance_wallet_outlined,
  ),
  _ReportType('sales_voided', 'Voided items', Icons.delete_outline),
  _ReportType('sales_discounts', 'Discounts granted', Icons.discount_outlined),
  _ReportType(
    'sales_discounts_by_source',
    'Discounts by source',
    Icons.pie_chart_outline,
  ),
  _ReportType('sales_item_discounts', 'Items discounts', Icons.sell_outlined),
  _ReportType(
    'sales_stock_movement',
    'Stock movement',
    Icons.swap_horiz_outlined,
  ),
];

const _purchaseReports = [
  _ReportType('purchase_products', 'Products', Icons.local_offer_outlined),
  _ReportType('purchase_suppliers', 'Suppliers', Icons.store_outlined),
  _ReportType('purchase_unpaid', 'Unpaid purchase', Icons.money_off_outlined),
  _ReportType(
    'purchase_discounts',
    'Purchase discounts',
    Icons.discount_outlined,
  ),
  _ReportType(
    'purchase_items_discounts',
    'Purchased items discounts',
    Icons.sell_outlined,
  ),
  _ReportType(
    'purchase_invoice_list',
    'Purchase invoice list',
    Icons.receipt_outlined,
  ),
  _ReportType('purchase_tax', 'Tax rates', Icons.percent),
  _ReportType('purchase_expiration', 'Expiration date', Icons.event_outlined),
];

const _stockReturnReports = [
  _ReportType('stock_return_products', 'Products', Icons.local_offer_outlined),
];

const _lossAndDamageReports = [
  _ReportType(
    'loss_and_damage_products',
    'Products',
    Icons.local_offer_outlined,
  ),
];

const _stockControlReports = [
  _ReportType(
    'reorder_list',
    'Reorder product list',
    Icons.shopping_cart_outlined,
  ),
  _ReportType(
    'low_stock_warning',
    'Low stock warning',
    Icons.warning_amber_outlined,
  ),
];

const _financeReports = [
  _ReportType(
    'transaction_history',
    'Transaction history',
    Icons.receipt_long_outlined,
  ),
];

// ─── Section lookup helpers ───────────────────────────────────────────────────

const _allSections = <(String, List<_ReportType>)>[
  ('Sales', _salesReports),
  ('Purchase', _purchaseReports),
  ('Stock Return', _stockReturnReports),
  ('Loss and damage', _lossAndDamageReports),
  ('Stock control', _stockControlReports),
  ('Finance', _financeReports),
];

String _sectionOf(String reportId) {
  for (final (section, reports) in _allSections) {
    if (reports.any((r) => r.id == reportId)) return section;
  }
  return '';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const ReportsScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _ReportType? _selectedReportType;
  ReportFilter _filter = ReportFilter(
    startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
    endDate: DateTime.now(),
  );
  final List<_OpenTab> _tabs = [];
  String _activeTabId = 'home';
  int _tabCounter = 0;
  String _searchQuery = '';

  void _showReport() {
    if (_selectedReportType == null) return;
    final tab = _OpenTab(
      id: 'tab_${_tabCounter++}',
      reportType: _selectedReportType!,
      filter: _filter,
    );
    setState(() {
      _tabs.add(tab);
      _activeTabId = tab.id;
    });
  }

  void _closeTab(String id) {
    setState(() {
      _tabs.removeWhere((t) => t.id == id);
      if (_activeTabId == id) _activeTabId = 'home';
    });
  }

  Future<void> _exportCsv() async {
    if (_selectedReportType == null) return;
    // Read before the first await: the column names are needed all the way
    // down and `context` must not be touched across an async gap.
    final l = AppLocalizations.of(context);
    final filter = _filter;
    final reportId = _selectedReportType!.id;
    final buf = StringBuffer();
    String filename;

    try {
      if (reportId == 'sales_by_product') {
        final rows = await ref.read(salesByProductProvider(filter).future);
        buf.writeln(
          _csvHeader([
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.rptColUom,
            l.totalBeforeTax,
            l.totalLabel,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.code ?? ''}","${r.product}",${r.quantity},"${r.uom}",${r.totalBeforeTax},${r.total}',
          );
        }
        buf.writeln(
          '"","Total",${rows.fold(0.0, (s, r) => s + r.quantity)},"",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'SalesByProduct';
      } else if (reportId == 'sales_by_group') {
        final rows = await ref.read(salesByProductGroupProvider(filter).future);
        buf.writeln(
          _csvHeader([
            l.fieldProductGroup,
            l.fieldQuantity,
            l.totalBeforeTax,
            l.totalLabel,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.productGroup}",${r.quantity},${r.totalBeforeTax},${r.total}',
          );
        }
        buf.writeln(
          '"Total",${rows.fold(0.0, (s, r) => s + r.quantity)},${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'SalesByProductGroup';
      } else if (reportId == 'sales_by_customer') {
        final rows = await ref.read(salesByCustomerProvider(filter).future);
        buf.writeln(
          _csvHeader([l.customerLabel, l.totalBeforeTax, l.totalLabel]),
        );
        for (final r in rows) {
          buf.writeln('"${r.customer}",${r.totalBeforeTax},${r.total}');
        }
        buf.writeln(
          '"Total",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'SalesByCustomer';
      } else if (reportId == 'sales_tax') {
        final rows = await ref.read(salesByTaxProvider(filter).future);
        buf.writeln(
          _csvHeader([
            l.rptColTaxName,
            l.totalBeforeTax,
            l.fieldTax,
            l.totalLabel,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.taxName}",${r.totalBeforeTax},${r.taxAmount},${r.total}',
          );
        }
        buf.writeln(
          '"Total",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.taxAmount)},${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'SalesTax';
      } else if (reportId == 'sales_payment_by_customer') {
        final rows = await ref.read(
          paymentTypesByCustomerProvider(filter).future,
        );
        final paymentTypes = rows.map((r) => r.paymentTypeName).toSet().toList()
          ..sort();
        final customers = rows.map((r) => r.customerName).toSet().toList()
          ..sort();
        final pivot = <String, Map<String, double>>{};
        for (final r in rows) {
          pivot.putIfAbsent(r.customerName, () => {});
          pivot[r.customerName]![r.paymentTypeName] =
              (pivot[r.customerName]![r.paymentTypeName] ?? 0) + r.amount;
        }
        buf.writeln(
          _csvHeader([l.customerLabel, ...paymentTypes, l.totalLabel]),
        );
        for (final c in customers) {
          final amounts = paymentTypes
              .map((pt) => pivot[c]?[pt] ?? 0.0)
              .toList();
          final total = amounts.fold(0.0, (s, a) => s + a);
          buf.writeln(['"$c"', ...amounts, total].join(','));
        }
        final grandAmounts = paymentTypes
            .map(
              (pt) => customers.fold(0.0, (s, c) => s + (pivot[c]?[pt] ?? 0.0)),
            )
            .toList();
        buf.writeln(
          [
            '"Total"',
            ...grandAmounts,
            rows.fold(0.0, (s, r) => s + r.amount),
          ].join(','),
        );
        filename = 'PaymentTypesByCustomer';
      } else if (reportId == 'sales_payment_by_user') {
        final rows = await ref.read(paymentTypesByUserProvider(filter).future);
        final paymentTypes = rows.map((r) => r.paymentTypeName).toSet().toList()
          ..sort();
        final users = rows.map((r) => r.userName).toSet().toList()..sort();
        final pivot = <String, Map<String, double>>{};
        for (final r in rows) {
          pivot.putIfAbsent(r.userName, () => {});
          pivot[r.userName]![r.paymentTypeName] =
              (pivot[r.userName]![r.paymentTypeName] ?? 0) + r.amount;
        }
        buf.writeln(_csvHeader([l.userLabel, ...paymentTypes, l.totalLabel]));
        for (final u in users) {
          final amounts = paymentTypes
              .map((pt) => pivot[u]?[pt] ?? 0.0)
              .toList();
          final total = amounts.fold(0.0, (s, a) => s + a);
          buf.writeln(['"$u"', ...amounts, total].join(','));
        }
        final grandAmounts = paymentTypes
            .map((pt) => users.fold(0.0, (s, u) => s + (pivot[u]?[pt] ?? 0.0)))
            .toList();
        buf.writeln(
          [
            '"Total"',
            ...grandAmounts,
            rows.fold(0.0, (s, r) => s + r.amount),
          ].join(','),
        );
        filename = 'PaymentTypesByUser';
      } else if (reportId == 'sales_payment_types') {
        final rows = await ref.read(salesByPaymentTypeProvider(filter).future);
        final paymentTypes = rows.map((r) => r.paymentTypeName).toSet().toList()
          ..sort();
        final dates = rows.map((r) => r.date).toSet().toList()..sort();
        final pivot = <DateTime, Map<String, double>>{};
        for (final r in rows) {
          pivot.putIfAbsent(r.date, () => {});
          pivot[r.date]![r.paymentTypeName] =
              (pivot[r.date]![r.paymentTypeName] ?? 0) + r.amount;
        }
        final dateFmt2 = DateFormat('dd/MM/yyyy');
        buf.writeln(_csvHeader([l.dateLabel, ...paymentTypes, l.totalLabel]));
        for (final d in dates) {
          final amounts = paymentTypes
              .map((pt) => pivot[d]?[pt] ?? 0.0)
              .toList();
          final total = amounts.fold(0.0, (s, a) => s + a);
          buf.writeln([dateFmt2.format(d), ...amounts, total].join(','));
        }
        // grand total row
        final grandAmounts = paymentTypes
            .map((pt) => dates.fold(0.0, (s, d) => s + (pivot[d]?[pt] ?? 0.0)))
            .toList();
        buf.writeln(
          [
            '',
            ...grandAmounts,
            rows.fold(0.0, (s, r) => s + r.amount),
          ].join(','),
        );
        filename = 'SalesByPaymentType';
      } else if (reportId == 'sales_refunds') {
        final rows = await ref.read(refundItemListProvider(filter).future);
        buf.writeln(
          _csvHeader([
            l.documentNumber,
            l.rptColRefNumber,
            l.dateLabel,
            l.rptColCustomerCode,
            l.customerLabel,
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.rptColUom,
            l.totalBeforeTax,
            l.rptColTotalTax,
            l.totalLabel,
          ]),
        );
        final dateFmt = DateFormat('dd/MM/yyyy');
        for (final r in rows) {
          buf.writeln(
            '"${r.documentNumber}","${r.refNumber ?? ''}","${dateFmt.format(r.date)}",'
            '"${r.customerCode ?? ''}","${r.customerName}","${r.productCode ?? ''}","${r.productName}",'
            '${r.quantity},"${r.uom}",${r.totalBeforeTax},${r.totalTax},${r.total}',
          );
        }
        buf.writeln(
          '"","","","","","","Total",'
          '${rows.fold(0.0, (s, r) => s + r.quantity)},"",'
          '${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},'
          '${rows.fold(0.0, (s, r) => s + r.totalTax)},'
          '${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'Refunds';
      } else if (reportId == 'sales_invoice_list') {
        final rows = await ref.read(invoiceListProvider(filter).future);
        buf.writeln(
          _csvHeader([
            '#',
            l.dateLabel,
            l.documentNumber,
            l.customerLabel,
            l.rptColPaymentMethod,
            l.totalLabel,
          ]),
        );
        final dateFmt = DateFormat('dd/MM/yyyy');
        var i = 1;
        for (final r in rows) {
          buf.writeln(
            '$i,"${dateFmt.format(r.date)}","${r.documentNumber}",'
            '"${r.customerName}","${r.paymentMethodName}",${r.total}',
          );
          i++;
        }
        buf.writeln(
          '"","","","","Total",${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'InvoiceList';
      } else if (reportId == 'sales_daily') {
        final rows = await ref.read(dailySalesProvider(filter).future);
        buf.writeln(_csvHeader([l.dateLabel, l.totalLabel]));
        final dayFmt = DateFormat('dd/MM/yyyy (EEE)');
        for (final r in rows) {
          buf.writeln('"${dayFmt.format(r.date)}",${r.total}');
        }
        buf.writeln('"Total",${rows.fold(0.0, (s, r) => s + r.total)}');
        filename = 'DailySales';
      } else if (reportId == 'sales_hourly') {
        final rows = await ref.read(hourlySalesProvider(filter).future);
        final grandTotal = rows.fold(0.0, (s, r) => s + r.totalSales);
        final grandCount = rows.fold(0, (s, r) => s + r.salesCount);
        final timeFmt = DateFormat('h:mm a');
        buf.writeln(
          _csvHeader([
            l.rptColHourStart,
            l.rptColHourEnd,
            l.rptColTotalSales,
            l.rptColSalesCount,
            l.rptColAverageSale,
            '%',
          ]),
        );
        for (final r in rows) {
          final start = DateTime(2000, 1, 1, r.hour);
          final avg = r.salesCount > 0 ? r.totalSales / r.salesCount : 0.0;
          final pct = grandTotal > 0 ? r.totalSales / grandTotal * 100 : 0.0;
          buf.writeln(
            '"${timeFmt.format(start)}","${timeFmt.format(start.add(const Duration(minutes: 59)))}",'
            '${r.totalSales},${r.salesCount},$avg,${pct.toStringAsFixed(2)}%',
          );
        }
        buf.writeln('"","Total",$grandTotal,$grandCount,,');
        filename = 'HourlySales';
      } else if (reportId == 'sales_hourly_group') {
        final rows = await ref.read(hourlySalesByGroupProvider(filter).future);
        final hours = rows.map((r) => r.hour).toSet().toList()..sort();
        final groups = rows.map((r) => r.productGroup).toSet().toList()..sort();
        final pivot = <String, Map<int, double>>{};
        for (final r in rows) {
          pivot.putIfAbsent(r.productGroup, () => {})[r.hour] =
              (pivot[r.productGroup]![r.hour] ?? 0) + r.total;
        }
        final timeFmt = DateFormat('h:mm a');
        final hourLabels = hours
            .map((h) => timeFmt.format(DateTime(2000, 1, 1, h)))
            .toList();
        buf.writeln(
          [
            l.fieldProductGroup,
            ...hourLabels,
            l.totalLabel,
          ].map((h) => '"$h"').join(','),
        );
        for (final g in groups) {
          final amounts = hours.map((h) => pivot[g]?[h] ?? 0.0).toList();
          buf.writeln(
            ['"$g"', ...amounts, amounts.fold(0.0, (s, a) => s + a)].join(','),
          );
        }
        final hourTotals = hours
            .map((h) => groups.fold(0.0, (s, g) => s + (pivot[g]?[h] ?? 0.0)))
            .toList();
        buf.writeln(
          [
            '"Total"',
            ...hourTotals,
            rows.fold(0.0, (s, r) => s + r.total),
          ].join(','),
        );
        filename = 'HourlySalesByGroup';
      } else if (reportId == 'sales_by_table') {
        final rows = await ref.read(salesByTableProvider(filter).future);
        buf.writeln(
          _csvHeader([
            l.rptColTableOrOrder,
            l.rptColNumberOfSales,
            l.totalLabel,
          ]),
        );
        for (final r in rows) {
          buf.writeln('"${r.orderNumber}",${r.numberOfSales},${r.total}');
        }
        buf.writeln(
          '"Total",${rows.fold(0, (s, r) => s + r.numberOfSales)},'
          '${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'SalesByTable';
      } else if (reportId == 'sales_profit') {
        final rows = await ref.read(profitProvider(filter).future);
        buf.writeln(
          _csvHeader([
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.fieldCost,
            l.totalLabel,
            l.rptColProfit,
            l.rptColMargin,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.productCode ?? ''}","${r.productName}",${r.quantity},'
            '${r.cost},${r.total},${r.profit},${r.margin.toStringAsFixed(2)}%',
          );
        }
        buf.writeln(
          '"","Total",${rows.fold(0.0, (s, r) => s + r.quantity)},'
          '${rows.fold(0.0, (s, r) => s + r.cost)},'
          '${rows.fold(0.0, (s, r) => s + r.total)},'
          '${rows.fold(0.0, (s, r) => s + r.profit)},',
        );
        filename = 'Profit';
      } else if (reportId == 'sales_unpaid') {
        final rows = await ref.read(unpaidSalesProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln(
          _csvHeader([
            l.customerLabel,
            l.documentNumber,
            l.dateLabel,
            l.rptColDueDate,
            l.totalLabel,
            l.rptColTotalPaid,
            l.rptColTotalUnpaid,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.customerName}","${r.documentNumber}",'
            '"${dateFmt.format(r.date)}","${r.dueDate != null ? dateFmt.format(r.dueDate!) : ''}",'
            '${r.documentTotal},${r.totalPaid},${r.totalUnpaid}',
          );
        }
        buf.writeln(
          '"","","","","","Total",${rows.fold(0.0, (s, r) => s + r.totalUnpaid)}',
        );
        filename = 'UnpaidSales';
      } else if (reportId == 'sales_starting_cash') {
        final rows = await ref.read(startingCashReportProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
        buf.writeln(
          _csvHeader([
            l.userLabel,
            l.typeLabel,
            l.fieldDescription,
            l.dateLabel,
            l.amount,
            l.rptColZReportNo,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.userName ?? ''}","${r.isCashOut ? 'Cash Out' : 'Cash In'}",'
            '"${r.description ?? ''}","${dateFmt.format(r.dateCreated)}",'
            '${r.signedAmount},${r.zReportNumber ?? ''}',
          );
        }
        buf.writeln(
          '"","","","Total",${rows.fold(0.0, (s, r) => s + r.signedAmount)},""',
        );
        filename = 'StartingCash';
      } else if (reportId == 'sales_stock_movement') {
        final rows = await ref.read(stockMovementReportProvider(filter).future);
        final total = rows.fold(0.0, (s, r) => s + r.numSales);
        final average = rows.isEmpty ? 0.0 : total / rows.length;
        buf.writeln(
          _csvHeader([
            l.categoryLabel,
            l.fieldCode,
            l.productLabel,
            l.rptColNumSales,
          ]),
        );
        for (final r in rows) {
          final cat = r.numSales >= average ? l.rptFastMoving : l.rptSlowMoving;
          buf.writeln(
            '"$cat","${r.productCode ?? ''}","${r.productName}",${r.numSales}',
          );
        }
        buf.writeln('"","","Total number of sales",$total');
        buf.writeln('"","","Average number of sales per item",$average');
        filename = 'StockMovement';
      } else if (reportId == 'sales_item_discounts') {
        final rows = await ref.read(
          itemsDiscountsReportProvider(filter).future,
        );
        buf.writeln(
          _csvHeader([l.fieldCode, l.productLabel, l.rptColTotalDiscount]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.productCode ?? ''}","${r.productName}",${r.totalDiscount}',
          );
        }
        buf.writeln(
          '"","Total",${rows.fold(0.0, (s, r) => s + r.totalDiscount)}',
        );
        filename = 'ItemsDiscounts';
      } else if (reportId == 'sales_discounts') {
        final rows = await ref.read(
          discountsGrantedReportProvider(filter).future,
        );
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln(
          _csvHeader([
            l.customerLabel,
            l.rptColDocument,
            l.dateLabel,
            l.userLabel,
            l.rptColTotalBeforeDisc,
            l.rptColTotalAfterDisc,
            l.rptColDiscountGranted,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.customerName}","${r.documentNumber}",'
            '"${dateFmt.format(r.date)}","${r.userName}",'
            '${r.totalBeforeDiscount},${r.totalAfterDiscount},${r.discountGranted}',
          );
        }
        buf.writeln(
          '"","","","","","Total",${rows.fold(0.0, (s, r) => s + r.discountGranted)}',
        );
        filename = 'DiscountsGranted';
      } else if (reportId == 'sales_discounts_by_source') {
        final rows = await ref.read(
          discountsBySourceReportProvider(filter).future,
        );
        buf.writeln(_csvHeader([l.rptColDiscountSource, l.totalLabel]));
        for (final r in rows) {
          buf.writeln('"${r.label}",${r.amount}');
        }
        buf.writeln('"Total",${rows.fold(0.0, (s, r) => s + r.amount)}');
        filename = 'DiscountsBySource';
      } else if (reportId == 'sales_voided') {
        final rows = await ref.read(voidedItemsReportProvider(filter).future);
        final dtFmt = DateFormat('dd/MM/yyyy HH:mm:ss');
        buf.writeln(
          _csvHeader([
            l.productLabel,
            l.rptColVoidedBy,
            l.rptColQtyShort,
            l.priceLabel,
            l.discountLabel,
            l.statusLabel,
            l.rptColOrderNo,
            l.rptColCreated,
            l.rptColVoided,
            l.totalLabel,
            l.rptColReason,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.productName}","${r.voidedByName ?? ''}",'
            '${r.quantity},${r.price},"${r.discountDisplay}",'
            '"${r.isConfirmed ? l.rptStatusConfirmed : l.rptStatusPending}",'
            '"${r.orderNumber}","${dtFmt.format(r.dateCreated)}",'
            '"${dtFmt.format(r.dateVoided)}",${r.total},'
            '"${r.reason ?? ''}"',
          );
        }
        buf.writeln(
          '"","","","","","","","","Total",${rows.fold(0.0, (s, r) => s + r.total)},""',
        );
        filename = 'VoidedItems';
      } else if (reportId == 'sales_item_list') {
        final rows = await ref.read(salesItemListProvider(filter).future);
        buf.writeln(
          _csvHeader([
            l.documentType,
            l.dateLabel,
            l.rptColCreateDate,
            l.documentNumber,
            l.rptColRefNumber,
            l.rptColCustomerCode,
            l.customerLabel,
            l.orderNumberLabel,
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.rptColUom,
            l.totalBeforeTax,
            l.rptColTotalTax,
            l.totalLabel,
          ]),
        );
        final dateFmt = DateFormat('dd/MM/yyyy');
        final dtFmt = DateFormat('dd/MM/yyyy HH:mm:ss');
        for (final r in rows) {
          buf.writeln(
            '"${r.documentTypeName}","${dateFmt.format(r.date)}","${dtFmt.format(r.dateCreated)}",'
            '"${r.documentNumber}","${r.refNumber ?? ''}","${r.customerCode ?? ''}","${r.customerName}",'
            '"${r.orderNumber ?? ''}","${r.productCode ?? ''}","${r.productName}",'
            '${r.quantity},"${r.uom}",${r.totalBeforeTax},${r.totalTax},${r.total}',
          );
        }
        buf.writeln(
          '"","","","","","","","","","Total",'
          '${rows.fold(0.0, (s, r) => s + r.quantity)},"",'
          '${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},'
          '${rows.fold(0.0, (s, r) => s + r.totalTax)},'
          '${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'SalesItemList';
      } else if (reportId == 'sales_users') {
        final rows = await ref.read(salesByUserProvider(filter).future);
        buf.writeln(_csvHeader([l.userLabel, l.totalBeforeTax, l.totalLabel]));
        for (final r in rows) {
          buf.writeln('"${r.user}",${r.totalBeforeTax},${r.total}');
        }
        buf.writeln(
          '"Total",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'SalesByUser';
      } else if (reportId == 'purchase_unpaid') {
        final rows = await ref.read(unpaidPurchaseProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln(
          _csvHeader([
            l.supplier,
            l.documentNumber,
            l.dateLabel,
            l.rptColDueDate,
            l.totalLabel,
            l.rptColTotalPaid,
            l.rptColTotalUnpaid,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.supplierName}","${r.documentNumber}",'
            '"${dateFmt.format(r.date)}","${r.dueDate != null ? dateFmt.format(r.dueDate!) : ''}",'
            '${r.documentTotal},${r.totalPaid},${r.totalUnpaid}',
          );
        }
        buf.writeln(
          '"","","","","","Total",${rows.fold(0.0, (s, r) => s + r.totalUnpaid)}',
        );
        filename = 'UnpaidPurchase';
      } else if (reportId == 'purchase_suppliers') {
        final rows = await ref.read(purchaseBySupplierProvider(filter).future);
        buf.writeln(_csvHeader([l.supplier, l.totalBeforeTax, l.totalLabel]));
        for (final r in rows) {
          buf.writeln('"${r.supplier}",${r.totalBeforeTax},${r.total}');
        }
        buf.writeln(
          '"Total",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'PurchaseBySupplier';
      } else if (reportId == 'purchase_products') {
        final rows = await ref.read(purchaseByProductProvider(filter).future);
        buf.writeln(
          _csvHeader([
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.rptColUom,
            l.totalBeforeTax,
            l.totalLabel,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.code ?? ''}","${r.product}",${r.quantity},"${r.uom}",${r.totalBeforeTax},${r.total}',
          );
        }
        buf.writeln(
          '"","Total",${rows.fold(0.0, (s, r) => s + r.quantity)},"",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'PurchaseByProduct';
      } else if (reportId == 'purchase_invoice_list') {
        final rows = await ref.read(purchaseInvoiceListProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln(
          _csvHeader([
            '#',
            l.supplier,
            l.rptColPurchaseNumber,
            l.externalDocument,
            l.dateLabel,
            l.totalLabel,
          ]),
        );
        var i = 1;
        for (final r in rows) {
          buf.writeln(
            '$i,"${r.supplierName}","${r.documentNumber}",'
            '"${r.externalDocument ?? ''}","${dateFmt.format(r.date)}",${r.total}',
          );
          i++;
        }
        buf.writeln(
          '"","","","","Total",${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'PurchaseInvoices';
      } else if (reportId == 'purchase_items_discounts') {
        final rows = await ref.read(
          purchaseItemsDiscountsProvider(filter).future,
        );
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln(
          _csvHeader([
            l.supplier,
            l.rptColDocument,
            l.dateLabel,
            l.userLabel,
            l.fieldCode,
            l.productLabel,
            l.qtyShort,
            l.fieldCost,
            l.rptColBeforeDisc,
            l.rptColAfterDisc,
            l.discountLabel,
            l.rptColTotalDisc,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.supplierName}","${r.documentNumber}",'
            '"${dateFmt.format(r.date)}","${r.userName}",'
            '"${r.productCode ?? ''}","${r.productName}",'
            '${r.quantity},${r.cost},'
            '${r.totalBeforeDiscount},${r.totalAfterDiscount},'
            '"${r.discountDisplay}",${r.totalDiscount}',
          );
        }
        buf.writeln(
          '"","","","","","","","","","","Total",${rows.fold(0.0, (s, r) => s + r.totalDiscount)}',
        );
        filename = 'PurchaseItemsDiscounts';
      } else if (reportId == 'purchase_discounts') {
        final rows = await ref.read(purchaseDiscountsProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln(
          _csvHeader([
            l.supplier,
            l.rptColDocument,
            l.dateLabel,
            l.userLabel,
            l.rptColTotalBeforeDisc,
            l.rptColTotalAfterDisc,
            l.rptColDiscountGranted,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.supplierName}","${r.documentNumber}",'
            '"${dateFmt.format(r.date)}","${r.userName}",'
            '${r.totalBeforeDiscount},${r.totalAfterDiscount},${r.discountGranted}',
          );
        }
        buf.writeln(
          '"","","","","","Total",${rows.fold(0.0, (s, r) => s + r.discountGranted)}',
        );
        filename = 'PurchaseDiscounts';
      } else if (reportId == 'purchase_tax') {
        final rows = await ref.read(purchaseByTaxProvider(filter).future);
        buf.writeln(
          _csvHeader([
            l.rptColTaxName,
            l.totalBeforeTax,
            l.fieldTax,
            l.totalLabel,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.taxName}",${r.totalBeforeTax},${r.taxAmount},${r.total}',
          );
        }
        buf.writeln(
          '"Total",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.taxAmount)},${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'PurchaseTax';
      } else if (reportId == 'purchase_expiration') {
        final rows = await ref.read(
          purchaseExpirationDateProvider(filter).future,
        );
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln(
          _csvHeader([
            '#',
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.rptColUom,
            l.rptColExpirationDate,
          ]),
        );
        var i = 1;
        for (final r in rows) {
          buf.writeln(
            '$i,"${r.productCode ?? ''}","${r.productName}",'
            '${r.quantity},"${r.uom}","${dateFmt.format(r.expirationDate)}"',
          );
          i++;
        }
        filename = 'PurchaseExpirationDate';
      } else if (reportId == 'stock_return_products') {
        final rows = await ref.read(
          stockReturnByProductProvider(filter).future,
        );
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln(
          _csvHeader([
            l.dateLabel,
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.rptColUom,
            l.totalBeforeTax,
            l.totalLabel,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${dateFmt.format(r.date)}","${r.code ?? ''}","${r.product}",${r.quantity},"${r.uom}",${r.totalBeforeTax},${r.total}',
          );
        }
        buf.writeln(
          '"","","Total",${rows.fold(0.0, (s, r) => s + r.quantity)},"",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'StockReturnByProduct';
      } else if (reportId == 'loss_and_damage_products') {
        final rows = await ref.read(
          lossAndDamageByProductProvider(filter).future,
        );
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln(
          _csvHeader([
            l.dateLabel,
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.rptColUom,
            l.totalBeforeTax,
            l.totalLabel,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${dateFmt.format(r.date)}","${r.code ?? ''}","${r.product}",${r.quantity},"${r.uom}",${r.totalBeforeTax},${r.total}',
          );
        }
        buf.writeln(
          '"","","Total",${rows.fold(0.0, (s, r) => s + r.quantity)},"",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}',
        );
        filename = 'LossAndDamageByProduct';
      } else if (reportId == 'reorder_list') {
        final rows = await ref.read(reorderProductListProvider(filter).future);
        buf.writeln(
          _csvHeader([
            l.supplier,
            l.rptColProductName,
            l.rptColOrderQty,
            l.rptColUom,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.supplierName}","${r.productName}",${r.orderQuantity},"${r.uom}"',
          );
        }
        filename = 'ReorderProductList';
      } else if (reportId == 'low_stock_warning') {
        final rows = await ref.read(lowStockWarningProvider(filter).future);
        buf.writeln(
          _csvHeader([
            l.supplier,
            l.rptColProductName,
            l.rptColCurrentStock,
            l.rptColWarningQty,
            l.rptColOrderQty,
            l.rptColUom,
          ]),
        );
        for (final r in rows) {
          buf.writeln(
            '"${r.supplierName}","${r.productName}",${r.currentStock},${r.lowStockWarningQuantity},${r.orderQuantity},"${r.uom}"',
          );
        }
        filename = 'LowStockWarning';
      } else if (reportId == 'transaction_history') {
        if (filter.customerId == null) return;
        final rows = await ref.read(transactionHistoryProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln(
          _csvHeader([
            l.dateLabel,
            l.rptColTransactionType,
            l.rptColRefNumber,
            l.rptColCredit,
            l.rptColDebit,
            l.balanceLabel,
          ]),
        );
        for (final r in rows) {
          final dateStr = r.isPreviousBalance
              ? ''
              : (r.date != null ? dateFmt.format(r.date!) : '');
          buf.writeln(
            '"$dateStr","${r.transactionType}","${r.refNumber ?? ''}",${r.credit},${r.debit},${r.balance}',
          );
        }
        filename = 'TransactionHistory';
      } else {
        return;
      }

      final file = File(
        '${Directory.systemTemp.path}\\${filename}_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(buf.toString());
      await Process.start('explorer.exe', [file.path]);

      if (mounted) {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).savedToPath(file.path),
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).exportFailed(e.toString()),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeTab = _tabs.where((t) => t.id == _activeTabId).firstOrNull;
    final favorites = ref.watch(favoriteReportsProvider);
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).reports),
        elevation: 0,
        // Suppress the auto back-arrow — ManagementLayout controls navigation.
        automaticallyImplyLeading: false,
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: AppLocalizations.of(context).showNavigation,
                onPressed: widget.onMenuPressed,
              )
            : null,
      ),
      body: Column(
        children: [
          // ── Tab bar ─────────────────────────────────────────────────────────
          Material(
            color: cs.surfaceContainerHighest,
            elevation: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _TabChip(
                    id: 'home',
                    label: AppLocalizations.of(context).selectReport,
                    icon: Icons.search,
                    active: _activeTabId == 'home',
                    onTap: () => setState(() => _activeTabId = 'home'),
                  ),
                  ..._tabs.map(
                    (t) => _TabChip(
                      id: t.id,
                      label: _reportLabel(context, t.reportType.id),
                      active: _activeTabId == t.id,
                      onTap: () => setState(() => _activeTabId = t.id),
                      onClose: () => _closeTab(t.id),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: cs.outlineVariant),

          // ── Body ─────────────────────────────────────────────────────────────
          Expanded(
            child: Material(
              color: cs.surface,
              child: _activeTabId == 'home'
                  ? _HomeView(
                      selected: _selectedReportType,
                      filter: _filter,
                      onSelectReport: (r) =>
                          setState(() => _selectedReportType = r),
                      onFilterChanged: (f) => setState(() => _filter = f),
                      onShowReport: _showReport,
                      onExportCsv: _exportCsv,

                      // UPDATE THESE THREE LINES:
                      favorites: favorites,
                      onToggleFavorite: (id) =>
                          ref.read(favoriteReportsProvider.notifier).toggle(id),
                      onClearFavorites: () =>
                          ref.read(favoriteReportsProvider.notifier).clear(),

                      searchQuery: _searchQuery,
                      onSearchChanged: (q) => setState(() => _searchQuery = q),
                    )
                  : activeTab != null
                  ? _TabPdfView(tab: activeTab)
                  : Center(
                      child: Text(AppLocalizations.of(context).tabNotFound),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab chip ─────────────────────────────────────────────────────────────────

/// One CSV header row. Every name is quoted and inner quotes doubled, because
/// a translated column name may itself contain a comma ("Total, taxes
/// comprises") which would otherwise shift every column in the sheet.
String _csvHeader(List<String> columns) =>
    columns.map((c) => '"${c.replaceAll('"', '""')}"').join(',');

class _TabChip extends StatelessWidget {
  final String id;
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _TabChip({
    required this.id,
    required this.label,
    this.icon,
    required this.active,
    required this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      splashColor: cs.primary.withValues(alpha: 0.1),
      highlightColor: cs.primary.withValues(alpha: 0.05),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? cs.surface : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: active ? cs.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: active ? cs.primary : cs.onSurfaceVariant,
              ),
              const Gap(6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: active ? cs.primary : cs.onSurfaceVariant,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (onClose != null) ...[
              const Gap(8),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Home view ────────────────────────────────────────────────────────────────

class _HomeView extends StatelessWidget {
  final _ReportType? selected;
  final ReportFilter filter;
  final ValueChanged<_ReportType> onSelectReport;
  final ValueChanged<ReportFilter> onFilterChanged;
  final VoidCallback onShowReport;
  final Future<void> Function() onExportCsv;
  final Set<String> favorites;
  final ValueChanged<String> onToggleFavorite;
  final VoidCallback onClearFavorites;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const _HomeView({
    required this.selected,
    required this.filter,
    required this.onSelectReport,
    required this.onFilterChanged,
    required this.onShowReport,
    required this.onExportCsv,
    required this.favorites,
    required this.onToggleFavorite,
    required this.onClearFavorites,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  Widget _sectionLabel(ColorScheme cs, String text, {Widget? trailing}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 16, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );

  Widget _reportTile(
    BuildContext context,
    ColorScheme cs,
    _ReportType r, {
    String? prefixLabel,
  }) {
    final active = selected?.id == r.id;
    final isFav = favorites.contains(r.id);
    return ListTile(
      dense: true,
      leading: Icon(
        r.icon,
        size: 18,
        color: active ? cs.primary : cs.onSurfaceVariant,
      ),
      title: Text(
        prefixLabel ?? _reportLabel(context, r.id),
        style: TextStyle(
          fontSize: 14,
          color: active ? cs.primary : cs.onSurface,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: IconButton(
        icon: Icon(
          isFav ? Icons.star_rounded : Icons.star_border_rounded,
          size: 20,
          color: isFav ? Colors.amber : cs.onSurfaceVariant,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
        onPressed: () => onToggleFavorite(r.id),
      ),
      selected: active,
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.35),
      onTap: () => onSelectReport(r),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Build filtered flat list when searching
    final q = searchQuery.trim().toLowerCase();
    final List<(String, _ReportType)> searchResults = q.isEmpty
        ? []
        : [
            for (final (section, reports) in _allSections)
              for (final r in reports)
                if (_reportLabel(context, r.id).toLowerCase().contains(q) ||
                    _sectionName(context, section).toLowerCase().contains(q))
                  (section, r),
          ];

    // Favorite _ReportType objects in insertion order
    final favoriteReports = [
      for (final (_, reports) in _allSections)
        for (final r in reports)
          if (favorites.contains(r.id)) r,
    ];

    return Row(
      children: [
        // ── Report list ──────────────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row with title + search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).selectReportToViewOrPrint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 200,
                      height: 36,
                      child: TextField(
                        onChanged: onSearchChanged,
                        style: TextStyle(fontSize: 13, color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).searchReports,
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: cs.primary,
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: cs.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: q.isNotEmpty
                    // ── Search results ───────────────────────────────────────
                    ? ListView(
                        children: [
                          if (searchResults.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                AppLocalizations.of(context).noReportsFound,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          for (final (section, r) in searchResults) ...[
                            _reportTile(
                              context,
                              cs,
                              r,
                              prefixLabel:
                                  '${_sectionName(context, section)} / ${_reportLabel(context, r.id)}',
                            ),
                            Divider(height: 1, color: cs.outlineVariant),
                          ],
                        ],
                      )
                    // ── Normal grouped list ──────────────────────────────────
                    : ListView(
                        children: [
                          // Favorites section
                          if (favoriteReports.isNotEmpty) ...[
                            _sectionLabel(
                              cs,
                              AppLocalizations.of(context).rptFavorites,
                              trailing: TextButton(
                                onPressed: onClearFavorites,
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  AppLocalizations.of(context).clearFavorites,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            for (final r in favoriteReports) ...[
                              _reportTile(
                                context,
                                cs,
                                r,
                                prefixLabel:
                                    '${_sectionName(context, _sectionOf(r.id))} / ${_reportLabel(context, r.id)}',
                              ),
                              Divider(height: 1, color: cs.outlineVariant),
                            ],
                          ],
                          // All sections
                          for (final (section, reports) in _allSections) ...[
                            _sectionLabel(cs, section),
                            const Divider(height: 1),
                            for (final r in reports) ...[
                              _reportTile(context, cs, r),
                              Divider(height: 1, color: cs.outlineVariant),
                            ],
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),

        // ── Filter panel ─────────────────────────────────────────────────────
        if (selected != null) ...[
          VerticalDivider(width: 1, color: cs.outlineVariant),
          _FilterPanel(
            reportId: selected!.id,
            filter: filter,
            onFilterChanged: onFilterChanged,
            onShowReport: onShowReport,
            onExportCsv: onExportCsv,
          ),
        ],
      ],
    );
  }
}

// ─── PDF preview tab ──────────────────────────────────────────────────────────

class _TabPdfView extends ConsumerWidget {
  final _OpenTab tab;
  const _TabPdfView({required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    // Every `_build*Pdf` takes this: the builders are top-level functions with
    // no BuildContext of their own, so the strings they print have to be handed
    // down from here.
    final l = AppLocalizations.of(context);
    final company = ref.watch(selectedCompanyProvider);
    final customers = ref.watch(allCustomersProvider).value ?? [];
    final users = ref.watch(allUsersProvider).value ?? [];
    final products = ref.watch(allProductsListProvider).value ?? [];

    // Every report names itself after what it is plus the range it covers, so
    // two exports of the same report don't overwrite each other on disk. Built
    // from the tab, so a new report type gets a real name without touching this.
    final baseName = reportPdfName(
      _reportLabel(context, tab.reportType.id),
      tab.filter.startDate,
      tab.filter.endDate,
    );
    final fileName = '$baseName.pdf';

    // "Save as PDF", shared by all report previews. `build` hands back the bytes
    // of whichever report is on screen, so this one action covers every type.
    final saveActions = <Widget>[
      PdfPreviewAction(
        icon: const Icon(Icons.save_alt),
        onPressed: (ctx, build, pageFormat) async {
          final messenger = ScaffoldMessenger.of(ctx);
          // Resolved up front, for the same reason `messenger` is: the save
          // dialog is an async gap and `ctx` may be gone by the time it returns.
          final l10n = AppLocalizations.of(ctx);
          try {
            final bytes = await build(pageFormat);
            final path = await savePdfAs(bytes: bytes, suggestedName: baseName);
            if (path == null) return; // cancelled
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.savedToPath(path))),
            );
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.saveFailed(e.toString()))),
            );
          }
        },
      ),
    ];

    String customerLabel() {
      if (tab.filter.customerId == null) return l.filterAll;
      return customers
              .where((c) => c.id == tab.filter.customerId)
              .map((c) => c.name)
              .firstOrNull ??
          l.filterAll;
    }

    String userLabel() {
      if (tab.filter.userId == null) return l.filterAll;
      return users
              .where((u) => u.id == tab.filter.userId)
              .map((u) => '${u.firstName ?? ''} ${u.lastName ?? ''}'.trim())
              .firstOrNull ??
          l.filterAll;
    }

    String productLabel() {
      if (tab.filter.productId == null) return l.filterAll;
      return products
              .where((p) => p.id == tab.filter.productId)
              .map((p) => p.name)
              .firstOrNull ??
          l.filterAll;
    }

    if (tab.reportType.id == 'sales_by_product') {
      final async = ref.watch(salesByProductProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildProductsPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_by_group') {
      final async = ref.watch(salesByProductGroupProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildProductGroupsPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_by_customer') {
      final async = ref.watch(salesByCustomerProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildCustomersPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_tax') {
      final async = ref.watch(salesByTaxProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildTaxPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_payment_by_customer') {
      final async = ref.watch(paymentTypesByCustomerProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPaymentTypesByCustomerPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_payment_by_user') {
      final async = ref.watch(paymentTypesByUserProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPaymentTypesByUserPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_payment_types') {
      final async = ref.watch(salesByPaymentTypeProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPaymentTypesPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_refunds') {
      final async = ref.watch(refundItemListProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildRefundsPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_invoice_list') {
      final async = ref.watch(invoiceListProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildInvoiceListPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_daily') {
      final async = ref.watch(dailySalesProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildDailySalesPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_hourly') {
      final async = ref.watch(hourlySalesProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildHourlySalesPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_hourly_group') {
      final async = ref.watch(hourlySalesByGroupProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildHourlySalesByGroupPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_by_table') {
      final async = ref.watch(salesByTableProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildSalesByTablePdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_profit') {
      final async = ref.watch(profitProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildProfitPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_unpaid') {
      final async = ref.watch(unpaidSalesProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildUnpaidSalesPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_starting_cash') {
      final async = ref.watch(startingCashReportProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildStartingCashPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            userLabel: userLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_stock_movement') {
      final async = ref.watch(stockMovementReportProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildStockMovementPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_item_discounts') {
      final async = ref.watch(itemsDiscountsReportProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildItemsDiscountsPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_discounts') {
      final async = ref.watch(discountsGrantedReportProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildDiscountsGrantedPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_discounts_by_source') {
      final async = ref.watch(discountsBySourceReportProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildDiscountsBySourcePdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_voided') {
      final async = ref.watch(voidedItemsReportProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildVoidedItemsPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_item_list') {
      final async = ref.watch(salesItemListProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildItemListPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'sales_users') {
      final async = ref.watch(salesByUserProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildUsersPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'purchase_unpaid') {
      final async = ref.watch(unpaidPurchaseProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildUnpaidPurchasePdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            supplierLabel: customerLabel(),
            userLabel: userLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'purchase_suppliers') {
      final async = ref.watch(purchaseBySupplierProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPurchaseBySupplierPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            supplierLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'purchase_products') {
      final async = ref.watch(purchaseByProductProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPurchaseByProductPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            supplierLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'purchase_tax') {
      final async = ref.watch(purchaseByTaxProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPurchaseTaxPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'purchase_expiration') {
      final async = ref.watch(purchaseExpirationDateProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPurchaseExpirationDatePdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            customerLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'purchase_invoice_list') {
      final async = ref.watch(purchaseInvoiceListProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPurchaseInvoiceListPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            supplierLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'purchase_items_discounts') {
      final async = ref.watch(purchaseItemsDiscountsProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPurchaseItemsDiscountsPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            supplierLabel: customerLabel(),
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'purchase_discounts') {
      final async = ref.watch(purchaseDiscountsProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPurchaseDiscountsPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            supplierLabel: customerLabel(),
            userLabel: userLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'stock_return_products') {
      final async = ref.watch(stockReturnByProductProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildStockReturnByProductPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'loss_and_damage_products') {
      final async = ref.watch(lossAndDamageByProductProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildLossAndDamageByProductPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            userLabel: userLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'reorder_list') {
      final async = ref.watch(reorderProductListProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildReorderProductListPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            supplierLabel: customerLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'low_stock_warning') {
      final async = ref.watch(lowStockWarningProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildLowStockWarningPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            supplierLabel: customerLabel(),
            productLabel: productLabel(),
          ),
        ),
      );
    }

    if (tab.reportType.id == 'transaction_history') {
      if (tab.filter.customerId == null) {
        return Center(
          child: Text(
            AppLocalizations.of(context).selectBusinessPartnerInFilter,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        );
      }
      final async = ref.watch(transactionHistoryProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => PdfPreview(
          pdfFileName: fileName,
          actions: saveActions,
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildTransactionHistoryPdf(
            l: l,
            rows: rows,
            filter: tab.filter,
            companyName: company?.name,
            companyAddress: company?.address,
            partnerLabel: customerLabel(),
          ),
        ),
      );
    }

    return Center(
      child: Text(
        AppLocalizations.of(context).reportComingSoon,
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
    );
  }
}

// ─── PDF builder functions ────────────────────────────────────────────────────

// ─── Fonts and text helpers for the report PDFs ───────────────────────────────

/// The four faces every report draws with, plus the styles that carry them.
///
/// 🚨 The faces must be named in the STYLE, not only in the page theme. Arabic
/// is shaped into presentation forms (U+FE70–FEFF) and those resolve correctly
/// only when the Arabic face is the run's BASE font — which is the swap
/// `styleForScript` performs, and it can only perform it if the style lists the
/// Arabic face in `fontFallback`. A style that inherits its fonts from the
/// theme leaves `fontFallback` empty, `styleForScript` returns it untouched,
/// and the report prints Arabic as disconnected letters running backwards.
/// See `printer/printed_text.dart` for the whole story.
class _RptFonts {
  final pw.Font latin;
  final pw.Font latinBold;
  final pw.Font arabic;
  final pw.Font arabicBold;
  const _RptFonts(this.latin, this.latinBold, this.arabic, this.arabicBold);

  static Future<_RptFonts> load() async => _RptFonts(
    await PdfFonts.latin(),
    await PdfFonts.latin(bold: true),
    await PdfFonts.arabic(),
    await PdfFonts.arabic(bold: true),
  );

  pw.ThemeData get theme => pw.ThemeData.withFont(
    base: latin,
    bold: latinBold,
    fontFallback: [arabic],
  );

  /// A style that names both faces at the weight asked for, so
  /// [styleForScript] can promote the Arabic one for an Arabic run.
  pw.TextStyle style({double size = 9, bool bold = false, PdfColor? color}) =>
      pw.TextStyle(
        font: bold ? latinBold : latin,
        fontFallback: [bold ? arabicBold : arabic],
        fontWeight: bold ? pw.FontWeight.bold : null,
        fontSize: size,
        color: color,
      );
}

/// A label and its value as TWO runs rather than one.
///
/// 🚨 Replaces the `pw.RichText` + two `pw.TextSpan` the reports used to build.
/// A TextSpan gets no direction of its own, so an Arabic label went unshaped;
/// and a single run holding both scripts comes out with its Latin half
/// reversed (`FUTUR3` → `3RUTUF`). Two runs means each picks its own.
pw.Widget _hdrPair(
  _RptFonts f,
  String label,
  String value, {
  double size = 9,
  bool boldLabel = true,
  bool boldValue = false,
  PdfColor? color,
}) => pw.Row(
  mainAxisSize: pw.MainAxisSize.min,
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    printedText(
      label,
      style: f.style(size: size, bold: boldLabel, color: color),
    ),
    // 🚨 The ':' is its own run, and the label must arrive WITHOUT one.
    // A colon is a neutral character: left at the end of an Arabic label it
    // is moved by the bidi pass to that run's visual LEFT end, so the pair
    // printed as `:الشركة FUTUR3` — the colon detached on the far side of
    // the label instead of introducing the value. On its own it stays
    // between the two in either script.
    printedText(
      ': ',
      style: f.style(size: size, bold: boldLabel, color: color),
    ),
    pw.Flexible(
      child: printedText(
        value,
        style: f.style(size: size, bold: boldValue, color: color),
      ),
    ),
  ],
);

/// Table cells as WIDGETS.
///
/// `TableHelper.fromTextArray` renders a plain-string cell with a bare
/// `pw.Text` and no direction, which is the unshaped-Arabic bug again. It uses
/// a cell verbatim when it already is a widget, so every header and every data
/// cell goes through [printedText] instead.
List<pw.Widget> _cells(List<String> values, pw.TextStyle style) => [
  for (final v in values) printedText(v, style: style),
];

Future<Uint8List> _buildProductsPdf({
  required AppLocalizations l,
  required List<SalesByProductRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      build: (ctx) => [
        printedText(
          l.rptTitleSalesByProduct,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          customerLabel,
          userLabel,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.rptColUom,
            l.totalBeforeTax,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            2: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map(
              (r) => [
                r.code ?? '',
                r.product,
                formatReportQuantity(r.quantity),
                r.uom,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ],
            ),
            [
              '',
              l.totalLabel,
              formatReportQuantity(rows.fold(0.0, (s, r) => s + r.quantity)),
              '',
              fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
            ],
          ],
          columnWidths: const {
            0: pw.FixedColumnWidth(60),
            1: pw.FlexColumnWidth(3),
            2: pw.FixedColumnWidth(70),
            3: pw.FixedColumnWidth(50),
            4: pw.FixedColumnWidth(90),
            5: pw.FixedColumnWidth(90),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildProductGroupsPdf({
  required AppLocalizations l,
  required List<SalesByProductGroupRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      build: (ctx) => [
        printedText(
          l.rptTitleSalesByGroup,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          customerLabel,
          userLabel,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.fieldProductGroup,
            l.fieldQuantity,
            l.totalBeforeTax,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map(
              (r) => [
                r.productGroup,
                formatReportQuantity(r.quantity),
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ],
            ),
            [
              l.totalLabel,
              formatReportQuantity(rows.fold(0.0, (s, r) => s + r.quantity)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
            ],
          ],
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FixedColumnWidth(80),
            2: pw.FixedColumnWidth(100),
            3: pw.FixedColumnWidth(100),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildTaxPdf({
  required AppLocalizations l,
  required List<SalesByTaxRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      build: (ctx) => [
        printedText(l.rptTitleSalesTax, style: f.style(size: 16, bold: true)),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          customerLabel,
          userLabel,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.rptColTaxName,
            l.totalBeforeTax,
            l.fieldTax,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map(
              (r) => [
                r.taxName,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.taxAmount),
                fmt.format(r.total),
              ],
            ),
            [
              l.totalLabel,
              fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.taxAmount)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
            ],
          ],
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FixedColumnWidth(100),
            2: pw.FixedColumnWidth(80),
            3: pw.FixedColumnWidth(100),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildCustomersPdf({
  required AppLocalizations l,
  required List<SalesByCustomerRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      build: (ctx) => [
        printedText(
          l.rptTitleSalesByCustomer,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          customerLabel,
          userLabel,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.customerLabel,
            l.totalBeforeTax,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map(
              (r) => [
                r.customer,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ],
            ),
            [
              l.totalLabel,
              fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
            ],
          ],
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FixedColumnWidth(100),
            2: pw.FixedColumnWidth(100),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildPaymentTypesByCustomerPdf({
  required AppLocalizations l,
  required List<PaymentTypesByCustomerRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  final paymentTypes = rows.map((r) => r.paymentTypeName).toSet().toList()
    ..sort();
  final customers = rows.map((r) => r.customerName).toSet().toList()..sort();
  final pivot = <String, Map<String, double>>{};
  for (final r in rows) {
    pivot.putIfAbsent(r.customerName, () => {});
    pivot[r.customerName]![r.paymentTypeName] =
        (pivot[r.customerName]![r.paymentTypeName] ?? 0) + r.amount;
  }

  final colWidths = <int, pw.FixedColumnWidth>{
    0: const pw.FixedColumnWidth(80),
  };
  for (var i = 1; i <= paymentTypes.length; i++) {
    colWidths[i] = const pw.FixedColumnWidth(80);
  }
  colWidths[paymentTypes.length + 1] = const pw.FixedColumnWidth(80);

  final grandAmounts = paymentTypes
      .map((pt) => customers.fold(0.0, (s, c) => s + (pivot[c]?[pt] ?? 0.0)))
      .toList();
  final grandTotal = rows.fold(0.0, (s, r) => s + r.amount);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      build: (ctx) => [
        printedText(
          l.rptTitlePaymentByCustomer,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          customerLabel,
          userLabel,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.customerLabel,
            ...paymentTypes,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            for (var i = 1; i <= paymentTypes.length + 1; i++)
              i: pw.Alignment.centerRight,
          },
          columnWidths: colWidths,
          data: [
            ...customers.map((c) {
              final amounts = paymentTypes
                  .map((pt) => pivot[c]?[pt] ?? 0.0)
                  .toList();
              final rowTotal = amounts.fold(0.0, (s, a) => s + a);
              return [c, ...amounts.map(fmt.format), fmt.format(rowTotal)];
            }),
            [
              l.totalLabel,
              ...grandAmounts.map(fmt.format),
              fmt.format(grandTotal),
            ],
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildPaymentTypesByUserPdf({
  required AppLocalizations l,
  required List<PaymentTypesByUserRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  final paymentTypes = rows.map((r) => r.paymentTypeName).toSet().toList()
    ..sort();
  final users = rows.map((r) => r.userName).toSet().toList()..sort();
  final pivot = <String, Map<String, double>>{};
  for (final r in rows) {
    pivot.putIfAbsent(r.userName, () => {});
    pivot[r.userName]![r.paymentTypeName] =
        (pivot[r.userName]![r.paymentTypeName] ?? 0) + r.amount;
  }

  final colWidths = <int, pw.FixedColumnWidth>{
    0: const pw.FixedColumnWidth(80),
  };
  for (var i = 1; i <= paymentTypes.length; i++) {
    colWidths[i] = const pw.FixedColumnWidth(80);
  }
  colWidths[paymentTypes.length + 1] = const pw.FixedColumnWidth(80);

  final grandAmounts = paymentTypes
      .map((pt) => users.fold(0.0, (s, u) => s + (pivot[u]?[pt] ?? 0.0)))
      .toList();
  final grandTotal = rows.fold(0.0, (s, r) => s + r.amount);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      build: (ctx) => [
        printedText(
          l.rptTitlePaymentByUser,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          customerLabel,
          userLabel,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            '',
            ...paymentTypes,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            for (var i = 1; i <= paymentTypes.length + 1; i++)
              i: pw.Alignment.centerRight,
          },
          columnWidths: colWidths,
          data: [
            ...users.map((u) {
              final amounts = paymentTypes
                  .map((pt) => pivot[u]?[pt] ?? 0.0)
                  .toList();
              final rowTotal = amounts.fold(0.0, (s, a) => s + a);
              return [u, ...amounts.map(fmt.format), fmt.format(rowTotal)];
            }),
            [
              l.totalLabel,
              ...grandAmounts.map(fmt.format),
              fmt.format(grandTotal),
            ],
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildPaymentTypesPdf({
  required AppLocalizations l,
  required List<SalesByPaymentTypeRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  // Pivot data
  final paymentTypes = rows.map((r) => r.paymentTypeName).toSet().toList()
    ..sort();
  final dates = rows.map((r) => r.date).toSet().toList()..sort();
  final pivot = <DateTime, Map<String, double>>{};
  for (final r in rows) {
    pivot.putIfAbsent(r.date, () => {});
    pivot[r.date]![r.paymentTypeName] =
        (pivot[r.date]![r.paymentTypeName] ?? 0) + r.amount;
  }

  // Build dynamic column widths: Date + one per payment type + Total
  final colWidths = <int, pw.FixedColumnWidth>{
    0: const pw.FixedColumnWidth(60),
  };
  for (var i = 1; i <= paymentTypes.length; i++) {
    colWidths[i] = const pw.FixedColumnWidth(80);
  }
  colWidths[paymentTypes.length + 1] = const pw.FixedColumnWidth(80);

  // Grand totals per payment type
  final grandAmounts = paymentTypes
      .map((pt) => dates.fold(0.0, (s, d) => s + (pivot[d]?[pt] ?? 0.0)))
      .toList();
  final grandTotal = rows.fold(0.0, (s, r) => s + r.amount);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      build: (ctx) => [
        printedText(
          l.rptTitlePaymentTypes,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          customerLabel,
          userLabel,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.dateLabel,
            ...paymentTypes,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            for (var i = 1; i <= paymentTypes.length + 1; i++)
              i: pw.Alignment.centerRight,
          },
          columnWidths: colWidths,
          data: [
            ...dates.map((d) {
              final amounts = paymentTypes
                  .map((pt) => pivot[d]?[pt] ?? 0.0)
                  .toList();
              final rowTotal = amounts.fold(0.0, (s, a) => s + a);
              return [
                dateFmt.format(d),
                ...amounts.map(fmt.format),
                fmt.format(rowTotal),
              ];
            }),
            // Grand total row
            ['', ...grandAmounts.map(fmt.format), fmt.format(grandTotal)],
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildItemListPdf({
  required AppLocalizations l,
  required List<SalesItemListRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');
  final dtFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(20),
      build: (ctx) => [
        printedText(l.rptTitleItemList, style: f.style(size: 16, bold: true)),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          customerLabel,
          userLabel,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style(size: 7)),
          headers: _cells([
            l.documentType,
            l.dateLabel,
            l.rptColCreateDate,
            l.documentNumber,
            l.rptColRefNumber,
            l.rptColCustomerCode,
            l.customerLabel,
            l.orderNumberLabel,
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.rptColUom,
            l.totalBeforeTax,
            l.rptColTotalTax,
            l.totalLabel,
          ], f.style(size: 7, bold: true)),
          headerStyle: f.style(size: 7, bold: true),
          cellStyle: f.style(size: 7),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            10: pw.Alignment.centerRight,
            12: pw.Alignment.centerRight,
            13: pw.Alignment.centerRight,
            14: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map(
              (r) => [
                r.documentTypeName,
                dateFmt.format(r.date),
                dtFmt.format(r.dateCreated),
                r.documentNumber,
                r.refNumber ?? '',
                r.customerCode ?? '',
                r.customerName,
                r.orderNumber ?? '',
                r.productCode ?? '',
                r.productName,
                formatReportQuantity(r.quantity),
                r.uom,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.totalTax),
                fmt.format(r.total),
              ],
            ),
            [
              '',
              '',
              '',
              '',
              '',
              '',
              '',
              '',
              '',
              l.totalLabel,
              formatReportQuantity(rows.fold(0.0, (s, r) => s + r.quantity)),
              '',
              fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.totalTax)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
            ],
          ],
          columnWidths: const {
            0: pw.FixedColumnWidth(40),
            1: pw.FixedColumnWidth(42),
            2: pw.FixedColumnWidth(68),
            3: pw.FixedColumnWidth(68),
            4: pw.FixedColumnWidth(38),
            5: pw.FixedColumnWidth(45),
            6: pw.FlexColumnWidth(1.5),
            7: pw.FixedColumnWidth(36),
            8: pw.FixedColumnWidth(32),
            9: pw.FlexColumnWidth(2),
            10: pw.FixedColumnWidth(42),
            11: pw.FixedColumnWidth(26),
            12: pw.FixedColumnWidth(52),
            13: pw.FixedColumnWidth(46),
            14: pw.FixedColumnWidth(52),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildProfitPdf({
  required AppLocalizations l,
  required List<ProfitRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final pctFmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  final grandQty = rows.fold(0.0, (s, r) => s + r.quantity);
  final grandCost = rows.fold(0.0, (s, r) => s + r.cost);
  final grandTotal = rows.fold(0.0, (s, r) => s + r.total);
  final grandProfit = grandTotal - grandCost;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(20),
      build: (ctx) => [
        printedText(l.rptTitleProfit, style: f.style(size: 16, bold: true)),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _hdrPair(
                    f,
                    l.periodLabel,
                    '${dateFmt.format(filter.startDate)} - ${dateFmt.format(filter.endDate)}',
                  ),
                  _hdrPair(f, l.customerLabel, customerLabel),
                  _hdrPair(f, l.userLabel, userLabel),
                  _hdrPair(f, l.productLabel, productLabel),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _hdrPair(f, l.rptColCompany, companyName ?? ''),
                  _hdrPair(f, l.setAddress, companyAddress ?? ''),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.fieldCost,
            l.totalLabel,
            l.rptColProfit,
            l.rptColMargin,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
            6: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map(
              (r) => [
                r.productCode ?? '',
                r.productName,
                formatReportQuantity(r.quantity),
                fmt.format(r.cost),
                fmt.format(r.total),
                fmt.format(r.profit),
                '${pctFmt.format(r.margin)}%',
              ],
            ),
            [
              '',
              '',
              fmt.format(grandQty),
              fmt.format(grandCost),
              fmt.format(grandTotal),
              fmt.format(grandProfit),
              '',
            ],
          ],
          columnWidths: const {
            0: pw.FixedColumnWidth(40),
            1: pw.FlexColumnWidth(2),
            2: pw.FixedColumnWidth(52),
            3: pw.FixedColumnWidth(60),
            4: pw.FixedColumnWidth(60),
            5: pw.FixedColumnWidth(60),
            6: pw.FixedColumnWidth(52),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildStockMovementPdf({
  required AppLocalizations l,
  required List<StockMovementRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final hdrFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  final total = rows.fold(0.0, (s, r) => s + r.numSales);
  final average = rows.isEmpty ? 0.0 : total / rows.length;

  final fast = rows.where((r) => r.numSales >= average).toList()
    ..sort((a, b) => b.numSales.compareTo(a.numSales));
  final slow = rows.where((r) => r.numSales < average).toList()
    ..sort((a, b) => b.numSales.compareTo(a.numSales));

  pw.Widget hdrRow(String label, String value) => _hdrPair(f, label, value);

  // `isFast` used to be inferred by comparing the title against the literal
  // 'Fast moving'; once that title is translated the comparison never matches
  // and every section renders grey. The caller states it instead.
  pw.Widget sectionTable(
    String title,
    List<StockMovementRow> items, {
    required bool isFast,
  }) => pw.Column(
    children: [
      pw.TableHelper.fromTextArray(
        cellBuilder: (i, v, r) => printedText('$v', style: f.style(size: 8)),
        headers: _cells([
          '#',
          title,
          l.rptColNumSales,
        ], f.style(size: 8, bold: true)),
        headerStyle: f.style(size: 8, bold: true),
        cellStyle: f.style(size: 8),
        headerDecoration: pw.BoxDecoration(
          color: isFast ? PdfColors.red100 : PdfColors.grey200,
        ),
        cellAlignments: {
          0: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
        },
        columnWidths: const {
          0: pw.FixedColumnWidth(24),
          1: pw.FlexColumnWidth(1),
          2: pw.FixedColumnWidth(80),
        },
        data: items
            .asMap()
            .entries
            .map(
              (e) => [
                '${e.key + 1}',
                e.value.productName,
                e.value.numSales.toStringAsFixed(0),
              ],
            )
            .toList(),
      ),
      pw.SizedBox(height: 8),
    ],
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(24),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8, color: PdfColors.red),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitleStockMovement,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  hdrRow(
                    l.periodLabel,
                    '${hdrFmt.format(filter.startDate)} - ${hdrFmt.format(filter.endDate)}',
                  ),
                  hdrRow(l.userLabel, userLabel),
                  hdrRow(l.productLabel, productLabel),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  hdrRow(l.rptColCompany, companyName ?? ''),
                  hdrRow(l.setAddress, companyAddress ?? ''),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                printedText(
                  l.rptTotalNumberOfSales(total.toStringAsFixed(0)),
                  style: f.style(),
                ),
                printedText(
                  l.rptAverageSalesPerItem(average.toStringAsFixed(0)),
                  style: f.style(),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        if (fast.isNotEmpty) sectionTable(l.rptFastMoving, fast, isFast: true),
        if (slow.isNotEmpty) sectionTable(l.rptSlowMoving, slow, isFast: false),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildItemsDiscountsPdf({
  required AppLocalizations l,
  required List<ItemsDiscountsRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final hdrFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  final grandTotal = rows.fold(0.0, (s, r) => s + r.totalDiscount);

  pw.Widget hdrRow(String label, String value) => _hdrPair(f, label, value);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(24),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8, color: PdfColors.red),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitleItemDiscounts,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  hdrRow(
                    l.periodLabel,
                    '${hdrFmt.format(filter.startDate)} - ${hdrFmt.format(filter.endDate)}',
                  ),
                  hdrRow(l.customerLabel, customerLabel),
                  hdrRow(l.userLabel, userLabel),
                  hdrRow(l.productLabel, productLabel),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  hdrRow(l.rptColCompany, companyName ?? ''),
                  hdrRow(l.setAddress, companyAddress ?? ''),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style(size: 8)),
          headers: _cells([
            '#',
            l.fieldCode,
            l.productLabel,
            l.rptColTotalDiscount,
          ], f.style(size: 8, bold: true)),
          headerStyle: f.style(size: 8, bold: true),
          cellStyle: f.style(size: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            0: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          columnWidths: const {
            0: pw.FixedColumnWidth(24),
            1: pw.FixedColumnWidth(50),
            2: pw.FlexColumnWidth(1),
            3: pw.FixedColumnWidth(80),
          },
          data: rows
              .asMap()
              .entries
              .map(
                (e) => [
                  '${e.key + 1}',
                  e.value.productCode ?? '',
                  e.value.productName,
                  fmt.format(e.value.totalDiscount),
                ],
              )
              .toList(),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: printedText(
                fmt.format(grandTotal),
                style: f.style(bold: true),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildDiscountsBySourcePdf({
  required AppLocalizations l,
  required List<DiscountBySourceRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  final grandTotal = rows.fold(0.0, (s, r) => s + r.amount);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(24),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8, color: PdfColors.red),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitleDiscountsBySource,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          l.filterAll,
          l.filterAll,
          l.filterAll,
        ),
        pw.SizedBox(height: 12),
        if (rows.isEmpty)
          printedText(l.rptNoDiscountsInPeriod, style: f.style(size: 10))
        else
          pw.TableHelper.fromTextArray(
            cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
            headers: _cells([
              l.rptColDiscountSource,
              l.totalLabel,
            ], f.style(bold: true)),
            headerStyle: f.style(bold: true),
            cellStyle: f.style(),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
            },
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FixedColumnWidth(90),
            },
            data: [
              for (final r in rows) [r.label, fmt.format(r.amount)],
              [l.totalLabel, fmt.format(grandTotal)],
            ],
          ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildDiscountsGrantedPdf({
  required AppLocalizations l,
  required List<DiscountsGrantedRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');
  final hdrFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  // Group by customer (order preserved from backend: alphabetical)
  final grouped = <String, List<DiscountsGrantedRow>>{};
  for (final r in rows) {
    grouped.putIfAbsent(r.customerName, () => []).add(r);
  }

  final grandTotal = rows.fold(0.0, (s, r) => s + r.discountGranted);
  final totalOrders = rows.length;

  pw.Widget hdrRow(String label, String value) => _hdrPair(f, label, value);

  const colWidths = {
    0: pw.FlexColumnWidth(1.5),
    1: pw.FixedColumnWidth(58),
    2: pw.FixedColumnWidth(58),
    3: pw.FixedColumnWidth(62),
    4: pw.FixedColumnWidth(62),
    5: pw.FixedColumnWidth(62),
  };

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(24),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8, color: PdfColors.red),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitleDiscountsGranted,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  hdrRow(
                    l.periodLabel,
                    '${hdrFmt.format(filter.startDate)} - ${hdrFmt.format(filter.endDate)}',
                  ),
                  hdrRow(l.customerLabel, customerLabel),
                  hdrRow(l.userLabel, userLabel),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  hdrRow(l.rptColCompany, companyName ?? ''),
                  hdrRow(l.setAddress, companyAddress ?? ''),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        for (final entry in grouped.entries) ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            child: _hdrPair(f, l.customerLabel, entry.key, boldValue: true),
          ),
          pw.TableHelper.fromTextArray(
            cellBuilder: (i, v, r) =>
                printedText('$v', style: f.style(size: 7)),
            headers: _cells([
              l.rptColDocument,
              l.dateLabel,
              l.userLabel,
              l.rptColTotalBeforeDisc,
              l.rptColTotalAfterDisc,
              l.rptColDiscountGranted,
            ], f.style(size: 7, bold: true)),
            headerStyle: f.style(size: 7, bold: true),
            cellStyle: f.style(size: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
            columnWidths: colWidths,
            data: [
              ...entry.value.map(
                (r) => [
                  r.documentNumber,
                  dateFmt.format(r.date),
                  r.userName,
                  fmt.format(r.totalBeforeDiscount),
                  fmt.format(r.totalAfterDiscount),
                  fmt.format(r.discountGranted),
                ],
              ),
              // Customer subtotal row
              [
                '',
                '',
                '',
                '',
                '',
                fmt.format(
                  entry.value.fold(0.0, (s, r) => s + r.discountGranted),
                ),
              ],
            ],
          ),
          pw.SizedBox(height: 6),
        ],
        pw.Divider(borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                printedText(
                  l.rptOrdersDiscounted('$totalOrders'),
                  style: f.style(),
                ),
                pw.SizedBox(height: 2),
                printedText(
                  l.rptTotalDiscounted(fmt.format(grandTotal)),
                  style: f.style(bold: true),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildVoidedItemsPdf({
  required AppLocalizations l,
  required List<VoidedItemRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dtFmt = DateFormat('dd/MM/yyyy HH:mm:ss');
  final hdrFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  final grandTotal = rows.fold(0.0, (s, r) => s + r.total);

  pw.Widget hdrRow(String label, String value) => _hdrPair(f, label, value);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(24),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8, color: PdfColors.red),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitleVoidedItems,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  hdrRow(
                    l.periodLabel,
                    '${hdrFmt.format(filter.startDate)} - ${hdrFmt.format(filter.endDate)}',
                  ),
                  hdrRow(l.userLabel, userLabel),
                  hdrRow(l.productLabel, productLabel),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  hdrRow(l.rptColCompany, companyName ?? ''),
                  hdrRow(l.setAddress, companyAddress ?? ''),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style(size: 7)),
          headers: _cells([
            l.productLabel,
            l.rptColVoidedBy,
            l.rptColQtyShort,
            l.priceLabel,
            l.discountLabel,
            l.statusLabel,
            l.rptColOrderNo,
            l.rptColCreated,
            l.rptColVoided,
            l.totalLabel,
            l.rptColReason,
          ], f.style(size: 7, bold: true)),
          headerStyle: f.style(size: 7, bold: true),
          cellStyle: f.style(size: 7),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            9: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map(
              (r) => [
                r.productName,
                r.voidedByName ?? '',
                r.quantity.toStringAsFixed(0),
                fmt.format(r.price),
                r.discountDisplay,
                r.isConfirmed ? l.rptStatusConfirmed : l.rptStatusPending,
                r.orderNumber,
                dtFmt.format(r.dateCreated),
                dtFmt.format(r.dateVoided),
                fmt.format(r.total),
                r.reason ?? '',
              ],
            ),
          ],
          columnWidths: const {
            0: pw.FlexColumnWidth(1.4),
            1: pw.FixedColumnWidth(48),
            2: pw.FixedColumnWidth(28),
            3: pw.FixedColumnWidth(40),
            4: pw.FixedColumnWidth(36),
            5: pw.FixedColumnWidth(52),
            6: pw.FixedColumnWidth(44),
            7: pw.FixedColumnWidth(72),
            8: pw.FixedColumnWidth(72),
            9: pw.FixedColumnWidth(44),
            10: pw.FlexColumnWidth(1.2),
          },
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: printedText(
                fmt.format(grandTotal),
                style: f.style(bold: true),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildStartingCashPdf({
  required AppLocalizations l,
  required List<StartingCashRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String userLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  final hdrFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  final totalCashIn = rows
      .where((r) => !r.isCashOut)
      .fold(0.0, (s, r) => s + r.amount);
  final totalCashOut = rows
      .where((r) => r.isCashOut)
      .fold(0.0, (s, r) => s + r.amount);
  final netTotal = totalCashIn - totalCashOut;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        printedText(
          l.rptTitleStartingCash,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _hdrPair(
                    f,
                    l.periodLabel,
                    '${hdrFmt.format(filter.startDate)} – ${hdrFmt.format(filter.endDate)}',
                  ),
                  _hdrPair(f, l.userLabel, userLabel),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _hdrPair(f, l.rptColCompany, companyName ?? ''),
                  _hdrPair(f, l.setAddress, companyAddress ?? ''),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style(size: 8)),
          headers: _cells([
            l.userLabel,
            l.typeLabel,
            l.fieldDescription,
            l.dateLabel,
            l.amount,
            l.rptColZReportNo,
          ], f.style(size: 8, bold: true)),
          headerStyle: f.style(size: 8, bold: true),
          cellStyle: f.style(size: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {4: pw.Alignment.centerRight},
          data: [
            ...rows.map(
              (r) => [
                r.userName ?? '',
                r.isCashOut ? l.cashOut : l.cashIn,
                r.description ?? '',
                dateFmt.format(r.dateCreated),
                r.isCashOut ? '-${fmt.format(r.amount)}' : fmt.format(r.amount),
                r.zReportNumber?.toString() ?? '',
              ],
            ),
          ],
          columnWidths: const {
            0: pw.FixedColumnWidth(80),
            1: pw.FixedColumnWidth(55),
            2: pw.FlexColumnWidth(),
            3: pw.FixedColumnWidth(80),
            4: pw.FixedColumnWidth(65),
            5: pw.FixedColumnWidth(50),
          },
        ),
        pw.SizedBox(height: 8),
        pw.Divider(
          borderStyle: pw.BorderStyle.dashed,
          color: PdfColors.grey400,
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _hdrPair(
                  f,
                  l.cashIn,
                  fmt.format(totalCashIn),
                  boldLabel: false,
                  boldValue: true,
                ),
                _hdrPair(
                  f,
                  l.cashOut,
                  '-${fmt.format(totalCashOut)}',
                  boldLabel: false,
                  boldValue: true,
                ),
                _hdrPair(
                  f,
                  l.rptNetTotal,
                  fmt.format(netTotal),
                  size: 10,
                  boldValue: true,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildUnpaidSalesPdf({
  required AppLocalizations l,
  required List<UnpaidSalesRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');
  final hdrDatFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  // Group by customer (data already sorted by customerName from backend)
  final byCustomer = <String, List<UnpaidSalesRow>>{};
  for (final r in rows) {
    byCustomer.putIfAbsent(r.customerName, () => []).add(r);
  }
  final grandTotal = rows.fold(0.0, (s, r) => s + r.totalUnpaid);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(20),
      build: (ctx) {
        final widgets = <pw.Widget>[
          printedText(
            l.rptTitleUnpaidSales,
            style: f.style(size: 16, bold: true),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _hdrPair(
                      f,
                      l.periodLabel,
                      '${hdrDatFmt.format(filter.startDate)} - ${hdrDatFmt.format(filter.endDate)}',
                    ),
                    _hdrPair(f, l.customerLabel, customerLabel),
                    _hdrPair(f, l.userLabel, userLabel),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _hdrPair(f, l.rptColCompany, companyName ?? ''),
                    _hdrPair(f, l.setAddress, companyAddress ?? ''),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
        ];

        for (final entry in byCustomer.entries) {
          final customerName = entry.key;
          final docs = entry.value;
          final customerUnpaid = docs.fold(0.0, (s, r) => s + r.totalUnpaid);

          widgets.add(
            pw.Container(
              color: PdfColors.grey200,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              child: _hdrPair(
                f,
                l.customerLabel,
                customerName,
                boldValue: true,
              ),
            ),
          );

          widgets.add(
            pw.TableHelper.fromTextArray(
              cellBuilder: (i, v, r) =>
                  printedText('$v', style: f.style(size: 8)),
              headers: _cells([
                l.documentNumber,
                l.dateLabel,
                l.rptColDueDate,
                l.totalLabel,
                l.rptColTotalPaid,
                l.rptColTotalUnpaid,
              ], f.style(size: 8, bold: true)),
              headerStyle: f.style(size: 8, bold: true),
              cellStyle: f.style(size: 8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignments: {
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              data: [
                ...docs.map(
                  (r) => [
                    r.documentNumber,
                    dateFmt.format(r.date),
                    r.dueDate != null ? dateFmt.format(r.dueDate!) : '',
                    fmt.format(r.documentTotal),
                    fmt.format(r.totalPaid),
                    fmt.format(r.totalUnpaid),
                  ],
                ),
                ['', '', '', '', '', fmt.format(customerUnpaid)],
              ],
              columnWidths: const {
                0: pw.FixedColumnWidth(90),
                1: pw.FixedColumnWidth(60),
                2: pw.FixedColumnWidth(60),
                3: pw.FixedColumnWidth(60),
                4: pw.FixedColumnWidth(60),
                5: pw.FixedColumnWidth(70),
              },
            ),
          );

          widgets.add(pw.SizedBox(height: 6));
        }

        widgets.addAll([
          pw.Divider(
            borderStyle: pw.BorderStyle.dashed,
            color: PdfColors.grey400,
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              _hdrPair(
                f,
                l.totalLabel,
                fmt.format(grandTotal),
                size: 10,
                boldValue: true,
              ),
            ],
          ),
        ]);

        return widgets;
      },
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildHourlySalesByGroupPdf({
  required AppLocalizations l,
  required List<HourlySalesByGroupRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');
  final timeFmt = DateFormat('h:mm a');

  final f = await _RptFonts.load();
  final theme = f.theme;

  final hours = rows.map((r) => r.hour).toSet().toList()..sort();
  final groups = rows.map((r) => r.productGroup).toSet().toList()..sort();
  final pivot = <String, Map<int, double>>{};
  for (final r in rows) {
    pivot.putIfAbsent(r.productGroup, () => {})[r.hour] =
        (pivot[r.productGroup]![r.hour] ?? 0) + r.total;
  }
  final groupTotals = <String, double>{
    for (final g in groups)
      g: hours.fold(0.0, (s, h) => s + (pivot[g]?[h] ?? 0.0)),
  };
  final hourTotals = <int, double>{
    for (final h in hours)
      h: groups.fold(0.0, (s, g) => s + (pivot[g]?[h] ?? 0.0)),
  };
  final grandTotal = rows.fold(0.0, (s, r) => s + r.total);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(20),
      build: (ctx) => [
        printedText(
          l.rptTitleHourlyByGroup,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        // 🚨 A pw.Row wrapping a single, un-Expanded pw.Column gives that
        // Column unbounded width, which _hdrPair's own Flexible value run
        // can't resolve ("Flex children have non-zero flex but incoming
        // width constraints are unbounded") — crashed this report the moment
        // it rendered (found 2026-09-01, POS_Manual_tests_NOTES.txt [35]).
        // No Row needed for a single child; the Column alone gets the page's
        // bounded width directly, same as every other top-level build item.
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _hdrPair(f, l.rptColCompany, companyName ?? ''),
            _hdrPair(f, l.setAddress, companyAddress ?? ''),
          ],
        ),
        pw.Divider(height: 12),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _hdrPair(
              f,
              l.periodLabel,
              '${dateFmt.format(filter.startDate)} - ${dateFmt.format(filter.endDate)}',
            ),
            _hdrPair(f, l.productLabel, productLabel),
            _hdrPair(f, l.customerLabel, customerLabel),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            '',
            ...hours.map((h) => timeFmt.format(DateTime(2000, 1, 1, h))),
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            for (var i = 1; i <= hours.length + 1; i++)
              i: pw.Alignment.centerRight,
          },
          data: [
            ...groups.map(
              (g) => [
                g,
                ...hours.map((h) => fmt.format(pivot[g]?[h] ?? 0.0)),
                fmt.format(groupTotals[g] ?? 0.0),
              ],
            ),
            [
              l.totalLabel,
              ...hours.map((h) => fmt.format(hourTotals[h] ?? 0.0)),
              fmt.format(grandTotal),
            ],
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildSalesByTablePdf({
  required AppLocalizations l,
  required List<SalesByTableRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  final grandCount = rows.fold(0, (s, r) => s + r.numberOfSales);
  final grandTotal = rows.fold(0.0, (s, r) => s + r.total);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(20),
      build: (ctx) => [
        printedText(l.rptTitleByTable, style: f.style(size: 16, bold: true)),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _hdrPair(
                    f,
                    l.periodLabel,
                    '${dateFmt.format(filter.startDate)} - ${dateFmt.format(filter.endDate)}',
                  ),
                  _hdrPair(f, l.customerLabel, customerLabel),
                  _hdrPair(f, l.userLabel, userLabel),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _hdrPair(f, l.rptColCompany, companyName ?? ''),
                  _hdrPair(f, l.setAddress, companyAddress ?? ''),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.rptColTableOrOrder,
            l.rptColNumberOfSales,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map(
              (r) => [r.orderNumber, '${r.numberOfSales}', fmt.format(r.total)],
            ),
            ['', '$grandCount', fmt.format(grandTotal)],
          ],
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FixedColumnWidth(80),
            2: pw.FixedColumnWidth(80),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildHourlySalesPdf({
  required AppLocalizations l,
  required List<HourlySalesRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final pctFmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');
  final timeFmt = DateFormat('h:mm a');

  final f = await _RptFonts.load();
  final theme = f.theme;

  final grandTotal = rows.fold(0.0, (s, r) => s + r.totalSales);
  final grandCount = rows.fold(0, (s, r) => s + r.salesCount);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(20),
      build: (ctx) => [
        printedText(
          l.rptTitleHourlySales,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _hdrPair(
                    f,
                    l.periodLabel,
                    '${dateFmt.format(filter.startDate)} - ${dateFmt.format(filter.endDate)}',
                  ),
                  _hdrPair(f, l.customerLabel, customerLabel),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _hdrPair(f, l.rptColCompany, companyName ?? ''),
                  _hdrPair(f, l.setAddress, companyAddress ?? ''),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.rptColHours,
            '',
            l.rptColTotalSales,
            l.rptColSalesCount,
            l.rptColAverageSale,
            '%',
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map((r) {
              final start = DateTime(2000, 1, 1, r.hour);
              final end = DateTime(2000, 1, 1, r.hour, 59);
              final avg = r.salesCount > 0 ? r.totalSales / r.salesCount : 0.0;
              final pct = grandTotal > 0
                  ? r.totalSales / grandTotal * 100
                  : 0.0;
              return [
                timeFmt.format(start),
                timeFmt.format(end),
                fmt.format(r.totalSales),
                '${r.salesCount}',
                fmt.format(avg),
                '${pctFmt.format(pct)}%',
              ];
            }),
            ['', '', fmt.format(grandTotal), '$grandCount', '', ''],
          ],
          columnWidths: const {
            0: pw.FixedColumnWidth(52),
            1: pw.FixedColumnWidth(52),
            2: pw.FixedColumnWidth(70),
            3: pw.FixedColumnWidth(60),
            4: pw.FixedColumnWidth(70),
            5: pw.FixedColumnWidth(52),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildDailySalesPdf({
  required AppLocalizations l,
  required List<DailySalesRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dayFmt = DateFormat('dd/MM/yyyy (EEE)');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(20),
      build: (ctx) => [
        printedText(l.rptTitleDailySales, style: f.style(size: 16, bold: true)),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _hdrPair(
                    f,
                    l.periodLabel,
                    '${dateFmt.format(filter.startDate)} - ${dateFmt.format(filter.endDate)}',
                  ),
                  _hdrPair(f, l.customerLabel, customerLabel),
                  _hdrPair(f, l.userLabel, userLabel),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _hdrPair(f, l.rptColCompany, companyName ?? ''),
                  _hdrPair(f, l.setAddress, companyAddress ?? ''),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([l.dateLabel, l.totalLabel], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {1: pw.Alignment.centerRight},
          data: [
            ...rows.map((r) => [dayFmt.format(r.date), fmt.format(r.total)]),
            ['', fmt.format(rows.fold(0.0, (s, r) => s + r.total))],
          ],
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FixedColumnWidth(80),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildInvoiceListPdf({
  required AppLocalizations l,
  required List<InvoiceListRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(20),
      build: (ctx) => [
        printedText(l.rptTitleInvoices, style: f.style(size: 16, bold: true)),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _hdrPair(
                    f,
                    l.periodLabel,
                    '${dateFmt.format(filter.startDate)} - ${dateFmt.format(filter.endDate)}',
                  ),
                  _hdrPair(f, l.customerLabel, customerLabel),
                  _hdrPair(f, l.userLabel, userLabel),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _hdrPair(f, l.rptColCompany, companyName ?? ''),
                  _hdrPair(f, l.setAddress, companyAddress ?? ''),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style(size: 8)),
          headers: _cells([
            '#',
            l.dateLabel,
            l.documentNumber,
            l.customerLabel,
            l.rptColPaymentMethod,
            l.totalLabel,
          ], f.style(size: 8, bold: true)),
          headerStyle: f.style(size: 8, bold: true),
          cellStyle: f.style(size: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            0: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          data: [
            ...rows.asMap().entries.map(
              (e) => [
                '${e.key + 1}',
                dateFmt.format(e.value.date),
                e.value.documentNumber,
                e.value.customerName,
                e.value.paymentMethodName,
                fmt.format(e.value.total),
              ],
            ),
            [
              '',
              '',
              '',
              '',
              l.totalLabel,
              fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
            ],
          ],
          columnWidths: const {
            0: pw.FixedColumnWidth(20),
            1: pw.FixedColumnWidth(54),
            2: pw.FixedColumnWidth(80),
            3: pw.FlexColumnWidth(2),
            4: pw.FlexColumnWidth(1.5),
            5: pw.FixedColumnWidth(60),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildRefundsPdf({
  required AppLocalizations l,
  required List<RefundItemListRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(20),
      build: (ctx) => [
        printedText(l.rptTitleRefunds, style: f.style(size: 16, bold: true)),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          customerLabel,
          userLabel,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style(size: 8)),
          headers: _cells([
            l.rptColDocumentShort,
            l.rptColRefShort,
            l.dateLabel,
            l.rptColCustomerCode,
            l.customerLabel,
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.rptColUom,
            l.totalBeforeTax,
            l.rptColTotalTax,
            l.totalLabel,
          ], f.style(size: 8, bold: true)),
          headerStyle: f.style(size: 8, bold: true),
          cellStyle: f.style(size: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            7: pw.Alignment.centerRight,
            9: pw.Alignment.centerRight,
            10: pw.Alignment.centerRight,
            11: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map(
              (r) => [
                r.documentNumber,
                r.refNumber ?? '',
                dateFmt.format(r.date),
                r.customerCode ?? '',
                r.customerName,
                r.productCode ?? '',
                r.productName,
                formatReportQuantity(r.quantity),
                r.uom,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.totalTax),
                fmt.format(r.total),
              ],
            ),
            [
              '',
              '',
              '',
              '',
              '',
              '',
              l.totalLabel,
              formatReportQuantity(rows.fold(0.0, (s, r) => s + r.quantity)),
              '',
              fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.totalTax)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
            ],
          ],
          columnWidths: const {
            0: pw.FixedColumnWidth(62),
            1: pw.FixedColumnWidth(46),
            2: pw.FixedColumnWidth(42),
            3: pw.FixedColumnWidth(46),
            4: pw.FlexColumnWidth(1.5),
            5: pw.FixedColumnWidth(32),
            6: pw.FlexColumnWidth(2),
            7: pw.FixedColumnWidth(42),
            8: pw.FixedColumnWidth(24),
            9: pw.FixedColumnWidth(52),
            10: pw.FixedColumnWidth(46),
            11: pw.FixedColumnWidth(52),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildUsersPdf({
  required AppLocalizations l,
  required List<SalesByUserRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      build: (ctx) => [
        printedText(
          l.rptTitleSalesByUsers,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          customerLabel,
          userLabel,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.userLabel,
            l.totalBeforeTax,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map(
              (r) => [
                r.user,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ],
            ),
            [
              l.totalLabel,
              fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
            ],
          ],
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FixedColumnWidth(100),
            2: pw.FixedColumnWidth(100),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildUnpaidPurchasePdf({
  required AppLocalizations l,
  required List<UnpaidPurchaseRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String supplierLabel,
  required String userLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');
  final hdrDatFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  final bySupplier = <String, List<UnpaidPurchaseRow>>{};
  for (final r in rows) {
    bySupplier.putIfAbsent(r.supplierName, () => []).add(r);
  }
  final grandTotal = rows.fold(0.0, (s, r) => s + r.totalUnpaid);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(20),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) {
        final widgets = <pw.Widget>[
          printedText(
            l.rptTitleUnpaidPurchase,
            style: f.style(size: 16, bold: true),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _hdrPair(
                      f,
                      l.periodLabel,
                      '${hdrDatFmt.format(filter.startDate)} - ${hdrDatFmt.format(filter.endDate)}',
                    ),
                    _hdrPair(f, l.supplier, supplierLabel),
                    _hdrPair(f, l.userLabel, userLabel),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _hdrPair(f, l.rptColCompany, companyName ?? ''),
                    _hdrPair(f, l.setAddress, companyAddress ?? ''),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
        ];

        for (final entry in bySupplier.entries) {
          final supplierName = entry.key;
          final docs = entry.value;
          final supplierUnpaid = docs.fold(0.0, (s, r) => s + r.totalUnpaid);

          widgets.add(
            pw.Container(
              color: PdfColors.grey200,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              child: _hdrPair(f, l.supplier, supplierName, boldValue: true),
            ),
          );

          widgets.add(
            pw.TableHelper.fromTextArray(
              cellBuilder: (i, v, r) =>
                  printedText('$v', style: f.style(size: 8)),
              headers: _cells([
                l.documentNumber,
                l.dateLabel,
                l.rptColDueDate,
                l.totalLabel,
                l.rptColTotalPaid,
                l.rptColTotalUnpaid,
              ], f.style(size: 8, bold: true)),
              headerStyle: f.style(size: 8, bold: true),
              cellStyle: f.style(size: 8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignments: {
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              data: [
                ...docs.map(
                  (r) => [
                    r.documentNumber,
                    dateFmt.format(r.date),
                    r.dueDate != null ? dateFmt.format(r.dueDate!) : '',
                    fmt.format(r.documentTotal),
                    fmt.format(r.totalPaid),
                    fmt.format(r.totalUnpaid),
                  ],
                ),
                ['', '', '', '', '', fmt.format(supplierUnpaid)],
              ],
              columnWidths: const {
                0: pw.FixedColumnWidth(100),
                1: pw.FixedColumnWidth(60),
                2: pw.FixedColumnWidth(60),
                3: pw.FixedColumnWidth(60),
                4: pw.FixedColumnWidth(60),
                5: pw.FixedColumnWidth(70),
              },
            ),
          );

          widgets.add(pw.SizedBox(height: 6));
        }

        widgets.addAll([
          pw.Divider(
            borderStyle: pw.BorderStyle.dashed,
            color: PdfColors.grey400,
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              _hdrPair(
                f,
                l.totalLabel,
                fmt.format(grandTotal),
                size: 10,
                boldValue: true,
              ),
            ],
          ),
        ]);

        return widgets;
      },
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildPurchaseBySupplierPdf({
  required AppLocalizations l,
  required List<PurchaseBySupplierRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String supplierLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitlePurchaseBySupplier,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          supplierLabel,
          userLabel,
          productLabel,
          customerRowLabel: l.supplier,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.supplier,
            l.totalBeforeTax,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map(
              (r) => [
                r.supplier,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ],
            ),
            [
              l.totalLabel,
              fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
            ],
          ],
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FixedColumnWidth(110),
            2: pw.FixedColumnWidth(110),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildPurchaseByProductPdf({
  required AppLocalizations l,
  required List<PurchaseByProductRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String supplierLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitlePurchaseByProduct,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          supplierLabel,
          userLabel,
          productLabel,
          customerRowLabel: l.supplier,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.rptColUom,
            l.totalBeforeTax,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            2: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map(
              (r) => [
                r.code ?? '',
                r.product,
                formatReportQuantity(r.quantity),
                r.uom,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ],
            ),
            [
              '',
              l.totalLabel,
              formatReportQuantity(rows.fold(0.0, (s, r) => s + r.quantity)),
              '',
              fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
            ],
          ],
          columnWidths: const {
            0: pw.FixedColumnWidth(60),
            1: pw.FlexColumnWidth(3),
            2: pw.FixedColumnWidth(70),
            3: pw.FixedColumnWidth(50),
            4: pw.FixedColumnWidth(90),
            5: pw.FixedColumnWidth(90),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildPurchaseExpirationDatePdf({
  required AppLocalizations l,
  required List<PurchaseExpirationDateRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8, color: PdfColors.red),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitleExpirationDate,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          customerLabel,
          userLabel,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            '#',
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.rptColUom,
            l.rptColExpirationDate,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            0: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          columnWidths: const {
            0: pw.FixedColumnWidth(30),
            1: pw.FixedColumnWidth(80),
            2: pw.FlexColumnWidth(3),
            3: pw.FixedColumnWidth(80),
            4: pw.FixedColumnWidth(60),
            5: pw.FixedColumnWidth(100),
          },
          data: rows
              .asMap()
              .entries
              .map(
                (e) => [
                  '${e.key + 1}',
                  e.value.productCode ?? '',
                  e.value.productName,
                  formatReportQuantity(e.value.quantity),
                  e.value.uom,
                  dateFmt.format(e.value.expirationDate),
                ],
              )
              .toList(),
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildPurchaseTaxPdf({
  required AppLocalizations l,
  required List<PurchaseByTaxRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8, color: PdfColors.red),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitlePurchaseTax,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          customerLabel,
          userLabel,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.rptColTaxName,
            l.totalBeforeTax,
            l.fieldTax,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FixedColumnWidth(110),
            2: pw.FixedColumnWidth(90),
            3: pw.FixedColumnWidth(110),
          },
          data: [
            ...rows.map(
              (r) => [
                r.taxName,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.taxAmount),
                fmt.format(r.total),
              ],
            ),
            [
              '',
              fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.taxAmount)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
            ],
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildPurchaseInvoiceListPdf({
  required AppLocalizations l,
  required List<PurchaseInvoiceListRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String supplierLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  final grandTotal = rows.fold(0.0, (s, r) => s + r.total);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8, color: PdfColors.red),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitlePurchaseInvoices,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          supplierLabel,
          userLabel,
          productLabel,
          customerRowLabel: l.supplier,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            '#',
            l.supplier,
            l.rptColPurchaseNumber,
            l.externalDocument,
            l.dateLabel,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            0: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          columnWidths: const {
            0: pw.FixedColumnWidth(24),
            1: pw.FlexColumnWidth(2),
            2: pw.FixedColumnWidth(110),
            3: pw.FixedColumnWidth(110),
            4: pw.FixedColumnWidth(70),
            5: pw.FixedColumnWidth(80),
          },
          data: [
            ...rows.asMap().entries.map(
              (e) => [
                '${e.key + 1}',
                e.value.supplierName,
                e.value.documentNumber,
                e.value.externalDocument ?? '',
                dateFmt.format(e.value.date),
                fmt.format(e.value.total),
              ],
            ),
            ['', '', '', '', '', fmt.format(grandTotal)],
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildPurchaseItemsDiscountsPdf({
  required AppLocalizations l,
  required List<PurchaseItemsDiscountsRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String supplierLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final hdrFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  // Group by supplier
  final grouped = <String, List<PurchaseItemsDiscountsRow>>{};
  for (final r in rows) {
    grouped.putIfAbsent(r.supplierName, () => []).add(r);
  }

  final grandTotalDiscount = rows.fold(0.0, (s, r) => s + r.totalDiscount);

  pw.Widget hdrRow(String label, String value) => _hdrPair(f, label, value);

  const colWidths = {
    0: pw.FixedColumnWidth(14), // #
    1: pw.FixedColumnWidth(44), // Code
    2: pw.FlexColumnWidth(2), // Product
    3: pw.FixedColumnWidth(42), // Qty
    4: pw.FixedColumnWidth(56), // Cost
    5: pw.FixedColumnWidth(62), // Before disc.
    6: pw.FixedColumnWidth(62), // After disc.
    7: pw.FixedColumnWidth(58), // Discount
    8: pw.FixedColumnWidth(58), // Total disc.
  };

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(20),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8, color: PdfColors.red),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) {
        final widgets = <pw.Widget>[
          printedText(
            l.rptTitlePurchasedItemDiscounts,
            style: f.style(size: 16, bold: true),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    hdrRow(
                      l.periodLabel,
                      '${hdrFmt.format(filter.startDate)} - ${hdrFmt.format(filter.endDate)}',
                    ),
                    hdrRow(l.supplier, supplierLabel),
                    hdrRow(l.userLabel, userLabel),
                    hdrRow(l.productLabel, productLabel),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    hdrRow(l.rptColCompany, companyName ?? ''),
                    hdrRow(l.setAddress, companyAddress ?? ''),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
        ];

        for (final entry in grouped.entries) {
          final supplierRows = entry.value;
          final supplierTotal = supplierRows.fold(
            0.0,
            (s, r) => s + r.totalDiscount,
          );

          widgets.add(
            pw.Container(
              width: double.infinity,
              color: PdfColors.grey200,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              child: _hdrPair(f, l.supplier, entry.key, boldValue: true),
            ),
          );

          var rowIndex = 1;
          widgets.add(
            pw.TableHelper.fromTextArray(
              cellBuilder: (i, v, r) =>
                  printedText('$v', style: f.style(size: 7)),
              headers: _cells([
                '#',
                l.fieldCode,
                l.productLabel,
                l.qtyShort,
                l.fieldCost,
                l.rptColBeforeDisc,
                l.rptColAfterDisc,
                l.discountLabel,
                l.rptColTotalDisc,
              ], f.style(size: 7, bold: true)),
              headerStyle: f.style(size: 7, bold: true),
              cellStyle: f.style(size: 7),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignments: {
                0: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.centerRight,
                8: pw.Alignment.centerRight,
              },
              columnWidths: colWidths,
              data: [
                ...supplierRows.map(
                  (r) => [
                    '${rowIndex++}',
                    r.productCode ?? '',
                    r.productName,
                    formatReportQuantity(r.quantity),
                    fmt.format(r.cost),
                    fmt.format(r.totalBeforeDiscount),
                    fmt.format(r.totalAfterDiscount),
                    r.discountDisplay,
                    fmt.format(r.totalDiscount),
                  ],
                ),
                ['', '', '', '', '', '', '', '', fmt.format(supplierTotal)],
              ],
            ),
          );
          widgets.add(pw.SizedBox(height: 6));
        }

        widgets.addAll([
          pw.Divider(
            borderStyle: pw.BorderStyle.dashed,
            color: PdfColors.grey400,
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              _hdrPair(
                f,
                l.rptColTotalDiscount,
                fmt.format(grandTotalDiscount),
                size: 10,
                boldValue: true,
              ),
            ],
          ),
        ]);

        return widgets;
      },
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildPurchaseDiscountsPdf({
  required AppLocalizations l,
  required List<PurchaseDiscountsRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String supplierLabel,
  required String userLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');
  final hdrFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  final grouped = <String, List<PurchaseDiscountsRow>>{};
  for (final r in rows) {
    grouped.putIfAbsent(r.supplierName, () => []).add(r);
  }

  final grandTotal = rows.fold(0.0, (s, r) => s + r.discountGranted);
  final totalOrders = rows.length;

  pw.Widget hdrRow(String label, String value) => _hdrPair(f, label, value);

  const colWidths = {
    0: pw.FlexColumnWidth(1.5),
    1: pw.FixedColumnWidth(58),
    2: pw.FixedColumnWidth(58),
    3: pw.FixedColumnWidth(62),
    4: pw.FixedColumnWidth(62),
    5: pw.FixedColumnWidth(62),
  };

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(24),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8, color: PdfColors.red),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitlePurchaseDiscounts,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  hdrRow(
                    l.periodLabel,
                    '${hdrFmt.format(filter.startDate)} - ${hdrFmt.format(filter.endDate)}',
                  ),
                  hdrRow(l.supplier, supplierLabel),
                  hdrRow(l.userLabel, userLabel),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  hdrRow(l.rptColCompany, companyName ?? ''),
                  hdrRow(l.setAddress, companyAddress ?? ''),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        for (final entry in grouped.entries) ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            child: _hdrPair(f, l.supplier, entry.key, boldValue: true),
          ),
          pw.TableHelper.fromTextArray(
            cellBuilder: (i, v, r) =>
                printedText('$v', style: f.style(size: 7)),
            headers: _cells([
              l.rptColDocument,
              l.dateLabel,
              l.userLabel,
              l.rptColTotalBeforeDisc,
              l.rptColTotalAfterDisc,
              l.rptColDiscountGranted,
            ], f.style(size: 7, bold: true)),
            headerStyle: f.style(size: 7, bold: true),
            cellStyle: f.style(size: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
            columnWidths: colWidths,
            data: [
              ...entry.value.map(
                (r) => [
                  r.documentNumber,
                  dateFmt.format(r.date),
                  r.userName,
                  fmt.format(r.totalBeforeDiscount),
                  fmt.format(r.totalAfterDiscount),
                  fmt.format(r.discountGranted),
                ],
              ),
              [
                '',
                '',
                '',
                '',
                '',
                fmt.format(
                  entry.value.fold(0.0, (s, r) => s + r.discountGranted),
                ),
              ],
            ],
          ),
          pw.SizedBox(height: 6),
        ],
        pw.Divider(borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                printedText(
                  l.rptOrdersDiscounted('$totalOrders'),
                  style: f.style(bold: true),
                ),
                pw.SizedBox(height: 2),
                printedText(
                  l.rptTotalDiscounted(fmt.format(grandTotal)),
                  style: f.style(size: 10, bold: true),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _pdfHeader(
  AppLocalizations l,
  _RptFonts f,
  DateFormat dateFmt,
  ReportFilter filter,
  String? companyName,
  String? companyAddress,
  String customerLabel,
  String userLabel,
  String productLabel, {

  /// Purchase reports label this row "Supplier"; pass `l.supplier` there.
  String? customerRowLabel,
}) {
  // 🚨 Was a local `row()` duplicating _hdrPair, minus the pw.Expanded its
  // callers wrap it in everywhere else. A Flexible value run needs a BOUNDED
  // width to size against; without Expanded here, these two Columns (and
  // everything nested inside, including _hdrPair's own Flexible) were laid
  // out with unbounded width, which throws "Flex children have non-zero flex
  // but incoming width constraints are unbounded" — crashed 20 reports the
  // moment any of them rendered (found 2026-09-01, POS_Manual_tests_NOTES.txt
  // [35]). Routed through the shared _hdrPair instead of a second copy of it.
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _hdrPair(
              f,
              l.periodLabel,
              '${dateFmt.format(filter.startDate)} – ${dateFmt.format(filter.endDate)}',
            ),
            pw.SizedBox(height: 3),
            _hdrPair(f, customerRowLabel ?? l.customerLabel, customerLabel),
            pw.SizedBox(height: 3),
            _hdrPair(f, l.userLabel, userLabel),
            pw.SizedBox(height: 3),
            _hdrPair(f, l.productLabel, productLabel),
          ],
        ),
      ),
      pw.SizedBox(width: 48),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _hdrPair(f, l.rptColCompany, companyName ?? ''),
            pw.SizedBox(height: 3),
            _hdrPair(f, l.setAddress, companyAddress ?? ''),
          ],
        ),
      ),
    ],
  );
}

Future<Uint8List> _buildStockReturnByProductPdf({
  required AppLocalizations l,
  required List<StockReturnByProductRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitleStockReturns,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          l.notAvailableShort,
          userLabel,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.dateLabel,
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.rptColUom,
            l.totalBeforeTax,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            3: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
            6: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map(
              (r) => [
                dateFmt.format(r.date),
                r.code ?? '',
                r.product,
                formatReportQuantity(r.quantity),
                r.uom,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ],
            ),
            [
              '',
              '',
              l.totalLabel,
              formatReportQuantity(rows.fold(0.0, (s, r) => s + r.quantity)),
              '',
              fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
            ],
          ],
          columnWidths: const {
            0: pw.FixedColumnWidth(65),
            1: pw.FixedColumnWidth(55),
            2: pw.FlexColumnWidth(3),
            3: pw.FixedColumnWidth(70),
            4: pw.FixedColumnWidth(45),
            5: pw.FixedColumnWidth(90),
            6: pw.FixedColumnWidth(90),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildLossAndDamageByProductPdf({
  required AppLocalizations l,
  required List<LossAndDamageByProductRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitleLossAndDamage,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          dateFmt,
          filter,
          companyName,
          companyAddress,
          l.notAvailableShort,
          userLabel,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.dateLabel,
            l.fieldCode,
            l.productLabel,
            l.fieldQuantity,
            l.rptColUom,
            l.totalBeforeTax,
            l.totalLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            3: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
            6: pw.Alignment.centerRight,
          },
          data: [
            ...rows.map(
              (r) => [
                dateFmt.format(r.date),
                r.code ?? '',
                r.product,
                formatReportQuantity(r.quantity),
                r.uom,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ],
            ),
            [
              '',
              '',
              l.totalLabel,
              formatReportQuantity(rows.fold(0.0, (s, r) => s + r.quantity)),
              '',
              fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
              fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
            ],
          ],
          columnWidths: const {
            0: pw.FixedColumnWidth(65),
            1: pw.FixedColumnWidth(55),
            2: pw.FlexColumnWidth(3),
            3: pw.FixedColumnWidth(70),
            4: pw.FixedColumnWidth(45),
            5: pw.FixedColumnWidth(90),
            6: pw.FixedColumnWidth(90),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildReorderProductListPdf({
  required AppLocalizations l,
  required List<ReorderProductListRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String supplierLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');

  final f = await _RptFonts.load();
  final theme = f.theme;

  // Build grouped table data
  final tableData = <List<String>>[];
  final supplierRows = <int>{};
  String? current;
  for (final r in rows) {
    if (r.supplierName != current) {
      current = r.supplierName;
      supplierRows.add(tableData.length);
      tableData.add([r.supplierName, '', '']);
    }
    tableData.add([r.productName, fmt.format(r.orderQuantity), r.uom]);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitleReorderList,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          DateFormat('dd/MM/yyyy'),
          filter,
          companyName,
          companyAddress,
          supplierLabel,
          l.notAvailableShort,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.rptColProductName,
            l.rptColOrderQty,
            l.rptColUom,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellDecoration: (index, data, rowNum) => supplierRows.contains(rowNum)
              ? const pw.BoxDecoration(color: PdfColors.grey200)
              : const pw.BoxDecoration(),
          cellAlignments: {1: pw.Alignment.centerRight},
          data: tableData,
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FixedColumnWidth(90),
            2: pw.FixedColumnWidth(60),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildLowStockWarningPdf({
  required AppLocalizations l,
  required List<LowStockWarningRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String supplierLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');

  final f = await _RptFonts.load();
  final theme = f.theme;

  // Build grouped table data
  final tableData = <List<String>>[];
  final supplierRows = <int>{};
  String? current;
  for (final r in rows) {
    if (r.supplierName != current) {
      current = r.supplierName;
      supplierRows.add(tableData.length);
      tableData.add([r.supplierName, '', '', '', '']);
    }
    tableData.add([
      r.productName,
      fmt.format(r.currentStock),
      fmt.format(r.lowStockWarningQuantity),
      fmt.format(r.orderQuantity),
      r.uom,
    ]);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(l.rptTitleLowStock, style: f.style(size: 16, bold: true)),
        pw.SizedBox(height: 8),
        _pdfHeader(
          l,
          f,
          DateFormat('dd/MM/yyyy'),
          filter,
          companyName,
          companyAddress,
          supplierLabel,
          l.notAvailableShort,
          productLabel,
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.rptColProductName,
            l.rptColCurrentStock,
            l.rptColWarningQty,
            l.rptColOrderQty,
            l.rptColUom,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellDecoration: (index, data, rowNum) => supplierRows.contains(rowNum)
              ? const pw.BoxDecoration(color: PdfColors.grey200)
              : const pw.BoxDecoration(),
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          data: tableData,
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FixedColumnWidth(85),
            2: pw.FixedColumnWidth(85),
            3: pw.FixedColumnWidth(85),
            4: pw.FixedColumnWidth(55),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _buildTransactionHistoryPdf({
  required AppLocalizations l,
  required List<TransactionHistoryRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String partnerLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final f = await _RptFonts.load();
  final theme = f.theme;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          printedText(
            DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: f.style(size: 8),
          ),
          printedText(
            l.pageNumberLabel('${ctx.pageNumber}'),
            style: f.style(size: 8),
          ),
        ],
      ),
      build: (ctx) => [
        printedText(
          l.rptTitleTransactionHistory,
          style: f.style(size: 16, bold: true),
        ),
        pw.SizedBox(height: 4),
        _hdrPair(f, l.rptBusinessPartner, partnerLabel, size: 10),
        pw.SizedBox(height: 4),
        _hdrPair(
          f,
          l.periodLabel,
          '${dateFmt.format(filter.startDate)} – ${dateFmt.format(filter.endDate)}',
          size: 10,
        ),
        if (companyName != null) ...[
          pw.SizedBox(height: 4),
          printedText(companyName, style: f.style(size: 10)),
          if (companyAddress != null)
            printedText(companyAddress, style: f.style(size: 10)),
        ],
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellBuilder: (i, v, r) => printedText('$v', style: f.style()),
          headers: _cells([
            l.dateLabel,
            l.rptColTransactionType,
            l.rptColRefNumber,
            l.rptColCredit,
            l.rptColDebit,
            l.balanceLabel,
          ], f.style(bold: true)),
          headerStyle: f.style(bold: true),
          cellStyle: f.style(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          data: rows.map((r) {
            final dateStr = r.isPreviousBalance
                ? ''
                : (r.date != null ? dateFmt.format(r.date!) : '');
            return [
              dateStr,
              r.transactionType,
              r.refNumber ?? '',
              r.credit > 0 ? fmt.format(r.credit) : '',
              r.debit > 0 ? fmt.format(r.debit) : '',
              fmt.format(r.balance),
            ];
          }).toList(),
          columnWidths: const {
            0: pw.FixedColumnWidth(65),
            1: pw.FixedColumnWidth(110),
            2: pw.FlexColumnWidth(2),
            3: pw.FixedColumnWidth(90),
            4: pw.FixedColumnWidth(90),
            5: pw.FixedColumnWidth(90),
          },
        ),
      ],
    ),
  );

  return doc.save();
}

// ─── Filter panel ─────────────────────────────────────────────────────────────

class _FilterPanel extends ConsumerWidget {
  final String reportId;
  final ReportFilter filter;
  final ValueChanged<ReportFilter> onFilterChanged;
  final VoidCallback onShowReport;
  final Future<void> Function() onExportCsv;

  const _FilterPanel({
    required this.reportId,
    required this.filter,
    required this.onFilterChanged,
    required this.onShowReport,
    required this.onExportCsv,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd/MM/yyyy');

    final customers = ref.watch(allCustomersProvider).value ?? [];
    final users = ref.watch(allUsersProvider).value ?? [];
    final warehouses = ref.watch(allWarehousesProvider).value ?? [];
    final products = ref.watch(allProductsListProvider).value ?? [];
    final groups = ref.watch(allProductGroupsProvider).value ?? [];

    return Container(
      width: 240,
      color: cs.surfaceContainerLow,
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context).filterLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const Gap(16),

            _FilterLabel(
              reportId == 'transaction_history'
                  ? AppLocalizations.of(context).businessPartnerRequired
                  : AppLocalizations.of(context).customersAndSuppliers,
            ),
            const Gap(4),
            _FilterDropdown<int?>(
              value: filter.customerId,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(AppLocalizations.of(context).filterAll),
                ),
                ...customers.map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) => onFilterChanged(filter.copyWith(customerId: v)),
            ),
            const Gap(12),

            if (reportId != 'transaction_history' &&
                reportId != 'reorder_list' &&
                reportId != 'low_stock_warning') ...[
              _FilterLabel(AppLocalizations.of(context).userLabel),
              const Gap(4),
              _FilterDropdown<int?>(
                value: filter.userId,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(AppLocalizations.of(context).filterAll),
                  ),
                  ...users.map((u) {
                    final name = '${u.firstName ?? ''} ${u.lastName ?? ''}'
                        .trim();
                    return DropdownMenuItem(
                      value: u.id,
                      child: Text(
                        name.isEmpty
                            ? u.username ??
                                  AppLocalizations.of(
                                    context,
                                  ).userNumbered('${u.id}')
                            : name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (v) => onFilterChanged(filter.copyWith(userId: v)),
              ),
              const Gap(12),

              _FilterLabel(AppLocalizations.of(context).cashRegister),
              const Gap(4),
              _FilterDropdown<int?>(
                value: filter.warehouseId,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(AppLocalizations.of(context).filterAll),
                  ),
                  ...warehouses.map(
                    (w) => DropdownMenuItem(
                      value: w.id,
                      child: Text(w.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) =>
                    onFilterChanged(filter.copyWith(warehouseId: v)),
              ),
              const Gap(12),

              _FilterLabel(AppLocalizations.of(context).productLabel),
              const Gap(4),
              _FilterDropdown<int?>(
                value: filter.productId,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(AppLocalizations.of(context).filterAll),
                  ),
                  ...products.map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) =>
                    onFilterChanged(filter.copyWith(productId: v)),
              ),
              const Gap(12),

              _FilterLabel(AppLocalizations.of(context).fieldProductGroup),
              const Gap(4),
              _FilterDropdown<int?>(
                value: filter.productGroupId,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(AppLocalizations.of(context).filterAll),
                  ),
                  ...groups.map(
                    (g) => DropdownMenuItem(
                      value: g.id,
                      child: Text(g.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) =>
                    onFilterChanged(filter.copyWith(productGroupId: v)),
              ),
              const Gap(6),
            ],

            if (reportId == 'sales_by_group')
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  AppLocalizations.of(context).includeSubgroups,
                  style: TextStyle(fontSize: 13, color: cs.onSurface),
                ),
                value: filter.includeSubgroups,
                onChanged: (v) => onFilterChanged(
                  filter.copyWith(includeSubgroups: v ?? false),
                ),
              ),

            const Gap(12),
            const Divider(),
            const Gap(8),

            if (reportId != 'reorder_list' &&
                reportId != 'low_stock_warning') ...[
              _FilterLabel(AppLocalizations.of(context).periodLabel),
              const Gap(6),
              _DateButton(
                label:
                    '${dateFmt.format(filter.startDate)} – ${dateFmt.format(filter.endDate)}',
                onTap: () => _pickRange(context),
              ),
              const Gap(16),
              const Divider(),
              const Gap(12),
            ],

            FilledButton.icon(
              icon: const Icon(Icons.search, size: 16),
              label: Text(AppLocalizations.of(context).showReport),
              onPressed: onShowReport,
            ),
            const Gap(8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.grid_on_outlined, size: 14),
                    label: Text(AppLocalizations.of(context).excel),
                    onPressed: onExportCsv,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final range = await showAppDateRangePicker(
      context,
      initialStart: filter.startDate,
      initialEnd: filter.endDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (range == null) return;
    onFilterChanged(
      filter.copyWith(startDate: range.start, endDate: range.end),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        color: cs.surface,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: items,
          onChanged: onChanged,
          style: TextStyle(fontSize: 13, color: cs.onSurface),
          dropdownColor: cs.surface,
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(8),
          color: cs.surface,
        ),
        child: Text(
          label,
          style: TextStyle(color: cs.onSurface, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
