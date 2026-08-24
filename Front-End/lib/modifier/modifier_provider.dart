import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/modifier/modifier_models.dart';

/// Every modifier group for the company, each with its options attached.
///
/// Streams from Drift, so it is offline-first and instant: the POS reads it on
/// a product tap and cannot afford a round trip there. Groups and options live
/// in two tables (they delta-sync on separate watermarks) and are composed back
/// together here, once, rather than at every call site.
///
/// Disabled rows are KEPT. The admin screen has to show them to re-enable them,
/// and the POS filters them out for itself — see [modifierGroupsForProductProvider].
final allModifierGroupsProvider =
    StreamProvider<List<ModifierGroup>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const []);

  final groupQuery = db.select(db.modifierGroupsTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.syncStatus.isNotIn(['pending_delete']))
    ..orderBy([
      (t) => OrderingTerm(expression: t.rank),
      (t) => OrderingTerm(expression: t.id),
    ]);

  return groupQuery.watch().asyncMap((groupRows) async {
    final optionRows = await (db.select(db.modifierOptionsTable)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.rank),
            (t) => OrderingTerm(expression: t.id),
          ]))
        .get();

    final byGroup = <int, List<ModifierOption>>{};
    for (final row in optionRows) {
      byGroup
          .putIfAbsent(row.modifierGroupId, () => [])
          .add(ModifierOption.fromDrift(row));
    }

    return groupRows
        .map((g) =>
            ModifierGroup.fromDrift(g).withOptions(byGroup[g.id] ?? const []))
        .toList();
  });
});

/// The groups one product offers, in the order they appear in the sheet.
///
/// 🚨 Filters out everything the cashier must not be shown, and the filtering is
/// the point: a disabled GROUP disappears entirely, a disabled OPTION disappears
/// from within its group, and a group left with no options is dropped rather
/// than rendered as an empty section nobody can satisfy. A mandatory group in
/// that state would otherwise block the sale with nothing to click.
final modifierGroupsForProductProvider = StreamProvider.autoDispose
    .family<List<ModifierGroup>, int>((ref, productId) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const []);

  final linkQuery = db.select(db.productModifierGroupsTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.productId.equals(productId))
    ..orderBy([
      (t) => OrderingTerm(expression: t.rank),
      (t) => OrderingTerm(expression: t.id),
    ]);

  return linkQuery.watch().asyncMap((links) async {
    if (links.isEmpty) return const <ModifierGroup>[];

    final all = await ref.read(allModifierGroupsProvider.future);
    final byId = {for (final g in all) g.id: g};

    final result = <ModifierGroup>[];
    for (final link in links) {
      final group = byId[link.modifierGroupId];
      if (group == null || !group.isEnabled) continue;

      final options = group.options.where((o) => o.isEnabled).toList();
      if (options.isEmpty) continue;

      result.add(group.withOptions(options));
    }
    return result;
  });
});

/// Product ids that offer at least one group.
///
/// The menu grid reads this ONCE to decide which taps open the customise sheet.
/// A per-product query on every tap would put a database round trip between the
/// finger and the dialog.
final productsWithModifiersProvider = StreamProvider<Set<int>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const {});

  final query = db.select(db.productModifierGroupsTable)
    ..where((t) => t.companyId.equals(companyId));

  return query.watch().map((rows) => rows.map((r) => r.productId).toSet());
});

/// The group ids one product is linked to — what the product editor's picker
/// binds to.
final productModifierGroupIdsProvider = StreamProvider.autoDispose
    .family<List<int>, int>((ref, productId) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const []);

  final query = db.select(db.productModifierGroupsTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.productId.equals(productId))
    ..orderBy([
      (t) => OrderingTerm(expression: t.rank),
      (t) => OrderingTerm(expression: t.id),
    ]);

  return query
      .watch()
      .map((rows) => rows.map((r) => r.modifierGroupId).toList());
});
