// Pins the "default tax rate" feature that moved from Products → General · Tax
// (backlog item 5, 2026-08-15).
//
// Three things here are load-bearing and each has burnt us before:
//   • the switch GATES the picker. The picker's selection is deliberately kept
//     when the switch goes off, so a cart that ignored the switch would tax
//     orders on a till whose operator sees the feature as disabled;
//   • the key RENAME (`Products.DefaultTaxRateIds` → `General.DefaultTaxRateIds`)
//     must carry an existing configuration over — and must not resurrect it
//     once the operator has deliberately cleared the new key;
//   • a product's OWN tax still outranks the default.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/api/promotion_models.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/promotions/promotion_provider.dart';
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';

/// Serves a fixed settings map so the setting under test is the only variable.
class _FakeSettings extends AppSettingsNotifier {
  _FakeSettings(this._values);
  final Map<String, String> _values;

  @override
  Map<String, String> build() => {...kSettingDefaults, ..._values};
}

Tax _tax(int id, String name, double rate, {bool isEnabled = true}) => Tax(
  id: id,
  name: name,
  rate: rate,
  isFixed: false,
  isTaxOnTotal: false,
  isEnabled: isEnabled,
);

/// The company's tax book, as the cart's warm cache would hold it.
final _taxBook = [
  _tax(4, 'TVA', 20),
  _tax(7, 'Eco', 5),
  _tax(9, 'Retired', 12, isEnabled: false),
];

ProviderContainer _containerWith(Map<String, String> settings) {
  final container = ProviderContainer(
    overrides: [
      appSettingsProvider.overrideWith(() => _FakeSettings(settings)),
      allTaxesProvider.overrideWith((ref) => Stream.value(_taxBook)),
      // Keeps the real AppDatabase out of the test — the cart's promotion
      // listener would otherwise build one on disk per container.
      allPromotionsProvider.overrideWith(
        (ref) => Stream.value(const <PromotionDto>[]),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

MenuProduct _product({List<MenuTax> taxes = const []}) => MenuProduct(
  id: 8,
  name: 'Shwarma',
  price: 35,
  isTaxInclusivePrice: true,
  color: 'Transparent',
  stockQuantity: 100,
  taxes: taxes,
);

/// A cart ready to accept `addItem` (which no-ops without an active order).
///
/// Must be awaited: the cart resolves default taxes against a warm in-memory
/// `_taxesCache`, fed by a `ref.listen` on the taxes STREAM. `fireImmediately`
/// delivers `AsyncLoading` synchronously, so without letting the stream emit
/// first, every default would resolve to nothing — the test would pass for
/// entirely the wrong reason.
/// Both subscriptions are required, for different reasons: the one on
/// [cartProvider] runs its `build()` so the cart installs its own listener on
/// the taxes stream, and the one on [allTaxesProvider] pins that autoDispose
/// stream open long enough to actually emit (a bare `read` of `.future` closes
/// its temporary subscription first and the await never completes).
Future<CartNotifier> _cartFrom(ProviderContainer c) async {
  final cartSub = c.listen(cartProvider, (_, __) {});
  addTearDown(cartSub.close);
  final taxSub = c.listen(allTaxesProvider, (_, __) {});
  addTearDown(taxSub.close);

  await c.read(allTaxesProvider.future);

  final cart = c.read(cartProvider.notifier);
  cart.state = cart.state.copyWith(activePosOrderId: 0);
  return cart;
}

void main() {
  group('parseDefaultTaxRateIds', () {
    test('parses a well-formed list', () {
      expect(parseDefaultTaxRateIds('4,7'), {4, 7});
    });

    test('tolerates blanks, spaces and junk instead of throwing', () {
      // A hand-edited app_properties row must never be able to brick the till.
      expect(parseDefaultTaxRateIds(' 4 , , x, 7,'), {4, 7});
      expect(parseDefaultTaxRateIds(''), isEmpty);
      expect(parseDefaultTaxRateIds(null), isEmpty);
    });
  });

  group('default tax auto-apply is gated by the switch', () {
    test('ON + configured rates: a product with no tax gets the defaults', () async {
      final cart = await _cartFrom(
        _containerWith({
          SettingKeys.taxIncludedByDefault: 'true',
          SettingKeys.defaultTaxRateIds: '4,7',
        }),
      );

      cart.addItem(_product());

      final applied = cart.state.items.single.appliedTaxes;
      expect(applied.map((t) => t.id).toSet(), {4, 7});
      // This is what puts the blue TAX badge on the cart line.
      expect(applied, isNotEmpty);
    });

    test('OFF: the RETAINED selection is not applied', () async {
      // The regression this exists for. Turning the switch off keeps the
      // picker's selection on purpose (so turning it back on restores it), so
      // "IDs are present" alone must never be enough to tax a line.
      final cart = await _cartFrom(
        _containerWith({
          SettingKeys.taxIncludedByDefault: 'false',
          SettingKeys.defaultTaxRateIds: '4,7',
        }),
      );

      cart.addItem(_product());

      expect(cart.state.items.single.appliedTaxes, isEmpty);
    });

    test('ON with no rates configured applies nothing', () async {
      final cart = await _cartFrom(
        _containerWith({
          SettingKeys.taxIncludedByDefault: 'true',
          SettingKeys.defaultTaxRateIds: '',
        }),
      );

      cart.addItem(_product());

      expect(cart.state.items.single.appliedTaxes, isEmpty);
    });

    test('a disabled tax rate is never applied as a default', () async {
      final cart = await _cartFrom(
        _containerWith({
          SettingKeys.taxIncludedByDefault: 'true',
          SettingKeys.defaultTaxRateIds: '9',
        }),
      );

      cart.addItem(_product());

      expect(cart.state.items.single.appliedTaxes, isEmpty);
    });

    test("the product's own tax outranks the default", () async {
      final cart = await _cartFrom(
        _containerWith({
          SettingKeys.taxIncludedByDefault: 'true',
          SettingKeys.defaultTaxRateIds: '4,7',
        }),
      );

      cart.addItem(
        _product(
          taxes: [
            MenuTax(
              id: 7,
              name: 'Eco',
              rate: 5,
              isFixed: false,
              isTaxOnTotal: false,
            ),
          ],
        ),
      );

      expect(cart.state.items.single.appliedTaxes.map((t) => t.id).toSet(), {7});
    });
  });

  group('Products.DefaultTaxRateIds → General.DefaultTaxRateIds migration', () {
    /// Resolves the settings map exactly as the app would: real
    /// [AppSettingsNotifier], fed by the given app_properties rows.
    ///
    /// The listen + await is not ceremony. `rawAppPropertiesProvider` is
    /// autoDispose, so a bare `read` drops it before the stream emits ("was
    /// disposed during loading state"); holding a subscription pins it, and
    /// awaiting lets the value land in `build()` before we assert.
    Future<Map<String, String>> settingsFrom(List<AppProperty> props) async {
      final container = ProviderContainer(
        overrides: [
          rawAppPropertiesProvider.overrideWith((ref) => Stream.value(props)),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(appSettingsProvider, (_, __) {});
      addTearDown(sub.close);
      await container.read(rawAppPropertiesProvider.future);
      return container.read(appSettingsProvider);
    }

    test('carries a pre-rename configuration over to the new key', () async {
      final settings = await settingsFrom([
        AppProperty(
          id: 1,
          name: SettingKeys.legacyDefaultTaxRateIds,
          value: '4,7',
        ),
      ]);

      expect(settings[SettingKeys.defaultTaxRateIds], '4,7');
    });

    test('the new key wins when both rows exist', () async {
      final settings = await settingsFrom([
        AppProperty(
          id: 1,
          name: SettingKeys.legacyDefaultTaxRateIds,
          value: '4,7',
        ),
        AppProperty(id: 2, name: SettingKeys.defaultTaxRateIds, value: '9'),
      ]);

      expect(settings[SettingKeys.defaultTaxRateIds], '9');
    });

    test('an EMPTY new-key row is authoritative — no resurrection', () async {
      // The subtle one: once the operator has deselected every rate, the new
      // key is legitimately ''. Falling back on emptiness (rather than on the
      // row's absence) would silently bring the old default back on next boot.
      final settings = await settingsFrom([
        AppProperty(
          id: 1,
          name: SettingKeys.legacyDefaultTaxRateIds,
          value: '4,7',
        ),
        AppProperty(id: 2, name: SettingKeys.defaultTaxRateIds, value: ''),
      ]);

      expect(settings[SettingKeys.defaultTaxRateIds], '');
    });

    test('an empty legacy row leaves the default alone', () async {
      final settings = await settingsFrom([
        AppProperty(
          id: 1,
          name: SettingKeys.legacyDefaultTaxRateIds,
          value: '  ',
        ),
      ]);

      expect(settings[SettingKeys.defaultTaxRateIds], '');
    });
  });
}
