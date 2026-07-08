import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/loyalty/loyalty_card_model.dart';

final allLoyaltyCardsProvider =
    StreamProvider.autoDispose<List<LoyaltyCard>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const Stream.empty();

  final query = db.select(db.loyaltyCardsTable).join([
    leftOuterJoin(
      db.customersTable,
      db.customersTable.id.equalsExp(db.loyaltyCardsTable.customerId),
    ),
  ])
    ..where(db.loyaltyCardsTable.companyId.equals(companyId))
    ..where(db.loyaltyCardsTable.syncStatus.isNotIn(['pending_delete']));

  return query.watch().map((rows) => rows.map((row) {
        final card = row.readTable(db.loyaltyCardsTable);
        final customer = row.readTableOrNull(db.customersTable);
        return LoyaltyCard.fromJoin(card, customer);
      }).toList());
});

class LoyaltyCardNotifier extends Notifier<void> {
  @override
  void build() {}

  AppDatabase get _db => ref.read(appDatabaseProvider);
  int? get _companyId => ref.read(selectedCompanyProvider)?.id;

  Future<void> addCard({
    required int customerId,
    String? cardNumber,
    double points = 0,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return;
    // Auto-assign a number when left blank (the dialog promises this). Use a
    // device-local timestamp so it's unique offline across terminals — the same
    // approach as offline document numbering — instead of leaving it null and
    // showing "No card number".
    final number = (cardNumber == null || cardNumber.trim().isEmpty)
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : cardNumber.trim();
    final tempId = -(DateTime.now().millisecondsSinceEpoch % 1000000000);
    await _db.into(_db.loyaltyCardsTable).insert(
          LoyaltyCardsTableCompanion(
            id: Value(tempId),
            companyId: Value(companyId),
            customerId: Value(customerId),
            cardNumber: Value(number),
            points: Value(points),
            lastModified: Value(DateTime.now().toUtc()),
            syncStatus: const Value('pending_create'),
          ),
        );
  }

  Future<void> updateCard({
    required int id,
    String? cardNumber,
    required double points,
  }) async {
    final existing = await (_db.select(_db.loyaltyCardsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;

    final isNew = existing.syncStatus == 'pending_create';
    await (_db.update(_db.loyaltyCardsTable)..where((t) => t.id.equals(id)))
        .write(LoyaltyCardsTableCompanion(
      cardNumber: Value(cardNumber),
      points: Value(points),
      lastModified: Value(DateTime.now().toUtc()),
      syncStatus: Value(isNew ? 'pending_create' : 'pending_update'),
      syncError: const Value(null),
    ));
  }

  /// Returns the loyalty card for [customerId] in the current company, or null.
  Future<LoyaltyCardsTableData?> findByCustomerId(int customerId) async {
    final companyId = _companyId;
    if (companyId == null) return null;
    return (_db.select(_db.loyaltyCardsTable)
          ..where((t) => t.customerId.equals(customerId))
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.syncStatus.isNotIn(['pending_delete']))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Adds [delta] to the customer's loyalty card points (negative to deduct).
  /// Clamps the result at 0. No-op if the customer has no card.
  Future<void> adjustPoints(int customerId, double delta) async {
    final card = await findByCustomerId(customerId);
    if (card == null) return;
    final newPoints = (card.points + delta).clamp(0, double.infinity);
    final isNew = card.syncStatus == 'pending_create';
    await (_db.update(_db.loyaltyCardsTable)
          ..where((t) => t.id.equals(card.id)))
        .write(LoyaltyCardsTableCompanion(
      points: Value(newPoints.toDouble()),
      lastModified: Value(DateTime.now().toUtc()),
      syncStatus: Value(isNew ? 'pending_create' : 'pending_update'),
      syncError: const Value(null),
    ));
  }

  Future<void> deleteCard(int id) async {
    final existing = await (_db.select(_db.loyaltyCardsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;

    if (existing.syncStatus == 'pending_create') {
      await (_db.delete(_db.loyaltyCardsTable)..where((t) => t.id.equals(id)))
          .go();
    } else {
      await (_db.update(_db.loyaltyCardsTable)..where((t) => t.id.equals(id)))
          .write(const LoyaltyCardsTableCompanion(
        syncStatus: Value('pending_delete'),
      ));
    }
  }
}

final loyaltyCardNotifierProvider =
    NotifierProvider<LoyaltyCardNotifier, void>(() => LoyaltyCardNotifier());
