import '../core/formatters.dart';
import '../core/json_utils.dart';

/// A row from `GET /Document/GetAll` (singular `Document` — real backend
/// naming). The endpoint returns the whole `DocumentDto`, which is what lets
/// the editor open a document without a second fetch.
class SalesDocument {
  const SalesDocument({
    required this.id,
    required this.number,
    required this.customerName,
    required this.documentTypeName,
    required this.total,
    this.date,
    this.documentTypeId = 0,
    this.customerId,
    this.userId = 0,
    this.userName,
    this.warehouseId = 0,
    this.warehouseName,
    this.orderNumber,
    this.stockDate,
    this.dueDate,
    this.referenceDocumentNumber,
    this.note,
    this.internalNote,
    this.discount = 0,
    this.discountType = 0,
    this.paidStatus = 0,
  });

  final int id;
  final String number;
  final String customerName;

  /// Human-readable type straight from the API — no client-side
  /// typeId -> name map.
  final String documentTypeName;

  /// NOTE: the field is `total`, **not** `totalAmount`.
  final double total;

  final DateTime? date;
  final int documentTypeId;
  final int? customerId;
  final int userId;
  final String? userName;
  final int warehouseId;
  final String? warehouseName;

  /// Set by checkout, refund and void — the POS's own documents.
  final String? orderNumber;
  final DateTime? stockDate;
  final DateTime? dueDate;
  final String? referenceDocumentNumber;
  final String? note;
  final String? internalNote;
  final double discount;

  /// 0 = percentage, 1 = amount.
  final int discountType;
  final int paidStatus;

  /// Rung up on a register. Its stock and payments belong to the flow that
  /// wrote it — checkout, refund or void — so the dashboard shows it but
  /// never edits or deletes it: removing a sale from a browser would leave its
  /// stock out and its drawer short, with the register none the wiser.
  bool get isPosDocument => orderNumber?.trim().isNotEmpty ?? false;

  /// Case-insensitive match on number, customer or type, for the search box.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return number.toLowerCase().contains(q) ||
        customerName.toLowerCase().contains(q) ||
        documentTypeName.toLowerCase().contains(q);
  }

  factory SalesDocument.fromJson(Map<String, dynamic> json) => SalesDocument(
    id: asInt(json['id']),
    number: asString(json['number'], '—'),
    customerName: asString(json['customerName'], 'Unknown customer'),
    documentTypeName: asString(json['documentTypeName'], '—'),
    total: asDouble(json['total']),
    date: Fmt.parseDate(json['date']),
    documentTypeId: asInt(json['documentTypeId']),
    customerId: asIntOrNull(json['customerId']),
    userId: asInt(json['userId']),
    userName: asStringOrNull(json['userName']),
    warehouseId: asInt(json['warehouseId']),
    warehouseName: asStringOrNull(json['warehouseName']),
    orderNumber: asStringOrNull(json['orderNumber']),
    stockDate: Fmt.parseDate(json['stockDate']),
    dueDate: Fmt.parseDate(json['dueDate']),
    referenceDocumentNumber: asStringOrNull(json['referenceDocumentNumber']),
    note: asStringOrNull(json['note']),
    internalNote: asStringOrNull(json['internalNote']),
    discount: asDouble(json['discount']),
    discountType: asInt(json['discountType']),
    paidStatus: asInt(json['paidStatus']),
  );
}

/// A row from `GET /DocumentItems/GetByDocumentId` (plural `DocumentItems`).
class DocumentLineItem {
  const DocumentLineItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
    this.productId = 0,
    this.priceBeforeTax = 0,
    this.discount = 0,
    this.discountType = 0,
    this.expectedQuantity,
    this.productCost = 0,
  });

  final int id;
  final String productName;
  final double quantity;

  /// Unit price, tax included.
  final double price;
  final double total;
  final int productId;
  final double priceBeforeTax;
  final double discount;
  final int discountType;

  /// What an inventory count was counted against. Every other line carries
  /// its own quantity here.
  final double? expectedQuantity;
  final double productCost;

  factory DocumentLineItem.fromJson(Map<String, dynamic> json) =>
      DocumentLineItem(
        id: asInt(json['id']),
        productName: asString(json['productName'], 'Unknown product'),
        quantity: asDouble(json['quantity']),
        price: asDouble(json['price']),
        total: asDouble(json['total']),
        productId: asInt(json['productId']),
        priceBeforeTax: asDouble(json['priceBeforeTax']),
        discount: asDouble(json['discount']),
        discountType: asInt(json['discountType']),
        expectedQuantity: asDoubleOrNull(json['expectedQuantity']),
        productCost: asDouble(json['productCost']),
      );
}
