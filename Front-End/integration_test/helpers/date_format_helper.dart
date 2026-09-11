/// `setDateFormat` / `expectDatesFollow` — proving one setting drives every date.
///
/// ```dart
/// final was = await setDateFormat(tester, ctx, 'yyyy-MM-dd');
/// await expectDatesFollow(tester, ctx, pattern: 'yyyy-MM-dd', where: 'Sales History');
/// ```
///
/// ## What this can prove that a unit test cannot
///
/// `test/app_date_format_test.dart` already proves `AppDateFormat` formats
/// correctly, falls back safely, exempts ISO output and handles the timezone.
/// All of that passes perfectly **while a screen ignores the class entirely** —
/// and that was the actual bug: seven screens never called a formatter at all.
/// They built the date by hand:
///
/// ```dart
/// '${_pad(d.day)}/${_pad(d.month)}/${d.year} ${_pad(d.hour)}:${_pad(d.minute)}'
/// ```
///
/// A search for `DateFormat` cannot see that, and neither can a unit test of the
/// formatter. Only reading the REAL screen can.
///
/// ## 🚨 One pattern is not enough
///
/// Asserting that Sales History shows `2026-09-01` while the setting is
/// `yyyy-MM-dd` proves nothing: a screen hardcoded to ISO passes it. The setting
/// has to be changed to a DIFFERENT shape and the screen re-read, so the only
/// way to satisfy both assertions is to actually follow the setting.
///
/// That is why [expectDatesFollow] also fails on a CONFLICTING shape rather than
/// merely requiring a matching one. A hand-rolled `01/09/2026` sitting beside a
/// correct `2026-09-01` is exactly the half-migrated state this test exists for.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/settings/settings_screen.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// The shapes the four offered patterns produce, as they appear on screen.
///
/// 🚨 `dd/MM/yyyy` and `MM/dd/yyyy` are the SAME shape — both are `NN/NN/NNNN`
/// and only the meaning of the first pair differs. Telling them apart on screen
/// would mean knowing the exact date of a row, which a test that did not create
/// that row cannot. So this test switches between shapes that ARE
/// distinguishable, and the day/month ordering is left to
/// `app_date_format_test.dart`, which can construct the input.
enum DateShape {
  /// `2026-09-01` — from `yyyy-MM-dd`.
  iso(r'\b\d{4}-\d{2}-\d{2}\b'),

  /// `01/09/2026` — from `dd/MM/yyyy` or `MM/dd/yyyy`.
  slashed(r'\b\d{2}/\d{2}/\d{4}\b'),

  /// `01-09-2026` — from `dd-MM-yyyy`.
  dashed(r'\b\d{2}-\d{2}-\d{4}\b');

  const DateShape(this.pattern);
  final String pattern;

  RegExp get regex => RegExp(pattern);

  /// The shape a chosen setting should produce.
  static DateShape of(String setting) => switch (setting) {
        'yyyy-MM-dd' => DateShape.iso,
        'dd-MM-yyyy' => DateShape.dashed,
        _ => DateShape.slashed,
      };
}

/// Sets `Application.DateFormat` and returns what it was before.
///
/// The previous value is returned so a caller can put it back — this is a
/// COMPANY setting, so a test that walks away having changed it has changed
/// every screen on every terminal of that shop.
Future<String> setDateFormat(
  WidgetTester tester,
  E2EContext ctx,
  String pattern,
) async {
  final before = ctx.container.read(appSettingsProvider)[SettingKeys.dateFormat];

  await openQuickSettings(tester, ctx);

  // The General tab's control is a dropdown carrying the label, so the ordinary
  // picker works — unlike the search-results variant of the same setting,
  // which is a compact dropdown with no label at all.
  await pickDropdown(tester, ctx.l.dateFormatLabel, pattern);

  // 🚨 Wait for the SETTING, not for the dropdown to look right. The write goes
  // through the settings notifier and the screens rebuild off the provider, so
  // the control showing the new value is a frame ahead of the app agreeing.
  await waitUntil(
    tester,
    () async =>
        ctx.container.read(appSettingsProvider)[SettingKeys.dateFormat] ==
        pattern,
    describe: 'the company setting becomes $pattern',
    timeout: const Duration(seconds: 60),
  );

  await leaveQuickSettings(tester, ctx);

  ctx.record(E2EArtifact(
    table: 'Setting',
    name: SettingKeys.dateFormat,
    extra: {'Value': pattern, 'Was': before},
  ));
  step('Date format: ${before ?? '(unset)'} -> $pattern');

  // 🚨 The default is returned when the company had never written the key, so a
  // caller restoring it puts back what the shop actually shows rather than an
  // empty string that would make every date fall back.
  return before ?? kSettingDefaults[SettingKeys.dateFormat] ?? 'dd/MM/yyyy';
}

/// Asserts every date visible on the current screen follows [pattern].
///
/// Two assertions, and both are needed:
///
///   * at least one date IS in the expected shape — otherwise a screen with no
///     dated rows at all would pass silently, which is the state a company with
///     no documents is in;
///   * NO date is in a conflicting shape — which is what catches a hand-rolled
///     one sitting beside a correct one.
void expectDatesFollow(
  WidgetTester tester,
  E2EContext ctx, {
  required String pattern,
  required String where,
}) {
  final expected = DateShape.of(pattern);
  final texts = visibleTexts(tester);

  final matching = expected.regex.allMatches(texts).map((m) => m[0]!).toSet();

  expect(
    matching,
    isNotEmpty,
    reason: '$where shows no date in the "$pattern" shape at all.\n'
        '  Either the screen has no dated rows on this company — run the chain '
        'so there is a document to look at — or it is not following the '
        'setting.\n'
        '  On screen now: $texts',
  );

  for (final other in DateShape.values) {
    if (other == expected) continue;

    // 🚨 ISO is a SUBSTRING risk in reverse: `01-09-2026` contains no 4-digit
    // leading group, and `2026-09-01` contains no 2-digit leading group, so the
    // two dash shapes cannot match each other. Checked explicitly all the same,
    // because the cost of being wrong here is a silent pass.
    final strays = other.regex.allMatches(texts).map((m) => m[0]!).toSet();
    expect(
      strays,
      isEmpty,
      reason: '$where is showing ${other.name}-shaped dates ($strays) while the '
          'company setting is "$pattern".\n'
          '  That is a date built by hand rather than through '
          '`appDateFormatProvider` — the exact bug this test exists for.\n'
          '  Correctly formatted dates on the same screen: $matching',
    );
  }

  step('$where: ${matching.length} date(s) follow "$pattern" '
      '(${matching.take(3).join(', ')})');
}

/// Opens the till's Quick Settings.
Future<void> openQuickSettings(WidgetTester tester, E2EContext ctx) async {
  if (find.byType(SettingsScreen).evaluate().isNotEmpty) return;

  await exitManagement(tester, ctx.l);
  await openSidebar(tester);

  // By WIDGET, never a bare `find.byIcon(Icons.tune)` — `MenuScreen` draws the
  // same icon on its (disabled) Modifiers button and comes first in tree order.
  await tapVisible(tester, sidebarIconButton(Icons.tune));
  await waitFor(
    tester,
    find.byType(SettingsScreen),
    timeout: const Duration(seconds: 60),
    because: 'Quick Settings did not open. A security key on '
        'SecurityKeys.settings will also look like this — 11 locks that rule and '
        'restores it, so a run that died mid-way leaves it admin-only.',
  );
  ctx.refreshL10n(tester);
}

/// Backs out of Quick Settings to the till.
Future<void> leaveQuickSettings(WidgetTester tester, E2EContext ctx) async {
  if (find.byType(SettingsScreen).evaluate().isEmpty) return;
  await tester.pageBack();
  await waitForGone(
    tester,
    find.byType(SettingsScreen),
    timeout: const Duration(seconds: 30),
  );
  await pumpFor(tester, const Duration(seconds: 1));
  ctx.refreshL10n(tester);
}
