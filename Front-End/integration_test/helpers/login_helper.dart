/// `loginToCompany` — boots the app and signs in on an already-linked terminal.
///
/// The first call in almost every recipe, and the one every other helper
/// assumes has already run:
///
/// ```dart
/// final ctx = E2EContext();
/// await loginToCompany(tester, ctx);
/// await createProduct(tester, ctx);
/// ```
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/main.dart' as app;

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Signs in to the terminal AS IT ALREADY IS and fills in [ctx].
///
/// 🚨 It never registers a device, and that is the point of the whole modular
/// suite. `login_new_company` proves the first-install path, and to do that it
/// must wipe and re-register — the one action that spends a licence seat. Every
/// helper-driven test starts from a linked terminal instead, so it can be run as
/// often as you like and costs nothing.
///
/// ## It does NOT set the language
///
/// That moved to `set_language_helper.dart`, deliberately. Switching the
/// language writes the COMPANY's `Application.Language`, so it is a one-time
/// setup for a terminal rather than something every test should do on its way
/// in — and the helpers do not need it anyway, because none of them hardcodes a
/// UI string. They read `ctx.l`, which follows whatever language the app is
/// actually in.
///
/// What this DOES do is wait for that language to stop moving. See below.
Future<void> loginToCompany(
  WidgetTester tester,
  E2EContext ctx, {
  bool bootApp = true,
}) async {
  // Sub-pixel RenderFlex overflows only — a real one still fails loudly.
  tolerateSubPixelOverflows();

  // The company this terminal is ALREADY linked to, which is not simply the
  // newest one Cypress provisioned. Confusing the two is the trap documented on
  // loadLinkedCompany(): the PIN screen of the wrong company is a perfectly
  // healthy screen, so the mismatch would otherwise surface 90 seconds later as
  // a missing user card.
  ctx.company = await loadLinkedCompany();
  step('Company ${ctx.company.companyId} — ${ctx.company.companyName}');

  if (bootApp) app.main();

  ctx.container = await signInToTill(tester, ctx.company);

  // 🚨 Wait for the locale to SETTLE before handing `ctx.l` to anything.
  //
  // The terminal renders the PIN screen in whatever language it had cached, and
  // the company's real `Application.Language` arrives with the post-sign-in
  // sync — so the app can be French at the PIN pad and English two screens
  // later. A recipe that took `ctx.l` straight from sign-in would then hunt for
  // French labels on an English screen and fail somewhere that looks unrelated,
  // which is exactly how this helper failed with `No dropdown labelled
  // "Langue"` against a screen reading `ENGLISH | Language`.
  final locale = await waitForStableLocale(tester);
  ctx.refreshL10n(tester);
  step('Till language settled: $locale');
}
