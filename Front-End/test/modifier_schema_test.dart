// Phase 1 of modifiers: the data layer, and the promise that it changes nothing.
//
// Five new tables land on both databases at once. The whole value of an
// additive migration is that an install which never syncs a single modifier
// behaves exactly as it did the day before — so these pin the shape of the new
// tables AND that the old ones are untouched.
//
// The pricing rules are here rather than in a UI test because they are the part
// that decides money: what a modifier adds, and what stops two differently
// customised burgers collapsing into one line.
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/modifier/modifier_models.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('the schema', () {
    test('the version is ahead of 61 — the migration will not run otherwise', () {
      // Pinned as a FLOOR, not an exact number: every later feature bumps this,
      // and a test that has to be edited on each bump gets edited without being
      // read. What matters is that the modifier tables landed after v61.
      expect(AppDatabase.expectedSchemaVersion, greaterThanOrEqualTo(62));
    });

    test('a group round-trips with its selection rules intact', () async {
      await db.into(db.modifierGroupsTable).insert(
            ModifierGroupsTableCompanion.insert(
              id: const Value(1),
              companyId: 1,
              name: 'Toppings',
              minSelections: const Value(1),
              maxSelections: const Value(3),
              allowsFreeText: const Value(true),
              lastModified: DateTime.now().toUtc(),
            ),
          );

      final row = await db.select(db.modifierGroupsTable).getSingle();
      expect(row.name, 'Toppings');
      expect(row.minSelections, 1);
      expect(row.maxSelections, 3);
      expect(row.allowsFreeText, isTrue);
    });

    test('a fresh group defaults to optional pick-one', () async {
      // The defaults have to be the harmless case: a group somebody creates
      // and forgets to configure must not block a sale.
      await db.into(db.modifierGroupsTable).insert(
            ModifierGroupsTableCompanion.insert(
              id: const Value(2),
              companyId: 1,
              name: 'Sauce',
              lastModified: DateTime.now().toUtc(),
            ),
          );

      final row = await db.select(db.modifierGroupsTable).getSingle();
      expect(row.minSelections, 0, reason: 'optional');
      expect(row.maxSelections, 1, reason: 'pick one');
      expect(row.allowsFreeText, isFalse);
      expect(row.isEnabled, isTrue);
      expect(row.syncStatus, 'synced');
    });

    test('an option carries money, including zero and negative', () async {
      // "No Sugar" is free and "Small" is a reduction — both are real options,
      // so neither 0 nor a negative may be treated as "unset".
      for (final (id, name, price) in [
        (1, 'Extra Cheese', 12.0),
        (2, 'No Sugar', 0.0),
        (3, 'Small size', -3.5),
      ]) {
        await db.into(db.modifierOptionsTable).insert(
              ModifierOptionsTableCompanion.insert(
                id: Value(id),
                companyId: 1,
                modifierGroupId: 1,
                name: name,
                additionalPrice: Value(price),
                lastModified: DateTime.now().toUtc(),
              ),
            );
      }

      final rows = await (db.select(db.modifierOptionsTable)
            ..orderBy([(t) => OrderingTerm(expression: t.id)]))
          .get();
      expect(rows.map((r) => r.additionalPrice), [12.0, 0.0, -3.5]);
    });

    test('a line snapshot survives its catalogue option being deleted',
        () async {
      // The reason these are snapshots. A null optionId must still leave a row
      // that reads perfectly on a reprinted receipt.
      await db.into(db.posOrderItemModifiersTable).insert(
            PosOrderItemModifiersTableCompanion.insert(
              localId: 'm1',
              orderItemLocalId: 'line-1',
              modifierOptionId: const Value(null),
              groupName: const Value('Toppings'),
              name: 'Extra Cheese',
              additionalPrice: const Value(12),
            ),
          );

      final row = await db.select(db.posOrderItemModifiersTable).getSingle();
      expect(row.modifierOptionId, isNull);
      expect(row.name, 'Extra Cheese');
      expect(row.additionalPrice, 12);
      expect(row.groupName, 'Toppings');
    });

    test('the document half stores the same snapshot', () async {
      await db.into(db.documentItemModifiersTable).insert(
            DocumentItemModifiersTableCompanion.insert(
              localId: 'd1',
              documentItemLocalId: 'docline-1',
              modifierOptionId: const Value(7),
              name: 'Garlic Sauce',
              additionalPrice: const Value(0),
            ),
          );

      final row = await db.select(db.documentItemModifiersTable).getSingle();
      expect(row.modifierOptionId, 7);
      expect(row.additionalPrice, 0);
    });

    test('the tables an existing install already had are untouched', () async {
      // The additive promise, stated as a test: nothing about products, order
      // lines or comments changed, so a till that never syncs a modifier sells
      // exactly as it did before.
      await db.into(db.productsTable).insert(
            ProductsTableCompanion.insert(
              id: const Value(1),
              companyId: 1,
              name: 'Burger',
              price: const Value(80),
              lastModified: DateTime.now().toUtc(),
            ),
          );

      final product = await db.select(db.productsTable).getSingle();
      expect(product.price, 80);

      // product_comments is still here — Phase 6 retires it, not Phase 1, and
      // the order line's own `comment` column is never going anywhere.
      final comments = await db.select(db.productCommentsTable).get();
      expect(comments, isEmpty);
    });
  });

  group('what a modifier adds', () {
    SelectedModifier m(String name, double price, {int? id}) =>
        SelectedModifier(modifierOptionId: id, name: name, additionalPrice: price);

    test('the worked example from the brief', () {
      // Base 80 + cheese 10 + gluten-free bun 15, times 2 = 210.
      final chosen = [m('Add Cheese', 10, id: 1), m('Gluten Free Bun', 15, id: 2)];
      const base = 80.0;

      final unitPrice = base + modifierSurcharge(chosen);
      expect(unitPrice, 105);
      expect(unitPrice * 2, 210);
    });

    test('no modifiers add nothing', () {
      expect(modifierSurcharge(const []), 0);
    });

    test('free options are real options that add nothing', () {
      expect(modifierSurcharge([m('No Sugar', 0), m('No Ice', 0)]), 0);
    });

    test('a negative modifier reduces the unit price', () {
      expect(80 + modifierSurcharge([m('Small size', -3.5)]), 76.5);
    });
  });

  group('what stops two customised lines merging', () {
    SelectedModifier opt(int id) =>
        SelectedModifier(modifierOptionId: id, name: 'opt$id');

    test('the same choices produce the same key', () {
      expect(
        modifierSelectionKey([opt(1), opt(2)]),
        modifierSelectionKey([opt(1), opt(2)]),
      );
    });

    test('order of choosing does not matter', () {
      // Cheese-then-bacon and bacon-then-cheese are the same burger.
      expect(
        modifierSelectionKey([opt(2), opt(1)]),
        modifierSelectionKey([opt(1), opt(2)]),
      );
    });

    test('different choices produce different keys', () {
      // The bug this exists to prevent: with separate-row OFF, addItem merges
      // by product id alone, so a plain burger and a burger with extra cheese
      // collapsed into one line at whichever price arrived first — and the
      // kitchen got a single ticket for two different sandwiches.
      expect(
        modifierSelectionKey([opt(1)]),
        isNot(modifierSelectionKey([opt(1), opt(2)])),
      );
      expect(modifierSelectionKey([opt(1)]), isNot(modifierSelectionKey([opt(2)])));
    });

    test('a plain line and a customised line never share a key', () {
      expect(modifierSelectionKey(const []), isNot(modifierSelectionKey([opt(1)])));
    });

    test('two lines carrying the same DELETED option still match', () {
      // Both snapshots lost their id; falling back to the name keeps a reopened
      // order from splitting into two identical-looking lines.
      const a = SelectedModifier(name: 'Extra Cheese');
      const b = SelectedModifier(name: 'Extra Cheese');
      expect(modifierSelectionKey([a]), modifierSelectionKey([b]));
    });
  });

  group('whether a group is satisfied', () {
    const optional = ModifierGroup(id: 1, name: 'Sauce');
    const mandatory =
        ModifierGroup(id: 2, name: 'Doneness', minSelections: 1, maxSelections: 1);
    const pickTwoToFour = ModifierGroup(
        id: 3, name: 'Toppings', minSelections: 2, maxSelections: 4);

    test('an optional group is satisfied by choosing nothing', () {
      expect(modifierGroupViolation(optional, 0), isNull);
    });

    test('a mandatory group blocks until something is chosen', () {
      expect(modifierGroupViolation(mandatory, 0), 'min');
      expect(modifierGroupViolation(mandatory, 1), isNull);
    });

    test('choosing past the maximum is a violation', () {
      expect(modifierGroupViolation(optional, 2), 'max');
      expect(modifierGroupViolation(pickTwoToFour, 5), 'max');
    });

    test('a range group is satisfied only inside its range', () {
      expect(modifierGroupViolation(pickTwoToFour, 1), 'min');
      expect(modifierGroupViolation(pickTwoToFour, 2), isNull);
      expect(modifierGroupViolation(pickTwoToFour, 4), isNull);
      expect(modifierGroupViolation(pickTwoToFour, 5), 'max');
    });

    test('single-choice is what decides radios versus checkboxes', () {
      expect(mandatory.isSingleChoice, isTrue);
      expect(pickTwoToFour.isSingleChoice, isFalse);
      expect(optional.isSingleChoice, isTrue,
          reason: 'optional pick-one is still a radio, just a clearable one');
    });

    test('mandatory is exactly "min > 0"', () {
      expect(optional.isMandatory, isFalse);
      expect(mandatory.isMandatory, isTrue);
      expect(pickTwoToFour.isMandatory, isTrue);
    });
  });
}
