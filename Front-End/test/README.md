# Tests

Two folders, split by **how Flutter runs them** — this split is required, not a
style choice:

```
test/                 # unit tests — pure Dart, headless, no device
├── error_handler_test.dart
├── scale_barcode_parser_test.dart
└── scale_weight_parser_test.dart

integration_test/     # on-device tests — real plugins (DB, prefs, secure storage)
├── cipher_test.dart              # proves the Drift DB is SQLCipher-encrypted
└── clear_local_data_test.dart    # wipes this terminal's saved identity
```

Everything device-dependent MUST live in `integration_test/`: Flutter only wires
up the native plugins (path_provider, shared_preferences, flutter_secure_storage)
for tests in that exact folder. Moved elsewhere they throw
`MissingPluginException`. So `test/` and `integration_test/` can't be merged.

## Unit tests

```bash
flutter test
```

Runs everything under `test/` headless in a couple of seconds. It does **not**
touch `integration_test/`, so a normal test run can never mutate a real device.

## Integration tests (need a device)

```bash
flutter test integration_test/cipher_test.dart -d windows
```

### Reset a terminal for auth / token-expiry testing

`clear_local_data_test.dart` wipes this machine's saved identity —
SharedPreferences (device id, company id, cached users, API base URL, …) and
secure storage (JWT, device token, subscription lease). It does **not** touch the
encrypted Drift database, so local orders/products survive; only auth + device
registration is reset.

```bash
flutter test integration_test/clear_local_data_test.dart -d windows
```

Afterwards, relaunch the app: it starts at the **master-login** screen with a
brand-new device id — a clean slate for master login, device registration, and
the session-expiry / token flows.
