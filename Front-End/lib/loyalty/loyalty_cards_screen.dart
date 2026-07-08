import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/loyalty/loyalty_card_model.dart';
import 'package:pos_app/loyalty/loyalty_card_provider.dart';
import 'package:pos_app/security/security_guard.dart';
import 'package:pos_app/security/security_keys.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class LoyaltyCardsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onMenuPressed;
  const LoyaltyCardsScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<LoyaltyCardsScreen> createState() =>
      _LoyaltyCardsScreenState();
}

class _LoyaltyCardsScreenState extends ConsumerState<LoyaltyCardsScreen> {
  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(allLoyaltyCardsProvider);
    final guard = ref.watch(securityGuardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.colorScheme.surface,
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onMenuPressed,
              )
            : null,
        title: const Text('Loyalty Cards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Loyalty Settings',
            onPressed: () => _showSettingsDialog(context),
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Card'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: () => guard.guard(
              context,
              SecurityKeys.loyaltyCards,
              () => _showAddDialog(context),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error loading loyalty cards: $e')),
        data: (cards) {
          final cs = theme.colorScheme;
          if (cards.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.card_giftcard,
                      size: 64,
                      color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No loyalty cards yet.',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _CardTile(
              card: cards[i],
              guard: guard,
              onEdit: () => _showEditDialog(context, cards[i]),
              onDelete: () => _showDeleteDialog(context, cards[i]),
              onQr: () => _showQrDialog(context, cards[i]),
            ),
          );
        },
      ),
    );
  }

  // ── Settings dialog ─────────────────────────────────────────────────────────

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _LoyaltySettingsDialog(),
    );
  }

  // ── Add dialog ──────────────────────────────────────────────────────────────

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _AddCardDialog(
        onSave: (customerId, cardNumber, points) async {
          try {
            await ref.read(loyaltyCardNotifierProvider.notifier).addCard(
                  customerId: customerId,
                  cardNumber: cardNumber.isEmpty ? null : cardNumber,
                  points: points,
                );
            if (mounted) {
              showAppSnackbar(context, ref, 'Loyalty card added');
            }
          } catch (e) {
            if (mounted) {
              showAppSnackbar(context, ref, 'Failed to add card: $e',
                  isError: true);
            }
          }
        },
      ),
    );
  }

  // ── Edit dialog ─────────────────────────────────────────────────────────────

  void _showEditDialog(BuildContext context, LoyaltyCard card) {
    showDialog(
      context: context,
      builder: (ctx) => _EditCardDialog(
        card: card,
        onSave: (cardNumber, points) async {
          try {
            await ref.read(loyaltyCardNotifierProvider.notifier).updateCard(
                  id: card.id,
                  cardNumber: cardNumber.isEmpty ? null : cardNumber,
                  points: points,
                );
            if (mounted) {
              showAppSnackbar(context, ref, 'Loyalty card updated');
            }
          } catch (e) {
            if (mounted) {
              showAppSnackbar(context, ref, 'Failed to update card: $e',
                  isError: true);
            }
          }
        },
      ),
    );
  }

  // ── Delete confirmation ──────────────────────────────────────────────────────

  void _showDeleteDialog(BuildContext context, LoyaltyCard card) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Delete Loyalty Card'),
        content: Text(
            'Delete the loyalty card for ${card.customerName}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(loyaltyCardNotifierProvider.notifier)
                    .deleteCard(card.id);
                if (mounted) {
                  showAppSnackbar(context, ref, 'Loyalty card deleted');
                }
              } catch (e) {
                if (mounted) {
                  showAppSnackbar(context, ref, 'Failed to delete: $e',
                      isError: true);
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── QR dialog ───────────────────────────────────────────────────────────────

  void _showQrDialog(BuildContext context, LoyaltyCard card) {
    final qrData = card.cardNumber ?? card.id.toString();
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(card.customerName),
        content: SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(data: qrData, size: 180),
              ),
              const SizedBox(height: 12),
              if (card.cardNumber != null)
                Text(card.cardNumber!,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Card tile ──────────────────────────────────────────────────────────────────

class _CardTile extends StatelessWidget {
  final LoyaltyCard card;
  final SecurityGuard guard;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onQr;

  const _CardTile({
    required this.card,
    required this.guard,
    required this.onEdit,
    required this.onDelete,
    required this.onQr,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPending = card.syncStatus != 'synced';

    return Card(
      color: Theme.of(context).cardColor,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Points badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                card.points.toInt().toString(),
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Customer + card number
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(card.customerName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (isPending)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('pending',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onTertiaryContainer)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.cardNumber ?? 'No card number',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.55),
                        fontSize: 13),
                  ),
                  Text(
                    '${card.points.toStringAsFixed(card.points % 1 == 0 ? 0 : 2)} pts',
                    style: TextStyle(
                        color: cs.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            // Actions
            IconButton(
              icon: Icon(Icons.qr_code,
                  color: cs.onSurface.withValues(alpha: 0.6)),
              tooltip: 'Show QR',
              onPressed: onQr,
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  color: cs.onSurface.withValues(alpha: 0.6)),
              tooltip: 'Edit',
              onPressed: () =>
                  guard.guard(context, SecurityKeys.loyaltyCards, onEdit),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: cs.error),
              tooltip: 'Delete',
              onPressed: () =>
                  guard.guard(context, SecurityKeys.loyaltyCards, onDelete),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add card dialog ────────────────────────────────────────────────────────────

class _AddCardDialog extends ConsumerStatefulWidget {
  final Future<void> Function(int customerId, String cardNumber, double points)
      onSave;

  const _AddCardDialog({required this.onSave});

  @override
  ConsumerState<_AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends ConsumerState<_AddCardDialog> {
  final _cardNumberCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController(text: '0');
  Customer? _selectedCustomer;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _cardNumberCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedCustomer == null) {
      setState(() => _error = 'Please select a customer.');
      return;
    }
    final points = double.tryParse(_pointsCtrl.text.trim()) ?? 0;
    if (points < 0) {
      setState(() => _error = 'Points cannot be negative.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
          _selectedCustomer!.id, _cardNumberCtrl.text.trim(), points);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(allCustomersProvider);
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: const Text('Add Loyalty Card'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Suppliers (isCustomer == false) are excluded from this list.
            customersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e',
                  style: TextStyle(color: cs.error, fontSize: 13)),
              data: (all) {
                final retailCustomers =
                    all.where((c) => c.isCustomer).toList();
                // The customers stream re-emits NEW Customer instances on every
                // change, so a stored _selectedCustomer becomes a stale object
                // that matches no item (Customer uses identity equality) — which
                // trips DropdownButton's "exactly one item" assertion. Resolve
                // the value to the current list's instance by id instead.
                final selected = _selectedCustomer == null
                    ? null
                    : retailCustomers
                        .where((c) => c.id == _selectedCustomer!.id)
                        .firstOrNull;
                return DropdownButtonFormField<Customer>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Customer *',
                    border: OutlineInputBorder(),
                  ),
                  items: retailCustomers
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.name,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCustomer = v),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cardNumberCtrl,
              decoration: const InputDecoration(
                labelText: 'Card Number',
                hintText: 'Leave blank to auto-assign',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pointsCtrl,
              decoration: const InputDecoration(
                labelText: 'Starting Points',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Add'),
        ),
      ],
    );
  }
}

// ── Edit card dialog ──────────────────────────────────────────────────────────

class _EditCardDialog extends StatefulWidget {
  final LoyaltyCard card;
  final Future<void> Function(String cardNumber, double points) onSave;

  const _EditCardDialog({required this.card, required this.onSave});

  @override
  State<_EditCardDialog> createState() => _EditCardDialogState();
}

class _EditCardDialogState extends State<_EditCardDialog> {
  late final TextEditingController _cardNumberCtrl;
  late final TextEditingController _pointsCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cardNumberCtrl =
        TextEditingController(text: widget.card.cardNumber ?? '');
    _pointsCtrl = TextEditingController(
        text: widget.card.points
            .toStringAsFixed(widget.card.points % 1 == 0 ? 0 : 2));
  }

  @override
  void dispose() {
    _cardNumberCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final points = double.tryParse(_pointsCtrl.text.trim());
    if (points == null || points < 0) {
      setState(() => _error = 'Enter a valid non-negative points value.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_cardNumberCtrl.text.trim(), points);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Text('Edit — ${widget.card.customerName}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _cardNumberCtrl,
              decoration: const InputDecoration(
                labelText: 'Card Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pointsCtrl,
              decoration: const InputDecoration(
                labelText: 'Points',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Loyalty Settings Dialog ───────────────────────────────────────────────────

class _LoyaltySettingsDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LoyaltySettingsDialog> createState() =>
      _LoyaltySettingsDialogState();
}

class _LoyaltySettingsDialogState extends ConsumerState<_LoyaltySettingsDialog> {
  late bool _enabled;
  late final TextEditingController _minAmountCtrl;
  late final TextEditingController _pointsPerThresholdCtrl;
  late final TextEditingController _pointValueCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(appSettingsProvider);
    _enabled = s[SettingKeys.loyaltyEnabled]?.toLowerCase() == 'true';
    _minAmountCtrl = TextEditingController(
        text: s[SettingKeys.loyaltyMinAmount] ?? '100');
    _pointsPerThresholdCtrl = TextEditingController(
        text: s[SettingKeys.loyaltyPointsPerThreshold] ?? '10');
    _pointValueCtrl = TextEditingController(
        text: s[SettingKeys.loyaltyPointValue] ?? '1.0');
  }

  @override
  void dispose() {
    _minAmountCtrl.dispose();
    _pointsPerThresholdCtrl.dispose();
    _pointValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final minAmt = double.tryParse(_minAmountCtrl.text.trim());
    final pts = double.tryParse(_pointsPerThresholdCtrl.text.trim());
    final val = double.tryParse(_pointValueCtrl.text.trim());
    if (minAmt == null || minAmt <= 0 || pts == null || pts <= 0 ||
        val == null || val <= 0) {
      showAppSnackbar(context, ref, 'All values must be positive numbers.',
          isError: true);
      return;
    }
    setState(() => _saving = true);
    final notifier = ref.read(appSettingsProvider.notifier);
    await notifier.set(SettingKeys.loyaltyEnabled, _enabled.toString());
    await notifier.set(SettingKeys.loyaltyMinAmount, minAmt.toString());
    await notifier.set(SettingKeys.loyaltyPointsPerThreshold, pts.toString());
    await notifier.set(SettingKeys.loyaltyPointValue, val.toString());
    if (mounted) {
      Navigator.pop(context);
      showAppSnackbar(context, ref, 'Loyalty settings saved');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: const Text('Loyalty Settings'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Loyalty Points'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const Divider(height: 24),
            // Earning rule
            Text('Earning Rule',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minAmountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Min. purchase amount',
                      border: OutlineInputBorder(),
                      suffixText: 'DH',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    enabled: _enabled,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('→', style: TextStyle(fontSize: 18)),
                ),
                Expanded(
                  child: TextField(
                    controller: _pointsPerThresholdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Points earned',
                      border: OutlineInputBorder(),
                      suffixText: 'pts',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    enabled: _enabled,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'e.g. every 100 DH spent earns 10 pts',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            // Redemption rule
            Text('Redemption Rule',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: _pointValueCtrl,
              decoration: const InputDecoration(
                labelText: '1 point equals',
                border: OutlineInputBorder(),
                suffixText: 'DH',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              enabled: _enabled,
            ),
            const SizedBox(height: 6),
            Text(
              'e.g. 1 pt = 1 DH discount at checkout',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
