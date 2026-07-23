import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:pos_app/cart/payment_model.dart';
import 'package:pos_app/cart/discount_display.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/app_date_picker.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/document/document_model.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/product/product_provider.dart';
import 'package:pos_app/document/documents_screen.dart';
import 'package:pos_app/document/document_item_tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';
import 'package:pos_app/cart/payment_provider.dart';
import 'package:pos_app/cart/payment_type_provider.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/stock/stock_provider.dart';

final documentCategoriesProvider =
    StreamProvider.autoDispose<List<DocumentCategory>>((ref) {
      final company = ref.watch(selectedCompanyProvider);
      if (company == null) return Stream.value(const <DocumentCategory>[]);
      final db = ref.watch(appDatabaseProvider);
      return db.watchDocumentCategories(company.id).map((rows) => rows
          .map((r) => DocumentCategory(id: r.id, name: r.name))
          .toList());
    });

/// Offline-first document line items, streamed from local Drift and keyed by
/// the document's local UUID. Product names/costs are resolved from the local
/// product cache so the editor renders fully offline.
final localDocumentItemsProvider = StreamProvider.autoDispose
    .family<List<DocumentItem>, LocalItemsArgs>((ref, args) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchDocumentItems(args.docLocalId).asyncMap((rows) async {
    final products = await db.select(db.productsTable).get();
    final pById = {for (final p in products) p.id: p};
    // `total` carries two different meanings depending on where the document
    // came from: a checkout document stores each line EX-tax (the tax sits in
    // `taxAmount`), a manual editor document stores it tax-INCLUSIVE. Same
    // origin test as _syncDocumentTotal — checkout stamps `orderNumber`.
    // Reading it origin-blind billed a 15.00 + 20% line as 12.50 (15 / 1.2).
    final doc = await db.getDocumentByLocalId(args.docLocalId);
    final isCheckoutDoc =
        doc?.orderNumber != null && doc!.orderNumber!.isNotEmpty;
    return rows
        .map((r) => DocumentItem.fromDrift(
              r,
              isCheckoutDoc: isCheckoutDoc,
              companyId: args.companyId,
              documentId: args.docServerId,
              product: pById[r.productId],
            ))
        .toList();
  });
});

/// Family key for [localDocumentItemsProvider].
class LocalItemsArgs {
  final String docLocalId;
  final int docServerId;
  final int companyId;

  const LocalItemsArgs({
    required this.docLocalId,
    required this.docServerId,
    required this.companyId,
  });

  @override
  bool operator ==(Object other) =>
      other is LocalItemsArgs &&
      other.docLocalId == docLocalId &&
      other.docServerId == docServerId &&
      other.companyId == companyId;

  @override
  int get hashCode => Object.hash(docLocalId, docServerId, companyId);
}

final documentItemTaxesProvider = FutureProvider.autoDispose
    .family<List<DocumentItemTaxModel>, int>((ref, documentItemId) async {
      final companyId = ref.watch(selectedCompanyProvider)?.id;
      if (companyId == null) return [];

      try {
        final dio = createDio();
        final res = await dio.get(
          '/DocumentItemTaxes/GetByDocumentItemId',
          queryParameters: {
            'documentItemId': documentItemId,
            'companyId': companyId,
          },
        );
        return (res.data as List)
            .map((x) => DocumentItemTaxModel.fromJson(x))
            .toList();
      } catch (e) {
        return [];
      }
    });

// --- ENTRY POINT ---
Future<void> showDocumentEditor(
  BuildContext context,
  WidgetRef ref, {
  Document? existingDocument,
}) async {
  // Grab the container while the context is still valid. After the dialog
  // closes the caller's widget may already be deactivated, which makes the
  // passed-in WidgetRef unsafe to use (it relies on a live BuildContext).
  // The container outlives individual widgets, so invalidating through it is
  // safe regardless of the caller's lifecycle.
  final container = ProviderScope.containerOf(context, listen: false);
  await showDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => _DocumentEditorDialog(existingDocument: existingDocument),
  );
  container.invalidate(allDocumentsProvider);
}

// --- MAIN EDITOR DIALOG ---
class _DocumentEditorDialog extends ConsumerStatefulWidget {
  final Document? existingDocument;
  const _DocumentEditorDialog({this.existingDocument});

  @override
  ConsumerState<_DocumentEditorDialog> createState() =>
      _DocumentEditorDialogState();
}

class _DocumentEditorDialogState extends ConsumerState<_DocumentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _headerSaved = false;
  int? _savedDocumentId;
  // Drift local UUID for the saved document — the key the offline-first
  // paid-status and payments writes operate on. Resolved lazily from the
  // document's server id when not supplied directly by the list.
  String? _savedDocumentLocalId;
  Document? _savedDocument;

  int? _selectedDocTypeId;
  String? _selectedDocTypeName;
  int? _selectedCustomerId;
  int? _selectedUserId;
  int? _selectedWarehouseId;
  late DateTime _date;
  late DateTime _dueDate;
  late DateTime _stockDate;

  final _numberCtrl = TextEditingController();
  final _internalNoteCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _refDocCtrl = TextEditingController();

  double _discount = 0;
  int _discountType = 0;
  bool _discountApplyRule = true;
  int _serviceType = 0;
  int _paidStatus = 0;

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingDocument != null;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _dueDate = DateTime.now().add(const Duration(days: 30));
    _stockDate = DateTime.now();

    if (_isEditing) {
      final d = widget.existingDocument!;
      _savedDocumentId = d.id;
      _savedDocumentLocalId = d.localId;
      _savedDocument = d;
      _headerSaved = true;

      // The list passes localId for offline-first writes. When it's missing
      // (e.g. a document opened straight from an API payload), resolve it from
      // the server id so paid-status / payments still persist locally.
      if (_savedDocumentLocalId == null && d.id > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _resolveLocalId();
        });
      }
      _selectedDocTypeId = d.documentTypeId;
      _selectedDocTypeName = d.documentTypeName;
      _selectedCustomerId = d.customerId;
      _selectedUserId = d.userId;
      _selectedWarehouseId = d.warehouseId;
      _numberCtrl.text = d.number;
      _internalNoteCtrl.text = d.internalNote ?? '';
      _noteCtrl.text = d.note ?? '';
      _refDocCtrl.text = d.referenceDocumentNumber ?? '';
      _discount = d.discount;
      _discountType = d.discountType;
      _discountApplyRule = d.discountApplyRule;
      _serviceType = d.serviceType;
      _paidStatus = d.paidStatus;

      try {
        _date = DateTime.parse(d.date);
      } catch (_) {}
      try {
        if (d.stockDate != null && d.stockDate!.isNotEmpty) {
          _stockDate = DateTime.parse(d.stockDate!);
        }
      } catch (_) {}
      try {
        if (d.dueDate != null && d.dueDate!.isNotEmpty) {
          _dueDate = DateTime.parse(d.dueDate!);
        }
      } catch (_) {}
    } else {
      // New document: seed discountApplyRule from the global setting.
      // 'Before tax' → false, 'After tax' (default) → true.
      final settings = ref.read(appSettingsProvider);
      final ruleStr = settings[SettingKeys.discountApplyRule] ?? 'After tax';
      _discountApplyRule = ruleStr != 'Before tax';
    }
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _internalNoteCtrl.dispose();
    _noteCtrl.dispose();
    _refDocCtrl.dispose();
    super.dispose();
  }

  Future<String> _fetchNextDocumentNumber(int documentTypeId) async {
    try {
      final companyId = ref.read(selectedCompanyProvider)?.id ?? 0;
      final dio = createDio();
      final response = await dio.get(
        '/Document/GetNextNumber',
        queryParameters: {
          'companyId': companyId,
          'documentTypeId': documentTypeId,
        },
      );
      return response.data as String;
    } catch (_) {
      // Fallback: timestamp-based number so the user can still proceed
      final now = DateTime.now();
      final yy = now.year.toString().substring(2);
      return 'DOC-$yy${now.millisecondsSinceEpoch}';
    }
  }

  String _isoDate(DateTime dt) => dt.toIso8601String().split('.')[0];

  Future<void> _syncDocumentTotal(double itemsSubtotal) async {
    final localId = _savedDocumentLocalId;
    if (localId == null) return;
    final db = ref.read(appDatabaseProvider);
    double finalTotal = itemsSubtotal;

    // Subtract every ORDER-level discount (customer profile, manual cart,
    // loyalty points) from discount_lines. Item-level discounts (manual item /
    // promotion) are already baked into itemsSubtotal, so they must NOT be
    // subtracted again. Key off the SOURCE, not `itemLocalId`: pulled-back lines
    // all return with a null itemLocalId, which would wrongly pull promotions
    // into the order-level set and double-count.
    final lines = await db.getDiscountLinesForDocument(localId);
    final orderLevel = lines
        .where((l) => DiscountSource.orderLevel.contains(l.source))
        .toList();

    // A POS/checkout document stores each line `total` EX-tax (the tax lives in
    // the item's `taxAmount`), so its tax must be added back here. A manual
    // editor document stores `total` tax-INCLUSIVE, so no tax is added.
    // Distinguish by ORIGIN — checkout stamps `orderNumber`, manual docs leave
    // it null — NOT by "has an order-level discount". The old proxy dropped the
    // tax from a taxed cash sale that simply had no discount, understating the
    // total the moment any item was edited.
    final doc = await db.getDocumentByLocalId(localId);
    final isCheckoutDoc =
        doc?.orderNumber != null && doc!.orderNumber!.isNotEmpty;

    if (isCheckoutDoc) {
      final docItems = await db.getActiveDocumentItems(localId);
      finalTotal += docItems.fold<double>(0, (s, i) => s + i.taxAmount);
      finalTotal -= orderLevel.fold<double>(0, (s, l) => s + l.amount);
    } else if (orderLevel.isNotEmpty) {
      // Manual document that nonetheless carries order-level discount_lines:
      // `total` is already tax-inclusive, so just subtract the discounts.
      finalTotal -= orderLevel.fold<double>(0, (s, l) => s + l.amount);
    } else if (_discountType == 1) {
      // Manual document with a header discount only (no discount_lines).
      finalTotal -= _discount;
    } else if (_discountType == 0) {
      finalTotal -= finalTotal * (_discount / 100);
    }
    if (finalTotal < 0) finalTotal = 0;
    try {
      // Offline-first: persist the recomputed total locally; the document is
      // flagged for push and SyncManager sends it to /Document/Update.
      await ref.read(appDatabaseProvider).setDocumentTotalLocal(localId, finalTotal);
      if (!mounted) return;
      // Rebuild so the Payments tab (documentTotal: _savedDocument.total) and
      // its Remaining Balance reflect the new items immediately — without this
      // setState the amount due stayed stale until the dialog was reopened.
      setState(() {
        _savedDocument = _savedDocument == null
            ? null
            : Document(
                id: _savedDocument!.id,
                localId: _savedDocument!.localId,
                number: _savedDocument!.number,
                userId: _savedDocument!.userId,
                customerId: _savedDocument!.customerId,
                companyId: _savedDocument!.companyId,
                documentTypeId: _savedDocument!.documentTypeId,
                documentTypeName: _savedDocument!.documentTypeName,
                warehouseId: _savedDocument!.warehouseId,
                date: _savedDocument!.date,
                total: finalTotal,
                discount: _savedDocument!.discount,
                discountType: _savedDocument!.discountType,
                discountApplyRule: _savedDocument!.discountApplyRule,
                paidStatus: _savedDocument!.paidStatus,
                serviceType: _savedDocument!.serviceType,
              );
      });
      ref.invalidate(allDocumentsProvider);
    } catch (e) {
      debugPrint("Total sync failed: $e");
    }
  }

  /// Resolves (and caches) the Drift local UUID for the saved document so the
  /// offline-first paid-status and payments writes have a key to operate on.
  /// Creates a 'srv_<id>' sentinel row for server-side documents that aren't in
  /// the local store yet (e.g. just created through the API in this dialog).
  Future<String?> _resolveLocalId() async {
    if (_savedDocumentLocalId != null) return _savedDocumentLocalId;
    final serverId = _savedDocumentId ?? 0;
    if (serverId <= 0) return null;
    final company = ref.read(selectedCompanyProvider);
    final localId =
        await ref.read(appDatabaseProvider).ensureLocalDocumentForServer(
              serverId: serverId,
              companyId: company?.id ?? 0,
              userId: _selectedUserId ?? 0,
              warehouseId: _selectedWarehouseId ?? 0,
              documentTypeId: _selectedDocTypeId ?? 0,
              number: _numberCtrl.text.trim(),
              total: _savedDocument?.total ?? 0,
              paidStatus: _paidStatus,
              date: _date,
            );
    if (mounted) setState(() => _savedDocumentLocalId = localId);
    return localId;
  }

  Future<void> _updatePaidStatus(int newStatus) async {
    final companyId = ref.read(selectedCompanyProvider)?.id ?? 0;
    final db = ref.read(appDatabaseProvider);
    final localId = await _resolveLocalId();

    // Offline-first: write through to local SQLite (the source of truth for the
    // documents list) so the toggle persists immediately and survives the
    // provider invalidate. SyncManager pushes the change to the server later.
    if (localId != null) {
      await db.setLocalPaidStatus(localId, newStatus);
      if (!mounted) return;
      setState(() => _paidStatus = newStatus);
      ref.invalidate(allDocumentsProvider);

      // Best-effort immediate server push; the dirty flag retries on next sync.
      if ((_savedDocumentId ?? 0) > 0) {
        try {
          await createDio().patch(
            '/Document/Update',
            queryParameters: {'companyId': companyId},
            data: {'id': _savedDocumentId, 'paidStatus': newStatus},
          );
          await db.clearPaidStatusDirty(localId);
        } catch (e) {
          debugPrint('Paid-status server push deferred to sync: $e');
        }
      }
      return;
    }

    // No server id yet (unsaved document): nothing to persist.
    if ((_savedDocumentId ?? 0) <= 0) return;
  }

  Future<void> _saveOrUpdateHeader() async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;
    if (_selectedDocTypeId == null) {
      setState(() => _errorMessage = "Please select a document type.");
      return;
    }
    if (_selectedCustomerId == null) {
      setState(() => _errorMessage = "Please select a customer/supplier.");
      return;
    }
    if (_selectedUserId == null) {
      setState(() => _errorMessage = "Please select a user.");
      return;
    }
    if (_selectedWarehouseId == null) {
      setState(() => _errorMessage = "Please select a warehouse.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final db = ref.read(appDatabaseProvider);

    try {
      if (!_headerSaved) {
        // --- CREATE (offline-first) ---
        final localId = const Uuid().v4();
        var number = _numberCtrl.text.trim();
        if (number.isEmpty) {
          number = 'DOC-${DateTime.now().millisecondsSinceEpoch}';
        }

        await db.createManualDocument(DocumentsTableCompanion(
          localId: Value(localId),
          companyId: Value(company.id),
          documentTypeId: Value(_selectedDocTypeId!),
          number: Value(number),
          userId: Value(_selectedUserId!),
          warehouseId: Value(_selectedWarehouseId!),
          customerId: Value(_selectedCustomerId),
          // Manual documents (purchases, etc.) are not POS orders — leave the
          // orderNumber null so it never feeds the POS sequence counter
          // (syncOrderNumber). The column and the API field are both nullable.
          orderNumber: const Value(null),
          total: const Value(0),
          discount: Value(_discount),
          discountType: Value(_discountType),
          serviceType: Value(_serviceType),
          paidStatus: const Value(0),
          stockDate: Value(_stockDate),
          dueDate: Value(_dueDate),
          internalNote: Value(_internalNoteCtrl.text.trim()),
          note: Value(_noteCtrl.text.trim()),
          referenceDocumentNumber: Value(_refDocCtrl.text.trim()),
          discountApplyRule: Value(_discountApplyRule),
          date: Value(_date),
          syncStatus: const Value('pending_create'),
          lastModified: Value(DateTime.now().toUtc()),
        ));

        final createdDoc = Document(
          id: 0,
          localId: localId,
          number: number,
          userId: _selectedUserId ?? 0,
          customerId: _selectedCustomerId ?? 0,
          companyId: company.id,
          documentTypeId: _selectedDocTypeId ?? 0,
          documentTypeName: _selectedDocTypeName,
          warehouseId: _selectedWarehouseId ?? 0,
          date: _isoDate(_date),
          total: 0,
          discount: _discount,
          discountType: _discountType,
          discountApplyRule: _discountApplyRule,
          internalNote: _internalNoteCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
          paidStatus: 0,
          serviceType: _serviceType,
        );

        setState(() {
          _savedDocumentId = 0;
          _savedDocumentLocalId = localId;
          _savedDocument = createdDoc;
          _numberCtrl.text = number;
          _headerSaved = true;
          _isLoading = false;
        });

        ref.invalidate(allDocumentsProvider);
        _kickSync();
      } else {
        // --- UPDATE (offline-first) ---
        final localId = await _resolveLocalId();
        if (localId == null) {
          setState(() {
            _errorMessage = "Could not resolve the local document.";
            _isLoading = false;
          });
          return;
        }

        await db.updateManualDocumentHeader(
          localId,
          DocumentsTableCompanion(
            number: Value(_numberCtrl.text.trim()),
            customerId: Value(_selectedCustomerId),
            userId: Value(_selectedUserId!),
            warehouseId: Value(_selectedWarehouseId!),
            documentTypeId: Value(_selectedDocTypeId!),
            discount: Value(_discount),
            discountType: Value(_discountType),
            discountApplyRule: Value(_discountApplyRule),
            serviceType: Value(_serviceType),
            stockDate: Value(_stockDate),
            dueDate: Value(_dueDate),
            internalNote: Value(_internalNoteCtrl.text.trim()),
            note: Value(_noteCtrl.text.trim()),
            referenceDocumentNumber: Value(_refDocCtrl.text.trim()),
            date: Value(_date),
          ),
        );

        setState(() => _isLoading = false);
        ref.invalidate(allDocumentsProvider);
        _kickSync();

        if (mounted) {
          showAppSnackbar(context, ref, "Document saved!");
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Best-effort immediate sync so a saved document reaches the server quickly
  /// when online; the connectivity / auto-sync watchers retry otherwise.
  void _kickSync() {
    ref.read(syncStateProvider.notifier).sync().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String title = "New Document";
    if (_isEditing) {
      title = "Edit Document — ${_numberCtrl.text}";
    } else if (_headerSaved) {
      title = "Document — ${_numberCtrl.text}";
    }

    final companyId = ref.read(selectedCompanyProvider)?.id ?? 0;
    final headerReady = _headerSaved && _savedDocumentLocalId != null;

    // One factory for the header form — each header tab renders a single card
    // via [section]; the fields/handlers stay identical across all three.
    _HeaderForm headerForm(DocumentEditorSection section) => _HeaderForm(
          section: section,
          isEditing: _headerSaved,
          selectedDocTypeName: _selectedDocTypeName,
          selectedCustomerId: _selectedCustomerId,
          selectedUserId: _selectedUserId,
          selectedWarehouseId: _selectedWarehouseId,
          date: _date,
          dueDate: _dueDate,
          stockDate: _stockDate,
          numberCtrl: _numberCtrl,
          internalNoteCtrl: _internalNoteCtrl,
          noteCtrl: _noteCtrl,
          refDocCtrl: _refDocCtrl,
          discount: _discount,
          discountType: _discountType,
          discountApplyRule: _discountApplyRule,
          errorMessage: _errorMessage,
          isLoading: _isLoading,
          onSelectDocType: () async {
            final result = await showDialog<DocumentType>(
              context: context,
              builder: (_) => const _SelectDocumentTypeDialog(),
            );
            if (result != null) {
              setState(() {
                _selectedDocTypeId = result.id;
                _selectedDocTypeName = "${result.code} - ${result.name}";
                _selectedWarehouseId ??=
                    ref.read(selectedWarehouseProvider)?.id;
              });
              if (_numberCtrl.text.isEmpty) {
                final nextNumber = await _fetchNextDocumentNumber(result.id);
                if (mounted) setState(() => _numberCtrl.text = nextNumber);
              }
            }
          },
          onCustomerChanged: (v) => setState(() => _selectedCustomerId = v),
          onUserChanged: (v) => setState(() => _selectedUserId = v),
          onWarehouseChanged: (v) => setState(() => _selectedWarehouseId = v),
          onDatePick: () async {
            final picked = await showAppDatePicker(
              context,
              initialDate: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) setState(() => _date = picked);
          },
          onDueDatePick: () async {
            final picked = await showAppDatePicker(
              context,
              initialDate: _dueDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) setState(() => _dueDate = picked);
          },
          onStockDatePick: () async {
            final picked = await showAppDatePicker(
              context,
              initialDate: _stockDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) setState(() => _stockDate = picked);
          },
          onDiscountChanged: (v) => setState(() => _discount = v),
          onDiscountTypeChanged: (v) => setState(() => _discountType = v),
          onDiscountApplyRuleChanged: (v) =>
              setState(() => _discountApplyRule = v),
          onSave: _saveOrUpdateHeader,
        );

    Widget headerTab(DocumentEditorSection section) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: headerForm(section),
        );

    // Shown on the items/discount/payments tabs until the header is saved.
    Widget needsHeader() => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Save the document header first (Document Info → '
              '${_isEditing ? "Save Header Changes" : "Create & Add Items"}) '
              'to manage items, discounts and payments.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        );

    const List<Widget> dialogTabs = [
      Tab(text: "Document Info"),
      Tab(text: "Parties & Logistics"),
      Tab(text: "Financials & Notes"),
      Tab(text: "Document Items"),
      Tab(text: "Discount Breakdown"),
      Tab(text: "Payments"),
    ];

    final List<Widget> dialogTabViews = [
      headerTab(DocumentEditorSection.info),
      headerTab(DocumentEditorSection.parties),
      headerTab(DocumentEditorSection.financials),
      // Document Items
      headerReady
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _ItemsView(
                documentId: _savedDocumentId ?? 0,
                documentLocalId: _savedDocumentLocalId!,
                companyId: companyId,
                onItemsChanged: _syncDocumentTotal,
                isPurchase: _selectedDocTypeName
                        ?.toLowerCase()
                        .contains('purchase') ==
                    true,
              ),
            )
          : needsHeader(),
      // Discount Breakdown
      headerReady
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child:
                  _DiscountBreakdownCard(documentLocalId: _savedDocumentLocalId!),
            )
          : needsHeader(),
      // Payments
      (headerReady && _savedDocumentId != null && _savedDocument != null)
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: _PaymentsView(
                documentId: _savedDocumentId!,
                documentLocalId: _savedDocumentLocalId,
                companyId: companyId,
                userId: _selectedUserId ?? 0,
                documentTotal: _savedDocument!.total,
                paidStatus: _paidStatus,
                onPaidStatusChanged: _updatePaidStatus,
                onPaidStatusRecomputed: (s) {
                  if (!mounted) return;
                  setState(() => _paidStatus = s);
                  ref.invalidate(allDocumentsProvider);
                },
              ),
            )
          : needsHeader(),
    ];

    return DefaultTabController(
      length: dialogTabs.length,
      child: AlertDialog(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            child: Column(
              children: [
                TabBar(
                  // Six tabs — scroll rather than cram them edge to edge.
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.disabledColor,
                  indicatorColor: theme.colorScheme.primary,
                  tabs: dialogTabs,
                ),
                Expanded(child: TabBarView(children: dialogTabViews)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).actionClose),
          ),
        ],
      ),
    );
  }
}

// --- DOCUMENT TYPE SELECTOR ---
class _SelectDocumentTypeDialog extends ConsumerStatefulWidget {
  const _SelectDocumentTypeDialog();

  @override
  ConsumerState<_SelectDocumentTypeDialog> createState() =>
      _SelectDocumentTypeDialogState();
}

class _SelectDocumentTypeDialogState
    extends ConsumerState<_SelectDocumentTypeDialog> {
  int? _selectedCategoryId;
  DocumentType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final asyncCategories = ref.watch(documentCategoriesProvider);
    final asyncTypes = ref.watch(allDocumentTypesProvider);

    return AlertDialog(
      title: Text(AppLocalizations.of(context).selectDocumentType),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 520,
        height: 380,
        child: asyncCategories.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(AppLocalizations.of(context).errorWithMessage(e.toString()))),
          data: (categories) => asyncTypes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(AppLocalizations.of(context).errorWithMessage(e.toString()))),
            data: (types) {
              if (_selectedCategoryId == null && categories.isNotEmpty) {
                _selectedCategoryId = categories.first.id;
              }
              final filteredTypes = types
                  .where((t) => t.documentCategoryId == _selectedCategoryId)
                  .toList();
              return Row(
                children: [
                  Container(
                    width: 160,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: ListView(
                      children: categories
                          .map(
                            (cat) => ListTile(
                              dense: true,
                              title: Text(cat.name),
                              selected: _selectedCategoryId == cat.id,
                              selectedTileColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.onSecondary,
                              onTap: () => setState(() {
                                _selectedCategoryId = cat.id;
                                _selectedType = null;
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: filteredTypes
                          .map(
                            (t) => ListTile(
                              dense: true,
                              title: Text("${t.code} - ${t.name}"),
                              selected: _selectedType?.id == t.id,
                              selectedTileColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.onSecondary,
                              onTap: () => setState(() => _selectedType = t),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        ElevatedButton(
          onPressed: _selectedType == null
              ? null
              : () => Navigator.of(context).pop(_selectedType),
          child: Text(AppLocalizations.of(context).actionOk),
        ),
      ],
    );
  }
}

/// Which section of the header form to render — lets the editor put each card
/// in its own tab while keeping all the fields/handlers in one widget.
enum DocumentEditorSection { all, info, parties, financials }

// --- HEADER FORM ---
class _HeaderForm extends ConsumerWidget {
  final DocumentEditorSection section;
  final bool isEditing;
  final String? selectedDocTypeName;
  final int? selectedCustomerId;
  final int? selectedUserId;
  final int? selectedWarehouseId;
  final DateTime date;
  final DateTime dueDate;
  final DateTime stockDate;
  final TextEditingController numberCtrl;
  final TextEditingController internalNoteCtrl;
  final TextEditingController noteCtrl;
  final TextEditingController refDocCtrl;
  final double discount;
  final int discountType;
  final bool discountApplyRule;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onSelectDocType;
  final ValueChanged<int?> onCustomerChanged;
  final ValueChanged<int?> onUserChanged;
  final ValueChanged<int?> onWarehouseChanged;
  final VoidCallback onDatePick;
  final VoidCallback onDueDatePick;
  final VoidCallback onStockDatePick;
  final ValueChanged<double> onDiscountChanged;
  final ValueChanged<int> onDiscountTypeChanged;
  final ValueChanged<bool> onDiscountApplyRuleChanged;
  final VoidCallback onSave;

  const _HeaderForm({
    this.section = DocumentEditorSection.all,
    required this.isEditing,
    required this.selectedDocTypeName,
    required this.selectedCustomerId,
    required this.selectedUserId,
    required this.selectedWarehouseId,
    required this.date,
    required this.dueDate,
    required this.stockDate,
    required this.numberCtrl,
    required this.internalNoteCtrl,
    required this.noteCtrl,
    required this.refDocCtrl,
    required this.discount,
    required this.discountType,
    required this.discountApplyRule,
    required this.errorMessage,
    required this.isLoading,
    required this.onSelectDocType,
    required this.onCustomerChanged,
    required this.onUserChanged,
    required this.onWarehouseChanged,
    required this.onDatePick,
    required this.onDueDatePick,
    required this.onStockDatePick,
    required this.onDiscountChanged,
    required this.onDiscountTypeChanged,
    required this.onDiscountApplyRuleChanged,
    required this.onSave,
  });

  String _fmt(DateTime dt) =>
      "${dt.day.toString().padLeft(2, '0')}-${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][dt.month - 1]}-${dt.year}";

  Widget _buildCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncCustomers = ref.watch(selectableCustomersProvider);
    final asyncUsers = ref.watch(allUsersProvider);
    final asyncWarehouses = ref.watch(allWarehousesProvider);
    final isSupplier =
        selectedDocTypeName?.toLowerCase().contains('purchase') == true ||
        selectedDocTypeName?.toLowerCase().contains('return') == true;

    final showInfo = section == DocumentEditorSection.all ||
        section == DocumentEditorSection.info;
    final showParties = section == DocumentEditorSection.all ||
        section == DocumentEditorSection.parties;
    final showFinancials = section == DocumentEditorSection.all ||
        section == DocumentEditorSection.financials;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── CARD 1: Document Info ──
        if (showInfo)
        _buildCard('Document Info', Icons.description_outlined, [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.list_alt),
                  label: Text(
                    selectedDocTypeName ?? "Select document type...",
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: onSelectDocType,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: numberCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).numberLabel,
                    prefixIcon: const Icon(Icons.tag),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _datePicker("Date", date, onDatePick, _fmt)),
              const SizedBox(width: 12),
              Expanded(
                child: _datePicker("Due Date", dueDate, onDueDatePick, _fmt),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _datePicker(
                  "Stock Date",
                  stockDate,
                  onStockDatePick,
                  _fmt,
                ),
              ),
            ],
          ),
        ]),
        if (showInfo) const SizedBox(height: 16),

        // ── CARD 2: Parties & Logistics ──
        if (showParties)
        _buildCard('Parties & Logistics', Icons.local_shipping_outlined, [
          // Customer / Supplier
          asyncCustomers.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(AppLocalizations.of(context).errorWithMessage(e.toString())),
            data: (customers) {
              final filtered = isSupplier
                  ? customers.where((c) => c.isSupplier).toList()
                  : customers.where((c) => c.isCustomer).toList();
              final isValid =
                  selectedCustomerId == null ||
                  filtered.any((c) => c.id == selectedCustomerId);
              return DropdownButtonFormField<int>(
                initialValue: isValid ? selectedCustomerId : null,
                decoration: InputDecoration(
                  labelText: isSupplier ? "Supplier *" : "Customer *",
                  prefixIcon: const Icon(Icons.business),
                  border: const OutlineInputBorder(),
                ),
                items: filtered
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: onCustomerChanged,
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // User
              Expanded(
                child: asyncUsers.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(AppLocalizations.of(context).errorWithMessage(e.toString())),
                  data: (users) {
                    final isValidUser =
                        selectedUserId == null ||
                        users.any((u) => u.id == selectedUserId);
                    return DropdownButtonFormField<int>(
                      initialValue: isValidUser ? selectedUserId : null,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).userRequired,
                        prefixIcon: const Icon(Icons.person),
                        border: const OutlineInputBorder(),
                      ),
                      items: users
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(u.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: onUserChanged,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Warehouse
              Expanded(
                child: asyncWarehouses.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(AppLocalizations.of(context).errorWithMessage(e.toString())),
                  data: (warehouses) {
                    final isValidWH =
                        selectedWarehouseId == null ||
                        warehouses.any((w) => w.id == selectedWarehouseId);
                    return DropdownButtonFormField<int>(
                      initialValue: isValidWH ? selectedWarehouseId : null,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).warehouseRequired,
                        prefixIcon: const Icon(Icons.warehouse_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      items: warehouses
                          .map(
                            (w) => DropdownMenuItem(
                              value: w.id,
                              child: Text(w.name),
                            ),
                          )
                          .toList(),
                      onChanged: onWarehouseChanged,
                    );
                  },
                ),
              ),
            ],
          ),
        ]),
        if (showParties) const SizedBox(height: 16),

        // ── CARD 3: Financials & Notes ──
        if (showFinancials)
        _buildCard('Financials & Notes', Icons.request_quote_outlined, [
          TextFormField(
            controller: refDocCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).referenceDocument,
              prefixIcon: const Icon(Icons.link),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: discount.toString(),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).posDiscount,
                    prefixIcon: const Icon(Icons.percent),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) => onDiscountChanged(double.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: discountType,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).typeLabel,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text("%")),
                    DropdownMenuItem(value: 1, child: Text(AppLocalizations.of(context).fixed)),
                  ],
                  onChanged: (v) => onDiscountTypeChanged(v ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Checkbox(
                      value: discountApplyRule,
                      onChanged: (v) => onDiscountApplyRuleChanged(v ?? true),
                    ),
                    const Expanded(
                      child: Text(
                        "Apply after tax",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: internalNoteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).internalNote,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).noteLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ]),
        if (showFinancials) const SizedBox(height: 16),

        if (errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.error),
            ),
            child: Text(
              errorMessage!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                icon: Icon(isEditing ? Icons.save : Icons.arrow_forward),
                label: Text(
                  isEditing ? "Save Header Changes" : "Create & Add Items",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                onPressed: onSave,
              ),
          ],
        ),
      ],
    );
  }

  Widget _datePicker(
    String label,
    DateTime value,
    VoidCallback onTap,
    String Function(DateTime) fmt,
  ) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(fmt(value)),
      ),
    );
  }
}

// --- ITEMS VIEW ---
// --- ITEMS VIEW ---
class _ItemsView extends ConsumerWidget {
  final int documentId;
  final String documentLocalId;
  final int companyId;
  final ValueChanged<double> onItemsChanged;
  final bool isPurchase;

  const _ItemsView({
    required this.documentId,
    required this.documentLocalId,
    required this.companyId,
    required this.onItemsChanged,
    this.isPurchase = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sym = ref.watch(currencySymbolProvider);
    final itemsArgs = LocalItemsArgs(
      docLocalId: documentLocalId,
      docServerId: documentId,
      companyId: companyId,
    );
    ref.listen<AsyncValue<List<DocumentItem>>>(
      localDocumentItemsProvider(itemsArgs),
      (previous, next) {
        // Only recompute + re-save the document total in response to an actual
        // item EDIT — never on the initial load. Recomputing on open flips a
        // synced document to pending_update and re-pushes it to the server,
        // which is exactly the "data changes as soon as I open it" bug. The
        // first emit is loading→data (previous is not AsyncData); a real edit is
        // data→data.
        if (previous is! AsyncData) return;
        next.whenData((items) {
          final subtotal = items.fold<double>(0, (s, i) => s + i.total);
          onItemsChanged(subtotal);
        });
      },
    );

    final asyncItems = ref.watch(localDocumentItemsProvider(itemsArgs));

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 24),
                    SizedBox(width: 12),
                    Text(
                      "Document Items",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(AppLocalizations.of(context).addProduct),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                  ),
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (_) => _AddItemDialog(
                        documentLocalId: documentLocalId,
                        companyId: companyId,
                        isPurchase: isPurchase,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(thickness: 1, color: theme.dividerColor),
            const SizedBox(height: 16),

            // ── Content ──
            asyncItems.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    "Error: $e",
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 64,
                            color: theme.disabledColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No items added yet.",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: theme.disabledColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Click 'Add Product' to get started.",
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Sum the ex-tax subtotals, not the raw `total` — that column
                // means ex-tax on checkout documents but tax-inclusive on
                // manual ones, which made this "Base Total" origin-dependent.
                final total = items.fold<double>(
                    0, (s, i) => s + i.priceBeforeTaxAfterDiscount);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- RESPONSIVE FLEX GRID HEADER ---
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              "Product",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Qty",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Price",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Item Disc.",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Tax",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Subtotal",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Total",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              "Actions",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- RESPONSIVE FLEX GRID ITEMS ---
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.3),
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: theme.dividerColor.withValues(alpha: 0.3),
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.productName ?? '-',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    item.quantity.toStringAsFixed(
                                      item.quantity % 1 == 0 ? 0 : 2,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    // Ex-tax, so Price → Subtotal → +Tax →
                                    // Total reads as one sum. `price`
                                    // (unit_price) is ex-tax on checkout rows
                                    // but tax-inclusive on manual ones.
                                    item.priceBeforeTax.toStringAsFixed(2),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    item.discount <= 0
                                        ? '—'
                                        : item.discountType == 0
                                            ? '${item.discount.toStringAsFixed(item.discount % 1 == 0 ? 0 : 2)}%'
                                            : '${item.discount.toStringAsFixed(2)} $sym',
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    item.taxRate > 0
                                        ? '${item.taxRate.toStringAsFixed(item.taxRate % 1 == 0 ? 0 : 1)}%'
                                        : '—',
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    item.priceBeforeTaxAfterDiscount
                                        .toStringAsFixed(2),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    item.totalWithTax.toStringAsFixed(2),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: context.successColor,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Tooltip(
                                        message: AppLocalizations.of(context).editItemAction,
                                        child: InkWell(
                                          onTap: () async {
                                            await showDialog(
                                              context: context,
                                              builder: (_) => _EditItemDialog(
                                                item: item,
                                                companyId: companyId,
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Icon(
                                              Icons.edit,
                                              color: theme.colorScheme.primary,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Tooltip(
                                        message: AppLocalizations.of(context).deleteItemAction,
                                        child: InkWell(
                                          onTap: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text(
                                                  "Delete Item",
                                                ),
                                                content: Text(
                                                  "Delete '${item.productName}'?",
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          ctx,
                                                        ).pop(false),
                                                    child: Text(AppLocalizations.of(context).actionCancel),
                                                  ),
                                                  ElevatedButton(
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor: theme
                                                              .colorScheme
                                                              .error,
                                                        ),
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          ctx,
                                                        ).pop(true),
                                                    child: Text(
                                                      "Delete",
                                                      style: TextStyle(
                                                        color: theme
                                                            .colorScheme
                                                            .onError,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true &&
                                                item.localId != null) {
                                              // Offline-first: remove locally
                                              // (the stream refreshes the list);
                                              // the sync queue DELETEs the server
                                              // row if it had one.
                                              await ref
                                                  .read(appDatabaseProvider)
                                                  .deleteDocumentItemLocal(
                                                      item.localId!);
                                              ref
                                                  .read(syncStateProvider
                                                      .notifier)
                                                  .sync()
                                                  .catchError((_) {});
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Icon(
                                              Icons.delete,
                                              color: theme.colorScheme.error,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),
                    Divider(
                      thickness: 1,
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "Items Base Total:",
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "${total.toStringAsFixed(2)} $sym",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.successColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- ADD ITEM DIALOG ---
class _AddItemDialog extends ConsumerStatefulWidget {
  final String documentLocalId;
  final int companyId;
  final bool isPurchase;
  const _AddItemDialog({
    required this.documentLocalId,
    required this.companyId,
    this.isPurchase = false,
  });

  @override
  ConsumerState<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends ConsumerState<_AddItemDialog> {
  int? _selectedProductId;
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController(); // price before tax
  final _discountCtrl = TextEditingController(text: '0');
  final _expDateCtrl = TextEditingController();
  int _discountType = 0;
  int? _selectedTaxId;
  double _selectedTaxRate = 0;
  DateTime? _expirationDate;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _expDateCtrl.dispose();
    super.dispose();
  }

  double get _pbt => double.tryParse(_priceCtrl.text) ?? 0;
  double get _price => _pbt * (1 + _selectedTaxRate / 100);
  double get _disc => double.tryParse(_discountCtrl.text) ?? 0;
  double get _qty => double.tryParse(_qtyCtrl.text) ?? 1;
  double get _discountTaxed =>
      _discountType == 0 ? _price * (_disc / 100) : _disc;
  double get _total => (_price - _discountTaxed) * _qty;

  Future<void> _submit() async {
    if (_selectedProductId == null) {
      setState(() => _errorMessage = "Please select a product.");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final db = ref.read(appDatabaseProvider);
      final itemLocalId = const Uuid().v4();
      // Offline-first: write the line item to local SQLite. The selected tax +
      // expiration travel on the row and SyncManager pushes them to
      // /DocumentItems(+Taxes/+ExpirationDates) on the next sync.
      await db.insertDocumentItemLocal(
            DocumentItemsTableCompanion(
              localId: Value(itemLocalId),
              documentId: Value(widget.documentLocalId),
              productId: Value(_selectedProductId!),
              quantity: Value(_qty),
              unitPrice: Value(_price),
              priceBeforeTax: Value(_pbt),
              discount: Value(_disc),
              discountType: Value(_discountType),
              total: Value(_total),
              taxAmount: Value((_price - _pbt) * _qty),
              taxId: Value(_selectedTaxId),
              taxRate: Value(_selectedTaxRate),
              expirationDate: Value(_expirationDate),
              syncStatus: const Value('pending_create'),
            ),
          );

      // Record the item discount as a manual_item discount line so the offline
      // sales "Discounts by source" report counts it (no-op on checkout docs).
      await db.syncManualItemDiscountLine(
        itemLocalId: itemLocalId,
        companyId: widget.companyId,
        productId: _selectedProductId!,
        value: _disc,
        valueType: _discountType,
        amount: _discountTaxed * _qty,
      );

      if (!mounted) return;
      if (widget.isPurchase && _selectedProductId != null) {
        await _maybeUpdateProductCost(
          productId: _selectedProductId!,
          purchasePrice: _pbt,
          quantity: _qty,
        );
      }
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to add item: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _maybeUpdateProductCost({
    required int productId,
    required double purchasePrice,
    required double quantity,
  }) async {
    try {
      final settings = ref.read(appSettingsProvider);
      if (settings[SettingKeys.autoUpdateCostPrice]?.toLowerCase() != 'true') return;

      final db = ref.read(appDatabaseProvider);
      final rows = await (db.select(db.productsTable)
            ..where((t) => t.id.equals(productId)))
          .get();
      if (rows.isEmpty) return;

      final product = rows.first;
      final double newCost;

      if (settings[SettingKeys.enableMovingAveragePrice]?.toLowerCase() == 'true') {
        // Weighted moving average: (OldQty * OldCost + NewQty * NewCost) / (OldQty + NewQty)
        // OldQty comes from the stock quantities already loaded for the selected warehouse.
        // Falls back to 0 on a cache miss, making NewCost = purchasePrice (mathematically correct
        // for an empty bin — nothing to weight against the new price).
        final oldQty = ref.read(stockQuantitiesProvider).value?[productId] ?? 0;
        newCost = oldQty > 0
            ? (oldQty * product.cost + quantity * purchasePrice) /
                (oldQty + quantity)
            : purchasePrice;
      } else {
        newCost = purchasePrice;
      }

      await (db.update(db.productsTable)
            ..where((t) => t.id.equals(productId)))
          .write(ProductsTableCompanion(
        cost: Value(newCost),
        lastPurchasePrice: Value(purchasePrice),
        lastModified: Value(DateTime.now().toUtc()),
      ));
    } catch (_) {
      // Non-fatal — best-effort local cache update.
      // The authoritative value is set by the backend on the next sync.
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncProducts = ref.watch(allProductsListProvider);
    final asyncTaxes = ref.watch(allTaxesProvider);
    final theme = Theme.of(context);
    final sym = ref.watch(currencySymbolProvider);
    String fmt(double v) => v.toStringAsFixed(2);

    return AlertDialog(
      title: Text(AppLocalizations.of(context).addProduct),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Product
              asyncProducts.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text(AppLocalizations.of(context).errorWithMessage(e.toString())),
                data: (products) => DropdownButtonFormField<int>(
                  initialValue: _selectedProductId,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).productRequired,
                    border: const OutlineInputBorder(),
                  ),
                  items: products
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            "${p.name}${p.code != null ? ' (${p.code})' : ''}",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    final p = products.firstWhere((prod) => prod.id == v);
                    setState(() {
                      _selectedProductId = v;
                      _priceCtrl.text = p.price.toStringAsFixed(2);
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Quantity + Price Before Tax
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).fieldQuantity,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).priceBeforeTax,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tax
              asyncTaxes.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (taxes) {
                  final enabled = taxes.where((t) => t.isEnabled).toList();
                  return DropdownButtonFormField<int>(
                    initialValue: _selectedTaxId,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).taxOptional,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Text(AppLocalizations.of(context).noneLabel),
                      ),
                      ...enabled.map(
                        (t) => DropdownMenuItem(
                          value: t.id,
                          child: Text("${t.name} (${t.rate}%)"),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      final rate = v == null
                          ? 0.0
                          : (taxes.firstWhere((t) => t.id == v).rate);
                      setState(() {
                        _selectedTaxId = v;
                        _selectedTaxRate = rate;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 12),

              // Discount + Type
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _discountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).itemDiscount,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _discountType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: 0, child: Text("%")),
                        DropdownMenuItem(value: 1, child: Text(AppLocalizations.of(context).fixed)),
                      ],
                      onChanged: (v) => setState(() => _discountType = v ?? 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Expiration date
              TextFormField(
                controller: _expDateCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).expirationDateOptional,
                  border: const OutlineInputBorder(),
                  suffixIcon: _expirationDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() {
                            _expirationDate = null;
                            _expDateCtrl.clear();
                          }),
                        )
                      : const Icon(Icons.calendar_today, size: 16),
                ),
                onTap: () async {
                  final picked = await showAppDatePicker(
                    context,
                    initialDate: _expirationDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _expirationDate = picked;
                      _expDateCtrl.text = picked
                          .toIso8601String()
                          .split('T')
                          .first;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Live preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _PreviewRow(
                      label: AppLocalizations.of(context).priceAfterTax,
                      value: "${fmt(_price)} $sym",
                    ),
                    const Divider(height: 8),
                    _PreviewRow(
                      label: AppLocalizations.of(context).totalLabel,
                      value: "${fmt(_total)} $sym",
                      bold: true,
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context).actionAdd),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: _submit,
          ),
      ],
    );
  }
}

// --- EDIT ITEM DIALOG (NOW SPLIT WITH TAXES) ---
class _EditItemDialog extends ConsumerStatefulWidget {
  final DocumentItem item;
  final int companyId;
  const _EditItemDialog({required this.item, required this.companyId});

  @override
  ConsumerState<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends ConsumerState<_EditItemDialog> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _expirationDateCtrl;
  DateTime? _expirationDate;
  late int _discountType;
  bool _isLoading = false;
  String? _errorMessage;

  int? _selectedTaxId;
  double _selectedTaxRate = 0;
  bool _taxResolved = false; // one-time taxId recovery from rate (older rows)

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
    _priceCtrl = TextEditingController(
      text: widget.item.priceBeforeTax.toString(),
    );
    _discountCtrl = TextEditingController(
      text: widget.item.discount.toString(),
    );
    _discountType = widget.item.discountType;
    _selectedTaxId = widget.item.taxId;
    _selectedTaxRate = widget.item.taxRate;
    _expirationDate = widget.item.expirationDate;
    _expirationDateCtrl = TextEditingController(
      text: _expirationDate?.toIso8601String().split('T').first ?? '',
    );
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _expirationDateCtrl.dispose();
    super.dispose();
  }

  double get _pbt =>
      double.tryParse(_priceCtrl.text) ?? widget.item.priceBeforeTax;
  double get _price => _pbt * (1 + _selectedTaxRate / 100);
  double get _qty => double.tryParse(_qtyCtrl.text) ?? widget.item.quantity;
  double get _disc =>
      double.tryParse(_discountCtrl.text) ?? widget.item.discount;
  double get _discTaxed => _discountType == 0 ? _price * (_disc / 100) : _disc;
  double get _total => (_price - _discTaxed) * _qty;

  Future<void> _submit() async {
    final localId = widget.item.localId;
    if (localId == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Offline-first: write the edit to local SQLite. The row carries the
      // single selected tax + expiration; SyncManager reconciles them with the
      // server's /DocumentItems(+Taxes/+ExpirationDates) on the next sync.
      final db = ref.read(appDatabaseProvider);
      await db.updateDocumentItemLocal(
            localId,
            DocumentItemsTableCompanion(
              quantity: Value(_qty),
              unitPrice: Value(_price),
              priceBeforeTax: Value(_pbt),
              discount: Value(_disc),
              discountType: Value(_discountType),
              total: Value(_total),
              taxAmount: Value((_price - _pbt) * _qty),
              taxId: Value(_selectedTaxId),
              taxRate: Value(_selectedTaxRate),
              expirationDate: Value(_expirationDate),
            ),
          );

      // Keep this item's manual_item discount line in step with the edit so the
      // offline "Discounts by source" report stays accurate (no-op on checkout
      // docs; clears the line when the discount is removed).
      await db.syncManualItemDiscountLine(
        itemLocalId: localId,
        companyId: widget.companyId,
        productId: widget.item.productId,
        value: _disc,
        valueType: _discountType,
        amount: _discTaxed * _qty,
      );
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = "Update failed: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sym = ref.watch(currencySymbolProvider);
    final allTaxesAsync = ref.watch(allTaxesProvider);

    // Live preview computation (single selected tax)
    final previewPrice = _price;
    final previewTotal = _total;
    String fmt(double v) => v.toStringAsFixed(2);

    return AlertDialog(
      title: Text(AppLocalizations.of(context).editDashTitle(widget.item.productName ?? '')),
      content: SizedBox(
        width: 800,
        height: 420,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT COLUMN (Item Details)
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).fieldQuantity,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).priceBeforeTax,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _discountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).posDiscount,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _discountType,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(value: 0, child: Text("%")),
                              DropdownMenuItem(value: 1, child: Text(AppLocalizations.of(context).fixed)),
                            ],
                            onChanged: (v) =>
                                setState(() => _discountType = v ?? 0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Expiration Date Field
                    TextFormField(
                      controller: _expirationDateCtrl,
                      readOnly: true,
                      onTap: () async {
                        final picked = await showAppDatePicker(
                          context,
                          initialDate: _expirationDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _expirationDate = picked;
                            _expirationDateCtrl.text = picked
                                .toIso8601String()
                                .split('T')
                                .first;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).expirationDate,
                        border: const OutlineInputBorder(),
                        suffixIcon: _expirationDate != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _expirationDate = null;
                                    _expirationDateCtrl.clear();
                                  });
                                },
                              )
                            : const Icon(Icons.calendar_today, size: 16),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Live preview
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          _PreviewRow(
                            label: AppLocalizations.of(context).priceAfterTax,
                            value: "${fmt(previewPrice)} $sym",
                          ),
                          const Divider(height: 8),
                          _PreviewRow(
                            label: AppLocalizations.of(context).totalLabel,
                            value: "${fmt(previewTotal)} $sym",
                            bold: true,
                          ),
                        ],
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 32),
            VerticalDivider(thickness: 1, color: theme.dividerColor),
            const SizedBox(width: 16),

            // RIGHT COLUMN (Item Tax)
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Item Tax",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  allTaxesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => Text(AppLocalizations.of(context).errorLoadingTaxes),
                    data: (taxes) {
                      // Recover the tax selection for older rows that stored a
                      // rate but no taxId (checkout used to not persist taxId) —
                      // match an available tax by rate, once.
                      if (!_taxResolved &&
                          _selectedTaxId == null &&
                          _selectedTaxRate > 0) {
                        _taxResolved = true;
                        final match = taxes
                            .where((t) =>
                                (t.rate.toDouble() - _selectedTaxRate).abs() <
                                0.01)
                            .firstOrNull;
                        if (match != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() => _selectedTaxId = match.id);
                            }
                          });
                        }
                      }
                      return DropdownButtonFormField<int?>(
                      initialValue: _selectedTaxId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).fieldTax,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(AppLocalizations.of(context).noTaxShort),
                        ),
                        ...taxes.map(
                          (t) => DropdownMenuItem<int?>(
                            value: t.id,
                            child: Text("${t.name} (${t.rate}%)"),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _selectedTaxId = v;
                        _selectedTaxRate = v == null
                            ? 0
                            : taxes
                                .firstWhere((t) => t.id == v)
                                .rate
                                .toDouble();
                      }),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _PreviewRow(
                      label: AppLocalizations.of(context).taxAmount,
                      value: "${fmt((_price - _pbt) * _qty)} $sym",
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: Text(AppLocalizations.of(context).updateItem),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: _submit,
          ),
      ],
    );
  }
}

class _PaidStatusChip extends StatelessWidget {
  final int paidStatus;
  final void Function(int) onChanged;

  const _PaidStatusChip({required this.paidStatus, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (paidStatus) {
      1 => ('Paid', Icons.check_circle, Colors.green),
      2 => ('Partial', Icons.timelapse, Colors.orange),
      _ => ('Unpaid', Icons.cancel, Colors.red),
    };

    final nextStatus = paidStatus == 1 ? 0 : 1;

    return ActionChip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: 0.1),
      onPressed: () => onChanged(nextStatus),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _PreviewRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 14 : 12,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

class _PaymentsView extends ConsumerWidget {
  final int documentId;
  final String? documentLocalId;
  final int companyId;
  final int userId;
  final double documentTotal;
  final int paidStatus;
  final void Function(int) onPaidStatusChanged;

  /// Called after a payment add/edit/delete recomputes the paid status from the
  /// live payments, so the editor's chip + the documents list reflect it. Unlike
  /// [onPaidStatusChanged] this does NOT re-persist (recompute already did) — it
  /// only syncs the in-memory state.
  final void Function(int) onPaidStatusRecomputed;

  const _PaymentsView({
    required this.documentId,
    required this.documentLocalId,
    required this.companyId,
    required this.userId,
    required this.documentTotal,
    required this.paidStatus,
    required this.onPaidStatusChanged,
    required this.onPaidStatusRecomputed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // documentLocalId is resolved by the editor right after the header saves.
    // Until then there is nothing to attach payments to.
    final localId = documentLocalId;
    if (localId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final asyncPayments = ref.watch(localDocumentPaymentsProvider(
      LocalPaymentsArgs(
        documentLocalId: localId,
        documentServerId: documentId > 0 ? documentId : null,
        companyId: companyId,
      ),
    ));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Applied Payments",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PaidStatusChip(
                  paidStatus: paidStatus,
                  onChanged: (nextStatus) async {
                    // Rule 3: guard against toggling to Unpaid when the
                    // document is already fully balanced — doing so clears all
                    // applied payment records.
                    final totalPaid = asyncPayments.value?.fold<double>(
                            0, (s, p) => s + p.amount.abs()) ??
                        0;
                    if (nextStatus == 0 && totalPaid >= documentTotal) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(AppLocalizations.of(context).markAsUnpaid),
                          content: const Text(
                            'This document has a complete payment balance.\n\n'
                            'Proceeding will permanently delete all associated '
                            'payment transactions. Are you sure?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(AppLocalizations.of(context).actionCancel),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: ctx.dangerColor),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(AppLocalizations.of(context).yesDeletePayments),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                    }
                    onPaidStatusChanged(nextStatus);
                  },
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.payment, size: 16),
                  label: Text(AppLocalizations.of(context).addPayment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                  ),
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (_) => _AddPaymentDialog(
                        documentServerId: documentId > 0 ? documentId : null,
                        documentLocalId: localId,
                        companyId: companyId,
                        userId: userId,
                      ),
                    );
                    // Reflect the new payment in the paid status (Unpaid →
                    // Partial → Paid) locally + in the documents list.
                    final s = await ref
                        .read(appDatabaseProvider)
                        .recomputePaidStatus(localId);
                    onPaidStatusRecomputed(s);
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        asyncPayments.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            "Error: $e",
            style: TextStyle(color: theme.colorScheme.error),
          ),
          data: (payments) {
            final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
            final remaining = documentTotal - totalPaid.abs();

            return Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Payment Summary Cards
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SummaryCard(
                        "Document Total",
                        documentTotal,
                        theme.colorScheme.primary,
                      ),
                      _SummaryCard(
                        "Total Paid",
                        totalPaid,
                        context.successColor,
                      ),
                      _SummaryCard(
                        "Remaining Balance",
                        remaining,
                        remaining > 0
                            ? context.warningColor
                            : theme.disabledColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (payments.isEmpty)
                    const Center(
                      child: Text(
                        "No payments added yet.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                          ),
                          columns: [
                            DataColumn(label: Text(AppLocalizations.of(context).idLabel)),
                            DataColumn(label: Text(AppLocalizations.of(context).statusLabel)),
                            DataColumn(label: Text(AppLocalizations.of(context).paymentType)),
                            DataColumn(label: Text(AppLocalizations.of(context).dateLabel)),
                            DataColumn(label: Text(AppLocalizations.of(context).amount), numeric: true),
                            DataColumn(label: Text(AppLocalizations.of(context).actions)),
                          ],
                          rows: payments.map((payment) {
                            final isLocked = payment.zReportId != null;
                            final isPending =
                                payment.syncStatus.startsWith('pending');
                            return DataRow(
                              cells: [
                                DataCell(Text(
                                  payment.id > 0 ? payment.id.toString() : '—',
                                )),
                                DataCell(
                                  Icon(
                                    isLocked
                                        ? Icons.lock
                                        : isPending
                                            ? Icons.sync
                                            : Icons.check_circle,
                                    color: isLocked
                                        ? theme.disabledColor
                                        : isPending
                                            ? theme.colorScheme.tertiary
                                            : context.successColor,
                                    size: 20,
                                  ),
                                ),
                                DataCell(
                                  Text(payment.paymentTypeName ?? "Unknown"),
                                ),
                                DataCell(
                                  Text(
                                    payment.date
                                        .toIso8601String()
                                        .split('T')
                                        .first,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    payment.amount.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: isLocked
                                              ? theme.disabledColor
                                              : theme.colorScheme.secondary,
                                          size: 18,
                                        ),
                                        onPressed: isLocked
                                            ? null
                                            : () async {
                                                await showDialog(
                                                  context: context,
                                                  builder: (_) =>
                                                      _EditPaymentDialog(
                                                        payment: payment,
                                                        companyId: companyId,
                                                      ),
                                                );
                                                final s = await ref
                                                    .read(appDatabaseProvider)
                                                    .recomputePaidStatus(
                                                        localId);
                                                onPaidStatusRecomputed(s);
                                              },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: isLocked
                                              ? theme.disabledColor
                                              : theme.colorScheme.error,
                                          size: 18,
                                        ),
                                        onPressed: isLocked
                                            ? null
                                            : () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                      "Delete Payment",
                                                    ),
                                                    content: const Text(
                                                      "Are you sure you want to delete this payment?",
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop(false),
                                                        child: const Text(
                                                          "Cancel",
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: theme
                                                              .colorScheme
                                                              .error,
                                                          foregroundColor: theme
                                                              .colorScheme
                                                              .onError,
                                                        ),
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop(true),
                                                        child: const Text(
                                                          "Delete",
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
                                                  final db = ref.read(
                                                      appDatabaseProvider);
                                                  final serverId =
                                                      payment.id > 0
                                                          ? payment.id
                                                          : null;
                                                  // Offline-first: remove from
                                                  // local SQLite first (the
                                                  // stream refreshes the list),
                                                  // then best-effort tell the
                                                  // server; the sync queue
                                                  // retries on failure.
                                                  await db.deleteLocalPayment(
                                                    localId: payment.localId!,
                                                    serverId: serverId,
                                                  );
                                                  if (serverId != null) {
                                                    try {
                                                      await createDio().delete(
                                                        '/Payments/Delete',
                                                        queryParameters: {
                                                          'id': serverId,
                                                          'companyId':
                                                              companyId,
                                                        },
                                                      );
                                                      await db
                                                          .hardDeletePayment(
                                                              payment.localId!);
                                                    } catch (e) {
                                                      debugPrint(
                                                          'Payment delete deferred to sync: $e');
                                                    }
                                                  }
                                                  // Removing a payment can drop
                                                  // the doc back to Partial /
                                                  // Unpaid.
                                                  final s = await db
                                                      .recomputePaidStatus(
                                                          localId);
                                                  onPaidStatusRecomputed(s);
                                                }
                                              },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  final String title;
  final double amount;
  final Color color;

  const _SummaryCard(this.title, this.amount, this.color);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sym = ref.watch(currencySymbolProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "${amount.toStringAsFixed(2)} $sym",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// --- ADD PAYMENT DIALOG ---
class _AddPaymentDialog extends ConsumerStatefulWidget {
  final int? documentServerId;
  final String documentLocalId;
  final int companyId;
  final int userId;
  const _AddPaymentDialog({
    required this.documentServerId,
    required this.documentLocalId,
    required this.companyId,
    required this.userId,
  });

  @override
  ConsumerState<_AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends ConsumerState<_AddPaymentDialog> {
  int? _selectedPaymentTypeId;
  final _amountCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedPaymentTypeId == null) {
      setState(() => _errorMessage = "Please select a payment type.");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    final db = ref.read(appDatabaseProvider);
    final localId = const Uuid().v4();

    // Offline-first: write the payment to local SQLite first so it shows
    // instantly and survives offline. SyncManager pushes 'pending_create' rows
    // to /Payments/Add on the next sync.
    final now = DateTime.now();
    await db.insertLocalPayment(PaymentsTableCompanion(
      localId: Value(localId),
      documentId: Value(widget.documentLocalId),
      paymentTypeId: Value(_selectedPaymentTypeId!),
      amount: Value(amount),
      userId: Value(widget.userId),
      date: Value(now),
      companyId: Value(widget.companyId),
      dateCreated: Value(now),
      syncStatus: const Value('pending_create'),
    ));

    // Best-effort immediate push so the row gets its server id while online.
    if (widget.documentServerId != null) {
      try {
        final res = await createDio().post(
          '/Payments/Add',
          queryParameters: {'companyId': widget.companyId},
          data: {
            'documentId': widget.documentServerId,
            'paymentTypeId': _selectedPaymentTypeId,
            'amount': amount,
            'userId': widget.userId,
          },
        );
        await db.markPaymentSynced(localId, _parsePaymentId(res.data));
      } on DioException catch (e) {
        // A real business rejection (e.g. overpayment) must not leave a ghost
        // local payment — roll it back and surface the server message.
        await db.hardDeletePayment(localId);
        if (!mounted) return;
        setState(() {
          _errorMessage = e.response?.data is Map
              ? (e.response?.data['message']?.toString() ??
                  e.response?.data.toString())
              : (e.response?.data?.toString() ?? "Failed to add payment.");
          _isLoading = false;
        });
        return;
      } catch (_) {
        // Network/offline error — keep the local row for the sync queue.
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// Pulls a created payment's server id out of the various shapes the API may
  /// return (bare int, {id}, or {data:{id}}).
  int? _parsePaymentId(dynamic body) {
    final data = body is Map && body.containsKey('data') ? body['data'] : body;
    if (data is Map) {
      return int.tryParse(
          data['id']?.toString() ?? data['Id']?.toString() ?? '');
    }
    if (data is num) return data.toInt();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final paymentTypesAsync = ref.watch(allPaymentTypesProvider);

    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(AppLocalizations.of(context).addPayment),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            paymentTypesAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text(AppLocalizations.of(context).errorWithMessage(e.toString())),
              data: (types) {
                if (_selectedPaymentTypeId == null && types.isNotEmpty) {
                  _selectedPaymentTypeId = types.first.id;
                }
                return DropdownButtonFormField<int>(
                  initialValue: _selectedPaymentTypeId,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).paymentType,
                    border: const OutlineInputBorder(),
                  ),
                  items: types
                      .map(
                        (t) =>
                            DropdownMenuItem(value: t.id, child: Text(t.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedPaymentTypeId = v),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).amount,
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  border: Border.all(color: theme.colorScheme.error),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.payment),
            label: Text(AppLocalizations.of(context).addPayment),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: _submit,
          ),
      ],
    );
  }
}

// --- EDIT PAYMENT DIALOG ---
class _EditPaymentDialog extends ConsumerStatefulWidget {
  final PaymentModel payment;
  final int companyId;
  const _EditPaymentDialog({required this.payment, required this.companyId});

  @override
  ConsumerState<_EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends ConsumerState<_EditPaymentDialog> {
  late final TextEditingController _amountCtrl;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.payment.amount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final amount =
        double.tryParse(_amountCtrl.text) ?? widget.payment.amount;
    final db = ref.read(appDatabaseProvider);
    final localId = widget.payment.localId;

    // Offline-first: persist the edit to local SQLite first, flagging it for a
    // server push, then best-effort PATCH while online.
    if (localId != null) {
      await db.editLocalPayment(
        localId: localId,
        amount: amount,
        currentSyncStatus: widget.payment.syncStatus,
      );
    }

    final serverId = widget.payment.id;
    if (serverId > 0) {
      try {
        await createDio().patch(
          '/Payments/Update',
          queryParameters: {'companyId': widget.companyId},
          data: {
            'id': serverId,
            'amount': amount,
            'date': widget.payment.date.toIso8601String(),
          },
        );
        if (localId != null) await db.markPaymentSynced(localId, serverId);
      } on DioException catch (e) {
        // Keep the local pending edit for the sync queue, but show why the
        // immediate push failed.
        if (!mounted) return;
        setState(() {
          _errorMessage = e.response?.data is Map
              ? (e.response?.data['message']?.toString() ??
                  e.response?.data.toString())
              : (e.response?.data?.toString() ?? "Update failed.");
          _isLoading = false;
        });
        if (localId == null) return; // nothing persisted locally — stay open
      } catch (_) {
        // Offline — local pending_update will sync later.
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(AppLocalizations.of(context).editPaymentTitle(widget.payment.id.toString())),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Payment Type: ${widget.payment.paymentTypeName ?? 'Unknown'}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).amount,
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  border: Border.all(color: theme.colorScheme.error),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: Text(AppLocalizations.of(context).actionSaveChanges),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: _submit,
          ),
      ],
    );
  }
}

/// Live discount breakdown for a document, ordered by application sequence.
/// Streams from the normalized `discount_lines` so it reflects edits instantly.
final documentDiscountLinesProvider = StreamProvider.autoDispose
    .family<List<DiscountLinesTableData>, String>((ref, documentLocalId) {
  final db = ref.watch(appDatabaseProvider);
  final q = db.select(db.discountLinesTable)
    ..where((t) => t.documentLocalId.equals(documentLocalId));
  // Sort in Dart to avoid widening the `drift` import (it's `show Value` only).
  return q.watch().map((rows) =>
      [...rows]..sort((a, b) => a.sequence.compareTo(b.sequence)));
});

/// Read-only card listing every discount applied to a document, with its source,
/// configured value, and resolved amount. The amounts are the figures stored at
/// sale time (already resolved under whatever discount-apply rule was in force),
/// so this never re-derives totals. Renders nothing when there are no discounts.
class _DiscountBreakdownCard extends ConsumerWidget {
  final String documentLocalId;
  const _DiscountBreakdownCard({required this.documentLocalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sym = ref.watch(currencySymbolProvider);
    final asyncLines = ref.watch(documentDiscountLinesProvider(documentLocalId));

    return asyncLines.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (all) {
        // Show every discount EXCEPT the per-item manual discount: that one
        // lives in document_items.discount/discountType and is already rendered
        // in the items table's "Item Disc." column, so repeating it here would
        // double-list it. Promotions and the order-level discounts (customer /
        // cart / loyalty) are NOT in the items table, so they belong here. Key
        // off the source — not `itemLocalId`, which is null on pulled-back rows.
        final lines =
            all.where((l) => l.source != DiscountSource.manualItem).toList();
        if (lines.isEmpty) return const SizedBox.shrink();
        final total = lines.fold<double>(0, (s, l) => s + l.amount);

        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sell_outlined, size: 24),
                      const SizedBox(width: 12),
                      Text(AppLocalizations.of(context).discountBreakdown,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...lines.map((l) {
                    final hint = discountLineHint(l, sym);
                    return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(discountLineLabel(l),
                                  style: theme.textTheme.bodyMedium),
                            ),
                            if (hint != null) ...[
                              Text(
                                hint,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(width: 14),
                            ],
                            Text(
                              '-${l.amount.toStringAsFixed(2)} $sym',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                  }),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(AppLocalizations.of(context).totalDiscounts,
                            style: theme.textTheme.titleSmall),
                      ),
                      Text(
                        '-${total.toStringAsFixed(2)} $sym',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
