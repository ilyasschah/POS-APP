import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';

/// The date pattern used for MACHINE-READABLE output — CSV columns, exported
/// data files, anything a spreadsheet or another program parses.
///
/// 🚨 Deliberately NOT the company's chosen display format, and this is the one
/// rule in this file that is about correctness rather than taste. A CSV whose
/// date column changes shape when somebody picks a different setting breaks
/// every downstream import that was written against the old shape — silently,
/// because `03/09/2026` and `09/03/2026` are both valid dates and neither one
/// errors. ISO also sorts correctly as text, which `dd/MM/yyyy` does not.
///
/// Use [AppDateFormat.isoDate] / [AppDateFormat.isoDateTime] at those call
/// sites rather than writing the pattern out again, so an export that opts out
/// of the setting is opting out VISIBLY.
const String kIsoDatePattern = 'yyyy-MM-dd';

/// How this company shows a date: the chosen pattern, plus the timezone the
/// instant is rendered in.
///
/// 🚨 **Both halves belong together, and keeping them apart is what let the
/// tables drift.** `Application.DateFormat` was wired through the `DateFormat`
/// call sites while the screens that also had to convert a timezone —
/// Sales History and Documents — had hand-rolled their own renderers out of
/// `padLeft` and string interpolation. Those never touched `DateFormat` at all,
/// so a sweep for `DateFormat('…')` could not see them and they went on
/// printing `dd/MM/yyyy` after the setting said otherwise. Anything that shows
/// a stored instant needs the zone AND the pattern; this object is the only
/// place that answers both.
///
/// Immutable and cheap to hold; the `DateFormat` instances are built once,
/// because a table body formats one per row.
class AppDateFormat {
  AppDateFormat(String? pattern, {String? timezone})
      : datePattern = (pattern == null || pattern.trim().isEmpty)
            ? _fallbackPattern
            : pattern.trim(),
        timezoneId = (timezone == null || timezone.trim().isEmpty)
            ? _fallbackTimezone
            : timezone.trim();

  /// What the setting defaults to, and what every hardcoded call site used
  /// before this existed — so an install that has never touched the setting
  /// sees exactly what it saw before.
  static const _fallbackPattern = 'dd/MM/yyyy';

  /// 'Etc/UTC', not 'UTC': the IANA database has no plain 'UTC' location key.
  static const _fallbackTimezone = 'Etc/UTC';

  /// The raw pattern, for the rare caller that needs to compose its own.
  final String datePattern;

  /// The IANA zone stored instants are displayed in.
  final String timezoneId;

  /// A date on its own. The overwhelmingly common case.
  late final DateFormat date = DateFormat(datePattern);

  /// Date + time to the minute.
  late final DateFormat dateTime = DateFormat('$datePattern HH:mm');

  /// Date + time to the second — report footers, audit rows.
  late final DateFormat dateTimeSeconds = DateFormat('$datePattern HH:mm:ss');

  /// Date with the weekday appended, e.g. `03/09/2026 (Thu)`.
  late final DateFormat dateWithWeekday = DateFormat('$datePattern (EEE)');

  /// The chosen pattern with a two-digit year, for columns too narrow for the
  /// full one.
  ///
  /// Derived from the chosen pattern rather than hardcoded, so a company on
  /// `yyyy-MM-dd` gets `yy-MM-dd` and not a sudden slash-separated date.
  late final String shortYearPattern = datePattern.replaceAll('yyyy', 'yy');

  late final DateFormat shortYearDate = DateFormat(shortYearPattern);

  /// The chosen date pattern followed by an arbitrary TIME pattern.
  ///
  /// For the handful of screens that want something other than 24-hour clock
  /// time — `h:mm a`, say. The DATE half still comes from the setting, which is
  /// the whole point: only the time half is the caller's business.
  DateFormat withTime(String timePattern) =>
      DateFormat('$datePattern $timePattern');

  /// [withTime] on the two-digit-year form.
  DateFormat shortYearWithTime(String timePattern) =>
      DateFormat('$shortYearPattern $timePattern');

  /// ISO date, for machine-readable output only — see [kIsoDatePattern].
  static final DateFormat isoDate = DateFormat(kIsoDatePattern);

  /// ISO date + time, for machine-readable output only.
  static final DateFormat isoDateTime = DateFormat('$kIsoDatePattern HH:mm');

  // ── timezone ──────────────────────────────────────────────────────────────

  /// The IANA database is loaded once per process, on first use.
  ///
  /// Three screens each called `initializeTimeZones()` in their own `initState`
  /// before this existed, which meant a screen that forgot to silently fell
  /// back to UTC. Doing it here means no caller can forget.
  static bool _tzReady = false;
  static void _ensureTimeZones() {
    if (_tzReady) return;
    tz_data.initializeTimeZones();
    _tzReady = true;
  }

  /// Moves a stored instant into the company's timezone.
  ///
  /// A naive `DateTime` is read as UTC, matching how the app stores them — the
  /// database holds UTC and the wire carries UTC. Falls back to the untouched
  /// instant if the configured zone is not a real IANA id, because a bad
  /// setting must not blank out every date on the screen.
  DateTime toDisplayZone(DateTime dt) {
    final utc = dt.isUtc
        ? dt
        : DateTime.utc(
            dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
    try {
      _ensureTimeZones();
      return tz.TZDateTime.from(utc, tz.getLocation(timezoneId));
    } catch (_) {
      return utc;
    }
  }

  /// An instant → `<date> HH:mm` in the company's zone and format.
  String stamp(DateTime dt) => dateTime.format(toDisplayZone(dt));

  /// A calendar day → the company's date format, with NO zone conversion.
  ///
  /// 🚨 A bare date is not an instant. Shifting `2026-09-03` by a UTC offset is
  /// how a document dated the 3rd starts displaying as the 2nd.
  String day(DateTime dt) => date.format(dt);

  /// An ISO string straight out of the database, rendered for display.
  ///
  /// Carries a time part → [stamp]; a bare `yyyy-MM-dd` → [day]. That split is
  /// what the two hand-rolled screen formatters were doing, and it is worth
  /// keeping: a document DATE and a created-at TIMESTAMP live in the same table
  /// and want different treatment.
  ///
  /// Unparseable input comes back verbatim rather than throwing — a malformed
  /// row should show its own bad value, not take the table down.
  String isoToDisplay(String? iso, {String fallback = '-'}) {
    if (iso == null || iso.isEmpty) return fallback;
    try {
      final dt = DateTime.parse(iso);
      final hasTime = iso.contains('T') || iso.contains(' ');
      return hasTime ? stamp(dt) : day(dt);
    } catch (_) {
      return iso;
    }
  }
}

/// The company's date format, rebuilt only when the SETTINGS it reads change.
///
/// 🚨 `.select`ed to a record of the two keys. `appSettingsProvider` hands out a
/// fresh `Map` on every rebuild and a `Map` has no value equality, so a plain
/// watch would rebuild every screen holding a date — which is nearly all of
/// them — on any settings write at all: a theme toggle, a printer name, a COM
/// port. A record compares by value, so only a real change to the format or the
/// timezone propagates. Same reasoning as `sessionGateProvider`.
final appDateFormatProvider = Provider<AppDateFormat>((ref) {
  final s = ref.watch(
    appSettingsProvider.select(
      (m) => (
        pattern: m[SettingKeys.dateFormat],
        timezone: m[SettingKeys.timezone],
      ),
    ),
  );
  return AppDateFormat(s.pattern, timezone: s.timezone);
});
