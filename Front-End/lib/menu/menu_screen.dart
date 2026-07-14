import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/menu/open_orders_screen.dart';
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/product/product_provider.dart';
import 'package:pos_app/product/product_model.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/customer/customer_picker_dialog.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/stock/warehouse_model.dart';
import 'package:pos_app/stock/warehouse_picker_dialog.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/menu/discount_dialog.dart';
import 'package:pos_app/menu/quantity_keypad_dialog.dart';
import 'package:pos_app/product/product_group_model.dart';
import 'package:pos_app/product/product_group_provider.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/cart/payment_checkout_dialog.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/kitchen/kitchen_push_service.dart';
import 'package:pos_app/tax/tax_provider.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/promotions/promotion_provider.dart';
import 'package:pos_app/api/promotion_models.dart';
import 'package:pos_app/bookings/bookings_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/sync/sync_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/floor_plan/floor_plan_table.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/product/product_comment_model.dart';
// import 'package:pos_app/menu/open_orders_screen.dart';
import 'package:pos_app/printer/receipt_printer_service.dart';
import 'package:pos_app/printer/printer_routing_service.dart';
import 'package:pos_app/refund/refund_dialog.dart';
import 'package:pos_app/security/security_guard.dart';
import 'package:pos_app/security/security_keys.dart';
import 'package:pos_app/utils/error_handler.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:pos_app/utils/scale_barcode_parser.dart';
import 'package:pos_app/customer_display/customer_display_provider.dart';
import 'package:pos_app/stock/stock_provider.dart';
import 'package:pos_app/stock/stock_control_provider.dart';
import 'package:pos_app/stock/stock_control_model.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/settings/local_ui_prefs.dart';

final currentGroupProvider = StateProvider<ProductGroup?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => "");

// --- MAIN SCREEN ---
class MenuScreen extends ConsumerStatefulWidget {
  final bool showAppBarNavigation;
  final VoidCallback? onToggleSidebar;

  const MenuScreen({
    super.key,
    this.showAppBarNavigation = false,
    this.onToggleSidebar,
  });

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  List<PromotionDto> _activePromos = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final company = ref.read(selectedCompanyProvider);
      if (company != null) {
        final hasActiveOrder = ref.read(cartProvider).activePosOrderId != null;
        if (!hasActiveOrder) {
          syncLatestOrderNumber(ref, company.id);
        }
        // Refresh the local stock + warehouse cache so the menu's offline-first
        // availability checks reflect changes made elsewhere (e.g. the Stock
        // screen, which still edits via the API). Best-effort — offline, the
        // existing Drift cache is used.
        final sm = ref.read(syncManagerProvider);
        sm.pullStocks(company.id).catchError((_) {});
        sm.pullWarehouses(company.id).catchError((_) {});
      }
      final promos = ref.read(activePromotionsProvider).value;
      if (promos != null && mounted) {
        setState(() => _activePromos = promos);
      }
    });
  }

  /// Small popup listing the currently-active promotions and the products each
  /// one applies to — reads from in-memory `_activePromos` + the local product
  /// cache, so it's instant and offline.
  void _showActivePromosPopup(BuildContext context) {
    final products = ref.read(allProductsListProvider).value ?? const [];
    final nameById = {for (final p in products) p.id: p.name};

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.star, color: ctx.warningColor),
              const SizedBox(width: 8),
              const Text('Active Promotions'),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: _activePromos.isEmpty
                ? const Text('No active promotions right now.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _activePromos.map((promo) {
                      final productNames = promo.items
                          .map((i) => nameById[i.productId])
                          .whereType<String>()
                          .toList();
                      final subtitle = productNames.isEmpty
                          ? 'No specific products assigned'
                          : productNames.join(', ');
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.local_offer,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(promo.name),
                        subtitle: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Narrow the cart dependency: this header shell only re-renders when a field
    // it actually shows changes (service type/status, the selected line, the
    // empty-state, the active order) — NOT on every item add / quantity / discount
    // edit, which the CartSection owns. cartState is read (not watched) so the
    // render conditions below stay fresh via that rebuild; the tap handlers read
    // the live cart via ref.read so they never act on stale state.
    ref.watch(cartProvider.select((c) => (
          c.serviceType,
          c.serviceStatus,
          c.selectedCartItemId,
          c.items.isEmpty,
          c.activePosOrderId,
        )));
    final cartState = ref.read(cartProvider);
    final currentCustomer = ref.watch(currentCustomerProvider);
    final asyncCustomers = ref.watch(allCustomersProvider);
    final settings = ref.watch(appSettingsProvider);
    final bookingEnabled =
        settings[SettingKeys.featureBookingEnabled]?.toLowerCase() == 'true';
    final floorPlanEnabled =
        settings[SettingKeys.featureFloorPlanEnabled]?.toLowerCase() == 'true';
    final serviceTypeEnabled =
        settings[SettingKeys.featureServiceTypeEnabled]?.toLowerCase() ==
        'true';
    final serviceStatusEnabled =
        settings[SettingKeys.featureServiceStatusEnabled]?.toLowerCase() ==
        'true';
    final customServiceTypes = ref
        .read(appSettingsProvider.notifier)
        .customServiceTypes;
    final customServiceStatuses = ref
        .read(appSettingsProvider.notifier)
        .customServiceStatuses;
    final showCustomerBtn =
        settings[SettingKeys.showCustomerBtn]?.toLowerCase() != 'false';
    final showDiscountBtn =
        settings[SettingKeys.showDiscountBtn]?.toLowerCase() != 'false';
    final showTransferBtn =
        settings[SettingKeys.showTransferBtn]?.toLowerCase() != 'false';
    final showRefundBtn =
        settings[SettingKeys.showRefundBtn]?.toLowerCase() != 'false';
    final showWarehouseBtn =
        settings[SettingKeys.showWarehouseBtn]?.toLowerCase() != 'false';
    final showBookingBtn =
        settings[SettingKeys.showBookingBtn]?.toLowerCase() != 'false';
    final showTablesBtn =
        settings[SettingKeys.showTablesBtn]?.toLowerCase() != 'false';
    final showKitchenBtn =
        settings[SettingKeys.showKitchenBtn]?.toLowerCase() != 'false';
    final showTaxBtn =
        settings[SettingKeys.showTaxBtn]?.toLowerCase() != 'false';
    final showQuantityBtn =
        settings[SettingKeys.showQuantityBtn]?.toLowerCase() != 'false';
    ref.listen(allCustomersProvider, (previous, next) {
      next.whenData((all) {
        final customers = all.where((c) => c.isCustomer).toList();
        final currentCartCustomer = ref.read(cartProvider).selectedCustomer;
        if (currentCartCustomer == null && customers.isNotEmpty) {
          final walkIn = customers.firstWhere(
            (c) => c.code == 'C000',
            orElse: () => customers.first,
          );
          final companyId = ref.read(selectedCompanyProvider)?.id;
          if (companyId != null) {
            ref.read(cartProvider.notifier).setCustomer(companyId, walkIn);
          }
        }
      });
    });

    // Sync daily order counter when company changes mid-session
    ref.listen(selectedCompanyProvider, (previous, next) {
      if (next != null && previous?.id != next.id) {
        final hasActiveOrder = ref.read(cartProvider).activePosOrderId != null;
        if (!hasActiveOrder) {
          syncLatestOrderNumber(ref, next.id);
        }
      }
    });

    // Watch (not just listen) so the "active promotions" banner reflects the
    // already-resolved value on first build, not only on later changes.
    _activePromos = ref.watch(activePromotionsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 62,
        automaticallyImplyLeading: false,
        leading: widget.showAppBarNavigation
            ? IconButton(
                icon: Icon(
                  Icons.menu,
                  size: 26,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: widget.onToggleSidebar,
              )
            : null,
        title: widget.showAppBarNavigation
            ? Text(
                ref.watch(selectedCompanyProvider)?.name ?? 'Branch',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              )
            : null,
        actions: [
          // --- Kitchen-ready notification ---
          // Persistent badge: appears when the KDS marks one or more orders
          // ready. Tapping it jumps to the Open Orders tab.
          Builder(
            builder: (context) {
              final readyCount = ref.watch(readyOrdersCountProvider).value ?? 0;
              if (readyCount == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  tooltip: '$readyCount order(s) ready',
                  onPressed: () =>
                      ref.read(mainNavigationIndexProvider.notifier).state = 1,
                  icon: Badge.count(
                    count: readyCount,
                    child: Icon(
                      Icons.notifications_active,
                      size: 26,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            },
          ),
          // --- Order Controls ---
          SizedBox(
            height: 60,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (showCustomerBtn)
                    asyncCustomers.when(
                      loading: () => const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (all) {
                        final customers = all
                            .where((c) => c.isCustomer)
                            .toList();
                        return _MenuHeaderActionBtn(
                          // Reflect live state: show the selected customer's
                          // name (highlighted) instead of a generic label.
                          icon: currentCustomer != null
                              ? Icons.person
                              : Icons.person_outline,
                          label: currentCustomer?.name ?? 'Customer',
                          active: currentCustomer != null,
                          onTap: () async {
                            final selected = await showCustomerPickerDialog(
                              context,
                              customers,
                              selectedId: ref
                                  .read(cartProvider)
                                  .selectedCustomer
                                  ?.id,
                            );
                            if (selected == null || !context.mounted) return;
                            ref
                                .read(currentCustomerProvider.notifier)
                                .setCustomer(selected);
                            final companyId = ref
                                .read(selectedCompanyProvider)
                                ?.id;
                            if (companyId != null) {
                              ref
                                  .read(cartProvider.notifier)
                                  .setCustomer(companyId, selected);
                            }
                          },
                        );
                      },
                    ),
                  // ── Dynamic Order Type button (unified shape) ──────────
                  if (serviceTypeEnabled)
                    _MenuHeaderActionBtn(
                      icon: Icons.restaurant_menu,
                      label:
                          customServiceTypes
                              .where((t) => t.id == cartState.serviceType)
                              .map((t) => t.name)
                              .firstOrNull ??
                          'Order Type',
                      customTint:
                          _kOrderTypePalette[customServiceTypes
                              .indexWhere((t) => t.id == cartState.serviceType)
                              .clamp(0, _kOrderTypePalette.length - 1)],
                      onTap: () async {
                        final val = await showDialog<int>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Select Order Type'),
                            contentPadding: const EdgeInsets.fromLTRB(
                              16,
                              16,
                              16,
                              16,
                            ),
                            content: SizedBox(
                              width: 500,
                              child: Row(
                                children: customServiceTypes
                                    .asMap()
                                    .entries
                                    .expand(
                                      (e) => [
                                        if (e.key > 0)
                                          const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, e.value.id),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  _kOrderTypePalette[e.key %
                                                      _kOrderTypePalette
                                                          .length],
                                              minimumSize: const Size(0, 100),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                    horizontal: 8,
                                                  ),
                                            ),
                                            child: Text(
                                              e.value.name,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        );
                        if (val == null) return;
                        final companyId = ref.read(selectedCompanyProvider)?.id;
                        if (val != 0) {
                          if (companyId != null) {
                            await ref
                                .read(cartProvider.notifier)
                                .clearFloorPlanTable(val, companyId: companyId);
                          }
                          if (ref.read(cartProvider).activePosOrderId == null) {
                            final user = ref.read(currentUserProvider);
                            if (companyId != null && user != null) {
                              try {
                                await ref
                                    .read(cartProvider.notifier)
                                    .startTablelessOrder(
                                      ApiClient(),
                                      companyId,
                                      user.id,
                                      val,
                                    );
                              } catch (e) {
                                if (context.mounted) {
                                  showAppSnackbar(
                                    context,
                                    ref,
                                    friendlyErrorMessage(e),
                                    isError: true,
                                  );
                                }
                              }
                            }
                          }
                        } else {
                          final cart = ref.read(cartProvider);
                          final floorPlanOn =
                              ref
                                  .read(
                                    appSettingsProvider,
                                  )[SettingKeys.featureFloorPlanEnabled]
                                  ?.toLowerCase() ==
                              'true';

                          if (cart.floorPlanTableId == null && floorPlanOn) {
                            if (!context.mounted) return;
                            final selectedSpace =
                                await showDialog<FloorPlanTable>(
                                  context: context,
                                  builder: (_) =>
                                      const _SelectAvailableSpaceDialog(),
                                );
                            if (selectedSpace == null) return;
                            if (!context.mounted) return;

                            final cId = ref.read(selectedCompanyProvider)?.id;
                            final uId = ref.read(currentUserProvider)?.id ?? 0;
                            if (cId == null) return;

                            final newOrderNumber = 'ORD- ${selectedSpace.name}';

                            await ApiClient().updatePosOrder(cId, {
                              'id': cart.activePosOrderId,
                              'userId': uId,
                              'number': newOrderNumber,
                              'floorPlanTableId': selectedSpace.id,
                              'serviceType': 0,
                              'serviceStatus': cart.serviceStatus,
                              'discount': cart.manualCartDiscount,
                              'discountType': cart.manualCartDiscountType,
                              'total': ref.read(cartTotalProvider),
                              'customerId': cart.selectedCustomer?.id,
                              'warehouseId': cart.activeWarehouseId ?? 1,
                            });
                            ref.read(kitchenSyncProvider).push();

                            if (!context.mounted) return;

                            ref
                                .read(cartProvider.notifier)
                                .setOrderContext(
                                  cart.activePosOrderId!,
                                  cart.activeWarehouseId ?? 1,
                                  tableId: selectedSpace.id,
                                  orderNumber: newOrderNumber,
                                );
                            ref
                                .read(cartProvider.notifier)
                                .setServiceType(0, regenerateOrderName: false);
                          } else {
                            ref.read(cartProvider.notifier).setServiceType(val);
                          }
                        }
                      },
                    ),
                  // ── Dynamic Service Status button (unified shape) ──────
                  if (serviceStatusEnabled)
                    _MenuHeaderActionBtn(
                      icon: Icons.label,
                      label:
                          customServiceStatuses
                              .where((s) => s.id == cartState.serviceStatus)
                              .map((s) => s.name)
                              .firstOrNull ??
                          'Status #${cartState.serviceStatus}',
                      customTint:
                          customServiceStatuses
                              .where((s) => s.id == cartState.serviceStatus)
                              .map((s) => s.color)
                              .firstOrNull ??
                          Theme.of(context).colorScheme.primary,
                      onTap: () {
                        showDialog<int>(
                          context: context,
                          builder: (ctx) {
                            if (customServiceStatuses.isEmpty) {
                              return AlertDialog(
                                title: const Text('Service Status'),
                                content: const Text(
                                  'No service statuses configured.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  ),
                                ],
                              );
                            }
                            return AlertDialog(
                              title: const Text('Select Service Status'),
                              contentPadding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                16,
                              ),
                              content: SizedBox(
                                width: 500,
                                child: Row(
                                  children: customServiceStatuses
                                      .asMap()
                                      .entries
                                      .expand((e) {
                                        final s = e.value;
                                        return [
                                          if (e.key > 0)
                                            const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, s.id),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: s.color,
                                                minimumSize: const Size(0, 100),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                      horizontal: 8,
                                                    ),
                                              ),
                                              child: Text(
                                                s.name,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ];
                                      })
                                      .toList(),
                                ),
                              ),
                            );
                          },
                        ).then((val) {
                          if (val != null) {
                            ref.read(cartProvider.notifier).setServiceStatus(val);
                          }
                        });
                      },
                    ),
                  if (showDiscountBtn)
                    _MenuHeaderActionBtn(
                      icon: Icons.percent,
                      label: 'Discount',
                      onTap: () => ref
                          .read(securityGuardProvider)
                          .guard(
                            context,
                            SecurityKeys.applyDiscount,
                            () => showDialog(
                              context: context,
                              builder: (_) => const DiscountDialog(),
                            ),
                          ),
                    ),
                  if (showQuantityBtn)
                    _MenuHeaderActionBtn(
                      icon: Icons.dialpad,
                      label: 'Quantity',
                      // Greyed out until a cart line is selected — same gating
                      // the Tax button uses.
                      onTap: cartState.selectedCartItemId == null
                          ? null
                          : () async {
                              final cart = ref.read(cartProvider);
                              final item = cart.items
                                  .where(
                                    (i) =>
                                        i.cartItemId == cart.selectedCartItemId,
                                  )
                                  .firstOrNull;
                              if (item == null) {
                                showAppSnackbar(
                                  context,
                                  ref,
                                  'Selected item not found.',
                                  isError: true,
                                );
                                return;
                              }
                              final newQty = await showQuantityKeypad(
                                context,
                                itemName: item.productName,
                                initialQuantity: item.quantity,
                                unit: item.measurementUnit,
                              );
                              if (newQty == null || !context.mounted) return;
                              if (newQty < 0) {
                                showAppSnackbar(
                                  context,
                                  ref,
                                  'Quantity cannot be negative.',
                                  isError: true,
                                );
                                return;
                              }
                              ref
                                  .read(cartProvider.notifier)
                                  .updateItemQuantity(item.cartItemId, newQty);
                            },
                    ),
                  if (showTaxBtn)
                    _MenuHeaderActionBtn(
                      icon: Icons.receipt,
                      label: 'Tax',
                      onTap: () => ref.read(securityGuardProvider).guard(
                        context,
                        SecurityKeys.taxOverride,
                        () {
                          final cart = ref.read(cartProvider);
                          final selectedCartItemId = cart.selectedCartItemId;
                          if (selectedCartItemId == null) {
                            showAppSnackbar(
                              context,
                              ref,
                              'Please select an item first',
                              isError: true,
                            );
                            return;
                          }
                          final item = cart.items
                              .where((i) => i.cartItemId == selectedCartItemId)
                              .firstOrNull;
                          if (item == null) {
                            showAppSnackbar(
                              context,
                              ref,
                              'Please add a product to the cart and select it',
                              isError: true,
                            );
                            return;
                          }
                          showDialog(
                            context: context,
                            builder: (_) => _ItemTaxDialog(item: item),
                          );
                        },
                      ),
                    ),
                  if (showTransferBtn)
                    _MenuHeaderActionBtn(
                      icon: Icons.swap_horiz,
                      label: 'Transfer',
                      onTap: cartState.activePosOrderId == null
                          ? null
                          : () => ref
                                .read(securityGuardProvider)
                                .guard(
                                  context,
                                  SecurityKeys.orderTransfer,
                                  () => showDialog(
                                    context: context,
                                    builder: (_) => _TransferDialog(
                                      cartState: ref.read(cartProvider),
                                    ),
                                  ),
                                ),
                    ),
                  if (showRefundBtn)
                    _MenuHeaderActionBtn(
                      icon: Icons.undo,
                      label: 'Refund',
                      onTap: () => ref
                          .read(securityGuardProvider)
                          .guard(
                            context,
                            SecurityKeys.refund,
                            () => showDialog(
                              context: context,
                              builder: (_) => const RefundDialog(),
                            ),
                          ),
                    ),

                  if (showKitchenBtn)
                    _MenuHeaderActionBtn(
                      icon: Icons.soup_kitchen,
                      label: 'Kitchen',
                      onTap: cartState.items.isEmpty
                          ? null
                          : () async {
                              try {
                                final roleSettings = ref.read(
                                  appSettingsProvider,
                                );
                                final cashier = ref.read(currentUserProvider);
                                final cart = ref.read(cartProvider);
                                final cartItems = cart.items;
                                final serviceLabel =
                                    switch (cart.serviceType) {
                                      0 => 'Dine In',
                                      1 => 'Takeaway',
                                      _ => 'Order',
                                    };
                                final roundNum = cartItems.isNotEmpty
                                    ? cartItems.first.roundNumber
                                    : 1;
                                final orderNo = cart.orderNumber ?? 'WALK-IN';
                                final cashierName =
                                    cashier?.displayName ?? 'Unknown';

                                // If any printer has "Print kitchen ticket" on,
                                // split the order across those printers by
                                // category (food→kitchen, drinks→bar). Otherwise
                                // fall back to the legacy single all-items ticket
                                // on the Kitchen printer — unchanged behaviour
                                // until the operator opts printers in.
                                final routing =
                                    ref.read(printerRoutingProvider);
                                if (routing.hasKitchenStations) {
                                  await routing.printStationTickets(
                                    items: cartItems,
                                    orderNumber: orderNo,
                                    cashierName: cashierName,
                                    serviceType: serviceLabel,
                                    roundNumber: roundNum,
                                    printTime: DateTime.now(),
                                  );
                                } else {
                                  await ReceiptPrinterService()
                                      .printKitchenTicket(
                                        orderNumber: orderNo,
                                        cashierName: cashierName,
                                        serviceType: serviceLabel,
                                        roundNumber: roundNum,
                                        printTime: DateTime.now(),
                                        items: cartItems,
                                        roleSettings: roleSettings,
                                      );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  showAppSnackbar(
                                    context,
                                    ref,
                                    'Kitchen print error: $e',
                                    isError: true,
                                  );
                                }
                              }
                            },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // --- Warehouse Switcher (centered picker, like the customer one) ---
          if (showWarehouseBtn)
            Consumer(
              builder: (context, ref, child) {
                final selectedWarehouse = ref.watch(selectedWarehouseProvider);
                final warehousesAsync = ref.watch(allWarehousesProvider);

                return _MenuHeaderActionBtn(
                  icon: Icons.warehouse,
                  label: selectedWarehouse?.name ?? 'Warehouse',
                  active: selectedWarehouse != null,
                  onTap: () async {
                    final list =
                        warehousesAsync.value ?? const <Warehouse>[];
                    final selected = await showWarehousePickerDialog(
                      context,
                      list,
                      selectedId: selectedWarehouse?.id,
                    );
                    if (selected == null || !context.mounted) return;
                    ref.read(selectedWarehouseProvider.notifier).state =
                        selected;
                  },
                );
              },
            ),

          if (bookingEnabled && showBookingBtn)
            _MenuHeaderActionBtn(
              icon: Icons.calendar_month,
              label: 'Bookings',
              onTap: () {
                ref.read(cartProvider.notifier).clearCart();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MainLayout(initialIndex: 2),
                  ), // Index 2 is Bookings
                  (route) => false,
                );
              },
            ),
          if (floorPlanEnabled && showTablesBtn)
            _MenuHeaderActionBtn(
              icon: Icons.grid_view,
              label: settings[SettingKeys.tablesButtonLabel] ?? 'Tables',
              onTap: () async {
                final cart = ref.read(cartProvider);
                final companyId = ref.read(selectedCompanyProvider)?.id;

                if (cart.items.isEmpty) {
                  if (cart.activePosOrderId != null && companyId != null) {
                    try {
                      await ApiClient().deletePosOrder(
                        companyId,
                        cart.activePosOrderId!,
                        cart.activeWarehouseId ??
                            ref.read(selectedWarehouseProvider)?.id ??
                            1,
                      );
                      ref.read(kitchenSyncProvider).push();
                    } catch (_) {}
                  }
                  ref.read(cartProvider.notifier).clearCart();
                } else {
                  if (companyId != null) {
                    final user = ref.read(currentUserProvider);
                    try {
                      await ref
                          .read(cartProvider.notifier)
                          .saveAndSuspend(
                            apiClient: ApiClient(),
                            companyId: companyId,
                            userId: user?.id ?? 0,
                          );
                    } catch (e) {
                      if (context.mounted) {
                        showAppSnackbar(
                          context,
                          ref,
                          'Could not save order: $e',
                          isError: true,
                        );
                      }
                      return;
                    }
                  }
                }

                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MainLayout(initialIndex: 4),
                    ),
                    (route) => false,
                  );
                }
              },
            ),

          // Promotion — special override action, pinned to the far right. Amber
          // star icon with a count badge.
          if (_activePromos.isNotEmpty)
            _MenuHeaderActionBtn(
              icon: Icons.star,
              label: 'Promos',
              iconColor: context.warningColor,
              badgeCount: _activePromos.length,
              onTap: () => _showActivePromosPopup(context),
            ),

          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const BrowserSection(),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              final currentWidth = ref.read(cartWidthProvider);
              final screenWidth = MediaQuery.of(context).size.width;
              final maxWidth = screenWidth * 0.5;
              double newWidth = currentWidth - details.delta.dx;
              if (newWidth < 250) newWidth = 250;
              if (newWidth > maxWidth) newWidth = maxWidth;
              // Live in-memory update during the drag.
              ref.read(cartWidthProvider.notifier).set(newWidth);
            },
            // Flush to on-device storage once the drag settles (one write per
            // resize). Stored locally — not cloud-synced — so resizing here
            // never changes the layout on another terminal.
            onHorizontalDragEnd: (_) {
              ref.read(cartWidthProvider.notifier).persist();
            },
            child: const MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: SizedBox(
                width: 8,
                child: VerticalDivider(width: 8, thickness: 1),
              ),
            ),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: SizedBox(
              width: ref.watch(cartWidthProvider),
              child: const CartSection(),
            ),
          ),
        ],
      ),
    );
  }
}

// Colour palette cycled by order-type index (no colour in the JSON for order types).
const _kOrderTypePalette = [
  Colors.indigo,
  Colors.deepOrange,
  Colors.green,
  Colors.purple,
  Colors.teal,
  Colors.brown,
];

class BrowserSection extends ConsumerStatefulWidget {
  const BrowserSection({super.key});

  @override
  ConsumerState<BrowserSection> createState() => _BrowserSectionState();
}

class _BrowserSectionState extends ConsumerState<BrowserSection> {
  int _currentPage = 0;
  List<PromotionDto> _activePromos = const [];
  Map<int, double> _stockMap = const {};
  Map<int, StockControl> _stockControlMap = const {};
  String? _activeSearchMode;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Called when the search field is submitted (e.g. barcode scanner sends Enter).
  /// Tries scale-barcode parsing first; falls back to exact barcode lookup.
  /// On a match the item is added to the cart and the search field is cleared.
  Future<void> _handleBarcodeSubmit(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    final settings = ref.read(appSettingsProvider);
    final allProducts = ref.read(allProductsListProvider).value ?? [];

    final scaleData = parseScaleBarcode(trimmed, settings);

    Product? match;
    double quantity;

    if (scaleData != null) {
      // Scale barcode path: look up by product code or barcode field
      match = allProducts.where((p) {
        if (!p.isEnabled) return false;
        final code = scaleData.productCode.toLowerCase();
        return (p.code?.toLowerCase() == code) ||
            p.barcodes.any((b) => b.toLowerCase() == code);
      }).firstOrNull;

      if (match == null) {
        if (mounted) {
          showAppSnackbar(
            context,
            ref,
            'Scale barcode: product "${scaleData.productCode}" not found.',
            isError: true,
          );
        }
        return;
      }

      if (scaleData.isPrice) {
        final unitPrice = match.price;
        if (unitPrice <= 0) {
          if (mounted) {
            showAppSnackbar(
              context,
              ref,
              'Cannot calculate quantity: unit price is zero.',
              isError: true,
            );
          }
          return;
        }
        quantity = scaleData.parsedValue / unitPrice;
      } else {
        quantity = scaleData.parsedValue;
      }

      if (quantity <= 0) {
        if (mounted) {
          showAppSnackbar(
            context,
            ref,
            'Parsed quantity is zero — check scale barcode configuration.',
            isError: true,
          );
        }
        return;
      }
    } else {
      // Standard barcode path: exact match only; non-match leaves search text intact
      match = allProducts
          .where(
            (p) =>
                p.isEnabled &&
                p.barcodes.any((b) => b.toLowerCase() == trimmed.toLowerCase()),
          )
          .firstOrNull;
      if (match == null) return;
      quantity = 1.0;
    }

    // Ensure an active order exists (same logic as product-card tap)
    final cartState = ref.read(cartProvider);
    if (cartState.activePosOrderId == null) {
      final floorPlanOn =
          settings[SettingKeys.featureFloorPlanEnabled]?.toLowerCase() ==
          'true';
      if (cartState.serviceType != 0 || !floorPlanOn) {
        final companyId = ref.read(selectedCompanyProvider)?.id;
        final user = ref.read(currentUserProvider);
        if (companyId == null || user == null) return;
        try {
          await ref
              .read(cartProvider.notifier)
              .startTablelessOrder(
                ApiClient(),
                companyId,
                user.id,
                cartState.serviceType,
              );
        } catch (e) {
          if (!mounted) return;
          showAppSnackbar(
            context,
            ref,
            'Error creating order: $e',
            isError: true,
          );
          return;
        }
      } else {
        if (mounted) {
          showAppSnackbar(
            context,
            ref,
            'Please select a table first!',
            isError: true,
          );
        }
        return;
      }
    }

    // Offline stock validation: hard-block negative inventory and warn on low
    // stock (acknowledgement required) before the item reaches the cart.
    if (!await _passesStockGuards(match, quantity)) return;

    // Age restriction check
    if (match.ageRestriction != null) {
      if (!mounted) return;
      final confirmed = await _showAgeRestrictionDialog(
        context,
        match.ageRestriction!,
      );
      if (!confirmed || !mounted) return;
    }

    // Resolve the product's assigned taxes so a scanned/searched item carries
    // its tax just like a tapped one.
    final productTaxes = await ref
        .read(cartProvider.notifier)
        .resolveProductTaxes(match.id);
    if (!mounted) return;

    // Add to cart and clear the search bar
    try {
      final menuProduct = MenuProduct(
        id: match.id,
        name: match.name,
        price: match.price,
        cost: match.cost,
        isTaxInclusivePrice: match.isTaxInclusivePrice,
        color: match.color,
        stockQuantity: 9999,
        taxes: productTaxes,
        isEnabled: match.isEnabled,
        ageRestriction: match.ageRestriction,
        isPriceChangeAllowed: match.isPriceChangeAllowed,
        isUsingDefaultQuantity: match.isUsingDefaultQuantity,
        measurementUnit: match.measurementUnit,
        isService: match.isService,
      );
      ref
          .read(cartProvider.notifier)
          .addItem(
            menuProduct,
            quantity: quantity,
            measurementUnit: match.measurementUnit,
          );
      _searchCtrl.clear();
      ref.read(searchQueryProvider.notifier).state = '';
    } catch (e) {
      if (mounted) {
        showAppSnackbar(
          context,
          ref,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  void _sortProducts(List<Product> products, String sortBy) {
    if (sortBy == 'Code') {
      products.sort((a, b) => (a.code ?? '').compareTo(b.code ?? ''));
    } else if (sortBy == 'Barcode') {
      products.sort(
        (a, b) => (a.barcodes.firstOrNull ?? '').compareTo(
          b.barcodes.firstOrNull ?? '',
        ),
      );
    } else {
      products.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  /// Synchronous, offline-first stock validation run the instant a product is
  /// tapped to be added to the cart. Reads live local stock ([_stockMap]) and the
  /// per-product control rules ([_stockControlMap]) — both seeded reactively in
  /// [build] from Drift — so it works with zero network access.
  ///
  /// Returns `true` if the item may be added, `false` if the add must be aborted.
  ///
  ///  * Projected qty = current local stock − qty already in the cart − this tap.
  ///  * Hard block: if "Prevent Negative Inventory" is on and the projection goes
  ///    below zero, the add is blocked outright.
  ///  * Soft warning: if a low-stock rule is enabled and the projection hits the
  ///    threshold, the cashier must explicitly acknowledge before proceeding.
  Future<bool> _passesStockGuards(Product product, double quantity) async {
    if (product.isService) return true;

    final settings = ref.read(appSettingsProvider);
    final currentStock = _stockMap[product.id] ?? 0;
    final cartQty = ref
        .read(cartProvider)
        .items
        .where((i) => i.productId == product.id)
        .fold(0.0, (sum, i) => sum + i.quantity);
    final projectedQuantity = currentStock - cartQty - quantity;

    // Hard block — negative inventory is not permitted.
    final preventNegInv =
        settings[SettingKeys.preventNegativeInventory]?.toLowerCase() == 'true';
    if (preventNegInv && projectedQuantity < 0) {
      if (context.mounted) await _showOutOfStockDialog(product);
      return false;
    }

    // Soft warning — running low against the configured threshold.
    final rule = _stockControlMap[product.id];
    if (rule != null && rule.isLowStockAt(projectedQuantity)) {
      if (!context.mounted) return false;
      return _showLowStockWarningDialog(product, projectedQuantity);
    }

    return true;
  }

  /// Flat, low-overhead warning the cashier must acknowledge when a tapped item
  /// would drop to/below its low-stock threshold. Returns `true` to proceed.
  Future<bool> _showLowStockWarningDialog(
    Product product,
    double projectedQuantity,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.navSidebarBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.navDivider, width: 1),
        ),
        icon: PhosphorIcon(
          PhosphorIconsRegular.warning,
          color: cs.error,
          size: 32,
        ),
        title: Text('${product.name} is running low'),
        content: Text(
          'Adding this item leaves only ${_fmtQty(projectedQuantity)} '
          '${product.measurementUnit ?? 'unit(s)'} in stock, at or below the '
          'low-stock warning level.\n\nAdd it anyway?',
          style: tt.bodyMedium?.copyWith(color: context.navMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed Anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Shown when a product can't be added because the selected warehouse is out
  /// of stock. Lists the other warehouses that still hold the product and lets
  /// the user switch the active warehouse to one of them in a single tap.
  Future<void> _showOutOfStockDialog(Product product) async {
    final cs = Theme.of(context).colorScheme;
    final byWarehouse =
        ref.read(stockByWarehouseProvider).value ??
        const <int, Map<int, double>>{};
    final warehouses = ref.read(allWarehousesProvider).value ?? const [];
    final selectedWh = ref.read(selectedWarehouseProvider);
    final whNames = {for (final w in warehouses) w.id: w.name};

    final fallbacks =
        (byWarehouse[product.id] ?? const <int, double>{}).entries
            .where((e) => e.value > 0 && e.key != selectedWh?.id)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final tt = Theme.of(ctx).textTheme;
        return AlertDialog(
          icon: PhosphorIcon(
            PhosphorIconsRegular.warningCircle,
            color: cs.error,
            size: 32,
          ),
          title: Text('${product.name} is out of stock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No stock available in ${selectedWh?.name ?? 'the selected warehouse'}.',
                style: tt.bodyMedium,
              ),
              const Gap(16),
              if (fallbacks.isEmpty)
                Text(
                  'This product is not available in any other warehouse.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                )
              else ...[
                Text('Available in:', style: tt.labelLarge),
                const Gap(8),
                ...fallbacks.map(
                  (e) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    child: ListTile(
                      leading: PhosphorIcon(
                        PhosphorIconsRegular.warehouse,
                        color: cs.primary,
                      ),
                      title: Text(whNames[e.key] ?? 'Warehouse ${e.key}'),
                      subtitle: Text('${_fmtQty(e.value)} in stock'),
                      trailing: FilledButton.tonal(
                        onPressed: () {
                          ref.read(cartProvider.notifier).setWarehouseId(e.key);
                          Navigator.pop(ctx);
                          showAppSnackbar(
                            context,
                            ref,
                            'Switched to ${whNames[e.key] ?? 'warehouse'} — tap the product to add it.',
                            isError: false,
                          );
                        },
                        child: const Text('Switch'),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentGroupProvider, (_, __) {
      if (mounted) setState(() => _currentPage = 0);
    });
    ref.listen(searchQueryProvider, (_, __) {
      if (mounted) setState(() => _currentPage = 0);
    });
    // Watch (don't just listen): ref.listen never delivers the provider's
    // already-resolved value, so when promotions/stock were loaded before this
    // grid mounted (the parent keeps them alive), the listener never fired and
    // the promo star / stock badge never appeared. Reading the current value
    // here seeds them on first build and refreshes on every change.
    _activePromos = ref.watch(activePromotionsProvider).value ?? const [];
    _stockMap = ref.watch(stockQuantitiesProvider).value ?? const {};
    // Per-product stock-control rules (reorder point, low-stock threshold) read
    // straight from the offline Drift cache so the add-to-cart guards below can
    // evaluate them synchronously without a network/async round-trip.
    _stockControlMap = ref.watch(stockControlsMapProvider).value ?? const {};

    final asyncGroups = ref.watch(allProductGroupsProvider);
    final asyncProducts = ref.watch(allProductsListProvider);
    final currentGroup = ref.watch(currentGroupProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final selectedCompany = ref.watch(selectedCompanyProvider);
    final settings = ref.watch(appSettingsProvider);

    if (selectedCompany == null) {
      return const Center(
        child: Text("No company selected. Open the menu and pick a company."),
      );
    }
    if (asyncGroups.isLoading || asyncProducts.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (asyncGroups.hasError || asyncProducts.hasError) {
      return const Center(child: Text("Error loading data"));
    }

    final allGroups = asyncGroups.value ?? [];
    final allProducts = asyncProducts.value ?? [];

    List<dynamic> itemsToDisplay = [];
    bool isSearching = searchQuery.isNotEmpty;

    final effectiveMode =
        _activeSearchMode ?? settings[SettingKeys.defaultSearch] ?? 'Name';
    final showSearchOptions =
        settings[SettingKeys.showSearchOptions]?.toLowerCase() != 'false';

    final sortBy = settings[SettingKeys.productSorting] ?? 'Name';
    if (isSearching) {
      final List<Product> filtered = allProducts.where((p) {
        if (!p.isEnabled) return false;
        final query = searchQuery.toLowerCase();
        switch (effectiveMode) {
          case 'Code':
            return p.code?.toLowerCase().contains(query) ?? false;
          case 'Barcode':
            return p.barcodes.any((b) => b.toLowerCase().contains(query));
          case 'All fields':
            return p.name.toLowerCase().contains(query) ||
                (p.code?.toLowerCase().contains(query) ?? false) ||
                p.barcodes.any((b) => b.toLowerCase().contains(query));
          case 'Name':
          default:
            return p.name.toLowerCase().contains(query);
        }
      }).toList();
      _sortProducts(filtered, sortBy);
      itemsToDisplay = filtered;
    } else {
      final visibleGroups = allGroups
          .where((g) => g.parentGroupId == currentGroup?.id)
          .toList();
      final List<Product> visibleProducts = allProducts
          .where((p) => p.productGroupId == currentGroup?.id && p.isEnabled)
          .toList();
      _sortProducts(visibleProducts, sortBy);
      itemsToDisplay = [...visibleGroups, ...visibleProducts];
    }

    final showSearchBtn =
        settings[SettingKeys.showSearchBtn]?.toLowerCase() != 'false';
    final cols = int.tryParse(settings[SettingKeys.menuGridCols] ?? '4') ?? 4;
    final rows = int.tryParse(settings[SettingKeys.menuGridRows] ?? '4') ?? 4;
    final itemsPerPage = cols * rows;
    final totalPages = itemsToDisplay.isEmpty
        ? 1
        : ((itemsToDisplay.length + itemsPerPage - 1) ~/ itemsPerPage);
    final safePage = _currentPage.clamp(0, totalPages - 1);
    final pageStart = safePage * itemsPerPage;
    final pageEnd = (pageStart + itemsPerPage).clamp(0, itemsToDisplay.length);
    final pageItems = itemsToDisplay.sublist(pageStart, pageEnd);

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────────────
        if (showSearchBtn)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const PhosphorIcon(
                        PhosphorIconsRegular.magnifyingGlass,
                        size: 20,
                      ),
                      fillColor: cs.surfaceContainer,
                      filled: true,
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const PhosphorIcon(
                                PhosphorIconsRegular.x,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref.read(searchQueryProvider.notifier).state =
                                    '';
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                    ),
                    onChanged: (v) =>
                        ref.read(searchQueryProvider.notifier).state = v,
                    onSubmitted: _handleBarcodeSubmit,
                  ),
                ),
                if (showSearchOptions) ...[
                  const SizedBox(width: 8),
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (mode, icon) in <(String, IconData)>[
                          ('All fields', PhosphorIconsRegular.asterisk),
                          ('Barcode', PhosphorIconsRegular.barcode),
                          ('Code', PhosphorIconsRegular.hash),
                          ('Name', PhosphorIconsRegular.tag),
                        ])
                          Tooltip(
                            message: mode,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () =>
                                  setState(() => _activeSearchMode = mode),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: effectiveMode == mode
                                      ? cs.primary.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: PhosphorIcon(
                                  icon,
                                  size: 20,
                                  color: effectiveMode == mode
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

        // ── Breadcrumb ──────────────────────────────────────────────────────
        if (!isSearching && currentGroup != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: cs.surfaceContainerHighest,
            child: Row(
              children: [
                IconButton(
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.arrowLeft,
                    size: 20,
                  ),
                  onPressed: () {
                    if (currentGroup.parentGroupId == null) {
                      ref.read(currentGroupProvider.notifier).state = null;
                    } else {
                      try {
                        final parent = allGroups.firstWhere(
                          (g) => g.id == currentGroup.parentGroupId,
                        );
                        ref.read(currentGroupProvider.notifier).state = parent;
                      } catch (_) {
                        ref.read(currentGroupProvider.notifier).state = null;
                      }
                    }
                  },
                ),
                const Gap(4),
                PhosphorIcon(
                  PhosphorIconsRegular.folder,
                  size: 18,
                  color: cs.primary,
                ),
                const Gap(8),
                Expanded(
                  child: Text(
                    currentGroup.name,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // ── Product / group grid ────────────────────────────────────────────
        Expanded(
          child: itemsToDisplay.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        isSearching
                            ? PhosphorIconsRegular.magnifyingGlass
                            : PhosphorIconsRegular.tray,
                        size: 56,
                        color: cs.onSurface.withValues(alpha: 0.25),
                      ),
                      const Gap(12),
                      Text(
                        isSearching
                            ? 'No products found for "$searchQuery"'
                            : 'This folder is empty',
                        style: tt.bodyLarge?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (ctx, constraints) {
                    final maxExtent = (constraints.maxWidth / cols).clamp(
                      100.0,
                      240.0,
                    );
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: maxExtent,
                        childAspectRatio: 0.82,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: pageItems.length,
                      itemBuilder: (context, index) {
                        final item = pageItems[index];
                        Widget card;
                        if (item is ProductGroup) {
                          card = _buildGroupCard(context, ref, item);
                        } else if (item is Product) {
                          card = _buildProductCard(context, ref, item);
                        } else {
                          return const SizedBox();
                        }
                        return card;
                      },
                    );
                  },
                ),
        ),

        _PaginationBar(
          currentPage: safePage,
          totalPages: totalPages,
          onFirst: () => setState(() => _currentPage = 0),
          onPrevious: () => setState(() => _currentPage = safePage - 1),
          onNext: () => setState(() => _currentPage = safePage + 1),
          onLast: () => setState(() => _currentPage = totalPages - 1),
        ),
      ],
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    WidgetRef ref,
    ProductGroup group,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent =
        (group.flutterColor == Colors.transparent ||
            group.flutterColor == Colors.white)
        ? cs.primary
        : group.flutterColor;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.45), width: 1.5),
      ),
      color: cs.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(currentGroupProvider.notifier).state = group;
          ref.read(searchQueryProvider.notifier).state = '';
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              // 3-tier fallback: disk file (FileImage, cached by path) →
              // base64 bytes (legacy/admin-edit flow) → folder icon.
              child: group.imageFile != null
                  ? Image.file(
                      group.imageFile!,
                      fit: BoxFit.cover,
                      cacheWidth: 150,
                    )
                  : group.imageBytes != null
                  ? Image.memory(
                      group.imageBytes!,
                      fit: BoxFit.cover,
                      cacheWidth: 150,
                    )
                  : Container(
                      color: accent.withValues(alpha: 0.1),
                      child: Center(
                        child: PhosphorIcon(
                          PhosphorIconsRegular.folder,
                          size: 52,
                          color: accent.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              color: accent.withValues(alpha: 0.1),
              child: Text(
                group.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sym = ref.watch(currencySymbolProvider);
    final showImages =
        ref
            .watch(appSettingsProvider)[SettingKeys.showProductImages]
            ?.toLowerCase() !=
        'false';
    final hasPromo =
        getActivePromotionCountForProduct(_activePromos, product.id) > 0;

    return InkWell(
      onTap: () async {
        final cartState = ref.read(cartProvider);
        if (cartState.activePosOrderId == null) {
          final floorPlanOn =
              ref
                  .read(
                    appSettingsProvider,
                  )[SettingKeys.featureFloorPlanEnabled]
                  ?.toLowerCase() ==
              'true';
          if (cartState.serviceType != 0 || !floorPlanOn) {
            final companyId = ref.read(selectedCompanyProvider)?.id;
            final user = ref.read(currentUserProvider);
            if (companyId == null || user == null) return;
            try {
              await ref
                  .read(cartProvider.notifier)
                  .startTablelessOrder(
                    ApiClient(),
                    companyId,
                    user.id,
                    cartState.serviceType,
                  );
            } catch (e) {
              if (!context.mounted) return;
              showAppSnackbar(
                context,
                ref,
                'Error creating order: $e',
                isError: true,
              );
              return;
            }
          } else {
            if (!context.mounted) return;
            showAppSnackbar(
              context,
              ref,
              'Please select a Table from the Floor Plan first!',
              isError: true,
            );
            return;
          }
        }

        if (product.ageRestriction != null) {
          if (!context.mounted) return;
          final confirmed = await _showAgeRestrictionDialog(
            context,
            product.ageRestriction!,
          );
          if (!confirmed) return;
        }

        double quantity = 1.0;
        if (!product.isUsingDefaultQuantity) {
          if (!context.mounted) return;
          final qty = await _showQuantityInputDialog(
            context,
            product.measurementUnit,
          );
          if (qty == null) return;
          quantity = qty;
        }

        // Offline stock validation: hard-block negative inventory and warn on
        // low stock (acknowledgement required) using the real tapped quantity.
        if (!context.mounted) return;
        if (!await _passesStockGuards(product, quantity)) return;

        double price = product.price;
        if (product.isPriceChangeAllowed) {
          final preventBelowCost =
              ref
                  .read(
                    appSettingsProvider,
                  )[SettingKeys.preventSaleBelowCostPrice]
                  ?.toLowerCase() ==
              'true';
          if (!context.mounted) return;
          final p = await _showPriceInputDialog(
            context,
            product.price,
            product.cost,
            preventBelowCost,
            sym,
          );
          if (p == null) return;
          price = p;
        }

        String? comment;
        try {
          // Read the product's comment suggestions straight from Drift. Going
          // through productCommentsProvider(...).future here was unreliable: it's
          // an autoDispose .family StreamProvider, and reading `.future` with no
          // active listener can resolve before the Drift watch-stream emits its
          // first row — so a product that HAS comments looked like it had none
          // and the modifier popup silently never showed. A direct query is
          // deterministic and fully offline (the rows are pulled during sync).
          final db = ref.read(appDatabaseProvider);
          final companyId = ref.read(selectedCompanyProvider)?.id ?? 0;
          final rows =
              await (db.select(db.productCommentsTable)
                    ..where((t) => t.companyId.equals(companyId))
                    ..where((t) => t.productId.equals(product.id))
                    ..where((t) => t.syncStatus.isNotIn(['pending_delete'])))
                  .get();
          final comments = rows.map(ProductComment.fromDrift).toList();
          if (comments.isNotEmpty) {
            if (!context.mounted) return;
            final result = await showDialog<String?>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => _ProductCommentsDialog(
                productName: product.name,
                predefinedComments: comments,
              ),
            );
            if (result == null) return;
            comment = result.trim().isEmpty ? null : result.trim();
          }
        } catch (_) {}

        // Load the product's assigned taxes (set in the product editor) so the
        // cart applies them. Without this the item is added with no tax even
        // though it has a primary tax rate configured. Offline-first: reads the
        // local product_taxes table + warm tax cache.
        final productTaxes = await ref
            .read(cartProvider.notifier)
            .resolveProductTaxes(product.id);

        if (!context.mounted) return;
        try {
          final menuProduct = MenuProduct(
            id: product.id,
            name: product.name,
            price: price,
            cost: product.cost,
            isTaxInclusivePrice: product.isTaxInclusivePrice,
            color: product.color,
            stockQuantity: 9999,
            taxes: productTaxes,
            isEnabled: product.isEnabled,
            ageRestriction: product.ageRestriction,
            isPriceChangeAllowed: product.isPriceChangeAllowed,
            isUsingDefaultQuantity: product.isUsingDefaultQuantity,
            measurementUnit: product.measurementUnit,
            isService: product.isService,
          );
          ref
              .read(cartProvider.notifier)
              .addItem(
                menuProduct,
                quantity: quantity,
                comment: comment,
                measurementUnit: product.measurementUnit,
              );
        } catch (e) {
          if (!context.mounted) return;
          showAppSnackbar(
            context,
            ref,
            e.toString().replaceAll("Exception: ", ""),
            isError: true,
          );
        }
      },
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        color: cs.surfaceContainer,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              // 3-tier fallback: disk file (fast, cached by path) →
              // base64 bytes (legacy/edit-flow) → placeholder icon.
              // Image.file is preferred for Drift-sourced products because
              // Flutter's image cache reuses the decoded copy across the
              // whole grid — Image.memory(Uint8List) bypasses that cache.
              child: showImages && product.imageFile != null
                  ? Image.file(
                      product.imageFile!,
                      fit: BoxFit.cover,
                      cacheWidth: 150,
                    )
                  : showImages && product.imageBytes != null
                  ? Image.memory(
                      product.imageBytes!,
                      fit: BoxFit.cover,
                      cacheWidth: 150,
                    )
                  : Container(
                      color: cs.surfaceContainerHighest,
                      child: Center(
                        child: PhosphorIcon(
                          PhosphorIconsRegular.forkKnife,
                          size: 44,
                          color: cs.onSurface.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              color: cs.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasPromo)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: PhosphorIcon(
                        PhosphorIconsFill.star,
                        size: 14,
                        color: cs.tertiary,
                      ),
                    ),
                  Text(
                    product.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    '${product.price.toStringAsFixed(2)} $sym',
                    style: tt.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGINATION BAR
// ─────────────────────────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFirst = currentPage == 0;
    final isLast = currentPage >= totalPages - 1;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavButton(
            icon: PhosphorIconsRegular.skipBack,
            tooltip: 'First',
            onTap: isFirst ? null : onFirst,
          ),
          _NavButton(
            icon: PhosphorIconsRegular.caretLeft,
            tooltip: 'Previous',
            onTap: isFirst ? null : onPrevious,
          ),
          const Gap(12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              '${currentPage + 1} / $totalPages',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          const Gap(12),
          _NavButton(
            icon: PhosphorIconsRegular.caretRight,
            tooltip: 'Next',
            onTap: isLast ? null : onNext,
          ),
          _NavButton(
            icon: PhosphorIconsRegular.skipForward,
            tooltip: 'Last',
            onTap: isLast ? null : onLast,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: PhosphorIcon(
            icon,
            size: 18,
            color: enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}

class CartSection extends ConsumerStatefulWidget {
  const CartSection({super.key});

  @override
  ConsumerState<CartSection> createState() => _CartSectionState();
}

class _CartSectionState extends ConsumerState<CartSection> {
  Future<void> _handleSave(BuildContext context, WidgetRef ref) async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;
    final currentUser = ref.read(currentUserProvider);

    final wasBookingOrder = ref.read(cartProvider).bookingId != null;
    final wasTableOrder = ref.read(cartProvider).floorPlanTableId != null;
    final savedSettings = ref.read(appSettingsProvider);
    final bookingEnabled =
        savedSettings[SettingKeys.featureBookingEnabled]?.toLowerCase() ==
        'true';
    final floorPlanEnabled =
        savedSettings[SettingKeys.featureFloorPlanEnabled]?.toLowerCase() ==
        'true';

    try {
      // Step 1: Save to local SQLite immediately — always works offline.
      await ref
          .read(cartProvider.notifier)
          .saveOrderLocally(
            companyId: company.id,
            userId: currentUser?.id ?? 0,
          );

      if (!context.mounted) return;

      // Step 2: Show success — the local save is durable regardless of network.
      showAppSnackbar(
        context,
        ref,
        wasBookingOrder
            ? 'Booking Saved!'
            : wasTableOrder
            ? 'Order Saved to Table!'
            : 'Order Saved!',
      );

      // Step 3: Navigate back to where the order came from. A booking order —
      // even one opened from a table (booking → table → save) — returns to
      // Bookings (booking takes priority); a table order returns to Tables;
      // anything else falls back to the configured default screen. POS-only
      // setups have nowhere to go, so just clear the cart and stay on the menu.
      int? nextIndex;
      if (wasBookingOrder && bookingEnabled) {
        nextIndex = 2; // Bookings
      } else if (wasTableOrder && floorPlanEnabled) {
        nextIndex = 4; // Tables / Floor Plan
      } else if (bookingEnabled || floorPlanEnabled) {
        nextIndex = resolveDefaultScreenIndex(savedSettings);
      }

      final idx = nextIndex;
      if (idx != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainLayout(initialIndex: idx)),
          (r) => false,
        );
      } else {
        ref.read(cartProvider.notifier).clearCart();
      }

      // Step 4: Fire-and-forget sync push so the server sees the open order
      // as soon as possible.  Failures are silent — the row stays 'pending'
      // and the next manual/auto sync will retry.
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
    } catch (e) {
      if (context.mounted) {
        showAppSnackbar(context, ref, 'Save failed: $e', isError: true);
      }
    }
  }

  Future<void> _handleVoidOrder(
    BuildContext context,
    WidgetRef ref,
    CartState cartState,
    List<CartItem> cartItems,
  ) async {
    // Step 1: Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: CircleAvatar(
          radius: 32,
          backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
          child: Icon(Icons.question_mark,
              size: 32, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
        ),
        title: const Text('Void order'),
        content: const Text('Are you sure you want to void this order?'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final settings = ref.read(appSettingsProvider);
    final requireReason =
        settings[SettingKeys.requireReasonOnVoid]?.toLowerCase() == 'true';

    // Step 2: Reason dialog (if setting enabled)
    String? selectedReason;
    if (requireReason && cartItems.isNotEmpty) {
      selectedReason = await _showVoidReasonDialog(
        context,
        cartState.orderNumber,
      );
      if (selectedReason == null || !context.mounted) return; // user cancelled
    }

    final companyId = ref.read(selectedCompanyProvider)?.id;
    final user = ref.read(currentUserProvider);
    if (companyId == null || cartState.activePosOrderId == null) return;

    final wasBookingOrder = cartState.bookingId != null;
    final wasTableOrder = cartState.floorPlanTableId != null;

    try {
      final db = ref.read(appDatabaseProvider);
      final serverId = cartState.activePosOrderId ?? 0;
      final warehouseId = cartState.activeWarehouseId ?? 1;
      final orderNumber = cartState.orderNumber ?? 'UNKNOWN';
      final existLocalId = cartState.existingLocalOrderId;

      // Build the void items JSON payload (same shape used by /PosVoids/Add).
      final itemsJson = jsonEncode(
        cartItems
            .map(
              (item) => {
                'productId': item.productId,
                'productName': item.productName,
                'roundNumber': item.roundNumber,
                'quantity': item.quantity,
                'price': item.price,
                'discount': item.discount,
                'discountType': item.discountType,
                'total': item.price * item.quantity,
                'userName': user?.displayName ?? 'Unknown',
                if (item.bundle != null) 'bundle': item.bundle,
              },
            )
            .toList(),
      );

      if (serverId > 0) {
        // Order has a server record — queue the void for sync and delete
        // the local open-order row.  SyncManager will POST /PosVoids/Add
        // and DELETE /PosOrder/Delete when connectivity returns.
        final localId = existLocalId ?? 'svr_$serverId';
        await db.queueVoidAndDeleteOrder(
          localId: localId,
          serverOrderId: serverId,
          companyId: companyId,
          userId: user?.id ?? 0,
          orderNumber: orderNumber,
          warehouseId: warehouseId,
          itemsJson: itemsJson,
          reason: selectedReason,
        );
        // Restore local stock for voided items.
        await db.deductStockForCheckout(
          items: cartItems
              .map(
                (item) => (
                  productId: item.productId,
                  quantity: -item.quantity, // negative = add back to stock
                  warehouseId: item.warehouseId ?? warehouseId,
                  isService: item.isService,
                  productName: item.productName,
                ),
              )
              .toList(),
          allowNegative: true, // always allow restoring stock
        );
        // Fire-and-forget sync so the server is updated immediately if online.
        ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      } else {
        // Local-only order (never pushed to server) — just delete the row.
        if (existLocalId != null) {
          await (db.delete(
            db.posOrdersTable,
          )..where((t) => t.localId.equals(existLocalId))).go();
          // Remove its discount_lines too (they link by local id with no FK
          // cascade) so a voided order leaves no discount records behind.
          await db.purgeDiscountLinesFor(existLocalId);
          // Restore local stock.
          await db.deductStockForCheckout(
            items: cartItems
                .map(
                  (item) => (
                    productId: item.productId,
                    quantity: -item.quantity,
                    warehouseId: item.warehouseId ?? warehouseId,
                    isService: item.isService,
                    productName: item.productName,
                  ),
                )
                .toList(),
            allowNegative: true,
          );
        }
      }

      ref.read(kitchenSyncProvider).push();
      ref.read(cartProvider.notifier).clearCart();

      if (!context.mounted) return;
      showAppSnackbar(context, ref, 'Order Voided', isError: true);

      final bookingEnabled =
          settings[SettingKeys.featureBookingEnabled]?.toLowerCase() == 'true';
      final floorPlanEnabled =
          settings[SettingKeys.featureFloorPlanEnabled]?.toLowerCase() ==
          'true';
      int? navIndex;
      if (wasBookingOrder && bookingEnabled) {
        navIndex = 2;
      } else if (wasTableOrder && floorPlanEnabled) {
        navIndex = 4;
      } else if (bookingEnabled) {
        navIndex = 2;
      } else if (floorPlanEnabled) {
        navIndex = 4;
      }

      if (navIndex != null && context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => MainLayout(initialIndex: navIndex!),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackbar(context, ref, 'Error: $e', isError: true);
      }
    }
  }

  Future<String?> _showVoidReasonDialog(
    BuildContext context,
    String? orderNumber,
  ) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VoidReasonDialog(orderNumber: orderNumber),
    );
  }

  // Gross line total for a cart item: net amount after discounts + item-level tax
  double _grossLineTotal(CartItem item) {
    final net =
        (item.price - item.discount - item.promotionalDiscount) * item.quantity;
    return item.appliedTaxes.fold(net, (sum, t) {
      if (t.isFixed) return sum + t.rate * item.quantity;
      return sum + net * (t.rate / 100);
    });
  }

  // Full-price gross for the strikethrough label (before item discounts + tax)
  double _grossLineFullPrice(CartItem item) {
    final net = item.price * item.quantity;
    return item.appliedTaxes.fold(net, (sum, t) {
      if (t.isFixed) return sum + t.rate * item.quantity;
      return sum + net * (t.rate / 100);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Forward every cart change into the customer display state machine.
    ref.listen<CartState>(cartProvider, (_, next) {
      final n = ref.read(cartProvider.notifier);
      ref
          .read(customerDisplayProvider.notifier)
          .syncFromCart(
            cartState: next,
            subtotal: n.subtotal,
            discount:
                n.discountTotal +
                n.customerDiscountAmount +
                n.manualCartDiscountAmount,
            tax: n.taxTotal,
            total: n.grandTotal,
          );
    });

    final cartState = ref.watch(cartProvider);
    final cartNotifier = ref.watch(cartProvider.notifier);
    final cartItems = cartState.items;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final subtotal = cartNotifier.subtotal;
    final discountTotal = cartNotifier.discountTotal;
    final taxTotal = cartNotifier.taxTotal;
    final grandTotal = cartNotifier.grandTotal;
    final sym = ref.watch(currencySymbolProvider);
    final settings = ref.watch(appSettingsProvider);
    final taxIncluded =
        settings[SettingKeys.displayAndPrintTaxIncluded]?.toLowerCase() !=
        'false';
    // Gross subtotal (after item discounts, including tax) used when taxIncluded=true.
    // Math: grossSubtotal - customerDiscount - cartDiscount = grandTotal ✓
    final grossSubtotal = subtotal - discountTotal + taxTotal;
    final dualEnabled =
        settings[SettingKeys.dualCurrencyEnabled]?.toLowerCase() == 'true';
    final dualSym = settings[SettingKeys.dualCurrencySymbol] ?? '€';
    final dualRate =
        double.tryParse(settings[SettingKeys.dualCurrencyRate] ?? '1.0') ?? 1.0;

    final allUsers = ref.watch(allUsersProvider).value ?? [];
    final staffName = cartState.bookingStaffId != null
        ? allUsers
                  .where((u) => u.id == cartState.bookingStaffId)
                  .map((u) => u.displayName)
                  .firstOrNull ??
              'Staff #${cartState.bookingStaffId}'
        : null;
    final guestName = cartState.orderNumber?.replaceFirst('APT- ', '');

    final allRooms = ref.watch(allRoomsProvider).value ?? [];
    final dailyOrderNumber = ref.watch(dailyOrderNumberProvider);
    final String contextLabel;
    if (cartState.bookingId != null) {
      final tableName = cartState.floorPlanTableId != null
          ? allRooms
                .where((t) => t.id == cartState.floorPlanTableId)
                .firstOrNull
                ?.name
          : null;
      final prefix =
          tableName ?? (guestName?.isNotEmpty == true ? guestName! : 'Booking');
      contextLabel = staffName != null ? '$prefix · Staff: $staffName' : prefix;
    } else if (cartState.floorPlanTableId != null) {
      contextLabel =
          allRooms
              .where((t) => t.id == cartState.floorPlanTableId)
              .firstOrNull
              ?.name ??
          'Table #${cartState.floorPlanTableId}';
    } else {
      final stored = cartState.orderNumber;
      if (stored != null && stored.isNotEmpty) {
        contextLabel = stored;
      } else {
        final types = ref.read(appSettingsProvider.notifier).customServiceTypes;
        final prefix =
            types
                .where((t) => t.id == cartState.serviceType)
                .map((t) => t.prefix)
                .firstOrNull ??
            'ORDER';
        contextLabel =
            '$prefix #${dailyOrderNumber.toString().padLeft(3, '0')}';
      }
    }

    return Column(
      children: [
        if (cartState.bookingId != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.teal.withValues(alpha: 0.15),
            child: Row(
              children: [
                const Icon(Icons.event, size: 16, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Booking: ',
                          style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        TextSpan(
                          text: guestName ?? '—',
                          style: const TextStyle(
                            color: Colors.teal,
                            fontSize: 12,
                          ),
                        ),
                        if (staffName != null) ...[
                          const TextSpan(
                            text: '  ·  Staff: ',
                            style: TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: staffName,
                            style: const TextStyle(
                              color: Colors.teal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  contextLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              if (ref
                      .read(
                        appSettingsProvider,
                      )[SettingKeys.enableCustomOrderName]
                      ?.toLowerCase() ==
                  'true')
                IconButton(
                  icon: Icon(
                    cartState.orderName?.isNotEmpty == true
                        ? Icons.badge
                        : Icons.badge_outlined,
                    size: 20,
                  ),
                  tooltip: cartState.orderName?.isNotEmpty == true
                      ? 'Order Name: ${cartState.orderName}'
                      : 'Set Order Name',
                  onPressed: () async {
                    final name = await _showOrderNameDialog(
                      context,
                      cartState.orderName,
                    );
                    if (name != null) {
                      ref
                          .read(cartProvider.notifier)
                          .setOrderName(name.isEmpty ? null : name);
                    }
                  },
                ),

              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh order number',
                onPressed: () async {
                  final companyId = ref.read(selectedCompanyProvider)?.id;
                  if (companyId == null) return;
                  ref.invalidate(openOrdersProvider);
                  await Future.delayed(const Duration(milliseconds: 300));
                  await ref
                      .read(cartProvider.notifier)
                      .syncOrderNumber(companyId);
                },
              ),

              ElevatedButton.icon(
                onPressed: cartItems.isEmpty
                    ? null
                    : () => _handleSave(context, ref),
                icon: const Icon(Icons.save, size: 18, color: Colors.white),
                label: const Text(
                  "SAVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: cartItems.isEmpty
              ? Center(
                  child: Text(
                    "Cart is empty",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: cartItems.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    final isSelected =
                        cartState.selectedCartItemId == item.cartItemId;
                    final cs = Theme.of(context).colorScheme;
                    final hasDiscount =
                        item.discount > 0 || item.promotionalDiscount > 0;

                    // Compact +/- stepper button — shrunk from the default 48px
                    // IconButton tap target so the controls row fits even a
                    // narrow cart panel without overflowing.
                    Widget stepBtn(IconData icon, VoidCallback onTap) =>
                        IconButton(
                          icon: Icon(icon, color: cs.onSurfaceVariant),
                          iconSize: 22,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                          onPressed: onTap,
                        );

                    // Small status pill (TAX / discount).
                    Widget badge(IconData icon, String label, Color color) =>
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: color.withAlpha(38),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 10, color: color),
                              const SizedBox(width: 2),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        );

                    return InkWell(
                      onTap: () => ref
                          .read(cartProvider.notifier)
                          .setSelectedProduct(item.cartItemId),
                      child: Container(
                        color: isSelected
                            ? (isDark
                                  ? Colors.blue[900]?.withValues(alpha: 0.3)
                                  : Colors.blue[50])
                            : null,
                        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Name + remove ──────────────────────────────
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.productName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color: context.dangerColor,
                                    size: 20,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 34,
                                    minHeight: 34,
                                  ),
                                  onPressed: () {
                                    void remove() => ref
                                        .read(cartProvider.notifier)
                                        .removeItem(item.cartItemId);
                                    // Removing a line from an already-saved
                                    // order is a gated "void item" action;
                                    // trimming a fresh unsaved cart is normal
                                    // cashier work and is not gated.
                                    if (cartState.activePosOrderId == null) {
                                      remove();
                                    } else {
                                      ref
                                          .read(securityGuardProvider)
                                          .guard(
                                            context,
                                            SecurityKeys.orderItemVoid,
                                            remove,
                                          );
                                    }
                                  },
                                ),
                              ],
                            ),
                            // ── Badges (wrap so they never overflow) ───────
                            if (item.appliedTaxes.isNotEmpty || hasDiscount)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 2,
                                  bottom: 2,
                                ),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (item.appliedTaxes.isNotEmpty)
                                      badge(
                                        Icons.receipt_long,
                                        'TAX',
                                        context.infoColor,
                                      ),
                                    if (item.discount > 0)
                                      badge(
                                        Icons.sell,
                                        "-${item.discountType == 0 ? item.discount.toInt() : item.discount.toStringAsFixed(1)}",
                                        context.successColor,
                                      ),
                                    if (item.promotionalDiscount > 0)
                                      const Text(
                                        '⭐',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                            // ── Quantity stepper + price ───────────────────
                            Row(
                              children: [
                                stepBtn(
                                  Icons.remove_circle_outline,
                                  () => ref
                                      .read(cartProvider.notifier)
                                      .decrementItem(item.cartItemId),
                                ),
                                InkWell(
                                  onTap: () {
                                    final controller = TextEditingController(
                                      text: item.quantity % 1 == 0
                                          ? item.quantity.toInt().toString()
                                          : item.quantity.toStringAsFixed(2),
                                    );
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Enter Quantity"),
                                        content: TextField(
                                          controller: controller,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          autofocus: true,
                                          decoration: InputDecoration(
                                            labelText: "Quantity",
                                            suffixText: item.measurementUnit,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text("Cancel"),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              final newQty = double.tryParse(
                                                controller.text,
                                              );
                                              if (newQty != null &&
                                                  newQty >= 0) {
                                                ref
                                                    .read(cartProvider.notifier)
                                                    .updateItemQuantity(
                                                      item.cartItemId,
                                                      newQty,
                                                    );
                                              }
                                              Navigator.pop(ctx);
                                            },
                                            child: const Text("Set"),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      _formatCartQty(item),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                stepBtn(
                                  Icons.add_circle_outline,
                                  () => ref
                                      .read(cartProvider.notifier)
                                      .incrementItem(item.cartItemId),
                                ),
                                const Spacer(),
                                // Price (strikethrough original + net).
                                Flexible(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (hasDiscount)
                                        Text(
                                          "${(taxIncluded ? _grossLineFullPrice(item) : item.price * item.quantity).toStringAsFixed(2)} $sym",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                      Text(
                                        "${(taxIncluded ? _grossLineTotal(item) : (item.price - item.discount - item.promotionalDiscount) * item.quantity).toStringAsFixed(2)} $sym",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: hasDiscount
                                              ? context.successColor
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black38 : Colors.black12,
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              _totalsRow(
                Text(
                  taxIncluded ? "Subtotal (incl. tax)" : "Subtotal",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
                value: Text(
                  "${(taxIncluded ? grossSubtotal : subtotal).toStringAsFixed(2)} $sym",
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              if (discountTotal > 0 && !taxIncluded)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _totalsRow(
                    Text(
                      "Item Discounts",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: context.successColor),
                    ),
                    value: Text(
                      "-${discountTotal.toStringAsFixed(2)} $sym",
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 16, color: context.successColor),
                    ),
                  ),
                ),
              if (cartState.customerDiscountValue != null &&
                  cartState.customerDiscountValue! > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _totalsRow(
                    // The deducted amount is shown on the right, so the label
                    // stays plain (no parenthetical value).
                    Text(
                      "Customer Discount",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: context.successColor),
                    ),
                    value: Text(
                      "-${cartNotifier.customerDiscountAmount.toStringAsFixed(2)} $sym",
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 16, color: context.successColor),
                    ),
                  ),
                ),
              if (cartState.manualCartDiscount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _totalsRow(
                    Text(
                      "Cart Discount",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: context.successColor),
                    ),
                    value: Text(
                      "-${cartNotifier.manualCartDiscountAmount.toStringAsFixed(2)} $sym",
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 16, color: context.successColor),
                    ),
                  ),
                ),
              if (cartNotifier.promotionalDiscountTotal > 0 && !taxIncluded)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _totalsRow(
                    Text(
                      "Total Promotional Discount",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: context.warningColor),
                    ),
                    value: Text(
                      "-${cartNotifier.promotionalDiscountTotal.toStringAsFixed(2)} $sym",
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 16, color: context.warningColor),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              _totalsRow(
                Text(
                  taxIncluded ? "Tax (incl.)" : "Taxes",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: taxIncluded
                        ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.45)
                        : null,
                  ),
                ),
                value: Text(
                  "${taxTotal.toStringAsFixed(2)} $sym",
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 16,
                    color: taxIncluded
                        ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.45)
                        : null,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, thickness: 1),
              ),
              _totalsRow(
                Text(
                  "Total Due",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.successColor,
                  ),
                ),
                valueFlexible: true,
                value: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    "${grandTotal.toStringAsFixed(2)} $sym",
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.successColor,
                    ),
                  ),
                ),
              ),
              if (dualEnabled && dualRate > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '≈ ${(grandTotal * dualRate).toStringAsFixed(2)} $dualSym',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              // Flat, touch-sized split: VOID (danger) + PAY (success), via the
              // theme-aware StatusColors tokens; everything else matches the app's
              // flat style — no shadow, consistent rounding + height.
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _CartFooterButton(
                      icon: Icons.block,
                      label: 'VOID',
                      color: context.dangerColor,
                      onTap: cartState.activePosOrderId == null
                          ? null
                          : () => ref
                                .read(securityGuardProvider)
                                .guard(
                                  context,
                                  SecurityKeys.orderVoid,
                                  () => _handleVoidOrder(
                                    context,
                                    ref,
                                    cartState,
                                    cartItems,
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: _CartFooterButton(
                      icon: Icons.payments,
                      label: 'PAY',
                      color: context.successColor,
                      onTap: cartItems.isEmpty
                          ? null
                          : () {
                              final settings = ref.read(appSettingsProvider);
                              final orderNameRequired =
                                  settings[SettingKeys.orderNameRequired]
                                      ?.toLowerCase() ==
                                  'true';
                              if (orderNameRequired &&
                                  (cartState.orderName == null ||
                                      cartState.orderName!.isEmpty)) {
                                showAppSnackbar(
                                  context,
                                  ref,
                                  'Order Name is required to complete this transaction.',
                                  isError: true,
                                );
                                return;
                              }
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) =>
                                    const PaymentCheckoutDialog(),
                              );
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Menu action-bar button ────────────────────────────────────────────────
// Touch-sized icon+label button for the order-controls toolbar. Replaces the
// old bare icon-only IconButtons so every action is clearly labelled and is an
// easy finger target. [_MenuActionVisual] is the icon+label body, reused for
// PopupMenuButton children (e.g. the warehouse switcher) where the menu itself
// owns the tap.
class _MenuActionVisual extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;
  // Optional explicit icon colour (e.g. the amber promotion star). Falls back
  // to [tint] when null so labels + icons stay in sync.
  final Color? iconColor;
  // Optional count bubble drawn on the icon (e.g. active-promotion count).
  final int? badgeCount;
  // Tonal box fill (flat, no shadow). Transparent when null — used by the
  // stateful service-type / service-status buttons to colour-code them.
  final Color? highlight;
  const _MenuActionVisual({
    required this.icon,
    required this.label,
    required this.tint,
    this.iconColor,
    this.badgeCount,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, size: 24, color: iconColor ?? tint);
    if (badgeCount != null && badgeCount! > 0) {
      iconWidget = Badge.count(count: badgeCount!, child: iconWidget);
    }
    return Container(
      constraints: const BoxConstraints(minWidth: 64),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        // Flat: solid tonal highlight, no shadow/elevation.
        color: highlight ?? Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Unified, flat top-header action button: a centred icon over a small label,
/// in a clean bounding box. Used for every order-control action so they share
/// one consistent touch-sized style. Disabled (onTap == null) dims the tint.
class _MenuHeaderActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color? iconColor;
  final int? badgeCount;
  // Dynamic colour for stateful buttons (service type / status): drives both the
  // icon+label tint and a flat tonal box fill, so they colour-code while sharing
  // the exact same shape as every other action button.
  final Color? customTint;
  const _MenuHeaderActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.iconColor,
    this.badgeCount,
    this.customTint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final tint = !enabled
        ? cs.onSurface.withValues(alpha: 0.3)
        : (customTint ?? (active ? cs.primary : cs.onSurface));
    final highlight = !enabled
        ? null
        : (customTint != null
              ? customTint!.withValues(alpha: 0.15)
              : (active ? cs.primary.withValues(alpha: 0.12) : null));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: _MenuActionVisual(
            icon: icon,
            label: label,
            tint: tint,
            iconColor: enabled ? iconColor : null,
            badgeCount: badgeCount,
            highlight: highlight,
          ),
        ),
      ),
    );
  }
}

// ── Cart footer button (VOID / PAY) ────────────────────────────────────────
// Flat, touch-sized primary action. Matches the app's flat style (no shadow,
// consistent 56px height + rounded corners); the fill colour is passed in and
// kept hard-coded (red for VOID, green for PAY). Disabled → neutral grey.
class _CartFooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _CartFooterButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 22),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ── Cart totals row ───────────────────────────────────────────────────────
// One line of the totals panel: label hard-left, value hard-right (decimal
// points line up cleanly down the column). The value keeps a guaranteed left
// gap from the label and is right-aligned; pass [valueFlexible] for the big
// grand-total so a long amount can scale-to-fit instead of overflowing.
Widget _totalsRow(
  Widget label, {
  required Widget value,
  bool valueFlexible = false,
}) {
  final v = Padding(padding: const EdgeInsets.only(left: 12), child: value);
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(child: label),
      valueFlexible ? Flexible(child: v) : v,
    ],
  );
}

// --- Quantity display helper
String _formatCartQty(CartItem item) {
  final qty = item.quantity % 1 == 0
      ? item.quantity.toInt().toString()
      : item.quantity.toStringAsFixed(2);
  if (item.measurementUnit != null && item.measurementUnit!.isNotEmpty) {
    return '$qty ${item.measurementUnit}';
  }
  return 'x$qty';
}

// --- Dialog helpers
Future<double?> _showQuantityInputDialog(
  BuildContext context,
  String? unit,
) async {
  final controller = TextEditingController();
  return showDialog<double?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Enter Quantity'),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        decoration: InputDecoration(labelText: 'Quantity', suffixText: unit),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final val = double.tryParse(controller.text);
            if (val != null && val > 0) Navigator.pop(ctx, val);
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

Future<String?> _showOrderNameDialog(
  BuildContext context,
  String? currentName,
) async {
  final controller = TextEditingController(text: currentName ?? '');
  return showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Order Name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Enter order name',
          hintText: 'e.g. John, Table 5',
        ),
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

Future<double?> _showPriceInputDialog(
  BuildContext context,
  double defaultPrice,
  double costPrice,
  bool preventBelowCost,
  String currencySymbol,
) async {
  final controller = TextEditingController(
    text: defaultPrice.toStringAsFixed(2),
  );
  String? errorText;
  return showDialog<double?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Set Sale Price'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Price',
            suffixText: ' $currencySymbol',
            errorText: errorText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val == null || val < 0) return;
              if (preventBelowCost && val < costPrice) {
                setState(
                  () => errorText = 'Sale price cannot be below cost price.',
                );
                return;
              }
              Navigator.pop(ctx, val);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> _showAgeRestrictionDialog(BuildContext context, int minAge) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: ctx.warningColor),
          const SizedBox(width: 8),
          const Text('Age Restriction'),
        ],
      ),
      content: Text(
        'This product requires customers to be at least $minAge years old.\n\n'
        'Please confirm the customer meets this requirement before proceeding.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Confirm ($minAge+)'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _ProductCommentsDialog extends StatefulWidget {
  final String productName;
  final List<ProductComment> predefinedComments;

  const _ProductCommentsDialog({
    required this.productName,
    required this.predefinedComments,
  });

  @override
  State<_ProductCommentsDialog> createState() => _ProductCommentsDialogState();
}

class _ProductCommentsDialogState extends State<_ProductCommentsDialog> {
  final Set<int> _selectedIds = {};
  final TextEditingController _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Comments: ${widget.productName}'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...widget.predefinedComments.map(
                (c) => SwitchListTile(
                  title: Text(c.comment),
                  value: _selectedIds.contains(c.id),
                  onChanged: (val) => setState(() {
                    val ? _selectedIds.add(c.id) : _selectedIds.remove(c.id);
                  }),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customController,
                decoration: const InputDecoration(
                  labelText: 'Custom comment',
                  hintText: 'Add a note...',
                  prefixIcon: Icon(Icons.edit_note),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final parts = widget.predefinedComments
                .where((c) => _selectedIds.contains(c.id))
                .map((c) => c.comment)
                .toList();
            final custom = _customController.text.trim();
            if (custom.isNotEmpty) parts.add(custom);
            Navigator.pop(context, parts.join(', '));
          },
          child: const Text('Add to Cart'),
        ),
      ],
    );
  }
}

class _ItemTaxDialog extends ConsumerStatefulWidget {
  final CartItem item;
  const _ItemTaxDialog({required this.item});

  @override
  ConsumerState<_ItemTaxDialog> createState() => _ItemTaxDialogState();
}

class _ItemTaxDialogState extends ConsumerState<_ItemTaxDialog> {
  late List<MenuTax> _selectedTaxes;

  @override
  void initState() {
    super.initState();
    _selectedTaxes = List.from(widget.item.appliedTaxes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final allTaxesAsync = ref.watch(allTaxesProvider);

    return AlertDialog(
      backgroundColor: theme.cardColor,
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      title: Text(
        'Taxes · ${widget.item.productName}',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      contentPadding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      content: SizedBox(
        width: 300,
        child: allTaxesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Error: $e"),
          ),
          data: (taxes) {
            if (taxes.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text("No taxes available in system."),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: taxes.length,
                itemBuilder: (ctx, i) {
                  final tax = taxes[i];
                  final isSelected = _selectedTaxes.any((t) => t.id == tax.id);

                  return CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: cs.primary,
                    title: Text(tax.name, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      "${tax.rate}${tax.isFixed ? '' : '%'}",
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedTaxes.add(
                            MenuTax(
                              id: tax.id,
                              name: tax.name,
                              rate: tax.rate,
                              isFixed: tax.isFixed,
                              isTaxOnTotal: tax.isTaxOnTotal,
                            ),
                          );
                        } else {
                          _selectedTaxes.removeWhere((t) => t.id == tax.id);
                        }
                      });
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 12, 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: () {
            ref
                .read(cartProvider.notifier)
                .updateItemTaxes(widget.item.cartItemId, _selectedTaxes);
            Navigator.pop(context);
          },
          child: const Text("Apply"),
        ),
      ],
    );
  }
}

class _TransferDialog extends ConsumerStatefulWidget {
  final CartState cartState;

  const _TransferDialog({required this.cartState});

  @override
  ConsumerState<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends ConsumerState<_TransferDialog> {
  User? _selectedStaff;
  FloorPlanTable? _selectedRoom;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final staffId = widget.cartState.bookingStaffId;
    if (staffId != null) {
      final users = ref.read(allUsersProvider).value ?? [];
      _selectedStaff = users.where((u) => u.id == staffId).firstOrNull;
    }
    final tableId = widget.cartState.floorPlanTableId;
    if (tableId != null) {
      final rooms = ref.read(allRoomsProvider).value ?? [];
      _selectedRoom = rooms.where((r) => r.id == tableId).firstOrNull;
    }
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final companyId = ref.read(selectedCompanyProvider)?.id;
    try {
      final activePosOrderId = widget.cartState.activePosOrderId;
      final bookingId = widget.cartState.bookingId;

      if (activePosOrderId != null && companyId != null) {
        final updateRequest = {
          "id": activePosOrderId,
          "userId":
              _selectedStaff?.id ?? ref.read(currentUserProvider)?.id ?? 0,
          "number": widget.cartState.orderNumber ?? "ORD-TEMP",
          "discount": widget.cartState.manualCartDiscount,
          "discountType": widget.cartState.manualCartDiscountType,
          "total": ref.read(cartTotalProvider),
          "customerId": widget.cartState.selectedCustomer?.id,
          "serviceType": widget.cartState.serviceType,
          "serviceStatus": widget.cartState.serviceStatus,
          "floorPlanTableId": _selectedRoom?.id,
          "warehouseId":
              widget.cartState.activeWarehouseId ??
              ref.read(selectedWarehouseProvider)?.id ??
              1,
        };
        await ApiClient().updatePosOrder(companyId, updateRequest);
        ref.read(kitchenSyncProvider).push();

        final oldTableId = widget.cartState.floorPlanTableId;
        final newTable = _selectedRoom;
        if (oldTableId != null &&
            newTable != null &&
            oldTableId != newTable.id) {
          try {
            await ApiClient().freeFloorPlanTable(companyId, oldTableId);
          } catch (_) {}
        }

        if (newTable != null) {
          final newOrderNumber = 'ORD- ${newTable.name}';
          ref
              .read(cartProvider.notifier)
              .setOrderContext(
                activePosOrderId,
                widget.cartState.activeWarehouseId ?? 1,
                tableId: newTable.id,
                orderNumber: newOrderNumber,
              );
        }
      }

      if (bookingId != null && companyId != null) {
        await ApiClient().updateBookingResource(
          companyId,
          bookingId,
          userId: _selectedStaff?.id,
          floorPlanTableId: _selectedRoom?.id,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        showAppSnackbar(context, ref, 'Order Transferred');
      }

      ref.read(cartProvider.notifier).clearCart();
      ref.invalidate(openOrdersProvider);
      await Future.delayed(const Duration(milliseconds: 300));
      if (companyId != null) {
        await syncLatestOrderNumber(ref, companyId);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Transfer failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final roomsAsync = ref.watch(allRoomsProvider);
    final floorPlanOn =
        ref
            .watch(appSettingsProvider)[SettingKeys.featureFloorPlanEnabled]
            ?.toLowerCase() ==
        'true';

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.swap_horiz),
          SizedBox(width: 8),
          Text('Transfer Order'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            usersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (users) {
                final enabled = users.where((u) => u.isEnabled).toList();
                return DropdownButtonFormField<User?>(
                  initialValue: _selectedStaff,
                  decoration: const InputDecoration(
                    labelText: 'Assign Staff',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<User?>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ...enabled.map(
                      (u) => DropdownMenuItem<User?>(
                        value: u,
                        child: Text(u.displayName),
                      ),
                    ),
                  ],
                  onChanged: (u) => setState(() => _selectedStaff = u),
                );
              },
            ),
            if (floorPlanOn) ...[
              const SizedBox(height: 16),
              roomsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (rooms) => DropdownButtonFormField<FloorPlanTable?>(
                  initialValue: _selectedRoom,
                  decoration: const InputDecoration(
                    labelText: 'Assign Room / Resource',
                    prefixIcon: Icon(Icons.meeting_room),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<FloorPlanTable?>(
                      value: null,
                      child: Text('No room'),
                    ),
                    ...rooms.map(
                      (t) => DropdownMenuItem<FloorPlanTable?>(
                        value: t,
                        child: Text(t.name),
                      ),
                    ),
                  ],
                  onChanged: (t) => setState(() => _selectedRoom = t),
                ),
              ),
            ],
            if (widget.cartState.bookingId != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.sync,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Calendar booking will be updated automatically.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.swap_horiz, color: Colors.white),
          label: const Text(
            'Confirm Transfer',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          onPressed: _saving ? null : _confirm,
        ),
      ],
    );
  }
}

class _SelectAvailableSpaceDialog extends ConsumerWidget {
  const _SelectAvailableSpaceDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final roomsAsync = ref.watch(allRoomsProvider);
    final spaceLabel =
        ref.watch(appSettingsProvider)[SettingKeys.tablesButtonLabel] ??
        'Table';

    return AlertDialog(
      title: Text('Select Available $spaceLabel'),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 380,
        child: roomsAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Error loading spaces: $e',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          data: (rooms) {
            final free = rooms.where((t) => t.status == 0).toList();
            if (free.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No free ${spaceLabel.toLowerCase()}s available',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: free.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final t = free[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.15,
                      ),
                      child: Icon(
                        Icons.table_restaurant,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      t.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => Navigator.pop(ctx, t),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// ── Void Reason Dialog ────────────────────────────────────────────────────────

class _VoidReasonDialog extends ConsumerStatefulWidget {
  final String? orderNumber;
  const _VoidReasonDialog({this.orderNumber});

  @override
  ConsumerState<_VoidReasonDialog> createState() => _VoidReasonDialogState();
}

class _VoidReasonDialogState extends ConsumerState<_VoidReasonDialog> {
  final _customCtrl = TextEditingController();
  String? _selected;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reasonsAsync = ref.watch(_voidReasonsDialogProvider);

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enter void reason',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (widget.orderNumber != null)
            Text(
              'Enter or select void reason for voiding "${widget.orderNumber}"',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            reasonsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (reasons) {
                if (reasons.isEmpty) return const SizedBox.shrink();
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasons.map((r) {
                    final active = _selected == r;
                    return ChoiceChip(
                      label: Text(r),
                      selected: active,
                      onSelected: (_) => setState(() {
                        _selected = active ? null : r;
                        if (!active) _customCtrl.clear();
                      }),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _customCtrl,
              decoration: InputDecoration(
                hintText: 'Enter void reason here',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {},
                ),
              ),
              onChanged: (v) {
                if (v.isNotEmpty) setState(() => _selected = null);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final reason = _selected ?? _customCtrl.text.trim();
            if (reason.isEmpty) return;
            Navigator.pop(context, reason);
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

// Lightweight provider just for the dialog — void reason names from the local
// Drift cache so the void flow works offline.
final _voidReasonsDialogProvider = StreamProvider.autoDispose<List<String>>((
  ref,
) {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const <String>[]);
  final db = ref.watch(appDatabaseProvider);
  return db
      .watchVoidReasons(companyId)
      .map(
        (rows) => rows.map((r) => r.name).where((n) => n.isNotEmpty).toList(),
      );
});
