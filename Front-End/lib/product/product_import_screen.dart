// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:dio/dio.dart' show Dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/product/catalog_transfer.dart';
import 'package:pos_app/product/csv_codec.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/uom/unit_of_measure.dart';
import 'package:pos_app/utils/api_error_parser.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// What the import screen loads.
enum CatalogImportKind { products, groups }

/// CSV and XML import for the product catalogue, or for its groups.
///
/// One screen for both because the work is the same — pick a file, match its
/// columns, look at exactly what will be sent, send it. The file formats and
/// the cell parsing live in `catalog_transfer.dart` / `csv_codec.dart`, where
/// they are tested; this screen only shows them.
///
/// The preview is the rows AS THEY WILL BE SENT, not the raw cells: a French
/// "12,50" shows as 12.5, and a cell that cannot be read is struck through in
/// red instead of quietly going to the server as nothing.
class ProductImportScreen extends ConsumerStatefulWidget {
  const ProductImportScreen({super.key, this.kind = CatalogImportKind.products});

  final CatalogImportKind kind;

  @override
  ConsumerState<ProductImportScreen> createState() => _ProductImportScreenState();
}

/// One preview row: what will be sent, and what could not be read.
class _PreviewRow {
  const _PreviewRow(this.number, this.data, {this.unreadable = const [], this.cells});

  /// 1-based record number in the file, header excluded.
  final int number;
  final Map<String, dynamic> data;
  final List<String> unreadable;

  /// The file's own cells, so an unreadable value can be shown as it was typed.
  final List<String>? cells;

  bool get hasName => (data['name'] as String?)?.trim().isNotEmpty ?? false;
}

class _ProductImportScreenState extends ConsumerState<ProductImportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  bool get _groups => widget.kind == CatalogImportKind.groups;
  List<ImportField> get _fields => _groups ? groupImportFields : productImportFields;

  // CSV
  String? _csvName;
  CsvTable? _csv;
  Map<String, int?> _mapping = const {};
  List<_PreviewRow> _csvRows = const [];
  bool _csvPreview = false;
  bool _csvMerge = false;
  String _docType = 'inventoryCount';

  // XML — a restore of our own export, so it updates what exists by default.
  String? _xmlName;
  List<_PreviewRow> _xmlRows = const [];
  List<GroupNode> _xmlGroups = const [];
  bool _xmlMerge = true;

  bool _busy = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Files ──────────────────────────────────────────────────────────────────

  /// The picked file as text. Bytes first: on Android a picked file's path can
  /// be a copy the plugin has not finished writing, or no path at all.
  Future<({String name, String text})?> _pick(String extension) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [extension],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return null;
    final bytes =
        file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) return null;
    return (name: file.name, text: decodeCsvBytes(bytes));
  }

  Future<void> _pickCsv() async {
    final l = AppLocalizations.of(context);
    try {
      final file = await _pick('csv');
      if (file == null || !mounted) return;
      final table = parseCsv(file.text);
      setState(() {
        _csvName = file.name;
        _csv = table;
        _mapping = autoMapColumns(table.headers, _fields);
        _csvPreview = false;
        _rebuildCsvRows();
      });
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, l.importFileUnreadable('$e'), isError: true);
      }
    }
  }

  Future<void> _pickXml() async {
    final l = AppLocalizations.of(context);
    try {
      final file = await _pick('xml');
      if (file == null || !mounted) return;
      final text = file.text.startsWith('﻿') ? file.text.substring(1) : file.text;
      final groups = parseGroupsXml(text);
      final rows = _groups
          ? [for (final g in groups) g.toImportJson()]
          : parseProductsXml(text);
      setState(() {
        _xmlName = file.name;
        _xmlGroups = _groups ? const [] : groups;
        _xmlRows = [for (var i = 0; i < rows.length; i++) _PreviewRow(i + 1, rows[i])];
      });
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, l.importFileUnreadable('$e'), isError: true);
      }
    }
  }

  void _rebuildCsvRows() {
    final table = _csv;
    if (table == null) {
      _csvRows = const [];
      return;
    }
    final rows = <_PreviewRow>[];
    for (var i = 0; i < table.rows.length; i++) {
      final parsed = parseImportRow(table.rows[i], _mapping, _fields);
      rows.add(_PreviewRow(i + 1, parsed.row,
          unreadable: parsed.unreadable, cells: table.rows[i]));
    }
    _csvRows = rows;
  }

  void _setMapping(String key, int? column) => setState(() {
        _mapping = {..._mapping, key: column};
        _rebuildCsvRows();
      });

  void _clearCsv() {
    _csvName = null;
    _csv = null;
    _mapping = const {};
    _csvRows = const [];
    _csvPreview = false;
  }

  void _clearXml() {
    _xmlName = null;
    _xmlRows = const [];
    _xmlGroups = const [];
  }

  List<ImportField> get _mappedFields =>
      [for (final f in _fields) if (_mapping[f.key] != null) f];

  /// The fields an XML file actually carries — its preview shows no empty columns.
  List<ImportField> get _xmlFields => [
        for (final f in _fields)
          if (_xmlRows.any((r) => _present(r.data[f.key]))) f,
      ];

  static bool _present(Object? v) =>
      v != null && !(v is String && v.isEmpty) && !(v is List && v.isEmpty);

  // ── Import ─────────────────────────────────────────────────────────────────

  Future<void> _import({
    required List<_PreviewRow> rows,
    required bool merge,
    required String documentType,
    required VoidCallback onDone,
    List<GroupNode> groupsFirst = const [],
  }) async {
    final company = ref.read(selectedCompanyProvider);
    final payload = [for (final r in rows) if (r.hasName) r.data];
    if (company == null || payload.isEmpty) return;
    final l = AppLocalizations.of(context);
    final sync = ref.read(syncStateProvider.notifier);
    final userId = ref.read(currentUserProvider)?.id ?? 0;

    setState(() => _busy = true);
    try {
      final dio = createDio();
      final outcome = _Outcome();
      Map<String, dynamic> body(List<Map<String, dynamic>> rows) => {
            'companyId': company.id,
            'skipDuplicates': !merge,
            'mergeDuplicates': merge,
            'rows': rows,
          };

      if (_groups) {
        outcome.absorb(await _post(dio, '/ProductGroups/ImportBulk', body(payload)));
      } else {
        // An XML export's groups carry their colour and rank. Imported first,
        // so the products find their groups already built, and built right —
        // the product import alone would create them plain.
        if (groupsFirst.isNotEmpty) {
          outcome.absorbGroups(await _post(dio, '/ProductGroups/ImportBulk',
              body([for (final g in groupsFirst) g.toImportJson()])));
        }
        outcome.absorb(await _post(dio, '/Products/ImportBulk', {
          ...body(payload),
          'userId': userId,
          'documentType': documentType,
        }));
      }

      // The catalogue screens read the local database, and only a sync fills
      // it — without this the import "did nothing" until the next sync.
      try {
        await sync.sync().timeout(const Duration(seconds: 45));
      } catch (_) {}

      if (!mounted) return;
      setState(onDone);
      await _showResult(outcome);
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, l.importFailed(parseApiError(e)), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>> _post(
      Dio dio, String path, Map<String, dynamic> body) async {
    final response = await dio.post(path, data: body);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> _showResult(_Outcome o) {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(l.importComplete),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ResultRow(Icons.add_circle_outline, l.created, o.created, ctx.successColor),
                  _ResultRow(Icons.edit_outlined, l.updatedLabel, o.updated, ctx.infoColor),
                  _ResultRow(Icons.skip_next_rounded, l.skippedLabel, o.skipped, ctx.warningColor),
                  if (o.groupsCreated != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l.importGroupsSummary(o.groupsCreated!, o.groupsUpdated ?? 0),
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  if (o.documentNumber != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.receipt_long, color: cs.primary, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('${l.documentCreated}${o.documentNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ],
                  ..._lines(ctx, l.importErrorCount(o.errors.length), o.errors, ctx.dangerColor),
                  ..._lines(ctx, l.importWarningCount(o.warnings.length), o.warnings,
                      ctx.warningColor),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.actionClose),
            ),
          ],
        );
      },
    );
  }

  static const _maxLines = 20;

  List<Widget> _lines(BuildContext ctx, String title, List<String> lines, Color color) {
    if (lines.isEmpty) return const [];
    final l = AppLocalizations.of(ctx);
    return [
      const SizedBox(height: 12),
      Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      for (final line in lines.take(_maxLines))
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text('• $line', style: const TextStyle(fontSize: 12)),
        ),
      if (lines.length > _maxLines)
        Text(l.importMoreLines(lines.length - _maxLines),
            style: TextStyle(
                fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
    ];
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_groups ? l.importGroupsTitle : l.importProductsTitle),
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
        children: [_csvTab(l, cs), _xmlTab(l, cs)],
      ),
    );
  }

  Widget _csvTab(AppLocalizations l, ColorScheme cs) {
    final table = _csv;
    final ready = _csvRows.where((r) => r.hasName).length;
    final nameless = _csvRows.length - ready;
    final canImport = table != null && _mapping['name'] != null && ready > 0 && !_busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Banner(text: _groups ? l.importGroupsCsvHint : l.importCsvHint),
        if (table == null)
          Expanded(child: _NoFile(onPick: _busy ? null : _pickCsv))
        else ...[
          _FileBar(fileName: _csvName!, onPick: _busy ? null : _pickCsv),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.view_column_rounded),
                    label: Text(l.importColumnsTab),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.table_rows_rounded),
                    label: Text(l.importPreviewTab(_csvRows.length)),
                  ),
                ],
                selected: {_csvPreview},
                onSelectionChanged: (s) => setState(() => _csvPreview = s.first),
              ),
            ),
          ),
          Expanded(
            child: _csvPreview
                ? _previewTable(l, cs, _csvRows, _mappedFields)
                : _mappingView(l, cs, table),
          ),
        ],
        _ActionBar(
          summary: _groups
              ? l.numberOfGroupsToImport(ready)
              : l.numberOfProductsToImport(ready),
          warning: nameless > 0 ? l.importRowsWithoutName(nameless) : null,
          label: l.importRowsAction(ready),
          busy: _busy,
          onImport: canImport
              ? () => _import(
                    rows: _csvRows,
                    merge: _csvMerge,
                    // No quantity column, no quantities — an empty document
                    // would be noise in the document list.
                    documentType: _mapping['quantity'] != null ? _docType : 'none',
                    onDone: _clearCsv,
                  )
              : null,
        ),
      ],
    );
  }

  Widget _xmlTab(AppLocalizations l, ColorScheme cs) {
    final hasFile = _xmlName != null;
    final ready = _xmlRows.where((r) => r.hasName).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Banner(text: _groups ? l.importGroupsXmlHint : l.importXmlHint),
        if (!hasFile)
          Expanded(child: _NoFile(onPick: _busy ? null : _pickXml))
        else ...[
          _FileBar(fileName: _xmlName!, onPick: _busy ? null : _pickXml),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _optionsPanel(l, cs, csv: false),
              ),
            ),
          ),
          Expanded(child: _previewTable(l, cs, _xmlRows, _xmlFields)),
        ],
        _ActionBar(
          summary: _groups
              ? l.numberOfGroupsToImport(ready)
              : l.numberOfProductsToImport(ready),
          label: l.importRowsAction(ready),
          busy: _busy,
          onImport: hasFile && ready > 0 && !_busy
              ? () => _import(
                    rows: _xmlRows,
                    merge: _xmlMerge,
                    documentType: 'none',
                    groupsFirst: _xmlGroups,
                    onDone: _clearXml,
                  )
              : null,
        ),
      ],
    );
  }

  // ── Column matching ────────────────────────────────────────────────────────

  Widget _mappingView(AppLocalizations l, ColorScheme cs, CsvTable table) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 760;
      final stacked = c.maxWidth < 520;
      final mapping = Align(
        alignment: AlignmentDirectional.topStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in _fields) _mappingRow(l, cs, table, f, stacked: stacked),
              const SizedBox(height: 8),
              Text(l.indicatesRequiredField,
                  style: TextStyle(color: cs.error, fontSize: 12)),
            ],
          ),
        ),
      );
      final options = _optionsPanel(l, cs, csv: true);

      if (!wide) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [mapping, const SizedBox(height: 16), options],
          ),
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 16),
              child: mapping,
            ),
          ),
          SizedBox(
            width: 340,
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 16, 16),
              child: options,
            ),
          ),
        ],
      );
    });
  }

  Widget _mappingRow(
    AppLocalizations l,
    ColorScheme cs,
    CsvTable table,
    ImportField f, {
    required bool stacked,
  }) {
    final column = _mapping[f.key];
    final missing = f.required && column == null;
    final sample = column == null ? null : _sampleOf(table, column);

    final label = Text.rich(
      TextSpan(children: [
        if (f.required) TextSpan(text: '* ', style: TextStyle(color: cs.error)),
        TextSpan(text: _fieldLabel(l, f.key)),
      ]),
      style: TextStyle(fontSize: 14, color: cs.onSurface),
    );

    final dropdown = InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: const OutlineInputBorder(),
        enabledBorder: missing
            ? OutlineInputBorder(borderSide: BorderSide(color: cs.error))
            : null,
        // The first value the column holds — the quickest proof that "Price"
        // really was matched to the prices and not to the costs.
        helperText: sample == null ? null : l.importSampleValue(sample),
        helperMaxLines: 1,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: column,
          isDense: true,
          isExpanded: true,
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(l.skipColumn, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            for (var i = 0; i < table.headers.length; i++)
              DropdownMenuItem<int?>(
                value: i,
                child: Text(_headerLabel(table, i), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _busy ? null : (v) => _setMapping(f.key, v),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 6), dropdown],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: SizedBox(width: 200, child: label),
                ),
                const SizedBox(width: 12),
                Expanded(child: dropdown),
              ],
            ),
    );
  }

  static String _headerLabel(CsvTable t, int i) {
    final h = t.headers[i].trim();
    return h.isEmpty ? '#${i + 1}' : h;
  }

  static String? _sampleOf(CsvTable t, int column) {
    for (final row in t.rows.take(20)) {
      if (column < row.length && row[column].trim().isNotEmpty) {
        final v = row[column].trim().replaceAll('\n', ' ');
        return v.length > 40 ? '${v.substring(0, 40)}…' : v;
      }
    }
    return null;
  }

  Widget _optionsPanel(AppLocalizations l, ColorScheme cs, {required bool csv}) {
    final merge = csv ? _csvMerge : _xmlMerge;
    final quantityMatched = _mapping['quantity'] != null;
    final heading = TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface);
    final hint = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.duplicatesQuestion, style: heading),
          const SizedBox(height: 8),
          // The server has two behaviours, not four: "skip" wins whenever it is
          // asked for, and neither flag also means skip. So one choice, not two
          // switches that could both be on.
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.skip_next_rounded),
                label: Text(l.duplicatesSkip),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.duplicatesMerge),
              ),
            ],
            selected: {merge},
            onSelectionChanged: _busy
                ? null
                : (s) => setState(() {
                      if (csv) {
                        _csvMerge = s.first;
                      } else {
                        _xmlMerge = s.first;
                      }
                    }),
          ),
          const SizedBox(height: 6),
          Text(merge ? l.duplicatesMergeHint : l.duplicatesSkipHint, style: hint),
          if (csv && !_groups) ...[
            const SizedBox(height: 20),
            Text(l.createDocumentFromQuantity, style: heading),
            const SizedBox(height: 4),
            for (final (value, label) in [
              ('inventoryCount', l.importDocInventoryCount),
              ('purchase', l.importDocPurchase),
              ('none', l.importDocNone),
            ])
              RadioListTile<String>(
                value: value,
                groupValue: quantityMatched ? _docType : 'none',
                onChanged: quantityMatched && !_busy
                    ? (v) => setState(() => _docType = v!)
                    : null,
                title: Text(label, style: const TextStyle(fontSize: 14)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            if (!quantityMatched) Text(l.importDocNeedsQuantity, style: hint),
          ],
        ],
      ),
    );
  }

  // ── Preview ────────────────────────────────────────────────────────────────

  Widget _previewTable(
    AppLocalizations l,
    ColorScheme cs,
    List<_PreviewRow> rows,
    List<ImportField> fields,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: IlyassTable<_PreviewRow>(
        tableId: _groups ? 'groupImportPreview' : 'productImportPreview',
        rows: rows,
        rowHeight: 44,
        rowColor: (r) => r.hasName ? null : cs.error.withValues(alpha: 0.06),
        emptyState: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.importNothingFound,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ),
        columns: [
          IlyassColumn<_PreviewRow>(
            key: 'line',
            label: '#',
            width: 64,
            minWidth: 48,
            numeric: true,
            resizable: false,
            cell: (c, r) =>
                Text('${r.number}', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          IlyassColumn<_PreviewRow>(
            key: 'status',
            label: l.statusLabel,
            width: 84,
            resizable: false,
            cell: (c, r) => _statusCell(c, l, r),
          ),
          for (final f in fields)
            IlyassColumn<_PreviewRow>(
              key: f.key,
              label: _fieldLabel(l, f.key),
              width: _columnWidth(f),
              numeric: f.numeric,
              flexible: f.key == 'name',
              cell: (c, r) => _valueCell(c, cs, f, r),
            ),
        ],
      ),
    );
  }

  static double _columnWidth(ImportField f) => switch (f.key) {
        'name' => 220,
        'description' => 240,
        _ => switch (f.kind) {
            ImportFieldKind.number || ImportFieldKind.integer => 110,
            ImportFieldKind.flag => 120,
            ImportFieldKind.list => 180,
            ImportFieldKind.text => 160,
          },
      };

  Widget _statusCell(BuildContext c, AppLocalizations l, _PreviewRow r) {
    final (icon, color, tip) = !r.hasName
        ? (Icons.block_rounded, c.dangerColor, l.importRowNoName)
        : r.unreadable.isNotEmpty
            ? (
                Icons.warning_amber_rounded,
                c.warningColor,
                l.importRowUnreadable(
                    r.unreadable.map((k) => _fieldLabel(l, k)).join(', ')),
              )
            : (Icons.check_circle_outline_rounded, c.successColor, l.importRowOk);
    return Tooltip(message: tip, child: Icon(icon, color: color, size: 20));
  }

  Widget _valueCell(BuildContext c, ColorScheme cs, ImportField f, _PreviewRow r) {
    if (r.unreadable.contains(f.key)) {
      final column = _mapping[f.key];
      final cells = r.cells;
      final raw = column != null && cells != null && column < cells.length
          ? cells[column].trim()
          : '';
      return Text(raw,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: c.dangerColor, decoration: TextDecoration.lineThrough));
    }

    // An XML product carries its whole group chain — show where it will land.
    final path = r.data['productGroupPath'];
    final Object? value = f.key == 'productGroupName' && path is List && path.isNotEmpty
        ? path.join(' › ')
        : r.data[f.key];

    if (value is bool) {
      return Icon(value ? Icons.check_rounded : Icons.remove_rounded,
          size: 18, color: value ? c.successColor : cs.onSurfaceVariant);
    }
    final text = switch (value) {
      null => '',
      num n => formatReportQuantity(n.toDouble()),
      List list => list.join(' $barcodeSeparator '),
      _ => '$value',
    };
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

/// A field's name on screen. Kept apart from [ImportField.aliases] on purpose:
/// those are matched against file headers and must not change with the UI
/// language, or an English spreadsheet stops matching on a French till.
String _fieldLabel(AppLocalizations l, String key) => switch (key) {
      'name' => l.fieldName,
      'productGroupName' => l.fieldProductGroup,
      'code' => l.fieldSku,
      'barcodes' => l.barcode,
      'measurementUnit' => l.fieldMeasurementUnit,
      'cost' => l.fieldCost,
      'markup' => l.fieldMarkup,
      'price' => l.fieldPrice,
      'taxRate' => l.fieldTax,
      'isTaxInclusivePrice' => l.fieldTaxInclusivePrice,
      'isPriceChangeAllowed' => l.fieldPriceChangeAllowed,
      'isUsingDefaultQuantity' => l.fieldUsingDefaultQuantity,
      'isService' => l.fieldServiceNotStock,
      'isEnabled' => l.fieldEnabled,
      'description' => l.fieldDescription,
      'quantity' => l.fieldQuantity,
      'supplierName' => l.fieldSupplier,
      'reorderPoint' => l.fieldReorderPoint,
      'preferredQuantity' => l.fieldPreferredQuantity,
      'isLowStockWarningEnabled' => l.fieldLowStockWarning,
      'lowStockWarningQuantity' => l.fieldLowStockWarningQuantity,
      'isToWeigh' => l.sellByWeight,
      'packSize' => l.importFieldPackSize,
      'color' => l.setColor,
      'parentGroupName' => l.parentFolder,
      'rank' => l.fieldRank,
      _ => key,
    };

/// Totals across the one or two requests an import makes.
class _Outcome {
  int created = 0;
  int updated = 0;
  int skipped = 0;
  int? groupsCreated;
  int? groupsUpdated;
  String? documentNumber;
  final List<String> errors = [];
  final List<String> warnings = [];

  static int _int(Object? v) => (v as num?)?.toInt() ?? 0;
  static List<String> _strings(Object? v) => [for (final s in (v as List?) ?? const []) '$s'];

  void absorb(Map<String, dynamic> r) {
    created += _int(r['created']);
    updated += _int(r['updated']);
    skipped += _int(r['skipped']);
    documentNumber ??= r['documentNumber'] as String?;
    errors.addAll(_strings(r['errors']));
    warnings.addAll(_strings(r['warnings']));
  }

  void absorbGroups(Map<String, dynamic> r) {
    groupsCreated = _int(r['created']);
    groupsUpdated = _int(r['updated']);
    errors.addAll(_strings(r['errors']));
    warnings.addAll(_strings(r['warnings']));
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.primaryContainer.withValues(alpha: 0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: cs.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: cs.onSurface)),
          ),
        ],
      ),
    );
  }
}

class _NoFile extends StatelessWidget {
  const _NoFile({required this.onPick});

  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_file_rounded,
                size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(l.importNoFileYet, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(l.selectFile),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: onPick,
            ),
          ],
        ),
      ),
    );
  }
}

class _FileBar extends StatelessWidget {
  const _FileBar({required this.fileName, required this.onPick});

  final String fileName;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.folder_open_rounded, size: 18),
          label: Text(l.selectFile),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: onPick,
        ),
        const SizedBox(width: 12),
        Icon(Icons.check_circle, color: context.successColor, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(fileName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ),
      ]),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.summary,
    required this.label,
    required this.busy,
    required this.onImport,
    this.warning,
  });

  final String summary;
  final String? warning;
  final String label;
  final bool busy;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              flex: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary,
                      style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                  if (warning != null)
                    Text(warning!,
                        style: TextStyle(fontSize: 12, color: context.dangerColor)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              flex: 2,
              child: FilledButton.icon(
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(label, overflow: TextOverflow.ellipsis),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: onImport,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.icon, this.label, this.count, this.color);

  final IconData icon;
  final String label;
  final int count;
  final Color color;

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
