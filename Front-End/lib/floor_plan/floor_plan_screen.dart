import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pos_app/floor_plan/floor_plan_provider.dart';
import 'package:pos_app/floor_plan/floor_plan_table_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'widgets/table_widget.dart';
import 'widgets/side_panel.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/navigation/nav_widgets.dart';

class FloorPlanScreen extends ConsumerStatefulWidget {
  /// Opens the global navigation drawer (supplied by MainLayout). When null —
  /// e.g. the screen is pushed as a standalone route — the leading hamburger is
  /// hidden, matching the other POS tab screens.
  final VoidCallback? onMenuPressed;

  const FloorPlanScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<FloorPlanScreen> createState() => _FloorPlanScreenState();
}

class _FloorPlanScreenState extends ConsumerState<FloorPlanScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          ref.invalidate(allFloorPlansProvider);
        } catch (_) {}
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            ref.invalidate(tablesByFloorPlanProvider);
          } catch (_) {}
        });
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(allFloorPlansProvider);
    final tablesAsync = ref.watch(tablesByFloorPlanProvider);
    final fpState = ref.watch(floorPlanProvider);
    final cs = Theme.of(context).colorScheme;

    final companyId = ref.watch(selectedCompanyProvider)?.id ?? 0;
    final userId = ref.watch(currentUserProvider)?.id ?? 0;
    // No `?? 1` fallback: the seed is async, and a literal 1 both targets a
    // warehouse this company may not own and outranks the configured default
    // once it reaches the cart. Null lets the cart resolve it properly.
    final warehouseId = ref.watch(selectedWarehouseProvider)?.id;
    final settings = ref.watch(appSettingsProvider);
    final bookingEnabled =
        (settings[SettingKeys.featureBookingEnabled] ?? 'true') == 'true';

    return Scaffold(
      backgroundColor: cs.surface,
      endDrawer: const SidePanel(),
      body: Column(
        children: [
          // Unified flat top bar (replaces the legacy Material AppBar): the
          // horizontally scrolling room/resource tabs sit left-middle, the
          // refresh + settings/filters actions stay pinned right.
          PosTopBar(
            onMenuPressed: widget.onMenuPressed,
            title: plansAsync.when(
              loading: () => const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => Text(
                AppLocalizations.of(context).errorLoadingRooms,
                style: TextStyle(color: cs.error),
              ),
              data: (plans) {
                if (plans.isEmpty) {
                  return Text(
                    AppLocalizations.of(context).noFloorPlans,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  );
                }
                if (fpState.activeFloorPlanId == null) {
                  Future.microtask(
                    () => ref
                        .read(floorPlanProvider.notifier)
                        .setActiveFloorPlan(plans.first.id),
                  );
                }
                return SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: plans.length,
                    itemBuilder: (_, i) {
                      final plan = plans[i];
                      final active = fpState.activeFloorPlanId == plan.id;
                      return InkWell(
                        onTap: () => ref
                            .read(floorPlanProvider.notifier)
                            .setActiveFloorPlan(plan.id),
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: active ? cs.primary : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Text(
                            plan.name,
                            style: TextStyle(
                              color: active ? cs.primary : cs.onSurfaceVariant,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            actions: [
              if (bookingEnabled)
                IconButton(
                  icon: PhosphorIcon(
                    PhosphorIconsRegular.calendarBlank,
                    color: cs.primary,
                  ),
                  tooltip: AppLocalizations.of(context).posBookings,
                  onPressed: () {
                    ref.read(mainNavigationIndexProvider.notifier).state = 2;
                  },
                ),
              IconButton(
                icon: PhosphorIcon(
                  PhosphorIconsRegular.arrowClockwise,
                  color: cs.onSurfaceVariant,
                ),
                tooltip: AppLocalizations.of(context).refresh,
                onPressed: () {
                  try {
                    ref.invalidate(allFloorPlansProvider);
                  } catch (_) {}
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    try {
                      ref.invalidate(tablesByFloorPlanProvider);
                    } catch (_) {}
                  });
                },
              ),
              Builder(
                builder: (ctx) => IconButton(
                  icon: PhosphorIcon(
                    PhosphorIconsRegular.slidersHorizontal,
                    color: cs.onSurfaceVariant,
                  ),
                  tooltip: AppLocalizations.of(context).settings,
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                ),
              ),
            ],
          ),
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  ref.read(floorPlanTableProvider.notifier).selectTable(null),
              child: CustomPaint(
                painter: fpState.showGrid
                    ? _DotGridPainter(cs.outlineVariant)
                    : null,
                child: SizedBox.expand(
                  child: plansAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) =>
                        Center(child: Text(AppLocalizations.of(context).errorLoadingTables)),
                    data: (plans) {
                      // No rooms/resources exist yet → guide the user to create
                      // the first one. Without this the screen spins forever:
                      // tablesByFloorPlanProvider stays in `loading` while there
                      // is no active floor plan to query.
                      if (plans.isEmpty) {
                        return _EmptyFloorState(
                          plansExist: false,
                          onAction: () => showAddFloorPlanDialog(context, ref),
                        );
                      }
                      return tablesAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) =>
                            Center(child: Text(AppLocalizations.of(context).errorLoadingTables)),
                        data: (tables) {
                          if (tables.isEmpty) {
                            final activePlanId = fpState.activeFloorPlanId;
                            return _EmptyFloorState(
                              plansExist: true,
                              onAction: activePlanId == null
                                  ? null
                                  : () async {
                                      final err = await ref
                                          .read(floorPlanTableProvider.notifier)
                                          .addTable(floorPlanId: activePlanId);
                                      if (err != null && context.mounted) {
                                        showAppSnackbar(context, ref, err,
                                            isError: true);
                                      }
                                    },
                            );
                          }
                          return Stack(
                            children: tables
                                .map(
                                  (t) => TableWidget(
                                    key: ValueKey(t.id),
                                    table: t,
                                    companyId: companyId,
                                    userId: userId,
                                    warehouseId: warehouseId,
                                  ),
                                )
                                .toList(),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown on the floor-plan canvas when there is nothing to draw yet — either no
/// floor plans exist at all, or the active one has no tables.
/// Its button opens the same options end-drawer that hosts the create actions.
class _EmptyFloorState extends StatelessWidget {
  /// false → no floor plans exist yet; true → the active plan has no tables.
  /// Only the wording differs.
  final bool plansExist;

  /// Creates the missing thing directly (new floor plan dialog, or a new
  /// table). Null disables the button (e.g. no active plan to attach a table).
  final VoidCallback? onAction;

  const _EmptyFloorState({
    required this.plansExist,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final String title;
    final String subtitle;
    final String action;
    if (!plansExist) {
      title = 'No floor plans yet';
      subtitle =
          'You haven\'t created any floor plans yet. Open the options to add your first one.';
      action = 'Create floor plan';
    } else {
      title = 'No tables yet';
      subtitle = 'This floor plan has no tables. Open the options to add some.';
      action = 'Add table';
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.table_restaurant_outlined,
                size: 56,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(action),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;
  _DotGridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;
    const step = 32.0;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter old) => old.color != color;
}
