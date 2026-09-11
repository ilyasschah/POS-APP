// The Stock Moves read model against real SQLite: which document lines become
// moves, in what order, with what status, and what the page says about more.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/document/document_type_constants.dart';
import 'package:pos_app/stock/stock_move_line.dart';
import 'package:pos_app/sync/sync_status.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

const kCompany = 1;
const kOtherCompany = 2;
const kMain = 10;
const kAnnex = 11;
const kAlice = 7;

const kMintTea = 100;
const kSaffron = 101;
const kDelivery = 102; // a service

void main() {
  late AppDatabase db;
  var seq = 0;
  final t0 = DateTime.utc(2026, 10, 1, 9);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.utc(2026, 10, 1);
    for (final (id, name) in [(kMain, 'Main'), (kAnnex, 'Annex')]) {
      await db.into(db.warehousesTable).insert(WarehousesTableCompanion(
            id: Value(id),
            companyId: const Value(kCompany),
            name: Value(name),
            lastModified: Value(now),
          ));
    }
    await db.into(db.usersTable).insert(UsersTableCompanion(
          id: const Value(kAlice),
          companyId: const Value(kCompany),
          name: const Value('Alice Brown'),
          lastModified: Value(now),
        ));
    for (final (id, name, barcode, uom, service) in [
      (kMintTea, 'Mint tea', '6111245', kUomPieces, false),
      (kSaffron, 'Saffron', null, kUomGram, false),
      (kDelivery, 'Delivery', null, kUomPieces, true),
    ]) {
      await db.into(db.productsTable).insert(ProductsTableCompanion(
            id: Value(id),
            companyId: const Value(kCompany),
            name: Value(name),
            barcode: Value(barcode),
            uomId: Value(uom),
            isService: Value(service),
            lastModified: Value(now),
          ));
    }
    await db.into(db.barcodesTable).insert(const BarcodesTableCompanion(
          localId: Value('bc-1'),
          productId: Value(kMintTea),
          companyId: Value(kCompany),
          value: Value('ALT-777'),
        ));
  });

  tearDown(() => db.close());

  Future<String> addDocument(
    int type, {
    required DateTime date,
    DateTime? stockDate,
    String? number,
    int? serverId = 1,
    String syncStatus = SyncStatuses.synced,
    int warehouseId = kMain,
    int companyId = kCompany,
  }) async {
    final localId = 'doc-${seq++}';
    await db.into(db.documentsTable).insert(DocumentsTableCompanion(
          localId: Value(localId),
          serverId: Value(serverId),
          companyId: Value(companyId),
          documentTypeId: Value(type),
          number: Value(number ?? 'N-$seq'),
          userId: const Value(kAlice),
          warehouseId: Value(warehouseId),
          date: Value(date),
          stockDate: Value(stockDate),
          syncStatus: Value(syncStatus),
          lastModified: Value(date),
        ));
    return localId;
  }

  Future<String> addLine(
    String documentId,
    int productId,
    double quantity, {
    double? expected,
    String syncStatus = SyncStatuses.synced,
  }) async {
    final localId = 'line-${seq++}';
    await db.into(db.documentItemsTable).insert(DocumentItemsTableCompanion(
          localId: Value(localId),
          documentId: Value(documentId),
          productId: Value(productId),
          quantity: Value(quantity),
          unitPrice: const Value(0),
          total: const Value(0),
          expectedQuantity: Value(expected),
          syncStatus: Value(syncStatus),
        ));
    return localId;
  }

  Future<StockMovePage> read({
    int limit = 200,
    int? warehouseId,
    String? search,
    int companyId = kCompany,
  }) =>
      db
          .watchStockMoves(
            companyId: companyId,
            limit: limit,
            warehouseId: warehouseId,
            search: search,
          )
          .first;

  test('every moving type becomes a move, newest first; a proforma never does',
      () async {
    final types = [
      DocumentTypes.purchase,
      DocumentTypes.sales,
      DocumentTypes.inventoryCount,
      DocumentTypes.refund,
      DocumentTypes.stockReturn,
      DocumentTypes.lossAndDamage,
      DocumentTypes.proforma,
    ];
    for (var i = 0; i < types.length; i++) {
      final doc =
          await addDocument(types[i], date: t0.add(Duration(hours: i)));
      // The count found 2 where the system held 5.
      await addLine(doc, kMintTea, 2,
          expected: types[i] == DocumentTypes.inventoryCount ? 5 : null);
    }

    final page = await read();

    expect(page.lines.map((m) => m.documentTypeId), [
      DocumentTypes.lossAndDamage,
      DocumentTypes.stockReturn,
      DocumentTypes.refund,
      DocumentTypes.inventoryCount,
      DocumentTypes.sales,
      DocumentTypes.purchase,
    ]);
    final count = page.lines
        .singleWhere((m) => m.documentTypeId == DocumentTypes.inventoryCount);
    expect((count.from, count.to, count.quantity), (
      StockLocationKind.warehouse,
      StockLocationKind.inventoryAdjustment,
      3.0,
    ));
    expect(count.isIncoming, isFalse);
  });

  test('service products, deleted lines and deleted documents are left out',
      () async {
    final sale = await addDocument(DocumentTypes.sales, date: t0);
    await addLine(sale, kMintTea, 1);
    await addLine(sale, kDelivery, 1);
    await addLine(sale, kSaffron, 250, syncStatus: SyncStatuses.pendingDelete);
    final gone = await addDocument(DocumentTypes.purchase,
        date: t0, syncStatus: SyncStatuses.pendingDelete);
    await addLine(gone, kMintTea, 10);

    final page = await read();

    expect(page.lines.map((m) => m.productId), [kMintTea]);
  });

  test('the stock date is when the goods moved; the document date otherwise',
      () async {
    final backDated = await addDocument(DocumentTypes.purchase,
        date: t0, stockDate: t0.add(const Duration(hours: 5)), number: 'LATE');
    await addLine(backDated, kMintTea, 1);
    final plain = await addDocument(DocumentTypes.purchase,
        date: t0.add(const Duration(hours: 2)), number: 'PLAIN');
    await addLine(plain, kMintTea, 1);

    final page = await read();

    expect(page.lines.map((m) => m.documentNumber), ['LATE', 'PLAIN']);
    expect(page.lines.first.date, t0.add(const Duration(hours: 5)));
    expect(page.lines.first.date.isUtc, isTrue);
  });

  test('a move is pending until the server has both its document and its line',
      () async {
    final synced = await addDocument(DocumentTypes.purchase, date: t0);
    await addLine(synced, kMintTea, 1);
    final unsyncedSale = await addDocument(DocumentTypes.sales,
        date: t0, serverId: null, syncStatus: SyncStatuses.pending);
    await addLine(unsyncedSale, kMintTea, 1);
    final editedLine = await addDocument(DocumentTypes.lossAndDamage, date: t0);
    await addLine(editedLine, kMintTea, 1,
        syncStatus: SyncStatuses.pendingCreate);

    final byType = {
      for (final m in (await read()).lines) m.documentTypeId: m.status
    };

    expect(byType[DocumentTypes.purchase], StockMoveStatus.done);
    expect(byType[DocumentTypes.sales], StockMoveStatus.pendingSync);
    expect(byType[DocumentTypes.lossAndDamage], StockMoveStatus.pendingSync);
  });

  test('the page says whether more lines lie behind its limit', () async {
    for (var i = 0; i < 5; i++) {
      final doc = await addDocument(DocumentTypes.purchase,
          date: t0.add(Duration(minutes: i)));
      await addLine(doc, kMintTea, 1);
    }

    final first = await read(limit: 3);
    expect(first.lines, hasLength(3));
    expect(first.hasMore, isTrue);

    final all = await read(limit: 10);
    expect(all.lines, hasLength(5));
    expect(all.hasMore, isFalse);
  });

  test('a count that agreed still counts as a line read for paging', () async {
    final count = await addDocument(DocumentTypes.inventoryCount,
        date: t0.add(const Duration(hours: 1)));
    await addLine(count, kMintTea, 4, expected: 4);
    final older = await addDocument(DocumentTypes.purchase, date: t0);
    await addLine(older, kMintTea, 1);

    final page = await read(limit: 1);

    // The agreeing count was read and dropped: nothing to show, but the
    // purchase behind it is still there to be paged to.
    expect(page.lines, isEmpty);
    expect(page.hasMore, isTrue);
  });

  test('search finds a product by name, by either barcode, and by reference',
      () async {
    final purchase =
        await addDocument(DocumentTypes.purchase, date: t0, number: 'PO-9');
    await addLine(purchase, kMintTea, 1);
    final saffron = await addDocument(DocumentTypes.purchase,
        date: t0, number: 'PO-10');
    await addLine(saffron, kSaffron, 5);

    Future<List<int>> found(String term) async =>
        [for (final m in (await read(search: term)).lines) m.productId];

    expect(await found('mint'), [kMintTea]);
    expect(await found('6111'), [kMintTea]);
    expect(await found('ALT-777'), [kMintTea]);
    expect(await found('PO-10'), [kSaffron]);
    // LIKE wildcards are the operator's text, not a pattern.
    expect(await found('%'), isEmpty);
    expect(await found('_'), isEmpty);
  });

  test('the warehouse filter and the company both scope the history',
      () async {
    final main = await addDocument(DocumentTypes.purchase, date: t0);
    await addLine(main, kMintTea, 1);
    final annex = await addDocument(DocumentTypes.purchase,
        date: t0, warehouseId: kAnnex);
    await addLine(annex, kSaffron, 1);
    final elsewhere = await addDocument(DocumentTypes.purchase,
        date: t0, companyId: kOtherCompany);
    await addLine(elsewhere, kMintTea, 1);

    expect((await read()).lines, hasLength(2));
    expect((await read(warehouseId: kAnnex)).lines.single.productId, kSaffron);
    expect((await read(companyId: kOtherCompany)).lines, hasLength(1));
  });

  test('the names are joined in', () async {
    final doc = await addDocument(DocumentTypes.purchase,
        date: t0, number: '26-100-000001');
    await addLine(doc, kSaffron, 250);

    final move = (await read()).lines.single;

    expect(move.documentNumber, '26-100-000001');
    expect(move.productName, 'Saffron');
    expect(move.barcode, isNull);
    expect(move.uomId, kUomGram);
    expect(move.warehouseName, 'Main');
    expect(move.userName, 'Alice Brown');
    expect(move.quantity, 250);
  });

  test('a write re-emits the history', () async {
    final lengths = db
        .watchStockMoves(companyId: kCompany, limit: 50)
        .map((p) => p.lines.length);
    final later = expectLater(lengths, emitsThrough(1));

    final doc = await addDocument(DocumentTypes.sales, date: t0);
    await addLine(doc, kMintTea, 1);

    await later;
  });

  test('a deleted document takes its moves with it, and only then', () async {
    final kept =
        await addDocument(DocumentTypes.purchase, date: t0, number: 'KEPT');
    await addLine(kept, kMintTea, 1);
    final syncedGone = await addDocument(DocumentTypes.purchase,
        date: t0, number: 'SYNCED-GONE');
    await addLine(syncedGone, kMintTea, 2);
    final localGone = await addDocument(DocumentTypes.purchase,
        date: t0,
        number: 'LOCAL-GONE',
        serverId: null,
        syncStatus: SyncStatuses.pendingCreate);
    await addLine(localGone, kSaffron, 3);

    // The only way a move leaves: its document is deleted. A synced one is
    // soft-deleted until the push reaches the server; one the server never
    // saw is removed outright.
    await db.deleteDocumentLocal(syncedGone);
    await db.deleteDocumentLocal(localGone);

    expect((await read()).lines.map((m) => m.documentNumber), ['KEPT']);

    // Once the push drops the soft-deleted row, its lines go with it — no
    // orphan line is left behind to come back as a move.
    await (db.delete(db.documentsTable)
          ..where((t) => t.localId.equals(syncedGone)))
        .go();
    final orphans = await (db.select(db.documentItemsTable)
          ..where((t) => t.documentId.isIn([syncedGone, localGone])))
        .get();
    expect(orphans, isEmpty);
  });

  test('an export reads every move the filter matches, not one page',
      () async {
    for (var i = 0; i < 5; i++) {
      final doc = await addDocument(DocumentTypes.purchase,
          date: t0.add(Duration(minutes: i)));
      await addLine(doc, i.isEven ? kMintTea : kSaffron, 1);
    }

    expect(await db.getStockMoves(companyId: kCompany), hasLength(5));
    expect(
        await db.getStockMoves(companyId: kCompany, search: 'saffron'),
        hasLength(2));
    // Newest first, like the screen.
    final all = await db.getStockMoves(companyId: kCompany);
    expect(all.first.date, t0.add(const Duration(minutes: 4)));
  });

  group('narrowed to one product', () {
    test('lists that product only, newest first', () async {
      for (var i = 0; i < 4; i++) {
        final doc = await addDocument(DocumentTypes.purchase,
            date: t0.add(Duration(minutes: i)));
        await addLine(doc, i.isEven ? kMintTea : kSaffron, 1);
      }

      final page = await db
          .watchStockMoves(companyId: kCompany, limit: 50, productId: kSaffron)
          .first;

      expect(page.lines.map((m) => m.productId), [kSaffron, kSaffron]);
      expect(page.lines.first.date, t0.add(const Duration(minutes: 3)));
    });

    test('still pages: the limit counts that product’s lines', () async {
      for (var i = 0; i < 3; i++) {
        final doc = await addDocument(DocumentTypes.purchase,
            date: t0.add(Duration(minutes: i)));
        await addLine(doc, kMintTea, 1);
        await addLine(doc, kSaffron, 1);
      }

      final page = await db
          .watchStockMoves(companyId: kCompany, limit: 2, productId: kMintTea)
          .first;

      expect(page.lines, hasLength(2));
      expect(page.hasMore, isTrue);
    });

    test("is answered by the product index", () async {
      final names = (await db
              .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'index'")
              .get())
          .map((r) => r.read<String>('name'))
          .toSet();

      expect(names, contains('idx_document_items_product_id'));
    });
  });

  group('narrowed to a period', () {
    // Local days — the range picker hands back calendar days on this device.
    final day = DateTime(2026, 9, 10);

    Future<void> moveAt(DateTime when, String number) async {
      final doc = await addDocument(DocumentTypes.purchase,
          date: when, number: number);
      await addLine(doc, kMintTea, 1);
    }

    test('takes whole days, both ends included', () async {
      await moveAt(day.subtract(const Duration(minutes: 1)), 'EVE');
      await moveAt(day, 'MIDNIGHT');
      await moveAt(day.add(const Duration(hours: 23, minutes: 59)), 'LATE');
      await moveAt(day.add(const Duration(days: 1)), 'NEXT');

      final page = await db
          .watchStockMoves(
            companyId: kCompany,
            limit: 50,
            dateRange: DateTimeRange(start: day, end: day),
          )
          .first;

      expect(page.lines.map((m) => m.documentNumber), ['LATE', 'MIDNIGHT']);
    });

    test('reads the stock date when there is one', () async {
      // Dated outside the period, but its goods moved inside it.
      final doc = await addDocument(DocumentTypes.purchase,
          date: day.subtract(const Duration(days: 5)),
          stockDate: day.add(const Duration(hours: 9)),
          number: 'BACKDATED');
      await addLine(doc, kMintTea, 1);

      final page = await db
          .watchStockMoves(
            companyId: kCompany,
            limit: 50,
            dateRange: DateTimeRange(start: day, end: day),
          )
          .first;

      expect(page.lines.single.documentNumber, 'BACKDATED');
    });

    test('combines with the product, and reaches the export too', () async {
      await moveAt(day.add(const Duration(hours: 1)), 'IN');
      final saffron = await addDocument(DocumentTypes.purchase,
          date: day.add(const Duration(hours: 2)), number: 'OTHER');
      await addLine(saffron, kSaffron, 1);
      await moveAt(day.add(const Duration(days: 3)), 'OUT');

      final exported = await db.getStockMoves(
        companyId: kCompany,
        productId: kMintTea,
        dateRange: DateTimeRange(start: day, end: day),
      );

      expect(exported.map((m) => m.documentNumber), ['IN']);
    });
  });

  group('stockOnHandInProductUnit', () {
    test("reads reference-unit stock in the product's own unit", () async {
      await db.into(db.stocksTable).insert(StocksTableCompanion(
            id: const Value(1),
            productId: const Value(kSaffron),
            warehouseId: const Value(kMain),
            companyId: const Value(kCompany),
            quantity: const Value(0.4), // kg
            lastModified: Value(t0),
          ));

      expect(
          await db.stockOnHandInProductUnit(
              productId: kSaffron, warehouseId: kMain),
          400); // g
    });

    test('is zero where nothing was ever stocked', () async {
      expect(
          await db.stockOnHandInProductUnit(
              productId: kMintTea, warehouseId: kAnnex),
          0);
    });
  });

  test("the history's indexes exist on a fresh install", () async {
    final names = (await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
            .get())
        .map((r) => r.read<String>('name'))
        .toSet();

    expect(names, contains('idx_document_items_document_id'));
    expect(names, contains('idx_documents_company_move_date'));
  });
}
