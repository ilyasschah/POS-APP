// Modifiers reaching the cart: what they cost, and what must not merge.
//
// The whole feature rests on one invariant —
//   price == basePrice + modifierSurcharge(selectedModifiers)
// — because every consumer downstream (the tax split, the discount and
// promotion engines, CheckoutItemDto, all 36 reports) reads `price` as THE unit
// price and knows nothing about modifiers. Break the invariant and none of them
// report an error; they just quietly charge the wrong amount.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/modifier/modifier_models.dart';
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';

class _FakeSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {...kSettingDefaults};
}

/// Separate-row OFF, which is the setting that makes merging possible at all.
class _MergingSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() =>
      {...kSettingDefaults, SettingKeys.separateRowForEachItem: 'false'};
}

CartNotifier _cart({bool merging = true}) {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      appSettingsProvider.overrideWith(
          merging ? _MergingSettings.new : _FakeSettings.new),
      allTaxesProvider.overrideWith((ref) => Stream.value(const <Tax>[])),
      selectableCustomersProvider
          .overrideWith((ref) => const AsyncValue.data(<Customer>[])),
      allCustomersProvider
          .overrideWith((ref) => Stream.value(const <Customer>[])),
    ],
  );
  addTearDown(container.dispose);

  final cart = container.read(cartProvider.notifier);
  // addItem no-ops without an open order.
  cart.state = cart.state.copyWith(activePosOrderId: 1);
  return cart;
}

void main() {
  MenuProduct burger({double price = 80}) => MenuProduct(
        id: 7,
        name: 'Burger',
        price: price,
        isTaxInclusivePrice: false,
        color: '#FFFFFF',
        stockQuantity: 9999,
        taxes: const [],
      );

  const cheese =
      SelectedModifier(modifierOptionId: 1, name: 'Extra Cheese', additionalPrice: 10);
  const bun = SelectedModifier(
      modifierOptionId: 2, name: 'Gluten Free Bun', additionalPrice: 15);
  const noSugar =
      SelectedModifier(modifierOptionId: 3, name: 'No Sugar', additionalPrice: 0);
  const small =
      SelectedModifier(modifierOptionId: 4, name: 'Small', additionalPrice: -5);

  group('what a customised line costs', () {
    test('the worked example: (80 + 10 + 15) x 2 = 210', () {
      final cart = _cart();
      cart.addItem(burger(), quantity: 2, modifiers: [cheese, bun]);

      final line = cart.state.items.single;
      expect(line.price, 105);
      expect(line.basePrice, 80);
      expect(line.price * line.quantity, 210);
    });

    test('the invariant holds', () {
      final cart = _cart();
      cart.addItem(burger(), modifiers: [cheese, bun]);

      final line = cart.state.items.single;
      expect(line.price, line.basePrice + modifierSurcharge(line.selectedModifiers));
    });

    test('a free choice costs nothing but is still recorded', () {
      // "No Sugar" is a real instruction to the kitchen that happens to be free.
      final cart = _cart();
      cart.addItem(burger(), modifiers: [noSugar]);

      final line = cart.state.items.single;
      expect(line.price, 80);
      expect(line.selectedModifiers, hasLength(1));
    });

    test('a negative modifier reduces the line', () {
      final cart = _cart();
      cart.addItem(burger(), modifiers: [small]);
      expect(cart.state.items.single.price, 75);
    });

    test('no modifiers leaves basePrice equal to price', () {
      final cart = _cart();
      cart.addItem(burger());

      final line = cart.state.items.single;
      expect(line.price, 80);
      expect(line.basePrice, 80);
      expect(line.selectedModifiers, isEmpty);
    });
  });

  group('lines that must NOT merge', () {
    test('a plain burger and a cheese burger stay separate', () {
      // The reported shape of this bug class: merging on product id alone
      // collapsed them into one line at whichever price arrived first, and the
      // kitchen got a single ticket for two different sandwiches.
      final cart = _cart();
      cart.addItem(burger());
      cart.addItem(burger(), modifiers: [cheese]);

      expect(cart.state.items, hasLength(2));
      expect(cart.state.items.map((i) => i.price), [80, 90]);
    });

    test('two different customisations stay separate', () {
      final cart = _cart();
      cart.addItem(burger(), modifiers: [cheese]);
      cart.addItem(burger(), modifiers: [bun]);

      expect(cart.state.items, hasLength(2));
    });

    test('the SAME customisation merges, and adds up', () {
      final cart = _cart();
      cart.addItem(burger(), modifiers: [cheese]);
      cart.addItem(burger(), modifiers: [cheese]);

      expect(cart.state.items, hasLength(1));
      expect(cart.state.items.single.quantity, 2);
      expect(cart.state.items.single.price, 90);
    });

    test('choosing the same options in a different order still merges', () {
      // Cheese-then-bun and bun-then-cheese are the same burger.
      final cart = _cart();
      cart.addItem(burger(), modifiers: [cheese, bun]);
      cart.addItem(burger(), modifiers: [bun, cheese]);

      expect(cart.state.items, hasLength(1));
      expect(cart.state.items.single.quantity, 2);
    });
  });

  group('repricing a customised line', () {
    test('the typed price is what the line costs', () {
      // The cashier is repricing what they can SEE, which is the modified
      // price. Treating the entry as a new BASE would silently add the
      // surcharge on top and ring up more than they typed.
      final cart = _cart();
      cart.addItem(burger(), modifiers: [cheese, bun]);
      final id = cart.state.items.single.cartItemId;

      cart.updateItemPrice(id, 100);

      expect(cart.state.items.single.price, 100);
    });

    test('the invariant survives a reprice', () {
      final cart = _cart();
      cart.addItem(burger(), modifiers: [cheese, bun]);
      final id = cart.state.items.single.cartItemId;

      cart.updateItemPrice(id, 100);

      final line = cart.state.items.single;
      expect(line.basePrice, 75, reason: '100 − 25 of modifiers');
      expect(line.price, line.basePrice + modifierSurcharge(line.selectedModifiers));
    });

    test('repricing does not drop the chosen modifiers', () {
      // They still have to reach the kitchen and the receipt.
      final cart = _cart();
      cart.addItem(burger(), modifiers: [cheese, bun]);
      final id = cart.state.items.single.cartItemId;

      cart.updateItemPrice(id, 100);

      expect(cart.state.items.single.selectedModifiers, hasLength(2));
    });
  });

  group('re-choosing modifiers on a line already in the cart', () {
    test('the price recomputes from the base, not from the last answer', () {
      // Recomputing from `price` would compound: 80 → 90 → 100 for the same
      // single 10 MAD choice.
      final cart = _cart();
      cart.addItem(burger(), modifiers: [cheese]);
      final id = cart.state.items.single.cartItemId;

      cart.setItemModifiers(id, [cheese]);
      expect(cart.state.items.single.price, 90);

      cart.setItemModifiers(id, [cheese]);
      expect(cart.state.items.single.price, 90);
    });

    test('swapping choices reprices correctly', () {
      final cart = _cart();
      cart.addItem(burger(), modifiers: [cheese]);
      final id = cart.state.items.single.cartItemId;

      cart.setItemModifiers(id, [bun]);

      expect(cart.state.items.single.price, 95);
      expect(cart.state.items.single.selectedModifiers.single.name,
          'Gluten Free Bun');
    });

    test('clearing every choice returns the line to its base price', () {
      final cart = _cart();
      cart.addItem(burger(), modifiers: [cheese, bun]);
      final id = cart.state.items.single.cartItemId;

      cart.setItemModifiers(id, const []);

      expect(cart.state.items.single.price, 80);
      expect(cart.state.items.single.selectedModifiers, isEmpty);
    });

    test('a free-text note lands on the line comment', () {
      // AllowsFreeText writes into the order line's existing column rather
      // than inventing a second one.
      final cart = _cart();
      cart.addItem(burger(), modifiers: [cheese]);
      final id = cart.state.items.single.cartItemId;

      cart.setItemModifiers(id, [cheese], comment: 'no ice');

      expect(cart.state.items.single.comment, 'no ice');
    });

    test('an unknown line changes nothing', () {
      final cart = _cart();
      cart.addItem(burger(), modifiers: [cheese]);

      cart.setItemModifiers('does-not-exist', const []);

      expect(cart.state.items.single.price, 90);
    });
  });

  group('the line carries its choices to the server', () {
    test('toJson includes the modifier snapshots', () {
      final cart = _cart();
      cart.addItem(burger(), modifiers: [cheese, bun]);

      final json = cart.state.items.single.toJson();
      final mods = json['modifiers'] as List;

      expect(mods, hasLength(2));
      expect((mods.first as Map)['name'], 'Extra Cheese');
      expect((mods.first as Map)['additionalPrice'], 10);
    });
  });
}
