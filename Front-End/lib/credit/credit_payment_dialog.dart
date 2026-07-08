import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/cart/payment_type_model.dart';
import 'package:pos_app/cart/payment_type_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/customer/customer_provider.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
class _UnpaidDoc {
  final int     id;
  final String  number;
  final String? documentTypeName;
  final String  dateStr;
  final String? userName;
  final double  total;
  final double  balance;
  final String  dateCreatedStr;
  final String? internalNote;
  final String? note;

  const _UnpaidDoc({
    required this.id,
    required this.number,
    this.documentTypeName,
    required this.dateStr,
    this.userName,
    required this.total,
    required this.balance,
    required this.dateCreatedStr,
    this.internalNote,
    this.note,
  });

  factory _UnpaidDoc.fromJson(Map<String, dynamic> j) {
    String fmt(String? raw) {
      if (raw == null || raw.isEmpty) return '';
      try {
        final dt = DateTime.parse(raw).toLocal();
        return DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {
        return raw;
      }
    }

    String fmtFull(String? raw) {
      if (raw == null || raw.isEmpty) return '';
      try {
        final dt = DateTime.parse(raw).toLocal();
        return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
      } catch (_) {
        return raw;
      }
    }

    return _UnpaidDoc(
      id:               j['id'] as int? ?? 0,
      number:           j['number'] as String? ?? '',
      documentTypeName: j['documentTypeName'] as String?,
      dateStr:          fmt(j['date'] as String?),
      userName:         j['userName'] as String?,
      total:            (j['total'] as num?)?.toDouble() ?? 0,
      balance:          (j['balance'] as num?)?.toDouble() ?? 0,
      dateCreatedStr:   fmtFull(j['dateCreated'] as String?),
      internalNote:     j['internalNote'] as String?,
      note:             j['note'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog entry point
// ---------------------------------------------------------------------------
class CreditPaymentsDialog extends ConsumerStatefulWidget {
  const CreditPaymentsDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const CreditPaymentsDialog(),
      );

  @override
  ConsumerState<CreditPaymentsDialog> createState() =>
      _CreditPaymentsDialogState();
}

class _CreditPaymentsDialogState
    extends ConsumerState<CreditPaymentsDialog> {
  // ── Controls ───────────────────────────────────────────────────────────────
  int?  _customerId;
  int?  _paymentTypeId;
  final _amountCtrl = TextEditingController(text: '0');
  bool  _useCustomerBalance   = false;
  bool  _automaticDistribution = false;

  // ── Data ──────────────────────────────────────────────────────────────────
  List<_UnpaidDoc> _docs        = [];
  Set<int>         _selectedIds = {};
  bool             _isLoading   = false;
  bool             _isSubmitting = false;
  String?          _errorMessage;

  // ── Computed ──────────────────────────────────────────────────────────────
  double get _customerBalance =>
      _docs.fold(0.0, (s, d) => s + d.balance);

  double get _selectedTotal =>
      _docs.where((d) => _selectedIds.contains(d.id))
           .fold(0.0, (s, d) => s + d.balance);

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _onCustomerChanged(int? id) {
    setState(() {
      _customerId       = id;
      _docs             = [];
      _selectedIds      = {};
      _useCustomerBalance = false;
      _amountCtrl.text  = '0';
      _errorMessage     = null;
    });
  }

  void _onAutoDistributionChanged(bool val) {
    setState(() {
      _automaticDistribution = val;
      _selectedIds           = {};
      _errorMessage          = null;
      if (_useCustomerBalance) {
        _amountCtrl.text =
            (val ? _customerBalance : _selectedTotal).toStringAsFixed(2);
      }
    });
  }

  void _onUseBalanceChanged(bool val) {
    setState(() {
      _useCustomerBalance = val;
      if (val) {
        _amountCtrl.text =
            (_automaticDistribution ? _customerBalance : _selectedTotal)
                .toStringAsFixed(2);
      }
    });
  }

  void _onRowToggle(int docId) {
    setState(() {
      if (_selectedIds.contains(docId)) {
        _selectedIds.remove(docId);
      } else {
        _selectedIds.add(docId);
      }
      if (_useCustomerBalance && !_automaticDistribution) {
        _amountCtrl.text = _selectedTotal.toStringAsFixed(2);
      }
    });
  }

  void _onSelectAll(bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedIds = _docs.map((d) => d.id).toSet();
      } else {
        _selectedIds = {};
      }
      if (_useCustomerBalance && !_automaticDistribution) {
        _amountCtrl.text = _selectedTotal.toStringAsFixed(2);
      }
    });
  }

  Future<void> _loadDocs() async {
    if (_customerId == null) return;
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;

    setState(() {
      _isLoading    = true;
      _errorMessage = null;
      _docs         = [];
      _selectedIds  = {};
    });

    try {
      final dio      = createDio();
      final response = await dio.get(
        '/Document/GetUnpaidByCustomer',
        queryParameters: {
          'companyId':  company.id,
          'customerId': _customerId,
        },
      );
      final list = response.data as List<dynamic>;
      final docs = list.map((j) => _UnpaidDoc.fromJson(j as Map<String, dynamic>)).toList();

      setState(() {
        _docs      = docs;
        _isLoading = false;
        if (_useCustomerBalance) {
          _amountCtrl.text = (_automaticDistribution
                  ? _customerBalance
                  : _selectedTotal)
              .toStringAsFixed(2);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading    = false;
        _errorMessage = 'Failed to load documents: $e';
      });
    }
  }

  Future<void> _submit() async {
    final company = ref.read(selectedCompanyProvider);
    final user    = ref.read(currentUserProvider);
    if (company == null || user == null) return;
    if (_customerId == null) return;

    // Resolve effective payment type: prefer explicit selection, fall back to
    // the first enabled type that the dropdown is visually displaying.
    final payTypes       = ref.read(allPaymentTypesProvider).asData?.value ?? [];
    final effectivePayId = _paymentTypeId ??
        payTypes.where((p) => p.isEnabled).firstOrNull?.id;
    if (effectivePayId == null) return;

    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid amount.');
      return;
    }

    if (!_automaticDistribution && _selectedIds.isEmpty) {
      setState(() => _errorMessage =
          'Please select at least one document, or enable Automatic distribution.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final dio = createDio();
      await dio.post(
        '/Payments/ApplyCreditPayment',
        queryParameters: {
          'companyId': company.id,
          'userId':    user.id,
        },
        data: {
          'customerId':          _customerId,
          'paymentTypeId':       effectivePayId,
          'amount':              amount,
          'isAutomatic':         _automaticDistribution,
          'selectedDocumentIds': _automaticDistribution
              ? <int>[]
              : _selectedIds.toList(),
        },
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      String msg = 'An error occurred: $e';
      setState(() {
        _isSubmitting = false;
        _errorMessage = msg;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme          = Theme.of(context);
    final customersAsync = ref.watch(allCustomersProvider);
    final payTypesAsync  = ref.watch(allPaymentTypesProvider);

    // Resolve selected customer name for summary
    final selectedCustomer = customersAsync.asData?.value
        .where((c) => c.id == _customerId)
        .firstOrNull;

    final bool canLoadDocs =
        _customerId != null && !_automaticDistribution && !_isLoading;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width:  double.maxFinite,
        height: MediaQuery.of(context).size.height - 32,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Title bar ─────────────────────────────────────────────────
            _TitleBar(onClose: () => Navigator.of(context).pop()),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left panel
                  _LeftPanel(
                    customersAsync:      customersAsync,
                    payTypesAsync:       payTypesAsync,
                    selectedCustomerId:  _customerId,
                    selectedPayTypeId:   _paymentTypeId,
                    amountCtrl:          _amountCtrl,
                    useCustomerBalance:  _useCustomerBalance,
                    automaticDistrib:    _automaticDistribution,
                    canLoadDocs:         canLoadDocs,
                    isLoading:           _isLoading,
                    onCustomerChanged:   _onCustomerChanged,
                    onPayTypeChanged:    (id) => setState(() => _paymentTypeId = id),
                    onUseBalanceChanged: _onUseBalanceChanged,
                    onAutoChanged:       _onAutoDistributionChanged,
                    onLoadDocs:          _loadDocs,
                  ),

                  VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),

                  // Right panel
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Summary header
                        _SummaryHeader(
                          customerName:  selectedCustomer?.name ?? _customerDisplayName(customersAsync),
                          customerBalance: _customerBalance,
                          selectedTotal:  _selectedTotal,
                          hasCustomer:    _customerId != null,
                          isAutomatic:    _automaticDistribution,
                        ),

                        // Error banner
                        if (_errorMessage != null)
                          Container(
                            color: theme.colorScheme.errorContainer,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer),
                            ),
                          ),

                        // Content area
                        Expanded(
                          child: _ContentArea(
                            hasCustomer:    _customerId != null,
                            isAutomatic:    _automaticDistribution,
                            isLoading:      _isLoading,
                            docs:           _docs,
                            selectedIds:    _selectedIds,
                            onRowToggle:    _onRowToggle,
                            onSelectAll:    _onSelectAll,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: theme.colorScheme.outlineVariant),

            // ── Bottom action bar ─────────────────────────────────────────
            _ActionBar(
              hasCustomer:  _customerId != null,
              isSubmitting: _isSubmitting,
              onOk:         _submit,
              onClose:      () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  String _customerDisplayName(AsyncValue<List<Customer>> async) {
    if (_customerId == null) return 'Select customer';
    return async.asData?.value
            .where((c) => c.id == _customerId)
            .firstOrNull
            ?.name ??
        '...';
  }
}

// ---------------------------------------------------------------------------
// Title bar
// ---------------------------------------------------------------------------
class _TitleBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TitleBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            'Credit payments',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Left control panel
// ---------------------------------------------------------------------------
class _LeftPanel extends StatelessWidget {
  final AsyncValue<List<Customer>>    customersAsync;
  final AsyncValue<List<PaymentType>> payTypesAsync;
  final int?                          selectedCustomerId;
  final int?                          selectedPayTypeId;
  final TextEditingController         amountCtrl;
  final bool                          useCustomerBalance;
  final bool                          automaticDistrib;
  final bool                          canLoadDocs;
  final bool                          isLoading;
  final void Function(int?)           onCustomerChanged;
  final void Function(int?)           onPayTypeChanged;
  final void Function(bool)           onUseBalanceChanged;
  final void Function(bool)           onAutoChanged;
  final VoidCallback                  onLoadDocs;

  const _LeftPanel({
    required this.customersAsync,
    required this.payTypesAsync,
    required this.selectedCustomerId,
    required this.selectedPayTypeId,
    required this.amountCtrl,
    required this.useCustomerBalance,
    required this.automaticDistrib,
    required this.canLoadDocs,
    required this.isLoading,
    required this.onCustomerChanged,
    required this.onPayTypeChanged,
    required this.onUseBalanceChanged,
    required this.onAutoChanged,
    required this.onLoadDocs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 270,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer
            Text('Customer', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            _CustomerDropdown(
              customersAsync:    customersAsync,
              selectedId:        selectedCustomerId,
              onChanged:         onCustomerChanged,
            ),
            const SizedBox(height: 16),

            // Payment type
            Text('Payment type', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            _PaymentTypeDropdown(
              payTypesAsync: payTypesAsync,
              selectedId:    selectedPayTypeId,
              onChanged:     onPayTypeChanged,
            ),
            const SizedBox(height: 16),

            // Amount + use balance
            Text('Amount', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Checkbox(
                        value:     useCustomerBalance,
                        onChanged: (v) => onUseBalanceChanged(v ?? false),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      Flexible(
                        child: GestureDetector(
                          onTap: () =>
                              onUseBalanceChanged(!useCustomerBalance),
                          child: Text(
                            'Use customer balance',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Automatic distribution
            Row(
              children: [
                Switch(
                  value:     automaticDistrib,
                  onChanged: onAutoChanged,
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onAutoChanged(!automaticDistrib),
                  child: Text(
                    'Automatic distribution',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Load button
            OutlinedButton.icon(
              onPressed: canLoadDocs ? onLoadDocs : null,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: const Text('Load unpaid documents'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dropdowns
// ---------------------------------------------------------------------------
class _CustomerDropdown extends StatelessWidget {
  final AsyncValue<List<Customer>> customersAsync;
  final int?                       selectedId;
  final void Function(int?)        onChanged;

  const _CustomerDropdown({
    required this.customersAsync,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customers = customersAsync.asData?.value
            .where((c) => c.isCustomer && c.code != 'C000')
            .toList() ??
        [];

    return _StyledDropdown<int?>(
      value:    selectedId,
      hint:     const Text('Select customer'),
      items:    customers
          .map((c) => DropdownMenuItem<int?>(
                value: c.id,
                child: Text(c.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _PaymentTypeDropdown extends StatelessWidget {
  final AsyncValue<List<PaymentType>> payTypesAsync;
  final int?                          selectedId;
  final void Function(int?)           onChanged;

  const _PaymentTypeDropdown({
    required this.payTypesAsync,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final payTypes = payTypesAsync.asData?.value
            .where((p) => p.isEnabled)
            .toList() ??
        [];

    final effectiveId = selectedId ??
        (payTypes.isNotEmpty ? payTypes.first.id : null);

    return _StyledDropdown<int?>(
      value:    effectiveId,
      items:    payTypes
          .map((p) => DropdownMenuItem<int?>(
                value: p.id,
                child: Text(p.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// Shared styled dropdown — uses DropdownButton inside InputDecorator so the
// selected value is always kept in sync with external state (unlike
// DropdownButtonFormField.initialValue which is set-once).
class _StyledDropdown<T> extends StatelessWidget {
  final T                              value;
  final Widget?                        hint;
  final List<DropdownMenuItem<T>>      items;
  final void Function(T?)              onChanged;

  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: theme.colorScheme.outline),
    );

    return InputDecorator(
      decoration: InputDecoration(
        isDense:        true,
        border:         border,
        enabledBorder:  border,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      child: DropdownButton<T>(
        value:          value,
        hint:           hint,
        isExpanded:     true,
        underline:      const SizedBox.shrink(),
        isDense:        true,
        items:          items,
        onChanged:      onChanged,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary header (right panel top)
// ---------------------------------------------------------------------------
const _kCyan = Color(0xFF0097A7);

class _SummaryHeader extends StatelessWidget {
  final String  customerName;
  final double  customerBalance;
  final double  selectedTotal;
  final bool    hasCustomer;
  final bool    isAutomatic;

  const _SummaryHeader({
    required this.customerName,
    required this.customerBalance,
    required this.selectedTotal,
    required this.hasCustomer,
    required this.isAutomatic,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Colored header bar
        Container(
          color: _kCyan,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Summary',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Content
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: theme.colorScheme.surfaceContainerLow,
          child: hasCustomer
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Customer balance',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.65))),
                    Text(
                      customerBalance.toStringAsFixed(2),
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Total in selected documents',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.65))),
                    Text(
                      isAutomatic
                          ? '---'
                          : selectedTotal.toStringAsFixed(2),
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                )
              : const SizedBox(height: 80),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Content area (right panel body)
// ---------------------------------------------------------------------------
class _ContentArea extends StatelessWidget {
  final bool                 hasCustomer;
  final bool                 isAutomatic;
  final bool                 isLoading;
  final List<_UnpaidDoc>     docs;
  final Set<int>             selectedIds;
  final void Function(int)   onRowToggle;
  final void Function(bool?) onSelectAll;

  const _ContentArea({
    required this.hasCustomer,
    required this.isAutomatic,
    required this.isLoading,
    required this.docs,
    required this.selectedIds,
    required this.onRowToggle,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // No customer selected
    if (!hasCustomer) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility_off_outlined,
                size: 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 12),
            Text(
              'Customer not selected.\nPlease select customer for reconciliation.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      );
    }

    // Automatic mode placeholder
    if (isAutomatic) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: _kCyan,
              child: Icon(Icons.info_outline,
                  size: 28, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              'Paid amount will be automatically distributed\nacross all unpaid sales.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    // Loading
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Empty state (loaded but no docs)
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 12),
            Text(
              'No unpaid documents found for this customer.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      );
    }

    // Table
    return _DocsTable(
      docs:       docs,
      selectedIds: selectedIds,
      onRowToggle: onRowToggle,
      onSelectAll: onSelectAll,
    );
  }
}

// ---------------------------------------------------------------------------
// Documents table
// ---------------------------------------------------------------------------
class _DocsTable extends StatelessWidget {
  final List<_UnpaidDoc>     docs;
  final Set<int>             selectedIds;
  final void Function(int)   onRowToggle;
  final void Function(bool?) onSelectAll;

  const _DocsTable({
    required this.docs,
    required this.selectedIds,
    required this.onRowToggle,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final allChecked = docs.isNotEmpty &&
        docs.every((d) => selectedIds.contains(d.id));
    final someChecked = !allChecked &&
        docs.any((d) => selectedIds.contains(d.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: _HeaderRow(
            allChecked:  allChecked,
            someChecked: someChecked,
            onSelectAll: onSelectAll,
          ),
        ),
        // Data rows
        Expanded(
          child: ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc       = docs[i];
              final isSelected = selectedIds.contains(doc.id);
              return _DocRow(
                doc:        doc,
                isSelected: isSelected,
                onToggle:   () => onRowToggle(doc.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Column flex weights — defined once so header and rows always match.
// Total = 12+12+10+9+9+9+20+11+9 = 101 flex units (+ 44px fixed checkbox).
const _kFlexNumber   = 12;
const _kFlexDocType  = 12;
const _kFlexDate     = 10;
const _kFlexUser     =  9;
const _kFlexTotal    =  9;
const _kFlexBalance  =  9;
const _kFlexCreated  = 20; // needs room for full "dd/MM/yyyy HH:mm:ss"
const _kFlexIntNote  = 11;
const _kFlexNote     =  9;

// Consistent cell padding prevents right-aligned values bleeding into the
// next column.  Every Expanded uses this wrapper.
Widget _col({required int flex, required Widget child}) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: child,
      ),
    );

class _HeaderRow extends StatelessWidget {
  final bool                 allChecked;
  final bool                 someChecked;
  final void Function(bool?) onSelectAll;

  const _HeaderRow({
    required this.allChecked,
    required this.someChecked,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: _kCyan,
      fontWeight: FontWeight.bold,
    );

    Widget hdr(int flex, String label, {bool right = false}) => _col(
          flex: flex,
          child: Text(label,
              style: style,
              textAlign: right ? TextAlign.right : TextAlign.left,
              overflow: TextOverflow.ellipsis),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Checkbox(
              value:     allChecked ? true : (someChecked ? null : false),
              tristate:  true,
              onChanged: onSelectAll,
            ),
          ),
          hdr(_kFlexNumber,  'Number'),
          hdr(_kFlexDocType, 'Document type'),
          hdr(_kFlexDate,    'Date'),
          hdr(_kFlexUser,    'User'),
          hdr(_kFlexTotal,   'Total',   right: true),
          hdr(_kFlexBalance, 'Balance', right: true),
          hdr(_kFlexCreated, 'Created'),
          hdr(_kFlexIntNote, 'Internal note'),
          hdr(_kFlexNote,    'Note'),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final _UnpaidDoc doc;
  final bool       isSelected;
  final VoidCallback onToggle;

  const _DocRow({
    required this.doc,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isSelected
        ? _kCyan.withValues(alpha: 0.15)
        : Colors.transparent;

    final s = theme.textTheme.bodySmall;

    return InkWell(
      onTap: onToggle,
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Checkbox(
                value:     isSelected,
                onChanged: (_) => onToggle(),
              ),
            ),
            _col(
              flex: _kFlexNumber,
              child: Text(doc.number,
                  style: s, overflow: TextOverflow.ellipsis),
            ),
            _col(
              flex: _kFlexDocType,
              child: Text(doc.documentTypeName ?? '',
                  style: s?.copyWith(color: _kCyan),
                  overflow: TextOverflow.ellipsis),
            ),
            _col(
              flex: _kFlexDate,
              child: Text(doc.dateStr,
                  style: s, overflow: TextOverflow.ellipsis),
            ),
            _col(
              flex: _kFlexUser,
              child: Text(doc.userName ?? '',
                  style: s, overflow: TextOverflow.ellipsis),
            ),
            _col(
              flex: _kFlexTotal,
              child: Text(
                doc.total.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: s?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            _col(
              flex: _kFlexBalance,
              child: Text(
                doc.balance.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: s?.copyWith(
                  color: doc.balance > 0
                      ? Colors.red.shade400
                      : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _col(
              flex: _kFlexCreated,
              child: Text(doc.dateCreatedStr,
                  style: s, overflow: TextOverflow.ellipsis),
            ),
            _col(
              flex: _kFlexIntNote,
              child: Text(doc.internalNote ?? '',
                  style: s, overflow: TextOverflow.ellipsis),
            ),
            _col(
              flex: _kFlexNote,
              child: Text(doc.note ?? '',
                  style: s, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom action bar
// ---------------------------------------------------------------------------
class _ActionBar extends StatelessWidget {
  final bool         hasCustomer;
  final bool         isSubmitting;
  final VoidCallback onOk;
  final VoidCallback onClose;

  const _ActionBar({
    required this.hasCustomer,
    required this.isSubmitting,
    required this.onOk,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton.icon(
            onPressed: hasCustomer && !isSubmitting ? onOk : null,
            icon: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check, size: 18),
            label: const Text('OK'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Close'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
