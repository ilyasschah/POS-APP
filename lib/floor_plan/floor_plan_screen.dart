import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pos_app/floor_plan/floor_plan_provider.dart';
import 'package:pos_app/floor_plan/floor_plan_table_provider.dart';
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
    final warehouseId = ref.watch(selectedWarehouseProvider)?.id ?? 1;
    final settings = ref.watch(appSettingsProvider);
    final isService = (settings[SettingKeys.industryMode] ?? 'FB') == 'Service';
    final bookingEnabled =
        (settings[SettingKeys.featureBookingEnabled] ?? 'true') == 'true';

    return Scaffold(
      backgroundColor: cs.surface,
      endDrawer: SidePanel(isService: isService),
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
                isService ? 'Error loading resources' : 'Error loading rooms',
                style: TextStyle(color: cs.error),
              ),
              data: (plans) {
                if (plans.isEmpty) {
                  return Text(
                    isService ? 'No Resources' : 'No Floor Plans',
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
                  tooltip: 'Bookings',
                  onPressed: () {
                    ref.read(mainNavigationIndexProvider.notifier).state = 2;
                  },
                ),
              IconButton(
                icon: PhosphorIcon(
                  PhosphorIconsRegular.arrowClockwise,
                  color: cs.onSurfaceVariant,
                ),
                tooltip: 'Refresh',
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
                  tooltip: 'Settings',
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
                  child: tablesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) =>
                        const Center(child: Text('Error loading tables')),
                    data: (tables) => Stack(
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
                    ),
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
