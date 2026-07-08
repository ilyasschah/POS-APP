import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/loyalty/loyalty_card_provider.dart';

/// Searchable customer picker. Returns the selected [Customer] on pop,
/// or null if the user cancelled. Search filters on name, phone and
/// loyalty card number simultaneously using offline data only.
///
/// Usage:
/// ```dart
/// final selected = await showCustomerPickerDialog(context, customers);
/// if (selected != null) { ... }
/// ```
Future<Customer?> showCustomerPickerDialog(
  BuildContext context,
  List<Customer> customers, {
  int? selectedId,
}) {
  return showDialog<Customer>(
    context: context,
    builder: (_) => CustomerPickerDialog(
      customers: customers,
      selectedId: selectedId,
    ),
  );
}

class CustomerPickerDialog extends ConsumerStatefulWidget {
  final List<Customer> customers;
  final int? selectedId;

  const CustomerPickerDialog({
    super.key,
    required this.customers,
    this.selectedId,
  });

  @override
  ConsumerState<CustomerPickerDialog> createState() =>
      _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends ConsumerState<CustomerPickerDialog> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Build a quick customerId → cardNumber lookup for card-number search.
    final cardsByCustomerId = <int, String>{};
    ref.watch(allLoyaltyCardsProvider).asData?.value.forEach((c) {
      if (c.cardNumber != null) cardsByCustomerId[c.customerId] = c.cardNumber!;
    });

    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? widget.customers
        : widget.customers
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                (c.phoneNumber?.toLowerCase().contains(q) == true) ||
                (cardsByCustomerId[c.id]?.toLowerCase().contains(q) == true))
            .toList();

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: const Text('Select Customer'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 400,
        height: 480,
        child: Column(
          children: [
            // ── Search field ──────────────────────────────────────────────
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search name, phone or card number…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            // ── Result count ──────────────────────────────────────────────
            if (_query.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            // ── List ──────────────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No customers found',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5)),
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: cs.outlineVariant),
                        itemBuilder: (_, i) {
                          final cu = filtered[i];
                          final isSelected = cu.id == widget.selectedId;
                          final cardNum = cardsByCustomerId[cu.id];
                          final subtitle = [
                            if (cu.phoneNumber?.isNotEmpty == true)
                              cu.phoneNumber!,
                            if (cardNum != null) 'Card: $cardNum',
                          ].join('  •  ');

                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isSelected
                                  ? cs.primary
                                  : cs.surfaceContainerHighest,
                              child: Icon(
                                Icons.person,
                                size: 16,
                                color: isSelected
                                    ? cs.onPrimary
                                    : cs.onSurface,
                              ),
                            ),
                            title: Text(
                              cu.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: subtitle.isNotEmpty
                                ? Text(
                                    subtitle,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          cs.onSurface.withValues(alpha: 0.6),
                                    ),
                                  )
                                : null,
                            selected: isSelected,
                            selectedTileColor:
                                cs.primary.withValues(alpha: 0.08),
                            onTap: () => Navigator.pop(context, cu),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }
}

/// Convenience mixin — wire into any ConsumerStatefulWidget that has a
/// customer-select button. Handles the full pick+assign flow in one call.
mixin CustomerPickerMixin on ConsumerState {
  Future<void> pickAndSetCustomer(
    BuildContext context,
    List<Customer> customers,
  ) async {
    final current = ref.read(cartProvider).selectedCustomer;
    final selected = await showCustomerPickerDialog(
      context,
      customers,
      selectedId: current?.id,
    );
    if (selected == null || !context.mounted) return;
    final companyId = ref.read(selectedCompanyProvider)?.id;
    ref.read(currentCustomerProvider.notifier).setCustomer(selected);
    if (companyId != null) {
      ref.read(cartProvider.notifier).setCustomer(companyId, selected);
    }
  }
}
