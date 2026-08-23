import 'package:pos_app/core/secure_storage.dart';

/// In-memory cache of the active device/user JWT.
///
/// The global Dio interceptor needs the token on every request, but reading
/// `flutter_secure_storage` (a DPAPI-backed file on Windows) per request caused
/// concurrent file access — and, when that file is corrupt, a delete-while-locked
/// crash. So the token is loaded from storage exactly ONCE (deduped) and then
/// kept here; every write path (login / refresh / logout) updates it in place, so
/// the interceptor never touches the file again.
class AuthTokenCache {
  AuthTokenCache._();

  static const _storage = kSecureStorage;
  static const _key = 'jwt_token';

  static String? _token;
  static bool _loaded = false;
  static Future<String?>? _loading;

  /// Fired whenever a real (non-empty) token becomes active. `main.dart` wires
  /// this to `SessionExpiry.reset` so a later expiry can re-trigger the login
  /// flow. Kept as a hook so this cache stays free of UI / navigation imports.
  static void Function()? onTokenSet;

  /// The current token, loading it from storage once on first use. Crash-proof:
  /// a corrupt/locked storage file yields `null` (proceed unauthenticated) rather
  /// than throwing.
  static Future<String?> get() async {
    if (_loaded) return _token;
    return _loading ??= _load();
  }

  static Future<String?> _load() async {
    try {
      _token = await _storage.read(key: _key);
    } catch (_) {
      _token = null; // corrupt / locked file — never crash a request over it
    }
    _loaded = true;
    _loading = null;
    return _token;
  }

  /// Update the cache when the active token changes (login / refresh).
  static void set(String? token) {
    _token = (token != null && token.isNotEmpty) ? token : null;
    _loaded = true;
    if (_token != null) onTokenSet?.call();
  }

  /// Drop the cached token (logout / device unlink).
  static void clear() {
    _token = null;
    _loaded = true;
  }
}
