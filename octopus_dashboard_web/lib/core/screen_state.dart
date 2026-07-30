import 'package:flutter/foundation.dart';

/// The load state of a single screen's data.
///
/// Deliberately starts in **loading**, never "empty/idle", so the first frame
/// shows a spinner rather than flashing a "no data" empty state before the
/// fetch has begun.
///
/// [ScreenState.error] can carry the previous [data]: when a background
/// refresh fails but we still hold good data, the screen keeps rendering that
/// data and shows a non-destructive inline banner instead of blanking out.
@immutable
class ScreenState<T> {
  const ScreenState.loading() : data = null, error = null, isRefreshing = false;

  const ScreenState.data(T this.data)
    : error = null,
      isRefreshing = false;

  const ScreenState.refreshing(T this.data)
    : error = null,
      isRefreshing = true;

  const ScreenState.error(String this.error, {this.data})
    : isRefreshing = false;

  final T? data;
  final String? error;

  /// True while re-fetching *with* data already on screen.
  final bool isRefreshing;

  /// True only for the very first load, when there is nothing to show yet.
  bool get isInitialLoading => data == null && error == null;

  bool get hasData => data != null;
  bool get hasError => error != null;

  /// The state to enter when a refresh begins: keep showing existing data if
  /// we have it, otherwise fall back to a full-screen spinner.
  ScreenState<T> toRefreshing() {
    final current = data;
    return current == null
        ? ScreenState<T>.loading()
        : ScreenState<T>.refreshing(current);
  }

  /// The state to enter when a refresh fails, preserving any data we still
  /// hold so a transient blip doesn't wipe the screen.
  ScreenState<T> toError(String message) =>
      ScreenState<T>.error(message, data: data);
}
