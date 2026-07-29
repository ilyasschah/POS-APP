import 'package:flutter/material.dart' show DateTimeRange;

/// Quick-select ranges offered by the dashboard's date filter.
///
/// Mirrors the iOS original's preset list and semantics: "this X" runs from
/// the start of the current period up to *now*, while "last X" covers the
/// whole of the previous period.
///
/// Weeks start on **Monday** (ISO 8601). The SwiftUI version inherited the
/// device locale's first weekday, which made the same preset mean different
/// things on different phones; pinning it keeps results reproducible.
enum DatePreset {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This week'),
  lastWeek('Last week'),
  thisMonth('This month'),
  lastMonth('Last month'),
  thisYear('This year'),
  lastYear('Last Year');

  const DatePreset(this.label);

  final String label;

  DateTimeRange resolve([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    return switch (this) {
      DatePreset.today => DateTimeRange(start: _startOfDay(now), end: now),
      DatePreset.yesterday => _fullDay(now.subtract(const Duration(days: 1))),
      DatePreset.thisWeek => DateTimeRange(start: _startOfWeek(now), end: now),
      DatePreset.lastWeek => _fullWeek(
        _startOfWeek(now).subtract(const Duration(days: 7)),
      ),
      DatePreset.thisMonth => DateTimeRange(
        start: DateTime(now.year, now.month),
        end: now,
      ),
      DatePreset.lastMonth => _fullMonth(now.year, now.month - 1),
      DatePreset.thisYear => DateTimeRange(
        start: DateTime(now.year),
        end: now,
      ),
      DatePreset.lastYear => DateTimeRange(
        start: DateTime(now.year - 1),
        end: _endOfDay(DateTime(now.year - 1, 12, 31)),
      ),
    };
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);

  static DateTimeRange _fullDay(DateTime d) =>
      DateTimeRange(start: _startOfDay(d), end: _endOfDay(d));

  /// Monday of the week containing [d].
  static DateTime _startOfWeek(DateTime d) =>
      _startOfDay(d).subtract(Duration(days: d.weekday - DateTime.monday));

  static DateTimeRange _fullWeek(DateTime monday) => DateTimeRange(
    start: _startOfDay(monday),
    end: _endOfDay(monday.add(const Duration(days: 6))),
  );

  /// [month] may be 0 — `DateTime` normalizes it to the previous December.
  static DateTimeRange _fullMonth(int year, int month) {
    final start = DateTime(year, month);
    // Day 0 of the following month is the last day of this one.
    final lastDay = DateTime(start.year, start.month + 1, 0);
    return DateTimeRange(start: start, end: _endOfDay(lastDay));
  }
}
