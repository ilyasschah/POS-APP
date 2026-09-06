/// `ensureRegisterOpen` / `ensureTablelessAllowed` — getting a till ready to trade.
///
/// ```dart
/// await loginToCompany(tester, ctx);
/// await ensureRegisterOpen(tester, ctx);
/// await ensureTablelessAllowed(tester, ctx);
/// ```
///
/// Separate from `make_sale_helper.dart` because it is a separate question. A
/// test about session handling wants these without a sale; a test about the
/// money path wants a sale and does not care how the drawer got open.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/session/session_gate.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Opens the register when there is no live session on it.
///
/// 🚨 Without this the browser renders `SessionBlockedScreen` instead of the
/// product grid — no search field, no cards, nothing to tap — because
/// `sessionGateProvider` blocks the whole till behind "Open the register first".
/// That is correct behaviour and the first thing a selling test has to learn.
///
/// 🚨 A session belongs to a REGISTER, not to a device. `activeSessionProvider`
/// matches a session row's `posDeviceUid` against **`registerUidProvider`** —
/// which reads the `PosSession.RegisterUid` setting and falls back to the
/// machine's real device GUID when that is blank. It is NOT `deviceUidProvider`.
/// Get that wrong and the symptom points nowhere near the cause.
Future<void> ensureRegisterOpen(WidgetTester tester, E2EContext ctx) async {
  // 🚨 Ask the GATE, not the screen.
  //
  // `sessionGateProvider` starts `unknown` while the company, the register uid
  // and the session row are still resolving — and `unknown` deliberately RENDERS
  // THE GRID, because a till that cannot answer the question must never be the
  // reason a shop stops trading. So "no blocked screen on this frame" is not
  // "the register is open"; it is very often "the gate has not decided yet", and
  // a test reading it that way sails past here and fails on a missing product
  // card several steps later.
  var gate = ctx.container.read(sessionGateProvider);
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (gate == SessionGate.unknown && DateTime.now().isBefore(deadline)) {
    await pumpFor(tester, const Duration(milliseconds: 500));
    gate = ctx.container.read(sessionGateProvider);
  }

  if (gate != SessionGate.blockedNoSession &&
      gate != SessionGate.blockedNotTrading) {
    step('Register trading (gate: ${gate.name})');
    return;
  }

  // A session in opening or closing control must be FINISHED, not opened over
  // the top — the blocked screen does not even offer to open one.
  if (gate == SessionGate.blockedNotTrading) {
    throw TestFailure(
      'This register has a session that is not trading (opening or closing '
      'control). Finish it before selling from here.',
    );
  }

  await waitFor(
    tester,
    find.byType(SessionBlockedScreen),
    timeout: const Duration(seconds: 30),
    because: 'The gate says there is no open session, so the till should be '
        'showing the "Open Register" screen.',
  );

  // Nothing to open when the drawer is already live somewhere else: that one has
  // to be JOINED, and a second session on the same register is exactly what this
  // screen exists to prevent.
  if (find.text(ctx.l.sessionJoinRegister).evaluate().isNotEmpty) {
    throw TestFailure(
      'This register has a session open on another terminal. Join or close it '
      'before selling from here.',
    );
  }

  step('No open session — opening the register');
  await tapVisible(tester, find.text(ctx.l.openRegister));
  await waitFor(tester, find.text(ctx.l.openingControl));

  // The opening float defaults to 0.00 and these tests have no opinion about it
  // — what is being proved is that a sale banks, not what the drawer started
  // with.
  //
  // 🚨 Scoped to the dialog. The blocked screen underneath carries its own
  // "Open Register" button with the SAME label, and it is FIRST in tree order —
  // an unscoped tap lands behind the modal barrier and the dialog just sits
  // there until the test times out.
  await tapVisible(
    tester,
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, ctx.l.openRegister),
    ),
  );

  await waitForGone(
    tester,
    find.text(ctx.l.openingControl),
    timeout: const Duration(seconds: 90),
  );
  await waitForGone(
    tester,
    find.byType(SessionBlockedScreen),
    timeout: const Duration(seconds: 60),
  );

  // Re-read after the navigation, as everything here does. The till renders a
  // different subtree once the gate unblocks, and `ctx.l` must come from the
  // tree that is actually on screen.
  ctx.refreshL10n(tester);
  step('Register opened');
}

/// Makes sure a product tap can start an order without picking a table first.
///
/// 🚨 `Order.AllowTablelessOrders` ships FALSE with the floor plan on, and at
/// those defaults a tap on a product does not ring it up: it says "select a
/// table from the floor plan" and returns. That is real behaviour worth its own
/// test — it is not the one being written here, which is about a counter-service
/// till where a tap is a sale.
///
/// Flipped through the app's own settings notifier rather than by overriding a
/// provider: these tests boot the shipping `main()`, so there is no override
/// seam, and the notifier is the same path the Settings screen writes through.
///
/// 🚨 It DOES change that company's setting. Acceptable on an E2E company, and
/// one more reason never to point these tests at a real till.
Future<void> ensureTablelessAllowed(WidgetTester tester, E2EContext ctx) async {
  final settings = ctx.container.read(appSettingsProvider);
  final floorPlanOn =
      settings[SettingKeys.featureFloorPlanEnabled]?.toLowerCase() == 'true';
  final tablelessOn =
      settings[SettingKeys.allowTablelessOrders]?.toLowerCase() == 'true';

  if (!floorPlanOn || tablelessOn) return;

  await ctx.container
      .read(appSettingsProvider.notifier)
      .setBool(SettingKeys.allowTablelessOrders, true);
  await pumpFor(tester, const Duration(seconds: 2));
  step('Tableless orders enabled — this till sells over the counter');
}
