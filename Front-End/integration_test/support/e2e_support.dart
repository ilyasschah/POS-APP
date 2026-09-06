/// Shared plumbing for the end-to-end integration tests: the company being
/// signed in as, and the waiting primitives a real-network test needs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_app/auth/login_screen.dart';
import 'package:pos_app/auth/master_login_screen.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/sync/sync_button.dart';

import '../config/test_config.dart';

/// One company as the Cypress admin-portal suite recorded it.
class E2ECompany {
  const E2ECompany({
    required this.companyId,
    required this.companyName,
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
  });

  final int companyId;
  final String companyName;

  /// 🚨 The login identity is the EMAIL, not the username. `/Auth/Login` looks
  /// the user up with `GetByEmailAnyCompanyAsync`, which matches on `Email`
  /// across every company with no company scoping.
  final String email;
  final String password;
  final String firstName;
  final String lastName;

  /// What the user card on the PIN screen is labelled with — `User.displayName`
  /// prefers the full name and falls back to the username.
  String get displayName => '$firstName $lastName'.trim();

  static E2ECompany fromJson(Map<String, dynamic> j) => E2ECompany(
        companyId: j['companyId'] as int,
        companyName: j['companyName'] as String,
        email: j['userEmail'] as String,
        password: j['userPassword'] as String,
        firstName: (j['firstName'] as String?) ?? '',
        lastName: (j['lastName'] as String?) ?? '',
      );
}

/// Loads the company to sign in as from the Cypress suite's output.
///
/// The two suites are joined by this file and nothing else: Cypress provisions
/// a real company through the admin portal and writes its login here; this test
/// picks it up and proves the till can actually use it.
E2ECompany loadE2ECompany() {
  final file = File(kCredentialsPath);

  if (!file.existsSync()) {
    throw StateError(
      'No credentials at ${file.absolute.path}\n'
      'That file is written by the Cypress suite. Create a company first:\n'
      '    cd e2e && npm run test:company\n',
    );
  }

  final raw = jsonDecode(file.readAsStringSync());
  if (raw is! List || raw.isEmpty) {
    throw StateError('No companies recorded in ${file.absolute.path}');
  }

  final entries = raw.cast<Map<String, dynamic>>();

  if (kCompanyId == null) {
    // Newest first — saveCredentials unshifts each new run onto the front.
    return E2ECompany.fromJson(entries.first);
  }

  final match = entries.where((e) => e['companyId'] == kCompanyId);
  if (match.isEmpty) {
    throw StateError(
      'No company $kCompanyId in ${file.absolute.path}. Recorded: '
      '${entries.map((e) => e['companyId']).join(', ')}',
    );
  }
  return E2ECompany.fromJson(match.first);
}

/// The company this terminal is CURRENTLY linked to, or null if unregistered.
///
/// 🚨 Not the same thing as "the newest company in the credentials file", and
/// confusing the two is a trap. The Cypress suite writes a new entry every time
/// it provisions a company, but the terminal stays linked to whichever one
/// `login_new_company` last registered against — so the moment Cypress runs
/// again, "newest in the file" and "the company on this machine" are different
/// companies, and a test that signs in as the former finds no user card at all.
///
/// The key is AuthStorage's private `_keyCompanyId`; it is spelled out here
/// because that is the one detail these tests need and cannot import.
Future<int?> linkedCompanyId() async =>
    (await SharedPreferences.getInstance()).getInt('company_id');

/// The recorded company matching this terminal's current registration.
///
/// Falls back to the newest entry when the terminal is not registered at all,
/// which is what `login_new_company` wants — it is about to register one.
Future<E2ECompany> loadLinkedCompany() async {
  final id = await linkedCompanyId();
  if (id == null) return loadE2ECompany();

  final file = File(kCredentialsPath);
  final entries = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  final match = entries.where((e) => e['companyId'] == id);
  if (match.isEmpty) {
    throw StateError(
      'This terminal is linked to company $id, but that company is not in\n'
      '${file.absolute.path}\n'
      'Recorded: ${entries.map((e) => e['companyId']).join(', ')}\n'
      'Re-link the terminal to a recorded company:\n'
      '    flutter test integration_test/login_new_company_test.dart -d windows\n',
    );
  }
  return E2ECompany.fromJson(match.first);
}

/// The running app's own translations.
///
/// 🚨 Do NOT hardcode UI strings in this test. The app ships English, French and
/// Arabic, and picks its locale from the company's `Application.Language`
/// setting — which means the SAME test run can be in a different language on a
/// different company. A test written against "Next" simply fails on a French
/// terminal, with "Suivante" on screen and nothing wrong with the app.
///
/// Reading the delegate out of the live widget tree makes every finder follow
/// whatever language the app actually chose.
AppLocalizations l10nOf(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

/// Every non-empty Text on screen, for a failure message.
///
/// A Flutter finder that misses says only what it wanted, never what was there,
/// which turns "No element" into a guessing game about which screen the app was
/// actually on. Printing the labels makes the answer obvious.
String visibleTexts(WidgetTester tester) {
  final seen = <String>{};
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final data = t.data?.trim();
    if (data != null && data.isNotEmpty) seen.add(data);
  }
  return seen.isEmpty ? '(no text on screen)' : seen.join(' | ');
}

/// Pumps until [finder] matches, or fails with a message naming what it wanted.
///
/// 🚨 `pumpAndSettle` cannot be used anywhere in this test. It waits for the
/// widget tree to go completely idle, and this flow is never idle at the
/// moments that matter: the master-login button holds a `CircularProgressIndicator`
/// while it talks to the server, and the PIN screen spins through a sync. An
/// indeterminate spinner schedules a frame forever, so `pumpAndSettle` times out
/// on a screen that is working perfectly.
///
/// Pumping on a fixed interval and testing the finder each time is what lets a
/// test wait on a real network without lying about what it is waiting for.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 60),
  String? because,
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) {
      // One more frame so anything that appeared this tick is laid out before
      // the caller tries to tap it.
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
  }

  throw TestFailure(
    'Timed out after ${timeout.inSeconds}s waiting for: '
    '${finder.describeMatch(Plurality.many)}'
    '${because == null ? '' : '\n  $because'}'
    '\n  On screen now: ${visibleTexts(tester)}',
  );
}

/// Waits for [finder] to disappear — used to confirm a screen was left behind
/// rather than merely that the next one appeared on top of it.
Future<void> waitForGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 60),
  String? because,
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isEmpty) return;
  }

  throw TestFailure(
    'Timed out after ${timeout.inSeconds}s waiting for '
    '${finder.describeMatch(Plurality.many)} to disappear\n'
    '${because == null ? '' : '  $because\n'}'
    '  On screen now: ${visibleTexts(tester)}',
  );
}

/// Pumps until an ASYNCHRONOUS [condition] comes back true.
///
/// [waitFor] is the widget-tree version of this and covers most waits; this one
/// exists for the facts that are not on screen at all — a Drift row, a server
/// id stamped by a background sync. Those cannot be asserted the moment the UI
/// says the work is done: a checkout banks its rows and kicks off a sync that
/// finishes some seconds later, so "read it once and expect it" is a race that
/// passes on a fast machine and fails on a loaded one.
///
/// The condition is re-evaluated on an interval and its own exceptions are
/// swallowed as "not yet" — a query against a row that does not exist yet is
/// the normal first answer, not a failure.
Future<void> waitUntil(
  WidgetTester tester,
  Future<bool> Function() condition, {
  required String describe,
  Duration timeout = const Duration(seconds: 60),
  Duration interval = const Duration(milliseconds: 500),
}) async {
  final deadline = DateTime.now().add(timeout);
  Object? lastError;

  while (DateTime.now().isBefore(deadline)) {
    try {
      if (await condition()) return;
    } catch (e) {
      lastError = e;
    }
    // Keep pumping while waiting: the app is still running, and a condition
    // that depends on a provider or an in-flight request needs frames to
    // progress.
    await pumpFor(tester, interval);
  }

  throw TestFailure(
    'Timed out after ${timeout.inSeconds}s waiting until $describe'
    '${lastError == null ? '' : '\n  Last error: $lastError'}'
    '\n  On screen now: ${visibleTexts(tester)}',
  );
}

/// Settles briefly without the forever-wait of `pumpAndSettle`.
Future<void> pumpFor(
  WidgetTester tester, [
  Duration duration = const Duration(seconds: 1),
]) async {
  final deadline = DateTime.now().add(duration);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Scrolls [finder] into view when it is inside a scroll view, then taps it.
///
/// The onboarding slides are `SingleChildScrollView`s and a short window puts
/// the lower controls off-screen, where `tester.tap` throws instead of
/// scrolling to them.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // ensureVisible would throw a bare "Bad state: No element" here, naming
    // neither the target nor the screen it was looking at.
    throw TestFailure(
      'Nothing to tap for: ${finder.describeMatch(Plurality.many)}\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }
  // `.first` throughout. A label is rarely unique in this app — a FAB and an
  // empty-state button can offer the same "New Group", and a management rail
  // keeps its label rendered while the screen it opened shows the same word as
  // a heading. `ensureVisible` and `tap` both demand exactly one match and
  // throw a bare "Bad state: Too many elements" otherwise, naming nothing.
  // Taking the first match is what the operator's eye does too.
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(finder.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 400));
}

/// Taps [nextLabel] until [target] is on screen.
///
/// 🚨 Counting slides does not work. The onboarding controls are a PERSISTENT
/// bar below the PageView, so the "Next" label is present on every slide — a
/// `waitFor(Next)` returns instantly whether or not the page actually turned,
/// and a fixed number of taps silently lands on the wrong slide the moment a
/// slide is added, removed, or advances itself. (The data-source slide does
/// exactly that: choosing "sync with the cloud" calls `_next` as its handler.)
///
/// Advancing until the destination is visible is stable against all of it.
Future<void> advanceUntil(
  WidgetTester tester,
  Finder target,
  String nextLabel, {
  int maxTaps = 10,
}) async {
  for (var i = 0; i < maxTaps; i++) {
    if (target.evaluate().isNotEmpty) return;

    final next = find.text(nextLabel);
    if (next.evaluate().isEmpty) {
      throw TestFailure(
        'Ran out of "$nextLabel" before reaching '
        '${target.describeMatch(Plurality.many)}\n'
        '  On screen now: ${visibleTexts(tester)}',
      );
    }

    await tapVisible(tester, next);
    // A PageView transition is ~300ms; give it room to land before the next
    // look, or two taps land on the same slide and the page count drifts.
    await pumpFor(tester, const Duration(milliseconds: 800));
  }

  if (target.evaluate().isEmpty) {
    throw TestFailure(
      'Tapped "$nextLabel" $maxTaps times without reaching '
      '${target.describeMatch(Plurality.many)}\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }
}

/// Prints a labelled step so a watched run reads as a narrative rather than a
/// wall of frames.
void step(String message) => debugPrint('  ▶ $message');

// ─────────────────────────────────────────────────────────────────────────────
// Fake data
// ─────────────────────────────────────────────────────────────────────────────

/// A run tag stamped into every generated name and code.
///
/// Two jobs. It makes a row traceable back to the run that created it, and it
/// keeps codes UNIQUE — `Tax.Code` carries `UQ_Tax_Code_PerCompany`, and the
/// product code is checked the same way, so a fixed literal would pass once and
/// then fail every re-run with a uniqueness error that reads like a bug.
final String kRunTag =
    DateTime.now().toIso8601String().substring(5, 16).replaceAll(RegExp(r'[-:T]'), '');

/// A short numeric suffix for codes that must stay short.
final String kRunDigits = kRunTag.replaceAll(RegExp(r'\D'), '');

/// `Beverages [E2E 09052014]` — a name a human can spot in the till and in SQL.
String tagged(String base) => '$base [E2E $kRunTag]';

// ─────────────────────────────────────────────────────────────────────────────
// Form helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Types into the field carrying [label], scrolling it into view first.
///
/// Forms here are long and live inside dialogs that scroll, so a field below
/// the fold is the normal case rather than the exception — `enterText` on an
/// off-screen field silently does nothing useful.
Future<void> fillField(
  WidgetTester tester,
  String label,
  String value, {
  Finder? within,
}) async {
  var field = find.widgetWithText(TextFormField, label);
  if (field.evaluate().isEmpty) {
    field = find.widgetWithText(TextField, label);
  }
  if (within != null) {
    field = find.descendant(of: within, matching: field);
  }

  if (field.evaluate().isEmpty) {
    throw TestFailure(
      'No field labelled "$label"\n  On screen now: ${visibleTexts(tester)}',
    );
  }

  await tester.ensureVisible(field.first);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.enterText(field.first, value);
  await tester.pump(const Duration(milliseconds: 250));
}

/// Any `DropdownButtonFormField`, whatever its type argument.
///
/// 🚨 `find.byType` compares the EXACT runtime type, so
/// `find.byType(DropdownButtonFormField<Object?>)` matches neither the
/// `<int?>` used for a product group nor the `<String>` used for a setting —
/// it simply finds nothing, quietly. Matching on the type's name is the only
/// thing that works across all of them.
final Finder anyDropdownField = find.byWidgetPredicate(
  (w) => w.runtimeType.toString().startsWith('DropdownButtonFormField'),
);

/// Opens a [DropdownButtonFormField] by the label on its decoration and picks
/// the entry reading [optionText].
///
/// 🚨 The option is tapped with `.last`. An open dropdown paints its menu OVER
/// the button, and the button still shows the current selection — so when the
/// value being chosen is also the value already selected, the text matches
/// twice and `.first` hits the button underneath, closing the menu without
/// changing anything.
/// Locates a labelled dropdown, whichever way it is labelled.
///
/// Two shapes exist and only one is an ancestor relationship:
///   * tax and settings put the caption in the field's own `labelText`, so the
///     Text really is inside the dropdown;
///   * the group editor prints a section label ABOVE a dropdown whose
///     decoration is null, so the caption is a SIBLING that no ancestor search
///     will ever reach.
/// `within` covers the second: inside one dialog there is only one dropdown.
Finder findDropdown(String fieldLabel, {Finder? within}) {
  final byLabel = find.ancestor(
    of: find.text(fieldLabel),
    matching: anyDropdownField,
  );
  if (byLabel.evaluate().isNotEmpty) return byLabel;
  if (within != null) {
    return find.descendant(of: within, matching: anyDropdownField);
  }
  return byLabel;
}

/// Opens the dropdown and picks the option, VERIFYING that the selection took.
///
/// 🚨 The verification is not belt-and-braces, it is the whole point.
/// `tester.tap` does not fail when its hit-test misses — it prints a warning
/// ("tapping at that location may not hit it") and carries on. So a menu entry
/// that scrolled a few pixels out from under the tap leaves the dropdown on its
/// previous value, the test sails past, and the product is saved with no group
/// at all. That is exactly what happened: two products came out correct and the
/// third reached the database with ProductGroupId NULL, with nothing in the run
/// output to suggest anything had gone wrong.
Future<void> pickDropdown(
  WidgetTester tester,
  String fieldLabel,
  String optionText, {
  Finder? within,
  bool matchSubstring = false,
  int attempts = 3,
}) async {
  for (var attempt = 1; attempt <= attempts; attempt++) {
    await _pickDropdownOnce(
      tester, fieldLabel, optionText,
      within: within, matchSubstring: matchSubstring,
    );

    // 🚨 Read the selection back FROM INSIDE THE DROPDOWN, not from the screen.
    //
    // An unscoped `find.textContaining(optionText)` matches anything on the
    // page — including the products table BEHIND the dialog, whose Category
    // column shows exactly these group names. So this check passed while the
    // dropdown had not changed at all, and the product was saved with no group:
    // reproducibly the third one, because by then a previous product carrying
    // that same group was sitting in the filtered list behind the dialog.
    final shown = find.descendant(
      of: findDropdown(fieldLabel, within: within),
      matching: matchSubstring
          ? find.textContaining(optionText)
          : find.text(optionText),
    );
    if (shown.evaluate().isNotEmpty) return;

    if (attempt == attempts) {
      throw TestFailure(
        'Dropdown "$fieldLabel" would not stay on "$optionText" after '
        '$attempts attempts (the tap is missing the menu entry)\n'
        '  On screen now: ${visibleTexts(tester)}',
      );
    }
    await pumpFor(tester, const Duration(milliseconds: 500));
  }
}

Future<void> _pickDropdownOnce(
  WidgetTester tester,
  String fieldLabel,
  String optionText, {
  Finder? within,
  bool matchSubstring = false,
}) async {
  // 🚨 Matched by NAME, not by `find.byType`. These fields are generic —
  // `DropdownButtonFormField<int?>` for a group, `<String>` for a setting — and
  // `find.byType` compares the exact runtime type, so a guess at the type
  // argument silently matches nothing.
  //
  // That failure is quiet and misleading. The finder falls through to the
  // label's own Text, and a label like "Parent Folder" is ALSO a column header
  // on the table behind the dialog — so the tap lands on the header, the
  // dropdown never opens, and the error arrives one step later as "dropdown has
  // no option X" about a dropdown that was never opened.
  // Two shapes of "labelled dropdown" exist here and only one is an ancestor
  // relationship:
  //   * tax and settings put the caption in the field's own `labelText`, so the
  //     Text really is inside the dropdown;
  //   * the group editor prints a `_SectionLabel` ABOVE a dropdown whose
  //     decoration is null, so the caption is a SIBLING and no ancestor search
  //     will ever reach it.
  // `within` covers the second: inside one dialog there is only one dropdown.
  final dropdown = findDropdown(fieldLabel, within: within);

  if (dropdown.evaluate().isEmpty) {
    throw TestFailure(
      'No dropdown labelled "$fieldLabel"\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }
  final target = dropdown.first;

  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.tap(target, warnIfMissed: false);
  await pumpFor(tester, const Duration(milliseconds: 700));

  // 🚨 Some options are not spelled the way the caller knows them. The tax
  // picker renders "${name} (${rate}%)" from a DOUBLE, so a 20% tax created as
  // "20" comes back as "VAT 20% [E2E 0906] (20.0%)" — an exact match on the
  // name finds nothing. Substring matching lets the caller identify an option
  // by the part it actually controls.
  final optionText0 =
      matchSubstring ? find.textContaining(optionText) : find.text(optionText);

  // 🚨 Confine the search to the OPEN MENU.
  //
  // These option labels are not unique on screen. Picking a product's group
  // while the products table sits behind the dialog means "Beverages [E2E …]"
  // matches twice: once in the menu, once in that table's Category column. And
  // `.last` is not a safe tie-break — it picked the TABLE cell, so
  // `ensureVisible` scrolled the table, the tap landed on the modal barrier,
  // the menu closed, and the product was saved with no group at all.
  //
  // The menu is the most recently pushed scrollable on screen, so scoping to it
  // removes every match that is not really an option.
  // No fallback to the unscoped finder: when the option is merely off-screen
  // the scoped finder is empty too, and falling back would put the table cell
  // straight back in play. Scrolling the menu is what reveals it (below).
  final menu = find.byType(Scrollable).last;
  final option = find.descendant(of: menu, matching: optionText0);

  // 🚨 An unfound option usually means "off-screen", not "absent".
  //
  // The menu is a ListView, and a ListView builds only the range it is
  // showing — so an entry below the fold is not in the widget tree at all and
  // `find.text` reports it missing. That is indistinguishable from a genuinely
  // absent option until you scroll, and it gets likelier every run: these
  // tests leave their groups behind, so the list that fitted on one screen on
  // day one does not on day ten.
  if (option.evaluate().isEmpty) {
    try {
      await tester.scrollUntilVisible(
        option,
        200,
        scrollable: menu,
        maxScrolls: 100,
      );
    } catch (_) {
      throw TestFailure(
        'Dropdown "$fieldLabel" has no option "$optionText", '
        'and scrolling the menu did not reveal one\n'
        '  On screen now: ${visibleTexts(tester)}',
      );
    }
  }

  // 🚨 Scroll the item into view before tapping it, and do NOT silence a miss.
  //
  // An open dropdown is a scrollable menu. Once a company has a few dozen
  // groups the wanted entry is built but sits below the fold, and a tap at its
  // off-screen coordinates lands on the barrier instead — which closes the menu
  // AND, because `showDialog` is barrier-dismissible by default, closes the
  // editor dialog underneath it. The test then fails several steps later
  // looking for a field on a form that is no longer on screen, with nothing
  // pointing back to the dropdown that actually caused it.
  await tester.ensureVisible(option.last);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(option.last);
  await pumpFor(tester, const Duration(milliseconds: 700));
}

/// Flips the [SwitchListTile] whose title is [label] to [on].
///
/// Reads the current value first: these switches are not all off by default,
/// and a blind tap would turn one the wrong way.
Future<void> setSwitch(
  WidgetTester tester,
  String label,
  bool on, {
  Finder? within,
}) async {
  // ── Shape 1: a SwitchListTile, where the label is INSIDE the control ───────
  var tile = find.widgetWithText(SwitchListTile, label);
  if (within != null) {
    tile = find.descendant(of: within, matching: tile);
  }

  if (tile.evaluate().isNotEmpty) {
    await tester.ensureVisible(tile.first);
    await tester.pump(const Duration(milliseconds: 150));

    if (tester.widget<SwitchListTile>(tile.first).value == on) return;
    await tester.tap(tile.first);
    await pumpFor(tester, const Duration(milliseconds: 400));
    return;
  }

  // ── Shape 2: a bare Switch SIDE BY SIDE with a Text, inside a Row ──────────
  //
  // 🚨 Both shapes exist in this app and they need different finders. The
  // product editor uses `SwitchListTile`; the payment-type editor's `_switchRow`
  // is `Row(children: [Text(label), Switch(...)])`, where the label is a SIBLING
  // of the control, not an ancestor of it. A helper that only knew the first
  // shape reported "no switch labelled X" about a switch plainly on screen —
  // the same class of miss as looking for the wrong search bar.
  var row = find.ancestor(
    of: find.text(label),
    matching: find.byType(Row),
  );
  if (within != null) {
    row = find.descendant(of: within, matching: row);
  }

  // `.first` is the INNERMOST Row containing this label — ancestors come
  // innermost-first — which is the one that also holds its own Switch. A wider
  // Row up the tree could hold several switches and pick the wrong one.
  final control = row.evaluate().isEmpty
      ? row
      : find.descendant(of: row.first, matching: find.byType(Switch));

  if (control.evaluate().isEmpty) {
    throw TestFailure(
      'No switch labelled "$label" — neither a SwitchListTile nor a Switch '
      'beside a Text of that name.\n  On screen now: ${visibleTexts(tester)}',
    );
  }

  await tester.ensureVisible(control.first);
  await tester.pump(const Duration(milliseconds: 150));

  if (tester.widget<Switch>(control.first).value == on) return;
  await tester.tap(control.first);
  await pumpFor(tester, const Duration(milliseconds: 400));
}

/// Picks a colour swatch from a palette `Wrap`, by position.
///
/// The palettes are built from a private list of `Color`s rendered as bare
/// `InkWell`s with no text or key, so position is the only handle they offer.
Future<void> pickSwatch(WidgetTester tester, int index) async {
  final swatches = find.descendant(
    of: find.byType(Wrap),
    matching: find.byType(InkWell),
  );

  if (swatches.evaluate().length <= index) {
    throw TestFailure(
      'Wanted colour swatch $index but found ${swatches.evaluate().length}',
    );
  }

  await tester.ensureVisible(swatches.at(index));
  await tester.pump(const Duration(milliseconds: 150));
  await tester.tap(swatches.at(index));
  await pumpFor(tester, const Duration(milliseconds: 400));
}

/// Types [query] into a list screen's search box and lets the list settle.
///
/// 🚨 Not a convenience — a correctness fix. These lists are scrollable tables
/// that only BUILD the rows currently on screen, so a freshly created row lands
/// below the fold and `find.text` cannot see it at all. The row exists, the
/// database has it, and the test fails anyway.
///
/// It gets worse the longer the suite is used: every run leaves its rows
/// behind, so a list that fitted on one screen on day one does not on day ten,
/// and a test that passed for weeks starts failing with no code change.
/// Filtering to the row under test is what makes the assertion stable.
///
/// Found by WIDGET, not by hint text. Every list screen wraps its field in a
/// `UnifiedSearchBar`, but they hint it differently — "Search" on groups,
/// "Search products…" on products — and the hint is only rendered while the
/// field is empty and on screen, so matching on it fails exactly when the list
/// is full, which is when this is needed.
Future<void> searchList(WidgetTester tester, String query) async {
  final field = find.descendant(
    of: find.byType(UnifiedSearchBar),
    matching: find.byType(TextField),
  );

  if (field.evaluate().isEmpty) {
    throw TestFailure(
      'No UnifiedSearchBar on this screen\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }

  // Focus first, then type, then CHECK. The field is rebuilt while a dialog
  // above it is dismissing, and text entered into the copy that is going away
  // simply vanishes — leaving an unfiltered list and a later failure that looks
  // like "the row was never created".
  await tester.ensureVisible(field.first);
  await tester.pump(const Duration(milliseconds: 150));

  for (var attempt = 1; attempt <= 3; attempt++) {
    await tester.tap(field.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(field.first, query);
    await pumpFor(tester, const Duration(milliseconds: 1500));

    final current = tester.widget<TextField>(field.first).controller?.text ?? '';
    if (current == query) return;

    if (attempt == 3) {
      throw TestFailure(
        'The search box would not hold "$query" (it reads "$current")\n'
        '  On screen now: ${visibleTexts(tester)}',
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The journey every already-linked test shares
// ─────────────────────────────────────────────────────────────────────────────

/// Ignores RenderFlex overflows under [tolerance] px, and only those.
///
/// 🚨 Driving these forms raises a transient `RenderFlex overflowed by 0.773
/// pixels` from inside a `TextField`'s `InputDecorator`, reported against an
/// element that is already DEFUNCT — it happened mid-layout on a widget that no
/// longer exists. It is invisible on screen and it fails the whole test, because
/// flutter_test treats any framework error as a failure.
///
/// The tolerance is deliberately a couple of pixels rather than "ignore
/// overflows": a real overflow — the kind CLAUDE.md forbids, where a control is
/// actually clipped off a 10-inch tablet — is tens or hundreds of pixels and
/// still fails the run loudly.
void tolerateSubPixelOverflows({double tolerance = 2.0}) {
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final overflow = RegExp(r'overflowed by ([\d.]+) pixels')
        .firstMatch(details.exceptionAsString());
    if (overflow != null &&
        (double.tryParse(overflow.group(1)!) ?? 999) < tolerance) {
      return;
    }
    defaultOnError?.call(details);
  };
}

/// Taps [pin] on the on-screen pad, one digit at a time.
///
/// The keys are `FilledButton`s labelled with their digit. Scoped to buttons so
/// a digit appearing elsewhere on screen — an order number, a price — can never
/// be mistaken for a key.
Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    final key = find.widgetWithText(FilledButton, digit);
    if (key.evaluate().isEmpty) {
      throw TestFailure(
        'No "$digit" key on the PIN pad\n'
        '  On screen now: ${visibleTexts(tester)}',
      );
    }
    await tester.tap(key.first);
    // The pad animates a filled dot per keystroke; give it a frame so the
    // fourth digit is not delivered before the third is registered.
    await tester.pump(const Duration(milliseconds: 350));
  }
  await tester.pump(const Duration(milliseconds: 600));
}

/// Signs in to an ALREADY-LINKED terminal with the PIN and returns the running
/// app's own [ProviderContainer].
///
/// 🚨 It never registers a device, which is the whole point. `login_new_company`
/// has to wipe and re-register to prove the first-install path, and registration
/// is the one action that spends a licence seat. Everything downstream of it
/// starts from a linked terminal instead, so it can be run as often as you like.
///
/// The container comes from the shipping tree rather than being built by the
/// test: the `ProviderScope` sits above the navigator, so it stays valid across
/// every screen the caller goes on to walk through, and what it says is what the
/// cashier is looking at.
Future<ProviderContainer> signInToTill(
  WidgetTester tester,
  E2ECompany company,
) async {
  await waitFor(
    tester,
    find.byType(LoginScreen),
    timeout: const Duration(seconds: 120),
    because: 'Expected the PIN screen of an already-linked terminal.',
  );

  // A registered terminal never shows master login. Reaching it means the device
  // identity is gone — and re-registering here would silently spend a seat.
  expect(
    find.byType(MasterLoginScreen),
    findsNothing,
    reason: 'This terminal is not linked. Run login_new_company once first — '
        'that test registers the device (and does spend a seat).',
  );

  final l = l10nOf(tester);
  step('PIN screen reached (language: ${l.localeName})');

  final container = ProviderScope.containerOf(
    tester.element(find.byType(LoginScreen)),
    listen: false,
  );

  // 🚨 Checked HERE, before the user card, and that ordering is the whole point.
  // A terminal is linked to whichever company registered it LAST, which is not
  // necessarily the newest entry in `pos-credentials.json` — a Cypress run that
  // provisions a company mid-afternoon silently changes what "newest" means
  // without touching this device.
  //
  // The PIN screen of the WRONG company is a perfectly healthy screen: it just
  // lists that company's users. So the mismatch would otherwise surface as a
  // 90-second wait for a card that can never appear, reported as "no card for
  // Jordon Quitzon" — which reads like a broken user list rather than a terminal
  // pointed somewhere else entirely.
  await waitUntil(
    tester,
    () async => container.read(selectedCompanyProvider) != null,
    describe: 'the terminal reports which company it is linked to',
    timeout: const Duration(seconds: 60),
  );
  final linked = container.read(selectedCompanyProvider);
  expect(
    linked?.id,
    company.companyId,
    reason: 'This terminal is linked to company ${linked?.id} '
        '(${linked?.name}), but the test is asking about ${company.companyId} '
        '(${company.companyName}).\n'
        'Either relink the terminal — flutter test '
        'integration_test/login_new_company_test.dart -d windows (spends a '
        'seat, and the new company needs setup_catalog run against it before '
        'there is anything to sell) — or pin this run to the linked company by '
        'setting kCompanyId in integration_test/config/test_config.dart.',
  );
  step('Linked company confirmed: ${linked!.name}');

  final userCard = find.widgetWithText(Card, company.displayName);
  await waitFor(
    tester,
    userCard,
    timeout: const Duration(seconds: 90),
    because: 'No card for "${company.displayName}" on the PIN screen. The user '
        'list is seeded from the server at master login, so an empty list means '
        'that seed did not arrive.',
  );
  await tapVisible(tester, userCard);
  await waitFor(tester, find.widgetWithText(FilledButton, '1'));

  // 🚨 The pad has TWO modes and every test has to survive both, because the
  // second one is what every re-run meets. The very first sign-in on a device
  // CREATES the PIN — four digits, then four more to confirm — but
  // `setDevicePin` stores it against this user AND this device id, and that id
  // is pinned, so the next run opens the pad in VERIFY mode and asks once. A
  // test that always typed eight digits would send the last four into an
  // already-authenticated screen.
  if (find.text(l.createFourDigitPin).evaluate().isNotEmpty) {
    await enterPin(tester, kPosPin);
    await waitFor(tester, find.text(l.confirmNewPin));
  }
  await enterPin(tester, kPosPin);

  await waitFor(
    tester,
    find.byType(MainLayout),
    timeout: const Duration(seconds: 180),
    because: 'The PIN was accepted but the till never opened.',
  );
  step('Signed in — till open');

  return container;
}

/// Opens the till's slide-in navigation drawer.
Future<void> openSidebar(WidgetTester tester) async {
  await tapVisible(tester, find.byIcon(Icons.menu).first);
  await pumpFor(tester, const Duration(milliseconds: 800));
}

/// Till sidebar → Management. It is a PUSHED shell, not a tab — see the
/// "Ilyass Screen" contract in CLAUDE.md.
Future<void> openManagement(WidgetTester tester, AppLocalizations l) async {
  await openSidebar(tester);
  await tapVisible(tester, find.text(l.management));
  await pumpFor(tester, const Duration(seconds: 2));
}

/// Taps one entry in the Management rail.
///
/// On a window 850px or wider the rail is permanent and expanded, so the labels
/// are simply on screen. Below that it collapses into a drawer, which is why
/// this falls back to opening one.
Future<void> openManagementSection(WidgetTester tester, String label) async {
  if (find.text(label).evaluate().isEmpty) {
    await openSidebar(tester);
  }
  await tapVisible(tester, find.text(label).first);
  await pumpFor(tester, const Duration(seconds: 2));
}

/// Runs a manual sync from the till's sidebar and closes the status panel.
///
/// The Sync control lives only in the till's sidebar — Management has none — so
/// a caller inside Management has to leave it first. Tapping the icon opens the
/// Sync Status panel; the action itself is the "Sync now" button inside it.
Future<void> syncNow(WidgetTester tester, AppLocalizations l) async {
  // 🚨 Only open the drawer if it is not ALREADY open. The sidebar is left open
  // by a previous pass — `exitManagement` comes back to a shell that still has
  // it out — and tapping the hamburger again would CLOSE it, taking the Sync
  // button off screen and failing two steps later with nothing pointing here.
  if (find.text(l.management).evaluate().isEmpty) {
    await openSidebar(tester);
  }

  final syncNowButton = find.widgetWithText(FilledButton, l.syncNow);

  // 🚨 Opened in a RETRY LOOP, because a single tap is not dependable here and
  // its failure is silent: `tester.tap` only warns when its hit-test misses. The
  // sidebar is still settling when this runs, so the button moves out from under
  // the tap, nothing opens, and the run dies two steps later on "nothing to tap
  // for Sync now" with no clue why.
  //
  // The SyncButton is found by TYPE, not tooltip. The tooltip is state-driven —
  // "Syncing…" mid-sync, "N pending, tap for status" when anything is queued —
  // so a finder pinned to the idle wording misses in exactly the situation this
  // step exists for.
  for (var attempt = 1; attempt <= 3; attempt++) {
    if (syncNowButton.evaluate().isNotEmpty) break;
    await tapVisible(tester, find.byType(SyncButton));
    await pumpFor(tester, const Duration(seconds: 2));
  }

  await waitFor(
    tester,
    syncNowButton,
    timeout: const Duration(seconds: 60),
    because: 'The Sync Status panel never opened.',
  );

  await tapVisible(tester, syncNowButton);

  // The button reads "Syncing…" while it works and returns to "Sync now" when
  // it finishes, so waiting for the label to come back is waiting for the sync.
  await pumpFor(tester, const Duration(seconds: 3));
  await waitFor(
    tester,
    find.widgetWithText(FilledButton, l.syncNow),
    timeout: const Duration(seconds: 180),
    because: 'The manual sync never finished.',
  );
  step('Sync complete');

  await tapVisible(tester, find.widgetWithText(TextButton, l.actionClose));
  await pumpFor(tester, const Duration(seconds: 1));

  // The sidebar is still open behind the dialog; tapping the shell closes it.
  if (find.text(l.management).evaluate().isNotEmpty) {
    await tapVisible(tester, find.byType(MainLayout));
  }
  await pumpFor(tester, const Duration(seconds: 1));
}

// ─────────────────────────────────────────────────────────────────────────────
// The E2E customer
// ─────────────────────────────────────────────────────────────────────────────

/// A real customer created on an E2E company, as `create_customer` recorded it.
///
/// The reason it exists at all: every sale rung up by these tests goes to the
/// WALK-IN customer, code `C000`, and a walk-in is not a customer for testing
/// purposes. It cannot be sold to on credit — `_complete` blocks a payment type
/// with `isCustomerRequired` and says so explicitly for `C000` — and it carries
/// no discount profile and no loyalty card. Anything touching those needs a
/// named customer that really exists on the server.
class E2ECustomer {
  const E2ECustomer({
    required this.customerId,
    required this.name,
    required this.code,
    required this.email,
    required this.phone,
  });

  /// The SERVER's id. Customers are created online-first — the form POSTs to
  /// `/Customer/AddCustomercommand` and swaps its negative temp row for the
  /// real one — so a recorded customer always has a positive id.
  final int customerId;
  final String name;
  final String code;
  final String email;
  final String phone;

  static E2ECustomer fromJson(Map<String, dynamic> j) => E2ECustomer(
        customerId: j['customerId'] as int,
        name: j['name'] as String,
        code: (j['code'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'name': name,
        'code': code,
        'email': email,
        'phone': phone,
      };
}

/// The newest customer recorded against [companyId] in the credentials file.
///
/// Defaults to the company this terminal is linked to, which is what a test
/// wanting "a real customer to sell to" means by it.
Future<E2ECustomer> loadE2ECustomer({int? companyId}) async {
  final id = companyId ?? (await loadLinkedCompany()).companyId;
  final file = File(kCredentialsPath);
  final entries = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  final company = entries.where((e) => e['companyId'] == id).firstOrNull;
  final recorded = (company?['customers'] as List?)?.cast<Map<String, dynamic>>();

  if (recorded == null || recorded.isEmpty) {
    throw StateError(
      'No customer recorded for company $id in ${file.absolute.path}\n'
      'Create one first:\n'
      '    flutter test integration_test/create_customer_test.dart -d windows\n',
    );
  }
  // Newest first — recordE2ECustomer unshifts each new one onto the front.
  return E2ECustomer.fromJson(recorded.first);
}

/// Writes [customer] into the credentials files, against its company.
///
/// 🚨 The JSON is the durable record and the .txt is a convenience view — not
/// the other way round. Cypress REWRITES `pos-credentials.txt` from scratch on
/// every provisioning run (`saveCredentials` renders it from `history[0]`), so
/// anything written there survives only until the next company is provisioned.
/// The customer therefore lives in the JSON, nested under the company it
/// belongs to, and the .txt gets a clearly-delimited copy for whoever is
/// reading the file rather than parsing it.
///
/// Both writes are idempotent: the JSON keeps a newest-first list so re-runs
/// accumulate rather than overwrite, and the .txt block is replaced wholesale.
Future<void> recordE2ECustomer({
  required int companyId,
  required E2ECustomer customer,
}) async {
  final jsonFile = File(kCredentialsPath);
  final entries = (jsonDecode(jsonFile.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  final company = entries.where((e) => e['companyId'] == companyId).firstOrNull;
  if (company == null) {
    throw StateError(
      'Cannot record a customer for company $companyId — it is not in '
      '${jsonFile.absolute.path}',
    );
  }

  final existing =
      (company['customers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  company['customers'] = [
    {
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      ...customer.toJson(),
    },
    ...existing,
  ];

  jsonFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(entries)}\n',
  );

  _appendCustomerBlock(
    companyId: companyId,
    companyName: (company['companyName'] as String?) ?? '$companyId',
    customer: customer,
  );
}

/// Markers around the block this suite owns inside `pos-credentials.txt`.
///
/// Delimited rather than simply appended so a re-run REPLACES its own block
/// instead of stacking a fresh copy under the last one, and so nothing outside
/// the markers — the company summary Cypress renders — is ever touched.
const String _kCustomerBlockStart = '=== E2E CUSTOMERS =========================================';
const String _kCustomerBlockEnd = '=== END E2E CUSTOMERS =====================================';

void _appendCustomerBlock({
  required int companyId,
  required String companyName,
  required E2ECustomer customer,
}) {
  final txtFile = File(
    kCredentialsPath.replaceFirst(RegExp(r'\.json$'), '.txt'),
  );

  var body = txtFile.existsSync() ? txtFile.readAsStringSync() : '';

  // Drop a previous block, if any.
  final start = body.indexOf(_kCustomerBlockStart);
  if (start != -1) {
    final end = body.indexOf(_kCustomerBlockEnd, start);
    body = end == -1
        ? body.substring(0, start)
        : body.substring(0, start) +
            body.substring(end + _kCustomerBlockEnd.length);
    body = body.trimRight();
    if (body.isNotEmpty) body += '\n';
  }

  final block = [
    '',
    _kCustomerBlockStart,
    ' A REAL customer, for tests that cannot use the C000 walk-in.',
    '',
    ' Belongs to    : $companyName (company $companyId)',
    ' Customer ID   : ${customer.customerId}',
    ' Name          : ${customer.name}',
    ' Code          : ${customer.code}',
    ' Email         : ${customer.email}',
    ' Phone         : ${customer.phone}',
    '',
    ' 🚨 The company summary ABOVE describes the newest company Cypress',
    '    provisioned, which is not necessarily the company this customer',
    '    belongs to — check the id on this block, not the one at the top.',
    '',
    ' Written by integration_test/create_customer_test.dart. The durable',
    ' record is pos-credentials.json; this file is regenerated from scratch',
    ' by the next Cypress provisioning run.',
    '',
    ' Verify in SQL Server:',
    '   SELECT * FROM [web-pos].dbo.Customer WHERE Id = ${customer.customerId};',
    _kCustomerBlockEnd,
    '',
  ].join('\n');

  txtFile.writeAsStringSync('$body$block');
}

// ─────────────────────────────────────────────────────────────────────────────
// The "Index 0" rule
// ─────────────────────────────────────────────────────────────────────────────

/// Picks the first REAL option in a dropdown and returns the label it chose.
///
/// This is the primitive behind the smart-default rule: a helper whose caller
/// did not name a tax (or a group, or a parent folder) falls back to "whatever
/// is already there", so a test that only cares about product creation does not
/// have to build a catalogue first.
///
/// 🚨 "First real option" is NOT `items[0]`, and the difference is the whole
/// reason this function exists rather than a bare `.at(0)` tap.
///
/// Every one of these dropdowns is built as a null-valued PLACEHOLDER followed
/// by the actual rows:
///
/// ```dart
/// items: [
///   DropdownMenuItem(value: null, child: Text(l10n.noTax)),   // <- index 0
///   ...enabled.map((t) => DropdownMenuItem(value: t.id, ...)),
/// ]
/// ```
///
/// So the literal index 0 of the Primary Tax Rate dropdown is **"No Tax"**, and
/// of Parent Folder it is **"None (Root)"**. A helper defaulting to index 0
/// would therefore save an UNTAXED product and report success — a green test
/// for exactly the wrong reason, which this suite has already been bitten by
/// three times (see the README's "Three bugs the database found").
///
/// Items are therefore filtered by `value != null` before [index] is applied.
/// Pass [allowPlaceholder] when the placeholder is genuinely the wanted answer
/// (a root-level folder really is `None (Root)`).
///
/// The label is read off the widget and then handed to [pickDropdown], so the
/// tap itself keeps every guardrail already established: the search is confined
/// to the open menu, an off-screen entry is scrolled to, and the selection is
/// read back and retried if it did not take.
Future<String> pickDropdownAt(
  WidgetTester tester,
  String fieldLabel, {
  Finder? within,
  int index = 0,
  bool allowPlaceholder = false,
}) async {
  final options = dropdownOptions(
    tester,
    fieldLabel,
    within: within,
    includePlaceholder: allowPlaceholder,
  );

  if (options.isEmpty) {
    throw TestFailure(
      'Dropdown "$fieldLabel" has no selectable option to fall back on.\n'
      '  The smart default needs at least one row to exist already — create '
      'one explicitly in this test, or run setup_catalog against this company '
      'first.\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }
  if (index >= options.length) {
    throw TestFailure(
      'Dropdown "$fieldLabel" was asked for option $index but offers only '
      '${options.length}: ${options.join(' | ')}',
    );
  }

  final chosen = options[index];
  // Substring: the tax picker renders "$name ($rate%)" and the label read off
  // the item is that whole string, but callers recording it want a stable
  // match. Delegating keeps the retry-and-verify behaviour.
  await pickDropdown(tester, fieldLabel, chosen,
      within: within, matchSubstring: true);
  return chosen;
}

/// The option labels a dropdown is currently offering, in menu order.
///
/// 🚨 Read from the `DropdownButton` INSIDE the form field, not from the
/// `DropdownButtonFormField` itself. The form field takes `items` as a
/// constructor argument and captures it in its `FormField` builder closure —
/// it is not a public field, so there is nothing to read on that widget.
/// The `DropdownButton` it builds does expose `items` publicly.
///
/// Matched by type NAME for the usual reason: these are generic
/// (`DropdownButton<int?>` for a group, `<String>` for a setting) and
/// `find.byType` compares the exact runtime type, so a guess at the type
/// argument silently matches nothing.
List<String> dropdownOptions(
  WidgetTester tester,
  String fieldLabel, {
  Finder? within,
  bool includePlaceholder = false,
}) {
  final field = findDropdown(fieldLabel, within: within);
  if (field.evaluate().isEmpty) {
    throw TestFailure(
      'No dropdown labelled "$fieldLabel"\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }

  final button = find.descendant(
    of: field.first,
    matching: find.byWidgetPredicate(
      (w) => w.runtimeType.toString().startsWith('DropdownButton<'),
    ),
  );
  if (button.evaluate().isEmpty) {
    throw TestFailure(
      'Dropdown "$fieldLabel" has not built its button yet — it is probably '
      'still showing a LinearProgressIndicator while its provider loads.',
    );
  }

  final items = (tester.widget(button.first) as dynamic).items as List?;
  if (items == null) return const [];

  final labels = <String>[];
  for (final item in items) {
    final dynamic entry = item;

    // 🚨 Skip DISABLED entries always, placeholder or not. The unit picker is
    // built as `[CATEGORY HEADER, unit, unit, CATEGORY HEADER, unit, ...]`,
    // where each header is a `DropdownMenuItem` with `enabled: false` and a
    // NEGATIVE value standing in for the category. A header is therefore not
    // caught by the null-value rule below — and being first, it is exactly what
    // `index: 0` would land on. The tap then does nothing (that is what
    // `enabled: false` means), the dropdown keeps its old value, and the retry
    // in `pickDropdown` burns its attempts before failing somewhere unhelpful.
    if (entry.enabled == false) continue;

    // The placeholder is the one carrying a null value — "No Tax",
    // "None (Root)". Identified by its VALUE, never by its text: that text is
    // localised, so a string check would work in English and quietly select an
    // untaxed product on a French terminal.
    if (!includePlaceholder && entry.value == null) continue;

    final child = entry.child;
    if (child is Text && child.data != null) {
      labels.add(child.data as String);
    }
  }
  return labels;
}

/// Gets to one Management section from wherever the app currently is.
///
/// This is what lets the flow helpers be mixed and matched freely. Each one
/// navigates itself, so `createTax` works whether it was called straight after
/// `loginToCompany` (the till is on screen, Management is not open) or straight
/// after `createProductGroup` (already inside Management, on another section).
///
/// 🚨 "Am I in Management?" is answered by the presence of `Exit Management`,
/// which exists ONLY in the Management rail. It is not `Navigator.canPop()` —
/// both shells are pushed over login, so `canPop()` is true inside every tab of
/// either one, and the "Ilyass Screen" contract in CLAUDE.md calls that out as
/// the trap it is.
Future<void> ensureManagementSection(
  WidgetTester tester,
  AppLocalizations l,
  String section,
) async {
  if (find.text(l.exitManagement).evaluate().isEmpty) {
    await openManagement(tester, l);
    await waitFor(
      tester,
      find.text(l.exitManagement),
      timeout: const Duration(seconds: 60),
      because: 'Management did not open.',
    );
  }
  await openManagementSection(tester, section);
}

/// Leaves Management and waits until it is really gone.
///
/// 🚨 Waits for MANAGEMENT TO GO, not for MainLayout to arrive. Management is
/// PUSHED over the till, so MainLayout never leaves the tree — a
/// `waitFor(find.byType(MainLayout))` is satisfied instantly while the portal is
/// still on screen and still animating out. The next step then opens the wrong
/// sidebar, and the run dies somewhere else entirely.
Future<void> exitManagement(WidgetTester tester, AppLocalizations l) async {
  if (find.text(l.exitManagement).evaluate().isEmpty) return;
  await tapVisible(tester, find.text(l.exitManagement));
  await waitForGone(tester, find.text(l.exitManagement));
  await pumpFor(tester, const Duration(seconds: 1));
}

/// Filters the product list to [productName] and opens its editor.
///
/// Shared by the barcode flow and the verification flow, which is why it is a
/// primitive rather than living in either helper.
///
/// 🚨 The list is FILTERED first, not scrolled. These tests leave their rows
/// behind, so a company accumulates products run after run — and a table only
/// builds what it is showing, which means `find.text` reports a perfectly real
/// product missing purely because it sits below the fold. That failure gets
/// likelier every single run.
///
/// Waiting for the Barcodes tab is the honest check that the editor opened in
/// its SECOND phase: a product that has not synced yet has no server id, so its
/// editor has no Barcodes tab at all and the wait fails saying so.
Future<void> openProductEditor(
  WidgetTester tester,
  AppLocalizations l,
  String productName,
) async {
  await searchList(tester, productName);
  await waitFor(tester, find.textContaining(productName));
  await tapVisible(tester, find.textContaining(productName));
  await waitFor(
    tester,
    find.text(l.barcodesTab),
    timeout: const Duration(seconds: 30),
    because: 'No Barcodes tab — "$productName" may still be unsynced.',
  );
}

/// Waits until the app's locale stops changing, and returns it.
///
/// 🚨 The locale is NOT stable immediately after sign-in, and that is the whole
/// reason this exists. The terminal renders the PIN screen in whatever language
/// it had cached, then the company's `Application.Language` arrives with the
/// post-sign-in sync — so the app can be French at the PIN pad and English two
/// screens later, having been given the company's real setting in between.
///
/// A helper that read `l10nOf` once at sign-in and reused it would then look for
/// French labels on an English screen. That is not hypothetical: it is exactly
/// how `setup_catalog` failed with `No dropdown labelled "Langue"` while the
/// screen plainly read `ENGLISH | Language`.
///
/// Settles by requiring the same locale on [stableReads] consecutive polls
/// rather than by sleeping a fixed amount, so a fast sync costs nothing and a
/// slow one is still caught.
Future<String> waitForStableLocale(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 60),
  int stableReads = 3,
  Duration interval = const Duration(milliseconds: 500),
}) async {
  final deadline = DateTime.now().add(timeout);
  var last = l10nOf(tester).localeName;
  var streak = 1;

  while (DateTime.now().isBefore(deadline)) {
    await pumpFor(tester, interval);
    final now = l10nOf(tester).localeName;

    if (now == last) {
      if (++streak >= stableReads) return now;
    } else {
      step('Locale changed mid-run: $last -> $now (the company setting arrived)');
      last = now;
      streak = 1;
    }
  }
  return last;
}

/// Resets any leftover search filter, on screens that HAVE a search box.
///
/// 🚨 Deliberately tolerant where [searchList] is strict, and the asymmetry is
/// the point:
///
///   * clearing a filter that does not exist is a no-op — there is nothing to
///     clear, so nothing is wrong;
///   * running a QUERY on a screen with no search box is a real problem, because
///     the caller is about to look for a row it believes has been filtered into
///     view. Silently skipping that would leave an unfiltered list and fail
///     later as "the row was never created".
///
/// Not every list screen has one. Products, Product Groups, Taxes, Payment Types
/// and Security Rules do; **Users does not** — it renders cards with no filter
/// at all, which is what made a blanket `searchList(tester, '')` fail there with
/// "No UnifiedSearchBar on this screen" on a screen that was working perfectly.
Future<void> clearSearch(WidgetTester tester) async {
  final field = find.descendant(
    of: find.byType(UnifiedSearchBar),
    matching: find.byType(TextField),
  );
  if (field.evaluate().isEmpty) return;

  final current = tester.widget<TextField>(field.first).controller?.text ?? '';
  if (current.isEmpty) return;

  await searchList(tester, '');
}

/// The innermost `Row` enclosing [of] — the idiom for reaching a control that
/// sits BESIDE its label rather than around it.
///
/// 🚨 This exists because `find.ancestor` cannot express "next to". Several
/// editors in this app lay a control out as a SIBLING of its caption:
///
/// ```dart
/// Row(children: [Text(label), Switch(...)])                  // payment types
/// Row(children: [Tooltip(Text(label)), SegmentedButton(...)]) // security rules
/// ```
///
/// `find.ancestor(of: label, matching: Switch)` asks for a Switch that CONTAINS
/// the label, and nothing does — so it matches nothing. That has now cost two
/// debugging sessions: once reported as "no switch labelled X" on a screen
/// plainly showing one, and once as an internal `'_found != null'` assertion
/// from inside the matcher, because the empty result had `.first` chained onto
/// it before anything checked it.
///
/// `.first` is the CLOSEST Row: `visitAncestorElements` walks child-upward, so
/// the enclosing tile's own Row comes before any wider one that might hold every
/// other row on the screen.
///
/// 🚨 Never chain `.first` onto a finder without knowing it matched. An empty
/// finder with `.first` on it does not fail where you wrote it — it fails later,
/// inside the matcher's own mismatch description, with a message about Flutter's
/// internals and no mention of what you were looking for.
Finder enclosingRow(
  WidgetTester tester,
  Finder of, {
  required String describe,
}) {
  if (of.evaluate().isEmpty) {
    throw TestFailure(
      'Nothing matched $describe, so there is no row around it.\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }

  final row = find.ancestor(of: of, matching: find.byType(Row));
  if (row.evaluate().isEmpty) {
    throw TestFailure(
      'Found $describe but no Row around it — the layout has changed.\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }
  return row.first;
}

/// A sidebar icon button, matched by WIDGET as well as icon.
///
/// 🚨 `find.byIcon` alone is ambiguous on the till, and the failure is silent.
/// `Icons.tune` is drawn TWICE while the sidebar is open:
///
///   * `MenuScreen`'s **Modifiers** button, in the cart header — and it is
///     `onTap: null` whenever no cart line is selected, which is most of the
///     time;
///   * `MainLayout`'s **Quick Settings**, in the sidebar.
///
/// The body comes before the sidebar in tree order, so `.first` taps the
/// DISABLED modifiers button. Nothing happens, no warning is printed, and the
/// run fails a minute later waiting for a screen that was never asked to open.
///
/// `NavIconButton` is the sidebar's own type and nothing else uses it, so
/// matching on the widget removes the ambiguity — and unlike the tooltip it
/// carries no translation to go stale.
Finder sidebarIconButton(IconData icon) => find.byWidgetPredicate(
      (w) => w is NavIconButton && w.icon == icon,
      description: 'sidebar icon button ($icon)',
    );
