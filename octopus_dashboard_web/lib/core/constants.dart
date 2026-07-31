/// App-wide constants.
///
/// Everything here is deliberately hardcoded per the product spec — there is
/// no company switcher and no currency picker in this app.
abstract final class AppConfig {
  /// Single-tenant scope. Every API call carries this as a query param.
  static const int companyId = 25;

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

  /// Pre-filled on the login screen for dev convenience, matching the iOS app.
  static const String defaultEmail = 'ilyasschah18@gmail.com';

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
  static const language = 'appLanguage';
}
