import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/core/app_date_picker.dart';
import 'package:pos_app/core/ilyass_table.dart';
import 'package:pos_app/core/unified_search_bar.dart';
import 'package:pos_app/document/document_filters.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/security/security_guard.dart';
import 'package:pos_app/security/security_keys.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/database/app_database.dart';
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
final allDocumentsProvider = FutureProvider.autoDispose<List<Document>>((
  ref,
) async {
  final company = ref.watch(selectedCompanyProvider);
  if (company == null) return [];
  final db = ref.watch(appDatabaseProvider);

  // Prefetch lookup rows once — avoids N+1 per-row queries.
  final customerRows = await db.select(db.customersTable).get();
  final userRows = await db.select(db.usersTable).get();
  final customerMap = {for (final c in customerRows) c.id: c.name};
  final userMap = {for (final u in userRows) u.id: u.name};

  // Best-effort type names from the API-backed provider; gracefully empty offline.
  final docTypes = ref.watch(allDocumentTypesProvider).value ?? [];
  final typeMap = {for (final t in docTypes) t.id: t.name};

  final rows = await db.getDocuments(companyId: company.id);

  return rows
      .map((row) => documentFromRow(
            row,
            userName: userMap[row.userId],
            customerName:
                row.customerId != null ? customerMap[row.customerId] : null,
            documentTypeName: typeMap[row.documentTypeId],
          ))
      .toList();
});

/// One local Drift row → the [Document] the editor takes.
///
/// Shared rather than inlined in the list: anything holding a local row — the
/// documents list, a session's payment list — must open the editor with the
/// same object, or the two paths drift apart in exactly the fields that decide
/// whether a save is an update or a duplicate.
///
/// The display names are optional because they are cosmetic: the editor
/// resolves customer / user / type from their ids either way.
Document documentFromRow(
  DocumentsTableData row, {
  String? userName,
  String? customerName,
  String? documentTypeName,
}) {
  // `number` carries the real value only — the editor seeds its Number field
  // from it and writes it straight back, so a "—" / "(Pending sync)" baked in
  // here would be saved AS the document number. The list renders those two
  // placeholders itself, off isPendingSync (see _displayNumber).
  return Document(
    id: row.serverId ?? 0,
    localId: row.localId,
    number: row.number ?? '',
    isPendingSync:
        row.syncStatus == 'pending' || row.syncStatus == 'pending_create',
    userId: row.userId,
    userName: userName,
    customerId: row.customerId ?? 0,
    customerName: customerName,
    companyId: row.companyId,
    documentTypeId: row.documentTypeId,
    documentTypeName: documentTypeName,
    warehouseId: row.warehouseId,
    orderNumber: row.orderNumber,
    date: row.date.toIso8601String(),
    stockDate: row.stockDate?.toIso8601String(),
    dueDate: row.dueDate?.toIso8601String(),
    total: row.total,
    discount: row.discount,
    discountType: row.discountType,
    paidStatus: row.paidStatus,
    discountApplyRule: row.discountApplyRule,
    serviceType: row.serviceType,
    internalNote: row.internalNote,
    note: row.note,
    referenceDocumentNumber: row.referenceDocumentNumber,
  );
}

/// Document types, streamed from the local Drift cache so the editor's type
/// picker (and offline document creation) work without a network connection.
/// Seeded by SyncManager.pullDocumentTypes.
final allDocumentTypesProvider = StreamProvider.autoDispose<List<DocumentType>>(
  (ref) {
    final db = ref.watch(appDatabaseProvider);
    return db.watchDocumentTypes().map(
      (rows) => rows
          .map(
            (r) => DocumentType(
              id: r.id,
              name: r.name,
              code: r.code,
              documentCategoryId: r.documentCategoryId,
              stockDirection: r.stockDirection,
            ),
          )
          .toList(),
    );
  },
);

final documentVisibleColumnsProvider = StateProvider<Map<String, bool>>(
  (ref) => {
    'ID': false,
    'Number': true,
    'Doc Type': true,
    'Paid': true,
    'Customer': true,
    'Date': true,
    'Order #': true,
    'User': false,
    'Discount': false,
    'Total': true,
    'Internal Note': false,
    'Note': false,
    'Created': false,
    'Updated': false,
    'Actions': true,
  },
);

/// What to show in place of a document number that does not exist yet. Kept out
/// of [Document.number] on purpose: that field seeds the editor's Number field
/// and is written straight back to the DB on save, so a placeholder stored
/// there would be persisted as the document's actual number.
String _displayNumber(BuildContext context, Document d) {
  if (d.number.isNotEmpty) return d.number;
  return d.isPendingSync
      ? '(${AppLocalizations.of(context).pendingSync})'
      : '—';
}

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
  /// Everything this screen filters on, in one immutable value. The eight
  /// nullable fields this replaced had to be kept in step with a `where`
  /// clause, a Reset button and eight dropdowns; a document now simply asks
  /// [DocumentFilters.matches] whether it belongs.
  DocumentFilters _filters = const DocumentFilters();

  final _searchCtrl = TextEditingController();

  final _dateFmt = DateFormat('dd/MM/yy');

  @override
  void initState() {
    super.initState();
    tz_data.initializeTimeZones();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
            : DateTime.utc(
                dt.year,
                dt.month,
                dt.day,
                dt.hour,
                dt.minute,
                dt.second,
              );
        final tzId =
            ref.read(appSettingsProvider)[SettingKeys.timezone] ?? 'UTC';
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

  String _monthAbbr(int m) =>
      AppLocalizations.of(context).monthAbbreviations.split(',')[m - 1];

  // ── badges ────────────────────────────────────────────────────────────────

  Widget _paidBadge(BuildContext context, int status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    switch (status) {
      case 1:
        return _badge(l.paid, isDark ? Colors.greenAccent : Colors.green);
      case 2:
        return _badge(l.partial, isDark ? Colors.orangeAccent : Colors.orange);
      case 0:
        return _badge(l.unpaid, isDark ? Colors.redAccent : Colors.red);
      default:
        return _badge(l.notAvailableShort, Colors.grey);
    }
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── filtering ─────────────────────────────────────────────────────────────

  List<Document> _applyFilters(List<Document> docs) =>
      docs.where(_filters.matches).toList();

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() => _filters = const DocumentFilters());
  }

  /// Applies (or un-applies) one filter from the menu.
  ///
  /// A suggestion built from the typed text consumes that text: leaving it in
  /// the field would filter twice — once as the chip, once as the free-text
  /// query — and the second pass is invisible to the operator.
  void _applyFilter(DocumentFilter filter, {bool consumesQuery = false}) {
    setState(() {
      var next = _filters.toggle(filter);
      if (consumesQuery) {
        _searchCtrl.clear();
        next = next.withQuery('');
      }
      _filters = next;
    });
  }

  void _removeFilter(DocumentFilterKind kind) =>
      setState(() => _filters = _filters.without(kind));

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final current = _filters.of(DocumentFilterKind.period)?.value
        as DateTimeRange?;
    final range = await showAppDateRangePicker(
      context,
      initialStart: current?.start ?? DateTime(now.year, now.month, 1),
      initialEnd: current?.end ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (range == null || !mounted) return;
    _applyFilter(_periodFilter(range));
  }

  DocumentFilter _periodFilter(DateTimeRange range) => DocumentFilter(
        kind: DocumentFilterKind.period,
        label: '${_dateFmt.format(range.start)} - ${_dateFmt.format(range.end)}',
        value: range,
        icon: Icons.date_range_outlined,
      );

  // ── column picker ─────────────────────────────────────────────────────────

  /// The keys of [documentVisibleColumnsProvider] are stable English ids — they
  /// are the map's identity, not display text — so the picker translates them
  /// on the way out instead. Same id→label split the table headers use.
  String _columnLabel(BuildContext context, String id) {
    final l = AppLocalizations.of(context);
    return switch (id) {
      'ID' => l.idLabel,
      'Number' => l.numberLabel,
      'Doc Type' => l.documentType,
      'Paid' => l.paidStatus,
      'Customer' => l.customerLabel,
      'Date' => l.dateLabel,
      'Order #' => l.orderNumberLabel,
      'User' => l.userLabel,
      'Discount' => l.discountLabel,
      'Total' => l.totalLabel,
      'Internal Note' => l.internalNoteLabel,
      'Note' => l.noteLabel,
      'Created' => l.created,
      'Updated' => l.updatedLabel,
      'Actions' => l.actionsLabel,
      _ => id,
    };
  }

  void _showColumnPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final columns = ref.watch(documentVisibleColumnsProvider);
          return AlertDialog(
            title: Text(AppLocalizations.of(context).showHideColumns),
            content: SizedBox(
              width: 300,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: columns.keys
                      .map(
                        (col) => CheckboxListTile(
                          title: Text(_columnLabel(context, col)),
                          value: columns[col],
                          onChanged: (val) => ref
                              .read(documentVisibleColumnsProvider.notifier)
                              .update((s) => {...s, col: val ?? false}),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).actionClose),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── filter panel ──────────────────────────────────────────────────────────

  /// The Odoo-style unified search: one bar carrying the typed query and every
  /// active filter as a dismissible chip, with a categorised menu anchored
  /// under it. Replaces the eight exposed dropdowns, which cost a third of the
  /// screen to state something the chips now say in one line.
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
    final l = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final searchBar = UnifiedSearchBar(
            controller: _searchCtrl,
            hintText: l.docSearchHint,
            chips: _searchChips(),
            sectionsBuilder: (query) => _filterSections(
              query: query,
              l: l,
              types: types,
              users: users,
              customers: customers,
              warehouses: warehouses,
            ),
            onQueryChanged: (value) =>
                setState(() => _filters = _filters.withQuery(value)),
            onClearAll: _clearFilters,
          );

          final results = _ResultCount(count: totalResults, label: l.totalResultsUpper);

          // The count sits beside the bar when there is room and drops under it
          // when there is not - the bar itself must never be squeezed narrow.
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchBar,
                const Gap(10),
                Align(alignment: AlignmentDirectional.centerEnd, child: results),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: searchBar),
              const Gap(20),
              results,
            ],
          );
        },
      ),
    );
  }

  /// One chip per active filter, in the order they were applied.
  List<SearchBarChip> _searchChips() => [
        for (final f in _filters.filters)
          SearchBarChip(
            id: f.kind.name,
            label: f.label,
            icon: f.icon,
            onRemove: () => _removeFilter(f.kind),
          ),
      ];

  /// The menu under the bar. Sections are built against the CURRENT query, so
  /// typing both offers "Number contains ..." suggestions and narrows the long
  /// lists (customers, users) in place.
  List<FilterMenuSection> _filterSections({
    required String query,
    required AppLocalizations l,
    required List<DocumentType> types,
    required List<User> users,
    required List<Customer> customers,
    required List<Warehouse> warehouses,
  }) {
    final q = query.trim();
    final lower = q.toLowerCase();
    const maxPerSection = 8;

    String userName(User u) {
      final full = '${u.firstName ?? ''} ${u.lastName ?? ''}'.trim();
      return full.isNotEmpty ? full : (u.username ?? l.userNumbered('${u.id}'));
    }

    /// Narrows a list by the typed text and caps it, so a shop with 2000
    /// customers still gets a menu that opens instantly.
    (List<T>, bool) narrow<T>(List<T> all, String Function(T) label) {
      final matched = lower.isEmpty
          ? all
          : all.where((e) => label(e).toLowerCase().contains(lower)).toList();
      return (matched.take(maxPerSection).toList(),
          matched.length > maxPerSection);
    }

    FilterMenuOption option(
      DocumentFilter filter, {
      bool consumesQuery = false,
    }) =>
        FilterMenuOption(
          label: filter.label,
          icon: filter.icon,
          selected: _filters.has(filter.kind, filter.value),
          onSelected: () =>
              _applyFilter(filter, consumesQuery: consumesQuery),
        );

    final sections = <FilterMenuSection>[];

    // 1. What the typed text could mean. Odoo's move: the query itself becomes
    //    a filter, which is how a single bar replaces the Number and Reference
    //    fields without losing them.
    if (q.isNotEmpty) {
      sections.add(FilterMenuSection(
        title: l.filterSuggestionsSection,
        icon: Icons.search,
        options: [
          option(
            DocumentFilter(
              kind: DocumentFilterKind.number,
              label: l.filterNumberContains(q),
              value: q,
              icon: Icons.tag,
            ),
            consumesQuery: true,
          ),
          option(
            DocumentFilter(
              kind: DocumentFilterKind.reference,
              label: l.filterReferenceContains(q),
              value: q,
              icon: Icons.link,
            ),
            consumesQuery: true,
          ),
        ],
      ));
    }

    // 2. Status
    sections.add(FilterMenuSection(
      title: l.paidStatus,
      icon: Icons.payments_outlined,
      options: [
        for (final entry in {1: l.paid, 2: l.partial, 0: l.unpaid}.entries)
          option(DocumentFilter(
            kind: DocumentFilterKind.paidStatus,
            label: entry.value,
            value: entry.key,
            icon: Icons.payments_outlined,
          )),
      ],
    ));

    // 3. Period
    final now = DateTime.now();
    final thisMonth = DateTimeRange(
      start: DateTime(now.year, now.month),
      end: now,
    );
    final lastMonthStart = DateTime(now.year, now.month - 1);
    final lastMonth = DateTimeRange(
      start: lastMonthStart,
      end: DateTime(now.year, now.month).subtract(const Duration(days: 1)),
    );
    sections.add(FilterMenuSection(
      title: l.periodLabel,
      icon: Icons.date_range_outlined,
      options: [
        option(DocumentFilter(
          kind: DocumentFilterKind.period,
          label: l.today,
          value: DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day),
          ),
          icon: Icons.today_outlined,
        )),
        option(DocumentFilter(
          kind: DocumentFilterKind.period,
          label: l.thisMonth,
          value: thisMonth,
          icon: Icons.date_range_outlined,
        )),
        option(DocumentFilter(
          kind: DocumentFilterKind.period,
          label: l.lastMonth,
          value: lastMonth,
          icon: Icons.date_range_outlined,
        )),
        FilterMenuOption(
          label: l.filterCustomRange,
          icon: Icons.edit_calendar_outlined,
          onSelected: _pickPeriod,
        ),
      ],
    ));

    // 4-7. The lookup lists, each narrowed by the query.
    final (docTypes, typesTruncated) = narrow(types, (t) => t.name);
    sections.add(FilterMenuSection(
      title: l.documentType,
      icon: Icons.description_outlined,
      footnote: typesTruncated ? l.filterKeepTyping : null,
      options: [
        for (final t in docTypes)
          option(DocumentFilter(
            kind: DocumentFilterKind.docType,
            label: t.name,
            value: t.id,
            icon: Icons.description_outlined,
          )),
      ],
    ));

    final (people, customersTruncated) = narrow(customers, (c) => c.name);
    sections.add(FilterMenuSection(
      title: l.customerLabel,
      icon: Icons.person_outline,
      footnote: customersTruncated ? l.filterKeepTyping : null,
      options: [
        for (final c in people)
          option(DocumentFilter(
            kind: DocumentFilterKind.customer,
            label: c.name,
            value: c.id,
            icon: Icons.person_outline,
          )),
      ],
    ));

    final (staff, usersTruncated) = narrow(users, userName);
    sections.add(FilterMenuSection(
      title: l.userLabel,
      icon: Icons.badge_outlined,
      footnote: usersTruncated ? l.filterKeepTyping : null,
      options: [
        for (final u in staff)
          option(DocumentFilter(
            kind: DocumentFilterKind.user,
            label: userName(u),
            value: u.id,
            icon: Icons.badge_outlined,
          )),
      ],
    ));

    final (stores, warehousesTruncated) = narrow(warehouses, (w) => w.name);
    sections.add(FilterMenuSection(
      title: l.warehouse,
      icon: Icons.warehouse_outlined,
      footnote: warehousesTruncated ? l.filterKeepTyping : null,
      options: [
        for (final w in stores)
          option(DocumentFilter(
            kind: DocumentFilterKind.warehouse,
            label: w.name,
            value: w.id,
            icon: Icons.warehouse_outlined,
          )),
      ],
    ));

    return sections;
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final asyncDocs = ref.watch(allDocumentsProvider);
    final company = ref.watch(selectedCompanyProvider);
    final theme = Theme.of(context);

    // Load filter-source data (silently — empty list while loading)
    final types = ref.watch(allDocumentTypesProvider).value ?? [];
    final users = ref.watch(allUsersProvider).value ?? [];
    final customers = ref.watch(allCustomersProvider).value ?? [];
    final warehouses = ref.watch(allWarehousesProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).documentExplorer),
        elevation: 0,
        // Suppress the auto back-arrow — ManagementLayout controls navigation.
        automaticallyImplyLeading: false,
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: AppLocalizations.of(context).showNavigation,
                onPressed: widget.onMenuPressed,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.view_column_rounded),
            tooltip: AppLocalizations.of(context).columns,
            onPressed: () => _showColumnPicker(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context).syncAndRefresh,
            onPressed: () {
              // The refresh button ON the documents screen — the single most
              // likely place someone checks whether another till's delete has
              // landed. Must reconcile deletions, not just pull additions.
              ref
                  .read(syncStateProvider.notifier)
                  .sync(manual: true)
                  .catchError((_) {});
              ref.invalidate(allDocumentsProvider);
            },
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton.icon(
              onPressed: company == null
                  ? null
                  : () => showDocumentEditor(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: Text(AppLocalizations.of(context).colNew),
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
        error: (e, _) => Center(child: Text(AppLocalizations.of(context).errorLoadingDocuments(e.toString()))),
        data: (allDocs) {
          if (company == null) {
            return Center(child: Text(AppLocalizations.of(context).noCompanySelectedShort));
          }
          final filtered = _applyFilters(allDocs);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFilterPanel(
                context: context,
                theme: theme,
                types: types,
                users: users,
                customers: customers,
                warehouses: warehouses,
                totalResults: filtered.length,
              ),
              Expanded(
                child: _DocumentTable(
                  documents: filtered,
                  companyId: company.id,
                  formatDate: _formatDate,
                  paidBadge: (status) => _paidBadge(context, status),
                  onRefresh: () => ref.invalidate(allDocumentsProvider),
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
    final theme = Theme.of(context);
    final visible = ref.watch(documentVisibleColumnsProvider);
    final sym = ref.watch(currencySymbolProvider);

    return IlyassTable<Document>(
      tableId: 'documents',
      rows: documents,
      columns: _columns(context, ref, visible, theme, sym),
      emptyState: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 64,
              color: theme.disabledColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).noDocumentsMatchingFilters,
              style: TextStyle(color: theme.disabledColor, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// Columns and cells in ONE list.
  ///
  /// The old table declared them as two parallel `if (v['X'])` chains, header
  /// and cell, which only lined up as long as both chains were edited
  /// together - miss one and every column right of it shows the wrong data.
  /// Here a column carries its own cell builder, so that class of bug cannot
  /// be written.
  ///
  /// Widths are starting points: every column except Actions can be dragged by
  /// its header edge, and [IlyassColumn.flexible] decides which one swallows
  /// the surplus on a wide monitor.
  List<IlyassColumn<Document>> _columns(
    BuildContext context,
    WidgetRef ref,
    Map<String, bool> v,
    ThemeData theme,
    String sym,
  ) {
    final l = AppLocalizations.of(context);

    // Which column absorbs the surplus width. Customer is the widest-varying
    // field; Number is the fallback when it is switched off. With neither the
    // table simply stops at its natural width rather than spreading the slack
    // evenly - which is what opened the dead zone between CUSTOMER and DATE.
    final flexKey = v['Customer'] == true
        ? 'Customer'
        : (v['Number'] == true ? 'Number' : null);

    return [
      if (v['ID'] == true)
        IlyassColumn<Document>(
          key: 'ID',
          label: l.idLabel,
          width: 72,
          minWidth: 56,
          numeric: true,
          cell: (context, d) => Text(
            d.id.toString(),
            style: TextStyle(color: theme.disabledColor, fontSize: 12),
          ),
        ),
      if (v['Number'] == true)
        IlyassColumn<Document>(
          key: 'Number',
          label: l.colNumber,
          width: 170,
          flexible: flexKey == 'Number',
          cell: (context, d) => Text(
            _displayNumber(context, d),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      if (v['Doc Type'] == true)
        IlyassColumn<Document>(
          key: 'Doc Type',
          label: l.colType,
          width: 160,
          cell: (context, d) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                size: 16,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  d.documentTypeName ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      if (v['Paid'] == true)
        IlyassColumn<Document>(
          key: 'Paid',
          label: l.colStatus,
          width: 120,
          minWidth: 90,
          cell: (context, d) => paidBadge(d.paidStatus),
        ),
      if (v['Customer'] == true)
        IlyassColumn<Document>(
          key: 'Customer',
          label: l.colCustomer,
          width: 220,
          flexible: flexKey == 'Customer',
          cell: (context, d) => Text(
            d.customerName ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (v['Date'] == true)
        IlyassColumn<Document>(
          key: 'Date',
          label: l.colDate,
          width: 165,
          cell: (context, d) => Text(
            formatDate(d.dateCreated ?? d.date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (v['Order #'] == true)
        IlyassColumn<Document>(
          key: 'Order #',
          label: l.colOrderNo,
          width: 140,
          cell: (context, d) => Text(
            d.orderNumber ?? l.notAvailableShort,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (v['User'] == true)
        IlyassColumn<Document>(
          key: 'User',
          label: l.colUser,
          width: 150,
          cell: (context, d) => Text(
            d.userName ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (v['Discount'] == true)
        IlyassColumn<Document>(
          key: 'Discount',
          label: l.colDisc,
          width: 110,
          minWidth: 80,
          numeric: true,
          cell: (context, d) => Text(
            d.discount <= 0
                ? '-'
                : (d.discountType == 1
                      ? '-${d.discount.toStringAsFixed(2)}'
                      : '${d.discount.toStringAsFixed(0)}%'),
          ),
        ),
      if (v['Total'] == true)
        IlyassColumn<Document>(
          key: 'Total',
          label: l.totalUpper,
          width: 140,
          minWidth: 100,
          // Money is end-aligned, always. A column of totals is read by its
          // last digits, and a centred one cannot be scanned at all.
          numeric: true,
          cell: (context, d) => Text(
            '${d.total.toStringAsFixed(2)} $sym',
            maxLines: 1,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      if (v['Internal Note'] == true)
        IlyassColumn<Document>(
          key: 'Internal Note',
          label: l.internalNote,
          width: 200,
          cell: (context, d) => Text(
            d.internalNote ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (v['Note'] == true)
        IlyassColumn<Document>(
          key: 'Note',
          label: l.colNote,
          width: 200,
          cell: (context, d) => Text(
            d.note ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (v['Created'] == true)
        IlyassColumn<Document>(
          key: 'Created',
          label: l.colCreated,
          width: 165,
          cell: (context, d) => Text(
            formatDate(d.dateCreated),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (v['Updated'] == true)
        IlyassColumn<Document>(
          key: 'Updated',
          label: l.colUpdated,
          width: 165,
          cell: (context, d) => Text(
            formatDate(d.dateUpdated),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (v['Actions'] == true)
        IlyassColumn<Document>(
          key: 'Actions',
          label: l.colActions,
          // Fixed and not resizable: two icons at a known size, packed tight.
          // Dragging this column would only ever create dead space.
          width: 96,
          resizable: false,
          cell: (context, d) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.edit_rounded,
                  color: theme.colorScheme.secondary,
                  size: 20,
                ),
                tooltip: l.actionEdit,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                onPressed: () =>
                    showDocumentEditor(context, ref, existingDocument: d),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: context.dangerColor,
                  size: 20,
                ),
                tooltip: l.actionDelete,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                onPressed: () => ref.read(securityGuardProvider).guard(
                      context,
                      SecurityKeys.invoicesDelete,
                      () => _confirmDelete(context, ref, d),
                    ),
              ),
            ],
          ),
        ),
    ];
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Document d,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteDocument),
        content: Text(
          AppLocalizations.of(context)
              .confirmDeleteQuoted(_displayNumber(context, d)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context).actionCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.dangerColor,
              foregroundColor: ctx.onStatusColor,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(context).actionDelete),
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
    BuildContext context,
    WidgetRef ref,
    Document d,
    int companyId,
  ) async {
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
      showAppSnackbar(context, ref, AppLocalizations.of(context).documentDeleted);
    } on DioException catch (e) {
      if (!context.mounted) return;
      final data = e.response?.data;
      final msg = (data is Map ? data['message'] : data?.toString()) ??
          AppLocalizations.of(context).deleteFailed;
      showAppSnackbar(context, ref, msg, isError: true);
    }
  }
}

/// TOTAL RESULTS, pinned to the trailing edge beside the search bar.
class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: cs.onSurfaceVariant,
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: cs.primary,
          ),
        ),
      ],
    );
  }
}
