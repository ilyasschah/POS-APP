import 'package:flutter/material.dart';

import 'package:pos_app/core/responsive.dart';
import 'package:pos_app/l10n/app_localizations.dart';

/// "Ilyass Screen" — the house shape for a screen you reach from the MAIN
/// NAVIGATION SIDEBAR, extracted from End of Day once five more sidebar
/// destinations were asked to behave like it.
///
/// The contract, so no screen has to re-derive it:
///
///  * **A sidebar destination is a TAB, never a pushed route.** It renders
///    inside the shell's `LazyIndexedStack`, so it keeps its scroll position
///    and its filters, switching to it costs no route animation, and it never
///    stacks *on top of* the shell it belongs to.
///  * **The top-left control is decided by how the screen is MOUNTED, not by
///    the screen.** Hosted in the shell → hamburger. Pushed as a standalone
///    route → back arrow. That is [IlyassLeading]'s whole job, and it is why
///    this file exists at all: Cash In/Out shipped a back arrow while it was a
///    shell tab, pointing at a route that was not there. A screen that picks
///    its own leading widget gets that wrong the moment it is mounted the
///    other way.
///  * **There is no "leave" button.** The sidebar is the way out of every
///    destination, so a Cancel button cancels the *work* — it does not
///    navigate. When a screen genuinely must hand control back after a commit,
///    it calls [ilyassLeave], which pops when pushed and returns to the POS tab
///    when hosted.
///  * The search bar lives in the HEADER, not stacked above the body: a search
///    row in the body costs a full strip of height on a 10-inch tablet for a
///    control that is one field tall.
///  * Everything that is not the one primary action hides behind a single ⋮.
///  * The primary action is a FAB, bottom-trailing, where a thumb already is.
///  * The title yields to the search bar on a narrow screen. The bar is the
///    control; the word is decoration.
///
/// It deliberately does NOT own the body, the search state, or the selection:
/// those differ per screen and belong to the screen. This is the chrome.
///
/// See also `IlyassListScaffold` (`lib/core/ilyass_list_scaffold.dart`), which
/// is this with the list-screen defaults already set, and `IlyassTable`
/// (`lib/core/ilyass_table.dart`) for what usually goes in [body].

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

/// Marks the subtree a navigation shell hosts its tabs in — MainLayout and
/// ManagementLayout both wrap their `LazyIndexedStack` in one.
///
/// 🚨 This is the ONLY reliable way to tell a hosted tab from a pushed route,
/// and it cannot be inferred: both shells are themselves pushed over the login
/// screen, so `Navigator.canPop()` is `true` inside every tab. Guessing from
/// that would put a back arrow on each management tab on desktop (where the
/// rail is permanent and no hamburger is passed), pointing at "pop the entire
/// management shell" — and would make [ilyassLeave] drop the operator back on
/// the login screen.
///
/// A route pushed from inside a tab does NOT inherit this: the new route is
/// built under the Navigator, which is an ANCESTOR of the shell, so the lookup
/// correctly finds nothing and the screen gets its back arrow.
class IlyassShell extends InheritedWidget {
  const IlyassShell({super.key, required super.child});

  /// True when the caller is a tab inside a navigation shell.
  static bool hosts(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IlyassShell>() != null;

  @override
  bool updateShouldNotify(IlyassShell oldWidget) => false;
}

/// The single control in the top-left of an Ilyass Screen.
///
/// 🚨 Screens must never hardcode this. The same widget is a shell tab on one
/// mounting and a pushed route on the next — Sessions is both: a sidebar tab,
/// and a route the session gate pushes mid-sale — and only the mounting
/// decides which control is correct:
///
///  * [onMenuPressed] given → hamburger, opens the sidebar.
///  * hosted by an [IlyassShell] → nothing: the shell's permanent rail is
///    already on screen, and there is no route under this one to go back to.
///  * pushed and poppable   → back arrow, pops.
///  * otherwise             → nothing, because there is nowhere to go.
class IlyassLeading extends StatelessWidget {
  const IlyassLeading({super.key, this.onMenuPressed, this.iconSize = 26});

  final VoidCallback? onMenuPressed;
  final double iconSize;

  /// Null when there is no control to show, so an [AppBar] can drop the slot
  /// entirely rather than reserve an empty 48px box for it.
  static Widget? maybe(
    BuildContext context,
    VoidCallback? onMenuPressed, {
    double iconSize = 26,
  }) {
    if (onMenuPressed == null && !_canGoBack(context)) return null;
    return IlyassLeading(onMenuPressed: onMenuPressed, iconSize: iconSize);
  }

  /// A back arrow is right only for a screen that was PUSHED. Inside a shell
  /// there is a route to pop — the shell's own — and popping it is never what
  /// the arrow appears to promise.
  static bool _canGoBack(BuildContext context) =>
      !IlyassShell.hosts(context) && Navigator.of(context).canPop();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (onMenuPressed != null) {
      return IconButton(
        icon: Icon(Icons.menu, size: iconSize, color: onSurface),
        tooltip: l.showNavigation,
        onPressed: onMenuPressed,
      );
    }
    if (_canGoBack(context)) {
      return IconButton(
        icon: Icon(Icons.arrow_back, size: iconSize, color: onSurface),
        tooltip: l.back,
        onPressed: () => Navigator.pop(context),
      );
    }
    return const SizedBox(width: 12);
  }
}

/// Hands control back from a screen that has finished its work.
///
/// Pops when the screen was pushed; otherwise it is a shell tab with nothing
/// under it, so it asks the host to return to the default destination instead
/// of stranding the operator on a form they have already committed.
///
/// This is the only navigation an Ilyass Screen is allowed to perform, and it
/// belongs on a commit, never on a Cancel that merely clears a field.
void ilyassLeave(BuildContext context, {VoidCallback? onReturnToShell}) {
  // 🚨 The shell check comes FIRST. Every tab can technically pop — the shell
  // itself was pushed over login — so popping from a tab signs the operator
  // out mid-shift instead of returning them to the POS.
  if (!IlyassShell.hosts(context) && Navigator.of(context).canPop()) {
    Navigator.pop(context);
  } else {
    onReturnToShell?.call();
  }
}

class IlyassScreen extends StatelessWidget {
  const IlyassScreen({
    super.key,
    required this.title,
    required this.body,
    this.onMenuPressed,
    this.searchBar,
    this.actions = const [],
    this.trailing = const [],
    this.bottom,
    this.footer,
    this.fabLabel,
    this.onFabPressed,
    this.floatingActionButton,
    this.maxContentWidth,
    this.resizeToAvoidBottomInset,
  });

  final String title;

  /// The table or the form. Gets the full width — no sidebar, no gutter —
  /// unless [maxContentWidth] caps it.
  final Widget body;

  /// Opens the navigation drawer. Supplied by the host shell; null when the
  /// screen is pushed as a standalone route, which is what turns the leading
  /// control into a back arrow. See [IlyassLeading].
  final VoidCallback? onMenuPressed;

  /// A `UnifiedSearchBar`, built by the screen because only the screen knows
  /// its filters. Null on a screen with nothing to search.
  final Widget? searchBar;

  /// The ⋮ menu. Empty hides the button entirely.
  final List<IlyassMenuAction> actions;

  /// Raw widgets pinned right of the title, before the ⋮ — a live count, a
  /// status chip. Keep it to things that *display*; anything that acts belongs
  /// in [actions].
  final List<Widget> trailing;

  /// Sits under the header, full width — a `TabBar` for a screen with sections.
  final PreferredSizeWidget? bottom;

  /// A pinned bar along the bottom edge, for a form whose commit button must
  /// stay reachable while the body scrolls. Never put navigation in it.
  ///
  /// It is deliberately NOT capped by [maxContentWidth]: a full-bleed bar reads
  /// as part of the screen, where a 480px one floating mid-screen reads as part
  /// of the form and gets lost. Cap the bar's *contents* yourself if the
  /// buttons should line up with a capped body.
  final Widget? footer;

  /// Label for the extended FAB — "Add Product", "New Document". Null means no
  /// FAB, for a screen where nothing is created.
  final String? fabLabel;
  final VoidCallback? onFabPressed;

  /// Replaces the built-in FAB outright, for a screen that needs something
  /// other than one extended button.
  final Widget? floatingActionButton;

  /// Ilyass Style reading cap. Set it on a form or a report — a 24-inch till
  /// stretches a 480px form to 2000px otherwise. Leave it null for a data
  /// table, which scrolls horizontally instead of being capped.
  final double? maxContentWidth;

  /// Leave null for the Flutter default. Set false on a screen whose search
  /// lives in the header and whose body must not reflow under the on-screen
  /// keyboard.
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = body;
    if (maxContentWidth != null) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth!),
          child: content,
        ),
      );
    }
    if (footer != null) {
      // The footer is pinned OUTSIDE the width cap: a full-bleed bar reads as
      // part of the screen, while a 480px-wide one floating mid-screen reads
      // as part of the form and gets lost against the background.
      content = Column(
        children: [Expanded(child: content), footer!],
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // Taller than the 56px default when it carries a search bar: that bar
        // holds chips and quick actions, and squeezing those into a standard
        // toolbar is exactly what makes them mouse-sized.
        toolbarHeight: searchBar == null ? kToolbarHeight : 72,
        titleSpacing: 12,
        backgroundColor: theme.colorScheme.surface,
        leading: IlyassLeading.maybe(context, onMenuPressed),
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
          ...trailing,
          if (actions.isNotEmpty) IlyassActionsMenu(actions: actions),
          const SizedBox(width: 8),
        ],
        bottom: bottom,
      ),
      body: content,
      floatingActionButton: floatingActionButton ??
          (fabLabel == null
              ? null
              : FloatingActionButton.extended(
                  // 🚨 A tag of this screen's own, never the default.
                  //
                  // Both shells keep every visited screen alive in a
                  // LazyIndexedStack, so two screens with a FAB are mounted in
                  // ONE Navigator subtree at once. Flutter's default hero tag
                  // is a shared constant, so the second one to mount collides
                  // with the first and every route animation throws
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

/// The ⋮ that every Ilyass Screen collapses its secondary actions into.
///
/// Public because the wide POS screens build their header from `PosTopBar`
/// rather than an [AppBar], and still owe the operator the same one menu.
class IlyassActionsMenu extends StatelessWidget {
  const IlyassActionsMenu({super.key, required this.actions});

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
