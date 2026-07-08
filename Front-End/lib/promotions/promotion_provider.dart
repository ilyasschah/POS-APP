import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/api/promotion_models.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';

/// Live list of promotions for the current company, streamed from Drift.
///
/// Each emission fetches the matching promotion_items rows so that
/// `activePromotionsProvider` can apply per-product discounts offline and
/// `getActivePromotionCountForProduct` returns accurate counts.
///
/// Items are re-fetched synchronously on every header-table change (asyncMap).
/// Standalone item mutations don't auto-trigger the stream; they always happen
/// together with a header write (save / pull) so this is acceptable.
final allPromotionsProvider =
    StreamProvider.autoDispose<List<PromotionDto>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const Stream.empty();

  return (db.select(db.promotionsTable)
        ..where((t) => t.companyId.equals(companyId))
        ..where((t) => t.syncStatus.isNotIn(['pending_delete'])))
      .watch()
      .asyncMap((promos) async {
        if (promos.isEmpty) return <PromotionDto>[];
        final ids = promos.map((p) => p.id).toList();
        final items = await (db.select(db.promotionItemsTable)
              ..where((t) => t.promotionId.isIn(ids)))
            .get();
        final byId = <int, List<PromotionItemsTableData>>{};
        for (final item in items) {
          byId.putIfAbsent(item.promotionId, () => []).add(item);
        }
        return promos
            .map((p) => PromotionDto.fromDrift(p, byId[p.id] ?? []))
            .toList();
      });
});

/// Promotions that are live *right now*, derived synchronously from
/// [allPromotionsProvider].
///
/// Kept as a plain `Provider` returning an `AsyncValue` (not a `StreamProvider`
/// wrapping `Stream.value`). The old StreamProvider form opened a *second*
/// stream subscription onto [allPromotionsProvider] and re-created that stream
/// on every upstream emission. During a route-transition TickerMode change
/// (e.g. popping back after saving a promotion) Riverpod's pause/resume
/// accounting double-counted those subscriptions and tripped the
/// `pausedActiveSubscriptionCount` assertion. A pure derived provider has no
/// stream of its own, so there's nothing to mis-pause — and every call site
/// already reads `.value`, which `AsyncValue` still exposes.
final activePromotionsProvider =
    Provider.autoDispose<AsyncValue<List<PromotionDto>>>((ref) {
  return ref.watch(allPromotionsProvider).whenData((promotions) {
    final now = DateTime.now();
    return promotions.where((p) => isPromotionActiveNow(p, now)).toList();
  });
});

/// Single source of truth for "is this promotion live right now" — used by both
/// the menu (to apply discounts / show the star) and the promotions list (to
/// show an accurate Active/Inactive badge). Checks enabled + date range + day
/// of week + time-of-day window.
bool isPromotionActiveNow(PromotionDto p, [DateTime? at]) {
  if (!p.isEnabled) return false;
  final now = at ?? DateTime.now();

  if (p.startDate != null) {
    final s = p.startDate!.toLocal();
    if (now.isBefore(DateTime(s.year, s.month, s.day))) return false;
  }
  if (p.endDate != null) {
    final e = p.endDate!.toLocal();
    if (now.isAfter(DateTime(e.year, e.month, e.day, 23, 59, 59))) return false;
  }

  // Day-of-week bitmask (Mon=bit0 … Sun=bit6). 0 means "every day".
  final dayBitmask = 1 << (now.weekday - 1);
  if (p.daysOfWeek > 0 && (p.daysOfWeek & dayBitmask) == 0) return false;

  // Only enforce a time-of-day window when both ends are set AND differ. A
  // zero-width window (start == end, e.g. "20:20"–"20:20") is a data-entry
  // artifact that would otherwise make the promo active for a single second —
  // treat it as "all day".
  final hasTimeWindow = p.startTime != null &&
      p.startTime!.isNotEmpty &&
      p.endTime != null &&
      p.endTime!.isNotEmpty &&
      p.startTime != p.endTime;
  if (hasTimeWindow) {
    final currentTimeString =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final safeStart =
        p.startTime!.length == 5 ? "${p.startTime}:00" : p.startTime!;
    final safeEnd = p.endTime!.length == 5 ? "${p.endTime}:00" : p.endTime!;
    if (currentTimeString.compareTo(safeStart) < 0) return false;
    if (currentTimeString.compareTo(safeEnd) > 0) return false;
  }
  return true;
}

int getActivePromotionCountForProduct(
    List<PromotionDto> activePromotions, int productId) {
  int count = 0;
  for (var promo in activePromotions) {
    if (promo.items.any((item) => item.productId == productId)) {
      count++;
    }
  }
  return count;
}
