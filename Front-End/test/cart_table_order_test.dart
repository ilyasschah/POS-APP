// Pins the "starting a new table order resets the cart" invariant.
//
// The bug this guards: tapping an empty table went through `setOrderContext`,
// which is a `copyWith` because its real job is moving the CURRENT order onto a
// table. So a new table inherited the previous order's items — and its
// `existingLocalOrderId`, which made the next save rewrite the previously parked
// order's row onto the new table, moving the order and emptying the old table.
//
// It also pins the warehouse resolution: a new order must fall back to the
// configured default, never to a hardcoded id 1.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';

class _FakeSettings extends AppSettingsNotifier {
  _FakeSettings(this._values);
  final Map<String, String> _values;

  @override
  Map<String, String> build() => {...kSettingDefaults, ..._values};
}

ProviderContainer _container({String defaultWarehouseId = '17'}) {
  final container = ProviderContainer(
    overrides: [
      appSettingsProvider.overrideWith(
        () => _FakeSettings({
          SettingKeys.defaultWarehouseId: defaultWarehouseId,
        }),
      ),
      allTaxesProvider.overrideWith((ref) => Stream.value(const <Tax>[])),
      // Empty: the default-customer seed is a no-op, keeping Drift out of the
      // test. The reset behaviour under test is independent of it.
      selectableCustomersProvider.overrideWith(
        (ref) => const AsyncValue.data(<Customer>[]),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

CartItem _item() => CartItem(
  cartItemId: 'line-1',
  posOrderId: 0,
  productId: 8,
  productName: 'Shwarma',
  price: 35,
  quantity: 1,
  appliedTaxes: const [],
);

void main() {
  group('startTableOrder', () {
    test('drops the previous order entirely', () {
      final cart = _container().read(cartProvider.notifier);
      // A cart still holding the order that was just parked on table 30.
      cart.state = cart.state.copyWith(
        items: [_item()],
        existingLocalOrderId: 'the-order-parked-on-A5',
        floorPlanTableId: 30,
        orderNumber: 'ORD- A5',
        manualCartDiscount: 5,
        manualCartDiscountType: 1,
      );

      cart.startTableOrder(tableId: 31, tableName: 'A6');

      expect(cart.state.items, isEmpty);
      // The load-bearing one: carrying this over made the next save overwrite
      // A5's parked order instead of creating A6's.
      expect(cart.state.existingLocalOrderId, isNull);
      expect(cart.state.floorPlanTableId, 31);
      expect(cart.state.orderNumber, 'ORD- A6');
      expect(cart.state.manualCartDiscount, 0);
      expect(cart.grandTotal, 0);
    });

    test('a new order falls back to the configured default warehouse', () {
      // Nothing selected yet — the seed is async and legitimately unresolved.
      final cart = _container(defaultWarehouseId: '17').read(
        cartProvider.notifier,
      );
      cart.startTableOrder(tableId: 31, tableName: 'A6');

      expect(cart.state.activeWarehouseId, 17);
      expect(cart.effectiveWarehouseId, 17);
    });

    test("the previous order's warehouse never leaks into the new one", () {
      final cart = _container(defaultWarehouseId: '17').read(
        cartProvider.notifier,
      );
      cart.state = cart.state.copyWith(activeWarehouseId: 99);

      cart.startTableOrder(tableId: 31, tableName: 'A6');

      expect(cart.state.activeWarehouseId, 17);
    });
  });
}
