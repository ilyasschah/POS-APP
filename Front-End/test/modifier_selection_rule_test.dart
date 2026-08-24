// How a group's min/max pair is explained to whoever configures it.
//
// The pair is the ONLY selection rule modifiers have — optional, mandatory,
// pick-one, pick-many and pick-2-to-4 are all expressed as two numbers — so the
// sentence rendered from it is the whole of what the admin sees before saving.
// Getting min and max the wrong way round produces a group that reads correctly
// and behaves backwards: a mandatory section that lets the cashier skip it, or
// an optional one that blocks the sale.
//
// These also pin the three translations, because a locale silently falling back
// to English is invisible to the analyzer and to every other test here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/modifier/modifier_groups_screen.dart';
import 'package:pos_app/modifier/modifier_models.dart';

void main() {
  /// Renders the label for one min/max pair in [code].
  Future<String> label(
    WidgetTester tester, {
    required int min,
    required int max,
    String code = 'en',
  }) async {
    late String result;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            result = selectionRuleLabel(
              context,
              ModifierGroup(
                id: 1,
                name: 'Toppings',
                minSelections: min,
                maxSelections: max,
              ),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return result;
  }

  group('the four shapes a rule can take', () {
    testWidgets('0/1 is optional, pick one', (tester) async {
      expect(await label(tester, min: 0, max: 1), 'Optional · pick one');
    });

    testWidgets('0/N is optional, pick up to N', (tester) async {
      expect(await label(tester, min: 0, max: 3), 'Optional · pick up to 3');
    });

    testWidgets('1/1 is required, pick one', (tester) async {
      expect(await label(tester, min: 1, max: 1), 'Required · pick one');
    });

    testWidgets('2/4 is a required range', (tester) async {
      expect(await label(tester, min: 2, max: 4), 'Required · pick 2 to 4');
    });
  });

  group('the boundary between optional and required', () {
    testWidgets('min 0 always reads optional, whatever max says',
        (tester) async {
      for (final max in [1, 2, 10]) {
        expect(await label(tester, min: 0, max: max), startsWith('Optional'));
      }
    });

    testWidgets('any min above 0 always reads required', (tester) async {
      // The single most consequential branch: this is what tells the admin the
      // group will BLOCK the sale until it is answered.
      for (final min in [1, 2, 5]) {
        expect(await label(tester, min: min, max: 10), startsWith('Required'));
      }
    });

    testWidgets('1/N is required but not the "pick one" phrasing',
        (tester) async {
      // "Required · pick one" would be a lie here — the cashier may pick more.
      expect(await label(tester, min: 1, max: 3), 'Required · pick 1 to 3');
    });
  });

  group('the model agrees with the sentence', () {
    test('isMandatory is exactly min > 0', () {
      expect(
        const ModifierGroup(id: 1, name: 'x', minSelections: 0).isMandatory,
        isFalse,
      );
      expect(
        const ModifierGroup(id: 1, name: 'x', minSelections: 1).isMandatory,
        isTrue,
      );
    });

    test('isSingleChoice is what picks radios over checkboxes', () {
      expect(
        const ModifierGroup(id: 1, name: 'x', maxSelections: 1).isSingleChoice,
        isTrue,
      );
      expect(
        const ModifierGroup(id: 1, name: 'x', maxSelections: 2).isSingleChoice,
        isFalse,
      );
    });
  });

  group('the rule is translated, not falling back to English', () {
    testWidgets('French', (tester) async {
      expect(await label(tester, min: 0, max: 1, code: 'fr'),
          'Facultatif · un seul');
      expect(await label(tester, min: 1, max: 1, code: 'fr'),
          'Obligatoire · un seul');
      expect(await label(tester, min: 2, max: 4, code: 'fr'),
          'Obligatoire · de 2 à 4');
    });

    testWidgets('Arabic', (tester) async {
      expect(await label(tester, min: 0, max: 1, code: 'ar'),
          'اختياري · خيار واحد');
      expect(await label(tester, min: 1, max: 1, code: 'ar'),
          'إلزامي · خيار واحد');
    });

    testWidgets('the choice count is pluralised per locale', (tester) async {
      // A plural rule that silently falls back reads "1 choices" on a receipt-
      // adjacent screen, which is the sort of thing customers notice first.
      late AppLocalizations fr;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(builder: (context) {
            fr = AppLocalizations.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(fr.optionCount(0), 'aucun choix');
      expect(fr.optionCount(1), '1 choix');
      expect(fr.optionCount(4), '4 choix');
    });
  });
}
