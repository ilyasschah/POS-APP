// Pins the settings sidebar's LAYOUT across every shipped locale.
//
// Why this file exists: the pinned "Save & Restart" action was a bare Row with
// an unwrapped Text, inside a hardcoded 211px panel. That is fine in English
// ("Save & Restart") and Arabic ("حفظ وإعادة التشغيل"), and overflows by 29px in
// French ("Enregistrer et redémarrer"). `dart analyze` was clean, every test
// passed, and both builds succeeded — a RenderFlex overflow is invisible to all
// of them. It only showed up as a yellow-and-black stripe on screen.
//
// So the assertions here are deliberately per-locale: an English-only layout
// test would have passed against the broken code. The fix has two halves and
// both are pinned below —
//   1. settingsSidebarWidth() measures the locale's longest label, so French
//      gets a wider panel instead of a truncated one;
//   2. SettingsSaveAction wraps its label in Flexible + ellipsis, so even at
//      the clamp ceiling it shrinks rather than overflowing.
// Half 2 is the one that must never regress: it is the hard guarantee.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/settings/settings_screen.dart';

/// Every locale the app ships an `.arb` for. Reading it from the generated
/// class rather than hardcoding means a newly added language is covered the day
/// its `.arb` lands, instead of silently skipping these checks.
const _locales = AppLocalizations.supportedLocales;

/// Builds the real sidebar action at the real computed width. Both come from
/// `settings_screen.dart` — no cloned layout, or this test would drift away
/// from the widget it is meant to protect.
Future<double> _pumpAction(WidgetTester tester, Locale locale) async {
  late double width;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          width = settingsSidebarWidth(context);
          return Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      const Spacer(),
                      SettingsSaveAction(onTap: () {}),
                    ],
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          );
        },
      ),
    ),
  );
  return width;
}

void main() {
  testWidgets('the save action never overflows, in any shipped locale', (
    tester,
  ) async {
    for (final locale in _locales) {
      await _pumpAction(tester, locale);
      // A RenderFlex overflow throws during paint; takeException surfaces it.
      // This is the assertion that fails against the pre-fix code, for `fr`.
      expect(
        tester.takeException(),
        isNull,
        reason: 'sidebar action overflowed in ${locale.languageCode}',
      );
    }
  });

  testWidgets('the label stays inside the panel, in any shipped locale', (
    tester,
  ) async {
    for (final locale in _locales) {
      final width = await _pumpAction(tester, locale);
      final label = tester.getSize(
        find.byType(Text).first,
      );
      // 12+12 padding, 20 icon, 10 gap = 54 of chrome. The text is what is left.
      expect(
        label.width,
        lessThanOrEqualTo(width - 54),
        reason: 'label wider than its button in ${locale.languageCode}',
      );
    }
  });

  testWidgets('the panel widens for long locales but stays bounded', (
    tester,
  ) async {
    for (final locale in _locales) {
      final width = await _pumpAction(tester, locale);
      // Floor: the historical 210px panel + its 1px divider. Short locales must
      // not shrink the familiar layout.
      expect(width, greaterThanOrEqualTo(211));
      // Ceiling: a runaway translation must not eat the content pane on a
      // 1280x800 tablet.
      expect(
        width,
        lessThanOrEqualTo(340),
        reason: 'sidebar unbounded in ${locale.languageCode}',
      );
    }
  });

  testWidgets('French gets a wider panel than English — the actual bug', (
    tester,
  ) async {
    final en = await _pumpAction(tester, const Locale('en'));
    final fr = await _pumpAction(tester, const Locale('fr'));
    // "Enregistrer et redémarrer" is materially longer than "Save & Restart".
    // If this ever reads equal, the width went back to being hardcoded and the
    // French label is being truncated again.
    expect(
      fr,
      greaterThan(en),
      reason: 'French panel did not grow — width is no longer measured',
    );
  });
}
