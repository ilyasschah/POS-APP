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
import 'package:pos_app/settings/device_scoped_settings.dart';
import 'package:pos_app/settings/local_ui_prefs.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/core/pos_virtual_keyboard.dart';
import 'package:pos_app/core/app_theme.dart';
import 'package:pos_app/core/device_theme_mode_provider.dart';
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
  const _BootDecision(this.registered, this.license);
}

class _MyAppState extends ConsumerState<MyApp> {
  late Future<_BootDecision> _bootFuture;

  @override
  void initState() {
    super.initState();
    _bootFuture = _decideBoot();
  }

  Future<_BootDecision> _decideBoot() async {
    final storage = ref.read(authStorageProvider);
    final registered = await storage.isDeviceRegistered();
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
