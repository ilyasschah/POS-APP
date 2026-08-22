import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../core/breakpoints.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/dashboard_screen.dart';
import '../documents/documents_controller.dart';
import '../documents/documents_screen.dart';
import '../products/products_controller.dart';
import '../products/products_screen.dart';
import '../sessions/sessions_controller.dart';
import '../sessions/sessions_screen.dart';
import '../settings/settings_screen.dart';
import '../stock/stock_controller.dart';
import '../stock/stock_screen.dart';
import '../users/users_controller.dart';
import '../users/users_screen.dart';

/// The seven top-level destinations, in order. Settings is reachable *only*
/// from here — there is no second entry point anywhere in the UI.
enum AppDestination {
  dashboard(Icons.show_chart),
  sessions(Icons.point_of_sale),
  products(Icons.sell),
  stock(Icons.inventory_2),
  documents(Icons.description),
  users(Icons.people),
  settings(Icons.settings);

  const AppDestination(this.icon);
  final IconData icon;

  // Grab the translation dynamically
  String title(AppLocalizations loc) {
    switch (this) {
      case AppDestination.dashboard:
        return loc.navDashboard;
      case AppDestination.sessions:
        return loc.navSessions;
      case AppDestination.products:
        return loc.navProducts;
      case AppDestination.stock:
        return loc.navStock;
      case AppDestination.documents:
        return loc.navDocuments;
      case AppDestination.users:
        return loc.navUsers;
      case AppDestination.settings:
        return loc.navSettings;
    }
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  bool _railExtended = false;

  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame: kicking off a fetch synchronously
    // here would mutate providers while the tree is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh(AppDestination.values[_index]);
    });
  }

  /// Re-fetches a destination's data.
  ///
  /// Called on **every** visit, not just the first. The screens live in an
  /// [IndexedStack] so they keep their scroll position and search text, which
  /// also means `initState` never runs again for a tab that's merely been
  /// off-screen — relying on it is exactly how three screens in the iOS build
  /// ended up showing stale/empty data until you navigated away and back.
  void _refresh(AppDestination destination) {
    switch (destination) {
      case AppDestination.dashboard:
        ref.read(dashboardProvider.notifier).load();
      case AppDestination.sessions:
        ref.read(sessionsProvider.notifier).load();
      case AppDestination.products:
        ref.read(productsProvider.notifier).load();
      case AppDestination.stock:
        ref.read(stockProvider.notifier).load();
      case AppDestination.documents:
        ref.read(documentsProvider.notifier).load();
      case AppDestination.users:
        ref.read(usersProvider.notifier).load();
      case AppDestination.settings:
        // Purely local preferences — nothing to fetch.
        break;
    }
  }

  void _select(int index) {
    setState(() => _index = index);
    _refresh(AppDestination.values[index]);
  }

  @override
  Widget build(BuildContext context) {
    final tier = LayoutTier.watch(context);
    final screens = _ScreenStack(index: _index);

    return Scaffold(
      appBar: tier.isCompact
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: context.palette.primaryText),
            )
          : null,
      // Inject the desktop sidebar into a mobile drawer!
      drawer: tier.isCompact
          ? Drawer(
              backgroundColor: context.palette.base,
              child: _Sidebar(
                index: _index,
                onSelect: (i) {
                  _select(i);
                  Navigator.pop(context); // Close drawer after tapping
                },
              ),
            )
          : null,
      body: SafeArea(
        child: switch (tier) {
          LayoutTier.compact => screens,
          LayoutTier.medium => Row(
            children: [
              _Rail(
                index: _index,
                extended: _railExtended,
                onSelect: _select,
                onToggleExtended: () =>
                    setState(() => _railExtended = !_railExtended),
              ),
              Expanded(child: screens),
            ],
          ),
          LayoutTier.expanded => Row(
            children: [
              _Sidebar(index: _index, onSelect: _select),
              Expanded(child: screens),
            ],
          ),
        },
      ),
    );
  }
}

/// Keeps all seven screens alive so each retains its scroll position and
/// search text across navigation, while making sure only the visible one does
/// any work.
///
/// [IndexedStack] alone keeps hidden children mounted *and ticking* — the
/// off-screen screens' loading spinners would animate forever, burning frames
/// on a page the user isn't looking at. [TickerMode] suspends animations for
/// everything except the selected screen.
class _ScreenStack extends StatelessWidget {
  const _ScreenStack({required this.index});

  final int index;

  /// `const` instances: because these widgets are identical across rebuilds,
  /// Flutter skips re-building the six off-screen subtrees when the selected
  /// tab changes, and a data refresh in one screen never rebuilds the others.
  static const List<Widget> _screens = [
    DashboardScreen(),
    SessionsScreen(),
    ProductsScreen(),
    StockScreen(),
    DocumentsScreen(),
    UsersScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: index,
      children: [
        for (var i = 0; i < _screens.length; i++)
          TickerMode(enabled: i == index, child: _screens[i]),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.index,
    required this.extended,
    required this.onSelect,
    required this.onToggleExtended,
  });

  final int index;
  final bool extended;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleExtended;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final loc = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: palette.primaryText.withValues(alpha: 0.1)),
        ),
      ),
      child: NavigationRail(
        selectedIndex: index,
        onDestinationSelected: onSelect,
        extended: extended,
        // NavigationRail asserts that an extended rail carries no label type.
        labelType: extended
            ? NavigationRailLabelType.none
            : NavigationRailLabelType.all,
        backgroundColor: Colors.transparent,
        indicatorColor: palette.accent.withValues(alpha: 0.18),
        selectedIconTheme: IconThemeData(color: palette.accent),
        unselectedIconTheme: IconThemeData(color: palette.dim(0.55)),
        selectedLabelTextStyle: AppText.style(
          size: 12,
          weight: 700,
          color: palette.accent,
        ),
        unselectedLabelTextStyle: AppText.style(
          size: 12,
          weight: 500,
          color: palette.dim(0.6),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: IconButton(
            onPressed: onToggleExtended,
            tooltip: extended ? 'Collapse menu' : 'Expand menu',
            icon: Icon(
              extended ? Icons.menu_open_rounded : Icons.menu_rounded,
              color: palette.dim(0.7),
            ),
          ),
        ),
        destinations: [
          for (final destination in AppDestination.values)
            NavigationRailDestination(
              icon: Icon(destination.icon),
              label: Text(destination.title(loc)),
            ),
        ],
      ),
    );
  }
}

/// Full sidebar for desktop widths — the closest analogue to the iOS
/// `NavigationSplitView`.
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 248,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: palette.primaryText.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: GlassCard(
          radius: 0,
          border: false,
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 22),
                child: Text(
                  'Octopus',
                  style: AppText.style(
                    size: 24,
                    weight: 800,
                    color: palette.primaryText,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final destination in AppDestination.values)
                      _SidebarItem(
                        destination: destination,
                        isSelected: destination.index == index,
                        onTap: () => onSelect(destination.index),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = isSelected ? palette.accent : palette.dim(0.7);
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? palette.accent.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: palette.primaryText.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(destination.icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.title(loc),
                    style: AppText.style(
                      size: 14,
                      weight: isSelected ? 700 : 500,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
