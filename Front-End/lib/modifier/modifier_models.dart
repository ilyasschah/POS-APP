/// Modifiers — the structured successor to free-text product comments.
///
/// A verbatim mirror of `Back-End/Web-POS.Api/Domain/ModifierGroup.cs` and
/// `ModifierOption.cs`. The two sides price a line independently (the till does
/// it offline, the server re-derives it on checkout), so a divergence here is a
/// receipt that disagrees with the database.
library;

// `reorderedForDrag` used to live here. It moved to core when the column picker
// needed the same off-by-one correction; re-exported so the modifier code that
// has always called it through this library still can.
export 'package:pos_app/core/reorder.dart' show reorderedForDrag;

import 'package:pos_app/database/app_database.dart';

/// A named set of choices offered on a product — "Toppings", "Doneness".
class ModifierGroup {
  final int id;
  final String name;

  /// Fewest options that must be chosen. 0 = optional.
  final int minSelections;

  /// Most that may be chosen. 1 renders as radios, more as checkboxes.
  final int maxSelections;

  /// Whether this group also takes a free-text note. See
  /// `ModifierGroup.AllowsFreeText` for why this lives on a group rather than
  /// being a second feature beside modifiers.
  final bool allowsFreeText;

  /// Stable key into the icon catalog; null draws the fallback. Chosen by the
  /// operator rather than guessed from [name], so it is right in every language.
  final String? iconKey;

  final int rank;
  final bool isEnabled;

  /// The group's choices, rank-ordered. Empty when loaded as a bare row.
  final List<ModifierOption> options;

  const ModifierGroup({
    required this.id,
    required this.name,
    this.minSelections = 0,
    this.maxSelections = 1,
    this.allowsFreeText = false,
    this.iconKey,
    this.rank = 0,
    this.isEnabled = true,
    this.options = const [],
  });

  /// True when the cashier must choose something before the item can be added.
  bool get isMandatory => minSelections > 0;

  /// True when the group is a pick-one — the single thing that decides whether
  /// the sheet draws radios or checkboxes.
  bool get isSingleChoice => maxSelections <= 1;

  ModifierGroup withOptions(List<ModifierOption> next) => ModifierGroup(
        id: id,
        name: name,
        minSelections: minSelections,
        maxSelections: maxSelections,
        allowsFreeText: allowsFreeText,
        iconKey: iconKey,
        rank: rank,
        isEnabled: isEnabled,
        options: next,
      );

  factory ModifierGroup.fromJson(Map<String, dynamic> json) => ModifierGroup(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        minSelections: (json['minSelections'] as num?)?.toInt() ?? 0,
        maxSelections: (json['maxSelections'] as num?)?.toInt() ?? 1,
        allowsFreeText: json['allowsFreeText'] as bool? ?? false,
        iconKey: json['iconKey'] as String?,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        isEnabled: json['isEnabled'] as bool? ?? true,
        options: (json['options'] as List?)
                ?.map((o) => ModifierOption.fromJson(o as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  factory ModifierGroup.fromDrift(ModifierGroupsTableData row) => ModifierGroup(
        id: row.id,
        name: row.name,
        minSelections: row.minSelections,
        maxSelections: row.maxSelections,
        allowsFreeText: row.allowsFreeText,
        iconKey: row.iconKey,
        rank: row.rank,
        isEnabled: row.isEnabled,
      );
}

/// One choice inside a [ModifierGroup], with the money it adds.
class ModifierOption {
  final int id;
  final int modifierGroupId;
  final String name;

  /// Added to the product's unit price when chosen. 0 is ordinary ("No Sugar"
  /// is a real kitchen instruction that happens to be free), and negative is
  /// legitimate (a "small size" reduction).
  final double additionalPrice;

  final int rank;
  final bool isEnabled;

  const ModifierOption({
    required this.id,
    required this.modifierGroupId,
    required this.name,
    this.additionalPrice = 0,
    this.rank = 0,
    this.isEnabled = true,
  });

  factory ModifierOption.fromJson(Map<String, dynamic> json) => ModifierOption(
        id: (json['id'] as num?)?.toInt() ?? 0,
        modifierGroupId: (json['modifierGroupId'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        additionalPrice: (json['additionalPrice'] as num?)?.toDouble() ?? 0,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        isEnabled: json['isEnabled'] as bool? ?? true,
      );

  factory ModifierOption.fromDrift(ModifierOptionsTableData row) =>
      ModifierOption(
        id: row.id,
        modifierGroupId: row.modifierGroupId,
        name: row.name,
        additionalPrice: row.additionalPrice,
        rank: row.rank,
        isEnabled: row.isEnabled,
      );

  /// The snapshot this option becomes once it is chosen on a line.
  SelectedModifier toSelection({String? groupName}) => SelectedModifier(
        modifierOptionId: id,
        groupName: groupName,
        name: name,
        additionalPrice: additionalPrice,
        rank: rank,
      );
}

/// One modifier as CHOSEN on a cart line — a snapshot, never a reference.
///
/// 🚨 [name] and [additionalPrice] are copied off the catalogue option at the
/// moment of sale and never read back. Renaming "Extra Cheese" to "Double
/// Cheese", repricing it, or deleting it must not reach backwards and change
/// what a parked order or a reprinted receipt says it sold — the same rule
/// `CartItem.isTaxInclusive` already follows.
///
/// [modifierOptionId] is nullable because a deleted option leaves a line that
/// still reads perfectly: the id is for reporting, the snapshot is the record.
class SelectedModifier {
  final int? modifierOptionId;

  /// The group this came from, kept so a receipt can print "Sauce: Garlic"
  /// without a catalogue lookup that might no longer resolve.
  final String? groupName;

  final String name;
  final double additionalPrice;
  final int rank;

  const SelectedModifier({
    this.modifierOptionId,
    this.groupName,
    required this.name,
    this.additionalPrice = 0,
    this.rank = 0,
  });

  factory SelectedModifier.fromJson(Map<String, dynamic> json) =>
      SelectedModifier(
        modifierOptionId: (json['modifierOptionId'] as num?)?.toInt(),
        groupName: json['groupName'] as String?,
        name: json['name'] as String? ?? '',
        additionalPrice: (json['additionalPrice'] as num?)?.toDouble() ?? 0,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'modifierOptionId': modifierOptionId,
        'ModifierOptionId': modifierOptionId,
        'groupName': groupName,
        'GroupName': groupName,
        'name': name,
        'Name': name,
        'additionalPrice': additionalPrice,
        'AdditionalPrice': additionalPrice,
        'rank': rank,
        'Rank': rank,
      };

  /// Identity for comparing two lines' selections — see [modifierSelectionKey].
  /// Falls back to the NAME when the option id is null, so two legacy lines
  /// carrying the same deleted option still compare equal.
  String get _identity => modifierOptionId?.toString() ?? 'name:$name';
}

/// What the chosen modifiers add to one unit of the product.
///
/// 🚨 This is added into `CartItem.price` at add time, NOT kept beside it. Every
/// consumer downstream — `lineTaxBasis`, the discount and promotion engines,
/// `CheckoutItemDto`, all 36 reports — reads `price` as the unit price, so
/// folding the surcharge in is what lets modifiers exist without touching any
/// of them. The corollary matters just as much: the per-line snapshot rows are
/// for DISPLAY and reporting only, and re-adding them to a total would charge
/// every modifier twice.
double modifierSurcharge(Iterable<SelectedModifier> selected) =>
    selected.fold<double>(0, (sum, m) => sum + m.additionalPrice);

/// A stable identity for a set of chosen modifiers.
///
/// 🚨 This is what stops two differently-customised lines merging. With
/// `Order.SeparateRowForEachItem` OFF, `addItem` merges by product id alone —
/// so a plain burger and a burger with extra cheese collapsed into one line at
/// whichever price arrived first, and the kitchen got one ticket. Order-
/// independent (sorted) so choosing cheese-then-bacon matches bacon-then-cheese.
String modifierSelectionKey(Iterable<SelectedModifier> selected) {
  final ids = selected.map((m) => m._identity).toList()..sort();
  return ids.join('|');
}

/// Rebuilds a line's chosen modifiers from its stored snapshot rows.
List<SelectedModifier> selectedModifiersFromRows(
  List<PosOrderItemModifiersTableData> rows,
) =>
    [
      for (final r in rows)
        SelectedModifier(
          modifierOptionId: r.modifierOptionId,
          groupName: r.groupName,
          name: r.name,
          additionalPrice: r.additionalPrice,
          rank: r.rank,
        ),
    ];

/// Composes what `AppDatabase.modifierGroupsForProductDirect` returns into the
/// models the customise sheet takes.
///
/// Kept beside the models rather than in the database layer so that layer stays
/// free of them.
List<ModifierGroup> modifierGroupsFromRows(
  List<({ModifierGroupsTableData group, List<ModifierOptionsTableData> options})>
      rows,
) =>
    [
      for (final row in rows)
        ModifierGroup.fromDrift(row.group)
            .withOptions(row.options.map(ModifierOption.fromDrift).toList()),
    ];

/// Whether a group's current selection satisfies its own rules.
///
/// Returns null when the group is satisfied, or the reason it is not. The POS
/// uses the reason to highlight the offending section rather than just greying
/// out the confirm button with no explanation — a cashier who cannot see WHICH
/// group is blocking them is stuck.
String? modifierGroupViolation(ModifierGroup group, int chosenCount) {
  if (chosenCount < group.minSelections) return 'min';
  if (chosenCount > group.maxSelections) return 'max';
  return null;
}
