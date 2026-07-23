import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/stock/warehouse_model.dart';

/// Centered warehouse picker — mirrors `showCustomerPickerDialog` so choosing a
/// warehouse is a proper centered dialog instead of a popup menu glued to the
/// header button. Returns the chosen [Warehouse], or null if cancelled.
Future<Warehouse?> showWarehousePickerDialog(
  BuildContext context,
  List<Warehouse> warehouses, {
  int? selectedId,
}) {
  return showDialog<Warehouse>(
    context: context,
    builder: (_) => _WarehousePickerDialog(
      warehouses: warehouses,
      selectedId: selectedId,
    ),
  );
}

class _WarehousePickerDialog extends StatefulWidget {
  final List<Warehouse> warehouses;
  final int? selectedId;
  const _WarehousePickerDialog({required this.warehouses, this.selectedId});

  @override
  State<_WarehousePickerDialog> createState() => _WarehousePickerDialogState();
}

class _WarehousePickerDialogState extends State<_WarehousePickerDialog> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // A search field only earns its space once the list is long.
    final showSearch = widget.warehouses.length > 6;

    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? widget.warehouses
        : widget.warehouses
              .where((w) => w.name.toLowerCase().contains(q))
              .toList();

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text(AppLocalizations.of(context).selectWarehouse),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 360,
        height: showSearch ? 440 : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSearch) ...[
              TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).searchWarehouse,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
            ],
            Flexible(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No warehouses found',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: cs.outlineVariant),
                        itemBuilder: (_, i) {
                          final w = filtered[i];
                          final isSelected = w.id == widget.selectedId;
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isSelected
                                  ? cs.primary
                                  : cs.surfaceContainerHighest,
                              child: Icon(
                                Icons.warehouse,
                                size: 16,
                                color: isSelected ? cs.onPrimary : cs.onSurface,
                              ),
                            ),
                            title: Text(
                              w.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check, size: 18, color: cs.primary)
                                : null,
                            selected: isSelected,
                            selectedTileColor: cs.primary.withValues(alpha: 0.08),
                            onTap: () => Navigator.pop(context, w),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }
}
