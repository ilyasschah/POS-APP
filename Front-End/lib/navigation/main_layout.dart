import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/onboarding/onboarding_seed.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/menu/menu_screen.dart';
import 'package:pos_app/menu/open_orders_screen.dart';
import 'package:pos_app/bookings/bookings_screen.dart';
import 'package:pos_app/bookings/booking_history_screen.dart';
import 'package:pos_app/floor_plan/floor_plan_screen.dart';
import 'package:pos_app/reports/z_report_screen.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/navigation/management_layout.dart';
import 'package:pos_app/navigation/power_modal.dart';
import 'package:pos_app/settings/settings_screen.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pos_app/auth/user_info_screen.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/auth/login_screen.dart';
import 'package:pos_app/auth/master_login_screen.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/sync/account_status_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:pos_app/database/backup_scheduler.dart';
import 'package:pos_app/cash/cash_movement_screen.dart';
import 'package:pos_app/time_clock/time_clock_screen.dart';
import 'package:pos_app/reports/sales_history_screen.dart';
import 'package:pos_app/credit/credit_payment_screen.dart';
import 'package:pos_app/shift/shift_management_screen.dart';
import 'package:pos_app/kitchen/pos_kitchen_server.dart';
import 'package:pos_app/sync/connectivity_watcher.dart';
import 'package:pos_app/sync/auto_sync_watcher.dart';
import 'package:pos_app/sync/sync_button.dart';
import 'package:pos_app/security/security_guard.dart';
import 'package:pos_app/security/security_keys.dart';

/// Shared reactive state for the active MainLayout tab index. Living outside
/// the widget means tab switches are pure state changes — callers (order
/// reopen, checkout completion) just set this instead of pushing a brand-new
/// MainLayout, so `initState` (and its one-time startup cash-in hook) never
/// re-fires on navigation.
///
/// Lazily seeded from the configured default screen on first read, so the very
/// first frame already lands on the right tab (no flash) without MainLayout
/// having to write the provider during its build/initState phase.
final mainNavigationIndexProvider = StateProvider<int>(
  (ref) => resolveDefaultScreenIndex(ref.read(appSettingsProvider)),
);

/// Resolves the configured default landing screen to a MainLayout tab index,
/// validated against the feature flags so we never route to a disabled (and
/// therefore empty `SizedBox.shrink`) screen — the cause of the post-checkout
/// black screen. Indices must match the `screens` array below:
/// 0 = POS Menu, 2 = Bookings, 4 = FloorPlan / Tables.
int resolveDefaultScreenIndex(Map<String, String> settings) {
  final pref = (settings[SettingKeys.defaultScreen] ?? 'POS').toLowerCase();
  final bookingEnabled =
      settings[SettingKeys.featureBookingEnabled]?.toLowerCase() == 'true';
  final floorPlanEnabled =
      settings[SettingKeys.featureFloorPlanEnabled]?.toLowerCase() == 'true';

  if (pref == 'booking' && bookingEnabled) return 2;
  if (pref == 'tables' && floorPlanEnabled) return 4;
  return 0; // POS Menu — always valid.
}

/// Small pill showing how many open orders the kitchen has marked ready.
/// Sits in the "View open sales" nav item's trailing slot.
class _ReadyCountBadge extends StatelessWidget {
  final int count;
  const _ReadyCountBadge(this.count);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          color: cs.onError,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class MainLayout extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainLayout({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> with WindowListener {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Guards the window-close hook against re-entry (double-clicking the close
  // button) so the on-close backup + destroy only run once.
  bool _closing = false;

  // window_manager only exists on desktop; the on-close backup hook is a no-op
  // on Android/iOS (mirrors the guard in main()).
  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  // The POS sidebar is a true overlay drawer: hidden by default, slid in over
  // the content by the top-left hamburger, and dismissed the instant a cashier
  // taps any item. Routed through the scaffold key so it works the same on
  // touch tablets and desktop.
  void _openSidebar() => _scaffoldKey.currentState?.openDrawer();
  void _closeSidebar() => _scaffoldKey.currentState?.closeDrawer();

  @override
  void initState() {
    super.initState();

    // Decide the landing tab once, on boot: an explicit caller-provided index
    // wins, otherwise honour the user's configured default screen (validated
    // against the feature flags). The provider is seeded lazily from settings
    // on first read, so this write only matters for re-login or an explicit
    // initialIndex — and it's deferred to after the first frame because
    // modifying a provider during initState/build is disallowed by Riverpod.
    final settings = ref.read(appSettingsProvider);
    final landingIndex = widget.initialIndex != 0
        ? widget.initialIndex
        : resolveDefaultScreenIndex(settings);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(mainNavigationIndexProvider.notifier).state = landingIndex;
      // Apply any feature choices made during pre-login onboarding (virtual
      // keyboard / tables / booking) now that a company + its settings exist.
      // Best-effort + idempotent — a no-op when nothing was parked.
      ref.read(onboardingFeatureSeedProvider.notifier).applyToCompanySettings();
      if (settings[SettingKeys.showCashInOnStart]?.toLowerCase() == 'true') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CashMovementScreen()),
        );
      }
    });

    // Desktop only: intercept the window close button so an on-close DB backup
    // (Database.Backup.OnClose) can finish before the app exits. Prevention is
    // scoped to the post-login shell — released in dispose — so the login /
    // master-login screens still close normally.
    if (_isDesktop) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
      // Release the interception so screens after logout close normally.
      windowManager.setPreventClose(false);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_closing) return;
    _closing = true;
    // Best-effort: runCloseBackup + _runBackup swallow errors internally, but
    // guard anyway so destroy() always runs and the window can never get stuck.
    try {
      await ref.read(backupSchedulerProvider.notifier).runCloseBackup();
    } catch (_) {}
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the connectivity watcher alive while the user is in the main shell.
    // Reading it here lazy-instantiates the provider (and its subscription)
    // on first build, and `autoDispose` is intentionally NOT used on it so it
    // survives rebuilds. Cleanup happens via ref.onDispose when the user logs
    // out and MainLayout is popped from the navigator.
    ref.watch(connectivityWatcherProvider);

    // Global auto-sync: any local write triggers a debounced push+pull. Kept
    // alive here for the whole post-login session (like the connectivity
    // watcher). Cleaned up via ref.onDispose when MainLayout is popped.
    ref.watch(autoSyncWatcherProvider);

    // Background poll for KDS order-status changes so the "ready" badge stays
    // live even while the cashier is on the POS menu. Kept alive for the
    // session like the watchers above.
    ref.watch(kitchenStatusWatcherProvider);

    // Automatic DB backups (on-start + interval), driven by the Database backup
    // settings. Kept alive for the session like the watchers above.
    ref.watch(backupSchedulerProvider);

    // Deleted-account guard: when a sync definitively reports this terminal's
    // company/tenant no longer exists (deleted in the admin portal), unlink the
    // device and return to the master login. Fires only on a real server "gone"
    // signal (see SyncNotifier) — never on an offline/transient error.
    ref.listen<bool>(accountRevokedProvider, (prev, next) async {
      if (next != true) return;
      ref.read(accountRevokedProvider.notifier).reset();
      // Erase the local mirror BEFORE unlinking. Unlinking alone only clears the
      // JWT/lease/company-id — it left the deleted company's entire dataset in
      // pos_app.sqlite, readable and backed up, for good. Deleting a tenant has
      // to reach its terminals too.
      await ref.read(appDatabaseProvider).purgeAllLocalData();
      await ref.read(authStorageProvider).unlinkDevice();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MasterLoginScreen()),
        (_) => false,
      );
    });

    // Revoked-terminal guard: an admin removed this device from the account
    // (User info → Active devices). Sign out and return to master login so the
    // operator can re-enrol it — a fresh master login clears the revoke.
    //
    // ⚠️ Unlike the deleted-COMPANY guard above, this must NOT purge local data.
    // The company is still theirs, and an unpushed sale sitting here is real
    // money that has to survive to be synced once they sign back in.
    ref.listen<String?>(deviceRevokedProvider, (prev, next) async {
      if (next == null) return;
      ref.read(deviceRevokedProvider.notifier).reset();
      await ref.read(authStorageProvider).unlinkDevice();
      if (!context.mounted) return;
      showAppSnackbar(context, ref, next, isError: true);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MasterLoginScreen()),
        (_) => false,
      );
    });

    // LAN listener: paired Kitchen Displays POST here when an order is marked
    // ready, flipping its local serviceStatus → drives the same badge offline.
    ref.watch(posKitchenServerProvider);

    // Count of orders the kitchen has marked ready — drives the nav badge.
    final readyCount = ref.watch(readyOrdersCountProvider).value ?? 0;

    // Active tab comes from the shared provider — tab switches are pure state
    // changes, never a MainLayout rebuild from a navigator push.
    final selectedIndex = ref.watch(mainNavigationIndexProvider);

    final settings = ref.watch(appSettingsProvider);
    final bookingEnabled =
        settings[SettingKeys.featureBookingEnabled]?.toLowerCase() == 'true';
    final floorPlanEnabled =
        settings[SettingKeys.featureFloorPlanEnabled]?.toLowerCase() == 'true';
    final company = ref.watch(selectedCompanyProvider);
    final companyName = company?.name ?? "Default Branch";

    // Render guard: tabs 2/3 (Bookings) and 4 (Floor Plan) collapse to an empty
    // `SizedBox.shrink` when their feature is off. If the active index points at
    // a disabled tab — e.g. a stale provider value or a direct initialIndex push
    // — the body would paint nothing (the "black screen"). Clamp to POS (0),
    // which is always renderable.
    bool isRenderable(int i) {
      if (i == 2 || i == 3) return bookingEnabled;
      if (i == 4) return floorPlanEnabled;
      return true;
    }

    final renderIndex = isRenderable(selectedIndex) ? selectedIndex : 0;

    final List<Widget> screens = [
      MenuScreen(showAppBarNavigation: true, onToggleSidebar: _openSidebar),
      OpenOrdersScreen(onMenuPressed: _openSidebar),
      bookingEnabled
          ? BookingsScreen(onMenuPressed: _openSidebar)
          : const SizedBox.shrink(),
      bookingEnabled
          ? BookingHistoryScreen(onMenuPressed: _openSidebar)
          : const SizedBox.shrink(),
      floorPlanEnabled
          ? FloorPlanScreen(onMenuPressed: _openSidebar)
          : const SizedBox.shrink(),
      EndOfDayScreen(onMenuPressed: _openSidebar),
      UserInfoScreen(onMenuPressed: _openSidebar),
    ];

    void handleNavTap(int index) {
      ref.read(mainNavigationIndexProvider.notifier).state = index;
      // Drawer behaviour: dismiss the sidebar the instant a tab is chosen.
      _closeSidebar();
    }

    Widget sidebar = Container(
      width: kSidebarW,
      color: context.navSidebarBg,
      child: SafeArea(
        child: Column(
          children: [
            NavSidebarHeader(name: companyName, onHideSidebar: _closeSidebar),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    NavItem(
                      icon: Icons.build_circle,
                      label: AppLocalizations.of(context).management,
                      onTap: () => ref.read(securityGuardProvider).guard(
                        context,
                        SecurityKeys.management,
                        () {
                          _closeSidebar();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManagementLayout(),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Divider(color: context.navDivider, height: 24),
                    ),

                    NavItem(
                      icon: Icons.point_of_sale,
                      label: AppLocalizations.of(context).posLabel,
                      isActive: selectedIndex == 0,
                      onTap: () => handleNavTap(0),
                    ),
                    NavItem(
                      icon: Icons.receipt_long,
                      label: AppLocalizations.of(context).viewSalesHistory,
                      isActive: selectedIndex == 99,
                      onTap: () => ref.read(securityGuardProvider).guard(
                        context,
                        SecurityKeys.salesHistory,
                        () {
                          _closeSidebar();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SalesHistoryScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    NavItem(
                      icon: Icons.layers,
                      label: AppLocalizations.of(context).viewOpenSales,
                      isActive: selectedIndex == 1,
                      trailing: readyCount > 0
                          ? _ReadyCountBadge(readyCount)
                          : null,
                      onTap: () => ref
                          .read(securityGuardProvider)
                          .guard(
                            context,
                            SecurityKeys.openOrders,
                            () => handleNavTap(1),
                          ),
                    ),
                    if (bookingEnabled)
                      NavItem(
                        icon: Icons.calendar_month,
                        label: AppLocalizations.of(context).posBookings,
                        isActive: selectedIndex == 2,
                        onTap: () => ref
                            .read(securityGuardProvider)
                            .guard(
                              context,
                              SecurityKeys.bookings,
                              () => handleNavTap(2),
                            ),
                      ),
                    if (bookingEnabled)
                      NavItem(
                        icon: Icons.history,
                        label: AppLocalizations.of(context).bookingHistory,
                        isActive: selectedIndex == 3,
                        onTap: () => ref
                            .read(securityGuardProvider)
                            .guard(
                              context,
                              SecurityKeys.bookingHistory,
                              () => handleNavTap(3),
                            ),
                      ),
                    if (floorPlanEnabled)
                      NavItem(
                        icon: Icons.grid_view,
                        label:
                            settings[SettingKeys.tablesButtonLabel] ??
                      AppLocalizations.of(context).tablesLabel,
                        isActive: selectedIndex == 4,
                        onTap: () => ref
                            .read(securityGuardProvider)
                            .guard(
                              context,
                              SecurityKeys.floorPlanView,
                              () => handleNavTap(4),
                            ),
                      ),

                    NavItem(
                      icon: Icons.schedule,
                      label: AppLocalizations.of(context).shiftManagement,
                      onTap: () => ref.read(securityGuardProvider).guard(
                        context,
                        SecurityKeys.shiftManagement,
                        () {
                          _closeSidebar();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ShiftManagementScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    NavItem(
                      icon: Icons.download,
                      label: AppLocalizations.of(context).cashInOut,
                      onTap: () => ref.read(securityGuardProvider).guard(
                        context,
                        SecurityKeys.cashMovement,
                        () {
                          _closeSidebar();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CashMovementScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    NavItem(
                      icon: Icons.credit_card,
                      label: AppLocalizations.of(context).creditPayments,
                      onTap: () => ref.read(securityGuardProvider).guard(
                        context,
                        SecurityKeys.creditPayments,
                        () {
                          _closeSidebar();
                          CreditPaymentsScreen.show(context);
                        },
                      ),
                    ),
                    NavItem(
                      icon: Icons.directions_run,
                      label: AppLocalizations.of(context).endOfDayLower,
                      isActive: selectedIndex == 5,
                      onTap: () => ref
                          .read(securityGuardProvider)
                          .guard(
                            context,
                            SecurityKeys.endOfDay,
                            () => handleNavTap(5),
                          ),
                    ),

                    const NavSectionLabel("User"),
                    // Live clocked-in status + today's total hours. Both widgets
                    // watch activeShiftProvider and self-hide when the employee
                    // has no open shift, so no startup-setting gate is needed.
                    const TimeClockStatusChip(),
                    const TotalHoursBadge(),
                    NavItem(
                      icon: Icons.person_outline,
                      label: AppLocalizations.of(context).userInfo,
                      isActive: selectedIndex == 6,
                      onTap: () => ref
                          .read(securityGuardProvider)
                          .guard(
                            context,
                            SecurityKeys.userProfile,
                            () => handleNavTap(6),
                          ),
                    ),
                    NavItem(
                      icon: Icons.logout,
                      label: AppLocalizations.of(context).signOut,
                      onTap: () {
                        ref.read(currentUserProvider.notifier).logout();
                        ref.invalidate(allUsersProvider);

                        _closeSidebar();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                    NavItem(
                      icon: Icons.campaign,
                      label: AppLocalizations.of(context).feedback,
                      onTap: () {},
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // BOTTOM HARDWARE BAR
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.navDivider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  NavIconButton(
                    icon: Icons.tune,
                    tooltip: AppLocalizations.of(context).quickSettings,
                    onTap: () => ref.read(securityGuardProvider).guard(
                      context,
                      SecurityKeys.settings,
                      () {
                        _closeSidebar();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SyncButton(),
                  if (!kIsWeb &&
                      (defaultTargetPlatform == TargetPlatform.windows ||
                          defaultTargetPlatform == TargetPlatform.macOS ||
                          defaultTargetPlatform == TargetPlatform.linux))
                    NavIconButton(
                      icon: Icons.fullscreen,
                      tooltip: AppLocalizations.of(context).fullScreen,
                      onTap: () async {
                        _closeSidebar();
                        final full = await windowManager.isFullScreen();
                        await windowManager.setFullScreen(!full);
                      },
                    ),
                  NavIconButton(
                    icon: Icons.power_settings_new,
                    tooltip: AppLocalizations.of(context).power,
                    onTap: () {
                      _closeSidebar();
                      showDialog(
                        context: context,
                        builder: (_) => const PowerModal(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.navScaffoldBg,
      // True overlay drawer on every form factor: the sidebar slides in over
      // the content rather than permanently squeezing the layout. The only way
      // to open it is the top-left hamburger (MenuScreen / OpenOrders app bar).
      drawer: Drawer(backgroundColor: context.navSidebarBg, child: sidebar),
      // The body is just the content — no permanent rail, no edge toggle.
      // Cached, instant tab switching (LazyIndexedStack keeps state).
      body: LazyIndexedStack(index: renderIndex, children: screens),
    );
  }
}
