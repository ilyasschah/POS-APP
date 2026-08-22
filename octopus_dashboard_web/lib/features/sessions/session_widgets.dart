import 'package:flutter/material.dart';

import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../models/pos_session.dart';

/// The colour a lifecycle state carries everywhere it appears.
///
/// Mapped through [AppPalette] rather than to literal colours so the whole
/// screen flips with the theme, and deliberately per-state rather than a
/// binary open/closed — OPENING_CONTROL and CLOSING_CONTROL are the two states
/// where a register exists but is *not* trading, and flattening them would
/// hide exactly that.
Color sessionTint(AppPalette palette, PosSessionState state) => switch (state) {
  PosSessionState.openingControl => palette.warning,
  PosSessionState.opened => palette.positive,
  PosSessionState.closingControl => palette.indigo,
  PosSessionState.closed => palette.neutral,
  PosSessionState.unknown => palette.neutral,
};

IconData sessionIcon(PosSessionState state) => switch (state) {
  PosSessionState.openingControl => Icons.hourglass_top_rounded,
  PosSessionState.opened => Icons.sensors_rounded,
  PosSessionState.closingControl => Icons.checklist_rounded,
  PosSessionState.closed => Icons.verified_rounded,
  PosSessionState.unknown => Icons.help_outline_rounded,
};

/// Resolves a user id to a name, falling back to the id itself.
String cashierLabel(Map<int, String> names, int? userId) {
  if (userId == null) return '—';
  return names[userId] ?? 'User #$userId';
}

/// LIVE / COUNTING / CLOSED pill. A trading session gets a glowing beacon
/// instead of a static icon.
class SessionStatusPill extends StatelessWidget {
  const SessionStatusPill({super.key, required this.state});

  final PosSessionState state;

  @override
  Widget build(BuildContext context) {
    final color = sessionTint(context.palette, state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == PosSessionState.opened)
            LiveBeacon(color: color)
          else
            Icon(sessionIcon(state), size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            state.badge,
            style: AppText.style(
              size: 11,
              weight: 800,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// The "still trading" beacon: a solid dot inside a soft halo.
///
/// Deliberately **static**. A forever-repeating pulse would repaint on every
/// frame of a page an owner may leave open all day — the same cost this app
/// already avoids by suspending off-screen tickers and skipping backdrop blur
/// over a flat background — and an endless animation also means
/// `pumpAndSettle` never returns, which would hang the widget tests.
class LiveBeacon extends StatelessWidget {
  const LiveBeacon({super.key, required this.color, this.size = 14});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Container(
          width: size * 0.55,
          height: size * 0.55,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 5,
                spreadRadius: 2.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rounded square carrying a session's state colour in the list.
class SessionStateGlyph extends StatelessWidget {
  const SessionStateGlyph({super.key, required this.state, this.size = 42});

  final PosSessionState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = sessionTint(context.palette, state);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.38),
            color.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(sessionIcon(state), size: size * 0.42, color: color),
    );
  }
}

/// One of the four headline figures above the list.
class SessionStatCard extends StatelessWidget {
  const SessionStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppText.eyebrow(palette.dim(0.55)).copyWith(
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppText.style(
                size: 21,
                weight: 800,
                color: palette.primaryText,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: AppText.caption(palette.dim(0.45)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Selectable chip with a count, used for the All / Live / Closed / Attention
/// filter row.
class SessionFilterChip extends StatelessWidget {
  const SessionFilterChip({
    super.key,
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = selected ? color : palette.dim(0.7);
    return Material(
      color: selected
          ? color.withValues(alpha: 0.16)
          : palette.primaryText.withValues(alpha: 0.05),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? color.withValues(alpha: 0.45)
              : palette.primaryText.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppText.label(foreground).weighted(selected ? 700 : 600),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: palette.primaryText.withValues(
                    alpha: selected ? 0.12 : 0.07,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: AppText.caption(foreground).weighted(700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eyebrow above a block of content, optionally with a live beacon.
class SessionSectionLabel extends StatelessWidget {
  const SessionSectionLabel({
    super.key,
    required this.text,
    this.color,
    this.showPulse = false,
  });

  final String text;
  final Color? color;
  final bool showPulse;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          if (showPulse) ...[
            LiveBeacon(color: color ?? palette.positive),
            const SizedBox(width: 8),
          ],
          Text(text.toUpperCase(), style: AppText.eyebrow(palette.dim(0.55))),
        ],
      ),
    );
  }
}
