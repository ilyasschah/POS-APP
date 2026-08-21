// Pins tax-INCLUSIVE pricing (backlog item 19 — a money bug).
//
// `Product.isTaxInclusivePrice` was stored, synced, exported and served in the
// menu payload, but no pricing code on either side ever read it: the cart did
// `taxableBase * (rate / 100)` unconditionally. So a 90 MAD product marked
// tax-inclusive at TVA 20% rang up 108 — the tax was charged a second time on
// top of a shelf price that already contained it.
//
// The invariant that matters most, and the one every test below circles:
//   an inclusive line with no discount totals EXACTLY its listed price.
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

class _FakeSettings extends AppSettingsNotifier {
  _FakeSettings(this._values);
  final Map<String, String> _values;

  @override
  Map<String, String> build() => {...kSettingDefaults, ..._values};
}

CartNotifier _cartWith(String discountApplyRule) {
  final container = ProviderContainer(
    overrides: [
      appSettingsProvider.overrideWith(
        () => _FakeSettings({SettingKeys.discountApplyRule: discountApplyRule}),
      ),
      allTaxesProvider.overrideWith((ref) => Stream.value(const <Tax>[])),
      allPromotionsProvider.overrideWith(
        (ref) => Stream.value(const <PromotionDto>[]),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(cartProvider.notifier);
}

MenuTax _tva() =>
    MenuTax(id: 4, name: 'TVA', rate: 20, isFixed: false, isTaxOnTotal: false);

CartItem _line({
  required bool inclusive,
  double price = 90,
  double quantity = 1,
  double discount = 0,
  List<MenuTax>? taxes,
}) => CartItem(
  cartItemId: 'line-1',
  posOrderId: 0,
  productId: 8,
  productName: 'Shwarma',
  price: price,
  quantity: quantity,
  discount: discount,
  discountType: 1, // fixed money
  appliedTaxes: taxes ?? [_tva()],
  isTaxInclusive: inclusive,
);

/// Rounds away float noise from dividing by 1.2 and multiplying back.
Matcher closeToMoney(double expected) => closeTo(expected, 0.000001);

void main() {
  group('the headline case — 90 MAD, TVA 20%, no discount', () {
    for (final rule in ['After tax', 'Before tax']) {
      test('inclusive totals exactly 90 under "$rule"', () {
        final cart = _cartWith(rule);
        cart.state = cart.state.copyWith(items: [_line(inclusive: true)]);
        final item = cart.state.items.single;

        // 90 / 1.2 = 75 net, so the tax is the 15 already inside the price.
        expect(cart.subtotal, closeToMoney(75));
        expect(cart.taxForItem(item), closeToMoney(15));
        // THE invariant: the customer pays the shelf price, not 108.
        expect(cart.grandTotal, closeToMoney(90));
        expect(cart.grossLineTotal(item), closeToMoney(90));
      });
    }

    test('exclusive still adds on top — 108 — and is unchanged', () {
      final cart = _cartWith('After tax');
      cart.state = cart.state.copyWith(items: [_line(inclusive: false)]);
      final item = cart.state.items.single;

      expect(cart.subtotal, closeToMoney(90));
      expect(cart.taxForItem(item), closeToMoney(18));
      expect(cart.grandTotal, closeToMoney(108));
    });
  });

  group('"12 off means 12 off" on an inclusive line, under either rule', () {
    // The rules must agree on what is PAID and may differ only on how much of
    // it is reported as tax. Netting the discount under "After tax" too would
    // have charged 80 instead of 78.
    test('After tax: tax on the full base, discount at face value', () {
      final cart = _cartWith('After tax');
      cart.state = cart.state.copyWith(
        items: [_line(inclusive: true, discount: 12)],
      );
      final item = cart.state.items.single;

      expect(cart.taxForItem(item), closeToMoney(15)); // 20% of the full 75
      expect(cart.grandTotal, closeToMoney(78)); // 90 − 12
    });

    test('Before tax: discount shrinks the base, taking its tax with it', () {
      final cart = _cartWith('Before tax');
      cart.state = cart.state.copyWith(
        items: [_line(inclusive: true, discount: 12)],
      );
      final item = cart.state.items.single;

      // Base (75 − 10) = 65 → 13. Less tax reported, same money paid.
      expect(cart.taxForItem(item), closeToMoney(13));
      expect(cart.grandTotal, closeToMoney(78));
    });
  });

  group('reconciliation and edges', () {
    test('a non-terminating split still reconciles: 100 @ 20%', () {
      final cart = _cartWith('After tax');
      cart.state = cart.state.copyWith(
        items: [_line(inclusive: true, price: 100)],
      );
      final item = cart.state.items.single;

      expect(cart.subtotal, closeToMoney(83.333333)); // 100 / 1.2
      expect(cart.taxForItem(item), closeToMoney(16.666667));
      expect(cart.grandTotal, closeToMoney(100));
    });

    test('quantity scales without breaking the identity', () {
      final cart = _cartWith('After tax');
      cart.state = cart.state.copyWith(
        items: [_line(inclusive: true, quantity: 3)],
      );
      expect(cart.grandTotal, closeToMoney(270)); // 3 × 90
    });

    test('a FIXED tax comes off the top, not divided out', () {
      final cart = _cartWith('After tax');
      final eco = MenuTax(
        id: 9,
        name: 'Eco',
        rate: 6,
        isFixed: true,
        isTaxOnTotal: false,
      );
      cart.state = cart.state.copyWith(
        items: [
          _line(inclusive: true, taxes: [_tva(), eco]),
        ],
      );
      final item = cart.state.items.single;

      // (90 − 6) / 1.2 = 70 net; taxes are 14 (TVA) + 6 (fixed) = 20.
      expect(cart.subtotal, closeToMoney(70));
      expect(cart.taxForItem(item), closeToMoney(20));
      expect(cart.grandTotal, closeToMoney(90));
    });

    test('two percentage taxes divide out by their SUM', () {
      final cart = _cartWith('After tax');
      final extra =
          MenuTax(id: 7, name: 'X', rate: 5, isFixed: false, isTaxOnTotal: false);
      cart.state = cart.state.copyWith(
        items: [
          _line(inclusive: true, price: 125, taxes: [_tva(), extra]),
        ],
      );
      final item = cart.state.items.single;

      expect(cart.subtotal, closeToMoney(100)); // 125 / 1.25
      expect(cart.taxForItem(item), closeToMoney(25)); // 20 + 5
      expect(cart.grandTotal, closeToMoney(125));
    });

    test('a line with no tax is untouched by the inclusive flag', () {
      final cart = _cartWith('After tax');
      cart.state = cart.state.copyWith(
        items: [_line(inclusive: true, taxes: const [])],
      );
      expect(cart.grandTotal, closeToMoney(90));
    });

    test('the per-tax payload still sums to the line tax', () {
      // What gets banked as DocumentItemTax rows must match what was charged.
      final cart = _cartWith('After tax');
      cart.state = cart.state.copyWith(items: [_line(inclusive: true)]);
      final item = cart.state.items.single;

      final entries = cart.taxAmountsForItem(item);
      expect(entries.single.id, 4);
      expect(
        entries.fold<double>(0, (s, t) => s + t.amount),
        closeToMoney(cart.taxForItem(item)),
      );
    });

    test('netUnitPriceFor is the ex-tax price banked as priceBeforeTax', () {
      final cart = _cartWith('After tax');
      cart.state = cart.state.copyWith(items: [_line(inclusive: true)]);
      final item = cart.state.items.single;

      // Used to bank the gross 90 into a column the backend recomputes tax on.
      expect(cart.netUnitPriceFor(item), closeToMoney(75));
    });
  });
}
