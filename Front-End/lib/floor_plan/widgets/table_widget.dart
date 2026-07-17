import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/floor_plan/floor_plan_provider.dart';
import 'package:pos_app/floor_plan/floor_plan_table.dart';
import 'package:pos_app/floor_plan/floor_plan_table_provider.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/bookings/bookings_provider.dart';
import 'package:pos_app/bookings/booking_model.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/utils/status_helper.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/kitchen/kitchen_push_service.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// What the cashier chose when tapping a free table that a live reservation is
/// holding: resume/open that reservation's order, or ring up a separate walk-in.
enum _BookedTableAction { reservation, walkIn }

class TableWidget extends ConsumerStatefulWidget {
  final FloorPlanTable table;
  final int companyId;
  final int userId;

  /// Null until the warehouse seed resolves. Passed through as-is — the cart
  /// falls back to the configured default; substituting a literal 1 here would
  /// pin the order to a warehouse the company may not even have.
  final int? warehouseId;

  const TableWidget({
    super.key,
    required this.table,
    required this.companyId,
    required this.userId,
    required this.warehouseId,
  });

  @override
  ConsumerState<TableWidget> createState() => _TableWidgetState();
}

class _TableWidgetState extends ConsumerState<TableWidget> {
  late double localX;
  late double localY;
  bool isCreatingOrder = false;

  @override
  void initState() {
    super.initState();
    localX = widget.table.positionX;
    localY = widget.table.positionY;
  }

  @override
  void didUpdateWidget(covariant TableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.table.positionX != widget.table.positionX ||
        oldWidget.table.positionY != widget.table.positionY) {
      localX = widget.table.positionX;
      localY = widget.table.positionY;
    }
  }

  /// `Order.AllowWalkInTableOrders`, defaulting to true (the historical
  /// behaviour) so a missing/unset key never locks the venue out of its tables.
  /// The gate is moot when bookings are switched off — there would be no way to
  /// satisfy it — so the feature flag being off also counts as "allowed".
  bool _walkInAllowed() {
    final settings = ref.read(appSettingsProvider);
    final bookingsOn =
        settings[SettingKeys.featureBookingEnabled]?.toLowerCase() == 'true';
    if (!bookingsOn) return true;
    return (settings[SettingKeys.allowWalkInTableOrders] ?? 'true')
            .toLowerCase() !=
        'false';
  }

  bool _hasLiveBooking() {
    final bookings = ref.read(allBookingsProvider).value ?? const [];
    return hasLiveBookingForTable(bookings, widget.table.id, DateTime.now());
  }

  Booking? _liveBookingForTable() {
    final bookings = ref.read(allBookingsProvider).value ?? const [];
    return liveBookingForTable(bookings, widget.table.id, DateTime.now());
  }

  /// Asks whether to open the reservation holding a free table or ring up a
  /// separate walk-in. The walk-in choice is hidden when the venue disallows
  /// walk-in table orders, leaving "Open reservation" (or Cancel).
  Future<_BookedTableAction?> _askBookedTableAction(
    BuildContext context,
    Booking booking, {
    required bool allowWalkIn,
  }) {
    final theme = Theme.of(context);
    return showDialog<_BookedTableAction>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: const Text('Reserved table'),
        content: Text(
          'This table is held by a reservation for '
          '"${booking.reservationName}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          if (allowWalkIn)
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogCtx, _BookedTableAction.walkIn),
              child: const Text('Walk-in'),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogCtx, _BookedTableAction.reservation),
            child: const Text('Open reservation'),
          ),
        ],
      ),
    );
  }

  /// Opens the reservation on this table: resumes its existing open order when it
  /// already has one (never a second order), otherwise starts a fresh order that
  /// inherits the reservation's customer — the fix for the Walk-in-inheritance
  /// bug on the floor-plan path.
  Future<void> _openReservation(ApiClient apiClient, Booking booking) async {
    final existingLocalId =
        await ref.read(openOrderForBookingProvider(booking.id).future);
    final cart = ref.read(cartProvider.notifier);
    if (existingLocalId != null) {
      final ok = await cart.loadOrderFromLocal(existingLocalId);
      if (!mounted) return;
      if (!ok) {
        showAppSnackbar(
          context,
          ref,
          'Could not open the reservation order. It may have been completed '
          'or voided.',
          isError: true,
        );
        return;
      }
    } else {
      await cart.startBookingOrder(
        apiClient,
        widget.companyId,
        widget.userId,
        booking.id,
        booking.reservationName,
        staffUserId: booking.userId,
        floorPlanTableId: widget.table.id,
        customerId: booking.customerId,
      );
      // Mark the reservation's tables occupied, mirroring the Bookings-screen
      // Start Service path. Best-effort — an offline floor-plan sync never
      // blocks opening the order.
      for (final tableId in booking.tableIds) {
        try {
          await apiClient.occupyFloorPlanTable(widget.companyId, tableId);
        } catch (_) {}
      }
    }
    // Either way service is (or already was) running — reflect it on the
    // reservation. Mirrors the Bookings-screen Start Service flip; the resume
    // branch normalizes rows started before the flip existed.
    if (booking.status < 3) {
      await ref
          .read(appDatabaseProvider)
          .setBookingStatusLocal(booking.id, 3);
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
    }
    if (mounted) {
      ref.read(mainNavigationIndexProvider.notifier).state = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTableId = ref.watch(floorPlanTableProvider);
    // Watched (not just read in the tap handler) so the autoDispose bookings
    // stream is actually alive and loaded by the time a table is tapped —
    // a bare read would hand back AsyncLoading and wrongly report "no booking".
    ref.watch(allBookingsProvider);
    final isEditMode = ref.watch(floorPlanProvider).isEditMode;
    final isSelected = selectedTableId == widget.table.id && isEditMode;
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);

    final showAllOccupied =
        (settings[SettingKeys.showAllOccupiedTablesInFloorPlan] ?? 'true')
            .toLowerCase() !=
        'false';
    final isLocked =
        !showAllOccupied &&
        widget.table.status > 0 &&
        widget.table.assignedUserId != null &&
        widget.table.assignedUserId != widget.userId;

    return Positioned(
      left: localX,
      top: localY,
      width: widget.table.width,
      height: widget.table.height,
      child: GestureDetector(
        onTap: () async {
          if (isLocked) return;
          if (isEditMode) {
            ref
                .read(floorPlanTableProvider.notifier)
                .selectTable(widget.table.id);
            Scaffold.of(context).openEndDrawer();
          } else {
            if (isCreatingOrder) return;
            setState(() => isCreatingOrder = true);

            try {
              final apiClient = ApiClient();

              if (widget.table.status > 0) {
                final success = await ref
                    .read(cartProvider.notifier)
                    .loadExistingOrder(
                      apiClient,
                      widget.companyId,
                      widget.table.id,
                      widget.warehouseId,
                    );
                if (success && mounted) {
                  ref.read(mainNavigationIndexProvider.notifier).state = 0;
                } else if (context.mounted) {
                  showAppSnackbar(
                    context,
                    ref,
                    'Could not find active order.',
                    isError: true,
                  );
                }
              } else {
                // A live reservation holding this FREE table: offer to open that
                // booking (inherit its customer, resume its existing order)
                // instead of silently ringing up a Walk-in — the bug where a
                // booked guest's order was banked against Walk-in. With walk-ins
                // disabled the choice collapses to just opening the reservation.
                final liveBooking = _liveBookingForTable();
                if (liveBooking != null) {
                  final action = await _askBookedTableAction(
                    context,
                    liveBooking,
                    allowWalkIn: _walkInAllowed(),
                  );
                  if (action == null) return;
                  if (action == _BookedTableAction.reservation) {
                    await _openReservation(apiClient, liveBooking);
                    return;
                  }
                  // _BookedTableAction.walkIn falls through to the normal flow.
                  if (!context.mounted) return;
                }
                // Walk-ups on a free table are allowed by default. When the
                // venue turns that off, the table may only be opened from a
                // booking that currently holds it — the booking's own "Start
                // Service" seeds the cart and bypasses this path entirely.
                if (!_walkInAllowed() && !_hasLiveBooking()) {
                  if (context.mounted) {
                    showAppSnackbar(
                      context,
                      ref,
                      'This table needs a booking. Create one, then start '
                      'service from it.',
                      isError: true,
                    );
                  }
                  return;
                }
                final types = ref
                    .read(appSettingsProvider.notifier)
                    .customServiceTypes;
                final serviceType = await showDialog<int>(
                  context: context,
                  builder: (dialogCtx) => Dialog(
                    backgroundColor: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 40.0,
                        horizontal: 20.0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Service type",
                            style: TextStyle(
                              fontSize: 28,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Select service type for this order",
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: types.asMap().entries.map((e) {
                              final idx = e.key;
                              final t = e.value;
                              final color =
                                  _kServiceTypePalette[idx %
                                      _kServiceTypePalette.length];
                              final icon =
                                  _kServiceTypeIcons[idx.clamp(
                                    0,
                                    _kServiceTypeIcons.length - 1,
                                  )];
                              return InkWell(
                                onTap: () => Navigator.pop(dialogCtx, t.id),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 140,
                                  padding: const EdgeInsets.all(24.0),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: theme.dividerColor,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(icon, size: 48, color: color),
                                      const SizedBox(height: 16),
                                      Text(
                                        t.name,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                if (serviceType == null) return;

                if (serviceType != 0) {
                  await ref
                      .read(cartProvider.notifier)
                      .startTablelessOrder(
                        apiClient,
                        widget.companyId,
                        widget.userId,
                        serviceType,
                      );
                  if (mounted) {
                    ref.read(mainNavigationIndexProvider.notifier).state = 0;
                  }
                } else {
                  // OFFLINE-FIRST: no /PosOrder/Create call. The order is
                  // materialised in Drift at checkout time with a UUID;
                  // here we just set up local cart context with sentinel 0.
                  // Kitchen push is best-effort — wrapped so an offline KDS
                  // can't block table selection.
                  try {
                    ref.read(kitchenSyncProvider).push();
                  } catch (_) {
                    /* kitchen push is non-critical */
                  }
                  if (mounted) {
                    ref
                        .read(cartProvider.notifier)
                        .startTableOrder(
                          tableId: widget.table.id,
                          tableName: widget.table.name,
                        );
                    ref.read(mainNavigationIndexProvider.notifier).state = 0;
                  }
                }
              }
            } catch (e) {
              if (context.mounted) {
                showAppSnackbar(context, ref, 'Error: $e', isError: true);
              }
            } finally {
              if (mounted) setState(() => isCreatingOrder = false);
            }
          }
        },
        onPanUpdate: isEditMode && !isLocked
            ? (details) => setState(() {
                localX += details.delta.dx;
                localY += details.delta.dy;
              })
            : null,
        onPanEnd: isEditMode && !isLocked
            ? (details) => ref
                  .read(floorPlanTableProvider.notifier)
                  .updateTableGeometry(
                    widget.table.id,
                    localX,
                    localY,
                    widget.table.width,
                    widget.table.height,
                  )
            : null,
        child: Container(
          decoration: BoxDecoration(
            gradient: isLocked
                ? LinearGradient(
                    colors: [
                      theme.colorScheme.surfaceContainerHighest,
                      theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.7,
                      ),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : ServiceStatusHelper.getGradient(widget.table.status),
            shape: widget.table.isRound ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.table.isRound
                ? null
                : BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : isLocked
                  ? theme.colorScheme.outline
                  : Colors.black.withValues(alpha: 0.1),
              width: isSelected ? 4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: isCreatingOrder
                ? const CircularProgressIndicator(color: Colors.white)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isLocked
                            ? Icons.lock_outline
                            : ServiceStatusHelper.getIcon(widget.table.status),
                        color: isLocked
                            ? theme.colorScheme.onSurfaceVariant
                            : Colors.white,
                        size: widget.table.height > 60 ? 24 : 16,
                      ),
                      if (widget.table.height > 50) const SizedBox(height: 4),
                      if (widget.table.height > 50)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            widget.table.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isLocked
                                  ? theme.colorScheme.onSurfaceVariant
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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

const _kServiceTypePalette = [
  Color(0xFF4F89F0),
  Color(0xFFFF7043),
  Color(0xFF66BB6A),
  Color(0xFFAB47BC),
  Color(0xFF26C6DA),
  Color(0xFFFFCA28),
];
const _kServiceTypeIcons = [
  Icons.restaurant,
  Icons.shopping_bag_outlined,
  Icons.delivery_dining,
  Icons.room_service,
  Icons.local_cafe,
  Icons.local_bar,
];
