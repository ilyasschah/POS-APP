import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_app/l10n/app_localizations.dart';

/// Definition of a single column the Products grid is able to render.
///
/// [mandatory] columns are always visible and are not offered as a toggle in
/// the column picker (e.g. the product name and the edit action), so the table
/// can never end up with nothing meaningful to show.
class ProductColumnDef {
  final String key;

  /// English fallback only — **not** what the grid renders. The visible text
  /// comes from [productColumnLabel]; see the note on [kProductColumns].
  final String label;
  final bool defaultVisible;
  final bool mandatory;
  final bool numeric;

  const ProductColumnDef(
    this.key,
    this.label, {
    this.defaultVisible = false,
    this.mandatory = false,
    this.numeric = false,
  });
}

/// The full, ordered catalogue of columns the grid can display. Every product
/// field surfaced here is read straight from the local (offline-first) Drift
/// row — no network call is involved in deciding what to show.
///
/// 🚨 [ProductColumnDef.key] is the column's **identity**: it gates rendering
/// and is the JSON key persisted to SharedPreferences, so it must never be
/// translated. `label` is a `const` English fallback — the grid and the picker
/// both render [productColumnLabel] instead, because a `const` list cannot
/// reach `AppLocalizations` (that needs a BuildContext).
const kProductColumns = <ProductColumnDef>[
  ProductColumnDef('image', 'Image', defaultVisible: true),
  ProductColumnDef('color', 'Color'),
  ProductColumnDef('code', 'Code', defaultVisible: true),
  ProductColumnDef('name', 'Name', defaultVisible: true, mandatory: true),
  ProductColumnDef('category', 'Category', defaultVisible: true),
  ProductColumnDef('price', 'Price', defaultVisible: true, numeric: true),
  ProductColumnDef('cost', 'Cost', defaultVisible: true, numeric: true),
  ProductColumnDef('plu', 'PLU', numeric: true),
  ProductColumnDef('unit', 'Unit'),
  ProductColumnDef('markup', 'Markup %', numeric: true),
  ProductColumnDef('lastPurchase', 'Last Purchase', numeric: true),
  ProductColumnDef('ageRestriction', 'Age Restriction', numeric: true),
  ProductColumnDef('rank', 'Rank', numeric: true),
  ProductColumnDef('taxInclusive', 'Tax Inclusive'),
  ProductColumnDef('service', 'Service'),
  ProductColumnDef('priceChange', 'Price Change'),
  ProductColumnDef('enabled', 'Enabled'),
  ProductColumnDef('description', 'Description'),
  ProductColumnDef('created', 'Created'),
  ProductColumnDef('updated', 'Updated'),
  ProductColumnDef('actions', 'Edit', defaultVisible: true, mandatory: true),
];

/// Localized header for a [ProductColumnDef.key]. Falls back to the `const`
/// English `label` for any key without a translation, so a column added later
/// still renders something rather than a blank cell.
String productColumnLabel(BuildContext context, String key) {
  final l = AppLocalizations.of(context);
  return switch (key) {
    'image' => l.colImage,
    'color' => l.setColor,
    'code' => l.fieldCode,
    'name' => l.fieldName,
    'category' => l.categoryLabel,
    'price' => l.fieldPrice,
    'cost' => l.fieldCost,
    'plu' => l.plu,
    'unit' => l.fieldUnit,
    'markup' => l.markupPercent,
    'lastPurchase' => l.lastPurchase,
    'ageRestriction' => l.ageRestriction,
    'rank' => l.fieldRank,
    'taxInclusive' => l.taxInclusive,
    'service' => l.serviceTag,
    'priceChange' => l.priceChange,
    'enabled' => l.fieldEnabled,
    'description' => l.fieldDescription,
    'created' => l.created,
    'updated' => l.updatedLabel,
    'actions' => l.actionEdit,
    _ => kProductColumns
        .firstWhere(
          (c) => c.key == key,
          orElse: () => const ProductColumnDef('', ''),
        )
        .label,
  };
}

const _kPrefsKey = 'products.visibleColumns';

/// Visible-column preferences for the Products grid, persisted on-device with
/// SharedPreferences so the choice survives restarts and works fully offline.
/// The map is keyed by [ProductColumnDef.key]; mandatory columns are always
/// forced to `true`.
final productVisibleColumnsProvider =
    NotifierProvider<ProductVisibleColumnsNotifier, Map<String, bool>>(
  ProductVisibleColumnsNotifier.new,
);

class ProductVisibleColumnsNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    // Seed synchronously with defaults so the grid renders immediately, then
    // hydrate from disk once SharedPreferences resolves.
    _load();
    return _defaults();
  }

  Map<String, bool> _defaults() => {
        for (final c in kProductColumns) c.key: c.defaultVisible || c.mandatory,
      };

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null || raw.isEmpty) return;
    final merged = _merge(raw);
    if (merged != null) state = merged;
  }

  /// Merge a persisted JSON blob over the defaults. New columns added in later
  /// app versions fall back to their default visibility; mandatory columns stay
  /// on regardless of what was stored.
  Map<String, bool>? _merge(String raw) {
    try {
      final stored = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final result = _defaults();
      for (final c in kProductColumns) {
        if (c.mandatory) continue;
        if (stored.containsKey(c.key)) result[c.key] = stored[c.key] == true;
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> setVisible(String key, bool value) async {
    final col = kProductColumns.firstWhere(
      (c) => c.key == key,
      orElse: () => const ProductColumnDef('', ''),
    );
    if (col.key.isEmpty || col.mandatory) return;

    state = {...state, key: value};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(state));
  }

  /// Restore the out-of-the-box column selection.
  Future<void> resetToDefaults() async {
    state = _defaults();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(state));
  }
}
