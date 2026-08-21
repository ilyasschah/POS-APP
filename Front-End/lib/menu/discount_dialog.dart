import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class DiscountDialog extends ConsumerStatefulWidget {
  const DiscountDialog({super.key});

  @override
  ConsumerState<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends ConsumerState<DiscountDialog>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  // Keypad state
  String _cartInput = '0';
  String _itemInput = '0';
  bool _replaceOnNextKey = true;

  int _cartDiscountType = 0;
  int _itemDiscountType = 0;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    final defaultTypeInt = settings[SettingKeys.defaultDiscountType] == 'Fixed'
        ? 1
        : 0;
    _cartDiscountType = defaultTypeInt;
    _itemDiscountType = defaultTypeInt;

    final itemDiscountAllowed =
        settings[SettingKeys.singleItemDiscountAllowed]?.toLowerCase() !=
        'false';
    if (itemDiscountAllowed) {
      _tabController = TabController(length: 2, vsync: this);
      _tabController!.addListener(() {
        if (_tabController!.indexIsChanging) {
          setState(() {
            _replaceOnNextKey = true;
          });
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartState = ref.read(cartProvider);
      _cartInput = _fmt(cartState.manualCartDiscount);

      if (cartState.manualCartDiscount > 0) {
        _cartDiscountType = cartState.manualCartDiscountType;
      }

      if (cartState.selectedCartItemId != null) {
        final item = cartState.items
            .where((i) => i.cartItemId == cartState.selectedCartItemId)
            .firstOrNull;
        if (item != null) {
          // Prefer the operator's ORIGINAL input form (e.g. "10" + %) over the
          // flattened per-unit money, so reopening a discounted line — on this
          // till or one it was pulled to — shows "10%" instead of a fixed amount.
          if (item.discountInputValue != null && item.discountInputType != null) {
            _itemInput = _fmt(item.discountInputValue!);
            _itemDiscountType = item.discountInputType!;
          } else if (item.discount > 0) {
            _itemInput = _fmt(item.discount);
            _itemDiscountType = item.discountType;
          }
        }
      }
      setState(() {});
    });
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // Helper getters/setters for the active tab's input
  bool get _isCartTab => _tabController == null || _tabController!.index == 0;

  String get _activeInput => _isCartTab ? _cartInput : _itemInput;

  set _activeInput(String val) {
    if (_isCartTab) {
      _cartInput = val;
    } else {
      _itemInput = val;
    }
  }

  // Keypad logic
  void _tapDigit(String d) {
    setState(() {
      if (_replaceOnNextKey) {
        _activeInput = '';
        _replaceOnNextKey = false;
      }
      _activeInput += d;
    });
  }

  void _tapDot() {
    setState(() {
      if (_replaceOnNextKey) {
        _activeInput = '0';
        _replaceOnNextKey = false;
      }
      if (_activeInput.isEmpty) _activeInput = '0';
      if (!_activeInput.contains('.')) _activeInput += '.';
    });
  }

  void _tapSign() {
    setState(() {
      _replaceOnNextKey = false;
      if (_activeInput.startsWith('-')) {
        _activeInput = _activeInput.substring(1);
      } else if (_activeInput.isNotEmpty && _activeInput != '0') {
        _activeInput = '-$_activeInput';
      }
    });
  }

  void _backspace() {
    setState(() {
      _replaceOnNextKey = false;
      if (_activeInput.isNotEmpty) {
        _activeInput = _activeInput.substring(0, _activeInput.length - 1);
      }
    });
  }

  void _applyCartDiscount() {
    final val = double.tryParse(_cartInput) ?? 0;
    ref.read(cartProvider.notifier).setCartDiscount(val, _cartDiscountType);
    Navigator.pop(context);
  }

  void _applyItemDiscount() {
    final cartState = ref.read(cartProvider);
    final selectedCartItemId = cartState.selectedCartItemId;
    if (selectedCartItemId == null) {
      showAppSnackbar(context, ref, AppLocalizations.of(context).noItemSelected, isError: true);
      return;
    }

    final item = cartState.items
        .where((i) => i.cartItemId == selectedCartItemId)
        .firstOrNull;
    if (item == null) {
      showAppSnackbar(context, ref, AppLocalizations.of(context).selectedItemNotFound, isError: true);
      return;
    }

    final val = double.tryParse(_itemInput) ?? 0;
    double finalDiscount = _itemDiscountType == 0
        ? item.price * (val / 100)
        : val;

    final settings = ref.read(appSettingsProvider);
    final preventBelowCost =
        settings[SettingKeys.preventSaleBelowCostPrice]?.toLowerCase() ==
        'true';
    if (preventBelowCost && item.cost > 0) {
      if (item.price - finalDiscount < item.cost) {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).discountBelowCost,
          isError: true,
        );
        return;
      }
    }

    final allowNegativePrice =
        settings[SettingKeys.allowNegativePrice]?.toLowerCase() != 'false';
    if (!allowNegativePrice && item.price - finalDiscount < 0) {
      showAppSnackbar(
        context,
        ref,
        AppLocalizations.of(context).discountNegativePrice,
        isError: true,
      );
      return;
    }

    ref
        .read(cartProvider.notifier)
        .setItemDiscount(
          selectedCartItemId,
          finalDiscount,
          1,
          inputValue: val,
          inputType: _itemDiscountType,
        );
    Navigator.pop(context);
  }

  void _apply() {
    if (_isCartTab) {
      _applyCartDiscount();
    } else {
      _applyItemDiscount();
    }
  }

  // Renders the modern toggle switch
  Widget _buildTypeSwitch(String currencySymbol) {
    final currentType = _isCartTab ? _cartDiscountType : _itemDiscountType;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        segments: [
          const ButtonSegment(value: 0, label: Text('%')),
          ButtonSegment(value: 1, label: Text(currencySymbol)),
        ],
        selected: {currentType},
        onSelectionChanged: (Set<int> newSelection) {
          setState(() {
            if (_isCartTab) {
              _cartDiscountType = newSelection.first;
            } else {
              _itemDiscountType = newSelection.first;
            }
          });
        },
      ),
    );
  }

  // Renders the clean readout display above the keypad
  Widget _buildDisplayBox() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final displayValue = _activeInput.isEmpty ? '0' : _activeInput;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.primary, width: 2),
      ),
      child: Text(
        displayValue,
        textAlign: TextAlign.right,
        style: tt.headlineSmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _row(List<String> keys) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _key(
              child: Text(keys[i]),
              onTap: () {
                switch (keys[i]) {
                  case '.':
                    _tapDot();
                  case '-':
                    _tapSign();
                  default:
                    _tapDigit(keys[i]);
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _key({
    required Widget child,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: filled ? cs.primary : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Center(
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: filled ? cs.onPrimary : cs.onSurface,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: filled ? cs.onPrimary : cs.onSurface,
                  size: 22,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sym = ref.watch(currencySymbolProvider);

    final hasSelectedItem = ref.watch(cartProvider).selectedCartItemId != null;

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      // Tighter insets + a scrollable body so the keypad fits (and, at worst,
      // scrolls instead of overflowing) on a short 7" screen.
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Text(
                AppLocalizations.of(context).applyDiscount,
                style: tt.titleLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              if (_tabController != null) ...[
                TabBar(
                  controller: _tabController,
                  labelColor: cs.primary,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  tabs: [
                    Tab(text: AppLocalizations.of(context).cartTab),
                    Tab(text: AppLocalizations.of(context).itemTab),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              if (!_isCartTab && !hasSelectedItem)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    AppLocalizations.of(context).selectItemFirst,
                    style: TextStyle(color: cs.error),
                  ),
                ),

              _buildTypeSwitch(sym),
              const SizedBox(height: 16),

              _buildDisplayBox(),
              const SizedBox(height: 16),

              // Keypad
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _row(['1', '2', '3']),
                          const SizedBox(height: 8),
                          _row(['4', '5', '6']),
                          const SizedBox(height: 8),
                          _row(['7', '8', '9']),
                          const SizedBox(height: 8),
                          _row(['-', '0', '.']),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _key(
                            child: const Icon(Icons.backspace_outlined),
                            onTap: _backspace,
                          ),
                          const SizedBox(height: 8),
                          _key(
                            child: const Text('esc'),
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _key(
                              child: const Icon(Icons.keyboard_return),
                              onTap: _apply,
                              filled: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
