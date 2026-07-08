import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/security/security_guard.dart';
import 'package:pos_app/auth/users_screen.dart';
import 'package:pos_app/cart/payment_types_screen.dart';
import 'package:pos_app/company/my_company_screen.dart';
import 'package:pos_app/customer/customers_screen.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/dashboard/dashboard_screen.dart';
import 'package:pos_app/document/documents_screen.dart';
import 'package:pos_app/product/products_screen.dart';
import 'package:pos_app/product/product_groups_screen.dart';
import 'package:pos_app/stock/stock_screen.dart';
import 'package:pos_app/promotions/promotions_list_screen.dart';
import 'package:pos_app/reports/reports_screen.dart';
import 'package:pos_app/tax/tax_rates_screen.dart';
import 'package:pos_app/void_reason/void_reason_screen.dart';
import 'package:pos_app/loyalty/loyalty_cards_screen.dart';

class ManagementLayout extends ConsumerStatefulWidget {
  const ManagementLayout({super.key});

  @override
  ConsumerState<ManagementLayout> createState() => _ManagementLayoutState();
}

class _ManagementLayoutState extends ConsumerState<ManagementLayout> {
  int _selectedIndex = 0;
  // Desktop rail starts expanded; the hamburger collapses it to a mini
  // icon-only rail (it is never fully removed on desktop).
  bool _isSidebarExpanded = true;
  bool _landed = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Security key gating each tab, indexed to match the `screens` list below.
  /// Keep this in sync with that list — a missing/renamed key fails secure
  /// (cashier denied) because SecurityGuard treats unknown keys as admin-only.
  static const _tabKeys = <String>[
    'Management.Dashboard',     // 0  Dashboard
    'Management.Documents',     // 1  Documents
    'Management.Products',      // 2  Products
    'Management.ProductGroups', // 3  Product Groups
    'Management.Stock',         // 4  Stock
    'Management.Reporting',     // 5  Reporting
    'Management.Customers',     // 6  Customers & suppliers
    'Management.Promotions',    // 7  Promotions
    'Management.Security',      // 8  Users & security
    'Management.PaymentTypes',  // 9  Payment types
    'Management.TaxRates',      // 10 Tax rates
    'Management.Company',       // 11 My company
    'Management.VoidReasons',   // 12 Void reasons
    'Management.LoyaltyCards',  // 13 Loyalty Cards
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 850;
    // On desktop the rail is always present (expanded or mini); on touch it is
    // a slide-in drawer. Mini mode only applies to the always-present rail.
    final isMini = isDesktop && !_isSidebarExpanded;
    final cs = Theme.of(context).colorScheme;

    // Synchronous RBAC enforcer for this user. Rebuilds when the user, the
    // configured key levels, or settings change.
    final guard = ref.watch(securityGuardProvider);

    // Land on the first tab this user may actually open, so a cashier who lacks
    // Dashboard doesn't open straight onto an "Access Denied" panel. Runs each
    // build until the keys have loaded (canAccess is fail-secure while empty),
    // then hands control to manual navigation.
    if (!_landed) {
      final firstAllowed = _tabKeys.indexWhere(guard.canAccess);
      if (firstAllowed != -1) {
        _landed = true;
        _selectedIndex = firstAllowed;
      }
    }

    final canViewSelected = guard.canAccess(_tabKeys[_selectedIndex]);

    // On desktop the rail is always present, so the per-screen app-bar menu
    // button is hidden (null); on touch it opens the slide-in drawer.
    void onMenuPressed() => _scaffoldKey.currentState?.openDrawer();
    final VoidCallback? screenMenu = isDesktop ? null : onMenuPressed;

    final List<Widget> screens = [
      DashboardScreen(onMenuPressed: screenMenu),
      DocumentsScreen(onMenuPressed: screenMenu),
      ProductsScreen(onMenuPressed: screenMenu),
      ProductGroupsScreen(onMenuPressed: screenMenu),
      StockScreen(onMenuPressed: screenMenu),
      ReportsScreen(onMenuPressed: screenMenu),
      CustomersScreen(onMenuPressed: screenMenu),
      PromotionsListScreen(onMenuPressed: screenMenu),
      UsersScreen(onMenuPressed: screenMenu),
      PaymentTypesScreen(onMenuPressed: screenMenu),
      TaxRatesScreen(onMenuPressed: screenMenu),
      MyCompanyScreen(onMenuPressed: screenMenu),
      VoidReasonsScreen(onMenuPressed: screenMenu),
      LoyaltyCardsScreen(onMenuPressed: screenMenu),
    ];

    void handleNavTap(int index) {
      // Enforce the per-tab security key: a denied tap shows the standard
      // "Access Denied" toast and leaves the current selection untouched.
      guard.guard(context, _tabKeys[index], () {
        setState(() => _selectedIndex = index);
        // Desktop sidebar stays put on tab select — only manual toggles hide it.
        if (!isDesktop && Scaffold.of(context).hasDrawer) {
          Navigator.pop(context);
        }
      });
    }

    Widget sidebar = Container(
      width: isMini ? kSidebarMiniW : kSidebarW,
      color: context.navSidebarBg,
      child: SafeArea(
        child: Column(
          children: [
            // Header. Expanded: portal title + collapse toggle. Mini: the title
            // is hidden and a single centred icon expands the rail again.
            // Colours read from adaptive nav tokens so the title stays legible
            // in Light Mode (charcoal) and Dark Mode (near-white).
            isMini
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 20),
                    child: Center(
                      child: IconButton(
                        icon: Icon(Icons.menu, color: context.navMuted),
                        tooltip: "Expand Sidebar",
                        onPressed: () =>
                            setState(() => _isSidebarExpanded = true),
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.fromLTRB(16, 24, 8, 20),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Management Portal",
                            style: TextStyle(
                              color: context.navText,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isDesktop)
                          IconButton(
                            icon: Icon(Icons.menu_open, color: context.navMuted),
                            tooltip: "Collapse Sidebar",
                            onPressed: () =>
                                setState(() => _isSidebarExpanded = false),
                          ),
                      ],
                    ),
                  ),

            // Scrollable nav items
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    NavItem(
                      isMini: isMini,
                      icon: Icons.dashboard,
                      label: "Dashboard",
                      isActive: _selectedIndex == 0,
                      onTap: () => handleNavTap(0),
                    ),
                    NavItem(
                      isMini: isMini,
                      icon: Icons.description,
                      label: "Documents",
                      isActive: _selectedIndex == 1,
                      onTap: () => handleNavTap(1),
                    ),
                    NavItem(
                      isMini: isMini,
                      icon: Icons.local_offer,
                      label: "Products",
                      isActive: _selectedIndex == 2,
                      onTap: () => handleNavTap(2),
                    ),
                    NavItem(
                      isMini: isMini,
                      icon: Icons.folder,
                      label: "Product Groups",
                      isActive: _selectedIndex == 3,
                      onTap: () => handleNavTap(3),
                    ),
                    NavItem(
                      isMini: isMini,
                      icon: Icons.inventory_2,
                      label: "Stock",
                      isActive: _selectedIndex == 4,
                      onTap: () => handleNavTap(4),
                    ),
                    NavItem(
                      isMini: isMini,
                      icon: Icons.bar_chart,
                      label: "Reporting",
                      isActive: _selectedIndex == 5,
                      onTap: () => handleNavTap(5),
                    ),
                    NavItem(
                      isMini: isMini,
                      icon: Icons.people,
                      label: "Customers & suppliers",
                      isActive: _selectedIndex == 6,
                      onTap: () => handleNavTap(6),
                    ),
                    NavItem(
                      isMini: isMini,
                      icon: Icons.favorite,
                      label: "Promotions",
                      isActive: _selectedIndex == 7,
                      onTap: () => handleNavTap(7),
                    ),
                    NavItem(
                      isMini: isMini,
                      icon: Icons.vpn_key,
                      label: "Users & security",
                      isActive: _selectedIndex == 8,
                      onTap: () => handleNavTap(8),
                    ),
                    NavItem(
                      isMini: isMini,
                      icon: Icons.credit_card,
                      label: "Payment types",
                      isActive: _selectedIndex == 9,
                      onTap: () => handleNavTap(9),
                    ),
                    NavItem(
                      isMini: isMini,
                      icon: Icons.percent,
                      label: "Tax rates",
                      isActive: _selectedIndex == 10,
                      onTap: () => handleNavTap(10),
                    ),
                    NavItem(
                      isMini: isMini,
                      icon: Icons.business,
                      label: "My company",
                      isActive: _selectedIndex == 11,
                      onTap: () => handleNavTap(11),
                    ),
                    NavItem(
                      isMini: isMini,
                      icon: Icons.block,
                      label: "Void reasons",
                      isActive: _selectedIndex == 12,
                      onTap: () => handleNavTap(12),
                    ),
                    NavItem(
                      isMini: isMini,
                      icon: Icons.card_giftcard,
                      label: "Loyalty Cards",
                      isActive: _selectedIndex == 13,
                      onTap: () => handleNavTap(13),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Pinned exit button at the bottom of the sidebar.
            // Tonal "danger" treatment: subtle error-tinted fill + border so it
            // reads as a destructive/exit action without a heavy solid block.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Tooltip(
                message: "Exit Management",
                child: SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: cs.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: cs.error.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout_rounded,
                                color: cs.error, size: 20),
                            // Mini rail: icon only — label collapses away.
                            if (!isMini) ...[
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  "Exit Management",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: cs.error,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.navScaffoldBg,
      drawer: isDesktop
          ? null
          : Drawer(backgroundColor: context.navSidebarBg, child: sidebar),
      body: Row(
        children: [
          // Desktop rail is always present (expanded or mini); collapsing only
          // shrinks it to icons, it is never removed. On touch it's a drawer.
          if (isDesktop) sidebar,

          // Every management screen renders its own AppBar with a menu leading
          // (no back-arrow), so the shell needs no fallback bar.
          // Render guard: if the active tab isn't permitted (e.g. cold start
          // before manual navigation), show an Access Denied panel instead of
          // the screen — defence in depth alongside the tap guard above.
          Expanded(
            child: canViewSelected
                ? LazyIndexedStack(
                    index: _selectedIndex,
                    children: screens,
                  )
                : _AccessDeniedPanel(
                    onMenuPressed: screenMenu,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shown in the management body when the active tab is gated by a security key
/// the current user lacks. The tap guard already blocks switching *to* a denied
/// tab; this also covers the cold-start case where the default landing tab is
/// itself denied (e.g. a cashier without Dashboard access).
class _AccessDeniedPanel extends StatelessWidget {
  final VoidCallback? onMenuPressed;
  const _AccessDeniedPanel({this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: onMenuPressed,
              )
            : null,
        title: const Text('Restricted'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: cs.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'You do not have permission to view this section.\n'
                'Choose another section from the menu, or ask an administrator '
                'for access.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Text(
          "$title Screen\n(Coming Soon)",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, color: Colors.grey),
        ),
      ),
    );
  }
}
