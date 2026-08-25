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
/// show an accurate Active/Inactive badge).
///
/// **Start and End are instants, not a daily window.** The edit screen offers
/// four fields labelled "Start Date / Start Time / End Date / End Time", so a
/// promotion set to 22 Aug 22:17 → 24 Aug 22:18 runs *continuously* across
/// those two nights. The time pair used to be enforced as a time-of-day window
/// on *every* day of the range, which silently turned that promotion into a
/// 60-second slot per day and left it reading "Inactive" for the other 1439.
///
/// The daily-window reading survives for the one shape where it is the only
/// possible one: **no dates at all** plus a time pair — the open-ended
/// "happy hour 17:00–19:00" (narrowed further by the day-of-week bitmask).
bool isPromotionActiveNow(PromotionDto p, [DateTime? at]) {
  if (!p.isEnabled) return false;
  final now = at ?? DateTime.now();

  // Day-of-week bitmask (Mon=bit0 … Sun=bit6). 0 means "every day".
  final dayBitmask = 1 << (now.weekday - 1);
  if (p.daysOfWeek > 0 && (p.daysOfWeek & dayBitmask) == 0) return false;

  final start = _promotionBoundary(p.startDate, p.startTime, endOfDay: false);
  final end = _promotionBoundary(p.endDate, p.endTime, endOfDay: true);

  if (start != null || end != null) {
    if (start != null && now.isBefore(start)) return false;
    if (end != null && now.isAfter(end)) return false;
    return true;
  }

  return _matchesDailyWindow(p, now);
}

/// Folds a promotion date and its companion time into one local instant.
///
/// Returns null when the date is absent: that end of the range is unbounded,
/// and a lone time has no day to anchor itself to. A missing or malformed time
/// falls back to the edge of the day — 00:00:00 for the start, 23:59:59 for
/// the end — so a date-only promotion still covers its full first and last day.
DateTime? _promotionBoundary(DateTime? date, String? time,
    {required bool endOfDay}) {
  if (date == null) return null;
  final d = date.toLocal();
  final parts = (time ?? '').split(':');
  final h = parts.length >= 2 ? int.tryParse(parts[0]) : null;
  final m = parts.length >= 2 ? int.tryParse(parts[1]) : null;
  if (h == null || m == null) {
    return endOfDay
        ? DateTime(d.year, d.month, d.day, 23, 59, 59)
        : DateTime(d.year, d.month, d.day);
  }
  final s = parts.length >= 3 ? (int.tryParse(parts[2]) ?? 0) : 0;
  return DateTime(d.year, d.month, d.day, h, m, s);
}

/// Recurring time-of-day window, for promotions with no date range.
///
/// Only enforced when both ends are set AND differ. A zero-width window
/// (start == end, e.g. "20:20"–"20:20") is a data-entry artifact that would
/// otherwise make the promo active for a single second — treat it as all day.
bool _matchesDailyWindow(PromotionDto p, DateTime now) {
  final hasTimeWindow = p.startTime != null &&
      p.startTime!.isNotEmpty &&
      p.endTime != null &&
      p.endTime!.isNotEmpty &&
      p.startTime != p.endTime;
  if (!hasTimeWindow) return true;

  final currentTimeString =
      "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
  final safeStart =
      p.startTime!.length == 5 ? "${p.startTime}:00" : p.startTime!;
  final safeEnd = p.endTime!.length == 5 ? "${p.endTime}:00" : p.endTime!;
  if (currentTimeString.compareTo(safeStart) < 0) return false;
  if (currentTimeString.compareTo(safeEnd) > 0) return false;
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
