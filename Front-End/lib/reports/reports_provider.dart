import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/reports/report_models.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/cart/discount_display.dart';

final salesByProductProvider = FutureProvider.autoDispose
    .family<List<SalesByProductRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetSalesByProduct',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null) 'userId': filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
      if (filter.productId != null) 'productId': filter.productId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
    },
  );

  return (response.data as List)
      .map((j) => SalesByProductRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final salesByTaxProvider = FutureProvider.autoDispose
    .family<List<SalesByTaxRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetSalesByTax',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null) 'userId': filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
      if (filter.productId != null) 'productId': filter.productId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
    },
  );

  return (response.data as List)
      .map((j) => SalesByTaxRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final salesByCustomerProvider = FutureProvider.autoDispose
    .family<List<SalesByCustomerRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetSalesByCustomer',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null) 'userId': filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
      if (filter.productId != null) 'productId': filter.productId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
    },
  );

  return (response.data as List)
      .map((j) => SalesByCustomerRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final paymentTypesByCustomerProvider = FutureProvider.autoDispose
    .family<List<PaymentTypesByCustomerRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetPaymentTypesByCustomer',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null) 'userId': filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
    },
  );

  return (response.data as List)
      .map((j) => PaymentTypesByCustomerRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final paymentTypesByUserProvider = FutureProvider.autoDispose
    .family<List<PaymentTypesByUserRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetPaymentTypesByUser',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null) 'userId': filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
    },
  );

  return (response.data as List)
      .map((j) => PaymentTypesByUserRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final salesByPaymentTypeProvider = FutureProvider.autoDispose
    .family<List<SalesByPaymentTypeRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetSalesByPaymentType',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null) 'userId': filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
    },
  );

  return (response.data as List)
      .map((j) => SalesByPaymentTypeRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final salesItemListProvider = FutureProvider.autoDispose
    .family<List<SalesItemListRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetSalesItemList',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null) 'userId': filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
      if (filter.productId != null) 'productId': filter.productId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
    },
  );

  return (response.data as List)
      .map((j) => SalesItemListRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final salesByUserProvider = FutureProvider.autoDispose
    .family<List<SalesByUserRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetSalesByUser',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null) 'userId': filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
      if (filter.productId != null) 'productId': filter.productId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
    },
  );

  return (response.data as List)
      .map((j) => SalesByUserRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final refundItemListProvider = FutureProvider.autoDispose
    .family<List<RefundItemListRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetRefundItemList',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.customerId    != null) 'customerId':    filter.customerId,
      if (filter.userId        != null) 'userId':        filter.userId,
      if (filter.warehouseId   != null) 'warehouseId':   filter.warehouseId,
      if (filter.productId     != null) 'productId':     filter.productId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
    },
  );

  return (response.data as List)
      .map((j) => RefundItemListRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final profitProvider = FutureProvider.autoDispose
    .family<List<ProfitRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetProfit',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null) 'userId': filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
      if (filter.productId != null) 'productId': filter.productId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
    },
  );

  return (response.data as List)
      .map((j) => ProfitRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final unpaidSalesProvider = FutureProvider.autoDispose
    .family<List<UnpaidSalesRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetUnpaidSales',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null) 'userId': filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
    },
  );

  return (response.data as List)
      .map((j) => UnpaidSalesRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final hourlySalesByGroupProvider = FutureProvider.autoDispose
    .family<List<HourlySalesByGroupRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetHourlySalesByGroup',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
    },
  );

  return (response.data as List)
      .map((j) => HourlySalesByGroupRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final salesByTableProvider = FutureProvider.autoDispose
    .family<List<SalesByTableRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetSalesByTable',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null) 'userId': filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
    },
  );

  return (response.data as List)
      .map((j) => SalesByTableRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final hourlySalesProvider = FutureProvider.autoDispose
    .family<List<HourlySalesRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetHourlySales',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
    },
  );

  return (response.data as List)
      .map((j) => HourlySalesRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final dailySalesProvider = FutureProvider.autoDispose
    .family<List<DailySalesRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetDailySales',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null) 'userId': filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
    },
  );

  return (response.data as List)
      .map((j) => DailySalesRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final invoiceListProvider = FutureProvider.autoDispose
    .family<List<InvoiceListRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetInvoiceList',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null) 'userId': filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
    },
  );

  return (response.data as List)
      .map((j) => InvoiceListRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final salesByProductGroupProvider = FutureProvider.autoDispose
    .family<List<SalesByProductGroupRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetSalesByProductGroup',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      'includeSubgroups': filter.includeSubgroups,
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null) 'userId': filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
      if (filter.productId != null) 'productId': filter.productId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
    },
  );

  return (response.data as List)
      .map((j) => SalesByProductGroupRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final startingCashReportProvider = FutureProvider.autoDispose
    .family<List<StartingCashRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/StartingCash/GetByDateRange',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      if (filter.userId != null) 'userId': filter.userId,
    },
  );

  return (response.data as List)
      .map((j) => StartingCashRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final stockMovementReportProvider = FutureProvider.autoDispose
    .family<List<StockMovementRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetStockMovement',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.userId != null)    'userId':    filter.userId,
      if (filter.productId != null) 'productId': filter.productId,
    },
  );

  return (response.data as List)
      .map((j) => StockMovementRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final itemsDiscountsReportProvider = FutureProvider.autoDispose
    .family<List<ItemsDiscountsRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetItemsDiscounts',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null)     'userId':     filter.userId,
      if (filter.productId != null)  'productId':  filter.productId,
    },
  );

  return (response.data as List)
      .map((j) => ItemsDiscountsRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final discountsGrantedReportProvider = FutureProvider.autoDispose
    .family<List<DiscountsGrantedRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetDiscountsGranted',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.userId != null)     'userId':     filter.userId,
    },
  );

  return (response.data as List)
      .map((j) => DiscountsGrantedRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

/// Local, offline-first "Discounts by source" report: aggregates the normalized
/// discount_lines by source over the filter period. Rows come back in a stable
/// canonical order, with zero-total sources omitted.
final discountsBySourceReportProvider = FutureProvider.autoDispose
    .family<List<DiscountBySourceRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const [];

  final db = ref.watch(appDatabaseProvider);
  final totals = await db.discountTotalsBySource(
    companyId,
    filter.startDate,
    filter.endDate,
  );

  return [
    for (final source in DiscountSource.all)
      if ((totals[source] ?? 0) != 0)
        DiscountBySourceRow(
          source: source,
          label: discountSourceLabelFor(source),
          amount: totals[source]!,
        ),
  ];
});

final voidedItemsReportProvider = FutureProvider.autoDispose
    .family<List<VoidedItemRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/PosVoids/GetByDateRange',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.userId != null)    'userId':    filter.userId,
      if (filter.productId != null) 'productId': filter.productId,
    },
  );

  return (response.data as List)
      .map((j) => VoidedItemRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final purchaseByProductProvider = FutureProvider.autoDispose
    .family<List<PurchaseByProductRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetPurchaseByProduct',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.customerId != null)     'supplierId':     filter.customerId,
      if (filter.userId != null)         'userId':         filter.userId,
      if (filter.warehouseId != null)    'warehouseId':    filter.warehouseId,
      if (filter.productId != null)      'productId':      filter.productId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
    },
  );

  return (response.data as List)
      .map((j) => PurchaseByProductRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final purchaseBySupplierProvider = FutureProvider.autoDispose
    .family<List<PurchaseBySupplierRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetPurchaseBySupplier',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.customerId != null)     'supplierId':     filter.customerId,
      if (filter.userId != null)         'userId':         filter.userId,
      if (filter.warehouseId != null)    'warehouseId':    filter.warehouseId,
      if (filter.productId != null)      'productId':      filter.productId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
    },
  );

  return (response.data as List)
      .map((j) => PurchaseBySupplierRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final purchaseByTaxProvider = FutureProvider.autoDispose
    .family<List<PurchaseByTaxRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetPurchaseByTax',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.customerId     != null) 'supplierId':     filter.customerId,
      if (filter.userId         != null) 'userId':         filter.userId,
      if (filter.warehouseId    != null) 'warehouseId':    filter.warehouseId,
      if (filter.productId      != null) 'productId':      filter.productId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
    },
  );

  return (response.data as List)
      .map((j) => PurchaseByTaxRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final purchaseInvoiceListProvider = FutureProvider.autoDispose
    .family<List<PurchaseInvoiceListRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetPurchaseInvoiceList',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.customerId  != null) 'supplierId':  filter.customerId,
      if (filter.userId      != null) 'userId':      filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
    },
  );

  return (response.data as List)
      .map((j) => PurchaseInvoiceListRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final purchaseItemsDiscountsProvider = FutureProvider.autoDispose
    .family<List<PurchaseItemsDiscountsRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetPurchaseItemsDiscounts',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'supplierId': filter.customerId,
      if (filter.userId != null)     'userId':     filter.userId,
      if (filter.productId != null)  'productId':  filter.productId,
    },
  );

  return (response.data as List)
      .map((j) => PurchaseItemsDiscountsRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final purchaseDiscountsProvider = FutureProvider.autoDispose
    .family<List<PurchaseDiscountsRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetPurchaseDiscounts',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.customerId != null) 'supplierId': filter.customerId,
      if (filter.userId != null)     'userId':     filter.userId,
    },
  );

  return (response.data as List)
      .map((j) => PurchaseDiscountsRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final purchaseExpirationDateProvider = FutureProvider.autoDispose
    .family<List<PurchaseExpirationDateRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetPurchaseExpirationDate',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.customerId  != null) 'supplierId':    filter.customerId,
      if (filter.userId      != null) 'userId':        filter.userId,
      if (filter.warehouseId != null) 'warehouseId':   filter.warehouseId,
      if (filter.productId   != null) 'productId':     filter.productId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
    },
  );

  return (response.data as List)
      .map((j) => PurchaseExpirationDateRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final stockReturnByProductProvider = FutureProvider.autoDispose
    .family<List<StockReturnByProductRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetStockReturnByProduct',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.userId      != null) 'userId':        filter.userId,
      if (filter.warehouseId != null) 'warehouseId':   filter.warehouseId,
      if (filter.productId   != null) 'productId':     filter.productId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
    },
  );

  return (response.data as List)
      .map((j) => StockReturnByProductRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final lossAndDamageByProductProvider = FutureProvider.autoDispose
    .family<List<LossAndDamageByProductRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetLossAndDamageByProduct',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.userId         != null) 'userId':         filter.userId,
      if (filter.warehouseId    != null) 'warehouseId':    filter.warehouseId,
      if (filter.productId      != null) 'productId':      filter.productId,
      if (filter.productGroupId != null) 'productGroupId': filter.productGroupId,
    },
  );

  return (response.data as List)
      .map((j) => LossAndDamageByProductRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final reorderProductListProvider = FutureProvider.autoDispose
    .family<List<ReorderProductListRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetReorderProductList',
    queryParameters: {
      'companyId': companyId,
      if (filter.customerId != null) 'supplierId': filter.customerId,
      if (filter.productId  != null) 'productId':  filter.productId,
    },
  );

  return (response.data as List)
      .map((j) => ReorderProductListRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final lowStockWarningProvider = FutureProvider.autoDispose
    .family<List<LowStockWarningRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetLowStockWarning',
    queryParameters: {
      'companyId': companyId,
      if (filter.customerId != null) 'supplierId': filter.customerId,
      if (filter.productId  != null) 'productId':  filter.productId,
    },
  );

  return (response.data as List)
      .map((j) => LowStockWarningRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final transactionHistoryProvider = FutureProvider.autoDispose
    .family<List<TransactionHistoryRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null || filter.customerId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetTransactionHistory',
    queryParameters: {
      'companyId': companyId,
      'partnerId': filter.customerId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
    },
  );

  return (response.data as List)
      .map((j) => TransactionHistoryRow.fromJson(j as Map<String, dynamic>))
      .toList();
});

final unpaidPurchaseProvider = FutureProvider.autoDispose
    .family<List<UnpaidPurchaseRow>, ReportFilter>((ref, filter) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return [];

  final dio = createDio();
  final response = await dio.get(
    '/Reports/GetUnpaidPurchase',
    queryParameters: {
      'companyId': companyId,
      'startDate': filter.startDate.toIso8601String(),
      'endDate':   filter.endDate.toIso8601String(),
      if (filter.customerId != null)  'supplierId':  filter.customerId,
      if (filter.userId != null)      'userId':      filter.userId,
      if (filter.warehouseId != null) 'warehouseId': filter.warehouseId,
    },
  );

  return (response.data as List)
      .map((j) => UnpaidPurchaseRow.fromJson(j as Map<String, dynamic>))
      .toList();
});
