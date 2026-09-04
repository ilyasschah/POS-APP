// The background poll's contract: it must respect the toggle, must not fire at
// boot, and must never install anything on its own.
import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/app_version.dart';
import 'package:pos_app/update/app_release.dart';
import 'package:pos_app/update/update_providers.dart';
import 'package:pos_app/update/update_service.dart';
import 'package:pos_app/update/update_watcher.dart';

/// Counts checks instead of reaching the network. Returning null is what the
/// real service does on any failure, so this models a check that FAILS.
class _CountingUpdateService extends UpdateService {
  int fetchCount = 0;

  @override
  Future<AppRelease?> fetchLatest() async {
    fetchCount++;
    return null;
  }
}

/// A check that reaches the server and finds nothing newer — a SUCCESS.
class _SucceedingUpdateService extends UpdateService {
  int fetchCount = 0;

  @override
  Future<AppRelease?> fetchLatest() async {
    fetchCount++;
    return const AppRelease(
      version: SemVer(1, 0, 0), // same as the running version below
      installerUrl: 'https://example.invalid/x.exe',
      installerName: 'x.exe',
      sizeBytes: 1,
      checksumUrl: 'https://example.invalid/x.exe.sha256',
    );
  }
}

/// Models the connection that never completes: the future stays pending until
/// the test releases it, exactly as a missing connect timeout behaved.
class _HangingUpdateService extends UpdateService {
  int fetchCount = 0;
  Completer<AppRelease?>? _pending;

  @override
  Future<AppRelease?> fetchLatest() {
    fetchCount++;
    // Only the FIRST call hangs; later ones behave normally, so the test can
    // prove the guard was released rather than merely re-entered.
    if (fetchCount == 1) {
      return (_pending = Completer<AppRelease?>()).future;
    }
    return Future.value(null);
  }

  /// Ends the hang the way a connect timeout does — a failure, not a result.
  void completeWithFailure() => _pending?.complete(null);
}

ProviderContainer _container(UpdateService service, {required bool autoCheck}) =>
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

  // ── Regression: the updater used to stop working until the app restarted ──

  test('a check that never returns does not wedge every later check', () {
    fakeAsync((async) {
      final service = _HangingUpdateService();
      final container = _container(service, autoCheck: true);
      addTearDown(container.dispose);

      container.read(updateWatcherProvider);
      async.elapse(const Duration(minutes: 2));
      async.flushMicrotasks();
      expect(service.fetchCount, 1, reason: 'the initial check fired');

      // While the fetch is pending the guard is held — that part is correct and
      // intended. What was NOT survivable is the fetch never ending at all,
      // because Dio had no connect timeout: the guard was then held for the life
      // of the process and every later check bounced off it. That root cause is
      // pinned in update_test.dart ("the client has a connect timeout"); this
      // test covers the other half — that once the transport does give up, the
      // controller settles and checking resumes.
      service.completeWithFailure();
      async.elapse(const Duration(seconds: 20));
      async.flushMicrotasks();

      expect(container.read(updateControllerProvider), isNot(isA<UpdateChecking>()),
          reason: 'the controller must not still be holding the guard');

      // And a later check actually runs rather than bouncing off the guard.
      async.elapse(const Duration(hours: 7));
      async.flushMicrotasks();
      expect(service.fetchCount, greaterThan(1));
    });
  }, skip: !Platform.isWindows);

  test('an exception mid-check does not leave the controller wedged', () {
    fakeAsync((async) {
      final service = _CountingUpdateService();
      // PackageInfo is a plugin channel call; on a broken install it throws.
      // fetchLatest swallows its own failures, but this one is outside it.
      final container = ProviderContainer(overrides: [
        updateServiceProvider.overrideWithValue(service),
        autoCheckUpdatesProvider.overrideWithValue(true),
        appVersionProvider.overrideWith(
          (ref) async => throw StateError('PackageInfo unavailable'),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(updateWatcherProvider);
      async.elapse(const Duration(minutes: 2));
      async.flushMicrotasks();

      // Before the try/catch this exception escaped check() with state still on
      // UpdateChecking, and the re-entry guard then refused every later check —
      // the same permanent wedge, reached a different way.
      expect(container.read(updateControllerProvider), isA<UpdateFailed>());

      // And checking genuinely resumes rather than bouncing off a held guard.
      async.elapse(const Duration(hours: 7));
      async.flushMicrotasks();
      expect(container.read(updateControllerProvider), isNot(isA<UpdateChecking>()));
    });
  }, skip: !Platform.isWindows);

  test('a failed check is retried once, without waiting six hours', () {
    fakeAsync((async) {
      final service = _CountingUpdateService(); // always returns null => failure
      final container = _container(service, autoCheck: true);
      addTearDown(container.dispose);

      container.read(updateWatcherProvider);
      async.elapse(const Duration(minutes: 2));
      async.flushMicrotasks();
      expect(service.fetchCount, 1);

      // The first check lands a minute after login, often before a just-booted
      // till has usable network. Without a retry that miss cost six hours, and a
      // 9-to-5 shop never reached the second tick at all.
      async.elapse(const Duration(minutes: 6));
      async.flushMicrotasks();
      expect(service.fetchCount, 2, reason: 'exactly one retry, ~5 minutes later');

      // One retry, not a backoff loop hammering the venue's connection.
      async.elapse(const Duration(minutes: 30));
      async.flushMicrotasks();
      expect(service.fetchCount, 2);
    });
  }, skip: !Platform.isWindows);

  test('a successful check is not retried', () {
    fakeAsync((async) {
      final service = _SucceedingUpdateService();
      final container = _container(service, autoCheck: true);
      addTearDown(container.dispose);

      container.read(updateWatcherProvider);
      async.elapse(const Duration(minutes: 2));
      async.flushMicrotasks();
      expect(service.fetchCount, 1);

      // "Up to date" is a success. Re-asking would burn the venue's GitHub
      // budget — 60 requests an hour shared by every till on that public IP,
      // because the API is called unauthenticated.
      async.elapse(const Duration(minutes: 30));
      async.flushMicrotasks();
      expect(service.fetchCount, 1);
    });
  }, skip: !Platform.isWindows);
}
