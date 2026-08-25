import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/modifier/modifier_icons.dart';
import 'package:pos_app/modifier/modifier_models.dart';

/// What the cashier chose, handed back to whoever opened the sheet.
class CustomizeResult {
  const CustomizeResult({required this.modifiers, this.note});

  final List<SelectedModifier> modifiers;

  /// The free-text note, when a group asked for one. Null when none was typed.
  ///
  /// It lands in the order line's existing `comment` column rather than a new
  /// one — see `ModifierGroup.AllowsFreeText`.
  final String? note;
}

/// Asks the cashier for a product's modifiers before it goes in the cart.
///
/// Returns null if they back out, which must mean "add nothing" — a cancelled
/// sheet that still added the plain item would be a wrong sale nobody asked for.
///
/// [initial] pre-selects, so the same sheet re-edits a line already in the cart.
Future<CustomizeResult?> showCustomizeItemSheet(
  BuildContext context, {
  required String itemName,
  required double basePrice,
  required List<ModifierGroup> groups,
  List<SelectedModifier> initial = const [],
  String? initialNote,
}) {
  return showDialog<CustomizeResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CustomizeItemSheet(
      itemName: itemName,
      basePrice: basePrice,
      groups: groups,
      initial: initial,
      initialNote: initialNote,
    ),
  );
}

// ── Design notes ─────────────────────────────────────────────────────────────
//
// This is read by someone with a queue behind them, on a 10-inch tablet, with a
// finger. Everything here follows from that: nothing is small, state is
// unmistakable, and the answer to "is this order complete?" is a SCAN down the
// status rail rather than a read.
//
// 🚨 Every colour comes from `colorScheme` or the house status tokens. The
// palette is not this file's to invent — see the theme rules in CLAUDE.md.
//
// **Icons are either CHOSEN or structural — never guessed from a name.** The
// group's glyph is the one the operator picked in the admin screen and stored
// on the row (`ModifierGroup.iconKey`), so it is right in every language;
// deriving it from "Toppings" with a keyword map would have matched English and
// left "Garnitures" and "الإضافات" on a fallback forever. The option cards then
// carry structural icons only — a filled check when chosen, a radio or a plus
// when not — which state what the control DOES and need no translation either.
//
// **Groups are numbered**, and that is earned rather than decorative:
// `ProductModifierGroup.rank` literally IS the sequence the cashier is asked
// in, and the product editor has drag-to-reorder for exactly that reason.
//
// **The running total appears once**, on the confirm button. It was tempting to
// echo it in the header; two live copies of one number is noise, and the button
// is where the hand is going anyway.

/// Card geometry. Chunky on purpose — these are finger targets first.
const double _kCardMinWidth = 240;
const double _kCardMinHeight = 64;
const double _kRadius = 14;

class _CustomizeItemSheet extends ConsumerStatefulWidget {
  const _CustomizeItemSheet({
    required this.itemName,
    required this.basePrice,
    required this.groups,
    required this.initial,
    required this.initialNote,
  });

  final String itemName;
  final double basePrice;
  final List<ModifierGroup> groups;
  final List<SelectedModifier> initial;
  final String? initialNote;

  @override
  ConsumerState<_CustomizeItemSheet> createState() =>
      _CustomizeItemSheetState();
}

class _CustomizeItemSheetState extends ConsumerState<_CustomizeItemSheet> {
  /// Chosen option ids, per group. A Set because within one group an option is
  /// either chosen or not — there is no "two of the same topping".
  final Map<int, Set<int>> _chosen = {};
  late final TextEditingController _noteCtrl;

  /// Set once the cashier has tried to confirm, so unmet groups are only
  /// called out AFTER a real attempt. Showing every mandatory group in red the
  /// instant the sheet opens reads as an error they have not made yet.
  bool _triedToConfirm = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.initialNote ?? '');

    final initialIds =
        widget.initial.map((m) => m.modifierOptionId).whereType<int>().toSet();
    for (final g in widget.groups) {
      _chosen[g.id] = g.options
          .where((o) => initialIds.contains(o.id))
          .map((o) => o.id)
          .toSet();

      // A mandatory pick-one with nothing chosen yet starts on its first
      // choice. The cashier has to pick something, and a radio group with no
      // default is one more tap on every single sale.
      if (_chosen[g.id]!.isEmpty &&
          g.isMandatory &&
          g.isSingleChoice &&
          g.options.isNotEmpty) {
        _chosen[g.id] = {g.options.first.id};
      }
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  List<SelectedModifier> get _selection => [
        for (final g in widget.groups)
          for (final o in g.options)
            if (_chosen[g.id]?.contains(o.id) ?? false)
              o.toSelection(groupName: g.name),
      ];

  List<ModifierGroup> get _unmet => widget.groups
      .where((g) =>
          modifierGroupViolation(g, _chosen[g.id]?.length ?? 0) != null)
      .toList();

  bool get _wantsNote => widget.groups.any((g) => g.allowsFreeText);

  void _toggle(ModifierGroup group, ModifierOption option) {
    setState(() {
      final chosen = _chosen[group.id] ??= {};

      if (group.isSingleChoice) {
        // Radio behaviour, with one addition: tapping the chosen option again
        // CLEARS it when the group is optional. Otherwise an optional pick-one
        // becomes impossible to un-answer once touched.
        if (chosen.contains(option.id)) {
          if (!group.isMandatory) chosen.clear();
        } else {
          chosen
            ..clear()
            ..add(option.id);
        }
        return;
      }

      if (chosen.contains(option.id)) {
        chosen.remove(option.id);
      } else if (chosen.length < group.maxSelections) {
        chosen.add(option.id);
      }
    });
  }

  void _confirm() {
    if (_unmet.isNotEmpty) {
      setState(() => _triedToConfirm = true);
      return;
    }
    final note = _noteCtrl.text.trim();
    Navigator.pop(
      context,
      CustomizeResult(
        modifiers: _selection,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sym = ref.watch(currencySymbolProvider);
    final size = MediaQuery.sizeOf(context);

    final unmetIds =
        _triedToConfirm ? _unmet.map((g) => g.id).toSet() : const <int>{};
    final total = widget.basePrice + modifierSurcharge(_selection);

    return Dialog(
      backgroundColor: theme.cardColor,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kRadius + 6),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(itemName: widget.itemName),
            Divider(height: 1, color: cs.outlineVariant),

            // ── Body ──────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < widget.groups.length; i++) ...[
                      if (i > 0) const SizedBox(height: 22),
                      _GroupSection(
                        index: i + 1,
                        group: widget.groups[i],
                        chosen: _chosen[widget.groups[i].id] ?? const {},
                        isUnmet: unmetIds.contains(widget.groups[i].id),
                        currencySymbol: sym,
                        onToggle: (o) => _toggle(widget.groups[i], o),
                      ),
                    ],
                    if (_wantsNote) ...[
                      const SizedBox(height: 22),
                      _NoteSection(
                        index: widget.groups.length + 1,
                        controller: _noteCtrl,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Divider(height: 1, color: cs.outlineVariant),
            _Footer(
              total: total,
              currencySymbol: sym,
              onCancel: () => Navigator.pop(context),
              onConfirm: _confirm,
              // Live, so the button reads as the answer rather than a gate.
              blockedCount: _unmet.length,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.itemName});

  final String itemName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: PhosphorIcon(PhosphorIconsFill.slidersHorizontal,
                size: 20, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // Its own string, not `customizeItem('')` trimmed — that only
                  // works while every translation happens to put the product
                  // name last, which is not a promise any translator made.
                  l10n.customizeEyebrow,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.actionCancel,
            icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ── One group ────────────────────────────────────────────────────────────────

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.index,
    required this.group,
    required this.chosen,
    required this.isUnmet,
    required this.currencySymbol,
    required this.onToggle,
  });

  final int index;
  final ModifierGroup group;
  final Set<int> chosen;
  final bool isUnmet;
  final String currencySymbol;
  final ValueChanged<ModifierOption> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final atMax = !group.isSingleChoice && chosen.length >= group.maxSelections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Numbered because the order is real data, not decoration.
            _StepMarker(index: index, isUnmet: isUnmet),
            const SizedBox(width: 10),
            // The icon the operator PICKED for this group, or the neutral
            // fallback. Only one glyph here on purpose — the option cards
            // already say whether this is a radio or a checkbox, so repeating
            // the rule as a second icon would be two symbols competing.
            PhosphorIcon(
              modifierIconFor(group.iconKey).fill,
              size: 18,
              color: isUnmet ? cs.error : cs.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 3,
              child: Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isUnmet ? cs.error : cs.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 2,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _StatusPill(
                  group: group,
                  chosenCount: chosen.length,
                  isUnmet: isUnmet,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            // Column count from the width the section actually has, against a
            // minimum card width — never from a device-class guess. A tablet in
            // landscape has room for two; a narrow cart pane does not.
            final columns =
                (constraints.maxWidth / _kCardMinWidth).floor().clamp(1, 2);
            const gap = 10.0;
            final cardWidth = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - gap * (columns - 1)) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final o in group.options)
                  SizedBox(
                    width: cardWidth,
                    child: _OptionCard(
                      option: o,
                      isSingleChoice: group.isSingleChoice,
                      chosen: chosen.contains(o.id),
                      // Dimmed only when picking it would break the rule. An
                      // already-chosen option always stays live, or a full
                      // group could be cleared but never changed.
                      enabled: chosen.contains(o.id) ||
                          group.isSingleChoice ||
                          !atMax,
                      currencySymbol: currencySymbol,
                      onTap: () => onToggle(o),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The group's position in the sequence the cashier is asked.
class _StepMarker extends StatelessWidget {
  const _StepMarker({required this.index, required this.isUnmet});

  final int index;
  final bool isUnmet;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tint = isUnmet ? cs.error : cs.primary;

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$index',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: tint,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// The signature element: Required → ✓ Done, live.
///
/// It turns "is this order complete?" into a scan down the right edge instead
/// of a read of every section. A pick-many group also carries its live count,
/// because "2/3" answers the question the cashier is actually holding.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.group,
    required this.chosenCount,
    required this.isUnmet,
  });

  final ModifierGroup group;
  final int chosenCount;
  final bool isUnmet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final satisfied =
        modifierGroupViolation(group, chosenCount) == null && chosenCount > 0;

    final (Color tint, IconData icon, String label) = switch (true) {
      _ when isUnmet => (
          cs.error,
          PhosphorIconsFill.warningCircle,
          l10n.chooseAtLeastN(group.minSelections),
        ),
      _ when satisfied => (
          context.successColor,
          PhosphorIconsFill.checkCircle,
          l10n.tagDone,
        ),
      _ when group.isMandatory => (
          context.warningColor,
          PhosphorIconsFill.asterisk,
          l10n.tagRequired,
        ),
      _ => (
          cs.onSurfaceVariant,
          PhosphorIconsRegular.circleDashed,
          l10n.tagOptional,
        ),
    };

    // The live count earns its place only where more than one is possible.
    final counter =
        group.isSingleChoice ? null : '$chosenCount/${group.maxSelections}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 13, color: tint),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              counter == null ? label : '$label · $counter',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: tint,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── One choice ───────────────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.isSingleChoice,
    required this.chosen,
    required this.enabled,
    required this.currencySymbol,
    required this.onTap,
  });

  final ModifierOption option;
  final bool isSingleChoice;
  final bool chosen;
  final bool enabled;
  final String currencySymbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final background =
        chosen ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.45);
    final border = chosen ? cs.primary : cs.outlineVariant;
    final foreground = chosen ? cs.onPrimaryContainer : cs.onSurface;

    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(_kRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            // Short enough to feel instant under a finger, long enough to read
            // as a state change rather than a repaint.
            duration: const Duration(milliseconds: 120),
            constraints: const BoxConstraints(minHeight: _kCardMinHeight),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(color: border, width: chosen ? 2 : 1),
            ),
            child: Row(
              children: [
                // A real icon carrying real state: filled check when chosen,
                // outline plus when not. Reads at a glance, in any language.
                PhosphorIcon(
                  chosen
                      ? PhosphorIconsFill.checkCircle
                      : (isSingleChoice
                          ? PhosphorIconsRegular.circle
                          : PhosphorIconsRegular.plusCircle),
                  size: 24,
                  color: chosen ? cs.primary : cs.outline,
                ),
                const SizedBox(width: 12),
                Flexible(
                  flex: 3,
                  child: Text(
                    option.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: chosen ? FontWeight.w700 : FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
                // A free choice shows NO price. "+0.00" beside "No Sugar" is
                // noise the cashier reads past on every single sale.
                if (option.additionalPrice != 0) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 2,
                    child: Text(
                      '${option.additionalPrice > 0 ? '+' : '−'}'
                      '${option.additionalPrice.abs().toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: option.additionalPrice > 0
                            ? (chosen ? foreground : cs.onSurfaceVariant)
                            : context.successColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── The typed note ───────────────────────────────────────────────────────────

class _NoteSection extends StatelessWidget {
  const _NoteSection({required this.index, required this.controller});

  final int index;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _StepMarker(index: index, isUnmet: false),
            const SizedBox(width: 10),
            PhosphorIcon(PhosphorIconsRegular.notePencil,
                size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(l10n.aNoteForTheKitchen,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: l10n.aNoteHint,
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kRadius),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kRadius),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Footer ───────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({
    required this.total,
    required this.currencySymbol,
    required this.onCancel,
    required this.onConfirm,
    required this.blockedCount,
  });

  final double total;
  final String currencySymbol;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final int blockedCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Row(
        children: [
          TextButton(
            // Backing out adds NOTHING. A cancelled sheet that still added the
            // plain item would be a sale nobody asked for.
            onPressed: onCancel,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            child: Text(l10n.actionCancel),
          ),
          const SizedBox(width: 12),
          // Expanded + end-aligned, NOT Spacer + Flexible: those two both claim
          // free space and left the button floating in the middle of the bar
          // with a gap to its right. This pins it to the trailing edge and lets
          // it size to its own content, which is where the hand goes.
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
              // Stays LIVE while groups are unanswered rather than greying out:
              // pressing it is how the cashier finds out which section is
              // blocking, and a dead button explains nothing.
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kRadius),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    blockedCount > 0
                        ? PhosphorIconsFill.warningCircle
                        : PhosphorIconsFill.shoppingCartSimple,
                    size: 18,
                    color: cs.onPrimary,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      l10n.addToOrder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // The one place the running total appears. Tabular so the
                  // digits do not shuffle as choices are tapped.
                  Text(
                    '$currencySymbol ${total.toStringAsFixed(2)}',
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimary.withValues(alpha: 0.92),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
