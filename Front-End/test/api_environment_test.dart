// Pins the Dev/Test environment picker shown on the master-login screen.
//
// Why it matters: a terminal pointed at the wrong backend fails INVISIBLY. It
// logs in, syncs, and faithfully reports whatever that server believes —
// including "your subscription expired" read off a tenant record that isn't
// yours. That is exactly what happened on 2026-08-06, and it cost a session to
// find, because nothing on screen named the server being asked.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/core/config.dart';
import 'package:pos_app/settings/device_scoped_settings.dart';

void main() {
  group('ApiEnvironment.forUrl', () {
    test('recognises each shipped environment', () {
      expect(ApiEnvironment.forUrl(AppConfig.devBaseUrl), ApiEnvironment.dev);
      expect(ApiEnvironment.forUrl(AppConfig.testBaseUrl), ApiEnvironment.test);
    });

    test('tolerates trailing slashes, case and padding', () {
      expect(ApiEnvironment.forUrl('${AppConfig.devBaseUrl}/'),
          ApiEnvironment.dev);
      expect(ApiEnvironment.forUrl('  ${AppConfig.testBaseUrl.toUpperCase()}  '),
          ApiEnvironment.test);
    });

    test('returns null for a hand-entered endpoint — never a wrong label', () {
      // The whole point of the control is to say where the app is pointing. A
      // custom URL silently rendered as "Dev" would reintroduce the bug.
      expect(ApiEnvironment.forUrl('http://192.168.83.1:5002/api'), isNull);
      expect(ApiEnvironment.forUrl(''), isNull);
    });

    test('the two environments are actually different servers', () {
      expect(ApiEnvironment.dev.baseUrl,
          isNot(ApiEnvironment.test.baseUrl),
          reason: 'a picker between two identical endpoints is a lie');
    });
  });

  test('picking an environment changes what createDio() will dial', () {
    // _selectEnvironment writes through appSettingsProvider, whose apiBaseUrl
    // branch calls setApiBaseUrl(). This is that effect, isolated.
    setApiBaseUrl(ApiEnvironment.test.baseUrl);
    expect(apiBaseUrl, AppConfig.testBaseUrl);

    setApiBaseUrl(ApiEnvironment.dev.baseUrl);
    expect(apiBaseUrl, AppConfig.devBaseUrl);
  });

  test('the endpoint is device-scoped and can never be cloud-synced', () {
    // If this key ever reached app_properties, a terminal on the LAN endpoint
    // would push it to one on the hosted endpoint and silently move it to a
    // different backend — the same failure class as the Windows printer name
    // and the `D:\` backup path arriving on an Android tablet.
    expect(DeviceScopedSettings.isDeviceScoped('Application.Api.BaseUrl'),
        isTrue);
  });
}
