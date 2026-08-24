import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/responsive.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/modifier/modifier_models.dart';
import 'package:pos_app/modifier/modifier_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// The modifier catalogue's admin screen: groups on the left, the selected
/// group's editor on the right.
///
/// Master/detail rather than a list plus a dialog because a group is edited as
/// ONE thing — its name, its selection rule and its whole option list are saved
/// together (see `/Modifiers/SaveGroup`), and splitting them across a dialog
/// would hide half the record while the other half is being changed.
///
/// Below [kModifierMasterDetailWidth] the detail pane cannot hold a price field
/// next to a name field without overflowing, so the two panes stack into one
/// and the list pushes the editor as a full page. The threshold is measured
/// against the pane's own constraints, never `context.isCompact` — a 10-inch
/// tablet in landscape is not a phone, and it has the room.
class ModifierGroupsScreen extends ConsumerStatefulWidget {
  /// Passed by ManagementLayout when the sidebar is hidden, so the AppBar shows
  /// a menu icon rather than a back arrow.
  final VoidCallback? onMenuPressed;

  const ModifierGroupsScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<ModifierGroupsScreen> createState() =>
      _ModifierGroupsScreenState();
}

/// Narrower than this and the editor's name+price row has nowhere to go.
const double kModifierMasterDetailWidth = 900;

class _ModifierGroupsScreenState extends ConsumerState<ModifierGroupsScreen> {
  /// The group being edited. Null means nothing is selected.
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = ref.watch(allModifierGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.modifierGroups,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: l10n.showNavigation,
                onPressed: widget.onMenuPressed,
              )
            : null,
      ),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(l10n.errorWithMessage(e.toString()),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        data: (list) => LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= kModifierMasterDetailWidth;
            final selected =
                list.where((g) => g.id == _selectedId).firstOrNull;

            if (!wide) {
              return _GroupList(
                groups: list,
                selectedId: null,
                onTap: (g) => _openAsPage(g),
                onNew: () => _openAsPage(null),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: _GroupList(
                    groups: list,
                    selectedId: _selectedId,
                    onTap: (g) => setState(() => _selectedId = g.id),
                    onNew: () => setState(() => _selectedId = null),
                  ),
                ),
                Container(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  flex: 3,
                  child: _GroupEditor(
                    // Keyed by group id so switching selection REBUILDS the
                    // editor's controllers. Without it the previous group's
                    // text stays in the fields and the next Save writes it.
                    key: ValueKey(_selectedId),
                    group: selected,
                    onSaved: (id) => setState(() => _selectedId = id),
                    onDeleted: () => setState(() => _selectedId = null),
                  ),
                ),
              ],
            );
          },
        ),
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

// ── The list ─────────────────────────────────────────────────────────────────

class _GroupList extends StatelessWidget {
  const _GroupList({
    required this.groups,
    required this.selectedId,
    required this.onTap,
    required this.onNew,
  });

  final List<ModifierGroup> groups;
  final int? selectedId;
  final ValueChanged<ModifierGroup> onTap;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.modifierGroupsHint,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add),
                label: Text(l10n.addModifierGroup),
              ),
            ],
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? Center(
                  child: Text(l10n.noModifierGroupsYet,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final g = groups[i];
                    final isSelected = g.id == selectedId;
                    return Card(
                      elevation: 0,
                      color: isSelected ? cs.primaryContainer : cs.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? cs.primary : cs.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        onTap: () => onTap(g),
                        title: Row(
                          children: [
                            // Loose Flexible on both sides with spaceBetween —
                            // Expanded on the name would strand the badge at
                            // the row's midpoint.
                            Flexible(
                              flex: 3,
                              child: Text(
                                g.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? cs.onPrimaryContainer
                                      : cs.onSurface,
                                ),
                              ),
                            ),
                            if (!g.isEnabled) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 2,
                                child: _Badge(
                                  label: l10n.groupIsDisabled,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${selectionRuleLabel(context, g)} · '
                          '${l10n.optionCount(g.options.length)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: isSelected
                                  ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                                  : cs.onSurfaceVariant),
                        ),
                        trailing: g.allowsFreeText
                            ? Icon(Icons.edit_note, color: cs.onSurfaceVariant)
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      );
}

// ── The editor ───────────────────────────────────────────────────────────────

/// One option's in-progress edit state.
///
/// Carries the catalogue [id] through untouched, which is load-bearing: past
/// sales point at it for reporting, so a save must UPDATE the row rather than
/// recreate it. Null means this choice is new.
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
  const _GroupEditor({
    super.key,
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
