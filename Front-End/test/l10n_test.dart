// Pins the localization wiring. The realistic regression as strings are
// extracted screen-by-screen is a key that exists in app_en.arb but was never
// added to app_fr.arb / app_ar.arb — gen-l10n fills the gap with the ENGLISH
// text rather than failing, so a half-translated build looks fine to the
// analyzer and to every other test in this repo. These assert the translated
// value, not just "a string came back".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/l10n/app_locale.dart';
import 'package:pos_app/l10n/app_localizations.dart';

void main() {
  Future<AppLocalizations> load(WidgetTester tester, String code) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('ships exactly the locales the app claims to support', (
    tester,
  ) async {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      {'en', 'fr', 'ar'},
    );
  });

  testWidgets('English resolves', (tester) async {
    final l10n = await load(tester, 'en');
    expect(l10n.actionCancel, 'Cancel');
    expect(l10n.deviceRegistrationTitle, 'Device Registration');
  });

  testWidgets('French is actually translated, not falling back to English', (
    tester,
  ) async {
    final l10n = await load(tester, 'fr');
    expect(l10n.actionCancel, 'Annuler');
    expect(l10n.deviceRegistrationTitle, "Enregistrement de l'appareil");
    expect(l10n.fieldPassword, 'Mot de passe');
  });

  testWidgets('Arabic is actually translated, not falling back to English', (
    tester,
  ) async {
    final l10n = await load(tester, 'ar');
    expect(l10n.actionCancel, 'إلغاء');
    expect(l10n.deviceRegistrationTitle, 'تسجيل الجهاز');
    expect(l10n.fieldPassword, 'كلمة المرور');
  });

  testWidgets('TRAP: an unsupported locale resolves to Arabic, not English — '
      'which is why resolveAppLocale must map es/de/it itself', (tester) async {
    // The Settings dropdown now offers only en/fr/ar, but companies seeded
    // before that trim can still hold es/de/it/pt in Application.Language —
    // the stored value is untouched, only the picker shrank.
    //
    // Flutter's default resolution falls back to supportedLocales.FIRST, and
    // gen-l10n emits that list alphabetically — so 'ar' is first, and a legacy
    // code would silently render the whole app in Arabic. Nothing hands
    // MaterialApp (or lookupAppLocalizations) a raw setting value for exactly
    // this reason; resolveAppLocale maps anything unknown to English first.
    //
    // If this expectation ever flips to 'Cancel', Flutter changed its fallback
    // and the guard can be reconsidered. Until then, deleting it is a live bug.
    final l10n = await load(tester, 'es');
    expect(l10n.actionCancel, 'إلغاء');
  });

  group('resolveAppLocale — the guard the trap above requires', () {
    test(
      'maps every unshipped code to English, never to supportedLocales.first',
      () {
        // es/de/it were offered by the Settings dropdown for months, so these
        // are real stored values, not hypotheticals.
        for (final code in ['es', 'de', 'it', 'pt', 'zh', 'xx', '']) {
          expect(
            resolveAppLocale(code),
            const Locale('en'),
            reason: 'for "$code"',
          );
        }
      },
    );

    test('a null/absent setting is English', () {
      expect(resolveAppLocale(null), const Locale('en'));
    });

    test('passes through the locales we actually ship', () {
      expect(resolveAppLocale('en'), const Locale('en'));
      expect(resolveAppLocale('fr'), const Locale('fr'));
      expect(resolveAppLocale('ar'), const Locale('ar'));
    });

    test('normalizes case and strips a region/script suffix', () {
      // A value like fr_FR or AR-MA must still resolve — it names a locale we
      // ship, and dropping it to English would be a silent downgrade.
      expect(resolveAppLocale('FR'), const Locale('fr'));
      expect(resolveAppLocale('fr_FR'), const Locale('fr'));
      expect(resolveAppLocale('ar-MA'), const Locale('ar'));
      expect(resolveAppLocale('en_US'), const Locale('en'));
    });

    test('every resolved locale is one lookupAppLocalizations accepts', () {
      // The point of the guard: its output is always safe to hand straight to
      // the generated lookup from a provider, with no BuildContext in sight.
      for (final code in ['en', 'fr', 'ar', 'es', 'xx', null]) {
        expect(
          AppLocalizations.supportedLocales.contains(resolveAppLocale(code)),
          isTrue,
          reason: 'for "$code"',
        );
      }
    });
  });
}
