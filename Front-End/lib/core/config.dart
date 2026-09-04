/// Compile-time configuration.
///
/// ✅ **[defaultApiBaseUrl] points at PRODUCTION** (`api.octopus-pos.com`).
/// It pointed at the LAN/Tailscale dev server from 2026-08-06 until the
/// production cutover.
///
/// ## Why this is the only place the endpoint is written
///
/// It used to be spelled out in **three** places — here, `kDefaultApiBaseUrl`
/// in `api/api_client.dart`, and `kSettingDefaults[SettingKeys.apiBaseUrl]` in
/// `app_settings/app_settings_model.dart` — and this copy was **dead code, never
/// referenced by anything**. Editing one and missing the others is exactly how a
/// terminal ends up silently talking to the wrong backend: a fresh install with
/// no device-local override took the compiled default, reached a *different*
/// server, and was told by it that the subscription had expired — indis­tinguish­able
/// on screen from a real lapse. The other two now both read from here.
class AppConfig {
  /// The LAN dev/test backend (the machine the API runs on under the VS
  /// debugger).
  ///
  /// ⚠️ `100.114.12.38` is that machine's **Tailscale** address. A device not on
  /// that Tailnet — a plain VM on a VMware NAT network, for instance — cannot
  /// route to it at all, whatever this app is configured with. Such a machine
  /// needs either Tailscale installed inside it, or the API relaunched on every
  /// adapter (`ASPNETCORE_URLS=http://0.0.0.0:5002`) and a reachable address
  /// entered manually in Settings.
  static const String devBaseUrl = 'http://100.114.12.38:5002/api';

  /// The old hosted test backend.
  ///
  /// ⚠️ This server is GONE — the OVH box it ran on was deleted. The constant is
  /// kept only so a terminal that still has the URL saved in SharedPreferences
  /// resolves to a labelled segment ("Test") in the picker instead of showing up
  /// as an unrecognised custom endpoint. Nothing answers on it.
  static const String testBaseUrl = 'https://51-91-6-6.sslip.io/api';

  /// **Production.** The backend customers actually talk to.
  static const String prodBaseUrl = 'https://api.octopus-pos.com/api';

  /// The endpoint a terminal uses until one is chosen — on the master-login
  /// environment picker, or in Settings → Connection → API base URL. Stored
  /// device-locally in SharedPreferences; never cloud-synced, because it is how
  /// this terminal reaches the cloud in the first place.
  ///
  /// ✅ **Defaults to [prodBaseUrl].**
  ///
  /// This used to default to [devBaseUrl] behind a "flip it before shipping"
  /// note, and nothing enforced the flip. Neither `release-windows.yml` nor
  /// `release-macos.yml` passes `--dart-define=API_BASE_URL`, so every release
  /// built from this repo compiled in a **Tailscale address** — an endpoint that
  /// is unroutable from any customer machine on earth. A shipped terminal would
  /// simply fail to reach anything, with no clue as to why.
  ///
  /// Overridable at build time without touching source:
  /// `flutter build windows --dart-define=API_BASE_URL=https://…/api`
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: prodBaseUrl,
  );
}

/// The backends the master-login picker offers.
///
/// Mirrors the segmented control in `octopus_dashboard_web`
/// (`ApiEnvironment` in `features/auth/auth_controller.dart`) so the two apps
/// behave the same way — the POS just persists the choice device-locally
/// instead of in browser localStorage.
///
/// A terminal pointed at the wrong backend is not a visible failure: it logs in
/// fine, syncs fine, and reports whatever *that* server believes — including
/// "your subscription expired" from a tenant record that is not yours. Making
/// the choice explicit at master login is the point.
enum ApiEnvironment {
  dev('Dev', AppConfig.devBaseUrl),
  test('Test', AppConfig.testBaseUrl),
  prod('Production', AppConfig.prodBaseUrl);

  const ApiEnvironment(this.label, this.baseUrl);

  final String label;
  final String baseUrl;

  /// Trailing slashes and case differ harmlessly between a typed URL and a
  /// constant; compare on a normalized form so a hand-entered endpoint still
  /// lights up the matching segment.
  static String normalize(String url) {
    var v = url.trim().toLowerCase();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  /// Which segment [url] corresponds to, or **null** for a custom endpoint.
  ///
  /// Null rather than a default: a terminal on a hand-entered URL must not be
  /// shown as "Dev" or "Test", because the picker is the one place someone
  /// looks to confirm where the app is pointing. (The dashboard falls back to
  /// Test here; the POS deliberately does not — it has a Settings field for
  /// arbitrary endpoints, and silently mislabelling one is the exact failure
  /// this control exists to prevent.)
  static ApiEnvironment? forUrl(String url) {
    final normalized = normalize(url);
    for (final env in values) {
      if (normalize(env.baseUrl) == normalized) return env;
    }
    return null;
  }
}
