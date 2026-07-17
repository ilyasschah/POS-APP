// Pins the two ways promotions failed to "wake up" in the cart.
//
// 1. A CONDITIONAL line ("Buy 2, get 10% off") was applied on the first unit:
//    `_applyPromotions` matched on productId alone and never read
//    `isConditional` / `quantity`, so the condition the operator configured did
//    nothing whatsoever.
// 2. The promo list was pulled with `ref.read(activePromotionsProvider)`, whose
//    source is an autoDispose *stream*. With no listener holding it open a read
//    returns AsyncLoading → null → no promotions at all. It only ever worked
//    because the POS menu happens to watch it; reopening an order from the
//    bookings or floor-plan screen silently dropped every promotional discount.
//    The cart now keeps its own warm cache, so these tests deliberately never
//    mount a widget — that IS the regression.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/api/promotion_models.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/promotions/promotion_provider.dart';
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';

class _FakeSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {...kSettingDefaults};
}

/// A promotion on product 8. [requiredQty] > 0 makes it conditional.
PromotionDto _promo({
  required double value,
  int discountType = 0, // 0 = %, 1 = fixed
  double requiredQty = 0,
  int conditionType = 0, // 0 = Same Product — the only kind the editor offers
}) => PromotionDto(
  id: 1,
  companyId: 1,
  name: 'Buy more, save more',
  daysOfWeek: 0, // every day
  isEnabled: true,
  items: [
    PromotionItemDto(
      id: 1,
      promotionId: 1,
      productId: 8,
      discountType: discountType,
      priceType: 0,
      value: value,
      isConditional: requiredQty > 0,
      quantity: requiredQty,
      conditionType: conditionType,
      quantityLimit: 0,
    ),
  ],
);

/// Overrides the *stream* at the bottom of the chain rather than
/// `activePromotionsProvider` itself, leaving the real autoDispose plumbing —
/// and therefore the warmth bug — reachable. Overriding the derived provider
/// with a plain synchronous value hides it: the read succeeds and every test
/// passes against the broken code.
ProviderContainer _container(List<PromotionDto> promos) {
  final container = ProviderContainer(
    overrides: [
      appSettingsProvider.overrideWith(_FakeSettings.new),
      allTaxesProvider.overrideWith((ref) => Stream.value(const <Tax>[])),
      selectableCustomersProvider.overrideWith(
        (ref) => const AsyncValue.data(<Customer>[]),
      ),
      allPromotionsProvider.overrideWith((ref) => Stream.value(promos)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Builds the cart and lets the promotions stream deliver its first event, the
/// way a running app does long before anyone taps a product.
///
/// The `listen(cartProvider)` is not ceremony: a provider that is only *read*
/// doesn't maintain the `ref.listen` links its own build set up, so without it
/// the promotions stream never resolves and every test here fails for a reason
/// that has nothing to do with the code under test. In the app the cart is
/// always watched by the POS UI, so this is what production actually looks like.
Future<CartNotifier> _warmCart(List<PromotionDto> promos) async {
  final container = _container(promos);
  container.listen(cartProvider, (_, _) {});
  final cart = container.read(cartProvider.notifier);
  await Future<void>.delayed(Duration.zero);
  return cart;
}

CartItem _item({double quantity = 1}) => CartItem(
  cartItemId: 'line-1',
  posOrderId: 0,
  productId: 8,
  productName: 'Shwarma',
  price: 35,
  quantity: quantity,
  appliedTaxes: const [],
);

void main() {
  group('conditional promotions', () {
    test('does not apply below the required quantity', () async {
      final cart = await _warmCart([_promo(value: 10, requiredQty: 2)]);
      cart.state = cart.state.copyWith(items: [_item()]);

      cart.updateItemQuantity('line-1', 1);

      // The bug: this was 3.50 — the discount fired on a single unit.
      expect(cart.state.items.first.promotionalDiscount, 0);
      expect(cart.state.items.first.promotionId, isNull);
    });

    test('applies once the required quantity is reached', () async {
      final cart = await _warmCart([_promo(value: 10, requiredQty: 2)]);
      cart.state = cart.state.copyWith(items: [_item()]);

      cart.updateItemQuantity('line-1', 2);

      expect(cart.state.items.first.promotionalDiscount, 3.5); // 10% of 35
      expect(cart.state.items.first.promotionId, 1);
    });

    test('un-applies when the quantity drops back below the condition', () async {
      final cart = await _warmCart([_promo(value: 10, requiredQty: 2)]);
      cart.state = cart.state.copyWith(items: [_item(quantity: 2)]);
      cart.updateItemQuantity('line-1', 2);
      expect(cart.state.items.first.promotionalDiscount, 3.5);

      cart.decrementItem('line-1');

      expect(cart.state.items.first.promotionalDiscount, 0);
      expect(cart.state.items.first.promotionId, isNull);
    });

    test('an unconditional promotion still applies at quantity 1', () async {
      final cart = await _warmCart([_promo(value: 10)]);
      cart.state = cart.state.copyWith(items: [_item()]);

      cart.updateItemQuantity('line-1', 1);

      expect(cart.state.items.first.promotionalDiscount, 3.5);
    });

    test('an unknown condition type is left unapplied, not guessed at', () async {
      final cart = await _warmCart([
        _promo(value: 10, requiredQty: 2, conditionType: 99),
      ]);
      cart.state = cart.state.copyWith(items: [_item()]);

      cart.updateItemQuantity('line-1', 5);

      expect(cart.state.items.first.promotionalDiscount, 0);
    });
  });

  // `Order.SeparateRowForEachItem` splits every unit onto its own row, so a
  // "Buy 2" condition met by the CART is never met by any single row. The
  // condition must be evaluated against the product's total across the cart.
  group('conditional promotions with split rows', () {
    CartItem pepsi(String id) => CartItem(
      cartItemId: id,
      posOrderId: 0,
      productId: 8,
      productName: 'Pepsi',
      price: 35,
      quantity: 1,
      appliedTaxes: const [],
    );

    test('three rows of qty 1 satisfy a "Buy 2" promotion', () async {
      final cart = await _warmCart([_promo(value: 10, requiredQty: 2)]);
      cart.state = cart.state.copyWith(
        items: [pepsi('r1'), pepsi('r2'), pepsi('r3')],
      );

      cart.updateItemQuantity('r1', 1); // re-runs promo evaluation

      // The bug: each row saw quantity 1 < 2, so every row got 0.
      for (final line in cart.state.items) {
        expect(line.promotionalDiscount, 3.5);
        expect(line.promotionId, 1);
      }
    });

    test('a single split row does NOT satisfy "Buy 2"', () async {
      final cart = await _warmCart([_promo(value: 10, requiredQty: 2)]);
      cart.state = cart.state.copyWith(items: [pepsi('r1')]);

      cart.updateItemQuantity('r1', 1);

      expect(cart.state.items.single.promotionalDiscount, 0);
    });

    test('removing a row drops the cart back below the condition', () async {
      final cart = await _warmCart([_promo(value: 10, requiredQty: 2)]);
      cart.state = cart.state.copyWith(items: [pepsi('r1'), pepsi('r2')]);
      cart.updateItemQuantity('r1', 1);
      expect(cart.state.items.first.promotionalDiscount, 3.5);

      cart.removeItem('r2');

      expect(cart.state.items.single.promotionalDiscount, 0);
    });

    test('another product\'s rows do not count toward the condition', () async {
      final cart = await _warmCart([_promo(value: 10, requiredQty: 2)]);
      final fanta = CartItem(
        cartItemId: 'f1',
        posOrderId: 0,
        productId: 9, // no promotion on this one
        productName: 'Fanta',
        price: 35,
        quantity: 1,
        appliedTaxes: const [],
      );
      cart.state = cart.state.copyWith(items: [pepsi('r1'), fanta]);

      cart.updateItemQuantity('r1', 1);

      // One Pepsi + one Fanta is not "Buy 2 Pepsi".
      expect(cart.state.items.first.promotionalDiscount, 0);
      expect(cart.state.items.last.promotionalDiscount, 0);
    });
  });

  test('promotions apply with no widget watching the provider', () async {
    // The warm-cache regression: with the old `ref.read`, the autoDispose
    // stream behind activePromotionsProvider had no listener here, so the read
    // hit AsyncLoading and this came back 0.
    final cart = await _warmCart([_promo(value: 10)]);
    cart.state = cart.state.copyWith(items: [_item()]);

    cart.updateItemQuantity('line-1', 1);

    expect(cart.state.items.first.promotionalDiscount, 3.5);
  });
}
