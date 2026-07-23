import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/promotion_models.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class PromotionEditDialog extends ConsumerStatefulWidget {
  final PromotionDto? promotion;

  const PromotionEditDialog({super.key, this.promotion});

  @override
  ConsumerState<PromotionEditDialog> createState() =>
      _PromotionEditDialogState();
}

class _PromotionEditDialogState extends ConsumerState<PromotionEditDialog> {
  late TextEditingController _nameController;
  late int _daysOfWeek;
  late bool _isEnabled;
  DateTime? _startDate;
  String? _startTime;
  DateTime? _endDate;
  String? _endTime;

  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.promotion?.name ?? '');
    _daysOfWeek = widget.promotion?.daysOfWeek ?? 127; // All days
    _isEnabled = widget.promotion?.isEnabled ?? true;
    _startDate = widget.promotion?.startDate;
    _startTime = widget.promotion?.startTime;
    _endDate = widget.promotion?.endDate;
    _endTime = widget.promotion?.endTime;
    if (widget.promotion != null) {
      _items = List.from(
        widget.promotion!.items.map(
          (i) => UpdatePromotionItemRequest(
            id: i.id,
            productId: i.productId,
            discountType: i.discountType,
            priceType: i.priceType,
            value: i.value,
            isConditional: i.isConditional,
            quantity: i.quantity,
            conditionType: i.conditionType,
            quantityLimit: i.quantityLimit,
          ),
        ),
      );
    }
  }

  void _save() async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;

    try {
      if (widget.promotion == null) {
        final request = CreatePromotionRequest(
          name: _nameController.text,
          daysOfWeek: _daysOfWeek,
          startDate: _startDate,
          startTime: _startTime,
          endDate: _endDate,
          endTime: _endTime,
          items: _items.whereType<CreatePromotionItemRequest>().toList(),
        );
        await ApiClient().createPromotion(companyId, request);
      } else {
        List<UpdatePromotionItemRequest> updateItems = _items.map((item) {
          if (item is CreatePromotionItemRequest) {
            return UpdatePromotionItemRequest(
              id: 0,
              productId: item.productId,
              discountType: item.discountType,
              priceType: item.priceType,
              value: item.value,
              isConditional: item.isConditional,
              quantity: item.quantity,
              conditionType: item.conditionType,
              quantityLimit: item.quantityLimit,
            );
          }
          return item as UpdatePromotionItemRequest;
        }).toList();

        final request = UpdatePromotionRequest(
          id: widget.promotion!.id,
          name: _nameController.text,
          daysOfWeek: _daysOfWeek,
          isEnabled: _isEnabled,
          startDate: _startDate,
          startTime: _startTime,
          endDate: _endDate,
          endTime: _endTime,
          items: updateItems,
        );
        await ApiClient().updatePromotion(companyId, request);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showAppSnackbar(context, ref, 'Error: $e', isError: true);
    }
  }

  void _addItem() async {
    final result = await showDialog<CreatePromotionItemRequest>(
      context: context,
      builder: (ctx) => const _PromotionItemEditDialog(),
    );
    if (result != null) {
      setState(() {
        _items.add(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.promotion == null ? 'Create Promotion' : 'Edit Promotion',
      ),
      content: SizedBox(
        width: 600,
        height: 600,
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context).promotionName),
            ),
            Row(
              children: [
                Text(AppLocalizations.of(context).isEnabled),
                const Spacer(),
                Switch(
                  value: _isEnabled,
                  onChanged: (v) => setState(() => _isEnabled = v),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: Text(AppLocalizations.of(context).addItem),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (ctx, i) {
                  final item = _items[i];
                  return ListTile(
                    title: Text(AppLocalizations.of(context).uidValueLabel(item.uid.toString(), item.value.toString())),
                    subtitle: Text(AppLocalizations.of(context).typeValueLabel(item.discountType)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                      onPressed: () {
                        setState(() {
                          _items.removeAt(i);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        ElevatedButton(onPressed: _save, child: Text(AppLocalizations.of(context).actionSave)),
      ],
    );
  }
}

class _PromotionItemEditDialog extends StatefulWidget {
  const _PromotionItemEditDialog();

  @override
  State<_PromotionItemEditDialog> createState() =>
      _PromotionItemEditDialogState();
}

class _PromotionItemEditDialogState extends State<_PromotionItemEditDialog> {
  final _uidController = TextEditingController(text: '0');
  final _valueController = TextEditingController(text: '0');
  int _discountType = 0;
  final int _priceType = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).addPromotionItem),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _uidController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).targetUid,
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _valueController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context).discountValue),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<int>(
              initialValue: _discountType,
              decoration: InputDecoration(labelText: AppLocalizations.of(context).discountType),
              items: [
                DropdownMenuItem(value: 0, child: Text(AppLocalizations.of(context).percentageSign)),
                DropdownMenuItem(value: 1, child: Text(AppLocalizations.of(context).fixedAmountSymLabel('\$'))),
              ],
              onChanged: (v) => setState(() => _discountType = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              CreatePromotionItemRequest(
                productId: int.tryParse(_uidController.text) ?? 0,
                value: double.tryParse(_valueController.text) ?? 0,
                discountType: _discountType,
                priceType: _priceType,
                isConditional: false,
                quantity: 0,
                conditionType: 0,
                quantityLimit: 0,
              ),
            );
          },
          child: Text(AppLocalizations.of(context).actionAdd),
        ),
      ],
    );
  }
}
