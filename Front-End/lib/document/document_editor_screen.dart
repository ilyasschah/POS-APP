import 'dart:math' as math;

import 'package:pos_app/core/ilyass_form.dart';
import 'package:pos_app/core/responsive.dart';
import 'package:flutter/material.dart';
import 'package:pos_app/core/ilyass_dropdown.dart';
import 'package:pos_app/core/app_date_format.dart';
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
import 'package:pos_app/document/document_type_constants.dart';
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
import 'package:pos_app/session/session_provider.dart';
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
    final fixedTaxIds = {
      for (final t in await db.select(db.taxesTable).get())
        if (t.isFixed) t.id,
    };
    return rows
        .map((r) => DocumentItem.fromDrift(
              r,
              isCheckoutDoc: isCheckoutDoc,
              companyId: args.companyId,
              documentId: args.docServerId,
              product: pById[r.productId],
              fixedTaxIds: fixedTaxIds,
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

/// The Payments tab's index in the editor's tab bar. Named because callers
/// that arrive from the money side — a session's payment list, a receipt —
/// want that tab, and a bare `5` in their code would silently point at the
/// wrong tab the day one is inserted.
const int kDocumentEditorPaymentsTab = 5;

// --- ENTRY POINT ---
Future<void> showDocumentEditor(
  BuildContext context,
  WidgetRef ref, {
  Document? existingDocument,
  int initialTabIndex = 0,
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
    builder: (_) => _DocumentEditorDialog(
      existingDocument: existingDocument,
      initialTabIndex: initialTabIndex,
    ),
  );
  container.invalidate(allDocumentsProvider);
}

// --- MAIN EDITOR DIALOG ---
class _DocumentEditorDialog extends ConsumerStatefulWidget {
  final Document? existingDocument;

  /// Which tab to land on. Defaults to the header — a caller opening the
  /// editor to settle money passes [kDocumentEditorPaymentsTab] instead.
  final int initialTabIndex;

  const _DocumentEditorDialog({
    this.existingDocument,
    this.initialTabIndex = 0,
  });

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
    final l = AppLocalizations.of(context);
    if (_selectedDocTypeId == null) {
      setState(() => _errorMessage = l.selectDocumentTypeError);
      return;
    }
    if (_selectedCustomerId == null) {
      setState(() => _errorMessage = l.selectCustomerSupplierError);
      return;
    }
    if (_selectedUserId == null) {
      setState(() => _errorMessage = l.selectUserError);
      return;
    }
    if (_selectedWarehouseId == null) {
      setState(() => _errorMessage = l.selectWarehouseError);
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
            _errorMessage = l.couldNotResolveLocalDocument;
            _isLoading = false;
          });
          return;
        }

        await db.updateManualDocumentHeader(
          localId,
          DocumentsTableCompanion(
            // '' — NOT null — is how this codebase spells "no number yet"
            // (Document.fromJson and every `number?.isNotEmpty` check agree).
            // Null would be pushed as JSON null, and CreateDocumentRequest.Number
            // is `required string`: the API rejects it with a 400, which parks a
            // still-pending_create row at sync_failed with no retry path.
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
          showAppSnackbar(context, ref, l.documentSaved);
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
    final l = AppLocalizations.of(context);

    // The controller is empty for a document the server has not numbered yet;
    // the title still needs something to render after the dash.
    final titleNumber =
        _numberCtrl.text.trim().isEmpty ? '—' : _numberCtrl.text.trim();
    String title = l.newDocument;
    if (_isEditing) {
      title = l.editDocumentNumbered(titleNumber);
    } else if (_headerSaved) {
      title = l.documentNumbered(titleNumber);
    }

    final companyId = ref.read(selectedCompanyProvider)?.id ?? 0;
    final headerReady = _headerSaved && _savedDocumentLocalId != null;

    // One factory for the header form — each header tab renders a single card
    // via [section]; the fields/handlers stay identical across all three.
    _HeaderForm headerForm(DocumentEditorSection section) => _HeaderForm(
          section: section,
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
        );

    Widget headerTab(DocumentEditorSection section) =>
        IlyassTabBody(children: [headerForm(section)]);

    // Shown on the items/discount/payments tabs until the header is saved. It
    // used to be a bare sentence; it now says why, and offers the way back.
    Widget needsHeader() => Builder(
          builder: (tabContext) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 44,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.saveHeaderFirstHint(
                        _isEditing ? l.saveHeaderChanges : l.createAndAddItems,
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: Text(l.documentInfo),
                      onPressed: () =>
                          DefaultTabController.of(tabContext).animateTo(0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    final List<Widget> dialogTabs = [
      Tab(text: l.documentInfo),
      Tab(text: l.partiesLogistics),
      Tab(text: l.financialsNotes),
      Tab(text: l.documentItems),
      Tab(text: l.discountBreakdown),
      Tab(text: l.paymentsTab),
    ];

    /// The first three tabs are the header form; the footer's save button
    /// belongs to them and to nothing after.
    const headerTabCount = 3;

    final List<Widget> dialogTabViews = [
      headerTab(DocumentEditorSection.info),
      headerTab(DocumentEditorSection.parties),
      headerTab(DocumentEditorSection.financials),
      // Document Items
      headerReady
          ? IlyassTabBody(
              children: [
                _ItemsView(
                  documentId: _savedDocumentId ?? 0,
                  documentLocalId: _savedDocumentLocalId!,
                  companyId: companyId,
                  documentTypeId: _selectedDocTypeId,
                  warehouseId: _selectedWarehouseId,
                  onItemsChanged: _syncDocumentTotal,
                  isPurchase: _selectedDocTypeName
                          ?.toLowerCase()
                          .contains('purchase') ==
                      true,
                ),
              ],
            )
          : needsHeader(),
      // Discount Breakdown — label → amount rows, capped so an amount never
      // ends up a monitor's width away from the discount it belongs to.
      headerReady
          ? IlyassTabBody(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _DiscountBreakdownCard(
                      documentLocalId: _savedDocumentLocalId!,
                    ),
                  ),
                ),
              ],
            )
          : needsHeader(),
      // Payments
      (headerReady && _savedDocumentId != null && _savedDocument != null)
          ? IlyassTabBody(
              children: [
                _PaymentsView(
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
              ],
            )
          : needsHeader(),
    ];

    // The header's own action. It lives in the footer — always on screen,
    // never scrolled away — but only while a header tab is the one open.
    Widget saveHeaderButton() => _isLoading
        ? const SizedBox(
            width: 160,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        : ElevatedButton.icon(
            icon: Icon(
              _headerSaved ? Icons.save : Icons.arrow_forward,
              size: 18,
            ),
            label: Text(
              _headerSaved ? l.saveHeaderChanges : l.createAndAddItems,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: _saveOrUpdateHeader,
          );

    // Sized to the screen it is on rather than 90% of it, which on a desktop
    // monitor was a wall of empty field and on a 768-high till ran off the
    // bottom once the title and footer were added. ~200dp is the dialog's own
    // chrome (title, footer, inset) that the body has to leave room for.
    final dialogWidth = context.dialogWidth(1200);
    final bodyHeight = math.max(
      360.0,
      math.min(820.0, context.screenHeight - 200),
    );
    final danger = context.dangerColor;

    return DefaultTabController(
      length: dialogTabs.length,
      // Clamped: a caller asking for a tab that no longer exists lands on the
      // header rather than throwing.
      initialIndex:
          widget.initialTabIndex.clamp(0, dialogTabs.length - 1),
      child: AlertDialog(
        contentPadding: EdgeInsets.zero,
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
        actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            // Which KIND of document this is, on every tab — the title alone
            // is only a number.
            if (_selectedDocTypeName != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _selectedDocTypeName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: dialogWidth,
            height: bodyHeight,
            child: Column(
              children: [
                TabBar(
                  // Six tabs — scroll rather than cram them edge to edge.
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  indicatorColor: theme.colorScheme.primary,
                  labelStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: dialogTabs,
                ),
                Expanded(child: TabBarView(children: dialogTabViews)),
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: danger.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 18, color: danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // The footer's top edge. The actions below sit outside the
                // scrolling tab body, so this line is what makes them read as
                // a fixed bar instead of buttons floating under the form.
                const Divider(height: 1),
              ],
            ),
          ),
        ),
        actions: [
          Builder(
            builder: (actionsContext) {
              final tabs = DefaultTabController.of(actionsContext);
              return AnimatedBuilder(
                animation: tabs,
                builder: (_, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(96, 48),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.actionClose),
                    ),
                    if (tabs.index < headerTabCount) ...[
                      const SizedBox(width: 12),
                      saveHeaderButton(),
                    ],
                  ],
                ),
              );
            },
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

  // The save button and the error banner moved to the dialog's footer, which
  // is on screen whichever header tab is open — so they are no longer here.
  const _HeaderForm({
    this.section = DocumentEditorSection.all,
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
  });

  /// 🚨 Was `03-Sep-2026`, built from a localized month table and ignoring
  /// `Application.DateFormat` entirely. A document DATE is a calendar day, not
  /// an instant, so it takes no timezone conversion — see `AppDateFormat.day`.
  String _fmt(AppDateFormat dates, DateTime dt) => dates.day(dt);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    String fmt(DateTime dt) => _fmt(ref.watch(appDateFormatProvider), dt);
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

    InputDecoration deco(String label, {IconData? icon}) =>
        ilyassFieldDecoration(
          context,
          label: label,
          prefixIcon: icon == null ? null : Icon(icon),
        );

    Widget failed(Object e) => Text(l.errorWithMessage(e.toString()));

    final sections = <Widget>[
      // ── Document Info ──
      if (showInfo)
        IlyassFormSection(
          icon: Icons.description_outlined,
          title: l.documentInfo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The type is picked in its own dialog but shown as a FIELD — as
              // a stray button it read as an action, not as the document's
              // most important property. The number shares its row.
              IlyassFieldRow(
                flexes: const [3, 2],
                children: [
                  _tapField(
                    context,
                    label: l.documentType,
                    value: selectedDocTypeName,
                    icon: Icons.list_alt,
                    suffixIcon: Icons.arrow_drop_down,
                    onTap: onSelectDocType,
                  ),
                  TextFormField(
                    controller: numberCtrl,
                    decoration: deco(l.numberLabel, icon: Icons.tag),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              IlyassFieldRow(
                minFieldWidth: 160,
                children: [
                  _tapField(
                    context,
                    label: l.dateLabel,
                    value: fmt(date),
                    suffixIcon: Icons.calendar_today,
                    onTap: onDatePick,
                  ),
                  _tapField(
                    context,
                    label: l.dueDate,
                    value: fmt(dueDate),
                    suffixIcon: Icons.calendar_today,
                    onTap: onDueDatePick,
                  ),
                  _tapField(
                    context,
                    label: l.stockDate,
                    value: fmt(stockDate),
                    suffixIcon: Icons.calendar_today,
                    onTap: onStockDatePick,
                  ),
                ],
              ),
            ],
          ),
        ),

      // ── Parties & Logistics ──
      if (showParties)
        IlyassFormSection(
          icon: Icons.local_shipping_outlined,
          title: l.partiesLogistics,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer / Supplier — the party the document is FOR, so it
              // gets the whole row.
              asyncCustomers.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => failed(e),
                data: (customers) {
                  final filtered = isSupplier
                      ? customers.where((c) => c.isSupplier).toList()
                      : customers.where((c) => c.isCustomer).toList();
                  final isValid =
                      selectedCustomerId == null ||
                      filtered.any((c) => c.id == selectedCustomerId);
                  return IlyassDropdown<int>(
                    value: isValid ? selectedCustomerId : null,
                    label: isSupplier ? l.supplierRequired : l.customerRequired,
                    prefixIcon: Icons.business,
                    items: [
                      for (final c in filtered)
                        IlyassDropdownItem(value: c.id, label: c.name),
                    ],
                    onChanged: onCustomerChanged,
                  );
                },
              ),
              const SizedBox(height: 16),
              IlyassFieldRow(
                children: [
                  // User
                  asyncUsers.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => failed(e),
                    data: (users) {
                      final isValidUser =
                          selectedUserId == null ||
                          users.any((u) => u.id == selectedUserId);
                      return IlyassDropdown<int>(
                        value: isValidUser ? selectedUserId : null,
                        label: l.userRequired,
                        prefixIcon: Icons.person,
                        items: [
                          for (final u in users)
                            IlyassDropdownItem(value: u.id, label: u.displayName),
                        ],
                        onChanged: onUserChanged,
                      );
                    },
                  ),
                  // Warehouse
                  asyncWarehouses.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => failed(e),
                    data: (warehouses) {
                      final isValidWH =
                          selectedWarehouseId == null ||
                          warehouses.any((w) => w.id == selectedWarehouseId);
                      return IlyassDropdown<int>(
                        value: isValidWH ? selectedWarehouseId : null,
                        label: l.warehouseRequired,
                        prefixIcon: Icons.warehouse_outlined,
                        items: [
                          for (final w in warehouses)
                            IlyassDropdownItem(value: w.id, label: w.name),
                        ],
                        onChanged: onWarehouseChanged,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

      // ── Financials & Notes ──
      if (showFinancials)
        IlyassFormSection(
          icon: Icons.request_quote_outlined,
          title: l.financialsNotes,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: refDocCtrl,
                decoration: deco(l.referenceDocument, icon: Icons.link),
              ),
              const SizedBox(height: 16),
              IlyassFieldRow(
                flexes: const [3, 2],
                children: [
                  // The amount and whether it is a % or a fixed sum read as
                  // one value, so they share the wider column.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          initialValue: discount.toString(),
                          decoration: deco(l.posDiscount, icon: Icons.percent),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (v) =>
                              onDiscountChanged(double.tryParse(v) ?? 0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: IlyassDropdown<int>(
                          value: discountType,
                          label: l.typeLabel,
                          items: [
                            const IlyassDropdownItem(value: 0, label: '%'),
                            IlyassDropdownItem(value: 1, label: l.fixed),
                          ],
                          onChanged: (v) => onDiscountTypeChanged(v ?? 0),
                        ),
                      ),
                    ],
                  ),
                  // Was a bare checkbox trailing the row; now the same option
                  // card as every other on/off setting in the editors.
                  IlyassOptionSwitch(
                    title: l.applyAfterTax,
                    value: discountApplyRule,
                    onChanged: onDiscountApplyRuleChanged,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              IlyassFieldRow(
                children: [
                  TextFormField(
                    controller: internalNoteCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: deco(l.internalNote),
                  ),
                  TextFormField(
                    controller: noteCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: deco(l.noteLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          sections[i],
        ],
      ],
    );
  }

  /// A read-only field that opens a picker — the document type, the dates.
  /// Drawn exactly like a text field, so the form reads as one grid.
  Widget _tapField(
    BuildContext context, {
    required String label,
    required String? value,
    required VoidCallback onTap,
    IconData? icon,
    IconData? suffixIcon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: ilyassFieldDecoration(
          context,
          label: label,
          prefixIcon: icon == null ? null : Icon(icon),
          suffixIcon: suffixIcon == null ? null : Icon(suffixIcon, size: 18),
        ),
        child: Text(
          value ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// --- ITEMS VIEW ---
class _ItemsView extends ConsumerWidget {
  final int documentId;
  final String documentLocalId;
  final int companyId;
  final ValueChanged<double> onItemsChanged;
  final bool isPurchase;

  /// What a new line is added to — an inventory count records the stock it
  /// was counted against, and needs both to look that stock up.
  final int? documentTypeId;
  final int? warehouseId;

  const _ItemsView({
    required this.documentId,
    required this.documentLocalId,
    required this.companyId,
    required this.onItemsChanged,
    this.isPurchase = false,
    this.documentTypeId,
    this.warehouseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);
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
    final count = asyncItems.value?.length ?? 0;

    return IlyassFormSection(
      icon: Icons.inventory_2_outlined,
      title: l.documentItems,
      trailing: count == 0 ? null : IlyassCountBadge(count),
      actions: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.add, size: 18),
          label: Text(l.addProduct),
          onPressed: () async {
            await showDialog(
              context: context,
              builder: (_) => _AddItemDialog(
                documentLocalId: documentLocalId,
                companyId: companyId,
                isPurchase: isPurchase,
                documentTypeId: documentTypeId,
                warehouseId: warehouseId,
              ),
            );
          },
        ),
      ],
      child: asyncItems.when(
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
              l.errorWithMessage('$e'),
              style: TextStyle(color: cs.error),
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 48, color: cs.outline),
                  const SizedBox(height: 12),
                  Text(
                    l.noItemsAddedYet,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.clickAddProductToStart,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          // Sum the ex-tax subtotals, not the raw `total` — that column means
          // ex-tax on checkout documents but tax-inclusive on manual ones,
          // which made this "Base Total" origin-dependent.
          final total = items.fold<double>(
              0, (s, i) => s + i.priceBeforeTaxAfterDiscount);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ItemsTable(items: items, sym: sym, companyId: companyId),
              const SizedBox(height: 14),
              // The figure the table adds up to, set apart as the section's
              // conclusion rather than one more row under it.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.successColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 3,
                      child: Text(
                        l.itemsBaseTotal,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
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
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The document's lines. Eight columns: below [_minWidth] they stop being
/// readable, so the table scrolls sideways instead of squeezing — tables are
/// the one thing that scrolls rather than wraps (Ilyass Style §3).
class _ItemsTable extends ConsumerWidget {
  const _ItemsTable({
    required this.items,
    required this.sym,
    required this.companyId,
  });

  final List<DocumentItem> items;
  final String sym;
  final int companyId;

  static const double _minWidth = 760;

  /// Two 36×36 icon buttons and the gap between them — fixed, never flexed.
  static const double _actionsWidth = 88;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);

    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: cs.onSurfaceVariant,
    );
    // Money and counts end-aligned: a column of totals is read by its last
    // digits.
    Widget head(String text, {int flex = 1, bool numeric = true}) => Expanded(
          flex: flex,
          child: Text(
            text,
            textAlign: numeric ? TextAlign.end : TextAlign.start,
            overflow: TextOverflow.ellipsis,
            style: headerStyle,
          ),
        );
    Widget figure(String text, {TextStyle? style}) => Expanded(
          child: Text(text, textAlign: TextAlign.end, style: style),
        );

    Widget row(DocumentItem item) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    item.productName ?? '-',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                figure(
                  item.quantity.toStringAsFixed(
                    item.quantity % 1 == 0 ? 0 : 2,
                  ),
                ),
                // Ex-tax, so Price → Subtotal → +Tax → Total reads as one sum.
                // `price` (unit_price) is ex-tax on checkout rows but
                // tax-inclusive on manual ones.
                figure(item.priceBeforeTax.toStringAsFixed(2)),
                figure(
                  item.discount <= 0
                      ? '—'
                      : item.discountType == 0
                          ? '${item.discount.toStringAsFixed(item.discount % 1 == 0 ? 0 : 2)}%'
                          : '${item.discount.toStringAsFixed(2)} $sym',
                ),
                figure(item.taxRateLabel ?? '—'),
                figure(item.priceBeforeTaxAfterDiscount.toStringAsFixed(2)),
                figure(
                  item.totalWithTax.toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: context.successColor,
                  ),
                ),
                SizedBox(
                  width: _actionsWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: l.editItemAction,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        icon: Icon(Icons.edit_outlined, size: 20, color: cs.primary),
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => _EditItemDialog(
                              item: item,
                              companyId: companyId,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: l.deleteItemAction,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l.deleteItem),
                              content: Text(
                                l.deleteItemConfirm(item.productName ?? ''),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text(l.actionCancel),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cs.error,
                                  ),
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: Text(
                                    l.actionDelete,
                                    style: TextStyle(color: cs.onError),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && item.localId != null) {
                            // Offline-first: remove locally (the stream
                            // refreshes the list); the sync queue DELETEs the
                            // server row if it had one.
                            await ref
                                .read(appDatabaseProvider)
                                .deleteDocumentItemLocal(item.localId!);
                            ref
                                .read(syncStateProvider.notifier)
                                .sync()
                                .catchError((_) {});
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    final table = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: cs.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                head(l.productLabel, flex: 3, numeric: false),
                head(l.qtyShort),
                head(l.priceLabel),
                head(l.itemDiscShort),
                head(l.fieldTax),
                head(l.subtotal),
                head(l.totalLabel),
                SizedBox(
                  width: _actionsWidth,
                  child: Text(
                    l.actionsLabel,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: headerStyle,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: cs.outlineVariant),
            row(items[i]),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _minWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: _minWidth, child: table),
        );
      },
    );
  }
}

// --- ADD ITEM DIALOG ---
class _AddItemDialog extends ConsumerStatefulWidget {
  final String documentLocalId;
  final int companyId;
  final bool isPurchase;
  final int? documentTypeId;
  final int? warehouseId;
  const _AddItemDialog({
    required this.documentLocalId,
    required this.companyId,
    this.isPurchase = false,
    this.documentTypeId,
    this.warehouseId,
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
  bool _selectedTaxIsFixed = false;
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
  double get _disc => double.tryParse(_discountCtrl.text) ?? 0;
  double get _qty => double.tryParse(_qtyCtrl.text) ?? 1;
  ({double unitPrice, double unitDiscount, double total}) get _money =>
      editorLineMoney(
        priceBeforeTax: _pbt,
        quantity: _qty,
        discount: _disc,
        discountType: _discountType,
        taxRate: _selectedTaxRate,
        taxIsFixed: _selectedTaxIsFixed,
      );
  double get _price => _money.unitPrice;
  double get _discountTaxed => _money.unitDiscount;
  double get _total => _money.total;

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_selectedProductId == null) {
      setState(() => _errorMessage = l.selectProductError);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final db = ref.read(appDatabaseProvider);
      final itemLocalId = const Uuid().v4();
      // An inventory count records the stock it was counted against, read NOW
      // — before anything else moves it — so the Stock Moves history can show
      // the variance (counted − expected) instead of taking the whole count
      // for goods received. Every other line leaves it null: it expects exactly
      // what it carries.
      final expected = widget.documentTypeId == DocumentTypes.inventoryCount &&
              widget.warehouseId != null
          ? await db.stockOnHandInProductUnit(
              productId: _selectedProductId!,
              warehouseId: widget.warehouseId!,
            )
          : null;
      // Offline-first: write the line item to local SQLite. The selected tax +
      // expiration travel on the row and SyncManager pushes them to
      // /DocumentItems(+Taxes/+ExpirationDates) on the next sync.
      await db.insertDocumentItemLocal(
            DocumentItemsTableCompanion(
              localId: Value(itemLocalId),
              documentId: Value(widget.documentLocalId),
              productId: Value(_selectedProductId!),
              quantity: Value(_qty),
              expectedQuantity: Value(expected),
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
        _errorMessage = l.failedToAddItem('$e');
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
                data: (products) => IlyassDropdown<int>(
                  value: _selectedProductId,
                  label: AppLocalizations.of(context).productRequired,
                  items: [
                    for (final p in products)
                      IlyassDropdownItem(
                        value: p.id,
                        label:
                            "${p.name}${p.code != null ? ' (${p.code})' : ''}",
                      ),
                  ],
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
                  return IlyassDropdown<int?>(
                    value: _selectedTaxId,
                    label: AppLocalizations.of(context).taxOptional,
                    items: [
                      IlyassDropdownItem<int?>(
                        value: null,
                        label: AppLocalizations.of(context).noneLabel,
                      ),
                      for (final t in enabled)
                        IlyassDropdownItem<int?>(
                          value: t.id,
                          label: "${t.name} (${t.rate}${t.isFixed ? '' : '%'})",
                        ),
                    ],
                    onChanged: (v) {
                      final tax =
                          v == null ? null : taxes.firstWhere((t) => t.id == v);
                      setState(() {
                        _selectedTaxId = v;
                        _selectedTaxRate = tax?.rate ?? 0.0;
                        _selectedTaxIsFixed = tax?.isFixed ?? false;
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
                    child: IlyassDropdown<int>(
                      value: _discountType,
                      items: [
                        const IlyassDropdownItem(value: 0, label: '%'),
                        IlyassDropdownItem(
                          value: 1,
                          label: AppLocalizations.of(context).fixed,
                        ),
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
  bool _selectedTaxIsFixed = false;
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
    _selectedTaxIsFixed = widget.item.taxIsFixed;
    _expirationDate = widget.item.expirationDate;
    // Display only — the field is `readOnly` and the real value lives in
    // `_expirationDate`, so this can follow the company's date format without
    // anything having to parse it back.
    _expirationDateCtrl = TextEditingController(
      text: _expirationDate == null
          ? ''
          : ref.read(appDateFormatProvider).day(_expirationDate!),
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
  double get _qty => double.tryParse(_qtyCtrl.text) ?? widget.item.quantity;
  double get _disc =>
      double.tryParse(_discountCtrl.text) ?? widget.item.discount;
  ({double unitPrice, double unitDiscount, double total}) get _money =>
      editorLineMoney(
        priceBeforeTax: _pbt,
        quantity: _qty,
        discount: _disc,
        discountType: _discountType,
        taxRate: _selectedTaxRate,
        taxIsFixed: _selectedTaxIsFixed,
      );
  double get _price => _money.unitPrice;
  double get _discTaxed => _money.unitDiscount;
  double get _total => _money.total;

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
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
        _errorMessage = l.updateFailedWithMessage('$e');
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
                          child: IlyassDropdown<int>(
                            value: _discountType,
                            items: [
                              const IlyassDropdownItem(value: 0, label: '%'),
                              IlyassDropdownItem(
                                value: 1,
                                label: AppLocalizations.of(context).fixed,
                              ),
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
                            _expirationDateCtrl.text =
                                ref.read(appDateFormatProvider).day(picked);
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
                  Text(
                    AppLocalizations.of(context).itemTax,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
                        // Percentage taxes only: the rate these rows carry was
                        // derived as tax over base, which a fixed tax never is.
                        final match = taxes
                            .where((t) =>
                                !t.isFixed &&
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
                      return IlyassDropdown<int?>(
                      value: _selectedTaxId,
                      label: AppLocalizations.of(context).fieldTax,
                      dense: true,
                      items: [
                        IlyassDropdownItem<int?>(
                          value: null,
                          label: AppLocalizations.of(context).noTaxShort,
                        ),
                        for (final t in taxes)
                          IlyassDropdownItem<int?>(
                            value: t.id,
                            label: "${t.name} (${t.rate}${t.isFixed ? '' : '%'})",
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        final tax = v == null
                            ? null
                            : taxes.firstWhere((t) => t.id == v);
                        _selectedTaxId = v;
                        _selectedTaxRate = tax?.rate.toDouble() ?? 0;
                        _selectedTaxIsFixed = tax?.isFixed ?? false;
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
    final l = AppLocalizations.of(context);
    // The theme's status palette rather than raw Colors.* — those did not
    // adapt to the dark theme.
    final (label, icon, color) = switch (paidStatus) {
      1 => (l.paid, Icons.check_circle, context.successColor),
      2 => (l.partial, Icons.timelapse, context.warningColor),
      _ => (l.unpaid, Icons.cancel, context.dangerColor),
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
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);

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
    final count = asyncPayments.value?.length ?? 0;

    return IlyassFormSection(
      icon: Icons.payments_outlined,
      title: l.appliedPayments,
      trailing: count == 0 ? null : IlyassCountBadge(count),
      actions: [
        _PaidStatusChip(
          paidStatus: paidStatus,
          onChanged: (nextStatus) async {
            // Rule 3: guard against toggling to Unpaid when the document is
            // already fully balanced — doing so clears all applied payment
            // records.
            final totalPaid = asyncPayments.value?.fold<double>(
                    0, (s, p) => s + p.amount.abs()) ??
                0;
            if (nextStatus == 0 && totalPaid >= documentTotal) {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.markAsUnpaid),
                  content: Text(l.deleteAllPaymentsWarning),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l.actionCancel),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: ctx.dangerColor),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.yesDeletePayments),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
            }
            onPaidStatusChanged(nextStatus);
          },
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.payment, size: 18),
          label: Text(l.addPayment),
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
            // Reflect the new payment in the paid status (Unpaid → Partial →
            // Paid) locally + in the documents list.
            final s =
                await ref.read(appDatabaseProvider).recomputePaidStatus(localId);
            onPaidStatusRecomputed(s);
          },
        ),
      ],
      child: asyncPayments.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (e, _) => Text(
          l.errorWithMessage('$e'),
          style: TextStyle(color: cs.error),
        ),
        data: (payments) {
          final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
          final remaining = documentTotal - totalPaid.abs();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Payment summary. Three across while they fit, stacked below
              // that — the old fixed Row of three overflowed a 7" tablet.
              IlyassTileGrid(
                minTileWidth: 170,
                maxPerRow: 3,
                children: [
                  _SummaryCard(l.documentTotal, documentTotal, cs.primary),
                  _SummaryCard(l.totalPaid, totalPaid, context.successColor),
                  _SummaryCard(
                    l.remainingBalance,
                    remaining,
                    remaining > 0 ? context.warningColor : theme.disabledColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 44, color: cs.outline),
                      const SizedBox(height: 8),
                      Text(
                        l.noPaymentsAddedYet,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              else
                // A table scrolls sideways rather than overflowing a narrow
                // screen — its columns never shrink below their content.
                LayoutBuilder(
                  builder: (context, constraints) => Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          // The border's own 2px, so the row fills it exactly.
                          minWidth: constraints.maxWidth - 2,
                        ),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            cs.surfaceContainerHighest,
                          ),
                          columns: [
                            DataColumn(label: Text(l.idLabel)),
                            DataColumn(label: Text(l.statusLabel)),
                            DataColumn(label: Text(l.paymentType)),
                            DataColumn(label: Text(l.dateLabel)),
                            DataColumn(label: Text(l.amount), numeric: true),
                            DataColumn(label: Text(l.actions)),
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
                                            ? cs.tertiary
                                            : context.successColor,
                                    size: 20,
                                  ),
                                ),
                                DataCell(
                                  Text(payment.paymentTypeName ?? l.unknownLabel),
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
                                          Icons.edit_outlined,
                                          color: isLocked
                                              ? theme.disabledColor
                                              : cs.secondary,
                                          size: 20,
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
                                        tooltip: l.deletePayment,
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: isLocked
                                              ? theme.disabledColor
                                              : cs.error,
                                          size: 20,
                                        ),
                                        onPressed: isLocked
                                            ? null
                                            : () async {
                                                final confirm =
                                                    await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: Text(l.deletePayment),
                                                    content: Text(
                                                      l.deletePaymentConfirm,
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop(false),
                                                        child:
                                                            Text(l.actionCancel),
                                                      ),
                                                      ElevatedButton(
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              cs.error,
                                                          foregroundColor:
                                                              cs.onError,
                                                        ),
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop(true),
                                                        child:
                                                            Text(l.actionDelete),
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
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One figure of the payment summary: a quiet caption over a tinted amount.
class _SummaryCard extends ConsumerWidget {
  final String title;
  final double amount;
  final Color color;

  const _SummaryCard(this.title, this.amount, this.color);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sym = ref.watch(currencySymbolProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          // Shrinks a long total instead of wrapping it mid-number.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              "${amount.toStringAsFixed(2)} $sym",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
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
    final l = AppLocalizations.of(context);
    if (_selectedPaymentTypeId == null) {
      setState(() => _errorMessage = l.selectPaymentTypeError);
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
      // The session TAKING the money, which is not necessarily the one that
      // raised the document: settling last night's unpaid invoice puts cash in
      // today's drawer, and today's drawer is what gets counted.
      sessionLocalId:
          Value(ref.read(activeSessionProvider).value?.localId),
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
              : (e.response?.data?.toString() ?? l.failedToAddPayment);
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
                return IlyassDropdown<int>(
                  value: _selectedPaymentTypeId,
                  label: AppLocalizations.of(context).paymentType,
                  items: [
                    for (final t in types)
                      IlyassDropdownItem(value: t.id, label: t.name),
                  ],
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
    final l = AppLocalizations.of(context);
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
              : (e.response?.data?.toString() ?? l.updateFailedShort);
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
              AppLocalizations.of(context).paymentTypeNamed(
                widget.payment.paymentTypeName ??
                    AppLocalizations.of(context).unknownLabel,
              ),
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
/// so this never re-derives totals. Shows an empty state when there are none.
class _DiscountBreakdownCard extends ConsumerWidget {
  final String documentLocalId;
  const _DiscountBreakdownCard({required this.documentLocalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final loc = AppLocalizations.of(context);
    final sym = ref.watch(currencySymbolProvider);
    final asyncLines = ref.watch(documentDiscountLinesProvider(documentLocalId));

    return IlyassFormSection(
      icon: Icons.sell_outlined,
      title: loc.discountBreakdown,
      child: asyncLines.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(
          loc.errorWithMessage('$e'),
          style: TextStyle(color: cs.error),
        ),
        data: (all) {
          // Show every discount EXCEPT the per-item manual discount: that one
          // lives in document_items.discount/discountType and is already
          // rendered in the items table's "Item Disc." column, so repeating it
          // here would double-list it. Promotions and the order-level discounts
          // (customer / cart / loyalty) are NOT in the items table, so they
          // belong here. Key off the source — not `itemLocalId`, which is null
          // on pulled-back rows.
          final lines =
              all.where((l) => l.source != DiscountSource.manualItem).toList();

          // The tab used to render NOTHING here — a blank page that read as a
          // broken screen rather than as "this document has no discounts".
          if (lines.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.sell_outlined, size: 40, color: cs.outline),
                  const SizedBox(height: 8),
                  Text(
                    loc.noDocumentDiscounts,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }
          final total = lines.fold<double>(0, (s, l) => s + l.amount);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...lines.map((l) {
                final hint = discountLineHint(l, sym);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          discountLineLabel(l),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (hint != null) ...[
                        Text(
                          hint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
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
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loc.totalDiscounts,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    '-${total.toStringAsFixed(2)} $sym',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
