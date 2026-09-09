// Switching the active warehouse must work whether or not anything on screen
// happens to be watching the warehouse LIST.
//
// The bug this pins, reported from the till: with warehouse A selected, tapping
// a product stocked only in warehouse B raises the out-of-stock dialog, which
// offers "Switch". Tapping it did nothing — the POS stayed on A. Turn ON the
// POS header's warehouse button (an unrelated display setting) and the very same
// tap switched instantly.
//
// The cause was not the dialog. `setWarehouseId` resolved the Warehouse object
// through `ref.read(allWarehousesProvider)`, and that provider is `autoDispose`:
// with no widget watching it, the read gets a freshly-created provider still in
// AsyncLoading, whose `.value` is null. The old code then hit
// `if (wh != null)` and silently did nothing. The header button's `Consumer` was
// what kept the list warm, which is why an unrelated setting decided whether a
// core action worked.
//
// So these tests deliberately never watch `allWarehousesProvider` — that cold
// state IS the reproduction.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';

const int _companyId = 1;
const int _warehouseA = 10;
const int _warehouseB = 20;

class _FakeSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {...kSettingDefaults};
}

Future<void> _seedWarehouses(AppDatabase db) async {
  for (final (id, name) in [(_warehouseA, 'Warehouse A'), (_warehouseB, 'Warehouse B')]) {
    await db.into(db.warehousesTable).insert(
          WarehousesTableCompanion(
            id: Value(id),
            companyId: const Value(_companyId),
            name: Value(name),
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
  }
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
  container
      .read(selectedCompanyProvider.notifier)
      .update(Company(id: _companyId, name: 'Test'));
  return container;
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await _seedWarehouses(db);
  });
  tearDown(() => db.close());

  test('switching warehouses works with the warehouse list cold', () async {
    final container = _container(db);
    final cart = container.read(cartProvider.notifier);

    // The reproduction: nothing has watched allWarehousesProvider, so it is
    // unresolved — exactly the state the POS is in when the header's warehouse
    // button is switched off.
    expect(container.read(allWarehousesProvider).value, isNull,
        reason: 'the list must be COLD or this test proves nothing');

    cart.setWarehouseId(_warehouseB);

    // Resolved from Drift rather than from the cold provider.
    await Future<void>.delayed(Duration.zero);

    final selected = container.read(selectedWarehouseProvider);
    expect(selected, isNotNull,
        reason: 'the silent miss: the POS stayed on the old warehouse');
    expect(selected!.id, _warehouseB);
    expect(selected.name, 'Warehouse B');
  });

  test('the cart line and the visible selection agree after a switch', () async {
    final container = _container(db);
    final cart = container.read(cartProvider.notifier);

    cart.setWarehouseId(_warehouseB);
    await Future<void>.delayed(Duration.zero);

    // Two different things used to be able to disagree: the cart sourced from B
    // while every stock figure on screen was still filtered to A.
    expect(cart.state.activeWarehouseId, _warehouseB);
    expect(container.read(selectedWarehouseProvider)?.id, _warehouseB);
  });

  test('resuming an order moves the visible warehouse too', () async {
    final container = _container(db);
    final cart = container.read(cartProvider.notifier);

    // setOrderContext carried an identical copy of the same miss.
    cart.setOrderContext(77, _warehouseB, orderNumber: 'POS1-100-000077');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(selectedWarehouseProvider)?.id, _warehouseB);
    expect(cart.state.activeWarehouseId, _warehouseB);
  });

  test('a warehouse queued for deletion is never selected', () async {
    await db.into(db.warehousesTable).insert(
          WarehousesTableCompanion(
            id: const Value(99),
            companyId: const Value(_companyId),
            name: const Value('Deleted Warehouse'),
            syncStatus: const Value('pending_delete'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );

    final container = _container(db);
    container.read(cartProvider.notifier).setWarehouseId(99);
    await Future<void>.delayed(Duration.zero);

    // The picker hides these rows, so the fallback must hide them too — landing
    // on one would source stock from a warehouse the cashier cannot see.
    expect(container.read(selectedWarehouseProvider), isNull);
  });

  test('another company\'s warehouse is never selected', () async {
    await db.into(db.warehousesTable).insert(
          WarehousesTableCompanion(
            id: const Value(98),
            companyId: const Value(_companyId + 1),
            name: const Value('Other Company Warehouse'),
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );

    final container = _container(db);
    container.read(cartProvider.notifier).setWarehouseId(98);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(selectedWarehouseProvider), isNull);
  });
}
