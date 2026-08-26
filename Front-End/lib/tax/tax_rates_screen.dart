import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/core/ilyass_list_scaffold.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

// --- SCREEN ---
class TaxRatesScreen extends ConsumerStatefulWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const TaxRatesScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<TaxRatesScreen> createState() => _TaxRatesScreenState();
}

class _TaxRatesScreenState extends ConsumerState<TaxRatesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// Ticked rows, by tax id.
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

  List<Tax> _visible(List<Tax> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            (t.code?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  Future<void> _openEditor(int companyId, [Tax? tax]) async {
    await showDialog(
      context: context,
      builder: (_) => _TaxFormDialog(companyId: companyId, tax: tax),
    );
    ref.invalidate(allTaxesProvider);
  }

  Future<void> _bulkDelete(int companyId) async {
    if (_selectedIds.isEmpty) return;
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final all = ref.read(allTaxesProvider).value ?? const <Tax>[];
    final targets = all.where((t) => _selectedIds.contains(t.id)).toList();
    if (targets.isEmpty) return;

    // ONE confirmation for the batch — looping the per-row dialog would put
    // nine prompts in front of someone deleting nine rows.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Text(l.deleteTax),
          ],
        ),
        content: Text(targets.length == 1
            ? l.deleteTaxRateConfirm(targets.first.name)
            : l.deleteProductsConfirm(targets.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.actionCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    for (final tax in targets) {
      if (!mounted) return;
      await _delete(context, ref, tax.id, companyId);
    }
    if (mounted) setState(_selectedIds.clear);
  }

  List<IlyassMenuAction> _menuActions(
    BuildContext context,
    int? companyId,
    List<Tax>? taxes,
  ) {
    final l = AppLocalizations.of(context);
    final hasSelection = _selectedIds.isNotEmpty;

    return [
      IlyassMenuAction(
        icon: Icons.delete_outline_rounded,
        label: hasSelection
            ? l.deleteWithCount(_selectedIds.length)
            : l.actionDelete,
        color: hasSelection ? context.dangerColor : null,
        enabled: hasSelection && companyId != null,
        onSelected: () {
          if (companyId != null) _bulkDelete(companyId);
        },
      ),
      IlyassMenuAction(
        icon: Icons.swap_horiz,
        label: l.switchTaxes,
        dividerBefore: true,
        enabled: companyId != null && taxes != null,
        onSelected: () async {
          if (companyId == null || taxes == null) return;
          await showDialog(
            context: context,
            builder: (_) =>
                _SwitchTaxesDialog(taxes: taxes, companyId: companyId),
          );
          ref.invalidate(allTaxesProvider);
        },
      ),
      IlyassMenuAction(
        icon: Icons.refresh,
        label: l.refresh,
        onSelected: () => ref.invalidate(allTaxesProvider),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final asyncTaxes = ref.watch(allTaxesProvider);
    final company = ref.watch(selectedCompanyProvider);

    return IlyassListScaffold(
      title: l.taxRates,
      onMenuPressed: widget.onMenuPressed,
      searchBar: UnifiedSearchBar(
        controller: _searchCtrl,
        singleLine: true,
        hintText: l.actionSearch,
        chips: const [],
        sectionsBuilder: (_) => const [],
        onQueryChanged: _setQuery,
        onClearAll: () {
          _searchCtrl.clear();
          _setQuery('');
        },
      ),
      actions: _menuActions(context, company?.id, asyncTaxes.value),
      fabLabel: l.newTaxRate,
      onFabPressed: company == null ? null : () => _openEditor(company.id),
      body: asyncTaxes.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
        error: (e, _) => Center(
          child: Text(
            l.errorLoadingTaxesMsg(e.toString()),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
        data: (all) {
          if (company == null) {
            return Center(
              child: Text(
                l.noCompanySelectedShort,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            );
          }
          final companyId = company.id;
          final taxes = _visible(all);
          final selected =
              _selectedIds.intersection(taxes.map((t) => t.id).toSet());

          return IlyassTable<Tax>(
            tableId: 'taxRates',
            rows: taxes,
            rowHeight: 64,
            onRowTap: (t) => _openEditor(companyId, t),
            isRowSelected: (t) => selected.contains(t.id),
            // A switched-off rate reads as switched off at a glance.
            rowColor: (t) => t.isEnabled
                ? null
                : theme.disabledColor.withValues(alpha: 0.05),
            columns: [
              ilyassSelectionColumn<Tax, int>(
                rows: taxes,
                selected: selected,
                idOf: (t) => t.id,
                onChanged: (ids) => setState(() {
                  _selectedIds
                    ..clear()
                    ..addAll(ids);
                }),
              ),
              IlyassColumn<Tax>(
                key: 'name',
                label: l.fieldName,
                width: 240,
                flexible: true,
                cell: (context, t) => Text(
                  t.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IlyassColumn<Tax>(
                key: 'rate',
                label: l.rateLabel,
                width: 120,
                numeric: true,
                cell: (context, t) => Text(
                  '${t.rate.toStringAsFixed(t.rate % 1 == 0 ? 0 : 2)}'
                  '${t.isFixed ? '' : '%'}',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IlyassColumn<Tax>(
                key: 'code',
                label: l.fieldCode,
                width: 140,
                cell: (context, t) => Text(t.code ?? '-',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              IlyassColumn<Tax>(
                key: 'fixed',
                label: l.fixed,
                width: 110,
                cell: (context, t) => _BoolIcon(value: t.isFixed, theme: theme),
              ),
              IlyassColumn<Tax>(
                key: 'taxOnTotal',
                label: l.taxOnTotal,
                width: 130,
                cell: (context, t) =>
                    _BoolIcon(value: t.isTaxOnTotal, theme: theme),
              ),
              IlyassColumn<Tax>(
                key: 'enabled',
                label: l.fieldEnabled,
                width: 110,
                cell: (context, t) =>
                    _BoolIcon(value: t.isEnabled, theme: theme),
              ),
            ],
            emptyState: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.percent,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      all.isEmpty ? l.noTaxRatesFound : l.noResultsForFilters,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 18,
                      ),
                    ),
                    if (all.isEmpty) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(l.addFirstTaxRate),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        onPressed: () => _openEditor(companyId),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    int id,
    int companyId,
  ) async {
    try {
      // Offline-first: tombstone locally (the list drops it instantly via the
      // Drift stream); SyncManager issues /Taxes/DeleteTax on the next push.
      await ref.read(appDatabaseProvider).deleteTaxLocal(id);
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      if (!context.mounted) return;
      showAppSnackbar(context, ref, AppLocalizations.of(context).taxRateDeleted);
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackbar(context, ref, AppLocalizations.of(context).deleteFailed,
          isError: true);
    }
  }
}

// --- BOOL ICON ---
class _BoolIcon extends StatelessWidget {
  final bool value;
  final ThemeData theme;
  const _BoolIcon({required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (!value) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.check, color: theme.colorScheme.primary, size: 14),
    );
  }
}

// --- ADD / EDIT TAX DIALOG ---
class _TaxFormDialog extends ConsumerStatefulWidget {
  final int companyId;
  final Tax? tax;

  const _TaxFormDialog({required this.companyId, this.tax});

  @override
  ConsumerState<_TaxFormDialog> createState() => _TaxFormDialogState();
}

class _TaxFormDialogState extends ConsumerState<_TaxFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _codeCtrl;
  late bool _isFixed;
  late bool _isTaxOnTotal;
  late bool _isEnabled;

  bool get _isEditing => widget.tax != null;

  @override
  void initState() {
    super.initState();
    final t = widget.tax;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _rateCtrl = TextEditingController(
      text: t != null
          ? t.rate % 1 == 0
                ? t.rate.toInt().toString()
                : t.rate.toString()
          : '',
    );
    _codeCtrl = TextEditingController(text: t?.code ?? '');
    _isFixed = t?.isFixed ?? false;
    _isTaxOnTotal = t?.isTaxOnTotal ?? true;
    _isEnabled = t?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rateCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Required + unique-per-company, case-insensitive.
  ///
  /// Compared against the local Drift cache (the same rows the list shows), so
  /// it works offline — which matters, because the failure it prevents was
  /// only ever raised by the server, asynchronously, after the dialog was gone.
  String? _validateCode(String? v) {
    final code = (v ?? '').trim();
    if (code.isEmpty) return AppLocalizations.of(context).requiredField;

    final taxes = ref.read(allTaxesProvider).value ?? const [];
    final clash = taxes.any(
      (t) =>
          t.id != widget.tax?.id &&
          (t.code ?? '').trim().toLowerCase() == code.toLowerCase(),
    );
    return clash ? AppLocalizations.of(context).taxCodeAlreadyUsed : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Offline-first: write to the local DB first so the list updates instantly
      // via the Drift stream; SyncManager pushes /Taxes/AddTax|UpdateTax later.
      await ref.read(appDatabaseProvider).saveTaxLocal(
            id: _isEditing ? widget.tax!.id : null,
            companyId: widget.companyId,
            name: _nameCtrl.text.trim(),
            rate: double.tryParse(_rateCtrl.text.trim()) ?? 0,
            code: _codeCtrl.text.trim(),
            isFixed: _isFixed,
            isTaxOnTotal: _isTaxOnTotal,
            isEnabled: _isEnabled,
          );
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).operationFailed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      // Scroll + tighter insets so the form fits (and scrolls if needed) on a
      // short 7" screen instead of overflowing the bottom.
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _isEditing
            ? AppLocalizations.of(context).editTaxRate
            : AppLocalizations.of(context).newTaxRate,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).nameRequired,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? AppLocalizations.of(context).requiredField
                              : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _codeCtrl,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).codeRequired,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      // Required AND unique, enforced here rather than left to
                      // the server. `UQ_Tax_Code_PerCompany` is a unique index
                      // on (CompanyId, Code) and SQL Server counts an EMPTY
                      // string as a value, so a blank code is only free once
                      // per company — the second one used to blow up as a 500
                      // deep inside a background sync, long after the dialog
                      // had closed. Catching it on the field means the bad
                      // value never reaches Drift, let alone the push queue.
                      validator: _validateCode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rateCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).rateRequired,
                  hintText: AppLocalizations.of(context).hintTwentyPercent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return AppLocalizations.of(context).requiredField;
                  }
                  if (double.tryParse(v.trim()) == null) {
                    return AppLocalizations.of(context).enterValidNumber;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _switchRow(
                AppLocalizations.of(context).fixedAmount,
                _isFixed,
                (v) => setState(() => _isFixed = v),
                theme,
              ),
              _switchRow(
                AppLocalizations.of(context).taxOnTotal,
                _isTaxOnTotal,
                (v) => setState(() => _isTaxOnTotal = v),
                theme,
              ),
              _switchRow(
                AppLocalizations.of(context).fieldEnabled,
                _isEnabled,
                (v) => setState(() => _isEnabled = v),
                theme,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: Text(_isEditing
                ? AppLocalizations.of(context).actionUpdate
                : AppLocalizations.of(context).actionSave),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: _submit,
          ),
      ],
    );
  }

  Widget _switchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

// --- SWITCH TAXES DIALOG ---
class _SwitchTaxesDialog extends ConsumerStatefulWidget {
  final List<Tax> taxes;
  final int companyId;

  const _SwitchTaxesDialog({required this.taxes, required this.companyId});

  @override
  ConsumerState<_SwitchTaxesDialog> createState() => _SwitchTaxesDialogState();
}

class _SwitchTaxesDialogState extends ConsumerState<_SwitchTaxesDialog> {
  int? _oldTaxId;
  int? _newTaxId;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _replace() async {
    if (_oldTaxId == null || _newTaxId == null) {
      setState(() =>
          _errorMessage = AppLocalizations.of(context).pleaseSelectBothTaxes);
      return;
    }
    if (_oldTaxId == _newTaxId) {
      setState(() =>
          _errorMessage = AppLocalizations.of(context).oldAndNewTaxMustDiffer);
      return;
    }

    // Get the old tax object to extract its rate
    final oldTax = widget.taxes.firstWhere((t) => t.id == _oldTaxId);
    // Get the new tax object to keep all its other fields intact
    final newTax = widget.taxes.firstWhere((t) => t.id == _newTaxId);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Offline-first: apply the old tax's rate to the new tax locally; keep all
      // the new tax's other fields. SyncManager pushes /Taxes/UpdateTax later.
      await ref.read(appDatabaseProvider).saveTaxLocal(
            id: newTax.id,
            companyId: widget.companyId,
            name: newTax.name,
            rate: oldTax.rate, // <-- old tax rate applied to new tax
            code: newTax.code,
            isFixed: newTax.isFixed,
            isTaxOnTotal: newTax.isTaxOnTotal,
            isEnabled: newTax.isEnabled,
          );
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      if (!mounted) return;
      setState(
        () => _successMessage =
            AppLocalizations.of(context).taxRateAppliedSuccessfully(
          '${oldTax.rate}${oldTax.isFixed ? '' : '%'}',
          oldTax.name,
          newTax.name,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).switchFailed;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        AppLocalizations.of(context).switchTaxes,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).replaceTaxesHint,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Old Tax Dropdown
            DropdownButtonFormField<int>(
              initialValue: _oldTaxId,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).oldTax,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: widget.taxes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(
                        "${t.name} (${t.rate.toStringAsFixed(t.rate % 1 == 0 ? 0 : 2)}${t.isFixed ? '' : '%'})",
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _oldTaxId = v),
            ),
            const SizedBox(height: 16),

            // New Tax Dropdown
            DropdownButtonFormField<int>(
              initialValue: _newTaxId,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).newTax,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: widget.taxes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(
                        "${t.name} (${t.rate.toStringAsFixed(t.rate % 1 == 0 ? 0 : 2)}${t.isFixed ? '' : '%'})",
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _newTaxId = v),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.successColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: context.successColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(
                          color: context.successColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).actionClose),
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: Text(AppLocalizations.of(context).replace),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: _replace,
          ),
      ],
    );
  }
}
