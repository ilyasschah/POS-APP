// Reopening a parked order has to restore each line's UNIT.
//
// A `pos_order_items` row stores a bare number — 100 — and nothing about what
// it counts. The unit belongs to the product, so a rebuilt line has to read it
// back out of the catalogue. It did not, and so every reopened line silently
// became `pcs`: a parked 100 g of saffron came back reading `x100` instead of
// `100 g`, and from that point every unit decision downstream — the stock
// deduction, the out-of-stock guard, the receipt, the Amount key — was working
// in the wrong unit on an order that had been perfectly correct when it was
// saved. The line's own money never moved, which is exactly what made it hard
// to see: the total still said 3000.00.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

class _FakeSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {...kSettingDefaults};
}

CartNotifier _cart(AppDatabase db) {
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
  return container.read(cartProvider.notifier);
}

void main() {
  late AppDatabase db;

  const orderLocalId = 'the-parked-saffron-order';
  const saffronId = 10002;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Saffron: priced 30 MAD per GRAM, sold by weight, stock held in kg.
  Future<void> seedSaffron({
    int uomId = kUomGram,
    bool isToWeigh = true,
    String? measurementUnit,
  }) async {
    await db.into(db.productsTable).insert(
          ProductsTableCompanion.insert(
            id: const Value(saffronId),
            companyId: 1,
            name: 'Saffron',
            price: const Value(30),
            uomId: Value(uomId),
            isToWeigh: Value(isToWeigh),
            measurementUnit: Value(measurementUnit),
            lastModified: DateTime.now().toUtc(),
          ),
        );
  }

  /// One parked line: 100 of them, at 30 each.
  Future<void> parkOrder() async {
    await db.saveOpenOrder(
      PosOrdersTableCompanion(
        localId: const Value(orderLocalId),
        serverId: const Value(null),
        companyId: const Value(1),
        userId: const Value(1),
        serviceType: const Value(0),
        serviceStatus: const Value(1),
        orderName: const Value('ORDER #005'),
        openedAt: Value(DateTime.now().toUtc()),
        status: const Value(0),
        total: const Value(3000),
        warehouseId: const Value(1),
        lastModified: Value(DateTime.now().toUtc()),
      ),
      [
        const PosOrderItemsTableCompanion(
          localId: Value('line-1'),
          orderId: Value(orderLocalId),
          productId: Value(saffronId),
          quantity: Value(100),
          unitPrice: Value(30),
          warehouseId: Value(1),
        ),
      ],
    );
  }

  group('a reopened weighed line knows what it counts', () {
    test('the unit comes back as grams, not pieces', () async {
      await seedSaffron();
      await parkOrder();
      final cart = _cart(db);

      expect(await cart.loadOrderFromLocal(orderLocalId), isTrue);

      final line = cart.state.items.single;
      expect(line.uomId, kUomGram,
          reason: 'pcs here is what rendered the line as "x100"');
      expect(formatQuantity(line.quantity, line.uomId), '100 g');
    });

    test('the sell-by-weight flag comes back too', () async {
      // It is what turns the keypad's price key into the Amount key, so losing
      // it on reopen quietly takes the feature away from a parked order.
      await seedSaffron();
      await parkOrder();
      final cart = _cart(db);
      await cart.loadOrderFromLocal(orderLocalId);

      expect(cart.state.items.single.isToWeigh, isTrue);
    });

    test('the money is unchanged — only the unit was ever wrong', () async {
      await seedSaffron();
      await parkOrder();
      final cart = _cart(db);
      await cart.loadOrderFromLocal(orderLocalId);

      final line = cart.state.items.single;
      expect(line.quantity, 100);
      expect(line.price, 30);
      expect(line.quantity * line.price, 3000);
    });

    test('the restored line deducts kilograms, not kilos-worth of grams',
        () async {
      // End-to-end: the unit is only worth restoring because the stock ledger
      // reads it. 100 g off a 0.500 kg shelf leaves 0.400 kg.
      await seedSaffron();
      await parkOrder();
      await db.into(db.stocksTable).insert(
            StocksTableCompanion.insert(
              id: const Value(1),
              productId: saffronId,
              warehouseId: 1,
              companyId: 1,
              quantity: const Value(0.500),
              lastModified: DateTime.now().toUtc(),
            ),
          );

      final cart = _cart(db);
      await cart.loadOrderFromLocal(orderLocalId);
      final line = cart.state.items.single;

      await db.deductStockForCheckout(
        items: [
          (
            productId: line.productId,
            quantity: line.quantity,
            uomId: line.uomId,
            warehouseId: 1,
            isService: line.isService,
            productName: line.productName,
          )
        ],
        allowNegative: true,
      );

      final stock = await db.select(db.stocksTable).getSingle();
      expect(stock.quantity, 0.400);
    });
  });

  group('the fallbacks', () {
    test('a product missing from the local catalogue stays pieces', () async {
      // Nothing to read the unit off. Pieces converts 1:1, so an unknown
      // product behaves exactly as it did before any of this existed.
      await parkOrder();
      final cart = _cart(db);
      await cart.loadOrderFromLocal(orderLocalId);

      expect(cart.state.items.single.uomId, kUomPieces);
      expect(cart.state.items.single.isToWeigh, isFalse);
    });

    test('a row still on the bare default heals from its legacy text',
        () async {
      // Synced from a server that predates the UoM catalog: uomId is the
      // untouched `pcs` default while measurementUnit says 'kg'. The text is
      // the unit somebody actually chose, so it wins — the same rule
      // Product.fromDrift applies everywhere else.
      await seedSaffron(uomId: kUomPieces, measurementUnit: 'kg');
      await parkOrder();
      final cart = _cart(db);
      await cart.loadOrderFromLocal(orderLocalId);

      expect(cart.state.items.single.uomId, kUomKilogram);
    });

    test('an ordinary pieces product is untouched by any of this', () async {
      await seedSaffron(
          uomId: kUomPieces, isToWeigh: false, measurementUnit: null);
      await parkOrder();
      final cart = _cart(db);
      await cart.loadOrderFromLocal(orderLocalId);

      final line = cart.state.items.single;
      expect(line.uomId, kUomPieces);
      expect(line.isToWeigh, isFalse);
      expect(line.quantity, 100);
    });
  });
}
