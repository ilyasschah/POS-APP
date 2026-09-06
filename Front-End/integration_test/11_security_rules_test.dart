// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
//
// 11_security_rules — a real shift change, with a permission in the way.
//
//   as the company admin  → lock Settings and Management to admin-only
//   sign out              → sign in as the ADMIN 10 created
//                             · Settings opens
//                             · Management opens
//   sign out              → sign in as the CASHIER 10 created
//                             · Settings is REFUSED
//                             · Management is REFUSED
//   sign out              → back as the company admin, put both rules back
//
//   cd Front-End
//   flutter test integration_test/11_security_rules_test.dart -d windows
//
// ── Why it signs in as each person ──────────────────────────────────────────
//
// `SecurityGuard.canAccess` short-circuits on `accessLevel == 0`: an admin is
// allowed everything and the key is never even consulted. So a test that stayed
// signed in as an admin could lock every rule in the app and never see a single
// refusal — it would be measuring the account, not the rule.
//
// The only way to watch a permission actually stop somebody is to BE that
// somebody. That is what the two users from `10` are for, and why this test does
// a real sign-out and sign-in for each of them rather than asking the guard
// class what it would have said.
//
// 🚨 The admin half is not decoration. Without it, "the screen did not open" is
// equally true of a broken screen, a mistyped PIN, or rules that never synced.
// Watching the same tap succeed for an admin seconds later is what makes the
// cashier's refusal mean the RULE.
//
// ── The PINs come from 10, and are entered ONCE ─────────────────────────────
//
// `10_create_users` sets each user's PIN through the Users screen's "Admin:
// Reset Device PIN" action, so the pad here opens in VERIFY mode: one four-digit
// entry, no confirmation.
//
// 🚨 If the pad asks to CREATE a PIN instead, `signInAsUser` fails rather than
// typing it twice. That state means `10` never ran on this terminal, and quietly
// creating the PIN would SET a value this test merely assumed — going green
// while proving nothing about what `10` was supposed to leave behind.
//
// ── It puts the rules back ──────────────────────────────────────────────────
//
// 🚨 Security rules are COMPANY-WIDE, and `Management` gates the portal every
// other test in the chain drives. Leaving it admin-only would not break the
// chain — the chain signs in as an admin — but it would silently change the shop
// for every terminal on it. Both rules are restored through the company admin,
// and the restore is asserted.
//
// ── It does NOT register a device ───────────────────────────────────────────
//
// Signs in to the terminal as it already is, so it never spends a licence seat.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:pos_app/security/security_keys.dart';

import 'helpers/e2e_context.dart';
import 'helpers/guarded_access_helper.dart';
import 'helpers/login_helper.dart';
import 'helpers/record_users_helper.dart';
import 'helpers/security_rule_helper.dart';
import 'helpers/switch_user_helper.dart';
import 'support/e2e_support.dart';

/// The two rules this test locks, and the screens they gate.
const Map<String, GuardedScreen> kRulesUnderTest = {
  SecurityKeys.settings: GuardedScreen.settings,
  SecurityKeys.management: GuardedScreen.management,
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('security_rules', (tester) async {
    final ctx = E2EContext();

    // ── 1 · Always start as the company admin ─────────────────────────────────
    //
    // The rules screen itself lives inside Management, which this test is about
    // to lock — so the account that changes the rules has to be one the lock
    // cannot shut out.
    await loginToCompany(tester, ctx);

    // The pair `10` created, read back with the PINs it chose. They exist
    // nowhere else: the database knows the access level, not the credentials.
    final users = await loadE2EUsers(companyId: ctx.company.companyId);
    final newAdmin = users.firstWhere(
      (u) => u.isAdmin,
      orElse: () => throw TestFailure(
        'No admin recorded for this company.\n'
        'Run: flutter test integration_test/10_create_users_test.dart -d windows',
      ),
    );
    final cashier = users.firstWhere(
      (u) => !u.isAdmin,
      orElse: () => throw TestFailure(
        'No cashier recorded for this company — there is nobody a rule can '
        'refuse, so every assertion here would pass vacuously.\n'
        'Run: flutter test integration_test/10_create_users_test.dart -d windows',
      ),
    );
    step('Scenario: admin "${newAdmin.username}" vs cashier '
        '"${cashier.username}"');

    // ── 2 · Lock both rules ───────────────────────────────────────────────────
    final restore = <String, SecurityLevel>{};
    for (final key in kRulesUnderTest.keys) {
      restore[key] =
          await setSecurityLevel(tester, ctx, key, SecurityLevel.adminOnly);
    }
    step('Locked: ${kRulesUnderTest.keys.join(', ')} are admin-only');

    // ── 3 · The new ADMIN still gets in ───────────────────────────────────────
    await logoutFromTill(tester, ctx);
    await signInAsUser(tester, ctx, newAdmin);

    for (final entry in kRulesUnderTest.entries) {
      await expectGuardedScreen(tester, ctx, entry.value, allowed: true);
    }
    step('${newAdmin.username} (Admin) reached both locked screens');

    // ── 4 · The CASHIER is refused ────────────────────────────────────────────
    await logoutFromTill(tester, ctx);
    await signInAsUser(tester, ctx, cashier);

    for (final entry in kRulesUnderTest.entries) {
      await expectGuardedScreen(tester, ctx, entry.value, allowed: false);
    }
    step('${cashier.username} (Cashier) was refused both');

    // ── 5 · Back as the company admin, and put the rules back ─────────────────
    //
    // 🚨 Through the COMPANY admin, not the cashier currently signed in — the
    // rules screen lives inside Management, which that cashier has just been
    // refused. Signing back in as an account the lock cannot shut out is the
    // only way to undo it.
    //
    // `bootApp: false` because the app is already running; calling `main()` a
    // second time would stack a whole second app over the first.
    await logoutFromTill(tester, ctx);
    await loginToCompany(tester, ctx, bootApp: false);

    for (final entry in restore.entries) {
      await setSecurityLevel(tester, ctx, entry.key, entry.value);
    }

    // Prove the unlock landed rather than assuming it. A restore that silently
    // failed would leave the shop locked for every terminal on this company.
    for (final entry in restore.entries) {
      expect(
        await securityLevelOf(ctx, entry.key),
        entry.value,
        reason: '"${entry.key}" was not restored to ${entry.value.name}. The '
            'company is left carrying a permission this test invented.',
      );
    }
    step('Restored: '
        '${restore.entries.map((e) => '${e.key}=${e.value.name}').join(', ')}');

    step('security_rules PASSED — admin got in, cashier was refused, '
        'rules put back');
  });
}
