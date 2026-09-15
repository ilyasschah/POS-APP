import 'package:flutter/material.dart';

import 'glass.dart';
import 'theme.dart';
import 'typography.dart';

/// The **Ilyass Form**, ported from the POS (`Front-End/lib/core/ilyass_form.dart`)
/// onto the dashboard's glass cards: titled section cards, fields that pair up
/// only while they fit, math-based tile grids, and label → value rows that
/// never strand a value mid-row.
///
/// Every width here is measured on what the widget actually got, never on the
/// window (Ilyass Style §2) — a form inside a dialog, a sheet or a wide page
/// makes the same decisions from its own space.

/// Space between two fields, across or down.
const double kIlyassFieldGap = 16;

/// A titled card on a form: an icon and a heading, an optional line saying
/// what the section is FOR, then its fields.
class IlyassFormSection extends StatelessWidget {
  const IlyassFormSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final String? subtitle;

  /// Right after the title — a count, a total.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: palette.accent),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.headline(palette.primaryText),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
          if (subtitle != null)
            Padding(
              // Lined up under the title text, past the icon.
              padding: const EdgeInsetsDirectional.only(start: 30, top: 4),
              child: Text(
                subtitle!,
                style: AppText.caption(palette.dim(0.65)).copyWith(fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Fields side by side while each keeps [minFieldWidth], stacked below that.
/// Every row of a section using the same [flexes] is what lines its columns up.
class IlyassFieldRow extends StatelessWidget {
  const IlyassFieldRow({
    super.key,
    required this.children,
    this.flexes,
    this.minFieldWidth = 240,
  });

  final List<Widget> children;
  final List<int>? flexes;
  final double minFieldWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = children.length;
        final fits =
            constraints.maxWidth >= n * minFieldWidth + (n - 1) * kIlyassFieldGap;
        if (!fits) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(height: kIlyassFieldGap),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: kIlyassFieldGap),
              Expanded(flex: flexes?[i] ?? 1, child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Tiles in as many columns as fit at [minTileWidth] — at most [maxPerRow] —
/// each column the same width. Collapses continuously as the width shrinks,
/// with no jump at a breakpoint.
class IlyassTileGrid extends StatelessWidget {
  const IlyassTileGrid({
    super.key,
    required this.children,
    this.minTileWidth = 240,
    this.maxPerRow = 3,
    this.gap = 12,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxPerRow;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = ((constraints.maxWidth + gap) / (minTileWidth + gap))
            .floor()
            .clamp(1, maxPerRow);
        final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// One label → value line (Ilyass Style §1): the label hard left, the value
/// hard right, both loose so a long value ellipsizes instead of being parked
/// at the midpoint.
class IlyassValueRow extends StatelessWidget {
  const IlyassValueRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
    this.valueColor,
  });

  final String label;
  final String value;

  /// The line a column of figures adds up to — a total.
  final bool emphasis;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final valueStyle = emphasis
        ? AppText.bodyStrong(valueColor ?? palette.accent).weighted(800)
        : AppText.bodyStrong(valueColor ?? palette.primaryText);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 3,
            child: Text(
              label,
              style: emphasis
                  ? AppText.bodyStrong(palette.primaryText)
                  : AppText.body(palette.dim(0.7)),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// A field that opens a picker instead of taking typing — a date. Shaped like
/// every other input so the form reads as one set of fields, not a mix of
/// fields and buttons.
class IlyassTapField extends StatelessWidget {
  const IlyassTapField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;

  /// Null shows the field read-only.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onTap != null;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: label,
            enabled: enabled,
            labelStyle: AppText.label(palette.dim(0.7)),
            suffixIcon: Icon(
              icon,
              size: 20,
              color: enabled ? palette.accent : palette.dim(0.35),
            ),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(
              enabled ? palette.primaryText : palette.dim(0.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two to four mutually exclusive choices as one control — "%" or "DH".
/// Every segment is a full 48px target.
class IlyassSegmented<T> extends StatelessWidget {
  const IlyassSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<(T value, String label)> segments;
  final T value;

  /// Null shows the control read-only.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SegmentedButton<T>(
      showSelectedIcon: false,
      segments: [
        for (final (v, label) in segments)
          ButtonSegment<T>(value: v, label: Text(label)),
      ],
      selected: {value},
      onSelectionChanged:
          onChanged == null ? null : (s) => onChanged!(s.first),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(56, 48)),
        textStyle: WidgetStatePropertyAll(AppText.style(size: 15, weight: 700)),
        side: WidgetStatePropertyAll(
          BorderSide(color: palette.primaryText.withValues(alpha: 0.16)),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTheme.onAccent(palette.accent)
              : palette.primaryText,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? palette.accent : null,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.controlRadius),
          ),
        ),
      ),
    );
  }
}
