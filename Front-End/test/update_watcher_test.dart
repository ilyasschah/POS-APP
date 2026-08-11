// The background poll's contract: it must respect the toggle, must not fire at
// boot, and must never install anything on its own.
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/app_version.dart';
import 'package:pos_app/update/app_release.dart';
import 'package:pos_app/update/update_providers.dart';
import 'package:pos_app/update/update_service.dart';
import 'package:pos_app/update/update_watcher.dart';

/// Counts checks instead of reaching the network.
class _CountingUpdateService extends UpdateService {
  int fetchCount = 0;

  @override
  Future<AppRelease?> fetchLatest() async {
    fetchCount++;
    return null;
  }
}

ProviderContainer _container(_CountingUpdateService service, {required bool autoCheck}) =>
    ProviderContainer(overrides: [
      updateServiceProvider.overrideWithValue(service),
      autoCheckUpdatesProvider.overrideWithValue(autoCheck),
      appVersionProvider.overrideWith(
        (ref) async => const AppVersion(version: '1.0.0', buildNumber: '1'),
      ),
    ]);

void main() {
  test('the toggle OFF means the terminal never phones home', () {
    fakeAsync((async) {
      final service = _CountingUpdateService();
      final container = _container(service, autoCheck: false);
      addTearDown(container.dispose);

      container.read(updateWatcherProvider);
      async.elapse(const Duration(days: 2));
      async.flushMicrotasks();

      // Not "checks less often" — zero. An operator who turned it off expects
      // no outbound requests at all.
      expect(service.fetchCount, 0);
    });
  });

  test('nothing is checked during the first minute of a session', () {
    fakeAsync((async) {
      final service = _CountingUpdateService();
      final container = _container(service, autoCheck: true);
      addTearDown(container.dispose);

      container.read(updateWatcherProvider);
      // Boot already competes with login, master-data pull and the first sync.
      async.elapse(const Duration(seconds: 45));
      async.flushMicrotasks();

      expect(service.fetchCount, 0);
    });
  }, skip: !Platform.isWindows);

  test('a long-running till keeps checking after the first time', () {
    fakeAsync((async) {
      final service = _CountingUpdateService();
      final container = _container(service, autoCheck: true);
      addTearDown(container.dispose);

      container.read(updateWatcherProvider);

      async.elapse(const Duration(minutes: 2));
      async.flushMicrotasks();
      final afterFirst = service.fetchCount;
      expect(afterFirst, greaterThan(0), reason: 'the initial check must fire');

      // Tills are switched on in the morning and left running for days, so a
      // once-per-launch check would miss every release in between.
      async.elapse(const Duration(hours: 13));
      async.flushMicrotasks();
      expect(service.fetchCount, greaterThan(afterFirst));
    });
  }, skip: !Platform.isWindows);
}
