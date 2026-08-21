import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/barcode/nomenclature/barcode_matcher.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rule.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rules_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// Editor for the company's barcode nomenclature.
///
/// A reorderable list, because order is the semantics: the first rule whose
/// pattern matches wins, so a catch-all dragged above the weighted rule silently
/// turns every scale label into a single unit at full price. Dragging is the
/// only way to express that, which is why this is not a plain form.
class BarcodeRulesEditor extends ConsumerStatefulWidget {
  const BarcodeRulesEditor({super.key});

  @override
  ConsumerState<BarcodeRulesEditor> createState() => _BarcodeRulesEditorState();
}

class _BarcodeRulesEditorState extends ConsumerState<BarcodeRulesEditor> {
  /// The working copy. Edits stay local until Save, so a half-finished pattern
  /// never reaches the till.
  List<BarcodeRule>? _draft;
  bool _saving = false;

  /// Set once the draft diverges from what was loaded, so Save can be disabled
  /// rather than silently rewriting an untouched nomenclature.
  bool _dirty = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final rulesAsync = ref.watch(barcodeRulesProvider);

    return rulesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('$e', style: TextStyle(color: theme.colorScheme.error)),
      ),
      data: (loaded) {
        final rules = _draft ??= List<BarcodeRule>.from(loaded);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                l10n.barcodeRulesHint('{NNDD}'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            _header(theme, l10n),
            // shrinkWrap because this sits inside the settings tab's own
            // scroll view; the list is a handful of rows, never long enough
            // for the cost to matter.
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: rules.length,
              // onReorderItem, not onReorder: it hands back an index already
              // adjusted for the removal, so no off-by-one correction here.
              onReorderItem: (oldIndex, newIndex) => setState(() {
                final moved = rules.removeAt(oldIndex);
                rules.insert(newIndex, moved);
                _dirty = true;
              }),
              itemBuilder: (context, i) => _RuleRow(
                key: ValueKey('rule_${i}_${rules[i].id}'),
                index: i,
                rule: rules[i],
                onChanged: (updated) => setState(() {
                  rules[i] = updated;
                  _dirty = true;
                }),
                onDelete: () => setState(() {
                  rules.removeAt(i);
                  _dirty = true;
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() {
                      rules.add(BarcodeRule(
                        // Negative so it cannot collide with a server id; the
                        // API assigns real ones on save.
                        id: -(rules.length + 1),
                        name: '',
                        sequence: (rules.length + 1) * 10,
                        type: BarcodeRuleType.unit,
                        encoding: BarcodeEncoding.any,
                        pattern: '',
                      ));
                      _dirty = true;
                    }),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.addRuleLine),
                  ),
                  const Spacer(),
                  if (_dirty)
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _draft = null;
                                _dirty = false;
                              }),
                      child: Text(l10n.actionCancel),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: (!_dirty || _saving) ? null : () => _save(rules),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l10n.actionSave),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            _BarcodeTester(rules: rules),
          ],
        );
      },
    );
  }

  Widget _header(ThemeData theme, AppLocalizations l10n) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 32),
            Expanded(flex: 3, child: Text(l10n.ruleName, style: _headerStyle(theme))),
            Expanded(flex: 3, child: Text(l10n.ruleType, style: _headerStyle(theme))),
            Expanded(flex: 2, child: Text(l10n.ruleEncoding, style: _headerStyle(theme))),
            Expanded(flex: 3, child: Text(l10n.rulePattern, style: _headerStyle(theme))),
            const SizedBox(width: 40),
          ],
        ),
      );

  TextStyle? _headerStyle(ThemeData theme) =>
      theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold);

  /// Mirrors `refreshBarcodeRules`, which takes a provider [Ref] this widget
  /// does not have. Kept deliberately narrow: pull, replace, done.
  Future<void> _pullIntoCache(int companyId) async {
    final fresh = await ApiClient().getBarcodeRules(companyId);
    final db = ref.read(appDatabaseProvider);

    await db.transaction(() async {
      await (db.delete(db.barcodeRulesTable)
            ..where((t) => t.companyId.equals(companyId)))
          .go();

      for (final rule in fresh) {
        await db.into(db.barcodeRulesTable).insert(
              BarcodeRulesTableCompanion(
                id: Value(rule.id),
                companyId: Value(companyId),
                name: Value(rule.name),
                sequence: Value(rule.sequence),
                type: Value(typeToApi(rule.type)),
                encoding: Value(encodingToApi(rule.encoding)),
                pattern: Value(rule.pattern),
                isEnabled: Value(rule.isEnabled),
              ),
            );
      }
    });
  }

  Future<void> _save(List<BarcodeRule> rules) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;

    setState(() => _saving = true);
    try {
      // List position IS the evaluation order — the server renumbers from it,
      // so the sequence values carried here are irrelevant.
      await ApiClient().replaceBarcodeRules(companyId, rules);

      // Repopulates the local cache the POS actually scans against; without it
      // the till keeps decoding with the old rules until the next startup.
      await _pullIntoCache(companyId);
      ref.invalidate(barcodeRulesProvider);

      if (!mounted) return;
      setState(() {
        _draft = null;
        _dirty = false;
      });
      showAppSnackbar(context, ref, AppLocalizations.of(context).barcodeRulesSaved);
    } catch (e) {
      if (!mounted) return;
      // The API returns a 400 whose message names the offending rule, so show
      // the server's text rather than a generic failure.
      final message = e is DioException
          ? (e.response?.data?.toString() ?? e.message ?? '$e')
          : '$e';
      showAppSnackbar(context, ref, message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// One editable rule line.
class _RuleRow extends StatelessWidget {
  final int index;
  final BarcodeRule rule;
  final ValueChanged<BarcodeRule> onChanged;
  final VoidCallback onDelete;

  const _RuleRow({
    super.key,
    required this.index,
    required this.rule,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.drag_indicator,
                  size: 20, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: rule.name,
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) => onChanged(rule.copyWith(name: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<BarcodeRuleType>(
              initialValue: rule.type,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: BarcodeRuleType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(_typeLabel(t, l10n),
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) =>
                  v == null ? null : onChanged(rule.copyWith(type: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<BarcodeEncoding>(
              initialValue: rule.encoding,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: BarcodeEncoding.values
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(encodingLabel(e),
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) =>
                  v == null ? null : onChanged(rule.copyWith(encoding: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: rule.pattern,
              decoration: const InputDecoration(
                  isDense: true, hintText: '22.....{NNDDD}'),
              style: const TextStyle(fontFamily: 'monospace'),
              onChanged: (v) => onChanged(rule.copyWith(pattern: v)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: l10n.actionDelete,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _typeLabel(BarcodeRuleType type, AppLocalizations l10n) =>
      switch (type) {
        BarcodeRuleType.unit => l10n.ruleTypeUnit,
        BarcodeRuleType.weighted => l10n.ruleTypeWeighted,
        BarcodeRuleType.priced => l10n.ruleTypePriced,
        BarcodeRuleType.discounted => l10n.ruleTypeDiscounted,
      };
}

/// Runs a sample barcode through the draft rules.
///
/// Worth its own control because a pattern is easy to get subtly wrong — an
/// off-by-one in the dot count matches nothing, and the only other way to find
/// out is at the till with a customer waiting.
class _BarcodeTester extends ConsumerStatefulWidget {
  final List<BarcodeRule> rules;

  const _BarcodeTester({required this.rules});

  @override
  ConsumerState<_BarcodeTester> createState() => _BarcodeTesterState();
}

class _BarcodeTesterState extends ConsumerState<_BarcodeTester> {
  final _controller = TextEditingController();
  BarcodeMatch? _match;
  bool _ran = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.testBarcode, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              isDense: true,
              hintText: '2210001003504',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () => setState(() {
                  _ran = true;
                  _match = matchBarcode(_controller.text, widget.rules);
                }),
              ),
            ),
            onSubmitted: (v) => setState(() {
              _ran = true;
              _match = matchBarcode(v, widget.rules);
            }),
          ),
          if (_ran) ...[
            const SizedBox(height: 8),
            Text(
              _match == null
                  ? l10n.testBarcodeNoMatch
                  : l10n.testBarcodeMatched(
                      _match!.rule.name.isEmpty
                          ? _match!.rule.pattern
                          : _match!.rule.name,
                      _match!.value == 0 ? '—' : _match!.value.toString(),
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _match == null
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            if (_match != null)
              Text(
                _match!.productKey,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
