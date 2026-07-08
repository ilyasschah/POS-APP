import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class DiscountDialog extends ConsumerStatefulWidget {
  const DiscountDialog({super.key});

  @override
  ConsumerState<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends ConsumerState<DiscountDialog>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final TextEditingController _cartValueCtrl = TextEditingController(text: '0');
  final TextEditingController _itemValueCtrl = TextEditingController(text: '0');

  int _cartDiscountType = 0;
  int _itemDiscountType = 0;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    final defaultTypeInt = settings[SettingKeys.defaultDiscountType] == 'Fixed' ? 1 : 0;
    _cartDiscountType = defaultTypeInt;
    _itemDiscountType = defaultTypeInt;

    final itemDiscountAllowed =
        settings[SettingKeys.singleItemDiscountAllowed]?.toLowerCase() != 'false';
    if (itemDiscountAllowed) {
      _tabController = TabController(length: 2, vsync: this);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartState = ref.read(cartProvider);
      _cartValueCtrl.text = cartState.manualCartDiscount.toString();
      // Always restore the saved type — not just when discount > 0.
      _cartDiscountType = cartState.manualCartDiscountType;

      if (cartState.selectedCartItemId != null) {
        final item = cartState.items
            .where((i) => i.cartItemId == cartState.selectedCartItemId)
            .firstOrNull;
        if (item != null) {
          _itemValueCtrl.text = item.discount.toString();
          _itemDiscountType = item.discountType;
        }
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _cartValueCtrl.dispose();
    _itemValueCtrl.dispose();
    super.dispose();
  }

  void _applyCartDiscount() {
    final val = double.tryParse(_cartValueCtrl.text) ?? 0;
    ref.read(cartProvider.notifier).setCartDiscount(val, _cartDiscountType);
    Navigator.pop(context);
  }

  void _applyItemDiscount() {
    final cartState = ref.read(cartProvider);
    final selectedCartItemId = cartState.selectedCartItemId;
    if (selectedCartItemId == null) {
      showAppSnackbar(context, ref, 'No item selected!', isError: true);
      return;
    }

    final item = cartState.items
        .where((i) => i.cartItemId == selectedCartItemId)
        .firstOrNull;
    if (item == null) {
      showAppSnackbar(context, ref, 'Selected item not found.', isError: true);
      return;
    }

    final val = double.tryParse(_itemValueCtrl.text) ?? 0;
    double finalDiscount = _itemDiscountType == 0 ? item.price * (val / 100) : val;

    final settings = ref.read(appSettingsProvider);
    final preventBelowCost =
        settings[SettingKeys.preventSaleBelowCostPrice]?.toLowerCase() == 'true';
    if (preventBelowCost && item.cost > 0) {
      if (item.price - finalDiscount < item.cost) {
        showAppSnackbar(context, ref, 'Discount would price item below cost.', isError: true);
        return;
      }
    }

    final allowNegativePrice =
        settings[SettingKeys.allowNegativePrice]?.toLowerCase() != 'false';
    if (!allowNegativePrice && item.price - finalDiscount < 0) {
      showAppSnackbar(
        context,
        ref,
        'Discount would result in a negative price.',
        isError: true,
      );
      return;
    }

    // `finalDiscount` is an absolute currency amount (a % entry was converted to
    // money above), so store it as Fixed (type 1) — not the entry mode. This
    // keeps the value self-consistent: reopening the dialog prefills the amount
    // against the Fixed tab and re-applying it is stable, instead of the amount
    // being re-read as a percentage and silently shrinking.
    //
    // The as-entered figure (val + the chosen tab) is passed alongside so the
    // discount record/receipt can show "10%" rather than its money value, while
    // the cart math keeps using the resolved `finalDiscount`.
    ref.read(cartProvider.notifier).setItemDiscount(
          selectedCartItemId,
          finalDiscount,
          1,
          inputValue: val,
          inputType: _itemDiscountType,
        );
    Navigator.pop(context);
  }

  void _apply() {
    if (_tabController == null || _tabController!.index == 0) {
      _applyCartDiscount();
    } else {
      _applyItemDiscount();
    }
  }

  Widget _buildCartDiscountColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey(_cartDiscountType),
          initialValue: _cartDiscountType,
          decoration: const InputDecoration(labelText: 'Discount Type'),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Percentage (%)')),
            DropdownMenuItem(value: 1, child: Text('Fixed Amount')),
          ],
          onChanged: (v) => setState(() => _cartDiscountType = v!),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _cartValueCtrl,
          decoration: const InputDecoration(labelText: 'Value'),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildItemDiscountColumn(ColorScheme cs) {
    final hasSelectedItem = ref.watch(cartProvider).selectedCartItemId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasSelectedItem)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Please select an item in the cart first.',
              style: TextStyle(color: cs.error),
            ),
          ),
        DropdownButtonFormField<int>(
          key: ValueKey(_itemDiscountType),
          initialValue: _itemDiscountType,
          decoration: const InputDecoration(labelText: 'Discount Type'),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Percentage (%)')),
            DropdownMenuItem(value: 1, child: Text('Fixed Amount')),
          ],
          onChanged: (v) => setState(() => _itemDiscountType = v!),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _itemValueCtrl,
          decoration: const InputDecoration(labelText: 'Value'),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Apply Discount'),
      content: SizedBox(
        width: 400,
        height: _tabController != null ? 300 : 180,
        child: _tabController != null
            ? Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: cs.primary,
                    unselectedLabelColor: cs.onSurfaceVariant,
                    tabs: const [
                      Tab(text: 'Cart Discount'),
                      Tab(text: 'Item Discount'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCartDiscountColumn(),
                        _buildItemDiscountColumn(cs),
                      ],
                    ),
                  ),
                ],
              )
            : _buildCartDiscountColumn(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _apply, child: const Text('Apply')),
      ],
    );
  }
}
