import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../core/async_controller.dart';
import '../../core/screen_state.dart';
import '../../models/pos_session.dart';
import '../auth/auth_controller.dart';

/// History depths offered by the screen's menu. 50 matches the API default.
const List<int> kSessionHistoryDepths = [25, 50, 100, 250];

/// The session list — newest first, every register.
class SessionsController extends AsyncController<List<PosSession>> {
  int _take = 50;

  /// How deep into the history the last fetch reached.
  int get take => _take;

  @override
  Future<List<PosSession>> fetch(CancelToken cancelToken) =>
      api.fetchPosSessions(take: _take, cancelToken: cancelToken);

  /// Widens or narrows the window, then reloads with it.
  Future<void> loadWithTake(int value) {
    _take = value;
    return load();
  }
}

final sessionsProvider =
    NotifierProvider<SessionsController, ScreenState<List<PosSession>>>(
      SessionsController.new,
    );

/// One session's computed figures, fetched on demand by the row that shows it.
///
/// Deliberately **not** auto-disposed: rows scroll in and out constantly, and
/// an auto-disposing family would re-fetch the same summary every time a row
/// came back on screen. Freshness is handled by invalidating the family on an
/// explicit refresh instead.
///
/// Riverpod 3 retries failed providers with exponential backoff by default;
/// that is disabled here so a genuine failure shows once rather than
/// re-firing forever behind the user's back.
final sessionSummaryProvider = FutureProvider.family<PosSessionSummary, int>((
  ref,
  sessionId,
) async {
  final api = ref.watch(apiProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel('session summary no longer needed'));

  return api.fetchPosSessionSummary(
    sessionId: sessionId,
    cancelToken: cancelToken,
  );
}, retry: (_, _) => null);

/// userId → display name, so a session can read "opened by Sarah" instead of
/// "opened by 7".
///
/// Decoration only: a failure resolves to an empty map rather than an error,
/// because a missing name must never take the session list down with it — the
/// rows fall back to "User #7", which is still true.
final cashierNamesProvider = FutureProvider<Map<int, String>>((ref) async {
  final api = ref.watch(apiProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel('cashier names no longer needed'));

  try {
    final users = await api.fetchUsers(cancelToken: cancelToken);
    return {for (final user in users) user.id: user.displayName};
  } on ApiException {
    return const {};
  }
}, retry: (_, _) => null);
