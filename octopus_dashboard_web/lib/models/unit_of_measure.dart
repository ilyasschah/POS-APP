/// The unit-of-measure catalogue, mirrored from the POS
/// (`Front-End/lib/uom/unit_of_measure.dart`) and the API
/// (`Api.Domain.UnitOfMeasure`).
///
/// Stock is held in the REFERENCE unit of a product's category: kilograms for
/// anything sold by weight, litres by volume, metres by length, and pieces for
/// everything counted — a box of 12 is 12 pieces in stock. So a product sold in
/// grams shows its stock in kg, and one sold by the box shows pieces.
///
/// 🚨 A copy, guarded by `test/uom_catalog_mirror_test.dart`, which reads the
/// POS file and fails when the two disagree. Ids are permanent: never renumber.
library;

enum UomCategory { unit, weight, volume, length }

class UnitOfMeasure {
  const UnitOfMeasure({
    required this.id,
    required this.code,
    required this.category,
    required this.digits,
    this.isReference = false,
  });

  final int id;

  /// The symbol printed next to a quantity ('kg', 'g', 'pcs').
  final String code;
  final UomCategory category;

  /// Decimal places a quantity in this unit is shown with — 3 for kg, 0 for g.
  final int digits;

  /// True for the one unit its category's stock is stored in.
  final bool isReference;
}

const int kUomPieces = 1;
const int kUomBox = 3;
const int kUomPack = 4;

const List<UnitOfMeasure> kUnitsOfMeasure = [
  UnitOfMeasure(id: kUomPieces, code: 'pcs', category: UomCategory.unit, digits: 0, isReference: true),
  UnitOfMeasure(id: 2, code: 'dozen', category: UomCategory.unit, digits: 0),
  UnitOfMeasure(id: kUomBox, code: 'box', category: UomCategory.unit, digits: 0),
  UnitOfMeasure(id: kUomPack, code: 'pack', category: UomCategory.unit, digits: 0),
  UnitOfMeasure(id: 10, code: 'kg', category: UomCategory.weight, digits: 3, isReference: true),
  UnitOfMeasure(id: 11, code: 'g', category: UomCategory.weight, digits: 0),
  UnitOfMeasure(id: 12, code: 'lb', category: UomCategory.weight, digits: 2),
  UnitOfMeasure(id: 20, code: 'L', category: UomCategory.volume, digits: 3, isReference: true),
  UnitOfMeasure(id: 21, code: 'mL', category: UomCategory.volume, digits: 0),
  UnitOfMeasure(id: 30, code: 'm', category: UomCategory.length, digits: 3, isReference: true),
  UnitOfMeasure(id: 31, code: 'cm', category: UomCategory.length, digits: 0),
];

/// The unit with [id], or pieces when the id is unknown — never throws, so a
/// product carrying a stale id still lists.
UnitOfMeasure uomById(int? id) => kUnitsOfMeasure.firstWhere(
  (u) => u.id == id,
  orElse: () => kUnitsOfMeasure.first,
);

/// The unit whose [code] this is, compared without case; null when none is.
UnitOfMeasure? uomByCode(String? code) {
  final c = code?.trim().toLowerCase();
  if (c == null || c.isEmpty) return null;
  for (final u in kUnitsOfMeasure) {
    if (u.code.toLowerCase() == c) return u;
  }
  return null;
}

/// The unit a product's stock is counted in: the reference unit of the
/// category it is sold in.
UnitOfMeasure stockUomOf(int? uomId) {
  final category = uomById(uomId).category;
  return kUnitsOfMeasure.firstWhere(
    (u) => u.category == category && u.isReference,
  );
}

/// [quantity] with its unit — `12.500 kg`, `40 pcs`.
///
/// The same rule as the POS: at least the unit's decimals, and more whenever
/// the value has them. A quantity that renders as zero when it is not zero is
/// worse than an ugly one.
String formatUomQuantity(double quantity, UnitOfMeasure unit) {
  var digits = unit.digits;
  while (digits < 6 &&
      double.parse(quantity.toStringAsFixed(digits)) != quantity) {
    digits++;
  }
  return '${quantity.toStringAsFixed(digits)} ${unit.code}';
}
