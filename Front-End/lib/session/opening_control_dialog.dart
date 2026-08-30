import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/session/register_identity.dart';
import 'package:pos_app/session/session_provider.dart';

/// Odoo's **Opening Control**: confirm the float before the register trades.
///
/// 🚨 This step is not paperwork. Every expected-cash figure for the rest of the
/// day is `opening + …`, so a float nobody verified makes the closing count
/// meaningless — which is exactly why the lifecycle has a state for it rather
/// than jumping straight to OPENED.
class OpeningControlDialog extends ConsumerStatefulWidget {
  const OpeningControlDialog({super.key});

  /// Returns true when a session was opened.
  static Future<bool> show(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => const OpeningControlDialog(),
      ) ??
      false;

  @override
  ConsumerState<OpeningControlDialog> createState() =>
      _OpeningControlDialogState();
}

class _OpeningControlDialogState extends ConsumerState<OpeningControlDialog> {
  final _cash = TextEditingController(text: '0.00');
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cash.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    final userId = ref.read(currentUserProvider)?.id;
    // The REGISTER's uid, not this terminal's — that is what makes the session
    // joinable by a second device. Unset falls back to the device GUID, so an
    // install that never picked a register opens its own exactly as before.
    final uid = ref.read(registerUidProvider).value;
    if (companyId == null || userId == null || uid == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final opening =
          double.tryParse(_cash.text.trim().replaceAll(',', '.')) ?? 0;
      final notifier = ref.read(sessionNotifierProvider.notifier);
      final session = await notifier.openSession(
        companyId: companyId,
        userId: userId,
        deviceUid: uid,
        deviceName: await getRegisterName(),
        openingCash: opening,
      );
      // The float the operator just entered IS the opening control, so the
      // session goes straight to OPENED. The two states stay distinct in the
      // model because a session can also be opened by a sync from another
      // source, and that one has not been counted by anybody.
      await notifier.confirmOpening(
        localId: session.localId,
        countedOpeningCash: opening,
        openingNote: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sym = ref.watch(currencySymbolProvider);

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text(l.openingControl, style: theme.textTheme.titleMedium),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l.sessionOpeningCash} ($sym)',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            _AmountField(controller: _cash, autofocus: true),
            const SizedBox(height: 16),
            Text(l.openingNote, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l.openingNoteHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l.actionDiscard),
        ),
        FilledButton(
          onPressed: _busy ? null : _open,
          child: Text(l.openRegister),
        ),
      ],
    );
  }
}

/// Money input with the clear (✕) and coin affordances from the Odoo dialog.
class _AmountField extends StatefulWidget {
  const _AmountField({required this.controller, this.autofocus = false});

  final TextEditingController controller;
  final bool autofocus;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: widget.controller,
            autofocus: widget.autofocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: widget.controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .deleteButtonTooltip,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        widget.controller.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // The coin button: a deliberate "count it again from zero" reset, which
        // is what the Odoo affordance does. Kept because a cashier mis-typing a
        // float then correcting it digit by digit is how wrong opening balances
        // get entered.
        IconButton.filledTonal(
          tooltip: '0.00',
          onPressed: () {
            widget.controller.text = '0.00';
            setState(() {});
          },
          icon: Icon(Icons.savings_outlined,
              size: 20, color: theme.colorScheme.primary),
        ),
      ],
    );
  }
}
