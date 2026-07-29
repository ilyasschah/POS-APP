import '../core/formatters.dart';
import '../core/json_utils.dart';

/// A row from `GET /Document/GetAll` (singular `Document` — real backend
/// naming).
class SalesDocument {
  const SalesDocument({
    required this.id,
    required this.number,
    required this.customerName,
    required this.documentTypeName,
    required this.total,
    this.date,
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

  factory SalesDocument.fromJson(Map<String, dynamic> json) => SalesDocument(
    id: asInt(json['id']),
    number: asString(json['number'], '—'),
    customerName: asString(json['customerName'], 'Unknown customer'),
    documentTypeName: asString(json['documentTypeName'], '—'),
    total: asDouble(json['total']),
    date: Fmt.parseDate(json['date']),
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
  });

  final int id;
  final String productName;
  final double quantity;

  /// Unit price.
  final double price;
  final double total;

  factory DocumentLineItem.fromJson(Map<String, dynamic> json) =>
      DocumentLineItem(
        id: asInt(json['id']),
        productName: asString(json['productName'], 'Unknown product'),
        quantity: asDouble(json['quantity']),
        price: asDouble(json['price']),
        total: asDouble(json['total']),
      );
}
