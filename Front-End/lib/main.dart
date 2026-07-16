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
import 'package:pos_app/license/license_service.dart';
import 'package:pos_app/license/subscription_blocked_screen.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:pos_app/settings/local_ui_prefs.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
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

ThemeData _buildTheme(String mode, Color seed) {
  switch (mode) {
    case 'light':
      return ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
      );

    case 'dimmed':
      final cs = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: cs.copyWith(
          surface: const Color(0xFF1C2333),
          surfaceContainerLowest: const Color(0xFF111927),
          surfaceContainerLow: const Color(0xFF1A2030),
          surfaceContainer: const Color(0xFF202736),
          surfaceContainerHigh: const Color(0xFF263040),
          surfaceContainerHighest: const Color(0xFF283045),
        ),
        scaffoldBackgroundColor: const Color(0xFF15202B),
        cardColor: const Color(0xFF1C2333),
      );

    case 'night':
      final cs = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: cs.copyWith(
          surface: const Color(0xFF080808),
          surfaceContainerLowest: Colors.black,
          surfaceContainerLow: const Color(0xFF0D0D0D),
          surfaceContainer: const Color(0xFF111111),
          surfaceContainerHigh: const Color(0xFF161616),
          surfaceContainerHighest: const Color(0xFF1C1C1C),
          onSurface: Colors.white,
          onSurfaceVariant: const Color(0xFFCCCCCC),
        ),
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF0D0D0D),
      );

    case 'gray':
      final cs = ColorScheme.fromSeed(
        seedColor: const Color(0xFF808080),
        brightness: Brightness.dark,
      ).copyWith(primary: seed, secondary: seed, tertiary: seed);
      return ThemeData(
        useMaterial3: true,
        colorScheme: cs,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardColor: const Color(0xFF262626),
      );

    case 'high_contrast':
      final cs = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: cs.copyWith(
          surface: Colors.black,
          surfaceContainerLowest: Colors.black,
          surfaceContainerLow: const Color(0xFF0A0A0A),
          surfaceContainer: const Color(0xFF0F0F0F),
          surfaceContainerHigh: const Color(0xFF1A1A1A),
          surfaceContainerHighest: const Color(0xFF222222),
          onSurface: Colors.white,
          onSurfaceVariant: const Color(0xFFE0E0E0),
          outline: const Color(0xFF777777),
          outlineVariant: const Color(0xFF444444),
        ),
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF111111),
      );

    default: // 'dark'
      return ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      );
  }
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

  Color _parseAccentColor(String? hex) {
    if (hex == null) return Colors.blue;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final prefs = ref.watch(sharedPreferencesProvider);

    final isRtl =
        settings[SettingKeys.writingDirection]?.toUpperCase() == 'RTL';

    // Read synchronously from SharedPreferences first to stop the brown flash
    final savedHex =
        prefs.getString('boot_theme_color') ??
        settings[SettingKeys.themeAccentColor];
    final themeString =
        prefs.getString('boot_theme_mode') ??
        settings[SettingKeys.themeMode] ??
        'dark';

    final seed = _parseAccentColor(savedHex);
    final themeData = _buildTheme(themeString, seed);

    // Global font scale — a per-terminal preference stored locally (NOT cloud
    // synced), so adjusting it on one POS never changes another. The notifier
    // already clamps to a safe range; applied as a textScaler override so it
    // multiplies every Text in the tree, including ones with a hardcoded
    // fontSize.
    final fontScale = ref.watch(fontScaleProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      title: 'POS System',
      themeMode: ThemeMode.light,
      theme: themeData,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(fontScale)),
        child: Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
      ),
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
          return const LoginScreen();
        },
      ),
    );
  }
}
