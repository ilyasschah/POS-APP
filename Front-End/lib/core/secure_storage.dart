import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The one `FlutterSecureStorage` configuration the app uses.
///
/// Every call site must go through this rather than constructing its own
/// `FlutterSecureStorage()`, because the default options are wrong on macOS —
/// see below — and a fourth call site that forgets would fail at runtime with a
/// bare error code, on one platform only.
///
/// ## Why macOS needs an override
///
/// `MacOsOptions.usesDataProtectionKeychain` defaults to **true**, which routes
/// reads and writes to macOS's data-protection keychain. That keychain requires
/// the calling app to be code-signed with a `keychain-access-groups`
/// entitlement, and the entitlement is only honoured for an app signed by an
/// Apple Developer ID team. Octopus POS ships ad-hoc signed (see
/// `macos/Runner/Release.entitlements`), so every read and write came back as
/// OSStatus **-34018 / errSecMissingEntitlement** — surfaced to the operator as
/// "Registration failed: Unexpected security result code, Code: -34018".
///
/// That was not a login bug. `DeviceKeyService` keeps the SQLCipher secret here
/// and `AuthStorage` keeps the JWTs, so on macOS the app could neither open its
/// own database nor hold a session.
///
/// Setting the flag to false uses the legacy file-based (login) keychain, which
/// needs no entitlement and no paid Apple account. The items are still stored
/// by the OS keychain, still encrypted at rest, and still scoped to the user
/// account — the entitlement gates *which* keychain, not whether there is one.
///
/// ⚠️ If this app is ever signed with a real Developer ID, do not flip this back
/// without a migration: the two keychains are separate stores, so items written
/// under one are invisible to the other. On macOS that would read as a wiped
/// device — a lost database key means a database that cannot be opened.
///
/// Windows (DPAPI), Android (Keystore) and Linux ignore this option entirely.
const FlutterSecureStorage kSecureStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);

/// Serialised, self-healing access to [kSecureStorage]. Every call site should
/// go through this rather than touching [kSecureStorage] directly.
///
/// ## The bug this exists to kill
///
/// `flutter_secure_storage_windows` keeps one DPAPI-encrypted JSON file and
/// takes NO lock over it. `write` and `delete` are read-modify-write — both
/// call `load()` first — so a sync tick that refreshes the JWT while the
/// licence lease is being read has two operations on that one file at once.
///
/// When the blob will not decrypt, `load()` logs "Delete corrupt file" and
/// calls `file.delete()` on its way out. With a second operation mid-flight the
/// delete loses the race against that operation's own transient handle and
/// throws:
///
/// ```text
/// PathAccessException: Cannot delete file ... (OS Error: The process cannot
/// access the file because it is being used by another process, errno = 32)
/// ```
///
/// The corrupt file therefore survives, so the very next call fails the same
/// way — for ever. That is the loop that filled the console, failed the
/// `refreshToken` sync step, and made `LicenseService` report a healthy network
/// as "lease refresh skipped (offline?)".
///
/// Running the operations one at a time is the whole fix: the plugin's own
/// cleanup then succeeds, the bad file goes exactly once, and the next write
/// rebuilds the store from empty.
class SecureStore {
  SecureStore._();

  /// The tail of the queue. Every operation chains onto it, so exactly one is
  /// ever in flight. The `catch` inside [_serial] keeps this future from
  /// completing with an error — a failed operation must not poison the lane
  /// behind it.
  static Future<void> _tail = Future<void>.value();

  static bool _reportedUnreadable = false;

  /// Exposed so the ordering guarantee — the entire point of this class —
  /// can be tested without a platform channel.
  @visibleForTesting
  static Future<T> runSerially<T>(Future<T> Function() op) => _serial(op);

  static Future<T> _serial<T>(Future<T> Function() op) {
    final done = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        done.complete(await op());
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  /// Says it once. The failure repeats on every sync tick until the store is
  /// rebuilt, and 50 identical stack traces hide whatever else is in the log.
  static void _noteUnreadable(Object e) {
    if (_reportedUnreadable) return;
    _reportedUnreadable = true;
    debugPrint(
      'Secure storage is unreadable and is being rebuilt — stored tokens are '
      'gone and the device will need to sign in again. Cause: $e',
    );
  }

  /// A read whose value is safe to lose: an unreadable store reads as "nothing
  /// stored". Correct for the JWTs and the licence lease — the worst case is a
  /// sign-in — and it keeps a broken keystore from failing a sync step.
  static Future<String?> readOrNull(String key) => _serial(() async {
        try {
          return await kSecureStorage.read(key: key);
        } catch (e) {
          // The failed read has already binned the bad file, so there is
          // nothing to retry against — the store is simply empty now.
          _noteUnreadable(e);
          return null;
        }
      });

  /// A read that must NOT invent an answer: an unreadable store throws rather
  /// than reporting "absent".
  ///
  /// 🚨 [DeviceKeyService] depends on this distinction. It mints a new random
  /// secret when the stored one is absent, and that secret derives the
  /// SQLCipher key — so answering "absent" for a store that is merely
  /// unreadable would silently re-key the database and strand every row in it.
  /// Absent means absent; unreadable is a failure and has to travel like one.
  static Future<String?> readOrThrow(String key) =>
      _serial(() => kSecureStorage.read(key: key));

  /// Writes, retrying once through the plugin's own recovery.
  ///
  /// `write` calls `load()` first, and a `load()` that cannot decrypt deletes
  /// the file before it rethrows. So the first attempt is what clears the bad
  /// blob and the second lands on an empty store — which is exactly the state a
  /// fresh install writes into.
  static Future<void> write(String key, String value) =>
      _serial(() => _selfHeal(() => kSecureStorage.write(key: key, value: value)));

  static Future<void> delete(String key) =>
      _serial(() => _selfHeal(() => kSecureStorage.delete(key: key)));

  static Future<void> _selfHeal(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      _noteUnreadable(e);
      await op();
    }
  }
}
