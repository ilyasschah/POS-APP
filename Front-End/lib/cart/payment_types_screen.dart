import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/cart/payment_type_model.dart';
import 'package:pos_app/cart/payment_type_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/sync/sync_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────

class PaymentTypesScreen extends ConsumerWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const PaymentTypesScreen({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final asyncTypes = ref.watch(allPaymentTypesProvider);
    final company = ref.watch(selectedCompanyProvider);

    final visibleColumns = ref.watch(paymentTypeVisibleColumnsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text("Payment Types"),
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
          // COLUMN PICKER
          IconButton(
            icon: const Icon(Icons.view_column_rounded),
            tooltip: "Columns",
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) {
                  return Consumer(
                    builder: (context, ref, _) {
                      final columns = ref.watch(
                        paymentTypeVisibleColumnsProvider,
                      );

                      return AlertDialog(
                        title: const Text("Visible Columns"),

                        content: SizedBox(
                          width: 320,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: columns.entries.map((entry) {
                                return CheckboxListTile(
                                  value: entry.value,
                                  title: Text(entry.key),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  onChanged: (v) {
                                    final updated = Map<String, bool>.from(
                                      columns,
                                    );

                                    updated[entry.key] = v ?? false;

                                    ref
                                            .read(
                                              paymentTypeVisibleColumnsProvider
                                                  .notifier,
                                            )
                                            .state =
                                        updated;
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Close"),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: company == null
                ? null
                : () => ref
                    .read(syncManagerProvider)
                    .pullPaymentTypes(company.id),
          ),

          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "New Payment Type",
            onPressed: company == null
                ? null
                : () async {
                    await showDialog(
                      context: context,
                      builder: (_) =>
                          _PaymentTypeFormDialog(companyId: company.id),
                    );

                    await ref
                        .read(syncManagerProvider)
                        .pullPaymentTypes(company.id);
                  },
          ),
        ],
      ),

      body: asyncTypes.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (e, _) => Center(child: Text("Error loading payment types: $e")),

        data: (types) {
          if (company == null) {
            return const Center(child: Text("No company selected."));
          }

          final int companyId = company.id;

          if (types.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "No payment types found.",
                    style: TextStyle(color: theme.disabledColor, fontSize: 16),
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Add First Payment Type"),

                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (_) =>
                            _PaymentTypeFormDialog(companyId: companyId),
                      );

                      await ref
                          .read(syncManagerProvider)
                          .pullPaymentTypes(companyId);
                    },
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- RESPONSIVE HEADER ROW ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    child: Row(
                      children: [
                        if (visibleColumns['Name'] == true)
                          Expanded(
                            flex: 3,
                            child: Text(
                              "Name",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        if (visibleColumns['Code'] == true)
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Code",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        if (visibleColumns['Position'] == true)
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Position",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        if (visibleColumns['Enabled'] == true)
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Enabled",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        if (visibleColumns['Quick Pay'] == true)
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Quick Pay",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        if (visibleColumns['Customer Req.'] == true)
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Customer Req.",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        if (visibleColumns['Change'] == true)
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Change",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        if (visibleColumns['Mark Paid'] == true)
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Mark Paid",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        if (visibleColumns['Cash Drawer'] == true)
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Cash Drawer",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        if (visibleColumns['Fiscal'] == true)
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Fiscal",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        if (visibleColumns['Slip'] == true)
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Slip",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        if (visibleColumns['Shortcut'] == true)
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Shortcut",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        if (visibleColumns['Actions'] == true)
                          SizedBox(
                            width: 100,
                            child: Text(
                              "Actions",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // --- LIST OF ITEMS ---
                  Expanded(
                    child: ListView.separated(
                      itemCount: types.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      ),
                      itemBuilder: (context, index) {
                        final t = types[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              if (visibleColumns['Name'] == true)
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    t.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (visibleColumns['Code'] == true)
                                Expanded(flex: 1, child: Text(t.code ?? '-')),
                              if (visibleColumns['Position'] == true)
                                Expanded(
                                  flex: 1,
                                  child: Text(t.ordinal.toString()),
                                ),
                              if (visibleColumns['Enabled'] == true)
                                Expanded(
                                  flex: 1,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _BoolIcon(value: t.isEnabled),
                                  ),
                                ),
                              if (visibleColumns['Quick Pay'] == true)
                                Expanded(
                                  flex: 1,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _BoolIcon(value: t.isQuickPayment),
                                  ),
                                ),
                              if (visibleColumns['Customer Req.'] == true)
                                Expanded(
                                  flex: 1,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _BoolIcon(
                                      value: t.isCustomerRequired,
                                    ),
                                  ),
                                ),
                              if (visibleColumns['Change'] == true)
                                Expanded(
                                  flex: 1,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _BoolIcon(value: t.isChangeAllowed),
                                  ),
                                ),
                              if (visibleColumns['Mark Paid'] == true)
                                Expanded(
                                  flex: 1,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _BoolIcon(value: t.markAsPaid),
                                  ),
                                ),
                              if (visibleColumns['Cash Drawer'] == true)
                                Expanded(
                                  flex: 1,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _BoolIcon(value: t.openCashDrawer),
                                  ),
                                ),
                              if (visibleColumns['Fiscal'] == true)
                                Expanded(
                                  flex: 1,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _BoolIcon(value: t.isFiscal),
                                  ),
                                ),
                              if (visibleColumns['Slip'] == true)
                                Expanded(
                                  flex: 1,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _BoolIcon(value: t.isSlipRequired),
                                  ),
                                ),
                              if (visibleColumns['Shortcut'] == true)
                                Expanded(
                                  flex: 1,
                                  child: Text(t.shortcutKey ?? '-'),
                                ),
                              if (visibleColumns['Actions'] == true)
                                SizedBox(
                                  width: 100,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Tooltip(
                                        message: "Edit",
                                        child: InkWell(
                                          onTap: () async {
                                            await showDialog(
                                              context: context,
                                              builder: (_) =>
                                                  _PaymentTypeFormDialog(
                                                    companyId: companyId,
                                                    paymentType: t,
                                                  ),
                                            );
                                            ref.invalidate(
                                              allPaymentTypesProvider,
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Icon(
                                              Icons.edit,
                                              color: theme.colorScheme.primary,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: "Delete",
                                        child: InkWell(
                                          onTap: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text("Delete"),
                                                content: Text(
                                                  "Delete payment type '${t.name}'?",
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
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
                                                        ),
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          ctx,
                                                        ).pop(true),
                                                    child: Text(
                                                      "Delete",
                                                      style: TextStyle(
                                                        color: theme
                                                            .colorScheme
                                                            .onError,
                                                      ),
                                                    ),
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
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Icon(
                                              Icons.delete,
                                              color: theme.colorScheme.error,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
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
      showAppSnackbar(context, ref, 'Payment type deleted');
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackbar(context, ref, 'Delete failed', isError: true);
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
        _errorMessage = "Operation failed.";
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
      title: Text(_isEditing ? "Edit Payment Type" : "New Payment Type"),

      content: SizedBox(
        width: 500,

        child: Form(
          key: _formKey,

          child: SingleChildScrollView(
            child: Column(
              children: [
                // GENERAL INFO
                _buildCard('General Info', Icons.info_outline, [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,

                        child: TextFormField(
                          controller: _nameCtrl,

                          decoration: const InputDecoration(
                            labelText: "Name *",

                            prefixIcon: Icon(Icons.payment),

                            border: OutlineInputBorder(),
                          ),

                          validator: (v) =>
                              v == null || v.trim().isEmpty ? "Required" : null,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: TextFormField(
                          controller: _codeCtrl,

                          decoration: const InputDecoration(
                            labelText: "Code",

                            prefixIcon: Icon(Icons.code),

                            border: OutlineInputBorder(),
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

                          decoration: const InputDecoration(
                            labelText: "Position",

                            prefixIcon: Icon(Icons.format_list_numbered),

                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: TextFormField(
                          controller: _shortcutCtrl,

                          decoration: const InputDecoration(
                            labelText: "Shortcut",

                            prefixIcon: Icon(Icons.keyboard),

                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),

                const SizedBox(height: 16),

                // CORE SETTINGS
                _buildCard('Core Settings', Icons.settings_outlined, [
                  _switchRow(
                    "Enabled",
                    _isEnabled,
                    (v) => setState(() => _isEnabled = v),
                  ),

                  _switchRow(
                    "Quick Payment",
                    _isQuickPayment,
                    (v) => setState(() => _isQuickPayment = v),
                  ),

                  _switchRow(
                    "Mark As Paid",
                    _markAsPaid,
                    (v) => setState(() => _markAsPaid = v),
                  ),
                ]),

                const SizedBox(height: 16),

                // ADVANCED
                _buildCard('Advanced / Hardware', Icons.hardware_outlined, [
                  _switchRow(
                    "Open Cash Drawer",
                    _openCashDrawer,
                    (v) => setState(() => _openCashDrawer = v),
                  ),

                  _switchRow(
                    "Customer Required",
                    _isCustomerRequired,
                    (v) => setState(() => _isCustomerRequired = v),
                  ),

                  _switchRow(
                    "Change Allowed",
                    _isChangeAllowed,
                    (v) => setState(() => _isChangeAllowed = v),
                  ),

                  _switchRow(
                    "Fiscal",
                    _isFiscal,
                    (v) => setState(() => _isFiscal = v),
                  ),

                  _switchRow(
                    "Slip Required",
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

          child: const Text("Cancel"),
        ),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8),

            child: CircularProgressIndicator(),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.save),

            label: Text(_isEditing ? "Update" : "Save"),

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
