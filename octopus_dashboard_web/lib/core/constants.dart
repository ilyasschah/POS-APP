/// App-wide constants.
///
/// 🚨 The company id used to live here as `companyId = 25`, described as
/// "single-tenant scope". It was applied to every request regardless of who
/// signed in, so the dashboard reported company 25's figures to every account
/// and a freshly created company looked like it had no access — the server was
/// never asked about it. The tenant now comes from the login response
/// (`user.companyId`) and travels on the API client. Currency is still fixed.
abstract final class AppConfig {
  /// Currency is always Moroccan dirham, suffixed after the number.
  /// e.g. "1,234.56 DH". Never user-configurable.
  static const String currencySuffix = 'DH';

  /// Named backend environments offered by the login screen's segmented picker.
  ///
  /// NOTE (web-specific): a page served over HTTPS cannot call the `http://`
  /// Dev backend — browsers block mixed active content. Dev is only reachable
  /// when this app itself is served over http (e.g. `flutter run` on
  /// localhost). The login screen surfaces a warning when it detects that
  /// combination, because "wrong API URL" is the single most common cause of
  /// "why is nothing loading".
  static const String devBaseUrl = 'http://100.114.12.38:5002/api';
  static const String testBaseUrl = 'https://51-91-6-6.sslip.io/api';

  /// The only backend this app should point at by default. The iOS original
  /// still shipped a stale Tailscale IP as its compiled-in default; that bug
  /// is fixed here by defaulting to Test.
  static const String defaultBaseUrl = testBaseUrl;

  /// Minimum length enforced client-side before an admin password reset is
  /// allowed to submit.
  static const int minPasswordLength = 6;
}

/// Persisted preference keys (backed by localStorage on web).
abstract final class PrefKeys {
  static const darkMode = 'isDarkMode';
  static const glassEnabled = 'glassEffectEnabled';
  static const glassOpacity = 'glassTransparency';
  static const apiBaseUrl = 'apiBaseUrl';
  static const apiToken = 'apiToken';

  /// The signed-in user's company, stored alongside [apiToken] and removed with
  /// it. The two together are one session; either alone is a stale key.
  static const companyId = 'companyId';

  /// The address used for the last successful sign-in, so the login field can
  /// be pre-filled with the operator's OWN account rather than a constant.
  static const lastEmail = 'lastEmail';
  static const language = 'appLanguage';
}
