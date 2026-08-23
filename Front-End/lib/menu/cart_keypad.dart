import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/l10n/app_localizations.dart';

/// What the digits type into.
enum CartKeypadMode {
  /// The selected line's quantity.
  quantity,

  /// The selected line's unit price. Only for a product whose
  /// `isPriceChangeAllowed` is set.
  price,
}

/// The cart's numeric keypad — the single way a cashier edits a line.
///
/// It replaces the per-row `−/+` stepper and the `X`: a line is chosen by
/// tapping it, and everything after that happens here. One control instead of
/// three tiny targets per row is the whole point on a touch screen, and it is
/// how Odoo's POS behaves.
///
/// Layout, four columns:
///
///     1   2   3   Qté
///     4   5   6   Prix
///     7   8   9   ⌫   (double height — it is the destructive key)
///     +/- 0   ,
///
/// Purely presentational: it reports key presses and never touches the cart.
/// The parent owns the typed entry and decides what each press means, which is
/// what keeps the security gate on deleting a line in one place.
class CartKeypad extends StatelessWidget {
  const CartKeypad({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.onDigit,
    required this.onSignToggle,
    required this.onBackspace,
    required this.hasSelection,
    required this.priceChangeAllowed,
    this.keyHeight = 52,
  });

  final CartKeypadMode mode;
  final ValueChanged<CartKeypadMode> onModeChanged;

  /// A digit, or the decimal separator.
  final ValueChanged<String> onDigit;

  final VoidCallback onSignToggle;

  /// Erase the last typed character, or — with nothing typed — remove the line.
  final VoidCallback onBackspace;

  /// False when no cart line is selected: the whole pad greys out, because
  /// every key here acts on a line.
  final bool hasSelection;

  /// Gates the **Prix** key. A product the cashier may not reprice keeps the
  /// key visible but dead, so the rule is legible rather than invisible.
  final bool priceChangeAllowed;

  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The locale's own decimal separator — "," in French, "." in English.
    // Typing the wrong one is a wrong price, so it is read from the locale
    // rather than hardcoded. An unknown locale falls back to the dot the
    // parser accepts anyway.
    String decimal;
    try {
      decimal = NumberFormat.decimalPattern(
        Localizations.localeOf(context).toLanguageTag(),
      ).symbols.DECIMAL_SEP;
    } catch (_) {
      decimal = '.';
    }
    if (decimal.isEmpty) decimal = '.';

    Widget digit(String value) => _KeypadKey(
          label: value,
          height: keyHeight,
          enabled: hasSelection,
          onTap: () => onDigit(value),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── digits ──────────────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [digit('1'), digit('2'), digit('3')]),
                  Row(children: [digit('4'), digit('5'), digit('6')]),
                  Row(children: [digit('7'), digit('8'), digit('9')]),
                  Row(
                    children: [
                      _KeypadKey(
                        label: '+/-',
                        height: keyHeight,
                        enabled: hasSelection,
                        tint: context.warningColor,
                        onTap: onSignToggle,
                      ),
                      digit('0'),
                      digit(decimal),
                    ],
                  ),
                ],
              ),
            ),
            // ── modes + delete ──────────────────────────────────────────────
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _KeypadKey(
                        label: l.fieldQuantity,
                        height: keyHeight,
                        enabled: hasSelection,
                        selected: mode == CartKeypadMode.quantity,
                        onTap: () => onModeChanged(CartKeypadMode.quantity),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _KeypadKey(
                        label: l.priceLabel,
                        height: keyHeight,
                        // Dead, not hidden: "you cannot change this price" is
                        // information the cashier needs at the moment they try.
                        enabled: hasSelection && priceChangeAllowed,
                        selected: mode == CartKeypadMode.price,
                        onTap: () => onModeChanged(CartKeypadMode.price),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _KeypadKey(
                        icon: Icons.backspace_outlined,
                        // Twice the height: it is the key that empties a line,
                        // and it is the one an operator reaches for in a hurry.
                        height: keyHeight * 2,
                        enabled: hasSelection,
                        tint: context.dangerColor,
                        onTap: onBackspace,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({
    this.label,
    this.icon,
    required this.height,
    required this.enabled,
    required this.onTap,
    this.selected = false,
    this.tint,
  });

  final String? label;
  final IconData? icon;
  final double height;
  final bool enabled;
  final bool selected;
  final Color? tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = tint ?? cs.primary;

    final Color background;
    final Color foreground;
    if (!enabled) {
      background = cs.surfaceContainerHighest.withValues(alpha: 0.35);
      foreground = cs.onSurface.withValues(alpha: 0.28);
    } else if (selected) {
      background = accent.withValues(alpha: 0.16);
      foreground = accent;
    } else if (tint != null) {
      background = accent.withValues(alpha: 0.12);
      foreground = accent;
    } else {
      background = cs.surfaceContainerHighest.withValues(alpha: 0.6);
      foreground = cs.onSurface;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Container(
              height: height,
              alignment: Alignment.center,
              decoration: selected
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                    )
                  : null,
              child: icon != null
                  ? Icon(icon, size: 22, color: foreground)
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          label ?? '',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.w600,
                            color: foreground,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
