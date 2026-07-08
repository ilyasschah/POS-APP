import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
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

final licenseServiceProvider = Provider<LicenseService>(
  (ref) => LicenseService(ref.read(authStorageProvider)),
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
      if (lease != null && lease.isNotEmpty) {
        await _storage.saveLease(lease);
        final issuedAt = _decodeIssuedAt(lease);
        if (issuedAt != null) await _storage.recordServerTime(issuedAt);
      }
      return evaluate();
    } catch (e) {
      debugPrint('lease refresh skipped (offline?) — $e');
      return null;
    }
  }

  /// Reads the server-stamped `issuedAt` claim (the trusted clock pin).
  static DateTime? _decodeIssuedAt(String jwt) {
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
      final map =
          jsonDecode(utf8.decode(base64.decode(p))) as Map<String, dynamic>;
      final v = map['issuedAt'] as String?;
      return v == null ? null : DateTime.tryParse(v)?.toUtc();
    } catch (_) {
      return null;
    }
  }
}
