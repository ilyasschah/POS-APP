// Pins the feature seed: pre-login onboarding parks the per-company choices
// (virtual keyboard / tables / booking) device-locally, and they survive until
// the first login applies them. (applyToCompanySettings needs a live company +
// appSettings, so it's exercised manually / in integration, not here.)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/onboarding/onboarding_seed.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> boot({Map<String, Object> initial = const {}}) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a fresh device has an empty seed', () async {
    final c = await boot();
    expect(c.read(onboardingFeatureSeedProvider).isEmpty, isTrue);
  });

  test('each choice is stored and reflected in state', () async {
    final c = await boot();
    final notifier = c.read(onboardingFeatureSeedProvider.notifier);
    await notifier.setTables(false);
    await notifier.setVirtualKeyboard(true);

    final seed = c.read(onboardingFeatureSeedProvider);
    expect(seed.tables, isFalse);
    expect(seed.virtualKeyboard, isTrue);
    expect(seed.booking, isNull); // untouched
    expect(seed.isEmpty, isFalse);
  });

  test('parked choices persist across a relaunch (until applied on login)',
      () async {
    final c = await boot();
    await c.read(onboardingFeatureSeedProvider.notifier).setBooking(false);

    final prefs = await SharedPreferences.getInstance();
    final relaunch = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(relaunch.dispose);
    expect(relaunch.read(onboardingFeatureSeedProvider).booking, isFalse);
  });
}
