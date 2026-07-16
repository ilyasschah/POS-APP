import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/license/license_service.dart';
import 'package:pos_app/sync/account_status_provider.dart';
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

  /// Kicks off a full bidirectional sync. UI bindings should call this and
  /// observe `state.isLoading` / `state.hasError` rather than awaiting the
  /// future, so multiple consumers can react without races.
  Future<void> sync() async {
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
        return ref.read(syncManagerProvider).sync(companyId);
      },
    );
  }
}

final syncStateProvider = AsyncNotifierProvider<SyncNotifier, List<String>>(
  SyncNotifier.new,
);
