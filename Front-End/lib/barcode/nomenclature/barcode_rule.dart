/// The company's barcode nomenclature.
///
/// Mirrors `Back-End/Web-POS.Api/Domain/BarcodeRule.cs` and
/// `Services/BarcodeRuleMatcher.cs`. The POS must decode a scale label while
/// offline, so the matching logic lives on both sides rather than behind an
/// endpoint — keep the two implementations in step.
library;

/// What the value embedded in a matched barcode MEANS.
enum BarcodeRuleType {
  /// Plain product barcode — no embedded value.
  unit,

  /// Embedded value is a quantity in the product's own unit.
  weighted,

  /// Embedded value is a line TOTAL; quantity = value / unit price.
  priced,

  /// Embedded value is a percentage discount for the line.
  discounted,
}

/// Symbology the rule is restricted to. [BarcodeEncoding.any] skips length and
/// check-digit validation entirely.
enum BarcodeEncoding { any, ean13, upcA }

BarcodeRuleType _typeFromApi(String? raw) => switch (raw?.toLowerCase()) {
      'weighted' => BarcodeRuleType.weighted,
      'priced' => BarcodeRuleType.priced,
      'discounted' => BarcodeRuleType.discounted,
      _ => BarcodeRuleType.unit,
    };

String typeToApi(BarcodeRuleType type) => switch (type) {
      BarcodeRuleType.weighted => 'Weighted',
      BarcodeRuleType.priced => 'Priced',
      BarcodeRuleType.discounted => 'Discounted',
      BarcodeRuleType.unit => 'Unit',
    };

BarcodeEncoding _encodingFromApi(String? raw) => switch (raw?.toLowerCase()) {
      'ean13' => BarcodeEncoding.ean13,
      'upca' => BarcodeEncoding.upcA,
      _ => BarcodeEncoding.any,
    };

String encodingToApi(BarcodeEncoding encoding) => switch (encoding) {
      BarcodeEncoding.ean13 => 'Ean13',
      BarcodeEncoding.upcA => 'UpcA',
      BarcodeEncoding.any => 'Any',
    };

/// Human label for the encoding column.
String encodingLabel(BarcodeEncoding encoding) => switch (encoding) {
      BarcodeEncoding.ean13 => 'EAN-13',
      BarcodeEncoding.upcA => 'UPC-A',
      BarcodeEncoding.any => 'Any',
    };

/// One line of the nomenclature.
class BarcodeRule {
  final int id;
  final String name;

  /// Ascending evaluation order — first match wins.
  final int sequence;

  final BarcodeRuleType type;
  final BarcodeEncoding encoding;

  /// Prefix pattern, e.g. `22.....{NNDDD}`.
  final String pattern;

  final bool isEnabled;

  const BarcodeRule({
    required this.id,
    required this.name,
    required this.sequence,
    required this.type,
    required this.encoding,
    required this.pattern,
    this.isEnabled = true,
  });

  factory BarcodeRule.fromJson(Map<String, dynamic> json) => BarcodeRule(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        type: _typeFromApi(json['type'] as String?),
        encoding: _encodingFromApi(json['encoding'] as String?),
        pattern: json['pattern'] as String? ?? '',
        isEnabled: json['isEnabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sequence': sequence,
        'type': typeToApi(type),
        'encoding': encodingToApi(encoding),
        'pattern': pattern,
        'isEnabled': isEnabled,
      };

  BarcodeRule copyWith({
    String? name,
    int? sequence,
    BarcodeRuleType? type,
    BarcodeEncoding? encoding,
    String? pattern,
    bool? isEnabled,
  }) =>
      BarcodeRule(
        id: id,
        name: name ?? this.name,
        sequence: sequence ?? this.sequence,
        type: type ?? this.type,
        encoding: encoding ?? this.encoding,
        pattern: pattern ?? this.pattern,
        isEnabled: isEnabled ?? this.isEnabled,
      );
}

/// Outcome of matching a scanned barcode against a nomenclature.
class BarcodeMatch {
  final BarcodeRule rule;

  /// The barcode with the embedded-value digits blanked back to zeros — this is
  /// what the product's stored barcode must equal.
  final String productKey;

  /// The decoded embedded number, already scaled by its decimal positions.
  /// Zero for [BarcodeRuleType.unit] rules.
  final double value;

  const BarcodeMatch({
    required this.rule,
    required this.productKey,
    required this.value,
  });
}

/// The default nomenclature, used when the company has none yet (a fresh install
/// that has not synced, or an offline first run). Mirrors `BarcodeRuleSeeder`.
///
/// Order matters: the catch-all Unit rule must stay last, or it swallows every
/// scale label before the weighted rule is ever consulted.
const List<BarcodeRule> kDefaultBarcodeRules = [
  BarcodeRule(
      id: -1,
      name: 'Price Barcodes 2 Decimals',
      sequence: 10,
      type: BarcodeRuleType.priced,
      encoding: BarcodeEncoding.ean13,
      pattern: '25.....{NNNDD}'),
  BarcodeRule(
      id: -2,
      name: 'Weight Barcodes 3 Decimals',
      sequence: 20,
      type: BarcodeRuleType.weighted,
      encoding: BarcodeEncoding.ean13,
      pattern: '22.....{NNDDD}'),
  BarcodeRule(
      id: -3,
      name: 'Discount Barcodes',
      sequence: 30,
      type: BarcodeRuleType.discounted,
      encoding: BarcodeEncoding.any,
      pattern: '22{NN}'),
  BarcodeRule(
      id: -4,
      name: 'Product Barcodes',
      sequence: 40,
      type: BarcodeRuleType.unit,
      encoding: BarcodeEncoding.any,
      pattern: '.*'),
];
