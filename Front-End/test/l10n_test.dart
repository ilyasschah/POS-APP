// Pins the localization wiring. The realistic regression as strings are
// extracted screen-by-screen is a key that exists in app_en.arb but was never
// added to app_fr.arb / app_ar.arb — gen-l10n fills the gap with the ENGLISH
// text rather than failing, so a half-translated build looks fine to the
// analyzer and to every other test in this repo. These assert the translated
// value, not just "a string came back".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('ships exactly the locales the app claims to support',
      (tester) async {
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

  testWidgets('French is actually translated, not falling back to English',
      (tester) async {
    final l10n = await load(tester, 'fr');
    expect(l10n.actionCancel, 'Annuler');
    expect(l10n.deviceRegistrationTitle, "Enregistrement de l'appareil");
    expect(l10n.fieldPassword, 'Mot de passe');
  });

  testWidgets('Arabic is actually translated, not falling back to English',
      (tester) async {
    final l10n = await load(tester, 'ar');
    expect(l10n.actionCancel, 'إلغاء');
    expect(l10n.deviceRegistrationTitle, 'تسجيل الجهاز');
    expect(l10n.fieldPassword, 'كلمة المرور');
  });

  testWidgets(
      'TRAP: an unsupported locale resolves to Arabic, not English — '
      'which is why MyApp._resolveLocale must map es/de/it itself',
      (tester) async {
    // The Settings dropdown now offers only en/fr/ar, but companies seeded
    // before that trim can still hold es/de/it/pt in Application.Language —
    // the stored value is untouched, only the picker shrank.
    //
    // Flutter's default resolution falls back to supportedLocales.FIRST, and
    // gen-l10n emits that list alphabetically — so 'ar' is first, and a legacy
    // code would silently render the whole app in Arabic. MyApp never hands
    // MaterialApp a raw setting value for exactly this reason; it maps
    // anything unknown to English first.
    //
    // If this expectation ever flips to 'Cancel', Flutter changed its fallback
    // and the guard in main.dart can be reconsidered. Until then, deleting
    // that guard is a live bug.
    final l10n = await load(tester, 'es');
    expect(l10n.actionCancel, 'إلغاء');
  });
}
