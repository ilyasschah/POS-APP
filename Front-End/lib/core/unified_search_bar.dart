import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An Odoo-style unified search bar: one field that carries the typed query
/// **and** the active filters, each as a dismissible chip inside the bar, with
/// a categorised filter menu anchored underneath it.
///
/// Why one bar instead of a panel of dropdowns: eight exposed dropdowns cost a
/// third of the screen and claim attention permanently, while the answer to
/// "what am I filtering on right now" is spread across eight controls. Here the
/// active state IS the chip row — nothing to read but what is switched on.
///
/// The menu is an [OverlayEntry] anchored with [CompositedTransformTarget] /
/// [CompositedTransformFollower], so it floats above the page and cannot push
/// the table around when it opens.

/// One active filter, rendered as a chip inside the bar.
@immutable
class SearchBarChip {
  const SearchBarChip({
    required this.id,
    required this.label,
    required this.icon,
    required this.onRemove,
    this.color,
  });

  /// Stable identity — used as the widget key so removing one chip does not
  /// rebuild the rest.
  final String id;

  final String label;
  final IconData icon;
  final VoidCallback onRemove;

  /// Tints the chip; defaults to the theme's primary.
  final Color? color;
}

/// One selectable line in the filter menu.
@immutable
class FilterMenuOption {
  const FilterMenuOption({
    required this.label,
    required this.onSelected,
    this.icon,
    this.selected = false,
    this.trailingLabel,
  });

  final String label;
  final VoidCallback onSelected;
  final IconData? icon;

  /// Renders a check and the accent colour — this option is already applied.
  final bool selected;

  /// Small end-aligned hint, e.g. a count or a date range.
  final String? trailingLabel;
}

/// A titled group of options in the menu — Status, Date, Customer, …
@immutable
class FilterMenuSection {
  const FilterMenuSection({
    required this.title,
    required this.options,
    this.icon,
    this.footnote,
  });

  final String title;
  final IconData? icon;
  final List<FilterMenuOption> options;

  /// Shown greyed under the options, e.g. "keep typing to narrow this list".
  final String? footnote;
}

class UnifiedSearchBar extends StatefulWidget {
  const UnifiedSearchBar({
    super.key,
    required this.controller,
    required this.chips,
    required this.sectionsBuilder,
    required this.hintText,
    this.onQueryChanged,
    this.onSubmitted,
    this.onClearAll,
    this.menuMaxHeight = 420,
    this.singleLine = false,
    this.trailing,
  });

  final TextEditingController controller;

  /// Active filters, oldest first. Rendered before the text input.
  final List<SearchBarChip> chips;

  /// Builds the menu for the current query — so the same menu can offer
  /// "Search Number for: INV-2" while the user types and the plain category
  /// list when the field is empty.
  final List<FilterMenuSection> Function(String query) sectionsBuilder;

  final String hintText;
  final ValueChanged<String>? onQueryChanged;

  /// Enter with text in the field. Given the first menu option, if any, so the
  /// caller can apply the obvious suggestion.
  final ValueChanged<String>? onSubmitted;

  /// Clears the query and every chip. Hidden when nothing is active.
  final VoidCallback? onClearAll;

  final double menuMaxHeight;

  /// Quick actions that belong to the search itself, rendered INSIDE the bar's
  /// border just before the filter button — the Products screen's scope
  /// toggles (all fields / barcode / code / name) are the case this exists
  /// for. They are not filters: a scope changes what the typed text is matched
  /// against, so it has no chip and never appears in the menu.
  final Widget? trailing;

  /// Keeps the bar exactly one row tall: chips sit beside the input instead of
  /// wrapping under it, and each one is capped so the field always keeps room
  /// to type in.
  ///
  /// For hosts with a fixed height — a top bar is 62px and cannot grow — where
  /// a second row of chips would overflow rather than expand.
  final bool singleLine;

  @override
  State<UnifiedSearchBar> createState() => _UnifiedSearchBarState();
}

class _UnifiedSearchBarState extends State<UnifiedSearchBar> {
  final LayerLink _link = LayerLink();
  final GlobalKey _barKey = GlobalKey();
  final FocusNode _focusNode = FocusNode();

  /// Ties the bar and its floating menu into one tap group — see [_buildMenu].
  final Object _groupId = Object();

  OverlayEntry? _menu;

  bool get _isOpen => _menu != null;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // Remove the entry DIRECTLY, not through _closeMenu: an overlay entry left
    // behind outlives this widget and paints over the next screen, but calling
    // setState from dispose asserts — the element is already defunct by the
    // time State.dispose runs, even though `mounted` still reads true.
    _menu?.remove();
    _menu = null;
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Typing re-renders the menu in place (the suggestions depend on the
    // query) and opens it on the first character, the way a search box that
    // suggests things is expected to behave.
    if (_isOpen) {
      _menu!.markNeedsBuild();
    } else if (widget.controller.text.isNotEmpty) {
      _openMenu();
    }
    setState(() {}); // the clear button appears/disappears with the text
  }

  void _toggleMenu() => _isOpen ? _closeMenu() : _openMenu();

  void _openMenu() {
    if (_isOpen) return;
    final overlay = Overlay.of(context);
    _menu = OverlayEntry(builder: _buildMenu);
    overlay.insert(_menu!);
    setState(() {});
  }

  void _closeMenu() {
    _menu?.remove();
    _menu = null;
    if (mounted) setState(() {});
  }

  /// The bar's live width, read at build time so the menu tracks a window
  /// resize rather than freezing at the width it had when it opened.
  double get _barWidth {
    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.width ?? 480;
  }

  Widget _buildMenu(BuildContext context) {
    final sections = widget.sectionsBuilder(widget.controller.text);

    // 🚨 A [TapRegion] group, NOT a full-screen barrier. A barrier over the
    // whole page also covers the bar itself, so with the menu open the first
    // click on a chip's X (or on Clear all) is swallowed just to dismiss the
    // menu, and the operator has to click twice to remove a filter they can
    // see. Sharing a group id with the bar means taps on either count as
    // "inside" and only a tap somewhere else closes it.
    return TapRegion(
      groupId: _groupId,
      onTapOutside: (_) => _closeMenu(),
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 6),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: _FilterMenu(
            width: _barWidth,
            maxHeight: widget.menuMaxHeight,
            sections: sections,
            onSelected: (option) {
              option.onSelected();
              _closeMenu();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasContent =
        widget.chips.isNotEmpty || widget.controller.text.isNotEmpty;

    return TapRegion(
      groupId: _groupId,
      child: CompositedTransformTarget(
        link: _link,
        child: Container(
          key: _barKey,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isOpen || _focusNode.hasFocus
                  ? cs.primary.withValues(alpha: 0.7)
                  : cs.outlineVariant.withValues(alpha: 0.5),
              width: _isOpen || _focusNode.hasFocus ? 1.5 : 1,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: widget.singleLine ? 3 : 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              // Chips FIRST, then the input.
              Expanded(child: _chipsAndInput(theme)),
              if (hasContent && widget.onClearAll != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).deleteButtonTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    widget.onClearAll!();
                    _closeMenu();
                  },
                ),
              if (widget.trailing != null) ...[
                SizedBox(
                  height: 26,
                  child: VerticalDivider(
                    width: 12,
                    thickness: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                widget.trailing!,
              ],
              SizedBox(
                height: 26,
                child: VerticalDivider(
                  width: 12,
                  thickness: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              // The trailing filter button, inside the bar's border.
              _FilterButton(isOpen: _isOpen, onPressed: _toggleMenu),
            ],
          ),
        ),
      ),
    );
  }

  /// Wrapping by default — a long filter set moves to a second line instead of
  /// squeezing the field to nothing. In [UnifiedSearchBar.singleLine] the bar
  /// cannot grow, so the chips are capped and share the row instead.
  Widget _chipsAndInput(ThemeData theme) {
    if (!widget.singleLine) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final chip in widget.chips)
            _Chip(key: ValueKey(chip.id), chip: chip),
          SizedBox(
            width: widget.chips.isEmpty ? double.infinity : 200,
            child: _input(theme),
          ),
        ],
      );
    }

    return Row(
      children: [
        for (final chip in widget.chips) ...[
          ConstrainedBox(
            // Capped, so three filters cannot leave the operator with a
            // 20px-wide box to type in.
            constraints: const BoxConstraints(maxWidth: 170),
            child: _Chip(key: ValueKey(chip.id), chip: chip),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(child: _input(theme)),
      ],
    );
  }

  Widget _input(ThemeData theme) {
    return KeyboardListener(
      focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _closeMenu();
        }
      },
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onQueryChanged,
        onSubmitted: widget.onSubmitted,
        onTap: _openMenu,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            vertical: widget.singleLine ? 6 : 10,
          ),
          hintText: widget.chips.isEmpty ? widget.hintText : null,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.chip});

  final SearchBarChip chip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = chip.color ?? theme.colorScheme.primary;

    return InputChip(
      avatar: Icon(chip.icon, size: 15, color: color),
      label: Text(chip.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      deleteIcon: Icon(Icons.close, size: 15, color: color),
      onDeleted: chip.onRemove,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.isOpen, required this.onPressed});

  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: isOpen ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list_rounded,
                size: 18,
                color: isOpen ? cs.primary : cs.onSurfaceVariant,
              ),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: isOpen ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The floating panel itself — sections of options, scrollable, capped so it
/// never runs off the bottom of a short window.
class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.width,
    required this.maxHeight,
    required this.sections,
    required this.onSelected,
  });

  final double width;
  final double maxHeight;
  final List<FilterMenuSection> sections;
  final ValueChanged<FilterMenuOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final visible = sections.where((s) => s.options.isNotEmpty).toList();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      color: cs.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
        child: visible.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  MaterialLocalizations.of(context).searchFieldLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 9,
                          color: cs.outlineVariant.withValues(alpha: 0.35),
                        ),
                      _section(theme, visible[i]),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _section(ThemeData theme, FilterMenuSection section) {
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(
            children: [
              if (section.icon != null) ...[
                Icon(section.icon, size: 14, color: cs.primary),
                const SizedBox(width: 8),
              ],
              Text(
                section.title.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        for (final option in section.options) _option(theme, option),
        if (section.footnote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
            child: Text(
              section.footnote!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _option(ThemeData theme, FilterMenuOption option) {
    final cs = theme.colorScheme;
    final color = option.selected ? cs.primary : cs.onSurface;

    return InkWell(
      onTap: () => onSelected(option),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: option.selected
                  ? Icon(Icons.check, size: 15, color: cs.primary)
                  : (option.icon == null
                        ? null
                        : Icon(
                            option.icon,
                            size: 15,
                            color: cs.onSurfaceVariant,
                          )),
            ),
            Expanded(
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: option.selected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
            if (option.trailingLabel != null) ...[
              const SizedBox(width: 10),
              Text(
                option.trailingLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
