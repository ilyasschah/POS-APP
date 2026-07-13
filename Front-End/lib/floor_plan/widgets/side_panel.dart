import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pos_app/floor_plan/floor_plan_provider.dart';
import 'package:pos_app/floor_plan/floor_plan_table.dart';
import 'package:pos_app/floor_plan/floor_plan_table_provider.dart';
import 'package:pos_app/security/security_guard.dart';
import 'package:pos_app/security/security_keys.dart';

class SidePanel extends ConsumerWidget {
  final bool isService;
  const SidePanel({super.key, this.isService = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fpState = ref.watch(floorPlanProvider);
    final selectedTableId = ref.watch(floorPlanTableProvider);
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      width: 300,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PanelHeader(
              isEditMode: fpState.isEditMode,
              isService: isService,
              onClose: fpState.isEditMode
                  ? () {
                      ref
                          .read(floorPlanProvider.notifier)
                          .toggleEditMode(false);
                      ref
                          .read(floorPlanTableProvider.notifier)
                          .selectTable(null);
                      Navigator.pop(context);
                    }
                  : () => Navigator.pop(context),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Expanded(
              child: fpState.isEditMode
                  ? _EditPanel(
                      isService: isService,
                      selectedTableId: selectedTableId,
                      activePlanId: fpState.activeFloorPlanId ?? 0,
                      fpState: fpState,
                    )
                  : _ViewPanel(
                      isService: isService,
                      context: context,
                      ref: ref,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final bool isEditMode;
  final bool isService;
  final VoidCallback onClose;

  const _PanelHeader({
    required this.isEditMode,
    required this.isService,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          PhosphorIcon(
            isEditMode
                ? PhosphorIconsRegular.pencilSimpleSlash
                : PhosphorIconsRegular.sliders,
            size: 20,
            color: cs.primary,
          ),
          const Gap(10),
          Expanded(
            child: Text(
              isEditMode
                  ? (isService ? 'Edit Resources' : 'Edit Floor Plan')
                  : 'Options',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: PhosphorIcon(
              isEditMode
                  ? PhosphorIconsRegular.x
                  : PhosphorIconsRegular.arrowRight,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
            tooltip: isEditMode ? 'Exit Edit Mode' : 'Close',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

// ─── View Panel (normal mode) ─────────────────────────────────────────────────

class _ViewPanel extends StatelessWidget {
  final bool isService;
  final BuildContext context;
  final WidgetRef ref;

  const _ViewPanel({
    required this.isService,
    required this.context,
    required this.ref,
  });

  @override
  Widget build(BuildContext _) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ActionTile(
          icon: PhosphorIconsRegular.pencilSimple,
          title: isService ? 'Edit Resources & Rooms' : 'Edit Floor Plan',
          subtitle: 'Add, resize, and rename tables',
          onTap: () => ref.read(securityGuardProvider).guard(
            context,
            SecurityKeys.floorPlanDesign,
            () {
              ref.read(floorPlanProvider.notifier).toggleEditMode(true);
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}

// ─── Edit Panel (edit mode) ───────────────────────────────────────────────────

class _EditPanel extends ConsumerStatefulWidget {
  final bool isService;
  final int? selectedTableId;
  final int activePlanId;
  final FloorPlanState fpState;

  const _EditPanel({
    required this.isService,
    required this.selectedTableId,
    required this.activePlanId,
    required this.fpState,
  });

  @override
  ConsumerState<_EditPanel> createState() => _EditPanelState();
}

class _EditPanelState extends ConsumerState<_EditPanel> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tables = ref.watch(tablesByFloorPlanProvider).value ?? [];
    final selectedTable = widget.selectedTableId != null
        ? tables.where((t) => t.id == widget.selectedTableId).firstOrNull
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Grid settings
        const _SectionLabel('View Settings'),
        const Gap(8),
        _SettingsCard(
          children: [
            _ToggleRow(
              icon: PhosphorIconsRegular.dotsSixVertical,
              label: 'Show grid',
              value: widget.fpState.showGrid,
              onChanged: (v) =>
                  ref.read(floorPlanProvider.notifier).toggleShowGrid(v),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            _ToggleRow(
              icon: PhosphorIconsRegular.magnet,
              label: 'Snap to grid',
              value: widget.fpState.snapToGrid,
              onChanged: (v) =>
                  ref.read(floorPlanProvider.notifier).toggleSnapToGrid(v),
            ),
          ],
        ),
        const Gap(20),

        // Floor plan actions
        _SectionLabel(widget.isService ? 'Areas' : 'Floor Plans'),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: _OutlineBtn(
                icon: PhosphorIconsRegular.plus,
                label: widget.isService ? 'New Area' : 'New Floor',
                onTap: () => _showAddPlanDialog(context),
              ),
            ),
            const Gap(8),
            Expanded(
              child: _OutlineBtn(
                icon: PhosphorIconsRegular.pencilSimple,
                label: 'Rename',
                onTap: () => _showRenamePlanDialog(context),
              ),
            ),
          ],
        ),
        const Gap(8),
        _OutlineBtn(
          icon: PhosphorIconsRegular.trash,
          label: widget.isService ? 'Remove Area' : 'Remove Floor',
          danger: true,
          onTap: () => _confirmDeletePlan(context),
        ),
        const Gap(20),

        // Table actions
        _SectionLabel(widget.isService ? 'Resources' : 'Tables'),
        const Gap(8),
        _PrimaryBtn(
          icon: PhosphorIconsRegular.plus,
          label: widget.isService ? 'Add Resource' : 'Add Table',
          onTap: () {
            if (widget.activePlanId != 0) {
              ref
                  .read(floorPlanTableProvider.notifier)
                  .addTable(
                    FloorPlanTable(
                      id: 0,
                      floorPlanId: widget.activePlanId,
                      name: widget.isService ? 'New Resource' : 'New Table',
                      positionX: 60,
                      positionY: 60,
                      width: 100,
                      height: 100,
                      isRound: false,
                    ),
                  );
            }
          },
        ),

        // Table properties (when a table is selected)
        if (selectedTable != null) ...[
          const Gap(20),
          _SectionLabel(
            widget.isService ? 'Resource Properties' : 'Table Properties',
          ),
          const Gap(8),
          _TablePropertiesEditor(
            table: selectedTable,
            isService: widget.isService,
          ),
        ],
      ],
    );
  }

  void _showAddPlanDialog(BuildContext context) =>
      showAddFloorPlanDialog(context, ref, isService: widget.isService);

  void _showRenamePlanDialog(BuildContext context) {
    final plans = ref.read(allFloorPlansProvider).value ?? [];
    final active = plans.where((p) => p.id == widget.activePlanId).firstOrNull;
    if (active == null) return;

    final ctrl = TextEditingController(text: active.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                ref
                    .read(floorPlanProvider.notifier)
                    .updateFloorPlan(
                      active.id,
                      ctrl.text.trim(),
                      'Transparent',
                    );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlan(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Floor Plan'),
        content: const Text(
          'This will permanently remove the floor plan and all its tables. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () {
              ref
                  .read(floorPlanProvider.notifier)
                  .deleteFloorPlan(widget.activePlanId);
              Navigator.pop(ctx);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ─── Table Properties Editor ──────────────────────────────────────────────────

class _TablePropertiesEditor extends ConsumerStatefulWidget {
  final FloorPlanTable table;
  final bool isService;
  const _TablePropertiesEditor({required this.table, required this.isService});

  @override
  ConsumerState<_TablePropertiesEditor> createState() =>
      _TablePropertiesEditorState();
}

class _TablePropertiesEditorState
    extends ConsumerState<_TablePropertiesEditor> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.table.name);
  }

  @override
  void didUpdateWidget(covariant _TablePropertiesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.table.id != widget.table.id) {
      _nameCtrl.text = widget.table.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _applyName() {
    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) {
      ref
          .read(floorPlanTableProvider.notifier)
          .updateTableProperties(widget.table.id, name, widget.table.isRound);
    }
  }

  void _setSize(double w, double h) {
    ref
        .read(floorPlanTableProvider.notifier)
        .updateTableGeometry(
          widget.table.id,
          widget.table.positionX,
          widget.table.positionY,
          w,
          h,
        );
  }

  void _nudge(double dx, double dy) {
    ref
        .read(floorPlanTableProvider.notifier)
        .updateTableGeometry(
          widget.table.id,
          (widget.table.positionX + dx).clamp(0, 2000),
          (widget.table.positionY + dy).clamp(0, 2000),
          widget.table.width,
          widget.table.height,
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = widget.table;

    return _SettingsCard(
      children: [
        // Name
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Name',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const Gap(6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (_) => _applyName(),
                    ),
                  ),
                  const Gap(8),
                  IconButton.filled(
                    icon: const PhosphorIcon(PhosphorIconsRegular.check, size: 16),
                    onPressed: _applyName,
                    tooltip: 'Apply name',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: cs.outlineVariant),

        // Shape
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shape',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const Gap(8),
              Row(
                children: [
                  _ShapeOption(
                    label: 'Square',
                    icon: PhosphorIconsRegular.square,
                    selected: !t.isRound,
                    onTap: () => ref
                        .read(floorPlanTableProvider.notifier)
                        .updateTableProperties(t.id, t.name, false),
                  ),
                  const Gap(8),
                  _ShapeOption(
                    label: 'Circle',
                    icon: PhosphorIconsRegular.circle,
                    selected: t.isRound,
                    onTap: () => ref
                        .read(floorPlanTableProvider.notifier)
                        .updateTableProperties(t.id, t.name, true),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: cs.outlineVariant),

        // Size
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Size',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const Gap(8),
              _SizeRow(
                label: 'W',
                value: t.width,
                onDecrement: () =>
                    _setSize((t.width - 10).clamp(40, 500), t.height),
                onIncrement: () =>
                    _setSize((t.width + 10).clamp(40, 500), t.height),
              ),
              const Gap(6),
              _SizeRow(
                label: 'H',
                value: t.height,
                onDecrement: () =>
                    _setSize(t.width, (t.height - 10).clamp(40, 500)),
                onIncrement: () =>
                    _setSize(t.width, (t.height + 10).clamp(40, 500)),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: cs.outlineVariant),

        // Position nudge
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Position',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const Gap(8),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NudgeBtn(
                      icon: PhosphorIconsRegular.arrowUp,
                      onTap: () => _nudge(0, -10),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _NudgeBtn(
                          icon: PhosphorIconsRegular.arrowLeft,
                          onTap: () => _nudge(-10, 0),
                        ),
                        const Gap(8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: PhosphorIcon(
                            PhosphorIconsRegular.arrowsOut,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Gap(8),
                        _NudgeBtn(
                          icon: PhosphorIconsRegular.arrowRight,
                          onTap: () => _nudge(10, 0),
                        ),
                      ],
                    ),
                    _NudgeBtn(
                      icon: PhosphorIconsRegular.arrowDown,
                      onTap: () => _nudge(0, 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: cs.outlineVariant),

        // Delete
        Padding(
          padding: const EdgeInsets.all(12),
          child: _OutlineBtn(
            icon: PhosphorIconsRegular.trash,
            label: widget.isService ? 'Remove Resource' : 'Remove Table',
            danger: true,
            onTap: () =>
                ref.read(floorPlanTableProvider.notifier).deleteTable(t.id),
          ),
        ),
      ],
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: cs.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          PhosphorIcon(icon, size: 16, color: cs.onSurfaceVariant),
          const Gap(10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: cs.onSurface),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: PhosphorIcon(
                  icon,
                  size: 20,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        fontSize: 13,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _OutlineBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = danger ? cs.error : cs.onSurface;
    return OutlinedButton.icon(
      icon: PhosphorIcon(icon, size: 15, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        side: BorderSide(
          color: danger ? cs.error.withValues(alpha: 0.5) : cs.outlineVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PrimaryBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: PhosphorIcon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(double.infinity, 44),
      ),
      onPressed: onTap,
    );
  }
}

class _SizeRow extends StatelessWidget {
  final String label;
  final double value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _SizeRow({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const Gap(8),
        IconButton.outlined(
          icon: const PhosphorIcon(PhosphorIconsRegular.minus, size: 14),
          onPressed: onDecrement,
          style: IconButton.styleFrom(
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
          ),
        ),
        Expanded(
          child: Text(
            value.toInt().toString(),
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
        ),
        IconButton.outlined(
          icon: const PhosphorIcon(PhosphorIconsRegular.plus, size: 14),
          onPressed: onIncrement,
          style: IconButton.styleFrom(
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _ShapeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ShapeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                icon,
                size: 22,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
              const Gap(4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NudgeBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NudgeBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: PhosphorIcon(icon, size: 16, color: cs.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Prompts for a name and creates a floor plan / resource area. Shared by the
/// side panel's "New Floor" action and the empty-canvas call-to-action so both
/// open the exact same dialog.
Future<void> showAddFloorPlanDialog(
  BuildContext context,
  WidgetRef ref, {
  required bool isService,
}) {
  return showDialog(
    context: context,
    builder: (ctx) {
      String newName = '';
      return AlertDialog(
        title: Text(isService ? 'New Resource Area' : 'New Floor Plan'),
        content: TextField(
          onChanged: (v) => newName = v,
          decoration: const InputDecoration(
            hintText: 'E.g., Second Floor',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (newName.isNotEmpty) {
                ref
                    .read(floorPlanProvider.notifier)
                    .addFloorPlan(newName, 'Transparent');
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      );
    },
  );
}
