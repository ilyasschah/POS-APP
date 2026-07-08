class Document {
  final int id;
  /// Drift local UUID PK — set when the document came from the offline-first
  /// list so the editor can write paid-status / payments through to local SQLite.
  /// Null for documents built straight from an API payload (e.g. bookings).
  final String? localId;
  final String number;
  final int userId;
  final String? userName;
  final int customerId;
  final String? customerName;
  final int companyId;
  final String? companyName;
  final int documentTypeId;
  final String? documentTypeName;
  final int warehouseId;
  final String? warehouseName;
  final String? orderNumber;
  final String date;
  final String? stockDate;
  final double total;
  final String? referenceDocumentNumber;
  final String? dateCreated;
  final String? dateUpdated;
  final String? internalNote;
  final String? note;
  final String? dueDate;
  final double discount;
  final int discountType;
  final int paidStatus;
  final bool discountApplyRule;
  final int serviceType;

  Document({
    required this.id,
    this.localId,
    required this.number,
    required this.userId,
    this.userName,
    required this.customerId,
    this.customerName,
    required this.companyId,
    this.companyName,
    required this.documentTypeId,
    this.documentTypeName,
    required this.warehouseId,
    this.warehouseName,
    this.orderNumber,
    required this.date,
    this.stockDate,
    required this.total,
    this.referenceDocumentNumber,
    this.dateCreated,
    this.dateUpdated,
    this.internalNote,
    this.note,
    this.dueDate,
    this.discount = 0,
    this.discountType = 0,
    this.paidStatus = 0,
    this.discountApplyRule = true,
    this.serviceType = 0,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] ?? 0,
      number: json['number'] ?? '',
      userId: json['userId'] ?? 0,
      userName: json['userName'],
      customerId: json['customerId'] ?? 0,
      customerName: json['customerName'],
      companyId: json['companyId'] ?? 0,
      companyName: json['companyName'],
      documentTypeId: json['documentTypeId'] ?? 0,
      documentTypeName: json['documentTypeName'],
      warehouseId: json['warehouseId'] ?? 0,
      warehouseName: json['warehouseName'],
      orderNumber: json['orderNumber'],
      date: json['date'] ?? '',
      stockDate: json['stockDate'],
      total: (json['total'] as num?)?.toDouble() ?? 0,
      referenceDocumentNumber: json['referenceDocumentNumber'],
      dateCreated: json['dateCreated'],
      dateUpdated: json['dateUpdated'],
      internalNote: json['internalNote'],
      note: json['note'],
      dueDate: json['dueDate'],
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      discountType: json['discountType'] ?? 0,
      paidStatus: json['paidStatus'] ?? 0,
      discountApplyRule: json['discountApplyRule'] ?? true,
      serviceType: json['serviceType'] ?? 0,
    );
  }
}

class DocumentType {
  final int id;
  final String name;
  final String? code;
  final int? documentCategoryId;
  final String? documentCategoryName;
  // Server inventory direction (0 = none, 1 = add, 2 = deduct).
  final int stockDirection;

  DocumentType({
    required this.id,
    required this.name,
    this.code,
    this.documentCategoryId,
    this.documentCategoryName,
    this.stockDirection = 0,
  });

  factory DocumentType.fromJson(Map<String, dynamic> json) {
    return DocumentType(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'],
      documentCategoryId: json['documentCategoryId'],
      documentCategoryName: json['documentCategoryName'],
      stockDirection: json['stockDirection'] ?? 0,
    );
  }
}

class DocumentCategory {
  final int id;
  final String name;

  DocumentCategory({required this.id, required this.name});

  factory DocumentCategory.fromJson(Map<String, dynamic> json) {
    return DocumentCategory(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

class DocumentItem {
  final int id;
  /// Drift local UUID + sync state — present only for items read from the
  /// offline-first local store. Null/'synced' for API-sourced items.
  final String? localId;
  final String syncStatus;
  final int companyId;
  final int documentId;
  final String? documentNumber;
  final int productId;
  final String? productCode;
  final String? productName;
  final String? measurementUnit;
  final double quantity;
  final double expectedQuantity;
  final double priceBeforeTax;
  final double price;
  final double discount;
  final int discountType;
  final double productCost;
  final double priceBeforeTaxAfterDiscount;
  final double priceAfterDiscount;
  final double total;
  final double totalAfterDocumentDiscount;
  final bool discountApplyRule;
  final int? taxId;
  final double taxRate;
  final DateTime? expirationDate;

  DocumentItem({
    required this.id,
    this.localId,
    this.syncStatus = 'synced',
    this.taxId,
    this.taxRate = 0,
    this.expirationDate,
    required this.companyId,
    required this.documentId,
    this.documentNumber,
    required this.productId,
    this.productCode,
    this.productName,
    this.measurementUnit,
    required this.quantity,
    required this.expectedQuantity,
    required this.priceBeforeTax,
    required this.price,
    required this.discount,
    required this.discountType,
    required this.productCost,
    required this.priceBeforeTaxAfterDiscount,
    required this.priceAfterDiscount,
    required this.total,
    required this.totalAfterDocumentDiscount,
    required this.discountApplyRule,
  });

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    return DocumentItem(
      id: json['id'] ?? 0,
      companyId: json['companyId'] ?? 0,
      documentId: json['documentId'] ?? 0,
      documentNumber: json['documentNumber'],
      productId: json['productId'] ?? 0,
      productCode: json['productCode'],
      productName: json['productName'],
      measurementUnit: json['measurementUnit'],
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      expectedQuantity: (json['expectedQuantity'] as num?)?.toDouble() ?? 0,
      priceBeforeTax: (json['priceBeforeTax'] as num?)?.toDouble() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      discountType: json['discountType'] ?? 0,
      productCost: (json['productCost'] as num?)?.toDouble() ?? 0,
      priceBeforeTaxAfterDiscount:
          (json['priceBeforeTaxAfterDiscount'] as num?)?.toDouble() ?? 0,
      priceAfterDiscount: (json['priceAfterDiscount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      totalAfterDocumentDiscount:
          (json['totalAfterDocumentDiscount'] as num?)?.toDouble() ?? 0,
      discountApplyRule: json['discountApplyRule'] ?? true,
    );
  }
}

// Keep existing DocumentItemDto for menu_screen checkout compatibility
class DocumentItemDto {
  final int documentId;
  final int productId;
  final double quantity;
  final double price;
  final double total;

  DocumentItemDto({
    required this.documentId,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.total,
  });

  Map<String, dynamic> toJson() {
    return {
      "DocumentId": documentId,
      "ProductId": productId,
      "Quantity": quantity,
      "Price": price,
      "Total": total,
      "Discount": 0,
      "DiscountType": 0,
      "ProductCost": 0,
      "TaxRate": 0,
      "PriceBeforeTaxAfterDiscount": price,
      "PriceAfterDiscount": price,
      "TotalAfterDocumentDiscount": total,
    };
  }
}

class DocumentDto {
  final String number;
  final int userId;
  final int customerId;
  final String date;
  final double total;
  final int companyId;

  DocumentDto({
    required this.number,
    required this.userId,
    required this.customerId,
    required this.date,
    required this.total,
    required this.companyId,
  });

  Map<String, dynamic> toJson() => {
        "Number": number,
        "UserId": userId,
        "CustomerId": customerId,
        "Date": date,
        "Total": total,
        "CompanyId": companyId,
      };
}
