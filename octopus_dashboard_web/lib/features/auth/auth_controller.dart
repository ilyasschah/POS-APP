import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../api/octopus_api.dart';
import '../../core/constants.dart';
import '../../core/settings.dart';

/// Which named backend a base URL corresponds to.
enum ApiEnvironment {
  dev('Dev', AppConfig.devBaseUrl),
  test('Test', AppConfig.testBaseUrl),
  prod('Production', AppConfig.prodBaseUrl);

  const ApiEnvironment(this.label, this.baseUrl);

  final String label;
  final String baseUrl;

  /// Resolves the segmented control's selection from the current URL,
  /// falling back to Production for any custom URL. (It used to fall back to
  /// Test — that backend no longer exists, so the fallback pointed the control
  /// at a dead server.)
  static ApiEnvironment forUrl(String url) {
    final normalized = OctopusApi.normalizeBaseUrl(url);
    for (final env in values) {
      if (OctopusApi.normalizeBaseUrl(env.baseUrl) == normalized) return env;
    }
    return ApiEnvironment.prod;
  }
}

@immutable
class AuthState {
  const AuthState({
    required this.baseUrl,
    required this.email,
    this.token,
    this.companyId,
    this.isLoading = false,
    this.errorMessage,
  });

  final String baseUrl;
  final String email;

  /// Opaque bearer token, persisted so a browser reload does not sign the user
  /// out mid-task.
  final String? token;

  /// The company the token belongs to. Persisted WITH the token and cleared
  /// with it — the two are one session, and a token restored without knowing
  /// whose company it is was the bug: the dashboard came back up scoped to
  /// whatever company the constant said, under someone else's session.
  final int? companyId;

  final bool isLoading;
  final String? errorMessage;

  /// A session is only usable when BOTH halves survived. A token with no
  /// company cannot scope a single request, so it is not a signed-in state —
  /// it is a stale key, and treating it as a session is what put another
  /// company's data on screen.
  bool get isAuthenticated =>
      token != null && token!.isNotEmpty && (companyId ?? 0) > 0;

  AuthState copyWith({
    String? baseUrl,
    String? email,
    String? token,
    int? companyId,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearToken = false,
  }) => AuthState(
    baseUrl: baseUrl ?? this.baseUrl,
    email: email ?? this.email,
    token: clearToken ? null : (token ?? this.token),
    companyId: clearToken ? null : (companyId ?? this.companyId),
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    // Both halves of the session or neither. A token whose company is missing
    // cannot scope a request, and restoring it anyway is how the dashboard came
    // back up under a previous user's session.
    final token = prefs.getString(PrefKeys.apiToken);
    final companyId = prefs.getInt(PrefKeys.companyId);
    final sessionIntact =
        token != null && token.isNotEmpty && (companyId ?? 0) > 0;
    return AuthState(
      // The last-used URL is remembered so a client doesn't retype it on
      // every visit; defaults to Test rather than the stale Dev IP the iOS
      // build shipped with.
      baseUrl: prefs.getString(PrefKeys.apiBaseUrl) ?? AppConfig.defaultBaseUrl,
      // The LAST EMAIL SIGNED IN WITH, not a compile-time address. The field
      // used to be pre-filled with a developer's own account, so signing in on
      // a fresh browser with only a password typed logged you into somebody
      // else's company — which is exactly what "it keeps logging back to
      // another user" describes.
      email: prefs.getString(PrefKeys.lastEmail) ?? '',
      token: sessionIntact ? token : null,
      companyId: sessionIntact ? companyId : null,
    );
  }

  void setBaseUrl(String value) {
    state = state.copyWith(baseUrl: value, clearError: true);
  }

  void setEmail(String value) {
    state = state.copyWith(email: value, clearError: true);
  }

  /// Applies an environment preset, overwriting the API Base URL field.
  void selectEnvironment(ApiEnvironment env) => setBaseUrl(env.baseUrl);

  Future<bool> login(String password) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, clearError: true);

    final baseUrl = OctopusApi.normalizeBaseUrl(state.baseUrl);
    // Built through the factory rather than `apiProvider`: at this point there
    // is no token, and `apiProvider` depends on this controller's own state.
    final api = ref.read(apiFactoryProvider)(baseUrl: baseUrl);
    try {
      final result = await api.login(
        email: state.email.trim(),
        password: password,
      );

      if (!result.success || result.token == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: result.message?.trim().isNotEmpty == true
              ? result.message
              : 'Login failed. Check your email and password.',
        );
        return false;
      }

      // No company on the account means nothing can be scoped, so say so
      // instead of signing in to a dashboard that would answer for the wrong
      // tenant or fail on every panel.
      final companyId = result.companyId ?? 0;
      if (companyId <= 0) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'This account is not attached to a company, so there is nothing '
              'to show. Ask an administrator to assign it one.',
        );
        return false;
      }

      // Remember the URL that actually worked. Best-effort: Safari in private
      // mode can refuse localStorage entirely, and failing to remember a
      // preference must never block an otherwise successful sign-in.
      try {
        await ref
            .read(sharedPreferencesProvider)
            .setString(PrefKeys.apiBaseUrl, baseUrl);
        await ref
            .read(sharedPreferencesProvider)
            .setString(PrefKeys.apiToken, result.token!);
        // Stored with the token, cleared with the token.
        await ref
            .read(sharedPreferencesProvider)
            .setInt(PrefKeys.companyId, companyId);
        await ref
            .read(sharedPreferencesProvider)
            .setString(PrefKeys.lastEmail, state.email.trim());
      } catch (_) {
        // Ignored on purpose.
      }

      state = state.copyWith(
        token: result.token,
        companyId: companyId,
        baseUrl: baseUrl,
        isLoading: false,
        clearError: true,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      // Backstop: anything unexpected must still clear the loading state,
      // otherwise the Sign In button spins forever with no way to retry.
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not sign in: $e',
      );
      return false;
    } finally {
      api.close();
    }
  }

  void signOut() {
    try {
      ref.read(sharedPreferencesProvider).remove(PrefKeys.apiToken);
      // The company goes with it. Leaving it behind meant the next sign-in
      // started life already scoped to the previous user's tenant.
      ref.read(sharedPreferencesProvider).remove(PrefKeys.companyId);
    } catch (_) {}
    state = state.copyWith(clearToken: true, clearError: true);
  }
}

/// Constructs API clients. Overridden in tests to inject a fake; there is no
/// other reason to replace it.
typedef ApiFactory =
    OctopusApi Function({
      required String baseUrl,
      String? token,
      int? companyId,
      void Function()? onTokenExpired,
    });

final apiFactoryProvider = Provider<ApiFactory>((ref) => OctopusApi.new);

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// The authenticated API client.
///
/// Watches only the session-identifying fields, so transient auth changes
/// (such as `isLoading` flipping during sign-in) don't needlessly rebuild the
/// client or invalidate every screen that depends on it.
final apiProvider = Provider<OctopusApi>((ref) {
  final session = ref.watch(
    authProvider.select((s) => (s.baseUrl, s.token, s.companyId)),
  );
  final api = ref.read(apiFactoryProvider)(
    baseUrl: session.$1,
    token: session.$2,
    companyId: session.$3,
    onTokenExpired: () {
      ref.read(authProvider.notifier).signOut();
    },
  );
  ref.onDispose(api.close);
  return api;
});
