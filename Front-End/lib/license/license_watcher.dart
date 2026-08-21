import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/license/license_service.dart';

/// Runtime subscription guard (Pillar 2).
///
/// Enforcement used to run ONLY at boot (`main.dart._decideBoot`), so a terminal
/// left running past its lease `validUntil` — or one the provider paused
/// server-side — kept trading until it was restarted. This re-evaluates the
/// offline lease on a timer while the POS is open:
///
///   • OFFLINE it re-checks the CACHED lease, which still expires against the
///     anti-rollback clock (`AuthStorage.trustedNow` = max(device clock, highest
///     server time ever seen)) — so winding the device clock back cannot keep an
///     expired terminal alive.
///   • ONLINE it pulls a fresh lease first, so a provider-side Stop / Resume /
///     days change lands within one interval even on an idle till.
///
/// [MainLayout] listens to this and routes to `SubscriptionBlockedScreen` the
/// moment the evaluation turns `blocked`, without waiting for a restart. Kept
/// alive for the post-login session like the connectivity / auto-sync watchers.
class LicenseWatcher extends Notifier<LicenseEvaluation?> {
  Timer? _timer;

  /// How often the license is re-checked. A couple of minutes lands a paused
  /// subscription quickly without hammering the control plane; a natural offline
  /// expiry blocks within the same window.
  static const _interval = Duration(minutes: 2);

  @override
  LicenseEvaluation? build() {
    _timer = Timer.periodic(_interval, (_) => _heartbeat());
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  Future<void> _heartbeat() async {
    final companyId = await ref.read(authStorageProvider).getCompanyId();
    if (companyId == null) return; // not linked — nothing to enforce
    // Pull a fresh lease when reachable so a provider pause/resume lands even on
    // an idle terminal; offline this is a no-op and the cached lease is judged.
    try {
      await ref.read(licenseServiceProvider).refreshFromServer(companyId);
    } catch (_) {}
    state = await ref.read(licenseServiceProvider).evaluate();
  }
}

/// Read this from a long-lived widget (MainLayout) to keep the watcher alive for
/// the whole post-login session.
final licenseWatcherProvider =
    NotifierProvider<LicenseWatcher, LicenseEvaluation?>(LicenseWatcher.new);
