import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
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

class CashMovementScreen extends ConsumerStatefulWidget {
  const CashMovementScreen({super.key});

  @override
  ConsumerState<CashMovementScreen> createState() => _CashMovementScreenState();
}

class _CashMovementScreenState extends ConsumerState<CashMovementScreen> {
  int _type = 0; // 0 = Cash In (Add), 1 = Cash Out (Remove)
  final _amountCtrl = TextEditingController(text: '0');
  final _descCtrl   = TextEditingController();
  bool   _saving    = false;
  String? _error;

  static final _dtFmt = DateFormat('dd/MM/yyyy HH:mm:ss');
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
      setState(() => _error = 'Enter a valid amount greater than zero.');
      return;
    }

    final company = ref.read(selectedCompanyProvider);
    final user    = ref.read(currentUserProvider);
    if (company == null || user == null) {
      setState(() => _error = 'Missing company or user context.');
      return;
    }

    setState(() {
      _saving = true;
      _error  = null;
    });

    try {
      // OFFLINE WRITE: persist locally as `pending`. The sync engine flushes
      // to /StartingCash/Add when network is available. The entries list is a
      // live stream off the local table, so the new row appears instantly —
      // no network round-trip and no manual invalidation needed.
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
      _amountCtrl.text = '0';
      _descCtrl.clear();
      setState(() => _saving = false);

      // Return to the main shell once the row is persisted. When launched from
      // MainLayout's startup flow this simply pops back; if the screen was ever
      // shown as a root route, redirect into MainLayout so the user is never
      // stranded on this canvas.
      if (!context.mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainLayout()),
        );
      }
    } catch (e) {
      setState(() {
        _error  = e.toString();
        _saving = false;
      });
    }
  }

  void _cancel() {
    _amountCtrl.text = '0';
    _descCtrl.clear();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final cs      = theme.colorScheme;
    final entries = ref.watch(_cashEntriesProvider);

    final isCashIn = _type == 0;
    // Adaptive accent: POS primary for "add", semantic error for "remove".
    final accent   = isCashIn ? context.navAccent : cs.error;
    final onAccent = isCashIn ? cs.onPrimary : cs.onError;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cash In / Out',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Type selector ─────────────────────────────────────
                      Row(
                        children: [
                          _TypeButton(
                            label: 'Add cash',
                            icon: Icons.arrow_downward_rounded,
                            selected: isCashIn,
                            activeColor: context.navAccent,
                            activeForeground: cs.onPrimary,
                            onTap: () => setState(() => _type = 0),
                          ),
                          const SizedBox(width: 4),
                          _TypeButton(
                            label: 'Remove cash',
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
                        'Amount',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.right,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        onTap: () {
                          if (_amountCtrl.text == '0') _amountCtrl.clear();
                        },
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
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
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _descCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter the reason for adding or removing cash...',
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
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
                        Text(
                          _error!,
                          style: TextStyle(color: cs.error, fontSize: 13),
                        ),
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
                          'Could not load entries: $e',
                          style: TextStyle(color: cs.error, fontSize: 12),
                        ),
                        data: (rows) {
                          // Resolve user ids → names from the local users
                          // cache so pulled rows from other tills show a name.
                          final users =
                              ref.watch(allUsersProvider).asData?.value ??
                                  const [];
                          String nameFor(int uid) {
                            for (final u in users) {
                              if (u.id == uid) {
                                final full = [u.firstName, u.lastName]
                                    .whereType<String>()
                                    .where((s) => s.isNotEmpty)
                                    .join(' ')
                                    .trim();
                                return full.isEmpty
                                    ? (u.username ?? 'User #$uid')
                                    : full;
                              }
                            }
                            return 'User #$uid';
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cash entries (${rows.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (rows.isEmpty)
                                Text(
                                  'No cash movements today.',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                )
                              else
                                ...rows.map((r) => _EntryTile(
                                      row: r,
                                      userName: nameFor(r.userId),
                                      dtFmt: _dtFmt,
                                      numFmt: _numFmt,
                                    )),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // ── Action buttons (pinned to bottom) ─────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: context.navScaffoldBg,
                  border: Border(
                    top: BorderSide(color: context.navDivider),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _cancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
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
                                    strokeWidth: 2, color: onAccent),
                              )
                            : Text(
                                isCashIn ? 'Save Cash In' : 'Save Cash Out',
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
            ],
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
    final cs        = Theme.of(context).colorScheme;
    final isCashOut = row.type == 'out';
    final color     = isCashOut ? cs.error : context.navAccent;
    final sign      = isCashOut ? '-' : '+';
    final desc      = row.note?.isNotEmpty == true
        ? row.note!
        : (isCashOut ? 'Cash out' : 'Cash in');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCashOut ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
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
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
