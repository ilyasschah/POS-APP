import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/core/ilyass_column_order.dart'
    show ilyassApplyColumnOrder;
import 'package:pos_app/core/reorder.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/settings/settings_provider.dart';

/// The POS header's order-control buttons: their stable ids, the order this
/// till shows them in, and the Settings list that edits both.
///
/// WHICH buttons show is company data — the `ButtonBar.Show*` settings, synced
/// to every till. The ORDER is not: it is how one till's operators like their
/// screen, so it lives in this device's SharedPreferences — shared by everyone
/// who signs in here, never following a login. The same scope as the cart
/// width and the table column orders.

// Stable ids. Never translated and never renamed: a saved order is a list of
// these, and a rename silently drops that button back to its default place.
const kPosBtnCustomer = 'customer';
const kPosBtnOrderType = 'orderType';
const kPosBtnServiceStatus = 'serviceStatus';
const kPosBtnDiscount = 'discount';
const kPosBtnTax = 'tax';
const kPosBtnModifiers = 'modifiers';
const kPosBtnTransfer = 'transfer';
const kPosBtnRefund = 'refund';
const kPosBtnCashDrawer = 'cashDrawer';
const kPosBtnKitchen = 'kitchen';
const kPosBtnAddition = 'addition';
const kPosBtnCloseRegister = 'closeRegister';
const kPosBtnWarehouse = 'warehouse';
const kPosBtnBooking = 'booking';
const kPosBtnTables = 'tables';
const kPosBtnPromos = 'promos';

/// Where this till's order lives.
const kPosHeaderOrderPrefKey = 'pos.header.order';

/// This till's header order, as a list of button ids. Empty until someone
/// reorders — the header then shows its declared default.
final posHeaderOrderProvider =
    NotifierProvider<PosHeaderOrderNotifier, List<String>>(
  PosHeaderOrderNotifier.new,
);

class PosHeaderOrderNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    try {
      return ref
              .read(sharedPreferencesProvider)
              .getStringList(kPosHeaderOrderPrefKey) ??
          const <String>[];
    } catch (_) {
      // No store wired up — a test or a preview. The declared order applies.
      return const <String>[];
    }
  }

  /// [ids] is the FULL catalogue in its new order, hidden buttons included:
  /// storing only the visible ones would lose a hidden button's place, and
  /// switching it back on would fling it to the end.
  void setOrder(List<String> ids) {
    state = List<String>.unmodifiable(ids);
    try {
      ref
          .read(sharedPreferencesProvider)
          .setStringList(kPosHeaderOrderPrefKey, ids);
    } catch (_) {
      // The order still holds for this sitting.
    }
  }

  /// Back to the order the header declares.
  void reset() {
    state = const <String>[];
    try {
      ref.read(sharedPreferencesProvider).remove(kPosHeaderOrderPrefKey);
    } catch (_) {
      // Nothing to forget.
    }
  }
}

/// Puts the header's buttons into [order].
///
/// Each button carries its id as a `ValueKey<String>`. A button [order] does
/// not mention — one added in a later version — keeps the place the header
/// declares it in, instead of being exiled to the end of a layout saved before
/// it existed.
List<Widget> applyPosHeaderOrder(List<Widget> buttons, List<String> order) =>
    ilyassApplyColumnOrder(buttons, order, _idOf);

String _idOf(Widget widget) {
  final key = widget.key;
  // An unkeyed widget still needs a unique id, or it would be dropped.
  return key is ValueKey<String> ? key.value : '#${identityHashCode(widget)}';
}

/// One header button as the Settings list shows it.
@immutable
class PosHeaderButtonSpec {
  const PosHeaderButtonSpec({
    required this.id,
    required this.label,
    required this.icon,
    this.settingKey,
  });

  final String id;
  final String label;
  final IconData icon;

  /// Its show/hide switch. Null for a button that appears by itself when its
  /// feature is on — order type, service status, promotions.
  final String? settingKey;
}

/// Every header button, in the header's default order.
List<PosHeaderButtonSpec> posHeaderButtonCatalog(AppLocalizations l) => [
      PosHeaderButtonSpec(
        id: kPosBtnCustomer,
        label: l.customerLabel,
        icon: Icons.person_outline,
        settingKey: SettingKeys.showCustomerBtn,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnOrderType,
        label: l.orderTypeLabel,
        icon: Icons.restaurant_menu,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnServiceStatus,
        label: l.serviceStatus,
        icon: Icons.label,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnDiscount,
        label: l.posDiscount,
        icon: Icons.percent,
        settingKey: SettingKeys.showDiscountBtn,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnTax,
        label: l.fieldTax,
        icon: Icons.receipt,
        settingKey: SettingKeys.showTaxBtn,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnModifiers,
        label: l.posModifiers,
        icon: Icons.tune,
        settingKey: SettingKeys.showModifiersBtn,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnTransfer,
        label: l.posTransfer,
        icon: Icons.swap_horiz,
        settingKey: SettingKeys.showTransferBtn,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnRefund,
        label: l.posRefund,
        icon: Icons.undo,
        settingKey: SettingKeys.showRefundBtn,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnCashDrawer,
        label: l.setCashDrawer,
        icon: Icons.point_of_sale,
        settingKey: SettingKeys.showCashDrawerBtn,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnKitchen,
        label: l.setSendToKitchen,
        icon: Icons.soup_kitchen,
        settingKey: SettingKeys.showKitchenBtn,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnAddition,
        label: l.posAddition,
        icon: Icons.receipt_long,
        settingKey: SettingKeys.showAdditionBtn,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnCloseRegister,
        label: l.closeRegister,
        icon: Icons.lock_outline,
        settingKey: SettingKeys.showCloseRegisterBtn,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnWarehouse,
        label: l.setWarehouseSwitcher,
        icon: Icons.warehouse,
        settingKey: SettingKeys.showWarehouseBtn,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnBooking,
        label: l.posBookings,
        icon: Icons.calendar_month,
        settingKey: SettingKeys.showBookingBtn,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnTables,
        label: l.setTablesFloorPlan,
        icon: Icons.grid_view,
        settingKey: SettingKeys.showTablesBtn,
      ),
      PosHeaderButtonSpec(
        id: kPosBtnPromos,
        label: l.posPromos,
        icon: Icons.star,
      ),
    ];

/// Settings → POS Buttons: one row per header button — a drag handle that
/// sets the order on THIS till, and a switch that shows or hides it on EVERY
/// till.
class PosHeaderButtonOrderList extends ConsumerWidget {
  const PosHeaderButtonOrderList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final order = ref.watch(posHeaderOrderProvider);
    final settings = ref.watch(appSettingsProvider);
    final specs = ilyassApplyColumnOrder(
      posHeaderButtonCatalog(l),
      order,
      (s) => s.id,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.posHeaderOrderHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                // Nothing to reset while the till still shows the default.
                onPressed: order.isEmpty
                    ? null
                    : () => ref.read(posHeaderOrderProvider.notifier).reset(),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: Text(l.resetButtonOrder),
              ),
            ],
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Handles are explicit: the switch must stay tappable, and a
          // long-press-to-drag row on a touch screen fights with the scroll.
          buildDefaultDragHandles: false,
          itemCount: specs.length,
          // Deliberately the deprecated `onReorder`, like the column picker:
          // its replacement pre-adjusts newIndex, which `reorderedForDrag`
          // already corrects for.
          // ignore: deprecated_member_use
          onReorder: (oldIndex, newIndex) => ref
              .read(posHeaderOrderProvider.notifier)
              .setOrder([
            for (final s in reorderedForDrag(specs, oldIndex, newIndex)) s.id,
          ]),
          itemBuilder: (context, index) {
            final spec = specs[index];
            final key = spec.settingKey;
            final on = key == null || settings[key]?.toLowerCase() == 'true';
            return ListTile(
              key: ValueKey(spec.id),
              contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 12),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Tooltip(
                      message: l.dragToReorderButtons,
                      child: Padding(
                        // Finger-sized: on a tablet this is the control the
                        // whole feature is driven by.
                        padding: const EdgeInsets.all(12),
                        child: Icon(Icons.drag_indicator, color: cs.outline),
                      ),
                    ),
                  ),
                  Icon(
                    spec.icon,
                    color: on ? cs.primary : theme.disabledColor,
                  ),
                ],
              ),
              title: Text(spec.label),
              subtitle: key == null ? Text(l.posButtonAutomatic) : null,
              trailing: key == null
                  ? null
                  : Switch(
                      value: on,
                      activeThumbColor: cs.primary,
                      onChanged: (v) => ref
                          .read(appSettingsProvider.notifier)
                          .setBool(key, v),
                    ),
            );
          },
        ),
      ],
    );
  }
}
