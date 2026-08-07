// Pins that a terminal's default API endpoint is declared exactly ONCE.
//
// The bug this guards, which cost a full debugging session on 2026-08-06:
// the default endpoint was written out in three independent places —
// `AppConfig.baseUrl` (which was dead code and referenced by nothing),
// `kDefaultApiBaseUrl`, and `kSettingDefaults[SettingKeys.apiBaseUrl]`.
//
// A freshly-installed POS with no device-local override therefore dialled the
// compiled-in constant, reached a DIFFERENT backend than the one being worked
// on, and was told by that server that the company's subscription had expired.
// On screen it was indistinguishable from a genuine lapse: same title, same
// message, same "contact your service provider". Meanwhile the intended server
// said the subscription ran for another ten days.
//
// Nothing else catches this — every value was individually valid, analyze was
// clean, and the app booted fine. It only surfaces with two terminals and two
// backends.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/core/config.dart';

void main() {
  test('every default-endpoint constant resolves to the same URL', () {
    expect(kDefaultApiBaseUrl, AppConfig.defaultApiBaseUrl);
    expect(kSettingDefaults[SettingKeys.apiBaseUrl], AppConfig.defaultApiBaseUrl,
        reason: 'the Settings field must advertise the endpoint actually used');
  });

  test('the default is a usable absolute URL ending in /api', () {
    final uri = Uri.tryParse(AppConfig.defaultApiBaseUrl);
    expect(uri, isNotNull);
    expect(uri!.hasScheme, isTrue, reason: 'Dio needs an absolute baseUrl');
    expect(uri.scheme, anyOf('http', 'https'));
    expect(uri.host, isNotEmpty);
    // Every call site is written as '/Controller/Action', so the base must
    // already carry the /api prefix or every request 404s.
    expect(AppConfig.defaultApiBaseUrl, endsWith('/api'));
    expect(AppConfig.defaultApiBaseUrl, isNot(endsWith('//api')));
  });

  test('a blank stored override falls back to the default, not to empty', () {
    // initApiBaseUrl is fed straight from SharedPreferences, which returns null
    // on a fresh install and '' if the operator clears the Settings field.
    for (final stored in <String?>[null, '', '   ']) {
      initApiBaseUrl(stored);
      expect(apiBaseUrl, AppConfig.defaultApiBaseUrl,
          reason: 'a terminal must never end up with an empty baseUrl');
    }
  });

  test('a device-local override wins, and clearing it restores the default',
      () {
    initApiBaseUrl('http://10.0.0.7:5002/api');
    expect(apiBaseUrl, 'http://10.0.0.7:5002/api');

    setApiBaseUrl('');
    expect(apiBaseUrl, AppConfig.defaultApiBaseUrl,
        reason: 'clearing the field is "use the default", not "use nothing"');
  });
}
