/// `logoutFromTill` / `signInAsUser` — changing who is standing at the till.
///
/// ```dart
/// await logoutFromTill(tester, ctx);
/// await signInAsUser(tester, ctx, user);
/// ```
///
/// One file because they are one flow: a shift change. Nothing wants to log out
/// and stay logged out, and nothing can sign a second person in without logging
/// the first one off — the till has exactly one current user.
///
/// ## 🚨 The PIN must already exist on this device
///
/// A PIN is stored per user **and per device**. `10_create_users` sets one for
/// each user it makes, through the Users screen's "Admin: Reset Device PIN"
/// action — the same `setDevicePin` the pad itself calls — so [signInAsUser]
/// meets a VERIFY pad: one four-digit entry.
///
/// A CREATE pad here is treated as a failure rather than handled. Typing the PIN
/// twice would work, but it would SET a value this helper merely assumed and the
/// run would go green while proving nothing about what `10` left behind.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/login_screen.dart';
import 'package:pos_app/navigation/main_layout.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';
import 'record_users_helper.dart';

/// Signs the current user out and lands back on the PIN screen.
///
/// Safe to call when already signed out.
Future<void> logoutFromTill(WidgetTester tester, E2EContext ctx) async {
  if (find.byType(LoginScreen).evaluate().isNotEmpty) {
    step('Already signed out');
    return;
  }

  // Management is a PUSHED shell over the till, and the sign-out item lives in
  // the TILL's sidebar — so leave the portal first or the drawer that opens is
  // the wrong one.
  await exitManagement(tester, ctx.l);

  if (find.text(ctx.l.management).evaluate().isEmpty) {
    await openSidebar(tester);
  }

  // 🚨 Found by ICON, not by the "Sign out" label. `NavItem` renders its label
  // as text, but so does every other row in that sidebar, and a translated
  // string is one relabelling away from matching the wrong one. `Icons.logout`
  // appears exactly once.
  await tapVisible(tester, find.byIcon(Icons.logout));

  // Sign-out does `pushAndRemoveUntil(LoginScreen)`, so the login screen
  // ARRIVING is the honest signal — MainLayout is torn down with it.
  await waitFor(
    tester,
    find.byType(LoginScreen),
    timeout: const Duration(seconds: 60),
    because: 'Sign out did not return the till to the PIN screen.',
  );
  await pumpFor(tester, const Duration(seconds: 1));
  ctx.refreshL10n(tester);
  step('Signed out');
}

/// Signs in as [user] with the PIN `10_create_users` set for them.
///
/// Assumes the app is on the PIN screen — call [logoutFromTill] first.
Future<void> signInAsUser(
  WidgetTester tester,
  E2EContext ctx,
  E2EUser user,
) async {
  await waitFor(
    tester,
    find.byType(LoginScreen),
    timeout: const Duration(seconds: 60),
    because: 'Not on the PIN screen — sign the current user out first.',
  );
  ctx.refreshL10n(tester);

  // 🚨 The user list is seeded from the server and refreshed on this screen, so
  // a user created minutes ago on this same terminal can still be a moment late
  // arriving. Waiting is not optional even though `10` already proved the row
  // exists in the database.
  final card = find.widgetWithText(Card, user.displayName);
  await waitFor(
    tester,
    card,
    timeout: const Duration(seconds: 90),
    because: 'No card for "${user.displayName}" on the PIN screen. The list is '
        'seeded from the server, so a missing card means that seed has not '
        'arrived — or the user was created on a different company.',
  );
  // 🚨 Two cards with the same name is UNRESOLVABLE, and failing here is the
  // only honest thing to do.
  //
  // The PIN screen's card shows the display name and the role — nothing else.
  // No username, no email. So a company carrying two "Karim Admin" users offers
  // two identical cards, and neither this test nor a human standing at the till
  // can tell which is which. Tapping `.first` would sign in as whichever the
  // tree happened to build first and every assertion afterwards would be about
  // the wrong person.
  //
  // `10_create_users` prevents this by using STABLE usernames, so a re-run
  // reuses one Karim rather than minting another. Duplicates therefore mean the
  // company is carrying users from before that change.
  if (card.evaluate().length > 1) {
    throw TestFailure(
      '${card.evaluate().length} user cards read "${user.displayName}" — the '
      'PIN screen shows only the name and role, so there is no way to tell '
      'which one is "${user.username}".\n'
      '  Delete the duplicates on this company; 10_create_users now reuses a '
      'single pair instead of creating a new one each run.',
    );
  }

  await tapVisible(tester, card);
  await waitFor(tester, find.widgetWithText(FilledButton, '1'));

  // 🚨 VERIFY only — one entry, not two, and a create pad here is a FAILURE.
  //
  // `10_create_users` sets each user's PIN through the Users screen's "Admin:
  // Reset Device PIN" action, which calls the same `setDevicePin` the pad does
  // and writes `pinHash` into the local row. So by the time anybody signs in,
  // the pad opens in verify mode.
  //
  // Meeting the CREATE pad instead means that never happened — the user was
  // made on another terminal, the row was wiped, or `10` did not finish — and
  // quietly typing the PIN twice would paper over it. Worse, it would SET a PIN
  // this test merely assumed, so the run would pass while proving nothing about
  // what `10` was supposed to leave behind.
  if (find.text(ctx.l.createFourDigitPin).evaluate().isNotEmpty) {
    throw TestFailure(
      '"${user.displayName}" has no PIN on this terminal — the pad is asking to '
      'create one.\n'
      '  A PIN is stored per user AND per device, and 10_create_users is what '
      'sets it here.\n'
      '  Run: flutter test integration_test/10_create_users_test.dart -d windows',
    );
  }
  await enterPin(tester, user.pin);

  await waitFor(
    tester,
    find.byType(MainLayout),
    timeout: const Duration(seconds: 180),
    because: 'The PIN was accepted but the till never opened for '
        '"${user.displayName}".',
  );
  ctx.refreshL10n(tester);

  // 🚨 Confirm WHO is signed in, not merely that a till opened. Tapping the
  // wrong card and typing a PIN that happened to match would land on a working
  // till as the wrong person — and every permission assertion after it would be
  // about somebody else.
  await waitUntil(
    tester,
    () async =>
        ctx.container.read(currentUserProvider)?.username == user.username,
    describe: 'the till reports ${user.username} as the current user',
    timeout: const Duration(seconds: 30),
  );

  step('Signed in as ${user.displayName} (${user.accessLevelName})');
}
