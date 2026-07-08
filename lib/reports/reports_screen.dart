import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/product/product_provider.dart';
import 'package:pos_app/product/product_group_provider.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/reports/report_models.dart';
import 'package:pos_app/reports/reports_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

// ─── Data models ──────────────────────────────────────────────────────────────

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
  const _OpenTab({required this.id, required this.reportType, required this.filter});
}

// ─── Report catalogue ─────────────────────────────────────────────────────────

const _salesReports = [
  _ReportType('sales_by_product',         'Products',                      Icons.local_offer_outlined),
  _ReportType('sales_by_group',           'Product groups',                Icons.folder_outlined),
  _ReportType('sales_by_customer',        'Customers',                     Icons.people_outline),
  _ReportType('sales_tax',                'Tax rates',                     Icons.percent),
  _ReportType('sales_users',              'Users',                         Icons.person_outline),
  _ReportType('sales_item_list',          'Item list',                     Icons.list_alt_outlined),
  _ReportType('sales_payment_types',      'Payment types',                 Icons.credit_card_outlined),
  _ReportType('sales_payment_by_user',    'Payment types by users',        Icons.manage_accounts_outlined),
  _ReportType('sales_payment_by_customer','Payment types by customers',    Icons.person_pin_outlined),
  _ReportType('sales_refunds',            'Refunds',                       Icons.undo_outlined),
  _ReportType('sales_invoice_list',       'Invoice list',                  Icons.receipt_outlined),
  _ReportType('sales_daily',              'Daily sales',                   Icons.today_outlined),
  _ReportType('sales_hourly',             'Hourly sales',                  Icons.schedule_outlined),
  _ReportType('sales_hourly_group',       'Hourly sales by product groups',Icons.bar_chart_outlined),
  _ReportType('sales_by_table',           'Table or order number',         Icons.table_restaurant_outlined),
  _ReportType('sales_profit',             'Profit & margin',               Icons.trending_up_outlined),
  _ReportType('sales_unpaid',             'Unpaid sales',                  Icons.money_off_outlined),
  _ReportType('sales_starting_cash',      'Starting cash entries',         Icons.account_balance_wallet_outlined),
  _ReportType('sales_voided',             'Voided items',                  Icons.delete_outline),
  _ReportType('sales_discounts',          'Discounts granted',             Icons.discount_outlined),
  _ReportType('sales_discounts_by_source','Discounts by source',           Icons.pie_chart_outline),
  _ReportType('sales_item_discounts',     'Items discounts',               Icons.sell_outlined),
  _ReportType('sales_stock_movement',     'Stock movement',                Icons.swap_horiz_outlined),
];

const _purchaseReports = [
  _ReportType('purchase_products',         'Products',                    Icons.local_offer_outlined),
  _ReportType('purchase_suppliers',        'Suppliers',                   Icons.store_outlined),
  _ReportType('purchase_unpaid',           'Unpaid purchase',             Icons.money_off_outlined),
  _ReportType('purchase_discounts',        'Purchase discounts',          Icons.discount_outlined),
  _ReportType('purchase_items_discounts',  'Purchased items discounts',   Icons.sell_outlined),
  _ReportType('purchase_invoice_list',     'Purchase invoice list',       Icons.receipt_outlined),
  _ReportType('purchase_tax',              'Tax rates',                   Icons.percent),
  _ReportType('purchase_expiration',       'Expiration date',             Icons.event_outlined),
];

const _stockReturnReports = [
  _ReportType('stock_return_products', 'Products', Icons.local_offer_outlined),
];

const _lossAndDamageReports = [
  _ReportType('loss_and_damage_products', 'Products', Icons.local_offer_outlined),
];

const _stockControlReports = [
  _ReportType('reorder_list',      'Reorder product list', Icons.shopping_cart_outlined),
  _ReportType('low_stock_warning', 'Low stock warning',    Icons.warning_amber_outlined),
];

const _financeReports = [
  _ReportType('transaction_history', 'Transaction history', Icons.receipt_long_outlined),
];

// ─── Section lookup helpers ───────────────────────────────────────────────────

const _allSections = <(String, List<_ReportType>)>[
  ('Sales',           _salesReports),
  ('Purchase',        _purchaseReports),
  ('Stock Return',    _stockReturnReports),
  ('Loss and damage', _lossAndDamageReports),
  ('Stock control',   _stockControlReports),
  ('Finance',         _financeReports),
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
  final Set<String> _favorites = {};
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
    final filter = _filter;
    final reportId = _selectedReportType!.id;
    final buf = StringBuffer();
    String filename;

    try {
      if (reportId == 'sales_by_product') {
        final rows = await ref.read(salesByProductProvider(filter).future);
        buf.writeln('Code,Product,Quantity,UOM,Total before tax,Total');
        for (final r in rows) {
          buf.writeln('"${r.code ?? ''}","${r.product}",${r.quantity},"${r.uom}",${r.totalBeforeTax},${r.total}');
        }
        buf.writeln('"","Total",${rows.fold(0.0, (s, r) => s + r.quantity)},"",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}');
        filename = 'SalesByProduct';
      } else if (reportId == 'sales_by_group') {
        final rows = await ref.read(salesByProductGroupProvider(filter).future);
        buf.writeln('Product group,Quantity,Total before tax,Total');
        for (final r in rows) {
          buf.writeln('"${r.productGroup}",${r.quantity},${r.totalBeforeTax},${r.total}');
        }
        buf.writeln('"Total",${rows.fold(0.0, (s, r) => s + r.quantity)},${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}');
        filename = 'SalesByProductGroup';
      } else if (reportId == 'sales_by_customer') {
        final rows = await ref.read(salesByCustomerProvider(filter).future);
        buf.writeln('Customer,Total before tax,Total');
        for (final r in rows) {
          buf.writeln('"${r.customer}",${r.totalBeforeTax},${r.total}');
        }
        buf.writeln('"Total",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}');
        filename = 'SalesByCustomer';
      } else if (reportId == 'sales_tax') {
        final rows = await ref.read(salesByTaxProvider(filter).future);
        buf.writeln('Tax name,Total before tax,Tax,Total');
        for (final r in rows) {
          buf.writeln('"${r.taxName}",${r.totalBeforeTax},${r.taxAmount},${r.total}');
        }
        buf.writeln('"Total",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.taxAmount)},${rows.fold(0.0, (s, r) => s + r.total)}');
        filename = 'SalesTax';
      } else if (reportId == 'sales_payment_by_customer') {
        final rows = await ref.read(paymentTypesByCustomerProvider(filter).future);
        final paymentTypes = rows.map((r) => r.paymentTypeName).toSet().toList()..sort();
        final customers = rows.map((r) => r.customerName).toSet().toList()..sort();
        final pivot = <String, Map<String, double>>{};
        for (final r in rows) {
          pivot.putIfAbsent(r.customerName, () => {});
          pivot[r.customerName]![r.paymentTypeName] =
              (pivot[r.customerName]![r.paymentTypeName] ?? 0) + r.amount;
        }
        buf.writeln(['Customer', ...paymentTypes, 'Total'].map((h) => '"$h"').join(','));
        for (final c in customers) {
          final amounts = paymentTypes.map((pt) => pivot[c]?[pt] ?? 0.0).toList();
          final total = amounts.fold(0.0, (s, a) => s + a);
          buf.writeln(['"$c"', ...amounts, total].join(','));
        }
        final grandAmounts = paymentTypes.map((pt) =>
            customers.fold(0.0, (s, c) => s + (pivot[c]?[pt] ?? 0.0))).toList();
        buf.writeln(['"Total"', ...grandAmounts, rows.fold(0.0, (s, r) => s + r.amount)].join(','));
        filename = 'PaymentTypesByCustomer';
      } else if (reportId == 'sales_payment_by_user') {
        final rows = await ref.read(paymentTypesByUserProvider(filter).future);
        final paymentTypes = rows.map((r) => r.paymentTypeName).toSet().toList()..sort();
        final users = rows.map((r) => r.userName).toSet().toList()..sort();
        final pivot = <String, Map<String, double>>{};
        for (final r in rows) {
          pivot.putIfAbsent(r.userName, () => {});
          pivot[r.userName]![r.paymentTypeName] =
              (pivot[r.userName]![r.paymentTypeName] ?? 0) + r.amount;
        }
        buf.writeln(['User', ...paymentTypes, 'Total'].map((h) => '"$h"').join(','));
        for (final u in users) {
          final amounts = paymentTypes.map((pt) => pivot[u]?[pt] ?? 0.0).toList();
          final total = amounts.fold(0.0, (s, a) => s + a);
          buf.writeln(['"$u"', ...amounts, total].join(','));
        }
        final grandAmounts = paymentTypes.map((pt) =>
            users.fold(0.0, (s, u) => s + (pivot[u]?[pt] ?? 0.0))).toList();
        buf.writeln(['"Total"', ...grandAmounts, rows.fold(0.0, (s, r) => s + r.amount)].join(','));
        filename = 'PaymentTypesByUser';
      } else if (reportId == 'sales_payment_types') {
        final rows = await ref.read(salesByPaymentTypeProvider(filter).future);
        final paymentTypes = rows.map((r) => r.paymentTypeName).toSet().toList()..sort();
        final dates = rows.map((r) => r.date).toSet().toList()..sort();
        final pivot = <DateTime, Map<String, double>>{};
        for (final r in rows) {
          pivot.putIfAbsent(r.date, () => {});
          pivot[r.date]![r.paymentTypeName] =
              (pivot[r.date]![r.paymentTypeName] ?? 0) + r.amount;
        }
        final dateFmt2 = DateFormat('dd/MM/yyyy');
        buf.writeln(['Date', ...paymentTypes, 'Total'].map((h) => '"$h"').join(','));
        for (final d in dates) {
          final amounts = paymentTypes.map((pt) => pivot[d]?[pt] ?? 0.0).toList();
          final total = amounts.fold(0.0, (s, a) => s + a);
          buf.writeln([dateFmt2.format(d), ...amounts, total].join(','));
        }
        // grand total row
        final grandAmounts = paymentTypes.map((pt) =>
            dates.fold(0.0, (s, d) => s + (pivot[d]?[pt] ?? 0.0))).toList();
        buf.writeln(['', ...grandAmounts, rows.fold(0.0, (s, r) => s + r.amount)].join(','));
        filename = 'SalesByPaymentType';
      } else if (reportId == 'sales_refunds') {
        final rows = await ref.read(refundItemListProvider(filter).future);
        buf.writeln('Document number,Ref. number,Date,Customer code,Customer,Code,Product,Quantity,UOM,Total before tax,Total tax,Total');
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
        buf.writeln('#,Date,Document number,Customer,Payment method,Total');
        final dateFmt = DateFormat('dd/MM/yyyy');
        var i = 1;
        for (final r in rows) {
          buf.writeln(
            '$i,"${dateFmt.format(r.date)}","${r.documentNumber}",'
            '"${r.customerName}","${r.paymentMethodName}",${r.total}',
          );
          i++;
        }
        buf.writeln('"","","","","Total",${rows.fold(0.0, (s, r) => s + r.total)}');
        filename = 'InvoiceList';
      } else if (reportId == 'sales_daily') {
        final rows = await ref.read(dailySalesProvider(filter).future);
        buf.writeln('Date,Total');
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
        buf.writeln('Hour start,Hour end,Total sales,Sales count,Average sale,%');
        for (final r in rows) {
          final start = DateTime(2000, 1, 1, r.hour);
          final avg   = r.salesCount > 0 ? r.totalSales / r.salesCount : 0.0;
          final pct   = grandTotal > 0 ? r.totalSales / grandTotal * 100 : 0.0;
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
        final hourLabels = hours.map((h) => timeFmt.format(DateTime(2000, 1, 1, h))).toList();
        buf.writeln(['Product group', ...hourLabels, 'Total'].map((h) => '"$h"').join(','));
        for (final g in groups) {
          final amounts = hours.map((h) => pivot[g]?[h] ?? 0.0).toList();
          buf.writeln(['"$g"', ...amounts, amounts.fold(0.0, (s, a) => s + a)].join(','));
        }
        final hourTotals = hours.map((h) => groups.fold(0.0, (s, g) => s + (pivot[g]?[h] ?? 0.0))).toList();
        buf.writeln(['"Total"', ...hourTotals, rows.fold(0.0, (s, r) => s + r.total)].join(','));
        filename = 'HourlySalesByGroup';
      } else if (reportId == 'sales_by_table') {
        final rows = await ref.read(salesByTableProvider(filter).future);
        buf.writeln('Table / order number,Number of sales,Total');
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
        buf.writeln('Code,Product,Quantity,Cost,Total,Profit,Margin');
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
        buf.writeln('Customer,Document number,Date,Due date,Total,Total paid,Total unpaid');
        for (final r in rows) {
          buf.writeln(
            '"${r.customerName}","${r.documentNumber}",'
            '"${dateFmt.format(r.date)}","${r.dueDate != null ? dateFmt.format(r.dueDate!) : ''}",'
            '${r.documentTotal},${r.totalPaid},${r.totalUnpaid}',
          );
        }
        buf.writeln('"","","","","","Total",${rows.fold(0.0, (s, r) => s + r.totalUnpaid)}');
        filename = 'UnpaidSales';
      } else if (reportId == 'sales_starting_cash') {
        final rows = await ref.read(startingCashReportProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
        buf.writeln('User,Type,Description,Date,Amount,Z-Report #');
        for (final r in rows) {
          buf.writeln(
            '"${r.userName ?? ''}","${r.isCashOut ? 'Cash Out' : 'Cash In'}",'
            '"${r.description ?? ''}","${dateFmt.format(r.dateCreated)}",'
            '${r.signedAmount},${r.zReportNumber ?? ''}',
          );
        }
        buf.writeln('"","","","Total",${rows.fold(0.0, (s, r) => s + r.signedAmount)},""');
        filename = 'StartingCash';
      } else if (reportId == 'sales_stock_movement') {
        final rows = await ref.read(stockMovementReportProvider(filter).future);
        final total   = rows.fold(0.0, (s, r) => s + r.numSales);
        final average = rows.isEmpty ? 0.0 : total / rows.length;
        buf.writeln('Category,Code,Product,Num. of sales');
        for (final r in rows) {
          final cat = r.numSales >= average ? 'Fast moving' : 'Slow moving';
          buf.writeln('"$cat","${r.productCode ?? ''}","${r.productName}",${r.numSales}');
        }
        buf.writeln('"","","Total number of sales",$total');
        buf.writeln('"","","Average number of sales per item",$average');
        filename = 'StockMovement';
      } else if (reportId == 'sales_item_discounts') {
        final rows = await ref.read(itemsDiscountsReportProvider(filter).future);
        buf.writeln('Code,Product,Total discount');
        for (final r in rows) {
          buf.writeln('"${r.productCode ?? ''}","${r.productName}",${r.totalDiscount}');
        }
        buf.writeln('"","Total",${rows.fold(0.0, (s, r) => s + r.totalDiscount)}');
        filename = 'ItemsDiscounts';
      } else if (reportId == 'sales_discounts') {
        final rows = await ref.read(discountsGrantedReportProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln('Customer,Document,Date,User,Total before disc.,Total after disc.,Discount granted');
        for (final r in rows) {
          buf.writeln(
            '"${r.customerName}","${r.documentNumber}",'
            '"${dateFmt.format(r.date)}","${r.userName}",'
            '${r.totalBeforeDiscount},${r.totalAfterDiscount},${r.discountGranted}',
          );
        }
        buf.writeln('"","","","","","Total",${rows.fold(0.0, (s, r) => s + r.discountGranted)}');
        filename = 'DiscountsGranted';
      } else if (reportId == 'sales_discounts_by_source') {
        final rows = await ref.read(discountsBySourceReportProvider(filter).future);
        buf.writeln('Discount source,Total');
        for (final r in rows) {
          buf.writeln('"${r.label}",${r.amount}');
        }
        buf.writeln('"Total",${rows.fold(0.0, (s, r) => s + r.amount)}');
        filename = 'DiscountsBySource';
      } else if (reportId == 'sales_voided') {
        final rows = await ref.read(voidedItemsReportProvider(filter).future);
        final dtFmt = DateFormat('dd/MM/yyyy HH:mm:ss');
        buf.writeln('Product,Voided by,Qty.,Price,Discount,Status,Order #,Created,Voided,Total,Reason');
        for (final r in rows) {
          buf.writeln(
            '"${r.productName}","${r.voidedByName ?? ''}",'
            '${r.quantity},${r.price},"${r.discountDisplay}",'
            '"${r.isConfirmed ? 'Confirmed' : 'Pending'}",'
            '"${r.orderNumber}","${dtFmt.format(r.dateCreated)}",'
            '"${dtFmt.format(r.dateVoided)}",${r.total},'
            '"${r.reason ?? ''}"',
          );
        }
        buf.writeln('"","","","","","","","","Total",${rows.fold(0.0, (s, r) => s + r.total)},""');
        filename = 'VoidedItems';
      } else if (reportId == 'sales_item_list') {
        final rows = await ref.read(salesItemListProvider(filter).future);
        buf.writeln('Document type,Date,Create date,Document number,Ref. number,Customer code,Customer,Order number,Code,Product,Quantity,UOM,Total before tax,Total tax,Total');
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
        buf.writeln('User,Total before tax,Total');
        for (final r in rows) {
          buf.writeln('"${r.user}",${r.totalBeforeTax},${r.total}');
        }
        buf.writeln('"Total",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}');
        filename = 'SalesByUser';
      } else if (reportId == 'purchase_unpaid') {
        final rows = await ref.read(unpaidPurchaseProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln('Supplier,Document number,Date,Due date,Total,Total paid,Total unpaid');
        for (final r in rows) {
          buf.writeln(
            '"${r.supplierName}","${r.documentNumber}",'
            '"${dateFmt.format(r.date)}","${r.dueDate != null ? dateFmt.format(r.dueDate!) : ''}",'
            '${r.documentTotal},${r.totalPaid},${r.totalUnpaid}',
          );
        }
        buf.writeln('"","","","","","Total",${rows.fold(0.0, (s, r) => s + r.totalUnpaid)}');
        filename = 'UnpaidPurchase';
      } else if (reportId == 'purchase_suppliers') {
        final rows = await ref.read(purchaseBySupplierProvider(filter).future);
        buf.writeln('Supplier,Total before tax,Total');
        for (final r in rows) {
          buf.writeln('"${r.supplier}",${r.totalBeforeTax},${r.total}');
        }
        buf.writeln('"Total",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}');
        filename = 'PurchaseBySupplier';
      } else if (reportId == 'purchase_products') {
        final rows = await ref.read(purchaseByProductProvider(filter).future);
        buf.writeln('Code,Product,Quantity,UOM,Total before tax,Total');
        for (final r in rows) {
          buf.writeln('"${r.code ?? ''}","${r.product}",${r.quantity},"${r.uom}",${r.totalBeforeTax},${r.total}');
        }
        buf.writeln('"","Total",${rows.fold(0.0, (s, r) => s + r.quantity)},"",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}');
        filename = 'PurchaseByProduct';
      } else if (reportId == 'purchase_invoice_list') {
        final rows = await ref.read(purchaseInvoiceListProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln('#,Supplier,Purchase number,External document,Date,Total');
        var i = 1;
        for (final r in rows) {
          buf.writeln(
            '$i,"${r.supplierName}","${r.documentNumber}",'
            '"${r.externalDocument ?? ''}","${dateFmt.format(r.date)}",${r.total}',
          );
          i++;
        }
        buf.writeln('"","","","","Total",${rows.fold(0.0, (s, r) => s + r.total)}');
        filename = 'PurchaseInvoices';
      } else if (reportId == 'purchase_items_discounts') {
        final rows = await ref.read(purchaseItemsDiscountsProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln('Supplier,Document,Date,User,Code,Product,Qty,Cost,Before disc.,After disc.,Discount,Total disc.');
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
        buf.writeln('"","","","","","","","","","","Total",${rows.fold(0.0, (s, r) => s + r.totalDiscount)}');
        filename = 'PurchaseItemsDiscounts';
      } else if (reportId == 'purchase_discounts') {
        final rows = await ref.read(purchaseDiscountsProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln('Supplier,Document,Date,User,Total before disc.,Total after disc.,Discount granted');
        for (final r in rows) {
          buf.writeln(
            '"${r.supplierName}","${r.documentNumber}",'
            '"${dateFmt.format(r.date)}","${r.userName}",'
            '${r.totalBeforeDiscount},${r.totalAfterDiscount},${r.discountGranted}',
          );
        }
        buf.writeln('"","","","","","Total",${rows.fold(0.0, (s, r) => s + r.discountGranted)}');
        filename = 'PurchaseDiscounts';
      } else if (reportId == 'purchase_tax') {
        final rows = await ref.read(purchaseByTaxProvider(filter).future);
        buf.writeln('Tax name,Total before tax,Tax,Total');
        for (final r in rows) {
          buf.writeln('"${r.taxName}",${r.totalBeforeTax},${r.taxAmount},${r.total}');
        }
        buf.writeln('"Total",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.taxAmount)},${rows.fold(0.0, (s, r) => s + r.total)}');
        filename = 'PurchaseTax';
      } else if (reportId == 'purchase_expiration') {
        final rows = await ref.read(purchaseExpirationDateProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln('#,Code,Product,Quantity,UOM,Expiration date');
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
        final rows = await ref.read(stockReturnByProductProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln('Date,Code,Product,Quantity,UOM,Total before tax,Total');
        for (final r in rows) {
          buf.writeln('"${dateFmt.format(r.date)}","${r.code ?? ''}","${r.product}",${r.quantity},"${r.uom}",${r.totalBeforeTax},${r.total}');
        }
        buf.writeln('"","","Total",${rows.fold(0.0, (s, r) => s + r.quantity)},"",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}');
        filename = 'StockReturnByProduct';
      } else if (reportId == 'loss_and_damage_products') {
        final rows = await ref.read(lossAndDamageByProductProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln('Date,Code,Product,Quantity,UOM,Total before tax,Total');
        for (final r in rows) {
          buf.writeln('"${dateFmt.format(r.date)}","${r.code ?? ''}","${r.product}",${r.quantity},"${r.uom}",${r.totalBeforeTax},${r.total}');
        }
        buf.writeln('"","","Total",${rows.fold(0.0, (s, r) => s + r.quantity)},"",${rows.fold(0.0, (s, r) => s + r.totalBeforeTax)},${rows.fold(0.0, (s, r) => s + r.total)}');
        filename = 'LossAndDamageByProduct';
      } else if (reportId == 'reorder_list') {
        final rows = await ref.read(reorderProductListProvider(filter).future);
        buf.writeln('Supplier,Product name,Order qty.,UOM');
        for (final r in rows) {
          buf.writeln('"${r.supplierName}","${r.productName}",${r.orderQuantity},"${r.uom}"');
        }
        filename = 'ReorderProductList';
      } else if (reportId == 'low_stock_warning') {
        final rows = await ref.read(lowStockWarningProvider(filter).future);
        buf.writeln('Supplier,Product name,Current stock,Warning qty.,Order qty.,UOM');
        for (final r in rows) {
          buf.writeln('"${r.supplierName}","${r.productName}",${r.currentStock},${r.lowStockWarningQuantity},${r.orderQuantity},"${r.uom}"');
        }
        filename = 'LowStockWarning';
      } else if (reportId == 'transaction_history') {
        if (filter.customerId == null) return;
        final rows = await ref.read(transactionHistoryProvider(filter).future);
        final dateFmt = DateFormat('dd/MM/yyyy');
        buf.writeln('Date,Transaction type,Ref. number,Credit,Debit,Balance');
        for (final r in rows) {
          final dateStr = r.isPreviousBalance ? '' : (r.date != null ? dateFmt.format(r.date!) : '');
          buf.writeln('"$dateStr","${r.transactionType}","${r.refNumber ?? ''}",${r.credit},${r.debit},${r.balance}');
        }
        filename = 'TransactionHistory';
      } else {
        return;
      }

      final file = File(
          '${Directory.systemTemp.path}\\${filename}_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await Process.start('explorer.exe', [file.path]);

      if (mounted) {
        showAppSnackbar(context, ref, 'Saved: ${file.path}');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Export failed: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeTab = _tabs.where((t) => t.id == _activeTabId).firstOrNull;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Reports'),
        elevation: 0,
        // Suppress the auto back-arrow — ManagementLayout controls navigation.
        automaticallyImplyLeading: false,
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Show navigation',
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
                  label: 'Select report',
                  icon: Icons.search,
                  active: _activeTabId == 'home',
                  onTap: () => setState(() => _activeTabId = 'home'),
                ),
                ..._tabs.map((t) => _TabChip(
                      id: t.id,
                      label: t.reportType.label,
                      active: _activeTabId == t.id,
                      onTap: () => setState(() => _activeTabId = t.id),
                      onClose: () => _closeTab(t.id),
                    )),
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
                    onSelectReport: (r) => setState(() => _selectedReportType = r),
                    onFilterChanged: (f) => setState(() => _filter = f),
                    onShowReport: _showReport,
                    onExportCsv: _exportCsv,
                    favorites: _favorites,
                    onToggleFavorite: (id) => setState(() {
                      if (_favorites.contains(id)) {
                        _favorites.remove(id);
                      } else {
                        _favorites.add(id);
                      }
                    }),
                    onClearFavorites: () => setState(() => _favorites.clear()),
                    searchQuery: _searchQuery,
                    onSearchChanged: (q) => setState(() => _searchQuery = q),
                  )
                : activeTab != null
                    ? _TabPdfView(tab: activeTab)
                    : const Center(child: Text('Tab not found')),
          ),
        ),
      ],
      ),
    );
  }
}

// ─── Tab chip ─────────────────────────────────────────────────────────────────

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
              Icon(icon, size: 14,
                  color: active ? cs.primary : cs.onSurfaceVariant),
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
                  child: Icon(Icons.close, size: 13,
                      color: cs.onSurfaceVariant),
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

  Widget _reportTile(ColorScheme cs, _ReportType r, {String? prefixLabel}) {
    final active = selected?.id == r.id;
    final isFav = favorites.contains(r.id);
    return ListTile(
      dense: true,
      leading: Icon(r.icon, size: 18,
          color: active ? cs.primary : cs.onSurfaceVariant),
      title: Text(
        prefixLabel ?? r.label,
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
                if (r.label.toLowerCase().contains(q) ||
                    section.toLowerCase().contains(q))
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
                    Text(
                      'Select report to view or print',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 220,
                      height: 36,
                      child: TextField(
                        onChanged: onSearchChanged,
                        style: TextStyle(fontSize: 13, color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Search reports',
                          hintStyle: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant),
                          prefixIcon: Icon(Icons.search,
                              size: 18, color: cs.onSurfaceVariant),
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
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
                            borderSide:
                                BorderSide(color: cs.primary, width: 1.5),
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
                              child: Text('No reports found.',
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 13)),
                            ),
                          for (final (section, r) in searchResults) ...[
                            _reportTile(cs, r,
                                prefixLabel: '$section / ${r.label}'),
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
                              'Favorites',
                              trailing: TextButton(
                                onPressed: onClearFavorites,
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.primary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Clear favorites',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const Divider(height: 1),
                            for (final r in favoriteReports) ...[
                              _reportTile(cs, r,
                                  prefixLabel:
                                      '${_sectionOf(r.id)} / ${r.label}'),
                              Divider(height: 1, color: cs.outlineVariant),
                            ],
                          ],
                          // All sections
                          for (final (section, reports) in _allSections) ...[
                            _sectionLabel(cs, section),
                            const Divider(height: 1),
                            for (final r in reports) ...[
                              _reportTile(cs, r),
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
    final company = ref.watch(selectedCompanyProvider);
    final customers = ref.watch(allCustomersProvider).value ?? [];
    final users = ref.watch(allUsersProvider).value ?? [];
    final products = ref.watch(allProductsListProvider).value ?? [];

    String customerLabel() {
      if (tab.filter.customerId == null) return 'All';
      return customers
              .where((c) => c.id == tab.filter.customerId)
              .map((c) => c.name)
              .firstOrNull ??
          'All';
    }

    String userLabel() {
      if (tab.filter.userId == null) return 'All';
      return users
              .where((u) => u.id == tab.filter.userId)
              .map((u) =>
                  '${u.firstName ?? ''} ${u.lastName ?? ''}'.trim())
              .firstOrNull ??
          'All';
    }

    String productLabel() {
      if (tab.filter.productId == null) return 'All';
      return products
              .where((p) => p.id == tab.filter.productId)
              .map((p) => p.name)
              .firstOrNull ??
          'All';
    }

    if (tab.reportType.id == 'sales_by_product') {
      final async = ref.watch(salesByProductProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'SalesByProduct.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildProductsPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'SalesByProductGroup.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildProductGroupsPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'SalesByCustomer.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildCustomersPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'SalesTax.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildTaxPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'PaymentTypesByCustomer.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPaymentTypesByCustomerPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'PaymentTypesByUser.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPaymentTypesByUserPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'SalesByPaymentType.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPaymentTypesPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'Refunds.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildRefundsPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'InvoiceList.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildInvoiceListPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'DailySales.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildDailySalesPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'HourlySales.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildHourlySalesPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'HourlySalesByGroup.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildHourlySalesByGroupPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'SalesByTable.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildSalesByTablePdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'Profit.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildProfitPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'UnpaidSales.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildUnpaidSalesPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'StartingCash.pdf',
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildStartingCashPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'StockMovement.pdf',
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildStockMovementPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'ItemsDiscounts.pdf',
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildItemsDiscountsPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'DiscountsGranted.pdf',
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildDiscountsGrantedPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'DiscountsBySource.pdf',
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildDiscountsBySourcePdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'VoidedItems.pdf',
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildVoidedItemsPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'SalesItemList.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildItemListPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'SalesByUser.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildUsersPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'UnpaidPurchase.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildUnpaidPurchasePdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'PurchaseBySupplier.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPurchaseBySupplierPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'PurchaseByProduct.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPurchaseByProductPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'PurchaseTax.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPurchaseTaxPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'PurchaseExpirationDate.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPurchaseExpirationDatePdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'PurchaseInvoices.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPurchaseInvoiceListPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'PurchaseItemsDiscounts.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPurchaseItemsDiscountsPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'PurchaseDiscounts.pdf',
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildPurchaseDiscountsPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'StockReturnByProduct.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildStockReturnByProductPdf(
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
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'LossAndDamageByProduct.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildLossAndDamageByProductPdf(
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
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'ReorderProductList.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildReorderProductListPdf(
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
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'LowStockWarning.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildLowStockWarningPdf(
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
            'Please select a business partner in the filter panel.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        );
      }
      final async = ref.watch(transactionHistoryProvider(tab.filter));
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
        data: (rows) => PdfPreview(
          pdfFileName: 'TransactionHistory.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          canChangePageFormat: false,
          canDebug: false,
          allowSharing: false,
          build: (_) => _buildTransactionHistoryPdf(
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
      child: Text('This report is coming soon.',
          style: TextStyle(color: cs.onSurfaceVariant)),
    );
  }
}

// ─── PDF builder functions ────────────────────────────────────────────────────

Future<Uint8List> _buildProductsPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    build: (ctx) => [
      pw.Text('SALES BY PRODUCT',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          customerLabel, userLabel, productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Code', 'Product', 'Quantity', 'UOM', 'Total before tax', 'Total'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          2: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) => [
                r.code ?? '',
                r.product,
                fmt.format(r.quantity),
                r.uom,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ]),
          [
            '', 'Total',
            fmt.format(rows.fold(0.0, (s, r) => s + r.quantity)),
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
  ));

  return doc.save();
}

Future<Uint8List> _buildProductGroupsPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    build: (ctx) => [
      pw.Text('SALES BY PRODUCT GROUPS',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          customerLabel, userLabel, productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Product group', 'Quantity', 'Total before tax', 'Total'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) => [
                r.productGroup,
                fmt.format(r.quantity),
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ]),
          [
            'Total',
            fmt.format(rows.fold(0.0, (s, r) => s + r.quantity)),
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
  ));

  return doc.save();
}

Future<Uint8List> _buildTaxPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    build: (ctx) => [
      pw.Text('SALES TAX',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          customerLabel, userLabel, productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Tax name', 'Total before tax', 'Tax', 'Total'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) => [
                r.taxName,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.taxAmount),
                fmt.format(r.total),
              ]),
          [
            'Total',
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
  ));

  return doc.save();
}

Future<Uint8List> _buildCustomersPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    build: (ctx) => [
      pw.Text('SALES BY CUSTOMER',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          customerLabel, userLabel, productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Customer', 'Total before tax', 'Total'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) => [
                r.customer,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ]),
          [
            'Total',
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
  ));

  return doc.save();
}

Future<Uint8List> _buildPaymentTypesByCustomerPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  final paymentTypes = rows.map((r) => r.paymentTypeName).toSet().toList()..sort();
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

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    build: (ctx) => [
      pw.Text('PAYMENT TYPES BY CUSTOMERS',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          customerLabel, userLabel, productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Customer', ...paymentTypes, 'Total'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          for (var i = 1; i <= paymentTypes.length + 1; i++)
            i: pw.Alignment.centerRight,
        },
        columnWidths: colWidths,
        data: [
          ...customers.map((c) {
            final amounts =
                paymentTypes.map((pt) => pivot[c]?[pt] ?? 0.0).toList();
            final rowTotal = amounts.fold(0.0, (s, a) => s + a);
            return [c, ...amounts.map(fmt.format), fmt.format(rowTotal)];
          }),
          ['Total', ...grandAmounts.map(fmt.format), fmt.format(grandTotal)],
        ],
      ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildPaymentTypesByUserPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  final paymentTypes = rows.map((r) => r.paymentTypeName).toSet().toList()..sort();
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

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    build: (ctx) => [
      pw.Text('PAYMENT TYPES BY USERS',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          customerLabel, userLabel, productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['', ...paymentTypes, 'Total'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          for (var i = 1; i <= paymentTypes.length + 1; i++)
            i: pw.Alignment.centerRight,
        },
        columnWidths: colWidths,
        data: [
          ...users.map((u) {
            final amounts =
                paymentTypes.map((pt) => pivot[u]?[pt] ?? 0.0).toList();
            final rowTotal = amounts.fold(0.0, (s, a) => s + a);
            return [u, ...amounts.map(fmt.format), fmt.format(rowTotal)];
          }),
          ['Total', ...grandAmounts.map(fmt.format), fmt.format(grandTotal)],
        ],
      ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildPaymentTypesPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  // Pivot data
  final paymentTypes = rows.map((r) => r.paymentTypeName).toSet().toList()..sort();
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

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    build: (ctx) => [
      pw.Text('SALES BY PAYMENT TYPES',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          customerLabel, userLabel, productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Date', ...paymentTypes, 'Total'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          for (var i = 1; i <= paymentTypes.length + 1; i++)
            i: pw.Alignment.centerRight,
        },
        columnWidths: colWidths,
        data: [
          ...dates.map((d) {
            final amounts =
                paymentTypes.map((pt) => pivot[d]?[pt] ?? 0.0).toList();
            final rowTotal = amounts.fold(0.0, (s, a) => s + a);
            return [
              dateFmt.format(d),
              ...amounts.map(fmt.format),
              fmt.format(rowTotal),
            ];
          }),
          // Grand total row
          [
            '',
            ...grandAmounts.map(fmt.format),
            fmt.format(grandTotal),
          ],
        ],
      ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildItemListPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    margin: const pw.EdgeInsets.all(20),
    build: (ctx) => [
      pw.Text('SALES ITEM LIST',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          customerLabel, userLabel, productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: [
          'Document type', 'Date', 'Create date', 'Document number',
          'Ref. number', 'Customer code', 'Customer', 'Order number',
          'Code', 'Product', 'Quantity', 'UOM',
          'Total before tax', 'Total tax', 'Total',
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
        cellStyle: const pw.TextStyle(fontSize: 7),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          10: pw.Alignment.centerRight,
          12: pw.Alignment.centerRight,
          13: pw.Alignment.centerRight,
          14: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) => [
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
                fmt.format(r.quantity),
                r.uom,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.totalTax),
                fmt.format(r.total),
              ]),
          [
            '', '', '', '', '', '', '', '', '', 'Total',
            fmt.format(rows.fold(0.0, (s, r) => s + r.quantity)),
            '',
            fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
            fmt.format(rows.fold(0.0, (s, r) => s + r.totalTax)),
            fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
          ],
        ],
        columnWidths: const {
          0:  pw.FixedColumnWidth(40),
          1:  pw.FixedColumnWidth(42),
          2:  pw.FixedColumnWidth(68),
          3:  pw.FixedColumnWidth(68),
          4:  pw.FixedColumnWidth(38),
          5:  pw.FixedColumnWidth(45),
          6:  pw.FlexColumnWidth(1.5),
          7:  pw.FixedColumnWidth(36),
          8:  pw.FixedColumnWidth(32),
          9:  pw.FlexColumnWidth(2),
          10: pw.FixedColumnWidth(42),
          11: pw.FixedColumnWidth(26),
          12: pw.FixedColumnWidth(52),
          13: pw.FixedColumnWidth(46),
          14: pw.FixedColumnWidth(52),
        },
      ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildProfitPdf({
  required List<ProfitRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt     = NumberFormat('#,##0.00');
  final pctFmt  = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  final grandQty    = rows.fold(0.0, (s, r) => s + r.quantity);
  final grandCost   = rows.fold(0.0, (s, r) => s + r.cost);
  final grandTotal  = rows.fold(0.0, (s, r) => s + r.total);
  final grandProfit = grandTotal - grandCost;

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    margin: const pw.EdgeInsets.all(20),
    build: (ctx) => [
      pw.Text('PROFIT',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Period:   ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: '${dateFmt.format(filter.startDate)} - ${dateFmt.format(filter.endDate)}', style: const pw.TextStyle(fontSize: 9)),
              ])),
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Customer: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: customerLabel, style: const pw.TextStyle(fontSize: 9)),
              ])),
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'User:     ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: userLabel, style: const pw.TextStyle(fontSize: 9)),
              ])),
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Product:  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: productLabel, style: const pw.TextStyle(fontSize: 9)),
              ])),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Company: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: companyName ?? '', style: const pw.TextStyle(fontSize: 9)),
              ])),
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Address: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: companyAddress ?? '', style: const pw.TextStyle(fontSize: 9)),
              ])),
            ],
          )),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Code', 'Product', 'Quantity', 'Cost', 'Total', 'Profit', 'Margin'],
        headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle:        const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
          6: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) => [
                r.productCode ?? '',
                r.productName,
                fmt.format(r.quantity),
                fmt.format(r.cost),
                fmt.format(r.total),
                fmt.format(r.profit),
                '${pctFmt.format(r.margin)}%',
              ]),
          [
            '', '',
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
  ));

  return doc.save();
}

Future<Uint8List> _buildStockMovementPdf({
  required List<StockMovementRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String userLabel,
  required String productLabel,
}) async {
  final doc    = pw.Document();
  final hdrFmt = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  final total   = rows.fold(0.0, (s, r) => s + r.numSales);
  final average = rows.isEmpty ? 0.0 : total / rows.length;

  final fast = rows.where((r) => r.numSales >= average).toList()
    ..sort((a, b) => b.numSales.compareTo(a.numSales));
  final slow = rows.where((r) => r.numSales < average).toList()
    ..sort((a, b) => b.numSales.compareTo(a.numSales));

  pw.Widget hdrRow(String label, String value) => pw.RichText(
      text: pw.TextSpan(children: [
        pw.TextSpan(text: '$label  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.TextSpan(text: value,      style: const pw.TextStyle(fontSize: 9)),
      ]));

  pw.Widget sectionTable(String title, List<StockMovementRow> items) =>
      pw.Column(children: [
        pw.TableHelper.fromTextArray(
          headers: ['#', title, 'Num. of sales'],
          headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle:        const pw.TextStyle(fontSize: 8),
          headerDecoration: pw.BoxDecoration(color: title == 'Fast moving' ? PdfColors.red100 : PdfColors.grey200),
          cellAlignments: {
            0: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
          },
          columnWidths: const {
            0: pw.FixedColumnWidth(24),
            1: pw.FlexColumnWidth(1),
            2: pw.FixedColumnWidth(80),
          },
          data: items.asMap().entries.map((e) => [
            '${e.key + 1}',
            e.value.productName,
            e.value.numSales.toStringAsFixed(0),
          ]).toList(),
        ),
        pw.SizedBox(height: 8),
      ]);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(24),
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
        pw.Text('Page ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('STOCK MOVEMENT',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              hdrRow('Period:',  '${hdrFmt.format(filter.startDate)} - ${hdrFmt.format(filter.endDate)}'),
              hdrRow('User:',    userLabel),
              hdrRow('Product:', productLabel),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              hdrRow('Company:', companyName ?? ''),
              hdrRow('Address:', companyAddress ?? ''),
            ],
          )),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Total number of sales: ${total.toStringAsFixed(0)}',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Average number of sales per item: ${average.toStringAsFixed(0)}',
                  style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      if (fast.isNotEmpty) sectionTable('Fast moving', fast),
      if (slow.isNotEmpty) sectionTable('Slow moving', slow),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildItemsDiscountsPdf({
  required List<ItemsDiscountsRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc    = pw.Document();
  final fmt    = NumberFormat('#,##0.00');
  final hdrFmt = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  final grandTotal = rows.fold(0.0, (s, r) => s + r.totalDiscount);

  pw.Widget hdrRow(String label, String value) => pw.RichText(
      text: pw.TextSpan(children: [
        pw.TextSpan(text: '$label  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.TextSpan(text: value,      style: const pw.TextStyle(fontSize: 9)),
      ]));

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(24),
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
        pw.Text('Page ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('ITEMS DISCOUNTS',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              hdrRow('Period:',   '${hdrFmt.format(filter.startDate)} - ${hdrFmt.format(filter.endDate)}'),
              hdrRow('Customer:', customerLabel),
              hdrRow('User:',     userLabel),
              hdrRow('Product:',  productLabel),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              hdrRow('Company:', companyName ?? ''),
              hdrRow('Address:', companyAddress ?? ''),
            ],
          )),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['#', 'Code', 'Product', 'Total discount'],
        headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        cellStyle:        const pw.TextStyle(fontSize: 8),
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
        data: rows.asMap().entries.map((e) => [
          '${e.key + 1}',
          e.value.productCode ?? '',
          e.value.productName,
          fmt.format(e.value.totalDiscount),
        ]).toList(),
      ),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: pw.Text(
              fmt.format(grandTotal),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
          ),
        ],
      ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildDiscountsBySourcePdf({
  required List<DiscountBySourceRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  final grandTotal = rows.fold(0.0, (s, r) => s + r.amount);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(24),
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
        pw.Text('Page ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('DISCOUNTS BY SOURCE',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress, 'All', 'All', 'All'),
      pw.SizedBox(height: 12),
      if (rows.isEmpty)
        pw.Text('No discounts in this period.',
            style: const pw.TextStyle(fontSize: 10))
      else
        pw.TableHelper.fromTextArray(
          headers: ['Discount source', 'Total'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
          columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FixedColumnWidth(90)},
          data: [
            for (final r in rows) [r.label, fmt.format(r.amount)],
            ['Total', fmt.format(grandTotal)],
          ],
        ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildDiscountsGrantedPdf({
  required List<DiscountsGrantedRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
}) async {
  final doc    = pw.Document();
  final fmt    = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');
  final hdrFmt  = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  // Group by customer (order preserved from backend: alphabetical)
  final grouped = <String, List<DiscountsGrantedRow>>{};
  for (final r in rows) {
    grouped.putIfAbsent(r.customerName, () => []).add(r);
  }

  final grandTotal  = rows.fold(0.0, (s, r) => s + r.discountGranted);
  final totalOrders = rows.length;

  pw.Widget hdrRow(String label, String value) => pw.RichText(
      text: pw.TextSpan(children: [
        pw.TextSpan(text: '$label  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.TextSpan(text: value,      style: const pw.TextStyle(fontSize: 9)),
      ]));

  const colWidths = {
    0: pw.FlexColumnWidth(1.5),
    1: pw.FixedColumnWidth(58),
    2: pw.FixedColumnWidth(58),
    3: pw.FixedColumnWidth(62),
    4: pw.FixedColumnWidth(62),
    5: pw.FixedColumnWidth(62),
  };

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(24),
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
        pw.Text('Page ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('DISCOUNTS GRANTED (AFTER TAX)',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              hdrRow('Period:',   '${hdrFmt.format(filter.startDate)} - ${hdrFmt.format(filter.endDate)}'),
              hdrRow('Customer:', customerLabel),
              hdrRow('User:',     userLabel),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              hdrRow('Company:', companyName ?? ''),
              hdrRow('Address:', companyAddress ?? ''),
            ],
          )),
        ],
      ),
      pw.SizedBox(height: 12),
      for (final entry in grouped.entries) ...[
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          child: pw.Text('Customer: ${entry.key}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ),
        pw.TableHelper.fromTextArray(
          headers: ['Document', 'Date', 'User', 'Total before disc.', 'Total after disc.', 'Discount granted'],
          headerStyle:     pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
          cellStyle:       const pw.TextStyle(fontSize: 7),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          columnWidths: colWidths,
          data: [
            ...entry.value.map((r) => [
              r.documentNumber,
              dateFmt.format(r.date),
              r.userName,
              fmt.format(r.totalBeforeDiscount),
              fmt.format(r.totalAfterDiscount),
              fmt.format(r.discountGranted),
            ]),
            // Customer subtotal row
            ['', '', '', '', '',
              fmt.format(entry.value.fold(0.0, (s, r) => s + r.discountGranted))],
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
              pw.Text('Number of orders discounted:  $totalOrders',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 2),
              pw.Text('Total discounted:  ${fmt.format(grandTotal)}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildVoidedItemsPdf({
  required List<VoidedItemRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String userLabel,
  required String productLabel,
}) async {
  final doc     = pw.Document();
  final fmt     = NumberFormat('#,##0.00');
  final dtFmt   = DateFormat('dd/MM/yyyy HH:mm:ss');
  final hdrFmt  = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  final grandTotal = rows.fold(0.0, (s, r) => s + r.total);

  pw.Widget hdrRow(String label, String value) => pw.RichText(
      text: pw.TextSpan(children: [
        pw.TextSpan(text: '$label  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 9)),
      ]));

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(24),
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
        pw.Text('Page ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('VOIDED ITEMS',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              hdrRow('Period:', '${hdrFmt.format(filter.startDate)} - ${hdrFmt.format(filter.endDate)}'),
              hdrRow('User:', userLabel),
              hdrRow('Product:', productLabel),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              hdrRow('Company:', companyName ?? ''),
              hdrRow('Address:', companyAddress ?? ''),
            ],
          )),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Product', 'Voided by', 'Qty.', 'Price', 'Discount', 'Status', 'Order #', 'Created', 'Voided', 'Total', 'Reason'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
        cellStyle:   const pw.TextStyle(fontSize: 7),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          9: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) => [
            r.productName,
            r.voidedByName ?? '',
            r.quantity.toStringAsFixed(0),
            fmt.format(r.price),
            r.discountDisplay,
            r.isConfirmed ? 'Confirmed' : 'Pending',
            r.orderNumber,
            dtFmt.format(r.dateCreated),
            dtFmt.format(r.dateVoided),
            fmt.format(r.total),
            r.reason ?? '',
          ]),
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
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: pw.Text(
              fmt.format(grandTotal),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
          ),
        ],
      ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildStartingCashPdf({
  required List<StartingCashRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String userLabel,
}) async {
  final doc     = pw.Document();
  final fmt     = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  final hdrFmt  = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  final totalCashIn  = rows.where((r) => !r.isCashOut).fold(0.0, (s, r) => s + r.amount);
  final totalCashOut = rows.where((r) =>  r.isCashOut).fold(0.0, (s, r) => s + r.amount);
  final netTotal     = totalCashIn - totalCashOut;

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(24),
    build: (ctx) => [
      pw.Text('STARTING CASH ENTRIES',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Period:  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: '${hdrFmt.format(filter.startDate)} – ${hdrFmt.format(filter.endDate)}', style: const pw.TextStyle(fontSize: 9)),
              ])),
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'User:    ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: userLabel, style: const pw.TextStyle(fontSize: 9)),
              ])),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Company: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: companyName ?? '', style: const pw.TextStyle(fontSize: 9)),
              ])),
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Address: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: companyAddress ?? '', style: const pw.TextStyle(fontSize: 9)),
              ])),
            ],
          )),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['User', 'Type', 'Description', 'Date', 'Amount', 'Z-Report #'],
        headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        cellStyle:        const pw.TextStyle(fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {4: pw.Alignment.centerRight},
        data: [
          ...rows.map((r) => [
            r.userName ?? '',
            r.isCashOut ? 'Cash Out' : 'Cash In',
            r.description ?? '',
            dateFmt.format(r.dateCreated),
            r.isCashOut
                ? '-${fmt.format(r.amount)}'
                : fmt.format(r.amount),
            r.zReportNumber?.toString() ?? '',
          ]),
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
      pw.Divider(borderStyle: pw.BorderStyle.dashed, color: PdfColors.grey400),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.RichText(text: pw.TextSpan(children: [
                const pw.TextSpan(text: 'Cash In:   ', style: pw.TextStyle(fontSize: 9)),
                pw.TextSpan(text: fmt.format(totalCashIn),  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ])),
              pw.RichText(text: pw.TextSpan(children: [
                const pw.TextSpan(text: 'Cash Out:  ', style: pw.TextStyle(fontSize: 9)),
                pw.TextSpan(text: '-${fmt.format(totalCashOut)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ])),
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Net Total: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.TextSpan(text: fmt.format(netTotal), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ])),
            ],
          ),
        ],
      ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildUnpaidSalesPdf({
  required List<UnpaidSalesRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
}) async {
  final doc = pw.Document();
  final fmt     = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');
  final hdrDatFmt = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  // Group by customer (data already sorted by customerName from backend)
  final byCustomer = <String, List<UnpaidSalesRow>>{};
  for (final r in rows) {
    byCustomer.putIfAbsent(r.customerName, () => []).add(r);
  }
  final grandTotal = rows.fold(0.0, (s, r) => s + r.totalUnpaid);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    margin: const pw.EdgeInsets.all(20),
    build: (ctx) {
      final widgets = <pw.Widget>[
        pw.Text('UNPAID SALES',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Period:   ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: '${hdrDatFmt.format(filter.startDate)} - ${hdrDatFmt.format(filter.endDate)}', style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Customer: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: customerLabel, style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'User:     ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: userLabel, style: const pw.TextStyle(fontSize: 9)),
                ])),
              ],
            )),
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Company: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: companyName ?? '', style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Address: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: companyAddress ?? '', style: const pw.TextStyle(fontSize: 9)),
                ])),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 12),
      ];

      for (final entry in byCustomer.entries) {
        final customerName = entry.key;
        final docs = entry.value;
        final customerUnpaid = docs.fold(0.0, (s, r) => s + r.totalUnpaid);

        widgets.add(pw.Container(
          color: PdfColors.grey200,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: pw.Text('Customer: $customerName',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ));

        widgets.add(pw.TableHelper.fromTextArray(
          headers: ['Document number', 'Date', 'Due date', 'Total', 'Total paid', 'Total unpaid'],
          headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle:        const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          data: [
            ...docs.map((r) => [
                  r.documentNumber,
                  dateFmt.format(r.date),
                  r.dueDate != null ? dateFmt.format(r.dueDate!) : '',
                  fmt.format(r.documentTotal),
                  fmt.format(r.totalPaid),
                  fmt.format(r.totalUnpaid),
                ]),
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
        ));

        widgets.add(pw.SizedBox(height: 6));
      }

      widgets.addAll([
        pw.Divider(borderStyle: pw.BorderStyle.dashed, color: PdfColors.grey400),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('Total:  ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text(fmt.format(grandTotal),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          ],
        ),
      ]);

      return widgets;
    },
  ));

  return doc.save();
}

Future<Uint8List> _buildHourlySalesByGroupPdf({
  required List<HourlySalesByGroupRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt     = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');
  final timeFmt = DateFormat('h:mm a');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  final hours  = rows.map((r) => r.hour).toSet().toList()..sort();
  final groups = rows.map((r) => r.productGroup).toSet().toList()..sort();
  final pivot  = <String, Map<int, double>>{};
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

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    margin: const pw.EdgeInsets.all(20),
    build: (ctx) => [
      pw.Text('HOURLY SALES BY PRODUCT GROUPS',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: 'Company: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.TextSpan(text: companyName ?? '', style: const pw.TextStyle(fontSize: 9)),
            ])),
            pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: 'Address: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.TextSpan(text: companyAddress ?? '', style: const pw.TextStyle(fontSize: 9)),
            ])),
          ]),
        ],
      ),
      pw.Divider(height: 12),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: 'Period:   ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.TextSpan(text: '${dateFmt.format(filter.startDate)} - ${dateFmt.format(filter.endDate)}', style: const pw.TextStyle(fontSize: 9)),
            ])),
            pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: 'Product:  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.TextSpan(text: productLabel, style: const pw.TextStyle(fontSize: 9)),
            ])),
            pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: 'Customer: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.TextSpan(text: customerLabel, style: const pw.TextStyle(fontSize: 9)),
            ])),
          ]),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: [
          '',
          ...hours.map((h) => timeFmt.format(DateTime(2000, 1, 1, h))),
          'Total',
        ],
        headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle:        const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          for (var i = 1; i <= hours.length + 1; i++) i: pw.Alignment.centerRight,
        },
        data: [
          ...groups.map((g) => [
                g,
                ...hours.map((h) => fmt.format(pivot[g]?[h] ?? 0.0)),
                fmt.format(groupTotals[g] ?? 0.0),
              ]),
          [
            'Total',
            ...hours.map((h) => fmt.format(hourTotals[h] ?? 0.0)),
            fmt.format(grandTotal),
          ],
        ],
      ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildSalesByTablePdf({
  required List<SalesByTableRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
}) async {
  final doc = pw.Document();
  final fmt     = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  final grandCount = rows.fold(0, (s, r) => s + r.numberOfSales);
  final grandTotal = rows.fold(0.0, (s, r) => s + r.total);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    margin: const pw.EdgeInsets.all(20),
    build: (ctx) => [
      pw.Text('SALES BY TABLE / ORDER NUMBER',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Period:   ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: '${dateFmt.format(filter.startDate)} - ${dateFmt.format(filter.endDate)}', style: const pw.TextStyle(fontSize: 9)),
              ])),
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Customer: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: customerLabel, style: const pw.TextStyle(fontSize: 9)),
              ])),
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'User:     ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: userLabel, style: const pw.TextStyle(fontSize: 9)),
              ])),
            ]),
          ),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Company: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: companyName ?? '', style: const pw.TextStyle(fontSize: 9)),
              ])),
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Address: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.TextSpan(text: companyAddress ?? '', style: const pw.TextStyle(fontSize: 9)),
              ])),
            ]),
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Table / order number', 'Number of sales', 'Total'],
        headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle:        const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) => [r.orderNumber, '${r.numberOfSales}', fmt.format(r.total)]),
          ['', '$grandCount', fmt.format(grandTotal)],
        ],
        columnWidths: const {
          0: pw.FlexColumnWidth(2),
          1: pw.FixedColumnWidth(80),
          2: pw.FixedColumnWidth(80),
        },
      ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildHourlySalesPdf({
  required List<HourlySalesRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
}) async {
  final doc = pw.Document();
  final fmt     = NumberFormat('#,##0.00');
  final pctFmt  = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');
  final timeFmt = DateFormat('h:mm a');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  final grandTotal = rows.fold(0.0, (s, r) => s + r.totalSales);
  final grandCount = rows.fold(0, (s, r) => s + r.salesCount);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    margin: const pw.EdgeInsets.all(20),
    build: (ctx) => [
      pw.Text('HOURLY SALES',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Period:   ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: '${dateFmt.format(filter.startDate)} - ${dateFmt.format(filter.endDate)}', style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Customer: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: customerLabel, style: const pw.TextStyle(fontSize: 9)),
                ])),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Company: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: companyName ?? '', style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Address: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: companyAddress ?? '', style: const pw.TextStyle(fontSize: 9)),
                ])),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Hours', '', 'Total sales', 'Sales count', 'Average sale', '%'],
        headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle:        const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) {
            final start   = DateTime(2000, 1, 1, r.hour);
            final end     = DateTime(2000, 1, 1, r.hour, 59);
            final avg     = r.salesCount > 0 ? r.totalSales / r.salesCount : 0.0;
            final pct     = grandTotal > 0 ? r.totalSales / grandTotal * 100 : 0.0;
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
  ));

  return doc.save();
}

Future<Uint8List> _buildDailySalesPdf({
  required List<DailySalesRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
}) async {
  final doc = pw.Document();
  final fmt    = NumberFormat('#,##0.00');
  final dayFmt = DateFormat('dd/MM/yyyy (EEE)');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    margin: const pw.EdgeInsets.all(20),
    build: (ctx) => [
      pw.Text('DAILY SALES',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Period:   ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: '${dateFmt.format(filter.startDate)} - ${dateFmt.format(filter.endDate)}', style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Customer: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: customerLabel, style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'User:     ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: userLabel, style: const pw.TextStyle(fontSize: 9)),
                ])),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Company: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: companyName ?? '', style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Address: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: companyAddress ?? '', style: const pw.TextStyle(fontSize: 9)),
                ])),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Date', 'Total'],
        headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle:        const pw.TextStyle(fontSize: 9),
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
  ));

  return doc.save();
}

Future<Uint8List> _buildInvoiceListPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    margin: const pw.EdgeInsets.all(20),
    build: (ctx) => [
      pw.Text('INVOICES',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Period:   ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: '${dateFmt.format(filter.startDate)} - ${dateFmt.format(filter.endDate)}', style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Customer: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: customerLabel, style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'User:     ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: userLabel, style: const pw.TextStyle(fontSize: 9)),
                ])),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Company: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: companyName ?? '', style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Address: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: companyAddress ?? '', style: const pw.TextStyle(fontSize: 9)),
                ])),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['#', 'Date', 'Document number', 'Customer', 'Payment method', 'Total'],
        headerStyle:     pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        cellStyle:       const pw.TextStyle(fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          0: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
        },
        data: [
          ...rows.asMap().entries.map((e) => [
                '${e.key + 1}',
                dateFmt.format(e.value.date),
                e.value.documentNumber,
                e.value.customerName,
                e.value.paymentMethodName,
                fmt.format(e.value.total),
              ]),
          [
            '', '', '', '', 'Total',
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
  ));

  return doc.save();
}

Future<Uint8List> _buildRefundsPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    margin: const pw.EdgeInsets.all(20),
    build: (ctx) => [
      pw.Text('REFUNDS',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          customerLabel, userLabel, productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: [
          'Document #', 'Ref. #', 'Date',
          'Customer code', 'Customer',
          'Code', 'Product', 'Quantity', 'UOM',
          'Total before tax', 'Total tax', 'Total',
        ],
        headerStyle:     pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        cellStyle:       const pw.TextStyle(fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          7:  pw.Alignment.centerRight,
          9:  pw.Alignment.centerRight,
          10: pw.Alignment.centerRight,
          11: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) => [
                r.documentNumber,
                r.refNumber ?? '',
                dateFmt.format(r.date),
                r.customerCode ?? '',
                r.customerName,
                r.productCode ?? '',
                r.productName,
                fmt.format(r.quantity),
                r.uom,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.totalTax),
                fmt.format(r.total),
              ]),
          [
            '', '', '', '', '', '', 'Total',
            fmt.format(rows.fold(0.0, (s, r) => s + r.quantity)),
            '',
            fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
            fmt.format(rows.fold(0.0, (s, r) => s + r.totalTax)),
            fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
          ],
        ],
        columnWidths: const {
          0:  pw.FixedColumnWidth(62),
          1:  pw.FixedColumnWidth(46),
          2:  pw.FixedColumnWidth(42),
          3:  pw.FixedColumnWidth(46),
          4:  pw.FlexColumnWidth(1.5),
          5:  pw.FixedColumnWidth(32),
          6:  pw.FlexColumnWidth(2),
          7:  pw.FixedColumnWidth(42),
          8:  pw.FixedColumnWidth(24),
          9:  pw.FixedColumnWidth(52),
          10: pw.FixedColumnWidth(46),
          11: pw.FixedColumnWidth(52),
        },
      ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildUsersPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    build: (ctx) => [
      pw.Text('SALES BY USERS',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          customerLabel, userLabel, productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['User', 'Total before tax', 'Total'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) => [
                r.user,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ]),
          [
            'Total',
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
  ));

  return doc.save();
}

Future<Uint8List> _buildUnpaidPurchasePdf({
  required List<UnpaidPurchaseRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String supplierLabel,
  required String userLabel,
}) async {
  final doc = pw.Document();
  final fmt       = NumberFormat('#,##0.00');
  final dateFmt   = DateFormat('dd/MM/yyyy');
  final hdrDatFmt = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  final bySupplier = <String, List<UnpaidPurchaseRow>>{};
  for (final r in rows) {
    bySupplier.putIfAbsent(r.supplierName, () => []).add(r);
  }
  final grandTotal = rows.fold(0.0, (s, r) => s + r.totalUnpaid);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    margin: const pw.EdgeInsets.all(20),
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Page ${ctx.pageNumber}',
            style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) {
      final widgets = <pw.Widget>[
        pw.Text('UNPAID PURCHASE',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Period:   ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: '${hdrDatFmt.format(filter.startDate)} - ${hdrDatFmt.format(filter.endDate)}', style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Supplier: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: supplierLabel, style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'User:     ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: userLabel, style: const pw.TextStyle(fontSize: 9)),
                ])),
              ],
            )),
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Company: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: companyName ?? '', style: const pw.TextStyle(fontSize: 9)),
                ])),
                pw.RichText(text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Address: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.TextSpan(text: companyAddress ?? '', style: const pw.TextStyle(fontSize: 9)),
                ])),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 12),
      ];

      for (final entry in bySupplier.entries) {
        final supplierName = entry.key;
        final docs = entry.value;
        final supplierUnpaid = docs.fold(0.0, (s, r) => s + r.totalUnpaid);

        widgets.add(pw.Container(
          color: PdfColors.grey200,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: pw.Text('Supplier: $supplierName',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ));

        widgets.add(pw.TableHelper.fromTextArray(
          headers: ['Document number', 'Date', 'Due date', 'Total', 'Total paid', 'Total unpaid'],
          headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle:        const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          data: [
            ...docs.map((r) => [
                  r.documentNumber,
                  dateFmt.format(r.date),
                  r.dueDate != null ? dateFmt.format(r.dueDate!) : '',
                  fmt.format(r.documentTotal),
                  fmt.format(r.totalPaid),
                  fmt.format(r.totalUnpaid),
                ]),
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
        ));

        widgets.add(pw.SizedBox(height: 6));
      }

      widgets.addAll([
        pw.Divider(borderStyle: pw.BorderStyle.dashed, color: PdfColors.grey400),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('Total:  ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text(fmt.format(grandTotal),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          ],
        ),
      ]);

      return widgets;
    },
  ));

  return doc.save();
}

Future<Uint8List> _buildPurchaseBySupplierPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Page ${ctx.pageNumber}',
            style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('PURCHASE BY SUPPLIER',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          supplierLabel, userLabel, productLabel,
          customerRowLabel: 'Supplier'),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Supplier', 'Total before tax', 'Total'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) => [
                r.supplier,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ]),
          [
            'Total',
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
  ));

  return doc.save();
}

Future<Uint8List> _buildPurchaseByProductPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Page ${ctx.pageNumber}',
            style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('PURCHASE BY PRODUCT',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          supplierLabel, userLabel, productLabel,
          customerRowLabel: 'Supplier'),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Code', 'Product', 'Quantity', 'UOM', 'Total before tax', 'Total'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          2: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) => [
                r.code ?? '',
                r.product,
                fmt.format(r.quantity),
                r.uom,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ]),
          [
            '', 'Total',
            fmt.format(rows.fold(0.0, (s, r) => s + r.quantity)),
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
  ));

  return doc.save();
}

Future<Uint8List> _buildPurchaseExpirationDatePdf({
  required List<PurchaseExpirationDateRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc     = pw.Document();
  final fmt     = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
        pw.Text('Page ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('EXPIRATION DATE',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          customerLabel, userLabel, productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['#', 'Code', 'Product', 'Quantity', 'UOM', 'Expiration date'],
        headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle:        const pw.TextStyle(fontSize: 9),
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
        data: rows.asMap().entries.map((e) => [
              '${e.key + 1}',
              e.value.productCode ?? '',
              e.value.productName,
              fmt.format(e.value.quantity),
              e.value.uom,
              dateFmt.format(e.value.expirationDate),
            ]).toList(),
      ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildPurchaseTaxPdf({
  required List<PurchaseByTaxRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String customerLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc     = pw.Document();
  final fmt     = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
        pw.Text('Page ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('PURCHASE TAX',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          customerLabel, userLabel, productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Tax name', 'Total before tax', 'Tax', 'Total'],
        headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle:        const pw.TextStyle(fontSize: 9),
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
          ...rows.map((r) => [
                r.taxName,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.taxAmount),
                fmt.format(r.total),
              ]),
          [
            '',
            fmt.format(rows.fold(0.0, (s, r) => s + r.totalBeforeTax)),
            fmt.format(rows.fold(0.0, (s, r) => s + r.taxAmount)),
            fmt.format(rows.fold(0.0, (s, r) => s + r.total)),
          ],
        ],
      ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildPurchaseInvoiceListPdf({
  required List<PurchaseInvoiceListRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String supplierLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc    = pw.Document();
  final fmt    = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  final grandTotal = rows.fold(0.0, (s, r) => s + r.total);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
        pw.Text('Page ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('PURCHASE INVOICES',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          supplierLabel, userLabel, productLabel,
          customerRowLabel: 'Supplier'),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['#', 'Supplier', 'Purchase number', 'External document', 'Date', 'Total'],
        headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle:        const pw.TextStyle(fontSize: 9),
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
          ...rows.asMap().entries.map((e) => [
            '${e.key + 1}',
            e.value.supplierName,
            e.value.documentNumber,
            e.value.externalDocument ?? '',
            dateFmt.format(e.value.date),
            fmt.format(e.value.total),
          ]),
          ['', '', '', '', '', fmt.format(grandTotal)],
        ],
      ),
    ],
  ));

  return doc.save();
}

Future<Uint8List> _buildPurchaseItemsDiscountsPdf({
  required List<PurchaseItemsDiscountsRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String supplierLabel,
  required String userLabel,
  required String productLabel,
}) async {
  final doc    = pw.Document();
  final fmt    = NumberFormat('#,##0.00');
  final hdrFmt = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  // Group by supplier
  final grouped = <String, List<PurchaseItemsDiscountsRow>>{};
  for (final r in rows) {
    grouped.putIfAbsent(r.supplierName, () => []).add(r);
  }

  final grandTotalDiscount = rows.fold(0.0, (s, r) => s + r.totalDiscount);

  pw.Widget hdrRow(String label, String value) => pw.RichText(
      text: pw.TextSpan(children: [
        pw.TextSpan(text: '$label  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.TextSpan(text: value,      style: const pw.TextStyle(fontSize: 9)),
      ]));

  const colWidths = {
    0: pw.FixedColumnWidth(14),   // #
    1: pw.FixedColumnWidth(44),   // Code
    2: pw.FlexColumnWidth(2),     // Product
    3: pw.FixedColumnWidth(42),   // Qty
    4: pw.FixedColumnWidth(56),   // Cost
    5: pw.FixedColumnWidth(62),   // Before disc.
    6: pw.FixedColumnWidth(62),   // After disc.
    7: pw.FixedColumnWidth(58),   // Discount
    8: pw.FixedColumnWidth(58),   // Total disc.
  };

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    margin: const pw.EdgeInsets.all(20),
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
        pw.Text('Page ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) {
      final widgets = <pw.Widget>[
        pw.Text('PURCHASED ITEMS DISCOUNTS',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                hdrRow('Period:',   '${hdrFmt.format(filter.startDate)} - ${hdrFmt.format(filter.endDate)}'),
                hdrRow('Supplier:', supplierLabel),
                hdrRow('User:',     userLabel),
                hdrRow('Product:',  productLabel),
              ],
            )),
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                hdrRow('Company:', companyName ?? ''),
                hdrRow('Address:', companyAddress ?? ''),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 12),
      ];

      for (final entry in grouped.entries) {
        final supplierRows = entry.value;
        final supplierTotal = supplierRows.fold(0.0, (s, r) => s + r.totalDiscount);

        widgets.add(pw.Container(
          width: double.infinity,
          color: PdfColors.grey200,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: pw.Text('Supplier: ${entry.key}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ));

        var rowIndex = 1;
        widgets.add(pw.TableHelper.fromTextArray(
          headers: ['#', 'Code', 'Product', 'Qty', 'Cost', 'Before disc.', 'After disc.', 'Discount', 'Total disc.'],
          headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
          cellStyle:        const pw.TextStyle(fontSize: 7),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
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
            ...supplierRows.map((r) => [
              '${rowIndex++}',
              r.productCode ?? '',
              r.productName,
              fmt.format(r.quantity),
              fmt.format(r.cost),
              fmt.format(r.totalBeforeDiscount),
              fmt.format(r.totalAfterDiscount),
              r.discountDisplay,
              fmt.format(r.totalDiscount),
            ]),
            ['', '', '', '', '', '', '', '',
              fmt.format(supplierTotal)],
          ],
        ));
        widgets.add(pw.SizedBox(height: 6));
      }

      widgets.addAll([
        pw.Divider(borderStyle: pw.BorderStyle.dashed, color: PdfColors.grey400),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('Total discount:  ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text(fmt.format(grandTotalDiscount),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          ],
        ),
      ]);

      return widgets;
    },
  ));

  return doc.save();
}

Future<Uint8List> _buildPurchaseDiscountsPdf({
  required List<PurchaseDiscountsRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String supplierLabel,
  required String userLabel,
}) async {
  final doc     = pw.Document();
  final fmt     = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');
  final hdrFmt  = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  final grouped = <String, List<PurchaseDiscountsRow>>{};
  for (final r in rows) {
    grouped.putIfAbsent(r.supplierName, () => []).add(r);
  }

  final grandTotal  = rows.fold(0.0, (s, r) => s + r.discountGranted);
  final totalOrders = rows.length;

  pw.Widget hdrRow(String label, String value) => pw.RichText(
      text: pw.TextSpan(children: [
        pw.TextSpan(text: '$label  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.TextSpan(text: value,      style: const pw.TextStyle(fontSize: 9)),
      ]));

  const colWidths = {
    0: pw.FlexColumnWidth(1.5),
    1: pw.FixedColumnWidth(58),
    2: pw.FixedColumnWidth(58),
    3: pw.FixedColumnWidth(62),
    4: pw.FixedColumnWidth(62),
    5: pw.FixedColumnWidth(62),
  };

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(24),
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
        pw.Text('Page ${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('PURCHASE DISCOUNTS',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              hdrRow('Period:',   '${hdrFmt.format(filter.startDate)} - ${hdrFmt.format(filter.endDate)}'),
              hdrRow('Supplier:', supplierLabel),
              hdrRow('User:',     userLabel),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              hdrRow('Company:', companyName ?? ''),
              hdrRow('Address:', companyAddress ?? ''),
            ],
          )),
        ],
      ),
      pw.SizedBox(height: 12),
      for (final entry in grouped.entries) ...[
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          child: pw.Text('Supplier: ${entry.key}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ),
        pw.TableHelper.fromTextArray(
          headers: ['Document', 'Date', 'User', 'Total before disc.', 'Total after disc.', 'Discount granted'],
          headerStyle:      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
          cellStyle:        const pw.TextStyle(fontSize: 7),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          columnWidths: colWidths,
          data: [
            ...entry.value.map((r) => [
              r.documentNumber,
              dateFmt.format(r.date),
              r.userName,
              fmt.format(r.totalBeforeDiscount),
              fmt.format(r.totalAfterDiscount),
              fmt.format(r.discountGranted),
            ]),
            ['', '', '', '', '',
              fmt.format(entry.value.fold(0.0, (s, r) => s + r.discountGranted))],
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
              pw.Text('Number of orders discounted: $totalOrders',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.SizedBox(height: 2),
              pw.Text('Total discounted: ${fmt.format(grandTotal)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            ],
          ),
        ],
      ),
    ],
  ));

  return doc.save();
}

pw.Widget _pdfHeader(
  DateFormat dateFmt,
  ReportFilter filter,
  String? companyName,
  String? companyAddress,
  String customerLabel,
  String userLabel,
  String productLabel, {
  String customerRowLabel = 'Customer',
}) {
  const ts = pw.TextStyle(fontSize: 9);
  final tb = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);

  row(String lbl, String val) => pw.Row(children: [
        pw.Text('$lbl: ', style: tb),
        pw.Text(val, style: ts),
      ]);

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        row('Period',
            '${dateFmt.format(filter.startDate)} – ${dateFmt.format(filter.endDate)}'),
        pw.SizedBox(height: 3),
        row(customerRowLabel, customerLabel),
        pw.SizedBox(height: 3),
        row('User', userLabel),
        pw.SizedBox(height: 3),
        row('Product', productLabel),
      ]),
      pw.SizedBox(width: 48),
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        row('Company', companyName ?? ''),
        pw.SizedBox(height: 3),
        row('Address', companyAddress ?? ''),
      ]),
    ],
  );
}

Future<Uint8List> _buildStockReturnByProductPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Page ${ctx.pageNumber}',
            style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('STOCK RETURNS BY PRODUCT',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          'N/A', userLabel, productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Date', 'Code', 'Product', 'Quantity', 'UOM', 'Total before tax', 'Total'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          3: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
          6: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) => [
                dateFmt.format(r.date),
                r.code ?? '',
                r.product,
                fmt.format(r.quantity),
                r.uom,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ]),
          [
            '', '', 'Total',
            fmt.format(rows.fold(0.0, (s, r) => s + r.quantity)),
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
  ));

  return doc.save();
}

Future<Uint8List> _buildLossAndDamageByProductPdf({
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

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Page ${ctx.pageNumber}',
            style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('LOSS AND DAMAGE BY PRODUCT',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(dateFmt, filter, companyName, companyAddress,
          'N/A', userLabel, productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Date', 'Code', 'Product', 'Quantity', 'UOM', 'Total before tax', 'Total'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignments: {
          3: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
          6: pw.Alignment.centerRight,
        },
        data: [
          ...rows.map((r) => [
                dateFmt.format(r.date),
                r.code ?? '',
                r.product,
                fmt.format(r.quantity),
                r.uom,
                fmt.format(r.totalBeforeTax),
                fmt.format(r.total),
              ]),
          [
            '', '', 'Total',
            fmt.format(rows.fold(0.0, (s, r) => s + r.quantity)),
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
  ));

  return doc.save();
}

Future<Uint8List> _buildReorderProductListPdf({
  required List<ReorderProductListRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String supplierLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

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

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Page ${ctx.pageNumber}',
            style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('REORDER PRODUCT LIST',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(DateFormat('dd/MM/yyyy'), filter, companyName, companyAddress,
          supplierLabel, 'N/A', productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Product name', 'Order qty.', 'UOM'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
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
  ));

  return doc.save();
}

Future<Uint8List> _buildLowStockWarningPdf({
  required List<LowStockWarningRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String supplierLabel,
  required String productLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

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

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Page ${ctx.pageNumber}',
            style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('LOW STOCK WARNING',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      _pdfHeader(DateFormat('dd/MM/yyyy'), filter, companyName, companyAddress,
          supplierLabel, 'N/A', productLabel),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Product name', 'Current stock', 'Warning qty.', 'Order qty.', 'UOM'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
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
  ));

  return doc.save();
}

Future<Uint8List> _buildTransactionHistoryPdf({
  required List<TransactionHistoryRow> rows,
  required ReportFilter filter,
  String? companyName,
  String? companyAddress,
  required String partnerLabel,
}) async {
  final doc = pw.Document();
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('dd/MM/yyyy');

  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    theme: theme,
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Page ${ctx.pageNumber}',
            style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (ctx) => [
      pw.Text('TRANSACTION HISTORY',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text('Business partner: $partnerLabel',
          style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 4),
      pw.Text(
          'Period: ${dateFmt.format(filter.startDate)} – ${dateFmt.format(filter.endDate)}',
          style: const pw.TextStyle(fontSize: 10)),
      if (companyName != null) ...[
        pw.SizedBox(height: 4),
        pw.Text(companyName, style: const pw.TextStyle(fontSize: 10)),
        if (companyAddress != null)
          pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 10)),
      ],
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Date', 'Transaction type', 'Ref. number', 'Credit', 'Debit', 'Balance'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
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
  ));

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
            Text('Filter',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            const Gap(16),

            _FilterLabel(reportId == 'transaction_history'
                ? 'Business partner (required)'
                : 'Customers & suppliers'),
            const Gap(4),
            _FilterDropdown<int?>(
              value: filter.customerId,
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...customers.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => onFilterChanged(filter.copyWith(customerId: v)),
            ),
            const Gap(12),

            if (reportId != 'transaction_history' &&
                reportId != 'reorder_list' &&
                reportId != 'low_stock_warning') ...[
              const _FilterLabel('User'),
              const Gap(4),
              _FilterDropdown<int?>(
                value: filter.userId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ...users.map((u) {
                    final name =
                        '${u.firstName ?? ''} ${u.lastName ?? ''}'.trim();
                    return DropdownMenuItem(
                        value: u.id,
                        child: Text(
                            name.isEmpty ? u.username ?? 'User ${u.id}' : name,
                            overflow: TextOverflow.ellipsis));
                  }),
                ],
                onChanged: (v) => onFilterChanged(filter.copyWith(userId: v)),
              ),
              const Gap(12),

              const _FilterLabel('Cash register'),
              const Gap(4),
              _FilterDropdown<int?>(
                value: filter.warehouseId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ...warehouses.map((w) => DropdownMenuItem(
                      value: w.id,
                      child: Text(w.name, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) =>
                    onFilterChanged(filter.copyWith(warehouseId: v)),
              ),
              const Gap(12),

              const _FilterLabel('Product'),
              const Gap(4),
              _FilterDropdown<int?>(
                value: filter.productId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ...products.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => onFilterChanged(filter.copyWith(productId: v)),
              ),
              const Gap(12),

              const _FilterLabel('Product group'),
              const Gap(4),
              _FilterDropdown<int?>(
                value: filter.productGroupId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ...groups.map((g) => DropdownMenuItem(
                      value: g.id,
                      child: Text(g.name, overflow: TextOverflow.ellipsis))),
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
                title: Text('Include subgroups',
                    style:
                        TextStyle(fontSize: 13, color: cs.onSurface)),
                value: filter.includeSubgroups,
                onChanged: (v) => onFilterChanged(
                    filter.copyWith(includeSubgroups: v ?? false)),
              ),

            const Gap(12),
            const Divider(),
            const Gap(8),

            if (reportId != 'reorder_list' && reportId != 'low_stock_warning') ...[
              const _FilterLabel('Period'),
              const Gap(6),
              Row(
                children: [
                  Expanded(
                    child: _DateButton(
                      label: dateFmt.format(filter.startDate),
                      onTap: () => _pickDate(context, true),
                    ),
                  ),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('–')),
                  Expanded(
                    child: _DateButton(
                      label: dateFmt.format(filter.endDate),
                      onTap: () => _pickDate(context, false),
                    ),
                  ),
                ],
              ),
              const Gap(16),
              const Divider(),
              const Gap(12),
            ],

            FilledButton.icon(
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Show report'),
              onPressed: onShowReport,
            ),
            const Gap(8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.grid_on_outlined, size: 14),
                    label: const Text('Excel'),
                    onPressed: onExportCsv,
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final initial = isStart ? filter.startDate : filter.endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    onFilterChanged(isStart
        ? filter.copyWith(startDate: picked)
        : filter.copyWith(endDate: picked));
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(text,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant));
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
        child: Text(label,
            style: TextStyle(color: cs.onSurface, fontSize: 12),
            textAlign: TextAlign.center),
      ),
    );
  }
}
