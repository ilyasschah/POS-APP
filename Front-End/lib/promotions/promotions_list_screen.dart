import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/core/status_colors.dart';
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

  String _formatDaysOfWeek(BuildContext context, int bitmask) {
    final l10n = AppLocalizations.of(context);
    if (bitmask == 0 || bitmask == 127) return l10n.everyDay;
    final days = l10n.weekdayAbbreviations.split(',');
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
        title: Text(AppLocalizations.of(context).promotions),
        // Suppress the auto back-arrow — ManagementLayout controls navigation.
        automaticallyImplyLeading: false,
        // Inside ManagementLayout: a menu icon (when the sidebar is hidden).
        // Pushed standalone (e.g. from the POS "Active Promotions" banner):
        // a back arrow so the user isn't stranded with no way out.
        leading: onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: AppLocalizations.of(context).showNavigation,
                onPressed: onMenuPressed,
              )
            : (Navigator.of(context).canPop()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: AppLocalizations.of(context).back,
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: promotionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text(AppLocalizations.of(context).errorWithMessage(err.toString()))),
          data: (promotions) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header bar
              Row(
                children: [
                  Text(
                    AppLocalizations.of(context)
                        .promotionsCount(promotions.length),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text(AppLocalizations.of(context).refresh),
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
                    label: Text(AppLocalizations.of(context).addPromotion),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.successColor,
                      foregroundColor: context.onStatusColor,
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
                            AppLocalizations.of(context).noPromotionsYet,
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
                                  Expanded(flex: 3, child: Text(AppLocalizations.of(context).fieldName, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                                  Expanded(flex: 2, child: Text(AppLocalizations.of(context).statusLabel, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                                  Expanded(flex: 2, child: Text(AppLocalizations.of(context).days, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                                  Expanded(flex: 2, child: Text(AppLocalizations.of(context).startDate, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                                  Expanded(flex: 2, child: Text(AppLocalizations.of(context).startTime, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                                  Expanded(flex: 2, child: Text(AppLocalizations.of(context).endDate, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                                  Expanded(flex: 2, child: Text(AppLocalizations.of(context).endTime, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                                  Expanded(flex: 2, child: Align(alignment: AlignmentDirectional.centerEnd, child: Text(AppLocalizations.of(context).actions, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)))),
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
                                                  padding: const EdgeInsetsDirectional.only(end: 6),
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
                                                    ? (
                                                        AppLocalizations.of(context)
                                                            .statusDisabled,
                                                        Colors.red
                                                      )
                                                    : isPromotionActiveNow(
                                                            promotion)
                                                        ? (
                                                            AppLocalizations.of(context)
                                                                .statusActive,
                                                            Colors.green
                                                          )
                                                        : (
                                                            AppLocalizations.of(context)
                                                                .statusInactive,
                                                            Colors.orange
                                                          );
                                            return Align(
                                              alignment: AlignmentDirectional.centerStart,
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
                                        Expanded(flex: 2, child: Text(_formatDaysOfWeek(context, promotion.daysOfWeek))),
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
                                                icon: Icon(Icons.edit, color: context.infoColor),
                                                tooltip: AppLocalizations.of(context).actionEdit,
                                                padding: const EdgeInsets.all(10),
                                                onPressed: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => PromotionEditScreen(promotion: promotion),
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.delete, color: context.dangerColor),
                                                tooltip: AppLocalizations.of(context).actionDelete,
                                                padding: const EdgeInsets.all(10),
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: Text(AppLocalizations.of(context).confirmDelete),
                                                      content: Text(AppLocalizations.of(context).deleteQuotedConfirm(promotion.name)),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(ctx, false),
                                                          child: Text(AppLocalizations.of(context).actionCancel),
                                                        ),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: ctx.dangerColor,
                                                            foregroundColor: ctx.onStatusColor,
                                                          ),
                                                          onPressed: () => Navigator.pop(ctx, true),
                                                          child: Text(AppLocalizations.of(context).actionDelete),
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
