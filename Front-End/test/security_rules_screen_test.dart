// The Security Rules screen, split out of the Users & Security tab bar.
//
// What is worth pinning here is everything the old tab got wrong:
//
//  * 🚨 the two Stock sub-rules are `Management.*` NAMES that belong under
//    Stock. The category test that catches them has to run before the
//    `startsWith('Management.')` one, and swapping those two lines silently
//    files "view cost prices" under Management — where an operator looking for
//    it in the Stock section will not find it;
//  * the grid was `FractionallySizedBox(widthFactor: 0.5)` — two columns on a
//    7" tablet and two on a 27" monitor. The count is now derived from the
//    width the section actually got;
//  * there was no way to find one rule among ~45 except reading all of them.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/ilyass_dropdown.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/security/security_key_model.dart';
import 'package:pos_app/security/security_key_provider.dart';
import 'package:pos_app/security/security_rules_screen.dart';

const _rules = <(String, int)>[
  // General
  ('Settings', 1),
  ('CashMovement', 0),
  // Sales
  ('Refund', 0),
  ('CashDrawer.Open', 1),
  ('Order.All', 0),
  // Management
  ('Management.Products', 0),
  // Stock — a `Management.` name that must NOT land under Management.
  ('Management.Stock.ShowCostPrices', 1),
];

void main() {
  late ProviderContainer container;

  List<SecurityKeyModel> keys() => [
        for (final (name, level) in _rules)
          SecurityKeyModel(name: name, level: level),
      ];

  setUp(() {
    container = ProviderContainer(
      overrides: [
        allSecurityKeysProvider.overrideWith((ref) => Stream.value(keys())),
      ],
    );
    container
        .read(selectedCompanyProvider.notifier)
        .update(Company(id: 1, name: 'Test'));
  });

  tearDown(() => container.dispose());

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1400, 900),
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en'), Locale('fr')],
          home: const SecurityRulesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // 🚨 Scoped to the search bar. Every rule tile carries a role dropdown, and a
  // Material 3 dropdown is built on a TextField too — a bare
  // `find.byType(TextField)` matches one per rule plus the search.
  final searchField = find.descendant(
    of: find.byType(UnifiedSearchBar),
    matching: find.byType(TextField),
  );

  testWidgets('every rule is on screen, under its own section', (tester) async {
    // Tall enough that all four sections are laid out at once — a ListView
    // does not build what is below the fold, and Stock is the last section.
    await pump(tester, size: const Size(1400, 1600));

    for (final section in ['General', 'Sales', 'Management', 'Stock']) {
      expect(find.text(section), findsWidgets, reason: '$section section');
    }
    expect(find.text('Refund'), findsOneWidget);
    expect(find.text('Open cash drawer'), findsOneWidget);
  });

  testWidgets('a Management.Stock.* rule is filed under Stock', (tester) async {
    await pump(tester, size: const Size(1400, 1600));

    // Both sections are on screen, so proving the rule is in the right one
    // means comparing positions rather than presence: it must sit BELOW the
    // Stock heading, which is the last section drawn.
    final stockHeading = tester.getTopLeft(find.text('Stock')).dy;
    final managementHeading = tester.getTopLeft(find.text('Management')).dy;
    final rule = tester.getTopLeft(find.text('View cost prices')).dy;

    expect(managementHeading, lessThan(stockHeading));
    expect(rule, greaterThan(stockHeading));
  });

  testWidgets('the search finds a rule by its translated label',
      (tester) async {
    await pump(tester);

    await tester.enterText(searchField, 'refund');
    await tester.pumpAndSettle();

    expect(find.text('Refund'), findsOneWidget);
    expect(find.text('Open cash drawer'), findsNothing);
    expect(find.text('Quick inventory'), findsNothing);
  });

  testWidgets('the search also finds it by the raw key name', (tester) async {
    // The key is what the seeder, SecurityKeys and any support conversation
    // call the rule — and the only spelling that works in every language.
    await pump(tester);

    await tester.enterText(searchField, 'CashDrawer');
    await tester.pumpAndSettle();

    expect(find.text('Open cash drawer'), findsOneWidget);
    expect(find.text('Refund'), findsNothing);
  });

  testWidgets('a search that matches nothing says so', (tester) async {
    await pump(tester);

    await tester.enterText(searchField, 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('No results for these filters'), findsOneWidget);
    expect(find.text('"zzzz"'), findsOneWidget);
  });

  testWidgets('the role picker is never narrower than its own words',
      (tester) async {
    // 🚨 Two bugs this pins. First a SegmentedButton given a fifth of the tile
    // wrapped its words one character per line ("Ca sh ie r"). Then a dropdown
    // in a fixed 150/178px box: that fits "Admin" but not "Administrateur", and
    // a dropdown field does not ellipsize — it SCROLLS the text inside itself,
    // so the French till read "Administra" with no sign anything was hidden.
    // The picker is sized by its longest option and measured before the label.
    for (final size in const [Size(1400, 1600), Size(420, 1600)]) {
      await pump(tester, size: size, locale: const Locale('fr'));

      final fields = find.descendant(
        of: find.byType(IlyassDropdown<int>),
        matching: find.byType(EditableText),
      );
      final count = fields.evaluate().length;
      expect(count, _rules.length, reason: 'one role picker per rule');

      for (var i = 0; i < count; i++) {
        final editable =
            tester.state<EditableTextState>(fields.at(i)).renderEditable;
        expect(editable.maxScrollExtent, 0,
            reason: '${size.width}px window: "${editable.text?.toPlainText()}" '
                'is scrolled inside its own field');
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the column count comes from the width, not a breakpoint',
      (tester) async {
    const tile = ValueKey('security-rule-Refund');

    await pump(tester, size: const Size(1400, 900));
    final wide = tester.getSize(find.byKey(tile)).width;

    await pump(tester, size: const Size(700, 900));
    final narrow = tester.getSize(find.byKey(tile)).width;

    // 🚨 The old grid was a fixed widthFactor: 0.5, so this ratio was 2.0 at
    // every window size. One column at 700px; two inside the 1200px cap, where
    // a third would leave no room for a rule label beside the role picker.
    expect(narrow, greaterThan(600));
    expect(wide, inInclusiveRange(500, 620));
  });
}
