import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/security/security_guard.dart';
import 'package:pos_app/security/security_keys.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/document/document_model.dart';
import 'package:pos_app/document/document_editor_screen.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/stock/warehouse_model.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Reads sales documents from local Drift — local DB is the source of truth.
/// Name fields (userName, customerName, documentTypeName) are resolved from
/// local lookup tables so the list renders fully offline.
/// Call [syncStateProvider.notifier.sync()] before invalidating this provider
/// when you want to pull fresh data from the server.
final allDocumentsProvider = FutureProvider.autoDispose<List<Document>>((ref) async {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return [];
  final db = ref.watch(appDatabaseProvider);

  // Prefetch lookup rows once — avoids N+1 per-row queries.
  final customerRows = await db.select(db.customersTable).get();
  final userRows     = await db.select(db.usersTable).get();
  final customerMap  = {for (final c in customerRows) c.id: c.name};
  final userMap      = {for (final u in userRows) u.id: u.name};

  // Best-effort type names from the API-backed provider; gracefully empty offline.
  final docTypes = ref.watch(allDocumentTypesProvider).value ?? [];
  final typeMap  = {for (final t in docTypes) t.id: t.name};

  final rows = await db.getDocuments(companyId: company.id);

  return rows.map((row) {
    final pendingCreate =
        row.syncStatus == 'pending' || row.syncStatus == 'pending_create';
    final displayNumber = row.number?.isNotEmpty == true
        ? row.number!
        : (pendingCreate ? '(Pending sync)' : '—');
    return Document(
      id:               row.serverId ?? 0,
      localId:          row.localId,
      number:           displayNumber,
      userId:           row.userId,
      userName:         userMap[row.userId],
      customerId:       row.customerId ?? 0,
      customerName:     row.customerId != null ? customerMap[row.customerId] : null,
      companyId:        row.companyId,
      documentTypeId:   row.documentTypeId,
      documentTypeName: typeMap[row.documentTypeId],
      warehouseId:      row.warehouseId,
      orderNumber:      row.orderNumber,
      date:             row.date.toIso8601String(),
      stockDate:        row.stockDate?.toIso8601String(),
      dueDate:          row.dueDate?.toIso8601String(),
      total:            row.total,
      discount:         row.discount,
      discountType:     row.discountType,
      paidStatus:       row.paidStatus,
      discountApplyRule: row.discountApplyRule,
      serviceType:      row.serviceType,
      internalNote:     row.internalNote,
      note:             row.note,
      referenceDocumentNumber: row.referenceDocumentNumber,
    );
  }).toList();
});

/// Document types, streamed from the local Drift cache so the editor's type
/// picker (and offline document creation) work without a network connection.
/// Seeded by SyncManager.pullDocumentTypes.
final allDocumentTypesProvider =
    StreamProvider.autoDispose<List<DocumentType>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchDocumentTypes().map((rows) => rows
      .map((r) => DocumentType(
            id: r.id,
            name: r.name,
            code: r.code,
            documentCategoryId: r.documentCategoryId,
            stockDirection: r.stockDirection,
          ))
      .toList());
});

final documentVisibleColumnsProvider = StateProvider<Map<String, bool>>((ref) => {
  'ID':            false,
  'Number':        true,
  'Doc Type':      true,
  'Paid':          true,
  'Customer':      true,
  'Date':          true,
  'Order #':       true,
  'User':          false,
  'Discount':      false,
  'Total':         true,
  'Internal Note': false,
  'Note':          false,
  'Created':       false,
  'Updated':       false,
  'Actions':       true,
});

// ── Screen ────────────────────────────────────────────────────────────────────

class DocumentsScreen extends ConsumerStatefulWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const DocumentsScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  // ── filter state ──────────────────────────────────────────────────────────
  int?  _filterUserId;
  int?  _filterCustomerId;
  int?  _filterDocTypeId;
  int?  _filterPaidStatus;
  int?  _filterWarehouseId;
  final _docNumberCtrl = TextEditingController();
  final _refNumberCtrl = TextEditingController();
  DateTimeRange? _filterDateRange;

  final _dateFmt = DateFormat('dd/MM/yy');

  @override
  void initState() {
    super.initState();
    tz_data.initializeTimeZones();
  }

  @override
  void dispose() {
    _docNumberCtrl.dispose();
    _refNumberCtrl.dispose();
    super.dispose();
  }

  // ── date formatting ───────────────────────────────────────────────────────

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final isTimestamp = iso.contains('T') || iso.contains(' ');
      final dt = DateTime.parse(iso);
      if (isTimestamp) {
        final utcDt = dt.isUtc
            ? dt
            : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
        final tzId = ref.read(appSettingsProvider)[SettingKeys.timezone] ?? 'UTC';
        DateTime display;
        try {
          final location = tz.getLocation(tzId);
          display = tz.TZDateTime.from(utcDt, location);
        } catch (_) {
          display = utcDt;
        }
        return '${display.day.toString().padLeft(2, '0')}-'
            '${_monthAbbr(display.month)}-${display.year.toString().substring(2)} '
            '${display.hour.toString().padLeft(2, '0')}:'
            '${display.minute.toString().padLeft(2, '0')}';
      } else {
        return '${dt.day.toString().padLeft(2, '0')}-'
            '${_monthAbbr(dt.month)}-${dt.year.toString().substring(2)}';
      }
    } catch (_) {
      return iso;
    }
  }

  String _monthAbbr(int m) => const [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ][m - 1];

  // ── badges ────────────────────────────────────────────────────────────────

  Widget _paidBadge(BuildContext context, int status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case 1:  return _badge("Paid",    isDark ? Colors.greenAccent  : Colors.green);
      case 2:  return _badge("Partial", isDark ? Colors.orangeAccent : Colors.orange);
      case 0:  return _badge("Unpaid",  isDark ? Colors.redAccent    : Colors.red);
      default: return _badge("N/A",     Colors.grey);
    }
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  // ── filtering ─────────────────────────────────────────────────────────────

  List<Document> _applyFilters(List<Document> docs) {
    final docNum = _docNumberCtrl.text.trim().toLowerCase();
    final refNum = _refNumberCtrl.text.trim().toLowerCase();

    return docs.where((d) {
      if (_filterUserId       != null && d.userId        != _filterUserId)       return false;
      if (_filterCustomerId   != null && d.customerId    != _filterCustomerId)   return false;
      if (_filterDocTypeId    != null && d.documentTypeId!= _filterDocTypeId)    return false;
      if (_filterPaidStatus   != null && d.paidStatus    != _filterPaidStatus)   return false;
      if (_filterWarehouseId  != null && d.warehouseId   != _filterWarehouseId)  return false;
      if (docNum.isNotEmpty && !d.number.toLowerCase().contains(docNum))        return false;
      if (refNum.isNotEmpty &&
          !(d.referenceDocumentNumber?.toLowerCase().contains(refNum) ?? false)) {
        return false;
      }
      if (_filterDateRange != null) {
        try {
          final dt  = DateTime.parse(d.date);
          final end = _filterDateRange!.end.add(const Duration(days: 1));
          if (dt.isBefore(_filterDateRange!.start) || !dt.isBefore(end))       return false;
        } catch (_) {}
      }
      return true;
    }).toList();
  }

  void _clearFilters() => setState(() {
    _filterUserId      = null;
    _filterCustomerId  = null;
    _filterDocTypeId   = null;
    _filterPaidStatus  = null;
    _filterWarehouseId = null;
    _filterDateRange   = null;
    _docNumberCtrl.clear();
    _refNumberCtrl.clear();
  });

  // ── column picker ─────────────────────────────────────────────────────────

  void _showColumnPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(builder: (context, ref, _) {
        final columns = ref.watch(documentVisibleColumnsProvider);
        return AlertDialog(
          title: const Text("Show / Hide Columns"),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: columns.keys.map((col) => CheckboxListTile(
                  title: Text(col),
                  value: columns[col],
                  onChanged: (val) =>
                      ref.read(documentVisibleColumnsProvider.notifier)
                          .update((s) => {...s, col: val ?? false}),
                )).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      }),
    );
  }

  // ── filter panel ──────────────────────────────────────────────────────────

  InputDecoration _inputDeco(ColorScheme cs, String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: cs.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cs.primary),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
  );

  Widget _dropdownField<T>({
    required ColorScheme cs,
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) =>
      DropdownButtonFormField<T>(
        key:          ValueKey(value),
        initialValue: value,
        isExpanded:   true,
        decoration:   _inputDeco(cs, hint),
        hint:         Text(hint, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        items:        items,
        onChanged:    onChanged,
        style:        TextStyle(fontSize: 13, color: cs.onSurface),
      );

  Widget _buildFilterPanel({
    required BuildContext context,
    required ThemeData theme,
    required List<DocumentType> types,
    required List<User> users,
    required List<Customer> customers,
    required List<Warehouse> warehouses,
    required int totalResults,
  }) {
    final cs = theme.colorScheme;

    // Period display text
    final periodLabel = _filterDateRange == null
        ? 'All dates'
        : '${_dateFmt.format(_filterDateRange!.start)} – ${_dateFmt.format(_filterDateRange!.end)}';

    // User display name
    String userName(User u) {
      final full = '${u.firstName ?? ''} ${u.lastName ?? ''}'.trim();
      return full.isNotEmpty ? full : (u.username ?? 'User ${u.id}');
    }

    final labelStyle = TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant);

    Widget label(String t) => Text(t, style: labelStyle);

    Widget filterCol({required String lbl, required Widget control}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label(lbl), const Gap(4), control],
          ),
        );

    const gap = Gap(12);

    return Container(
      decoration: BoxDecoration(
        color:  cs.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        children: [
          // ── Row 1: User | Customer | Document Type ──────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              filterCol(
                lbl: 'User',
                control: _dropdownField<int?>(
                  cs:       cs,
                  value:    _filterUserId,
                  hint:     'All users',
                  items:    [
                    const DropdownMenuItem(value: null, child: Text('All users')),
                    ...users.map((u) => DropdownMenuItem(value: u.id, child: Text(userName(u)))),
                  ],
                  onChanged: (v) => setState(() => _filterUserId = v),
                ),
              ),
              gap,
              filterCol(
                lbl: 'Customer',
                control: _dropdownField<int?>(
                  cs:       cs,
                  value:    _filterCustomerId,
                  hint:     'All customers',
                  items:    [
                    const DropdownMenuItem(value: null, child: Text('All customers')),
                    ...customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => setState(() => _filterCustomerId = v),
                ),
              ),
              gap,
              filterCol(
                lbl: 'Document type',
                control: _dropdownField<int?>(
                  cs:       cs,
                  value:    _filterDocTypeId,
                  hint:     'All document types',
                  items:    [
                    const DropdownMenuItem(value: null, child: Text('All document types')),
                    ...types.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                  ],
                  onChanged: (v) => setState(() => _filterDocTypeId = v),
                ),
              ),
            ],
          ),
          const Gap(10),
          // ── Row 2: Paid Status | Warehouse | Doc Number ─────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              filterCol(
                lbl: 'Paid status',
                control: _dropdownField<int?>(
                  cs:    cs,
                  value: _filterPaidStatus,
                  hint:  'All transactions',
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All transactions')),
                    DropdownMenuItem(value: 1,    child: Text('Paid')),
                    DropdownMenuItem(value: 2,    child: Text('Partial')),
                    DropdownMenuItem(value: 0,    child: Text('Unpaid')),
                  ],
                  onChanged: (v) => setState(() => _filterPaidStatus = v),
                ),
              ),
              gap,
              filterCol(
                lbl: 'Warehouse',
                control: _dropdownField<int?>(
                  cs:       cs,
                  value:    _filterWarehouseId,
                  hint:     'All warehouses',
                  items:    [
                    const DropdownMenuItem(value: null, child: Text('All warehouses')),
                    ...warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))),
                  ],
                  onChanged: (v) => setState(() => _filterWarehouseId = v),
                ),
              ),
              gap,
              filterCol(
                lbl: 'Document number',
                control: TextField(
                  controller: _docNumberCtrl,
                  decoration: _inputDeco(cs, 'e.g. 26-200-000001'),
                  style: TextStyle(fontSize: 13, color: cs.onSurface),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const Gap(10),
          // ── Row 3: Ref Doc | Period | Clear | Search | Total ────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              filterCol(
                lbl: 'External document',
                control: TextField(
                  controller: _refNumberCtrl,
                  decoration: _inputDeco(cs, 'Reference document'),
                  style: TextStyle(fontSize: 13, color: cs.onSurface),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              gap,
              filterCol(
                lbl: 'Period',
                control: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context:         context,
                      firstDate:       DateTime(2020),
                      lastDate:        DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: _filterDateRange,
                    );
                    if (range != null) setState(() => _filterDateRange = range);
                  },
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color:  cs.surface,
                      border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range_outlined,
                            size: 15, color: cs.onSurfaceVariant),
                        const Gap(6),
                        Expanded(
                          child: Text(periodLabel,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _filterDateRange != null
                                      ? cs.onSurface
                                      : cs.onSurfaceVariant)),
                        ),
                        if (_filterDateRange != null)
                          GestureDetector(
                            onTap: () => setState(() => _filterDateRange = null),
                            child: Icon(Icons.close,
                                size: 14, color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              gap,
              // Buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 15), // align with controls
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon:      const Icon(Icons.filter_alt_off_outlined, size: 15),
                        label:     const Text('Clear'),
                        onPressed: _clearFilters,
                        style:     OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
                      ),
                      const Gap(8),
                      FilledButton.icon(
                        icon:      const Icon(Icons.search, size: 15),
                        label:     const Text('Search'),
                        onPressed: () => setState(() {}),
                        style:     FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
                      ),
                      const Gap(16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('TOTAL RESULTS',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: cs.onSurfaceVariant)),
                          Text(
                            totalResults.toString(),
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: cs.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final asyncDocs = ref.watch(allDocumentsProvider);
    final company   = ref.watch(selectedCompanyProvider);
    final theme     = Theme.of(context);

    // Load filter-source data (silently — empty list while loading)
    final types      = ref.watch(allDocumentTypesProvider).value ?? [];
    final users      = ref.watch(allUsersProvider).value ?? [];
    final customers  = ref.watch(allCustomersProvider).value ?? [];
    final warehouses = ref.watch(allWarehousesProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Document Explorer"),
        elevation: 0,
        // Suppress the auto back-arrow — ManagementLayout controls navigation.
        automaticallyImplyLeading: false,
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Show navigation',
                onPressed: widget.onMenuPressed,
              )
            : null,
        actions: [
          IconButton(
            icon:     const Icon(Icons.view_column_rounded),
            tooltip:  "Columns",
            onPressed: () => _showColumnPicker(context),
          ),
          IconButton(
            icon:    const Icon(Icons.refresh),
            tooltip: "Sync & Refresh",
            onPressed: () {
              ref.read(syncStateProvider.notifier).sync().catchError((_) {});
              ref.invalidate(allDocumentsProvider);
            },
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton.icon(
              onPressed: company == null ? null : () => showDocumentEditor(context, ref),
              icon:  const Icon(Icons.add, size: 18),
              label: const Text("NEW"),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: asyncDocs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text("Error loading documents: $e")),
        data: (allDocs) {
          if (company == null) return const Center(child: Text("No company selected."));
          final filtered = _applyFilters(allDocs);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFilterPanel(
                context:     context,
                theme:       theme,
                types:       types,
                users:       users,
                customers:   customers,
                warehouses:  warehouses,
                totalResults: filtered.length,
              ),
              Expanded(
                child: _DocumentTable(
                  documents:  filtered,
                  companyId:  company.id,
                  formatDate: _formatDate,
                  paidBadge:  (status) => _paidBadge(context, status),
                  onRefresh:  () => ref.invalidate(allDocumentsProvider),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Document table ────────────────────────────────────────────────────────────

class _DocumentTable extends ConsumerWidget {
  final List<Document> documents;
  final int companyId;
  final String Function(String?) formatDate;
  final Widget Function(int) paidBadge;
  final VoidCallback onRefresh;

  const _DocumentTable({
    required this.documents,
    required this.companyId,
    required this.formatDate,
    required this.paidBadge,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme              = Theme.of(context);
    final isDark             = theme.brightness == Brightness.dark;
    final columnsVisibility  = ref.watch(documentVisibleColumnsProvider);
    final sym                = ref.watch(currencySymbolProvider);

    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded,
                size: 64,
                color: theme.disabledColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text("No documents matching filters.",
                style: TextStyle(color: theme.disabledColor, fontSize: 16)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark
                    ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              ),
              dataRowMinHeight: 52,
              dataRowMaxHeight: 60,
              columnSpacing:   24,
              dividerThickness: 0.5,
              columns: _buildColumns(columnsVisibility, theme),
              rows: documents
                  .map((d) => DataRow(
                        cells: _buildCells(
                            context, ref, d, columnsVisibility, theme, sym),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns(Map<String, bool> v, ThemeData t) {
    return [
      if (v['ID']            == true) const DataColumn(label: Text("ID"),            numeric: true),
      if (v['Number']        == true) const DataColumn(label: Text("NUMBER")),
      if (v['Doc Type']      == true) const DataColumn(label: Text("TYPE")),
      if (v['Paid']          == true) const DataColumn(label: Text("STATUS")),
      if (v['Customer']      == true) const DataColumn(label: Text("CUSTOMER")),
      if (v['Date']          == true) const DataColumn(label: Text("DATE")),
      if (v['Order #']       == true) const DataColumn(label: Text("ORDER #")),
      if (v['User']          == true) const DataColumn(label: Text("USER")),
      if (v['Discount']      == true) const DataColumn(label: Text("DISC"),          numeric: true),
      if (v['Total']         == true) const DataColumn(label: Text("TOTAL"),         numeric: true),
      if (v['Internal Note'] == true) const DataColumn(label: Text("INTERNAL NOTE")),
      if (v['Note']          == true) const DataColumn(label: Text("NOTE")),
      if (v['Created']       == true) const DataColumn(label: Text("CREATED")),
      if (v['Updated']       == true) const DataColumn(label: Text("UPDATED")),
      if (v['Actions']       == true) const DataColumn(label: Text("ACTIONS")),
    ];
  }

  List<DataCell> _buildCells(
    BuildContext context,
    WidgetRef ref,
    Document d,
    Map<String, bool> v,
    ThemeData theme,
    String sym,
  ) {
    return [
      if (v['ID'] == true)
        DataCell(Text(d.id.toString(),
            style: TextStyle(color: theme.disabledColor, fontSize: 12))),
      if (v['Number'] == true)
        DataCell(Text(d.number,
            style: const TextStyle(fontWeight: FontWeight.bold))),
      if (v['Doc Type'] == true)
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.description_outlined,
              size: 16, color: theme.colorScheme.secondary),
          const SizedBox(width: 8),
          Text(d.documentTypeName ?? '-'),
        ])),
      if (v['Paid']     == true) DataCell(paidBadge(d.paidStatus)),
      if (v['Customer'] == true) DataCell(Text(d.customerName ?? '-')),
      if (v['Date']     == true) DataCell(Text(formatDate(d.dateCreated ?? d.date))),
      if (v['Order #']  == true) DataCell(Text(d.orderNumber ?? 'N/A')),
      if (v['User']     == true) DataCell(Text(d.userName ?? '-')),
      if (v['Discount'] == true)
        DataCell(Text(d.discount <= 0
            ? "-"
            : (d.discountType == 1
                ? "-${d.discount.toStringAsFixed(2)}"
                : "${d.discount.toStringAsFixed(0)}%"))),
      if (v['Total'] == true)
        DataCell(Text(
          "${d.total.toStringAsFixed(2)} $sym",
          style: TextStyle(
              fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
        )),
      if (v['Internal Note'] == true) DataCell(Text(d.internalNote ?? '-')),
      if (v['Note']          == true) DataCell(Text(d.note ?? '-')),
      if (v['Created']       == true) DataCell(Text(formatDate(d.dateCreated))),
      if (v['Updated']       == true) DataCell(Text(formatDate(d.dateUpdated))),
      if (v['Actions'] == true)
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: Icon(Icons.edit_rounded,
                color: theme.colorScheme.secondary, size: 20),
            tooltip:  "Edit",
            onPressed: () => showDocumentEditor(context, ref, existingDocument: d),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: context.dangerColor, size: 20),
            tooltip:  "Delete",
            onPressed: () => ref.read(securityGuardProvider).guard(
              context,
              SecurityKeys.invoicesDelete,
              () => _confirmDelete(context, ref, d),
            ),
          ),
        ])),
    ];
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Document d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   const Text("Delete Document"),
        content: Text("Are you sure you want to delete '${d.number}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ctx.dangerColor,
                foregroundColor: ctx.onStatusColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await _delete(context, ref, d, companyId);
      onRefresh();
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Document d, int companyId) async {
    final db = ref.read(appDatabaseProvider);
    try {
      // Offline-first: resolve the local row (by localId, else by serverId) and
      // soft-delete/hard-delete it locally so it disappears immediately. The
      // sync queue issues /Document/Delete on the next sync.
      var localId = d.localId;
      if (localId == null && d.id > 0) {
        localId = (await db.getDocumentByServerId(d.id))?.localId;
      }
      if (localId != null) {
        await db.deleteDocumentLocal(localId);
        ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      } else if (d.id > 0) {
        // No local row — fall back to a direct server delete.
        await createDio().delete(
          '/Document/Delete',
          queryParameters: {'id': d.id, 'companyId': companyId},
        );
      }
      if (!context.mounted) return;
      showAppSnackbar(context, ref, 'Document deleted');
    } on DioException catch (e) {
      if (!context.mounted) return;
      final data = e.response?.data;
      final msg = (data is Map ? data['message'] : data?.toString()) ?? 'Delete failed';
      showAppSnackbar(context, ref, msg, isError: true);
    }
  }
}
