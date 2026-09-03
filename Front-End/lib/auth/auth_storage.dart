import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/core/secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_app/auth/auth_token_cache.dart';

final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

class AuthStorage {
  static const _keyJwt = 'jwt_token';
  // The device's own token from master-login. Kept alongside the active token so
  // that when a cashier logs in via PIN we can exchange it for a per-user token
  // (POST /Auth/UserToken) — and revert to it on logout / offline.
  static const _keyDeviceJwt = 'device_jwt';
  static const _keyDeviceId = 'device_id';
  static const _keyCompanyId = 'company_id';
  static const _keyCachedUsers = 'cached_users';
  static const _keyRegisteredEmail = 'registered_email';
  // Pillar 2 — offline subscription lease (signed token + its decoded expiry).
  static const _keyLease = 'license_lease';
  static const _keyLeaseValidUntil = 'license_valid_until';
  // RSA public key used to verify the lease signature offline (cached from the
  // server). Not secret, but kept beside the lease.
  static const _keyLeasePubKey = 'license_public_key';
  // Highest server clock value ever observed (from a verified lease's issuedAt).
  // The offline guard never trusts a device clock earlier than this, so winding
  // the system clock back can't resurrect an expired subscription.
  static const _keyMaxServerTime = 'max_seen_server_time';

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_keyDeviceId);

    if (deviceId == null || deviceId.isEmpty) {
      deviceId = "POS-${const Uuid().v4()}";
      await prefs.setString(_keyDeviceId, deviceId);
    }

    return deviceId;
  }

  Future<void> saveMasterSession(String jwt, int companyId) async {
    // The master-login token is both the initial active token and the durable
    // device token used to mint per-user tokens later.
    await SecureStore.write(_keyJwt, jwt);
    await SecureStore.write(_keyDeviceJwt, jwt);
    AuthTokenCache.set(jwt);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCompanyId, companyId);
  }

  Future<String?> getDeviceJwt() async =>
      SecureStore.readOrNull(_keyDeviceJwt);

  /// Reverts the active token to the durable device token — used on logout and
  /// as the offline fallback when no per-user token could be minted.
  Future<void> resetActiveToDevice() async {
    final device = await getDeviceJwt();
    if (device != null && device.isNotEmpty) {
      await SecureStore.write(_keyJwt, device);
      AuthTokenCache.set(device);
    }
  }

  /// Persists the signed subscription lease and its decoded `validUntil` so the
  /// app can enforce the subscription offline (Pillar 2).
  Future<void> saveLease(String? lease) async {
    if (lease == null || lease.isEmpty) return;
    await SecureStore.write(_keyLease, lease);
    final validUntil = decodeLeaseValidUntil(lease);
    final prefs = await SharedPreferences.getInstance();
    if (validUntil != null) {
      await prefs.setString(
          _keyLeaseValidUntil, validUntil.toUtc().toIso8601String());
    }
  }

  Future<String?> getLease() async => SecureStore.readOrNull(_keyLease);

  /// Caches the server's RSA public key (PEM) used to verify the lease offline.
  Future<void> saveLeasePublicKey(String pem) async {
    if (pem.isEmpty) return;
    await SecureStore.write(_keyLeasePubKey, pem);
  }

  Future<String?> getLeasePublicKey() async =>
      SecureStore.readOrNull(_keyLeasePubKey);

  /// Advances the monotonic anti-rollback clock to [serverTime] if it is newer
  /// than what we've already seen (never moves backwards).
  Future<void> recordServerTime(DateTime serverTime) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keyMaxServerTime);
    final seen = existing == null ? null : DateTime.tryParse(existing);
    if (seen == null || serverTime.toUtc().isAfter(seen)) {
      await prefs.setString(
          _keyMaxServerTime, serverTime.toUtc().toIso8601String());
    }
  }

  Future<DateTime?> getMaxSeenServerTime() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyMaxServerTime);
    return s == null ? null : DateTime.tryParse(s);
  }

  /// The clock the offline guard trusts: the later of the device clock and the
  /// highest server time we've ever seen — so a backwards clock jump can't
  /// extend an expired lease.
  Future<DateTime> trustedNow() async {
    final now = DateTime.now().toUtc();
    final maxSeen = await getMaxSeenServerTime();
    return (maxSeen != null && maxSeen.isAfter(now)) ? maxSeen : now;
  }

  Future<DateTime?> getLeaseValidUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyLeaseValidUntil);
    return s == null ? null : DateTime.tryParse(s);
  }

  /// Decodes the `validUntil` claim from a lease JWT WITHOUT verifying its
  /// signature (display/quick-check only — verification against the server
  /// public key happens in the boot guard).
  static DateTime? decodeLeaseValidUntil(String jwt) {
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
      final map = jsonDecode(utf8.decode(base64.decode(p))) as Map<String, dynamic>;
      final v = map['validUntil'] as String?;
      return v == null ? null : DateTime.tryParse(v);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getJwt() async {
    return await SecureStore.readOrNull(_keyJwt);
  }

  /// Overwrites just the stored JWT — used by the sliding-window refresh on sync
  /// to keep the device token from expiring while online (leaves companyId/lease
  /// untouched, unlike [saveMasterSession]).
  Future<void> saveJwt(String jwt) async {
    if (jwt.isEmpty) return;
    await SecureStore.write(_keyJwt, jwt);
    AuthTokenCache.set(jwt);
  }

  Future<int?> getCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCompanyId);
  }

  Future<void> saveRegisteredEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRegisteredEmail, email);
  }

  Future<String?> getRegisteredEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRegisteredEmail);
  }

  Future<void> unlinkDevice() async {
    AuthTokenCache.clear();
    await SecureStore.delete(_keyJwt);
    await SecureStore.delete(_keyDeviceJwt);
    await SecureStore.delete(_keyLease);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCompanyId);
    await prefs.remove(_keyCachedUsers);
    await prefs.remove(_keyRegisteredEmail);
    await prefs.remove(_keyLeaseValidUntil);
  }

  Future<bool> isDeviceRegistered() async {
    final jwt = await getJwt();
    final companyId = await getCompanyId();
    return jwt != null && jwt.isNotEmpty && companyId != null;
  }

  Future<void> saveCachedUsers(List<dynamic> usersJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCachedUsers, jsonEncode(usersJson));
  }

  Future<List<dynamic>?> getCachedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? usersStr = prefs.getString(_keyCachedUsers);
    if (usersStr != null && usersStr.isNotEmpty) {
      return jsonDecode(usersStr) as List<dynamic>;
    }
    return null;
  }
}
