import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/formatters.dart';
import '../../models/document.dart';
import '../../models/document_lookups.dart';
import '../../models/product.dart';
import '../../models/unit_of_measure.dart';

/// The document editor's model: what the operator has entered so far, as plain
/// data, with no widgets and no network — so the rules that decide what gets
/// sent can be tested on their own.

/// Whether a discount is a share of the price or an amount off it — the
/// server's `DiscountType`.
abstract final class DiscountKind {
  static const int percent = 0;
  static const int amount = 1;
}

/// The steps of creating a document, in the order the wizard walks them.
enum DocumentStep {
  type('Type'),
  details('Details'),
  parties('Parties'),
  lines('Lines'),
  review('Review');

  const DocumentStep(this.title);
  final String title;

  bool get isFirst => index == 0;
  bool get isLast => this == DocumentStep.review;
  DocumentStep get next => DocumentStep.values[math.min(index + 1, 4)];
  DocumentStep get previous => DocumentStep.values[math.max(index - 1, 0)];
}

typedef LineMoney = ({double unitPrice, double unitDiscount, double total});

/// The money of one line carrying at most one tax.
///
/// The POS editor's `editorLineMoney`, and what the server's
/// `DocumentItemTaxService.RecalculateItemAsync` rewrites the line to once its
/// tax arrives. The three must agree, or a line's total changes after it is
/// saved. A fixed tax is a flat amount per unit: added to the price rather
/// than multiplied into it, and a percentage discount never shrinks it.
LineMoney lineMoney({
  required double priceBeforeTax,
  required double quantity,
  required double discount,
  required int discountType,
  TaxOption? tax,
}) {
  final rate = tax?.rate ?? 0;
  final isFixed = tax?.isFixed ?? false;
  final fixedPerUnit = isFixed ? rate : 0.0;
  final unitPrice = isFixed
      ? priceBeforeTax + rate
      : priceBeforeTax * (1 + rate / 100);
  final unitDiscount = discountType == DiscountKind.percent
      ? (unitPrice - fixedPerUnit) * (discount / 100)
      : discount;
  return (
    unitPrice: unitPrice,
    unitDiscount: unitDiscount,
    total: (unitPrice - unitDiscount) * quantity,
  );
}

/// Expresses [referenceQuantity] — stock, which is held in its category's
/// reference unit — in the unit [product] is sold in, as the POS's
/// `uomFromReference` does: 0.25 kg of a gram-priced product is 250 g.
///
/// An inventory count line is typed in the product's unit, so the stock it is
/// counted against must be in that unit before the two are compared.
double stockInProductUnit(double referenceQuantity, Product product) {
  final factor = _uomFactor(product.effectiveUomId, product.packSize);
  final converted = factor == 1 ? referenceQuantity : referenceQuantity * factor;
  return double.parse(converted.toStringAsFixed(4));
}

/// How many of a unit make one reference unit — mirrored from the POS
/// catalogue (`Front-End/lib/uom/unit_of_measure.dart`). A box or pack uses
/// the product's own pack size when it states one.
double _uomFactor(int uomId, double? packSize) {
  if ((uomId == kUomBox || uomId == kUomPack) &&
      packSize != null &&
      packSize > 0) {
    return 1 / packSize;
  }
  return switch (uomId) {
    2 || kUomBox => 1 / 12,
    kUomPack => 1 / 6,
    11 || 21 => 1000,
    12 => 2.20462,
    31 => 100,
    _ => 1,
  };
}

const Object _unset = Object();

/// One line of a document being edited.
@immutable
class DraftLine {
  DraftLine({
    String? key,
    this.serverId,
    required this.productId,
    required this.productName,
    this.uomId = kUomPieces,
    required this.quantity,
    this.expectedQuantity,
    required this.priceBeforeTax,
    this.discount = 0,
    this.discountType = DiscountKind.percent,
    this.tax,
    this.pushedTaxId,
    this.productCost = 0,
  }) : key = key ?? (serverId != null ? 'line-$serverId' : 'new-${_nextKey++}');

  static int _nextKey = 0;

  /// This line's identity inside the editor — stable across edits and saves.
  final String key;

  /// The server's id for the line; null until it has been saved.
  final int? serverId;

  final int productId;
  final String productName;

  /// The unit [quantity] is counted in: the product's own.
  final int uomId;
  final double quantity;

  /// An inventory count's stock at the moment it was counted, in the
  /// product's unit. Null on every other line, which expects what it carries.
  final double? expectedQuantity;

  final double priceBeforeTax;
  final double discount;
  final int discountType;
  final TaxOption? tax;

  /// The tax the SERVER holds on this line, which it keeps apart from the line
  /// itself. Differs from [tax] until the change has been pushed.
  final int? pushedTaxId;
  final double productCost;

  LineMoney get money => lineMoney(
    priceBeforeTax: priceBeforeTax,
    quantity: quantity,
    discount: discount,
    discountType: discountType,
    tax: tax,
  );

  double get total => money.total;

  String get quantityLabel => formatUomQuantity(quantity, uomById(uomId));

  DraftLine copyWith({
    Object? serverId = _unset,
    int? productId,
    String? productName,
    int? uomId,
    double? quantity,
    Object? expectedQuantity = _unset,
    double? priceBeforeTax,
    double? discount,
    int? discountType,
    Object? tax = _unset,
    Object? pushedTaxId = _unset,
    double? productCost,
  }) => DraftLine(
    key: key,
    serverId: identical(serverId, _unset) ? this.serverId : serverId as int?,
    productId: productId ?? this.productId,
    productName: productName ?? this.productName,
    uomId: uomId ?? this.uomId,
    quantity: quantity ?? this.quantity,
    expectedQuantity: identical(expectedQuantity, _unset)
        ? this.expectedQuantity
        : expectedQuantity as double?,
    priceBeforeTax: priceBeforeTax ?? this.priceBeforeTax,
    discount: discount ?? this.discount,
    discountType: discountType ?? this.discountType,
    tax: identical(tax, _unset) ? this.tax : tax as TaxOption?,
    pushedTaxId: identical(pushedTaxId, _unset)
        ? this.pushedTaxId
        : pushedTaxId as int?,
    productCost: productCost ?? this.productCost,
  );

  /// The `POST /DocumentItems/Add` body — the same shape the POS pushes.
  Map<String, dynamic> toCreateJson(int documentId) => {
    'documentId': documentId,
    'productId': productId,
    'quantity': quantity,
    // An inventory count moves stock by counted − expected; every other line
    // expects exactly what it carries.
    'expectedQuantity': expectedQuantity ?? quantity,
    'priceBeforeTax': priceBeforeTax,
    'price': money.unitPrice,
    'discount': discount,
    'discountType': discountType,
    'productCost': productCost,
    'discountApplyRule': true,
  };

  /// The `PATCH /DocumentItems/Update` body.
  Map<String, dynamic> toUpdateJson(int documentId) => {
    'id': serverId,
    ...toCreateJson(documentId),
  };

  /// Whether the server's copy of the line (its tax aside) would change.
  bool differsFrom(DraftLine other) =>
      productId != other.productId ||
      quantity != other.quantity ||
      (expectedQuantity ?? quantity) !=
          (other.expectedQuantity ?? other.quantity) ||
      priceBeforeTax != other.priceBeforeTax ||
      discount != other.discount ||
      discountType != other.discountType;

  /// A line the server already holds, with the tax it carries there.
  factory DraftLine.fromServer(
    DocumentLineItem item, {
    required DocumentLookups lookups,
    required bool isInventoryCount,
    int? taxId,
  }) {
    final product = lookups.productById(item.productId);
    return DraftLine(
      serverId: item.id,
      productId: item.productId,
      productName: product?.displayName ?? item.productName,
      uomId: product?.effectiveUomId ?? kUomPieces,
      quantity: item.quantity,
      expectedQuantity: isInventoryCount ? item.expectedQuantity : null,
      priceBeforeTax: item.priceBeforeTax,
      discount: item.discount,
      discountType: item.discountType,
      tax: lookups.taxById(taxId),
      pushedTaxId: taxId,
      productCost: item.productCost,
    );
  }
}

/// A document being created or edited.
@immutable
class DocumentDraft {
  const DocumentDraft({
    this.id,
    this.type,
    this.number = '',
    this.autoNumber,
    required this.date,
    required this.stockDate,
    required this.dueDate,
    this.customerId,
    this.userId,
    this.warehouseId,
    this.reference = '',
    this.note = '',
    this.internalNote = '',
    this.discount = 0,
    this.discountType = DiscountKind.percent,
    this.lines = const [],
  });

  factory DocumentDraft.blank(DateTime now) => DocumentDraft(
    date: now,
    stockDate: now,
    dueDate: now.add(const Duration(days: 30)),
  );

  /// An existing document, ready to edit.
  factory DocumentDraft.fromDocument(
    SalesDocument document, {
    required DocumentLookups lookups,
    required List<DraftLine> lines,
  }) {
    final date = document.date ?? DateTime.now();
    return DocumentDraft(
      id: document.id,
      type: lookups.typeById(document.documentTypeId),
      number: document.number,
      date: date,
      stockDate: document.stockDate ?? date,
      dueDate: document.dueDate ?? date,
      customerId: document.customerId,
      userId: document.userId > 0 ? document.userId : null,
      warehouseId: document.warehouseId > 0 ? document.warehouseId : null,
      reference: document.referenceDocumentNumber ?? '',
      note: document.note ?? '',
      internalNote: document.internalNote ?? '',
      discount: document.discount,
      discountType: document.discountType,
      lines: lines,
    );
  }

  /// The server's id; null until the document has been created.
  final int? id;
  final DocumentTypeOption? type;
  final String number;

  /// The number the editor filled in. While [number] still shows it, the
  /// number follows the type — it carries the type's code (26-220-…), so a
  /// Refund must not keep the 200 number of the Sale picked before it. One the
  /// operator typed is theirs and is kept.
  final String? autoNumber;

  /// The document's calendar day.
  final DateTime date;

  /// When the goods moved — what the Stock Moves history orders by.
  final DateTime stockDate;
  final DateTime dueDate;
  final int? customerId;
  final int? userId;
  final int? warehouseId;
  final String reference;
  final String note;
  final String internalNote;
  final double discount;
  final int discountType;
  final List<DraftLine> lines;

  bool get isCreated => id != null;
  bool get numberFollowsType =>
      number.trim().isEmpty || number == autoNumber;

  /// Lines already on the server have moved stock in this warehouse, as this
  /// type. Changing either afterwards would leave that stock where it went.
  bool get hasSavedLines => lines.any((l) => l.serverId != null);

  double get subtotal => lines.fold<double>(0, (sum, l) => sum + l.total);

  double get discountAmount {
    final raw = discountType == DiscountKind.amount
        ? discount
        : subtotal * discount / 100;
    return raw.clamp(0, math.max(0, subtotal)).toDouble();
  }

  double get total => math.max(0, subtotal - discountAmount);

  DocumentDraft copyWith({
    Object? id = _unset,
    Object? type = _unset,
    String? number,
    Object? autoNumber = _unset,
    DateTime? date,
    DateTime? stockDate,
    DateTime? dueDate,
    Object? customerId = _unset,
    Object? userId = _unset,
    Object? warehouseId = _unset,
    String? reference,
    String? note,
    String? internalNote,
    double? discount,
    int? discountType,
    List<DraftLine>? lines,
  }) => DocumentDraft(
    id: identical(id, _unset) ? this.id : id as int?,
    type: identical(type, _unset) ? this.type : type as DocumentTypeOption?,
    number: number ?? this.number,
    autoNumber: identical(autoNumber, _unset)
        ? this.autoNumber
        : autoNumber as String?,
    date: date ?? this.date,
    stockDate: stockDate ?? this.stockDate,
    dueDate: dueDate ?? this.dueDate,
    customerId: identical(customerId, _unset)
        ? this.customerId
        : customerId as int?,
    userId: identical(userId, _unset) ? this.userId : userId as int?,
    warehouseId: identical(warehouseId, _unset)
        ? this.warehouseId
        : warehouseId as int?,
    reference: reference ?? this.reference,
    note: note ?? this.note,
    internalNote: internalNote ?? this.internalNote,
    discount: discount ?? this.discount,
    discountType: discountType ?? this.discountType,
    lines: lines ?? this.lines,
  );

  /// Adds [line], or replaces the line it was edited from.
  DocumentDraft withLine(DraftLine line) {
    final index = lines.indexWhere((l) => l.key == line.key);
    return copyWith(
      lines: index < 0
          ? [...lines, line]
          : [for (final l in lines) l.key == line.key ? line : l],
    );
  }

  DocumentDraft withoutLine(String key) =>
      copyWith(lines: [for (final l in lines) if (l.key != key) l]);

  /// Why [step] cannot be left yet, or null when it can. The wording says
  /// what to do, not what went wrong.
  String? problemAt(DocumentStep step, {required bool creating}) {
    switch (step) {
      case DocumentStep.type:
        return type == null ? 'Pick the kind of document to create.' : null;
      case DocumentStep.details:
        if (number.trim().isEmpty) return 'Give the document a number.';
        if (_day(dueDate).isBefore(_day(date))) {
          return 'Set the due date on or after the document date.';
        }
        return null;
      case DocumentStep.parties:
        if (customerId == null) {
          return type?.tradesWithSuppliers == true
              ? 'Choose the supplier.'
              : 'Choose the customer.';
        }
        if (userId == null) return 'Choose the staff member responsible.';
        if (warehouseId == null) return 'Choose the warehouse.';
        return null;
      case DocumentStep.lines:
        return creating && lines.isEmpty
            ? 'Add at least one line.'
            : null;
      case DocumentStep.review:
        if (discount < 0) return 'Enter a discount of zero or more.';
        if (discountType == DiscountKind.percent && discount > 100) {
          return 'Enter a percentage discount of 100 or less.';
        }
        return null;
    }
  }

  /// The first step that still needs something, with what it needs.
  (DocumentStep, String)? firstProblem({required bool creating}) {
    for (final step in DocumentStep.values) {
      final problem = problemAt(step, creating: creating);
      if (problem != null) return (step, problem);
    }
    return null;
  }

  /// The `POST /Document/Add` body — the shape the POS pushes for a manual
  /// document. No order number: that is what marks a register's documents.
  Map<String, dynamic> createJson() => {
    'number': number.trim(),
    'userId': userId,
    'customerId': customerId,
    'orderNumber': null,
    ..._datesJson(),
    'total': total,
    'isClockedOut': true,
    'documentTypeId': type?.id,
    'warehouseId': warehouseId,
    'internalNote': internalNote.trim(),
    'note': note.trim(),
    'referenceDocumentNumber': reference.trim(),
    'discount': discount,
    'discountType': discountType,
    'paidStatus': 0,
    'discountApplyRule': true,
    'serviceType': 0,
  };

  /// The `PATCH /Document/Update` body. The endpoint has no discount type and
  /// no user, so neither can change once the document exists.
  Map<String, dynamic> updateJson() => {
    'id': id,
    'number': number.trim(),
    'customerId': customerId,
    ..._datesJson(),
    'documentTypeId': type?.id,
    'warehouseId': warehouseId,
    'internalNote': internalNote.trim(),
    'note': note.trim(),
    'referenceDocumentNumber': reference.trim(),
    'discount': discount,
    'discountApplyRule': true,
    'total': total,
  };

  /// `Document.Date` and `DueDate` are calendar days: sent as the local day,
  /// never through UTC, which would land a midnight on the previous day.
  /// `StockDate` is an instant, so it travels as one.
  Map<String, dynamic> _datesJson() => {
    'date': Fmt.apiDate(date),
    'stockDate': stockDate.toUtc().toIso8601String(),
    'dueDate': Fmt.apiDate(dueDate),
  };

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
