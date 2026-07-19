// Pins the first-run flag that gates onboarding: a fresh device shows it, a
// returning device skips it, completing persists across relaunches, and reset
// re-arms it. This is the contract MyApp's reactive `home:` gate depends on.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/onboarding/onboarding_prefs.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Boots a container over a mock SharedPreferences seeded with [initial],
  // mirroring how main() overrides the provider with a real instance.
  Future<ProviderContainer> boot({Map<String, Object> initial = const {}}) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a fresh install has not completed onboarding', () async {
    final c = await boot();
    expect(c.read(onboardingCompleteProvider), isFalse);
  });

  test('a returning device that finished onboarding skips it', () async {
    final c = await boot(initial: {'onboarding_complete_v1': true});
    expect(c.read(onboardingCompleteProvider), isTrue);
  });

  test('complete() flips the flag and persists it across a relaunch', () async {
    final c = await boot();
    await c.read(onboardingCompleteProvider.notifier).complete();
    expect(c.read(onboardingCompleteProvider), isTrue);

    // A fresh container over the same (persisted) prefs still reads complete.
    final prefs = await SharedPreferences.getInstance();
    final relaunch = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(relaunch.dispose);
    expect(relaunch.read(onboardingCompleteProvider), isTrue);
  });

  test('reset() clears the flag so onboarding shows again', () async {
    final c = await boot(initial: {'onboarding_complete_v1': true});
    expect(c.read(onboardingCompleteProvider), isTrue);
    await c.read(onboardingCompleteProvider.notifier).reset();
    expect(c.read(onboardingCompleteProvider), isFalse);
  });
}
