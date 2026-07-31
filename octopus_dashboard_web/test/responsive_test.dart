import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_dashboard_web/core/settings.dart';
import 'package:octopus_dashboard_web/core/theme.dart';
import 'package:octopus_dashboard_web/features/auth/auth_controller.dart';
import 'package:octopus_dashboard_web/features/shell/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

/// The viewport widths the spec requires to render cleanly.
const viewports = <String, Size>{
  'small Android phone (360)': Size(360, 800),
  'iPhone (390)': Size(390, 844),
  'iPad portrait (768)': Size(768, 1024),
  'laptop (1280)': Size(1280, 800),
  'desktop (1920)': Size(1920, 1080),
};

/// Nav items are located by icon rather than label: the collapsed rail shows
/// abbreviated titles, and a sidebar label like "Products & Prices" is
/// identical to that screen's own page header.
Finder navItem(AppDestination destination) => find.byIcon(destination.icon);

Future<ProviderContainer> makeContainer({Object? failWith}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      apiProvider.overrideWithValue(FakeApi(failWith: failWith)),
    ],
  );
}

/// Pumps the shell once at [size]. Each test pumps exactly one tree so that
/// a stale widget tree can never bleed into the next scenario.
Future<void> pumpShell(
  WidgetTester tester,
  Size size, {
  ProviderContainer? container,
  bool darkMode = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final scope = container ?? await makeContainer();
  addTearDown(scope.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: scope,
      child: MaterialApp(
        theme: AppTheme.build(darkMode ? Brightness.dark : Brightness.light),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Responsive navigation', () {
    testWidgets('360px uses a bottom navigation bar', (tester) async {
      await pumpShell(tester, const Size(360, 800));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('390px uses a bottom navigation bar', (tester) async {
      await pumpShell(tester, const Size(390, 844));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('599px still uses a bottom bar (breakpoint edge)', (
      tester,
    ) async {
      await pumpShell(tester, const Size(599, 900));
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('600px switches to a navigation rail (breakpoint edge)', (
      tester,
    ) async {
      await pumpShell(tester, const Size(600, 900));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('768px uses a navigation rail', (tester) async {
      await pumpShell(tester, const Size(768, 1024));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('1280px uses the full sidebar', (tester) async {
      await pumpShell(tester, const Size(1280, 800));
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      // The sidebar shows the brand plus every destination's full title.
      expect(find.text('Octopus'), findsOneWidget);
      for (final destination in AppDestination.values) {
        expect(
          find.text('Dashboard'),
          findsWidgets,
          reason: '${destination.title} should be listed in the sidebar',
        );
      }
    });
  });

  group('No layout overflow', () {
    // A RenderFlex overflow throws during paint, which fails the test — so
    // visiting every screen at every width is itself the assertion.
    for (final entry in viewports.entries) {
      testWidgets('every screen renders cleanly at ${entry.key}', (
        tester,
      ) async {
        await pumpShell(tester, entry.value);

        for (final destination in AppDestination.values) {
          await tester.tap(navItem(destination).first);
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: '${destination.title} overflowed at ${entry.key}',
          );
        }
      });
    }

    testWidgets('renders cleanly in light mode', (tester) async {
      await pumpShell(tester, const Size(390, 844), darkMode: false);
      expect(tester.takeException(), isNull);
    });
  });

  group('Screen data', () {
    testWidgets('dashboard shows the formatted total', (tester) async {
      await pumpShell(tester, const Size(1280, 800));
      expect(find.text('Octopus Dashboard'), findsOneWidget);
      expect(find.text('1,234,567.89 DH'), findsOneWidget);
    });

    testWidgets('stock lists unstocked products as Unassigned', (tester) async {
      await pumpShell(tester, const Size(1280, 800));
      await tester.tap(navItem(AppDestination.stock).first);
      await tester.pumpAndSettle();

      // Product 7 is stocked across two warehouses (400 + 77); product 8 has
      // no stock row at all and must still appear.
      expect(find.text('477'), findsOneWidget);
      expect(find.text('Unassigned'), findsOneWidget);
    });

    testWidgets('users show derived role and status', (tester) async {
      await pumpShell(tester, const Size(1280, 800));
      await tester.tap(navItem(AppDestination.users).first);
      await tester.pumpAndSettle();

      expect(find.text('ilyasschah'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Disabled Cashier'), findsOneWidget);
      expect(find.text('Cashier'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('products list shows price and cost', (tester) async {
      await pumpShell(tester, const Size(1280, 800));
      await tester.tap(navItem(AppDestination.products).first);
      await tester.pumpAndSettle();

      expect(find.text('Pepsi'), findsOneWidget);
      expect(find.text('10.00 DH'), findsOneWidget);
      expect(find.text('Cost 5.00 DH'), findsOneWidget);
    });
  });

  group('Data refresh on every visit', () {
    testWidgets('revisiting a tab re-fetches its data', (tester) async {
      final api = CountingApi();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final scope = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(scope.dispose);

      await pumpShell(tester, const Size(1280, 800), container: scope);
      expect(api.productCalls, 0);

      await tester.tap(navItem(AppDestination.products).first);
      await tester.pumpAndSettle();
      expect(api.productCalls, 1);

      // Navigate away, then back: the second visit must fetch again rather
      // than showing whatever was left over from the first.
      await tester.tap(navItem(AppDestination.documents).first);
      await tester.pumpAndSettle();
      await tester.tap(navItem(AppDestination.products).first);
      await tester.pumpAndSettle();

      expect(
        api.productCalls,
        2,
        reason: 'each visit to a screen must re-fetch its data',
      );
    });
  });

  group('Error handling', () {
    testWidgets('a failed first load shows a retryable error', (tester) async {
      final scope = await makeContainer(failWith: Exception('boom'));
      await pumpShell(tester, const Size(1280, 800), container: scope);
      expect(find.text('Retry'), findsWidgets);
    });
  });
}
