import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Pins the IANA database assumption behind the Settings timezone picker.
///
/// The picker crashed with DropdownButton's "There should be exactly one item
/// with [DropdownButton]'s value: UTC" because both the setting default and the
/// picker's fallback used `'UTC'` — which is **not** a location key in this
/// database (the canonical id is `Etc/UTC`). The dropdown had 341 items and none
/// matched, so the assertion fired the moment the mode was switched to Manual.
///
/// `_TimezoneCardState._safeTzId` now falls back to `_kUtcTzId` ('Etc/UTC'), and
/// `kSettingDefaults[SettingKeys.timezone]` uses it too. If a future `timezone`
/// package release renames or drops that key, this fails loudly here rather than
/// silently degrading the fallback to whatever sorts first (Africa/Abidjan).
void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('the IANA database has no bare "UTC" key — the canonical id is Etc/UTC', () {
    final ids = tz.timeZoneDatabase.locations.keys;
    expect(ids, isNot(contains('UTC')));
    expect(ids, contains('Etc/UTC'));
  });
}
