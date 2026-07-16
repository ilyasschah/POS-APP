// Pins the cart↔document reconciliation invariant across `discountApplyRule`.
//
// The bug this guards (doc POS1-200-000005): line tax was computed in three
// places and only the cart read the setting, so an "After tax" company banked a
// document whose own line (30 + 6) contradicted its total (37.00) by exactly
// (discount × rate). Everything must now come from `taxAmountsForItem`, so the
// invariant below — the cart total equals the sum of what the document rows
// record — holds under either rule.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';

/// Serves a fixed settings map so the rule under test is the only variable.
class _FakeSettings extends AppSettingsNotifier {
  _FakeSettings(this._values);
  final Map<String, String> _values;

  @override
  Map<String, String> build() => {...kSettingDefaults, ..._values};
}

ProviderContainer _containerFor(String discountApplyRule) {
  final container = ProviderContainer(
    overrides: [
      appSettingsProvider.overrideWith(
        () => _FakeSettings({SettingKeys.discountApplyRule: discountApplyRule}),
      ),
      // The cart only listens to this to warm its tax cache; the test builds
      // lines with explicit taxes, so an empty stream is enough.
      allTaxesProvider.overrideWith((ref) => Stream.value(const <Tax>[])),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// The real sale that exposed the bug: 35.00 with TVA 20% and a 5.00 fixed
/// item discount.
CartItem _shwarma() => CartItem(
      cartItemId: 'line-1',
      posOrderId: 0,
      productId: 8,
      productName: 'Shwarma',
      price: 35,
      quantity: 1,
      discount: 5,
      discountType: 1, // fixed money
      appliedTaxes: [
        MenuTax(
          id: 4,
          name: 'TVA',
          rate: 20,
          isFixed: false,
          isTaxOnTotal: false,
        ),
      ],
    );

void main() {
  group('discountApplyRule — cart and document line must agree', () {
    test('"After tax": tax is charged on the undiscounted price', () {
      final cart = _containerFor('After tax').read(cartProvider.notifier);
      cart.state = cart.state.copyWith(items: [_shwarma()]);
      final item = cart.state.items.single;

      // 20% of the FULL 35.00 — the discount does not shrink the tax.
      expect(cart.taxForItem(item), 7);
      // What the document line stores: 35 - 5 = 30 taxable.
      final lineTotal =
          (item.price - item.discount - item.promotionalDiscount) *
              item.quantity;
      expect(lineTotal, 30);
      // The invariant: the line reconciles to the document total.
      expect(lineTotal + cart.taxForItem(item), cart.grandTotal);
      expect(cart.grandTotal, 37);
    });

    test('"Before tax": the discount shrinks the taxable base', () {
      final cart = _containerFor('Before tax').read(cartProvider.notifier);
      cart.state = cart.state.copyWith(items: [_shwarma()]);
      final item = cart.state.items.single;

      // 20% of the DISCOUNTED 30.00.
      expect(cart.taxForItem(item), 6);
      final lineTotal =
          (item.price - item.discount - item.promotionalDiscount) *
              item.quantity;
      expect(lineTotal + cart.taxForItem(item), cart.grandTotal);
      expect(cart.grandTotal, 36);
    });

    test('the per-tax payload sums to the line tax under either rule', () {
      for (final rule in ['After tax', 'Before tax']) {
        final cart = _containerFor(rule).read(cartProvider.notifier);
        cart.state = cart.state.copyWith(items: [_shwarma()]);
        final item = cart.state.items.single;

        final entries = cart.taxAmountsForItem(item);
        expect(entries.single.id, 4, reason: 'tax id must survive: $rule');
        expect(
          entries.fold<double>(0, (s, t) => s + t.amount),
          cart.taxForItem(item),
          reason: 'server payload must match the stored amount: $rule',
        );
      }
    });
  });
}
