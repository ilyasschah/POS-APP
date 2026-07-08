class MenuTax {
  final int id;
  final String name;
  final double rate;
  final bool isFixed;
  final bool isTaxOnTotal;

  MenuTax({
    required this.id,
    required this.name,
    required this.rate,
    required this.isFixed,
    required this.isTaxOnTotal,
  });

  factory MenuTax.fromJson(Map<String, dynamic> json) {
    return MenuTax(
      id: json['id'],
      name: json['name'] ?? '',
      rate: (json['rate'] ?? 0).toDouble(),
      isFixed: json['isFixed'] ?? false,
      isTaxOnTotal: json['isTaxOnTotal'] ?? false,
    );
  }
}

class MenuProduct {
  final int id;
  final String name;
  final double price;
  final double cost;
  final bool isTaxInclusivePrice;
  final String color;
  final double stockQuantity;
  final List<MenuTax> taxes;
  final bool isEnabled;
  final int? ageRestriction;
  final bool isPriceChangeAllowed;
  final bool isUsingDefaultQuantity;
  final String? measurementUnit;
  final bool isService;

  MenuProduct({
    required this.id,
    required this.name,
    required this.price,
    this.cost = 0.0,
    required this.isTaxInclusivePrice,
    required this.color,
    required this.stockQuantity,
    required this.taxes,
    this.isEnabled = true,
    this.ageRestriction,
    this.isPriceChangeAllowed = false,
    this.isUsingDefaultQuantity = true,
    this.measurementUnit,
    this.isService = false,
  });

  factory MenuProduct.fromJson(Map<String, dynamic> json) {
    return MenuProduct(
      id: json['id'],
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      cost: (json['cost'] ?? 0).toDouble(),
      isTaxInclusivePrice: json['isTaxInclusivePrice'] ?? true,
      color: json['color'] ?? 'Transparent',
      stockQuantity: (json['stockQuantity'] ?? 0).toDouble(),
      taxes:
          (json['taxes'] as List?)?.map((t) => MenuTax.fromJson(t)).toList() ??
          [],
      isEnabled: json['isEnabled'] ?? true,
      ageRestriction: json['ageRestriction'],
      isPriceChangeAllowed: json['isPriceChangeAllowed'] ?? false,
      isUsingDefaultQuantity: json['isUsingDefaultQuantity'] ?? true,
      measurementUnit: json['measurementUnit'],
      isService: json['isService'] ?? false,
    );
  }
}

class MenuCategory {
  final int id;
  final String name;
  final String color;
  final List<MenuProduct> products;

  MenuCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.products,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'],
      name: json['name'] ?? '',
      color: json['color'] ?? 'Transparent',
      products:
          (json['products'] as List?)
              ?.map((p) => MenuProduct.fromJson(p))
              .toList() ??
          [],
    );
  }
}

class CartItem {
  final String cartItemId;
  int posOrderId;
  final int productId;
  int roundNumber;
  double quantity;
  double price;
  final double cost;
  // Resolved per-unit manual discount in currency (the item-discount dialog
  // converts a % entry to money before storing, so the cart math can subtract
  // it directly). [discountType] is therefore effectively "fixed" for the math.
  double discount;
  int discountType;
  // The discount as the user ENTERED it, preserved for display/records so a
  // "10%" entry isn't flattened to its money value. Null = no manual discount
  // (or a legacy row where only the resolved amount is known). discount_lines
  // and receipts read these; the cart totals keep using [discount].
  double? discountInputValue;
  int? discountInputType; // 0 = %, 1 = fixed
  double promotionalDiscount;
  // Id of the promotion that produced [promotionalDiscount], set by
  // _applyPromotions. Lets the normalized discount_lines record trace a promo
  // discount back to its source. Null when no promotion applies.
  int? promotionId;
  String? comment;
  String? bundle;
  bool isSaved;
  final String productName;
  List<MenuTax> appliedTaxes;
  int? warehouseId;
  String? measurementUnit;
  final bool isService;

  CartItem({
    required this.cartItemId,
    required this.posOrderId,
    required this.productId,
    this.roundNumber = 1,
    this.quantity = 1,
    required this.price,
    this.cost = 0.0,
    this.discount = 0,
    this.discountType = 0,
    this.discountInputValue,
    this.discountInputType,
    this.promotionalDiscount = 0,
    this.promotionId,
    this.comment,
    this.bundle,
    this.isSaved = false,
    required this.productName,
    required this.appliedTaxes,
    this.warehouseId,
    this.measurementUnit,
    this.isService = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': 0,
      'Id': 0,
      'posOrderId': posOrderId,
      'PosOrderId': posOrderId,
      'productId': productId,
      'ProductId': productId,
      'productName': productName,
      'ProductName': productName,
      'roundNumber': roundNumber,
      'RoundNumber': roundNumber,
      'quantity': quantity,
      'Quantity': quantity,
      'price': price,
      'Price': price,
      'discount': discount,
      'Discount': discount,
      'discountType': discountType,
      'DiscountType': discountType,
      'promotionalDiscount': promotionalDiscount,
      'PromotionalDiscount': promotionalDiscount,
      'comment': comment,
      'Comment': comment,
      'bundle': bundle,
      'Bundle': bundle,
      'isLocked': false,
      'IsLocked': false,
      'isFeatured': false,
      'IsFeatured': false,
      'appliedTaxIds': appliedTaxes.map((t) => t.id).toList(),
      'AppliedTaxIds': appliedTaxes.map((t) => t.id).toList(),
      'warehouseId': warehouseId, // Include warehouseId in JSON
      'WarehouseId': warehouseId,
    };
  }
}

class CheckoutItemTaxDto {
  final int taxId;
  final double amount;

  CheckoutItemTaxDto({required this.taxId, required this.amount});

  Map<String, dynamic> toJson() {
    return {
      'taxId': taxId,
      'amount': amount,
    };
  }
}

class CheckoutItemDto {
  final int productId;
  final double quantity;
  final double priceBeforeTaxAfterDiscount;
  final double priceAfterDiscount;
  final double total;
  final double totalAfterDocumentDiscount;
  final List<CheckoutItemTaxDto> taxes;

  CheckoutItemDto({
    required this.productId,
    required this.quantity,
    required this.priceBeforeTaxAfterDiscount,
    required this.priceAfterDiscount,
    required this.total,
    required this.totalAfterDocumentDiscount,
    required this.taxes,
  });

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'quantity': quantity,
      'priceBeforeTaxAfterDiscount': priceBeforeTaxAfterDiscount,
      'priceAfterDiscount': priceAfterDiscount,
      'total': total,
      'totalAfterDocumentDiscount': totalAfterDocumentDiscount,
      'taxes': taxes.map((t) => t.toJson()).toList(),
    };
  }
}

class CheckoutRequest {
  final int posOrderId;
  final int paymentTypeId;
  final double amountPaid;
  final int documentTypeId;
  final int warehouseId;
  final List<CheckoutItemDto> items;
  final double grandTotal;
  final String? orderNumber;

  CheckoutRequest({
    required this.posOrderId,
    required this.paymentTypeId,
    required this.amountPaid,
    required this.documentTypeId,
    required this.warehouseId,
    required this.items,
    required this.grandTotal,
    this.orderNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'posOrderId': posOrderId,
      'paymentTypeId': paymentTypeId,
      'amountPaid': amountPaid,
      'documentTypeId': documentTypeId,
      'warehouseId': warehouseId,
      'items': items.map((i) => i.toJson()).toList(),
      'grandTotal': grandTotal,
      if (orderNumber != null) 'orderNumber': orderNumber,
    };
  }
}

// --- ORDER HEADER ---
class PosOrderDto {
  final int userId;
  final String number;
  final double discount;
  final int discountType;
  final double? total;
  final int? customerId;

  final String? userName;
  final String? customerName;

  PosOrderDto({
    required this.userId,
    required this.number,
    this.discount = 0,
    this.discountType = 0,
    this.total,
    this.customerId,
    this.userName,
    this.customerName,
  });

  Map<String, dynamic> toJson() {
    return {
      "Id": 0,
      "UserId": userId,
      "Number": number,
      "Discount": discount,
      "DiscountType": discountType,
      "Total": total,
      "CustomerId": customerId,
      "UserName": userName,
      "CustomerName": customerName,
    };
  }
}

// --- ORDER ITEMS ---
class PosOrderItemDto {
  final int posOrderId;
  final int productId;
  final String productName;
  final double quantity;
  final double price;
  final double discount;
  final int discountType;
  final bool isLocked;
  final bool isFeatured;

  PosOrderItemDto({
    required this.posOrderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.discount = 0.0,
    this.discountType = 0,
    this.isLocked = false,
    this.isFeatured = false,
  });

  Map<String, dynamic> toJson() {
    return {
      "Id": 0,
      "PosOrderId": posOrderId,
      "ProductId": productId,
      "ProductName": productName,
      "RoundNumber": 0,
      "Quantity": quantity,
      "Price": price,
      "IsLocked": isLocked,
      "Discount": discount,
      "DiscountType": discountType,
      "IsFeatured": isFeatured,
      "DateCreated": DateTime.now().toIso8601String(),
    };
  }
}
