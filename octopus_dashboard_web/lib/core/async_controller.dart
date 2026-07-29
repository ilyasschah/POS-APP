import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../api/octopus_api.dart';
import '../features/auth/auth_controller.dart';
import 'screen_state.dart';

/// Base class for every screen-scoped data controller.
///
/// Centralizes the three rules that the iOS original got wrong:
///
/// 1. **Starts in loading**, never idle/empty, so the first frame is a spinner
///    rather than a flash of "no data".
/// 2. **A cancelled request is not an error.** Superseded and torn-down
///    requests are dropped silently instead of surfacing "couldn't load".
/// 3. **Refreshing keeps existing data on screen** while the new fetch is in
///    flight, so re-visiting a tab doesn't blank it out.
abstract class AsyncController<T> extends Notifier<ScreenState<T>> {
  CancelToken? _inFlight;
  bool _disposed = false;

  /// The session-scoped API client. Watched (not read) so that signing out or
  /// switching backends resets this controller back to a clean loading state.
  late final OctopusApi api = ref.watch(apiProvider);

  @override
  ScreenState<T> build() {
    // Touch `api` so the dependency is registered during build.
    api;
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _inFlight?.cancel('controller disposed');
    });
    return ScreenState<T>.loading();
  }

  /// Performs the actual network call. Implementations must forward
  /// [cancelToken] to every request they make.
  Future<T> fetch(CancelToken cancelToken);

  /// (Re)loads this screen's data.
  ///
  /// Safe to call on every visit to the screen — an in-flight request from a
  /// previous visit is cancelled rather than racing this one.
  Future<void> load() async {
    _inFlight?.cancel('superseded by a newer request');
    final token = CancelToken();
    _inFlight = token;

    state = state.toRefreshing();

    try {
      final data = await fetch(token);
      if (_disposed || token.isCancelled) return;
      state = ScreenState<T>.data(data);
    } on ApiException catch (error) {
      if (_disposed || token.isCancelled || error.isCancelled) return;
      state = state.toError(error.message);
    } catch (error) {
      if (_disposed || token.isCancelled) return;
      state = state.toError('Unexpected error: $error');
    } finally {
      if (identical(_inFlight, token)) _inFlight = null;
    }
  }
}
