import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/sync/sync_notifier.dart';

/// Watches the device's connectivity stream and auto-triggers a sync whenever
/// the network transitions from offline to online.
///
/// Guards against three failure modes that real-world WiFi exhibits:
///   1. **Flapping**: rapid online/offline/online toggles — debounced to one
///      sync per 10s window.
///   2. **Concurrent runs**: the previous sync may still be in flight when a
///      new transition fires — we skip if `syncStateProvider.isLoading`.
///   3. **Cold start "first event"**: connectivity_plus emits the *current*
///      state as the first event after listen(). That isn't a transition;
///      we suppress the auto-trigger on the very first emission.
///
/// The watcher is created by reading [connectivityWatcherProvider] from
/// anywhere that should keep it alive (typically MainLayout). It cleans up
/// its stream subscription via `ref.onDispose`.
class ConnectivityWatcher extends Notifier<void> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _wasOnline = false;
  bool _seenFirstEvent = false;
  DateTime? _lastTrigger;

  static const _debounce = Duration(seconds: 10);

  @override
  void build() {
    _sub = Connectivity().onConnectivityChanged.listen(_onConnectivityChange);
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
  }

  void _onConnectivityChange(List<ConnectivityResult> results) {
    // connectivity_plus 6.x reports a list — multiple interfaces can be active
    // simultaneously (e.g. wifi + ethernet on a dock). Anything other than
    // `none` counts as online.
    final isOnline = results.any((r) => r != ConnectivityResult.none);

    // Capture initial state without triggering — the first emission is just
    // a snapshot, not a transition.
    if (!_seenFirstEvent) {
      _seenFirstEvent = true;
      _wasOnline = isOnline;
      return;
    }

    final wasOnline = _wasOnline;
    _wasOnline = isOnline;

    if (!(isOnline && !wasOnline)) return; // not an offline→online edge

    // Debounce: ignore if we synced recently. Flaky WiFi reconnecting twice
    // in 10s shouldn't fire two BatchSync POSTs back-to-back.
    final now = DateTime.now();
    if (_lastTrigger != null && now.difference(_lastTrigger!) < _debounce) {
      return;
    }

    // Skip if a sync is already in flight (manual button press, login seed,
    // a previous reconnection still completing). SyncNotifier.sync() is
    // idempotent but reentering would replace AsyncLoading with AsyncLoading
    // and confuse the badge/spinner state.
    final syncState = ref.read(syncStateProvider);
    if (syncState.isLoading) return;

    _lastTrigger = now;
    // Fire-and-forget — the notifier owns state transitions. Errors surface
    // through syncStateProvider's AsyncError and the SyncButton snackbar.
    unawaited(ref.read(syncStateProvider.notifier).sync());
  }
}

/// Read this from any widget that should keep the watcher alive (typically
/// inside `MainLayout.build` once the user is post-login).
final connectivityWatcherProvider =
    NotifierProvider<ConnectivityWatcher, void>(ConnectivityWatcher.new);
