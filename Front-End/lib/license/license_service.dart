import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dio/dio.dart' show DioException;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/auth/auth_storage.dart';

/// Outcome of evaluating the stored offline subscription lease (Pillar 2).
enum LicenseState {
  /// Verified lease, still within its (grace-extended) validity window.
  active,

  /// Verified lease, but its validity window has passed — the terminal is
  /// blocked until it can refresh online.
  expired,

  /// The lease signature did not match the server public key — it was edited
  /// or forged. Treated as a hard block.
  tampered,

  /// No lease, or not yet verifiable offline (no cached key) — fail-open so a
  /// legacy / freshly-installed terminal is never bricked. Enforcement starts
  /// once a real lease + key are present.
  unknown,
}

class LicenseEvaluation {
  final LicenseState state;
  final DateTime? validUntil;

  /// Whole days until expiry (negative once expired). Display only.
  final int daysLeft;

  const LicenseEvaluation(this.state, {this.validUntil, this.daysLeft = 0});

  /// The app should drop into the read-only block screen for these states.
  bool get blocked =>
      state == LicenseState.expired || state == LicenseState.tampered;
}

/// Everything the Settings → Subscription tab shows. Read straight out of the
/// signed lease, so it stays truthful offline (the lease is the same artefact
/// the boot guard enforces — there is no second source to drift from).
class SubscriptionInfo {
  /// When the tenant was provisioned. Null on a lease issued before the server
  /// carried the claim, or for a company with no tenant record yet.
  final DateTime? startedAt;

  /// The subscription's own period end — what the customer is billed to.
  final DateTime? periodEnd;

  /// Period end + grace: the moment the terminal actually stops working.
  final DateTime? validUntil;

  /// Paid terminal cap. 0 when no subscription is provisioned (trial).
  final int seatAllowance;

  final String billingStatus;
  final LicenseState state;

  /// Whole days until [periodEnd] — the date the Subscription tab shows — so
  /// the status pill can never contradict the row beneath it. Goes 0/negative
  /// while the terminal is still running inside the grace window, which is the
  /// state [validUntil] covers. Display only; enforcement uses [validUntil].
  final int daysLeft;

  const SubscriptionInfo({
    required this.state,
    required this.seatAllowance,
    required this.billingStatus,
    required this.daysLeft,
    this.startedAt,
    this.periodEnd,
    this.validUntil,
  });
}

final licenseServiceProvider = Provider<LicenseService>(
  (ref) => LicenseService(ref.read(authStorageProvider)),
);

/// Subscription details for the Settings tab.
///
/// Pulls a fresh lease FIRST (best-effort), then decodes it. Without that pull
/// the tab only ever showed the lease cached at app launch, so changing the
/// expiry in the admin portal left the badge stale until the operator restarted
/// the POS — which reads as "the app didn't sync".
///
/// Still offline-safe: the refresh is wrapped, and any failure (no network, API
/// down) simply falls through to the cached lease, which is what [describe]
/// reads anyway. Nothing here can block or fail the tab.
final subscriptionInfoProvider = FutureProvider.autoDispose<SubscriptionInfo>(
  (ref) async {
    final service = ref.read(licenseServiceProvider);
    final companyId = await ref.read(authStorageProvider).getCompanyId();
    if (companyId != null) {
      try {
        await service.refreshFromServer(companyId);
      } catch (_) {
        // Offline / server unreachable — keep the cached lease.
      }
    }
    return service.describe();
  },
);

/// Verifies and enforces the signed offline subscription lease entirely on the
/// device, so the terminal keeps honouring (or refusing) the subscription with
/// no connectivity. Online, [refreshFromServer] slides the window forward.
class LicenseService {
  LicenseService(this._storage);
  final AuthStorage _storage;

  /// Evaluates the locally-stored lease for the boot guard. Pure/offline.
  Future<LicenseEvaluation> evaluate() async {
    final lease = await _storage.getLease();
    // No lease (legacy install / never master-logged-in): fail-open.
    if (lease == null || lease.isEmpty) {
      return const LicenseEvaluation(LicenseState.unknown);
    }

    // Verify the signature when we have the cached public key. Without it we
    // can't prove authenticity offline yet, so soft-trust until a sync caches
    // the key (a brand-new install that never reached the server).
    final pem = await _storage.getLeasePublicKey();
    if (pem != null && pem.isNotEmpty) {
      if (!_signatureValid(lease, pem)) {
        return const LicenseEvaluation(LicenseState.tampered);
      }
    }

    final validUntil = AuthStorage.decodeLeaseValidUntil(lease)?.toUtc();
    if (validUntil == null) {
      return const LicenseEvaluation(LicenseState.unknown);
    }

    // Anti-rollback: compare against the later of the device clock and the
    // highest server time we've ever seen.
    final now = await _storage.trustedNow();
    final daysLeft = validUntil.difference(now).inHours ~/ 24;
    final state =
        now.isBefore(validUntil) ? LicenseState.active : LicenseState.expired;
    return LicenseEvaluation(state, validUntil: validUntil, daysLeft: daysLeft);
  }

  /// Describes the stored lease for display. Reuses [evaluate] for the verdict
  /// (so the tab can never disagree with the boot guard) and reads the rest of
  /// the claims off the same lease.
  Future<SubscriptionInfo> describe() async {
    final evaluation = await evaluate();
    final lease = await _storage.getLease();
    // A tampered lease's claims are attacker-controlled — show the verdict only,
    // never its forged dates/seat count dressed up as fact.
    final claims = (lease == null || evaluation.state == LicenseState.tampered)
        ? null
        : _decodePayload(lease);

    final periodEnd = _claimDate(claims, 'periodEnd');

    // Count down to the date the tab actually DISPLAYS (periodEnd), not to
    // validUntil. They differ by Lease:GraceDays, so counting to validUntil put
    // "expires in 3 days" directly above a "Renews / Ends" date that had already
    // passed — and since the gap is the grace constant, the pill read exactly
    // "3 days" for every lapsed subscription regardless of the real date.
    // evaluation.daysLeft (→ validUntil) stays the enforcement number.
    final displayEnd = periodEnd ?? evaluation.validUntil;
    final daysLeft = displayEnd == null
        ? evaluation.daysLeft
        : displayEnd.difference(await _storage.trustedNow()).inHours ~/ 24;

    return SubscriptionInfo(
      state: evaluation.state,
      daysLeft: daysLeft,
      validUntil: evaluation.validUntil,
      startedAt: _claimDate(claims, 'startedAt'),
      periodEnd: periodEnd,
      seatAllowance:
          int.tryParse(claims?['seatAllowance']?.toString() ?? '') ?? 0,
      billingStatus: claims?['billingStatus']?.toString() ?? 'unknown',
    );
  }

  static DateTime? _claimDate(Map<String, dynamic>? claims, String key) {
    final v = claims?[key] as String?;
    return v == null ? null : DateTime.tryParse(v)?.toUtc();
  }

  /// True when [lease]'s RS256 signature matches [pem]. A valid signature that
  /// merely expired / isn't-yet-active still counts as authentic — the time
  /// window is enforced separately (with anti-rollback) in [evaluate].
  bool _signatureValid(String lease, String pem) {
    try {
      JWT.verify(lease, RSAPublicKey(pem));
      return true;
    } on JWTExpiredException {
      return true; // signature verified before the exp check
    } on JWTNotActiveException {
      return true; // signature verified before the nbf check
    } catch (e) {
      debugPrint('lease signature rejected — $e');
      return false;
    }
  }

  /// Online refresh: re-fetch + cache the public key and a fresh lease, and pin
  /// the server clock (anti-rollback). Returns the new evaluation, or null when
  /// the server is unreachable (the cached lease stays in force).
  Future<LicenseEvaluation?> refreshFromServer(int companyId) async {
    final dio = createDio();
    try {
      final keyResp = await dio.get('/Master/LeasePublicKey');
      final pem = (keyResp.data as Map?)?['publicKeyPem'] as String?;
      if (pem != null && pem.isNotEmpty) {
        await _storage.saveLeasePublicKey(pem);
      }

      final leaseResp = await dio
          .get('/Master/Lease', queryParameters: {'companyId': companyId});
      final lease = (leaseResp.data as Map?)?['lease'] as String?;
      if (lease == null || lease.isEmpty) {
        // 🚨 The request SUCCEEDED but carried no lease (e.g. the company has no
        // tenant on this server). Returning `evaluate()` here re-judged the OLD
        // cached lease and reported it as *expired* — telling the operator their
        // subscription had lapsed when the truth is "this server has nothing to
        // say about this company". Null means "no answer", which the retry
        // surfaces as a connection problem instead.
        debugPrint('lease refresh: server returned no lease for company '
            '$companyId at $apiBaseUrl');
        return null;
      }
      await _storage.saveLease(lease);
      final issuedAt = _decodeIssuedAt(lease);
      if (issuedAt != null) await _storage.recordServerTime(issuedAt);
      // await, not a bare return: without it a throw from evaluate()
      // escapes past the catch below instead of degrading to null,
      // which is the whole contract of this offline-tolerant refresh.
      return await evaluate();
    } catch (e) {
      // "(offline?)" only when it plausibly IS the network. This catch also
      // sees storage and decode failures, and labelling those as offline sent
      // the last one on a hunt for a network fault that did not exist.
      final offline = e is DioException;
      debugPrint(
        'lease refresh skipped${offline ? ' (offline?)' : ''} — $e',
      );
      return null;
    }
  }

  /// Reads the server-stamped `issuedAt` claim (the trusted clock pin).
  static DateTime? _decodeIssuedAt(String jwt) =>
      _claimDate(_decodePayload(jwt), 'issuedAt');

  /// Decodes a lease's claim payload WITHOUT verifying its signature — callers
  /// must only use this for display, or after [_signatureValid] has passed.
  static Map<String, dynamic>? _decodePayload(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      var p = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (p.length % 4) {
        case 2:
          p += '==';
          break;
        case 3:
          p += '=';
          break;
      }
      return jsonDecode(utf8.decode(base64.decode(p))) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
