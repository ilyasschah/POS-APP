// The sheet a cashier drives mid-sale, with a queue behind them.
//
// Every one of these is about a wrong sale rather than a wrong pixel: a
// cancelled sheet that still adds the item, a mandatory group that lets itself
// be skipped, a pick-many group that accepts one more than it should, or a
// confirm button that greys out without saying which section is blocking.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/modifier/customize_item_sheet.dart';
import 'package:pos_app/modifier/modifier_models.dart';

class _FakeSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {...kSettingDefaults};
}

void main() {
  ModifierOption opt(int id, String name, [double price = 0]) =>
      ModifierOption(
          id: id, modifierGroupId: 1, name: name, additionalPrice: price);

  ModifierGroup toppings({int min = 0, int max = 2}) => ModifierGroup(
        id: 1,
        name: 'Toppings',
        minSelections: min,
        maxSelections: max,
        options: [
          opt(1, 'Extra Cheese', 3),
          opt(2, 'Extra Tomato', 3),
          opt(3, 'Big Frise', 4),
        ],
      );

  Future<void> pumpSheet(
    WidgetTester tester, {
    required List<ModifierGroup> groups,
    double basePrice = 42,
    List<SelectedModifier> initial = const [],
    void Function(CustomizeResult?)? onResult,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsProvider.overrideWith(_FakeSettings.new)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final r = await showCustomizeItemSheet(
                      context,
                      itemName: 'Cheeseburger',
                      basePrice: basePrice,
                      groups: groups,
                      initial: initial,
                    );
                    onResult?.call(r);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('it opens with the right shape', () {
    testWidgets('the item name and every choice are on screen', (t) async {
      await pumpSheet(t, groups: [toppings()]);

      expect(find.text('Cheeseburger'), findsOneWidget);
      expect(find.text('Toppings'), findsOneWidget);
      expect(find.text('Extra Cheese'), findsOneWidget);
      expect(find.text('Big Frise'), findsOneWidget);
    });

    testWidgets('the running total starts at the base price', (t) async {
      await pumpSheet(t, groups: [toppings()]);
      expect(find.textContaining('42.00'), findsOneWidget);
    });

    testWidgets('an optional group is tagged Optional, not Required',
        (t) async {
      await pumpSheet(t, groups: [toppings()]);

      expect(find.textContaining('Optional'), findsOneWidget);
      expect(find.textContaining('Required'), findsNothing);
    });

    testWidgets('a mandatory group is tagged Required up front', (t) async {
      // A pick-MANY mandatory group has no default, so it opens unsatisfied.
      await pumpSheet(t, groups: [toppings(min: 2, max: 3)]);
      expect(find.textContaining('Required'), findsOneWidget);
    });

    testWidgets('nothing is flagged in error before a confirm is attempted',
        (t) async {
      // Red sections on open read as a mistake the cashier has not made yet.
      await pumpSheet(t, groups: [toppings(min: 2, max: 3)]);
      expect(find.textContaining('Choose at least'), findsNothing);
    });

    testWidgets('a free choice shows no price at all', (t) async {
      // "+0.00" beside "No Sugar" is noise read past on every single sale.
      await pumpSheet(t, groups: [
        ModifierGroup(id: 1, name: 'Sugar', options: [opt(1, 'No Sugar')])
      ]);

      expect(find.text('No Sugar'), findsOneWidget);
      expect(find.textContaining('0.00'), findsNothing);
    });
  });

  group('choosing', () {
    testWidgets('the total follows what was tapped', (t) async {
      await pumpSheet(t, groups: [toppings()]);

      await t.tap(find.text('Extra Cheese'));
      await t.pumpAndSettle();

      expect(find.textContaining('45.00'), findsOneWidget);
    });

    testWidgets('a second choice adds again', (t) async {
      await pumpSheet(t, groups: [toppings()]);

      await t.tap(find.text('Extra Cheese'));
      await t.pumpAndSettle();
      await t.tap(find.text('Big Frise'));
      await t.pumpAndSettle();

      expect(find.textContaining('49.00'), findsOneWidget);
    });

    testWidgets('tapping a chosen option in a pick-many clears it', (t) async {
      await pumpSheet(t, groups: [toppings()]);

      await t.tap(find.text('Extra Cheese'));
      await t.pumpAndSettle();
      await t.tap(find.text('Extra Cheese'));
      await t.pumpAndSettle();

      expect(find.textContaining('42.00'), findsOneWidget);
    });

    testWidgets('a pick-one group swaps rather than accumulating', (t) async {
      await pumpSheet(t, groups: [toppings(max: 1)]);

      await t.tap(find.text('Extra Cheese'));
      await t.pumpAndSettle();
      await t.tap(find.text('Big Frise'));
      await t.pumpAndSettle();

      // 42 + 4, not 42 + 3 + 4.
      expect(find.textContaining('46.00'), findsOneWidget);
    });

    testWidgets('the counter tracks a pick-many group live', (t) async {
      await pumpSheet(t, groups: [toppings()]);
      expect(find.textContaining('0/2'), findsOneWidget);

      await t.tap(find.text('Extra Cheese'));
      await t.pumpAndSettle();

      expect(find.textContaining('1/2'), findsOneWidget);
    });

    testWidgets('a satisfied group flips to Done', (t) async {
      // The signature: the status rail answers "is this complete?" at a glance.
      await pumpSheet(t, groups: [toppings(min: 1, max: 2)]);
      expect(find.textContaining('Required'), findsOneWidget);

      await t.tap(find.text('Extra Cheese'));
      await t.pumpAndSettle();

      expect(find.textContaining('Done'), findsOneWidget);
      expect(find.textContaining('Required'), findsNothing);
    });

    testWidgets('a mandatory pick-one opens already answered', (t) async {
      // Saves a tap on every sale, and the group is Done from the start.
      await pumpSheet(t, groups: [toppings(min: 1, max: 1)]);

      expect(find.textContaining('Done'), findsOneWidget);
      expect(find.textContaining('45.00'), findsOneWidget);
    });
  });

  group('the rules are enforced, not suggested', () {
    testWidgets('confirming an unmet group names it instead of closing',
        (t) async {
      CustomizeResult? result;
      var called = false;
      await pumpSheet(
        t,
        groups: [toppings(min: 2, max: 3)],
        onResult: (r) {
          result = r;
          called = true;
        },
      );

      await t.tap(find.text('Add to order'));
      await t.pumpAndSettle();

      expect(called, isFalse, reason: 'the sheet must stay open');
      expect(result, isNull);
      expect(find.textContaining('Choose at least 2'), findsOneWidget);
    });

    testWidgets('it closes once the rule is met', (t) async {
      CustomizeResult? result;
      await pumpSheet(
        t,
        groups: [toppings(min: 2, max: 3)],
        onResult: (r) => result = r,
      );

      await t.tap(find.text('Extra Cheese'));
      await t.pumpAndSettle();
      await t.tap(find.text('Big Frise'));
      await t.pumpAndSettle();
      await t.tap(find.text('Add to order'));
      await t.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.modifiers.map((m) => m.name),
          ['Extra Cheese', 'Big Frise']);
    });

    testWidgets('a pick-many group refuses one past its limit', (t) async {
      await pumpSheet(t, groups: [toppings(max: 2)]);

      await t.tap(find.text('Extra Cheese'));
      await t.pumpAndSettle();
      await t.tap(find.text('Extra Tomato'));
      await t.pumpAndSettle();
      await t.tap(find.text('Big Frise'));
      await t.pumpAndSettle();

      // 42 + 3 + 3, with Big Frise refused.
      expect(find.textContaining('48.00'), findsOneWidget);
    });

    testWidgets('an already-chosen option stays live at the limit', (t) async {
      // Otherwise a full group can only be cleared, never changed.
      await pumpSheet(t, groups: [toppings(max: 2)]);

      await t.tap(find.text('Extra Cheese'));
      await t.pumpAndSettle();
      await t.tap(find.text('Extra Tomato'));
      await t.pumpAndSettle();
      await t.tap(find.text('Extra Cheese'));
      await t.pumpAndSettle();

      expect(find.textContaining('45.00'), findsOneWidget);
    });
  });

  group('backing out', () {
    testWidgets('Cancel adds NOTHING', (t) async {
      // A cancelled sheet that still added the plain item would be a sale
      // nobody asked for.
      CustomizeResult? result;
      var called = false;
      await pumpSheet(
        t,
        groups: [toppings()],
        onResult: (r) {
          result = r;
          called = true;
        },
      );

      await t.tap(find.text('Extra Cheese'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();

      expect(called, isTrue);
      expect(result, isNull);
    });
  });

  group('re-editing a line already in the cart', () {
    testWidgets('it opens with the previous choices selected', (t) async {
      await pumpSheet(
        t,
        groups: [toppings()],
        initial: const [
          SelectedModifier(
              modifierOptionId: 1, name: 'Extra Cheese', additionalPrice: 3),
        ],
      );

      expect(find.textContaining('45.00'), findsOneWidget);
      expect(find.textContaining('1/2'), findsOneWidget);
    });
  });

  group('the note only appears when a group asks for it', () {
    testWidgets('absent by default', (t) async {
      await pumpSheet(t, groups: [toppings()]);
      expect(find.textContaining('Note for the kitchen'), findsNothing);
    });

    testWidgets('present when the group allows free text', (t) async {
      await pumpSheet(t, groups: [
        ModifierGroup(
          id: 1,
          name: 'Toppings',
          allowsFreeText: true,
          options: [opt(1, 'Extra Cheese', 3)],
        )
      ]);

      expect(find.textContaining('Note for the kitchen'), findsOneWidget);
    });

    testWidgets('what is typed comes back with the result', (t) async {
      CustomizeResult? result;
      await pumpSheet(
        t,
        groups: [
          ModifierGroup(
            id: 1,
            name: 'Toppings',
            allowsFreeText: true,
            options: [opt(1, 'Extra Cheese', 3)],
          )
        ],
        onResult: (r) => result = r,
      );

      await t.enterText(find.byType(TextField), 'no ice');
      await t.tap(find.text('Add to order'));
      await t.pumpAndSettle();

      expect(result?.note, 'no ice');
    });
  });
}
