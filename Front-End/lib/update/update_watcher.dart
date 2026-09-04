import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/update/app_release.dart';
import 'package:pos_app/update/update_providers.dart';
import 'package:pos_app/update/update_service.dart';

/// Background "is there a newer version?" poll, gated by the
/// `App.Update.AutoCheck` toggle in Settings → About.
///
/// It only ever CHECKS. It never downloads and never installs: replacing the
/// software is an explicit decision by whoever is standing at the till, because
/// installing closes the app — mid-service that is a lost sale, and the pre-install
/// guard (an open cart) can only be judged by a human.
///
/// Design constraints, all learned from this codebase:
/// * **Never at boot.** Startup already logs in, pulls master data and syncs; one
///   more network call competing with that delays the first sale for no reason.
///   The first check waits [_initialDelay].
/// * **Repeats.** A till is switched on in the morning and left running for days,
///   so a once-per-launch check would miss every release in between.
/// * **Silent.** A failed check is not an error the cashier can act on. The
///   result lands in `updateControllerProvider`, which Settings → About renders.
/// * **Windows only** — Android cannot self-install.
///
/// Kept alive by `ref.watch(updateWatcherProvider)` in MainLayout, exactly like
/// [autoSyncWatcherProvider].
class UpdateWatcher extends Notifier<void> {
  Timer? _initial;
  Timer? _periodic;
  Timer? _retry;

  /// Long enough for login, the master-data pull and the first sync to finish.
  static const _initialDelay = Duration(minutes: 1);

  /// A release lands a few times a week at most; polling harder buys nothing and
  /// spends a shop's bandwidth.
  static const _interval = Duration(hours: 6);

  /// One retry after a failed check.
  ///
  /// The first check fires a minute after login, which on a till that was just
  /// switched on is easily before the network is actually usable. Without this
  /// that miss cost SIX HOURS — and a shop that opens at 9 and closes at 17
  /// never reaches the second tick, so the terminal would go a whole day
  /// without ever looking. Deliberately one retry, not a backoff loop: the
  /// point is to survive a cold start, not to hammer a venue's connection.
  static const _retryDelay = Duration(minutes: 5);

  @override
  void build() {
    _cancel();
    ref.onDispose(_cancel);

    // Watched, not read: flipping the toggle off must stop the timers, and
    // flipping it on must start them without restarting the app.
    final enabled = ref.watch(autoCheckUpdatesProvider);
    if (!enabled || !UpdateService.isSupported) return;

    _initial = Timer(_initialDelay, _check);
    _periodic = Timer.periodic(_interval, (_) => _check());
  }

  void _check({bool allowRetry = true}) {
    // check() is already a no-op while a check or download is in flight, and it
    // swallows its own failures — an offline venue must not produce noise.
    final future = ref.read(updateControllerProvider.notifier).check();

    if (!allowRetry) return;
    future.whenComplete(() {
      // Only a failed check earns a retry. Reaching the server and being told
      // "up to date" is a success, and re-asking would waste the venue's
      // GitHub rate limit — it is 60 requests an hour for ALL tills sharing the
      // venue's public IP, because the API is called unauthenticated.
      if (ref.read(updateControllerProvider) is! UpdateFailed) return;
      _retry?.cancel();
      _retry = Timer(_retryDelay, () => _check(allowRetry: false));
    });
  }

  void _cancel() {
    _initial?.cancel();
    _periodic?.cancel();
    _retry?.cancel();
    _initial = null;
    _periodic = null;
    _retry = null;
  }
}

final updateWatcherProvider =
    NotifierProvider<UpdateWatcher, void>(UpdateWatcher.new);
