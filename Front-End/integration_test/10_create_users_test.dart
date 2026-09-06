// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
//
// 10_create_users — one ADMIN and one CASHIER, recorded with their credentials.
//
//   cd Front-End
//   flutter test integration_test/10_create_users_test.dart -d windows
//
// ── Why two, and why both are needed ────────────────────────────────────────
//
// `11_security_rules` locks a permission and then signs in as each of these
// people in turn to watch the till treat them differently. That needs BOTH ends
// of the comparison:
//
//   * the CASHIER is who a rule can actually refuse;
//   * the ADMIN is the control. Without it, "the screen did not open" is equally
//     true of a broken screen, a bad PIN, or a sync that never landed. Watching
//     the same tap succeed for an admin seconds later is what makes the refusal
//     mean the RULE.
//
// 🚨 The admin is a NEW user, not the company's original. Reusing the account the
// whole chain signs in with would prove the bypass while telling us nothing about
// a user this suite created.
//
// ── One pair per company, reused ────────────────────────────────────────────
//
// 🚨 These two have STABLE usernames (`karim.admin.e2e`, `amina.cashier.e2e`),
// unlike every other name this suite generates. A re-run therefore REUSES them
// and just re-sets the PIN, rather than minting a fresh pair each time.
//
// The reason is the PIN screen: its user card shows the display name and the
// role and nothing else. Run-tagged usernames still produce cards reading
// "Karim Admin", so a company accumulated three Aminas and two Karims whose
// cards were indistinguishable — and `11` could not have told which to tap.
//
// ── What gets written to pos-credentials.json ───────────────────────────────
//
// Both users, under the linked company, with their PASSWORD and their PIN.
// Neither exists anywhere else: the database knows the access level, not the
// credentials this run generated. `11` cannot sign in as them without this.
//
// ── It gives each of them a PIN ─────────────────────────────────────────────
//
// Straight after creating a user it uses the Users screen's own **Security
// actions → Admin: Reset Device PIN**, which calls the same `setDevicePin` the
// PIN pad calls. So `11` signs in with ONE four-digit entry rather than meeting
// the create pad (four digits, then four again to confirm).
//
// 🚨 "Device" is literal. The PIN is stored against the user AND this terminal,
// and the hash is written into the local `users` row — that is what makes the
// pad open in verify mode. On another machine these users have no PIN at all.
//
// The stored hash is checked against `base64(sha256(pin))`, so this proves the
// RIGHT PIN was set, not merely that some PIN exists.
//
// ── What it does NOT do ─────────────────────────────────────────────────────
//
// It does not sign in as either of them — `11` does that, and being those people
// is the entire point there.
//
// ── It does NOT register a device ───────────────────────────────────────────
//
// Signs in to the terminal as it already is, so it never spends a licence seat.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/create_user_helper.dart';
import 'helpers/e2e_context.dart';
import 'helpers/login_helper.dart';
import 'helpers/record_users_helper.dart';
import 'support/e2e_support.dart';

/// PINs for the two users, distinct from the company admin's `kPosPin`.
///
/// 🚨 Different from each other on purpose. If both shared a PIN, a run that
/// tapped the wrong user card would still get into the till, and every
/// permission assertion in `11` would then be about the wrong person while
/// looking perfectly green.
const String kAdminPin = '3333';
const String kCashierPin = '4444';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create_users', (tester) async {
    final ctx = E2EContext();

    await loginToCompany(tester, ctx);

    final admin = await createUser(
      tester,
      ctx,
      firstName: 'Karim',
      lastName: 'Admin',
      role: UserRole.admin,
      pin: kAdminPin,
    );

    final cashier = await createUser(
      tester,
      ctx,
      firstName: 'Amina',
      lastName: 'Cashier',
      role: UserRole.cashier,
      pin: kCashierPin,
    );

    // ── One of each, and the levels are what was asked for ────────────────────
    //
    // 🚨 The access level is what makes these users worth creating, so it is read
    // back rather than assumed. The dropdown is keyed on an int — 0 Admin,
    // 1 Cashier — behind localised labels, which is exactly the shape where a
    // mis-picked option saves silently. Two admins would make every assertion in
    // `11` pass for the wrong reason.
    //
    // 🚨 Read from Drift, not `allUsersProvider` — see the note in
    // `create_user_helper`. That provider filters on `isEnabled` and nothing on
    // the Users screen listens to it; the screen renders `allUsersAdminProvider`,
    // which streams the same table with no filter.
    final users = await usersInDb(ctx);

    final savedAdmin = users.firstWhere(
      (u) => u.username == admin.username,
      orElse: () =>
          throw TestFailure('"${admin.username}" is not in the user list'),
    );
    final savedCashier = users.firstWhere(
      (u) => u.username == cashier.username,
      orElse: () =>
          throw TestFailure('"${cashier.username}" is not in the user list'),
    );

    expect(
      savedAdmin.accessLevel,
      0,
      reason: '"${admin.username}" came back at access level '
          '${savedAdmin.accessLevel}, not Admin (0). Without a second admin '
          'there is no control for 11 to compare the cashier against.',
    );
    expect(
      savedCashier.accessLevel,
      1,
      reason: '"${cashier.username}" came back at access level '
          '${savedCashier.accessLevel}, not Cashier (1). A second ADMIN would '
          'make every security-rule assertion pass for the wrong reason.',
    );

    // The company's ORIGINAL admin must survive — the rest of the chain signs in
    // as it, and `11` restores the rules through it.
    expect(
      users.where((u) => u.accessLevel == 0).length,
      greaterThanOrEqualTo(2),
      reason: 'Expected the company admin AND the new admin; found '
          '${users.where((u) => u.accessLevel == 0).length}.',
    );

    // ── Readable back through the loader 11 will use ──────────────────────────
    //
    // 🚨 Read back through `loadE2EUsers` rather than trusting the write, so a
    // broken WRITER fails here — where the fix is obvious — instead of in `11`
    // as "no card for Karim Admin" ninety seconds into a sign-in.
    final recorded = await loadE2EUsers(companyId: ctx.company.companyId);
    expect(
      recorded.map((u) => u.username),
      containsAll(<String>[admin.username, cashier.username]),
      reason: 'The pair did not come back out of pos-credentials.json under a '
          'single run tag, which is what 11 reads.',
    );
    expect(
      recorded.where((u) => u.isAdmin),
      hasLength(1),
      reason: 'The recorded pair must be exactly one admin and one cashier.',
    );
    expect(recorded.where((u) => !u.isAdmin), hasLength(1));

    step('create_users PASSED — admin "${admin.username}" (PIN ${admin.pin}) '
        'and cashier "${cashier.username}" (PIN ${cashier.pin}) recorded for '
        'company ${ctx.company.companyId}');
  });
}
