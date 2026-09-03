// `Application.DateFormat` was a setting that changed nothing.
//
// It had a dropdown in Settings › General › Regional offering four patterns,
// and every screen and every PDF in the app constructed its own
// `DateFormat('dd/MM/yyyy')` regardless — ~85 call sites in `reports_screen`
// alone, plus thirteen other files. Picking `yyyy-MM-dd` changed the value
// stored in the database and nothing a user could see.
//
// These tests pin the two halves of the fix: that the chosen pattern actually
// reaches the composed forms, and that machine-readable output does NOT follow
// it — which is the rule that stops a CSV silently changing shape under a
// spreadsheet that was written against the old one.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/core/app_date_format.dart';

void main() {
  final d = DateTime(2026, 9, 3, 14, 5, 9);

  group('the chosen pattern governs the display forms', () {
    test('each offered dropdown option formats as itself', () {
      // The four values `settings_screen.dart` actually offers. If one is ever
      // added there and not here, the new one is untested rather than silently
      // fine.
      expect(AppDateFormat('dd-MM-yyyy').date.format(d), '03-09-2026');
      expect(AppDateFormat('MM/dd/yyyy').date.format(d), '09/03/2026');
      expect(AppDateFormat('yyyy-MM-dd').date.format(d), '2026-09-03');
      expect(AppDateFormat('dd/MM/yyyy').date.format(d), '03/09/2026');
    });

    test('the composed forms keep the chosen date half', () {
      final f = AppDateFormat('yyyy-MM-dd');
      expect(f.dateTime.format(d), '2026-09-03 14:05');
      expect(f.dateTimeSeconds.format(d), '2026-09-03 14:05:09');
      expect(f.withTime('h:mm a').format(d), startsWith('2026-09-03 2:05'));
    });

    test('the weekday form appends rather than replacing the date', () {
      expect(AppDateFormat('dd/MM/yyyy').dateWithWeekday.format(d),
          '03/09/2026 (Thu)');
    });

    test('the short-year form narrows the year it was actually given', () {
      // Derived, not hardcoded: a company on yyyy-MM-dd must not suddenly get
      // a slash-separated date just because a column is narrow.
      expect(AppDateFormat('dd/MM/yyyy').shortYearDate.format(d), '03/09/26');
      expect(AppDateFormat('yyyy-MM-dd').shortYearDate.format(d), '26-09-03');
      expect(AppDateFormat('MM/dd/yyyy').shortYearWithTime('HH:mm').format(d),
          '09/03/26 14:05');
    });
  });

  group('a missing or junk setting falls back rather than throwing', () {
    // dd/MM/yyyy is what every call site hardcoded before this existed, so an
    // install whose setting is missing sees exactly what it saw before.
    test('null falls back to the historical default', () {
      expect(AppDateFormat(null).datePattern, 'dd/MM/yyyy');
      expect(AppDateFormat(null).date.format(d), '03/09/2026');
    });

    test('empty and whitespace fall back too', () {
      expect(AppDateFormat('').date.format(d), '03/09/2026');
      expect(AppDateFormat('   ').date.format(d), '03/09/2026');
    });

    test('a stored value is trimmed rather than taken literally', () {
      // A stray space in a settings row would otherwise become a leading space
      // on every printed date.
      expect(AppDateFormat(' yyyy-MM-dd ').date.format(d), '2026-09-03');
    });
  });

  group('machine-readable output does NOT follow the setting', () {
    // 🚨 The rule the CSV exports depend on. Both formats below are valid
    // dates, so a downstream importer does not ERROR when the shape changes —
    // it reads 09/03 as March 9th and carries on. That silence is the reason
    // exports are pinned.
    test('the ISO formats ignore whatever the company chose', () {
      expect(AppDateFormat.isoDate.format(d), '2026-09-03');
      expect(AppDateFormat.isoDateTime.format(d), '2026-09-03 14:05');
    });

    test('ISO stays ISO no matter how many instances are built', () {
      AppDateFormat('MM/dd/yyyy');
      AppDateFormat('dd-MM-yyyy');
      expect(AppDateFormat.isoDate.format(d), '2026-09-03');
    });

    test('the ISO pattern is sortable as plain text', () {
      final days = [DateTime(2026, 1, 9), DateTime(2026, 10, 1)]
          .map(AppDateFormat.isoDate.format)
          .toList();
      expect(days..sort(), ['2026-01-09', '2026-10-01']);
    });
  });

  group('isoToDisplay — the path the tables actually use', () {
    // 🚨 This is what the first pass MISSED. Sales History and Documents did
    // not call `DateFormat` at all; they hand-rolled `padLeft` strings that
    // hardcoded dd/MM/yyyy while doing their own timezone conversion, so a
    // sweep for `DateFormat('…')` could not see them and both tables went on
    // ignoring the setting after it was changed. Reported from the till.
    final f = AppDateFormat('yyyy-MM-dd', timezone: 'Etc/UTC');

    test('a timestamp gets the date AND the time', () {
      expect(f.isoToDisplay('2026-09-01T23:42:00Z'), '2026-09-01 23:42');
    });

    test('a bare date gets no time appended', () {
      expect(f.isoToDisplay('2026-09-01'), '2026-09-01');
    });

    test('a space-separated timestamp counts as a timestamp too', () {
      expect(f.isoToDisplay('2026-09-01 23:42:00'), '2026-09-01 23:42');
    });

    test('null and empty give the caller fallback, not a crash', () {
      expect(f.isoToDisplay(null), '-');
      expect(f.isoToDisplay(''), '-');
      expect(f.isoToDisplay(null, fallback: '—'), '—');
    });

    test('junk comes back verbatim rather than taking the table down', () {
      expect(f.isoToDisplay('not-a-date'), 'not-a-date');
    });

    test('the chosen pattern reaches it — the whole point of the fix', () {
      const iso = '2026-09-01T23:42:00Z';
      expect(AppDateFormat('MM/dd/yyyy').isoToDisplay(iso),
          startsWith('09/01/2026'));
      expect(AppDateFormat('dd-MM-yyyy').isoToDisplay(iso),
          startsWith('01-09-2026'));
    });
  });

  group('the timezone half', () {
    test('a stored instant is shown in the company zone', () {
      // 23:42 UTC on the 1st is 01:42 on the 2nd in Casablanca (UTC+1 there in
      // September) — the date rolls over, which is exactly why the conversion
      // cannot be skipped.
      final utc = AppDateFormat('yyyy-MM-dd', timezone: 'Etc/UTC');
      final casa = AppDateFormat('yyyy-MM-dd', timezone: 'Africa/Casablanca');
      const iso = '2026-09-01T23:42:00Z';
      expect(utc.isoToDisplay(iso), '2026-09-01 23:42');
      expect(casa.isoToDisplay(iso), isNot(utc.isoToDisplay(iso)));
      expect(casa.isoToDisplay(iso), startsWith('2026-09-02'));
    });

    test('a bare DATE is never shifted by a zone', () {
      // 🚨 A calendar day is not an instant. Shifting 2026-09-01 by an offset
      // is how a document dated the 1st starts displaying as the 31st.
      for (final zone in ['Etc/UTC', 'Africa/Casablanca', 'America/New_York']) {
        expect(AppDateFormat('yyyy-MM-dd', timezone: zone)
            .isoToDisplay('2026-09-01'), '2026-09-01');
      }
    });

    test('an unknown zone falls back instead of blanking every date', () {
      final f = AppDateFormat('yyyy-MM-dd', timezone: 'Mars/Olympus_Mons');
      expect(f.isoToDisplay('2026-09-01T23:42:00Z'), '2026-09-01 23:42');
    });

    test('a missing zone reads as UTC, matching how rows are stored', () {
      expect(AppDateFormat('yyyy-MM-dd', timezone: null).timezoneId,
          'Etc/UTC');
      expect(AppDateFormat('yyyy-MM-dd', timezone: '').timezoneId, 'Etc/UTC');
    });

    test('a naive DateTime is read as UTC, not as device-local', () {
      // The database and the wire both carry UTC; treating a naive value as
      // local would shift every date by the till's own offset.
      final f = AppDateFormat('yyyy-MM-dd HH:mm', timezone: 'Etc/UTC');
      expect(f.stamp(DateTime(2026, 9, 1, 23, 42)), startsWith('2026-09-01'));
    });
  });

  test('the default in app_settings_model is a pattern this class accepts', () {
    // The seeded default and the fallback here must agree, or a fresh install
    // formats dates differently from one whose setting has been cleared.
    final seeded = kSettingDefaults[SettingKeys.dateFormat];
    expect(seeded, isNotNull);
    expect(AppDateFormat(seeded).datePattern, seeded);
    expect(() => AppDateFormat(seeded).date.format(d), returnsNormally);
  });
}
