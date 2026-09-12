import 'package:flutter/material.dart';

import 'package:pos_app/l10n/app_localizations.dart';

/// The Period presets a filter bar offers — today, yesterday, this and last
/// week (weeks start on Monday), this and last calendar month — each as a
/// label and a range of WHOLE days, for the Period section of a
/// `UnifiedSearchBar`.
///
/// Built with the DateTime constructor rather than by subtracting Durations,
/// which drifts an hour across a DST change and lands "yesterday" at 23:00 the
/// day before. Ends are inclusive days: a range ending on the 5th means "up to
/// the end of the 5th", so callers compare against the day AFTER [end].
List<(String, DateTimeRange)> periodPresets(
  AppLocalizations l, {
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final yesterday = DateTime(n.year, n.month, n.day - 1);
  final weekStart = DateTime(n.year, n.month, n.day - (n.weekday - 1));
  final monthStart = DateTime(n.year, n.month);
  return [
    (l.today, DateTimeRange(start: today, end: today)),
    (l.yesterday, DateTimeRange(start: yesterday, end: yesterday)),
    (l.thisWeek, DateTimeRange(start: weekStart, end: today)),
    (
      l.lastWeek,
      DateTimeRange(
        start: DateTime(weekStart.year, weekStart.month, weekStart.day - 7),
        end: DateTime(weekStart.year, weekStart.month, weekStart.day - 1),
      ),
    ),
    (l.thisMonth, DateTimeRange(start: monthStart, end: today)),
    (
      l.lastMonth,
      DateTimeRange(
        start: DateTime(n.year, n.month - 1),
        // Day 0 of this month is the last day of the previous one.
        end: DateTime(n.year, n.month, 0),
      ),
    ),
  ];
}
