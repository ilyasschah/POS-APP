import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/cart/payment_provider.dart';
import 'package:pos_app/cash/cash_movement_dialog.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/reports/z_report_model.dart';
import 'package:pos_app/reports/z_report_provider.dart';
import 'package:pos_app/reports/z_report_receipt_dialog.dart';
import 'package:pos_app/reports/z_report_service.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:pos_app/session/manager_authorisation.dart';
import 'package:pos_app/session/session_provider.dart';
import 'package:pos_app/session/session_reconciliation.dart';
import 'package:pos_app/session/session_summary_provider.dart';

/// Odoo's **Closing Register**: the per-method reconciliation matrix.
///
/// Layout follows the supplied screenshot: one row per payment method with
/// Expected / Counted / Difference; the cash row expands into its makeup
/// (opening + cash in/out + cash payments); a separate Cash Count field; a
/// closing note; Close Register / Discard, with Cash In/Out and Daily Sale as
/// secondary actions.
///
/// 🚨 Reconciliation is per METHOD, not cash-only. Only cash is physically
/// counted — the card/bank rows are *confirmed*, and "confirmed 4,137.70" is a
/// different statement from "never looked at", which is why they get their own
/// input rather than being assumed correct.
class ClosingRegisterDialog extends ConsumerStatefulWidget {
  const ClosingRegisterDialog({super.key, required this.session});

  final ShiftsTableData session;

  static Future<bool> show(BuildContext context, ShiftsTableData session) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ClosingRegisterDialog(session: session),
      ) ??
      false;

  @override
  ConsumerState<ClosingRegisterDialog> createState() =>
      _ClosingRegisterDialogState();
}

class _ClosingRegisterDialogState extends ConsumerState<ClosingRegisterDialog> {
  final _cashCount = TextEditingController(text: '0.00');
  final _note = TextEditingController();
  final _counted = <int, TextEditingController>{};
  bool _cashExpanded = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cashCount.dispose();
    _note.dispose();
    for (final c in _counted.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _countedCash =>
      double.tryParse(_cashCount.text.trim().replaceAll(',', '.')) ?? 0;

  double? _countedFor(SessionMethodTotal m) {
    // The cash row reads the drawer count, not its own box — there is one
    // physical drawer, and two inputs that could disagree about it would be a
    // bug waiting to happen.
    if (m.isCash) return _countedCash;
    final text = _counted[m.paymentTypeId]?.text.trim().replaceAll(',', '.');
    if (text == null || text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _close(SessionReconciliation summary) async {
    final l = AppLocalizations.of(context);
    final sym = ref.read(currencySymbolProvider);
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    final difference = _countedCash - summary.expectedCash;

    // 🚨 The tolerance gate. Beyond it, the cashier cannot sign off their own
    // shortfall — an administrator has to. Checked here AND server-side; this
    // one is so the cashier is told before the drawer is committed.
    if (difference.abs() > summary.maxCashDifference) {
      final authorised = await ManagerAuthorisation.request(
        context,
        ref,
        reason: l.managerAuthRequired(
          '${difference.toStringAsFixed(2)} $sym',
          '${summary.maxCashDifference.toStringAsFixed(2)} $sym',
        ),
      );
      if (!authorised) return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionNotifierProvider.notifier).closeSession(
            localId: widget.session.localId,
            closedByUserId: userId,
            expectedCash: summary.expectedCash,
            countedCash: _countedCash,
            closingNote: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );

      // Closing the register closes the DAY for this session: the Z-report is
      // generated here, offline, from the sales carrying this session's id.
      //
      // 🚨 The server also generates one on push (`GenerateForSessionAsync`),
      // and that stays authoritative — but waiting for it meant an offline till
      // shut its drawer with no slip to print and nothing to show. The local
      // report stamps what it covered, so the same money cannot be reported a
      // second time by End of Day.
      final report = await _generateSessionZReport();

      if (!mounted) return;
      Navigator.pop(context, true);
      if (report != null) await showZReportDialog(context, ref, report);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Generates and persists this session's Z-report.
  ///
  /// 🚨 Never allowed to fail the close. The drawer has been counted and the
  /// session row is already committed by the time this runs — a Z-report that
  /// could not be written is a slip the cashier does not get, not a register
  /// that stays open. The server generates its own on push regardless.
  Future<ZReportModel?> _generateSessionZReport() async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    final userId = ref.read(currentUserProvider)?.id;
    if (companyId == null || userId == null) return null;
    try {
      final report = await ZReportService.generate(
        db: ref.read(appDatabaseProvider),
        companyId: companyId,
        userId: userId,
        scope: ZReportScope.session,
        sessionLocalId: widget.session.localId,
      );
      ref.invalidate(unreportedPaymentsProvider);
      ref.invalidate(allZReportsProvider);
      // Best-effort push so the server-authoritative report syncs when online.
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      return report;
    } catch (_) {
      return null;
    }
  }

  /// "Print Z Report", next to Cash In / Out.
  ///
  /// A **preview**: the figures as they stand right now, printed through the
  /// same `ReceiptPrinterService.printZReport` the End-of-Day slip uses, with
  /// nothing persisted and no number taken from the sequence. Reading the
  /// drawer must never be the thing that closes it — the real report is still
  /// generated by Close Register, over the full session.
  Future<void> _printPreview() async {
    final l = AppLocalizations.of(context);
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;

    setState(() => _busy = true);
    try {
      final report = await ZReportService.preview(
        db: ref.read(appDatabaseProvider),
        companyId: companyId,
        sessionLocalId: widget.session.localId,
      );
      if (!mounted) return;
      if (report == null) {
        showAppSnackbar(context, ref, l.nothingToReport);
        return;
      }
      await showZReportDialog(context, ref, report);
    } catch (e) {
      if (mounted) showAppSnackbar(context, ref, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sym = ref.watch(currencySymbolProvider);
    // Keyed on the session being closed, not on "the active one": the dialog
    // is always handed its session, and reading it back by id keeps the figures
    // right even at the moment the register stops being the live one.
    final summary =
        ref.watch(sessionSummaryProvider(widget.session.localId)).value;

    String money(double v) => '${v.toStringAsFixed(2)} $sym';

    if (summary == null) {
      return const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    for (final m in summary.methods) {
      if (!m.isCash) {
        _counted.putIfAbsent(
          m.paymentTypeId,
          // Non-cash rows pre-fill with the expected figure: the operator is
          // CONFIRMING an electronic total, not counting notes, so making them
          // retype it invites transcription errors without adding assurance.
          () => TextEditingController(text: m.expected.toStringAsFixed(2)),
        );
      }
    }

    final difference = _countedCash - summary.expectedCash;
    final overTolerance = difference.abs() > summary.maxCashDifference;

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Row(
        children: [
          Expanded(
              child: Text(l.closingRegister,
                  style: theme.textTheme.titleMedium)),
          Text(
            l.sessionOrdersTotal(summary.documentCount, money(summary.totalTaken)),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column headers
              Row(
                children: [
                  const Expanded(flex: 3, child: SizedBox()),
                  Expanded(
                      flex: 2,
                      child: Text(l.sessionExpected,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelMedium)),
                  Expanded(
                      flex: 2,
                      child: Text(l.sessionCounted,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium)),
                  Expanded(
                      flex: 2,
                      child: Text(l.sessionDifference,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelMedium)),
                ],
              ),
              const Divider(),

              // 🚨 ONE cash row, ALWAYS, and its expected figure is the whole
              // drawer — opening + cash payments + cash in − cash out — not the
              // cash takings alone. Two reasons: a session that took no cash
              // still has a drawer to count (otherwise this matrix renders
              // empty while the warning below quotes a difference out of
              // nowhere), and the difference shown here has to be the SAME
              // number the tolerance gate and the close itself use.
              _MethodRow(
                method: SessionMethodTotal(
                  paymentTypeId: _kCashRowId,
                  paymentTypeName: _cashRowName(l, summary),
                  isCash: true,
                  expected: summary.expectedCash,
                ),
                counted: _countedCash,
                controller: null,
                expanded: _cashExpanded,
                onToggle: () => setState(() => _cashExpanded = !_cashExpanded),
                onChanged: () => setState(() {}),
              ),
              // The cash makeup — how the expected figure was arrived at.
              // Without it the cashier is asked to accept a number with no
              // way to see where it came from.
              if (_cashExpanded) ...[
                _SubRow(
                    label: l.sessionOpeningRow,
                    value: money(summary.openingCash)),
                _SubRow(
                    label: l.sessionCashInOutRow,
                    value: '+ ${money(summary.cashIn - summary.cashOut)}'),
                _SubRow(
                    label: l.sessionCashPaymentsRow,
                    value: '+ ${money(summary.cashPayments)}'),
              ],

              for (final m in summary.methods.where((m) => !m.isCash))
                _MethodRow(
                  method: m,
                  counted: _countedFor(m),
                  controller: _counted[m.paymentTypeId],
                  expanded: null,
                  onToggle: null,
                  onChanged: () => setState(() {}),
                ),

              const Divider(height: 24),

              Text(l.cashCount, style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              TextField(
                controller: _cashCount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _cashCount.text = '0.00';
                      setState(() {});
                    },
                  ),
                ),
              ),

              if (overTolerance) ...[
                const SizedBox(height: 10),
                _Warning(
                  text: l.managerAuthRequired(
                    '${difference.toStringAsFixed(2)} $sym',
                    '${summary.maxCashDifference.toStringAsFixed(2)} $sym',
                  ),
                ),
              ],
              if (!summary.cashMethodsConfigured) ...[
                const SizedBox(height: 10),
                _Warning(text: l.sessionCashInferred),
              ],

              const SizedBox(height: 16),
              Text(l.closingNote, style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l.closingNoteHint,
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
      ),
      // ⚠️ ONE Row, not three loose buttons. AlertDialog lays its actions out
      // in an OverflowBar, which rejects flex parent data — a bare Spacer
      // between them throws "Incorrect use of ParentDataWidget" on every build.
      // The Row owns the spacing instead, and Cash In / Out keeps its place on
      // the left away from the two committing actions.
      actions: [
        Row(
          children: [
            TextButton.icon(
              onPressed: _busy ? null : () => showCashMovementDialog(context, ref),
              icon: const Icon(Icons.swap_vert, size: 18),
              label: Text(l.cashInOut),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: _busy ? null : _printPreview,
              icon: const Icon(Icons.receipt_long, size: 18),
              label: Text(l.printZReport),
            ),
            const Spacer(),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: Text(l.actionDiscard),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy ? null : () => _close(summary),
              child: Text(l.closeRegister),
            ),
          ],
        ),
      ],
    );
  }
}

/// The synthetic cash row's id. Negative so it can never collide with a real
/// payment type — the row stands for the DRAWER, which no single method owns.
const int _kCashRowId = -1;

/// What to call the drawer row: the company's own cash method name when there
/// is exactly one, otherwise a neutral label — "Cash" and "Cash CIH" both being
/// the same drawer, and inventing a name for a two-method setup would be worse
/// than saying plainly which thing is being counted.
String _cashRowName(AppLocalizations l, SessionReconciliation summary) {
  final cash = summary.methods.where((m) => m.isCash).toList();
  return cash.length == 1 ? cash.first.paymentTypeName : l.cashDrawer;
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    required this.counted,
    required this.controller,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
  });

  final SessionMethodTotal method;
  final double? counted;
  final TextEditingController? controller;
  final bool? expanded;
  final VoidCallback? onToggle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diff = counted == null ? null : counted! - method.expected;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (onToggle != null)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28),
                    iconSize: 18,
                    onPressed: onToggle,
                    icon: Icon(expanded == true
                        ? Icons.arrow_drop_down
                        : Icons.arrow_right),
                  ),
                Flexible(
                  child: Text(method.paymentTypeName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(method.expected.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: controller == null
                  // Cash is counted in the dedicated field below — one drawer,
                  // one input.
                  ? Text(counted?.toStringAsFixed(2) ?? '—',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge)
                  : TextField(
                      controller: controller,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      onChanged: (_) => onChanged(),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              diff == null ? '—' : diff.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: diff == null || diff == 0
                    ? theme.colorScheme.onSurface
                    : context.dangerColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 2),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: muted)),
          Expanded(
              flex: 2,
              child: Text(value, textAlign: TextAlign.right, style: muted)),
          const Expanded(flex: 4, child: SizedBox()),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.warningColor;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}
