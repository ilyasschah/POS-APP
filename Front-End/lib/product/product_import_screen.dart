// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:xml/xml.dart' as xml;

// ---------------------------------------------------------------------------
// CSV parsing
// ---------------------------------------------------------------------------

List<List<String>> _parseCsv(String content) {
  final lines =
      content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  return lines
      .where((l) => l.trim().isNotEmpty)
      .map(_parseCsvLine)
      .toList();
}

List<String> _parseCsvLine(String line) {
  final fields = <String>[];
  final buf = StringBuffer();
  bool inQ = false;
  int i = 0;
  while (i < line.length) {
    final c = line[i];
    if (c == '"') {
      if (inQ && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i += 2;
        continue;
      }
      inQ = !inQ;
    } else if (c == ',' && !inQ) {
      fields.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
    i++;
  }
  fields.add(buf.toString());
  return fields;
}

bool? _parseBool(String? v) {
  if (v == null || v.isEmpty) return null;
  final l = v.toLowerCase().trim();
  if (l == '1' || l == 'true' || l == 'yes') return true;
  if (l == '0' || l == 'false' || l == 'no') return false;
  return null;
}

// ---------------------------------------------------------------------------
// XML parsing
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _parseXmlRows(String content) {
  final doc = xml.XmlDocument.parse(content);
  final rows = <Map<String, dynamic>>[];
  _parseXmlGroup(doc.rootElement, null, rows);
  return rows;
}

void _parseXmlGroup(
    xml.XmlElement el, String? groupName, List<Map<String, dynamic>> rows) {
  final items = el.findElements('Items').firstOrNull;
  if (items == null) return;
  for (final item in items.findElements('PosItem')) {
    final type = item.getAttribute('xsi:type');
    if (type == 'ProductGroup') {
      final childGroup = item.findElements('Name').firstOrNull?.innerText;
      _parseXmlGroup(item, childGroup, rows);
    } else if (type == 'Product') {
      rows.add(_parseXmlProduct(item, groupName));
    }
  }
}

Map<String, dynamic> _parseXmlProduct(
    xml.XmlElement el, String? groupName) {
  String? t(String tag) => el.findElements(tag).firstOrNull?.innerText;

  final taxes =
      el.findElements('Taxes').firstOrNull?.findElements('Tax').toList() ?? [];
  final taxRate = taxes.isEmpty
      ? null
      : double.tryParse(taxes.first.findElements('Rate').firstOrNull?.innerText ?? '');

  final barcodes = el
          .findElements('Barcodes')
          .firstOrNull
          ?.findElements('Barcode')
          .toList() ??
      [];
  final firstBarcode = barcodes.isEmpty
      ? null
      : barcodes.first.findElements('Value').firstOrNull?.innerText;

  final muName =
      el.findElements('MeasurementUnit').firstOrNull?.findElements('Name').firstOrNull?.innerText;

  return {
    'name': t('Name') ?? '',
    'productGroupName': groupName,
    'code': t('Code'),
    'barcode': firstBarcode,
    'measurementUnit': muName,
    'cost': double.tryParse(t('Cost') ?? ''),
    'markup': double.tryParse(t('Markup') ?? ''),
    'price': double.tryParse(t('Price') ?? ''),
    'taxRate': taxRate,
    'isTaxInclusivePrice': t('IsTaxInclusivePrice') == 'true',
    'isPriceChangeAllowed': t('IsPriceChangeAllowed') == 'true',
    'isUsingDefaultQuantity': t('IsUsingDefaultQuantity') == 'true',
    'isService': t('IsService') == 'true',
    'isEnabled': t('IsEnabled') == 'true',
    'description': t('Description'),
    'quantity': null,
    'supplierName': null,
    'reorderPoint': null,
    'preferredQuantity': null,
    'isLowStockWarningEnabled': null,
    'lowStockWarningQuantity': null,
  };
}

// ---------------------------------------------------------------------------
// Field definitions
// ---------------------------------------------------------------------------

typedef _Field = ({String key, String label, bool required});

const _fields = <_Field>[
  (key: 'name',                    label: 'Name',                       required: true),
  (key: 'productGroup',            label: 'Product group',              required: false),
  (key: 'code',                    label: 'SKU',                        required: false),
  (key: 'barcode',                 label: 'Barcode',                    required: false),
  (key: 'measurementUnit',         label: 'Measurement unit',           required: false),
  (key: 'cost',                    label: 'Cost',                       required: false),
  (key: 'markup',                  label: 'Markup',                     required: false),
  (key: 'price',                   label: 'Price',                      required: false),
  (key: 'tax',                     label: 'Tax',                        required: false),
  (key: 'isTaxInclusivePrice',     label: 'Tax inclusive price',        required: false),
  (key: 'isPriceChangeAllowed',    label: 'Price change allowed',       required: false),
  (key: 'isUsingDefaultQuantity',  label: 'Using default quantity',     required: false),
  (key: 'isService',               label: 'Service (not using stock)',  required: false),
  (key: 'isEnabled',               label: 'Enabled',                    required: false),
  (key: 'description',             label: 'Description',                required: false),
  (key: 'quantity',                label: 'Quantity',                   required: false),
  (key: 'supplier',                label: 'Supplier',                   required: false),
  (key: 'reorderPoint',            label: 'Reorder point',              required: false),
  (key: 'preferredQuantity',       label: 'Preferred quantity',         required: false),
  (key: 'isLowStockWarningEnabled',label: 'Low stock warning',          required: false),
  (key: 'lowStockWarningQuantity', label: 'Low stock warning quantity', required: false),
];

// CSV column aliases for auto-mapping
const _fieldAliases = <String, List<String>>{
  'name':                    ['Name', 'name'],
  'productGroup':            ['ProductGroup', 'Product group', 'productgroup'],
  'code':                    ['SKU', 'Code', 'sku', 'code'],
  'barcode':                 ['Barcode', 'barcode'],
  'measurementUnit':         ['MeasurementUnit', 'Measurement unit', 'Unit'],
  'cost':                    ['Cost', 'cost'],
  'markup':                  ['Markup', 'markup'],
  'price':                   ['Price', 'price'],
  'tax':                     ['Tax', 'tax'],
  'isTaxInclusivePrice':     ['IsTaxInclusivePrice', 'Tax inclusive price', 'TaxInclusivePrice'],
  'isPriceChangeAllowed':    ['IsPriceChangeAllowed', 'Price change allowed', 'PriceChangeAllowed'],
  'isUsingDefaultQuantity':  ['IsUsingDefaultQuantity', 'Using default quantity'],
  'isService':               ['IsService', 'Service', 'Service (not using stock)'],
  'isEnabled':               ['IsEnabled', 'Enabled'],
  'description':             ['Description', 'description'],
  'quantity':                ['Quantity', 'quantity'],
  'supplier':                ['Supplier', 'SupplierName', 'supplier'],
  'reorderPoint':            ['ReorderPoint', 'Reorder point'],
  'preferredQuantity':       ['PreferredQuantity', 'Preferred quantity'],
  'isLowStockWarningEnabled':['LowStockWarning', 'IsLowStockWarningEnabled', 'Low stock warning'],
  'lowStockWarningQuantity': ['WarningQuantity', 'LowStockWarningQuantity', 'Low stock warning quantity'],
};

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ProductImportScreen extends ConsumerStatefulWidget {
  const ProductImportScreen({super.key});

  @override
  ConsumerState<ProductImportScreen> createState() =>
      _ProductImportScreenState();
}

class _ProductImportScreenState extends ConsumerState<ProductImportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // CSV state
  String? _csvPath;
  List<String> _headers = [];
  List<List<String>> _dataRows = [];
  late final Map<String, String?> _mapping = {for (final f in _fields) f.key: null};
  bool _skipDuplicates = false;
  bool _mergeDuplicates = false;
  String _docType = 'inventoryCount';
  bool _showPreview = false;
  bool _isImportingCsv = false;

  // XML state
  String? _xmlPath;
  bool _isImportingXml = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() => _showPreview = false));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ---- CSV file picking ----
  Future<void> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final content = await File(path).readAsString();
    final rows = _parseCsv(content);
    if (rows.isEmpty) return;
    setState(() {
      _csvPath = path;
      _headers = rows.first;
      _dataRows = rows.skip(1).toList();
      _showPreview = false;
      _autoMap();
    });
  }

  void _autoMap() {
    for (final f in _fields) {
      final aliases = _fieldAliases[f.key] ?? [f.label];
      String? found;
      for (final alias in aliases) {
        final match = _headers.firstWhereOrNull(
            (h) => h.toLowerCase() == alias.toLowerCase());
        if (match != null) {
          found = match;
          break;
        }
      }
      _mapping[f.key] = found;
    }
  }

  String? _cell(List<String> row, String fieldKey) {
    final h = _mapping[fieldKey];
    if (h == null) return null;
    final idx = _headers.indexOf(h);
    if (idx < 0 || idx >= row.length) return null;
    final v = row[idx].trim();
    return v.isEmpty ? null : v;
  }

  Map<String, dynamic> _buildRow(List<String> row) => {
        'name':                    _cell(row, 'name') ?? '',
        'productGroupName':        _cell(row, 'productGroup'),
        'code':                    _cell(row, 'code'),
        'barcode':                 _cell(row, 'barcode'),
        'measurementUnit':         _cell(row, 'measurementUnit'),
        'cost':                    double.tryParse(_cell(row, 'cost') ?? ''),
        'markup':                  double.tryParse(_cell(row, 'markup') ?? ''),
        'price':                   double.tryParse(_cell(row, 'price') ?? ''),
        'taxRate':                 double.tryParse(_cell(row, 'tax') ?? ''),
        'isTaxInclusivePrice':     _parseBool(_cell(row, 'isTaxInclusivePrice')),
        'isPriceChangeAllowed':    _parseBool(_cell(row, 'isPriceChangeAllowed')),
        'isUsingDefaultQuantity':  _parseBool(_cell(row, 'isUsingDefaultQuantity')),
        'isService':               _parseBool(_cell(row, 'isService')),
        'isEnabled':               _parseBool(_cell(row, 'isEnabled')),
        'description':             _cell(row, 'description'),
        'quantity':                double.tryParse(_cell(row, 'quantity') ?? ''),
        'supplierName':            _cell(row, 'supplier'),
        'reorderPoint':            double.tryParse(_cell(row, 'reorderPoint') ?? ''),
        'preferredQuantity':       double.tryParse(_cell(row, 'preferredQuantity') ?? ''),
        'isLowStockWarningEnabled':_parseBool(_cell(row, 'isLowStockWarningEnabled')),
        'lowStockWarningQuantity': double.tryParse(_cell(row, 'lowStockWarningQuantity') ?? ''),
      };

  bool get _csvReady =>
      _csvPath != null && _mapping['name'] != null && !_isImportingCsv;

  Future<void> _importCsv() async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;
    final userId = ref.read(currentUserProvider)?.id ?? 0;
    setState(() => _isImportingCsv = true);
    try {
      final rows = _dataRows.map(_buildRow).toList();
      final dio = createDio();
      final response = await dio.post('/Products/ImportBulk', data: {
        'companyId':      company.id,
        'userId':         userId,
        'skipDuplicates': _skipDuplicates,
        'mergeDuplicates':_mergeDuplicates,
        'documentType':   _docType,
        'rows':           rows,
      });
      final r = response.data as Map<String, dynamic>;
      if (mounted) {
        _showResult(
          r['created'] as int,
          r['updated'] as int,
          r['skipped'] as int,
          (r['errors'] as List).cast<String>(),
          r['documentNumber'] as String?,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Import failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isImportingCsv = false);
    }
  }

  // ---- XML ----
  Future<void> _pickXml() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    setState(() => _xmlPath = result.files.single.path);
  }

  Future<void> _importXml() async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null || _xmlPath == null) return;
    setState(() => _isImportingXml = true);
    try {
      final content = await File(_xmlPath!).readAsString();
      final rows = _parseXmlRows(content);
      final dio = createDio();
      final response = await dio.post('/Products/ImportBulk', data: {
        'companyId':      company.id,
        'skipDuplicates': false,
        'mergeDuplicates':true,
        'documentType':   'none',
        'rows':           rows,
      });
      final r = response.data as Map<String, dynamic>;
      if (mounted) {
        _showResult(r['created'] as int, r['updated'] as int,
            r['skipped'] as int, (r['errors'] as List).cast<String>());
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Import failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isImportingXml = false);
    }
  }

  void _showResult(int created, int updated, int skipped, List<String> errors,
      [String? documentNumber]) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultRow(Icons.add_circle_outline, 'Created', created, Colors.green),
            _ResultRow(Icons.edit_outlined, 'Updated', updated, Colors.blue),
            _ResultRow(Icons.skip_next, 'Skipped', skipped, Colors.orange),
            if (documentNumber != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.receipt_long, color: Colors.teal, size: 18),
                const SizedBox(width: 8),
                const Text('Document created: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(documentNumber,
                    style: const TextStyle(
                        color: Colors.teal, fontWeight: FontWeight.bold)),
              ]),
            ],
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('${errors.length} error(s):',
                  style: const TextStyle(color: Colors.red)),
              ...errors.take(5).map((e) => Text('• $e',
                  style: const TextStyle(fontSize: 12))),
            ],
          ],
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import'),
        backgroundColor: cs.surface,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: cs.primary,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          tabs: const [Tab(text: 'CSV'), Tab(text: 'XML')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildCsvTab(cs), _buildXmlTab(cs)],
      ),
    );
  }

  // =========================================================================
  // CSV TAB
  // =========================================================================

  Widget _buildCsvTab(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoBanner(cs,
            'Use CSV import to load products using custom CSV file or a CSV exported from other application.'),
        // File selector row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_outlined, size: 18),
              label: const Text('Select file'),
              onPressed: _pickCsv,
            ),
            if (_csvPath != null) ...[
              const SizedBox(width: 12),
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(_csvPath!,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 8),
        // Main content
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Field mapping
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._fields.map((f) => _mappingRow(cs, f)),
                      const SizedBox(height: 8),
                      Text('* Indicates required field',
                          style: TextStyle(
                              color: cs.error, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              // Right: Options
              SizedBox(
                width: 280,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                  child: _optionsPanel(cs),
                ),
              ),
            ],
          ),
        ),
        // Action bar
        _csvActionBar(cs),
        // Preview table
        if (_showPreview && _dataRows.isNotEmpty) _previewTable(cs),
      ],
    );
  }

  Widget _mappingRow(ColorScheme cs, _Field f) {
    final isRequired = f.required;
    final hasFile = _csvPath != null;
    final selected = _mapping[f.key];
    final options = [null, ..._headers];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Row(children: [
              if (isRequired)
                Text('* ', style: TextStyle(color: cs.error, fontSize: 13)),
              Text(f.label,
                  style: TextStyle(
                      fontSize: 13, color: cs.onSurface)),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isRequired && hasFile && selected == null
                      ? cs.error
                      : cs.outline.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(4),
                color: cs.surface,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: options.contains(selected) ? selected : null,
                  isDense: true,
                  isExpanded: true,
                  hint: Text('(Skip)',
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 13)),
                  items: options.map((h) {
                    return DropdownMenuItem<String?>(
                      value: h,
                      child: Text(h ?? '(Skip)',
                          style: TextStyle(
                              fontSize: 13,
                              color: h == null
                                  ? cs.onSurfaceVariant
                                  : cs.onSurface)),
                    );
                  }).toList(),
                  onChanged: hasFile
                      ? (v) => setState(() => _mapping[f.key] = v)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionsPanel(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What happens if duplicates are found?',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        _checkRow(cs, 'Skip duplicates', _skipDuplicates,
            (v) => setState(() => _skipDuplicates = v)),
        _checkRow(cs, 'Merge duplicates', _mergeDuplicates,
            (v) => setState(() => _mergeDuplicates = v)),
        const SizedBox(height: 16),
        Text('Create document from specified quantity',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        _radioRow(cs, 'Inventory count', 'inventoryCount'),
        _radioRow(cs, 'Purchase', 'purchase'),
        _radioRow(cs, 'None (no document)', 'none'),
      ],
    );
  }

  Widget _checkRow(ColorScheme cs, String label, bool value,
      ValueChanged<bool> onChanged) {
    return Row(children: [
      Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface)),
    ]);
  }

  Widget _radioRow(ColorScheme cs, String label, String val) {
    return Row(children: [
      Radio<String>(
          value: val,
          groupValue: _docType,
          onChanged: (v) => setState(() => _docType = v!)),
      Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface)),
    ]);
  }

  Widget _csvActionBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Preview'),
          onPressed: _csvReady && _dataRows.isNotEmpty
              ? () => setState(() => _showPreview = !_showPreview)
              : null,
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          icon: _isImportingCsv
              ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download_rounded, size: 18),
          label: const Text('Import'),
          style: FilledButton.styleFrom(
              backgroundColor: _csvReady ? Colors.green : null),
          onPressed: _csvReady ? _importCsv : null,
        ),
      ]),
    );
  }

  Widget _previewTable(ColorScheme cs) {
    // Build visible columns (only mapped ones)
    final visibleFields = _fields
        .where((f) => _mapping[f.key] != null)
        .toList();

    return Container(
      height: 260,
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outlineVariant))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Number of products to import: ${_dataRows.length}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                      cs.surfaceContainerHighest),
                  dataRowMinHeight: 28,
                  dataRowMaxHeight: 32,
                  headingRowHeight: 36,
                  columnSpacing: 24,
                  columns: visibleFields
                      .map((f) => DataColumn(
                          label: Text(f.label,
                              style: const TextStyle(fontSize: 12))))
                      .toList(),
                  rows: _dataRows.take(50).map((row) {
                    return DataRow(
                      cells: visibleFields.map((f) {
                        final v = _cell(row, f.key) ?? '';
                        return DataCell(Text(v,
                            style: const TextStyle(fontSize: 12)));
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // XML TAB
  // =========================================================================

  Widget _buildXmlTab(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBanner(cs,
            'Use XML import to load products exported from this application.\n'
            'XML import will preserve all properties, including products hierarchy.'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_outlined, size: 18),
              label: const Text('Select file'),
              onPressed: _pickXml,
            ),
            if (_xmlPath != null) ...[
              const SizedBox(width: 12),
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(_xmlPath!,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            icon: _isImportingXml
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_rounded, size: 18),
            label: const Text('Import'),
            style: FilledButton.styleFrom(
                backgroundColor:
                    _xmlPath != null && !_isImportingXml ? Colors.green : null),
            onPressed:
                _xmlPath != null && !_isImportingXml ? _importXml : null,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // Shared
  // =========================================================================

  Widget _infoBanner(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.primary.withValues(alpha: 0.1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: cs.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: cs.onSurface)),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _ResultRow(this.icon, this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('$count'),
      ]),
    );
  }
}

extension _IterableExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
