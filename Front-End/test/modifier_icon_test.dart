// The icon a modifier group carries, and why it is stored rather than guessed.
//
// The alternative was deriving a glyph from the group's NAME with a keyword
// map. That only works in the language the map was written in: "Toppings"
// matches, "Garnitures" and "الإضافات" do not, so most users of an app that
// ships three languages would see the fallback on every group forever. Storing
// the operator's choice bypasses the name entirely.
//
// The contract these pin: a key always resolves to SOMETHING, an unknown key
// degrades to the fallback rather than crashing a sale, and the choice survives
// a save and reopen.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/modifier/modifier_icons.dart';
import 'package:pos_app/modifier/modifier_models.dart';

void main() {
  group('the catalog', () {
    test('offers eight choices', () {
      // Small on purpose: a picker with two hundred icons is a browsing task in
      // the middle of setting up a menu.
      expect(kModifierIcons, hasLength(8));
    });

    test('every key is unique', () {
      // A duplicate key would make one entry unreachable and the picker would
      // show two tiles that both claim to be selected.
      final keys = kModifierIcons.map((i) => i.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
    });

    test('no key collides with the fallback', () {
      expect(kModifierIcons.map((i) => i.key),
          isNot(contains(kModifierIconFallback.key)));
    });

    test('every entry has both weights', () {
      // The sheet draws Fill and the picker draws Regular; a missing one is a
      // blank square in production.
      for (final i in kModifierIcons) {
        expect(i.regular, isNotNull, reason: i.key);
        expect(i.fill, isNotNull, reason: i.key);
      }
    });

    test('the keys are stable strings, not numbers', () {
      // A codepoint would break the moment the icon set is swapped or a glyph
      // renumbered, and it is unreadable in a database dump.
      for (final i in kModifierIcons) {
        expect(i.key, isNotEmpty);
        expect(int.tryParse(i.key), isNull, reason: '${i.key} looks numeric');
      }
    });
  });

  group('resolving a key', () {
    test('a known key resolves to its own icon', () {
      expect(modifierIconFor('burger').key, 'burger');
      expect(modifierIconFor('sauce').key, 'sauce');
    });

    test('null falls back', () {
      expect(modifierIconFor(null).key, kModifierIconFallback.key);
    });

    test('empty falls back', () {
      expect(modifierIconFor('').key, kModifierIconFallback.key);
    });

    test('an UNKNOWN key falls back instead of throwing', () {
      // A group synced from a build that knew more icons than this one, or one
      // whose entry has since been removed, still has to render mid-sale.
      expect(modifierIconFor('sushi').key, kModifierIconFallback.key);
      expect(modifierIconFor('🍔').key, kModifierIconFallback.key);
    });

    test('resolution is case-sensitive, matching what is stored', () {
      // Keys are written by this app, never typed, so loosening the match would
      // only hide a real mismatch.
      expect(modifierIconFor('Burger').key, kModifierIconFallback.key);
    });
  });

  group('what the picker treats as selected', () {
    test('a real key is selectable', () {
      expect(isKnownModifierIcon('burger'), isTrue);
    });

    test('the fallback is NOT a selection', () {
      // It is the absence of a choice, which is why the picker renders it as
      // the "None" option rather than a ninth icon.
      expect(isKnownModifierIcon(null), isFalse);
      expect(isKnownModifierIcon(''), isFalse);
      expect(isKnownModifierIcon(kModifierIconFallback.key), isFalse);
    });

    test('an unknown key is not shown as selected', () {
      // The editor drops it to "None" rather than leaving no tile highlighted.
      expect(isKnownModifierIcon('sushi'), isFalse);
    });
  });

  group('the choice survives storage', () {
    late AppDatabase db;
    const companyId = 25;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> save({String? iconKey}) => db.saveModifierGroupLocal(
          companyId: companyId,
          name: 'Toppings',
          minSelections: 0,
          maxSelections: 2,
          allowsFreeText: false,
          rank: 0,
          isEnabled: true,
          iconKey: iconKey,
          options: [
            (id: null, name: 'Extra Cheese', additionalPrice: 3, isEnabled: true)
          ],
        );

    test('it round-trips through Drift', () async {
      final id = await save(iconKey: 'sauce');

      final row = await db.select(db.modifierGroupsTable).getSingle();
      expect(row.id, id);
      expect(row.iconKey, 'sauce');
      expect(ModifierGroup.fromDrift(row).iconKey, 'sauce');
    });

    test('no icon stores null, not a sentinel string', () async {
      await save();
      expect((await db.select(db.modifierGroupsTable).getSingle()).iconKey,
          isNull);
    });

    test('it reaches the till with the group', () async {
      final id = await save(iconKey: 'spice');
      await db.setProductModifierGroupsLocal(
          companyId: companyId, productId: 7, groupIds: [id]);

      final groups = modifierGroupsFromRows(
          await db.modifierGroupsForProductDirect(companyId, 7));

      expect(groups.single.iconKey, 'spice');
      expect(modifierIconFor(groups.single.iconKey).key, 'spice');
    });

    test('clearing it back to None sticks', () async {
      final id = await save(iconKey: 'burger');
      await db.saveModifierGroupLocal(
        companyId: companyId,
        groupId: id,
        name: 'Toppings',
        minSelections: 0,
        maxSelections: 2,
        allowsFreeText: false,
        rank: 0,
        isEnabled: true,
        iconKey: null,
        options: [
          (id: null, name: 'Extra Cheese', additionalPrice: 3, isEnabled: true)
        ],
      );

      expect((await db.select(db.modifierGroupsTable).getSingle()).iconKey,
          isNull);
    });

    test('withOptions does not drop it', () async {
      // The composing path the till uses — losing the icon there would show the
      // fallback on a group that has one.
      const g = ModifierGroup(id: 1, name: 'Toppings', iconKey: 'drink');
      expect(g.withOptions(const []).iconKey, 'drink');
    });

    test('it survives the JSON the server speaks', () {
      final g = ModifierGroup.fromJson(const {
        'id': 1,
        'name': 'Toppings',
        'iconKey': 'dessert',
      });
      expect(g.iconKey, 'dessert');
    });

    test('a server that sends no icon leaves it null', () {
      final g = ModifierGroup.fromJson(const {'id': 1, 'name': 'Toppings'});
      expect(g.iconKey, isNull);
      expect(modifierIconFor(g.iconKey).key, kModifierIconFallback.key);
    });
  });
}
