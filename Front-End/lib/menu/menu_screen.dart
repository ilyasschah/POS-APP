import 'dart:convert';
import 'package:pos_app/core/ilyass_screen.dart';
import 'package:pos_app/session/session_screen.dart';
import 'package:pos_app/barcode/scan_bus.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pos_app/core/dropdown_options.dart';
import 'package:pos_app/core/sound_service.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/menu/open_orders_screen.dart';
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/product/product_provider.dart';
import 'package:pos_app/product/product_model.dart';
import 'package:pos_app/product/product_sort.dart';
import 'package:pos_app/session/session_gate.dart';
import 'package:pos_app/product/product_search.dart';
import 'package:pos_app/product/product_search_bar.dart';
import 'package:pos_app/barcode/barcode_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/customer/customer_picker_dialog.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/stock/warehouse_model.dart';
import 'package:pos_app/stock/warehouse_picker_dialog.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/menu/discount_dialog.dart';
import 'package:pos_app/menu/cart_keypad.dart';
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
// import 'package:pos_app/menu/open_orders_screen.dart';
import 'package:pos_app/printer/cash_drawer_service.dart';
import 'package:pos_app/printer/kitchen_ticket_data.dart';
import 'package:pos_app/printer/receipt_printer_service.dart';
import 'package:pos_app/printer/printer_routing_service.dart';
import 'package:pos_app/refund/refund_dialog.dart';
import 'package:pos_app/security/security_guard.dart';
import 'package:pos_app/security/security_keys.dart';
import 'package:pos_app/utils/error_handler.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:pos_app/barcode/nomenclature/barcode_matcher.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rule.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rules_provider.dart';
import 'package:pos_app/menu/weigh_item_dialog.dart';
import 'package:pos_app/modifier/customize_item_sheet.dart';
import 'package:pos_app/modifier/modifier_models.dart';
import 'package:pos_app/uom/unit_of_measure.dart';
import 'package:pos_app/customer_display/customer_display_provider.dart';
import 'package:pos_app/customer_display/customer_display_state.dart';
import 'package:pos_app/utils/customer_display_service.dart';
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

  /// Leaves the POS via a header button, dealing with the open order first,
  /// then navigating to [initialIndex] in [MainLayout].
  ///
  /// Shared by the Tables and Bookings buttons because they must treat the
  /// cart the same way, and did not: Tables parked the order while Bookings
  /// called `clearCart()` outright, throwing away whatever was rung up. An
  /// order left behind is recoverable; a discarded one is not.
  ///
  /// Two cases:
  ///  • **Empty cart with an active order** — the order exists but holds
  ///    nothing, so it is deleted rather than parked as an empty shell.
  ///  • **Cart with items** — parked via `saveAndSuspend`, which upserts the
  ///    row this cart is already backed by. A save failure ABORTS the
  ///    navigation, so the operator sees the error while still on the order
  ///    instead of arriving at the floor plan having quietly lost it.
  Future<void> _leavePosFor(int initialIndex) async {
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
    } else if (companyId != null) {
      final user = ref.read(currentUserProvider);
      try {
        await ref
            .read(cartProvider.notifier)
            .saveAndSuspend(companyId: companyId, userId: user?.id ?? 0);
      } catch (e) {
        if (mounted) {
          showAppSnackbar(
            context,
            ref,
            AppLocalizations.of(context).couldNotSaveOrder('$e'),
            isError: true,
          );
        }
        return;
      }
    }

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MainLayout(initialIndex: initialIndex),
        ),
        (route) => false,
      );
    }
  }

  /// Prints the **Addition** — the pre-bill the customer settles against.
  ///
  /// 🚨 This banks NOTHING: no document, no payment, no stock movement, no
  /// loyalty accrual, no sync. It is a read-only render of the live cart, so
  /// pressing it five times is harmless and none of it shows up in the reports.
  /// Everything that turns a cart into a sale lives in `PaymentCheckoutDialog`.
  ///
  /// Reuses `printCartReceipt` with `isGuestCheck: true`, which the builder
  /// already understood but nothing ever passed — that flag adds the
  /// "*** GUEST CHECK ***" banner and suppresses the parts that would be lies
  /// on an unpaid bill: the payment/change rows, points earned/balance, and the
  /// barcode (which encodes a sale that does not exist yet).
  Future<void> _printAddition(BuildContext context, WidgetRef ref) async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) return;

    try {
      final notifier = ref.read(cartProvider.notifier);
      final settings = ref.read(appSettingsProvider);

      Uint8List? logoBytes;
      final logoB64 = company.logo;
      if (logoB64 != null && logoB64.isNotEmpty) {
        try {
          logoBytes = base64Decode(logoB64);
        } catch (_) {}
      }

      // ⚠️ Totals come from the cart notifier, never re-derived here — line tax
      // has exactly one source of truth (handoff §3), and `discountTotal`
      // already includes the per-item promotion, so adding it again would
      // double-count it. Same composition the checkout dialog snapshots.
      await ReceiptPrinterService().printCartReceipt(
        company: company,
        cashier: ref.read(currentUserProvider),
        customer: cart.selectedCustomer,
        orderNumber: cart.orderNumber ?? 'WALK-IN',
        // No document number: nothing has been banked, so the PDF names itself
        // after the order + print time.
        printTime: DateTime.now(),
        items: cart.items,
        subtotal: notifier.subtotal,
        totalDiscount:
            notifier.discountTotal +
            notifier.customerDiscountAmount +
            notifier.manualCartDiscountAmount,
        totalTax: notifier.taxTotal,
        grandTotal: ref.read(cartTotalProvider),
        currencySymbol: ref.read(currencySymbolProvider),
        logoBytes: logoBytes,
        roleSettings: settings,
        isGuestCheck: true,
      );

      if (context.mounted) {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).additionPrinted,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).kitchenPrintError('$e'),
          isError: true,
        );
      }
    }
  }

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
              Text(AppLocalizations.of(context).activePromotions),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: _activePromos.isEmpty
                ? Text(AppLocalizations.of(context).noActivePromotions)
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
              child: Text(AppLocalizations.of(context).actionClose),
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
    ref.watch(
      cartProvider.select(
        (c) => (
          c.serviceType,
          c.serviceStatus,
          c.selectedCartItemId,
          c.items.isEmpty,
          c.activePosOrderId,
        ),
      ),
    );
    final cartState = ref.read(cartProvider);
    // Drive the header customer button off the CART's own customer — the single
    // source of truth for this order — not the parallel currentCustomerProvider,
    // which drifts out of sync (a reopened order showed a stale Walk-in/empty
    // name while the cart held the right one). select() rebuilds the header only
    // when the customer actually changes.
    final currentCustomer = ref.watch(
      cartProvider.select((c) => c.selectedCustomer),
    );
    final asyncCustomers = ref.watch(selectableCustomersProvider);
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
    final showCashDrawerBtn =
        settings[SettingKeys.showCashDrawerBtn]?.toLowerCase() != 'false';
    final showWarehouseBtn =
        settings[SettingKeys.showWarehouseBtn]?.toLowerCase() != 'false';
    final showBookingBtn =
        settings[SettingKeys.showBookingBtn]?.toLowerCase() != 'false';
    final showTablesBtn =
        settings[SettingKeys.showTablesBtn]?.toLowerCase() != 'false';
    final showKitchenBtn =
        settings[SettingKeys.showKitchenBtn]?.toLowerCase() != 'false';
    final showAdditionBtn =
        settings[SettingKeys.showAdditionBtn]?.toLowerCase() != 'false';
    final showCloseRegisterBtn =
        settings[SettingKeys.showCloseRegisterBtn]?.toLowerCase() != 'false';
    final showTaxBtn =
        settings[SettingKeys.showTaxBtn]?.toLowerCase() != 'false';
    final showCommentBtn =
        settings[SettingKeys.showCommentBtn]?.toLowerCase() != 'false';
    final showModifiersBtn =
        settings[SettingKeys.showModifiersBtn]?.toLowerCase() != 'false';
    // A sync can swap an offline-created table's temp id out from under an open
    // cart. This stream re-emits when that lands, so heal the cart's id then —
    // otherwise the header falls back to 'Table #-1784…' for the rest of the sale.
    ref.listen(allRoomsProvider, (previous, next) {
      next.whenData((_) => ref.read(cartProvider.notifier).healTableId());
    });
    ref.listen(selectableCustomersProvider, (previous, next) {
      next.whenData((all) {
        final cart = ref.read(cartProvider);
        // A booking order carries the reservation's customer (seeded by
        // startBookingOrder). Never auto-reset it to Walk-in — doing so was
        // overwriting "test" with Walk-in in the header when the seed lost a
        // race with this listener.
        if (cart.bookingId != null) return;
        final customers = all.where((c) => c.isCustomer).toList();
        if (cart.selectedCustomer == null && customers.isNotEmpty) {
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
        // Hamburger as the shell's POS tab, back arrow if ever pushed — the
        // mounting decides. See `lib/core/ilyass_screen.dart`.
        leading: IlyassLeading.maybe(
          context,
          widget.showAppBarNavigation ? widget.onToggleSidebar : null,
        ),
        titleSpacing: 0,
        centerTitle: false,
        // Order-control buttons live in the AppBar title slot (which, unlike
        // actions:, is width-bounded) so they scroll horizontally instead of
        // running off a small (7") screen.
        title: SingleChildScrollView(
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
                    final customers = all.where((c) => c.isCustomer).toList();
                    return _MenuHeaderActionBtn(
                      // Reflect live state: show the selected customer's
                      // name (highlighted) instead of a generic label.
                      icon: currentCustomer != null
                          ? Icons.person
                          : Icons.person_outline,
                      label:
                          currentCustomer?.name ??
                          AppLocalizations.of(context).customerLabel,
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
                        final companyId = ref.read(selectedCompanyProvider)?.id;
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
                      AppLocalizations.of(context).orderTypeLabel,
                  customTint:
                      _kOrderTypePalette[customServiceTypes
                          .indexWhere((t) => t.id == cartState.serviceType)
                          .clamp(0, _kOrderTypePalette.length - 1)],
                  onTap: () async {
                    final val = await showDialog<int>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(
                          AppLocalizations.of(context).selectOrderType,
                        ),
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
                                    if (e.key > 0) const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, e.value.id),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              _kOrderTypePalette[e.key %
                                                  _kOrderTypePalette.length],
                                          minimumSize: const Size(0, 100),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
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
                        final selectedSpace = await showDialog<FloorPlanTable>(
                          context: context,
                          builder: (_) => const _SelectAvailableSpaceDialog(),
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
                          // Not `?? 1`: selectedWarehouseProvider is seeded
                          // asynchronously, so substituting 1 mid-seed pins
                          // the order to a warehouse the company may not own
                          // (company 25 owns 17 and 20 — there is no 1) AND
                          // outranks Order.DefaultWarehouseId, because
                          // effectiveWarehouseId accepts any id > 0.
                          'warehouseId': ref
                              .read(cartProvider.notifier)
                              .effectiveWarehouseId,
                        });
                        ref.read(kitchenSyncProvider).push();

                        if (!context.mounted) return;

                        ref
                            .read(cartProvider.notifier)
                            .setOrderContext(
                              cart.activePosOrderId!,
                              ref
                                  .read(cartProvider.notifier)
                                  .effectiveWarehouseId,
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
                            title: Text(
                              AppLocalizations.of(context).serviceStatus,
                            ),
                            content: Text(
                              AppLocalizations.of(context).noServiceStatuses,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  AppLocalizations.of(context).actionClose,
                                ),
                              ),
                            ],
                          );
                        }
                        return AlertDialog(
                          title: Text(
                            AppLocalizations.of(context).selectServiceStatus,
                          ),
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
                                      if (e.key > 0) const SizedBox(width: 12),
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
                                            padding: const EdgeInsets.symmetric(
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
                  label: AppLocalizations.of(context).posDiscount,
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
              if (showTaxBtn)
                _MenuHeaderActionBtn(
                  icon: Icons.receipt,
                  label: AppLocalizations.of(context).posTax,
                  // Greyed out until a cart line is selected — the tax
                  // override acts on one line, so there's nothing to change
                  // otherwise. Same gating as Quantity and Comment (replaces
                  // the old always-on button + "select an item" snackbar).
                  onTap: cartState.selectedCartItemId == null
                      ? null
                      : () => ref.read(securityGuardProvider).guard(
                          context,
                          SecurityKeys.taxOverride,
                          () {
                            final cart = ref.read(cartProvider);
                            final item = cart.items
                                .where(
                                  (i) =>
                                      i.cartItemId == cart.selectedCartItemId,
                                )
                                .firstOrNull;
                            if (item == null) return;
                            showDialog(
                              context: context,
                              builder: (_) => _ItemTaxDialog(item: item),
                            );
                          },
                        ),
                ),
              if (showCommentBtn)
                _MenuHeaderActionBtn(
                  icon: Icons.comment_outlined,
                  label: AppLocalizations.of(context).posComment,
                  // Greyed out until a cart line is selected — a comment
                  // belongs to one line, so there is nothing to edit
                  // otherwise. Same gating as Quantity.
                  onTap: cartState.selectedCartItemId == null
                      ? null
                      : () async {
                          final cart = ref.read(cartProvider);
                          final item = cart.items
                              .where(
                                (i) => i.cartItemId == cart.selectedCartItemId,
                              )
                              .firstOrNull;
                          if (item == null) return;
                          // Just the note now. The predefined-comment
                          // catalogue this used to load is retired —
                          // modifiers do that job with prices, rules and
                          // reporting rows (backlog 38, phase 6).
                          final result = await showDialog<String?>(
                            context: context,
                            builder: (_) => _ItemNoteDialog(
                              productName: item.productName,
                              initialComment: item.comment,
                              confirmLabel: AppLocalizations.of(
                                context,
                              ).actionSave,
                            ),
                          );
                          if (result == null) return;
                          ref
                              .read(cartProvider.notifier)
                              .setItemComment(
                                item.cartItemId,
                                result.trim().isEmpty ? null : result.trim(),
                              );
                        },
                ),
              if (showModifiersBtn)
                _MenuHeaderActionBtn(
                  icon: Icons.tune,
                  label: AppLocalizations.of(context).posModifiers,
                  // Greyed out until a cart line is selected — modifiers
                  // belong to one line. Same gating as Comment and Quantity.
                  onTap: cartState.selectedCartItemId == null
                      ? null
                      : () => _editItemModifiers(context),
                ),
              if (showTransferBtn)
                _MenuHeaderActionBtn(
                  icon: Icons.swap_horiz,
                  label: AppLocalizations.of(context).posTransfer,
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
                  label: AppLocalizations.of(context).posRefund,
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
              if (showCashDrawerBtn)
                _MenuHeaderActionBtn(
                  icon: Icons.point_of_sale,
                  label: AppLocalizations.of(context).posOpenDrawer,
                  // Admin-only the moment the admin sets CashDrawer.Open to
                  // level 1 in Users & Security; seeded at level 0, so out
                  // of the box a cashier may still pop the drawer. Refused
                  // with a DIALOG, not a toast — see guardWithDialog.
                  onTap: () => ref
                      .read(securityGuardProvider)
                      .guardWithDialog(
                        context,
                        SecurityKeys.cashDrawerOpen,
                        () => _openCashDrawerFromTill(context, ref),
                      ),
                ),

              if (showKitchenBtn)
                _MenuHeaderActionBtn(
                  icon: Icons.soup_kitchen,
                  label: AppLocalizations.of(context).posKitchen,
                  onTap: cartState.items.isEmpty
                      ? null
                      : () async {
                          try {
                            final roleSettings = ref.read(appSettingsProvider);
                            final cashier = ref.read(currentUserProvider);
                            final cart = ref.read(cartProvider);
                            final cartItems = cart.items;
                            // 🚨 Was a hardcoded English switch
                            // (0→"Dine In", 1→"Takeaway", _→"Order") that
                            // ignored the venue's configured service types
                            // entirely. It didn't even match the shipped
                            // defaults ("Dine-In"), and every type beyond
                            // the first two — Delivery, and anything the
                            // operator added — reached the kitchen as the
                            // meaningless word "Order".
                            final serviceLabel = KitchenTicketData.serviceLabel(
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .customServiceTypes,
                              cart.serviceType,
                              fallback: AppLocalizations.of(context).posOrder,
                            );
                            // The table, resolved to its NAME. Previously it
                            // reached the kitchen only by accident, embedded
                            // in the order number.
                            final tableName = KitchenTicketData.tableName(
                              ref.read(allRoomsProvider).value ?? const [],
                              cart.floorPlanTableId,
                            );
                            final orderNo = cart.orderNumber ?? 'WALK-IN';
                            final cashierName =
                                cashier?.displayName ?? 'Unknown';

                            // If any printer has "Print kitchen ticket" on,
                            // split the order across those printers by
                            // category (food→kitchen, drinks→bar). Otherwise
                            // fall back to the legacy single all-items ticket
                            // on the Kitchen printer — unchanged behaviour
                            // until the operator opts printers in.
                            final routing = ref.read(printerRoutingProvider);
                            var printed = 0;
                            var fellBack = false;
                            if (routing.hasKitchenStations) {
                              printed = await routing.printStationTickets(
                                items: cartItems,
                                orderNumber: orderNo,
                                cashierName: cashierName,
                                serviceType: serviceLabel,
                                tableName: tableName,
                                printTime: DateTime.now(),
                              );
                              // 🚨 A station only prints the items matching
                              // its printer group, and skips the order
                              // entirely when none match. With stations
                              // configured but none covering this cart, the
                              // button previously did *nothing at all* — no
                              // ticket, no error, no message. Fall back to
                              // the full ticket so pressing Kitchen always
                              // produces one.
                              fellBack = printed == 0;
                            }
                            if (printed == 0) {
                              await ReceiptPrinterService().printKitchenTicket(
                                orderNumber: orderNo,
                                cashierName: cashierName,
                                serviceType: serviceLabel,
                                tableName: tableName,
                                printTime: DateTime.now(),
                                items: cartItems,
                                roleSettings: roleSettings,
                              );
                              printed = 1;
                            }
                            // Always confirm. Printing is fire-and-forget at
                            // the dispatcher (a dead printer must never
                            // crash a sale), so without this the operator
                            // has no way to tell a sent ticket from a
                            // silently dropped one.
                            if (context.mounted) {
                              showAppSnackbar(
                                context,
                                ref,
                                fellBack
                                    ? AppLocalizations.of(
                                        context,
                                      ).kitchenNoStationMatched
                                    : AppLocalizations.of(
                                        context,
                                      ).kitchenTicketsPrinted(printed),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showAppSnackbar(
                                context,
                                ref,
                                AppLocalizations.of(
                                  context,
                                ).kitchenPrintError('$e'),
                                isError: true,
                              );
                            }
                          }
                        },
                ),

              // ── Addition (pre-bill / guest check) ─────────────────────
              // Prints what the customer OWES so they can settle up. It
              // banks nothing: no document, no payment, no stock movement,
              // no loyalty. That separation is the whole point — pressing it
              // twice must be harmless, and it must never look like a sale
              // in the reports.
              if (showAdditionBtn)
                _MenuHeaderActionBtn(
                  icon: Icons.receipt_long,
                  label: AppLocalizations.of(context).posAddition,
                  onTap: cartState.items.isEmpty
                      ? null
                      : () => _printAddition(context, ref),
                ),

              // Close the register from the till itself. Ending the day
              // used to mean leaving the POS, finding the session screen
              // and closing from there — three navigations for the last
              // thing a cashier does every single shift.
              if (showCloseRegisterBtn)
                _MenuHeaderActionBtn(
                  icon: Icons.lock_outline,
                  label: AppLocalizations.of(context).closeRegister,
                  onTap: () => SessionScreen.show(context),
                ),
              // --- Warehouse Switcher (centered picker, like the customer one) ---
              if (showWarehouseBtn)
                Consumer(
                  builder: (context, ref, child) {
                    final selectedWarehouse = ref.watch(
                      selectedWarehouseProvider,
                    );
                    final warehousesAsync = ref.watch(allWarehousesProvider);

                    return _MenuHeaderActionBtn(
                      icon: Icons.warehouse,
                      label:
                          selectedWarehouse?.name ??
                          AppLocalizations.of(context).warehouse,
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
                  label: AppLocalizations.of(context).posBookings,
                  // Index 2 is Bookings. Parks the order on the way out, same as
                  // Tables — it used to `clearCart()` outright, silently binning
                  // whatever the operator had rung up.
                  onTap: () => _leavePosFor(2),
                ),
              if (floorPlanEnabled && showTablesBtn)
                _MenuHeaderActionBtn(
                  icon: Icons.grid_view,
                  label:
                      settings[SettingKeys.tablesButtonLabel] ??
                      AppLocalizations.of(context).tablesLabel,
                  onTap: () => _leavePosFor(4), // Index 4 is the floor plan
                ),

              // Promotion — special override action, pinned to the far right. Amber
              // star icon with a count badge.
              if (_activePromos.isNotEmpty)
                _MenuHeaderActionBtn(
                  icon: Icons.star,
                  label: AppLocalizations.of(context).posPromos,
                  iconColor: context.warningColor,
                  badgeCount: _activePromos.length,
                  onTap: () => _showActivePromosPopup(context),
                ),
            ],
          ),
        ),
        // Kitchen-ready notification stays pinned to the right, outside the
        // overflow bar, so it's always visible when the KDS marks orders ready.
        actions: [
          Builder(
            builder: (context) {
              final readyCount = ref.watch(readyOrdersCountProvider).value ?? 0;
              if (readyCount == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  tooltip: AppLocalizations.of(context).ordersReady(readyCount),
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
          const SizedBox(width: 4),
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

  /// Re-opens the customise sheet for the SELECTED cart line.
  ///
  /// The sheet is otherwise only shown on the way in, so a cashier who picked
  /// the wrong sauce had to void the line and ring it again. It pre-selects
  /// from the line ([showCustomizeItemSheet]'s `initial`), so this is an edit
  /// rather than a fresh choice.
  Future<void> _editItemModifiers(BuildContext context) async {
    final cart = ref.read(cartProvider);
    final item = cart.items
        .where((i) => i.cartItemId == cart.selectedCartItemId)
        .firstOrNull;
    if (item == null) return;

    // Read straight from Drift — see the note on the add-to-cart path. Going
    // through the autoDispose family provider's `.future` resolves before the
    // watch-stream emits, so a product WITH groups opens an empty sheet.
    List<ModifierGroup> groups = const [];
    try {
      final rows = await ref
          .read(appDatabaseProvider)
          .modifierGroupsForProductDirect(
            ref.read(selectedCompanyProvider)?.id ?? 0,
            item.productId,
          );
      groups = modifierGroupsFromRows(rows);
    } catch (_) {}

    if (!context.mounted) return;
    if (groups.isEmpty) {
      // Nothing to choose. Say so rather than opening an empty sheet — the
      // product simply has no groups attached in Management → Modifier Groups.
      showAppSnackbar(
        context,
        ref,
        AppLocalizations.of(context).noModifierGroupsExistYet,
      );
      return;
    }

    final result = await showCustomizeItemSheet(
      context,
      itemName: item.productName,
      basePrice: item.basePrice,
      groups: groups,
      initial: item.selectedModifiers,
      initialNote: item.comment,
    );
    // Null means backed out, and that must leave the line exactly as it was.
    if (result == null) return;

    ref
        .read(cartProvider.notifier)
        .setItemModifiers(
          item.cartItemId,
          result.modifiers,
          comment: result.note,
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
  // Current page in the paged Grid layout (ignored in the scrollable List one).
  int _currentPage = 0;

  /// Scans that did not arrive through the search field: the global keyboard
  /// listener, and the debug panel's simulator. Both are routed into
  /// [_handleBarcodeSubmit] — the same method the search field calls — so
  /// there is exactly one decode path to reason about.
  StreamSubscription<Scan>? _scanSub;
  List<PromotionDto> _activePromos = const [];
  Map<int, double> _stockMap = const {};
  Map<int, StockControl> _stockControlMap = const {};
  String? _activeSearchMode;
  final TextEditingController _searchCtrl = TextEditingController();
  // Drives the scrollable List-layout grid; snapped back to the top whenever
  // the browsed group or the search query changes.
  final ScrollController _gridScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scanSub = ref.read(scanBusProvider).stream.listen((scan) {
      // 🚨 A HARDWARE scan only acts while the POS tab is the one on screen.
      // This screen stays mounted behind Documents, Settings and the rest
      // (LazyIndexedStack keeps it alive), so without this a barcode read while
      // someone browsed reports would quietly add a line to a cart nobody is
      // looking at. A SIMULATED scan is someone deliberately testing from the
      // debug panel and is always delivered.
      if (scan.source == ScanSource.hardware &&
          ref.read(mainNavigationIndexProvider) != 0) {
        return;
      }
      _handleBarcodeSubmit(scan.code);
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _searchCtrl.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  /// Reset the browse position when the group or search query changes: the
  /// paged Grid layout jumps back to page 1, the scrollable List layout to the
  /// top — so a fresh list never opens mid-scroll or mid-page.
  void _resetBrowsePosition() {
    if (mounted && _currentPage != 0) setState(() => _currentPage = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _gridScrollController.hasClients) {
        _gridScrollController.jumpTo(0);
      }
    });
  }

  /// Called when the search field is submitted (e.g. barcode scanner sends Enter).
  ///
  /// The scan is read through the company's barcode nomenclature: the first rule
  /// whose pattern matches decides whether the code is a plain product, a
  /// weighed one, one carrying a price, or one carrying a discount. On a match
  /// the item is added to the cart and the search field is cleared.
  Future<void> _handleBarcodeSubmit(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    final settings = ref.read(appSettingsProvider);
    final allProducts = ref.read(allProductsListProvider).value ?? [];
    // Both barcode stores — the `products.barcode` column AND the `barcodes`
    // table the product editor's Barcodes tab writes to. Without the second one
    // a barcode an admin deliberately added was findable in the Products screen
    // yet did nothing when scanned at the till (backlog item 34).
    final extraBarcodes =
        ref.read(allBarcodesByProductIdProvider).value ?? const {};
    final sellable = allProducts.where((p) => p.isEnabled);

    final scan = matchBarcode(trimmed, readBarcodeRules(ref));

    Product? match;
    double quantity;
    double? discountPercent;

    // The key excludes any embedded value, so every weight of one product
    // resolves to the same lookup. Code is tried first, then barcodes —
    // deterministic where a single pass would take whichever Drift returned
    // first when both kinds of match existed.
    final key = scan?.productKey ?? trimmed;
    match =
        sellable
            .where((p) => p.code?.toLowerCase() == key.toLowerCase())
            .firstOrNull ??
        findProductByBarcode(sellable, key, extraBarcodes: extraBarcodes);

    if (match == null) {
      // The reject tone fires for ANY unmatched scan, including the silent case
      // below: a cashier scanning head-down needs to hear that nothing went in
      // the cart, which is precisely the gap ⭐10 describes. The message stays
      // conditional; the sound does not.
      SoundService.instance.play(settings, PosSound.scanFail);
      // A rule claimed the barcode but no product carries that key — worth
      // saying so, because the usual cause is a product whose stored barcode
      // does not have the embedded positions zeroed. A plain unmatched scan
      // stays silent and leaves the text for the cashier to search with.
      if (scan != null && scan.rule.type != BarcodeRuleType.unit && mounted) {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).scaleBarcodeProductNotFound(key),
          isError: true,
        );
      }
      return;
    }

    switch (scan?.rule.type) {
      case BarcodeRuleType.weighted:
        quantity = scan!.value;

      case BarcodeRuleType.priced:
        // The label carries a line TOTAL, so the quantity is whatever that
        // total buys at the product's unit price.
        final unitPrice = match.price;
        if (unitPrice <= 0) {
          if (mounted) {
            showAppSnackbar(
              context,
              ref,
              AppLocalizations.of(context).cannotCalcQuantity,
              isError: true,
            );
          }
          return;
        }
        quantity = scan!.value / unitPrice;

      case BarcodeRuleType.discounted:
        // The value is a percentage off this line, not a quantity.
        quantity = 1.0;
        discountPercent = scan!.value;

      case BarcodeRuleType.unit:
      case null:
        quantity = 1.0;
    }

    // A priced label dividing into an unrepresentable fraction (12.50 / 3.00)
    // genuinely produces 4.166666…, which must not reach a decimal(18,4)
    // column as one figure and the receipt as another. Snapped at the storage
    // precision, NOT the unit's rounding — the latter would quantise a real
    // 0.5 on a pcs product up to 1.
    quantity = snapToStorage(quantity);

    if (quantity <= 0) {
      if (mounted) {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).parsedQuantityZero,
          isError: true,
        );
      }
      return;
    }

    // Ensure an active order exists (same logic as product-card tap)
    final cartState = ref.read(cartProvider);
    if (cartState.activePosOrderId == null) {
      final floorPlanOn =
          settings[SettingKeys.featureFloorPlanEnabled]?.toLowerCase() ==
          'true';
      final tablelessAllowed =
          settings[SettingKeys.allowTablelessOrders]?.toLowerCase() == 'true';
      if (cartState.serviceType != 0 || !floorPlanOn || tablelessAllowed) {
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
            AppLocalizations.of(context).errorCreatingOrder('$e'),
            isError: true,
          );
          return;
        }
      } else {
        if (mounted) {
          showAppSnackbar(
            context,
            ref,
            AppLocalizations.of(context).selectTableFirst,
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
        uomId: match.uomId,
        isToWeigh: match.isToWeigh,
        isService: match.isService,
      );
      ref
          .read(cartProvider.notifier)
          .addItem(
            menuProduct,
            quantity: quantity,
            measurementUnit: match.measurementUnit,
          );

      // A discount barcode carries a percentage for the line it was scanned
      // onto, so it is applied after the item exists rather than baked into
      // addItem — which has no notion of a scanned discount.
      //
      // setItemDiscount stores an ABSOLUTE per-unit amount (discountType 1);
      // inputValue/inputType keep the percentage the label actually carried, so
      // reopening the discount dialog shows "20%" rather than the money it
      // worked out to.
      if (discountPercent != null && discountPercent > 0) {
        // The LAST matching line: with `Order.SeparateRowForEachItem` on, the
        // scan just appended a new row, and the discount belongs to that one
        // rather than to an identical product added earlier.
        final lines = ref
            .read(cartProvider)
            .items
            .where((i) => i.productId == match!.id);
        final line = lines.isEmpty ? null : lines.last;
        if (line != null) {
          ref
              .read(cartProvider.notifier)
              .setItemDiscount(
                line.cartItemId,
                match.price * (discountPercent / 100),
                1,
                inputValue: discountPercent,
                inputType: 0,
              );
        }
      }

      // Sounded here, not at the match: everything between (stock guards, the
      // age-restriction dialog, tax resolution) can still abandon the scan, and
      // a confirmation tone for an item that never reached the cart is worse
      // than no tone at all.
      SoundService.instance.play(settings, PosSound.scanOk);

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

    // 🚨 Everything here is in the STOCK unit, and [quantity] arrives in the
    // SALE unit. Comparing them raw made a gram-priced product unsellable: one
    // gram of saffron read as one kilogram, 0.500 − 1 went negative, and the
    // out-of-stock dialog fired on the first tap of a product with half a kilo
    // on the shelf. The cart lines get the same treatment — each carries its
    // own uomId, and a cart can hold the same product under two of them.
    final currentStock = _stockMap[product.id] ?? 0;
    final cartQty = ref
        .read(cartProvider)
        .items
        .where((i) => i.productId == product.id)
        .fold(0.0, (sum, i) => sum + uomToReference(i.quantity, i.uomId));
    final projectedQuantity = snapToStorage(
      currentStock - cartQty - uomToReference(quantity, product.uomId),
    );

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
        title: Text(
          AppLocalizations.of(context).productRunningLow(product.name),
        ),
        content: Text(
          // The projection came out of the stock ledger, so it is named in the
          // STOCK unit — quoting the sale unit here would read "0.4 g" under a
          // product holding 400 grams.
          AppLocalizations.of(context).lowStockAddAnyway(
            formatQuantityValue(projectedQuantity, product.stockUom.id),
            product.stockUom.code,
          ),
          style: tt.bodyMedium?.copyWith(color: context.navMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).actionProceedAnyway),
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
          title: Text(
            AppLocalizations.of(context).productOutOfStock(product.name),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).noStockAvailableIn(
                  selectedWh?.name ??
                      AppLocalizations.of(context).theSelectedWarehouse,
                ),
                style: tt.bodyMedium,
              ),
              const Gap(16),
              if (fallbacks.isEmpty)
                Text(
                  AppLocalizations.of(context).notAvailableOtherWarehouse,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                )
              else ...[
                Text(
                  AppLocalizations.of(context).availableIn,
                  style: tt.labelLarge,
                ),
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
                      title: Text(
                        whNames[e.key] ??
                            AppLocalizations.of(
                              context,
                            ).warehouseNumbered('${e.key}'),
                      ),
                      // Warehouse figures are stock-ledger figures: named in the
                      // reference unit, at that unit's precision.
                      subtitle: Text(
                        AppLocalizations.of(context).quantityInStock(
                          '${formatQuantityValue(e.value, product.stockUom.id)} '
                          '${product.stockUom.code}',
                        ),
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () {
                          ref.read(cartProvider.notifier).setWarehouseId(e.key);
                          Navigator.pop(ctx);
                          showAppSnackbar(
                            context,
                            ref,
                            AppLocalizations.of(context).switchedToWarehouse(
                              whNames[e.key] ??
                                  AppLocalizations.of(context).warehouse,
                            ),
                            isError: false,
                          );
                        },
                        child: Text(AppLocalizations.of(context).actionSwitch),
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
              child: Text(AppLocalizations.of(context).actionClose),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reset to page 1 / scroll top when the browsed group or search changes.
    ref.listen(currentGroupProvider, (_, __) => _resetBrowsePosition());
    ref.listen(searchQueryProvider, (_, __) => _resetBrowsePosition());
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
    // Secondary barcodes (the `barcodes` table). Watched so a barcode added on
    // another terminal shows up here after the next sync without a reopen.
    final extraBarcodes =
        ref.watch(allBarcodesByProductIdProvider).value ?? const {};

    if (selectedCompany == null) {
      return Center(
        child: Text(AppLocalizations.of(context).noCompanySelected),
      );
    }

    // 🚨 No session, no selling. Rendered as an ACTIONABLE screen with an
    // "Open Register" button rather than an empty grid or an error — a cashier
    // who cannot sell must be shown the one thing that fixes it, not left
    // guessing. `sessionGateProvider` fails OPEN when it cannot determine the
    // state, so a transient fault never lands here.
    final gate = ref.watch(sessionGateProvider);
    if (gate == SessionGate.blockedNoSession ||
        gate == SessionGate.blockedNotTrading) {
      return SessionBlockedScreen(gate: gate);
    }

    if (asyncGroups.isLoading || asyncProducts.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (asyncGroups.hasError || asyncProducts.hasError) {
      return Center(child: Text(AppLocalizations.of(context).errorLoadingData));
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
      // `isEnabled` stays HERE, not in productMatchesSearch: the till must never
      // offer a disabled product, while the Products management screen must be
      // able to find one. See the predicate's doc comment.
      final List<Product> filtered = allProducts
          .where(
            (p) =>
                p.isEnabled &&
                productMatchesSearch(
                  p,
                  searchQuery,
                  effectiveMode,
                  extraBarcodes: extraBarcodes[p.id] ?? const [],
                ),
          )
          .toList();
      sortProductsBy(filtered, sortBy);
      itemsToDisplay = filtered;
    } else {
      final visibleGroups = allGroups
          .where((g) => g.parentGroupId == currentGroup?.id)
          .toList();
      final List<Product> visibleProducts = allProducts
          .where((p) => p.productGroupId == currentGroup?.id && p.isEnabled)
          .toList();
      sortProductsBy(visibleProducts, sortBy);
      itemsToDisplay = [...visibleGroups, ...visibleProducts];
    }

    final showSearchBtn =
        settings[SettingKeys.showSearchBtn]?.toLowerCase() != 'false';
    // Layout mode: 'Grid' pages Columns × Rows with a first/prev/next/last bar;
    // 'List' scrolls the whole set using only the column count.
    final isGridLayout =
        settings[SettingKeys.menuLayoutMode]?.toLowerCase() == 'grid';
    final cols = int.tryParse(settings[SettingKeys.menuGridCols] ?? '4') ?? 4;
    final rows = int.tryParse(settings[SettingKeys.menuGridRows] ?? '4') ?? 4;

    // Paged Grid layout only: slice the full list into Columns × Rows pages.
    final itemsPerPage = cols * rows;
    final totalPages = itemsToDisplay.isEmpty
        ? 1
        : ((itemsToDisplay.length + itemsPerPage - 1) ~/ itemsPerPage);
    final safePage = _currentPage.clamp(0, totalPages - 1);
    // What renders right now: one page in Grid layout, everything in List.
    final visibleItems = isGridLayout
        ? itemsToDisplay.sublist(
            safePage * itemsPerPage,
            ((safePage + 1) * itemsPerPage).clamp(0, itemsToDisplay.length),
          )
        : itemsToDisplay;

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────────────
        // Shared with the Products management screen — see ProductSearchBar.
        if (showSearchBtn)
          ProductSearchBar(
            controller: _searchCtrl,
            query: searchQuery,
            scope: effectiveMode,
            hintText: AppLocalizations.of(context).searchProductsHint,
            showScopeButtons: showSearchOptions,
            onQueryChanged: (v) =>
                ref.read(searchQueryProvider.notifier).state = v,
            onScopeChanged: (mode) => setState(() => _activeSearchMode = mode),
            onSubmitted: _handleBarcodeSubmit,
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
              : isGridLayout
              ? LayoutBuilder(
                  builder: (ctx, constraints) {
                    // Paged Grid: derive the aspect ratio so exactly
                    // Columns × Rows fit the viewport — no inner scroll, the
                    // nav bar moves between pages.
                    const pad = 12.0;
                    const gap = 10.0;
                    final cellW =
                        (constraints.maxWidth - pad * 2 - gap * (cols - 1)) /
                        cols;
                    final cellH =
                        (constraints.maxHeight - pad * 2 - gap * (rows - 1)) /
                        rows;
                    final ratio = (cellW > 0 && cellH > 0)
                        ? cellW / cellH
                        : 0.82;
                    return GridView.builder(
                      padding: const EdgeInsets.all(pad),
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        childAspectRatio: ratio,
                        crossAxisSpacing: gap,
                        mainAxisSpacing: gap,
                      ),
                      itemCount: visibleItems.length,
                      itemBuilder: (context, index) =>
                          _browserCard(context, visibleItems[index]),
                    );
                  },
                )
              : GridView.builder(
                  // List: fixed column count, the whole set scrolls vertically.
                  controller: _gridScrollController,
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    childAspectRatio: 0.82,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: visibleItems.length,
                  itemBuilder: (context, index) =>
                      _browserCard(context, visibleItems[index]),
                ),
        ),
        // First / prev / next / last bar — paged Grid layout only.
        if (isGridLayout && itemsToDisplay.isNotEmpty)
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

  /// Builds a single browser tile — a group folder or a product card — shared
  /// by both the paged Grid and the scrollable List layouts.
  Widget _browserCard(BuildContext context, Object item) {
    if (item is ProductGroup) return _buildGroupCard(context, ref, item);
    if (item is Product) return _buildProductCard(context, ref, item);
    return const SizedBox();
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
    // The product's colour marker (null when unset) — tints the card border and
    // the no-image placeholder so a coloured product no longer reads as grey.
    final marker = product.markerColor;

    return InkWell(
      onTap: () async {
        final cartState = ref.read(cartProvider);
        if (cartState.activePosOrderId == null) {
          final settings = ref.read(appSettingsProvider);
          final floorPlanOn =
              settings[SettingKeys.featureFloorPlanEnabled]?.toLowerCase() ==
              'true';
          final tablelessAllowed =
              settings[SettingKeys.allowTablelessOrders]?.toLowerCase() ==
              'true';
          if (cartState.serviceType != 0 || !floorPlanOn || tablelessAllowed) {
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
                AppLocalizations.of(context).errorCreatingOrder('$e'),
                isError: true,
              );
              return;
            }
          } else {
            if (!context.mounted) return;
            showAppSnackbar(
              context,
              ref,
              AppLocalizations.of(context).selectTableFromFloorPlan,
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

        final isWeighedSale = product.isToWeigh && !product.isService;

        double quantity = 1.0;
        if (isWeighedSale) {
          // Odoo's flow: a weighed product asks for its quantity up front —
          // from the scale when one is configured, from the keypad otherwise.
          // Checked before isUsingDefaultQuantity so a product carrying both
          // settings does not ask twice.
          if (!context.mounted) return;
          final weighed = await showWeighItemDialog(
            context,
            ref,
            itemName: product.name,
            uomId: product.uomId,
            unitPrice: product.price,
            currencySymbol: sym,
          );
          if (weighed == null) return;
          quantity = weighed;
        } else if (!product.isUsingDefaultQuantity) {
          if (!context.mounted) return;
          final qty = await _showQuantityInputDialog(
            context,
            product.measurementUnit,
          );
          if (qty == null) return;
          quantity = qty;
        }

        // ── Modifiers ────────────────────────────────────────────────────
        // Asked BEFORE the stock guards and the comment popup, because backing
        // out of the sheet must abandon the whole add — running the guards
        // first would warn about stock for an item that never gets added.
        List<SelectedModifier> chosenModifiers = const [];
        String? modifierNote;

        // Read straight from Drift — see the note on
        // `modifierGroupsForProductDirect`. Going through the autoDispose
        // family provider's `.future` here resolved before the watch-stream
        // emitted, so a product WITH groups never opened the sheet at all.
        List<ModifierGroup> groups = const [];
        try {
          final rows = await ref
              .read(appDatabaseProvider)
              .modifierGroupsForProductDirect(
                ref.read(selectedCompanyProvider)?.id ?? 0,
                product.id,
              );
          groups = modifierGroupsFromRows(rows);
        } catch (_) {}

        if (groups.isNotEmpty) {
          if (!context.mounted) return;
          final result = await showCustomizeItemSheet(
            context,
            itemName: product.name,
            basePrice: product.price,
            groups: groups,
          );
          // Null means cancelled, and cancelled means add NOTHING. Falling
          // through to add the plain item would be a sale nobody asked for.
          if (result == null) return;
          chosenModifiers = result.modifiers;
          modifierNote = result.note;
        }

        // Offline stock validation: hard-block negative inventory and warn on
        // low stock (acknowledgement required) using the real tapped quantity.
        if (!context.mounted) return;
        if (!await _passesStockGuards(product, quantity)) return;

        double price = product.price;
        // 🚨 A weighed product never asks for a price on the way in, even when
        // it is flagged price-changeable. Its price is per gram — a cashier
        // typing "50" into that box would set 50 MAD *per gram* and ring up
        // 5 000 for a 100 g bag. The money entry a weighed sale actually needs
        // is the cart keypad's Amount key, which back-solves the WEIGHT from
        // the shelf price and leaves the price alone.
        if (product.isPriceChangeAllowed && !isWeighedSale) {
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

        // 🚨 The comment prompt that used to fire here is GONE, not moved.
        // A product with predefined comments interrupted every single tap with
        // a switch list of them; the product's modifier groups now ask the same
        // question properly, from the same tap, and a product with nothing to
        // ask is added in ONE tap as it always should have been. The line's
        // note is still reachable any time from the Comment button, and a group
        // can ask for one itself (`allowsFreeText`) — which is what
        // `modifierNote` below now is.

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
            uomId: product.uomId,
            isToWeigh: product.isToWeigh,
            isService: product.isService,
          );
          ref
              .read(cartProvider.notifier)
              .addItem(
                menuProduct,
                quantity: quantity,
                // The sheet's free-text note, in the same column the retired
                // comment popup wrote to. One note per line, one column.
                comment: modifierNote,
                measurementUnit: product.measurementUnit,
                modifiers: chosenModifiers,
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
            color: marker != null
                ? marker.withValues(alpha: 0.55)
                : cs.outlineVariant.withValues(alpha: 0.5),
            width: marker != null ? 1.5 : 1,
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
                      color: marker != null
                          ? marker.withValues(alpha: 0.18)
                          : cs.surfaceContainerHighest,
                      child: Center(
                        child: PhosphorIcon(
                          PhosphorIconsRegular.forkKnife,
                          size: 44,
                          color: marker != null
                              ? marker.withValues(alpha: 0.85)
                              : cs.onSurface.withValues(alpha: 0.2),
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
            tooltip: AppLocalizations.of(context).paginationFirst,
            onTap: isFirst ? null : onFirst,
          ),
          _NavButton(
            icon: PhosphorIconsRegular.caretLeft,
            tooltip: AppLocalizations.of(context).paginationPrevious,
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
            tooltip: AppLocalizations.of(context).paginationNext,
            onTap: isLast ? null : onNext,
          ),
          _NavButton(
            icon: PhosphorIconsRegular.skipForward,
            tooltip: AppLocalizations.of(context).paginationLast,
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
  // ── keypad state ──────────────────────────────────────────────────────────
  /// What the cashier has typed since the last selection change. Empty means
  /// "nothing typed" — which is what makes the backspace key fall through to
  /// removing the line.
  String _keypadEntry = '';

  CartKeypadMode _keypadMode = CartKeypadMode.quantity;

  /// The line every keypad key acts on.
  CartItem? _selectedItem(CartState cart) => cart.items
      .where((i) => i.cartItemId == cart.selectedCartItemId)
      .firstOrNull;

  void _selectLine(String cartItemId) {
    // A fresh selection starts a fresh number: carrying "25" from the last line
    // over to this one would reprice or re-quantify it on the next digit.
    setState(() {
      _keypadEntry = '';
      _keypadMode = CartKeypadMode.quantity;
    });
    ref.read(cartProvider.notifier).setSelectedProduct(cartItemId);
  }

  void _setKeypadMode(CartKeypadMode mode) {
    setState(() {
      _keypadMode = mode;
      _keypadEntry = '';
    });
  }

  /// Appends a digit (or the decimal separator) and applies it live, the way a
  /// POS keypad is expected to behave — the line reads back what was typed.
  void _onKeypadDigit(String key) {
    final item = _selectedItem(ref.read(cartProvider));
    if (item == null) return;

    final isSeparator = key != '0' && int.tryParse(key) == null; // ',' or '.'
    if (isSeparator && _keypadEntry.contains(RegExp(r'[.,]'))) return;

    setState(() => _keypadEntry += key);
    _applyKeypadEntry(item);
  }

  /// 🚨 Toggles the sign of what is being typed, and refuses to apply it.
  ///
  /// A negative quantity is not a thing this cart can hold — `updateItemQuantity`
  /// treats anything <= 0 as "remove the line", and stock, promotions and
  /// checkout all assume positive lines. Refunds have their own flow. So the
  /// key exists (a cashier reaching for it gets an answer) and says why.
  void _onKeypadSign() {
    setState(() {
      _keypadEntry = _keypadEntry.startsWith('-')
          ? _keypadEntry.substring(1)
          : '-$_keypadEntry';
    });
    if (_keypadEntry.startsWith('-')) {
      showAppSnackbar(
        context,
        ref,
        AppLocalizations.of(context).quantityCannotBeNegative,
        isError: true,
      );
    }
  }

  /// Erases the last character; with nothing typed, removes the line.
  void _onKeypadBackspace() {
    final cart = ref.read(cartProvider);
    final item = _selectedItem(cart);
    if (item == null) return;

    if (_keypadEntry.isNotEmpty) {
      setState(
        () => _keypadEntry = _keypadEntry.substring(0, _keypadEntry.length - 1),
      );
      _applyKeypadEntry(item);
      return;
    }

    // 🚨 Same gate the old per-row X carried: trimming a fresh cart is ordinary
    // cashier work, but removing a line from an order that has already been
    // saved is a void and needs authorisation.
    void remove() {
      ref.read(cartProvider.notifier).removeItem(item.cartItemId);
      setState(() => _keypadEntry = '');
    }

    if (cart.activePosOrderId == null) {
      remove();
    } else {
      ref
          .read(securityGuardProvider)
          .guard(context, SecurityKeys.orderItemVoid, remove);
    }
  }

  /// Read from the CATALOGUE, not the cart line.
  ///
  /// The line does not carry the flag, and adding it would mean a Drift column
  /// and a migration for something that is not line data. Reading it live is
  /// the better answer anyway: a manager who turns "allow price change" off
  /// should see that take effect when a parked order is reopened, not be
  /// overruled by a copy taken at add time.
  bool _priceChangeAllowed(CartItem item) {
    final products = ref.read(allProductsListProvider).value ?? const [];
    return products
            .where((p) => p.id == item.productId)
            .firstOrNull
            ?.isPriceChangeAllowed ??
        false;
  }

  /// Whether this line is sold by weight — which is what turns the keypad's
  /// price key into an amount key.
  ///
  /// Read from the CATALOGUE first for the same reason [_priceChangeAllowed] is:
  /// a manager who flips "sell by weight" should see it take effect on a
  /// reopened order rather than be overruled by a copy taken at add time. The
  /// line's own flag is the fallback for a product this terminal has not cached.
  bool _isWeighedLine(CartItem item) {
    final products = ref.read(allProductsListProvider).value ?? const [];
    final product = products.where((p) => p.id == item.productId).firstOrNull;
    final weighed = product?.isToWeigh ?? item.isToWeigh;
    // A service has no weight to solve for, and the product editor already
    // refuses the combination — this is the belt to that's braces.
    return weighed && !(product?.isService ?? item.isService);
  }

  /// Attaches a customer to this order — the same picker the header button
  /// opens, reachable from the cart where the cashier is already looking.
  Future<void> _pickCartCustomer(BuildContext context) async {
    final all = ref.read(selectableCustomersProvider).value ?? const [];
    final selected = await showCustomerPickerDialog(
      context,
      all.where((c) => c.isCustomer).toList(),
      selectedId: ref.read(cartProvider).selectedCustomer?.id,
    );
    if (selected == null || !context.mounted) return;

    ref.read(currentCustomerProvider.notifier).setCustomer(selected);
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId != null) {
      ref.read(cartProvider.notifier).setCustomer(companyId, selected);
    }
  }

  void _applyKeypadEntry(CartItem item) {
    final value = double.tryParse(_keypadEntry.replaceAll(',', '.'));
    if (value == null || value < 0) return;

    final notifier = ref.read(cartProvider.notifier);
    switch (_keypadMode) {
      case CartKeypadMode.quantity:
        // 0 is a state the cashier passes THROUGH while typing "0.5"; applying
        // it would delete the line mid-keystroke.
        if (value > 0) notifier.updateItemQuantity(item.cartItemId, value);
      case CartKeypadMode.price:
        if (_isWeighedLine(item)) {
          // 🚨 The reverse sale. On a weighed line the digits are MONEY, not a
          // unit price: "50 dirhams of saffron" at 30 MAD/g is 1.6667 g, and
          // the weight is what the keypad writes. `price` is deliberately left
          // alone — it is the divisor, so every keystroke re-solves from the
          // shelf price instead of compounding on the last answer.
          final weight = quantityForAmount(value, item.price, item.uomId);
          if (weight != null && weight > 0) {
            notifier.updateItemQuantity(item.cartItemId, weight);
          }
        } else if (_priceChangeAllowed(item)) {
          notifier.updateItemPrice(item.cartItemId, value);
        }
    }
  }

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
            ? AppLocalizations.of(context).bookingSaved
            : wasTableOrder
            ? AppLocalizations.of(context).orderSavedToTable
            : AppLocalizations.of(context).orderSaved,
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

      // The order is parked in Drift now, so the cart must let go of it. It
      // previously kept everything on the navigating paths, which meant the next
      // table tap inherited these items AND this order's existingLocalOrderId —
      // so saving there rewrote this order's row onto the new table, moving the
      // order and leaving the table it came from empty. Reopen a parked order by
      // tapping its table or via Open Orders.
      ref.read(cartProvider.notifier).clearCart();

      final idx = nextIndex;
      if (idx != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainLayout(initialIndex: idx)),
          (r) => false,
        );
      }

      // Step 4: Fire-and-forget sync push so the server sees the open order
      // as soon as possible.  Failures are silent — the row stays 'pending'
      // and the next manual/auto sync will retry.
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
    } catch (e) {
      if (context.mounted) {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).saveFailed('$e'),
          isError: true,
        );
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
          child: Icon(
            Icons.question_mark,
            size: 32,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(AppLocalizations.of(context).voidOrder),
        content: Text(AppLocalizations.of(context).voidOrderConfirm),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).actionNo),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).actionYes),
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
      // Voiding restocks every line, so a hardcoded 1 would return the stock to
      // a warehouse the company may not own — silently, and unrecoverably once
      // the void has synced. effectiveWarehouseId resolves it properly.
      final warehouseId = ref.read(cartProvider.notifier).effectiveWarehouseId;
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
                  // In the line's SALE unit; the conversion back to the stock
                  // unit is deductStockForCheckout's job. Without it a voided
                  // 100 g line put 100 KILOS of saffron back on the shelf.
                  uomId: item.uomId,
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
          // Guarded: refuses (and surfaces an error) if this row is still the
          // only carrier for an unbanked checkout, which deleting would strand
          // permanently. Also purges the order's discount_lines, which link by
          // local id with no FK cascade.
          await db.deleteLocalOrder(existLocalId);
          // Restore local stock.
          await db.deductStockForCheckout(
            items: cartItems
                .map(
                  (item) => (
                    productId: item.productId,
                    quantity: -item.quantity,
                    uomId: item.uomId,
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

      // The reservation's order is gone — mirror the server's own void handling
      // (PosOrderService delete: UnlinkPosOrder + MarkAsArrived) locally, so the
      // booking drops back to Arrived (2) at once and can be restarted, instead
      // of sitting In Service with no order behind it.
      final voidedBookingId = cartState.bookingId;
      if (voidedBookingId != null) {
        await db.setBookingStatusLocal(voidedBookingId, 2);
        await db.unlinkBookingPosOrder(voidedBookingId);
      }

      ref.read(kitchenSyncProvider).push();
      ref.read(cartProvider.notifier).clearCart();

      if (!context.mounted) return;
      showAppSnackbar(
        context,
        ref,
        AppLocalizations.of(context).orderVoided,
        isError: true,
      );

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
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).errorWithMessage('$e'),
          isError: true,
        );
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

  // Gross line figures now come from the cart notifier — these used to add tax
  // on top of `item.price` unconditionally, which double-taxed every
  // tax-INCLUSIVE product on the POS line rows (a 90 MAD product showed 108).
  // The notifier divides the tax back out of an inclusive price first.
  double _grossLineTotal(CartItem item) =>
      ref.read(cartProvider.notifier).grossLineTotal(item);

  // Full-price gross for the strikethrough label (before item discounts + tax)
  double _grossLineFullPrice(CartItem item) =>
      ref.read(cartProvider.notifier).grossLineFullPrice(item);

  /// Mirrors the cart onto the SERIAL pole display, which until now lit up only
  /// when the payment dialog opened.
  ///
  /// A customer watched a blank display through the entire scan and got one
  /// number at the end — the moment it is too late to query an item. Showing
  /// each line as it is rung is the whole reason the hardware is on the counter.
  ///
  /// Fire-and-forget on purpose: `_send` swallows its own errors on this path
  /// (a dead display must never disturb a sale) and awaiting it would put a
  /// serial write between the cashier's tap and the frame.
  void _updatePoleDisplay(CartState? previous, CartState next, double total) {
    // Work out WHAT to show now, while `previous` and `next` are still the two
    // states this notification is about — but do the provider reads and the
    // serial write on the next microtask.
    //
    // 🚨 A cart notification can be delivered inside a build. Reading a provider
    // there can initialise it mid-build, and Riverpod turns that into
    // `setState() called during build` in a stack that names some other widget
    // entirely — an exception nobody would trace back to a pole display. The
    // display is also fire-and-forget by design: a serial write has no business
    // between a cashier's tap and the frame that answers it.
    final changed = next.items.isEmpty
        ? null
        : _mostRecentlyChangedItem(previous?.items, next.items);
    final isEmpty = next.items.isEmpty;
    if (!isEmpty && changed == null) return; // not a change about a line

    Future.microtask(() {
      if (!mounted) return;
      final settings = ref.read(appSettingsProvider);

      // The payment dialog owns the display while it is open — it shows TOTAL
      // DUE and restores the welcome message on close. Talking over it would
      // flip the display back to a line item while the customer is being asked
      // to pay.
      final status = ref.read(customerDisplayProvider).status;
      if (status == CustomerDisplayStatus.paymentPending ||
          status == CustomerDisplayStatus.checkoutSuccess) {
        return;
      }

      if (isEmpty) {
        CustomerDisplayService.showWelcome(settings: settings);
        return;
      }
      CustomerDisplayService.showLineItem(
        settings: settings,
        name: changed!.productName,
        quantity: changed.quantity,
        unitPrice: changed.price,
        runningTotal: total,
        unitLabel: changed.measurementUnit ?? '',
      );
    });
  }

  /// The line this cart change was about: a new line, or one whose quantity or
  /// price moved.
  ///
  /// 🚨 Not `items.last`. With "separate row per item" OFF, re-scanning a
  /// product MERGES into its existing line — which can sit anywhere in the list
  /// — so the last row is somebody else's product and the display would name
  /// the wrong thing at the moment the customer is watching it most closely.
  static CartItem? _mostRecentlyChangedItem(
    List<CartItem>? before,
    List<CartItem> after,
  ) {
    if (after.isEmpty) return null;
    if (before == null || before.isEmpty) return after.last;

    final previous = {for (final i in before) i.cartItemId: i};
    CartItem? newest;
    for (final item in after) {
      final was = previous[item.cartItemId];
      if (was == null) {
        newest = item; // a line that did not exist before
      } else if (was.quantity != item.quantity || was.price != item.price) {
        newest ??= item; // a merge or a quantity/price edit
      }
    }
    // Nothing about a LINE changed (a discount, a customer, a table move).
    // Leave whatever is on the display rather than picking a row at random.
    return newest;
  }

  @override
  Widget build(BuildContext context) {
    // Forward every cart change into the customer display state machine.
    ref.listen<CartState>(cartProvider, (previous, next) {
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
      _updatePoleDisplay(previous, next, n.grandTotal);
    });

    final cartState = ref.watch(cartProvider);
    final cartNotifier = ref.watch(cartProvider.notifier);
    final cartItems = cartState.items;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // What the keypad and the Client button act on.
    final selectedItem = _selectedItem(cartState);
    final selectedCustomer = cartState.selectedCustomer;
    final keypadVisible = ref.watch(cartKeypadVisibleProvider);

    final discountTotal = cartNotifier.discountTotal;
    final grandTotal = cartNotifier.grandTotal;
    final sym = ref.watch(currencySymbolProvider);
    final settings = ref.watch(appSettingsProvider);
    final taxIncluded =
        settings[SettingKeys.displayAndPrintTaxIncluded]?.toLowerCase() !=
        'false';
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
                        TextSpan(
                          text: AppLocalizations.of(context).bookingPrefix,
                          style: const TextStyle(
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
                          TextSpan(
                            text: AppLocalizations.of(context).staffPrefix,
                            style: const TextStyle(
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
        // ── Cart header strip: order number, refresh, save ─────────────────
        // Sized from the width it actually has: SAVE keeps its label while
        // there is room and drops to the icon alone when the cart column is
        // narrow, so the order number is never the thing that gets ellipsized.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const saveWithLabel = 104.0;
              const saveIconOnly = 48.0;
              const labelMin = 120.0;

              final showSaveLabel =
                  constraints.maxWidth >= labelMin + saveWithLabel;
              final canSave = cartItems.isNotEmpty;

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      contextLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: showSaveLabel ? saveWithLabel : saveIconOnly,
                    height: 38,
                    child: showSaveLabel
                        ? ElevatedButton.icon(
                            onPressed: canSave
                                ? () => _handleSave(context, ref)
                                : null,
                            icon: const Icon(Icons.save, size: 18),
                            label: Text(
                              AppLocalizations.of(context).saveUpper,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          )
                        : ElevatedButton(
                            onPressed: canSave
                                ? () => _handleSave(context, ref)
                                : null,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: Tooltip(
                              message: AppLocalizations.of(context).saveUpper,
                              child: const Icon(Icons.save, size: 18),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),

        Expanded(
          child: cartItems.isEmpty
              ? Center(
                  child: Text(
                    AppLocalizations.of(context).cartIsEmpty,
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
                      onTap: () => _selectLine(item.cartItemId),
                      child: Container(
                        color: isSelected
                            ? (isDark
                                  ? Colors.blue[900]?.withValues(alpha: 0.3)
                                  : Colors.blue[50])
                            : null,
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        // ONE line: quantity, name (+ badges), price. The
                        // stacked layout put the money on a second row, which
                        // is the number a cashier is scanning for — and it
                        // halved how many lines fit on a till screen.
                        //
                        // Widths are decided from what the row actually has
                        // (Ilyass Style): the badges and the struck-through
                        // original price are dropped in that order when the
                        // cart column is narrow, so the name and the amount
                        // never have to fight for room.
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const qtyWidth = 62.0;
                            const priceWidth = 96.0;
                            const gap = 8.0;

                            // What each optional piece costs, and the width the
                            // product name may never drop below.
                            var badgeWidth = 0.0;
                            if (item.appliedTaxes.isNotEmpty) {
                              badgeWidth += 52;
                            }
                            if (item.discount > 0) badgeWidth += 56;
                            if (item.promotionalDiscount > 0) badgeWidth += 20;

                            final fit = cartRowFit(
                              width: constraints.maxWidth,
                              hasDiscount: hasDiscount,
                              badgeWidth: badgeWidth,
                              qtyWidth: qtyWidth,
                              priceWidth: priceWidth,
                              gap: gap,
                            );
                            final showOriginal = fit.showOriginal;
                            final showBadges = fit.showBadges;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Quantity — fixed, so the names line up.
                                    SizedBox(
                                      width: qtyWidth,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withValues(
                                            alpha: 0.10,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            _formatCartQty(item),
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: cs.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: gap),
                                    // Name + badges — takes whatever is left.
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.productName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (showBadges) ...[
                                            const SizedBox(width: 6),
                                            if (item.appliedTaxes.isNotEmpty)
                                              badge(
                                                Icons.receipt_long,
                                                'TAX',
                                                context.infoColor,
                                              ),
                                            if (item.discount > 0) ...[
                                              const SizedBox(width: 4),
                                              badge(
                                                Icons.sell,
                                                "-${item.discountType == 0 ? item.discount.toInt() : item.discount.toStringAsFixed(1)}",
                                                context.successColor,
                                              ),
                                            ],
                                            if (item.promotionalDiscount >
                                                0) ...[
                                              const SizedBox(width: 4),
                                              const Text(
                                                '⭐',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: gap),
                                    // Price — hard right, so a column of amounts
                                    // can be read down its last digits.
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (showOriginal) ...[
                                          Text(
                                            "${(taxIncluded ? _grossLineFullPrice(item) : item.price * item.quantity).toStringAsFixed(2)} $sym",
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: cs.onSurfaceVariant,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: priceWidth,
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment:
                                                AlignmentDirectional.centerEnd,
                                            child: Text(
                                              "${(taxIncluded ? _grossLineTotal(item) : (item.price - item.discount - item.promotionalDiscount) * item.quantity).toStringAsFixed(2)} $sym",
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: hasDiscount
                                                    ? context.successColor
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                // The chosen modifiers, indented under the name.
                                // Rendered from the line's own SNAPSHOTS, never
                                // from the catalogue — a renamed or deleted option
                                // must still print what was actually sold.
                                if (item.selectedModifiers.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      start: qtyWidth + gap,
                                      top: 2,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (final m in item.selectedModifiers)
                                          Row(
                                            children: [
                                              Flexible(
                                                flex: 3,
                                                child: Text(
                                                  '· ${m.name}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                              // A free choice prints no price:
                                              // "+0.00" beside "No Sugar" is noise
                                              // on every line of every receipt.
                                              if (m.additionalPrice != 0) ...[
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  flex: 2,
                                                  child: Text(
                                                    '${m.additionalPrice > 0 ? '+' : '−'}'
                                                    '${m.additionalPrice.abs().toStringAsFixed(2)}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          cs.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
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
              // Subtotal and Tax rows removed on purpose: the cart states one
              // number. Any discount that IS applied still gets its own line
              // below, because a price the cashier cannot explain to the
              // customer is worse than a longer footer.
              if (discountTotal > 0 && !taxIncluded)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _totalsRow(
                    Text(
                      AppLocalizations.of(context).itemDiscountsPlural,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.successColor,
                      ),
                    ),
                    value: Text(
                      "-${discountTotal.toStringAsFixed(2)} $sym",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.successColor,
                      ),
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
                      AppLocalizations.of(context).customerDiscountLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.successColor,
                      ),
                    ),
                    value: Text(
                      "-${cartNotifier.customerDiscountAmount.toStringAsFixed(2)} $sym",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.successColor,
                      ),
                    ),
                  ),
                ),
              if (cartState.manualCartDiscount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _totalsRow(
                    Text(
                      AppLocalizations.of(context).cartDiscountLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.successColor,
                      ),
                    ),
                    value: Text(
                      "-${cartNotifier.manualCartDiscountAmount.toStringAsFixed(2)} $sym",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.successColor,
                      ),
                    ),
                  ),
                ),
              if (cartNotifier.promotionalDiscountTotal > 0 && !taxIncluded)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _totalsRow(
                    Text(
                      AppLocalizations.of(context).totalPromotionalDiscount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.warningColor,
                      ),
                    ),
                    value: Text(
                      "-${cartNotifier.promotionalDiscountTotal.toStringAsFixed(2)} $sym",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.warningColor,
                      ),
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, thickness: 1),
              ),
              _totalsRow(
                Text(
                  AppLocalizations.of(context).totalLabel,
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
              // ── Client + actions ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _CartToolButton(
                      icon: selectedCustomer != null
                          ? Icons.person
                          : Icons.person_outline,
                      label:
                          selectedCustomer?.name ??
                          AppLocalizations.of(context).customerLabel,
                      active: selectedCustomer != null,
                      onTap: () => _pickCartCustomer(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ⋮ — everything that is not an everyday key. VOID lives here
                  // now: it ends an order, and a destructive action does not
                  // belong beside PAY where a thumb lands on it by accident.
                  _CartActionsMenu(
                    onVoid: cartState.activePosOrderId == null
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
                  const SizedBox(width: 8),
                  // Give the cart its height back on a short screen.
                  //
                  // 🚨 Icon-only and fixed-size, like the ⋮ beside it — NOT a
                  // _CartToolButton. That one is a Row with a Flexible child, so
                  // it needs a bounded width and only works wrapped in Expanded;
                  // dropped bare into this Row it was handed an unbounded width
                  // and blew up layout for the whole cart. The assertion that
                  // catches it is debug-only, so a release build showed a blank
                  // panel instead of an error.
                  CartIconToggle(
                    icon: keypadVisible
                        ? Icons.keyboard_hide_outlined
                        : Icons.dialpad,
                    tooltip: keypadVisible
                        ? AppLocalizations.of(context).hideKeypad
                        : AppLocalizations.of(context).showKeypad,
                    active: !keypadVisible,
                    onTap: () =>
                        ref.read(cartKeypadVisibleProvider.notifier).toggle(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ── Keypad ──────────────────────────────────────────────────
              // Collapsible, because the keypad and the item list compete for
              // the same column. On a 1366×768 till the keypad leaves room for
              // barely two lines of cart, and a shop that types quantities
              // rarely would rather see the order. The choice is per-terminal
              // (see cartKeypadVisibleProvider) — it is a property of the
              // screen, not of the company.
              if (keypadVisible)
                CartKeypad(
                  mode: _keypadMode,
                  onModeChanged: _setKeypadMode,
                  onDigit: _onKeypadDigit,
                  onSignToggle: _onKeypadSign,
                  onBackspace: _onKeypadBackspace,
                  hasSelection: selectedItem != null,
                  priceChangeAllowed:
                      selectedItem != null && _priceChangeAllowed(selectedItem),
                  priceEntersAmount:
                      selectedItem != null && _isWeighedLine(selectedItem),
                ),
              const SizedBox(height: 10),
              // ── Pay ─────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: _CartFooterButton(
                  icon: Icons.payments,
                  label: AppLocalizations.of(context).posPay,
                  color: context.successColor,
                  onTap: cartItems.isEmpty
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const PaymentCheckoutDialog(),
                          );
                        },
                ),
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
          // Cap the label so a long French label (or a selected customer's full
          // name) can't stretch the button — it ellipsizes and the full text
          // stays reachable through the button's Tooltip.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 84),
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tint,
              ),
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
/// The till's "Open Drawer" button — the last piece of handoff.md ★8.
///
/// The hardware has been reachable since `cash_drawer_service.dart` landed; what
/// was missing was a way to ask for it outside a sale (a customer wants change,
/// the cashier drops a note in). Three outcomes, and they must never look alike
/// on a screen next to a drawer that did not move:
///
/// * no station has its drawer switch on → say so and name the screen that
///   fixes it, rather than sending a kick nobody wired and reporting success;
/// * the kick went out → the usual confirmation;
/// * a station refused → that station's own reason, verbatim.
///
/// Fires EVERY enabled station, like the end of a sale does: a till with two
/// drawers is rare but real, and the operator pressed one button meaning "open
/// the drawer", not "open the first one I happen to find".
Future<void> _openCashDrawerFromTill(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  final settings = ref.read(appSettingsProvider);
  if (enabledCashDrawers(settings).isEmpty) {
    showAppSnackbar(context, ref, l10n.cashDrawerNotConfigured, isError: true);
    return;
  }
  final failures = await openEnabledDrawers(settings);
  if (!context.mounted) return;
  showAppSnackbar(
    context,
    ref,
    failures.isEmpty
        ? l10n.cashDrawerOpenedOk
        : l10n.cashDrawerFailed(failures.first),
    isError: failures.isNotEmpty,
  );
}

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

/// What still fits on one cart line at [width].
///
/// 🚨 The order things are dropped in is the whole point. The NET amount and
/// the product name always survive: the amount is what the customer is being
/// charged, and a truncated name is the cashier not knowing what they are
/// selling. The struck-through original price goes first, the TAX/discount
/// badges second — those are hints, and their information is still on the
/// receipt and in the totals.
({bool showOriginal, bool showBadges}) cartRowFit({
  required double width,
  required bool hasDiscount,
  required double badgeWidth,
  double qtyWidth = 62,
  double priceWidth = 96,
  double gap = 8,
  double strikeWidth = 62,
  double nameMin = 96,
}) {
  var free = width - qtyWidth - gap * 2 - priceWidth;

  final showOriginal = hasDiscount && free - strikeWidth >= nameMin;
  if (showOriginal) free -= strikeWidth;

  final showBadges = badgeWidth > 0 && free - badgeWidth >= nameMin;
  return (showOriginal: showOriginal, showBadges: showBadges);
}

// ── Cart tool button (Client) ──────────────────────────────────────────────
// Flat, touch-sized, and it doubles as its own state readout: with a customer
// attached it shows that customer's name, highlighted.
class _CartToolButton extends StatelessWidget {
  const _CartToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = active ? cs.primary : cs.onSurface;

    return Material(
      color: active
          ? cs.primary.withValues(alpha: 0.12)
          : cs.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compact cart toggle ────────────────────────────────────────────────────
// A fixed 44x44 icon button for the row beside the ⋮ menu. Deliberately holds
// no flexible child, so it imposes no width requirement on its parent and can
// sit in a Row without an Expanded around it.
class CartIconToggle extends StatelessWidget {
  const CartIconToggle({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;

  /// Highlighted when the thing it controls is switched OFF, so the toggle
  /// reads as "something is hidden" at a glance.
  final bool active;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: active
          ? cs.primary.withValues(alpha: 0.12)
          : cs.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            width: 44,
            child: Icon(
              icon,
              size: 20,
              color: active ? cs.primary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Cart actions menu (⋮) ──────────────────────────────────────────────────
// Holds what is not an everyday key. VOID is the first entry; anything else
// that ends or reshapes a whole order belongs here rather than beside PAY.
class _CartActionsMenu extends StatelessWidget {
  const _CartActionsMenu({required this.onVoid});

  /// Null when there is no saved order to void — the entry greys out rather
  /// than disappearing, so the action stays findable.
  final VoidCallback? onVoid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<int>(
        tooltip: AppLocalizations.of(context).colActions,
        position: PopupMenuPosition.under,
        onSelected: (_) => onVoid?.call(),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 0,
            enabled: onVoid != null,
            child: Row(
              children: [
                Icon(
                  Icons.block,
                  size: 18,
                  color: onVoid == null
                      ? cs.onSurface.withValues(alpha: 0.35)
                      : context.dangerColor,
                ),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(context).posVoid),
              ],
            ),
          ),
        ],
        child: SizedBox(
          height: 44,
          width: 44,
          child: Icon(Icons.more_vert, size: 20, color: cs.onSurface),
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
        // Scale the label to one line so a longer word (e.g. French "ANNULER")
        // shrinks to fit a narrow cart panel instead of wrapping.
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
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
  // At the line's own unit precision: a weighed line reads `0.500 kg`, not the
  // old fixed 2-decimal `0.5` — and never `0.13` for a real 0.125 kg.
  final unit = uomById(item.uomId);
  final qty = formatQuantityValue(item.quantity, item.uomId);

  // The legacy free-text unit is preferred for display when it disagrees with
  // the catalog code, so a line parked before the UoM catalog existed still
  // shows whatever it was sold as.
  final label = (item.measurementUnit?.isNotEmpty ?? false)
      ? item.measurementUnit!
      : unit.code;

  return item.uomId == kUomPieces && (item.measurementUnit?.isEmpty ?? true)
      ? 'x$qty'
      : '$qty $label';
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
      title: Text(AppLocalizations.of(context).enterQuantity),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).fieldQuantity,
          suffixText: unit,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        ElevatedButton(
          onPressed: () {
            final val = double.tryParse(controller.text);
            if (val != null && val > 0) Navigator.pop(ctx, val);
          },
          child: Text(AppLocalizations.of(context).actionConfirm),
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
        title: Text(AppLocalizations.of(context).setSalePrice),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).priceLabel,
            suffixText: ' $currencySymbol',
            errorText: errorText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(AppLocalizations.of(context).actionCancel),
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
            child: Text(AppLocalizations.of(context).actionConfirm),
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
          Text(AppLocalizations.of(context).ageRestriction),
        ],
      ),
      content: Text(AppLocalizations.of(context).ageRestrictionBody(minAge)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            AppLocalizations.of(context).confirmMinimumAge(minAge.toString()),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// A free-text note on one cart line.
///
/// 🚨 What this REPLACED, and why the note itself survived it. This dialog used
/// to render the product's predefined-comment catalogue as a list of switches,
/// joined the chosen ones with ", " and stored the string. Modifiers do that
/// job properly — priced, grouped, with pick-one/pick-many rules and their own
/// reporting rows — so the catalogue is retired (backlog 38, phase 6).
///
/// The NOTE is not the catalogue and does not go with it: "allergic to nuts" is
/// not a menu option anyone can enumerate in advance. It stays exactly where it
/// was, in `CartItem.comment`, and still prints on the kitchen ticket under the
/// choices. A group can also ask for one in the Customize sheet — see
/// `ModifierGroup.allowsFreeText`.
class _ItemNoteDialog extends StatefulWidget {
  final String productName;

  /// The line's current note, when editing one already in the cart.
  final String? initialComment;
  final String confirmLabel;

  const _ItemNoteDialog({
    required this.productName,
    this.initialComment,
    this.confirmLabel = 'Add to Cart',
  });

  @override
  State<_ItemNoteDialog> createState() => _ItemNoteDialogState();
}

class _ItemNoteDialogState extends State<_ItemNoteDialog> {
  late final TextEditingController _customController = TextEditingController(
    text: widget.initialComment?.trim() ?? '',
  );

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        AppLocalizations.of(context).commentsForProduct(widget.productName),
      ),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _customController,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).customComment,
            hintText: AppLocalizations.of(context).addANoteHint,
            prefixIcon: const Icon(Icons.edit_note),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        ElevatedButton(
          // Empty is a legitimate answer — it CLEARS the note. Returning null
          // for it would be read as "cancelled" by both call sites and the old
          // text would stay on the line.
          onPressed: () =>
              Navigator.pop(context, _customController.text.trim()),
          child: Text(widget.confirmLabel),
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

    // With General.TaxIncludedByDefault on, tax is an admin decision made in
    // the product editor / Settings — not something the cashier renegotiates
    // per line. The dialog still OPENS (so the operator can see exactly what
    // is being charged and why the blue TAX badge is there); it just can't be
    // edited. One rule for every line, whether the tax came from the product's
    // own assignment or from the configured default, so two lines side by side
    // never behave differently.
    final locked =
        ref
            .watch(appSettingsProvider)[SettingKeys.taxIncludedByDefault]
            ?.toLowerCase() ==
        'true';

    return AlertDialog(
      backgroundColor: theme.cardColor,
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      title: Row(
        children: [
          Expanded(
            child: Text(
              AppLocalizations.of(
                context,
              ).taxesForProduct(widget.item.productName),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (locked)
            Tooltip(
              message: AppLocalizations.of(context).taxLockedBySetting,
              child: Icon(
                Icons.lock_outline,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
        ],
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
            child: Text(
              AppLocalizations.of(context).errorWithMessage(e.toString()),
            ),
          ),
          data: (taxes) {
            if (taxes.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(AppLocalizations.of(context).noTaxesAvailable),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (locked)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        AppLocalizations.of(context).taxLockedBySetting,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: taxes.length,
                      itemBuilder: (ctx, i) {
                        final tax = taxes[i];
                        final isSelected = _selectedTaxes.any(
                          (t) => t.id == tax.id,
                        );

                        return CheckboxListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: cs.primary,
                          title: Text(
                            tax.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(
                                alpha: locked && !isSelected ? 0.5 : 1,
                              ),
                            ),
                          ),
                          subtitle: Text(
                            "${tax.rate}${tax.isFixed ? '' : '%'}",
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          secondary: locked && isSelected
                              ? Icon(
                                  Icons.lock_outline,
                                  size: 15,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                )
                              : null,
                          value: isSelected,
                          // A null callback is what makes Checkbox render its
                          // disabled state — nothing to check, nothing to
                          // uncheck.
                          onChanged: locked
                              ? null
                              : (val) {
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
                                      _selectedTaxes.removeWhere(
                                        (t) => t.id == tax.id,
                                      );
                                    }
                                  });
                                },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 12, 8),
      actions: locked
          // Read-only: a single dismiss. No Apply button at all, so there is no
          // path that could write a tax change from the till.
          ? [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).actionClose),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).actionCancel),
              ),
              FilledButton(
                onPressed: () {
                  ref
                      .read(cartProvider.notifier)
                      .updateItemTaxes(widget.item.cartItemId, _selectedTaxes);
                  Navigator.pop(context);
                },
                child: Text(AppLocalizations.of(context).actionApply),
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

    // Captured for the rollback below: the optimistic local move has to be
    // undoable if the server rejects the transfer.
    final oldTableId = widget.cartState.floorPlanTableId;
    final previousOrderNumber = widget.cartState.orderNumber;
    final previousUserId = ref.read(currentUserProvider)?.id;
    String? movedLocalId;

    try {
      final activePosOrderId = widget.cartState.activePosOrderId;
      final bookingId = widget.cartState.bookingId;

      if (activePosOrderId != null && companyId != null) {
        final movedUserId =
            _selectedStaff?.id ?? ref.read(currentUserProvider)?.id ?? 0;
        // Compute the destination name BEFORE the server call. It used to be
        // derived afterwards, purely for the cart, so the server kept the
        // ORIGIN table's name — an order moved to A5 stayed "ORD- A7" server-
        // side while the cart said "ORD- A5", and the pull's name-matching
        // branch then had two disagreeing views of the same order.
        final destinationName = _selectedRoom != null
            ? 'ORD- ${_selectedRoom!.name}'
            : (widget.cartState.orderNumber ?? "ORD-TEMP");
        final updateRequest = {
          "id": activePosOrderId,
          "userId": movedUserId,
          "number": destinationName,
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
        final newTable = _selectedRoom;

        // ── LOCAL FIRST ───────────────────────────────────────────────────
        // Floor-plan occupancy is derived from open `pos_orders.tableId`
        // (§3 — `floor_plan_tables.status` is dead), so the origin table only
        // frees once this local row moves. This used to run AFTER two awaited
        // network round trips, which is exactly why the old table sat there
        // looking occupied "until it synced" — and why tapping it in that
        // window raised "Could not find active order".
        //
        // Writing local first makes the floor plan correct on the next frame.
        // The server still decides: if it rejects, the catch below puts the
        // row back, so the optimism is never left standing on a failure.
        if (newTable != null) {
          final localId =
              widget.cartState.existingLocalOrderId ??
              (await ref
                      .read(appDatabaseProvider)
                      .getOpenOrderByServerId(activePosOrderId))
                  ?.localId;
          if (localId != null) {
            await ref
                .read(appDatabaseProvider)
                .moveOrderToTable(
                  localId: localId,
                  tableId: newTable.id,
                  orderName: destinationName,
                  userId: movedUserId,
                );
            movedLocalId = localId;
          }
          ref
              .read(cartProvider.notifier)
              .setOrderContext(
                activePosOrderId,
                // Same reason as the service-type move above — never hardcode 1.
                ref.read(cartProvider.notifier).effectiveWarehouseId,
                tableId: newTable.id,
                orderNumber: destinationName,
              );
          // Repaint the floor plan / open-orders list off the row just written.
          ref.invalidate(openOrdersProvider);
        }

        // ── THEN the server ───────────────────────────────────────────────
        await ApiClient().updatePosOrder(companyId, updateRequest);
        ref.read(kitchenSyncProvider).push();

        if (oldTableId != null &&
            newTable != null &&
            oldTableId != newTable.id) {
          try {
            await ApiClient().freeFloorPlanTable(companyId, oldTableId);
          } catch (_) {}
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
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).orderTransferred,
        );
      }

      // The cart deliberately KEEPS the order. It used to `clearCart()` here,
      // which threw away the very order this dialog had just re-pointed at the
      // destination table — so the till came back empty and the next tap rang
      // up a SECOND order instead of continuing the transferred one. The cart
      // context was already moved above, and `existingLocalOrderId` survives
      // `setOrderContext`, so carrying on and saving updates the same order.
      ref.invalidate(openOrdersProvider);
    } catch (e) {
      // Put the optimistic local move back — the server did not accept it, so
      // leaving the order on the destination table would strand it somewhere
      // it does not belong and free a table that is still occupied.
      if (movedLocalId != null) {
        try {
          await ref
              .read(appDatabaseProvider)
              .moveOrderToTable(
                localId: movedLocalId,
                tableId: oldTableId,
                orderName: previousOrderNumber,
                userId: previousUserId,
              );
          final activePosOrderId = widget.cartState.activePosOrderId;
          if (activePosOrderId != null) {
            ref
                .read(cartProvider.notifier)
                .setOrderContext(
                  activePosOrderId,
                  ref.read(cartProvider.notifier).effectiveWarehouseId,
                  tableId: oldTableId,
                  orderNumber: previousOrderNumber,
                );
          }
          ref.invalidate(openOrdersProvider);
        } catch (_) {
          // Rollback itself failed — the next pull reconciles from the server,
          // which never accepted the move in the first place.
        }
      }
      if (mounted) {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).transferFailed('$e'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    // Free tables only: transferring an order onto a table someone is already
    // sitting at would park two open orders on it.
    final roomsAsync = ref.watch(freeRoomsProvider);
    final floorPlanOn =
        ref
            .watch(appSettingsProvider)[SettingKeys.featureFloorPlanEnabled]
            ?.toLowerCase() ==
        'true';

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.swap_horiz),
          const SizedBox(width: 8),
          Text(AppLocalizations.of(context).transferOrder),
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
                // Keyed by ID, never by the User object — see
                // [dropdownOptionsById] for why. The extra exposure here: a
                // staff member who has since been DISABLED is filtered out of
                // `enabled` while still being this order's assignee, and the
                // helper unions them back in.
                final enabled = users.where((u) => u.isEnabled).toList();
                final opts = dropdownOptionsById(
                  enabled,
                  _selectedStaff,
                  (u) => u.id,
                );
                final unique = opts.options;
                return DropdownButtonFormField<int?>(
                  initialValue: opts.value,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).assignStaff,
                    prefixIcon: const Icon(Icons.badge),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(AppLocalizations.of(context).unassigned),
                    ),
                    ...unique.map(
                      (u) => DropdownMenuItem<int?>(
                        value: u.id,
                        child: Text(u.displayName),
                      ),
                    ),
                  ],
                  onChanged: (id) => setState(() {
                    _selectedStaff = unique
                        .where((u) => u.id == id)
                        .firstOrNull;
                  }),
                );
              },
            ),
            if (floorPlanOn) ...[
              const SizedBox(height: 16),
              roomsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (freeRooms) {
                  // ⚠️ Keyed by ID, not by the FloorPlanTable object.
                  //
                  // FloorPlanTable declares no `==`, so Dart compares by
                  // IDENTITY. `_selectedRoom` is seeded in initState from a
                  // `ref.read(allRoomsProvider)` snapshot, while these items
                  // come from a later emission of a DIFFERENT provider — same
                  // table, freshly constructed object. The previous guard here
                  // only handled "table missing from the list" (comparing ids)
                  // while still handing the widget the stale OBJECT, so it
                  // matched ZERO items and the assert took down the whole
                  // dialog the moment Transfer was pressed on a seated order.
                  //
                  // The helper also unions this order's own table back in — it
                  // reads as occupied because it is holding it, so the free
                  // list excludes it — and de-dupes, which covers the "2 or
                  // more" half of the same assert.
                  final opts = dropdownOptionsById(
                    freeRooms,
                    _selectedRoom,
                    (r) => r.id,
                  );
                  final unique = opts.options;

                  return DropdownButtonFormField<int?>(
                    initialValue: opts.value,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(
                        context,
                      ).assignRoomOrResource,
                      prefixIcon: const Icon(Icons.meeting_room),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(AppLocalizations.of(context).noRoom),
                      ),
                      ...unique.map(
                        (t) => DropdownMenuItem<int?>(
                          value: t.id,
                          child: Text(t.name),
                        ),
                      ),
                    ],
                    // Re-resolve the object from the LIVE list, so everything
                    // downstream (_confirm's floorPlanTableId / name) works off
                    // the instance the user actually picked.
                    onChanged: (id) => setState(() {
                      _selectedRoom = unique
                          .where((r) => r.id == id)
                          .firstOrNull;
                    }),
                  );
                },
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
                      AppLocalizations.of(context).calendarBookingUpdated,
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
          child: Text(AppLocalizations.of(context).actionCancel),
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
          label: Text(
            AppLocalizations.of(context).confirmTransfer,
            style: const TextStyle(color: Colors.white),
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
      title: Text(
        AppLocalizations.of(context).selectAvailableSpace(spaceLabel),
      ),
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
              AppLocalizations.of(context).errorLoadingSpaces(e.toString()),
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
                      AppLocalizations.of(
                        context,
                      ).noFreeSpacesAvailable(spaceLabel.toLowerCase()),
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
          child: Text(AppLocalizations.of(context).actionCancel),
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
          Text(
            AppLocalizations.of(context).enterVoidReason,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (widget.orderNumber != null)
            Text(
              AppLocalizations.of(
                context,
              ).voidReasonPrompt(widget.orderNumber!),
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
                hintText: AppLocalizations.of(context).enterVoidReason,
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
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        FilledButton(
          onPressed: () {
            final reason = _selected ?? _customCtrl.text.trim();
            if (reason.isEmpty) return;
            Navigator.pop(context, reason);
          },
          child: Text(AppLocalizations.of(context).actionContinue),
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
