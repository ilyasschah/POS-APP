import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/ilyass_list_scaffold.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/responsive.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pos_app/modifier/modifier_icons.dart';
import 'package:pos_app/modifier/modifier_models.dart';
import 'package:pos_app/modifier/modifier_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// The modifier catalogue's admin screen: a table of groups, each opening its
/// own editor page.
///
/// 🚨 The editor is a full PAGE, not a dialog, and that has not changed. A
/// group is saved as ONE thing — its name, its selection rule and its whole
/// option list go to `/Modifiers/SaveGroup` together — so a dialog would hide
/// half the record while the other half is being changed. What went away is the
/// permanent side-by-side split, which cost 60% of the width to show one group
/// whether or not anyone was editing it.
class ModifierGroupsScreen extends ConsumerStatefulWidget {
  /// Passed by ManagementLayout when the sidebar is hidden, so the AppBar shows
  /// a menu icon rather than a back arrow.
  final VoidCallback? onMenuPressed;

  const ModifierGroupsScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<ModifierGroupsScreen> createState() =>
      _ModifierGroupsScreenState();
}

class _ModifierGroupsScreenState extends ConsumerState<ModifierGroupsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// Ticked rows, by group id.
  final Set<int> _selectedIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    setState(() {
      _query = value;
      // Selection is by id and survives filtering, so a row the search hid must
      // drop out of it.
      _selectedIds.clear();
    });
  }

  /// Matches the group name AND its option names — an operator hunting for
  /// "Extra cheese" should not have to remember it lives under "Toppings".
  List<ModifierGroup> _visible(List<ModifierGroup> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((g) =>
            g.name.toLowerCase().contains(q) ||
            g.options.any((o) => o.name.toLowerCase().contains(q)))
        .toList();
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final all =
        ref.read(allModifierGroupsProvider).value ?? const <ModifierGroup>[];
    final targets = all.where((g) => _selectedIds.contains(g.id)).toList();
    if (targets.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteGroup),
        content: Text(targets.length == 1
            ? l10n.deleteQuotedConfirm(targets.first.name)
            : l10n.deleteProductsConfirm(targets.length)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.actionCancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;
    try {
      for (final group in targets) {
        await ref.read(appDatabaseProvider).deleteModifierGroupLocal(group.id);
      }
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      if (mounted) setState(_selectedIds.clear);
    } catch (_) {
      if (mounted) {
        showAppSnackbar(context, ref, AppLocalizations.of(context).deleteFailed,
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final groups = ref.watch(allModifierGroupsProvider);
    final hasSelection = _selectedIds.isNotEmpty;

    return IlyassListScaffold(
      title: l10n.modifierGroups,
      onMenuPressed: widget.onMenuPressed,
      searchBar: UnifiedSearchBar(
        controller: _searchCtrl,
        singleLine: true,
        hintText: l10n.actionSearch,
        chips: const [],
        sectionsBuilder: (_) => const [],
        onQueryChanged: _setQuery,
        onClearAll: () {
          _searchCtrl.clear();
          _setQuery('');
        },
      ),
      actions: [
        IlyassMenuAction(
          icon: Icons.delete_outline_rounded,
          label: hasSelection
              ? l10n.deleteWithCount(_selectedIds.length)
              : l10n.actionDelete,
          color: hasSelection ? cs.error : null,
          enabled: hasSelection,
          onSelected: _bulkDelete,
        ),
      ],
      fabLabel: l10n.addModifierGroup,
      onFabPressed: () => _openAsPage(null),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(l10n.errorWithMessage(e.toString()),
              style: TextStyle(color: cs.error)),
        ),
        data: (all) {
          final list = _visible(all);
          final selected =
              _selectedIds.intersection(list.map((g) => g.id).toSet());

          return IlyassTable<ModifierGroup>(
            tableId: 'modifierGroups',
            rows: list,
            rowHeight: 64,
            onRowTap: _openAsPage,
            isRowSelected: (g) => selected.contains(g.id),
            // A disabled group reads as disabled at a glance.
            rowColor: (g) => g.isEnabled
                ? null
                : theme.disabledColor.withValues(alpha: 0.05),
            columns: [
              ilyassSelectionColumn<ModifierGroup, int>(
                rows: list,
                selected: selected,
                idOf: (g) => g.id,
                onChanged: (ids) => setState(() {
                  _selectedIds
                    ..clear()
                    ..addAll(ids);
                }),
              ),
              IlyassColumn<ModifierGroup>(
                key: 'name',
                label: l10n.fieldName,
                width: 240,
                flexible: true,
                cell: (context, g) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(modifierIconFor(g.iconKey).regular, size: 18),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              IlyassColumn<ModifierGroup>(
                key: 'rule',
                label: l10n.colSelectionRule,
                width: 200,
                cell: (context, g) => Text(
                  selectionRuleLabel(context, g),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
              IlyassColumn<ModifierGroup>(
                key: 'options',
                label: l10n.options,
                width: 130,
                numeric: true,
                cell: (context, g) => Text('${g.options.length}'),
              ),
              IlyassColumn<ModifierGroup>(
                key: 'freeText',
                label: l10n.allowFreeText,
                width: 140,
                cell: (context, g) => Icon(
                  g.allowsFreeText
                      ? Icons.check_circle
                      : Icons.remove_circle_outline,
                  size: 18,
                  color: g.allowsFreeText
                      ? cs.primary
                      : theme.disabledColor,
                ),
              ),
              IlyassColumn<ModifierGroup>(
                key: 'enabled',
                label: l10n.fieldEnabled,
                width: 120,
                cell: (context, g) => Icon(
                  g.isEnabled ? Icons.check_circle : Icons.remove_circle_outline,
                  size: 18,
                  color: g.isEnabled ? cs.primary : theme.disabledColor,
                ),
              ),
            ],
            emptyState: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.tune,
                        size: 64,
                        color: theme.disabledColor.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      all.isEmpty
                          ? l10n.noModifierGroupsYet
                          : l10n.noResultsForFilters,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.hintColor, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openAsPage(ModifierGroup? group) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(group == null
                ? AppLocalizations.of(context).addModifierGroup
                : group.name),
          ),
          body: _GroupEditor(
            group: group,
            onSaved: (_) => Navigator.of(context).maybePop(),
            onDeleted: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }
}

/// Plain-language rendering of a group's min/max pair.
///
/// The raw numbers are meaningless to whoever configures this ("min 1 max 1"),
/// while "Required · pick one" is the sentence they were thinking in.
String selectionRuleLabel(BuildContext context, ModifierGroup g) {
  final l10n = AppLocalizations.of(context);
  if (g.minSelections <= 0) {
    return g.maxSelections <= 1
        ? l10n.selectionRuleOptionalOne
        : l10n.selectionRuleOptionalMany(g.maxSelections);
  }
  return (g.minSelections == 1 && g.maxSelections == 1)
      ? l10n.selectionRuleExactlyOne
      : l10n.selectionRuleRange(g.minSelections, g.maxSelections);
}

class _DraftOption {
  _DraftOption({this.id, String name = '', double price = 0})
      : nameCtrl = TextEditingController(text: name),
        priceCtrl = TextEditingController(
            text: price == 0 ? '' : price.toStringAsFixed(2)),
        isEnabled = true;

  final int? id;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  bool isEnabled;

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
  }

  double get price =>
      double.tryParse(priceCtrl.text.trim().replaceAll(',', '.')) ?? 0;
}

class _GroupEditor extends ConsumerStatefulWidget {
  // No `key`: the editor used to be a persistent side pane that had to be
  // rebuilt when the selection changed, or the previous group's text stayed in
  // the fields. Each editor is its own route now, so it is fresh by
  // construction.
  const _GroupEditor({
    required this.group,
    required this.onSaved,
    required this.onDeleted,
  });

  /// Null creates a new group.
  final ModifierGroup? group;
  final ValueChanged<int> onSaved;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends ConsumerState<_GroupEditor> {
  late final TextEditingController _nameCtrl;
  late List<_DraftOption> _options;
  late int _min;
  late int _max;
  late bool _allowsFreeText;
  late bool _isEnabled;
  late String? _iconKey;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _nameCtrl = TextEditingController(text: g?.name ?? '');
    _min = g?.minSelections ?? 0;
    _max = g?.maxSelections ?? 1;
    _allowsFreeText = g?.allowsFreeText ?? false;
    _isEnabled = g?.isEnabled ?? true;
    // A key from a build that knew more icons than this one falls back to "no
    // icon" in the picker rather than showing nothing as selected.
    _iconKey = isKnownModifierIcon(g?.iconKey) ? g!.iconKey : null;
    _options = [
      for (final o in g?.options ?? const <ModifierOption>[])
        _DraftOption(id: o.id, name: o.name, price: o.additionalPrice)
          ..isEnabled = o.isEnabled,
    ];
    if (_options.isEmpty) _options.add(_DraftOption());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  List<_DraftOption> get _named =>
      _options.where((o) => o.nameCtrl.text.trim().isNotEmpty).toList();

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim();
    final named = _named;

    // Same three rules the server enforces, checked here so the operator is
    // told before a round trip — and so an offline save cannot queue a group
    // the server will later reject.
    if (name.isEmpty) {
      setState(() => _error = l10n.aGroupNeedsAName);
      return;
    }
    if (_min > 0 && named.isEmpty) {
      setState(() => _error = l10n.mandatoryNeedsOptions);
      return;
    }
    if (_min > named.length && named.isNotEmpty) {
      setState(() =>
          _error = l10n.minCannotExceedChoices(_min, named.length));
      return;
    }

    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final id = await ref.read(appDatabaseProvider).saveModifierGroupLocal(
            companyId: companyId,
            groupId: widget.group?.id,
            name: name,
            minSelections: _min,
            // Clamped the same way the domain does: a Max below Min leaves a
            // group nothing can satisfy, and the failure would surface at the
            // till as a product that cannot be added.
            maxSelections: _max < _min ? _min : _max,
            allowsFreeText: _allowsFreeText,
            iconKey: _iconKey,
            rank: widget.group?.rank ?? 0,
            isEnabled: _isEnabled,
            options: [
              for (final o in named)
                (
                  id: o.id,
                  name: o.nameCtrl.text.trim(),
                  additionalPrice: o.price,
                  isEnabled: o.isEnabled,
                ),
            ],
          );

      // Fire-and-forget: the local write already landed, so the screen is
      // correct whether or not the server is reachable.
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});

      if (!mounted) return;
      showAppSnackbar(context, ref, l10n.modifierGroupSaved);
      widget.onSaved(id);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final g = widget.group;
    if (g == null) return;
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteModifierGroupQ(g.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteModifierGroupBody),
            const SizedBox(height: 12),
            // Said at the moment of deleting, not buried in a help page: a
            // delete only reaches other tills on a FULL sync, and the operator
            // has no way to know that otherwise.
            Text(l10n.disableRatherThanDelete,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(appDatabaseProvider).deleteModifierGroupLocal(g.id);
    ref.read(syncStateProvider.notifier).sync().catchError((_) {});
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sym = ref.watch(currencySymbolProvider);
    final isEditing = widget.group != null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxReadableWidth),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              isEditing ? l10n.editModifierGroup : l10n.addModifierGroup,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.nameRequired,
                hintText: l10n.modifierGroupNameHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 20),

            // ── Icon ──────────────────────────────────────────────────────
            _IconPicker(
              selected: _iconKey,
              onChanged: (key) => setState(() => _iconKey = key),
            ),
            const SizedBox(height: 20),

            // ── Selection rule ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: l10n.minSelections,
                    value: _min,
                    min: 0,
                    onChanged: (v) => setState(() {
                      _min = v;
                      if (_max < _min) _max = _min;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumberField(
                    label: l10n.maxSelections,
                    value: _max,
                    min: 1,
                    onChanged: (v) => setState(() {
                      _max = v;
                      if (_min > _max) _min = _max;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              selectionRuleLabel(
                context,
                ModifierGroup(
                  id: 0,
                  name: '',
                  minSelections: _min,
                  maxSelections: _max,
                ),
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: cs.primary),
            ),

            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _allowsFreeText,
              onChanged: (v) => setState(() => _allowsFreeText = v),
              title: Text(l10n.allowFreeText),
              subtitle: Text(l10n.allowFreeTextHint,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isEnabled,
              onChanged: (v) => setState(() => _isEnabled = v),
              title: Text(l10n.groupEnabled),
            ),

            const Divider(height: 32),

            // ── Options ───────────────────────────────────────────────────
            Text(l10n.modifierOptionsTitle,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (var i = 0; i < _options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _options[i].nameCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: l10n.optionNameHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _options[i].priceCtrl,
                        // A negative surcharge is legitimate — a "small size"
                        // reduction — so the minus sign is allowed through.
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^-?[0-9]*[.,]?[0-9]*')),
                        ],
                        textAlign: TextAlign.end,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '0.00',
                          suffixText: sym,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: cs.error),
                      tooltip: l10n.actionDelete,
                      onPressed: () => setState(() {
                        _options.removeAt(i).dispose();
                        if (_options.isEmpty) _options.add(_DraftOption());
                      }),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _options.add(_DraftOption())),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addModifierOption),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
            ],

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(isEditing ? Icons.save : Icons.add),
              label: Text(
                  isEditing ? l10n.actionSaveChanges : l10n.addModifierGroup),
            ),
            if (isEditing) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _delete,
                icon: Icon(Icons.delete_outline, color: cs.error),
                label: Text(l10n.actionDelete,
                    style: TextStyle(color: cs.error)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small stepper for a count that has a floor.
///
/// Typed entry as well as the arrows: setting "pick up to 6" by tapping + six
/// times is the kind of thing that makes an admin screen hated.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Flexible(
            child: Text('$value',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

/// Picks the icon a group carries at the till.
///
/// A short, fixed row rather than a searchable grid: this is one field on a
/// form somebody is filling in to get a menu working, not a browsing task. The
/// eight are generic on purpose — a sauce drop covers ketchup, harissa and mayo
/// — so nobody has to hunt for their exact product and give up.
///
/// "None" is the FIRST option, not a missing state hidden at the end. It is a
/// legitimate choice, it is the default, and the till has a neutral icon ready
/// for it.
class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    String labelFor(String key) => switch (key) {
          'burger' => l10n.iconBurger,
          'pizza' => l10n.iconPizza,
          'meal' => l10n.iconMeal,
          'side' => l10n.iconSide,
          'sauce' => l10n.iconSauce,
          'drink' => l10n.iconDrink,
          'dessert' => l10n.iconDessert,
          'spice' => l10n.iconSpice,
          _ => l10n.iconNone,
        };

    Widget tile({
      required String? key,
      required IconData icon,
      required String label,
    }) {
      final isSelected = key == selected;
      return Tooltip(
        message: label,
        child: Semantics(
          label: label,
          selected: isSelected,
          button: true,
          child: Material(
            color: isSelected
                ? cs.primaryContainer
                : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onChanged(key),
              child: Container(
                // Finger-sized, like everything else an operator taps.
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? cs.primary : cs.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: PhosphorIcon(
                  icon,
                  size: 24,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.groupIcon,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(l10n.groupIconHint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            tile(
              key: null,
              icon: kModifierIconFallback.regular,
              label: l10n.iconNone,
            ),
            for (final i in kModifierIcons)
              tile(key: i.key, icon: i.regular, label: labelFor(i.key)),
          ],
        ),
      ],
    );
  }
}
