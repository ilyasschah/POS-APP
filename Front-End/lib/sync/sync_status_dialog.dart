import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/sync/sync_status_provider.dart';

/// Display label for a sync entity.
///
/// 🚨 `SyncEntityStatus.label` is an **identifier, not screen text** — it is
/// embedded verbatim in the UNION-ALL query built by
/// `sync_status_provider._buildSql()` (`SELECT 'Sales orders' AS label …`) and
/// comes back out of SQLite as the row key. Translating `_entities` would
/// change the SQL and break the mapping. Only the label is localized here.
String _syncEntityLabel(BuildContext context, String id) {
  final l10n = AppLocalizations.of(context);
  switch (id) {
    case 'Sales orders':
      return l10n.syncSalesOrders;
    case 'Documents':
      return l10n.documents;
    case 'Payments':
      return l10n.paymentsTab;
    case 'Voids':
      return l10n.syncVoids;
    case 'Cash movements':
      return l10n.syncCashMovements;
    case 'Z-reports':
      return l10n.syncZReports;
    case 'Shifts':
      return l10n.syncShifts;
    case 'Time clock':
      return l10n.timeClock;
    case 'Products':
      return l10n.products;
    case 'Product groups':
      return l10n.productGroups;
    case 'Product comments':
      return l10n.syncProductComments;
    case 'Barcodes':
      return l10n.barcodesTab;
    case 'Taxes':
      return l10n.taxesLabel;
    case 'Product taxes':
      return l10n.syncProductTaxes;
    case 'Payment types':
      return l10n.paymentTypes;
    case 'Void reasons':
      return l10n.voidReasons;
    case 'Customers':
      return l10n.customersLabel;
    case 'Customer discounts':
      return l10n.syncCustomerDiscounts;
    case 'Loyalty cards':
      return l10n.loyaltyCards;
    case 'Promotions':
      return l10n.promotions;
    case 'Stock':
      return l10n.stock;
    case 'Stock counts':
      return l10n.syncStockCounts;
    case 'Stock transfers':
      return l10n.syncStockTransfers;
    case 'Warehouses':
      return l10n.warehouses;
    case 'Users':
      return l10n.users;
    case 'Company':
      return l10n.setCompany;
    case 'Settings':
      return l10n.settings;
    default:
      return id;
  }
}

/// Opens the Sync Status panel — a per-entity summary of what's still pending
/// vs. fully synced, with a "Sync now" action that runs a full sync in place.
Future<void> showSyncStatusDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const SyncStatusDialog(),
  );
}

class SyncStatusDialog extends ConsumerWidget {
  const SyncStatusDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Toasts (success / partial-failure / rejection) are surfaced by the
    // always-mounted SyncButton's listener — we don't duplicate them here.
    final statusAsync = ref.watch(syncStatusProvider);
    final isSyncing = ref.watch(syncStateProvider).isLoading;

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  Icon(PhosphorIcons.arrowsClockwise(),
                      size: 22, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).syncStatusTitle,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: statusAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(AppLocalizations.of(context).couldNotReadSyncStatus(e.toString()),
                        style: TextStyle(color: cs.error)),
                  ),
                  data: (list) => _StatusBody(entities: list),
                ),
              ),
              const SizedBox(height: 12),
              // ── Footer actions ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context).actionClose),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: isSyncing
                        ? null
                        // manual: the operator pressed Sync, so reconcile
                        // deletions from other tills now, not in 6 hours.
                        : () => ref
                            .read(syncStateProvider.notifier)
                            .sync(manual: true),
                    icon: isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(PhosphorIcons.arrowsClockwise(), size: 18),
                    label: Text(isSyncing
            ? AppLocalizations.of(context).syncingEllipsis
            : AppLocalizations.of(context).syncNow),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({required this.entities});

  final List<SyncEntityStatus> entities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Failed first, then pending, then synced — so anything needing attention
    // sits at the top of the scroll.
    final sorted = [...entities]..sort((a, b) {
        int rank(SyncEntityStatus e) =>
            e.failed > 0 ? 0 : (e.pending > 0 ? 1 : 2);
        final r = rank(a).compareTo(rank(b));
        // Sort on the TRANSLATED label so the list reads alphabetically in
        // the operator's own language, not in English.
        return r != 0
            ? r
            : _syncEntityLabel(context, a.label)
                .compareTo(_syncEntityLabel(context, b.label));
      });

    final pendingTotal = entities.fold<int>(0, (s, e) => s + e.pending);
    final failedTotal = entities.fold<int>(0, (s, e) => s + e.failed);
    final allClean = pendingTotal == 0 && failedTotal == 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Summary banner ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: (allClean ? context.successColor : context.warningColor)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                allClean
                    ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                    : PhosphorIcons.cloudArrowUp(),
                color: allClean ? context.successColor : context.warningColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  allClean
                      ? AppLocalizations.of(context).everythingIsSynced
                      : [
                          if (pendingTotal > 0)
                            AppLocalizations.of(context)
                              .itemsPendingCount(pendingTotal),
                          if (failedTotal > 0)
                            AppLocalizations.of(context).failedCount(failedTotal),
                        ].join(' · '),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: sorted.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
            itemBuilder: (_, i) => _EntityRow(entity: sorted[i]),
          ),
        ),
      ],
    );
  }
}

class _EntityRow extends StatelessWidget {
  const _EntityRow({required this.entity});

  final SyncEntityStatus entity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    late final IconData icon;
    late final Color color;
    late final String trailing;

    if (entity.failed > 0) {
      icon = PhosphorIcons.warningCircle(PhosphorIconsStyle.fill);
      color = cs.error;
      trailing = entity.pending > 0
          ? '${AppLocalizations.of(context).failedCount(entity.failed)} · ${AppLocalizations.of(context).pendingCount(entity.pending)}'
          : AppLocalizations.of(context).failedCount(entity.failed);
    } else if (entity.pending > 0) {
      icon = PhosphorIcons.arrowsClockwise();
      color = context.warningColor;
      trailing = AppLocalizations.of(context).pendingCount(entity.pending);
    } else {
      icon = PhosphorIcons.checkCircle(PhosphorIconsStyle.fill);
      color = context.successColor;
      trailing = AppLocalizations.of(context).syncedStatus;
    }

    // A stored reason only makes sense to show for the rows that need
    // attention — never under a green "Synced" row.
    final reason = entity.isSynced ? null : entity.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_syncEntityLabel(context, entity.label),
                    style: theme.textTheme.bodyLarge),
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              trailing,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight:
                    entity.isSynced ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
