// The two bugs that reached the user's database in one save.
//
// 1. EVERY CHOICE DOUBLED. A new option is written locally with a temporary
//    negative id; the server assigns a real one. The push used to leave the
//    temporary row in place and let a later delta pull bring the real one in
//    ALONGSIDE it — and because the group is `synced` by then, it never
//    re-enters the push queue, so the duplicate is permanent. The user's table
//    showed exactly that: -1/-2/-3 pending_create beside 4/5/6 synced, one pair
//    per choice.
//
// 2. PRODUCT LINKS NEVER SYNCED. They were written `pending_create` and no push
//    was ever written for them, so a product's modifier groups stayed on the
//    till that set them.
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  late AppDatabase db;
  const companyId = 25;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ({int? id, String name, double additionalPrice, bool isEnabled}) opt(
          String name, double price) =>
      (id: null, name: name, additionalPrice: price, isEnabled: true);

  ({
    int id,
    String name,
    double additionalPrice,
    int rank,
    bool isEnabled,
    DateTime lastModified
  }) served(int id, String name, double price, int rank) => (
        id: id,
        name: name,
        additionalPrice: price,
        rank: rank,
        isEnabled: true,
        lastModified: DateTime.now().toUtc(),
      );

  Future<int> saveToppings() => db.saveModifierGroupLocal(
        companyId: companyId,
        name: 'Toppings',
        minSelections: 0,
        maxSelections: 2,
        allowsFreeText: false,
        rank: 0,
        isEnabled: true,
        options: [
          opt('Extra Chees', 3),
          opt('Extra Tomato', 3),
          opt('Big Frise', 4),
        ],
      );

  group("a pushed group ends up with the server's options, and only those", () {
    test('three choices in, three choices out — not six', () async {
      // The reported bug, start to finish.
      final tempId = await saveToppings();
      expect(await db.modifierOptionsForGroup(tempId), hasLength(3));

      await db.remapModifierGroupId(tempId, 2);
      await db.replaceModifierOptionsFromServer(
        companyId: companyId,
        groupId: 2,
        options: [
          served(4, 'Extra Chees', 3, 0),
          served(5, 'Extra Tomato', 3, 1),
          served(6, 'Big Frise', 4, 2),
        ],
      );

      final all = await db.select(db.modifierOptionsTable).get();
      expect(all, hasLength(3), reason: 'six rows is the bug');
      expect(all.map((o) => o.id).toSet(), {4, 5, 6});
      expect(all.every((o) => o.syncStatus == 'synced'), isTrue);
    });

    test('no temporary row survives the replace', () async {
      final tempId = await saveToppings();
      await db.remapModifierGroupId(tempId, 2);
      await db.replaceModifierOptionsFromServer(
        companyId: companyId,
        groupId: 2,
        options: [served(4, 'Extra Chees', 3, 0)],
      );

      final all = await db.select(db.modifierOptionsTable).get();
      expect(all.where((o) => o.id < 0), isEmpty);
    });

    test("the server's prices and order are what stick", () async {
      final tempId = await saveToppings();
      await db.remapModifierGroupId(tempId, 2);
      await db.replaceModifierOptionsFromServer(
        companyId: companyId,
        groupId: 2,
        options: [
          served(6, 'Big Frise', 4, 0),
          served(4, 'Extra Chees', 3, 1),
        ],
      );

      final options = await db.modifierOptionsForGroup(2);
      expect(options.map((o) => o.name), ['Big Frise', 'Extra Chees']);
      expect(options.map((o) => o.additionalPrice), [4, 3]);
    });

    test('a group that lost every option ends up empty, not stale', () async {
      final tempId = await saveToppings();
      await db.remapModifierGroupId(tempId, 2);
      await db.replaceModifierOptionsFromServer(
          companyId: companyId, groupId: 2, options: const []);

      expect(await db.modifierOptionsForGroup(2), isEmpty);
    });

    test("another group's options are untouched", () async {
      final a = await saveToppings();
      await db.remapModifierGroupId(a, 2);
      final b = await db.saveModifierGroupLocal(
        companyId: companyId,
        name: 'Sauce',
        minSelections: 0,
        maxSelections: 1,
        allowsFreeText: false,
        rank: 1,
        isEnabled: true,
        options: [opt('Garlic', 0)],
      );

      await db.replaceModifierOptionsFromServer(
          companyId: companyId, groupId: 2, options: [served(4, 'X', 0, 0)]);

      expect(await db.modifierOptionsForGroup(b), hasLength(1));
    });
  });

  group('repairing a database that already has the duplicates', () {
    test('temporary rows under a SYNCED group are purged', () async {
      // Exactly the user's table: group synced, three real options, three
      // temporary leftovers that no queue would ever revisit.
      await db.into(db.modifierGroupsTable).insertOnConflictUpdate(
            ModifierGroupsTableCompanion.insert(
              id: const Value(2),
              companyId: companyId,
              name: 'Toppings',
              lastModified: DateTime.now().toUtc(),
            ),
          );
      for (final (id, status) in [
        (-1, 'pending_create'),
        (-2, 'pending_create'),
        (-3, 'pending_create'),
        (4, 'synced'),
        (5, 'synced'),
        (6, 'synced'),
      ]) {
        await db.into(db.modifierOptionsTable).insertOnConflictUpdate(
              ModifierOptionsTableCompanion.insert(
                id: Value(id),
                companyId: companyId,
                modifierGroupId: 2,
                name: 'opt$id',
                syncStatus: Value(status),
                lastModified: DateTime.now().toUtc(),
              ),
            );
      }

      final purged = await db.purgeSupersededModifierOptions(companyId);

      expect(purged, 3);
      final left = await db.select(db.modifierOptionsTable).get();
      expect(left.map((o) => o.id).toSet(), {4, 5, 6});
    });

    test('a REAL pending edit is not purged', () async {
      // The rule that makes the purge safe: adding a choice to a synced group
      // marks the GROUP pending_update, so its temporary option is live work.
      final id = await db.saveModifierGroupLocal(
        companyId: companyId,
        groupId: 2,
        name: 'Toppings',
        minSelections: 0,
        maxSelections: 2,
        allowsFreeText: false,
        rank: 0,
        isEnabled: true,
        options: [opt('A new choice', 5)],
      );

      final purged = await db.purgeSupersededModifierOptions(companyId);

      expect(purged, 0);
      expect(await db.modifierOptionsForGroup(id), hasLength(1));
    });

    test('a clean database purges nothing', () async {
      await db.replaceModifierOptionsFromServer(
          companyId: companyId, groupId: 2, options: [served(4, 'X', 0, 0)]);
      expect(await db.purgeSupersededModifierOptions(companyId), 0);
    });
  });

  group('product links actually reach the server now', () {
    test('a link written offline is queued', () async {
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 59, groupIds: [2]);

      expect(await db.productIdsWithPendingModifierLinks(companyId), [59]);
    });

    test("the server's ids replace the synthetic local ones", () async {
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 59, groupIds: [2, 3]);

      await db.replaceProductModifierLinksFromServer(
        companyId: companyId,
        productId: 59,
        links: [
          (id: 11, modifierGroupId: 2, rank: 0, lastModified: DateTime.now().toUtc()),
          (id: 12, modifierGroupId: 3, rank: 1, lastModified: DateTime.now().toUtc()),
        ],
      );

      final rows = await (db.select(db.productModifierGroupsTable)
            ..orderBy([(t) => OrderingTerm(expression: t.rank)]))
          .get();
      expect(rows.map((r) => r.id), [11, 12]);
      expect(rows.every((r) => r.syncStatus == 'synced'), isTrue);
      expect(await db.productIdsWithPendingModifierLinks(companyId), isEmpty);
    });

    test('the replace does not touch another product', () async {
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 59, groupIds: [2]);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 60, groupIds: [3]);

      await db.replaceProductModifierLinksFromServer(
        companyId: companyId,
        productId: 59,
        links: [
          (id: 11, modifierGroupId: 2, rank: 0, lastModified: DateTime.now().toUtc()),
        ],
      );

      expect(await db.productIdsWithPendingModifierLinks(companyId), [60]);
    });

    test('a link pointing at an unsynced group is held back', () async {
      // The ordering rule: pushing this would send the server a group id it has
      // never heard of, and it rejects the whole product.
      final tempGroup = await saveToppings();
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 59, groupIds: [tempGroup]);

      final links = await db.modifierLinksForProduct(companyId, 59);
      expect(links.any((l) => l.modifierGroupId < 0), isTrue,
          reason: 'the push must skip this product until the group lands');
    });

    test('clearing a product clears the server side too', () async {
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 59, groupIds: [2]);
      await db.replaceProductModifierLinksFromServer(
          companyId: companyId, productId: 59, links: const []);

      expect(await db.modifierLinksForProduct(companyId, 59), isEmpty);
    });
  });
}
