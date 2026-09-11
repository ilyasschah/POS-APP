/// The import/export file formats for the product catalogue and its groups.
///
/// Kept apart from the screens so every format can be written and read back in
/// a test — the round trip is the whole point of an export, and it was never
/// checked: a description with a line break broke the CSV import, every weighed
/// product came back as a per-piece one, only the first barcode survived, and
/// the XML flattened the group tree while its own screen promised to keep it.
library;

import 'package:pos_app/product/csv_codec.dart';
import 'package:pos_app/product/product_export_model.dart';
import 'package:pos_app/uom/unit_of_measure.dart';
import 'package:xml/xml.dart';

// ── Groups ──────────────────────────────────────────────────────────────────

/// A product group as a file carries it: identified by NAME, which the server
/// keeps unique per company, and placed by its parent's name — so a file from
/// one company means the same thing in another, where no id does.
class GroupNode {
  const GroupNode({
    required this.name,
    this.parentName,
    this.color = 'Transparent',
    this.rank = 0,
  });

  /// One row of `/ProductGroups/GetForExport`.
  factory GroupNode.fromExportJson(Map<String, dynamic> j) => GroupNode(
        name: (j['name'] as String? ?? '').trim(),
        parentName: _blankToNull(j['parentGroupName'] as String?),
        color: _blankToNull(j['color'] as String?) ?? 'Transparent',
        rank: (j['rank'] as num?)?.toInt() ?? 0,
      );

  final String name;
  final String? parentName;
  final String color;
  final int rank;

  String get key => _key(name);

  /// The body `/ProductGroups/ImportBulk` expects for this group.
  Map<String, dynamic> toImportJson() => {
        'name': name,
        'parentGroupName': parentName,
        'color': color,
        'rank': rank,
      };
}

/// Parents before children, siblings by rank then name. A group whose parent is
/// not in the list comes out as a root; the members of a loop come out last, as
/// they are — nothing is ever dropped from an export.
List<GroupNode> orderParentsFirst(Iterable<GroupNode> groups) {
  final all = groups.where((g) => g.name.trim().isNotEmpty).toList();
  final byKey = {for (final g in all) g.key: g};

  String? parentKey(GroupNode g) {
    final p = g.parentName;
    if (p == null) return null;
    final k = _key(p);
    return byKey.containsKey(k) && k != g.key ? k : null;
  }

  final children = <String?, List<GroupNode>>{};
  for (final g in all) {
    (children[parentKey(g)] ??= []).add(g);
  }
  for (final list in children.values) {
    list.sort(_byRankThenName);
  }

  final out = <GroupNode>[];
  final seen = <String>{};
  void walk(String? parent) {
    for (final g in children[parent] ?? const <GroupNode>[]) {
      if (!seen.add(g.key)) continue;
      out.add(g);
      walk(g.key);
    }
  }

  walk(null);
  final loopMembers = all.where((g) => !seen.contains(g.key)).toList()
    ..sort(_byRankThenName);
  for (final g in loopMembers) {
    if (seen.add(g.key)) out.add(g);
  }
  return out;
}

/// The chain from the root to [leaf], by name. Stops at a loop or at a parent
/// the list does not know.
List<String> groupPathOf(String? leaf, Map<String, GroupNode> byKey) {
  final start = _blankToNull(leaf);
  if (start == null) return const [];
  final path = <String>[];
  final seen = <String>{};
  for (String? at = start; at != null && seen.add(_key(at));) {
    final node = byKey[_key(at)];
    path.insert(0, node?.name ?? at);
    at = node?.parentName;
  }
  return path;
}

const List<String> groupCsvHeaders = ['Name', 'Parent', 'Color', 'Rank'];

/// Groups as CSV, parents first so a reader always meets a parent before the
/// group that names it.
String buildGroupsCsv(Iterable<GroupNode> groups) => encodeCsv([
      groupCsvHeaders,
      for (final g in orderParentsFirst(groups))
        [g.name, g.parentName, g.color, g.rank],
    ]);

/// Groups as XML, nested the way they are nested — the same schema as the
/// product export, so either file carries the same tree.
String buildGroupsXml(Iterable<GroupNode> groups) {
  final tree = _GroupTree(groups);
  return _document((b) {
    for (final root in tree.roots) {
      _writeGroup(b, tree, root, null);
    }
  });
}

/// Every group in an XML file — a groups export, or the group skeleton of a
/// product export — with the parent it is nested in.
List<GroupNode> parseGroupsXml(String content) {
  final out = <GroupNode>[];
  void walk(XmlElement el, String? parent) {
    final items = el.getElement('Items');
    if (items == null) return;
    for (final item in items.findElements('PosItem')) {
      if (item.getAttribute('xsi:type') != 'ProductGroup') continue;
      final name = _text(item, 'Name');
      if (name == null) {
        walk(item, parent);
        continue;
      }
      out.add(GroupNode(
        name: name,
        parentName: parent,
        color: _text(item, 'Color') ?? 'Transparent',
        rank: int.tryParse(_text(item, 'Rank') ?? '') ?? 0,
      ));
      walk(item, name);
    }
  }

  walk(XmlDocument.parse(content).rootElement, null);
  return out;
}

// ── Products ────────────────────────────────────────────────────────────────

/// Several barcodes share one CSV cell, separated by this — a character no
/// barcode symbology uses.
const String barcodeSeparator = '|';

const List<String> productCsvHeaders = [
  'Name', 'ProductGroup', 'SKU', 'Barcode', 'MeasurementUnit', 'Cost',
  'Markup', 'Price', 'Tax', 'TaxIsFixed', 'IsTaxInclusivePrice',
  'IsPriceChangeAllowed',
  'IsUsingDefaultQuantity', 'IsService', 'IsEnabled', 'Description',
  'Quantity', 'Supplier', 'ReorderPoint', 'PreferredQuantity',
  'LowStockWarning', 'WarningQuantity', 'IsToWeigh', 'PackSize', 'Color',
];

/// Products as CSV. The group column holds the product's own group; the tree
/// itself travels in the groups export (or the XML one).
String buildProductsCsv(List<ProductExportRow> rows) => encodeCsv([
      productCsvHeaders,
      for (final p in rows)
        [
          p.name,
          p.productGroupName,
          p.code,
          p.barcodes.join(barcodeSeparator),
          unitCodeOf(p),
          p.cost,
          p.markup,
          p.price,
          p.taxes.isNotEmpty ? p.taxes.first.rate : null,
          // Without it a fixed 5.00 came back in as a 5% tax.
          p.taxes.isNotEmpty ? p.taxes.first.isFixed : null,
          p.isTaxInclusivePrice,
          p.isPriceChangeAllowed,
          p.isUsingDefaultQuantity,
          p.isService,
          p.isEnabled,
          p.description,
          p.totalStock,
          p.supplierName,
          p.reorderPoint,
          p.preferredQuantity,
          p.isLowStockWarningEnabled,
          p.lowStockWarningQuantity,
          p.isToWeigh,
          p.packSize,
          p.color,
        ],
    ]);

/// The unit a product is sold in, as the code the importer maps back
/// (`kg`, `g`, `box`, `pcs` …). Read from the catalogue id rather than the
/// legacy free text, which an old row may never have filled in — with the same
/// self-heal the product model applies when the id is still the bare default.
String unitCodeOf(ProductExportRow p) {
  final id = p.uomId == kUomPieces ? uomFromLegacyText(p.measurementUnit) : p.uomId;
  return uomById(id).code;
}

/// Products as XML, each under its REAL group — the tree above it included —
/// where the old export put every product one level deep under its own group's
/// name and lost everything above.
String buildProductsXml(
  List<ProductExportRow> products,
  Iterable<GroupNode> groups,
) {
  final byKey = {for (final g in groups) g.key: g};

  // Only the part of the tree that holds products: each product's group and
  // everything above it. A group the list does not know becomes a root.
  final needed = <String, GroupNode>{};
  for (final p in products) {
    final path = groupPathOf(p.productGroupName, byKey);
    for (var i = 0; i < path.length; i++) {
      final k = _key(path[i]);
      needed.putIfAbsent(
        k,
        () => byKey[k] ?? GroupNode(name: path[i], parentName: i > 0 ? path[i - 1] : null),
      );
    }
  }

  final byGroup = <String?, List<ProductExportRow>>{};
  for (final p in products) {
    final g = _blankToNull(p.productGroupName);
    (byGroup[g == null ? null : _key(g)] ??= []).add(p);
  }

  final tree = _GroupTree(needed.values);
  final barcodeIds = _Counter();
  return _document((b) {
    for (final root in tree.roots) {
      _writeGroup(b, tree, root, (g) {
        for (final p in byGroup[g.key] ?? const <ProductExportRow>[]) {
          _writeProduct(b, p, barcodeIds);
        }
      });
    }
    for (final p in byGroup[null] ?? const <ProductExportRow>[]) {
      _writeProduct(b, p, barcodeIds);
    }
  });
}

/// Rows for `/Products/ImportBulk` from an XML file, each carrying its group's
/// full path (root first) so the server can rebuild the tree.
///
/// A flag the file does not carry is sent as null — "say nothing" — rather than
/// false, so an older or foreign file never switches products off.
List<Map<String, dynamic>> parseProductsXml(String content) {
  final rows = <Map<String, dynamic>>[];
  void walk(XmlElement el, List<String> path) {
    final items = el.getElement('Items');
    if (items == null) return;
    for (final item in items.findElements('PosItem')) {
      switch (item.getAttribute('xsi:type')) {
        case 'ProductGroup':
          final name = _text(item, 'Name');
          walk(item, [...path, ?name]);
        case 'Product':
          rows.add(_productRow(item, path));
      }
    }
  }

  walk(XmlDocument.parse(content).rootElement, const []);
  return rows;
}

// ── internals ───────────────────────────────────────────────────────────────

const _xsd = 'http://www.w3.org/2001/XMLSchema';
const _xsi = 'http://www.w3.org/2001/XMLSchema-instance';

String _key(String s) => s.trim().toLowerCase();

String? _blankToNull(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

int _byRankThenName(GroupNode a, GroupNode b) {
  final r = a.rank.compareTo(b.rank);
  return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

String? _text(XmlElement el, String tag) => _blankToNull(el.getElement(tag)?.innerText);

String _num(double v) =>
    v == v.truncateToDouble() && v.abs() < 1e15 ? v.toInt().toString() : v.toString();

class _Counter {
  int _next = 1;
  int take() => _next++;
}

/// Parent → children, built so a loop can never hang the walk: a group counts
/// as a child only if its parent was PLACED before it. [orderParentsFirst] puts
/// every reachable parent first, so only a loop member finds its parent
/// unplaced — and it becomes a root instead of vanishing.
class _GroupTree {
  _GroupTree(Iterable<GroupNode> groups) {
    final all = orderParentsFirst(groups);
    final known = {for (final g in all) g.key};
    final placed = <String>{};
    for (final g in all) {
      final p = g.parentName == null ? null : _key(g.parentName!);
      if (p != null && p != g.key && known.contains(p) && placed.contains(p)) {
        (_children[p] ??= []).add(g);
      } else {
        roots.add(g);
      }
      placed.add(g.key);
    }
  }

  final List<GroupNode> roots = [];
  final Map<String, List<GroupNode>> _children = {};

  List<GroupNode> childrenOf(GroupNode g) => _children[g.key] ?? const [];
}

String _document(void Function(XmlBuilder b) writeItems) {
  final b = XmlBuilder()..declaration(encoding: 'utf-8');
  b.element('ProductGroup', nest: () {
    b
      ..attribute('xmlns:xsd', _xsd)
      ..attribute('xmlns:xsi', _xsi)
      ..element('Color', nest: 'Transparent')
      ..element('Rank', nest: '0')
      ..element('Items', nest: () => writeItems(b));
  });
  return b.buildDocument().toXmlString(pretty: true, indent: '  ');
}

void _writeGroup(
  XmlBuilder b,
  _GroupTree tree,
  GroupNode g,
  void Function(GroupNode g)? writeProducts,
) {
  b.element('PosItem', nest: () {
    b
      ..attribute('xsi:type', 'ProductGroup')
      ..element('Name', nest: g.name)
      ..element('Color', nest: g.color)
      ..element('Rank', nest: '${g.rank}')
      ..element('Items', nest: () {
        for (final child in tree.childrenOf(g)) {
          _writeGroup(b, tree, child, writeProducts);
        }
        writeProducts?.call(g);
      });
  });
}

void _writeLong(XmlBuilder b, String tag, int value) {
  b.element(tag, nest: () {
    b
      ..attribute('xsi:type', 'xsd:long')
      ..text('$value');
  });
}

void _writeProduct(XmlBuilder b, ProductExportRow p, _Counter barcodeIds) {
  b.element('PosItem', nest: () {
    b.attribute('xsi:type', 'Product');
    _writeLong(b, 'Id', p.id);
    b
      ..element('Name', nest: p.name)
      ..element('Color', nest: p.color)
      ..element('Rank', nest: '${p.rank ?? 0}');
    if (p.code != null) b.element('Code', nest: p.code!);
    if (p.plu != null) b.element('PLU', nest: '${p.plu}');
    b
      ..element('Price', nest: _num(p.price))
      ..element('Taxes', nest: () {
        for (final t in p.taxes) {
          b.element('Tax', nest: () {
            _writeLong(b, 'Id', t.id);
            b
              ..element('Name', nest: t.name)
              ..element('Rate', nest: _num(t.rate))
              ..element('Code', nest: t.code ?? '')
              ..element('IsFixed', nest: '${t.isFixed}')
              ..element('IsTaxOnTotal', nest: '${t.isTaxOnTotal}')
              ..element('IsEnabled', nest: '${t.isEnabled}');
          });
        }
      })
      ..element('IsTaxInclusivePrice', nest: '${p.isTaxInclusivePrice}')
      ..element('Excise', nest: '0')
      ..element('MeasurementUnit', nest: () => b.element('Name', nest: unitCodeOf(p)))
      // Dropped by the old export, so a round trip turned every weighed product
      // back into a per-piece one and every box back into twelve.
      ..element('IsToWeigh', nest: '${p.isToWeigh}');
    if (p.packSize != null) b.element('PackSize', nest: _num(p.packSize!));
    b
      ..element('Package', nest: () => b.element('Quantity', nest: '1'))
      ..element('Barcodes', nest: () {
        for (final code in p.barcodes) {
          b.element('Barcode', nest: () {
            _writeLong(b, 'Id', barcodeIds.take());
            b.element('Value', nest: code);
          });
        }
      })
      ..element('IsUsingSerialNumbers', nest: 'false')
      ..element('IsDiscountAllowed', nest: 'true')
      ..element('MaxDiscount', nest: '100')
      ..element('IsPriceChangeAllowed', nest: '${p.isPriceChangeAllowed}')
      ..element('IsManufactureRequired', nest: 'false')
      ..element('IsService', nest: '${p.isService}')
      ..element('IsUsingDefaultQuantity', nest: '${p.isUsingDefaultQuantity}');
    if (p.description != null && p.description!.isNotEmpty) {
      b.element('Description', nest: p.description!);
    }
    b
      ..element('IsEnabled', nest: '${p.isEnabled}')
      ..element('Cost', nest: _num(p.cost));
    if (p.lastPurchasePrice != null) {
      b.element('LastPurchasePrice', nest: _num(p.lastPurchasePrice!));
    }
    if (p.markup != null) b.element('Markup', nest: _num(p.markup!));
    if (p.ageRestriction != null) {
      b.element('AgeRestriction', nest: '${p.ageRestriction}');
    } else {
      b.element('AgeRestriction', nest: () => b.attribute('xsi:nil', 'true'));
    }
    if (p.dateCreated != null) b.element('DateCreated', nest: p.dateCreated!);
    if (p.dateUpdated != null) b.element('DateUpdated', nest: p.dateUpdated!);
  });
}

Map<String, dynamic> _productRow(XmlElement el, List<String> path) {
  bool? flag(String tag) => parseCsvBool(_text(el, tag));

  // The first tax that carries a rate, WITH its kind: a fixed 5.00 and a 5%
  // are different taxes, and the number alone cannot tell them apart.
  final firstTax = el
      .getElement('Taxes')
      ?.findElements('Tax')
      .where((t) => parseCsvNumber(t.getElement('Rate')?.innerText) != null)
      .firstOrNull;
  final taxRate = parseCsvNumber(firstTax?.getElement('Rate')?.innerText);
  final taxIsFixed = parseCsvBool(firstTax?.getElement('IsFixed')?.innerText);

  final barcodes = el
          .getElement('Barcodes')
          ?.findElements('Barcode')
          .map((b) => b.getElement('Value')?.innerText.trim() ?? '')
          .where((v) => v.isNotEmpty)
          .toList() ??
      const <String>[];

  final description = el.getElement('Description')?.innerText;

  return {
    'name': _text(el, 'Name') ?? '',
    'productGroupName': path.isEmpty ? null : path.last,
    'productGroupPath': path,
    'code': _text(el, 'Code'),
    'barcodes': barcodes,
    // Older API builds read only the single form.
    'barcode': barcodes.isEmpty ? null : barcodes.first,
    'measurementUnit':
        _blankToNull(el.getElement('MeasurementUnit')?.getElement('Name')?.innerText),
    'cost': parseCsvNumber(_text(el, 'Cost')),
    'markup': parseCsvNumber(_text(el, 'Markup')),
    'price': parseCsvNumber(_text(el, 'Price')),
    'taxRate': taxRate,
    'taxIsFixed': taxIsFixed,
    'isTaxInclusivePrice': flag('IsTaxInclusivePrice'),
    'isPriceChangeAllowed': flag('IsPriceChangeAllowed'),
    'isUsingDefaultQuantity': flag('IsUsingDefaultQuantity'),
    'isService': flag('IsService'),
    'isEnabled': flag('IsEnabled'),
    'description': description == null || description.trim().isEmpty ? null : description,
    'isToWeigh': flag('IsToWeigh') ?? false,
    'packSize': parseCsvNumber(_text(el, 'PackSize')),
    'color': _text(el, 'Color'),
  };
}

// ── CSV import ──────────────────────────────────────────────────────────────

/// What a CSV cell becomes on its way to the server.
enum ImportFieldKind { text, number, integer, flag, list }

/// One thing the CSV importer can fill, and the headers that fill it on sight.
///
/// [key] is the name the import endpoint reads, so a parsed row IS the request
/// body — there is no second mapping to fall out of step with the first.
class ImportField {
  const ImportField(
    this.key,
    this.aliases, {
    this.kind = ImportFieldKind.text,
    this.required = false,
    this.fallback,
  });

  final String key;

  /// Headers matched automatically, compared without case, spaces or
  /// punctuation — "Measurement unit", "measurement_unit" and "MeasurementUnit"
  /// are one header. This app's own export header comes first.
  final List<String> aliases;

  final ImportFieldKind kind;
  final bool required;

  /// Sent when the cell is blank or not matched. Only for a field the server
  /// cannot take as null — a null plain bool fails the WHOLE request.
  final Object? fallback;

  bool get numeric =>
      kind == ImportFieldKind.number || kind == ImportFieldKind.integer;
}

/// The product importer's fields, in the order the screen lists them.
const List<ImportField> productImportFields = [
  ImportField('name', ['Name', 'Product', 'Nom'], required: true, fallback: ''),
  ImportField('productGroupName', ['ProductGroup', 'Group', 'Category', 'Groupe', 'Catégorie']),
  ImportField('code', ['SKU', 'Code', 'Reference', 'Référence']),
  ImportField('barcodes', ['Barcode', 'Barcodes', 'EAN', 'Code-barres'], kind: ImportFieldKind.list),
  ImportField('measurementUnit', ['MeasurementUnit', 'Unit', 'UOM', 'Unité']),
  ImportField('cost', ['Cost', 'Coût', 'Cout'], kind: ImportFieldKind.number),
  ImportField('markup', ['Markup', 'Marge'], kind: ImportFieldKind.number),
  ImportField('price', ['Price', 'Prix'], kind: ImportFieldKind.number),
  ImportField('taxRate', ['Tax', 'TaxRate', 'VAT', 'TVA', 'Taxe'], kind: ImportFieldKind.number),
  // Blank means a percentage — what a bare number in a spreadsheet is.
  ImportField('taxIsFixed', ['TaxIsFixed', 'FixedTax', 'IsFixed'], kind: ImportFieldKind.flag),
  ImportField('isTaxInclusivePrice', ['IsTaxInclusivePrice', 'TaxInclusivePrice'], kind: ImportFieldKind.flag),
  ImportField('isPriceChangeAllowed', ['IsPriceChangeAllowed', 'PriceChangeAllowed'], kind: ImportFieldKind.flag),
  ImportField('isUsingDefaultQuantity', ['IsUsingDefaultQuantity', 'UsingDefaultQuantity'], kind: ImportFieldKind.flag),
  ImportField('isService', ['IsService', 'Service', 'Service (not using stock)'], kind: ImportFieldKind.flag),
  ImportField('isEnabled', ['IsEnabled', 'Enabled', 'Active'], kind: ImportFieldKind.flag),
  ImportField('description', ['Description']),
  ImportField('quantity', ['Quantity', 'Stock', 'Quantité', 'Qty'], kind: ImportFieldKind.number),
  ImportField('supplierName', ['Supplier', 'SupplierName', 'Fournisseur']),
  ImportField('reorderPoint', ['ReorderPoint'], kind: ImportFieldKind.number),
  ImportField('preferredQuantity', ['PreferredQuantity'], kind: ImportFieldKind.number),
  ImportField('isLowStockWarningEnabled', ['LowStockWarning', 'IsLowStockWarningEnabled'], kind: ImportFieldKind.flag),
  ImportField('lowStockWarningQuantity', ['WarningQuantity', 'LowStockWarningQuantity'], kind: ImportFieldKind.number),
  // The server's IsToWeigh is a plain bool. A merge ORs it with the product's
  // own, so false here never switches weighing off.
  ImportField('isToWeigh', ['IsToWeigh', 'SellByWeight', 'Weighed'], kind: ImportFieldKind.flag, fallback: false),
  ImportField('packSize', ['PackSize', 'PiecesPerPack'], kind: ImportFieldKind.number),
  ImportField('color', ['Color', 'Colour', 'Couleur']),
];

/// The group importer's fields — the columns [buildGroupsCsv] writes.
const List<ImportField> groupImportFields = [
  ImportField('name', ['Name', 'Group', 'Nom', 'Groupe'], required: true, fallback: ''),
  ImportField('parentGroupName', ['Parent', 'ParentGroup', 'ParentGroupName', 'ParentFolder']),
  ImportField('color', ['Color', 'Colour', 'Couleur']),
  ImportField('rank', ['Rank', 'Order', 'Position', 'Rang'], kind: ImportFieldKind.integer),
];

/// Which column fills each field, found by header. Each column is used at most
/// once and the first matching alias wins; a field nothing matches maps to null.
///
/// By column INDEX, not header text: a file with two "Price" columns has two
/// different columns, and a lookup by text could only ever reach the first.
Map<String, int?> autoMapColumns(List<String> headers, List<ImportField> fields) {
  final keys = [for (final h in headers) _headerKey(h)];
  final taken = <int>{};
  final out = <String, int?>{};
  for (final f in fields) {
    int? found;
    for (final alias in f.aliases) {
      final want = _headerKey(alias);
      for (var i = 0; i < keys.length && found == null; i++) {
        if (!taken.contains(i) && keys[i] == want) found = i;
      }
      if (found != null) break;
    }
    if (found != null) taken.add(found);
    out[f.key] = found;
  }
  return out;
}

String _headerKey(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

/// One CSV record as a row for the import endpoint.
///
/// `unreadable` names the fields whose cell held something that is not a
/// number or a yes/no. They are sent EMPTY — which says nothing, so a merge
/// keeps the current value — and never as zero, which would import an
/// unreadable price as free. The preview shows them so the file can be fixed.
({Map<String, dynamic> row, List<String> unreadable}) parseImportRow(
  List<String> cells,
  Map<String, int?> mapping,
  List<ImportField> fields,
) {
  final row = <String, dynamic>{};
  final unreadable = <String>[];
  for (final f in fields) {
    final col = mapping[f.key];
    final raw = col == null || col >= cells.length ? null : _blankToNull(cells[col]);
    Object? value;
    if (raw != null) {
      value = switch (f.kind) {
        ImportFieldKind.text => raw,
        ImportFieldKind.number => parseCsvNumber(raw),
        ImportFieldKind.integer => parseCsvNumber(raw)?.round(),
        ImportFieldKind.flag => parseCsvBool(raw),
        ImportFieldKind.list => [
            for (final part in raw.split(barcodeSeparator))
              if (part.trim().isNotEmpty) part.trim(),
          ],
      };
      if (value == null) unreadable.add(f.key);
    }
    row[f.key] = value ?? f.fallback;
  }
  return (row: row, unreadable: unreadable);
}
