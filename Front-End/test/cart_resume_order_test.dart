// Pins the invariant that resuming a saved order keeps it identifiable, so the
// next save UPDATES it rather than inserting a duplicate.
//
// The bug this guards: `loadOrderFromLocal` restored `activePosOrderId` from
// `row.serverId`, which is NULL for any order created offline and not yet
// synced — i.e. every booking order. The POS reads `activePosOrderId == null` as
// "no order is open" and silently calls `startTablelessOrder` on the next
// product tap; that builds a FRESH CartState, wiping `existingLocalOrderId` (and
// `bookingId`). `saveOrderLocally` keys on `existingLocalOrderId ?? uuid()`, so
// the save then minted a new UUID and left the original row behind — two
// pos_orders rows for one order.
//
// The DB layer was never the problem: `saveOpenOrder` already upserts via
// `insertOnConflictUpdate`. Given the right localId it updates in place.
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
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';

class _FakeSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {...kSettingDefaults};
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

/// An order parked offline: it has a localId but no serverId, exactly like one
/// started from a booking and saved while the API was unreachable.
Future<String> _parkOrder(AppDatabase db, {int? bookingId}) async {
  const localId = 'the-parked-order';
  await db.saveOpenOrder(
    PosOrdersTableCompanion(
      localId: const Value(localId),
      serverId: const Value(null), // never synced
      companyId: const Value(1),
      userId: const Value(1),
      serviceType: const Value(0),
      serviceStatus: const Value(1),
      orderName: const Value('APT- Ilyass'),
      bookingId: Value(bookingId),
      openedAt: Value(DateTime.now().toUtc()),
      status: const Value(0),
      total: const Value(35),
      warehouseId: const Value(17),
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

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('resuming an unsynced order marks an order as open', () async {
    final localId = await _parkOrder(db, bookingId: 42);
    final cart = _container(db).read(cartProvider.notifier);

    expect(await cart.loadOrderFromLocal(localId), isTrue);

    // The load-bearing one. Null here means "no order open", which makes the
    // POS start a brand-new tableless order on the next product tap and orphan
    // this one as a duplicate.
    expect(cart.state.activePosOrderId, isNotNull);
    expect(cart.state.existingLocalOrderId, localId);
    expect(cart.state.bookingId, 42);
  });

  test('re-saving a resumed order updates it instead of duplicating', () async {
    final localId = await _parkOrder(db, bookingId: 42);
    final cart = _container(db).read(cartProvider.notifier);
    await cart.loadOrderFromLocal(localId);

    await cart.saveOrderLocally(companyId: 1, userId: 1);

    final rows = await db.select(db.posOrdersTable).get();
    expect(rows, hasLength(1), reason: 'a second row is the duplicate bug');
    expect(rows.single.localId, localId);
    expect(rows.single.bookingId, 42, reason: 'booking link must survive');
  });

  // End-to-end reproduction of the reported duplicate. The wipe doesn't happen
  // in the cart — it happens because menu_screen reads `activePosOrderId == null`
  // as "no order open" and starts a tableless one on the next product tap. That
  // guard is mirrored here (rather than mounting the whole POS) so the chain
  // resume → add product → save is exercised exactly as a cashier drives it.
  test('adding a product to a resumed order does not fork a new one', () async {
    final localId = await _parkOrder(db, bookingId: 42);
    final cart = _container(db).read(cartProvider.notifier);
    await cart.loadOrderFromLocal(localId);

    // ── menu_screen's product-tap handler, verbatim in spirit ──
    if (cart.state.activePosOrderId == null) {
      await cart.startTablelessOrder(ApiClient(), 1, 1, 0);
    }
    // Adding the product matters: saveOrderLocally early-returns on an empty
    // cart, so the fork only becomes a real second ROW once a line exists.
    cart.addItem(
      MenuProduct(
        id: 8,
        name: 'Pepsi',
        price: 35,
        isTaxInclusivePrice: false,
        color: '#FFFFFF',
        stockQuantity: 100,
        taxes: const [],
      ),
    );
    await cart.saveOrderLocally(companyId: 1, userId: 1);

    final rows = await db.select(db.posOrdersTable).get();
    expect(
      rows,
      hasLength(1),
      reason: 'the guard fired and forked a second order',
    );
    expect(rows.single.localId, localId);
    expect(rows.single.bookingId, 42);
  });

  test('the local-only sentinel never leaks into serverId on save', () async {
    final localId = await _parkOrder(db);
    final cart = _container(db).read(cartProvider.notifier);
    await cart.loadOrderFromLocal(localId);

    await cart.saveOrderLocally(companyId: 1, userId: 1);

    // activePosOrderId is 0 for a local order; saving must not write that 0 as
    // a real server id, or the sync would try to update PosOrder #0.
    final rows = await db.select(db.posOrdersTable).get();
    expect(rows.single.serverId, isNull);
  });

  // ── saveAndSuspend: the POS header's Tables / Bookings buttons ────────────
  //
  // Reported by the operator: open a table, save, reopen it, then press TABLES
  // in the POS header — and the table ends up holding TWO orders. Cause was
  // `saveAndSuspend` keeping its own copy of the save that minted a fresh
  // localId with serverId:null every single time, so suspending an order that
  // already had a row inserted a second one. It now delegates to
  // `saveOrderLocally`, which resolves the existing row.
  group('saveAndSuspend parks the SAME order', () {
    test('suspending a resumed order does not create a second one', () async {
      final localId = await _parkOrder(db, bookingId: 42);
      final cart = _container(db).read(cartProvider.notifier);
      await cart.loadOrderFromLocal(localId);

      expect(await cart.saveAndSuspend(companyId: 1, userId: 1), isTrue);

      final rows = await db.select(db.posOrdersTable).get();
      expect(
        rows,
        hasLength(1),
        reason: 'the reported bug: two open orders on one table',
      );
      expect(rows.single.localId, localId);
    });

    test('it preserves the booking link the old copy dropped', () async {
      final localId = await _parkOrder(db, bookingId: 42);
      final cart = _container(db).read(cartProvider.notifier);
      await cart.loadOrderFromLocal(localId);

      await cart.saveAndSuspend(companyId: 1, userId: 1);

      // The private copy never wrote bookingId, so parking a reservation's
      // order via the header button silently unlinked it from its booking.
      expect((await db.select(db.posOrdersTable).get()).single.bookingId, 42);
    });

    test('it empties the till so the next order starts clean', () async {
      final localId = await _parkOrder(db, bookingId: 42);
      final cart = _container(db).read(cartProvider.notifier);
      await cart.loadOrderFromLocal(localId);

      await cart.saveAndSuspend(companyId: 1, userId: 1);

      expect(cart.state.items, isEmpty);
      expect(cart.state.activePosOrderId, isNull);
    });

    test('suspending twice still leaves exactly one row', () async {
      // The operator bouncing between the POS and the floor plan must not
      // accumulate a row per trip.
      final localId = await _parkOrder(db);
      final container = _container(db);
      final cart = container.read(cartProvider.notifier);

      await cart.loadOrderFromLocal(localId);
      await cart.saveAndSuspend(companyId: 1, userId: 1);
      await cart.loadOrderFromLocal(localId);
      await cart.saveAndSuspend(companyId: 1, userId: 1);

      expect(await db.select(db.posOrdersTable).get(), hasLength(1));
    });

    test('it refuses when there is no open order', () async {
      final cart = _container(db).read(cartProvider.notifier);
      expect(await cart.saveAndSuspend(companyId: 1, userId: 1), isFalse);
      expect(await db.select(db.posOrdersTable).get(), isEmpty);
    });
  });
}
