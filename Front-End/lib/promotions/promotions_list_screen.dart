import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/promotions/promotion_provider.dart';
import 'package:pos_app/promotions/promotion_edit_screen.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/sync/sync_provider.dart';

class PromotionsListScreen extends ConsumerWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const PromotionsListScreen({super.key, this.onMenuPressed});

  String _formatDaysOfWeek(int bitmask) {
    if (bitmask == 0 || bitmask == 127) return "Every day";
    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final activeDays = <String>[];
    for (int i = 0; i < 7; i++) {
      if ((bitmask & (1 << i)) != 0) activeDays.add(days[i]);
    }
    return activeDays.join(", ");
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "-";
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotionsAsync = ref.watch(allPromotionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotions'),
        // Suppress the auto back-arrow — ManagementLayout controls navigation.
        automaticallyImplyLeading: false,
        // Inside ManagementLayout: a menu icon (when the sidebar is hidden).
        // Pushed standalone (e.g. from the POS "Active Promotions" banner):
        // a back arrow so the user isn't stranded with no way out.
        leading: onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Show navigation',
                onPressed: onMenuPressed,
              )
            : (Navigator.of(context).canPop()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: promotionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (promotions) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header bar
              Row(
                children: [
                  Text(
                    '${promotions.length} Promotion${promotions.length == 1 ? '' : 's'}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh"),
                    // The list streams live from Drift, so it needs no manual
                    // provider refresh — "Refresh" pulls the latest from the
                    // server (best-effort) and the stream reflects the new rows.
                    onPressed: () async {
                      final companyId = ref.read(selectedCompanyProvider)?.id;
                      if (companyId == null) return;
                      try {
                        await ref
                            .read(syncManagerProvider)
                            .pullPromotions(companyId);
                      } catch (_) {
                        // Offline — the local stream is already current.
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Add Promotion"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    // No post-pop refresh needed: allPromotionsProvider streams
                    // live from Drift and updates the instant the editor writes.
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PromotionEditScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Table card
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: theme.cardColor,
                  clipBehavior: Clip.antiAlias,
                  child: promotions.isEmpty
                      ? Center(
                          child: Text(
                            'No promotions yet. Tap "Add Promotion" to create one.',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            // Header row
                            Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                                  Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                                  Expanded(flex: 2, child: Text('Days', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                                  Expanded(flex: 2, child: Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                                  Expanded(flex: 2, child: Text('Start Time', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                                  Expanded(flex: 2, child: Text('End Date', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                                  Expanded(flex: 2, child: Text('End Time', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                                  Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)))),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            // Data rows
                            Expanded(
                              child: ListView.separated(
                                itemCount: promotions.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final promotion = promotions[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Row(
                                            children: [
                                              if (promotion.isPendingSync)
                                                Padding(
                                                  padding: const EdgeInsets.only(right: 6),
                                                  child: Icon(
                                                    Icons.cloud_upload_outlined,
                                                    size: 16,
                                                    color: theme.colorScheme.tertiary,
                                                  ),
                                                ),
                                              Flexible(
                                                child: Text(
                                                  promotion.name,
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Builder(builder: (_) {
                                            // Real status: Disabled (off),
                                            // Active (live now), or Inactive
                                            // (enabled but outside its date /
                                            // day / time window). Shown as a
                                            // colour-coded dot; the label is in
                                            // the tooltip on hover/long-press.
                                            final (label, color) =
                                                !promotion.isEnabled
                                                    ? ("Disabled", Colors.red)
                                                    : isPromotionActiveNow(
                                                            promotion)
                                                        ? ("Active", Colors.green)
                                                        : ("Inactive",
                                                            Colors.orange);
                                            return Align(
                                              alignment: Alignment.centerLeft,
                                              child: Tooltip(
                                                message: label,
                                                child: Container(
                                                  width: 14,
                                                  height: 14,
                                                  decoration: BoxDecoration(
                                                    color: color,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ),
                                        Expanded(flex: 2, child: Text(_formatDaysOfWeek(promotion.daysOfWeek))),
                                        Expanded(flex: 2, child: Text(_formatDate(promotion.startDate))),
                                        Expanded(flex: 2, child: Text(promotion.startTime ?? "-")),
                                        Expanded(flex: 2, child: Text(_formatDate(promotion.endDate))),
                                        Expanded(flex: 2, child: Text(promotion.endTime ?? "-")),
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.blue),
                                                tooltip: "Edit",
                                                padding: const EdgeInsets.all(10),
                                                onPressed: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => PromotionEditScreen(promotion: promotion),
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                tooltip: "Delete",
                                                padding: const EdgeInsets.all(10),
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text('Confirm Delete'),
                                                      content: Text('Delete "${promotion.name}"?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(ctx, false),
                                                          child: const Text('Cancel'),
                                                        ),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.red,
                                                            foregroundColor: Colors.white,
                                                          ),
                                                          onPressed: () => Navigator.pop(ctx, true),
                                                          child: const Text('Delete'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm != true) return;
                                                  final companyId = ref.read(selectedCompanyProvider)?.id;
                                                  if (companyId == null) return;
                                                  final db = ref.read(appDatabaseProvider);

                                                  if (promotion.isPendingCreate) {
                                                    // Never reached the server — hard-delete locally.
                                                    await (db.delete(db.promotionItemsTable)
                                                          ..where((t) => t.promotionId.equals(promotion.id)))
                                                        .go();
                                                    await (db.delete(db.promotionsTable)
                                                          ..where((t) => t.id.equals(promotion.id)))
                                                        .go();
                                                  } else {
                                                    // Soft-delete: hidden by provider filter immediately.
                                                    await (db.update(db.promotionsTable)
                                                          ..where((t) => t.id.equals(promotion.id)))
                                                        .write(const PromotionsTableCompanion(
                                                      syncStatus: Value('pending_delete'),
                                                    ));
                                                    // Try API inline while online.
                                                    try {
                                                      await ApiClient().deletePromotion(companyId, promotion.id);
                                                      await (db.delete(db.promotionItemsTable)
                                                            ..where((t) => t.promotionId.equals(promotion.id)))
                                                          .go();
                                                      await (db.delete(db.promotionsTable)
                                                            ..where((t) => t.id.equals(promotion.id)))
                                                          .go();
                                                    } catch (_) {
                                                      // Offline — SyncManager pushPendingPromotionOps retries.
                                                    }
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
