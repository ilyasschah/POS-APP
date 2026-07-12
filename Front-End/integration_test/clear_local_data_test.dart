// On-device utility that WIPES this terminal's saved local identity, returning
// the app to a fresh, unregistered state. Clears:
//   • SharedPreferences  — device id, company id, cached users, API base URL,
//                          theme prefs, license validity/clock, etc.
//   • flutter_secure_storage — the JWT, the durable device token, and the
//                          signed subscription lease + its public key.
//
// It deliberately does NOT touch the encrypted Drift database (local orders /
// products / documents), so only auth + device registration is reset — not
// transactional data. After running, relaunch the app and it will start at the
// master-login screen with a brand-new device id.
//
// Use it to re-test master login / device registration / token-expiry from a
// clean slate.
//
// It lives in integration_test/ (needs real device plugins), so a bare
// `flutter test` never runs it — no normal test run can wipe the machine. Run it
// deliberately, on a device:
//   flutter test integration_test/clear_local_data_test.dart -d windows
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CLEAR local device data (SharedPreferences + secure storage)',
      (tester) async {
    // ── SharedPreferences (device id, company id, cached users, base URL…) ──
    final prefs = await SharedPreferences.getInstance();
    final prefKeysBefore = prefs.getKeys().toList()..sort();
    debugPrint('CLEAR shared_preferences keys before (${prefKeysBefore.length}): '
        '$prefKeysBefore');
    await prefs.clear();

    // ── Secure storage (JWT / device token / lease). Log key NAMES only,
    //    never the secret values. ───────────────────────────────────────────
    const secure = FlutterSecureStorage();
    final secureKeysBefore = (await secure.readAll()).keys.toList()..sort();
    debugPrint('CLEAR secure-storage keys before (${secureKeysBefore.length}): '
        '$secureKeysBefore');
    await secure.deleteAll();

    // ── Confirm the wipe ────────────────────────────────────────────────────
    final prefsAfter = (await SharedPreferences.getInstance()).getKeys();
    final secureAfter = await secure.readAll();
    expect(prefsAfter, isEmpty, reason: 'SharedPreferences should be empty');
    expect(secureAfter, isEmpty, reason: 'secure storage should be empty');

    debugPrint('CLEAR done — device is now UNREGISTERED. '
        'Relaunch the app → master login, fresh device id.');
  });
}
