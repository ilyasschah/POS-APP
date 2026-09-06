/// `expectGuardedScreen` — taps a permission-guarded control and asserts whether
/// the person at the till got in.
///
/// ```dart
/// await expectGuardedScreen(tester, ctx, GuardedScreen.management,
///     allowed: true);
/// ```
///
/// ## What a refusal actually looks like
///
/// `SecurityGuard.guard` does not throw, navigate, or disable the control. It
/// runs the tap handler for an allowed user and, for a denied one, shows a TOAST
/// and returns. So the observable difference is entirely "did the screen open".
///
/// 🚨 The screen is therefore the primary assertion and the toast is the
/// corroborating one — never the other way round. The toast is an `OverlayEntry`
/// on a timer: it slides away after `Message.Duration` seconds, so a test that
/// waited for the screen first and looked for the toast afterwards would be
/// hunting something that had already gone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/navigation/management_layout.dart';
import 'package:pos_app/settings/settings_screen.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// The guarded destinations this helper knows how to open.
enum GuardedScreen {
  /// Sidebar → Management. Guarded by `SecurityKeys.management`.
  management,

  /// Sidebar → the ⋮ Quick Settings button. Guarded by `SecurityKeys.settings`.
  settings,
}

/// Taps [screen]'s entry point and asserts the outcome matches [allowed].
///
/// Leaves the app back on the till either way, so it can be called repeatedly.
Future<void> expectGuardedScreen(
  WidgetTester tester,
  E2EContext ctx,
  GuardedScreen screen, {
  required bool allowed,
}) async {
  final target = switch (screen) {
    GuardedScreen.management => find.byType(ManagementLayout),
    GuardedScreen.settings => find.byType(SettingsScreen),
  };

  await openSidebar(tester);
  ctx.refreshL10n(tester);

  // 🚨 Management is reached by its LABEL, Quick Settings by `sidebarIconButton`
  // — and neither is arbitrary.
  //
  // A bare `find.byIcon(Icons.tune)` is AMBIGUOUS here: `MenuScreen` draws the
  // same icon on its Modifiers button, the body comes first in tree order, and
  // that button is DISABLED while the cart is empty. So `.first` tapped a dead
  // control, nothing happened, and this helper waited sixty seconds for a screen
  // nobody had asked to open. `sidebarIconButton` matches the sidebar's own
  // widget type instead.
  //
  // Management has a real label and no unique icon, so it stays on text.
  final trigger = switch (screen) {
    GuardedScreen.management => find.text(ctx.l.management),
    GuardedScreen.settings => sidebarIconButton(Icons.tune),
  };
  await tapVisible(tester, trigger.first);

  if (allowed) {
    await waitFor(
      tester,
      target,
      timeout: const Duration(seconds: 60),
      because: '${screen.name} did not open for '
          '"${ctx.container.read(currentUserProvider)?.username}", who should '
          'be allowed. A rule left admin-only by an earlier run that died '
          'before restoring looks exactly like this.',
    );
    step('${screen.name}: opened, as expected');
    await _leave(tester, ctx, screen);
    return;
  }

  // ── Denied ────────────────────────────────────────────────────────────────
  //
  // 🚨 Pump for a bounded time and assert the screen NEVER arrives, rather than
  // checking once. A single check straight after the tap would pass while the
  // route was still pushing — reporting a refusal that had not happened yet.
  final deadline = DateTime.now().add(const Duration(seconds: 6));
  var sawToast = false;
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));

    if (target.evaluate().isNotEmpty) {
      throw TestFailure(
        '${screen.name} OPENED for a user who should have been refused.\n'
        '  The rule is set to admin-only, so this is either the wrong user '
        'signed in or the guard not consulting the rule.\n'
        '  On screen now: ${visibleTexts(tester)}',
      );
    }

    // Catch the toast WHILE it is up. It is an OverlayEntry on a timer, so this
    // is checked every tick rather than once at the end.
    if (!sawToast &&
        find.text(ctx.l.accessDeniedNoPermission).evaluate().isNotEmpty) {
      sawToast = true;
    }
  }

  // The toast corroborates; its absence is worth saying out loud but is not
  // proof of a bug on its own — a slow machine can miss a three-second overlay.
  step('${screen.name}: refused'
      '${sawToast ? ' (denial toast seen)' : ' (toast not caught — it is a '
          'timed overlay; the screen not opening is the assertion)'}');

  // The sidebar is still open behind the refusal; close it so the next call
  // starts from the same place a fresh one would.
  if (find.text(ctx.l.management).evaluate().isNotEmpty) {
    await tapVisible(tester, find.byType(MainLayout));
  }
  await pumpFor(tester, const Duration(seconds: 1));
}

/// Backs out of a screen that DID open.
Future<void> _leave(
  WidgetTester tester,
  E2EContext ctx,
  GuardedScreen screen,
) async {
  switch (screen) {
    case GuardedScreen.management:
      await exitManagement(tester, ctx.l);
    case GuardedScreen.settings:
      await tester.pageBack();
      await waitForGone(
        tester,
        find.byType(SettingsScreen),
        timeout: const Duration(seconds: 30),
      );
  }
  await pumpFor(tester, const Duration(seconds: 1));
  ctx.refreshL10n(tester);
}
