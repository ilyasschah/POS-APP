import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/cash/cash_movement_kind.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/core/ilyass_screen.dart';
import 'package:pos_app/session/session_gate.dart';
import 'package:pos_app/session/session_summary_provider.dart';
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/navigation/nav_widgets.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

/// Offline-first stream of today's cash movements straight from the local
/// `starting_cash` table. New saves appear instantly and the list works fully
/// offline; the sync engine pulls other tills' rows into the same table.
final _cashEntriesProvider =
    StreamProvider.autoDispose<List<StartingCashTableData>>((ref) {
      final companyId = ref.watch(selectedCompanyProvider)?.id;
      if (companyId == null) return Stream.value(const []);

      final db = ref.watch(appDatabaseProvider);
      return db.watchTodayStartingCash(companyId);
    });

// ── Screen ────────────────────────────────────────────────────────────────────

/// Cash In / Cash Out — an Ilyass Screen (`lib/core/ilyass_screen.dart`).
///
/// It is a sidebar TAB, so it opens inside the shell with a hamburger instead
/// of landing on top of it behind a back arrow. It is also the one screen the
/// shell can still push as a route (`Cash.ShowOnStart` opens it over login),
/// which is exactly why the leading control is [IlyassLeading]'s decision and
/// not this screen's.
class CashMovementScreen extends ConsumerStatefulWidget {
  /// Opens the POS navigation drawer. Supplied by MainLayout when this is the
  /// active tab; null when pushed as a standalone route, which is what turns
  /// the hamburger into a back arrow.
  final VoidCallback? onMenuPressed;

  const CashMovementScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<CashMovementScreen> createState() => _CashMovementScreenState();
}

class _CashMovementScreenState extends ConsumerState<CashMovementScreen> {
  int _type = 0; // 0 = Cash In (Add), 1 = Cash Out (Remove)
  final _amountCtrl = TextEditingController(text: '0');
  final _descCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  // Was `static final`, which made the company's date format unreachable —
  // a static has no `ref`. See the note in sales_history_screen.dart.
  DateFormat get _dtFmt => ref.watch(appDateFormatProvider).dateTimeSeconds;
  static final _numFmt = NumberFormat('#,##0.00');

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(
        () => _error = AppLocalizations.of(context).enterValidAmountAboveZero,
      );
      return;
    }

    final company = ref.read(selectedCompanyProvider);
    final user = ref.read(currentUserProvider);
    if (company == null || user == null) {
      setState(
        () => _error = AppLocalizations.of(context).missingCompanyOrUserContext,
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // OFFLINE WRITE: persist locally as `pending`. The sync engine flushes
      // to /StartingCash/Add when network is available. The entries list is a
      // live stream off the local table, so the new row appears instantly —
      // no network round-trip and no manual invalidation needed.
      // Cash in/out moves the drawer, so it belongs to a session — same rule
      // as a sale, and what makes the movement reconcilable at closing.
      if (!await SessionGuard.ensureCanSell(context, ref)) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      if (!mounted) return;

      final db = ref.read(appDatabaseProvider);
      await db.insertOfflineCashMovement(
        StartingCashTableCompanion.insert(
          localId: '', // helper fills a UUID when blank
          companyId: company.id,
          userId: user.id,
          amount: amount,
          type: _type == 0 ? CashMovementKind.cashIn : CashMovementKind.cashOut,
          note: Value(
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          ),
          createdAt: DateTime.now().toUtc(),
          // Bind the movement to the session that was trading. The drawer only
          // moves during a session, so this is what makes it reconcilable —
          // and it replaces the legacy `ZReportNumber`, which was company-wide
          // and could not tell two registers apart.
          sessionLocalId: Value(
            ref.read(activeSessionRowProvider).value?.localId,
          ),
        ),
      );
      _amountCtrl.text = '0';
      _descCtrl.clear();
      setState(() => _saving = false);

      // Return to the main shell once the row is persisted.
      _leaveToShell();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  /// Hands control back once the movement is recorded.
  ///
  /// Which way "back" is depends on how the screen was mounted, and
  /// [ilyassLeave] is what decides: it pops when this was pushed over the shell
  /// (`Cash.ShowOnStart` on login), and switches the shell to the POS tab when
  /// this IS the shell — there is nothing to pop off a tab, and the old code
  /// covered that case by pushing a whole second MainLayout.
  void _leaveToShell() {
    if (!mounted) return;
    ilyassLeave(
      context,
      onReturnToShell: () =>
          ref.read(mainNavigationIndexProvider.notifier).state = PosTab.pos,
    );
  }

  // "Cancel" abandons the cash movement and returns to the POS. It previously
  // only reset the fields, which read as a dead button on the after-login
  // launch where the user expects Cancel to close the screen and move on.
  void _cancel() => _leaveToShell();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entries = ref.watch(_cashEntriesProvider);

    final isCashIn = _type == 0;
    // Adaptive accent: POS primary for "add", semantic error for "remove".
    final accent = isCashIn ? context.navAccent : cs.error;
    final onAccent = isCashIn ? cs.onPrimary : cs.onError;

    return IlyassScreen(
      title: AppLocalizations.of(context).cashInOut,
      onMenuPressed: widget.onMenuPressed,
      // A form, not a table: capped so a 24-inch till does not stretch two
      // fields across a metre of glass.
      maxContentWidth: 480,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Type selector ─────────────────────────────────────
            Row(
              children: [
                _TypeButton(
                  label: AppLocalizations.of(context).addCash,
                  icon: Icons.arrow_downward_rounded,
                  selected: isCashIn,
                  activeColor: context.navAccent,
                  activeForeground: cs.onPrimary,
                  onTap: () => setState(() => _type = 0),
                ),
                const SizedBox(width: 4),
                _TypeButton(
                  label: AppLocalizations.of(context).removeCash,
                  icon: Icons.arrow_upward_rounded,
                  selected: !isCashIn,
                  activeColor: cs.error,
                  activeForeground: cs.onError,
                  onTap: () => setState(() => _type = 1),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Amount ────────────────────────────────────────────
            Text(
              AppLocalizations.of(context).amount,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onTap: () {
                if (_amountCtrl.text == '0') _amountCtrl.clear();
              },
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: cs.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Description ───────────────────────────────────────
            Text(
              AppLocalizations.of(context).description,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).cashReasonHint,
                hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                contentPadding: const EdgeInsets.all(12),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: cs.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: accent, width: 2),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
            ],

            const SizedBox(height: 24),

            // ── Cash entries list ─────────────────────────────────
            entries.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text(
                AppLocalizations.of(context).couldNotLoadEntries(e.toString()),
                style: TextStyle(color: cs.error, fontSize: 12),
              ),
              data: (rows) {
                // Resolve user ids → names from the local users
                // cache so pulled rows from other tills show a name.
                final users =
                    ref.watch(allUsersProvider).asData?.value ?? const [];
                String nameFor(int uid) {
                  for (final u in users) {
                    if (u.id == uid) {
                      final full = [u.firstName, u.lastName]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' ')
                          .trim();
                      return full.isEmpty
                          ? (u.username ??
                                AppLocalizations.of(
                                  context,
                                ).userNumbered('$uid'))
                          : full;
                    }
                  }
                  return AppLocalizations.of(context).userNumbered('$uid');
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(
                        context,
                      ).cashEntriesCount(rows.length),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (rows.isEmpty)
                      Text(
                        AppLocalizations.of(context).noCashMovementsToday,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      )
                    else
                      ...rows.map(
                        (r) => _EntryTile(
                          row: r,
                          userName: nameFor(r.userId),
                          dtFmt: _dtFmt,
                          numFmt: _numFmt,
                        ),
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),

      // ── Action buttons (pinned to bottom) ─────────────────────────────────
      //
      // The bar itself is full-bleed so its divider reads as the edge of the
      // screen; only its contents sit inside the same 480px column as the form
      // above, so the buttons line up with the fields they commit.
      footer: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: context.navScaffoldBg,
          border: Border(top: BorderSide(color: context.navDivider)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _cancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(AppLocalizations.of(context).actionCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: onAccent,
                            ),
                          )
                        : Text(
                            isCashIn
                                ? AppLocalizations.of(context).saveCashIn
                                : AppLocalizations.of(context).saveCashOut,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
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

// ── Type selector button ──────────────────────────────────────────────────────

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final Color activeForeground;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.activeForeground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bg = selected ? activeColor : cs.surfaceContainerHighest;
    final fg = selected ? activeForeground : cs.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single entry row ──────────────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  final StartingCashTableData row;
  final String userName;
  final DateFormat dtFmt;
  final NumberFormat numFmt;

  const _EntryTile({
    required this.row,
    required this.userName,
    required this.dtFmt,
    required this.numFmt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCashOut = row.type == CashMovementKind.cashOut;
    // The opening float is in the ledger but is NOT a movement during the
    // shift: it is where the drawer started. Rendering it as a cash-in — which
    // is what "anything that is not `out`" did — would have it read as money
    // somebody added mid-shift, and read as counted twice by anyone adding the
    // column up by eye.
    final isOpening = row.type == CashMovementKind.opening;
    final color = isCashOut
        ? cs.error
        : isOpening
        ? cs.onSurfaceVariant
        : context.navAccent;
    final sign = isCashOut ? '-' : '+';
    final desc = row.note?.isNotEmpty == true
        ? row.note!
        : isOpening
        ? AppLocalizations.of(context).sessionOpeningCash
        : (isCashOut
              ? AppLocalizations.of(context).cashOut
              : AppLocalizations.of(context).cashIn);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isOpening
                ? Icons.savings_outlined
                : isCashOut
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sign${numFmt.format(row.amount)} / $desc',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$userName @ ${dtFmt.format(row.createdAt.toLocal())}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
