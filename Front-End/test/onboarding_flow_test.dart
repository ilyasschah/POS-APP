// Exercises the first-run flow end to end: it renders without overflow at both a
// phone width and a desktop width (the adaptive layouts), Skip completes it, and
// walking to the last page + picking a theme + Get Started both applies the theme
// choice live and flags onboarding done. The Setup slide's POS name must be
// confirmed free by the server before Next leaves it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/device_theme_mode_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/onboarding/onboarding_prefs.dart';
import 'package:pos_app/onboarding/onboarding_screen.dart';
import 'package:pos_app/onboarding/onboarding_seed.dart';
import 'package:pos_app/settings/device_identity.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required double width,
    DeviceNameCheck nameCheck = DeviceNameCheck.available,
    List<String>? checkedNames,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // No server in a widget test: the POS-name check answers from here.
        deviceNameCheckerProvider.overrideWithValue((name) async {
          checkedNames?.add(name);
          return nameCheck;
        }),
      ],
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

  // 7 pages: welcome, DATA SOURCE, features, quick-start, setup, layout,
  // activity → 4 Next taps reach the setup slide. The data-source slide sits
  // second (cloud vs restore-a-backup); "Next" advances past it exactly like
  // its own "Sync with the cloud" card does.
  Future<void> toSetupSlide(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Set up your terminal'), findsOneWidget);
  }

  Finder posNameField() => find.widgetWithText(TextField, 'Device name');

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
    final checked = <String>[];
    final c = await pump(tester, width: 400, checkedNames: checked);
    await toSetupSlide(tester);

    // The picker OPENS on Light. That is the app's default now — it is what
    // these slides and the master login render in, before any company settings
    // have synced — so there is nothing to change by tapping Light first.
    expect(c.read(deviceThemeModeProvider), isNull);

    // Theme choice applies live via the device override. The round trip goes
    // through Dark on purpose: a single-selection SegmentedButton reports a
    // CHANGE, so tapping the already-selected segment fires nothing and an
    // assertion on it would pass without the picker being wired up at all.
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(c.read(deviceThemeModeProvider), 'dark');

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(c.read(deviceThemeModeProvider), 'light');

    await tester.enterText(posNameField(), 'POS7');
    await tester.pump();

    // Through the layout slide, then on to the activity slide (the last page).
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text("What's your business?"), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // The name was checked with the server, then — and only then — stored.
    expect(checked, ['POS7']);
    expect(await getDeviceName(), 'POS7');

    // Picking "Shop" switches tables + booking off in the seed.
    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    expect(c.read(onboardingFeatureSeedProvider).tables, isFalse);
    expect(c.read(onboardingFeatureSeedProvider).booking, isFalse);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(c.read(onboardingCompleteProvider), isTrue);
  });

  testWidgets('Setup refuses a POS name another terminal already uses',
      (tester) async {
    await pump(tester, width: 400, nameCheck: DeviceNameCheck.taken);
    await toSetupSlide(tester);

    await tester.enterText(posNameField(), 'POS1');
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Set up your terminal'), findsOneWidget);
    expect(
      find.textContaining('POS1 is already used by another terminal'),
      findsOneWidget,
    );
    // Refused names are never stored: they would become this till's
    // document-number prefix.
    expect(await getDeviceName(), isEmpty);
  });

  testWidgets('Setup refuses a POS name it cannot verify', (tester) async {
    await pump(tester, width: 400, nameCheck: DeviceNameCheck.unverified);
    await toSetupSlide(tester);

    await tester.enterText(posNameField(), 'POS3');
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Set up your terminal'), findsOneWidget);
    expect(find.textContaining("Couldn't check this name"), findsOneWidget);
    expect(await getDeviceName(), isEmpty);
  });

  testWidgets('Setup requires a POS name', (tester) async {
    final checked = <String>[];
    await pump(tester, width: 400, checkedNames: checked);
    await toSetupSlide(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Set up your terminal'), findsOneWidget);
    expect(find.text('Enter a name for this terminal.'), findsOneWidget);
    expect(checked, isEmpty);
  });

  testWidgets('Setup cannot be swiped past without the name check',
      (tester) async {
    await pump(tester, width: 400);
    await toSetupSlide(tester);

    await tester.enterText(posNameField(), 'POS7');
    await tester.pump();
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Set up your terminal'), findsOneWidget);
    expect(await getDeviceName(), isEmpty);
  });
}
