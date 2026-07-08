import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Definition of a single column the Products grid is able to render.
///
/// [mandatory] columns are always visible and are not offered as a toggle in
/// the column picker (e.g. the product name and the edit action), so the table
/// can never end up with nothing meaningful to show.
class ProductColumnDef {
  final String key;
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
const kProductColumns = <ProductColumnDef>[
  ProductColumnDef('image', 'Image', defaultVisible: true),
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
