import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';

/// Global background sync trigger, configured by the AUTO SYNC settings:
///   • Enabled            (App.AutoSync.Enabled)
///   • Mode               (App.AutoSync.Mode = 'After every save' | 'Every 1 hour')
///   • Show notification  (App.AutoSync.ShowNotification) — gated in SyncButton.
///
/// "After every save": a short debounce after any local write, then push+pull.
/// "Every 1 hour": a periodic timer; individual writes don't trigger a sync.
///
/// Loop safety (critical): a sync's own pull writes to many tables, and Drift
/// delivers those table-change notifications asynchronously — sometimes AFTER
/// `syncStateProvider` has already flipped out of loading. So an `isLoading`
/// check alone is NOT enough. We use an explicit [_suppress] flag that stays on
/// for the whole sync PLUS a short grace window afterwards, during which all
/// table changes are ignored. That absorbs the trailing pull notifications and
/// makes a self-retriggering loop impossible.
///
/// Settings are read at trigger time (not watched) so the watcher never rebuilds
/// — important, because a sync pulling app_properties would otherwise rebuild it
/// mid-sync and drop the suppression flag.
///
/// Kept alive by reading [autoSyncWatcherProvider] from MainLayout.
class AutoSyncWatcher extends Notifier<void> {
  StreamSubscription<void>? _sub;
  Timer? _debounce;
  Timer? _hourly;
  Timer? _suppressTimer;

  /// True while a sync is running and for [_grace] after it finishes — every
  /// table change seen in this window is ignored (it's the sync's own writes).
  bool _suppress = false;

  static const _debounceDelay = Duration(seconds: 3);
  static const _grace = Duration(seconds: 3);
  static const _interval = Duration(hours: 1);

  @override
  void build() {
    final db = ref.watch(appDatabaseProvider);
    // Always listen; whether a change actually triggers a sync is decided at
    // trigger time from the live settings.
    _sub = db.tableUpdates().listen((_) => _onTablesChanged());
    _hourly = Timer.periodic(_interval, (_) => _onHourly());
    ref.onDispose(() {
      _sub?.cancel();
      _debounce?.cancel();
      _hourly?.cancel();
      _suppressTimer?.cancel();
    });
  }

  bool get _enabled =>
      ref.read(appSettingsProvider)[SettingKeys.autoSyncEnabled]
          ?.toLowerCase() ==
      'true';

  bool get _hourlyMode =>
      (ref.read(appSettingsProvider)[SettingKeys.autoSyncMode] ?? '') ==
      'Every 1 hour';

  void _onTablesChanged() {
    if (_suppress || ref.read(syncStateProvider).isLoading) return;
    if (!_enabled || _hourlyMode) return; // only "after every save" reacts
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, _runSync);
  }

  void _onHourly() {
    if (_suppress || ref.read(syncStateProvider).isLoading) return;
    if (!_enabled || !_hourlyMode) return;
    _runSync();
  }

  Future<void> _runSync() async {
    if (ref.read(syncStateProvider).isLoading) return;
    if (ref.read(selectedCompanyProvider)?.id == null) return;

    // Only attempt when online — otherwise every offline write would queue a
    // failing sync. Offline data stays `pending` and ships when the
    // ConnectivityWatcher fires on reconnect.
    final conn = await Connectivity().checkConnectivity();
    final online = conn.any((r) => r != ConnectivityResult.none);
    if (!online) return;
    if (ref.read(syncStateProvider).isLoading) return; // re-check post-await

    // Suppress for the whole run + a grace window so the pull's trailing
    // table-change notifications can't re-arm us.
    _suppress = true;
    _suppressTimer?.cancel();
    try {
      await ref.read(syncStateProvider.notifier).sync();
    } finally {
      _suppressTimer = Timer(_grace, () => _suppress = false);
    }
  }
}

/// Read this from a long-lived widget (MainLayout) to keep the watcher alive
/// for the whole post-login session.
final autoSyncWatcherProvider =
    NotifierProvider<AutoSyncWatcher, void>(AutoSyncWatcher.new);
