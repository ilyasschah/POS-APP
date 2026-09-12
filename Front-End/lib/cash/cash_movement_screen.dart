import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/cash/cash_movement_kind.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/core/ilyass_screen.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/session/session_gate.dart';
import 'package:pos_app/session/session_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

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

/// Raised by MainLayout when `Cash.ShowOnStart` lands the operator on this tab
/// after login. The tab then opens on the entry FORM instead of the ledger, and
/// finishing it — Save or Cancel — carries on to the POS, as the after-login
/// step always has. Consumed on first read, so the next visit shows the ledger.
final cashEntryOnStartProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────

/// Cash In / Cash Out — an Ilyass Screen (`lib/core/ilyass_screen.dart`).
///
/// A sidebar TAB with two faces:
///  * the **ledger** — today's movements as an [IlyassTable], with a floating
///    money button to record a new one;
///  * the **entry form** — reached ONLY from that button, or from the
///    after-login step ([cashEntryOnStartProvider]).
///
/// The form is a state of the tab, not a pushed route: a sidebar destination
/// is never pushed, and so Cancel here cancels the work instead of having to
/// navigate anywhere.
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
  /// Ledger (false) or entry form (true).
  bool _composing = false;

  /// Whether the form was opened by the after-login step — that decides where
  /// finishing it goes.
  bool _fromStartup = false;

  int _type = 0; // 0 = Cash In (Add), 1 = Cash Out (Remove)
  final _amountCtrl = TextEditingController(text: '0');
  final _descCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  static final _numFmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    // MainLayout raises the flag BEFORE it switches to this tab, so the first
    // build already knows. A tab that is already mounted hears it through the
    // listener in build instead.
    if (ref.read(cashEntryOnStartProvider)) _beginStartupEntry();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _beginStartupEntry() {
    _composing = true;
    _fromStartup = true;
    _resetForm();
    // Consumed, so the next visit opens on the ledger. Deferred: a provider
    // cannot be written while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(cashEntryOnStartProvider.notifier).state = false;
    });
  }

  /// The floating button.
  void _openEntry() => setState(() {
    _composing = true;
    _fromStartup = false;
    _resetForm();
  });

  void _resetForm() {
    _type = 0;
    _amountCtrl.text = '0';
    _descCtrl.clear();
    _error = null;
    _saving = false;
  }

  /// Closes the form — after a save, or on Cancel, which cancels the WORK.
  ///
  /// From the floating button that means back to the ledger, where a saved row
  /// is now on top. From the after-login step it carries on to the POS:
  /// [ilyassLeave] pops if this was pushed, and otherwise switches the tab.
  void _finishEntry() {
    if (!mounted) return;
    final fromStartup = _fromStartup;
    setState(() {
      _composing = false;
      _fromStartup = false;
      _resetForm();
    });
    if (fromStartup) {
      ilyassLeave(
        context,
        onReturnToShell: () =>
            ref.read(mainNavigationIndexProvider.notifier).state = PosTab.pos,
      );
    }
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
      // to /StartingCash/Add when network is available. The ledger is a live
      // stream off the local table, so the new row appears instantly — no
      // network round-trip and no manual invalidation needed.
      // Cash in/out moves the drawer, so it belongs to a session — same rule
      // as a sale, and what makes the movement reconcilable at closing.
      if (!await SessionGuard.ensureCanSell(context, ref)) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      if (!mounted) return;

      // Awaited, not `.value`: the session the gate just approved. build()
      // watches the provider, so this resolves at once; the timeout only
      // guards a stream that never answers — a movement is money that already
      // moved, so it is saved unattached rather than not saved at all.
      final session = await ref
          .read(activeSessionProvider.future)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
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
          sessionLocalId: Value(session?.localId),
        ),
      );
      _finishEntry();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the session stream LISTENED while this screen is up. An unlistened
    // provider is paused, so Save's awaited read would never complete — and a
    // plain `.value` read there is how movements got stamped with no session.
    ref.watch(activeSessionProvider);
    ref.listen<bool>(cashEntryOnStartProvider, (_, next) {
      if (next && !_composing) setState(_beginStartupEntry);
    });
    return _composing ? _buildEntry(context) : _buildLedger(context);
  }

  // ── Ledger ────────────────────────────────────────────────────────────────

  /// How one ledger row reads: its kind, icon, colour and sign.
  ///
  /// The opening float is in the ledger but is NOT a movement during the
  /// session — it is where the drawer started. Drawn as a cash-in it would read
  /// as money somebody added mid-shift, and as counted twice by anyone adding
  /// the column up by eye; so it is neutral and unsigned.
  ({String label, IconData icon, Color color, String sign}) _kind(
    BuildContext context,
    StartingCashTableData row,
  ) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    if (row.type == CashMovementKind.cashOut) {
      return (
        label: l.cashOut,
        icon: Icons.arrow_upward_rounded,
        color: cs.error,
        sign: '-',
      );
    }
    if (row.type == CashMovementKind.opening) {
      return (
        label: l.sessionOpeningCash,
        icon: Icons.savings_outlined,
        color: cs.onSurfaceVariant,
        sign: '',
      );
    }
    return (
      label: l.cashIn,
      icon: Icons.arrow_downward_rounded,
      color: context.navAccent,
      sign: '+',
    );
  }

  Widget _buildLedger(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dates = ref.watch(appDateFormatProvider);
    final entries = ref.watch(_cashEntriesProvider);

    // Resolve user ids → names from the local users cache so rows pulled from
    // other tills show a name.
    final users = ref.watch(allUsersProvider).asData?.value ?? const [];
    String nameFor(int uid) {
      for (final u in users) {
        if (u.id == uid) {
          final full = [u.firstName, u.lastName]
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .join(' ')
              .trim();
          return full.isEmpty ? (u.username ?? l.userNumbered('$uid')) : full;
        }
      }
      return l.userNumbered('$uid');
    }

    final columns = <IlyassColumn<StartingCashTableData>>[
      IlyassColumn(
        key: 'time',
        label: l.dateTimeLabel,
        width: 170,
        cell: (_, r) => Text(
          dates.stamp(r.createdAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      IlyassColumn(
        key: 'type',
        label: l.typeLabel,
        width: 170,
        cell: (context, r) {
          final k = _kind(context, r);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(k.icon, size: 18, color: k.color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  k.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: k.color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
      IlyassColumn(
        key: 'description',
        label: l.description,
        width: 240,
        flexible: true,
        cell: (_, r) => Text(
          r.note?.trim().isNotEmpty == true ? r.note!.trim() : '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      IlyassColumn(
        key: 'user',
        label: l.userLabel,
        width: 170,
        cell: (_, r) => Text(
          nameFor(r.userId),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      IlyassColumn(
        key: 'amount',
        label: l.amount,
        width: 140,
        numeric: true,
        cell: (context, r) {
          final k = _kind(context, r);
          return Text(
            '${k.sign}${_numFmt.format(r.amount)}',
            style: TextStyle(color: k.color, fontWeight: FontWeight.bold),
          );
        },
      ),
    ];

    final count = entries.value?.length ?? 0;

    return IlyassScreen(
      title: l.cashInOut,
      onMenuPressed: widget.onMenuPressed,
      trailing: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text(
              l.cashEntriesCount(count),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        // 🚨 A tag of its own: MainLayout keeps every visited tab mounted, and
        // two FABs on the default tag throw "multiple heroes share the same
        // tag" on every route animation.
        heroTag: 'cash-movement-new',
        onPressed: _openEntry,
        icon: const Icon(Icons.payments_outlined),
        label: Text(l.newCashMovement),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            l.couldNotLoadEntries(e.toString()),
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (rows) => IlyassTable<StartingCashTableData>(
          tableId: 'cashMovements',
          columns: columns,
          rows: rows,
          emptyState: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 56,
                  color: cs.onSurface.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 12),
                Text(
                  l.noCashMovementsToday,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Entry form ────────────────────────────────────────────────────────────

  Widget _buildEntry(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final isCashIn = _type == 0;
    // Adaptive accent: POS primary for "add", semantic error for "remove".
    final accent = isCashIn ? context.navAccent : cs.error;
    final onAccent = isCashIn ? cs.onPrimary : cs.onError;

    return IlyassScreen(
      title: l.cashInOut,
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
                  label: l.addCash,
                  icon: Icons.arrow_downward_rounded,
                  selected: isCashIn,
                  activeColor: context.navAccent,
                  activeForeground: cs.onPrimary,
                  onTap: () => setState(() => _type = 0),
                ),
                const SizedBox(width: 4),
                _TypeButton(
                  label: l.removeCash,
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
              l.amount,
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
              l.description,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l.cashReasonHint,
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
                    onPressed: _saving ? null : _finishEntry,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(l.actionCancel),
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
                            // Disabled while saving: the neutral fill.
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onSurfaceVariant,
                            ),
                          )
                        : Text(
                            isCashIn ? l.saveCashIn : l.saveCashOut,
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
