import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/session/opening_control_dialog.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/session/register_identity.dart';
import 'package:pos_app/session/session_list_screen.dart';
import 'package:pos_app/session/session_provider.dart';
import 'package:pos_app/session/session_screen.dart';

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
/// 🚨 **Every dependency below is `.select`ed to the one fact it contributes,
/// and that is load-bearing, not tidiness.**
///
/// `appSettingsProvider` hands out a fresh `Map` on every rebuild, and a `Map`
/// has no value equality — so a plain `ref.watch(appSettingsProvider)` made this
/// gate **invalidate on every settings change in the app**: a theme toggle, a
/// printer name, a language, a COM port. Same for the whole `Company` object,
/// and for the session ROW, which Drift re-emits on every sale.
///
/// The invalidation alone is the damage, and it needs no change in the answer.
/// `appSettingsProvider` is a `Notifier` that gets marked dirty and flushed
/// **lazily, inside a widget build** — so the first widget to watch this gate
/// would flush settings, get a fresh map, and the gate would invalidate itself
/// mid-build. Riverpod turns that into `setState() called during build`,
/// reported against whatever widget happened to be building at the time
/// (`BrowserSection`, in the crash that prompted this) — an exception with no
/// visible connection to sessions at all.
///
/// ⚠️ **A value listener cannot see this, which is why it survived so long.**
/// The gate recomputes to the same enum, so `container.listen` stays silent and
/// so does `ProviderObserver.didUpdateProvider`. What `test/session_gate_test.dart`
/// can pin is the visible half — `registerUidProvider` re-running on every
/// unrelated write — plus the answers themselves, so the narrowing cannot
/// quietly change what a gate on the money path says.
final sessionGateProvider = Provider<SessionGate>((ref) {
  final enforced = ref.watch(
    appSettingsProvider.select(
      (s) =>
          (s[SettingKeys.requireOpenSession] ?? 'true').toLowerCase() != 'false',
    ),
  );
  if (!enforced) return SessionGate.allowed;

  // Cannot determine → allow. Never block on missing context.
  final hasCompany =
      ref.watch(selectedCompanyProvider.select((c) => c != null));
  if (!hasCompany) return SessionGate.unknown;

  final hasRegister =
      ref.watch(registerUidProvider.select((a) => a.value != null));
  if (!hasRegister) return SessionGate.unknown;

  // One record rather than the row: the gate reads exactly two things from the
  // session, and a record compares by value — so a sale that bumps the
  // session's figures no longer rebuilds the gate.
  final session = ref.watch(
    activeSessionProvider.select(
      (a) => (
        undetermined: a.isLoading || a.hasError,
        status: a.value?.status,
      ),
    ),
  );
  if (session.undetermined) return SessionGate.unknown;
  if (session.status == null) return SessionGate.blockedNoSession;
  return PosSessionStatus.canSell(session.status!)
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
    // A session already open on another till. Offering it FIRST matters: the
    // wrong move here is cheap to make and expensive to undo — a second session
    // on a drawer that already has one splits one day's cash across two
    // Z-reports that no count can reconcile afterwards.
    final joinable = notTrading
        ? const <ShiftsTableData>[]
        : (ref.watch(joinableSessionsProvider).value ?? const []);

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
                if (joinable.isNotEmpty) ...[
                  Text(
                    l.sessionJoinOpenElsewhere,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 12),
                  // Straight to the session when there is only one — the extra
                  // list screen would be a menu of one. Several tills means a
                  // real choice, and choosing the wrong drawer is the mistake
                  // this whole screen is trying to prevent.
                  FilledButton.icon(
                    onPressed: () => joinable.length == 1
                        ? SessionScreen.showFor(context, joinable.first)
                        : SessionListScreen.show(context),
                    icon: const Icon(Icons.login),
                    label: Text(l.sessionJoinRegister),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (!notTrading)
                  // Demoted to an outline once there is a session to join: both
                  // are still one tap, but only one of them is usually right.
                  (joinable.isEmpty
                      ? FilledButton.icon(
                          onPressed: () => OpeningControlDialog.show(context),
                          icon: const Icon(Icons.lock_open),
                          label: Text(l.openRegister),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => OpeningControlDialog.show(context),
                          icon: const Icon(Icons.lock_open),
                          label: Text(l.openRegister),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
