// Pins that a service status picked from the POS header STICKS.
//
// Reported from production: changing an order from 1 to 2 with the header's
// status button always came back as 1, while the KDS's "ready" (3) landed
// instantly. Three separate leaks, each enough on its own:
//
//   • the button only changed the in-memory cart. The floor plan and the KDS
//     read the Drift ROW, and walking away without Save discarded it. The KDS
//     writes the row directly (`PosKitchenServer._markReady`) — hence "instant".
//   • even after a save, the 10s open-order poll wrote the server's stale 1
//     over the 'pending' row before the push could send the 2.
//   • on an empty cart, the first product tap ran `startTablelessOrder`, which
//     rebuilt the cart with a hardcoded 1.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/menu/open_orders_screen.dart';
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';

class _FakeSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {...kSettingDefaults};
}

/// Stands in for the server during the open-order poll. Reports the order at
/// the status the server last heard — 1, the value before the header change.
class _StaleServer extends ApiClient {
  @override
  Future<List<dynamic>> getAllPosOrders(int companyId) async => [
        {
          'id': 77,
          'number': 'ORD- T4',
          'userId': 1,
          'floorPlanTableId': null,
          'serviceType': 0,
          'serviceStatus': 1,
          'total': 35.0,
          'warehouseId': 17,
        },
      ];

  @override
  Future<List<dynamic>> getOrderItems(int companyId, int posOrderId) async =>
      const [];
}

ProviderContainer _container(AppDatabase db) {
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      appSettingsProvider.overrideWith(_FakeSettings.new),
      allTaxesProvider.overrideWith((ref) => Stream.value(const <Tax>[])),
      selectableCustomersProvider.overrideWith(
        (ref) => const AsyncValue.data(<Customer>[]),
      ),
      allCustomersProvider.overrideWith(
        (ref) => Stream.value(const <Customer>[]),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// An order parked at status 1 and already pushed — the row a cashier reopens
/// from its table before changing the status.
Future<String> _parkSyncedOrder(AppDatabase db) async {
  const localId = 'the-parked-order';
  await db.saveOpenOrder(
    PosOrdersTableCompanion(
      localId: const Value(localId),
      serverId: const Value(77),
      companyId: const Value(1),
      userId: const Value(1),
      serviceType: const Value(0),
      serviceStatus: const Value(1),
      orderName: const Value('ORD- T4'),
      openedAt: Value(DateTime.now().toUtc()),
      status: const Value(0),
      total: const Value(35),
      warehouseId: const Value(17),
      syncStatus: const Value('synced'),
      lastModified: Value(DateTime.now().toUtc()),
    ),
    [
      const PosOrderItemsTableCompanion(
        localId: Value('item-1'),
        orderId: Value(localId),
        productId: Value(8),
        quantity: Value(1),
        unitPrice: Value(35),
        warehouseId: Value(17),
      ),
    ],
  );
  return localId;
}

final _pepsi = MenuProduct(
  id: 8,
  name: 'Pepsi',
  price: 35,
  isTaxInclusivePrice: false,
  color: '#FFFFFF',
  stockQuantity: 100,
  taxes: const [],
);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<PosOrdersTableData> row(String localId) =>
      (db.select(db.posOrdersTable)..where((t) => t.localId.equals(localId)))
          .getSingle();

  test('picking a status on a parked order writes it through to the row',
      () async {
    final localId = await _parkSyncedOrder(db);
    final cart = _container(db).read(cartProvider.notifier);
    await cart.loadOrderFromLocal(localId);

    await cart.setServiceStatus(2);

    // No Save pressed. The floor plan and the KDS read this row, not the cart.
    final saved = await row(localId);
    expect(saved.serviceStatus, 2);
    expect(saved.syncStatus, 'pending', reason: 'the push must carry it up');
    expect(cart.state.serviceStatus, 2);
  });

  test('the open-order poll does not revert a status picked from the header',
      () async {
    final localId = await _parkSyncedOrder(db);
    final cart = _container(db).read(cartProvider.notifier);
    await cart.loadOrderFromLocal(localId);
    await cart.setServiceStatus(2);

    // The poll lands before the push — the server still says 1.
    await syncOpenOrdersToDrift(db, 1,
        fallbackWarehouseId: 17, api: _StaleServer());

    // The reported bug end to end: this came back as 1.
    expect((await row(localId)).serviceStatus, 2);
  });

  test('a status picked on an empty cart survives the first product tap',
      () async {
    final cart = _container(db).read(cartProvider.notifier);

    await cart.setServiceStatus(2);

    // ── menu_screen's product-tap handler, verbatim in spirit ──
    if (cart.state.activePosOrderId == null) {
      await cart.startTablelessOrder(ApiClient(), 1, 1, 0);
    }
    expect(cart.state.serviceStatus, 2, reason: 'was reset to a hardcoded 1');

    cart.addItem(_pepsi);
    await cart.saveOrderLocally(companyId: 1, userId: 1);
    expect((await db.select(db.posOrdersTable).get()).single.serviceStatus, 2);
  });

  test('the next order after a clear still starts at 1', () async {
    final cart = _container(db).read(cartProvider.notifier);

    // The previous order ended ready; keeping the status must not leak it.
    await cart.setServiceStatus(3);
    cart.clearCart();
    await cart.startTablelessOrder(ApiClient(), 1, 1, 0);

    expect(cart.state.serviceStatus, 1);
  });
}
