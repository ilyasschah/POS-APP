import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/sync/sync_status_provider.dart';

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
                      'Sync Status',
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
                    child: Text('Couldn\'t read sync status: $e',
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
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: isSyncing
                        ? null
                        : () => ref.read(syncStateProvider.notifier).sync(),
                    icon: isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(PhosphorIcons.arrowsClockwise(), size: 18),
                    label: Text(isSyncing ? 'Syncing…' : 'Sync now'),
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
        return r != 0 ? r : a.label.compareTo(b.label);
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
            color: (allClean ? Colors.green : Colors.orange)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                allClean
                    ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                    : PhosphorIcons.cloudArrowUp(),
                color: allClean ? Colors.green : Colors.orange,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  allClean
                      ? 'Everything is synced'
                      : [
                          if (pendingTotal > 0)
                            '$pendingTotal item${pendingTotal == 1 ? '' : 's'} pending',
                          if (failedTotal > 0)
                            '$failedTotal failed',
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
          ? '${entity.failed} failed · ${entity.pending} pending'
          : '${entity.failed} failed';
    } else if (entity.pending > 0) {
      icon = PhosphorIcons.arrowsClockwise();
      color = Colors.orange;
      trailing = '${entity.pending} pending';
    } else {
      icon = PhosphorIcons.checkCircle(PhosphorIconsStyle.fill);
      color = Colors.green;
      trailing = 'Synced';
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
                Text(entity.label, style: theme.textTheme.bodyLarge),
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
