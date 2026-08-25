// Whether tapping a product opens the customise sheet at all.
//
// This is the read that decides it, and it silently returned nothing on a
// product that plainly had a group attached — the sheet never opened and the
// item went straight into the cart. The cause was reading an autoDispose
// `.family` StreamProvider's `.future` with no active listener: it resolved
// before the Drift watch-stream emitted its first row. The identical trap is
// documented on `productCommentsProvider` a few lines from that call site.
//
// So these run against the DATABASE, the way the till does, and cover the
// filtering too — a group that must not be offered is as much a bug as one
// that must be and is not.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/modifier/modifier_models.dart';

void main() {
  late AppDatabase db;
  const companyId = 25;
  const burgerId = 59;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seedGroup({
    int id = 2,
    String name = 'Toppings',
    bool enabled = true,
    int min = 0,
    int max = 2,
    String syncStatus = 'synced',
  }) =>
      db.into(db.modifierGroupsTable).insertOnConflictUpdate(
            ModifierGroupsTableCompanion.insert(
              id: Value(id),
              companyId: companyId,
              name: name,
              minSelections: Value(min),
              maxSelections: Value(max),
              isEnabled: Value(enabled),
              syncStatus: Value(syncStatus),
              lastModified: DateTime.now().toUtc(),
            ),
          );

  Future<void> seedOption({
    required int id,
    int groupId = 2,
    String name = 'Extra Cheese',
    double price = 3,
    bool enabled = true,
    int rank = 0,
  }) =>
      db.into(db.modifierOptionsTable).insertOnConflictUpdate(
            ModifierOptionsTableCompanion.insert(
              id: Value(id),
              companyId: companyId,
              modifierGroupId: groupId,
              name: name,
              additionalPrice: Value(price),
              rank: Value(rank),
              isEnabled: Value(enabled),
              lastModified: DateTime.now().toUtc(),
            ),
          );

  Future<List<ModifierGroup>> lookup() async => modifierGroupsFromRows(
        await db.modifierGroupsForProductDirect(companyId, burgerId),
      );

  group('the sheet opens when it should', () {
    test('a product with a linked group finds it', () async {
      // The reported failure: this returned empty and the sheet never opened.
      await seedGroup();
      await seedOption(id: 4);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: burgerId, groupIds: [2]);

      final groups = await lookup();

      expect(groups, hasLength(1));
      expect(groups.single.name, 'Toppings');
      expect(groups.single.options.single.name, 'Extra Cheese');
    });

    test('it works while the link is still PENDING push', () async {
      // Exactly the state a till is in the moment the operator attaches a
      // group offline. Requiring a synced link would mean the sheet only
      // appeared after a successful sync.
      await seedGroup();
      await seedOption(id: 4);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: burgerId, groupIds: [2]);

      final links = await db.modifierLinksForProduct(companyId, burgerId);
      expect(links.single.syncStatus, 'pending_create');
      expect(await lookup(), hasLength(1));
    });

    test('link order is the order the cashier is asked', () async {
      await seedGroup(id: 2, name: 'Toppings');
      await seedGroup(id: 3, name: 'Doneness');
      await seedOption(id: 4, groupId: 2);
      await seedOption(id: 5, groupId: 3, name: 'Rare');
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: burgerId, groupIds: [3, 2]);

      expect((await lookup()).map((g) => g.name), ['Doneness', 'Toppings']);
    });

    test('options come back in their own rank order', () async {
      await seedGroup();
      await seedOption(id: 6, name: 'Bacon', rank: 1);
      await seedOption(id: 4, name: 'Extra Cheese', rank: 0);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: burgerId, groupIds: [2]);

      expect((await lookup()).single.options.map((o) => o.name),
          ['Extra Cheese', 'Bacon']);
    });

    test('the selection rule survives the round trip', () async {
      await seedGroup(min: 1, max: 3);
      await seedOption(id: 4);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: burgerId, groupIds: [2]);

      final g = (await lookup()).single;
      expect(g.minSelections, 1);
      expect(g.maxSelections, 3);
      expect(g.isMandatory, isTrue);
    });
  });

  group('the sheet stays shut when it should', () {
    test('a product with no links offers nothing', () async {
      await seedGroup();
      await seedOption(id: 4);

      expect(await lookup(), isEmpty);
    });

    test('a DISABLED group is not offered', () async {
      // Turning a group off is the documented way to retire one, so this is
      // the path that actually gets used.
      await seedGroup(enabled: false);
      await seedOption(id: 4);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: burgerId, groupIds: [2]);

      expect(await lookup(), isEmpty);
    });

    test('a group with no options is dropped, not shown empty', () async {
      // A MANDATORY group in that state would block the sale with nothing to
      // click — worse than not asking at all.
      await seedGroup(min: 1);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: burgerId, groupIds: [2]);

      expect(await lookup(), isEmpty);
    });

    test('a group whose options are all disabled is dropped', () async {
      await seedGroup();
      await seedOption(id: 4, enabled: false);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: burgerId, groupIds: [2]);

      expect(await lookup(), isEmpty);
    });

    test('a group being deleted locally is not offered', () async {
      await seedGroup(syncStatus: 'pending_delete');
      await seedOption(id: 4);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: burgerId, groupIds: [2]);

      expect(await lookup(), isEmpty);
    });

    test('a disabled OPTION disappears without taking its group', () async {
      await seedGroup();
      await seedOption(id: 4, name: 'Extra Cheese');
      await seedOption(id: 5, name: 'Retired topping', enabled: false, rank: 1);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: burgerId, groupIds: [2]);

      final g = (await lookup()).single;
      expect(g.options.map((o) => o.name), ['Extra Cheese']);
    });

    test('another product does not borrow this one\'s groups', () async {
      await seedGroup();
      await seedOption(id: 4);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 60, groupIds: [2]);

      expect(await lookup(), isEmpty);
    });

    test('another company is invisible', () async {
      await seedGroup();
      await seedOption(id: 4);
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: burgerId, groupIds: [2]);

      expect(await db.modifierGroupsForProductDirect(99, burgerId), isEmpty);
    });

    test('a link to a group that is not cached is skipped, not crashed',
        () async {
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: burgerId, groupIds: [404]);

      expect(await lookup(), isEmpty);
    });
  });
}
