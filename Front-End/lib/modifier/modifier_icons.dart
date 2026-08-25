import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// The icons a modifier group may carry, chosen by hand in the admin screen.
///
/// 🚨 **Chosen, never guessed.** The obvious alternative was deriving an icon
/// from the group's NAME with a keyword map — and a keyword map only works in
/// the language it was written in. This app ships English, French and Arabic:
/// "Toppings" would match, "Garnitures" and "الإضافات" would not, and most
/// users would see the fallback on every group forever. Storing the operator's
/// choice bypasses the name entirely, so the icon is right in every language.
///
/// Deliberately SMALL. A picker with two hundred icons is a browsing task in
/// the middle of setting up a menu; eight is a glance. They are also generic on
/// purpose — a "sauce" drop covers ketchup, harissa and mayo, and nobody has to
/// find their exact product.
///
/// Stored as a stable string [ModifierIcon.key], not a codepoint: the key still
/// resolves if the icon set is swapped or a glyph renumbered, and it is legible
/// in a database dump.
class ModifierIcon {
  const ModifierIcon({
    required this.key,
    required this.regular,
    required this.fill,
  });

  /// What goes in `ModifierGroup.iconKey`. Never translated, never renumbered.
  final String key;

  final IconData regular;
  final IconData fill;
}

/// The fallback, used when a group has no icon or carries an unknown key.
///
/// Neutral on purpose: it says "this group adds something" without pretending
/// to know what. A group whose key no longer exists in the catalog lands here
/// rather than on nothing, so the catalog can shrink safely.
const ModifierIcon kModifierIconFallback = ModifierIcon(
  key: 'generic',
  regular: PhosphorIconsRegular.listPlus,
  fill: PhosphorIconsFill.listPlus,
);

/// The eight offered in the picker, in the order they appear there.
///
/// Ordered by how often a food business needs them, not alphabetically — the
/// first row of the picker should cover most menus.
const List<ModifierIcon> kModifierIcons = [
  ModifierIcon(
    key: 'burger',
    regular: PhosphorIconsRegular.hamburger,
    fill: PhosphorIconsFill.hamburger,
  ),
  ModifierIcon(
    key: 'pizza',
    regular: PhosphorIconsRegular.pizza,
    fill: PhosphorIconsFill.pizza,
  ),
  ModifierIcon(
    key: 'meal',
    regular: PhosphorIconsRegular.forkKnife,
    fill: PhosphorIconsFill.forkKnife,
  ),
  ModifierIcon(
    key: 'side',
    regular: PhosphorIconsRegular.bowlFood,
    fill: PhosphorIconsFill.bowlFood,
  ),
  ModifierIcon(
    key: 'sauce',
    regular: PhosphorIconsRegular.drop,
    fill: PhosphorIconsFill.drop,
  ),
  ModifierIcon(
    key: 'drink',
    regular: PhosphorIconsRegular.coffee,
    fill: PhosphorIconsFill.coffee,
  ),
  ModifierIcon(
    key: 'dessert',
    regular: PhosphorIconsRegular.iceCream,
    fill: PhosphorIconsFill.iceCream,
  ),
  ModifierIcon(
    key: 'spice',
    regular: PhosphorIconsRegular.fire,
    fill: PhosphorIconsFill.fire,
  ),
];

final Map<String, ModifierIcon> _byKey = {
  for (final i in kModifierIcons) i.key: i,
};

/// The icon for [key], or the fallback.
///
/// Never throws and never returns null: a group carrying a key from a newer
/// build, or from a catalog entry since removed, still has to render at the
/// till mid-sale.
ModifierIcon modifierIconFor(String? key) {
  if (key == null || key.isEmpty) return kModifierIconFallback;
  return _byKey[key] ?? kModifierIconFallback;
}

/// Whether [key] is one the picker can show as selected.
///
/// The fallback is not "selected" — it is the absence of a choice, which is why
/// the picker renders it as the clear option rather than a ninth icon.
bool isKnownModifierIcon(String? key) =>
    key != null && key.isNotEmpty && _byKey.containsKey(key);
