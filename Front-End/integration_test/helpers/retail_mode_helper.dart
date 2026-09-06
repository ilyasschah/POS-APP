/// `configureRetailMode` — turns the till into a counter-service shop.
///
/// ```dart
/// await loginToCompany(tester, ctx);
/// await configureRetailMode(tester, ctx);
/// ```
///
/// ## What "retail" means here
///
/// A shop with a counter and a scanner: no floor plan, no bookings, and no
/// order to park and come back to. A tap or a scan rings up, PAY finishes.
///
/// | setting | retail | why |
/// |---|---|---|
/// | `Feature_FloorPlan_Enabled` | **false** | no tables to seat anyone at |
/// | `Feature_Booking_Enabled` | **false** | nobody reserves a till |
/// | `Order.AllowTablelessOrders` | **true** | a tap must ring up on its own |
/// | `ButtonBar.ShowTables` | false | the button would open a disabled feature |
/// | `ButtonBar.ShowBooking` | false | same |
/// | `ButtonBar.ShowSearch` | **true** | this is where a SCAN lands |
/// | `App.DefaultScreen` | `POS` | never boot to a screen that is switched off |
///
/// 🚨 `ShowSearch` is forced ON, not left alone. The till's search field is the
/// widget wired to `onSubmitted: _handleBarcodeSubmit` — it is where a scanner's
/// keystrokes arrive. A shop that sells by scanning literally cannot trade
/// without it, and with it off the failure reads as "no search field" several
/// steps after the setting that caused it.
///
/// 🚨 **Saving an order CANNOT be switched off.** An earlier version of this
/// file claimed it was a consequence of disabling the floor plan. That is wrong:
/// the SAVE button on the till is gated only by `cartItems.isNotEmpty`
/// (`menu_screen.dart`) — no feature flag, no `ButtonBar.ShowSave`, nothing. A
/// tableless order parks perfectly well as an open ticket.
///
/// So "no saving orders" is a property of the SCENARIO, not of the
/// configuration: this flow scans and pays, and never touches SAVE. If the shop
/// genuinely must not offer it, that is a missing setting in the app rather than
/// something a test can arrange — see TEST_PLAN.md §2.
///
/// 🚨 It WRITES the company's settings, so it changes the shop for every
/// terminal on it. That is the point — these are E2E companies configured for a
/// scenario — and one more reason never to point this at a real till.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// What the app concludes when a flag's key is not in the settings map at all.
///
/// Two readers exist in `lib/`, and they disagree:
///
/// ```dart
/// settings[SettingKeys.featureFloorPlanEnabled]?.toLowerCase() == 'true'   // absent → OFF
/// settings[SettingKeys.showSearchBtn]?.toLowerCase()          != 'false'   // absent → ON
/// ```
enum _Absent { on, off }

/// Reads a flag exactly the way the app reads it.
///
/// A present value written by `setBool` is always `'true'` or `'false'`, so both
/// readers agree on it — the difference only bites on an ABSENT key, which is
/// the normal state for a company that has never touched that setting.
bool _isOn(String? raw, _Absent absent) {
  if (raw == null) return absent == _Absent.on;
  final v = raw.toLowerCase();
  return absent == _Absent.on ? v != 'false' : v == 'true';
}

/// Configures the linked company as a retail shop.
///
/// Only writes what is actually wrong, so a company already in retail mode costs
/// nothing and the run says so.
Future<void> configureRetailMode(WidgetTester tester, E2EContext ctx) async {
  // 🚨 These two families are read DIFFERENTLY when the key is absent, and
  // assuming one rule for both gets the answer wrong in one direction or the
  // other. Verified against the readers in `lib/`:
  //
  //   Feature_*      `settings[k]?.toLowerCase() == 'true'`   absent → OFF
  //   ButtonBar.*    `settings[k]?.toLowerCase() != 'false'`  absent → ON
  //
  // A blanket `== 'true'` would decide the search bar was off on a company that
  // has never written that key, and "fix" a setting that was never wrong; a
  // blanket `!= 'false'` would decide the floor plan was on for the same reason.
  // Neither breaks loudly — they just make this helper write settings it should
  // not and report changes that did not happen.
  final wanted = <String, ({bool value, _Absent absent})>{
    SettingKeys.featureFloorPlanEnabled: (value: false, absent: _Absent.off),
    SettingKeys.featureBookingEnabled: (value: false, absent: _Absent.off),
    SettingKeys.allowTablelessOrders: (value: true, absent: _Absent.off),
    SettingKeys.showTablesBtn: (value: false, absent: _Absent.on),
    SettingKeys.showBookingBtn: (value: false, absent: _Absent.on),
    // Where a scan LANDS. Without it there is no way to ring anything up on a
    // scanner-driven till, and the failure surfaces as "no search field" far
    // from the setting that caused it.
    SettingKeys.showSearchBtn: (value: true, absent: _Absent.on),
  };

  final settings = ctx.container.read(appSettingsProvider);
  final notifier = ctx.container.read(appSettingsProvider.notifier);

  final changed = <String>[];
  for (final entry in wanted.entries) {
    final current = _isOn(settings[entry.key], entry.value.absent);
    if (current == entry.value.value) continue;
    await notifier.setBool(entry.key, entry.value.value);
    changed.add('${entry.key}=${entry.value.value}');
  }

  // 🚨 Never leave the till booting to a screen that has just been switched
  // off. `App.DefaultScreen` is 'POS' | 'Tables' | 'Booking', and a company left
  // on 'Tables' with the floor plan disabled lands on a dead tab — which reads
  // as "the till did not open" rather than as a settings problem.
  if (settings[SettingKeys.defaultScreen] != 'POS') {
    await notifier.set(SettingKeys.defaultScreen, 'POS');
    changed.add('${SettingKeys.defaultScreen}=POS');
  }

  if (changed.isEmpty) {
    step('Retail mode already configured');
  } else {
    await pumpFor(tester, const Duration(seconds: 2));
    step('Retail mode set — ${changed.join(', ')}');
  }
}
