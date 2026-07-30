import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import 'dashboard_controller.dart';
import 'date_presets.dart';

/// Opens the date-range filter: a modal dialog on wide viewports, a bottom
/// sheet on compact ones.
Future<void> showDateFilter(BuildContext context) {
  final tier = LayoutTier.watch(context);

  if (tier.prefersDialog) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Layout.maxDialogWidth),
          child: const GlassCard.overlay(
            padding: EdgeInsets.all(24),
            child: DateFilterPanel(),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: 12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: GlassCard.overlay(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle.
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: context.palette.dim(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Flexible(child: DateFilterPanel()),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Preset grid + manual start/end pickers + "Apply Filter".
///
/// Presets apply immediately and close; the manual pickers require the
/// explicit Apply action, matching the iOS original.
class DateFilterPanel extends ConsumerWidget {
  const DateFilterPanel({super.key});

  void _apply(BuildContext context, WidgetRef ref) {
    Navigator.of(context).pop();
    ref.read(dashboardProvider.notifier).load();
  }

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref, {
    required bool isStart,
  }) async {
    final range = ref.read(dashboardRangeProvider);
    final initial = isStart ? range.start : range.end;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (picked == null) return;

    final controller = ref.read(dashboardRangeProvider.notifier);
    if (isStart) {
      controller.setStart(picked);
      // Keep the range coherent if the user picks a start after the end.
      if (picked.isAfter(ref.read(dashboardRangeProvider).end)) {
        controller.setEnd(picked);
      }
    } else {
      controller.setEnd(picked);
      if (picked.isBefore(ref.read(dashboardRangeProvider).start)) {
        controller.setStart(picked);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final range = ref.watch(dashboardRangeProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select Date Range',
            textAlign: TextAlign.center,
            style: AppText.headline(palette.primaryText),
          ),
          const SizedBox(height: 18),
          Text(
            'Predefined period',
            style: AppText.label(palette.dim(0.7)),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              // Two columns normally, four when there's room — keeps the grid
              // from becoming a tall scroll on wide dialogs.
              final columns = constraints.maxWidth >= 460 ? 4 : 2;
              const spacing = 10.0;
              final itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final preset in DatePreset.values)
                    SizedBox(
                      width: itemWidth,
                      child: _PresetButton(
                        preset: preset,
                        onTap: () {
                          ref
                              .read(dashboardRangeProvider.notifier)
                              .setRange(preset.resolve());
                          _apply(context, ref);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Divider(color: palette.primaryText.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          _DateRow(
            label: 'Start Date',
            value: Fmt.date(range.start),
            onTap: () => _pickDate(context, ref, isStart: true),
          ),
          const SizedBox(height: 10),
          _DateRow(
            label: 'End Date',
            value: Fmt.date(range.end),
            onTap: () => _pickDate(context, ref, isStart: false),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: () => _apply(context, ref),
              child: const Text('Apply Filter'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({required this.preset, required this.onTap});

  final DatePreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.primaryText.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppTheme.controlRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(
            preset.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(palette.primaryText),
          ),
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(child: Text(label, style: AppText.body(palette.primaryText))),
        GlassPill(
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: palette.accent,
              ),
              const SizedBox(width: 8),
              Text(value, style: AppText.label(palette.primaryText)),
            ],
          ),
        ),
      ],
    );
  }
}
