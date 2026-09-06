// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
// login_new_company — the first-install journey, end to end, against the REAL
// dev server and the REAL database.
//
// It picks up where the Cypress suite stops. `e2e/` provisions a company
// through the admin portal and writes its login to
// `e2e/output/pos-credentials.json`; this test takes that company and walks a
// brand-new terminal all the way to the till:
//
//   wipe this device  →  master login (Dev)  →  onboarding  →  PIN  →  MainLayout
//
// ── Nothing here is mocked ──────────────────────────────────────────────────
//
// 🚨 Nothing is stubbed, and it has to be that way. This test is about device
// registration, the licence lease, onboarding and the PIN — none of which can be
// proved against a fake server, because the thing being tested IS the exchange
// with the real one. So it boots the shipping `main()` and lets every request go
// out. When it passes, the device row, the settings and the PIN are really in
// the database.
//
// That also means it is NOT a unit test and must never run in `flutter test`.
// It lives in integration_test/, which a bare `flutter test` does not collect.
//
// ── Running it ──────────────────────────────────────────────────────────────
//
//   cd Front-End
//   flutter test integration_test/login_new_company_test.dart -d windows
//
// The app opens in a real window and you can watch every step happen.
//
// ── It leaves state behind ──────────────────────────────────────────────────
//
// The run REGISTERS this machine as a terminal of that company and burns one of
// its seats, and it wipes whatever terminal identity this machine already had.
// That is the point of the test, but do not run it on a machine you are using
// as a real till. To undo it:
//   flutter test integration_test/clear_local_data_test.dart -d windows
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_app/auth/login_screen.dart';
import 'package:pos_app/auth/master_login_screen.dart';
import 'package:pos_app/main.dart' as app;
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/onboarding/onboarding_screen.dart';
import 'package:pos_app/settings/device_identity.dart';

import 'config/test_config.dart';
import 'support/e2e_support.dart';

void main() {
  // 🚨 Required, and required FIRST. Without it the test runs on the plain
  // widget binding and never reaches the Windows device at all.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login_new_company', (tester) async {
    final company = loadE2ECompany();

    step('Company ${company.companyId} — ${company.companyName}');
    step('Signing in as ${company.email}');

    // ── 0 · A genuinely fresh terminal ───────────────────────────────────────
    //
    // 🚨 Before `app.main()`, not after. `main()` reads the saved API endpoint
    // and the device-scoped settings synchronously during startup, and the boot
    // decision that picks the first screen reads the saved registration. Clear
    // any of that late and the app has already decided it is a registered
    // terminal, skips master login, and the test walks into a screen it was not
    // expecting.
    //
    // Both stores matter: SharedPreferences holds the device and company ids,
    // secure storage holds the JWT, the durable device token and the signed
    // subscription lease. Leaving either behind keeps this machine registered.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await const FlutterSecureStorage().deleteAll();
    step('Local device identity wiped — this is now an unregistered terminal');

    // 🚨 Re-seed the device id so repeat runs re-register the SAME terminal.
    //
    // The wipe above cleared it, so `getOrCreateDeviceId()` would mint a fresh
    // `POS-<uuid>` — and the server enforces the seat cap at master login. On a
    // company licensed for 3 terminals this test would pass three times and
    // then fail the fourth with "that limit is reached", which looks like a
    // regression and is really just this test leaking a seat per run.
    //
    // The key is AuthStorage's private `_keyDeviceId`; it is spelled out here
    // because that is the one detail this test needs and cannot import.
    if (kDeviceId != null) {
      await prefs.setString('device_id', kDeviceId!);
      step('Device id pinned to $kDeviceId (re-uses one seat)');
    }

    app.main();

    // ── 1 · Master login ─────────────────────────────────────────────────────
    await waitFor(
      tester,
      find.byType(MasterLoginScreen),
      timeout: const Duration(seconds: 120),
      because: 'A wiped device should boot to master login. If it went '
          'somewhere else, the wipe above did not take.',
    );
    step('Master login reached');

    // Every label from here on comes from the app's own delegate, never a
    // hardcoded English string.
    //
    // 🚨 Re-read after each navigation rather than captured once. The locale is
    // decided by the company's `Application.Language`, which arrives during
    // master login — so an instance captured before that call can belong to a
    // different language than the screen being looked at.
    var l = l10nOf(tester);
    step('App language at master login: ${l.localeName}');

    // 🚨 Pick the backend BEFORE typing credentials. `AppConfig` compiles in
    // Production as the default endpoint, so without this tap the terminal
    // registers against the live system and burns a real seat.
    await tapVisible(tester, find.text(kApiEnvironment));
    step('Environment: $kApiEnvironment');

    final emailField = find.widgetWithText(TextField, l.fieldEmail);
    final passwordField = find.widgetWithText(TextField, l.fieldPassword);
    expect(emailField, findsOneWidget);
    expect(passwordField, findsOneWidget);

    await tester.enterText(emailField, company.email);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(passwordField, company.password);
    await tester.pump(const Duration(milliseconds: 200));

    await tapVisible(tester, find.text(l.linkDeviceUpper));
    step('Device registration submitted — waiting on the server');

    // ── 2 · Onboarding ───────────────────────────────────────────────────────
    //
    // Registration pushes straight here on a first install, because every
    // choice onboarding makes has to be written against a company that exists.
    // The wait is long: this single tap registers the device, fetches the
    // licence lease, loads the company, seeds the users and pulls every
    // application setting before it navigates.
    await waitFor(
      tester,
      find.byType(OnboardingScreen),
      timeout: const Duration(seconds: 180),
      because: 'Master login did not complete. A wrong email/password or a '
          'server that is down both stop here — check the app window for the '
          'error banner.',
    );
    l = l10nOf(tester);
    step('Registered. Onboarding started (language: ${l.localeName})');

    // 🚨 Onboarding is navigated by CONTENT, never by counting slides. The
    // controls bar sits below the PageView and is on every slide, so "Next" is
    // always present and tells you nothing about which page you are on. Worse,
    // the data-source slide advances ITSELF when you choose the cloud, so a
    // fixed tap count overshoots by one — which is exactly how an earlier
    // version of this test sailed past Setup and landed on Layout.

    // The data-source choice comes first and has to be made explicitly:
    // "restore from a backup" would replace the database and restart the app,
    // so the cloud path is the only one this test can take. Tapping it also
    // advances the page.
    await advanceUntil(
      tester,
      find.text(l.onboardingCloudTitle),
      l.paginationNext,
    );
    await tapVisible(tester, find.text(l.onboardingCloudTitle));
    step('Data source: sync with the cloud');

    // ── Setup — the only slide this test fills in ────────────────────────────
    final posNameField = find.widgetWithText(TextField, l.deviceNameLower);
    await advanceUntil(tester, posNameField, l.paginationNext);
    step('Setup slide reached');

    await tester.ensureVisible(posNameField);
    await tester.enterText(posNameField, kPosName);
    await tester.pump(const Duration(milliseconds: 300));
    step('POS name: $kPosName');

    // Theme.
    final themeLabel = kThemeMode == 'light' ? l.themeLight : l.themeDark;
    await tapVisible(tester, find.text(themeLabel));
    step('Theme: $themeLabel');

    // Accent. The swatches are the only GestureDetectors inside the Accent
    // row's Wrap, so scoping to it avoids catching a tap target from the
    // scaffold around them.
    final swatches = find.descendant(
      of: find.byType(Wrap),
      matching: find.byType(GestureDetector),
    );
    expect(
      swatches,
      findsWidgets,
      reason: 'No accent swatches on the Setup slide',
    );
    await tapVisible(tester, swatches.at(kAccentIndex));
    step('Accent: swatch $kAccentIndex');

    // Everything else — text size, the feature switches, and the whole Layout
    // and Activity slides — is left exactly as it shipped. The last slide swaps
    // "Next" for "Get Started", so that label is the destination.
    await advanceUntil(tester, find.text(l.getStarted), l.paginationNext);
    await tapVisible(tester, find.text(l.getStarted));
    step('Onboarding finished');

    // ── 3 · POS login and PIN ────────────────────────────────────────────────
    await waitFor(
      tester,
      find.byType(LoginScreen),
      timeout: const Duration(seconds: 120),
    );
    l = l10nOf(tester);
    step('POS login reached');

    // A brand-new company has exactly one user: the admin the portal created.
    final userCard = find.widgetWithText(Card, company.displayName);
    await waitFor(
      tester,
      userCard,
      timeout: const Duration(seconds: 90),
      because: 'No card for "${company.displayName}". The user list is seeded '
          'from the server at master login, so an empty list means that seed '
          'did not arrive.',
    );
    await tapVisible(tester, userCard);
    step('Selected user ${company.displayName}');

    // Wait for the pad itself rather than a particular heading — which heading
    // it shows is the thing being decided below.
    await waitFor(tester, find.widgetWithText(FilledButton, '1'));

    // 🚨 The pad has TWO modes and this test has to survive both, because the
    // second one is what every re-run meets.
    //
    // `_PinPadModal` branches on `user.hasPinForThisDevice`. The very first run
    // creates the PIN: four digits are captured, the pad clears, and four more
    // have to match. But `setDevicePin` stores that PIN against this user AND
    // this device id — and the device id is pinned, so on the next run the same
    // pad opens in VERIFY mode and asks for the PIN once. A test that always
    // typed eight digits would send the last four into an already-authenticated
    // screen the first time it was run twice.
    final creatingPin = find.text(l.createFourDigitPin).evaluate().isNotEmpty;

    if (creatingPin) {
      step('PIN pad is in CREATE mode — first run on this device');
      await _enterPin(tester, kPosPin);

      await waitFor(
        tester,
        find.text(l.confirmNewPin),
        because: 'The pad should ask for confirmation after four digits.',
      );
      await _enterPin(tester, kPosPin);
      step('PIN created and confirmed');
    } else {
      step('PIN pad is in VERIFY mode — this device already knows the user');
      await _enterPin(tester, kPosPin);
      step('PIN accepted');
    }

    // ── 4 · The till ─────────────────────────────────────────────────────────
    //
    // Setting the PIN signs the user in and replaces the whole navigation stack
    // with MainLayout. Reaching it is the success condition: this terminal is
    // registered, onboarded, and trading.
    await waitFor(
      tester,
      find.byType(MainLayout),
      timeout: const Duration(seconds: 180),
      because: 'The PIN was accepted but the till never opened.',
    );

    // Nothing of the sign-in flow should still be on the stack behind it.
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(MasterLoginScreen), findsNothing);

    await pumpFor(tester, const Duration(seconds: 2));

    // ── 5 · The onboarding choices actually stuck ────────────────────────────
    //
    // Reaching the till proves the flow completed; it does not prove anything
    // typed on the way was kept. Both of these are read back from the running
    // app rather than from what the test remembers typing.

    // The terminal's name is device-local truth, and it is also what the admin
    // portal's device list shows instead of the raw POS-<uuid> signature.
    expect(
      await getDeviceName(),
      kPosName,
      reason: 'The POS name from onboarding was not persisted',
    );

    // The theme is asserted on the rendered app, not on the stored setting —
    // a saved value that never reaches MaterialApp is not a light terminal.
    expect(
      Theme.of(tester.element(find.byType(MainLayout))).brightness,
      kThemeMode == 'light' ? Brightness.light : Brightness.dark,
      reason: 'The till is not running the theme onboarding selected',
    );

    step('POS screen open — login_new_company PASSED');
  });
}

/// Taps [pin] on the on-screen pad, one digit at a time.
///
/// The keys are `FilledButton.tonal`s labelled with their digit. Scoped to the
/// modal's own buttons so a digit appearing elsewhere on screen — an order
/// number, a price — can never be mistaken for a key.
Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    final key = find.widgetWithText(FilledButton, digit);
    expect(
      key,
      findsOneWidget,
      reason: 'No "$digit" key on the PIN pad',
    );
    await tester.tap(key);
    // The pad animates a filled dot per keystroke; give it a frame so the
    // fourth digit is not delivered before the third is registered.
    await tester.pump(const Duration(milliseconds: 350));
  }
  await tester.pump(const Duration(milliseconds: 600));
}
