// The POS name ("POS1") is the label the account's Active-devices list shows
// instead of the 40-character `POS-<uuid>` signature. It is device-local truth
// (shared_preferences), so the ONLY way the server learns it is by the terminal
// reporting it: `deviceName` on /Auth/Login, `X-Device-Name` on every sync, and
// /Master/RenameDevice right after an edit.
//
// Two contracts are pinned here because breaking either is silent:
//   • the header is SENT when a name is set — otherwise DeviceRegistry keeps the
//     name a device first registered with, forever (which is how every live row
//     ended up reading "POS terminal");
//   • the header is OMITTED when no name is set — the server reads "no name" as
//     "no change", so sending an empty one would blank a good name on the first
//     sync from a terminal whose pref hasn't loaded.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/settings/device_identity.dart';
import 'package:pos_app/sync/sync_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quiet_sync_logs.dart';

/// Records the headers and URI of every request a sync makes; answers everything
/// with a 404 so no step can accidentally succeed and do real work.
class _HeaderSpyAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> requestHeaders = [];
  final List<String> requestedUris = [];

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<List<int>>? _, Future<void>? __) async {
    requestHeaders.add(Map<String, dynamic>.from(options.headers));
    requestedUris.add(options.uri.toString());
    return ResponseBody.fromString(jsonEncode(null), 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    // Every request below is answered 404 on purpose — see quiet_sync_logs.
    silenceDebugPrint();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<_HeaderSpyAdapter> syncOnce() async {
    final adapter = _HeaderSpyAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api'))
      ..httpClientAdapter = adapter;
    await SyncManager(db: db, dio: dio, authStorage: AuthStorage()).sync(25);
    return adapter;
  }

  group('the terminal reports its name to the control plane', () {
    test('a named POS sends X-Device-Name on every sync request', () async {
      SharedPreferences.setMockInitialValues({
        'pos.device.name': 'POS1',
        'device_id': 'POS-test-device',
      });

      final adapter = await syncOnce();

      expect(adapter.requestHeaders, isNotEmpty,
          reason: 'the sync made no request at all — the spy proves nothing');
      for (final headers in adapter.requestHeaders) {
        expect(headers['X-Device-Name'], 'POS1');
        expect(headers['X-Device-Id'], 'POS-test-device');
      }
    });

    test('an unnamed POS omits the header, so the server keeps the name it has',
        () async {
      SharedPreferences.setMockInitialValues({'device_id': 'POS-test-device'});

      final adapter = await syncOnce();

      expect(adapter.requestHeaders, isNotEmpty);
      for (final headers in adapter.requestHeaders) {
        expect(headers.containsKey('X-Device-Name'), isFalse);
        // The seat signature still goes out — only the label is withheld.
        expect(headers['X-Device-Id'], 'POS-test-device');
      }
      expect(
        adapter.requestedUris.where((u) => u.contains('RenameDevice')),
        isEmpty,
        reason: 'nothing to report — an empty name must never be sent',
      );
    });

    // 🚨 The regression this exists for. The header is only READ by SeatGuard,
    // which runs at the BatchSync ingresses — endpoints a terminal with nothing
    // pending never calls. Reported live: a named till pressed Sync over and
    // over and its registry row still read the placeholder it was registered
    // with. So the name must go out under its own power, every sync.
    test('every sync reports the name outright, not only when there is a push',
        () async {
      SharedPreferences.setMockInitialValues({
        'pos.device.name': 'POS1',
        'device_id': 'POS-test-device',
      });

      final adapter = await syncOnce();

      final rename = adapter.requestedUris
          .where((u) => u.contains('/Master/RenameDevice'))
          .toList();
      expect(rename, hasLength(1),
          reason: 'a sync with an empty push queue still has to report');
      expect(rename.single, contains('deviceName=POS1'));
      expect(rename.single, contains('deviceId=POS-test-device'));
    });
  });

  group('name entry produces a valid document-number prefix', () {
    const formatter = DeviceNameInputFormatter();

    TextEditingValue type(String s) => formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: s),
        );

    test('the field stores exactly what it shows', () {
      // Whatever the formatter allows through must survive sanitizeDeviceName
      // untouched — otherwise the operator names the POS one thing and the
      // document numbers carry another.
      for (final raw in ['caisse 1', 'POS-2', 'Terminal_Bar#3', 'abcdefghijklmnop']) {
        final shown = type(raw).text;
        expect(sanitizeDeviceName(shown), shown,
            reason: '"$raw" typed as "$shown" would be rewritten on save');
      }
    });

    test('lowercase, spaces and punctuation are corrected as typed', () {
      expect(type('caisse 1').text, 'CAISSE1');
      expect(type('POS-2').text, 'POS2');
    });

    test('length is capped at the barcode-safe limit', () {
      expect(type('ABCDEFGHIJKLMNOP').text.length, kDeviceNameMaxLength);
    });

    test('an empty field stays empty — never the "POS" fallback', () {
      // Clearing the field is mid-edit, not a decision. Substituting here would
      // persist "POS" over a name the operator was in the middle of retyping.
      expect(type('').text, '');
      expect(type('---').text, '');
      // The fallback belongs to sanitize, which is what a SAVE goes through.
      expect(sanitizeDeviceName(''), 'POS');
    });
  });
}
