import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_dashboard_web/core/constants.dart';
import 'package:octopus_dashboard_web/core/settings.dart';
import 'package:octopus_dashboard_web/core/theme.dart';
import 'package:octopus_dashboard_web/features/auth/auth_controller.dart';
import 'package:octopus_dashboard_web/features/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

Future<ProviderContainer> _container({Object? failWith}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      apiFactoryProvider.overrideWithValue(
        ({
          required String baseUrl,
          String? token,
          int? companyId,
          onTokenExpired,
        }) => FakeApi(failWith: failWith),
      ),
    ],
  );
}

Future<void> _pumpLogin(
  WidgetTester tester,
  ProviderContainer scope, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(scope.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: scope,
      child: MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: const LoginScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the branding and an empty email on a fresh browser', (
    tester,
  ) async {
    await _pumpLogin(tester, await _container());

    expect(find.text('Octopus Owner'), findsOneWidget);
    expect(find.text('Business Dashboard'), findsOneWidget);
    // 🚨 Empty, not a hardcoded address. The field used to arrive pre-filled
    // with a developer's own account, so typing only a password signed you into
    // somebody else's company.
    expect(find.text('ilyasschah18@gmail.com'), findsNothing);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('pre-fills the address of the last successful sign-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.lastEmail: 'owner@shop.ma',
    });
    final prefs = await SharedPreferences.getInstance();
    final scope = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiFactoryProvider.overrideWithValue(
          ({
            required String baseUrl,
            String? token,
            int? companyId,
            onTokenExpired,
          }) => FakeApi(),
        ),
      ],
    );
    await _pumpLogin(tester, scope);

    expect(find.text('owner@shop.ma'), findsOneWidget);
  });

  testWidgets('a restored token with no company is not a session', (
    tester,
  ) async {
    // The exact shape of the bug: the token outlived the company it belonged
    // to, and the app came back up "signed in" and scoped to the wrong tenant.
    SharedPreferences.setMockInitialValues({PrefKeys.apiToken: 'stale-token'});
    final prefs = await SharedPreferences.getInstance();
    final scope = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiFactoryProvider.overrideWithValue(
          ({
            required String baseUrl,
            String? token,
            int? companyId,
            onTokenExpired,
          }) => FakeApi(),
        ),
      ],
    );
    addTearDown(scope.dispose);

    expect(scope.read(authProvider).isAuthenticated, isFalse);
    expect(scope.read(authProvider).token, isNull);
  });

  testWidgets('signing in adopts the company from the login response', (
    tester,
  ) async {
    final scope = await _container();
    addTearDown(scope.dispose);

    final ok = await scope.read(authProvider.notifier).login('pw');

    expect(ok, isTrue);
    // FakeApi answers with company 7 — never the old hardcoded 25.
    expect(scope.read(authProvider).companyId, 7);
    expect(scope.read(authProvider).isAuthenticated, isTrue);
  });

  testWidgets('defaults to the Test environment, not the stale Dev IP', (
    tester,
  ) async {
    final scope = await _container();
    await _pumpLogin(tester, scope);

    expect(scope.read(authProvider).baseUrl, AppConfig.testBaseUrl);
    expect(find.text(AppConfig.testBaseUrl), findsOneWidget);
  });

  testWidgets('picking an environment overwrites the API Base URL field', (
    tester,
  ) async {
    final scope = await _container();
    await _pumpLogin(tester, scope);

    await tester.tap(find.text('Dev'));
    await tester.pumpAndSettle();

    expect(scope.read(authProvider).baseUrl, AppConfig.devBaseUrl);
    expect(find.text(AppConfig.devBaseUrl), findsOneWidget);

    await tester.tap(find.text('Test'));
    await tester.pumpAndSettle();
    expect(scope.read(authProvider).baseUrl, AppConfig.testBaseUrl);
  });

  testWidgets('password visibility can be toggled', (tester) async {
    await _pumpLogin(tester, await _container());

    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
  });

  testWidgets('a successful sign-in stores the token', (tester) async {
    final scope = await _container();
    await _pumpLogin(tester, scope);

    await tester.enterText(find.byType(TextField).last, 'Admin@123');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(scope.read(authProvider).isAuthenticated, isTrue);
    expect(scope.read(authProvider).token, 'test-token');
  });

  testWidgets('a failed sign-in shows an inline error and stays put', (
    tester,
  ) async {
    final scope = await _container(failWith: Exception('nope'));
    await _pumpLogin(tester, scope);

    await tester.enterText(find.byType(TextField).last, 'wrong');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(scope.read(authProvider).isAuthenticated, isFalse);
    expect(scope.read(authProvider).errorMessage, isNotNull);
    // Still on the login screen.
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('the login card stays narrow on a wide desktop viewport', (
    tester,
  ) async {
    await _pumpLogin(tester, await _container(), size: const Size(1920, 1080));

    // The form must not stretch across a 1920px monitor.
    final card = tester.getSize(
      find
          .ancestor(
            of: find.text('Octopus Owner'),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(card.width, lessThanOrEqualTo(520));
    expect(tester.takeException(), isNull);
  });
}
