import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Pillar 3 — derives the SQLCipher key for the local database.
///
/// The key is **never hardcoded**. It is derived (HKDF-SHA256) from two inputs:
///
///  1. A 256-bit random *secret* generated once and kept in
///     [FlutterSecureStorage]. On Windows that store is DPAPI (user+machine
///     bound); on Android it is Keystore-backed and **non-exportable**. This is
///     the strong binding — the secret cannot be copied to another machine/user.
///  2. A stable *hardware fingerprint* (machine GUID / device build identity),
///     used as the HKDF salt for defense-in-depth.
///
/// Net effect: copying `pos_app.sqlite` to another device is useless — the
/// secret can't leave its origin device, so the derived key can't be
/// reconstructed there. This is also what makes the Pillar-4 seat binding
/// clone-proof (a soft `device_id` alone was copyable).
class DeviceKeyService {
  static const _secureStorage = FlutterSecureStorage();

  /// Secure-storage key holding the random secret (the strong, non-exportable
  /// half of the derivation).
  static const _kSecret = 'db_cipher_secret_v1';

  /// HKDF context string — bump if the derivation scheme ever changes.
  static const _info = 'pos-db-key-v1';

  /// Returns the 64-char hex SQLCipher key for this device. Stable across runs
  /// on the same device; different on any other device.
  Future<String> getDatabaseKey() async {
    final secret = await _getOrCreateSecret();
    final salt = utf8.encode(await _hardwareFingerprint());
    final keyBytes = _hkdfSha256(
      ikm: secret,
      salt: salt,
      info: utf8.encode(_info),
      length: 32,
    );
    return _toHex(keyBytes);
  }

  /// Loads the persisted random secret, generating + storing one on first run.
  Future<List<int>> _getOrCreateSecret() async {
    final existing = await _secureStorage.read(key: _kSecret);
    if (existing != null && existing.isNotEmpty) {
      try {
        return base64Decode(existing);
      } catch (_) {/* corrupted — regenerate below */}
    }
    final rng = Random.secure();
    final secret = List<int>.generate(32, (_) => rng.nextInt(256));
    await _secureStorage.write(key: _kSecret, value: base64Encode(secret));
    return secret;
  }

  /// A best-effort, stable per-device identifier. Failures fall back to a
  /// constant so the derivation never throws (the secret still binds the key).
  Future<String> _hardwareFingerprint() async {
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isWindows) {
        final w = await info.windowsInfo;
        return 'win:${w.deviceId}'; // registry MachineGuid
      }
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        // Unit identity isn't exposed cross-platform; combine the stable build
        // identifiers. The non-exportable Keystore secret is the real binding —
        // this is salt only.
        return 'and:${a.id}|${a.fingerprint}|${a.hardware}|'
            '${a.board}|${a.device}|${a.model}|${a.manufacturer}';
      }
      if (Platform.isLinux) {
        final l = await info.linuxInfo;
        return 'lin:${l.machineId ?? l.id}';
      }
      if (Platform.isMacOS) {
        final m = await info.macOsInfo;
        return 'mac:${m.systemGUID ?? m.computerName}';
      }
    } catch (_) {/* fall through */}
    return 'generic-device';
  }

  /// RFC 5869 HKDF (extract + expand) over HMAC-SHA256.
  List<int> _hkdfSha256({
    required List<int> ikm,
    required List<int> salt,
    required List<int> info,
    int length = 32,
  }) {
    final prk = Hmac(sha256, salt).convert(ikm).bytes; // extract
    final out = <int>[];
    var t = <int>[];
    var counter = 1;
    while (out.length < length) {
      t = Hmac(sha256, prk).convert([...t, ...info, counter]).bytes; // expand
      out.addAll(t);
      counter++;
    }
    return out.sublist(0, length);
  }

  String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
