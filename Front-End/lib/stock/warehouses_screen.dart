import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/stock/stock_model.dart';
import 'package:pos_app/stock/warehouse_model.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

// --- SCREEN ---
class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncWarehouses = ref.watch(allWarehousesProvider);
    final company = ref.watch(selectedCompanyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Warehouses"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: () => ref.invalidate(allWarehousesProvider),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Add Warehouse",
            onPressed: company == null
                ? null
                : () async {
                    await showDialog(
                      context: context,
                      builder: (_) =>
                          _WarehouseFormDialog(companyId: company.id),
                    );
                    ref.invalidate(allWarehousesProvider);
                  },
          ),
        ],
      ),
      body: asyncWarehouses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error loading warehouses: $e")),
        data: (warehouses) {
          if (company == null) {
            return const Center(child: Text("No company selected."));
          }
          final int companyId = company.id;

          if (warehouses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("No warehouses found.",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Add First Warehouse"),
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        builder: (_) =>
                            _WarehouseFormDialog(companyId: companyId),
                      );
                      ref.invalidate(allWarehousesProvider);
                    },
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: warehouses.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final w = warehouses[i];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Icon(Icons.warehouse, color: Colors.white),
                ),
                title: Text(w.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("ID: ${w.id}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueGrey),
                      tooltip: "Edit",
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          builder: (_) => _WarehouseFormDialog(
                            companyId: companyId,
                            warehouse: w,
                          ),
                        );
                        ref.invalidate(allWarehousesProvider);
                      },
                    ),
                    // Delete
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: "Delete",
                      onPressed: () => _handleDelete(
                          context, ref, w, companyId, warehouses),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Delete flow ─────────────────────────────────────────────────────────
  // A warehouse can't just be dropped if it still holds stock (the DB FK would
  // reject it, and silently losing inventory is worse). So we first look up the
  // warehouse's stock and, when there is any, ask the user to either REVOKE it
  // (delete the stock rows) or MOVE it to another warehouse — then delete.

  Future<void> _handleDelete(BuildContext context, WidgetRef ref, Warehouse w,
      int companyId, List<Warehouse> all) async {
    final repo = ref.read(warehouseRepositoryProvider);

    // Offline-first: the stock check reads the local Drift cache.
    List<StockItem> stocks;
    try {
      stocks = await repo.stocksFor(w.id);
    } catch (e) {
      if (context.mounted) _snack(context, ref, 'Could not check stock: $e', error: true);
      return;
    }
    if (!context.mounted) return;

    // No stock → simple confirm + delete.
    if (stocks.isEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Delete Warehouse"),
          content: Text("Are you sure you want to delete '${w.name}'?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm == true && context.mounted) {
        await _run(context, ref, () => repo.delete(w.id), "Warehouse deleted");
      }
      return;
    }

    // Has stock → revoke or move.
    final others = all.where((x) => x.id != w.id).toList();
    if (!context.mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Warehouse has stock"),
        content: Text(
          "'${w.name}' still holds ${stocks.length} stock item"
          "${stocks.length == 1 ? '' : 's'}. What should happen to it before "
          "the warehouse is deleted?",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'revoke'),
            child: const Text("Revoke stock",
                style: TextStyle(color: Colors.red)),
          ),
          if (others.isNotEmpty)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'move'),
              child: const Text("Move stock"),
            ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;

    if (action == 'revoke') {
      await _run(context, ref, () => repo.delete(w.id, stockAction: 'revoke'),
          "Warehouse and its stock deleted");
    } else if (action == 'move') {
      final target = await showDialog<Warehouse>(
        context: context,
        builder: (_) => _MoveTargetDialog(targets: others),
      );
      if (target == null || !context.mounted) return;
      await _run(
          context,
          ref,
          () => repo.delete(w.id,
              stockAction: 'move', targetWarehouseId: target.id),
          "Stock moved to ${target.name}; warehouse deleted");
    }
  }

  /// Runs a local (offline-first) [op] and reports the outcome. The Drift stream
  /// behind `allWarehousesProvider` refreshes the list on its own — no manual
  /// invalidate, no network round-trip.
  Future<void> _run(BuildContext context, WidgetRef ref,
      Future<void> Function() op, String successMsg) async {
    try {
      await op();
      if (context.mounted) _snack(context, ref, successMsg);
    } catch (e) {
      if (context.mounted) _snack(context, ref, e.toString(), error: true);
    }
  }

  void _snack(BuildContext context, WidgetRef ref, String msg,
      {bool error = false}) {
    showAppSnackbar(context, ref, msg, isError: error);
  }
}

/// Lists the other warehouses so the user can pick where the stock moves to.
class _MoveTargetDialog extends StatelessWidget {
  final List<Warehouse> targets;
  const _MoveTargetDialog({required this.targets});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Move stock to…"),
      content: SizedBox(
        width: 320,
        child: ListView(
          shrinkWrap: true,
          children: targets
              .map((w) => ListTile(
                    leading: const Icon(Icons.warehouse, color: Colors.indigo),
                    title: Text(w.name),
                    onTap: () => Navigator.pop(context, w),
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
      ],
    );
  }
}

// --- ADD / EDIT DIALOG ---
class _WarehouseFormDialog extends ConsumerStatefulWidget {
  final int companyId;
  final Warehouse? warehouse;

  const _WarehouseFormDialog({
    required this.companyId,
    this.warehouse,
  });

  @override
  ConsumerState<_WarehouseFormDialog> createState() =>
      _WarehouseFormDialogState();
}

class _WarehouseFormDialogState extends ConsumerState<_WarehouseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditing => widget.warehouse != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.warehouse?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(warehouseRepositoryProvider);
      if (_isEditing) {
        await repo.rename(widget.warehouse!.id, _nameCtrl.text.trim());
      } else {
        await repo.add(_nameCtrl.text.trim());
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? "Edit Warehouse" : "New Warehouse"),
      content: SizedBox(
        width: 320,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration:
                    const InputDecoration(labelText: "Warehouse Name *"),
                autofocus: true,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel")),
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
}
