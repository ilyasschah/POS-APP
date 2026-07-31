import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../api/octopus_api.dart';
import '../../core/constants.dart';
import '../../core/settings.dart';

/// Which named backend a base URL corresponds to.
enum ApiEnvironment {
  dev('Dev', AppConfig.devBaseUrl),
  test('Test', AppConfig.testBaseUrl);

  const ApiEnvironment(this.label, this.baseUrl);

  final String label;
  final String baseUrl;

  /// Resolves the segmented control's selection from the current URL,
  /// falling back to Test for any custom URL.
  static ApiEnvironment forUrl(String url) {
    final normalized = OctopusApi.normalizeBaseUrl(url);
    for (final env in values) {
      if (OctopusApi.normalizeBaseUrl(env.baseUrl) == normalized) return env;
    }
    return ApiEnvironment.test;
  }
}

@immutable
class AuthState {
  const AuthState({
    required this.baseUrl,
    required this.email,
    this.token,
    this.isLoading = false,
    this.errorMessage,
  });

  final String baseUrl;
  final String email;

  /// Opaque bearer token. Held in memory only — deliberately not persisted, so
  /// a browser reload requires signing in again.
  final String? token;

  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  AuthState copyWith({
    String? baseUrl,
    String? email,
    String? token,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearToken = false,
  }) => AuthState(
    baseUrl: baseUrl ?? this.baseUrl,
    email: email ?? this.email,
    token: clearToken ? null : (token ?? this.token),
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return AuthState(
      // The last-used URL is remembered so a client doesn't retype it on
      // every visit; defaults to Test rather than the stale Dev IP the iOS
      // build shipped with.
      baseUrl: prefs.getString(PrefKeys.apiBaseUrl) ?? AppConfig.defaultBaseUrl,
      email: AppConfig.defaultEmail,
      token: prefs.getString(PrefKeys.apiToken),
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
      } catch (_) {
        // Ignored on purpose.
      }

      state = state.copyWith(
        token: result.token,
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
  final session = ref.watch(authProvider.select((s) => (s.baseUrl, s.token)));
  final api = ref.read(apiFactoryProvider)(
    baseUrl: session.$1,
    token: session.$2,
    onTokenExpired: () {
      ref.read(authProvider.notifier).signOut();
    },
  );
  ref.onDispose(api.close);
  return api;
});
