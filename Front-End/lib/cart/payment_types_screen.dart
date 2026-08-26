import 'package:flutter/material.dart';
import 'package:pos_app/core/ilyass_column_order.dart';
import 'package:pos_app/core/ilyass_list_scaffold.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/cart/payment_type_model.dart';
import 'package:pos_app/cart/payment_type_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/sync/sync_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// Display label for a `paymentTypeVisibleColumnsProvider` key.
///
/// 🚨 The keys (`'Quick Pay'`, `'Customer Req.'`, …) are the map's **identity** —
/// they gate every column and are what the picker writes back. Translating the
/// map itself would break the grid the moment the language changed. Only the
/// label is localized, exactly like `documents_screen._columnLabel` and
/// `sales_history_screen._masterColumnIds` / `_masterColumns`.
String _paymentColumnLabel(BuildContext context, String id) {
  final l10n = AppLocalizations.of(context);
  switch (id) {
    case 'Name':
      return l10n.fieldName;
    case 'Code':
      return l10n.fieldCode;
    case 'Position':
      return l10n.fieldPosition;
    case 'Enabled':
      return l10n.fieldEnabled;
    case 'Quick Pay':
      return l10n.colQuickPay;
    case 'Customer Req.':
      return l10n.colCustomerRequired;
    case 'Change':
      return l10n.change;
    case 'Mark Paid':
      return l10n.colMarkPaid;
    case 'Cash Drawer':
      return l10n.setCashDrawer;
    case 'Fiscal':
      return l10n.fiscal;
    case 'Slip':
      return l10n.colSlip;
    case 'Shortcut':
      return l10n.fieldShortcut;
    case 'Actions':
      return l10n.actions;
    default:
      return id;
  }
}

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────

class PaymentTypesScreen extends ConsumerStatefulWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const PaymentTypesScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<PaymentTypesScreen> createState() =>
      _PaymentTypesScreenState();
}

class _PaymentTypesScreenState extends ConsumerState<PaymentTypesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// Ticked rows, by payment-type id.
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

  List<PaymentType> _visible(List<PaymentType> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            (t.code?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  Future<void> _openEditor(int companyId, [PaymentType? paymentType]) async {
    await showDialog(
      context: context,
      builder: (_) => _PaymentTypeFormDialog(
        companyId: companyId,
        paymentType: paymentType,
      ),
    );
    ref.invalidate(allPaymentTypesProvider);
    await ref.read(syncManagerProvider).pullPaymentTypes(companyId);
  }

  void _showColumnPicker(BuildContext context) {
    final catalogue =
        ref.read(paymentTypeVisibleColumnsProvider).keys.toList();

    showIlyassColumnPicker(
      context: context,
      tableId: 'paymentTypes',
      columns: [
        for (final key in catalogue)
          IlyassPickerColumn(key: key, label: _paymentColumnLabel(context, key)),
      ],
      isVisible: (key) =>
          ref.read(paymentTypeVisibleColumnsProvider)[key] ?? false,
      onVisibleChanged: (key, value) {
        final updated =
            Map<String, bool>.from(ref.read(paymentTypeVisibleColumnsProvider));
        updated[key] = value;
        ref.read(paymentTypeVisibleColumnsProvider.notifier).state = updated;
      },
    );
  }

  Future<void> _bulkDelete(int companyId) async {
    if (_selectedIds.isEmpty) return;
    final l = AppLocalizations.of(context);
    final all =
        ref.read(allPaymentTypesProvider).value ?? const <PaymentType>[];
    final targets = all.where((t) => _selectedIds.contains(t.id)).toList();
    if (targets.isEmpty) return;

    // ONE confirmation for the batch — looping the per-row dialog would put
    // nine prompts in front of someone deleting nine rows.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(targets.length == 1
            ? l.deletePaymentTypeConfirm(targets.first.name)
            : l.deleteProductsConfirm(targets.length)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.actionCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.dangerColor,
              foregroundColor: ctx.onStatusColor,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    for (final type in targets) {
      if (!mounted) return;
      await _delete(context, ref, type.id, companyId);
    }
    if (mounted) setState(_selectedIds.clear);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final asyncTypes = ref.watch(allPaymentTypesProvider);
    final company = ref.watch(selectedCompanyProvider);
    final visibleColumns = ref.watch(paymentTypeVisibleColumnsProvider);
    final hasSelection = _selectedIds.isNotEmpty;

    return IlyassListScaffold(
      title: l.paymentTypes,
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
      actions: [
        IlyassMenuAction(
          icon: Icons.delete_outline_rounded,
          label: hasSelection
              ? l.deleteWithCount(_selectedIds.length)
              : l.actionDelete,
          color: hasSelection ? context.dangerColor : null,
          enabled: hasSelection && company != null,
          onSelected: () {
            if (company != null) _bulkDelete(company.id);
          },
        ),
        IlyassMenuAction(
          icon: Icons.view_column_rounded,
          label: l.columnsTooltip,
          dividerBefore: true,
          onSelected: () => _showColumnPicker(context),
        ),
        IlyassMenuAction(
          icon: Icons.refresh,
          label: l.refreshTooltip,
          enabled: company != null,
          onSelected: () {
            if (company != null) {
              ref.read(syncManagerProvider).pullPaymentTypes(company.id);
            }
          },
        ),
      ],
      fabLabel: l.newPaymentType,
      onFabPressed: company == null ? null : () => _openEditor(company.id),
      body: asyncTypes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l.errorLoadingPaymentTypes(e.toString()))),
        data: (all) {
          if (company == null) {
            return Center(child: Text(l.noCompanySelectedShort));
          }
          final companyId = company.id;
          final types = _visible(all);
          final selected =
              _selectedIds.intersection(types.map((t) => t.id).toSet());

          Widget boolCell(bool v) => _BoolIcon(value: v);

          /// One entry per toggleable column, in the order the provider
          /// declares them — the picker reorders this list, so the widths and
          /// cells must live with their key rather than in a parallel chain.
          final catalogue = <String, IlyassColumn<PaymentType>>{
            'Name': IlyassColumn<PaymentType>(
              key: 'Name',
              label: _paymentColumnLabel(context, 'Name'),
              width: 220,
              flexible: true,
              cell: (context, t) => Text(
                t.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            'Code': IlyassColumn<PaymentType>(
              key: 'Code',
              label: _paymentColumnLabel(context, 'Code'),
              width: 130,
              cell: (context, t) => Text(t.code ?? '-',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            'Position': IlyassColumn<PaymentType>(
              key: 'Position',
              label: _paymentColumnLabel(context, 'Position'),
              width: 110,
              numeric: true,
              cell: (context, t) => Text('${t.ordinal}'),
            ),
            'Enabled': IlyassColumn<PaymentType>(
              key: 'Enabled',
              label: _paymentColumnLabel(context, 'Enabled'),
              width: 110,
              cell: (context, t) => boolCell(t.isEnabled),
            ),
            'Quick Pay': IlyassColumn<PaymentType>(
              key: 'Quick Pay',
              label: _paymentColumnLabel(context, 'Quick Pay'),
              width: 120,
              cell: (context, t) => boolCell(t.isQuickPayment),
            ),
            'Customer Req.': IlyassColumn<PaymentType>(
              key: 'Customer Req.',
              label: _paymentColumnLabel(context, 'Customer Req.'),
              width: 140,
              cell: (context, t) => boolCell(t.isCustomerRequired),
            ),
            'Change': IlyassColumn<PaymentType>(
              key: 'Change',
              label: _paymentColumnLabel(context, 'Change'),
              width: 110,
              cell: (context, t) => boolCell(t.isChangeAllowed),
            ),
            'Mark Paid': IlyassColumn<PaymentType>(
              key: 'Mark Paid',
              label: _paymentColumnLabel(context, 'Mark Paid'),
              width: 120,
              cell: (context, t) => boolCell(t.markAsPaid),
            ),
            'Cash Drawer': IlyassColumn<PaymentType>(
              key: 'Cash Drawer',
              label: _paymentColumnLabel(context, 'Cash Drawer'),
              width: 130,
              cell: (context, t) => boolCell(t.openCashDrawer),
            ),
            'Fiscal': IlyassColumn<PaymentType>(
              key: 'Fiscal',
              label: _paymentColumnLabel(context, 'Fiscal'),
              width: 110,
              cell: (context, t) => boolCell(t.isFiscal),
            ),
            'Slip': IlyassColumn<PaymentType>(
              key: 'Slip',
              label: _paymentColumnLabel(context, 'Slip'),
              width: 110,
              cell: (context, t) => boolCell(t.isSlipRequired),
            ),
            'Shortcut': IlyassColumn<PaymentType>(
              key: 'Shortcut',
              label: _paymentColumnLabel(context, 'Shortcut'),
              width: 120,
              cell: (context, t) => Text(t.shortcutKey ?? '-'),
            ),
          };

          return IlyassTable<PaymentType>(
            tableId: 'paymentTypes',
            rows: types,
            rowHeight: 64,
            onRowTap: (t) => _openEditor(companyId, t),
            isRowSelected: (t) => selected.contains(t.id),
            // A switched-off type reads as switched off at a glance.
            rowColor: (t) => t.isEnabled
                ? null
                : theme.disabledColor.withValues(alpha: 0.05),
            columns: [
              ilyassSelectionColumn<PaymentType, int>(
                rows: types,
                selected: selected,
                idOf: (t) => t.id,
                onChanged: (ids) => setState(() {
                  _selectedIds
                    ..clear()
                    ..addAll(ids);
                }),
              ),
              for (final entry in catalogue.entries)
                if (visibleColumns[entry.key] == true) entry.value,
            ],
            emptyState: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.payments_outlined,
                        size: 64,
                        color: theme.disabledColor.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      all.isEmpty
                          ? l.noPaymentTypesFound
                          : l.noResultsForFilters,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: theme.disabledColor, fontSize: 16),
                    ),
                    if (all.isEmpty) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(l.addFirstPaymentType),
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
      // Offline-first: tombstone locally (list drops it instantly via the Drift
      // stream); SyncManager issues /PaymentTypes/Delete on the next push.
      await ref.read(appDatabaseProvider).deletePaymentTypeLocal(id);
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      if (!context.mounted) return;
      showAppSnackbar(
          context, ref, AppLocalizations.of(context).paymentTypeDeleted);
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackbar(context, ref, AppLocalizations.of(context).deleteFailed,
          isError: true);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// BOOL ICON
// ─────────────────────────────────────────────────────────────

class _BoolIcon extends StatelessWidget {
  final bool value;

  const _BoolIcon({required this.value});

  @override
  Widget build(BuildContext context) {
    return Icon(
      value ? Icons.check : null,

      color: Theme.of(context).colorScheme.primary,

      size: 18,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FORM DIALOG
// ─────────────────────────────────────────────────────────────

class _PaymentTypeFormDialog extends ConsumerStatefulWidget {
  final int companyId;
  final PaymentType? paymentType;

  const _PaymentTypeFormDialog({required this.companyId, this.paymentType});

  @override
  ConsumerState<_PaymentTypeFormDialog> createState() =>
      _PaymentTypeFormDialogState();
}

class _PaymentTypeFormDialogState
    extends ConsumerState<_PaymentTypeFormDialog> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _ordinalCtrl;
  late final TextEditingController _shortcutCtrl;

  late bool _isEnabled;
  late bool _isQuickPayment;
  late bool _isCustomerRequired;
  late bool _isChangeAllowed;
  late bool _markAsPaid;
  late bool _openCashDrawer;
  late bool _isFiscal;
  late bool _isSlipRequired;

  bool get _isEditing => widget.paymentType != null;

  @override
  void initState() {
    super.initState();

    final p = widget.paymentType;

    _nameCtrl = TextEditingController(text: p?.name ?? '');

    _codeCtrl = TextEditingController(text: p?.code ?? '');

    _ordinalCtrl = TextEditingController(text: p?.ordinal.toString() ?? '0');

    _shortcutCtrl = TextEditingController(text: p?.shortcutKey ?? '');

    _isEnabled = p?.isEnabled ?? true;
    _isQuickPayment = p?.isQuickPayment ?? false;

    _isCustomerRequired = p?.isCustomerRequired ?? false;

    _isChangeAllowed = p?.isChangeAllowed ?? false;

    _markAsPaid = p?.markAsPaid ?? false;

    _openCashDrawer = p?.openCashDrawer ?? false;

    _isFiscal = p?.isFiscal ?? false;

    _isSlipRequired = p?.isSlipRequired ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _ordinalCtrl.dispose();
    _shortcutCtrl.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Offline-first: write to the local DB first so the list updates instantly
      // via the Drift stream; SyncManager pushes /PaymentTypes/Add|Update later.
      await ref.read(appDatabaseProvider).savePaymentTypeLocal(
            id: _isEditing ? widget.paymentType!.id : null,
            companyId: widget.companyId,
            name: _nameCtrl.text.trim(),
            code: _codeCtrl.text.trim(),
            ordinal: int.tryParse(_ordinalCtrl.text.trim()) ?? 0,
            shortcutKey: _shortcutCtrl.text.trim(),
            isEnabled: _isEnabled,
            isQuickPayment: _isQuickPayment,
            isCustomerRequired: _isCustomerRequired,
            isChangeAllowed: _isChangeAllowed,
            markAsPaid: _markAsPaid,
            openCashDrawer: _openCashDrawer,
            isFiscal: _isFiscal,
            isSlipRequired: _isSlipRequired,
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

  Widget _buildCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 1,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                Icon(icon, size: 22),

                const SizedBox(width: 10),

                Text(
                  title,

                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_isEditing
          ? AppLocalizations.of(context).editPaymentType
          : AppLocalizations.of(context).newPaymentType),

      content: SizedBox(
        width: 500,

        child: Form(
          key: _formKey,

          child: SingleChildScrollView(
            child: Column(
              children: [
                // GENERAL INFO
                _buildCard(AppLocalizations.of(context).generalInfo,
                    Icons.info_outline, [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,

                        child: TextFormField(
                          controller: _nameCtrl,

                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context).fieldNameRequired,

                            prefixIcon: const Icon(Icons.payment),

                            border: const OutlineInputBorder(),
                          ),

                          validator: (v) =>
                              v == null || v.trim().isEmpty
                          ? AppLocalizations.of(context).requiredField
                          : null,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: TextFormField(
                          controller: _codeCtrl,

                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context).fieldCode,

                            prefixIcon: const Icon(Icons.code),

                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ordinalCtrl,

                          keyboardType: TextInputType.number,

                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context).fieldPosition,

                            prefixIcon: const Icon(Icons.format_list_numbered),

                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: TextFormField(
                          controller: _shortcutCtrl,

                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context).fieldShortcut,

                            prefixIcon: const Icon(Icons.keyboard),

                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),

                const SizedBox(height: 16),

                // CORE SETTINGS
                _buildCard(AppLocalizations.of(context).coreSettings,
                    Icons.settings_outlined, [
                  _switchRow(
                    AppLocalizations.of(context).fieldEnabled,
                    _isEnabled,
                    (v) => setState(() => _isEnabled = v),
                  ),

                  _switchRow(
                    AppLocalizations.of(context).quickPayment,
                    _isQuickPayment,
                    (v) => setState(() => _isQuickPayment = v),
                  ),

                  _switchRow(
                    AppLocalizations.of(context).markAsPaid,
                    _markAsPaid,
                    (v) => setState(() => _markAsPaid = v),
                  ),
                ]),

                const SizedBox(height: 16),

                // ADVANCED
                _buildCard(AppLocalizations.of(context).advancedHardware,
                    Icons.hardware_outlined, [
                  _switchRow(
                    AppLocalizations.of(context).openCashDrawerLower,
                    _openCashDrawer,
                    (v) => setState(() => _openCashDrawer = v),
                  ),

                  _switchRow(
                    AppLocalizations.of(context).customerRequiredLabel,
                    _isCustomerRequired,
                    (v) => setState(() => _isCustomerRequired = v),
                  ),

                  _switchRow(
                    AppLocalizations.of(context).changeAllowed,
                    _isChangeAllowed,
                    (v) => setState(() => _isChangeAllowed = v),
                  ),

                  _switchRow(
                    AppLocalizations.of(context).fiscal,
                    _isFiscal,
                    (v) => setState(() => _isFiscal = v),
                  ),

                  _switchRow(
                    AppLocalizations.of(context).slipRequired,
                    _isSlipRequired,
                    (v) => setState(() => _isSlipRequired = v),
                  ),
                ]),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,

                      borderRadius: BorderRadius.circular(8),
                    ),

                    child: Text(
                      _errorMessage!,

                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),

          child: Text(AppLocalizations.of(context).actionCancel),
        ),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8),

            child: CircularProgressIndicator(),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.save),

            label: Text(_isEditing ? AppLocalizations.of(context).actionUpdate : AppLocalizations.of(context).actionSave),

            onPressed: _submit,
          ),
      ],
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          Text(label),

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
