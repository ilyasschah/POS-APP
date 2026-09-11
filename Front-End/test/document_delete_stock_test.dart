// Deleting a document gives back the stock its lines moved — on this till, at
// once — by the server's rule for deleting a line: a Purchase takes back what
// it received, a Stock Return and a Loss & Damage put back what they removed,
// and nothing else is touched.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/document/document_type_constants.dart';
import 'package:pos_app/sync/sync_status.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

const kCompany = 1;
const kMain = 10;
const kAnnex = 11;

const kMintTea = 100; // counted in pieces
const kSaffron = 101; // sold by the gram, stocked in kilograms
const kUntracked = 102; // never stocked on this till

void main() {
  late AppDatabase db;
  var seq = 0;
  final now = DateTime.utc(2026, 9, 11);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (final (id, uom) in [
      (kMintTea, kUomPieces),
      (kSaffron, kUomGram),
      (kUntracked, kUomPieces),
    ]) {
      await db.into(db.productsTable).insert(ProductsTableCompanion(
            id: Value(id),
            companyId: const Value(kCompany),
            name: Value('Product $id'),
            uomId: Value(uom),
            lastModified: Value(now),
          ));
    }
    // Mint tea: 25 pcs in Main, 7 in the Annex. Saffron: 1 kg in Main.
    for (final (id, product, warehouse, quantity) in [
      (1, kMintTea, kMain, 25.0),
      (2, kMintTea, kAnnex, 7.0),
      (3, kSaffron, kMain, 1.0),
    ]) {
      await db.into(db.stocksTable).insert(StocksTableCompanion(
            id: Value(id),
            productId: Value(product),
            warehouseId: Value(warehouse),
            companyId: const Value(kCompany),
            quantity: Value(quantity),
            lastModified: Value(now),
          ));
    }
  });

  tearDown(() => db.close());

  Future<StocksTableData> stockRow(int productId, [int warehouseId = kMain]) =>
      (db.select(db.stocksTable)
            ..where((t) => t.productId.equals(productId))
            ..where((t) => t.warehouseId.equals(warehouseId)))
          .getSingle();

  Future<double> stockOf(int productId, [int warehouseId = kMain]) async =>
      (await stockRow(productId, warehouseId)).quantity;

  /// A document in Main. By default the server has it and every line of it —
  /// the ordinary shape of anything a delete reaches.
  Future<String> document(
    int type,
    List<(int, double)> lines, {
    int? serverId = 1,
    String syncStatus = SyncStatuses.synced,
    int? lineServerId = 1,
    String lineStatus = SyncStatuses.synced,
  }) async {
    final localId = 'doc-${seq++}';
    await db.into(db.documentsTable).insert(DocumentsTableCompanion(
          localId: Value(localId),
          serverId: Value(serverId),
          companyId: const Value(kCompany),
          documentTypeId: Value(type),
          userId: const Value(1),
          warehouseId: const Value(kMain),
          date: Value(now),
          syncStatus: Value(syncStatus),
          lastModified: Value(now),
        ));
    for (final (product, quantity) in lines) {
      await db.into(db.documentItemsTable).insert(DocumentItemsTableCompanion(
            localId: Value('line-${seq++}'),
            documentId: Value(localId),
            serverId: Value(lineServerId),
            productId: Value(product),
            quantity: Value(quantity),
            unitPrice: const Value(0),
            total: const Value(0),
            syncStatus: Value(lineStatus),
          ));
    }
    return localId;
  }

  group('deleting a document gives back what its lines moved', () {
    test('a Purchase takes back what it received', () async {
      final doc = await document(DocumentTypes.purchase, [(kMintTea, 10)]);

      await db.deleteDocumentLocal(doc);

      expect(await stockOf(kMintTea), 15);
    });

    test('a Stock Return puts back what it sent to the vendor', () async {
      final doc = await document(DocumentTypes.stockReturn, [(kMintTea, 4)]);

      await db.deleteDocumentLocal(doc);

      expect(await stockOf(kMintTea), 29);
    });

    test('a Loss & Damage puts back what it wrote off', () async {
      final doc = await document(DocumentTypes.lossAndDamage, [(kMintTea, 3)]);

      await db.deleteDocumentLocal(doc);

      expect(await stockOf(kMintTea), 28);
    });

    test('every line counts, several of one product included', () async {
      final doc = await document(
          DocumentTypes.purchase, [(kMintTea, 3), (kMintTea, 4), (kSaffron, 100)]);

      await db.deleteDocumentLocal(doc);

      expect(await stockOf(kMintTea), 18);
      expect(await stockOf(kSaffron), 0.9);
    });

    test('a weighed line is converted to the stock unit, like the server does',
        () async {
      // 250 g bought; the stock row holds kilograms.
      final doc = await document(DocumentTypes.purchase, [(kSaffron, 250)]);

      await db.deleteDocumentLocal(doc);

      expect(await stockOf(kSaffron), 0.75);
    });

    test("only the document's own warehouse moves", () async {
      final doc = await document(DocumentTypes.purchase, [(kMintTea, 10)]);

      await db.deleteDocumentLocal(doc);

      expect(await stockOf(kMintTea, kAnnex), 7);
    });
  });

  group('and gives back nothing', () {
    for (final (name, type) in [
      ('a sale', DocumentTypes.sales),
      ('a refund', DocumentTypes.refund),
      ('an inventory count', DocumentTypes.inventoryCount),
      ('a proforma', DocumentTypes.proforma),
    ]) {
      test('for $name — its lines never moved stock on delete', () async {
        final doc = await document(type, [(kMintTea, 5)]);

        await db.deleteDocumentLocal(doc);

        expect(await stockOf(kMintTea), 25);
      });
    }

    test('for a line that never reached the server', () async {
      // The server applies a line's stock when it receives it; this one it
      // never did, so no stock was ever added to take back.
      final doc = await document(DocumentTypes.purchase, [(kMintTea, 10)],
          lineServerId: null, lineStatus: SyncStatuses.pendingCreate);

      await db.deleteDocumentLocal(doc);

      expect(await stockOf(kMintTea), 25);
    });

    test('for a document the server never saw — and it is gone outright',
        () async {
      final doc = await document(DocumentTypes.purchase, [(kMintTea, 10)],
          serverId: null,
          syncStatus: SyncStatuses.pendingCreate,
          lineServerId: null,
          lineStatus: SyncStatuses.pendingCreate);

      await db.deleteDocumentLocal(doc);

      expect(await stockOf(kMintTea), 25);
      expect(await db.getDocumentByLocalId(doc), isNull);
    });

    test('for a product this till never stocked — no row is invented',
        () async {
      final doc = await document(DocumentTypes.purchase, [(kUntracked, 5)]);

      await db.deleteDocumentLocal(doc);

      final rows = await (db.select(db.stocksTable)
            ..where((t) => t.productId.equals(kUntracked)))
          .get();
      expect(rows, isEmpty);
    });

    test('a second time, when the same document is deleted again', () async {
      final doc = await document(DocumentTypes.purchase, [(kMintTea, 10)]);

      await db.deleteDocumentLocal(doc);
      await db.deleteDocumentLocal(doc);

      expect(await stockOf(kMintTea), 15);
    });
  });

  test('a pushed line soft-deleted since is still given back', () async {
    // The server still holds it, and reverses it along with the document.
    final doc = await document(DocumentTypes.purchase, [(kMintTea, 10)],
        lineStatus: SyncStatuses.pendingDelete);

    await db.deleteDocumentLocal(doc);

    expect(await stockOf(kMintTea), 15);
  });

  test('the stock row is corrected, not queued to be pushed', () async {
    // The server does its own reversal when the delete lands; pushing this
    // figure as an edit on top of it would take the stock out twice.
    final doc = await document(DocumentTypes.purchase, [(kMintTea, 10)]);

    await db.deleteDocumentLocal(doc);

    expect((await stockRow(kMintTea)).syncStatus, SyncStatuses.synced);
  });

  test('the synced document waits, soft-deleted, for its delete to be pushed',
      () async {
    final doc = await document(DocumentTypes.purchase, [(kMintTea, 10)]);

    await db.deleteDocumentLocal(doc);

    expect((await db.getDocumentByLocalId(doc))?.syncStatus,
        SyncStatuses.pendingDelete);
  });
}
