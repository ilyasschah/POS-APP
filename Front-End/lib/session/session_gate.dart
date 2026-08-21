import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/session/opening_control_dialog.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/session/session_provider.dart';

/// Why the register may or may not trade right now.
enum SessionGate {
  /// A session is OPENED. Sell.
  allowed,

  /// We positively know there is no open session on this register.
  blockedNoSession,

  /// The session is live but not trading — OPENING_CONTROL (float not
  /// confirmed) or CLOSING_CONTROL (drawer being counted).
  blockedNotTrading,

  /// 🚨 We could not determine the state — the device id or company is still
  /// loading, or something failed. **This ALLOWS selling.** See the note on
  /// [sessionGateProvider]: a register that cannot answer the question must
  /// never be the reason a shop stops taking money.
  unknown,
}

/// Whether this register may take money, and why not if it may not.
///
/// 🚨 **Fails OPEN, deliberately, and this is the most important line in the
/// file.** The rule being enforced ("no sale without an open session") gates the
/// first action of every day. If the gate answered "no" whenever it was unsure —
/// device id still resolving, company not loaded, a Drift hiccup — then a
/// transient fault would stop a shop trading, which is far worse than the
/// bookkeeping gap the rule exists to close. So only a POSITIVE "there is no
/// open session here" blocks; everything else lets the sale through and the
/// server's fail-open `ResolveOpenSessionAsync` banks it unattached.
///
/// The second safety valve is `PosSession.RequireOpenSession`: turning it off in
/// Settings restores trading instantly if session state is ever wrong on a real
/// till. A gate on the money path needs a way out that does not require a
/// developer.
final sessionGateProvider = Provider<SessionGate>((ref) {
  final settings = ref.watch(appSettingsProvider);
  final enforced =
      (settings[SettingKeys.requireOpenSession] ?? 'true').toLowerCase() !=
          'false';
  if (!enforced) return SessionGate.allowed;

  // Cannot determine → allow. Never block on missing context.
  if (ref.watch(selectedCompanyProvider) == null) return SessionGate.unknown;
  final uid = ref.watch(deviceUidProvider);
  if (uid.value == null) return SessionGate.unknown;

  final async = ref.watch(activeSessionProvider);
  if (async.isLoading || async.hasError) return SessionGate.unknown;

  final session = async.value;
  if (session == null) return SessionGate.blockedNoSession;
  return PosSessionStatus.canSell(session.status)
      ? SessionGate.allowed
      : SessionGate.blockedNotTrading;
});

/// True when money may move. `unknown` counts as allowed — see above.
final canSellProvider2 = Provider<bool>((ref) {
  final gate = ref.watch(sessionGateProvider);
  return gate == SessionGate.allowed || gate == SessionGate.unknown;
});

/// Guards a money action (checkout, refund, cash movement).
///
/// Returns true when the caller may proceed. When it blocks, it explains why
/// and offers the way forward — opening the register — rather than a bare
/// refusal the cashier cannot act on.
class SessionGuard {
  const SessionGuard._();

  static Future<bool> ensureCanSell(BuildContext context, WidgetRef ref) async {
    final gate = ref.read(sessionGateProvider);
    if (gate == SessionGate.allowed || gate == SessionGate.unknown) return true;

    final l = AppLocalizations.of(context);
    final openNow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.lock_outline,
            color: Theme.of(ctx).colorScheme.primary, size: 30),
        title: Text(l.sessionRequiredTitle),
        content: Text(gate == SessionGate.blockedNotTrading
            ? l.sessionNotTradingBody
            : l.sessionRequiredBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.actionCancel),
          ),
          // Only offer to open when there is nothing live. A session in
          // CLOSING_CONTROL must be finished, not opened over the top.
          if (gate == SessionGate.blockedNoSession)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.openRegister),
            ),
        ],
      ),
    );

    if (openNow != true || !context.mounted) return false;
    return OpeningControlDialog.show(context);
  }
}

/// Full-screen block for the POS menu — actionable, never a dead end.
class SessionBlockedScreen extends ConsumerWidget {
  const SessionBlockedScreen({super.key, required this.gate});

  final SessionGate gate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final notTrading = gate == SessionGate.blockedNotTrading;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.point_of_sale_outlined,
                    size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(l.sessionRequiredTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 10),
                Text(
                  notTrading ? l.sessionNotTradingBody : l.sessionRequiredBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                if (!notTrading)
                  FilledButton.icon(
                    onPressed: () => OpeningControlDialog.show(context),
                    icon: const Icon(Icons.lock_open),
                    label: Text(l.openRegister),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
