/// Units of measure.
///
/// A verbatim mirror of `Back-End/Web-POS.Api/Domain/UnitOfMeasure.cs` — the ids,
/// factors and rounding MUST stay identical, because the id is what travels in
/// `Product.uomId` and both sides convert with it independently. Change one file
/// and you change the other in the same commit.
library;

/// The category a unit belongs to.
///
/// Conversion is only ever legal BETWEEN units of one category — grams convert
/// to kilograms, never to litres.
enum UomCategory { unit, weight, volume, length }

/// One entry of the hardcoded unit catalog.
class UnitOfMeasure {
  /// Permanent id, written into `Product.uomId`. Never reuse or renumber one.
  final int id;

  /// Short symbol shown next to a quantity ('kg', 'g', 'pcs').
  final String code;

  final UomCategory category;

  /// How many of THIS unit make one reference unit of the category — `g` has
  /// factor 1000 because 1000 g are one kg. Converting a quantity to the
  /// reference unit is therefore a DIVISION by the factor.
  final double factor;

  /// Smallest meaningful step (0.001 for kg, 1 for g). Quantities snap to it so
  /// a scale's floating noise cannot write 0.4999999996 kg into stock.
  final double rounding;

  /// Decimal places implied by [rounding], for display and for the keypad.
  final int digits;

  const UnitOfMeasure({
    required this.id,
    required this.code,
    required this.category,
    required this.factor,
    required this.rounding,
    required this.digits,
  });

  /// True for the one unit its category is stored in.
  bool get isReference => factor == 1.0;

  /// Whether a quantity in this unit can sensibly be a fraction. Drives whether
  /// the POS offers a decimal keypad or plain +/- steppers.
  bool get allowsFractions => digits > 0;
}

// ── Well-known ids ───────────────────────────────────────────────────────────

const int kUomPieces = 1;
const int kUomKilogram = 10;
const int kUomGram = 11;
const int kUomLitre = 20;
const int kUomMillilitre = 21;
const int kUomMetre = 30;

/// The catalog, grouped by category with the reference unit first.
const List<UnitOfMeasure> kUnitsOfMeasure = [
  // Unit — reference: pcs
  UnitOfMeasure(id: kUomPieces, code: 'pcs', category: UomCategory.unit, factor: 1, rounding: 1, digits: 0),
  UnitOfMeasure(id: 2, code: 'dozen', category: UomCategory.unit, factor: 1 / 12, rounding: 1, digits: 0),
  UnitOfMeasure(id: 3, code: 'box', category: UomCategory.unit, factor: 1 / 12, rounding: 1, digits: 0),
  UnitOfMeasure(id: 4, code: 'pack', category: UomCategory.unit, factor: 1 / 6, rounding: 1, digits: 0),

  // Weight — reference: kg
  UnitOfMeasure(id: kUomKilogram, code: 'kg', category: UomCategory.weight, factor: 1, rounding: 0.001, digits: 3),
  UnitOfMeasure(id: kUomGram, code: 'g', category: UomCategory.weight, factor: 1000, rounding: 1, digits: 0),
  UnitOfMeasure(id: 12, code: 'lb', category: UomCategory.weight, factor: 2.20462, rounding: 0.01, digits: 2),

  // Volume — reference: L
  UnitOfMeasure(id: kUomLitre, code: 'L', category: UomCategory.volume, factor: 1, rounding: 0.001, digits: 3),
  UnitOfMeasure(id: kUomMillilitre, code: 'mL', category: UomCategory.volume, factor: 1000, rounding: 1, digits: 0),

  // Length — reference: m
  UnitOfMeasure(id: kUomMetre, code: 'm', category: UomCategory.length, factor: 1, rounding: 0.001, digits: 3),
  UnitOfMeasure(id: 31, code: 'cm', category: UomCategory.length, factor: 100, rounding: 1, digits: 0),
];

final Map<int, UnitOfMeasure> _byId = {for (final u in kUnitsOfMeasure) u.id: u};

final Map<UomCategory, UnitOfMeasure> _referenceByCategory = {
  for (final u in kUnitsOfMeasure.where((u) => u.isReference)) u.category: u,
};

/// The unit with [id], or pieces when the id is unknown or null.
///
/// Never throws: a product carrying a stale id must still sell.
UnitOfMeasure uomById(int? id) => _byId[id] ?? _byId[kUomPieces]!;

/// The unit [unit]'s category keeps its stock in.
UnitOfMeasure referenceUomOf(UnitOfMeasure unit) => _referenceByCategory[unit.category]!;

/// The catalog grouped for a dropdown, categories in catalog order.
Map<UomCategory, List<UnitOfMeasure>> uomsByCategory() {
  final grouped = <UomCategory, List<UnitOfMeasure>>{};
  for (final u in kUnitsOfMeasure) {
    grouped.putIfAbsent(u.category, () => []).add(u);
  }
  return grouped;
}

/// Converts [quantity], expressed in the unit with [uomId], into that category's
/// reference unit — the only unit stock is ever held in.
///
/// 100 g (uomId 11) becomes 0.100 kg.
double uomToReference(double quantity, int? uomId) {
  final unit = uomById(uomId);
  final converted = unit.isReference ? quantity : quantity / unit.factor;
  return snapToStorage(converted);
}

/// The inverse of [uomToReference]: expresses a reference-unit quantity in the
/// unit with [uomId]. Used to show stock in the unit a product is sold in.
double uomFromReference(double referenceQuantity, int? uomId) {
  final unit = uomById(uomId);
  final converted =
      unit.isReference ? referenceQuantity : referenceQuantity * unit.factor;
  return snapToStorage(converted);
}

/// The precision every quantity column actually stores — `decimal(18,4)` on
/// SQL Server. 0.0001 kg is a tenth of a gram.
const double kQuantityStorageStep = 0.0001;

/// Kills binary-floating error without altering the number.
///
/// Snapping to the UNIT's rounding was wrong here and quietly destructive: on a
/// `pcs` product (rounding 1) it turned a deliberate 0.5 into 1, both on the
/// line and in the stock deduction. The unit's rounding is a display and
/// scale-reading concern; what conversion needs is only to stop 0.4999999996
/// reaching the database, so it snaps at the storage precision instead.
double snapToStorage(double value) => snapToRounding(value, kQuantityStorageStep);

/// Rounds to the nearest multiple of [rounding].
double snapToRounding(double value, double rounding) {
  if (rounding <= 0) return value;

  // Scaled through an int before multiplying back, so 0.001 steps do not
  // reintroduce the binary-floating error this call exists to remove.
  return (value / rounding).roundToDouble() * rounding;
}

/// Formats [quantity] at the precision its unit deserves — `1.500 kg`, `250 g`,
/// `2 pcs`.
String formatQuantity(double quantity, int? uomId, {bool withCode = true}) {
  final unit = uomById(uomId);
  final text = formatQuantityValue(quantity, uomId);
  return withCode ? '$text ${unit.code}' : text;
}

/// The number alone. Split from [formatQuantity] for table cells and text
/// fields that supply their own unit column.
///
/// Two rules, and the second one matters more than the first:
///
/// 1. Trailing zeros are KEPT down to the unit's precision — a kilogram reads
///    `88.000`, never `88`. On a weighed product those digits are the point.
/// 2. A digit the quantity actually HAS is never hidden. Formatting strictly at
///    the unit's precision looked tidy right up until a line carried 0.25 on a
///    unit whose precision is 0, and the cart, the receipt and the customer
///    display all confidently printed `0`. A quantity that renders as zero when
///    it is not zero is worse than an ugly one, and it survives into paper.
///
/// So: at least the unit's decimals, and more whenever the value needs them.
String formatQuantityValue(double quantity, int? uomId) {
  var digits = uomById(uomId).digits;

  // Grow until the rendered text round-trips to the same number. Capped at 6
  // because past that a double is reporting its own binary error, not a count.
  while (digits < 6 &&
      double.parse(quantity.toStringAsFixed(digits)) != quantity) {
    digits++;
  }

  return quantity.toStringAsFixed(digits);
}

/// A quantity for a report row, which carries no unit of its own.
///
/// Reports formatted quantities with the MONEY pattern (`#,##0.00`), so a real
/// 0.002 kg sale printed as `0.00` — the figure the shop reconciles against,
/// reading as nothing sold. Falls through to [formatQuantityValue]'s rule: show
/// what the number has, hide nothing.
String formatReportQuantity(double quantity) => formatQuantityValue(quantity, null);

/// Best-effort match of the legacy free-text `measurementUnit` onto a catalog id.
///
/// Mirrors `UnitOfMeasure.FromLegacyText` in C# and the migration's backfill SQL.
/// Used when an older local row has a unit string but no id yet.
int uomFromLegacyText(String? text) {
  if (text == null || text.trim().isEmpty) return kUomPieces;

  switch (text.trim().toLowerCase()) {
    case 'kg':
    case 'kgs':
    case 'kilo':
    case 'kilos':
    case 'kilogram':
    case 'kilograms':
      return kUomKilogram;
    case 'g':
    case 'gr':
    case 'gm':
    case 'gram':
    case 'grams':
      return kUomGram;
    case 'lb':
    case 'lbs':
    case 'pound':
    case 'pounds':
      return 12;
    case 'l':
    case 'lt':
    case 'ltr':
    case 'litre':
    case 'litres':
    case 'liter':
    case 'liters':
      return kUomLitre;
    case 'ml':
    case 'millilitre':
    case 'millilitres':
    case 'milliliter':
    case 'milliliters':
      return kUomMillilitre;
    case 'm':
    case 'mtr':
    case 'meter':
    case 'meters':
    case 'metre':
    case 'metres':
      return kUomMetre;
    case 'cm':
    case 'centimeter':
    case 'centimeters':
    case 'centimetre':
    case 'centimetres':
      return 31;
    case 'dozen':
    case 'dz':
    case 'doz':
      return 2;
    case 'box':
    case 'bx':
    case 'carton':
      return 3;
    case 'pack':
    case 'pk':
    case 'packet':
      return 4;
    default:
      return kUomPieces;
  }
}
