// `sessionGateProvider` watched the whole settings MAP, the whole `Company` and
// the whole session ROW. A `Map` has no value equality, so EVERY settings change
// in the app — a theme, a language, a printer name, a COM port — invalidated the
// gate and re-ran `registerUidProvider`.
//
// The invalidation alone is what crashed a build: `appSettingsProvider` is a
// Notifier that gets marked dirty and flushed LAZILY, inside a widget build, so
// the first widget to watch the gate flushed settings, got a fresh Map, and the
// gate invalidated itself mid-build. Riverpod turns that into `setState() called
// during build`, reported against whatever widget happened to be building —
// which is how it surfaced: an exception naming `BrowserSection`, with nothing
// about sessions in it.
//
// ⚠️ WHAT THESE TESTS CAN AND CANNOT SEE. The gate recomputes to the SAME enum,
// so neither `container.listen` nor `ProviderObserver.didUpdateProvider` can
// observe the wasted rebuild — both are value-based. (Both were tried; both
// passed against the unfixed code, which is the whole reason this comment
// exists.) What is observable, and is pinned below, is `registerUidProvider`
// re-running — two emissions per unrelated settings write — plus every answer
// the gate gives, so the narrowing cannot quietly change what a gate on the
// money path says.
//
// 🚨 These tests use the REAL `registerUidProvider`, not an override. Its
// dependency on the settings map is the thing under test, and an early draft
// overrode it — which made the assertions vacuous. The settings seed a register
// uid so the provider never reaches its `AuthStorage` fallback.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/session/register_identity.dart';
import 'package:pos_app/session/session_gate.dart';
import 'package:pos_app/session/session_provider.dart';

class _FakeSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {
        ...kSettingDefaults,
        // Configured, so the real registerUidProvider never falls back to
        // secure storage — which a unit test has no access to.
        SettingKeys.registerUid: 'reg-1',
      };

  /// Rebuilds with a brand-new Map, exactly as the real notifier does when
  /// `rawAppPropertiesProvider` resolves. The instance always differs; only
  /// `.select` stops that reaching a dependant.
  void put(String key, String value) => state = {...state, key: value};
}

/// Holds a fixed company, so the gate reads a real notifier it can `.select`
/// through rather than a plain value override.
class _FixedCompany extends SelectedCompanyNotifier {
  _FixedCompany(this._company);
  final Company? _company;
  @override
  Company? build() => _company;
}

ShiftsTableData _session(int status) => ShiftsTableData(
      localId: 'sess-1',
      companyId: 1,
      userId: 1,
      startingCash: 0,
      status: status,
      openedAt: DateTime(2026, 8, 30),
      lastModified: DateTime(2026, 8, 30),
      isDrawerShift: true,
      forceClosed: false,
      hasLateArrivals: false,
      syncStatus: 'synced',
    );

typedef _Harness = ({
  ProviderContainer container,
  _FakeSettings settings,
  StreamController<ShiftsTableData?> sessions,
});

_Harness _harness({bool withCompany = true}) {
  final company = withCompany ? Company(id: 1, name: 'Test') : null;
  // A controller rather than `Stream.value`, so a test can leave the session
  // UNRESOLVED — that is the `unknown` branch the fail-open rule hangs on, and
  // it has to be reachable.
  final sessions = StreamController<ShiftsTableData?>.broadcast();
  final container = ProviderContainer(
    overrides: [
      appSettingsProvider.overrideWith(_FakeSettings.new),
      selectedCompanyProvider.overrideWith(() => _FixedCompany(company)),
      activeSessionProvider.overrideWith((ref) => sessions.stream),
    ],
  );
  addTearDown(() {
    container.dispose();
    sessions.close();
  });
  return (
    container: container,
    settings: container.read(appSettingsProvider.notifier) as _FakeSettings,
    sessions: sessions,
  );
}

/// Subscribes to the gate so its dependencies stay alive, and drains the queue.
Future<void> _settle(ProviderContainer c) async {
  c.listen<SessionGate>(sessionGateProvider, (_, __) {});
  await c.read(registerUidProvider.future);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group("a setting that is none of the gate's business", () {
    // Guards the ANSWER rather than the rebuild — see the note at the top of
    // this file about what is observable. A flicker here would be visible to a
    // cashier as the "no session" screen appearing mid-shift.
    test('does not disturb the gate\'s answer', () async {
      final h = _harness();
      var changes = 0;
      h.container.listen<SessionGate>(sessionGateProvider, (_, __) => changes++);
      await _settle(h.container);

      // Settle on a DEFINITE answer first. With the gate parked on `unknown`
      // the flicker is invisible — it flips to unknown and back to unknown —
      // and the test would pass against the very code it exists to catch.
      h.sessions.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(h.container.read(sessionGateProvider), SessionGate.blockedNoSession);
      changes = 0;

      // Each of these produces a FRESH Map, which under the old code
      // invalidated the gate three times over.
      h.settings.put(SettingKeys.customerDisplayCharset, 'cp1256');
      h.settings.put('Application.Language', 'fr');
      h.settings.put(SettingKeys.customerDisplayPort, 'COM9');
      await Future<void>.delayed(Duration.zero);

      expect(changes, 0,
          reason: 'unrelated settings writes moved the session gate');
    });

    test('🚨 does not re-run the register uid', () async {
      final h = _harness();
      var emissions = 0;
      h.container.listen<AsyncValue<String>>(
          registerUidProvider, (_, __) => emissions++);
      await _settle(h.container);
      emissions = 0;

      h.settings.put('Application.Language', 'ar');
      h.settings.put(SettingKeys.customerDisplayPort, 'COM9');
      await Future<void>.delayed(Duration.zero);

      expect(emissions, 0,
          reason: 'a theme or language change reloaded the register identity');

      // The key it DOES depend on must still come through — otherwise this test
      // would pass just as happily against a provider wired to nothing.
      h.settings.put(SettingKeys.registerUid, 'reg-2');
      await Future<void>.delayed(Duration.zero);
      expect(emissions, greaterThan(0));
      expect(await h.container.read(registerUidProvider.future), 'reg-2');
    });

    test('the setting it DOES depend on still gets through', () async {
      final h = _harness();
      await _settle(h.container);
      expect(h.container.read(sessionGateProvider), isNot(SessionGate.allowed));

      // The escape hatch: turning enforcement off restores trading at once.
      h.settings.put(SettingKeys.requireOpenSession, 'false');
      await Future<void>.delayed(Duration.zero);
      expect(h.container.read(sessionGateProvider), SessionGate.allowed);
    });
  });

  group('fail-open contract, unchanged by the narrowing', () {
    test('enforcement off → allowed, whatever else is true', () async {
      final h = _harness(withCompany: false);
      h.settings.put(SettingKeys.requireOpenSession, 'false');
      expect(h.container.read(sessionGateProvider), SessionGate.allowed);
    });

    test('no company → unknown, which sells', () async {
      final h = _harness(withCompany: false);
      expect(h.container.read(sessionGateProvider), SessionGate.unknown);
    });

    test('session still loading → unknown, which sells', () async {
      final h = _harness();
      await _settle(h.container);
      expect(h.container.read(sessionGateProvider), SessionGate.unknown);
    });

    test('a failed session query → unknown, which sells', () async {
      final h = _harness();
      await _settle(h.container);
      h.sessions.addError(StateError('drift hiccup'));
      await Future<void>.delayed(Duration.zero);
      expect(h.container.read(sessionGateProvider), SessionGate.unknown);
    });
  });

  group('the answers themselves', () {
    Future<SessionGate> gateFor(int? status) async {
      final h = _harness();
      await _settle(h.container);
      h.sessions.add(status == null ? null : _session(status));
      await Future<void>.delayed(Duration.zero);
      return h.container.read(sessionGateProvider);
    }

    test('no open session → blocked, the one positive block', () async {
      expect(await gateFor(null), SessionGate.blockedNoSession);
    });

    test('OPENED → allowed', () async {
      expect(await gateFor(PosSessionStatus.opened), SessionGate.allowed);
    });

    test('counting the drawer → blocked, but not "no session"', () async {
      expect(await gateFor(PosSessionStatus.closingControl),
          SessionGate.blockedNotTrading);
      expect(await gateFor(PosSessionStatus.openingControl),
          SessionGate.blockedNotTrading);
    });
  });
}
