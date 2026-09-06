/// `createUser` — a second person on the till.
///
/// ```dart
/// await createUser(tester, ctx, firstName: 'Amina', role: UserRole.cashier);
/// ```
///
/// ## Why a cashier is needed
///
/// Everything the suite does so far runs as the company's Admin, which can reach
/// every screen — so no test can currently tell "this works" from "this works
/// because nothing is ever denied". A cashier is what makes the security keys
/// (`SecurityKeys.*`) observable at all, and what makes `doc.userId` mean
/// something: a sale attributed to whoever happens to be signed in proves less
/// than one attributed to the person who rang it up.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/database/database_provider.dart';

import '../config/test_config.dart';
import '../support/e2e_support.dart';
import 'e2e_context.dart';
import 'record_users_helper.dart';
import 'reset_user_pin_helper.dart';

/// Which access level the user gets.
///
/// 🚨 The dropdown is keyed on an INT — `0` is Admin and `1` is Cashier — and
/// the labels are localised, so the option is picked by its translated text
/// while the meaning lives in the number.
enum UserRole { admin, cashier }

/// Creates a user and returns its username.
///
/// Returns without creating anything if that username already exists, so the
/// test is safe to re-run.
///
/// Assumes `loginToCompany` has already run; navigates to the section itself.
Future<E2EUser> createUser(
  WidgetTester tester,
  E2EContext ctx, {
  String? firstName,
  String? lastName,
  String? username,
  String? email,
  String? password,
  UserRole role = UserRole.cashier,
  String pin = kPosPin,
}) async {
  final first = firstName ?? 'Amina';
  final last = lastName ?? 'Cashier';

  // 🚨 STABLE, not run-tagged — the opposite of every other name this suite
  // generates, and deliberately so.
  //
  // Products and taxes are tagged because re-runs must not collide on a unique
  // index. Users are different: this helper is idempotent by username, so a
  // stable name means a re-run REUSES the same person instead of minting a new
  // one. That matters because the PIN screen's user card shows only the DISPLAY
  // NAME and the role — no username, no email. A run-tagged username still
  // produces a card reading "Karim Admin", so a company accumulated three
  // Karims and two Aminas whose cards were indistinguishable, and
  // `setUserDevicePin` set the PIN on whichever came first in the tree while the
  // test waited for it on the one it had just created.
  //
  // One Karim and one Amina per company, forever, is the fix.
  final user = username ?? '${first.toLowerCase()}.${last.toLowerCase()}.e2e';
  final mail = email ?? '$user@octopus-e2e.test';

  // Derived from the name rather than the run, for the same reason: a re-run
  // does NOT reset an existing user's password, so a freshly generated one would
  // be recorded against an account that does not have it.
  final pass = password ?? 'Pos${first}E2E!7';

  await ensureManagementSection(tester, ctx.l, ctx.l.users);
  step('Users opened');
  await clearSearch(tester);

  final existing = await _usersInDb(ctx);
  final already = existing.where((u) => u.username == user).firstOrNull;
  if (already != null) {
    step('User "$user" already exists');
    // Re-set the PIN even so: the row may predate this terminal, or carry a PIN
    // from a run that chose a different one, and `11` signs in with the value
    // recorded below.
    await setUserDevicePin(
      tester,
      ctx,
      userId: already.id,
      email: already.email ?? mail,
      displayName: '$first $last',
      pin: pin,
    );
    final record = E2EUser(
      userId: already.id,
      firstName: first,
      lastName: last,
      username: user,
      email: mail,
      password: pass,
      pin: pin,
      accessLevel: already.accessLevel,
    );
    await recordE2EUser(ctx, record);
    return record;
  }

  // Two openers, one editor — the FAB, and an "Add first user" button that an
  // empty list shows instead. A company always has its Admin, so the empty state
  // is unreachable here in practice; handled anyway because the cost is a line
  // and the failure would be a mystery.
  final addFirst = find.widgetWithText(ElevatedButton, ctx.l.addFirstUser);
  if (addFirst.evaluate().isNotEmpty) {
    await tapVisible(tester, addFirst.first);
  } else {
    await tapVisible(
      tester,
      find.widgetWithText(FloatingActionButton, ctx.l.addUser),
    );
  }

  // 🚨 Waited on the DIALOG, not on its title text — see
  // `create_payment_type_helper` for the failure that rule exists to stop. Here
  // the FAB reads "Add User" and the title "Add New User", so they do not
  // collide today; written the safe way so a rename cannot reintroduce it.
  final dialog = find.byType(AlertDialog);
  await waitFor(
    tester,
    dialog,
    timeout: const Duration(seconds: 30),
    because: 'The user editor never opened.',
  );

  // Scoped to the dialog: the users table behind carries its own "Username" and
  // "Email" column headers.
  await fillField(tester, ctx.l.firstNameRequired, first, within: dialog);
  await fillField(tester, ctx.l.lastNameRequired, last, within: dialog);
  await fillField(tester, ctx.l.usernameRequired, user, within: dialog);
  await fillField(tester, ctx.l.fieldEmail, mail, within: dialog);
  await fillField(tester, ctx.l.passwordRequired, pass, within: dialog);

  await pickDropdown(
    tester,
    ctx.l.accessLevel,
    role == UserRole.admin ? ctx.l.roleAdmin : ctx.l.roleCashier,
    within: dialog,
  );

  await tapVisible(
    tester,
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(ElevatedButton, ctx.l.actionSave),
    ),
  );

  await waitForGone(
    tester,
    dialog,
    timeout: const Duration(seconds: 90),
    because: 'The user editor stayed open — the save did not complete. A '
        'username already taken on this company fails exactly like this.',
  );

  // 🚨 Read from DRIFT, not from `allUsersProvider`, and the distinction cost a
  // full run to find.
  //
  // There are TWO user providers and the Users screen watches the other one:
  //
  //   allUsersProvider        StreamProvider, filters `isEnabled == true`,
  //                           and NOTHING on this screen listens to it
  //   allUsersAdminProvider   autoDispose, NO isEnabled filter, paired with
  //                           `seedUsersFromApiProvider` — this is what renders
  //                           the cards
  //
  // So a `container.read(allUsersProvider)` here is a read of a provider the app
  // is not driving, and it timed out for 60 seconds while the new user's card
  // was plainly on screen and the row was on the server. Querying the table the
  // screen's own provider streams from has no lifecycle to get wrong.
  await waitUntil(
    tester,
    () async => (await _usersInDb(ctx)).any((u) => u.username == user),
    describe: '"$user" reaches the local user table',
    timeout: const Duration(seconds: 60),
  );

  final saved = (await _usersInDb(ctx)).firstWhere((u) => u.username == user);

  // ── Give them a PIN, as an admin would ────────────────────────────────────
  //
  // 🚨 Done HERE rather than left to the pad, so a user this helper returns is
  // one that can actually sign in. Without it the first sign-in meets the pad in
  // CREATE mode — four digits then four again — and every test that switches
  // user pays for that and has to know about it.
  //
  // It uses the Users screen's own "Admin: Reset Device PIN" action, which calls
  // the very same `setDevicePin` the pad does, so the result is indistinguishable
  // from a PIN the user typed themselves.
  await setUserDevicePin(
    tester,
    ctx,
    userId: saved.id,
    email: mail,
    displayName: '$first $last',
    pin: pin,
  );

  ctx.record(E2EArtifact(
    table: 'User',
    name: '$first $last',
    code: user,
    extra: {'Role': role.name, 'Email': mail, 'Id': saved.id},
  ));

  // 🚨 Recorded to `pos-credentials.json`, password and PIN included, because
  // nothing else knows them. The database has the access level and the PIN's
  // HASH; it does not have the PIN itself or the password this run generated —
  // and `11_security_rules` has to actually SIGN IN as these people to watch a
  // rule refuse one of them.
  //
  // Recorded AFTER the PIN is set and verified, so the file can never claim a
  // PIN that was not stored.
  final record = E2EUser(
    userId: saved.id,
    firstName: first,
    lastName: last,
    username: user,
    email: mail,
    password: pass,
    pin: pin,
    accessLevel: role == UserRole.admin ? 0 : 1,
  );
  await recordE2EUser(ctx, record);

  step('User created: $first $last / $user (${role.name}), '
      'password $pass, PIN $pin');
  return record;
}

/// Every user this terminal knows about, straight from Drift.
///
/// The same rows `allUsersAdminProvider` streams — company-scoped, with NO
/// `isEnabled` filter — but read directly, so it does not depend on any provider
/// being alive or listened to at the moment of the call.
Future<List<User>> usersInDb(E2EContext ctx) => _usersInDb(ctx);

Future<List<User>> _usersInDb(E2EContext ctx) async {
  final db = ctx.container.read(appDatabaseProvider);
  final rows = await (db.select(db.usersTable)
        ..where((t) => t.companyId.equals(ctx.company.companyId)))
      .get();
  return rows.map(User.fromDrift).toList();
}
