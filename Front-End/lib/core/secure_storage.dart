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
