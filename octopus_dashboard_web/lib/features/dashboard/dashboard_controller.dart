import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_controller.dart';
import '../../core/screen_state.dart';
import '../../models/dashboard.dart';

/// The dashboard's active date filter.
///
/// Kept in its own provider so the picker can read/update the range without
/// touching the loaded data, and so changing the range doesn't rebuild the
/// chart widgets until new data actually arrives.
class DashboardRangeController extends Notifier<DateTimeRange> {
  @override
  DateTimeRange build() => defaultRange();

  /// Default range on first load: one month ago → today.
  static DateTimeRange defaultRange() {
    final now = DateTime.now();
    // DateTime normalizes an underflowing month (e.g. month 0 -> last
    // December), so this is safe in January.
    return DateTimeRange(
      start: DateTime(now.year, now.month - 1, now.day),
      end: now,
    );
  }

  void setRange(DateTimeRange range) => state = range;

  void setStart(DateTime start) =>
      state = DateTimeRange(start: start, end: state.end);

  void setEnd(DateTime end) =>
      state = DateTimeRange(start: state.start, end: end);
}

final dashboardRangeProvider =
    NotifierProvider<DashboardRangeController, DateTimeRange>(
      DashboardRangeController.new,
    );

class DashboardController extends AsyncController<DashboardData> {
  @override
  Future<DashboardData> fetch(CancelToken cancelToken) {
    final range = ref.read(dashboardRangeProvider);
    return api.fetchDashboard(
      startDate: range.start,
      endDate: range.end,
      cancelToken: cancelToken,
    );
  }
}

final dashboardProvider =
    NotifierProvider<DashboardController, ScreenState<DashboardData>>(
      DashboardController.new,
    );
