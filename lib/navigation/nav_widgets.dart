// Shared design tokens and primitive widgets for the two-tier navigation shell.
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/sync/server_status_provider.dart';

// ── Layout constant (non-colour — safe to keep const) ─────────────────────────
const kSidebarW = 220.0;
// Collapsed "mini rail" width — icon-only, used by the Management shell.
const kSidebarMiniW = 72.0;

// ── Theme helpers (replaces the old hardcoded kNav* constants) ────────────────
// Each widget now reads from Theme.of(context) so all custom themes apply.

extension NavTheme on BuildContext {
  ColorScheme get _cs => Theme.of(this).colorScheme;

  Color get navSidebarBg => _cs.surfaceContainer;
  Color get navHover => _cs.surfaceContainerHigh;
  Color get navActiveBg => _cs.primaryContainer;
  Color get navAccent => _cs.primary;
  Color get navText => _cs.onSurface;
  Color get navMuted => _cs.onSurfaceVariant;
  Color get navDivider => _cs.outline.withValues(alpha: 0.3);
  Color get navScaffoldBg => Theme.of(this).scaffoldBackgroundColor;
}

// ── Section label ─────────────────────────────────────────────────────────────

class NavSectionLabel extends StatelessWidget {
  final String text;
  const NavSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          color: context.navMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Sidebar company / logo header ─────────────────────────────────────────────

class NavSidebarHeader extends ConsumerWidget {
  final String name;
  final VoidCallback? onHideSidebar;

  const NavSidebarHeader({super.key, required this.name, this.onHideSidebar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(selectedCompanyProvider);
    final cs = Theme.of(context).colorScheme;
    final accent = context.navAccent;

    ImageProvider? logoProvider;
    if (company?.logo != null && company!.logo!.isNotEmpty) {
      try {
        logoProvider = MemoryImage(base64Decode(company.logo!));
      } catch (_) {}
    }
    final hasLogo = logoProvider != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 8, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            // Inset the asset so a transparent brand PNG breathes inside its
            // frame instead of touching the rounded edges.
            padding: hasLogo ? const EdgeInsets.all(6) : EdgeInsets.zero,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // A real logo sits on a neutral adaptive card frame (clean in both
              // light + dark) rather than a harsh accent block; the lettermark
              // fallback keeps the branded accent fill.
              color: hasLogo ? cs.surfaceContainerLow : accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: logoProvider != null
                // contain (never cover) so logos are shown whole, never cropped
                // or stretched, whatever aspect ratio the user uploads.
                ? Image(image: logoProvider, fit: BoxFit.contain)
                : Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: context.navText,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                _ServerStatusRow(accent: accent),
              ],
            ),
          ),
          if (onHideSidebar != null)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.menu_open, color: context.navMuted),
              tooltip: "Hide Sidebar",
              onPressed: onHideSidebar,
            ),
        ],
      ),
    );
  }
}

// ── Real-time server reachability dot ────────────────────────────────────────
// Watches the periodic ping in serverStatusProvider and renders a coloured
// dot + label. The `accent` colour is reused for the Online state so the
// sidebar header still matches the company theme; offline falls back to a
// muted neutral so it doesn't scream at the cashier during a brief outage.

class _ServerStatusRow extends ConsumerWidget {
  final Color accent;
  const _ServerStatusRow({required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value ?? false` covers both the "first ping in flight" (AsyncLoading)
    // and "ping just threw" (AsyncError) cases — both show as Offline, which
    // is the conservative default.
    final isOnline = ref.watch(serverStatusProvider).value ?? false;
    final color = isOnline ? accent : Theme.of(context).disabledColor;
    final label = isOnline ? 'Online' : 'Offline';

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Nav item (hover + optional active state) ──────────────────────────────────

class NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color? textColor;
  final Color? iconColor;
  final bool isActive;
  final VoidCallback onTap;

  /// Mini "rail" mode: render only the centred icon (label + trailing hidden)
  /// and surface the label through a hover Tooltip instead.
  final bool isMini;

  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.textColor,
    this.iconColor,
    this.isActive = false,
    this.isMini = false,
  });

  @override
  State<NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final accent = context.navAccent;
    final textColor = widget.textColor ?? (active ? accent : context.navText);
    final iconColor = widget.iconColor ?? (active ? accent : context.navMuted);
    final bg = active
        ? context.navActiveBg
        : (_hovered ? context.navHover : Colors.transparent);

    // ── Mini rail: icon-only, label exposed via Tooltip on hover ──────────────
    if (widget.isMini) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Tooltip(
          message: widget.label,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, size: 20, color: iconColor),
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          // Low-spec: flat Container (no per-frame animation, no transform).
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Static active-accent bar (instant state swap, no animation).
                if (active)
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Icon(widget.icon, size: 18, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small icon button for the hardware bar ────────────────────────────────────

class NavIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? iconColor;

  const NavIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor,
  });

  @override
  State<NavIconButton> createState() => _NavIconButtonState();
}

class _NavIconButtonState extends State<NavIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _hovered ? context.navHover : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: widget.iconColor ?? context.navMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Unified flat top bar ──────────────────────────────────────────────────────
// The shared header used across the core POS tab screens (Menu, Floor Plan,
// Bookings). Mirrors the Menu screen's bar: 62px tall, solid surface fill, a
// crisp single-line bottom divider, zero shadow/tint. A leading hamburger opens
// the global navigation drawer (wired from MainLayout via [onMenuPressed]); the
// title sits left-middle and screen-specific [actions] stay pinned to the right.
const kTopBarHeight = 62.0;

class PosTopBar extends StatelessWidget implements PreferredSizeWidget {
  /// Opens the global navigation drawer. When null the leading hamburger is
  /// hidden (e.g. the screen is pushed as a standalone route, not a tab).
  final VoidCallback? onMenuPressed;

  /// Explicit leading widget (e.g. a back button for a pushed route). When set
  /// it takes precedence over the [onMenuPressed] hamburger.
  final Widget? leading;

  /// Left-middle content — a plain title Text, or a horizontally scrolling row
  /// of tabs. Rendered inside an [Expanded] so it absorbs the free space.
  final Widget title;

  /// Screen-specific action widgets, pinned to the right edge.
  final List<Widget> actions;

  const PosTopBar({
    super.key,
    required this.title,
    this.onMenuPressed,
    this.leading,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(kTopBarHeight);

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        // Flat: solid surface, single divider line, no elevation/shadow/tint.
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: context.navDivider)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kTopBarHeight,
          child: Row(
            children: [
              if (leading != null)
                leading!
              else if (onMenuPressed != null)
                IconButton(
                  icon: Icon(Icons.menu, size: 26, color: onSurface),
                  tooltip: 'Menu',
                  onPressed: onMenuPressed,
                )
              else
                const SizedBox(width: 12),
              Expanded(child: title),
              ...actions,
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SHELL PRIMITIVES
// Reused by the POS (main), Management and Settings sidebars. Tuned for
// low-spec hardware: instant state swaps, no animation controllers, no clips.
// ─────────────────────────────────────────────────────────────────────────────

// ── Lazy IndexedStack ─────────────────────────────────────────────────────────
// Keeps every *visited* child alive so switching tabs is instant and preserves
// each view's state + scroll position (no rebuild / re-fetch). A child is only
// built the first time its index is shown; unvisited indices stay as a cheap
// SizedBox.shrink, so opening the shell doesn't eagerly spin up every screen
// (and its providers) at once.
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _activated = {};

  @override
  void initState() {
    super.initState();
    _activated.add(widget.index);
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _activated.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      sizing: StackFit.expand,
      children: [
        for (int i = 0; i < widget.children.length; i++)
          if (_activated.contains(i))
            widget.children[i]
          else
            const SizedBox.shrink(),
      ],
    );
  }
}

// Low-spec note: the sidebar now shows/hides instantly via conditional
// inclusion in each shell's Row (`if (visible) sidebar`), so the old
// width-animating CollapsibleSidebar wrapper (AnimatedContainer + ClipRect +
// OverflowBox) and the fade/slide NavBodyTransition were removed entirely —
// LazyIndexedStack already gives instant, stateful tab switching on its own.

// ── Floating edge toggle ──────────────────────────────────────────────────────
// A thin, accent-coloured tab docked to the left edge of the body that brings
// the sidebar back. Low-spec: flat colour, no shadow, no hover/size animation.
class NavEdgeToggle extends StatelessWidget {
  final VoidCallback onTap;
  const NavEdgeToggle({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 22,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.navAccent,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(12),
              ),
            ),
            child: Icon(
              Icons.chevron_right,
              size: 20,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
