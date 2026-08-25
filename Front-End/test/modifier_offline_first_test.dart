// Modifiers with the network unplugged — the whole point of this app.
//
// Two holes this covers, both found by the user asking "wait, it should be
// offline first, double check":
//
// 1. PARKING AN ORDER LOST THE CHOICES. `selectedModifiers` lived only in
//    memory and in the API payload, never in Drift. Reopening a parked order
//    showed the right TOTAL — the surcharge is already inside `unitPrice` — and
//    no "Extra Cheese" on it, so the kitchen ticket printed a plain burger. A
//    price that is right while the ticket is wrong is the worst way this can
//    fail, because nothing looks broken.
//
// 2. AN OFFLINE-CREATED PRODUCT LOST ITS GROUPS. `remapProductId` repoints
//    every table that references a temp product id and did not know about
//    `product_modifier_groups`, so the links kept pointing at the negative id:
//    the push would 400 and the till's own lookup — which keys on productId —
//    would stop opening the sheet the moment the product got its real id.
import 'package:drift/drift.dart' show Value;
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

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  const companyId = 25;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appSettingsProvider.overrideWith(_FakeSettings.new),
        allTaxesProvider.overrideWith((ref) => Stream.value(const <Tax>[])),
        selectableCustomersProvider
            .overrideWith((ref) => const AsyncValue.data(<Customer>[])),
        allCustomersProvider
            .overrideWith((ref) => Stream.value(const <Customer>[])),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  CartNotifier cart() {
    final c = container.read(cartProvider.notifier);
    c.state = c.state.copyWith(activePosOrderId: 1);
    return c;
  }

  MenuProduct burger() => MenuProduct(
        id: 7,
        name: 'Burger',
        price: 80,
        isTaxInclusivePrice: false,
        color: '#FFFFFF',
        stockQuantity: 9999,
        taxes: const [],
      );

  const cheese = SelectedModifier(
      modifierOptionId: 1,
      groupName: 'Toppings',
      name: 'Extra Cheese',
      additionalPrice: 10);
  const bun = SelectedModifier(
      modifierOptionId: 2,
      groupName: 'Toppings',
      name: 'Gluten Free Bun',
      additionalPrice: 15);

  group('parking an order offline keeps the choices', () {
    test('they survive a save and reopen', () async {
      final c = cart();
      c.addItem(burger(), quantity: 2, modifiers: [cheese, bun]);
      await c.saveOrderLocally(companyId: companyId, userId: 1);

      final localId = c.state.existingLocalOrderId!;
      c.clearCart();
      expect(c.state.items, isEmpty);

      await c.loadOrderFromLocal(localId);

      final line = c.state.items.single;
      expect(line.selectedModifiers.map((m) => m.name),
          ['Extra Cheese', 'Gluten Free Bun']);
    });

    test('the money is unchanged, which is why this was invisible', () async {
      final c = cart();
      c.addItem(burger(), quantity: 2, modifiers: [cheese, bun]);
      await c.saveOrderLocally(companyId: companyId, userId: 1);
      final localId = c.state.existingLocalOrderId!;
      c.clearCart();
      await c.loadOrderFromLocal(localId);

      final line = c.state.items.single;
      expect(line.price, 105);
      expect(line.price * line.quantity, 210);
    });

    test('basePrice is derived back, so re-editing does not compound',
        () async {
      // Restoring `basePrice = unitPrice` would leave the surcharge counted
      // twice the next time the choices are changed.
      final c = cart();
      c.addItem(burger(), modifiers: [cheese, bun]);
      await c.saveOrderLocally(companyId: companyId, userId: 1);
      final localId = c.state.existingLocalOrderId!;
      c.clearCart();
      await c.loadOrderFromLocal(localId);

      final line = c.state.items.single;
      expect(line.basePrice, 80);

      c.setItemModifiers(line.cartItemId, [cheese]);
      expect(c.state.items.single.price, 90);
    });

    test('the snapshot keeps the name and price, not a catalogue lookup',
        () async {
      final c = cart();
      c.addItem(burger(), modifiers: [cheese]);
      await c.saveOrderLocally(companyId: companyId, userId: 1);
      final localId = c.state.existingLocalOrderId!;
      c.clearCart();
      await c.loadOrderFromLocal(localId);

      final m = c.state.items.single.selectedModifiers.single;
      expect(m.name, 'Extra Cheese');
      expect(m.additionalPrice, 10);
      expect(m.groupName, 'Toppings');
      expect(m.modifierOptionId, 1);
    });

    test('re-saving replaces rather than doubling the rows', () async {
      // saveOrderLocally rewrites the lines with fresh localIds every time, so
      // the old modifier rows have to go with them.
      final c = cart();
      c.addItem(burger(), modifiers: [cheese, bun]);
      await c.saveOrderLocally(companyId: companyId, userId: 1);
      await c.saveOrderLocally(companyId: companyId, userId: 1);

      final rows = await db.select(db.posOrderItemModifiersTable).get();
      expect(rows, hasLength(2), reason: 'four rows is the leak');
    });

    test('a plain line stores nothing', () async {
      final c = cart();
      c.addItem(burger());
      await c.saveOrderLocally(companyId: companyId, userId: 1);

      expect(await db.select(db.posOrderItemModifiersTable).get(), isEmpty);
    });

    test('two differently customised lines keep their own choices', () async {
      final c = cart();
      c.addItem(burger(), modifiers: [cheese]);
      c.addItem(burger(), modifiers: [bun]);
      await c.saveOrderLocally(companyId: companyId, userId: 1);
      final localId = c.state.existingLocalOrderId!;
      c.clearCart();
      await c.loadOrderFromLocal(localId);

      expect(c.state.items, hasLength(2));
      expect(
        c.state.items.map((i) => i.selectedModifiers.single.name).toSet(),
        {'Extra Cheese', 'Gluten Free Bun'},
      );
    });
  });

  group('a product created offline keeps its groups', () {
    test('remapping the product id repoints its links', () async {
      // The till writes a temp negative product id until the push assigns a
      // real one; everything referencing it has to move at the same moment.
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: -5, groupIds: [2, 3]);

      await db.remapProductId(-5, 91);

      final links = await db.modifierLinksForProduct(companyId, 91);
      expect(links.map((l) => l.modifierGroupId), [2, 3]);
      expect(await db.modifierLinksForProduct(companyId, -5), isEmpty);
    });

    test('the customise sheet still finds them afterwards', () async {
      // The lookup keys on productId, so a stale link means the sheet silently
      // stops opening for that product.
      await db.into(db.modifierGroupsTable).insertOnConflictUpdate(
            ModifierGroupsTableCompanion.insert(
              id: const Value(2),
              companyId: companyId,
              name: 'Toppings',
              lastModified: DateTime.now().toUtc(),
            ),
          );
      await db.into(db.modifierOptionsTable).insertOnConflictUpdate(
            ModifierOptionsTableCompanion.insert(
              id: const Value(4),
              companyId: companyId,
              modifierGroupId: 2,
              name: 'Extra Cheese',
              lastModified: DateTime.now().toUtc(),
            ),
          );
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: -5, groupIds: [2]);

      await db.remapProductId(-5, 91);

      final groups = modifierGroupsFromRows(
          await db.modifierGroupsForProductDirect(companyId, 91));
      expect(groups, hasLength(1));
      expect(groups.single.options.single.name, 'Extra Cheese');
    });

    test('another product is not dragged along', () async {
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: -5, groupIds: [2]);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 60, groupIds: [3]);

      await db.remapProductId(-5, 91);

      expect((await db.modifierLinksForProduct(companyId, 60))
          .single
          .modifierGroupId, 3);
    });
  });

  group('the whole catalogue is writable with no network', () {
    test('a group, its options and a product link all save locally', () async {
      // Nothing in this test touches Dio. If any of it needed the server, the
      // admin screen would be unusable in a shop with a dropped connection.
      final groupId = await db.saveModifierGroupLocal(
        companyId: companyId,
        name: 'Toppings',
        minSelections: 0,
        maxSelections: 2,
        allowsFreeText: false,
        rank: 0,
        isEnabled: true,
        options: [
          (id: null, name: 'Extra Cheese', additionalPrice: 10, isEnabled: true),
        ],
      );
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 7, groupIds: [groupId]);

      expect(groupId, lessThan(0), reason: 'a local id until the push');
      expect(await db.modifierOptionsForGroup(groupId), hasLength(1));

      // And the till can offer it immediately — before any sync.
      final groups = modifierGroupsFromRows(
          await db.modifierGroupsForProductDirect(companyId, 7));
      expect(groups.single.options.single.name, 'Extra Cheese');
    });

    test('everything written offline is queued for push', () async {
      final groupId = await db.saveModifierGroupLocal(
        companyId: companyId,
        name: 'Toppings',
        minSelections: 0,
        maxSelections: 1,
        allowsFreeText: false,
        rank: 0,
        isEnabled: true,
        options: [(id: null, name: 'A', additionalPrice: 0, isEnabled: true)],
      );
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 7, groupIds: [groupId]);

      expect((await db.getPendingModifierGroups(companyId)).map((g) => g.id),
          contains(groupId));
      expect(await db.productIdsWithPendingModifierLinks(companyId), [7]);
    });
  });
}
