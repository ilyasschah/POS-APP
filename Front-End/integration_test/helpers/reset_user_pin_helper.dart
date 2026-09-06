/// `setUserDevicePin` — gives a user a PIN on THIS terminal, as an admin would.
///
/// ```dart
/// await setUserDevicePin(tester, ctx, userId: 24,
///     email: 'karim.admin.e2e@octopus-e2e.test',
///     displayName: 'Karim Admin', pin: '3333');
/// ```
///
/// ## Why this exists rather than letting the pad create the PIN
///
/// A user with no PIN on this device meets the pad in CREATE mode — four digits,
/// then four again to confirm. That is a real path and `01_login_new_company`
/// tests it, but it makes every other test that signs somebody in pay for it,
/// and it hides the thing they actually care about behind a two-stage entry.
///
/// The Users screen has the admin's own answer to this: **Security actions →
/// Admin: Reset Device PIN**. It calls the very same `setDevicePin` the pad
/// does, so a PIN set here is indistinguishable from one the user typed — and
/// afterwards the pad opens in VERIFY mode, one entry.
///
/// ## 🚨 "Device" is literal
///
/// `setDevicePin` posts this terminal's `deviceId` and writes `pinHash` into the
/// local `users` row. The PIN therefore exists **on this machine only** — the
/// same user on another till still has no PIN there and would meet the create
/// pad again. Nothing to work around; just do not expect the value to travel.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/database/database_provider.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Sets [pin] as [displayName]'s PIN on this terminal.
///
/// Assumes `loginToCompany` has already run as somebody who may manage users;
/// navigates to the Users screen itself.
Future<void> setUserDevicePin(
  WidgetTester tester,
  E2EContext ctx, {
  required int userId,
  required String email,
  required String displayName,
  required String pin,
}) async {
  assert(pin.length == 4, 'A device PIN is exactly four digits');

  await ensureManagementSection(tester, ctx.l, ctx.l.users);

  // 🚨 Found by EMAIL, never by the display name — and this is not a
  // preference, it is the bug that broke this helper on its first real run.
  //
  // The row's TITLE is the display name and nothing else identifies the person
  // there; the username appears only inside the subtitle's email. A company that
  // had accumulated three "Amina Cashier" and two "Karim Admin" rows therefore
  // gave `find.text(displayName)` several equally good matches, `.first` picked
  // the OLDEST, and the PIN was set on the wrong person — after which the wait
  // for the new user's hash timed out with the reset having plainly succeeded.
  //
  // The email carries the username, which is unique per company.
  final tile = find.ancestor(
    of: find.textContaining(email),
    matching: find.byType(ListTile),
  );
  await waitFor(
    tester,
    tile,
    timeout: const Duration(seconds: 60),
    because: 'No user row carrying "$email" on the Users screen.',
  );

  // 🚨 Ambiguity is a failure, not something to resolve with `.first`. Two rows
  // for one email should be impossible; if it happens, silently picking one
  // would set a PIN somewhere this test cannot see.
  if (tile.evaluate().length > 1) {
    throw TestFailure(
      '${tile.evaluate().length} user rows carry "$email" — cannot tell which '
      'is "$displayName".\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }

  final securityButton =
      find.descendant(of: tile.first, matching: find.byIcon(Icons.security));
  if (securityButton.evaluate().isEmpty) {
    throw TestFailure(
      'No security-actions button on "$displayName"\'s row.\n'
      '  On screen now: ${visibleTexts(tester)}',
    );
  }
  await tapVisible(tester, securityButton.first);
  await pumpFor(tester, const Duration(milliseconds: 600));

  // The menu is a route of its own, so its entries are NOT inside the tile any
  // more — scoping to the tile here would find nothing.
  await tapVisible(tester, find.text(ctx.l.adminResetDevicePin));

  final dialog = find.byType(AlertDialog);
  await waitFor(
    tester,
    dialog,
    timeout: const Duration(seconds: 30),
    because: 'The reset-PIN dialog never opened.',
  );

  await fillField(tester, ctx.l.newFourDigitPin, pin, within: dialog);

  await tapVisible(
    tester,
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(ElevatedButton, ctx.l.forceReset),
    ),
  );

  await waitForGone(
    tester,
    dialog,
    timeout: const Duration(seconds: 60),
    because: 'The reset-PIN dialog stayed open — the server did not accept it. '
        'The button also does nothing at all for a PIN under four digits.',
  );

  // ── Prove the RIGHT pin was stored ────────────────────────────────────────
  //
  // 🚨 Not "a pinHash exists" — that would be equally true of the pin this test
  // meant to set and of one left over from a previous run with a different
  // value, and the difference only shows up later as a sign-in that will not
  // take. `setDevicePin` writes `base64(sha256(utf8(pin)))`, the same algorithm
  // the backend uses, so the expected hash can be computed here exactly.
  final expected = base64Encode(sha256.convert(utf8.encode(pin)).bytes);
  final db = ctx.container.read(appDatabaseProvider);

  await waitUntil(
    tester,
    () async {
      final rows = await (db.select(db.usersTable)
            ..where((t) => t.id.equals(userId)))
          .get();
      return rows.isNotEmpty && rows.first.pinHash == expected;
    },
    describe: '"$displayName" carries the PIN $pin on this terminal',
    timeout: const Duration(seconds: 60),
  );

  ctx.record(E2EArtifact(
    table: 'UserDevicePin',
    name: displayName,
    extra: {'UserId': userId, 'Pin': pin},
  ));
  step('PIN set for $displayName: $pin (verify-only from here on)');
}
