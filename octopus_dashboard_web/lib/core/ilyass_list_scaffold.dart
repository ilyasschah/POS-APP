import 'package:flutter/material.dart';

import '../widgets/list_panel.dart';
import 'breakpoints.dart';
import 'glass.dart';
import 'theme.dart';
import 'typography.dart';

/// One line in a list screen's ⋮ menu.
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
  final bool enabled;

  /// Tints icon and label — for a destructive entry.
  final Color? color;

  /// Fences this entry off from the one above.
  final bool dividerBefore;
}

/// A LIST destination, ported from the POS (`IlyassListScaffold`) onto the
/// dashboard shell.
///
/// The chrome only — the list, its search state and its rows belong to the
/// screen. What it settles so no list screen re-derives it:
///
///  * The search field lives in the HEADER beside the title, and drops below
///    it only when the header is too narrow to hold both.
///  * Refresh is always visible — pull-to-refresh does not exist on a desktop
///    browser.
///  * Everything that is not the one primary action hides behind a single ⋮.
///  * The primary action is an extended FAB, bottom-trailing, where a thumb
///    already is on a tablet.
///
/// A sidebar destination is a TAB of the shell, so there is no leading
/// control here: the rail or drawer is the way out.
class IlyassListScaffold extends StatelessWidget {
  const IlyassListScaffold({
    super.key,
    required this.title,
    required this.body,
    this.searchBar,
    this.actions = const [],
    this.onRefresh,
    this.isRefreshing = false,
    this.banner,
    this.fabLabel,
    this.fabIcon = Icons.add_rounded,
    this.onFabPressed,
    this.maxContentWidth = Layout.maxContentWidth,
  });

  final String title;
  final Widget body;

  /// A search field built by the screen — only the screen knows what it
  /// filters. Null on a screen with nothing to search.
  final Widget? searchBar;

  /// The ⋮ menu. Empty hides it.
  final List<IlyassMenuAction> actions;

  final VoidCallback? onRefresh;
  final bool isRefreshing;

  /// A strip between the header and the body — a refresh-failed banner.
  final Widget? banner;

  /// "New document". Null means no FAB.
  final String? fabLabel;
  final IconData fabIcon;
  final VoidCallback? onFabPressed;

  final double maxContentWidth;

  /// Below this header width the search field moves under the title.
  static const double _inlineSearchWidth = 720;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tier = LayoutTier.watch(context);

    return Scaffold(
      // The shell already paints the page; this Scaffold exists to host the FAB.
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: Layout.pagePadding(tier),
        child: PageBody(
          maxWidth: maxContentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                title: title,
                searchBar: searchBar,
                actions: actions,
                onRefresh: onRefresh,
                isRefreshing: isRefreshing,
                inlineSearchWidth: _inlineSearchWidth,
              ),
              ?banner,
              Expanded(child: body),
            ],
          ),
        ),
      ),
      floatingActionButton: fabLabel == null
          ? null
          : FloatingActionButton.extended(
              // 🚨 A tag of this screen's own. The shell keeps every screen
              // mounted in one IndexedStack, and two FABs on the default tag
              // throw "multiple heroes share the same tag" on every route push.
              heroTag: 'ilyass-fab-$title',
              onPressed: onFabPressed,
              icon: Icon(fabIcon),
              label: Text(fabLabel!, style: AppText.style(size: 15, weight: 700)),
              backgroundColor: palette.accent,
              foregroundColor: AppTheme.onAccent(palette.accent),
              elevation: 2,
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.searchBar,
    required this.actions,
    required this.onRefresh,
    required this.isRefreshing,
    required this.inlineSearchWidth,
  });

  final String title;
  final Widget? searchBar;
  final List<IlyassMenuAction> actions;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final double inlineSearchWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.title(palette.primaryText),
    );
    final tools = <Widget>[
      if (onRefresh != null)
        GlassPill(
          tooltip: 'Refresh',
          onTap: onRefresh,
          padding: const EdgeInsets.all(13),
          child: isRefreshing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: palette.primaryText,
                  ),
                )
              : Icon(Icons.refresh_rounded, size: 20, color: palette.primaryText),
        ),
      if (actions.isNotEmpty) ...[
        const SizedBox(width: 8),
        _ActionsMenu(actions: actions),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inline =
              searchBar == null || constraints.maxWidth >= inlineSearchWidth;
          if (inline) {
            return Row(
              children: [
                if (searchBar == null)
                  Expanded(child: titleText)
                else ...[
                  titleText,
                  const SizedBox(width: 20),
                  Expanded(child: searchBar!),
                ],
                const SizedBox(width: 12),
                ...tools,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: titleText),
                  const SizedBox(width: 12),
                  ...tools,
                ],
              ),
              const SizedBox(height: 12),
              searchBar!,
            ],
          );
        },
      ),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({required this.actions});

  final List<IlyassMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopupMenuButton<int>(
      tooltip: 'More actions',
      position: PopupMenuPosition.under,
      onSelected: (index) => actions[index].onSelected(),
      itemBuilder: (_) => [
        for (var i = 0; i < actions.length; i++) ...[
          if (actions[i].dividerBefore && i > 0) const PopupMenuDivider(),
          PopupMenuItem<int>(
            value: i,
            height: 52,
            enabled: actions[i].enabled,
            child: Row(
              children: [
                Icon(
                  actions[i].icon,
                  size: 20,
                  color: actions[i].color ?? palette.dim(0.8),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    actions[i].label,
                    style: AppText.body(
                      actions[i].color ?? palette.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
      child: GlassPill(
        padding: const EdgeInsets.all(13),
        child: Icon(Icons.more_vert_rounded, size: 20, color: palette.primaryText),
      ),
    );
  }
}
