import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  channelBuffers.resize('flutter/lifecycle', 100);
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const OctopusApp(),
    ),
  );
}

class OctopusApp extends ConsumerWidget {
  const OctopusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(settingsProvider.select((s) => s.language));
    final isDarkMode = ref.watch(settingsProvider.select((s) => s.darkMode));
    final isAuthenticated = ref.watch(
      authProvider.select((s) => s.isAuthenticated),
    );

    return MaterialApp(
      title: 'Octopus Owner Dashboard',
      debugShowCheckedModeBanner: false,
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: isAuthenticated ? const AppShell() : const LoginScreen(),
      scrollBehavior: const _AppScrollBehavior(),
    );
  }
}

/// Lets lists be dragged with a mouse or trackpad, not just a touch screen —
/// without this, click-and-drag scrolling doesn't work in desktop browsers.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
