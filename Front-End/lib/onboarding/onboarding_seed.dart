import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/settings/settings_provider.dart';

/// Company-level choices captured during PRE-LOGIN onboarding (virtual keyboard,
/// tables, booking). They can't be written to the per-company cloud settings
/// until a company exists, so they are parked device-locally here and applied to
/// [appSettingsProvider] once — on the first login, from `MainLayout` — then
/// cleared. Theme / accent / text size are separate: those are device-local and
/// apply live during onboarding.
class OnboardingFeatureSeed {
  const OnboardingFeatureSeed({
    this.virtualKeyboard,
    this.tables,
    this.booking,
    this.layoutIsGrid,
  });

  final bool? virtualKeyboard;
  final bool? tables;
  final bool? booking;

  /// Menu layout choice: null = not picked (falls back to the global 'List'
  /// default), true = paged Grid, false = scrolling List.
  final bool? layoutIsGrid;

  bool get isEmpty =>
      virtualKeyboard == null &&
      tables == null &&
      booking == null &&
      layoutIsGrid == null;
}

const _kVk = 'onboarding_seed_virtual_keyboard';
const _kTables = 'onboarding_seed_tables';
const _kBooking = 'onboarding_seed_booking';
const _kLayout = 'onboarding_seed_layout_is_grid';

final onboardingFeatureSeedProvider =
    NotifierProvider<OnboardingFeatureSeedNotifier, OnboardingFeatureSeed>(
        OnboardingFeatureSeedNotifier.new);

class OnboardingFeatureSeedNotifier extends Notifier<OnboardingFeatureSeed> {
  @override
  OnboardingFeatureSeed build() {
    final p = ref.watch(sharedPreferencesProvider);
    return OnboardingFeatureSeed(
      virtualKeyboard: p.getBool(_kVk),
      tables: p.getBool(_kTables),
      booking: p.getBool(_kBooking),
      layoutIsGrid: p.getBool(_kLayout),
    );
  }

  Future<void> setVirtualKeyboard(bool v) => _put(_kVk, v);
  Future<void> setTables(bool v) => _put(_kTables, v);
  Future<void> setBooking(bool v) => _put(_kBooking, v);
  Future<void> setLayoutIsGrid(bool v) => _put(_kLayout, v);

  Future<void> _put(String key, bool v) async {
    await ref.read(sharedPreferencesProvider).setBool(key, v);
    // Re-read all keys so state reflects the full parked seed.
    final p = ref.read(sharedPreferencesProvider);
    state = OnboardingFeatureSeed(
      virtualKeyboard: p.getBool(_kVk),
      tables: p.getBool(_kTables),
      booking: p.getBool(_kBooking),
      layoutIsGrid: p.getBool(_kLayout),
    );
  }

  /// Applies any parked choices to the (now-available) per-company settings and
  /// clears the seed. Best-effort + idempotent — safe to call on every login:
  /// when there is nothing parked it is a no-op, and a failure (company/settings
  /// not ready yet) leaves the seed for the next attempt.
  Future<void> applyToCompanySettings() async {
    final seed = state;
    if (seed.isEmpty) return;
    try {
      final settings = ref.read(appSettingsProvider.notifier);
      if (seed.virtualKeyboard != null) {
        await settings.setBool(
            SettingKeys.enableVirtualKeyboard, seed.virtualKeyboard!);
      }
      if (seed.tables != null) {
        await settings.setBool(
            SettingKeys.featureFloorPlanEnabled, seed.tables!);
      }
      if (seed.booking != null) {
        await settings.setBool(SettingKeys.featureBookingEnabled, seed.booking!);
      }
      if (seed.layoutIsGrid != null) {
        await settings.set(
            SettingKeys.menuLayoutMode, seed.layoutIsGrid! ? 'Grid' : 'List');
      }
      final p = ref.read(sharedPreferencesProvider);
      await p.remove(_kVk);
      await p.remove(_kTables);
      await p.remove(_kBooking);
      await p.remove(_kLayout);
      state = const OnboardingFeatureSeed();
    } catch (_) {
      // Settings not ready — keep the seed and retry on the next login.
    }
  }
}
