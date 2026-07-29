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

  /// "1,234.56 DH" — two decimals, thousands separator, currency suffixed.
  static String currency(num? value) =>
      '${_money.format(value ?? 0)} ${AppConfig.currencySuffix}';

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

  /// Three-letter uppercase month label for the monthly chart, e.g. "JUL".
  static String monthLabel(int? month) {
    if (month == null || month < 1 || month > 12) return '${month ?? 0}';
    return DateFormat.MMM(_locale).format(DateTime(2000, month)).toUpperCase();
  }

  /// Hour-of-day label for the hourly chart, e.g. "14h".
  static String hourLabel(int? hour) => hour == null ? '' : '${hour}h';
}
