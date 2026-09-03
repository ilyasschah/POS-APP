import 'package:flutter/widgets.dart';

/// The languages the KDS actually ships strings for.
///
/// Order here is the order the picker shows them in. It is deliberately NOT
/// the order `supportedLocales` comes out in — see [resolveKdsLocale].
const kKdsLanguages = <String>['en', 'fr', 'ar'];

/// The default. English, explicitly, and not "whatever is first".
const kKdsFallbackLanguage = 'en';

/// Maps a stored language code onto a locale the app can actually render.
///
/// 🚨 **Do not delete this as redundant — it is a guard, not a convenience.**
/// gen-l10n emits `supportedLocales` ALPHABETICALLY, so the first entry is
/// `ar`. Flutter falls back to `supportedLocales.first` for anything it cannot
/// resolve, which means a stale or empty stored value renders the entire
/// kitchen display in Arabic rather than English. The POS learned this the hard
/// way and carries the same guard in `lib/l10n/app_locale.dart`; the KDS reads
/// its language from a preference written on a touchscreen in a kitchen, so it
/// is, if anything, more exposed.
///
/// Anything unknown — null, empty, `de`, a region-tagged `en_GB` — comes back
/// as [kKdsFallbackLanguage].
Locale resolveKdsLocale(String? code) {
  final normalized = (code ?? '').trim().toLowerCase();
  // Accept `ar_MA` / `ar-MA` by taking the language subtag only; the KDS has no
  // regional variants and matching on the full tag would drop to the fallback.
  final language =
      normalized.isEmpty ? '' : normalized.split(RegExp('[_-]')).first;
  return Locale(
    kKdsLanguages.contains(language) ? language : kKdsFallbackLanguage,
  );
}
