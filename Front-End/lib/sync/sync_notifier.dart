import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/license/license_service.dart';
import 'package:pos_app/sync/account_status_provider.dart';
import 'package:pos_app/sync/sync_manager.dart' show DeviceRevokedException;
import 'package:pos_app/sync/sync_provider.dart';

/// Tracks the in-flight state of a manual sync. `isLoading` is true while a sync
/// runs; `hasError` flips true only on a hard failure (the whole run threw). On
/// a normal finish the value is the list of step labels that failed individually
/// (empty = clean) — the SyncButton surfaces these so partial failures are
/// visible instead of silently swallowed.
class SyncNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    // Idle state — no work in flight at startup, nothing failed yet.
    return const [];
  }

  /// The run currently in flight, and whether the operator asked for it.
  ///
  /// Safe as instance state: [syncStateProvider] is not autoDispose and nothing
  /// invalidates it, so this notifier lives as long as the app does.
  Future<void>? _inFlight;
  bool _inFlightIsManual = false;

  /// Kicks off a full bidirectional sync. UI bindings should call this and
  /// observe `state.isLoading` / `state.hasError` rather than awaiting the
  /// future, so multiple consumers can react without races.
  ///
  /// Pass [manual] `true` when the operator explicitly asked for it (the Sync
  /// button, the sync panel, a pull-to-refresh). That forces the document pull
  /// to reconcile deletions immediately instead of on its 6-hour cadence — so
  /// "delete the sale on till 1, press Sync on till 2" removes it there and
  /// then. Background callers (connectivity restored, the hourly timer, the
  /// fire-and-forget push after a save) leave it false and stay cheap.
  ///
  /// ── Single-flight ─────────────────────────────────────────────────────────
  ///
  /// 🚨 Two syncs must never run at once, and this guard is a CORRECTNESS fix
  /// rather than an optimisation. Nearly forty call sites fire this
  /// `.catchError((_) {})`-style after a save — checkout, the modifier editor,
  /// bookings, product edits — so the overlap is not exotic: completing a sale
  /// starts a background sync, and a cashier who then taps Sync starts a second
  /// one on top of it. Two things break when they collide:
  ///
  ///   * **SQLite.** Both runs drive the same Drift database and the loser gets
  ///     `SqliteException(5): database is locked`. Steps are individually
  ///     caught, so the failure is SWALLOWED as "local cache preserved" — the
  ///     data simply does not sync and nobody is told. Once a transaction dies
  ///     that way its remaining statements report `Invalid argument
  ///     (transactionId): Does not reference a transaction`, which reads like a
  ///     Drift bug and is really just the collision.
  ///   * **The failure report.** `SyncManager` keeps `_failedSteps` as instance
  ///     state and CLEARS it at the top of every run, so the second sync wipes
  ///     the first one's failures — and the Sync panel proudly reports a clean
  ///     run for a sync whose steps failed.
  ///
  /// Joining rather than refusing is what keeps the semantics honest. A
  /// background request means "sync soon", which a run already in progress
  /// satisfies, so it simply awaits that one. A MANUAL request is not the same
  /// request — only a manual run reconciles deletions immediately — so when the
  /// operator presses Sync during a background push, this waits for that push to
  /// land and then does the manual pass they actually asked for.
  Future<void> sync({bool manual = false}) async {
    // Looped, not a single check: several callers can be waiting on the same
    // in-flight run, and one of them may start the manual pass while the others
    // are still suspended. Re-reading after each wait lets the rest join that
    // pass instead of racing to start their own.
    while (true) {
      final running = _inFlight;
      if (running == null) break;
      if (!manual || _inFlightIsManual) return running;
      // Never rethrow another caller's failure into this one — `_run` reports
      // through `state`, and this await is only about ordering.
      await running.catchError((_) {});
    }

    // Assigned with no await in between, so a caller resuming from the wait
    // above always sees this run rather than starting a second one.
    final run = _run(manual: manual);
    _inFlight = run;
    _inFlightIsManual = manual;
    try {
      await run;
    } finally {
      if (identical(_inFlight, run)) {
        _inFlight = null;
        _inFlightIsManual = false;
      }
    }
  }

  Future<void> _run({required bool manual}) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) {
      // No company selected — surface as an error so the snackbar fires.
      state = AsyncError(
        StateError('No company selected.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async {
        // Deleted-account check: if the server definitively reports our company is
        // gone (deleted in the admin portal), flag it so the shell routes back to
        // master login. Only a real "gone" response trips this — offline/errors do
        // not, so a legitimate offline terminal is never kicked out.
        if (await checkCompanyExists(companyId) == CompanyExistence.deleted) {
          ref.read(accountRevokedProvider.notifier).markRevoked();
          return const <String>[];
        }
        // (Offline refunds are now drained inside SyncManager.sync()'s push phase
        // via pushPendingRefundOps — straight from Drift, before pullDocuments —
        // so there's no separate refund queue to flush here anymore.)
        // Pillar 2: slide the offline subscription lease forward (and pin the
        // server clock for anti-rollback) while we're online. Non-fatal — a
        // failed refresh just leaves the existing cached lease in force.
        try {
          await ref.read(licenseServiceProvider).refreshFromServer(companyId);
        } catch (_) {/* offline / server down — cached lease stays valid */}
        try {
          return await ref
              .read(syncManagerProvider)
              .sync(companyId, manual: manual);
        } on DeviceRevokedException catch (e) {
          // The admin removed this terminal. Flag it for the shell to sign out
          // and route to master login; surfacing it as a plain sync error would
          // leave the operator on a till that can never sync again with no idea
          // why. Not rethrown — the terminal is being signed out, not failing.
          ref.read(deviceRevokedProvider.notifier).markRevoked(e.message);
          return const <String>[];
        }
      },
    );
  }
}

final syncStateProvider = AsyncNotifierProvider<SyncNotifier, List<String>>(
  SyncNotifier.new,
);
