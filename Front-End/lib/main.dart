import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/auth/auth_token_cache.dart';
import 'package:pos_app/auth/session_expiry.dart';
import 'package:pos_app/auth/master_login_screen.dart';
import 'package:pos_app/sync/account_status_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_app/auth/login_screen.dart';
import 'package:pos_app/l10n/app_locale.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/license/license_service.dart';
import 'package:pos_app/license/subscription_blocked_screen.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/database/db_location.dart';
import 'package:pos_app/settings/device_scoped_settings.dart';
import 'package:pos_app/settings/local_ui_prefs.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/core/pos_virtual_keyboard.dart';
import 'package:pos_app/core/app_theme.dart';
import 'package:pos_app/core/device_theme_mode_provider.dart';
import 'package:pos_app/database/db_missing_screen.dart';
import 'package:pos_app/database/restore_service.dart';
import 'package:pos_app/onboarding/onboarding_prefs.dart';
import 'package:pos_app/onboarding/onboarding_screen.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // window_manager only exists on desktop — skip on Android/iOS.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    await windowManager.ensureInitialized();
  }
  final prefs = await SharedPreferences.getInstance();
  // Seed the API endpoint from the device-local override BEFORE any request
  // (master-login/sync need it, and it can't come from the cloud-synced settings
  // because you need the endpoint to reach the cloud in the first place).
  initApiBaseUrl(prefs.getString(kApiBaseUrlPrefKey));
  // Same reasoning, one layer up: this terminal's printer / backup-path / COM
  // port choices are device-local and must be in memory before the first read of
  // appSettingsProvider, whose build() is synchronous and cannot await.
  await DeviceScopedSettings.init(prefs);

  // Graceful auth-failure handling: when the server rejects our token with 401,
  // the Dio interceptor routes here, to the login screen (once, debounced). A
  // fresh token re-arms it. Wired here so the coordinator stays UI-import-free.
  SessionExpiry.loginRouteBuilder =
      (_) => const LoginScreen(sessionExpired: true);
  AuthTokenCache.onTokenSet = SessionExpiry.reset;

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

/// Decides the first screen at boot: device registration first, then the
/// Pillar-2 offline subscription guard.
class _BootDecision {
  final bool registered;
  final LicenseEvaluation? license;

  /// The terminal is registered but its database file has gone. Distinct from
  /// a fresh install (where the file is *also* absent) — see [_decideBoot].
  final bool databaseMissing;

  const _BootDecision(this.registered, this.license,
      {this.databaseMissing = false});
}

class _MyAppState extends ConsumerState<MyApp> {
  late Future<_BootDecision> _bootFuture;

  @override
  void initState() {
    super.initState();
    _bootFuture = _decideBoot();
  }

  /// Re-runs the boot decision with the missing-database gate skipped, for the
  /// operator who chose "start fresh" on [DbMissingScreen]. The empty database
  /// is created on the first open and the normal sync repopulates it.
  Future<_BootDecision> _decideBootFresh() =>
      _decideBoot(ignoreMissingDatabase: true);

  Future<_BootDecision> _decideBoot({bool ignoreMissingDatabase = false}) async {
    // FIRST, before anything looks at the database file: relocate a database
    // left in the old (OneDrive-synced) Documents directory into the local
    // app-support directory. It must run before `liveDatabaseMissing()` below —
    // that check now looks in the NEW location, so without this a terminal
    // whose file is still in Documents would report "database missing" and
    // never open Drift, and the lazy migration inside `_openConnection` would
    // never fire. Idempotent + a no-op once migrated. See `db_location.dart`.
    await migrateDatabaseOutOfDocumentsIfNeeded();

    final storage = ref.read(authStorageProvider);
    final registered = await storage.isDeviceRegistered();

    // ⚠️ Checked BEFORE anything opens Drift, because opening a path that does
    // not exist CREATES an empty database — silently. Without this the terminal
    // boots looking like it lost every product and sale, with nothing on screen
    // saying why, and the operator's next sale writes into the empty file.
    //
    // Registration lives in secure storage, not the database, which is what
    // makes the two cases separable: no file + NOT registered is an ordinary
    // fresh install; no file + registered means it went missing underneath a
    // configured till. A staged restore is not a problem either way — the swap
    // happens when the connection opens, so the file is about to exist.
    if (!ignoreMissingDatabase &&
        registered &&
        await RestoreService.liveDatabaseMissing() &&
        !(await RestoreService.stagedFile()).existsSync()) {
      return const _BootDecision(true, null, databaseMissing: true);
    }

    if (!registered) return const _BootDecision(false, null);

    // Deleted-account guard at boot: if this terminal's company was deleted in
    // the admin portal while the app was closed, unlink and fall back to the
    // master login (re-link) instead of the subscription-blocked screen. Online
    // + best-effort only — an offline/unknown result never unlinks a legitimate
    // offline terminal (it just proceeds on its cached lease below).
    final companyId = await storage.getCompanyId();
    if (companyId != null) {
      if (await checkCompanyExists(companyId) == CompanyExistence.deleted) {
        // Same as the in-session guard in MainLayout: wipe the local mirror
        // first. Unlinking alone left the deleted company's whole dataset in
        // pos_app.sqlite forever.
        await ref.read(appDatabaseProvider).purgeAllLocalData();
        await storage.unlinkDevice();
        return const _BootDecision(false, null);
      }
      // Pull the freshest lease so a provider-side pause / resume / days change
      // (admin Subscriptions page) takes effect on this launch. Best-effort +
      // online only — offline keeps the cached lease, so a legitimate offline
      // terminal is never affected.
      try {
        await ref.read(licenseServiceProvider).refreshFromServer(companyId);
      } catch (_) {}
    }

    // Registered terminal: enforce the offline subscription lease before
    // letting the operator into the POS.
    final license = await ref.read(licenseServiceProvider).evaluate();
    return _BootDecision(true, license);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    // Language and writing direction are deliberately INDEPENDENT: picking
    // Arabic does not force RTL. App.WritingDirection (Settings → General →
    // Application Style) is the only thing that flips the layout, so a venue
    // can run an Arabic UI left-to-right if that is what they want.
    // Maps the stored `Application.Language` onto a locale we actually ship.
    // Companies seeded before the dropdown was trimmed can still hold es/de/it,
    // which have no .arb — and Flutter's own fallback is supportedLocales.first,
    // i.e. ARABIC. Never hand MaterialApp a raw setting value. See
    // resolveAppLocale's doc comment and test/l10n_test.dart.
    final locale = resolveAppLocale(settings[SettingKeys.language]);
    final isRtl =
        settings[SettingKeys.writingDirection]?.toUpperCase() == 'RTL';

    // Device-local accent wins (boot cache — stops the brown flash), read
    // reactively so the onboarding accent picker recolours the app live.
    final savedHex =
        ref.watch(deviceAccentColorProvider) ??
        settings[SettingKeys.themeAccentColor];
    // Device-local override wins (boot cache — prevents theme flash), now read
    // reactively so the onboarding theme picker restyles the app live.
    final themeString =
        ref.watch(deviceThemeModeProvider) ??
        settings[SettingKeys.themeMode] ??
        'dark';

    final seed = parseAccentColor(savedHex);
    final themeData = buildAppTheme(themeString, seed);

    // Global font scale — a per-terminal preference stored locally (NOT cloud
    // synced), so adjusting it on one POS never changes another. The notifier
    // already clamps to a safe range; applied as a textScaler override so it
    // multiplies every Text in the tree, including ones with a hardcoded
    // fontSize.
    final fontScale = ref.watch(fontScaleProvider);

    // First-run gate. Device-local, read synchronously (no async flash). When
    // the placeholder's "Get Started" flips this, MyApp rebuilds straight into
    // the normal boot flow below — no manual navigation.
    final onboarded = ref.watch(onboardingCompleteProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      // NOT `title:` — that is evaluated here in MyApp.build, ABOVE the
      // Localizations scope MaterialApp creates, so AppLocalizations.of(context)
      // would be null and the generated `!` throws at boot. onGenerateTitle's
      // callback runs with a context below Localizations, where it resolves.
      onGenerateTitle: (context) => AppLocalizations.of(context).posSystem,
      themeMode: ThemeMode.light,
      theme: themeData,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(fontScale)),
        child: Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: VirtualKeyboardHost(child: child!),
        ),
      ),
      // Boot order is deliberate: device registration (master login, which
      // needs the internet) comes FIRST, and onboarding only after it. That
      // guarantees a company exists by the time the operator makes any
      // onboarding choice, so nothing has to be captured before there is
      // somewhere to put it. Onboarding used to run ahead of all of this.
      home: FutureBuilder<_BootDecision>(
        future: _bootFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final decision = snapshot.data!;
          // Ahead of every other gate: with no database there is nothing for
          // the licence check or the login picker to read, and letting the app
          // through would quietly rebuild an empty one.
          if (decision.databaseMissing) {
            return DbMissingScreen(
              // "Start fresh" just proceeds — the empty database gets created
              // on the first open and the normal sync fills it from the cloud.
              onStartFresh: () => setState(() => _bootFuture = _decideBootFresh()),
            );
          }
          if (!decision.registered) return const MasterLoginScreen();
          final license = decision.license;
          if (license != null && license.blocked) {
            return SubscriptionBlockedScreen(evaluation: license);
          }
          // Reached on a cold launch of a device that is already registered but
          // has never been onboarded (e.g. an upgrade from a build that had no
          // onboarding). The first-install path goes through MasterLoginScreen,
          // which pushes onboarding itself once registration succeeds.
          if (!onboarded) return const OnboardingScreen();
          return const LoginScreen();
        },
      ),
    );
  }
}
