import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

// --- SCREEN ---
class TaxRatesScreen extends ConsumerWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const TaxRatesScreen({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTaxes = ref.watch(allTaxesProvider);
    final company = ref.watch(selectedCompanyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Tax Rates"),
        centerTitle: false,
        elevation: 0,
        // Suppress the auto back-arrow — ManagementLayout controls navigation.
        automaticallyImplyLeading: false,
        leading: onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Show navigation',
                onPressed: onMenuPressed,
              )
            : null,
        actions: [
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: () => ref.invalidate(allTaxesProvider),
          ),
          // Switch Taxes
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: "Switch Taxes",
            onPressed: company == null || asyncTaxes.value == null
                ? null
                : () async {
                    await showDialog(
                      context: context,
                      builder: (_) => _SwitchTaxesDialog(
                        taxes: asyncTaxes.value!,
                        companyId: company.id,
                      ),
                    );
                    ref.invalidate(allTaxesProvider);
                  },
          ),
          // Add
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: "New Tax Rate",
              color: theme.colorScheme.primary,
              onPressed: company == null
                  ? null
                  : () async {
                      await showDialog(
                        context: context,
                        builder: (_) => _TaxFormDialog(companyId: company.id),
                      );
                      ref.invalidate(allTaxesProvider);
                    },
            ),
          ),
        ],
      ),
      body: asyncTaxes.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
        error: (e, _) => Center(
          child: Text(
            "Error loading taxes: $e",
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
        data: (taxes) {
          if (company == null) {
            return Center(
              child: Text(
                "No company selected.",
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            );
          }
          final int companyId = company.id;

          if (taxes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.percent,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No tax rates found.",
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Add First Tax Rate"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (_) => _TaxFormDialog(companyId: companyId),
                      );
                      ref.invalidate(allTaxesProvider);
                    },
                  ),
                ],
              ),
            );
          }

          // FULL SCREEN RESPONSIVE LAYOUT
          return Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical, // Scroll down if many rows
                    child: SingleChildScrollView(
                      scrollDirection:
                          Axis.horizontal, // Scroll right if screen is narrow
                      child: ConstrainedBox(
                        // This forces the table to stretch to the edges of the card!
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            theme.colorScheme.surfaceContainerHighest,
                          ),
                          dataRowMaxHeight: 60,
                          dataRowMinHeight: 60,
                          columnSpacing:
                              32, // Gives columns nice breathing room
                          columns: [
                            DataColumn(
                              label: Text(
                                "Name",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "Rate",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text(
                                "Code",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "Fixed",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "Tax on Total",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "Enabled",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                "Actions",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                          rows: taxes.map((t) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    t.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    "${t.isFixed ? '' : ''}${t.rate.toStringAsFixed(t.rate % 1 == 0 ? 0 : 2)}${t.isFixed ? '' : '%'}",
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(Text(t.code ?? '-')),
                                DataCell(
                                  _BoolIcon(value: t.isFixed, theme: theme),
                                ),
                                DataCell(
                                  _BoolIcon(
                                    value: t.isTaxOnTotal,
                                    theme: theme,
                                  ),
                                ),
                                DataCell(
                                  _BoolIcon(value: t.isEnabled, theme: theme),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: theme.colorScheme.primary,
                                          size: 20,
                                        ),
                                        tooltip: "Edit",
                                        splashRadius: 24,
                                        onPressed: () async {
                                          await showDialog(
                                            context: context,
                                            builder: (_) => _TaxFormDialog(
                                              companyId: companyId,
                                              tax: t,
                                            ),
                                          );
                                          ref.invalidate(allTaxesProvider);
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: theme.colorScheme.error,
                                          size: 20,
                                        ),
                                        tooltip: "Delete",
                                        splashRadius: 24,
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              backgroundColor:
                                                  theme.colorScheme.surface,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              title: Row(
                                                children: [
                                                  Icon(
                                                    Icons.warning_amber_rounded,
                                                    color:
                                                        theme.colorScheme.error,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text("Delete Tax"),
                                                ],
                                              ),
                                              content: Text(
                                                "Are you sure you want to delete the tax rate '${t.name}'?",
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(false),
                                                  child: const Text("Cancel"),
                                                ),
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor: theme
                                                            .colorScheme
                                                            .error,
                                                        foregroundColor: theme
                                                            .colorScheme
                                                            .onError,
                                                      ),
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(true),
                                                  child: const Text("Delete"),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true &&
                                              context.mounted) {
                                            await _delete(
                                              context,
                                              ref,
                                              t.id,
                                              companyId,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
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
      showAppSnackbar(context, ref, "Tax rate deleted");
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackbar(context, ref, "Delete failed", isError: true);
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
        _errorMessage = "Operation failed.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _isEditing ? "Edit Tax Rate" : "New Tax Rate",
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
                        labelText: "Name *",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _codeCtrl,
                      decoration: InputDecoration(
                        labelText: "Code",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rateCtrl,
                decoration: InputDecoration(
                  labelText: "Rate *",
                  hintText: "e.g. 20 for 20%",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Required";
                  if (double.tryParse(v.trim()) == null) {
                    return "Enter a valid number";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _switchRow(
                "Fixed Amount",
                _isFixed,
                (v) => setState(() => _isFixed = v),
                theme,
              ),
              _switchRow(
                "Tax on Total",
                _isTaxOnTotal,
                (v) => setState(() => _isTaxOnTotal = v),
                theme,
              ),
              _switchRow(
                "Enabled",
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
          child: const Text("Cancel"),
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: Text(_isEditing ? "Update" : "Save"),
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
      setState(() => _errorMessage = "Please select both taxes.");
      return;
    }
    if (_oldTaxId == _newTaxId) {
      setState(() => _errorMessage = "Old and new tax must be different.");
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
      setState(
        () => _successMessage =
            "Rate ${oldTax.rate}${oldTax.isFixed ? '' : '%'} from '${oldTax.name}' "
            "applied to '${newTax.name}' successfully.",
      );
    } catch (e) {
      setState(() {
        _errorMessage = "Switch failed.";
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
      title: const Text(
        "Switch Taxes",
        style: TextStyle(fontWeight: FontWeight.bold),
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
                      "Use this form to replace taxes for all products. "
                      "Select the old tax you wish to replace with the new tax and click Replace.",
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
                labelText: "Old Tax",
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
                labelText: "New Tax",
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
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(
                          color: Colors.green,
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
          child: const Text("Close"),
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const Text("Replace"),
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
