import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';

/// Locale resolution for code that has **no `BuildContext`** — providers,
/// services, background work.
///
/// 🚨 **Never call `lookupAppLocalizations` on a raw setting value.** Flutter
/// falls back to `supportedLocales.first`, and gen-l10n emits that list
/// **alphabetically**, so the first entry is **`ar`** — a stale `es`/`de`
/// value (the Settings dropdown offers both, and neither has an `.arb`) would
/// silently render Arabic instead of English. [resolveAppLocale] is that
/// guard; `MyApp` applies the same mapping before `MaterialApp` ever sees the
/// locale, and `test/l10n_test.dart` pins it.
///
/// Prefer `AppLocalizations.of(context)` wherever a context exists — this
/// exists only for the places that genuinely cannot reach one.
Locale resolveAppLocale(String? code) {
  final lang = (code ?? 'en').toLowerCase().split(RegExp('[-_]')).first;
  return AppLocalizations.supportedLocales.any((l) => l.languageCode == lang)
      ? Locale(lang)
      : const Locale('en');
}

/// Localized strings for a provider, resolved from the `Application.Language`
/// setting through [resolveAppLocale].
///
/// Uses `ref.watch`, so a provider calling this rebuilds when the operator
/// changes the language — the strings it produces do not go stale.
AppLocalizations l10nOf(Ref ref) => lookupAppLocalizations(
      resolveAppLocale(ref.watch(appSettingsProvider)[SettingKeys.language]),
    );
