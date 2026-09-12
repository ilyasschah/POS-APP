// A split bill's payments leave the terminal VERBATIM — one per guest, never
// grouped by their payment method.
//
// The field report of 2026-09-11: two guests paid 184.60 and 198.00, both in
// Espèces, and the document came back with ONE 382.60 payment. The server was
// running the build from before the payment list existed and read only the
// order's paymentTypeId + summed amountPaid. This pins the terminal's half: the
// real `pushPendingOrders` sends both payments, and the local rows stay two.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/sync/sync_manager.dart';

import 'quiet_sync_logs.dart';

const _especes = 69;

/// Answers /PosOrder/BatchSync with a success for every order it receives and
/// keeps what was posted; every other endpoint 404s.
class _BatchSyncSpy implements HttpClientAdapter {
  final List<Map<String, dynamic>> posted = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? _,
    Future<void>? __,
  ) async {
    if (!options.path.contains('PosOrder/BatchSync')) {
      return ResponseBody.fromString('null', 404);
    }
    final body = (options.data is String
        ? jsonDecode(options.data as String)
        : options.data) as Map<String, dynamic>;
    posted.add(body);
    final results = [
      for (final o in body['orders'] as List)
        {'localId': (o as Map)['localId'], 'success': true, 'serverId': 216},
    ];
    return ResponseBody.fromString(
      jsonEncode({'results': results}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 9, 11, 20);
  const orderId = 'split-order';

  setUp(() {
    silenceDebugPrint();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  SyncManager managerFor(_BatchSyncSpy spy) => SyncManager(
        db: db,
        dio: Dio(BaseOptions(baseUrl: 'http://test.local/api'))
          ..httpClientAdapter = spy,
        authStorage: AuthStorage(),
      );

  PaymentsTableCompanion pay(String id, double amount, int order) =>
      PaymentsTableCompanion.insert(
        localId: id,
        documentId: orderId,
        paymentTypeId: _especes,
        amount: amount,
        userId: 9,
        date: now.add(Duration(seconds: order)),
        companyId: const Value(25),
      );

  /// Exactly what `bankCartSale` writes for a sale: the order carrier, and the
  /// document with a payment per tender.
  Future<void> bankSale(List<PaymentsTableCompanion> payments) async {
    final total = payments.fold<double>(0, (s, p) => s + p.amount.value);
    await db.insertOfflineOrder(
      PosOrdersTableCompanion.insert(
        localId: orderId,
        companyId: 25,
        userId: 9,
        serviceType: 0,
        openedAt: now,
        warehouseId: 17,
        lastModified: now,
        closedAt: Value(now),
        status: const Value(1),
        total: Value(total),
        number: const Value('POS4-200-000003'),
        paymentTypeId: const Value(_especes),
        amountPaid: Value(total),
        syncStatus: const Value('pending'),
      ),
      [
        PosOrderItemsTableCompanion(
          localId: const Value('line-1'),
          orderId: const Value(orderId),
          productId: const Value(41),
          quantity: const Value(1),
          unitPrice: Value(total),
          warehouseId: const Value(17),
          syncStatus: const Value('pending'),
        ),
      ],
    );
    await db.insertOfflineDocument(
      document: DocumentsTableCompanion.insert(
        localId: orderId,
        companyId: 25,
        userId: 9,
        warehouseId: 17,
        date: now,
        lastModified: now,
        number: const Value('POS4-200-000003'),
        total: Value(total),
        syncStatus: const Value('pending'),
      ),
      items: [
        DocumentItemsTableCompanion.insert(
          localId: 'line-1',
          documentId: orderId,
          productId: 41,
          quantity: 1,
          unitPrice: total,
          total: total,
        ),
      ],
      payment: payments.first,
      otherPayments: payments.skip(1).toList(),
    );
  }

  test('two guests paying in Espèces are pushed as two payments', () async {
    await bankSale([pay('guest-1', 184.60, 0), pay('guest-2', 198.00, 1)]);
    final spy = _BatchSyncSpy();

    await managerFor(spy).pushPendingOrders(25);

    final order = (spy.posted.single['orders'] as List).single as Map;
    expect(order['payments'], [
      {'paymentTypeId': _especes, 'amount': 184.60},
      {'paymentTypeId': _especes, 'amount': 198.00},
    ]);

    // Banked on the server: the document is linked and both rows stay — two
    // payments, both settled, never merged into one.
    final rows = await db.watchPayments(orderId).first;
    expect(rows.map((r) => r.amount), [184.60, 198.00]);
    expect(rows.map((r) => r.syncStatus).toSet(), {'synced'});
  });

  test('an ordinary sale keeps the payload it always had', () async {
    await bankSale([pay('only', 50, 0)]);
    final spy = _BatchSyncSpy();

    await managerFor(spy).pushPendingOrders(25);

    final order = (spy.posted.single['orders'] as List).single as Map;
    expect(order.containsKey('payments'), isFalse);
    expect(order['paymentTypeId'], _especes);
    expect(order['amountPaid'], 50);
  });
}
