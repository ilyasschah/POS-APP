import 'package:flutter/material.dart';
import 'package:pos_app/auth/auth_token_cache.dart';

/// Navigator handle for code that has no `BuildContext` — specifically the Dio
/// error interceptor, which lives below the widget tree. Wired onto `MaterialApp`
/// in `main.dart`.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// One-time "your token is dead → re-login" response to an authenticated 401.
///
/// The server rejects a stale / revoked / signing-secret-rotated token with 401.
/// A full sync fires dozens of requests that all 401 at once, so this is
/// **debounced**: the first one clears the token and routes to login; the rest
/// are ignored until a fresh token is issued (main.dart wires
/// [AuthTokenCache.onTokenSet] → [reset]).
///
/// Only requests that actually *carried* a token trigger this — a 401 with no
/// `Authorization` header is an ordinary auth failure (e.g. bad credentials on
/// `/Auth/Login`) and is left for the caller. Being offline is a *connection*
/// error, not a 401, so this never fires when the network is simply down.
class SessionExpiry {
  SessionExpiry._();

  static bool _handling = false;

  /// Builds the screen to land on. Set once in `main.dart` — kept as a hook so
  /// this file never imports the UI layer (which would form an import cycle with
  /// `api_client.dart`).
  static WidgetBuilder? loginRouteBuilder;

  /// A token-bearing request came back 401. Clear the dead token and route to
  /// login exactly once.
  static void onUnauthorized() {
    if (_handling || loginRouteBuilder == null) return;
    _handling = true;
    // Stop sending the dead token immediately so nothing keeps looping on it.
    AuthTokenCache.clear();
    // Never navigate during an error-callback/build frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = rootNavigatorKey.currentState;
      if (nav == null) {
        _handling = false; // no navigator yet — let a later 401 retry
        return;
      }
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: loginRouteBuilder!),
        (route) => false,
      );
    });
  }

  /// Re-arm after a fresh token is issued (successful login / refresh), so a
  /// later expiry can trigger the flow again.
  static void reset() => _handling = false;
}
