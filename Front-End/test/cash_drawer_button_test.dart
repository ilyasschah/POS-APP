// The till's "Open Drawer" button is only as good as the rule in front of it.
//
// 🚨 What this pins. `CashDrawer.Open` has existed in the seeded key set since
// before the hardware was wired, but nothing on the sales floor ever asked
// about it — the button did not exist. Now it does, and the refusal has to be a
// DIALOG: a cashier who taps "Open Drawer" beside a drawer that does not move
// reads a toast (if they catch it at all) as broken hardware and calls it in as
// a hardware fault. The dialog names the fix — fetch an administrator.
//
// The second trap is the empty rule set. A freshly enrolled terminal that has
// not synced yet denies a cashier everything, and answering "ask an admin"
// there sends them to a manager who cannot help. That case says "sync first".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/security/security_guard.dart';
import 'package:pos_app/security/security_key_model.dart';
import 'package:pos_app/security/security_keys.dart';

void main() {
  User user(int accessLevel) => User(
        id: 1,
        companyId: 1,
        username: 'u',
        accessLevel: accessLevel,
        isEnabled: true,
      );

  final adminOnly = [
    SecurityKeyModel(name: SecurityKeys.cashDrawerOpen, level: 1),
  ];
  final cashierMay = [
    SecurityKeyModel(name: SecurityKeys.cashDrawerOpen, level: 0),
  ];

  /// Pumps one button wired exactly as the till header wires it.
  Future<int Function()> pumpButton(
    WidgetTester tester,
    SecurityGuard guard,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => guard.guardWithDialog(
                context,
                SecurityKeys.cashDrawerOpen,
                () => opened++,
              ),
              child: const Text('Open Drawer'),
            ),
          ),
        ),
      ),
    );
    return () => opened;
  }

  testWidgets('an admin pops the drawer with no dialog in the way',
      (tester) async {
    // Level 1 on the key, and it still opens: accessLevel 0 never consults it.
    final opened =
        await pumpButton(tester, SecurityGuard(user(0), adminOnly, 3, 'Bottom'));

    await tester.tap(find.text('Open Drawer'));
    await tester.pumpAndSettle();

    expect(opened(), 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a cashier is stopped and told to fetch an administrator',
      (tester) async {
    final opened =
        await pumpButton(tester, SecurityGuard(user(1), adminOnly, 3, 'Bottom'));

    await tester.tap(find.text('Open Drawer'));
    await tester.pumpAndSettle();

    expect(opened(), 0, reason: 'no kick may reach the hardware');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Ask an administrator'), findsOneWidget);

    // It is a dialog, not a toast: it stays until dismissed.
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the same cashier opens it once the rule is set to level 0',
      (tester) async {
    final opened = await pumpButton(
        tester, SecurityGuard(user(1), cashierMay, 3, 'Bottom'));

    await tester.tap(find.text('Open Drawer'));
    await tester.pumpAndSettle();

    expect(opened(), 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a terminal with no rules yet blames the sync, not the cashier',
      (tester) async {
    final opened =
        await pumpButton(tester, SecurityGuard(user(1), const [], 3, 'Bottom'));

    await tester.tap(find.text('Open Drawer'));
    await tester.pumpAndSettle();

    expect(opened(), 0);
    expect(find.textContaining('Ask an administrator'), findsNothing);
    expect(find.textContaining('sync'), findsOneWidget);
  });

  test('the key name matches the one the API seeds', () {
    // CompanyDefaultsSeeder.DefaultSecurityKeys and users_screen.dart both
    // spell it this way. A rename here silently denies everyone: canAccess
    // treats an unknown key as admin-only.
    expect(SecurityKeys.cashDrawerOpen, 'CashDrawer.Open');
  });
}
