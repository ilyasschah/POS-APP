import 'package:flutter/material.dart';

/// The house dropdown — **the** control for picking one of a handful of
/// options anywhere in the app. (Searchable pickers — customers, products in
/// the cart — keep their own dialogs.)
///
/// Built on Material 3's [DropdownMenuFormField], not the legacy
/// `DropdownButton`, for the two things the old one could not do:
///
///  * **The menu opens BELOW the field** (above only when there is no room
///    below), instead of being laid over it with the current choice on top —
///    which hid the very field being changed.
///  * **It wears the app's theme**: a rounded field like every other input, a
///    rounded, elevated menu on the surface colour, the current choice tinted
///    in the accent with a check mark, and the field's border turning accent
///    while its menu is open.
///
/// Select-only: no typing, no search, and no keyboard popping up on a tablet.
///
/// 🚨 E2E helpers read [items] off this widget and the selection off its text
/// field (`integration_test/support/e2e_support.dart`). Never look for an
/// option's TEXT inside it: [DropdownMenu] keeps an invisible, measuring copy
/// of every option in its subtree, so every label is always "inside" it.
class IlyassDropdown<T> extends StatelessWidget {
  const IlyassDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.label,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.validator,
    this.enabled = true,
    this.dense = false,
    this.expand = true,
    this.width,
    this.menuMaxHeight = 360,
    this.textStyle,
    this.hasError = false,
  });

  /// The options, in menu order. Values must be unique.
  final List<IlyassDropdownItem<T>> items;

  /// The selected value. A null-valued item (a "None" placeholder) is shown
  /// like any other; with no matching item the field shows [hint].
  final T? value;

  /// Null makes the dropdown read-only, like [enabled] false.
  final ValueChanged<T?>? onChanged;

  /// The floating label inside the field. Omit it where a section title
  /// above the field already names it.
  final String? label;
  final String? hint;
  final String? helperText;
  final IconData? prefixIcon;
  final FormFieldValidator<T>? validator;
  final bool enabled;

  /// Tighter padding, for filter bars, table rows and settings rows.
  final bool dense;

  /// Fill the width the parent gives. False sizes the field to [width] (or to
  /// its widest option) — required inside a Row that does not bound it.
  final bool expand;
  final double? width;
  final double menuMaxHeight;
  final TextStyle? textStyle;

  /// Draws the field's border in the error colour without an error message —
  /// "this still needs choosing".
  final bool hasError;

  /// Adapts a legacy `DropdownMenuItem` list whose children are [Text]s: the
  /// label is the text. For the few screen-local wrappers that still take
  /// `DropdownMenuItem`s from their callers.
  static List<IlyassDropdownItem<V>> fromMenuItems<V>(
    List<DropdownMenuItem<V>> items,
  ) => [
    for (final item in items)
      IlyassDropdownItem<V>(
        value: item.value as V,
        label: switch (item.child) {
          final Text text when text.data != null => text.data!,
          _ => '${item.value}',
        },
        enabled: item.enabled,
      ),
  ];

  String get _selectedLabel =>
      items
          .where((i) => !i.header && i.value == value)
          .firstOrNull
          ?.label ??
      '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final interactive = enabled && onChanged != null;
    final selectedLabel = _selectedLabel;

    return DropdownMenuFormField<T>(
      // The form field seeds itself from its initial value ONCE. Keying it on
      // the value — and on the label, for a list that loads after the value
      // was set — re-seeds it whenever either changes, so a parent that sets
      // the value in code (a unit that forces a weight, a list that arrives
      // late) is always reflected.
      key: ValueKey<(Object?, String)>((value, selectedLabel)),
      initialSelection: value,
      dropdownMenuEntries: [
        for (final item in items) _entry(theme, item),
      ],
      onSelected: interactive ? onChanged : null,
      enabled: interactive,
      validator: validator,
      label: label == null ? null : Text(label!),
      hintText: hint,
      helperText: helperText,
      leadingIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
      trailingIcon: const Icon(Icons.keyboard_arrow_down_rounded),
      selectedTrailingIcon: Icon(
        Icons.keyboard_arrow_up_rounded,
        color: cs.primary,
      ),
      textStyle: textStyle,
      // A picker, not a text box: no typing, no filtering, no keyboard.
      selectOnly: true,
      enableSearch: false,
      enableFilter: false,
      requestFocusOnTap: false,
      expandedInsets: expand ? EdgeInsets.zero : null,
      width: expand ? null : width,
      menuHeight: menuMaxHeight,
      // A hair of air between the field and the menu that drops below it.
      alignmentOffset: const Offset(0, 6),
      menuStyle: ilyassMenuStyle(cs),
      decorationBuilder: (context, menu) => _decoration(cs, open: menu.isOpen),
    );
  }

  InputDecoration _decoration(ColorScheme cs, {required bool open}) {
    OutlineInputBorder border(Color colour, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colour, width: width),
        );
    final idle = hasError ? cs.error : cs.outline.withValues(alpha: 0.6);
    return InputDecoration(
      // 🚨 Set here, not only as `leadingIcon`: [DropdownMenu] moves its
      // leading icon into the decoration only when it builds the decoration
      // itself. With a decorationBuilder the icon is ours to place, or it is
      // silently dropped.
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
      filled: true,
      fillColor: cs.surface,
      isDense: dense,
      contentPadding: dense
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : null,
      border: border(idle),
      // The field "lights up" in the accent while its menu is open, so it is
      // obvious which field the menu below belongs to.
      enabledBorder: open ? border(cs.primary, 2) : border(idle),
      focusedBorder: border(cs.primary, 2),
      disabledBorder: border(cs.outline.withValues(alpha: 0.25)),
      errorBorder: border(cs.error),
      focusedErrorBorder: border(cs.error, 2),
    );
  }

  DropdownMenuEntry<T> _entry(ThemeData theme, IlyassDropdownItem<T> item) {
    final cs = theme.colorScheme;
    if (item.header) {
      // A section title inside the menu — never selectable, and set apart
      // like the section headers on the editor cards.
      return DropdownMenuEntry<T>(
        value: item.value,
        label: item.label,
        enabled: false,
        labelWidget: Text(
          item.label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        style: const ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(0, 32)),
          padding: WidgetStatePropertyAll(EdgeInsets.fromLTRB(12, 10, 12, 2)),
        ),
      );
    }

    final selected = item.value == value;
    return DropdownMenuEntry<T>(
      value: item.value,
      label: item.label,
      enabled: item.enabled,
      labelWidget: Text(
        item.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leadingIcon: item.icon == null ? null : Icon(item.icon, size: 18),
      trailingIcon: selected
          ? Icon(Icons.check_rounded, size: 18, color: cs.primary)
          : null,
      style: _entryStyle(theme, selected: selected),
    );
  }

  static ButtonStyle _entryStyle(ThemeData theme, {required bool selected}) {
    final cs = theme.colorScheme;
    Color foreground(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return cs.onSurface.withValues(alpha: 0.38);
      }
      return selected ? cs.primary : cs.onSurface;
    }

    return ButtonStyle(
      // Finger-sized: this is a touch till before it is a desktop.
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      backgroundColor: WidgetStatePropertyAll<Color?>(
        selected ? cs.primary.withValues(alpha: 0.12) : null,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(foreground),
      iconColor: WidgetStateProperty.resolveWith(foreground),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return cs.primary.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return cs.primary.withValues(alpha: 0.08);
        }
        return null;
      }),
      textStyle: WidgetStatePropertyAll(
        theme.textTheme.bodyLarge?.copyWith(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

/// One option of an [IlyassDropdown].
@immutable
class IlyassDropdownItem<T> {
  const IlyassDropdownItem({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
    this.header = false,
  });

  final T value;

  /// What the menu lists and the closed field shows. A closed Material 3
  /// dropdown is a text field, so the label is text by design.
  final String label;

  /// Shown before the label in the open menu.
  final IconData? icon;
  final bool enabled;

  /// A section title inside the menu (a unit category, say) — never
  /// selectable. Give it a value no real option uses.
  final bool header;
}

/// The menu surface every dropdown and menu in the app shares: rounded,
/// elevated, on the surface colour, with a hairline edge. Used by
/// [IlyassDropdown] and, through the theme, by plain [MenuAnchor]s.
MenuStyle ilyassMenuStyle(ColorScheme cs) => MenuStyle(
  backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
  // A soft lift, not a halo: a heavier shadow reads as a grey ring around
  // the menu on the light themes.
  elevation: const WidgetStatePropertyAll(3),
  shadowColor: WidgetStatePropertyAll(cs.shadow.withValues(alpha: 0.25)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
    ),
  ),
  padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
);
