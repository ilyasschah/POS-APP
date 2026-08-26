import 'package:flutter/material.dart';

import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/responsive.dart';
import 'package:pos_app/l10n/app_localizations.dart';

/// The house shape for a management list screen, extracted from the Products
/// screen once six more screens were asked to look like it.
///
/// The rules it encodes, so no screen has to re-derive them:
///
///  * The search bar lives in the HEADER, not stacked above the table. A search
///    row in the body costs a full strip of height on a 10" tablet for a
///    control that is one field tall.
///  * Everything that is not "add one" hides behind a single ⋮ — four loose
///    toolbar buttons is how the Products header ended up unreadable.
///  * The primary action is a FAB, bottom-trailing, where a thumb already is.
///  * The title yields to the search bar on a narrow screen. The bar is the
///    control; the word is decoration.
///
/// It deliberately does NOT own the table, the search state, or the selection:
/// those differ per screen and belong to the screen. This is the chrome.

/// One line in the ⋮ menu.
@immutable
class IlyassMenuAction {
  const IlyassMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.enabled = true,
    this.color,
    this.dividerBefore = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;

  /// A greyed line that still says what it would do — an operator needs to see
  /// that Delete exists before they understand they must tick something first.
  final bool enabled;

  /// Tints icon and label. For destructive entries; leave null otherwise.
  final Color? color;

  /// Separates this entry from the one above — used to fence off the
  /// destructive action from the routine ones.
  final bool dividerBefore;
}

class IlyassListScaffold extends StatelessWidget {
  const IlyassListScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onMenuPressed,
    this.searchBar,
    this.actions = const [],
    this.fabLabel,
    this.onFabPressed,
    this.floatingActionButton,
  });

  final String title;

  /// The table, usually. Gets the full width — no sidebar, no gutter.
  final Widget body;

  /// Opens the navigation drawer. Null when the host layout owns navigation.
  final VoidCallback? onMenuPressed;

  /// A `UnifiedSearchBar`, built by the screen because only the screen knows
  /// its filters. Null on a screen with nothing to search.
  final Widget? searchBar;

  /// The ⋮ menu. Empty hides the button entirely.
  final List<IlyassMenuAction> actions;

  /// Label for the extended FAB — "Add Product", "New Document". Null means no
  /// FAB, for a screen where nothing is created.
  final String? fabLabel;
  final VoidCallback? onFabPressed;

  /// Replaces the built-in FAB outright, for a screen that needs something
  /// other than one extended button.
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // Taller than the 56px default: the bar carries chips and quick
        // actions, and squeezing those into a standard toolbar is exactly what
        // makes them mouse-sized.
        toolbarHeight: searchBar == null ? kToolbarHeight : 72,
        titleSpacing: 12,
        backgroundColor: theme.colorScheme.surface,
        leading: onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: AppLocalizations.of(context).showNavigation,
                onPressed: onMenuPressed,
              )
            : null,
        title: searchBar == null
            ? Text(title)
            : Row(
                children: [
                  if (!context.isCompact) ...[
                    Text(title),
                    const SizedBox(width: 20),
                  ],
                  Expanded(child: searchBar!),
                ],
              ),
        actions: [
          if (actions.isNotEmpty) _ActionsMenu(actions: actions),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
      floatingActionButton: floatingActionButton ??
          (fabLabel == null
              ? null
              : FloatingActionButton.extended(
                  // 🚨 A tag of this screen's own, never the default.
                  //
                  // ManagementLayout keeps every visited screen alive in a
                  // LazyIndexedStack, so two screens with a FAB are mounted in
                  // ONE Navigator subtree at once. Flutter's default hero tag is
                  // a shared constant, so the second one to mount collides with
                  // the first and every route animation throws
                  // "multiple heroes share the same tag".
                  heroTag: 'ilyass-fab-$title',
                  onPressed: onFabPressed,
                  icon: const Icon(Icons.add),
                  label: Text(fabLabel!),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                )),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({required this.actions});

  final List<IlyassMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return PopupMenuButton<int>(
      tooltip: l.actionsLabel,
      position: PopupMenuPosition.under,
      onSelected: (index) => actions[index].onSelected(),
      itemBuilder: (_) => [
        for (var i = 0; i < actions.length; i++) ...[
          if (actions[i].dividerBefore && i > 0) const PopupMenuDivider(),
          PopupMenuItem<int>(
            value: i,
            // Finger-sized rows: this menu is now the only way to reach half
            // of what the screen can do, so it cannot be a mouse-sized list.
            height: 52,
            enabled: actions[i].enabled,
            child: Row(
              children: [
                Icon(actions[i].icon,
                    size: 20,
                    color: actions[i].enabled
                        ? actions[i].color
                        : theme.disabledColor),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    actions[i].label,
                    style: TextStyle(
                      color: actions[i].enabled
                          ? actions[i].color
                          : theme.disabledColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!context.isCompact) ...[
              Text(l.actionsLabel,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.onSurface)),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.more_vert, size: 22),
          ],
        ),
      ),
    );
  }
}

/// The leading checkbox column every one of these tables carries.
///
/// 🚨 The [GestureDetector] is what keeps the ROW's tap from firing: it sits
/// deeper in the hit test than [IlyassTable]'s row handler, so it wins the
/// gesture arena and ticking a box never opens the editor. The whole 40×40 box
/// is the target, not the 18px tick inside it.
IlyassColumn<T> ilyassSelectionColumn<T, I>({
  required List<T> rows,
  required Set<I> selected,
  required I Function(T row) idOf,
  required ValueChanged<Set<I>> onChanged,
}) {
  final allSelected = rows.isNotEmpty && selected.length == rows.length;

  Widget box({required bool? value, required VoidCallback onTap}) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          // The checkbox is painted, never tapped: one recognizer for the whole
          // cell beats two competing for the same 40px.
          child: IgnorePointer(
            child: Checkbox(tristate: true, value: value, onChanged: (_) {}),
          ),
        ),
      );

  return IlyassColumn<T>(
    key: 'select',
    label: '',
    width: 64,
    minWidth: 64,
    resizable: false,
    // Tristate: all / none / some, so a partial selection reads as partial
    // rather than as "nothing is selected".
    header: (context) => box(
      value: allSelected ? true : (selected.isEmpty ? false : null),
      onTap: () =>
          onChanged(allSelected ? <I>{} : {for (final r in rows) idOf(r)}),
    ),
    cell: (context, row) {
      final id = idOf(row);
      final isOn = selected.contains(id);
      return box(
        value: isOn,
        onTap: () => onChanged({
          for (final existing in selected)
            if (existing != id) existing,
          if (!isOn) id,
        }),
      );
    },
  );
}
