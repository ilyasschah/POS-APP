import 'package:flutter/widgets.dart';

import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/product/product_model.dart';

/// The four product-search scopes, shared by the POS menu and the Products
/// management screen.
///
/// 🚨 These strings are **stored values**, not screen text: `Menu.DefaultSearch`
/// persists one of them verbatim (see `SettingKeys.defaultSearch` and the
/// dropdown in Settings → Order & Payment · Items). Translating them would
/// change what is written to `app_properties` and break every terminal that
/// already holds the English value. Localize with [productSearchScopeLabel].
abstract final class ProductSearchScope {
  static const String name = 'Name';
  static const String code = 'Code';
  static const String barcode = 'Barcode';
  static const String allFields = 'All fields';

  /// Display order for the scope buttons — widest match first, so the option
  /// that "just finds it" is the leftmost.
  static const List<String> all = [allFields, barcode, code, name];
}

/// Localized label for a scope, for tooltips and accessibility. Mirrors the
/// Settings dropdown, which localizes the same four values the same way.
String productSearchScopeLabel(BuildContext context, String scope) {
  final l = AppLocalizations.of(context);
  switch (scope) {
    case ProductSearchScope.code:
      return l.fieldCode;
    case ProductSearchScope.barcode:
      return l.barcode;
    case ProductSearchScope.allFields:
      return l.allFields;
    case ProductSearchScope.name:
    default:
      return l.fieldName;
  }
}

/// Whether [product] matches [query] under [scope]. Case-insensitive substring
/// match; an empty (or whitespace-only) query matches everything.
///
/// 🚨 Deliberately does NOT filter on `isEnabled`. That is a caller's policy,
/// and the two callers disagree for good reason: the POS menu must never offer
/// a disabled product for sale, while the Products management screen exists
/// precisely to find and re-enable one (it renders them struck through). Baking
/// the POS's rule in here would silently hide disabled products from the admin.
///
/// [extraBarcodes] are additional barcode values for this product beyond
/// `Product.barcodes` — which only ever holds the single `products.barcode`
/// column. Secondary barcodes live in their own `barcodes` table, so the
/// Products screen passes them in (that screen is where they are entered, and
/// searching for one there returning nothing would read as broken). The POS
/// menu passes nothing and keeps its existing behaviour.
bool productMatchesSearch(
  Product product,
  String query,
  String scope, {
  Iterable<String> extraBarcodes = const [],
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;

  bool matchesName() => product.name.toLowerCase().contains(q);
  bool matchesCode() => product.code?.toLowerCase().contains(q) ?? false;
  bool matchesBarcode() =>
      product.barcodes.any((b) => b.toLowerCase().contains(q)) ||
      extraBarcodes.any((b) => b.toLowerCase().contains(q));

  switch (scope) {
    case ProductSearchScope.code:
      return matchesCode();
    case ProductSearchScope.barcode:
      return matchesBarcode();
    case ProductSearchScope.allFields:
      return matchesName() || matchesCode() || matchesBarcode();
    case ProductSearchScope.name:
    default:
      // Unknown scope falls back to Name, matching the POS menu's original
      // `default:` arm — a setting holding a stale value must not blank the
      // list, it must behave like the most ordinary search there is.
      return matchesName();
  }
}

/// True when [value] is EXACTLY one of this product's barcodes, in either
/// store. Case-insensitive, blanks trimmed. Used by the scan path, where a
/// substring match would ring up the wrong product.
bool productHasBarcode(
  Product product,
  String value, {
  Iterable<String> extraBarcodes = const [],
}) {
  final needle = value.trim().toLowerCase();
  if (needle.isEmpty) return false;
  bool eq(String b) => b.trim().toLowerCase() == needle;
  return product.barcodes.any(eq) || extraBarcodes.any(eq);
}

/// The product a scanned barcode refers to, or null.
///
/// Searches the primary `products.barcode` across the whole list FIRST, then
/// the secondary `barcodes` table. That precedence is the tie-break for the one
/// ambiguous case — two products carrying the same barcode, which nothing in
/// either database prevents. The old code took whichever product happened to
/// come first out of Drift; this is at least deterministic, and it keeps the
/// product whose *main* barcode was scanned winning over one that lists it as
/// an alternate.
///
/// [products] is expected to be pre-filtered by the caller (the till passes
/// enabled products only) — same division of responsibility as
/// [productMatchesSearch].
Product? findProductByBarcode(
  Iterable<Product> products,
  String value, {
  Map<int, List<String>> extraBarcodes = const {},
}) {
  if (value.trim().isEmpty) return null;
  Product? secondary;
  for (final p in products) {
    if (productHasBarcode(p, value)) return p;
    secondary ??= productHasBarcode(p, value,
            extraBarcodes: extraBarcodes[p.id] ?? const [])
        ? p
        : null;
  }
  return secondary;
}
