import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/currency/country_model.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/api/customer_discount_models.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class CustomersScreen extends ConsumerWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const CustomersScreen({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCustomers = ref.watch(allCustomersProvider);
    final company = ref.watch(selectedCompanyProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).customersSuppliers),
          // Suppress the auto back-arrow — ManagementLayout controls navigation.
          automaticallyImplyLeading: false,
          leading: onMenuPressed != null
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: AppLocalizations.of(context).showNavigation,
                  onPressed: onMenuPressed,
                )
              : null,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: "Customers"),
              Tab(icon: Icon(Icons.store), text: "Suppliers"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: AppLocalizations.of(context).actionAdd,
              onPressed: company == null
                  ? null
                  : () => showDialog(
                        context: context,
                        builder: (_) =>
                            _CustomerFormDialog(companyId: company.id),
                      ),
            ),
          ],
        ),
        body: asyncCustomers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(AppLocalizations.of(context).errorLoadingCustomers(e.toString()))),
          data: (all) {
            if (company == null) {
              return Center(child: Text(AppLocalizations.of(context).noCompanySelectedShort));
            }
            final int companyId = company.id;

            final customers = all.where((c) => c.isCustomer).toList();
            final suppliers = all.where((c) => c.isSupplier).toList();

            return TabBarView(
              children: [
                _CustomerList(
                  items: customers,
                  companyId: companyId,
                  emptyMessage: "No customers found.",
                ),
                _CustomerList(
                  items: suppliers,
                  companyId: companyId,
                  emptyMessage: "No suppliers found.",
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// --- SHARED LIST ---
class _CustomerList extends ConsumerWidget {
  final List<Customer> items;
  final int companyId;
  final String emptyMessage;

  const _CustomerList({
    required this.items,
    required this.companyId,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, i) {
        final c = items[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                c.isSupplier ? cs.secondaryContainer : cs.primaryContainer,
            child: Text(
              c.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: c.isSupplier
                    ? cs.onSecondaryContainer
                    : cs.onPrimaryContainer,
              ),
            ),
          ),
          title: Text(c.name),
          subtitle: Text(
            [
              if (c.phoneNumber != null && c.phoneNumber!.isNotEmpty)
                c.phoneNumber!,
              if (c.email != null && c.email!.isNotEmpty) c.email!,
              if (c.city != null && c.city!.isNotEmpty) c.city!,
            ].join(' · '),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EnableToggle(
                key: ValueKey('toggle_${c.id}'),
                customer: c,
                companyId: companyId,
              ),
              IconButton(
                icon: Icon(Icons.edit, color: cs.primary),
                tooltip: AppLocalizations.of(context).actionEdit,
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) =>
                      _CustomerFormDialog(companyId: companyId, customer: c),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete, color: cs.error),
                tooltip: AppLocalizations.of(context).actionDelete,
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(AppLocalizations.of(context).actionDelete),
                      content: Text(
                        "Are you sure you want to delete ${c.name}?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(AppLocalizations.of(context).actionCancel),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.error,
                            foregroundColor: cs.onError,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(AppLocalizations.of(context).actionDelete),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await _delete(context, ref, c, companyId);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Customer c,
    int companyId,
  ) async {
    final db = ref.read(appDatabaseProvider);

    // Optimistic: mark pending_delete so it disappears from the stream
    // immediately (allCustomersProvider filters out pending_delete rows).
    await (db.update(db.customersTable)..where((t) => t.id.equals(c.id)))
        .write(const CustomersTableCompanion(
      syncStatus: Value('pending_delete'),
    ));

    try {
      await createDio().delete(
        '/Customer/DeleteCustomercommand',
        queryParameters: {'id': c.id, 'companyId': companyId},
      );
      // Hard-delete the row and any cached discounts.
      await (db.delete(db.customerDiscountsTable)
            ..where((t) => t.customerId.equals(c.id)))
          .go();
      await (db.delete(db.customersTable)..where((t) => t.id.equals(c.id)))
          .go();
      if (!context.mounted) return;
      showAppSnackbar(context, ref, 'Deleted successfully');
    } on DioException catch (e) {
      if (e.response == null) {
        // Offline: keep as pending_delete — SyncManager will push on next sync.
        if (!context.mounted) return;
        showAppSnackbar(context, ref, 'Will delete when connection is restored');
      } else {
        // Server rejection: revert pending_delete back to synced.
        await (db.update(db.customersTable)..where((t) => t.id.equals(c.id)))
            .write(const CustomersTableCompanion(
          syncStatus: Value('synced'),
        ));
        if (!context.mounted) return;
        showAppSnackbar(
          context, ref,
          e.response?.data?.toString() ?? 'Delete failed',
          isError: true,
        );
      }
    }
  }
}

// --- ENABLE / DISABLE TOGGLE ---
class _EnableToggle extends ConsumerStatefulWidget {
  final Customer customer;
  final int companyId;

  const _EnableToggle({
    super.key,
    required this.customer,
    required this.companyId,
  });

  @override
  ConsumerState<_EnableToggle> createState() => _EnableToggleState();
}

class _EnableToggleState extends ConsumerState<_EnableToggle> {
  bool _loading = false;

  Future<void> _toggle() async {
    setState(() => _loading = true);
    final db = ref.read(appDatabaseProvider);
    final newEnabled = !widget.customer.isEnabled;

    // Optimistic: write new isEnabled + pending_update so the stream reflects
    // the change immediately without waiting for the server round-trip.
    await (db.update(db.customersTable)
          ..where((t) => t.id.equals(widget.customer.id)))
        .write(CustomersTableCompanion(
      isEnabled: Value(newEnabled),
      syncStatus: const Value('pending_update'),
      lastModified: Value(DateTime.now().toUtc()),
    ));

    try {
      await createDio().patch(
        '/Customer/UpdateCustomercommand',
        queryParameters: {'companyId': widget.companyId},
        data: {'id': widget.customer.id, 'isEnabled': newEnabled},
      );
      // Flip to synced on success.
      await (db.update(db.customersTable)
            ..where((t) => t.id.equals(widget.customer.id)))
          .write(const CustomersTableCompanion(
        syncStatus: Value('synced'),
        syncError: Value(null),
      ));
    } on DioException catch (e) {
      if (e.response == null) {
        // Offline: keep pending_update — SyncManager will push on next sync.
      } else {
        // Server rejection: revert the optimistic write.
        await (db.update(db.customersTable)
              ..where((t) => t.id.equals(widget.customer.id)))
            .write(CustomersTableCompanion(
          isEnabled: Value(!newEnabled),
          syncStatus: const Value('synced'),
        ));
        if (mounted) {
          showAppSnackbar(
            context, ref,
            e.response?.data?.toString() ?? 'Update failed',
            isError: true,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Switch(
      value: widget.customer.isEnabled,
      onChanged: (_) => _toggle(),
    );
  }
}

// --- ADD / EDIT CUSTOMER DIALOG ---
class _CustomerFormDialog extends ConsumerStatefulWidget {
  final int companyId;
  final Customer? customer;

  const _CustomerFormDialog({required this.companyId, this.customer});

  @override
  ConsumerState<_CustomerFormDialog> createState() =>
      _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  late bool _isCustomer;
  late bool _isSupplier;
  late bool _isTaxExempt;

  List<Country> _countries = [];
  int? _selectedCountryId;
  bool _countriesLoading = true;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _taxNumberCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _postalCodeCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _dueDateCtrl;
  late final TextEditingController _streetNameCtrl;
  late final TextEditingController _additionalStreetCtrl;
  late final TextEditingController _buildingNumberCtrl;
  late final TextEditingController _plotIdCtrl;
  late final TextEditingController _citySubdivisionCtrl;

  int _discountType = 0;
  late final TextEditingController _discountUidCtrl;
  late final TextEditingController _discountValueCtrl;
  CustomerDiscountDto? _existingDiscount;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _codeCtrl = TextEditingController(text: c?.code ?? '');
    _taxNumberCtrl = TextEditingController(text: c?.taxNumber ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _postalCodeCtrl = TextEditingController(text: c?.postalCode ?? '');
    _cityCtrl = TextEditingController(text: c?.city ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _phoneCtrl = TextEditingController(text: c?.phoneNumber ?? '');
    _dueDateCtrl = TextEditingController(
      text: c?.dueDatePeriod?.toString() ?? '',
    );
    _streetNameCtrl = TextEditingController(text: c?.streetName ?? '');
    _additionalStreetCtrl = TextEditingController(
      text: c?.additionalStreetName ?? '',
    );
    _buildingNumberCtrl = TextEditingController(text: c?.buildingNumber ?? '');
    _plotIdCtrl = TextEditingController(text: c?.plotIdentification ?? '');
    _citySubdivisionCtrl = TextEditingController(
      text: c?.citySubdivisionName ?? '',
    );

    _isCustomer = c?.isCustomer ?? true;
    _isSupplier = c?.isSupplier ?? false;
    _isTaxExempt = c?.isTaxExempt ?? false;
    _selectedCountryId = (c?.countryId != null && c!.countryId! > 0)
        ? c.countryId
        : null;

    _discountUidCtrl = TextEditingController(text: '0');
    _discountValueCtrl = TextEditingController(text: '0');

    _loadCountries();
    if (_isEditing) _loadDiscount();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DISCOUNT LOADING — try API first; on offline fall back to local Drift cache
  // and cache any successful API response for future offline use.
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _loadDiscount() async {
    try {
      final discount = await ApiClient().getCustomerDiscount(
        widget.companyId,
        widget.customer!.id,
      );
      if (discount != null) {
        // Cache it locally so the edit form works offline next time.
        final db = ref.read(appDatabaseProvider);
        await db.into(db.customerDiscountsTable).insertOnConflictUpdate(
          CustomerDiscountsTableCompanion(
            id: Value(discount.id),
            companyId: Value(discount.companyId),
            customerId: Value(discount.customerId),
            type: Value(discount.type),
            uid: Value(discount.uid),
            value: Value(discount.value),
            lastModified: Value(DateTime.now().toUtc()),
            syncStatus: const Value('synced'),
            syncError: const Value(null),
          ),
        );
        if (mounted) {
          setState(() {
            _existingDiscount = discount;
            _discountType = discount.type;
            _discountUidCtrl.text = discount.uid.toString();
            _discountValueCtrl.text = discount.value.toString();
          });
        }
      }
    } on DioException catch (e) {
      if (e.response == null) {
        // Offline: read from local Drift cache.
        final db = ref.read(appDatabaseProvider);
        final row = await (db.select(db.customerDiscountsTable)
              ..where((t) => t.customerId.equals(widget.customer!.id))
              ..where((t) => t.companyId.equals(widget.companyId))
              ..where((t) => t.syncStatus.isNotIn(['pending_delete'])))
            .getSingleOrNull();
        if (row != null && mounted) {
          setState(() {
            _existingDiscount = CustomerDiscountDto(
              id: row.id,
              companyId: row.companyId,
              customerId: row.customerId,
              type: row.type,
              uid: row.uid,
              value: row.value,
            );
            _discountType = row.type;
            _discountUidCtrl.text = row.uid.toString();
            _discountValueCtrl.text = row.value.toString();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadCountries() async {
    try {
      // Offline-first: countries come from the local Drift cache (kept fresh by
      // SyncManager.pullCountries), so the dropdown works with no connection.
      // serverId → model id to match the customer's stored countryId FK.
      final db = ref.read(appDatabaseProvider);
      final rows = await db.select(db.countriesTable).get();
      final countries = rows
          .map((r) => Country(id: r.serverId ?? 0, name: r.name, code: r.code))
          .toList();
      setState(() {
        _countries = countries;
        if (_selectedCountryId != null &&
            !countries.any((c) => c.id == _selectedCountryId)) {
          _selectedCountryId = countries.isNotEmpty ? countries.first.id : null;
        }
        _selectedCountryId ??= countries.isNotEmpty ? countries.first.id : null;
        _countriesLoading = false;
      });
    } catch (_) {
      setState(() => _countriesLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _taxNumberCtrl.dispose();
    _addressCtrl.dispose();
    _postalCodeCtrl.dispose();
    _cityCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _dueDateCtrl.dispose();
    _streetNameCtrl.dispose();
    _additionalStreetCtrl.dispose();
    _buildingNumberCtrl.dispose();
    _plotIdCtrl.dispose();
    _citySubdivisionCtrl.dispose();
    _discountUidCtrl.dispose();
    _discountValueCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SUBMIT — optimistic Drift write, then try API.
  //   • e.response == null → offline: keep pending op, pop + toast "saved offline"
  //   • e.response != null → server rejection: revert Drift, show error in dialog
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();

    // A blank code must travel as null, not '': the server's per-company unique code
    // index skips NULLs but treats '' as a real code, so a second blank-coded customer
    // would collide with the first.
    final codeText = _codeCtrl.text.trim();
    final code = codeText.isEmpty ? null : codeText;

    final payload = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'code': code,
      'taxNumber': _taxNumberCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'postalCode': _postalCodeCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'countryId': _selectedCountryId ?? 0,
      'email': _emailCtrl.text.trim(),
      'phoneNumber': _phoneCtrl.text.trim(),
      'isEnabled': true,
      'isCustomer': _isCustomer,
      'isSupplier': _isSupplier,
      'isTaxExempt': _isTaxExempt,
      'dueDatePeriod': int.tryParse(_dueDateCtrl.text.trim()) ?? 0,
      'streetName': _streetNameCtrl.text.trim(),
      'additionalStreetName': _additionalStreetCtrl.text.trim(),
      'buildingNumber': _buildingNumberCtrl.text.trim(),
      'plotIdentification': _plotIdCtrl.text.trim(),
      'citySubdivisionName': _citySubdivisionCtrl.text.trim(),
      'dateUpdated': nowIso,
    };

    if (_isEditing) {
      // Remember current row so we can revert on server rejection.
      final oldRow = await (db.select(db.customersTable)
            ..where((t) => t.id.equals(widget.customer!.id)))
          .getSingleOrNull();

      // Optimistic write.
      await (db.update(db.customersTable)
            ..where((t) => t.id.equals(widget.customer!.id)))
          .write(CustomersTableCompanion(
        dateUpdated: Value(now),
        name: Value(_nameCtrl.text.trim()),
        code: Value(code),
        taxNumber: Value(_taxNumberCtrl.text.trim()),
        address: Value(_addressCtrl.text.trim()),
        postalCode: Value(_postalCodeCtrl.text.trim()),
        city: Value(_cityCtrl.text.trim()),
        countryId: Value(_selectedCountryId),
        email: Value(_emailCtrl.text.trim()),
        phoneNumber: Value(_phoneCtrl.text.trim()),
        isCustomer: Value(_isCustomer),
        isSupplier: Value(_isSupplier),
        isTaxExempt: Value(_isTaxExempt),
        dueDatePeriod: Value(int.tryParse(_dueDateCtrl.text.trim())),
        streetName: Value(_streetNameCtrl.text.trim()),
        additionalStreetName: Value(_additionalStreetCtrl.text.trim()),
        buildingNumber: Value(_buildingNumberCtrl.text.trim()),
        plotIdentification: Value(_plotIdCtrl.text.trim()),
        citySubdivisionName: Value(_citySubdivisionCtrl.text.trim()),
        lastModified: Value(now),
        syncStatus: const Value('pending_update'),
      ));

      try {
        payload['id'] = widget.customer!.id;
        await createDio().patch(
          '/Customer/UpdateCustomercommand',
          queryParameters: {'companyId': widget.companyId},
          data: payload,
        );
        await (db.update(db.customersTable)
              ..where((t) => t.id.equals(widget.customer!.id)))
            .write(const CustomersTableCompanion(
          syncStatus: Value('synced'),
          syncError: Value(null),
        ));
        await _saveDiscount(widget.customer!.id);

        if (!mounted) return;
        showAppSnackbar(context, ref, 'Customer updated');
        Navigator.of(context).pop();
      } on DioException catch (e) {
        if (e.response == null) {
          // Offline: leave pending_update, also save discount locally.
          await _saveDiscountLocal(widget.customer!.id);
          if (!mounted) return;
          showAppSnackbar(context, ref, 'Saved offline — will sync when connected');
          Navigator.of(context).pop();
        } else {
          // Server rejection: revert Drift to the original row.
          if (oldRow != null) await _revertCustomerRow(db, oldRow);
          if (!mounted) return;
          setState(() {
            _errorMessage = e.response?.data?.toString() ?? 'Operation failed.';
            _isLoading = false;
          });
        }
      }
    } else {
      // CREATE — assign a negative temp id until the server confirms.
      final tempId = -(DateTime.now().millisecondsSinceEpoch);

      await db.into(db.customersTable).insert(CustomersTableCompanion(
        id: Value(tempId),
        companyId: Value(widget.companyId),
        // Stamped locally so an offline-created customer keeps its true creation
        // time when the sync push later sends it to the server.
        dateCreated: Value(now),
        dateUpdated: Value(now),
        name: Value(_nameCtrl.text.trim()),
        code: Value(code),
        taxNumber: Value(_taxNumberCtrl.text.trim()),
        address: Value(_addressCtrl.text.trim()),
        postalCode: Value(_postalCodeCtrl.text.trim()),
        city: Value(_cityCtrl.text.trim()),
        countryId: Value(_selectedCountryId),
        email: Value(_emailCtrl.text.trim()),
        phoneNumber: Value(_phoneCtrl.text.trim()),
        isEnabled: const Value(true),
        isCustomer: Value(_isCustomer),
        isSupplier: Value(_isSupplier),
        isTaxExempt: Value(_isTaxExempt),
        dueDatePeriod: Value(int.tryParse(_dueDateCtrl.text.trim())),
        streetName: Value(_streetNameCtrl.text.trim()),
        additionalStreetName: Value(_additionalStreetCtrl.text.trim()),
        buildingNumber: Value(_buildingNumberCtrl.text.trim()),
        plotIdentification: Value(_plotIdCtrl.text.trim()),
        citySubdivisionName: Value(_citySubdivisionCtrl.text.trim()),
        lastModified: Value(now),
        syncStatus: const Value('pending_create'),
      ));

      try {
        payload['dateCreated'] = nowIso;
        final res = await createDio().post(
          '/Customer/AddCustomercommand',
          queryParameters: {'companyId': widget.companyId},
          data: payload,
        );

        // Parse the server-assigned id.
        final data = res.data;
        int newId = 0;
        if (data is int) {
          newId = data;
        } else if (data is Map) {
          newId = ((data['id'] ?? data['Id']) as num?)?.toInt() ?? 0;
        }

        // Replace temp row with the real server id.
        await db.transaction(() async {
          await (db.delete(db.customersTable)
                ..where((t) => t.id.equals(tempId)))
              .go();
          if (newId > 0) {
            await db.into(db.customersTable).insert(CustomersTableCompanion(
              id: Value(newId),
              companyId: Value(widget.companyId),
              dateCreated: Value(now),
              dateUpdated: Value(now),
              name: Value(_nameCtrl.text.trim()),
              code: Value(code),
              taxNumber: Value(_taxNumberCtrl.text.trim()),
              address: Value(_addressCtrl.text.trim()),
              postalCode: Value(_postalCodeCtrl.text.trim()),
              city: Value(_cityCtrl.text.trim()),
              countryId: Value(_selectedCountryId),
              email: Value(_emailCtrl.text.trim()),
              phoneNumber: Value(_phoneCtrl.text.trim()),
              isEnabled: const Value(true),
              isCustomer: Value(_isCustomer),
              isSupplier: Value(_isSupplier),
              isTaxExempt: Value(_isTaxExempt),
              dueDatePeriod: Value(int.tryParse(_dueDateCtrl.text.trim())),
              streetName: Value(_streetNameCtrl.text.trim()),
              additionalStreetName: Value(_additionalStreetCtrl.text.trim()),
              buildingNumber: Value(_buildingNumberCtrl.text.trim()),
              plotIdentification: Value(_plotIdCtrl.text.trim()),
              citySubdivisionName: Value(_citySubdivisionCtrl.text.trim()),
              lastModified: Value(now),
              syncStatus: const Value('synced'),
            ));
            // Also redirect any pending discounts from the temp id to the real id.
            await (db.update(db.customerDiscountsTable)
                  ..where((t) => t.customerId.equals(tempId)))
                .write(CustomerDiscountsTableCompanion(customerId: Value(newId)));
          }
        });

        if (newId > 0) await _saveDiscount(newId);

        if (!mounted) return;
        showAppSnackbar(context, ref, 'Customer added');
        Navigator.of(context).pop();
      } on DioException catch (e) {
        if (e.response == null) {
          // Offline: keep the optimistic row (pending_create), save discount locally.
          await _saveDiscountLocal(tempId);
          if (!mounted) return;
          showAppSnackbar(context, ref, 'Saved offline — will sync when connected');
          Navigator.of(context).pop();
        } else {
          // Server rejection: delete the temp row.
          await (db.delete(db.customersTable)
                ..where((t) => t.id.equals(tempId)))
              .go();
          if (!mounted) return;
          setState(() {
            _errorMessage = e.response?.data?.toString() ?? 'Operation failed.';
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _revertCustomerRow(AppDatabase db, CustomersTableData old) =>
      db.into(db.customersTable).insertOnConflictUpdate(
        CustomersTableCompanion(
          id: Value(old.id),
          companyId: Value(old.companyId),
          name: Value(old.name),
          code: Value(old.code),
          taxNumber: Value(old.taxNumber),
          address: Value(old.address),
          postalCode: Value(old.postalCode),
          city: Value(old.city),
          countryId: Value(old.countryId),
          email: Value(old.email),
          phoneNumber: Value(old.phoneNumber),
          isEnabled: Value(old.isEnabled),
          isCustomer: Value(old.isCustomer),
          isSupplier: Value(old.isSupplier),
          dueDatePeriod: Value(old.dueDatePeriod),
          streetName: Value(old.streetName),
          additionalStreetName: Value(old.additionalStreetName),
          buildingNumber: Value(old.buildingNumber),
          plotIdentification: Value(old.plotIdentification),
          citySubdivisionName: Value(old.citySubdivisionName),
          isTaxExempt: Value(old.isTaxExempt),
          lastModified: Value(old.lastModified),
          syncStatus: Value(old.syncStatus),
          syncError: Value(old.syncError),
        ),
      );

  // ──────────────────────────────────────────────────────────────────────────
  // DISCOUNT HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  /// Online-first discount save: tries the API and caches the result in Drift.
  /// Falls back to [_saveDiscountLocal] when offline.
  Future<void> _saveDiscount(int customerId) async {
    final value = double.tryParse(_discountValueCtrl.text) ?? 0;
    final uid = int.tryParse(_discountUidCtrl.text) ?? 0;
    final db = ref.read(appDatabaseProvider);

    try {
      if (value <= 0) {
        if (_existingDiscount != null && _existingDiscount!.id > 0) {
          await ApiClient().deleteCustomerDiscount(
            widget.companyId, _existingDiscount!.id,
          );
          await (db.delete(db.customerDiscountsTable)
                ..where((t) => t.id.equals(_existingDiscount!.id)))
              .go();
        }
        return;
      }

      if (_existingDiscount == null) {
        final result = await ApiClient().createCustomerDiscount(
          widget.companyId,
          CreateCustomerDiscountRequest(
            customerId: customerId,
            type: _discountType,
            uid: uid,
            value: value,
          ),
        );
        await db.into(db.customerDiscountsTable).insertOnConflictUpdate(
          CustomerDiscountsTableCompanion(
            id: Value(result.id),
            companyId: Value(result.companyId),
            customerId: Value(result.customerId),
            type: Value(result.type),
            uid: Value(result.uid),
            value: Value(result.value),
            lastModified: Value(DateTime.now().toUtc()),
            syncStatus: const Value('synced'),
            syncError: const Value(null),
          ),
        );
      } else {
        await ApiClient().updateCustomerDiscount(
          widget.companyId,
          UpdateCustomerDiscountRequest(
            id: _existingDiscount!.id,
            type: _discountType,
            value: value,
          ),
        );
        await (db.update(db.customerDiscountsTable)
              ..where((t) => t.id.equals(_existingDiscount!.id)))
            .write(CustomerDiscountsTableCompanion(
          type: Value(_discountType),
          uid: Value(uid),
          value: Value(value),
          lastModified: Value(DateTime.now().toUtc()),
          syncStatus: const Value('synced'),
          syncError: const Value(null),
        ));
      }
    } catch (_) {
      // ApiClient wraps even DioExceptions in a generic Exception, so we can't
      // tell offline from a server error here — and silently dropping the
      // discount is exactly the "it didn't save" bug. Persist it locally with a
      // pending sync status either way, so it survives and the SyncManager
      // (pushPendingCustomerDiscountOps) reconciles it with the server later.
      await _saveDiscountLocal(customerId);
    }
  }

  /// Offline discount save: writes directly to Drift with a pending syncStatus.
  ///
  /// Looks up the customer's existing local discount by customerId rather than
  /// trusting [_existingDiscount] — so a re-save updates the one row instead of
  /// stacking a duplicate pending_create the server then rejects ("customer
  /// already has a discount"). The offline-first half of the "doesn't save" fix.
  Future<void> _saveDiscountLocal(int customerId) async {
    final value = double.tryParse(_discountValueCtrl.text) ?? 0;
    final uid = int.tryParse(_discountUidCtrl.text) ?? 0;
    final db = ref.read(appDatabaseProvider);

    final existing = await (db.select(db.customerDiscountsTable)
          ..where((t) => t.customerId.equals(customerId))
          ..where((t) => t.companyId.equals(widget.companyId))
          ..where((t) => t.syncStatus.isNotIn(['pending_delete'])))
        .getSingleOrNull();

    if (value <= 0) {
      if (existing != null) {
        if (existing.id < 0) {
          // Temp row that never reached the server — just drop it.
          await (db.delete(db.customerDiscountsTable)
                ..where((t) => t.id.equals(existing.id)))
              .go();
        } else {
          await (db.update(db.customerDiscountsTable)
                ..where((t) => t.id.equals(existing.id)))
              .write(const CustomerDiscountsTableCompanion(
            syncStatus: Value('pending_delete'),
          ));
        }
      }
      return;
    }

    if (existing == null) {
      final tempId = -(DateTime.now().millisecondsSinceEpoch);
      await db.into(db.customerDiscountsTable).insert(
        CustomerDiscountsTableCompanion(
          id: Value(tempId),
          companyId: Value(widget.companyId),
          customerId: Value(customerId),
          type: Value(_discountType),
          uid: Value(uid),
          value: Value(value),
          lastModified: Value(DateTime.now().toUtc()),
          syncStatus: const Value('pending_create'),
        ),
      );
    } else {
      // A not-yet-synced create stays a create (just with the new values).
      final nextStatus = existing.syncStatus == 'pending_create'
          ? 'pending_create'
          : 'pending_update';
      await (db.update(db.customerDiscountsTable)
            ..where((t) => t.id.equals(existing.id)))
          .write(CustomerDiscountsTableCompanion(
        type: Value(_discountType),
        uid: Value(uid),
        value: Value(value),
        lastModified: Value(DateTime.now().toUtc()),
        syncStatus: Value(nextStatus),
      ));
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sym = ref.watch(currencySymbolProvider);

    return AlertDialog(
      title: Text(_isEditing ? "Edit Customer" : "Add Customer / Supplier"),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _isCustomer,
                      onChanged: (v) => setState(() => _isCustomer = v ?? true),
                    ),
                    Text(AppLocalizations.of(context).customerLabel),
                    const SizedBox(width: 16),
                    Checkbox(
                      value: _isSupplier,
                      onChanged: (v) =>
                          setState(() => _isSupplier = v ?? false),
                    ),
                    Text(AppLocalizations.of(context).fieldSupplier),
                    const SizedBox(width: 16),
                    Checkbox(
                      value: _isTaxExempt,
                      onChanged: (v) =>
                          setState(() => _isTaxExempt = v ?? false),
                    ),
                    Text(AppLocalizations.of(context).taxExempt),
                  ],
                ),
                const SizedBox(height: 8),
                _sectionLabel(context, "General"),
                _row([
                  _field(
                    _nameCtrl,
                    "Name *",
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? "Required" : null,
                  ),
                  _field(_codeCtrl, "Code"),
                ]),
                _row([
                  _field(_taxNumberCtrl, "Tax Number"),
                  _field(_emailCtrl, "Email"),
                ]),
                _row([
                  _field(_phoneCtrl, "Phone Number"),
                  _field(
                    _dueDateCtrl,
                    "Due Date Period (days)",
                    keyboardType: TextInputType.number,
                  ),
                ]),
                const SizedBox(height: 12),
                _sectionLabel(context, "Address"),
                _row([
                  _field(_streetNameCtrl, "Street Name"),
                  _field(_buildingNumberCtrl, "Building Number"),
                ]),
                _row([
                  _field(_additionalStreetCtrl, "Additional Street"),
                  _field(_plotIdCtrl, "Plot Identification"),
                ]),
                _row([
                  _field(_cityCtrl, "City"),
                  _field(_postalCodeCtrl, "Postal Code"),
                ]),
                _field(_citySubdivisionCtrl, "District"),
                const SizedBox(height: 12),
                _sectionLabel(context, "Customer Discount"),
                _row([
                  DropdownButtonFormField<int>(
                    initialValue: _discountType,
                    // Fill the field width so a longer label (e.g. "Fixed
                    // Amount (MAD)") ellipsizes instead of overflowing the Row.
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).discountType,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 0,
                        child: Text(AppLocalizations.of(context).percentageSign),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text(AppLocalizations.of(context).fixedAmountSymLabel(sym)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _discountType = v!),
                  ),
                  _field(
                    _discountValueCtrl,
                    "Discount Value",
                    keyboardType: TextInputType.number,
                    // Show the unit so a fixed amount reads in the company
                    // currency (MAD) instead of a bare number, and % for percent.
                    suffixText: _discountType == 1 ? sym : '%',
                  ),
                ]),
                const SizedBox(height: 12),
                _countriesLoading
                    ? const LinearProgressIndicator()
                    : _countries.isEmpty
                    ? Text(
                        "No countries available.",
                        style: TextStyle(color: cs.error),
                      )
                    : DropdownButtonFormField<int>(
                        initialValue: _selectedCountryId,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).country,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: _countries
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCountryId = v),
                      ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ],
              ],
            ),
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
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: Text(_isEditing ? "Update" : "Save"),
            onPressed: _submit,
          ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Widget _row(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children:
          children
              .expand((w) => [Expanded(child: w), const SizedBox(width: 12)])
              .toList()
            ..removeLast(),
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    String? suffixText,
  }) => TextFormField(
    controller: ctrl,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      suffixText: suffixText,
    ),
    validator: validator,
    keyboardType: keyboardType,
  );
}
