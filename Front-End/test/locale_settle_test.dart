// Reproduces the race that broke setup_catalog, and proves the fix handles it.
//
// The failure: the terminal renders the PIN screen in whatever language it had
// cached, then the company's `Application.Language` arrives with the
// post-sign-in sync and the app re-renders in another language. A run that read
// its translations once at sign-in then hunted for French labels on an English
// screen:
//
//   No dropdown labelled "Langue"
//     On screen now: ... | ENGLISH | Language | ...
//
// `waitForStableLocale` exists to close that window. These tests drive the same
// mid-run locale change against a real widget tree, with no device needed.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/l10n/app_localizations.dart';

import '../integration_test/support/e2e_support.dart';

void main() {
  /// An app that starts in [start] and flips to [then] after [after].
  ///
  /// Stands in for the sync arriving with the company's real language setting.
  Future<void> pumpFlippingApp(
    WidgetTester tester, {
    required String start,
    String? then,
    Duration after = const Duration(seconds: 2),
  }) async {
    await tester.pumpWidget(_FlippingApp(start: start, then: then, after: after));
    await tester.pump();
  }

  testWidgets('returns the locale the app settles on, not the first one it saw',
      (tester) async {
    await pumpFlippingApp(tester, start: 'fr', then: 'en');

    // Read once, the way the broken helper did.
    expect(l10nOf(tester).localeName, 'fr');

    final settled = await waitForStableLocale(tester);

    expect(
      settled,
      'en',
      reason: 'The whole point: the value read at sign-in is not the value the '
          'screen will be driven in.',
    );
    expect(l10nOf(tester).localeName, 'en');
  });

  testWidgets('returns immediately when the locale never moves', (tester) async {
    await pumpFlippingApp(tester, start: 'en');

    final started = DateTime.now();
    expect(await waitForStableLocale(tester), 'en');

    // A stable app must not pay the full timeout — three quiet polls is enough.
    expect(
      DateTime.now().difference(started),
      lessThan(const Duration(seconds: 10)),
      reason: 'A settled locale should cost three polls, not a timeout.',
    );
  });

  testWidgets('survives a flip that lands late', (tester) async {
    await pumpFlippingApp(
      tester,
      start: 'fr',
      then: 'ar',
      after: const Duration(seconds: 5),
    );

    expect(await waitForStableLocale(tester), 'ar');
  });
}

/// A minimal app whose locale changes once, mid-run.
class _FlippingApp extends StatefulWidget {
  const _FlippingApp({required this.start, this.then, required this.after});

  final String start;
  final String? then;
  final Duration after;

  @override
  State<_FlippingApp> createState() => _FlippingAppState();
}

class _FlippingAppState extends State<_FlippingApp> {
  late String _code = widget.start;

  @override
  void initState() {
    super.initState();
    if (widget.then != null) {
      Future.delayed(widget.after, () {
        if (mounted) setState(() => _code = widget.then!);
      });
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        locale: Locale(_code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // A Scaffold, because `l10nOf` reads the delegate from the first one.
        home: const Scaffold(body: SizedBox.shrink()),
      );
}
