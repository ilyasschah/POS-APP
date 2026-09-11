import 'package:flutter/material.dart';
import 'package:pos_app/core/ilyass_screen.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/security/security_guard.dart';
import 'package:pos_app/security/security_rules_screen.dart';
import 'package:pos_app/auth/users_screen.dart';
import 'package:pos_app/cart/payment_types_screen.dart';
import 'package:pos_app/company/my_company_screen.dart';
import 'package:pos_app/customer/customers_screen.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/dashboard/dashboard_screen.dart';
import 'package:pos_app/document/documents_screen.dart';
import 'package:pos_app/modifier/modifier_groups_screen.dart';
import 'package:pos_app/product/products_screen.dart';
import 'package:pos_app/product/product_groups_screen.dart';
import 'package:pos_app/stock/stock_history_screen.dart';
import 'package:pos_app/stock/stock_screen.dart';
import 'package:pos_app/promotions/promotions_list_screen.dart';
import 'package:pos_app/reports/reports_screen.dart';
import 'package:pos_app/tax/tax_rates_screen.dart';
import 'package:pos_app/void_reason/void_reason_screen.dart';
import 'package:pos_app/loyalty/loyalty_cards_screen.dart';

/// One management sidebar destination. [_ManagementLayoutState._entries] is the
/// single source of truth: its order IS the sidebar order, and each entry
/// carries its own security key, icon, label and screen — so reordering the
/// menu is moving one entry, and a key can never drift out of step with the
/// screen it guards.
class _ManagementEntry {
  final String securityKey;
  final IconData icon;
  final String Function(AppLocalizations l) label;
  final Widget Function(VoidCallback? onMenuPressed) screen;

  const _ManagementEntry({
    required this.securityKey,
    required this.icon,
    required this.label,
    required this.screen,
  });
}

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

  /// Sidebar order, grouped by job: overview → catalogue (products and what
  /// hangs off them) → customers and what hangs off them → staff & access →
  /// configuration, with the company profile last. An index is only a position
  /// in this list — nothing outside this file stores one — so entries may be
  /// reordered freely.
  ///
  /// A missing/renamed security key fails secure (cashier denied) because
  /// SecurityGuard treats unknown keys as admin-only.
  static final _entries = <_ManagementEntry>[
    _ManagementEntry(
      securityKey: 'Management.Dashboard',
      icon: Icons.dashboard,
      label: (l) => l.dashboard,
      screen: (m) => DashboardScreen(onMenuPressed: m),
    ),
    _ManagementEntry(
      securityKey: 'Management.Documents',
      icon: Icons.description,
      label: (l) => l.documents,
      screen: (m) => DocumentsScreen(onMenuPressed: m),
    ),
    _ManagementEntry(
      securityKey: 'Management.Products',
      icon: Icons.local_offer,
      label: (l) => l.products,
      screen: (m) => ProductsScreen(onMenuPressed: m),
    ),
    _ManagementEntry(
      securityKey: 'Management.ModifierGroups',
      icon: Icons.tune,
      label: (l) => l.modifierGroups,
      screen: (m) => ModifierGroupsScreen(onMenuPressed: m),
    ),
    _ManagementEntry(
      securityKey: 'Management.ProductGroups',
      icon: Icons.folder,
      label: (l) => l.productGroups,
      screen: (m) => ProductGroupsScreen(onMenuPressed: m),
    ),
    _ManagementEntry(
      securityKey: 'Management.Stock',
      icon: Icons.inventory_2,
      label: (l) => l.stock,
      screen: (m) => StockScreen(onMenuPressed: m),
    ),
    // Same key as Stock on purpose: the moves are how the stock got to where
    // the stock screen shows it, and whoever may see one may see the other.
    _ManagementEntry(
      securityKey: 'Management.Stock',
      icon: Icons.swap_horiz,
      label: (l) => l.stockMoves,
      screen: (m) => StockHistoryScreen(onMenuPressed: m),
    ),
    _ManagementEntry(
      securityKey: 'Management.Reporting',
      icon: Icons.bar_chart,
      label: (l) => l.reporting,
      screen: (m) => ReportsScreen(onMenuPressed: m),
    ),
    _ManagementEntry(
      securityKey: 'Management.Customers',
      icon: Icons.people,
      label: (l) => l.customersSuppliersLower,
      screen: (m) => CustomersScreen(onMenuPressed: m),
    ),
    _ManagementEntry(
      securityKey: 'Management.LoyaltyCards',
      icon: Icons.card_giftcard,
      label: (l) => l.loyaltyCards,
      screen: (m) => LoyaltyCardsScreen(onMenuPressed: m),
    ),
    _ManagementEntry(
      securityKey: 'Management.Promotions',
      icon: Icons.favorite,
      label: (l) => l.promotions,
      screen: (m) => PromotionsListScreen(onMenuPressed: m),
    ),
    _ManagementEntry(
      securityKey: 'Management.Security',
      icon: Icons.manage_accounts,
      label: (l) => l.users,
      screen: (m) => UsersScreen(onMenuPressed: m),
    ),
    // Same key as Users on purpose: Users and Security rules were one tabbed
    // screen and are now two. Splitting the SCREEN is not splitting the
    // permission — anyone who may manage staff may set what they can do.
    _ManagementEntry(
      securityKey: 'Management.Security',
      icon: Icons.vpn_key,
      label: (l) => l.securityRules,
      screen: (m) => SecurityRulesScreen(onMenuPressed: m),
    ),
    _ManagementEntry(
      securityKey: 'Management.PaymentTypes',
      icon: Icons.credit_card,
      label: (l) => l.paymentTypesLower,
      screen: (m) => PaymentTypesScreen(onMenuPressed: m),
    ),
    _ManagementEntry(
      securityKey: 'Management.TaxRates',
      icon: Icons.percent,
      label: (l) => l.taxRatesLower,
      screen: (m) => TaxRatesScreen(onMenuPressed: m),
    ),
    _ManagementEntry(
      securityKey: 'Management.VoidReasons',
      icon: Icons.block,
      label: (l) => l.voidReasonsLower,
      screen: (m) => VoidReasonsScreen(onMenuPressed: m),
    ),
    _ManagementEntry(
      securityKey: 'Management.Company',
      icon: Icons.business,
      label: (l) => l.myCompanyLower,
      screen: (m) => MyCompanyScreen(onMenuPressed: m),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 850;
    // On desktop the rail is always present (expanded or mini); on touch it is
    // a slide-in drawer. Mini mode only applies to the always-present rail.
    final isMini = isDesktop && !_isSidebarExpanded;
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    // Synchronous RBAC enforcer for this user. Rebuilds when the user, the
    // configured key levels, or settings change.
    final guard = ref.watch(securityGuardProvider);

    // Land on the first tab this user may actually open, so a cashier who lacks
    // Dashboard doesn't open straight onto an "Access Denied" panel. Runs each
    // build until the keys have loaded (canAccess is fail-secure while empty),
    // then hands control to manual navigation.
    if (!_landed) {
      final firstAllowed =
          _entries.indexWhere((e) => guard.canAccess(e.securityKey));
      if (firstAllowed != -1) {
        _landed = true;
        _selectedIndex = firstAllowed;
      }
    }

    final canViewSelected =
        guard.canAccess(_entries[_selectedIndex].securityKey);

    // On desktop the rail is always present, so the per-screen app-bar menu
    // button is hidden (null); on touch it opens the slide-in drawer.
    void onMenuPressed() => _scaffoldKey.currentState?.openDrawer();
    final VoidCallback? screenMenu = isDesktop ? null : onMenuPressed;

    final List<Widget> screens = [
      for (final entry in _entries) entry.screen(screenMenu),
    ];

    void handleNavTap(int index) {
      // Enforce the per-tab security key: a denied tap shows the standard
      // "Access Denied" toast and leaves the current selection untouched.
      guard.guard(context, _entries[index].securityKey, () {
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
                        tooltip: l.expandSidebar,
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
                            l.managementPortal,
                            style: TextStyle(
                              color: context.navText,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isDesktop)
                          IconButton(
                            icon: Icon(
                              Icons.menu_open,
                              color: context.navMuted,
                            ),
                            tooltip: l.collapseSidebar,
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
                    for (var i = 0; i < _entries.length; i++)
                      NavItem(
                        isMini: isMini,
                        icon: _entries[i].icon,
                        label: _entries[i].label(l),
                        isActive: _selectedIndex == i,
                        onTap: () => handleNavTap(i),
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
                message: l.exitManagement,
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
                            Icon(
                              Icons.logout_rounded,
                              color: cs.error,
                              size: 20,
                            ),
                            // Mini rail: icon only — label collapses away.
                            if (!isMini) ...[
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  l.exitManagement,
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
            // IlyassShell marks this subtree as HOSTED, so a management screen
            // knows it is a tab and not a pushed route. Without it every tab
            // would sprout a back arrow on desktop (where `screenMenu` is null
            // because the rail is permanent) that popped the whole management
            // shell. See `lib/core/ilyass_screen.dart`.
            child: IlyassShell(
              child: canViewSelected
                  ? LazyIndexedStack(index: _selectedIndex, children: screens)
                  : _AccessDeniedPanel(onMenuPressed: screenMenu),
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
            ? IconButton(icon: const Icon(Icons.menu), onPressed: onMenuPressed)
            : null,
        title: Text(AppLocalizations.of(context).restricted),
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
                AppLocalizations.of(context).accessDenied,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).accessDeniedBody,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
