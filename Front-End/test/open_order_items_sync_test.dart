// Pins that a cross-device open order arrives WITH ITS LINE ITEMS.
//
// The bug this guards: `syncOpenOrdersToDrift` wrote only the `pos_orders`
// header. An order rung up on a tablet therefore landed on the Windows POS as a
// header-only row — correct number, correct total, ZERO items. Both reopen paths
// (`loadExistingOrder` from a floor-plan tap, `loadOrderById` from the Open
// Orders list) return `loadOrderFromLocal` the instant a local row exists, so
// their API fallbacks never ran and the cashier opened an EMPTY CART showing a
// non-zero total.
//
// Nothing else in the repo catches this: the header row is present and correct,
// analyze is clean, and the failure only appears with two devices and a network.
// Hence a DB-level test with the API stubbed.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/menu/open_orders_screen.dart';

/// Stands in for the server. Only the two methods the sync calls are overridden;
/// ApiClient's constructor just builds a Dio, so nothing reaches the network.
class _FakeApi extends ApiClient {
  _FakeApi({required this.orders, required this.items});

  final List<dynamic> orders;
  final List<dynamic> items;
  int getOrderItemsCalls = 0;

  @override
  Future<List<dynamic>> getAllPosOrders(int companyId) async => orders;

  @override
  Future<List<dynamic>> getOrderItems(int companyId, int posOrderId) async {
    getOrderItemsCalls++;
    return items;
  }
}

const _order = {
  'id': 77,
  'number': 'ORD- T4',
  'userId': 3,
  'floorPlanTableId': 12,
  'serviceType': 0,
  'serviceStatus': 1,
  'total': 45.0,
  'warehouseId': 2,
};

const _items = [
  {
    'id': 501,
    'productId': 9,
    'quantity': 2.0,
    'price': 15.0,
    'discount': 0.0,
    'discountType': 0,
    'comment': 'no ice',
    'taxes': [
      {'id': 4, 'name': 'VAT', 'rate': 20.0},
    ],
  },
  {
    'id': 502,
    'productId': 11,
    'quantity': 1.0,
    'price': 15.0,
    'discount': 0.0,
    'discountType': 0,
  },
];

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<PosOrderItemsTableData>> itemsFor(String localId) =>
      (db.select(db.posOrderItemsTable)
            ..where((t) => t.orderId.equals(localId)))
          .get();

  test('an order seen for the first time lands with its lines, not just a header',
      () async {
    final api = _FakeApi(orders: [_order], items: _items);

    await syncOpenOrdersToDrift(db, 1, api: api);

    final header = await (db.select(db.posOrdersTable)
          ..where((t) => t.serverId.equals(77)))
        .getSingleOrNull();
    expect(header, isNotNull, reason: 'header row should exist');

    // The assertion that fails against the pre-fix code: it was 0.
    final lines = await itemsFor(header!.localId);
    expect(lines, hasLength(2), reason: 'cart would be empty without these');

    final first = lines.firstWhere((l) => l.productId == 9);
    expect(first.quantity, 2.0);
    expect(first.unitPrice, 15.0);
    expect(first.comment, 'no ice');
    // Warehouse comes off the ORDER — the item payload carries none, and the
    // column is non-nullable.
    expect(first.warehouseId, 2);
    // Pulled from the server, so there is nothing to push back.
    expect(first.syncStatus, 'synced');
    // loadOrderFromLocal reads the tax IDs out of this and re-derives the rate
    // from the local taxes cache.
    expect(first.taxesJson, contains('"id":4'));

    expect(lines.firstWhere((l) => l.productId == 11).taxesJson, isNull);
  });

  test('re-syncing an unchanged order does not refetch its lines', () async {
    final api = _FakeApi(orders: [_order], items: _items);

    await syncOpenOrdersToDrift(db, 1, api: api);
    expect(api.getOrderItemsCalls, 1);

    // This poll runs every 20s; refetching every open order each tick would be
    // one request per order forever.
    await syncOpenOrdersToDrift(db, 1, api: api);
    expect(api.getOrderItemsCalls, 1, reason: 'nothing changed — no refetch');
    expect(await itemsFor('svr_77'), hasLength(2));
  });

  test('a total change on another terminal refreshes the lines', () async {
    final api = _FakeApi(orders: [_order], items: _items);
    await syncOpenOrdersToDrift(db, 1, api: api);

    final edited = _FakeApi(
      orders: [
        {..._order, 'total': 60.0},
      ],
      items: [
        ..._items,
        {'id': 503, 'productId': 12, 'quantity': 1.0, 'price': 15.0},
      ],
    );
    await syncOpenOrdersToDrift(db, 1, api: edited);

    expect(edited.getOrderItemsCalls, 1);
    // Stale lines beside a fresh total is the same class of bug as no lines at
    // all: the cart and the header would disagree.
    expect(await itemsFor('svr_77'), hasLength(3));
  });

  test('a same-price swap on another terminal still refreshes the lines',
      () async {
    // The case that total-only detection misses: product 11 is replaced by
    // product 12 at the SAME price, so total AND item count are unchanged. Only
    // ItemsLastChanged moves (a swap deletes a row and inserts a new one).
    final api = _FakeApi(
      orders: [
        {..._order, 'itemCount': 2, 'itemsLastChanged': '2026-07-24T10:00:00Z'},
      ],
      items: _items,
    );
    await syncOpenOrdersToDrift(db, 1, api: api);
    expect(api.getOrderItemsCalls, 1);

    final swapped = _FakeApi(
      orders: [
        {..._order, 'itemCount': 2, 'itemsLastChanged': '2026-07-24T10:05:00Z'},
      ],
      items: [
        _items.first,
        {'id': 504, 'productId': 12, 'quantity': 1.0, 'price': 15.0},
      ],
    );
    await syncOpenOrdersToDrift(db, 1, api: swapped);

    expect(swapped.getOrderItemsCalls, 1, reason: 'stamp moved — must refetch');
    final lines = await itemsFor('svr_77');
    expect(lines.map((l) => l.productId), containsAll([9, 12]));
    expect(lines.map((l) => l.productId), isNot(contains(11)));

    // And it settles: a third poll with nothing new must not refetch again.
    final quiet = _FakeApi(
      orders: [
        {..._order, 'itemCount': 2, 'itemsLastChanged': '2026-07-24T10:05:00Z'},
      ],
      items: const [],
    );
    await syncOpenOrdersToDrift(db, 1, api: quiet);
    expect(quiet.getOrderItemsCalls, 0, reason: 'stamp was persisted');
  });

  test('an order with unpushed local edits keeps its own lines', () async {
    // A row this device created and has not synced yet. The pull must not touch
    // it — deleting its lines would destroy work the server has never seen.
    await db.into(db.posOrdersTable).insert(
          PosOrdersTableCompanion.insert(
            localId: 'local-uuid-1',
            companyId: 1,
            userId: 3,
            serviceType: 0,
            openedAt: DateTime.now().toUtc(),
            status: const Value(0),
            warehouseId: 2,
            lastModified: DateTime.now().toUtc(),
            serverId: const Value(77),
            total: const Value(45.0),
            syncStatus: const Value('pending_update'),
          ),
        );
    await db.into(db.posOrderItemsTable).insert(
          PosOrderItemsTableCompanion.insert(
            localId: 'mine-1',
            orderId: 'local-uuid-1',
            productId: 99,
            quantity: 5,
            unitPrice: 3,
            warehouseId: 2,
          ),
        );

    final api = _FakeApi(orders: [_order], items: _items);
    await syncOpenOrdersToDrift(db, 1, api: api);

    expect(api.getOrderItemsCalls, 0, reason: 'must not touch a pending row');
    final lines = await itemsFor('local-uuid-1');
    expect(lines, hasLength(1));
    expect(lines.single.productId, 99);
  });
}
