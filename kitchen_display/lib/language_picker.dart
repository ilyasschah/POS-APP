import 'package:flutter/material.dart';

import 'kds_locale.dart';
import 'l10n/kds_localizations.dart';

/// The language control, in the one shape both KDS screens use.
///
/// A bottom sheet rather than a `PopupMenuButton`: this is a wall-mounted
/// touchscreen in a kitchen, often reached at arm's length with wet or gloved
/// hands, and a popup anchored to a 24px icon puts three 32px-tall rows in the
/// top corner. The sheet gives each language a full-width 56px row at the
/// bottom of the screen, where a hand already is.
class LanguageButton extends StatelessWidget {
  const LanguageButton({
    super.key,
    required this.onLanguageChanged,
    this.color,
  });

  final Future<void> Function(String code) onLanguageChanged;

  /// Set on the kitchen screen, whose app bar is the dark brand colour. Null
  /// takes the theme's own icon colour, which is what the light onboarding
  /// screen wants.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l = KdsLocalizations.of(context);
    return IconButton(
      icon: const Icon(Icons.translate),
      color: color,
      tooltip: l.language,
      iconSize: 26,
      onPressed: () => showLanguageSheet(context, onLanguageChanged),
    );
  }
}

/// Shows the picker. Separate from the button so the onboarding screen can
/// trigger it from its own layout without borrowing an app bar.
Future<void> showLanguageSheet(
  BuildContext context,
  Future<void> Function(String code) onLanguageChanged,
) {
  final l = KdsLocalizations.of(context);
  final current = Localizations.localeOf(context).languageCode;

  // Each language is NAMED IN ITSELF — "Français", "العربية" — and never
  // translated into the language currently showing. Someone who cannot read
  // the current language is exactly the person using this menu, so a list of
  // names they cannot read is a list they cannot escape from.
  final labels = <String, String>{
    'en': l.languageEnglish,
    'fr': l.languageFrench,
    'ar': l.languageArabic,
  };

  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.translate),
                const SizedBox(width: 12),
                Text(l.language,
                    style: Theme.of(ctx).textTheme.titleMedium),
              ],
            ),
          ),
          for (final code in kKdsLanguages)
            ListTile(
              minVerticalPadding: 12,
              title: Text(
                labels[code] ?? code,
                // The name is written in its OWN script, so it needs its own
                // direction — "العربية" in a left-to-right row is fine, but a
                // name with mixed content is not.
                textDirection:
                    code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(fontSize: 18),
              ),
              trailing: code == current
                  ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                onLanguageChanged(code);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
