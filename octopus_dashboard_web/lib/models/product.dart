import '../core/json_utils.dart';
import 'unit_of_measure.dart';

/// A row from `GET /Products/GetAll`.
///
/// The huge base64 `image` field is deliberately never decoded, stored or
/// re-sent — it is unused by every screen and would bloat both memory and the
/// update payload.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.code,
    required this.price,
    required this.cost,
    required this.isTaxInclusivePrice,
    required this.isPriceChangeAllowed,
    required this.isService,
    required this.isUsingDefaultQuantity,
    required this.isEnabled,
    required this.color,
    this.productGroupId,
    this.productGroupName,
    this.plu,
    this.measurementUnit,
    this.currencyId,
    this.description,
    this.markup,
    this.ageRestriction,
    this.lastPurchasePrice,
    this.rank,
    this.uomId = kUomPieces,
    this.isToWeigh = false,
    this.packSize,
  });

  final int id;

  // --- Required (non-nullable) server-side on update ---------------------
  final String name;
  final double price;
  final double cost;
  final bool isTaxInclusivePrice;
  final bool isPriceChangeAllowed;
  final bool isService;
  final bool isUsingDefaultQuantity;
  final bool isEnabled;
  final String color;

  // --- Optional / nullable, passed through unchanged ---------------------
  final String? code;
  final int? productGroupId;
  final String? productGroupName;
  final int? plu;
  final String? measurementUnit;
  final int? currencyId;
  final String? description;
  final double? markup;
  final int? ageRestriction;
  final double? lastPurchasePrice;
  final int? rank;

  /// The unit it is sold in — an id into [kUnitsOfMeasure].
  final int uomId;

  /// Weighed at the till rather than counted.
  final bool isToWeigh;

  /// Pieces in one box / pack of THIS product. Null = the nominal 12 / 6.
  final double? packSize;

  String get displayName => name.isEmpty ? 'Unnamed product' : name;

  /// [uomId], healed the way the POS heals it: a row still carrying the bare
  /// pieces default while its legacy text names a real unit was set up in that
  /// unit — the text is the choice somebody actually made.
  int get effectiveUomId {
    if (uomId != kUomPieces) return uomId;
    return uomByCode(measurementUnit)?.id ?? kUomPieces;
  }

  UnitOfMeasure get saleUnit => uomById(effectiveUomId);

  /// The unit its stock is counted in (kg for a product sold in grams).
  UnitOfMeasure get stockUnit => stockUomOf(effectiveUomId);

  /// Case-insensitive match on name or code, for the client-side search box.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        (code?.toLowerCase().contains(q) ?? false);
  }

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: asInt(json['id']),
    name: asString(json['name']),
    code: asStringOrNull(json['code']),
    price: asDouble(json['price']),
    cost: asDouble(json['cost']),
    isTaxInclusivePrice: asBool(json['isTaxInclusivePrice']),
    isPriceChangeAllowed: asBool(json['isPriceChangeAllowed']),
    isService: asBool(json['isService']),
    isUsingDefaultQuantity: asBool(json['isUsingDefaultQuantity']),
    isEnabled: asBool(json['isEnabled'], true),
    // `color` is non-nullable server-side; the API's own default is
    // "Transparent", so fall back to that rather than an empty string.
    color: asString(json['color'], 'Transparent'),
    productGroupId: asIntOrNull(json['productGroupId']),
    productGroupName: asStringOrNull(json['productGroupName']),
    plu: asIntOrNull(json['plu']),
    measurementUnit: asStringOrNull(json['measurementUnit']),
    currencyId: asIntOrNull(json['currencyId']),
    description: asStringOrNull(json['description']),
    markup: asDoubleOrNull(json['markup']),
    ageRestriction: asIntOrNull(json['ageRestriction']),
    lastPurchasePrice: asDoubleOrNull(json['lastPurchasePrice']),
    rank: asIntOrNull(json['rank']),
    uomId: asInt(json['uomId'], kUomPieces),
    isToWeigh: asBool(json['isToWeigh']),
    packSize: asDoubleOrNull(json['packSize']),
  );

  /// Builds the `PATCH /Products/Update` body.
  ///
  /// The backend rejects partial updates: every required field must be
  /// present, so an edit that only touches price/cost still resends the rest
  /// unchanged from the fetched record.
  Map<String, dynamic> toUpdateJson({
    required double newPrice,
    required double newCost,
  }) => {
    'id': id,
    // Required server-side.
    'name': name,
    'price': newPrice,
    'cost': newCost,
    'isTaxInclusivePrice': isTaxInclusivePrice,
    'isPriceChangeAllowed': isPriceChangeAllowed,
    'isService': isService,
    'isUsingDefaultQuantity': isUsingDefaultQuantity,
    'isEnabled': isEnabled,
    'color': color,
    // Optional, echoed back untouched.
    'productGroupId': productGroupId,
    'code': code,
    'plu': plu,
    'measurementUnit': measurementUnit,
    'currencyId': currencyId,
    'description': description,
    'markup': markup,
    'ageRestriction': ageRestriction,
    'lastPurchasePrice': lastPurchasePrice,
    'rank': rank,
    'uomId': uomId,
    'isToWeigh': isToWeigh,
    'packSize': packSize,
  };

  Map<String, dynamic> toCreateJson({
    required String newName,
    required double newPrice,
    required double newCost,
    required int? newProductGroupId,
    required String newColor,
  }) => {
    'productGroupId': newProductGroupId,
    'name': newName.trim(),
    'price': newPrice,
    'cost': newCost,
    'color': newColor.trim().isEmpty ? 'Transparent' : newColor.trim(),
    'uomId': uomId,
    'isTaxInclusivePrice': false,
    'isPriceChangeAllowed': true,
    'isService': false,
    'isUsingDefaultQuantity': true,
    'isEnabled': true,
  };
}
