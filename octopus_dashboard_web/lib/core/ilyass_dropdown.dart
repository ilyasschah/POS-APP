import 'package:flutter/material.dart';

import 'theme.dart';
import 'typography.dart';

/// The house dropdown — **the** control for picking one of a set of options —
/// ported from the POS (`Front-End/lib/core/ilyass_dropdown.dart`) onto the
/// dashboard's palette and Nunito type.
///
/// Built on Material 3's [DropdownMenuFormField] for the two things the legacy
/// `DropdownButton` could not do:
///
///  * **The menu opens BELOW the field** (above only when there is no room),
///    instead of being laid over the field it changes.
///  * **It wears the theme**: a rounded filled field like every other input, a
///    rounded opaque menu, the current choice tinted in the accent with a
///    check, and the field's border lighting up while its menu is open.
///
/// Select-only by default — no typing and no keyboard popping up on a tablet.
/// [searchable] turns on type-to-filter for the long lists (products,
/// customers), where scrolling a hundred rows by finger is the slower path.
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
    this.enabled = true,
    this.searchable = false,
    this.hasError = false,
    this.menuMaxHeight = 360,
  });

  /// The options, in menu order. Values must be unique.
  final List<IlyassDropdownItem<T>> items;

  /// The selected value; with no matching item the field shows [hint].
  final T? value;

  /// Null makes the dropdown read-only, like [enabled] false.
  final ValueChanged<T?>? onChanged;

  final String? label;
  final String? hint;
  final String? helperText;
  final IconData? prefixIcon;
  final bool enabled;

  /// Type to filter the menu. Off for short lists: filtering a list of four
  /// only summons a keyboard.
  final bool searchable;

  /// Draws the border in the error colour without a message — "this still
  /// needs choosing".
  final bool hasError;
  final double menuMaxHeight;

  String get _selectedLabel =>
      items.where((i) => i.value == value).firstOrNull?.label ?? '';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final interactive = enabled && onChanged != null;
    final selectedLabel = _selectedLabel;

    return DropdownMenuFormField<T>(
      // The form field seeds itself from its initial value ONCE. Keying it on
      // the value and its label re-seeds it whenever either changes, so a
      // parent that sets the value in code — or a list that arrives after the
      // value — is always reflected.
      key: ValueKey<(Object?, String)>((value, selectedLabel)),
      initialSelection: value,
      dropdownMenuEntries: [for (final item in items) _entry(context, item)],
      onSelected: interactive ? onChanged : null,
      enabled: interactive,
      label: label == null ? null : Text(label!),
      hintText: hint,
      helperText: helperText,
      trailingIcon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: palette.dim(0.6),
      ),
      selectedTrailingIcon: Icon(
        Icons.keyboard_arrow_up_rounded,
        color: palette.accent,
      ),
      textStyle: AppText.body(palette.primaryText),
      selectOnly: !searchable,
      enableSearch: searchable,
      enableFilter: searchable,
      requestFocusOnTap: searchable,
      expandedInsets: EdgeInsets.zero,
      menuHeight: menuMaxHeight,
      alignmentOffset: const Offset(0, 6),
      menuStyle: ilyassMenuStyle(context),
      decorationBuilder: (context, menu) =>
          _decoration(context, open: menu.isOpen),
    );
  }

  InputDecoration _decoration(BuildContext context, {required bool open}) {
    final palette = context.palette;
    OutlineInputBorder border(Color colour, [double width = 1.5]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.controlRadius),
          borderSide: BorderSide(color: colour, width: width),
        );
    final idle = hasError
        ? palette.negative
        : palette.primaryText.withValues(alpha: 0.12);
    return InputDecoration(
      // 🚨 Set here, not only as `leadingIcon`: with a decorationBuilder the
      // icon is ours to place, or [DropdownMenu] silently drops it.
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, size: 20, color: palette.dim(0.6)),
      labelStyle: AppText.label(palette.dim(0.7)),
      floatingLabelStyle: AppText.label(open ? palette.accent : palette.dim(0.8)),
      helperStyle: AppText.caption(palette.dim(0.6)),
      border: border(idle),
      // The field lights up in the accent while its menu is open, so it is
      // obvious which field the menu below belongs to.
      enabledBorder: open ? border(palette.accent, 2) : border(idle),
      focusedBorder: border(palette.accent, 2),
      disabledBorder: border(palette.primaryText.withValues(alpha: 0.06)),
      errorBorder: border(palette.negative),
      focusedErrorBorder: border(palette.negative, 2),
    );
  }

  DropdownMenuEntry<T> _entry(BuildContext context, IlyassDropdownItem<T> item) {
    final palette = context.palette;
    final selected = item.value == value;
    return DropdownMenuEntry<T>(
      value: item.value,
      label: item.label,
      enabled: item.enabled,
      labelWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (item.caption != null)
            Text(
              item.caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(palette.dim(0.6)),
            ),
        ],
      ),
      leadingIcon: item.icon == null ? null : Icon(item.icon, size: 18),
      trailingIcon: selected
          ? Icon(Icons.check_rounded, size: 18, color: palette.accent)
          : null,
      style: _entryStyle(context, selected: selected),
    );
  }

  static ButtonStyle _entryStyle(
    BuildContext context, {
    required bool selected,
  }) {
    final palette = context.palette;
    Color foreground(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return palette.dim(0.35);
      return selected ? palette.accent : palette.primaryText;
    }

    return ButtonStyle(
      // Finger-sized: this dashboard is used on tablets as often as desktops.
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      backgroundColor: WidgetStatePropertyAll<Color?>(
        selected ? palette.accent.withValues(alpha: 0.12) : null,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(foreground),
      iconColor: WidgetStateProperty.resolveWith(foreground),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return palette.accent.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return palette.accent.withValues(alpha: 0.08);
        }
        return null;
      }),
      textStyle: WidgetStatePropertyAll(
        AppText.style(size: 15, weight: selected ? 700 : 500),
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
    this.caption,
    this.icon,
    this.enabled = true,
  });

  final T value;

  /// What the menu lists and the closed field shows — and what a searchable
  /// dropdown filters on.
  final String label;

  /// A quieter second line in the open menu: a product code, a tax rate.
  final String? caption;

  final IconData? icon;
  final bool enabled;
}

/// The menu surface every dropdown shares: rounded, lifted, and OPAQUE — a
/// translucent menu over glass cards reads as the card behind it.
MenuStyle ilyassMenuStyle(BuildContext context) {
  final palette = context.palette;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(
      Color.alphaBlend(
        palette.primaryText.withValues(alpha: isDark ? 0.12 : 0.03),
        palette.base,
      ),
    ),
    elevation: const WidgetStatePropertyAll(6),
    shadowColor: WidgetStatePropertyAll(
      palette.primaryText.withValues(alpha: isDark ? 0.0 : 0.25),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        side: BorderSide(color: palette.primaryText.withValues(alpha: 0.14)),
      ),
    ),
    padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
  );
}
