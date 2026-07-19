import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/settings/settings_provider.dart';

/// Versioned so a future onboarding revamp can re-show the flow to returning
/// users by bumping the suffix — without colliding with the old install's flag.
const _kOnboardingDoneKey = 'onboarding_complete_v1';

/// Whether THIS DEVICE has finished the first-run onboarding.
///
/// Deliberately device-local (SharedPreferences), never the cloud-synced
/// [appSettingsProvider]: a freshly-installed terminal must see onboarding even
/// when the company already ran the app on another device. Read synchronously —
/// `main()` awaits SharedPreferences before `runApp`, so the gate decides on the
/// first frame with no async flash.
final onboardingCompleteProvider =
    NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_kOnboardingDoneKey) ?? false;

  /// Flags onboarding done. `MyApp` watches this provider, so flipping the state
  /// rebuilds it straight into the normal boot flow — no manual navigation.
  Future<void> complete() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kOnboardingDoneKey, true);
    state = true;
  }

  /// Clears the flag so onboarding shows again — powers a "Replay onboarding"
  /// action in Settings and the unit tests.
  Future<void> reset() async {
    await ref.read(sharedPreferencesProvider).remove(_kOnboardingDoneKey);
    state = false;
  }
}
