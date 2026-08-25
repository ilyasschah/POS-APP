// Phase 2: the offline half of the modifier catalogue.
//
// Everything here is about what happens between a save and a successful push —
// the window where ids are temporary, rows point at each other, and a till can
// be switched off. The rules that matter: a group and its options move as one,
// a real option id is never recycled (past sales point at it), and swapping a
// temp id for the server's real one must drag every referencing row with it.
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  late AppDatabase db;
  const companyId = 1;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ({int? id, String name, double additionalPrice, bool isEnabled}) opt(
    String name,
    double price, {
    int? id,
    bool enabled = true,
  }) =>
      (id: id, name: name, additionalPrice: price, isEnabled: enabled);

  Future<int> saveToppings({
    int? groupId,
    String name = 'Toppings',
    int min = 0,
    int max = 3,
    bool enabled = true,
    List<({int? id, String name, double additionalPrice, bool isEnabled})>?
        options,
  }) =>
      db.saveModifierGroupLocal(
        companyId: companyId,
        groupId: groupId,
        name: name,
        minSelections: min,
        maxSelections: max,
        allowsFreeText: false,
        rank: 0,
        isEnabled: enabled,
        options: options ?? [opt('Extra Cheese', 12), opt('Bacon', 15)],
      );

  group('saving a group offline', () {
    test('a new group gets a negative id and is queued to push', () async {
      final id = await saveToppings();

      expect(id, lessThan(0), reason: 'the server has not assigned one yet');
      final row = await db.select(db.modifierGroupsTable).getSingle();
      expect(row.syncStatus, 'pending_create');
    });

    test('its options come with it, ranked by list position', () async {
      final id = await saveToppings();

      final options = await db.modifierOptionsForGroup(id);
      expect(options.map((o) => o.name), ['Extra Cheese', 'Bacon']);
      expect(options.map((o) => o.rank), [0, 1]);
      expect(options.map((o) => o.additionalPrice), [12, 15]);
    });

    test('two new groups do not collide on the same temp id', () async {
      final a = await saveToppings(name: 'Toppings');
      final b = await saveToppings(name: 'Sauce');

      expect(a, isNot(b));
      expect(await db.select(db.modifierGroupsTable).get(), hasLength(2));
    });

    test('saving is a REPLACE — a dropped option really goes', () async {
      final id = await saveToppings();
      await saveToppings(groupId: id, options: [opt('Extra Cheese', 12)]);

      final options = await db.modifierOptionsForGroup(id);
      expect(options.map((o) => o.name), ['Extra Cheese']);
    });

    test('a real option id SURVIVES a re-save', () async {
      // Load-bearing: past sales point at that id for reporting, so recreating
      // the row on every save would orphan every document_item_modifier that
      // referenced it — and break "how many Extra Cheese" the moment somebody
      // renames the group.
      final id = await saveToppings(groupId: 900);
      await db.into(db.modifierOptionsTable).insertOnConflictUpdate(
            ModifierOptionsTableCompanion.insert(
              id: const Value(555),
              companyId: companyId,
              modifierGroupId: id,
              name: 'Extra Cheese',
              lastModified: DateTime.now().toUtc(),
            ),
          );

      await saveToppings(
        groupId: id,
        options: [opt('Extra Cheese', 14, id: 555)],
      );

      final options = await db.modifierOptionsForGroup(id);
      expect(options.single.id, 555, reason: 'the id must not be recycled');
      expect(options.single.additionalPrice, 14, reason: 'but the price updates');
    });

    test('an already-synced group re-saves as pending_update, not create',
        () async {
      // A create would POST id 0 and the server would make a SECOND group.
      await db.into(db.modifierGroupsTable).insertOnConflictUpdate(
            ModifierGroupsTableCompanion.insert(
              id: const Value(42),
              companyId: companyId,
              name: 'Toppings',
              lastModified: DateTime.now().toUtc(),
            ),
          );

      await saveToppings(groupId: 42, name: 'Toppings v2');

      final row = await db.select(db.modifierGroupsTable).getSingle();
      expect(row.syncStatus, 'pending_update');
      expect(row.name, 'Toppings v2');
    });
  });

  group('deleting', () {
    test('a group the server never saw is dropped outright', () async {
      final id = await saveToppings();
      await db.deleteModifierGroupLocal(id);

      expect(await db.select(db.modifierGroupsTable).get(), isEmpty);
      expect(await db.modifierOptionsForGroup(id), isEmpty,
          reason: 'its options go with it');
    });

    test('a synced group is flagged, not removed, until the push lands',
        () async {
      await db.into(db.modifierGroupsTable).insertOnConflictUpdate(
            ModifierGroupsTableCompanion.insert(
              id: const Value(42),
              companyId: companyId,
              name: 'Toppings',
              lastModified: DateTime.now().toUtc(),
            ),
          );

      await db.deleteModifierGroupLocal(42);

      final row = await db.select(db.modifierGroupsTable).getSingle();
      expect(row.syncStatus, 'pending_delete');
    });

    test('a flagged group is hidden from the pull so it cannot resurrect',
        () async {
      await db.into(db.modifierGroupsTable).insertOnConflictUpdate(
            ModifierGroupsTableCompanion.insert(
              id: const Value(42),
              companyId: companyId,
              name: 'Toppings',
              lastModified: DateTime.now().toUtc(),
            ),
          );
      await db.deleteModifierGroupLocal(42);

      expect(await db.pendingDeleteModifierGroupIds(companyId), {42});
    });

    test('deleting takes the product links with it', () async {
      final id = await saveToppings();
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 7, groupIds: [id]);

      await db.deleteModifierGroupLocal(id);

      expect(await db.select(db.productModifierGroupsTable).get(), isEmpty,
          reason: 'a link to a group that is gone renders an empty section');
    });
  });

  group('swapping a temp id for the real one', () {
    test('the group keeps its content and becomes synced', () async {
      final tempId = await saveToppings();
      await db.remapModifierGroupId(tempId, 42);

      final row = await db.select(db.modifierGroupsTable).getSingle();
      expect(row.id, 42);
      expect(row.name, 'Toppings');
      expect(row.maxSelections, 3);
      expect(row.syncStatus, 'synced');
    });

    test('its options follow it', () async {
      // The whole point of the cascade — options left pointing at -1 would be
      // invisible to every read, and the group would render with no choices.
      final tempId = await saveToppings();
      await db.remapModifierGroupId(tempId, 42);

      final options = await db.modifierOptionsForGroup(42);
      expect(options, hasLength(2));
      expect(await db.modifierOptionsForGroup(tempId), isEmpty);
    });

    test('its product links follow it too', () async {
      final tempId = await saveToppings();
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 7, groupIds: [tempId]);

      await db.remapModifierGroupId(tempId, 42);

      final links = await db.select(db.productModifierGroupsTable).get();
      expect(links.single.modifierGroupId, 42);
    });

    test('remapping an id that is not there does nothing', () async {
      await db.remapModifierGroupId(-99, 42);
      expect(await db.select(db.modifierGroupsTable).get(), isEmpty);
    });
  });

  group('linking groups to a product', () {
    test('list order becomes section order', () async {
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 7, groupIds: [30, 10, 20]);

      final links = await (db.select(db.productModifierGroupsTable)
            ..orderBy([(t) => OrderingTerm(expression: t.rank)]))
          .get();
      expect(links.map((l) => l.modifierGroupId), [30, 10, 20]);
      expect(links.map((l) => l.rank), [0, 1, 2]);
    });

    test('setting again replaces rather than appends', () async {
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 7, groupIds: [10, 20]);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 7, groupIds: [20]);

      final links = await db.select(db.productModifierGroupsTable).get();
      expect(links.map((l) => l.modifierGroupId), [20]);
    });

    test('one product does not disturb another', () async {
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 7, groupIds: [10]);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 8, groupIds: [20]);

      expect(await db.productIdsWithModifiers(companyId), {7, 8});
    });

    test('clearing a product leaves nothing behind', () async {
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 7, groupIds: [10]);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 7, groupIds: []);

      expect(await db.productIdsWithModifiers(companyId), isEmpty);
    });

    test('a product with no groups never opens the customise sheet', () async {
      // What the menu grid actually asks on every tap.
      expect(await db.productIdsWithModifiers(companyId), isEmpty);
    });
  });

  group('the push queue', () {
    test('picks up creates, updates and deletes, and nothing synced', () async {
      final created = await saveToppings(name: 'Toppings');

      await db.into(db.modifierGroupsTable).insertOnConflictUpdate(
            ModifierGroupsTableCompanion.insert(
              id: const Value(42),
              companyId: companyId,
              name: 'Sauce',
              lastModified: DateTime.now().toUtc(),
            ),
          );
      await db.into(db.modifierGroupsTable).insertOnConflictUpdate(
            ModifierGroupsTableCompanion.insert(
              id: const Value(43),
              companyId: companyId,
              name: 'Doneness',
              lastModified: DateTime.now().toUtc(),
            ),
          );
      await db.deleteModifierGroupLocal(43);

      final pending = await db.getPendingModifierGroups(companyId);
      final ids = pending.map((g) => g.id).toSet();

      expect(ids, contains(created));
      expect(ids, contains(43), reason: 'the pending delete');
      expect(ids, isNot(contains(42)), reason: '42 is already synced');
    });

    test('another company\'s pending edits are not drained', () async {
      await saveToppings();
      final other = await db.getPendingModifierGroups(99);
      expect(other, isEmpty);
    });
  });
}
