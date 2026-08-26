// The opening float as a cash-movement row.
//
// 🚨 The whole reason this needed care: expected cash is
//
//     openingCash + cashPayments + cashIn - cashOut
//
// and `openingCash` is the session's own `startingCash`. Writing the float into
// `starting_cash` as an ordinary `in` row would add the same money a second
// time, and every register in the estate would read over by its float — a
// discrepancy that looks like theft and is arithmetic. These tests pin the
// invariant so the row can exist for the operator to see WITHOUT ever being
// summed.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/cash/cash_movement_kind.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime.utc(2026, 8, 26, 8);
  const sessionLocalId = 'sess-1';

  Future<void> movement(String type, double amount) =>
      db.insertOfflineCashMovement(
        StartingCashTableCompanion.insert(
          localId: '',
          companyId: 25,
          userId: 9,
          amount: amount,
          type: type,
          createdAt: now,
          sessionLocalId: const Value(sessionLocalId),
        ),
      );

  Future<List<StartingCashTableData>> movements() =>
      (db.select(db.startingCashTable)
            ..where((t) => t.sessionLocalId.equals(sessionLocalId)))
          .get();

  group('the ledger shows the float without counting it', () {
    test('an opening row is stored and is a kind of its own', () async {
      await movement(CashMovementKind.opening, 2000);

      final rows = await movements();
      expect(rows, hasLength(1));
      expect(rows.single.type, 'opening');
      expect(rows.single.type, isNot(CashMovementKind.cashIn));
      expect(rows.single.type, isNot(CashMovementKind.cashOut));
    });

    test('it is excluded from BOTH the cash-in and cash-out totals', () async {
      await movement(CashMovementKind.opening, 2000);
      await movement(CashMovementKind.cashIn, 500);
      await movement(CashMovementKind.cashOut, 200);

      final rows = await movements();
      final cashIn = rows
          .where((m) => m.type == CashMovementKind.cashIn)
          .fold<double>(0, (s, m) => s + m.amount);
      final cashOut = rows
          .where((m) => m.type == CashMovementKind.cashOut)
          .fold<double>(0, (s, m) => s + m.amount);

      expect(cashIn, 500, reason: 'the 2000 float must not land in cash in');
      expect(cashOut, 200);
    });

    test('summing by "not out" is what double-counts — proof of the trap',
        () async {
      await movement(CashMovementKind.opening, 2000);
      await movement(CashMovementKind.cashIn, 500);

      final rows = await movements();
      final wrong = rows
          .where((m) => m.type != CashMovementKind.cashOut)
          .fold<double>(0, (s, m) => s + m.amount);

      // 2500, not 500: the shape any future refactor must not fall back into.
      expect(wrong, 2500);
    });
  });

  group('the wire mapping keeps the three kinds apart', () {
    test('each kind round-trips through the API value', () {
      for (final kind in [
        CashMovementKind.cashIn,
        CashMovementKind.cashOut,
        CashMovementKind.opening,
      ]) {
        expect(CashMovementKind.fromApi(CashMovementKind.toApi(kind)), kind);
      }
    });

    test('the opening float is 2, clear of the long-standing 0 and 1', () {
      expect(CashMovementKind.toApi(CashMovementKind.cashIn), 0);
      expect(CashMovementKind.toApi(CashMovementKind.cashOut), 1);
      expect(CashMovementKind.toApi(CashMovementKind.opening), 2);
    });

    test('an unknown value reads as a cash-in, matching the server default',
        () {
      expect(CashMovementKind.fromApi(null), CashMovementKind.cashIn);
      expect(CashMovementKind.fromApi(99), CashMovementKind.cashIn);
    });
  });
}
