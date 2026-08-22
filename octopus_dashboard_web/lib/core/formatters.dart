import 'package:intl/intl.dart';

import 'constants.dart';

/// Number/date formatting pinned to `en_US`.
///
/// The locale is explicit on purpose. On web the browser's locale leaks into
/// `intl`'s defaults, so an unpinned formatter would render "1 234,56" for a
/// French-locale browser and could shift API dates by a day. `en_US` symbol
/// data is compiled into `intl`, so no `initializeDateFormatting` call is
/// needed.
abstract final class Fmt {
  static const String _locale = 'en_US';

  static final NumberFormat _money = NumberFormat('#,##0.00', _locale);
  static final NumberFormat _plain = NumberFormat('#,##0.####', _locale);
  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd', _locale);
  static final DateFormat _displayDate = DateFormat('MMM d, yyyy', _locale);
  static final DateFormat _displayDateTime =
      DateFormat('MMM d, yyyy • HH:mm', _locale);
  static final DateFormat _shortDateTime = DateFormat('MMM d • HH:mm', _locale);
  static final DateFormat _clock = DateFormat('HH:mm', _locale);

  /// "1,234.56 DH" — two decimals, thousands separator, currency suffixed.
  static String currency(num? value) =>
      '${_money.format(value ?? 0)} ${AppConfig.currencySuffix}';

  /// "+12.00 DH" / "−12.00 DH", so a drawer shortfall reads as a shortfall at
  /// a glance. Values inside rounding noise render unsigned.
  static String signedCurrency(num? value) {
    final amount = (value ?? 0).toDouble();
    if (amount > 0.005) return '+${currency(amount)}';
    if (amount < -0.005) return '−${currency(-amount)}';
    return currency(0);
  }

  /// Quantities: trims pointless decimals, so 40.0 renders as "40" and
  /// 2.5 as "2.5".
  static String quantity(num? value) => _plain.format(value ?? 0);

  /// `yyyy-MM-dd` for API query params.
  ///
  /// Formats the *local* calendar fields, so "today" means the user's today.
  /// Deliberately not `toIso8601String()`, which would convert through UTC and
  /// can land on the previous/next day.
  static String apiDate(DateTime date) => _apiDate.format(date);

  static String date(DateTime? date) =>
      date == null ? '—' : _displayDate.format(date);

  static String dateTime(DateTime? date) =>
      date == null ? '—' : _displayDateTime.format(date);

  /// "Aug 17 • 09:12" — the year dropped, for dense list rows.
  static String shortDateTime(DateTime? date) =>
      date == null ? '—' : _shortDateTime.format(date);

  /// "17:54" — wall-clock only.
  static String time(DateTime? date) =>
      date == null ? '—' : _clock.format(date);

  /// Parses backend timestamps.
  ///
  /// The API mixes zoned (`...307Z`) and unzoned (`2026-07-16T00:00:00`)
  /// values. Zoned values are converted to local time; unzoned ones are
  /// already local wall-clock and are left alone.
  static DateTime? parseDate(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is! String || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  /// Parses a backend timestamp that is known to be UTC.
  ///
  /// POS sessions are stamped with `DateTime.UtcNow`, but EF reads them back
  /// from SQL Server as `Kind=Unspecified`, so they arrive with **no** zone
  /// suffix. [parseDate] would take that at face value as local wall-clock and
  /// every session time would silently drift by the viewer's UTC offset — an
  /// hour off in Morocco, more elsewhere. Use this parser for anything the
  /// server writes with `UtcNow`; use [parseDate] for values that are already
  /// local calendar dates (document dates).
  static DateTime? parseUtcDate(Object? raw) {
    if (raw is DateTime) return raw.isUtc ? raw.toLocal() : raw;
    if (raw is! String) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;

    final hasZone =
        text.endsWith('Z') ||
        text.endsWith('z') ||
        RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(text);
    // A bare date has no time to attach a zone to, and `2026-08-17Z` does not
    // parse — leave those alone.
    final hasTime = text.contains('T') || text.contains(' ');
    final normalized = (hasTime && !hasZone) ? '${text}Z' : text;

    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  /// "8h 42m" / "45m" / "2d 3h" — how long a session ran.
  static String duration(Duration? value) {
    if (value == null) return '—';
    final total = value.inMinutes < 0 ? 0 : value.inMinutes;
    final hours = total ~/ 60;
    final minutes = total % 60;
    if (hours >= 24) return '${hours ~/ 24}d ${hours % 24}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  /// Three-letter uppercase month label for the monthly chart, e.g. "JUL".
  static String monthLabel(int? month) {
    if (month == null || month < 1 || month > 12) return '${month ?? 0}';
    return DateFormat.MMM(_locale).format(DateTime(2000, month)).toUpperCase();
  }

  /// Hour-of-day label for the hourly chart, e.g. "14h".
  static String hourLabel(int? hour) => hour == null ? '' : '${hour}h';
}
