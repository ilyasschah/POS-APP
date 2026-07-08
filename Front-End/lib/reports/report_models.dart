class SalesByProductRow {
  final String? code;
  final String product;
  final double quantity;
  final String uom;
  final double totalBeforeTax;
  final double total;

  const SalesByProductRow({
    required this.code,
    required this.product,
    required this.quantity,
    required this.uom,
    required this.totalBeforeTax,
    required this.total,
  });

  factory SalesByProductRow.fromJson(Map<String, dynamic> j) =>
      SalesByProductRow(
        code: j['code'] as String?,
        product: j['product'] as String? ?? '',
        quantity: (j['quantity'] as num).toDouble(),
        uom: j['uom'] as String? ?? '',
        totalBeforeTax: (j['totalBeforeTax'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
      );
}

class SalesByProductGroupRow {
  final String productGroup;
  final double quantity;
  final double totalBeforeTax;
  final double total;

  const SalesByProductGroupRow({
    required this.productGroup,
    required this.quantity,
    required this.totalBeforeTax,
    required this.total,
  });

  factory SalesByProductGroupRow.fromJson(Map<String, dynamic> j) =>
      SalesByProductGroupRow(
        productGroup: j['productGroup'] as String? ?? '',
        quantity: (j['quantity'] as num).toDouble(),
        totalBeforeTax: (j['totalBeforeTax'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
      );
}

class SalesByCustomerRow {
  final String customer;
  final double totalBeforeTax;
  final double total;

  const SalesByCustomerRow({
    required this.customer,
    required this.totalBeforeTax,
    required this.total,
  });

  factory SalesByCustomerRow.fromJson(Map<String, dynamic> j) =>
      SalesByCustomerRow(
        customer: j['customer'] as String? ?? '',
        totalBeforeTax: (j['totalBeforeTax'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
      );
}

class SalesByTaxRow {
  final String taxName;
  final double totalBeforeTax;
  final double taxAmount;
  final double total;

  const SalesByTaxRow({
    required this.taxName,
    required this.totalBeforeTax,
    required this.taxAmount,
    required this.total,
  });

  factory SalesByTaxRow.fromJson(Map<String, dynamic> j) => SalesByTaxRow(
        taxName: j['taxName'] as String? ?? '',
        totalBeforeTax: (j['totalBeforeTax'] as num).toDouble(),
        taxAmount: (j['taxAmount'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
      );
}

class ReportFilter {
  final DateTime startDate;
  final DateTime endDate;
  final int? customerId;
  final int? userId;
  final int? warehouseId;
  final int? productId;
  final int? productGroupId;
  final bool includeSubgroups;

  const ReportFilter({
    required this.startDate,
    required this.endDate,
    this.customerId,
    this.userId,
    this.warehouseId,
    this.productId,
    this.productGroupId,
    this.includeSubgroups = false,
  });

  ReportFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    Object? customerId = _sentinel,
    Object? userId = _sentinel,
    Object? warehouseId = _sentinel,
    Object? productId = _sentinel,
    Object? productGroupId = _sentinel,
    bool? includeSubgroups,
  }) =>
      ReportFilter(
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        customerId: customerId == _sentinel ? this.customerId : customerId as int?,
        userId: userId == _sentinel ? this.userId : userId as int?,
        warehouseId: warehouseId == _sentinel ? this.warehouseId : warehouseId as int?,
        productId: productId == _sentinel ? this.productId : productId as int?,
        productGroupId: productGroupId == _sentinel ? this.productGroupId : productGroupId as int?,
        includeSubgroups: includeSubgroups ?? this.includeSubgroups,
      );
}

class SalesByUserRow {
  final String user;
  final double totalBeforeTax;
  final double total;

  const SalesByUserRow({
    required this.user,
    required this.totalBeforeTax,
    required this.total,
  });

  factory SalesByUserRow.fromJson(Map<String, dynamic> j) => SalesByUserRow(
        user: j['user'] as String? ?? '',
        totalBeforeTax: (j['totalBeforeTax'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
      );
}

class PaymentTypesByCustomerRow {
  final String customerName;
  final String paymentTypeName;
  final double amount;

  const PaymentTypesByCustomerRow({
    required this.customerName,
    required this.paymentTypeName,
    required this.amount,
  });

  factory PaymentTypesByCustomerRow.fromJson(Map<String, dynamic> j) =>
      PaymentTypesByCustomerRow(
        customerName: j['customerName'] as String? ?? '',
        paymentTypeName: j['paymentTypeName'] as String? ?? '',
        amount: (j['amount'] as num).toDouble(),
      );
}

class PaymentTypesByUserRow {
  final String userName;
  final String paymentTypeName;
  final double amount;

  const PaymentTypesByUserRow({
    required this.userName,
    required this.paymentTypeName,
    required this.amount,
  });

  factory PaymentTypesByUserRow.fromJson(Map<String, dynamic> j) =>
      PaymentTypesByUserRow(
        userName: j['userName'] as String? ?? '',
        paymentTypeName: j['paymentTypeName'] as String? ?? '',
        amount: (j['amount'] as num).toDouble(),
      );
}

class SalesByPaymentTypeRow {
  final DateTime date;
  final String paymentTypeName;
  final double amount;

  const SalesByPaymentTypeRow({
    required this.date,
    required this.paymentTypeName,
    required this.amount,
  });

  factory SalesByPaymentTypeRow.fromJson(Map<String, dynamic> j) =>
      SalesByPaymentTypeRow(
        date: DateTime.parse(j['date'] as String),
        paymentTypeName: j['paymentTypeName'] as String? ?? '',
        amount: (j['amount'] as num).toDouble(),
      );
}

class SalesItemListRow {
  final String documentTypeName;
  final DateTime date;
  final DateTime dateCreated;
  final String documentNumber;
  final String? refNumber;
  final String? customerCode;
  final String customerName;
  final String? orderNumber;
  final String? productCode;
  final String productName;
  final double quantity;
  final String uom;
  final double totalBeforeTax;
  final double totalTax;
  final double total;

  const SalesItemListRow({
    required this.documentTypeName,
    required this.date,
    required this.dateCreated,
    required this.documentNumber,
    required this.refNumber,
    required this.customerCode,
    required this.customerName,
    required this.orderNumber,
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.uom,
    required this.totalBeforeTax,
    required this.totalTax,
    required this.total,
  });

  factory SalesItemListRow.fromJson(Map<String, dynamic> j) => SalesItemListRow(
        documentTypeName: j['documentTypeName'] as String? ?? '',
        date: DateTime.parse(j['date'] as String),
        dateCreated: DateTime.parse(j['dateCreated'] as String),
        documentNumber: j['documentNumber'] as String? ?? '',
        refNumber: j['refNumber'] as String?,
        customerCode: j['customerCode'] as String?,
        customerName: j['customerName'] as String? ?? '',
        orderNumber: j['orderNumber'] as String?,
        productCode: j['productCode'] as String?,
        productName: j['productName'] as String? ?? '',
        quantity: (j['quantity'] as num).toDouble(),
        uom: j['uom'] as String? ?? '',
        totalBeforeTax: (j['totalBeforeTax'] as num).toDouble(),
        totalTax: (j['totalTax'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
      );
}

class RefundItemListRow {
  final String? customerCode;
  final String customerName;
  final String documentNumber;
  final String? refNumber;
  final DateTime date;
  final DateTime dateCreated;
  final String? orderNumber;
  final String? productCode;
  final String productName;
  final double quantity;
  final String uom;
  final double totalBeforeTax;
  final double totalTax;
  final double total;

  const RefundItemListRow({
    required this.customerCode,
    required this.customerName,
    required this.documentNumber,
    required this.refNumber,
    required this.date,
    required this.dateCreated,
    required this.orderNumber,
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.uom,
    required this.totalBeforeTax,
    required this.totalTax,
    required this.total,
  });

  factory RefundItemListRow.fromJson(Map<String, dynamic> j) => RefundItemListRow(
        customerCode:   j['customerCode'] as String?,
        customerName:   j['customerName'] as String? ?? '',
        documentNumber: j['documentNumber'] as String? ?? '',
        refNumber:      j['refNumber'] as String?,
        date:           DateTime.parse(j['date'] as String),
        dateCreated:    DateTime.parse(j['dateCreated'] as String),
        orderNumber:    j['orderNumber'] as String?,
        productCode:    j['productCode'] as String?,
        productName:    j['productName'] as String? ?? '',
        quantity:       (j['quantity'] as num).toDouble(),
        uom:            j['uom'] as String? ?? '',
        totalBeforeTax: (j['totalBeforeTax'] as num).toDouble(),
        totalTax:       (j['totalTax'] as num).toDouble(),
        total:          (j['total'] as num).toDouble(),
      );
}

class ProfitRow {
  final String? productCode;
  final String productName;
  final double quantity;
  final double cost;
  final double total;

  const ProfitRow({
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.cost,
    required this.total,
  });

  double get profit => total - cost;
  double get margin => total > 0 ? profit / total * 100 : 0.0;

  factory ProfitRow.fromJson(Map<String, dynamic> j) => ProfitRow(
        productCode: j['productCode'] as String?,
        productName: j['productName'] as String? ?? '',
        quantity:    (j['quantity'] as num).toDouble(),
        cost:        (j['cost'] as num).toDouble(),
        total:       (j['total'] as num).toDouble(),
      );
}

class UnpaidSalesRow {
  final String documentNumber;
  final DateTime date;
  final DateTime? dueDate;
  final String customerName;
  final double documentTotal;
  final double totalPaid;
  final double totalUnpaid;

  const UnpaidSalesRow({
    required this.documentNumber,
    required this.date,
    required this.dueDate,
    required this.customerName,
    required this.documentTotal,
    required this.totalPaid,
    required this.totalUnpaid,
  });

  factory UnpaidSalesRow.fromJson(Map<String, dynamic> j) => UnpaidSalesRow(
        documentNumber: j['documentNumber'] as String? ?? '',
        date:           DateTime.parse(j['date'] as String),
        dueDate:        j['dueDate'] != null ? DateTime.parse(j['dueDate'] as String) : null,
        customerName:   j['customerName'] as String? ?? '',
        documentTotal:  (j['documentTotal'] as num).toDouble(),
        totalPaid:      (j['totalPaid'] as num).toDouble(),
        totalUnpaid:    (j['totalUnpaid'] as num).toDouble(),
      );
}

class HourlySalesByGroupRow {
  final String productGroup;
  final int hour;
  final double total;

  const HourlySalesByGroupRow({
    required this.productGroup,
    required this.hour,
    required this.total,
  });

  factory HourlySalesByGroupRow.fromJson(Map<String, dynamic> j) =>
      HourlySalesByGroupRow(
        productGroup: j['productGroup'] as String? ?? '',
        hour:         j['hour'] as int,
        total:        (j['total'] as num).toDouble(),
      );
}

class SalesByTableRow {
  final String orderNumber;
  final int numberOfSales;
  final double total;

  const SalesByTableRow({
    required this.orderNumber,
    required this.numberOfSales,
    required this.total,
  });

  factory SalesByTableRow.fromJson(Map<String, dynamic> j) => SalesByTableRow(
        orderNumber:   j['orderNumber'] as String? ?? '',
        numberOfSales: j['numberOfSales'] as int,
        total:         (j['total'] as num).toDouble(),
      );
}

class HourlySalesRow {
  final int hour;
  final double totalSales;
  final int salesCount;

  const HourlySalesRow({
    required this.hour,
    required this.totalSales,
    required this.salesCount,
  });

  factory HourlySalesRow.fromJson(Map<String, dynamic> j) => HourlySalesRow(
        hour:       j['hour'] as int,
        totalSales: (j['totalSales'] as num).toDouble(),
        salesCount: j['salesCount'] as int,
      );
}

class DailySalesRow {
  final DateTime date;
  final double total;

  const DailySalesRow({required this.date, required this.total});

  factory DailySalesRow.fromJson(Map<String, dynamic> j) => DailySalesRow(
        date:  DateTime.parse(j['date'] as String),
        total: (j['total'] as num).toDouble(),
      );
}

class InvoiceListRow {
  final DateTime date;
  final String documentNumber;
  final String customerName;
  final String paymentMethodName;
  final double total;

  const InvoiceListRow({
    required this.date,
    required this.documentNumber,
    required this.customerName,
    required this.paymentMethodName,
    required this.total,
  });

  factory InvoiceListRow.fromJson(Map<String, dynamic> j) => InvoiceListRow(
        date:              DateTime.parse(j['date'] as String),
        documentNumber:    j['documentNumber'] as String? ?? '',
        customerName:      j['customerName'] as String? ?? '',
        paymentMethodName: j['paymentMethodName'] as String? ?? '',
        total:             (j['total'] as num).toDouble(),
      );
}

class StartingCashRow {
  final int id;
  final int companyId;
  final int userId;
  final String? userName;
  final double amount;
  final String? description;
  final int startingCashType;
  final int? zReportNumber;
  final DateTime dateCreated;

  const StartingCashRow({
    required this.id,
    required this.companyId,
    required this.userId,
    this.userName,
    required this.amount,
    this.description,
    required this.startingCashType,
    this.zReportNumber,
    required this.dateCreated,
  });

  bool get isCashOut => startingCashType == 1;
  double get signedAmount => isCashOut ? -amount : amount;

  factory StartingCashRow.fromJson(Map<String, dynamic> j) => StartingCashRow(
        id:               j['id'] as int,
        companyId:        j['companyId'] as int? ?? 0,
        userId:           j['userId'] as int,
        userName:         j['userName'] as String?,
        amount:           (j['amount'] as num).toDouble(),
        description:      j['description'] as String?,
        startingCashType: j['startingCashType'] as int? ?? 0,
        zReportNumber:    j['zReportNumber'] as int?,
        dateCreated:      DateTime.parse(j['dateCreated'] as String),
      );
}

class VoidedItemRow {
  final int id;
  final String orderNumber;
  final String? voidedByName;
  final String productName;
  final double quantity;
  final double price;
  final double discount;
  final int discountType;
  final bool isConfirmed;
  final String? reason;
  final DateTime dateCreated;
  final DateTime dateVoided;
  final double total;

  const VoidedItemRow({
    required this.id,
    required this.orderNumber,
    this.voidedByName,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.discount,
    required this.discountType,
    required this.isConfirmed,
    this.reason,
    required this.dateCreated,
    required this.dateVoided,
    required this.total,
  });

  String get discountDisplay => discountType == 1
      ? discount.toStringAsFixed(2)
      : '${discount.toStringAsFixed(0)}%';

  factory VoidedItemRow.fromJson(Map<String, dynamic> j) => VoidedItemRow(
        id:           j['id'] as int,
        orderNumber:  j['orderNumber'] as String? ?? '',
        voidedByName: j['voidedByName'] as String?,
        productName:  j['productName'] as String? ?? '',
        quantity:     (j['quantity'] as num).toDouble(),
        price:        (j['price'] as num).toDouble(),
        discount:     (j['discount'] as num?)?.toDouble() ?? 0.0,
        discountType: j['discountType'] as int? ?? 0,
        isConfirmed:  j['isConfirmed'] as bool? ?? false,
        reason:       j['reason'] as String?,
        dateCreated:  DateTime.parse(j['dateCreated'] as String),
        dateVoided:   DateTime.parse(j['dateVoided'] as String),
        total:        (j['total'] as num).toDouble(),
      );
}

class StockMovementRow {
  final String? productCode;
  final String productName;
  final double numSales;

  const StockMovementRow({
    this.productCode,
    required this.productName,
    required this.numSales,
  });

  factory StockMovementRow.fromJson(Map<String, dynamic> j) => StockMovementRow(
        productCode: j['productCode'] as String?,
        productName: j['productName'] as String? ?? '',
        numSales:    (j['numSales'] as num).toDouble(),
      );
}

class ItemsDiscountsRow {
  final String? productCode;
  final String productName;
  final double totalDiscount;

  const ItemsDiscountsRow({
    this.productCode,
    required this.productName,
    required this.totalDiscount,
  });

  factory ItemsDiscountsRow.fromJson(Map<String, dynamic> j) => ItemsDiscountsRow(
        productCode:   j['productCode'] as String?,
        productName:   j['productName'] as String? ?? '',
        totalDiscount: (j['totalDiscount'] as num).toDouble(),
      );
}

/// One row of the local "Discounts by source" report — the total currency
/// deducted by a single discount source over the filter period. Built offline
/// from the normalized discount_lines, not the server.
class DiscountBySourceRow {
  final String source; // DiscountSource.*
  final String label;
  final double amount;
  const DiscountBySourceRow({
    required this.source,
    required this.label,
    required this.amount,
  });
}

class DiscountsGrantedRow {
  final String customerName;
  final String documentNumber;
  final DateTime date;
  final String userName;
  final double totalBeforeDiscount;
  final double totalAfterDiscount;
  final double discountGranted;

  const DiscountsGrantedRow({
    required this.customerName,
    required this.documentNumber,
    required this.date,
    required this.userName,
    required this.totalBeforeDiscount,
    required this.totalAfterDiscount,
    required this.discountGranted,
  });

  factory DiscountsGrantedRow.fromJson(Map<String, dynamic> j) => DiscountsGrantedRow(
        customerName:        j['customerName'] as String? ?? 'Unknown',
        documentNumber:      j['documentNumber'] as String? ?? '',
        date:                DateTime.parse(j['date'] as String),
        userName:            j['userName'] as String? ?? '',
        totalBeforeDiscount: (j['totalBeforeDiscount'] as num).toDouble(),
        totalAfterDiscount:  (j['totalAfterDiscount'] as num).toDouble(),
        discountGranted:     (j['discountGranted'] as num).toDouble(),
      );
}

class PurchaseByProductRow {
  final String? code;
  final String product;
  final double quantity;
  final String uom;
  final double totalBeforeTax;
  final double total;

  const PurchaseByProductRow({
    required this.code,
    required this.product,
    required this.quantity,
    required this.uom,
    required this.totalBeforeTax,
    required this.total,
  });

  factory PurchaseByProductRow.fromJson(Map<String, dynamic> j) =>
      PurchaseByProductRow(
        code:           j['code'] as String?,
        product:        j['product'] as String? ?? '',
        quantity:       (j['quantity'] as num).toDouble(),
        uom:            j['uom'] as String? ?? '',
        totalBeforeTax: (j['totalBeforeTax'] as num).toDouble(),
        total:          (j['total'] as num).toDouble(),
      );
}

class UnpaidPurchaseRow {
  final String documentNumber;
  final DateTime date;
  final DateTime? dueDate;
  final String supplierName;
  final double documentTotal;
  final double totalPaid;
  final double totalUnpaid;

  const UnpaidPurchaseRow({
    required this.documentNumber,
    required this.date,
    required this.dueDate,
    required this.supplierName,
    required this.documentTotal,
    required this.totalPaid,
    required this.totalUnpaid,
  });

  factory UnpaidPurchaseRow.fromJson(Map<String, dynamic> j) => UnpaidPurchaseRow(
        documentNumber: j['documentNumber'] as String? ?? '',
        date:           DateTime.parse(j['date'] as String),
        dueDate:        j['dueDate'] != null ? DateTime.parse(j['dueDate'] as String) : null,
        supplierName:   j['supplierName'] as String? ?? '',
        documentTotal:  (j['documentTotal'] as num).toDouble(),
        totalPaid:      (j['totalPaid'] as num).toDouble(),
        totalUnpaid:    (j['totalUnpaid'] as num).toDouble(),
      );
}

class PurchaseByTaxRow {
  final String taxName;
  final double totalBeforeTax;
  final double taxAmount;
  final double total;

  const PurchaseByTaxRow({
    required this.taxName,
    required this.totalBeforeTax,
    required this.taxAmount,
    required this.total,
  });

  factory PurchaseByTaxRow.fromJson(Map<String, dynamic> j) => PurchaseByTaxRow(
        taxName:        j['taxName'] as String? ?? '',
        totalBeforeTax: (j['totalBeforeTax'] as num).toDouble(),
        taxAmount:      (j['taxAmount'] as num).toDouble(),
        total:          (j['total'] as num).toDouble(),
      );
}

class PurchaseInvoiceListRow {
  final DateTime date;
  final String documentNumber;
  final String? externalDocument;
  final String supplierName;
  final double total;

  const PurchaseInvoiceListRow({
    required this.date,
    required this.documentNumber,
    required this.externalDocument,
    required this.supplierName,
    required this.total,
  });

  factory PurchaseInvoiceListRow.fromJson(Map<String, dynamic> j) =>
      PurchaseInvoiceListRow(
        date:             DateTime.parse(j['date'] as String),
        documentNumber:   j['documentNumber'] as String? ?? '',
        externalDocument: j['externalDocument'] as String?,
        supplierName:     j['supplierName'] as String? ?? 'Unknown',
        total:            (j['total'] as num).toDouble(),
      );
}

class PurchaseItemsDiscountsRow {
  final String supplierName;
  final String documentNumber;
  final DateTime date;
  final String userName;
  final String? productCode;
  final String productName;
  final double quantity;
  final double cost;
  final double totalBeforeDiscount;
  final double totalAfterDiscount;
  final double discountValue;
  final int discountType;
  final double totalDiscount;

  const PurchaseItemsDiscountsRow({
    required this.supplierName,
    required this.documentNumber,
    required this.date,
    required this.userName,
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.cost,
    required this.totalBeforeDiscount,
    required this.totalAfterDiscount,
    required this.discountValue,
    required this.discountType,
    required this.totalDiscount,
  });

  String get discountDisplay => discountType == 1
      ? '${discountValue.toStringAsFixed(2)} (fixed)'
      : '${discountValue.toStringAsFixed(0)}%';

  factory PurchaseItemsDiscountsRow.fromJson(Map<String, dynamic> j) =>
      PurchaseItemsDiscountsRow(
        supplierName:        j['supplierName'] as String? ?? 'Unknown',
        documentNumber:      j['documentNumber'] as String? ?? '',
        date:                DateTime.parse(j['date'] as String),
        userName:            j['userName'] as String? ?? '',
        productCode:         j['productCode'] as String?,
        productName:         j['productName'] as String? ?? '',
        quantity:            (j['quantity'] as num).toDouble(),
        cost:                (j['cost'] as num).toDouble(),
        totalBeforeDiscount: (j['totalBeforeDiscount'] as num).toDouble(),
        totalAfterDiscount:  (j['totalAfterDiscount'] as num).toDouble(),
        discountValue:       (j['discountValue'] as num).toDouble(),
        discountType:        j['discountType'] as int? ?? 0,
        totalDiscount:       (j['totalDiscount'] as num).toDouble(),
      );
}

class PurchaseDiscountsRow {
  final String supplierName;
  final String documentNumber;
  final DateTime date;
  final String userName;
  final double totalBeforeDiscount;
  final double totalAfterDiscount;
  final double discountGranted;

  const PurchaseDiscountsRow({
    required this.supplierName,
    required this.documentNumber,
    required this.date,
    required this.userName,
    required this.totalBeforeDiscount,
    required this.totalAfterDiscount,
    required this.discountGranted,
  });

  factory PurchaseDiscountsRow.fromJson(Map<String, dynamic> j) => PurchaseDiscountsRow(
        supplierName:        j['supplierName'] as String? ?? 'Unknown',
        documentNumber:      j['documentNumber'] as String? ?? '',
        date:                DateTime.parse(j['date'] as String),
        userName:            j['userName'] as String? ?? '',
        totalBeforeDiscount: (j['totalBeforeDiscount'] as num).toDouble(),
        totalAfterDiscount:  (j['totalAfterDiscount'] as num).toDouble(),
        discountGranted:     (j['discountGranted'] as num).toDouble(),
      );
}

class PurchaseBySupplierRow {
  final String supplier;
  final double totalBeforeTax;
  final double total;

  const PurchaseBySupplierRow({
    required this.supplier,
    required this.totalBeforeTax,
    required this.total,
  });

  factory PurchaseBySupplierRow.fromJson(Map<String, dynamic> j) =>
      PurchaseBySupplierRow(
        supplier:       j['supplier'] as String? ?? 'Unknown',
        totalBeforeTax: (j['totalBeforeTax'] as num).toDouble(),
        total:          (j['total'] as num).toDouble(),
      );
}

class PurchaseExpirationDateRow {
  final String? productCode;
  final String productName;
  final double quantity;
  final String uom;
  final DateTime expirationDate;

  const PurchaseExpirationDateRow({
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.uom,
    required this.expirationDate,
  });

  factory PurchaseExpirationDateRow.fromJson(Map<String, dynamic> j) =>
      PurchaseExpirationDateRow(
        productCode:    j['productCode'] as String?,
        productName:    j['productName'] as String? ?? '',
        quantity:       (j['quantity'] as num).toDouble(),
        uom:            j['uom'] as String? ?? '',
        expirationDate: DateTime.parse(j['expirationDate'] as String),
      );
}

class StockReturnByProductRow {
  final DateTime date;
  final String? code;
  final String product;
  final double quantity;
  final String uom;
  final double totalBeforeTax;
  final double total;

  const StockReturnByProductRow({
    required this.date,
    required this.code,
    required this.product,
    required this.quantity,
    required this.uom,
    required this.totalBeforeTax,
    required this.total,
  });

  factory StockReturnByProductRow.fromJson(Map<String, dynamic> j) =>
      StockReturnByProductRow(
        date:           DateTime.parse(j['date'] as String),
        code:           j['code'] as String?,
        product:        j['product'] as String? ?? '',
        quantity:       (j['quantity'] as num).toDouble(),
        uom:            j['uom'] as String? ?? '',
        totalBeforeTax: (j['totalBeforeTax'] as num).toDouble(),
        total:          (j['total'] as num).toDouble(),
      );
}

class LossAndDamageByProductRow {
  final DateTime date;
  final String? code;
  final String product;
  final double quantity;
  final String uom;
  final double totalBeforeTax;
  final double total;

  const LossAndDamageByProductRow({
    required this.date,
    required this.code,
    required this.product,
    required this.quantity,
    required this.uom,
    required this.totalBeforeTax,
    required this.total,
  });

  factory LossAndDamageByProductRow.fromJson(Map<String, dynamic> j) =>
      LossAndDamageByProductRow(
        date:           DateTime.parse(j['date'] as String),
        code:           j['code'] as String?,
        product:        j['product'] as String? ?? '',
        quantity:       (j['quantity'] as num).toDouble(),
        uom:            j['uom'] as String? ?? '',
        totalBeforeTax: (j['totalBeforeTax'] as num).toDouble(),
        total:          (j['total'] as num).toDouble(),
      );
}

class ReorderProductListRow {
  final String supplierName;
  final String productName;
  final double orderQuantity;
  final String uom;

  const ReorderProductListRow({
    required this.supplierName,
    required this.productName,
    required this.orderQuantity,
    required this.uom,
  });

  factory ReorderProductListRow.fromJson(Map<String, dynamic> j) =>
      ReorderProductListRow(
        supplierName:  j['supplierName']  as String? ?? 'N/A',
        productName:   j['productName']   as String? ?? '',
        orderQuantity: (j['orderQuantity'] as num).toDouble(),
        uom:           j['uom']           as String? ?? '',
      );
}

class LowStockWarningRow {
  final String supplierName;
  final String productName;
  final double currentStock;
  final double lowStockWarningQuantity;
  final double orderQuantity;
  final String uom;

  const LowStockWarningRow({
    required this.supplierName,
    required this.productName,
    required this.currentStock,
    required this.lowStockWarningQuantity,
    required this.orderQuantity,
    required this.uom,
  });

  factory LowStockWarningRow.fromJson(Map<String, dynamic> j) =>
      LowStockWarningRow(
        supplierName:           j['supplierName']           as String? ?? 'N/A',
        productName:            j['productName']            as String? ?? '',
        currentStock:           (j['currentStock']          as num).toDouble(),
        lowStockWarningQuantity:(j['lowStockWarningQuantity'] as num).toDouble(),
        orderQuantity:          (j['orderQuantity']         as num).toDouble(),
        uom:                    j['uom']                    as String? ?? '',
      );
}

class TransactionHistoryRow {
  final DateTime? date;
  final String transactionType;
  final String? refNumber;
  final double credit;
  final double debit;
  final double balance;
  final bool isPreviousBalance;
  final String partnerName;

  const TransactionHistoryRow({
    this.date,
    required this.transactionType,
    this.refNumber,
    required this.credit,
    required this.debit,
    required this.balance,
    required this.isPreviousBalance,
    required this.partnerName,
  });

  factory TransactionHistoryRow.fromJson(Map<String, dynamic> j) =>
      TransactionHistoryRow(
        date:             j['date'] != null ? DateTime.parse(j['date'] as String) : null,
        transactionType:  j['transactionType'] as String? ?? '',
        refNumber:        j['refNumber'] as String?,
        credit:           (j['credit'] as num).toDouble(),
        debit:            (j['debit'] as num).toDouble(),
        balance:          (j['balance'] as num).toDouble(),
        isPreviousBalance: j['isPreviousBalance'] as bool? ?? false,
        partnerName:      j['partnerName'] as String? ?? '',
      );
}

const Object _sentinel = Object();
