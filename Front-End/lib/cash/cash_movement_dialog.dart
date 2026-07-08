import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';

Future<void> showCashMovementDialog(BuildContext context, WidgetRef ref) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CashMovementDialog(),
  );
}

class _CashMovementDialog extends ConsumerStatefulWidget {
  const _CashMovementDialog();

  @override
  ConsumerState<_CashMovementDialog> createState() =>
      _CashMovementDialogState();
}

class _CashMovementDialogState extends ConsumerState<_CashMovementDialog> {
  int _type = 0; // 0 = Cash In, 1 = Cash Out
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount greater than zero.');
      return;
    }

    final company = ref.read(selectedCompanyProvider);
    final user = ref.read(currentUserProvider);
    if (company == null || user == null) {
      setState(() => _error = 'Missing company or user context.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // OFFLINE WRITE (Phase 7): persist locally as `pending`, then close
      // the dialog. The connectivity watcher / manual sync button will push
      // this to /StartingCash/Add when the network is available.
      final db = ref.read(appDatabaseProvider);
      await db.insertOfflineCashMovement(
        StartingCashTableCompanion.insert(
          localId: '', // helper fills a UUID when blank
          companyId: company.id,
          userId: user.id,
          amount: amount,
          type: _type == 0 ? 'in' : 'out',
          note: Value(_descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim()),
          createdAt: DateTime.now().toUtc(),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCashIn = _type == 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Cash Movement',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Type toggle
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Cash In'),
                  icon: Icon(Icons.add_circle_outline),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Cash Out'),
                  icon: Icon(Icons.remove_circle_outline),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return isCashIn ? Colors.green : theme.colorScheme.error;
                  }
                  return null;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return null;
                }),
              ),
            ),
            const SizedBox(height: 20),

            // Amount
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(
                  isCashIn ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isCashIn ? Colors.green : theme.colorScheme.error,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. wifi bill, pre started',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 2,
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(
                      color: theme.colorScheme.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor:
                isCashIn ? Colors.green : theme.colorScheme.error,
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(isCashIn ? 'Save Cash In' : 'Save Cash Out'),
        ),
      ],
    );
  }
}
