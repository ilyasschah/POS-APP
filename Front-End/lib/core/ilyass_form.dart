import 'package:flutter/material.dart';

import 'package:pos_app/core/responsive.dart';

/// The **Ilyass Form**: the house building blocks for an editor dialog's tabs
/// — titled section cards, fields that pair up only while they fit, a grid of
/// equal-height tiles, and a switch that sits beside its own label.
///
/// Extracted from the product editor so the document editor (and whichever
/// dialog is next) looks the same by construction rather than by copy. The
/// layout rules are Ilyass Style's (PROJECT_DOCUMENTATION.md §7): widths are
/// measured on what the widget actually got, never on the window.

/// Page padding of an editor tab.
const double kIlyassTabPadding = 20;

/// Inner padding of an [IlyassFormSection].
const double kIlyassSectionPadding = 18;

/// Inner insets of a section card — a little tighter above the header.
const EdgeInsets kIlyassSectionInsets = EdgeInsets.fromLTRB(
  kIlyassSectionPadding,
  14,
  kIlyassSectionPadding,
  kIlyassSectionPadding,
);

/// The card every editor section sits on. Public so a tab that has to build
/// its own full-height card (a list that fills the tab) matches the rest.
BoxDecoration ilyassSectionDecoration(ColorScheme cs) => BoxDecoration(
  color: cs.surface,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
);

/// One outlined style for every field in an editor dialog. The fill matches
/// the section card behind it, so a floating label sits on a single colour
/// instead of straddling the border between two.
InputDecoration ilyassFieldDecoration(
  BuildContext context, {
  String? label,
  String? hint,
  String? prefix,
  String? suffix,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  prefixText: prefix,
  suffixText: suffix,
  prefixIcon: prefixIcon,
  suffixIcon: suffixIcon,
  filled: true,
  fillColor: Theme.of(context).colorScheme.surface,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
);

/// The frame an editor tab's sections sit in: page padding, the readable-width
/// cap, and a scroll view, so a short screen scrolls instead of overflowing.
class IlyassTabBody extends StatelessWidget {
  const IlyassTabBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kIlyassTabPadding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxReadableWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A section's small uppercase title, with an optional line of explanation
/// under it, an optional [trailing] (a count) beside it, and optional
/// [actions] (buttons) at the end of the line.
class IlyassSectionHeader extends StatelessWidget {
  const IlyassSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> actions;

  /// Below this width the actions drop beneath the title instead of sharing
  /// its line — measured on the section's own width.
  static const double _actionsInlineWidth = 520;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final heading = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            // Right after the title, not pushed to the far edge — a count
            // belongs to the words it counts.
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
        if (subtitle != null)
          Padding(
            // Lined up under the title text, past the icon.
            padding: const EdgeInsetsDirectional.only(start: 24, top: 4),
            child: Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );

    // No LayoutBuilder unless there is something to lay out: a plain header
    // must stay usable inside IlyassTileGrid's IntrinsicHeight.
    if (actions.isEmpty) return heading;

    final actionBar = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _actionsInlineWidth) {
          return Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: 12),
              actionBar,
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, const SizedBox(height: 10), actionBar],
        );
      },
    );
  }
}

/// A titled card on an editor tab: a small uppercase header, then its fields.
/// Subtle on purpose — it groups, it does not compete with the fields.
class IlyassFormSection extends StatelessWidget {
  const IlyassFormSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final Widget child;

  /// One quiet line under the title, for what the section is FOR.
  final String? subtitle;

  /// Beside the title — a count, say.
  final Widget? trailing;

  /// At the end of the header line — the section's own buttons.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: kIlyassSectionInsets,
      decoration: ilyassSectionDecoration(Theme.of(context).colorScheme),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IlyassSectionHeader(
            icon: icon,
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            actions: actions,
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// A small count pill for a section header.
class IlyassCountBadge extends StatelessWidget {
  const IlyassCountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Fields side by side while each keeps [minFieldWidth], stacked below that —
/// measured on the width the row actually gets, never the window (Ilyass
/// Style §2). Every row of a section using the same [flexes] is what lines its
/// columns up.
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

  static const double _gap = 16;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = children.length;
        final fits = constraints.maxWidth >= n * minFieldWidth + (n - 1) * _gap;
        if (!fits) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(height: _gap),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(flex: flexes?[i] ?? 1, child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Tiles in rows of as many as fit at [minTileWidth] — at most [maxPerRow] —
/// with every tile in a row stretched to one height, so a short tile beside a
/// long one leaves no ragged edge. Collapses continuously as the width shrinks.
///
/// 🚨 Tiles go through IntrinsicHeight, so a tile must not contain a
/// LayoutBuilder — which rules out [IlyassFieldRow] and a header with actions.
class IlyassTileGrid extends StatelessWidget {
  const IlyassTileGrid({
    super.key,
    required this.children,
    this.minTileWidth = 300,
    this.maxPerRow = 2,
  });

  final List<Widget> children;
  final double minTileWidth;

  /// Two by default: a third column pushes each switch or card too far from
  /// the label it belongs to. Short figures (a summary tile) can take three.
  final int maxPerRow;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = ((constraints.maxWidth + _gap) / (minTileWidth + _gap))
            .floor()
            .clamp(1, maxPerRow);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i += perRow) ...[
              if (i > 0) const SizedBox(height: _gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < perRow; j++) ...[
                      if (j > 0) const SizedBox(width: _gap),
                      Expanded(
                        child: i + j < children.length
                            ? children[i + j]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One on/off option: title, a line of explanation, and its switch right
/// beside them — not pushed to the far edge of a wide column.
///
/// 🚨 Stays a [SwitchListTile] with [title] as its exact title text: the E2E
/// `setSwitch` primitive finds these by `find.widgetWithText(SwitchListTile,
/// label)`. Wrapping the title or splitting it into a Row breaks that lookup.
class IlyassOptionSwitch extends StatelessWidget {
  const IlyassOptionSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;

  /// Optional: an option whose title says it all needs no second line.
  final String? subtitle;
  final bool value;

  /// Null disables the option (e.g. "sell by weight" on a service).
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // An option that is ON gets a faint primary edge, so the card's state
    // reads at a glance without hunting for the switch.
    final on = value && onChanged != null;
    return Material(
      color: on ? cs.primary.withValues(alpha: 0.05) : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: on ? cs.primary.withValues(alpha: 0.45) : cs.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 10, 4),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
      ),
    );
  }
}
