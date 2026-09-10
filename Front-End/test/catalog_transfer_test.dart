// The catalogue's import/export formats, end to end: what an export writes, the
// importer reads back to the same thing.
//
// 🚨 Why this exists: the round trip is the whole point of an export, and it had
// never been run. A description with a line break broke the CSV import, every
// weighed product came back per-piece, only the first barcode survived, the
// colour was never written at all, and the XML flattened the group tree while
// its own screen promised to keep it.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/product/catalog_transfer.dart';
import 'package:pos_app/product/csv_codec.dart';
import 'package:pos_app/product/product_export_model.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

ProductExportRow product(
  String name, {
  String? group,
  List<String> barcodes = const [],
  int uomId = kUomPieces,
  String? unit,
  bool isToWeigh = false,
  double? packSize,
  double price = 10,
  String color = 'Transparent',
  String? description,
}) =>
    ProductExportRow(
      id: name.hashCode,
      name: name,
      productGroupName: group,
      code: 'SKU-$name',
      measurementUnit: unit,
      uomId: uomId,
      isToWeigh: isToWeigh,
      packSize: packSize,
      cost: 4,
      price: price,
      isTaxInclusivePrice: true,
      isPriceChangeAllowed: false,
      isUsingDefaultQuantity: true,
      isService: false,
      isEnabled: true,
      description: description,
      totalStock: 7,
      reorderPoint: 2,
      preferredQuantity: 10,
      isLowStockWarningEnabled: true,
      lowStockWarningQuantity: 3,
      color: color,
      barcodes: barcodes,
      taxes: const [],
    );

/// A CSV file read the way the import screen reads it.
List<Map<String, dynamic>> importCsv(String csv, List<ImportField> fields) {
  final table = parseCsv(csv);
  final mapping = autoMapColumns(table.headers, fields);
  return [for (final r in table.rows) parseImportRow(r, mapping, fields).row];
}

void main() {
  group('products as CSV', () {
    final saffron = product(
      'Saffron',
      group: 'Spices',
      barcodes: ['111', '222'],
      uomId: kUomKilogram,
      unit: 'kg',
      isToWeigh: true,
      price: 12.5,
      color: '#FF4CAF50',
      description: 'Hot, sweet\n"Moroccan"',
    );

    test('every column our export writes is matched on sight', () {
      final table = parseCsv(buildProductsCsv([saffron]));
      final mapping = autoMapColumns(table.headers, productImportFields);

      final unmatched = [for (final e in mapping.entries) if (e.value == null) e.key];
      expect(unmatched, isEmpty);
    });

    test('what the export writes, the import reads back', () {
      final row = importCsv(buildProductsCsv([saffron]), productImportFields).single;

      expect(row['name'], 'Saffron');
      expect(row['productGroupName'], 'Spices');
      expect(row['barcodes'], ['111', '222'], reason: 'every barcode, not the first');
      expect(row['measurementUnit'], 'kg', reason: 'a kilo product stays a kilo product');
      expect(row['isToWeigh'], isTrue);
      expect(row['price'], 12.5);
      expect(row['color'], '#FF4CAF50', reason: 'the colour used to be dropped');
      expect(row['description'], 'Hot, sweet\n"Moroccan"');
      expect(row['quantity'], 7);
      expect(row['isLowStockWarningEnabled'], isTrue);
    });

    test('the unit comes from the uom id when the legacy text is empty', () {
      final row = importCsv(
        buildProductsCsv([product('Rice', uomId: kUomKilogram)]),
        productImportFields,
      ).single;

      expect(row['measurementUnit'], 'kg');
    });

    test('a box product keeps its own pack size', () {
      final row = importCsv(
        buildProductsCsv([product('Eggs', uomId: kUomBox, unit: 'box', packSize: 30)]),
        productImportFields,
      ).single;

      expect(row['measurementUnit'], 'box');
      expect(row['packSize'], 30);
    });
  });

  group('a CSV someone else made', () {
    test('a French Excel file: semicolons, decimal commas, French headers', () {
      final row = importCsv(
        'Nom;Prix;Couleur;Groupe\nThé;12,50;#FF000000;Boissons\n',
        productImportFields,
      ).single;

      expect(row['name'], 'Thé');
      expect(row['price'], 12.5);
      expect(row['color'], '#FF000000');
      expect(row['productGroupName'], 'Boissons');
    });

    test('headers match without case, spaces or punctuation', () {
      final mapping = autoMapColumns(
        ['name', 'Measurement unit', 'is_service'],
        productImportFields,
      );

      expect(mapping['name'], 0);
      expect(mapping['measurementUnit'], 1);
      expect(mapping['isService'], 2);
    });

    test('a column fills one field only, and our own header wins', () {
      // "Code" is a looser alias for the SKU; "SKU" is the one we write.
      final mapping = autoMapColumns(['Code', 'SKU'], productImportFields);

      expect(mapping['code'], 1);
    });

    test('an unreadable number is sent empty and reported — never as zero', () {
      final table = parseCsv('Name,Price\nTea,twelve\n');
      final mapping = autoMapColumns(table.headers, productImportFields);

      final parsed = parseImportRow(table.rows.single, mapping, productImportFields);

      expect(parsed.row['price'], isNull);
      expect(parsed.unreadable, ['price']);
    });

    test('a field the file lacks is null, except a plain bool the server needs', () {
      final row = importCsv('Name\nTea\n', productImportFields).single;

      expect(row['price'], isNull);
      expect(row['isEnabled'], isNull, reason: 'null says nothing on a merge');
      expect(row['isToWeigh'], isFalse, reason: 'null would fail the whole request');
    });

    test('a row with no name carries an empty one, so the screen can leave it out', () {
      final row = importCsv('Name,Price\n,5\n', productImportFields).single;

      expect(row['name'], '');
    });
  });

  group('groups', () {
    final tree = [
      const GroupNode(name: 'Hot', parentName: 'Drinks', color: '#FFFF0000', rank: 2),
      const GroupNode(name: 'Drinks', color: '#FF0000FF', rank: 1),
      const GroupNode(name: 'Food'),
    ];

    test('CSV: parents before children, and every column back', () {
      final rows = importCsv(buildGroupsCsv(tree), groupImportFields);
      final names = [for (final r in rows) r['name']];

      // Roots by rank (Food 0, Drinks 1), each followed by its children.
      expect(names, ['Food', 'Drinks', 'Hot']);
      expect(names.indexOf('Drinks'), lessThan(names.indexOf('Hot')));
      expect(rows.singleWhere((r) => r['name'] == 'Hot'), {
        'name': 'Hot',
        'parentGroupName': 'Drinks',
        'color': '#FFFF0000',
        'rank': 2,
      });
    });

    test('XML: the tree survives', () {
      final back = parseGroupsXml(buildGroupsXml(tree));

      final hot = back.singleWhere((g) => g.name == 'Hot');
      expect(hot.parentName, 'Drinks');
      expect(hot.color, '#FFFF0000');
      expect(hot.rank, 2);
      expect(back.singleWhere((g) => g.name == 'Food').parentName, isNull);
    });

    test('a loop still exports every group instead of hanging', () {
      final looped = [
        const GroupNode(name: 'A', parentName: 'B'),
        const GroupNode(name: 'B', parentName: 'A'),
        const GroupNode(name: 'Root'),
      ];

      final ordered = orderParentsFirst(looped).map((g) => g.name).toList();

      expect(ordered.first, 'Root');
      expect(ordered, containsAll(['A', 'B', 'Root']));
      expect(ordered, hasLength(3));
    });
  });

  group('products as XML', () {
    final groups = [
      const GroupNode(name: 'Drinks', color: '#FF0000FF'),
      const GroupNode(name: 'Hot', parentName: 'Drinks', color: '#FFFF0000'),
    ];
    final tea = product(
      'Mint tea',
      group: 'Hot',
      barcodes: ['555', '666'],
      uomId: kUomLitre,
      unit: 'L',
      isToWeigh: true,
      color: '#FF4CAF50',
    );
    final loose = product('Loose', barcodes: ['777']);

    test('each product lands under its full group path', () {
      final rows = parseProductsXml(buildProductsXml([tea, loose], groups));

      final back = rows.singleWhere((r) => r['name'] == 'Mint tea');
      expect(back['productGroupPath'], ['Drinks', 'Hot']);
      expect(back['barcodes'], ['555', '666']);
      expect(back['isToWeigh'], isTrue);
      expect(back['color'], '#FF4CAF50');

      final ungrouped = rows.singleWhere((r) => r['name'] == 'Loose');
      expect(ungrouped['productGroupPath'], isEmpty);
    });

    test('the group skeleton keeps its colours for the groups import', () {
      final back = parseGroupsXml(buildProductsXml([tea], groups));

      expect(back.singleWhere((g) => g.name == 'Hot').color, '#FFFF0000');
      expect(back.singleWhere((g) => g.name == 'Drinks').color, '#FF0000FF');
    });
  });
}
