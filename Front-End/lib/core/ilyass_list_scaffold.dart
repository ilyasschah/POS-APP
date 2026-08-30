import 'package:flutter/material.dart';

import 'package:pos_app/core/ilyass_screen.dart';
import 'package:pos_app/core/ilyass_table.dart';

// `IlyassMenuAction` and the ⋮ menu moved to `ilyass_screen.dart` when the
// header became the shared "Ilyass Screen" chrome. Re-exported so the twelve
// management screens that import this file keep compiling unchanged.
export 'package:pos_app/core/ilyass_screen.dart'
    show IlyassMenuAction, IlyassLeading, IlyassScreen, IlyassActionsMenu;

/// A management LIST screen: [IlyassScreen] with the defaults a table screen
/// always wants, and no width cap — data tables scroll horizontally instead of
/// being capped (see `PROJECT_DOCUMENTATION.md` §7).
///
/// New screens can use [IlyassScreen] directly; this stays because "the list
/// screens all look like Products" is a rule worth having one name for, and
/// because a list screen should not have to remember to leave
/// [IlyassScreen.maxContentWidth] null.
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

  /// Opens the navigation drawer. Null when the screen is pushed as its own
  /// route, which turns the leading control into a back arrow.
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
  Widget build(BuildContext context) => IlyassScreen(
        title: title,
        body: body,
        onMenuPressed: onMenuPressed,
        searchBar: searchBar,
        actions: actions,
        fabLabel: fabLabel,
        onFabPressed: onFabPressed,
        floatingActionButton: floatingActionButton,
      );
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
