import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/floor_plan/floor_plan_provider.dart';
import 'package:pos_app/floor_plan/floor_plan_table.dart';
import 'package:pos_app/floor_plan/floor_plan_table_provider.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/utils/status_helper.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/kitchen/kitchen_push_service.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class TableWidget extends ConsumerStatefulWidget {
  final FloorPlanTable table;
  final int companyId;
  final int userId;
  final int warehouseId;

  const TableWidget({
    Key? key,
    required this.table,
    required this.companyId,
    required this.userId,
    required this.warehouseId,
  }) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final selectedTableId = ref.watch(floorPlanTableProvider);
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
                } else if (mounted) {
                  showAppSnackbar(
                    context,
                    ref,
                    'Could not find active order.',
                    isError: true,
                  );
                }
              } else {
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
                        .setOrderContext(
                          0, // local-only sentinel
                          widget.warehouseId,
                          tableId: widget.table.id,
                          orderNumber: "ORD- ${widget.table.name}",
                        );
                    ref.read(cartProvider.notifier).state = ref
                        .read(cartProvider)
                        .copyWith(serviceType: 0);
                    ref.read(mainNavigationIndexProvider.notifier).state = 0;
                  }
                }
              }
            } catch (e) {
              if (mounted)
                showAppSnackbar(context, ref, 'Error: $e', isError: true);
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
