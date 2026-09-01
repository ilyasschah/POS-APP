import 'package:pos_app/product/product_model.dart';

/// Sorts [products] in place by `Products.Sorting` (see
/// `SettingKeys.productSorting`), shared by the POS menu grid and the
/// Products management table so both respect the same setting.
///
/// 🚨 [sortBy] is a **stored value**, not screen text — it comes straight out
/// of `app_properties` (seeded as `"Code"`; the Settings dropdown writes
/// `"Code"`, `"Barcode"` or `"Name"` verbatim). Anything else falls back to
/// sorting by name.
void sortProductsBy(List<Product> products, String sortBy) {
  if (sortBy == 'Code') {
    products.sort((a, b) => (a.code ?? '').compareTo(b.code ?? ''));
  } else if (sortBy == 'Barcode') {
    products.sort(
      (a, b) => (a.barcodes.firstOrNull ?? '').compareTo(
        b.barcodes.firstOrNull ?? '',
      ),
    );
  } else {
    products.sort((a, b) => a.name.compareTo(b.name));
  }
}
