import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/cart/payment_type_model.dart';
import 'package:pos_app/cart/payment_type_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/session/session_provider.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
class _UnpaidDoc {
  final int id;
  final String localId;
  final DateTime date;
  final String number;
  final String? documentTypeName;
  final String dateStr;
  final String? userName;
  final double total;
  final double balance;
  final String dateCreatedStr;
  final String? internalNote;
  final String? note;

  const _UnpaidDoc({
    required this.id,
    required this.localId,
    required this.date,
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
}

// ---------------------------------------------------------------------------
// Screen entry point
// ---------------------------------------------------------------------------
class CreditPaymentsScreen extends ConsumerStatefulWidget {
  const CreditPaymentsScreen({super.key});

  // Updated to push a route instead of showing a dialog
  static Future<void> show(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const CreditPaymentsScreen()));

  @override
  ConsumerState<CreditPaymentsScreen> createState() =>
      _CreditPaymentsScreenState();
}

class _CreditPaymentsScreenState extends ConsumerState<CreditPaymentsScreen> {
  // ── Controls ───────────────────────────────────────────────────────────────
  int? _customerId;
  int? _paymentTypeId;
  final _amountCtrl = TextEditingController(text: '0');
  bool _useCustomerBalance = false;
  bool _automaticDistribution = false;

  // ── Data ──────────────────────────────────────────────────────────────────
  List<_UnpaidDoc> _docs = [];
  Set<int> _selectedIds = {};
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // ── Computed ──────────────────────────────────────────────────────────────
  double get _customerBalance => _docs.fold(0.0, (s, d) => s + d.balance);

  double get _selectedTotal => _docs
      .where((d) => _selectedIds.contains(d.id))
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
      _customerId = id;
      _docs = [];
      _selectedIds = {};
      _useCustomerBalance = false;
      _amountCtrl.text = '0';
      _errorMessage = null;
    });
  }

  void _onAutoDistributionChanged(bool val) {
    setState(() {
      _automaticDistribution = val;
      _selectedIds = {};
      _errorMessage = null;
      if (_useCustomerBalance) {
        _amountCtrl.text = (val ? _customerBalance : _selectedTotal)
            .toStringAsFixed(2);
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
      _isLoading = true;
      _errorMessage = null;
      _docs = [];
      _selectedIds = {};
    });

    try {
      final db = ref.read(appDatabaseProvider);
      final rows = await db.getDocuments(
        companyId: company.id,
        customerId: _customerId,
      );

      final users = await db.select(db.usersTable).get();
      final types = await db.select(db.documentTypesTable).get();
      final userName = {for (final u in users) u.id: u.name};
      final typeName = {for (final t in types) t.id: t.name};

      final dateFmt = DateFormat('dd/MM/yyyy');
      final createdFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

      final docs = <_UnpaidDoc>[];
      for (final row in rows) {
        if (row.serverId == null || row.paidStatus == 1) continue;

        final payments = await db.getPayments(row.localId);
        final paid = payments
            .where((p) => p.syncStatus != 'pending_delete')
            .fold<double>(0, (s, p) => s + p.amount);
        final balance = row.total - paid;
        if (balance <= 0) continue;

        if (row.paidStatus == 0 && paid > 0.005) {
          await db.recomputePaidStatus(row.localId);
        }

        docs.add(
          _UnpaidDoc(
            id: row.serverId!,
            localId: row.localId,
            date: row.date,
            number: row.number ?? '',
            documentTypeName: typeName[row.documentTypeId],
            dateStr: dateFmt.format(row.date.toLocal()),
            userName: userName[row.userId],
            total: row.total,
            balance: balance,
            dateCreatedStr: createdFmt.format(
              (row.dateCreated ?? row.date).toLocal(),
            ),
            internalNote: row.internalNote,
            note: row.note,
          ),
        );
      }

      setState(() {
        _docs = docs;
        _isLoading = false;
        if (_useCustomerBalance) {
          _amountCtrl.text =
              (_automaticDistribution ? _customerBalance : _selectedTotal)
                  .toStringAsFixed(2);
        }
      });
    } catch (e) {
      if (!mounted) return;
      final message = AppLocalizations.of(context).errorLoadingDocuments('$e');
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
    }
  }

  Future<void> _submit() async {
    final company = ref.read(selectedCompanyProvider);
    final user = ref.read(currentUserProvider);
    if (company == null || user == null) return;
    if (_customerId == null) return;

    final payTypes = ref.read(allPaymentTypesProvider).asData?.value ?? [];
    final effectivePayId =
        _paymentTypeId ?? payTypes.where((p) => p.isEnabled).firstOrNull?.id;
    if (effectivePayId == null) return;

    final l = AppLocalizations.of(context);

    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      setState(() => _errorMessage = l.enterValidAmount);
      return;
    }

    if (!_automaticDistribution && _selectedIds.isEmpty) {
      setState(() => _errorMessage = l.selectDocumentOrAutoDistribute);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final db = ref.read(appDatabaseProvider);

      final targets =
          (_automaticDistribution
                ? List<_UnpaidDoc>.from(_docs)
                : _docs.where((d) => _selectedIds.contains(d.id)).toList())
            ..sort((a, b) => a.date.compareTo(b.date));

      var remaining = amount;
      final now = DateTime.now();
      var appliedToAny = false;
      for (final doc in targets) {
        if (remaining <= 0) break;
        final apply = remaining < doc.balance ? remaining : doc.balance;
        if (apply <= 0) continue;

        await db.insertLocalPayment(
          PaymentsTableCompanion(
            localId: Value(const Uuid().v4()),
            documentId: Value(doc.localId),
            paymentTypeId: Value(effectivePayId),
            amount: Value(apply),
            userId: Value(user.id),
            date: Value(now),
            companyId: Value(company.id),
            dateCreated: Value(now),
            // 🚨 The session TAKING the money, not the one that raised the
            // invoice. Settling last night's credit puts cash in TODAY's
            // drawer, and today's drawer is what gets counted — an unstamped
            // payment is money the closing count can never account for.
            sessionLocalId:
                Value(ref.read(activeSessionProvider).value?.localId),
            syncStatus: const Value('pending_create'),
          ),
        );
        await db.recomputePaidStatus(doc.localId);
        remaining -= apply;
        appliedToAny = true;
      }

      if (!appliedToAny) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = l.nothingToSettle;
        });
        return;
      }

      ref.read(syncStateProvider.notifier).sync().catchError((_) {});

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = l.anErrorOccurred('$e');
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customersAsync = ref.watch(selectableCustomersProvider);
    final payTypesAsync = ref.watch(allPaymentTypesProvider);

    final selectedCustomer = customersAsync.asData?.value
        .where((c) => c.id == _customerId)
        .firstOrNull;

    final bool canLoadDocs =
        _customerId != null && !_automaticDistribution && !_isLoading;

    // Converted to Scaffold instead of Dialog
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Replaced Title Bar with PosTopBar ─────────────────────────────
          PosTopBar(
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                size: 28,
              ), // Larger icon for touch
              tooltip: AppLocalizations.of(context).back,
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              AppLocalizations.of(context).creditPayments,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left panel - Widened for POS
                _LeftPanel(
                  customersAsync: customersAsync,
                  payTypesAsync: payTypesAsync,
                  selectedCustomerId: _customerId,
                  selectedPayTypeId: _paymentTypeId,
                  amountCtrl: _amountCtrl,
                  useCustomerBalance: _useCustomerBalance,
                  automaticDistrib: _automaticDistribution,
                  canLoadDocs: canLoadDocs,
                  isLoading: _isLoading,
                  onCustomerChanged: _onCustomerChanged,
                  onPayTypeChanged: (id) => setState(() => _paymentTypeId = id),
                  onUseBalanceChanged: _onUseBalanceChanged,
                  onAutoChanged: _onAutoDistributionChanged,
                  onLoadDocs: _loadDocs,
                ),

                VerticalDivider(
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),

                // Right panel
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Summary header
                      _SummaryHeader(
                        customerName:
                            selectedCustomer?.name ??
                            _customerDisplayName(customersAsync),
                        customerBalance: _customerBalance,
                        selectedTotal: _selectedTotal,
                        hasCustomer: _customerId != null,
                        isAutomatic: _automaticDistribution,
                      ),

                      // Error banner - Scaled text
                      if (_errorMessage != null)
                        Container(
                          color: theme.colorScheme.errorContainer,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontSize: 16,
                            ),
                          ),
                        ),

                      // Content area
                      Expanded(
                        child: _ContentArea(
                          hasCustomer: _customerId != null,
                          isAutomatic: _automaticDistribution,
                          isLoading: _isLoading,
                          docs: _docs,
                          selectedIds: _selectedIds,
                          onRowToggle: _onRowToggle,
                          onSelectAll: _onSelectAll,
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
            hasCustomer: _customerId != null,
            isSubmitting: _isSubmitting,
            onOk: _submit,
            onCancel: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  String _customerDisplayName(AsyncValue<List<Customer>> async) {
    if (_customerId == null) {
      return AppLocalizations.of(context).selectCustomerLower;
    }
    return async.asData?.value
            .where((c) => c.id == _customerId)
            .firstOrNull
            ?.name ??
        '...';
  }
}

// ---------------------------------------------------------------------------
// Left control panel
// ---------------------------------------------------------------------------
class _LeftPanel extends StatelessWidget {
  final AsyncValue<List<Customer>> customersAsync;
  final AsyncValue<List<PaymentType>> payTypesAsync;
  final int? selectedCustomerId;
  final int? selectedPayTypeId;
  final TextEditingController amountCtrl;
  final bool useCustomerBalance;
  final bool automaticDistrib;
  final bool canLoadDocs;
  final bool isLoading;
  final void Function(int?) onCustomerChanged;
  final void Function(int?) onPayTypeChanged;
  final void Function(bool) onUseBalanceChanged;
  final void Function(bool) onAutoChanged;
  final VoidCallback onLoadDocs;

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
      width: 340, // Increased width for better touch inputs
      // Scrollable so the form fits a short 7" screen instead of overflowing
      // the bottom.
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Customer
            Text(AppLocalizations.of(context).customerLabel, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _CustomerDropdown(
              customersAsync: customersAsync,
              selectedId: selectedCustomerId,
              onChanged: onCustomerChanged,
            ),
            const SizedBox(height: 24),

            // Payment type
            Text(AppLocalizations.of(context).paymentTypeLower, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _PaymentTypeDropdown(
              payTypesAsync: payTypesAsync,
              selectedId: selectedPayTypeId,
              onChanged: onPayTypeChanged,
            ),
            const SizedBox(height: 24),

            // Amount + use balance
            Text(AppLocalizations.of(context).amount, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 110, // Wider amount field
                  child: TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    textAlign: TextAlign.right,
                    style: theme.textTheme.titleMedium,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ), // Taller touch target
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Transform.scale(
                        scale: 1.2, // Larger checkbox
                        child: Checkbox(
                          value: useCustomerBalance,
                          onChanged: (v) => onUseBalanceChanged(v ?? false),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: GestureDetector(
                          onTap: () => onUseBalanceChanged(!useCustomerBalance),
                          child: Text(
                            AppLocalizations.of(context).useCustomerBalance,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Automatic distribution
            Row(
              children: [
                Transform.scale(
                  scale: 1.1, // Larger switch
                  child: Switch(
                    value: automaticDistrib,
                    onChanged: onAutoChanged,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => onAutoChanged(!automaticDistrib),
                  child: Text(
                    AppLocalizations.of(context).automaticDistribution,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Load button
            OutlinedButton.icon(
              onPressed: canLoadDocs ? onLoadDocs : null,
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Icon(Icons.sync, size: 24),
              label: Text(
                AppLocalizations.of(context).loadUnpaidDocuments,
                style: const TextStyle(fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ],
        ),
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
  final int? selectedId;
  final void Function(int?) onChanged;

  const _CustomerDropdown({
    required this.customersAsync,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customers =
        customersAsync.asData?.value
            .where((c) => c.isCustomer && c.code != 'C000')
            .toList() ??
        [];

    return _StyledDropdown<int?>(
      value: selectedId,
      hint: Text(AppLocalizations.of(context).selectCustomerLower, style: const TextStyle(fontSize: 16)),
      items: customers
          .map(
            (c) => DropdownMenuItem<int?>(
              value: c.id,
              child: Text(
                c.name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _PaymentTypeDropdown extends StatelessWidget {
  final AsyncValue<List<PaymentType>> payTypesAsync;
  final int? selectedId;
  final void Function(int?) onChanged;

  const _PaymentTypeDropdown({
    required this.payTypesAsync,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payTypes =
        payTypesAsync.asData?.value.where((p) => p.isEnabled).toList() ?? [];

    final effectiveId =
        selectedId ?? (payTypes.isNotEmpty ? payTypes.first.id : null);

    return _StyledDropdown<int?>(
      value: effectiveId,
      items: payTypes
          .map(
            (p) => DropdownMenuItem<int?>(
              value: p.id,
              child: Text(
                p.name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final T value;
  final Widget? hint;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.outline),
    );

    return InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        border: border,
        enabledBorder: border,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ), // Taller touch target
      ),
      child: DropdownButton<T>(
        value: value,
        hint: hint,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        isDense: true,
        iconSize: 28, // Bigger dropdown arrow
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary header (right panel top)
// ---------------------------------------------------------------------------
const _kCyan = Color(0xFF0097A7);

class _SummaryHeader extends StatelessWidget {
  final String customerName;
  final double customerBalance;
  final double selectedTotal;
  final bool hasCustomer;
  final bool isAutomatic;

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
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Colored header bar
        Container(
          color: _kCyan,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            l.summaryLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        // Content
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          color: theme.colorScheme.surfaceContainerLow,
          child: hasCustomer
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.customerBalance,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    Text(
                      customerBalance.toStringAsFixed(2),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.totalInSelectedDocuments,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    Text(
                      isAutomatic ? '---' : selectedTotal.toStringAsFixed(2),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : const SizedBox(height: 120),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Content area (right panel body)
// ---------------------------------------------------------------------------
class _ContentArea extends StatelessWidget {
  final bool hasCustomer;
  final bool isAutomatic;
  final bool isLoading;
  final List<_UnpaidDoc> docs;
  final Set<int> selectedIds;
  final void Function(int) onRowToggle;
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
    final l = AppLocalizations.of(context);

    // No customer selected
    if (!hasCustomer) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 80,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              l.customerNotSelectedReconcile,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
              radius: 40,
              backgroundColor: _kCyan,
              child: Icon(Icons.info_outline, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              l.autoDistributeExplain,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    // Loading
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }

    // Empty state (loaded but no docs)
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              l.noUnpaidDocumentsForCustomer,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    // Table
    return _DocsTable(
      docs: docs,
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
  final List<_UnpaidDoc> docs;
  final Set<int> selectedIds;
  final void Function(int) onRowToggle;
  final void Function(bool?) onSelectAll;

  const _DocsTable({
    required this.docs,
    required this.selectedIds,
    required this.onRowToggle,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: _HeaderRow(
            allChecked:
                docs.isNotEmpty &&
                docs.every((d) => selectedIds.contains(d.id)),
            someChecked:
                !docs.every((d) => selectedIds.contains(d.id)) &&
                docs.any((d) => selectedIds.contains(d.id)),
            onSelectAll: onSelectAll,
          ),
        ),
        // Data rows
        Expanded(
          child: ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              final isSelected = selectedIds.contains(doc.id);
              return _DocRow(
                doc: doc,
                isSelected: isSelected,
                onToggle: () => onRowToggle(doc.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

const _kFlexNumber = 12;
const _kFlexDocType = 12;
const _kFlexDate = 10;
const _kFlexUser = 9;
const _kFlexTotal = 9;
const _kFlexBalance = 9;
const _kFlexCreated = 20;
const _kFlexIntNote = 11;
const _kFlexNote = 9;

Widget _col({required int flex, required Widget child}) => Expanded(
  flex: flex,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: child,
  ),
);

class _HeaderRow extends StatelessWidget {
  final bool allChecked;
  final bool someChecked;
  final void Function(bool?) onSelectAll;

  const _HeaderRow({
    required this.allChecked,
    required this.someChecked,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final style = theme.textTheme.titleSmall?.copyWith(
      color: _kCyan,
      fontWeight: FontWeight.bold,
      fontSize: 15, // Larger header font
    );

    Widget hdr(int flex, String label, {bool right = false}) => _col(
      flex: flex,
      child: Text(
        label,
        style: style,
        textAlign: right ? TextAlign.right : TextAlign.left,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12), // Fatter header row
      child: Row(
        children: [
          SizedBox(
            width: 60, // Wider checkbox area
            child: Transform.scale(
              scale: 1.2,
              child: Checkbox(
                value: allChecked ? true : (someChecked ? null : false),
                tristate: true,
                onChanged: onSelectAll,
              ),
            ),
          ),
          hdr(_kFlexNumber, l.numberLabel),
          hdr(_kFlexDocType, l.documentType),
          hdr(_kFlexDate, l.dateLabel),
          hdr(_kFlexUser, l.userLabel),
          hdr(_kFlexTotal, l.totalLabel, right: true),
          hdr(_kFlexBalance, l.balanceLabel, right: true),
          hdr(_kFlexCreated, l.created),
          hdr(_kFlexIntNote, l.internalNoteLabel),
          hdr(_kFlexNote, l.noteLabel),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final _UnpaidDoc doc;
  final bool isSelected;
  final VoidCallback onToggle;

  const _DocRow({
    required this.doc,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isSelected ? _kCyan.withValues(alpha: 0.15) : Colors.transparent;

    final s = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 15,
    ); // Larger row font

    return InkWell(
      onTap: onToggle,
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(vertical: 14), // Fatter rows
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Transform.scale(
                scale: 1.2,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => onToggle(),
                ),
              ),
            ),
            _col(
              flex: _kFlexNumber,
              child: Text(
                doc.number,
                style: s,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _col(
              flex: _kFlexDocType,
              child: Text(
                doc.documentTypeName ?? '',
                style: s?.copyWith(color: _kCyan),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _col(
              flex: _kFlexDate,
              child: Text(
                doc.dateStr,
                style: s,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _col(
              flex: _kFlexUser,
              child: Text(
                doc.userName ?? '',
                style: s,
                overflow: TextOverflow.ellipsis,
              ),
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
                      ? context.dangerColor
                      : context.successColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _col(
              flex: _kFlexCreated,
              child: Text(
                doc.dateCreatedStr,
                style: s,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _col(
              flex: _kFlexIntNote,
              child: Text(
                doc.internalNote ?? '',
                style: s,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _col(
              flex: _kFlexNote,
              child: Text(
                doc.note ?? '',
                style: s,
                overflow: TextOverflow.ellipsis,
              ),
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
  final bool hasCustomer;
  final bool isSubmitting;
  final VoidCallback onOk;
  final VoidCallback onCancel;

  const _ActionBar({
    required this.hasCustomer,
    required this.isSubmitting,
    required this.onOk,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 16,
      ), // Fatter footer
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton.icon(
            onPressed: hasCustomer && !isSubmitting ? onOk : null,
            icon: isSubmitting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: context.onStatusColor,
                    ),
                  )
                : const Icon(Icons.check, size: 24),
            label: Text(AppLocalizations.of(context).actionOk, style: const TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(
              backgroundColor: context.successColor,
              foregroundColor: context.onStatusColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 24),
            label: Text(AppLocalizations.of(context).actionCancel, style: const TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(
              backgroundColor: context.dangerColor,
              foregroundColor: context.onStatusColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
