// Exercises the first-run flow end to end: it renders without overflow at both a
// phone width and a desktop width (the adaptive layouts), Skip completes it, and
// walking to the last page + picking a theme + Get Started both applies the theme
// choice live and flags onboarding done.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/device_theme_mode_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/onboarding/onboarding_prefs.dart';
import 'package:pos_app/onboarding/onboarding_screen.dart';
import 'package:pos_app/onboarding/onboarding_seed.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required double width,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // The delegates are required: onboarding now reads its copy through
        // AppLocalizations.of(context), which throws without them (MyApp
        // supplies them in the real app).
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('renders the welcome slide without overflow on a phone width',
      (tester) async {
    await pump(tester, width: 400);
    expect(find.text('Welcome to your POS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the wide two-pane layout without overflow on desktop',
      (tester) async {
    await pump(tester, width: 1280);
    expect(find.text('Welcome to your POS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Skip completes onboarding immediately', (tester) async {
    final c = await pump(tester, width: 400);
    expect(c.read(onboardingCompleteProvider), isFalse);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(c.read(onboardingCompleteProvider), isTrue);
  });

  testWidgets('walk all pages: theme on setup, activity, then Get Started',
      (tester) async {
    final c = await pump(tester, width: 400);

    // 7 pages: welcome, DATA SOURCE, features, quick-start, setup, layout,
    // activity → 4 Next taps reach the setup slide. The data-source slide sits
    // second (cloud vs restore-a-backup); "Next" advances past it exactly like
    // its own "Sync with the cloud" card does.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Set up your terminal'), findsOneWidget);

    // Theme choice applies live via the device override.
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(c.read(deviceThemeModeProvider), 'light');

    // Through the layout slide, then on to the activity slide (the last page).
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text("What's your business?"), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Picking "Shop" switches tables + booking off in the seed.
    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    expect(c.read(onboardingFeatureSeedProvider).tables, isFalse);
    expect(c.read(onboardingFeatureSeedProvider).booking, isFalse);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(c.read(onboardingCompleteProvider), isTrue);
  });
}
