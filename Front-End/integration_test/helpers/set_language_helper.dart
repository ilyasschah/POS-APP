/// `setTerminalLanguage` — pins the terminal's UI language. A ONE-TIME setup.
///
/// ```dart
/// await loginToCompany(tester, ctx);
/// await setTerminalLanguage(tester, ctx, 'en');
/// ```
///
/// ## Why this is not part of `loginToCompany`
///
/// It writes the COMPANY's `Application.Language` setting, so it changes the
/// language for every terminal on that company and for the owner dashboard —
/// not just for this run. Doing that on every sign-in meant every test paid two
/// navigations and a settings write to set a value that was almost always
/// already correct.
///
/// It does not need to run per-test either, and that is the deeper point: the
/// helpers never hardcode a UI string. They read `ctx.l`, so they follow
/// whatever language the app is actually in. Pinning the language is a
/// convenience for a HUMAN watching the run, not a requirement of the finders.
///
/// Run `set_language_test.dart` once against a terminal and leave it alone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/settings/settings_screen.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Switches the terminal to [languageCode] ('en', 'fr' or 'ar').
///
/// Returns without touching anything when the app is already in that language,
/// which is the common case.
Future<void> setTerminalLanguage(
  WidgetTester tester,
  E2EContext ctx,
  String languageCode,
) async {
  _optionFor(languageCode); // Fail on a bad code before navigating anywhere.

  // 🚨 Settle the locale BEFORE deciding anything, because it is still moving.
  //
  // The terminal renders the PIN screen in whatever language it had cached, and
  // the company's real `Application.Language` arrives with the post-sign-in
  // sync. So a check made at sign-in is made against a value that is about to
  // change — which is how this helper failed with `No dropdown labelled
  // "Langue"` while the screen plainly read `ENGLISH | Language`: the terminal
  // had already become English and the run was still holding French.
  final settled = await waitForStableLocale(tester);
  ctx.refreshL10n(tester);

  if (settled == languageCode) {
    step('Language already $settled — nothing to change');
    return;
  }

  await openSidebar(tester);

  // 🚨 By WIDGET TYPE, not by tooltip and not by icon alone.
  //
  // The tooltip is translated, so reaching for it with a cached `ctx.l` is the
  // same class of bug this helper exists to fix. But a bare
  // `find.byIcon(Icons.tune)` is ambiguous too: `MenuScreen`'s Modifiers button
  // carries the same icon, comes FIRST in tree order, and is disabled while the
  // cart is empty — so `.first` taps a dead control and nothing happens.
  //
  // That bug sat here unnoticed because this helper returns early whenever the
  // language is already correct, which it was on every company it had met.
  await tapVisible(tester, sidebarIconButton(Icons.tune));
  await waitFor(
    tester,
    find.byType(SettingsScreen),
    timeout: const Duration(seconds: 60),
    because: 'Quick Settings did not open. A security key on '
        'SecurityKeys.settings will also look like this.',
  );

  // 🚨 Re-read ON THE SETTINGS SCREEN, immediately before using its labels.
  // Anything read before this navigation describes a screen that is no longer
  // the one being driven.
  ctx.refreshL10n(tester);

  // Re-checked after the refresh, not only at the top. If the locale resolved
  // while we were navigating, the work is already done and touching the dropdown
  // would be a pointless write to the company's settings.
  if (ctx.l.localeName == languageCode) {
    step('Language resolved to $languageCode on the way here — leaving it');
    await _leaveSettings(tester, ctx);
    return;
  }

  // The options are rendered each in ITS OWN language ("ENGLISH", "FRANÇAIS"),
  // never in the current one, so these literals are correct where a translated
  // lookup would be wrong.
  await pickDropdown(tester, ctx.l.languageLabel, _optionFor(languageCode));
  await pumpFor(tester, const Duration(seconds: 2));

  // Re-read again: everything from here on is in the NEW language.
  ctx.refreshL10n(tester);
  expect(
    ctx.l.localeName,
    languageCode,
    reason: 'The language dropdown did not take effect',
  );
  step('Language switched to ${ctx.l.localeName}');

  await _leaveSettings(tester, ctx);
}

/// Backs out of Quick Settings and re-reads the translations behind it.
Future<void> _leaveSettings(WidgetTester tester, E2EContext ctx) async {
  await tester.pageBack();
  await waitFor(tester, find.byType(MainLayout));
  ctx.refreshL10n(tester);
}

/// The label the language picker shows for a locale code.
String _optionFor(String code) => switch (code) {
      'en' => 'ENGLISH',
      'fr' => 'FRANÇAIS',
      'ar' => 'العربية',
      _ => throw ArgumentError(
          'No language option for "$code" — the app ships en, fr and ar.'),
    };
