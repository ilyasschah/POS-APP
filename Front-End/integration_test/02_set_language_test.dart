// ignore_for_file: file_names
//
// The leading number is the RUN ORDER, and it is worth the lint. These tests
// are a chain — each one leaves the state the next one needs — so the order is
// the single most important thing about them, and a directory listing that
// sorts into it beats a naming convention. See integration_test/README.md.
// set_language — pins this terminal's UI language. Run it ONCE, not per-test.
//
//   cd Front-End
//   flutter test integration_test/set_language_test.dart -d windows
//
// Change which language in `config/test_config.dart` (`kLanguageCode`), or pass
// nothing and take the default.
//
// ── Why this is a test of its own ───────────────────────────────────────────
//
// 🚨 It writes the COMPANY's `Application.Language`, not a local preference. So
// it changes the language for every terminal on that company and for the owner
// dashboard — which is a real change, worth making deliberately rather than as a
// side effect of every other test signing in.
//
// It is also not a prerequisite for anything. The helpers never hardcode a UI
// string; they read `ctx.l` and follow whatever language the app is in. This
// exists so a HUMAN watching a run sees labels they can read, and so a language
// left behind by a previous experiment can be put back.
//
// ── It does NOT register a device ───────────────────────────────────────────
//
// Signs in to the terminal as it already is, so it never spends a licence seat.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'config/test_config.dart';
import 'helpers/e2e_context.dart';
import 'helpers/login_helper.dart';
import 'helpers/set_language_helper.dart';
import 'support/e2e_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('set_language', (tester) async {
    final ctx = E2EContext();

    await loginToCompany(tester, ctx);
    await setTerminalLanguage(tester, ctx, kLanguageCode);

    // Read back from the LIVE tree rather than trusting the helper's own report,
    // so a switch that only appeared to take is caught here.
    ctx.refreshL10n(tester);
    expect(
      ctx.l.localeName,
      kLanguageCode,
      reason: 'The terminal did not end up in $kLanguageCode.',
    );

    step('set_language PASSED — terminal is now in ${ctx.l.localeName}');
  });
}
