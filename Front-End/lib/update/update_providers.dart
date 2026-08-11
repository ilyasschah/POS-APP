import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/core/app_version.dart';
import 'package:pos_app/sync/pending_count_provider.dart';
import 'package:pos_app/update/app_release.dart';
import 'package:pos_app/update/update_guard.dart';
import 'package:pos_app/update/update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

/// Whether this terminal polls for new versions. Device-scoped — see
/// `settings/device_scoped_settings.dart` for why it must not cloud-sync.
final autoCheckUpdatesProvider = Provider<bool>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings[SettingKeys.autoCheckUpdates] == 'true';
});

/// What stands between the operator and installing an update, right now.
///
/// Watches the LIVE cart as well as the database: an in-progress sale exists
/// only in memory until checkout, so it is invisible to any row count.
final updateBlockersProvider = Provider<List<UpdateBlocker>>((ref) {
  final cartItems = ref.watch(cartProvider).items.length;
  final pending = ref.watch(pendingOrdersCountProvider).value ?? 0;
  return evaluateUpdateBlockers(
    cartItemCount: cartItems,
    pendingPushCount: pending,
  );
});

/// Drives the update UI. One state machine, so the button can never offer
/// "Install" while a download is still running.
class UpdateController extends Notifier<UpdateStatus> {
  CancelToken? _cancelToken;

  @override
  UpdateStatus build() {
    ref.onDispose(() => _cancelToken?.cancel());
    return const UpdateIdle();
  }

  /// Looks for a newer release. Never throws — a till offline mid-service must
  /// see "couldn't check", not an exception.
  Future<void> check() async {
    if (!UpdateService.isSupported) return;
    if (state is UpdateChecking || state is UpdateDownloading) return;

    state = const UpdateChecking();

    final running = SemVer.tryParse(
      (await ref.read(appVersionProvider.future)).version,
    );
    if (running == null) {
      state = const UpdateFailed('Could not read the running version.');
      return;
    }

    final release = await ref.read(updateServiceProvider).fetchLatest();
    if (release == null) {
      state = const UpdateFailed('Could not reach the update server.');
      return;
    }

    state = release.isNewerThan(running)
        ? UpdateAvailable(release)
        : UpdateUpToDate(running);
  }

  /// Downloads and verifies the installer. Does NOT install — the operator
  /// confirms that separately, because installing closes the app.
  Future<void> download(AppRelease release) async {
    if (state is UpdateDownloading) return;

    _cancelToken = CancelToken();
    state = UpdateDownloading(release, 0, release.sizeBytes);

    final path = await ref.read(updateServiceProvider).downloadInstaller(
          release,
          cancelToken: _cancelToken,
          onProgress: (received, total) {
            // total is -1 until the server declares a length; fall back to the
            // size the release metadata already told us.
            state = UpdateDownloading(
              release,
              received,
              total > 0 ? total : release.sizeBytes,
            );
          },
        );

    state = path == null
        ? const UpdateFailed(
            'The download failed or could not be verified. Nothing was installed.')
        : UpdateReadyToInstall(release, path);
  }

  void cancelDownload() {
    _cancelToken?.cancel();
    _cancelToken = null;
    state = const UpdateIdle();
  }

  /// Launches the installer. The caller must close the app straight after —
  /// Windows cannot replace a running executable.
  ///
  /// Refuses while a fatal blocker stands (an active cart), so the state machine
  /// cannot be driven past the guard by a stray tap.
  Future<bool> install() async {
    final current = state;
    if (current is! UpdateReadyToInstall) return false;
    if (!canInstallUpdate(ref.read(updateBlockersProvider))) return false;

    return ref.read(updateServiceProvider).launchInstaller(current.installerPath);
  }
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateStatus>(UpdateController.new);
