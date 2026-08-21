// lib/settings_screen.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/database/backup_service.dart';
import 'package:pos_app/utils/customer_display_service.dart';
import 'package:pos_app/customer_display/customer_display_web_server.dart';
import 'package:pos_app/customer_display/customer_display_screen.dart';
import 'package:pos_app/core/app_theme.dart';
import 'package:pos_app/core/app_version.dart';
import 'package:pos_app/sync/pending_count_provider.dart';
import 'package:pos_app/update/app_release.dart';
import 'package:pos_app/update/update_guard.dart';
import 'package:pos_app/update/update_providers.dart';
import 'package:pos_app/update/update_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/scale/scale_service.dart';
import 'package:pos_app/settings/barcode_rules_editor.dart';
import 'package:pos_app/database/restore_flow.dart';
import 'package:pos_app/settings/local_ui_prefs.dart';
import 'package:pos_app/settings/reset_database_section.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/app_settings/service_type_model.dart';
import 'package:pos_app/app_settings/service_status_model.dart';
import 'package:pos_app/app_settings/booking_settings_model.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/auth/login_screen.dart';
import 'package:pos_app/auth/master_login_screen.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/floor_plan/floor_plan_table_provider.dart';
import 'package:pos_app/license/license_service.dart';
import 'package:pos_app/navigation/nav_widgets.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/settings/printer_settings_screen.dart';
import 'package:pos_app/kitchen/kitchen_push_service.dart';
import 'package:pos_app/kitchen/printer_group_model.dart';
import 'package:pos_app/product/product_group_model.dart';
import 'package:pos_app/product/product_group_provider.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:pos_app/settings/device_identity.dart';
import 'package:pos_app/settings/developer_mode.dart';
import 'package:pos_app/session/session_summary_provider.dart';
import 'package:pos_app/cart/payment_type_provider.dart';
import 'package:pos_app/onboarding/onboarding_prefs.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GLOBAL SEARCH STATE
// ─────────────────────────────────────────────────────────────────────────────

/// Live query for the global settings search.
///
/// Empty string ⇒ the normal tabbed view is shown. Any non-empty value
/// overrides the right-hand content with a flat "Search Results" list.
/// The value is stored already trimmed + lowercased so that
/// [_SettingSearchEntry.matches] can do a plain `contains` with no per-frame
/// string allocations. Local to the settings screen — never persisted.
final settingsSearchQueryProvider = StateProvider<String>((ref) => '');

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR SIZING
// ─────────────────────────────────────────────────────────────────────────────

/// Memoised [settingsSidebarWidth] results, keyed by everything the
/// measurement depends on. Without it every rebuild — each keystroke in the
/// settings search — re-lays out ~20 `TextPainter`s.
final _sidebarWidthCache = <String, double>{};

/// Settings sidebar width, sized to the **current locale's** longest label
/// instead of a hardcoded 211.
///
/// 🚨 French runs ~15–20% longer than English, and this panel was a fixed
/// width: "Enregistrer et redémarrer" overflowed the pinned action by 29px and
/// every nav label ellipsised. Measuring beats per-locale magic numbers — it
/// stays right for whatever the `.arb` files actually contain, including any
/// language added later.
///
/// The chrome constants below mirror the two widgets being measured, so they
/// have to move together: [NavItem] = 8+8 outer padding, 8+8 container padding,
/// 3+8 active bar, 18 icon, 10 gap → 71; [SettingsSaveAction] = 12+12 padding,
/// 20 icon, 10 gap → 54.
double settingsSidebarWidth(BuildContext context) {
  final scaler = MediaQuery.textScalerOf(context);
  final key = '${Localizations.localeOf(context)}|${scaler.scale(15)}';
  final cached = _sidebarWidthCache[key];
  if (cached != null) return cached;

  double measure(String text, double size, FontWeight weight) {
    return (TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout()).width;
  }

  // Nav labels are measured at w600 — the *active* weight, i.e. the widest a
  // row ever renders.
  var widest = 0.0;
  for (final tab in _SettingsScreenState._tabsFor(context)) {
    widest = math.max(widest, measure(tab.label, 13, FontWeight.w600) + 71);
  }
  widest = math.max(
    widest,
    measure(AppLocalizations.of(context).saveAndRestart, 15, FontWeight.bold) +
        54,
  );

  // +1 for the right divider. The floor keeps short locales at the familiar
  // layout; the ceiling stops a runaway translation from eating the content
  // pane on a 10" tablet — SettingsSaveAction ellipsises if it ever bites.
  final width = (widest + 1).clamp(211.0, 340.0);
  _sidebarWidthCache[key] = width;
  return width;
}

/// The pinned "Save & Restart" action at the foot of the settings sidebar.
///
/// Extracted so `test/settings_sidebar_test.dart` exercises the real widget
/// rather than a copy of its layout — a cloned Row would drift from this one
/// and stop catching the overflow it exists to pin.
class SettingsSaveAction extends StatelessWidget {
  const SettingsSaveAction({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: context.navAccent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save_outlined, color: cs.onPrimary, size: 20),
                  const SizedBox(width: 10),
                  // Flexible + ellipsis is the hard guarantee. The sidebar is
                  // sized to fit this label, but at the clamp ceiling a long
                  // translation must shrink rather than overflow — same pattern
                  // as management_layout's exit button. Without it, French
                  // overflowed by 29px.
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context).saveAndRestart,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedIndex = 0;
  bool _isSidebarVisible = true;

  // Sidebar stays put on tab select — only manual toggles hide it.
  void _selectTab(int i) => setState(() => _selectedIndex = i);

  // Built per-frame rather than static const: the labels are localized, so
  // they can only be resolved once a BuildContext exists.
  static List<({IconData icon, String label})> _tabsFor(
    BuildContext context,
  ) => [
    (icon: Icons.tune, label: AppLocalizations.of(context).generalLower),
    (
      icon: Icons.receipt_long,
      label: AppLocalizations.of(context).setOrderAndPayment,
    ),
    (icon: Icons.inventory_2, label: AppLocalizations.of(context).products),
    (
      icon: Icons.monitor_weight,
      label: AppLocalizations.of(context).setWeighingScale,
    ),
    (
      icon: Icons.display_settings,
      label: AppLocalizations.of(context).setCustomerDisplay,
    ),
    (
      icon: Icons.kitchen,
      label: AppLocalizations.of(context).setKitchenDisplay,
    ),
    (icon: Icons.email, label: AppLocalizations.of(context).fieldEmail),
    (icon: Icons.print, label: AppLocalizations.of(context).setPrint),
    (
      icon: Icons.currency_exchange,
      label: AppLocalizations.of(context).dualCurrencyLower,
    ),
    (icon: Icons.storage, label: AppLocalizations.of(context).databaseLower),
    (
      icon: Icons.workspace_premium,
      label: AppLocalizations.of(context).setSubscription,
    ),
    (icon: Icons.info_outline, label: AppLocalizations.of(context).setAbout),
  ];

  static const _tabViews = [
    _GeneralTab(),
    _OrderPaymentTab(),
    _ProductsTab(),
    _WeighingScaleTab(),
    _CustomerDisplayTab(),
    _KitchenDisplayTab(),
    _EmailTab(),
    _PrintTab(),
    _DualCurrencyTab(),
    _DatabaseTab(),
    _SubscriptionTab(),
    _AboutTab(),
  ];

  Future<void> _saveAndRestart() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    // Wait for any in-flight settings write (its Drift commit + the resulting
    // provider rebuild) to fully settle, so our teardown below can't be
    // scheduled in the same tick — Riverpod 3 asserts "one task at a time"
    // otherwise. Settings persist live as they're changed, so there's nothing
    // to "save" here; this is purely a session reset + restart.
    try {
      await ref.read(appSettingsProvider.notifier).settle();
    } catch (_) {
      /* settle never throws, but stay defensive */
    }
    if (!mounted) return;

    // Best-effort local reset. The login flow re-initialises all of these, so a
    // transient scheduler hiccup must never block the restart.
    try {
      ref.read(cartProvider.notifier).clearCart();
      ref.read(floorPlanTableProvider.notifier).state = null;
      ref.invalidate(currentUserProvider);
    } catch (_) {
      /* proceed to login regardless */
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(rawAppPropertiesProvider).isLoading;
    final searchQuery = ref.watch(settingsSearchQueryProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: SettingsHeaderBar(isLoading: isLoading),
      body: Row(
        children: [
          // ── Left sidebar — instant show/hide via conditional inclusion ───
          if (_isSidebarVisible)
            Material(
              color: cs.surfaceContainerLow,
              child: Container(
                // Sized to the current locale's longest label — see
                // settingsSidebarWidth. Floors at the historical 211 (210 panel
                // + 1px right divider), so English and Arabic look unchanged.
                width: settingsSidebarWidth(context),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(width: 1, color: cs.outlineVariant),
                  ),
                ),
                child: Column(
                  children: [
                    // Scrollable tab list — takes all space above the pinned action.
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _tabsFor(context).length,
                        itemBuilder: (context, i) => NavItem(
                          icon: _tabsFor(context)[i].icon,
                          label: _tabsFor(context)[i].label,
                          isActive: i == _selectedIndex,
                          onTap: () => _selectTab(i),
                        ),
                      ),
                    ),

                    // Divider separating the nav list from the pinned action.
                    Divider(height: 1, color: context.navDivider),

                    SettingsSaveAction(onTap: _saveAndRestart),
                  ],
                ),
              ),
            ),
          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // When a search is active, the per-tab layout is completely
                // hidden and replaced by the unified "Search Results" view.
                // Otherwise the normal tabbed content renders (no auto-hide —
                // the sidebar only changes on manual toggles).
                if (searchQuery.isEmpty)
                  LazyIndexedStack(index: _selectedIndex, children: _tabViews)
                else
                  _SearchResultsView(
                    query: searchQuery,
                    onOpenTab: (i) {
                      // Clear the query (also empties the search field via its
                      // provider listener) and jump to the requested tab.
                      ref.read(settingsSearchQueryProvider.notifier).state = '';
                      setState(() => _selectedIndex = i);
                    },
                  ),
                if (!_isSidebarVisible)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: NavEdgeToggle(
                        onTap: () => setState(() => _isSidebarVisible = true),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The settings screen's header: the title, the global search, and the
/// settings-loading spinner.
///
/// The search lives here rather than in the sidebar so it survives collapsing
/// the sidebar (where it used to be hidden along with it), and here rather than
/// in a band of its own because the header already had empty space to the right
/// of the title — a second band would cost ~64px of vertical room, which is
/// scarce on a 10–13" tablet. While the query is non-empty the tab content below
/// is replaced by "Search Results".
///
/// Public only so `test/settings_header_bar_test.dart` can pump it — it has no
/// callers outside this file.
class SettingsHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const SettingsHeaderBar({super.key, this.isLoading = false});

  final bool isLoading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      elevation: 0,
      // Use a Stack to perfectly center the search bar regardless of the title
      title: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppLocalizations.of(context).settings,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: const _SettingsSearchField(),
            ),
          ),
        ],
      ),
      actions: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shadowColor: theme.shadowColor.withValues(alpha: 0.08),
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          ...children,
        ],
      ),
    );
  }
}

// A text field row that saves on focus-loss / submit
class _SettingTextField extends ConsumerStatefulWidget {
  final String settingKey;
  final String label;
  final String? hint;
  final TextInputType keyboardType;

  const _SettingTextField({
    required this.settingKey,
    required this.label,
    this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  ConsumerState<_SettingTextField> createState() => _SettingTextFieldState();
}

class _SettingTextFieldState extends ConsumerState<_SettingTextField> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final value = ref.read(appSettingsProvider.notifier).get(widget.settingKey);
    _ctrl = TextEditingController(text: value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(appSettingsProvider.notifier);
    if (_ctrl.text == notifier.get(widget.settingKey)) return;
    setState(() => _saving = true);
    try {
      await notifier.set(widget.settingKey, _ctrl.text.trim());
      if (mounted) {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).settingSaved(widget.label),
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).savedFieldFailed(widget.label),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType: widget.keyboardType,
              maxLines: 1,
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
              onSubmitted: (_) => _save(),
              onEditingComplete: _save,
            ),
          ),
          const SizedBox(width: 8),
          _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: Icon(
                    Icons.check_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: AppLocalizations.of(context).actionSave,
                  onPressed: _save,
                ),
        ],
      ),
    );
  }
}

// A toggle (switch) row that saves immediately on change
class _SettingSwitch extends ConsumerWidget {
  final String settingKey;
  final String label;
  final String? subtitle;
  final void Function(WidgetRef, bool)? onChanged;

  /// When false the row renders greyed out and ignores taps — for a setting
  /// whose parent feature is off, so it stays visible (and self-explanatory)
  /// instead of disappearing. The stored value is left untouched.
  final bool enabled;
  final IconData? icon;

  const _SettingSwitch({
    required this.settingKey,
    required this.label,
    this.subtitle,
    this.onChanged,
    this.enabled = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final value =
        ref.watch(appSettingsProvider)[settingKey]?.toLowerCase() == 'true';

    return SwitchListTile(
      secondary: icon != null
          ? Icon(
              icon,
              color: enabled ? theme.colorScheme.primary : theme.disabledColor,
            )
          : null,
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      activeThumbColor: theme.colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onChanged: enabled
          ? (v) {
              ref.read(appSettingsProvider.notifier).setBool(settingKey, v);
              onChanged?.call(ref, v);
            }
          : null,
    );
  }
}

// A dropdown row
class _SettingDropdown extends ConsumerWidget {
  final String settingKey;
  final String label;
  final List<String> options;

  const _SettingDropdown({
    required this.settingKey,
    required this.label,
    required this.options,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current =
        ref.watch(appSettingsProvider)[settingKey] ??
        kSettingDefaults[settingKey] ??
        options.first;

    final safeValue = options.contains(current) ? current : options.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: safeValue,
              decoration: InputDecoration(
                labelText: label,
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
              dropdownColor: theme.colorScheme.surfaceContainerHighest,
              items: options
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(_settingOptionLabel(context, o)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref.read(appSettingsProvider.notifier).set(settingKey, v);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom service-type editor ────────────────────────────────────────────────

class _CustomServiceTypesEditor extends ConsumerStatefulWidget {
  const _CustomServiceTypesEditor();

  @override
  ConsumerState<_CustomServiceTypesEditor> createState() =>
      _CustomServiceTypesEditorState();
}

class _CustomServiceTypesEditorState
    extends ConsumerState<_CustomServiceTypesEditor> {
  static const _palette = [
    Color(0xFF3F51B5),
    Color(0xFFFF5722),
    Color(0xFF4CAF50),
    Color(0xFF9C27B0),
    Color(0xFF009688),
    Color(0xFF795548),
  ];

  List<CustomServiceType> get _types =>
      ref.read(appSettingsProvider.notifier).customServiceTypes;

  Future<void> _save(List<CustomServiceType> updated) async {
    await ref
        .read(appSettingsProvider.notifier)
        .set(
          SettingKeys.customServiceTypes,
          CustomServiceType.listToJson(updated),
        );
    ref.read(cartProvider.notifier).clearCart();
  }

  Future<void> _showTypeDialog({CustomServiceType? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final prefixCtrl = TextEditingController(text: existing?.prefix ?? '');
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _TypeFormDialog(
        nameCtrl: nameCtrl,
        prefixCtrl: prefixCtrl,
        isEdit: existing != null,
      ),
    );
    if (result == null || !mounted) return;
    final name = result[0];
    final prefix = result[1];
    final updated = List<CustomServiceType>.from(_types);
    if (existing == null) {
      final nextId = updated.isEmpty
          ? 0
          : updated.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
      updated.add(CustomServiceType(id: nextId, name: name, prefix: prefix));
    } else {
      final i = updated.indexWhere((t) => t.id == existing.id);
      if (i >= 0) updated[i] = existing.copyWith(name: name, prefix: prefix);
    }
    await _save(updated);
  }

  Future<void> _delete(CustomServiceType target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).setDeleteServiceType),
        content: Text(
          AppLocalizations.of(context).removeNamedConfirm(target.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).actionCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save(_types.where((t) => t.id != target.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    // Watch so the list rebuilds when the setting is persisted.
    ref.watch(appSettingsProvider);
    final types = _types;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context).setServiceTypes,
                style: theme.textTheme.labelLarge,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showTypeDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: Text(AppLocalizations.of(context).actionAdd),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...types.asMap().entries.map((entry) {
            final idx = entry.key;
            final t = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: _palette[idx % _palette.length],
                    radius: 14,
                    child: Text(
                      '${t.id}',
                      style: TextStyle(
                        color: context.onStatusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(t.name),
                  subtitle: Text(
                    AppLocalizations.of(context).prefixColonValue(t.prefix),
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _showTypeDialog(existing: t),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: theme.colorScheme.error,
                        onPressed: () => _delete(t),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TypeFormDialog extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController prefixCtrl;
  final bool isEdit;

  const _TypeFormDialog({
    required this.nameCtrl,
    required this.prefixCtrl,
    required this.isEdit,
  });

  @override
  State<_TypeFormDialog> createState() => _TypeFormDialogState();
}

class _TypeFormDialogState extends State<_TypeFormDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isEdit
            ? AppLocalizations.of(context).editServiceType
            : AppLocalizations.of(context).addServiceType,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.nameCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).fieldName,
              hintText: AppLocalizations.of(context).setHintUberEats,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.prefixCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).setOrderNumberPrefix,
              hintText: AppLocalizations.of(context).setHintUber,
            ),
            onChanged: (v) {
              final upper = v.toUpperCase();
              if (v != upper) {
                widget.prefixCtrl.value = widget.prefixCtrl.value.copyWith(
                  text: upper,
                  selection: TextSelection.collapsed(offset: upper.length),
                );
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        ElevatedButton(
          onPressed: () {
            final name = widget.nameCtrl.text.trim();
            final prefix = widget.prefixCtrl.text.trim().toUpperCase();
            if (name.isNotEmpty && prefix.isNotEmpty) {
              Navigator.pop(context, [name, prefix]);
            }
          },
          child: Text(AppLocalizations.of(context).actionSave),
        ),
      ],
    );
  }
}

// ── Custom service-status editor ──────────────────────────────────────────────

class _CustomServiceStatusesEditor extends ConsumerStatefulWidget {
  const _CustomServiceStatusesEditor();

  @override
  ConsumerState<_CustomServiceStatusesEditor> createState() =>
      _CustomServiceStatusesEditorState();
}

class _CustomServiceStatusesEditorState
    extends ConsumerState<_CustomServiceStatusesEditor> {
  List<CustomServiceStatus> get _statuses =>
      ref.read(appSettingsProvider.notifier).customServiceStatuses;

  Future<void> _save(List<CustomServiceStatus> updated) async {
    await ref
        .read(appSettingsProvider.notifier)
        .set(
          SettingKeys.customServiceStatuses,
          CustomServiceStatus.listToJson(updated),
        );
    ref.read(cartProvider.notifier).clearCart();
  }

  Future<void> _showStatusDialog({CustomServiceStatus? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    int pickedColor = existing?.colorValue ?? 0xFF2196F3;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _StatusFormDialog(
        nameCtrl: nameCtrl,
        initialColor: pickedColor,
        isEdit: existing != null,
      ),
    );
    if (result == null || !mounted) return;
    final name = result['name'] as String;
    final colorValue = result['colorValue'] as int;
    final updated = List<CustomServiceStatus>.from(_statuses);
    if (existing == null) {
      final nextId = updated.isEmpty
          ? 1
          : updated.map((s) => s.id).reduce((a, b) => a > b ? a : b) + 1;
      updated.add(
        CustomServiceStatus(id: nextId, name: name, colorValue: colorValue),
      );
    } else {
      final i = updated.indexWhere((s) => s.id == existing.id);
      if (i >= 0) {
        updated[i] = existing.copyWith(name: name, colorValue: colorValue);
      }
    }
    await _save(updated);
  }

  Future<void> _delete(CustomServiceStatus target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).setDeleteServiceStatus),
        content: Text(
          AppLocalizations.of(context).removeNamedConfirm(target.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).actionCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save(_statuses.where((s) => s.id != target.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appSettingsProvider);
    final statuses = _statuses;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context).setServiceStatuses,
                style: theme.textTheme.labelLarge,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showStatusDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: Text(AppLocalizations.of(context).actionAdd),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...statuses.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: s.color,
                    radius: 14,
                    child: Text(
                      '${s.id}',
                      style: TextStyle(
                        color: context.onStatusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(s.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _showStatusDialog(existing: s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: theme.colorScheme.error,
                        onPressed: () => _delete(s),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFormDialog extends StatefulWidget {
  final TextEditingController nameCtrl;
  final int initialColor;
  final bool isEdit;

  const _StatusFormDialog({
    required this.nameCtrl,
    required this.initialColor,
    required this.isEdit,
  });

  @override
  State<_StatusFormDialog> createState() => _StatusFormDialogState();
}

class _StatusFormDialogState extends State<_StatusFormDialog> {
  static const _presets = [
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFF4CAF50), // Green
    Color(0xFFF44336), // Red
    Color(0xFF9C27B0), // Purple
    Color(0xFF009688), // Teal
    Color(0xFFFFC107), // Amber
    Color(0xFFE91E63), // Pink
    Color(0xFF3F51B5), // Indigo
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF795548), // Brown
    Color(0xFF9E9E9E), // Grey
  ];

  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isEdit
            ? AppLocalizations.of(context).editServiceStatus
            : AppLocalizations.of(context).addServiceStatus,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.nameCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).fieldName,
              hintText: AppLocalizations.of(context).setHintWaiting,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).setColor,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((c) {
              final isSelected = c.toARGB32() == _selected;
              return GestureDetector(
                onTap: () => setState(() => _selected = c.toARGB32()),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3,
                          )
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        ElevatedButton(
          onPressed: () {
            final name = widget.nameCtrl.text.trim();
            if (name.isNotEmpty) {
              Navigator.pop(context, {'name': name, 'colorValue': _selected});
            }
          },
          child: Text(AppLocalizations.of(context).actionSave),
        ),
      ],
    );
  }
}

// ── Booking settings card ─────────────────────────────────────────────────────

class _BookingSettingsCard extends ConsumerStatefulWidget {
  const _BookingSettingsCard();

  @override
  ConsumerState<_BookingSettingsCard> createState() =>
      _BookingSettingsCardState();
}

class _BookingSettingsCardState extends ConsumerState<_BookingSettingsCard> {
  static const _snappingOptions = [5, 10, 15, 30, 60];
  static const _durationOptions = [15, 30, 45, 60, 90, 120, 180, 240];

  BookingSettingsModel get _current =>
      ref.read(appSettingsProvider.notifier).bookingSettings;

  Future<void> _save(BookingSettingsModel updated) =>
      ref.read(appSettingsProvider.notifier).setBookingSettings(updated);

  @override
  Widget build(BuildContext context) {
    ref.watch(appSettingsProvider);
    final s = _current;
    final theme = Theme.of(context);

    return _SettingsCard(
      title: AppLocalizations.of(context).setBooking,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Resource Mode ──────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).resourceMode,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context).resourceModeHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: s.resourceMode,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(8),
                    items: [
                      DropdownMenuItem(
                        value: 'table',
                        child: Row(
                          children: [
                            const Icon(Icons.table_restaurant, size: 16),
                            const SizedBox(width: 6),
                            Text(AppLocalizations.of(context).setTable),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'room',
                        child: Row(
                          children: [
                            const Icon(Icons.meeting_room, size: 16),
                            const SizedBox(width: 6),
                            Text(AppLocalizations.of(context).setRoom),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'staff',
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 16),
                            const SizedBox(width: 6),
                            Text(AppLocalizations.of(context).setStaff),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) _save(s.copyWith(resourceMode: v));
                    },
                  ),
                ],
              ),
              const Divider(height: 28),

              // ── Default Duration ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).defaultDuration,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context).defaultDurationHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: _durationOptions.contains(s.defaultDurationMinutes)
                        ? s.defaultDurationMinutes
                        : _durationOptions.last,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(8),
                    items: _durationOptions
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(_formatDuration(m)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _save(s.copyWith(defaultDurationMinutes: v));
                      }
                    },
                  ),
                ],
              ),
              const Divider(height: 28),

              // ── Time Snapping ──────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).timeSnapping,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context).timeSnappingHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: _snappingOptions.contains(s.timeSnappingMinutes)
                        ? s.timeSnappingMinutes
                        : 15,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(8),
                    items: _snappingOptions
                        .map(
                          (m) =>
                              DropdownMenuItem(value: m, child: Text('$m min')),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _save(s.copyWith(timeSnappingMinutes: v));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

// Currency picker — loads from /Currencies/GetAll and saves code to settings
class _CurrencyDropdown extends ConsumerWidget {
  const _CurrencyDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currenciesAsync = ref.watch(currenciesProvider);
    final storedValue =
        ref.watch(appSettingsProvider)[SettingKeys.currencySymbol] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: currenciesAsync.when(
        loading: () => Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context).loadingCurrencies),
          ],
        ),
        error: (_, __) => Text(
          AppLocalizations.of(context).couldNotLoadCurrencies,
          style: TextStyle(color: context.dangerColor),
        ),
        data: (currencies) {
          if (currencies.isEmpty) return const SizedBox.shrink();

          final keys = currencies.map((c) => c.code ?? c.name).toList();
          final safeValue = keys.contains(storedValue)
              ? storedValue
              : keys.first;

          return DropdownButtonFormField<String>(
            initialValue: safeValue,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).setCurrency,
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
            dropdownColor: theme.colorScheme.surfaceContainerHighest,
            items: currencies.map((c) {
              final key = c.code ?? c.name;
              final label = c.code != null ? '${c.name} (${c.code})' : c.name;
              return DropdownMenuItem<String>(value: key, child: Text(label));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                ref
                    .read(appSettingsProvider.notifier)
                    .set(SettingKeys.currencySymbol, val);
              }
            },
          );
        },
      ),
    );
  }
}

// ─── Numeric stepper (± integer, saves to appSettingsProvider) ───────────────

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _StepBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? theme.colorScheme.primary : theme.disabledColor,
        ),
      ),
    );
  }
}

class _NumericStepper extends ConsumerWidget {
  final String settingKey;
  final int min;
  final int max;

  const _NumericStepper({
    required this.settingKey,
    required this.min,
    required this.max,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final raw =
        ref.watch(appSettingsProvider)[settingKey] ??
        kSettingDefaults[settingKey] ??
        '$min';
    final value = (int.tryParse(raw) ?? min).clamp(min, max);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: Icons.remove,
            enabled: value > min,
            onTap: () => ref
                .read(appSettingsProvider.notifier)
                .set(settingKey, '${value - 1}'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          _StepBtn(
            icon: Icons.add,
            enabled: value < max,
            onTap: () => ref
                .read(appSettingsProvider.notifier)
                .set(settingKey, '${value + 1}'),
          ),
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final String settingKey;
  final int min;
  final int max;
  final String? suffix;

  const _StepperRow({
    required this.label,
    required this.settingKey,
    required this.min,
    required this.max,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          _NumericStepper(settingKey: settingKey, min: min, max: max),
          if (suffix != null) ...[
            const SizedBox(width: 8),
            Text(suffix!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLOBAL SEARCH — UI + RESULTS + REGISTRY
// ─────────────────────────────────────────────────────────────────────────────

/// Flat Material-3 search box, mounted in the settings screen's header.
///
/// Low-spec friendly: no animated container, no blur, no drop shadow — just a
/// filled field with a thin explicit border. Pushes the live (trimmed +
/// lowercased) value into [settingsSearchQueryProvider] on every keystroke.
class _SettingsSearchField extends ConsumerStatefulWidget {
  const _SettingsSearchField();

  @override
  ConsumerState<_SettingsSearchField> createState() =>
      _SettingsSearchFieldState();
}

class _SettingsSearchFieldState extends ConsumerState<_SettingsSearchField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    // Initialize the controller WITH the current provider state to prevent
    // desyncs when the widget remounts or rebuilds.
    _ctrl = TextEditingController(text: ref.read(settingsSearchQueryProvider));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    setState(() {});
    ref.read(settingsSearchQueryProvider.notifier).state = raw
        .trim()
        .toLowerCase();
  }

  void _clear() {
    _ctrl.clear();
    ref.read(settingsSearchQueryProvider.notifier).state = '';
    setState(() {});
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the field in sync when the query is cleared programmatically
    ref.listen(settingsSearchQueryProvider, (_, next) {
      if (next.isEmpty && _ctrl.text.isNotEmpty) {
        _ctrl.clear();
        setState(() {});
      }
    });

    final hasText = _ctrl.text.isNotEmpty;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: context.navDivider, width: 1),
    );

    return TextField(
      controller: _ctrl,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      cursorColor: context.navAccent,
      style: TextStyle(color: context.navText, fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: context.navSidebarBg,
        hintText: AppLocalizations.of(context).setSearchAllSettings,
        hintStyle: TextStyle(color: context.navMuted, fontSize: 14),
        prefixIcon: Icon(Icons.search, size: 18, color: context.navMuted),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        suffixIcon: hasText
            ? IconButton(
                icon: Icon(Icons.close, size: 16, color: context.navMuted),
                splashRadius: 16,
                tooltip: AppLocalizations.of(context).actionReset,
                onPressed: _clear,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.navAccent, width: 1),
        ),
      ),
    );
  }
}

/// One catalogued setting, surfaced as a single iOS-style row in search.
///
/// [title] is the precise setting name — the *only* field matched against the
/// query. [tabName] is the category shown as the muted subtitle. [tabIndex] is
/// the owning tab. [trailingBuilder] returns the live, actionable control
/// (Switch / Dropdown / stepper / text field / "Open" button) that binds to the
/// very same [appSettingsProvider] state as the tab view — so changing a value
/// from the search list is identical to changing it inside its tab. When
/// [navigational] is true the whole row opens [tabIndex] (used for panels whose
/// editor is a full screen, e.g. Database, Printer).
class SearchableSetting {
  final String title;
  final String tabName;
  final int tabIndex;
  final bool navigational;
  final Widget Function(VoidCallback openTab)? trailingBuilder;

  SearchableSetting({
    required this.title,
    required this.tabName,
    required this.tabIndex,
    this.navigational = false,
    this.trailingBuilder,
  });

  /// Strict, surgical match: the query is tested against the title only.
  /// [q] is expected to already be trimmed + lowercased.
  bool matches(String q) => title.toLowerCase().contains(q);
}

/// The right-hand "Search Results" override — a flat, iOS-style list.
///
/// Filters [_kSearchableSettings] strictly by title and renders each match as a
/// [ListTile]: setting name as the title, its category as a muted subtitle, and
/// the real interactive control as the trailing widget. Nothing here is a copy
/// of the setting — the trailing controls drive [appSettingsProvider] directly.
class _SearchResultsView extends ConsumerWidget {
  const _SearchResultsView({required this.query, required this.onOpenTab});

  final String query;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = _kSearchableSettings(
      context,
    ).where((s) => s.matches(query)).toList();

    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 44, color: context.navMuted),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).noSettingsMatching(query),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.navMuted, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: matches.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 20,
        endIndent: 16,
        color: context.navDivider,
      ),
      itemBuilder: (context, i) {
        final s = matches[i];
        void openTab() => onOpenTab(s.tabIndex);
        return ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
          title: Text(
            s.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              s.tabName,
              style: TextStyle(color: context.navMuted, fontSize: 12),
            ),
          ),
          trailing: s.navigational
              ? Icon(Icons.chevron_right, color: context.navMuted)
              : s.trailingBuilder?.call(openTab),
          onTap: s.navigational ? openTab : null,
        );
      },
    );
  }
}

// ── Compact trailing controls (bind straight to appSettingsProvider) ──────────

/// Bare on/off control. [onChanged] mirrors any tab-side interlock side effects.
class _SwitchControl extends ConsumerWidget {
  final String settingKey;
  final void Function(WidgetRef, bool)? onChanged;
  const _SwitchControl(this.settingKey, {this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value =
        ref.watch(appSettingsProvider)[settingKey]?.toLowerCase() == 'true';
    return Switch(
      value: value,
      activeThumbColor: Theme.of(context).colorScheme.primary,
      onChanged: (v) {
        ref.read(appSettingsProvider.notifier).setBool(settingKey, v);
        onChanged?.call(ref, v);
      },
    );
  }
}

/// Bare dropdown bound to a string setting.
class _DropdownControl extends ConsumerWidget {
  final String settingKey;
  final List<String> options;
  const _DropdownControl(this.settingKey, this.options);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(appSettingsProvider)[settingKey] ??
        kSettingDefaults[settingKey] ??
        options.first;
    final safe = options.contains(current) ? current : options.first;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: DropdownButton<String>(
        value: safe,
        isDense: true,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(8),
        dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        items: options
            .map(
              (o) => DropdownMenuItem(
                value: o,
                child: Text(_settingOptionLabel(context, o)),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) {
            ref.read(appSettingsProvider.notifier).set(settingKey, v);
          }
        },
      ),
    );
  }
}

/// Theme-mode dropdown with friendly labels (keys live in app settings).
class _ThemeModeControl extends ConsumerWidget {
  const _ThemeModeControl();

  static const _labels = <String, String>{
    'light': 'Light',
    'dark': 'Dark',
    'dimmed': 'Dimmed',
    'night': 'Night',
    'gray': 'Gray',
    'high_contrast': 'High Contrast',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(appSettingsProvider)[SettingKeys.themeMode] ?? 'dark';
    final safe = _labels.containsKey(current) ? current : 'dark';
    return DropdownButton<String>(
      value: safe,
      isDense: true,
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(8),
      dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      items: _labels.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          ref.read(appSettingsProvider.notifier).set(SettingKeys.themeMode, v);
        }
      },
    );
  }
}

/// Compact text control that saves on submit / focus loss, like the tab row.
class _TextFieldControl extends ConsumerStatefulWidget {
  final String settingKey;
  final String? hint;
  final TextInputType keyboardType;
  const _TextFieldControl(
    this.settingKey, {
    this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  ConsumerState<_TextFieldControl> createState() => _TextFieldControlState();
}

class _TextFieldControlState extends ConsumerState<_TextFieldControl> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: ref.read(appSettingsProvider.notifier).get(widget.settingKey),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final notifier = ref.read(appSettingsProvider.notifier);
    if (_ctrl.text == notifier.get(widget.settingKey)) return;
    notifier.set(widget.settingKey, _ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: TextField(
        controller: _ctrl,
        keyboardType: widget.keyboardType,
        maxLines: 1,
        textAlign: TextAlign.end,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hint,
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _save(),
        onEditingComplete: _save,
        onTapOutside: (_) => _save(),
      ),
    );
  }
}

/// Trailing "Open" button for settings whose editor is a richer panel that
/// doesn't reduce to a single inline control (colour grids, async pickers…).
class _OpenTabButton extends StatelessWidget {
  final VoidCallback onTap;
  const _OpenTabButton(this.onTap);

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        elevation: 0,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: Text(AppLocalizations.of(context).setOpen),
    );
  }
}

/// The flat, catalogued index of every individually-addressable setting. The
/// trailing controls reuse the same [appSettingsProvider] plumbing as the tabs,
/// so editing from search and editing in a tab are the same operation.
///
/// Tab indices mirror `_SettingsScreenState._tabs`.
List<SearchableSetting> _kSearchableSettings(
  BuildContext context,
) => <SearchableSetting>[
  // ── General ────────────────────────────────────────────────────────────────
  SearchableSetting(
    title: AppLocalizations.of(context).setDefaultScreen,
    tabName: 'General · Startup',
    tabIndex: 0,
    trailingBuilder: (_) => const _DropdownControl(SettingKeys.defaultScreen, [
      'POS',
      'Tables',
      'Booking',
    ]),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setCurrency,
    tabName: 'General · Regional',
    tabIndex: 0,
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).languageLabel,
    tabName: 'General · Regional',
    tabIndex: 0,
    // Only the languages that actually have an .arb file — offering a code we
    // cannot render is what made this dropdown a no-op for years.
    trailingBuilder: (_) =>
        const _DropdownControl(SettingKeys.language, ['en', 'fr', 'ar']),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).dateFormatLabel,
    tabName: 'General · Regional',
    tabIndex: 0,
    trailingBuilder: (_) => const _DropdownControl(SettingKeys.dateFormat, [
      'dd-MM-yyyy',
      'MM/dd/yyyy',
      'yyyy-MM-dd',
      'dd/MM/yyyy',
    ]),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setTimezone,
    tabName: 'General · Regional',
    tabIndex: 0,
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setTaxIncludedByDefault,
    tabName: 'General · Tax',
    tabIndex: 0,
    // Deliberately NOT a bare _SwitchControl: flipping this on requires a
    // default tax rate, and that gate lives in the real control. Searching for
    // it opens the tab so the operator gets the switch AND the picker.
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setDefaultTaxRate,
    tabName: 'General · Tax',
    tabIndex: 0,
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setThemeMode,
    tabName: 'General · Appearance',
    tabIndex: 0,
    trailingBuilder: (_) => const _ThemeModeControl(),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setAccentColor,
    tabName: 'General · Appearance',
    tabIndex: 0,
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setFontSize,
    tabName: 'General · Appearance',
    tabIndex: 0,
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setWritingDirection,
    tabName: 'General · Application Style',
    tabIndex: 0,
    trailingBuilder: (_) =>
        const _DropdownControl(SettingKeys.writingDirection, ['LTR', 'RTL']),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setEnableVirtualKeyboard,
    tabName: 'General · Application Style',
    tabIndex: 0,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.enableVirtualKeyboard),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setMessageDuration,
    tabName: 'General · Messages',
    tabIndex: 0,
    trailingBuilder: (_) => const _NumericStepper(
      settingKey: SettingKeys.messageDuration,
      min: 1,
      max: 10,
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setMessagePosition,
    tabName: 'General · Messages',
    tabIndex: 0,
    trailingBuilder: (_) =>
        const _DropdownControl(SettingKeys.messagePosition, ['Top', 'Bottom']),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setShowCashInOnStart,
    tabName: 'General · Business Day',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showCashInOnStart),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setSelectBusinessDayOnStart,
    tabName: 'General · Business Day',
    tabIndex: 0,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.selectBusinessDayOnStart),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setSearchButton,
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showSearchBtn),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setTransferButton,
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showTransferBtn),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setCustomerButton,
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showCustomerBtn),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setDiscountButton,
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showDiscountBtn),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setCommentButton,
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showCommentBtn),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setRefundButton,
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showRefundBtn),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setCashDrawerButton,
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showCashDrawerBtn),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setWarehouseSwitcherButton,
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showWarehouseBtn),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setBookingsButton,
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showBookingBtn),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setTablesFloorPlanButton,
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showTablesBtn),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setSendToKitchenButton,
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showKitchenBtn),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setAdditionButton,
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showAdditionBtn),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setTaxButton,
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showTaxBtn),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setChangeQuantityButton,
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showQuantityBtn),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setApiBaseUrl,
    tabName: 'General · API',
    tabIndex: 0,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.apiBaseUrl,
      hint: 'http://192.168.1.1:5002/api',
      keyboardType: TextInputType.url,
    ),
  ),

  // ── Order & Payment ──────────────────────────────────────────────────────────
  SearchableSetting(
    title: AppLocalizations.of(context).setEnableFloorPlan,
    tabName: 'Order & Payment · Features',
    tabIndex: 1,
    trailingBuilder: (_) => _SwitchControl(
      SettingKeys.featureFloorPlanEnabled,
      onChanged: (ref, enabled) {
        if (!enabled) {
          ref
              .read(appSettingsProvider.notifier)
              .setBool(SettingKeys.featureBookingEnabled, false);
        }
      },
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setEnableBookings,
    tabName: 'Order & Payment · Features',
    tabIndex: 1,
    trailingBuilder: (_) => _SwitchControl(
      SettingKeys.featureBookingEnabled,
      onChanged: (ref, enabled) {
        if (enabled) {
          ref
              .read(appSettingsProvider.notifier)
              .setBool(SettingKeys.featureFloorPlanEnabled, true);
        }
      },
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setTablesButtonLabel,
    tabName: 'Order & Payment · Features',
    tabIndex: 1,
    trailingBuilder: (_) => _TextFieldControl(
      SettingKeys.tablesButtonLabel,
      hint: AppLocalizations.of(context).hintTablesRooms,
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setAllowTablelessOrders,
    tabName: 'Order & Payment · Features',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.allowTablelessOrders),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setAllowWalkInTableOrders,
    tabName: 'Order & Payment · Features',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.allowWalkInTableOrders),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setBookingSettings,
    tabName: 'Order & Payment · Booking',
    tabIndex: 1,
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setDefaultSearch,
    tabName: 'Order & Payment · Items',
    tabIndex: 1,
    trailingBuilder: (_) => const _DropdownControl(SettingKeys.defaultSearch, [
      'Name',
      'Code',
      'Barcode',
      'All fields',
    ]),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setShowSearchOptions,
    tabName: 'Order & Payment · Items',
    tabIndex: 1,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showSearchOptions),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setDefaultDiscountType,
    tabName: 'Order & Payment · Items',
    tabIndex: 1,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.defaultDiscountType,
      ['Percentage', 'Fixed'],
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setSeparateRowPerItem,
    tabName: 'Order & Payment · Items',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.separateRowForEachItem),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setPreventSaleBelowCost,
    tabName: 'Order & Payment · Items',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.preventSaleBelowCostPrice),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setPreventNegativeInventory,
    tabName: 'Order & Payment · Items',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.preventNegativeInventory),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setSingleUser,
    tabName: 'Order & Payment · Users',
    tabIndex: 1,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.singleUser),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setShowPrintDialog,
    tabName: 'Order & Payment · Payment',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.displayReceiptPrintDialog),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setDefaultDueDays,
    tabName: 'Order & Payment · Payment',
    tabIndex: 1,
    trailingBuilder: (_) => const _NumericStepper(
      settingKey: SettingKeys.defaultDueDateDays,
      min: 0,
      max: 90,
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setMergeItemsOnReceipt,
    tabName: 'Order & Payment · Payment',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.mergeItemsOnReceipt),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setSingleItemDiscount,
    tabName: 'Order & Payment · Payment',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.singleItemDiscountAllowed),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setRequireReasonOnVoid,
    tabName: 'Order & Payment · Void Items',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.requireReasonOnVoid),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setTrackUnconfirmedVoids,
    tabName: 'Order & Payment · Void Items',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.trackUnconfirmedVoidedItems),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setRequestServiceTypeAuto,
    tabName: 'Order & Payment · Service Type',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.requestServiceTypeAutomatically),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setDefaultServiceType,
    tabName: 'Order & Payment · Service Type',
    tabIndex: 1,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.defaultServiceType,
      ['Dine-in', 'Takeaway', 'Delivery'],
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setPrintLargeOrderNumber,
    tabName: 'Order & Payment · Service Type',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.printLargeOrderNumberInReceipt),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setServiceTypeSelector,
    tabName: 'Order & Payment · Service Type',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.featureServiceTypeEnabled),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setServiceStatusSelector,
    tabName: 'Order & Payment · Service Type',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.featureServiceStatusEnabled),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setResetOrderNumber,
    tabName: 'Order & Payment · Advanced',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.resetOrderNumberOnDayClose),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setShowItemsOnPaymentForm,
    tabName: 'Order & Payment · Advanced',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.showItemsOnPaymentForm),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setPaymentTypeRows,
    tabName: 'Order & Payment · Advanced',
    tabIndex: 1,
    trailingBuilder: (_) => const _NumericStepper(
      settingKey: SettingKeys.numberOfPaymentTypeRows,
      min: 0,
      max: 10,
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setShowAllOccupied,
    tabName: 'Order & Payment · Advanced',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.showAllOccupiedTablesInFloorPlan),
  ),

  // ── Products ─────────────────────────────────────────────────────────────────
  SearchableSetting(
    title: AppLocalizations.of(context).setDisplayPrintTaxIncluded,
    tabName: 'Products · General',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.displayAndPrintTaxIncluded),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setDiscountApplyRule,
    tabName: 'Products · General',
    tabIndex: 2,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.discountApplyRule,
      ['Before tax', 'After tax'],
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setSorting,
    tabName: 'Products · General',
    tabIndex: 2,
    trailingBuilder: (_) => const _DropdownControl(SettingKeys.productSorting, [
      'Name',
      'Code',
      'Barcode',
    ]),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setAllowNegativePrice,
    tabName: 'Products · General',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.allowNegativePrice),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setShowProductImages,
    tabName: 'Products · General',
    tabIndex: 2,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showProductImages),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setDefaultWarehouse,
    tabName: 'Products · Inventory',
    tabIndex: 2,
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setDefaultMeasurementUnit,
    tabName: 'Products · Product Defaults',
    tabIndex: 2,
    trailingBuilder: (_) => _TextFieldControl(
      SettingKeys.defaultMeasurementUnit,
      hint: AppLocalizations.of(context).hintUnitsExample,
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setDefaultBarcodeFormat,
    tabName: 'Products · Product Defaults',
    tabIndex: 2,
    trailingBuilder: (_) => const _DropdownControl(SettingKeys.barcodeFormat, [
      'EAN-13',
      'EAN-8',
      'UPC-A',
      'Code128',
      'QR',
    ]),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setCostPriceMarkup,
    tabName: 'Products · Product Defaults',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.costPriceBasedMarkup),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setAutoUpdateCostPrice,
    tabName: 'Products · Product Defaults',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.autoUpdateCostPrice),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setUpdateSalePriceFromMarkup,
    tabName: 'Products · Product Defaults',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.updateSalePriceOnMarkup),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setEnableMovingAverage,
    tabName: 'Products · Moving Average Price',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.enableMovingAveragePrice),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setMenuLayout,
    tabName: 'Products · Menu Grid',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _DropdownControl(SettingKeys.menuLayoutMode, ['List', 'Grid']),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setMenuGridColumns,
    tabName: 'Products · Menu Grid',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _DropdownControl(SettingKeys.menuGridCols, ['4', '5']),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setMenuGridRows,
    tabName: 'Products · Menu Grid',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _DropdownControl(SettingKeys.menuGridRows, ['3', '4', '5']),
  ),

  // ── Weighing Scale ───────────────────────────────────────────────────────────
  SearchableSetting(
    title: AppLocalizations.of(context).setEnableScaleBarcode,
    tabName: 'Weighing Scale · Barcode Parsing',
    tabIndex: 3,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.scaleBarcodeEnabled),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setFirstTwoDigits,
    tabName: 'Weighing Scale · Barcode Parsing',
    tabIndex: 3,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.scaleBarcodePrefix,
      hint: 'e.g. 21',
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setProductCodeDigits,
    tabName: 'Weighing Scale · Barcode Parsing',
    tabIndex: 3,
    trailingBuilder: (_) => const _NumericStepper(
      settingKey: SettingKeys.scaleBarcodeCodeLength,
      min: 1,
      max: 10,
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setNumberOfDecimals,
    tabName: 'Weighing Scale · Barcode Parsing',
    tabIndex: 3,
    trailingBuilder: (_) => const _NumericStepper(
      settingKey: SettingKeys.scaleBarcodeDecimalPlaces,
      min: 0,
      max: 5,
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).trimZerosFromCode,
    tabName: 'Weighing Scale · Barcode Parsing',
    tabIndex: 3,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.scaleBarcodeTrimZeros),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setScalePrintsPrice,
    tabName: 'Weighing Scale · Barcode Parsing',
    tabIndex: 3,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.scaleBarcodePrintsPrice),
  ),

  // ── Customer Display ─────────────────────────────────────────────────────────
  SearchableSetting(
    title: AppLocalizations.of(context).setCustomerDisplayEnabled,
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.customerDisplayEnabled),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setComPort,
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) =>
        const _DropdownControl(SettingKeys.customerDisplayPort, [
          'COM1',
          'COM2',
          'COM3',
          'COM4',
          'COM5',
          'COM6',
          'COM7',
          'COM8',
          'COM9',
          'COM10',
        ]),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setBitsPerSecond,
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.customerDisplayBaudRate,
      ['1200', '2400', '4800', '9600', '19200', '38400', '57600', '115200'],
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setDataBits,
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.customerDisplayDataBits,
      ['5', '6', '7', '8'],
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setParity,
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.customerDisplayParity,
      ['None', 'Even', 'Odd', 'Mark', 'Space'],
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setStopBits,
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.customerDisplayStopBits,
      ['1', '1.5', '2'],
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setFlowControl,
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.customerDisplayFlowControl,
      ['None', 'RTS/CTS', 'XON/XOFF'],
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setNumberOfCharacters,
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) => const _NumericStepper(
      settingKey: SettingKeys.customerDisplayNumChars,
      min: 1,
      max: 40,
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setWelcomeTopLine,
    tabName: 'Customer Display · Welcome Message',
    tabIndex: 4,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.customerDisplayWelcomeMessage,
      hint: 'WELCOME!',
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setWelcomeBottomLine,
    tabName: 'Customer Display · Welcome Message',
    tabIndex: 4,
    trailingBuilder: (_) =>
        const _TextFieldControl(SettingKeys.customerDisplayWelcomeBottom),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setEnableLiveWebDisplay,
    tabName: 'Customer Display · Screen Display (Web)',
    tabIndex: 4,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.customerDisplayWebEnabled),
  ),

  // ── Email ────────────────────────────────────────────────────────────────────
  SearchableSetting(
    title: AppLocalizations.of(context).setSmtpHost,
    tabName: 'Email · SMTP Server',
    tabIndex: 6,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.emailSmtpHost,
      hint: 'smtp.gmail.com',
      keyboardType: TextInputType.url,
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setSmtpPort,
    tabName: 'Email · SMTP Server',
    tabIndex: 6,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.emailSmtpPort,
      hint: '587',
      keyboardType: TextInputType.number,
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setFromEmailAddress,
    tabName: 'Email · Sender',
    tabIndex: 6,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.emailFromAddress,
      hint: 'pos@yourbusiness.com',
      keyboardType: TextInputType.emailAddress,
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setFromName,
    tabName: 'Email · Sender',
    tabIndex: 6,
    trailingBuilder: (_) => _TextFieldControl(
      SettingKeys.emailFromName,
      hint: AppLocalizations.of(context).posSystem,
    ),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).accountUserEmail,
    tabName: 'Email · Sender',
    tabIndex: 6,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.emailUserEmail,
      hint: 'your@email.com',
      keyboardType: TextInputType.emailAddress,
    ),
  ),

  // ── Dual Currency ────────────────────────────────────────────────────────────
  SearchableSetting(
    title: AppLocalizations.of(context).setDualCurrencyEnabled,
    tabName: 'Dual Currency',
    tabIndex: 8,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.dualCurrencyEnabled),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setSecondaryCurrencySymbol,
    tabName: 'Dual Currency',
    tabIndex: 8,
    trailingBuilder: (_) =>
        const _TextFieldControl(SettingKeys.dualCurrencySymbol, hint: 'e.g. €'),
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setExchangeRate,
    tabName: 'Dual Currency',
    tabIndex: 8,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.dualCurrencyRate,
      hint: 'e.g. 1.08',
      keyboardType: TextInputType.numberWithOptions(decimal: true),
    ),
  ),

  // ── Whole-screen panels (tap the row to open the tab) ────────────────────────
  SearchableSetting(
    title: AppLocalizations.of(context).setKitchenDisplay,
    tabName: 'Kitchen Display',
    tabIndex: 5,
    navigational: true,
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setPrinterReceiptSettings,
    tabName: 'Print',
    tabIndex: 7,
    navigational: true,
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setDatabaseBackup,
    tabName: 'Database',
    tabIndex: 9,
    navigational: true,
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setSubscription,
    tabName: 'Subscription',
    tabIndex: 10,
    navigational: true,
  ),
  SearchableSetting(
    title: AppLocalizations.of(context).setAbout,
    tabName: 'About',
    tabIndex: 11,
    navigational: true,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// TAB IMPLEMENTATIONS
// ─────────────────────────────────────────────────────────────────────────────

class _TabScrollView extends StatelessWidget {
  final List<Widget> cards;
  const _TabScrollView({required this.cards});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cards,
      ),
    );
  }
}

// Localized display names for enum-ish settings values that are STORED in
// English (theme keys, accent names, dropdown option values). The stored value
// never changes; only what the operator sees is translated. Unknown values
// (COM ports, EAN formats, currency codes, date patterns) pass through as-is.
String _accentColorLabel(BuildContext context, String name) {
  final l = AppLocalizations.of(context);
  switch (name) {
    case 'Blue':
      return l.colorBlue;
    case 'Green':
      return l.colorGreen;
    case 'Pink':
      return l.colorPink;
    case 'Purple':
      return l.colorPurple;
    case 'Orange':
      return l.colorOrange;
    case 'Red':
      return l.colorRed;
    default:
      return name;
  }
}

String _themeModeLabel(BuildContext context, String key) {
  final l = AppLocalizations.of(context);
  switch (key) {
    case 'light':
      return l.themeLight;
    case 'dark':
      return l.themeDark;
    case 'dimmed':
      return l.themeDimmed;
    case 'night':
      return l.themeNight;
    case 'gray':
      return l.themeGray;
    case 'high_contrast':
      return l.themeHighContrast;
    default:
      return key;
  }
}

String _settingOptionLabel(BuildContext context, String value) {
  final l = AppLocalizations.of(context);
  switch (value) {
    case 'en':
      return 'ENGLISH';
    case 'fr':
      return 'FRANÇAIS';
    case 'ar':
      return 'العربية';
    case 'POS':
      return l.posLabel;
    case 'Tables':
      return l.tablesLabel;
    case 'Booking':
      return l.bookingLabel;
    case 'Name':
      return l.fieldName;
    case 'Code':
      return l.fieldCode;
    case 'Barcode':
      return l.barcode;
    case 'All fields':
      return l.allFields;
    case 'Fixed':
      return l.fixed;
    case 'Percentage':
      return l.percentage;
    case 'Top':
      return l.top;
    case 'Bottom':
      return l.bottom;
    case 'After every save':
      return l.syncAfterEverySave;
    case 'Every 1 hour':
      return l.syncEveryHour;
    case 'Before tax':
      return l.beforeTax;
    case 'After tax':
      return l.afterTax;
    case 'List':
      return l.listLabel;
    case 'Grid':
      return l.gridLabel;
    default:
      return value; // technical values stay verbatim
  }
}

// ── Accent Color Picker ───────────────────────────────────────────────────────

class _AccentColorPicker extends ConsumerWidget {
  const _AccentColorPicker();

  // Replace the old list with these 6 main colors
  static const _colors = [
    ('Blue', Color(0xFF2196F3)),
    ('Green', Color(0xFF4CAF50)),
    ('Pink', Color(0xFFE91E63)),
    ('Purple', Color(0xFF9C27B0)),
    ('Orange', Color(0xFFFF9800)),
    ('Red', Color(0xFFF44336)),
  ];

  static String _toHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  static Color? _fromHex(String? hex) {
    if (hex == null) return null;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final current = _fromHex(settings[SettingKeys.themeAccentColor]);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).setAccentColor,
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _colors.map<Widget>((entry) {
              final (name, color) = entry;
              final isSelected =
                  current != null && color.toARGB32() == current.toARGB32();
              return GestureDetector(
                onTap: () => ref
                    .read(appSettingsProvider.notifier)
                    .set(SettingKeys.themeAccentColor, _toHex(color)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _accentColorLabel(context, name),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Font Scale Picker ─────────────────────────────────────────────────────────

/// Slider that scales every Text in the app. The multiplier is a per-terminal
/// preference stored locally (NOT cloud-synced) via [fontScaleProvider], which
/// main.dart reads into a global MediaQuery textScaler.
class _FontScalePicker extends ConsumerWidget {
  const _FontScalePicker();

  static const _min = kFontScaleMin;
  static const _max = kFontScaleMax;

  String _label(BuildContext context, double v) {
    final l10n = AppLocalizations.of(context);
    if (v <= 0.85) return l10n.fontSizeSmall;
    if (v < 1.05) return l10n.fontSizeDefault;
    if (v < 1.2) return l10n.fontSizeLarge;
    return l10n.fontSizeLarger;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final value = ref.watch(fontScaleProvider).clamp(_min, _max);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context).setFontSize,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${_label(context, value)}  (${(value * 100).round()}%)',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: _min,
            max: _max,
            // 0.8 → 1.3 in 0.05 steps = 10 divisions.
            divisions: 10,
            label: '${(value * 100).round()}%',
            // Live update on drag; flush to disk when the drag settles.
            onChanged: (v) => ref.read(fontScaleProvider.notifier).set(v),
            onChangeEnd: (v) =>
                ref.read(fontScaleProvider.notifier).setAndPersist(v),
          ),
          Text(
            AppLocalizations.of(context).fontPreview,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Theme Mode Picker ─────────────────────────────────────────────────────────

class _ThemeOpt {
  final String key;
  final String label;
  final IconData icon;
  final Color previewBg;
  final Color previewAccent;
  const _ThemeOpt(
    this.key,
    this.label,
    this.icon,
    this.previewBg,
    this.previewAccent,
  );
}

class _ThemeModePicker extends ConsumerWidget {
  const _ThemeModePicker();

  static final _options = <_ThemeOpt>[
    const _ThemeOpt(
      'light',
      'Light',
      PhosphorIconsRegular.sun,
      Color(0xFFF5F7FA),
      Color(0xFF2196F3),
    ),
    const _ThemeOpt(
      'dark',
      'Dark',
      PhosphorIconsRegular.moon,
      Color(0xFF1E2530),
      Color(0xFF90CAF9),
    ),
    const _ThemeOpt(
      'dimmed',
      'Dimmed',
      PhosphorIconsRegular.moonStars,
      Color(0xFF15202B),
      Color(0xFF64B5F6),
    ),
    const _ThemeOpt(
      'night',
      'Night',
      PhosphorIconsRegular.eye,
      Color(0xFF000000),
      Color(0xFF82B1FF),
    ),
    const _ThemeOpt(
      'gray',
      'Gray',
      PhosphorIconsRegular.circleHalf,
      Color(0xFF1E1E1E),
      Color(0xFFBDBDBD),
    ),
    const _ThemeOpt(
      'high_contrast',
      'High Contrast',
      PhosphorIconsRegular.circleHalfTilt,
      Color(0xFF000000),
      Color(0xFFFFFFFF),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final current = settings[SettingKeys.themeMode] ?? 'dark';
    final opt = _options.firstWhere(
      (o) => o.key == current,
      orElse: () => _options[1],
    );
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).setThemeMode,
            style: TextStyle(fontSize: 14, color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _show(context, ref, current),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(opt.icon, size: 17, color: cs.primary),
                  const SizedBox(width: 10),
                  Text(
                    _themeModeLabel(context, opt.key),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  _MiniPreview(bg: opt.previewBg, accent: opt.previewAccent),
                  const SizedBox(width: 10),
                  Icon(
                    PhosphorIconsRegular.caretDown,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _show(BuildContext context, WidgetRef ref, String current) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _ThemePickerDialog(
        options: _options,
        current: current,
        onSelect: (key) {
          ref
              .read(appSettingsProvider.notifier)
              .set(SettingKeys.themeMode, key);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _MiniPreview extends StatelessWidget {
  final Color bg;
  final Color accent;
  const _MiniPreview({required this.bg, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 26,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: bg == const Color(0xFFF5F7FA)
                  ? const Color(0xFFE0E0E0)
                  : Colors.black.withValues(alpha: 0.35),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: 2,
                          width: 12,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemePickerDialog extends StatelessWidget {
  final List<_ThemeOpt> options;
  final String current;
  final void Function(String) onSelect;

  const _ThemePickerDialog({
    required this.options,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 300,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF16202E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 48,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.palette,
                    size: 14,
                    color: Colors.white38,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    AppLocalizations.of(context).chooseTheme,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 4),
            ...options.map((opt) {
              final selected = opt.key == current;
              return _OptionTile(
                opt: opt,
                selected: selected,
                onTap: () => onSelect(opt.key),
              );
            }),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final _ThemeOpt opt;
  final bool selected;
  final VoidCallback onTap;
  const _OptionTile({
    required this.opt,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          splashColor: Colors.white.withValues(alpha: 0.07),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  opt.icon,
                  size: 17,
                  color: selected ? Colors.white : Colors.white54,
                ),
                const SizedBox(width: 12),
                Text(
                  _themeModeLabel(context, opt.key),
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const Spacer(),
                _MiniPreview(bg: opt.previewBg, accent: opt.previewAccent),
                const SizedBox(width: 10),
                SizedBox(
                  width: 16,
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Device Registration Card ──────────────────────────────────────────────────

class _DeviceCard extends ConsumerStatefulWidget {
  const _DeviceCard();

  @override
  ConsumerState<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<_DeviceCard> {
  String? _email;

  @override
  void initState() {
    super.initState();
    ref.read(authStorageProvider).getRegisteredEmail().then((e) {
      if (mounted) setState(() => _email = e);
    });
  }

  Future<void> _signOut() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).setSignOutDevice),
        content: Text(
          _email != null
              ? AppLocalizations.of(context).unlinkEmailWarning(_email!)
              : AppLocalizations.of(context).unlinkTerminalWarning,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).setSignOutDevice),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Release this terminal's seat BEFORE wiping the token (the call needs it).
    // Best-effort — offline sign-out is reclaimed by the server-side reaper.
    await ref.read(authServiceProvider).releaseDeviceSeat();
    await ref.read(authStorageProvider).unlinkDevice();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MasterLoginScreen()),
      (_) => false,
    );
  }

  Future<void> _editDeviceName() async {
    // The dialog owns its TextEditingController via a StatefulWidget so it's
    // disposed only when the route is fully removed (after the close
    // animation). Disposing it inline right after showDialog() returns raced
    // the exit animation — a rebuild during it touched the disposed controller
    // ("used after being disposed").
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          _DeviceNameDialog(initial: ref.read(deviceNameProvider)),
    );
    if (result == null || !mounted) return;
    await ref.read(deviceNameProvider.notifier).setName(result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deviceName = ref.watch(deviceNameProvider);

    return _SettingsCard(
      title: AppLocalizations.of(context).setDevice,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: CircleAvatar(
            backgroundColor: cs.secondaryContainer,
            child: Icon(
              Icons.point_of_sale,
              color: cs.onSecondaryContainer,
              size: 20,
            ),
          ),
          title: Text(
            deviceName.isEmpty
                ? AppLocalizations.of(context).notSet
                : deviceName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(AppLocalizations.of(context).setPosNameHint),
          trailing: TextButton.icon(
            icon: const Icon(Icons.edit, size: 16),
            label: Text(AppLocalizations.of(context).actionEdit),
            onPressed: _editDeviceName,
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Icon(
              Icons.person_outline,
              color: cs.onPrimaryContainer,
              size: 20,
            ),
          ),
          title: Text(
            _email ?? AppLocalizations.of(context).unknownLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(AppLocalizations.of(context).setRegisteredAccount),
          trailing: TextButton.icon(
            icon: Icon(Icons.logout, size: 16, color: cs.error),
            label: Text(
              AppLocalizations.of(context).setSignOut,
              style: TextStyle(color: cs.error),
            ),
            onPressed: _signOut,
          ),
        ),
      ],
    );
  }
}

// ── General ──────────────────────────────────────────────────────────────────
class _GeneralTab extends ConsumerWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final floorPlanEnabled =
        settings[SettingKeys.featureFloorPlanEnabled]?.toLowerCase() == 'true';
    final bookingEnabled =
        settings[SettingKeys.featureBookingEnabled]?.toLowerCase() == 'true';
    // POS is always available; Tables / Booking appear only when enabled.
    final defaultScreenOptions = <String>[
      'POS',
      if (floorPlanEnabled) 'Tables',
      if (bookingEnabled) 'Booking',
    ];

    return _TabScrollView(
      cards: [
        const _DeviceCard(),
        _SettingsCard(
          title: AppLocalizations.of(context).setStartup,
          children: [
            _SettingDropdown(
              settingKey: SettingKeys.defaultScreen,
              label: AppLocalizations.of(context).setDefaultScreen,
              options: defaultScreenOptions,
            ),
          ],
        ),
        _SettingsCard(
          // <-- Make sure to remove the 'const' keyword here
          title: AppLocalizations.of(context).setRegional,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive: 2 columns on tablets/desktops (>600px), 1 column on phones
                final isWide = constraints.maxWidth > 600;
                final itemWidth = isWide
                    ? constraints.maxWidth / 2
                    : constraints.maxWidth;

                return Wrap(
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: const _CurrencyDropdown(),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _SettingDropdown(
                        settingKey: SettingKeys.language,
                        label: AppLocalizations.of(context).languageLabel,
                        // Must stay in sync with lib/l10n/*.arb — see the
                        // matching list in the searchable-settings index.
                        options: const ['en', 'fr', 'ar'],
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _SettingDropdown(
                        settingKey: SettingKeys.dateFormat,
                        label: AppLocalizations.of(context).dateFormatLabel,
                        options: const [
                          'dd-MM-yyyy',
                          'MM/dd/yyyy',
                          'yyyy-MM-dd',
                          'dd/MM/yyyy',
                        ],
                      ),
                    ),
                    SizedBox(width: itemWidth, child: const _TimezoneCard()),
                  ],
                );
              },
            ),
            const SizedBox(height: 8), // Bottom padding buffer
          ],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setTaxHeader,
          children: const [
            // The switch and the picker are one feature: the switch is
            // meaningless without a rate to apply, so they sit together. The
            // picker used to live in the Products tab.
            _TaxIncludedByDefaultSwitch(),
            _DefaultTaxRatesSelector(),
          ],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setAppearance,
          children: const [
            _ThemeModePicker(),
            _AccentColorPicker(),
            _FontScalePicker(),
          ],
        ),
        _SettingsCard(
          // <-- Make sure to remove the 'const' keyword here
          title: AppLocalizations.of(context).setApplicationStyle,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive: 2 columns on tablets/desktops (>600px), 1 column on phones
                final isWide = constraints.maxWidth > 600;
                final itemWidth = isWide
                    ? constraints.maxWidth / 2
                    : constraints.maxWidth;

                return Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _SettingDropdown(
                        settingKey: SettingKeys.writingDirection,
                        label: AppLocalizations.of(context).setWritingDirection,
                        options: const ['LTR', 'RTL'],
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _SettingSwitch(
                        settingKey: SettingKeys.enableVirtualKeyboard,
                        label: AppLocalizations.of(
                          context,
                        ).setEnableVirtualKeyboard,
                        icon: Icons
                            .keyboard_outlined, // Added an icon for consistency
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8), // Bottom padding buffer
          ],
        ),
        _SettingsCard(
          // <-- Make sure to remove the 'const' keyword here
          title: AppLocalizations.of(context).setMessages,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive: 2 columns on tablets/desktops (>600px), 1 column on phones
                final isWide = constraints.maxWidth > 600;
                final itemWidth = isWide
                    ? constraints.maxWidth / 2
                    : constraints.maxWidth;

                return Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _StepperRow(
                        label: AppLocalizations.of(context).setMessageDuration,
                        settingKey: SettingKeys.messageDuration,
                        min: 1,
                        max: 10,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _SettingDropdown(
                        settingKey: SettingKeys.messagePosition,
                        label: AppLocalizations.of(context).setMessagePosition,
                        options: const ['Top', 'Bottom'],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8), // Bottom padding buffer
          ],
        ),
        _SettingsCard(
          // <-- Make sure to remove the 'const' keyword here
          title: AppLocalizations.of(context).setBusinessDay,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive: 2 columns on tablets/desktops (>600px), 1 column on phones
                final isWide = constraints.maxWidth > 600;
                final itemWidth = isWide
                    ? constraints.maxWidth / 2
                    : constraints.maxWidth;

                return Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _SettingSwitch(
                        settingKey: SettingKeys.showCashInOnStart,
                        label: AppLocalizations.of(
                          context,
                        ).setShowCashInOnStart,
                        icon: Icons.payments_outlined, // <-- Added icon here
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _SettingSwitch(
                        settingKey: SettingKeys.selectBusinessDayOnStart,
                        label: AppLocalizations.of(
                          context,
                        ).setSelectBusinessDayOnStart,
                        icon: Icons
                            .calendar_today_outlined, // <-- Added icon here
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8), // Bottom padding buffer
          ],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setPosButtonBar,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                AppLocalizations.of(context).posButtonsHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive: 2 columns on tablets/desktops (>600px), 1 column on phones
                final isWide = constraints.maxWidth > 600;
                final itemWidth = isWide
                    ? constraints.maxWidth / 2
                    : constraints.maxWidth;

                final posButtons = [
                  (
                    key: SettingKeys.showSearchBtn,
                    label: AppLocalizations.of(context).actionSearch,
                    icon: Icons.search,
                  ),
                  (
                    key: SettingKeys.showTransferBtn,
                    label: AppLocalizations.of(context).posTransfer,
                    icon: Icons.swap_horiz,
                  ),
                  (
                    key: SettingKeys.showCustomerBtn,
                    label: AppLocalizations.of(context).customerLabel,
                    icon: Icons.person_outline,
                  ),
                  (
                    key: SettingKeys.showDiscountBtn,
                    label: AppLocalizations.of(context).posDiscount,
                    icon: Icons.local_offer_outlined,
                  ),
                  (
                    key: SettingKeys.showCommentBtn,
                    label: AppLocalizations.of(context).posComment,
                    icon: Icons.chat_bubble_outline,
                  ),
                  (
                    key: SettingKeys.showRefundBtn,
                    label: AppLocalizations.of(context).posRefund,
                    icon: Icons.assignment_return_outlined,
                  ),
                  (
                    key: SettingKeys.showCashDrawerBtn,
                    label: AppLocalizations.of(context).setCashDrawer,
                    icon: Icons.point_of_sale,
                  ),
                  (
                    key: SettingKeys.showWarehouseBtn,
                    label: AppLocalizations.of(context).setWarehouseSwitcher,
                    icon: Icons.warehouse_outlined,
                  ),
                  (
                    key: SettingKeys.showBookingBtn,
                    label: AppLocalizations.of(context).posBookings,
                    icon: Icons.calendar_month_outlined,
                  ),
                  (
                    key: SettingKeys.showTablesBtn,
                    label: AppLocalizations.of(context).setTablesFloorPlan,
                    icon: Icons.table_restaurant_outlined,
                  ),
                  (
                    key: SettingKeys.showKitchenBtn,
                    label: AppLocalizations.of(context).setSendToKitchen,
                    icon: Icons.kitchen_outlined,
                  ),
                  (
                    key: SettingKeys.showAdditionBtn,
                    label: AppLocalizations.of(context).posAddition,
                    icon: Icons.receipt_long_outlined,
                  ),
                  (
                    key: SettingKeys.showTaxBtn,
                    label: AppLocalizations.of(context).fieldTax,
                    icon: Icons.account_balance_outlined,
                  ),
                  (
                    key: SettingKeys.showQuantityBtn,
                    label: AppLocalizations.of(context).setChangeQuantity,
                    icon: Icons.numbers,
                  ),
                ];

                return Wrap(
                  children: posButtons.map((btn) {
                    return SizedBox(
                      width: itemWidth,
                      child: _SettingSwitch(
                        settingKey: btn.key,
                        label: btn.label,
                        icon: btn.icon,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 8), // Bottom padding buffer
          ],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setApi,
          children: [
            _SettingTextField(
              settingKey: SettingKeys.apiBaseUrl,
              label: AppLocalizations.of(context).setApiBaseUrl,
              hint: 'http://192.168.1.1:5002/api',
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Order & Payment ───────────────────────────────────────────────────────────
class _OrderPaymentTab extends ConsumerWidget {
  const _OrderPaymentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final typeEnabled =
        settings[SettingKeys.featureServiceTypeEnabled]?.toLowerCase() ==
        'true';
    final statusEnabled =
        settings[SettingKeys.featureServiceStatusEnabled]?.toLowerCase() ==
        'true';
    final floorPlanEnabled =
        settings[SettingKeys.featureFloorPlanEnabled]?.toLowerCase() == 'true';
    // Helper method to wrap card children in a responsive 2-column grid
    Widget buildGrid(List<Widget> children) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          final itemWidth = isWide
              ? constraints.maxWidth / 2
              : constraints.maxWidth;

          return Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children
                .map((child) => SizedBox(width: itemWidth, child: child))
                .toList(),
          );
        },
      );
    }

    return _TabScrollView(
      cards: [
        _SettingsCard(
          title: AppLocalizations.of(context).setFeatures,
          children: [
            buildGrid([
              _SettingSwitch(
                settingKey: SettingKeys.featureFloorPlanEnabled,
                label: AppLocalizations.of(context).setEnableFloorPlan,
                subtitle: AppLocalizations.of(context).setShowTablesButton,
                icon: Icons.table_bar_outlined,
                onChanged: (ref, enabled) {
                  if (!enabled) {
                    ref
                        .read(appSettingsProvider.notifier)
                        .setBool(SettingKeys.featureBookingEnabled, false);
                  }
                },
              ),
              _SettingSwitch(
                settingKey: SettingKeys.featureBookingEnabled,
                label: AppLocalizations.of(context).setEnableBookings,
                subtitle: AppLocalizations.of(context).setRequiresFloorPlan,
                icon: Icons.edit_calendar_outlined,
                onChanged: (ref, enabled) {
                  if (enabled) {
                    ref
                        .read(appSettingsProvider.notifier)
                        .setBool(SettingKeys.featureFloorPlanEnabled, true);
                  }
                },
              ),
              _SettingTextField(
                settingKey: SettingKeys.tablesButtonLabel,
                label: AppLocalizations.of(context).setTablesButtonLabel,
                hint: AppLocalizations.of(context).hintTablesRooms,
              ),
              _SettingSwitch(
                settingKey: SettingKeys.allowTablelessOrders,
                label: AppLocalizations.of(context).setAllowTablelessOrders,
                subtitle: AppLocalizations.of(context).setWalkInHint,
                enabled: floorPlanEnabled,
                icon: Icons.no_meals_outlined,
              ),
              _SettingSwitch(
                settingKey: SettingKeys.allowWalkInTableOrders,
                label: AppLocalizations.of(context).setAllowWalkInTableOrders,
                subtitle: AppLocalizations.of(context).setStartOrderFreeTable,
                enabled: floorPlanEnabled,
                icon: Icons.directions_walk_outlined,
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
        const _BookingSettingsCard(),
        _SettingsCard(
          title: AppLocalizations.of(context).setItems,
          children: [
            buildGrid([
              _SettingDropdown(
                settingKey: SettingKeys.defaultSearch,
                label: AppLocalizations.of(context).setDefaultSearch,
                options: const ['Name', 'Code', 'Barcode', 'All fields'],
              ),
              _SettingSwitch(
                settingKey: SettingKeys.showSearchOptions,
                label: AppLocalizations.of(context).setShowSearchOptions,
                icon: Icons.manage_search_outlined,
              ),
              _SettingDropdown(
                settingKey: SettingKeys.defaultDiscountType,
                label: AppLocalizations.of(context).setDefaultDiscountType,
                options: const ['Percentage', 'Fixed'],
              ),
              _SettingSwitch(
                settingKey: SettingKeys.separateRowForEachItem,
                label: AppLocalizations.of(context).setSeparateRowPerItem,
                icon: Icons.format_list_bulleted_outlined,
              ),
              _SettingSwitch(
                settingKey: SettingKeys.preventSaleBelowCostPrice,
                label: AppLocalizations.of(context).setPreventSaleBelowCost,
                icon: Icons.money_off_outlined,
              ),
              _SettingSwitch(
                settingKey: SettingKeys.preventNegativeInventory,
                label: AppLocalizations.of(context).setPreventNegativeInventory,
                icon: Icons.inventory_2_outlined,
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setUsers,
          children: [
            buildGrid([
              _SettingSwitch(
                settingKey: SettingKeys.singleUser,
                label: AppLocalizations.of(context).setSingleUser,
                icon: Icons.person_outline,
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setPayment,
          children: [
            buildGrid([
              _SettingSwitch(
                settingKey: SettingKeys.displayReceiptPrintDialog,
                label: AppLocalizations.of(context).setShowPrintDialog,
                icon: Icons.receipt_long_outlined,
              ),
              _StepperRow(
                label: AppLocalizations.of(context).setDefaultDueDays,
                settingKey: SettingKeys.defaultDueDateDays,
                min: 0,
                max: 90,
              ),
              _SettingSwitch(
                settingKey: SettingKeys.mergeItemsOnReceipt,
                label: AppLocalizations.of(context).setMergeItemsOnReceipt,
                icon: Icons.merge_type_outlined,
              ),
              _SettingSwitch(
                settingKey: SettingKeys.singleItemDiscountAllowed,
                label: AppLocalizations.of(context).setSingleItemDiscount,
                icon: Icons.local_offer_outlined,
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
        // ── POS session ───────────────────────────────────────────────────
        // 🚨 Both settings here decide what happens at CLOSING. Without the
        // cash methods the till has to guess which tenders came out of the
        // drawer, and a mis-guess moves money between "counted" and merely
        // "confirmed" — which is why the session screen nags until this is set
        // rather than quietly carrying on.
        _SettingsCard(
          title: AppLocalizations.of(context).setPosSession,
          children: const [
            _CashPaymentMethodsSelector(),
            Divider(height: 24),
            _MaxCashDifferenceField(),
            SizedBox(height: 8),
          ],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setVoidItems,
          children: [
            buildGrid([
              _SettingSwitch(
                settingKey: SettingKeys.requireReasonOnVoid,
                label: AppLocalizations.of(context).setRequireReasonOnVoid,
                icon: Icons.remove_circle_outline,
              ),
              _SettingSwitch(
                settingKey: SettingKeys.trackUnconfirmedVoidedItems,
                label: AppLocalizations.of(context).setTrackUnconfirmedVoids,
                icon: Icons.track_changes_outlined,
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setServiceTypeHeader,
          children: [
            buildGrid([
              _SettingSwitch(
                settingKey: SettingKeys.requestServiceTypeAutomatically,
                label: AppLocalizations.of(context).setRequestServiceTypeAuto,
                icon: Icons.room_service_outlined,
              ),
              _SettingDropdown(
                settingKey: SettingKeys.defaultServiceType,
                label: AppLocalizations.of(context).setDefaultServiceType,
                options: const ['Dine-in', 'Takeaway', 'Delivery'],
              ),
              _SettingSwitch(
                settingKey: SettingKeys.printLargeOrderNumberInReceipt,
                label: AppLocalizations.of(context).setPrintLargeOrderNumber,
                icon: Icons.numbers_outlined,
              ),
              _SettingSwitch(
                settingKey: SettingKeys.featureServiceTypeEnabled,
                label: AppLocalizations.of(context).setServiceTypeSelector,
                subtitle: AppLocalizations.of(context).setShowOrderTypeButtons,
                icon: Icons.touch_app_outlined,
              ),
            ]),
            Opacity(
              opacity: typeEnabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !typeEnabled,
                child: const _CustomServiceTypesEditor(),
              ),
            ),
            buildGrid([
              _SettingSwitch(
                settingKey: SettingKeys.featureServiceStatusEnabled,
                label: AppLocalizations.of(context).setServiceStatusSelector,
                subtitle: AppLocalizations.of(
                  context,
                ).setShowServiceStatusBadge,
                icon: Icons.toggle_on_outlined,
              ),
            ]),
            Opacity(
              opacity: statusEnabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !statusEnabled,
                child: const _CustomServiceStatusesEditor(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setAdvancedSettings,
          children: [
            buildGrid([
              _SettingSwitch(
                settingKey: SettingKeys.resetOrderNumberOnDayClose,
                label: AppLocalizations.of(context).setResetOrderNumber,
                icon: Icons.restart_alt_outlined,
              ),
              _SettingSwitch(
                settingKey: SettingKeys.showItemsOnPaymentForm,
                label: AppLocalizations.of(context).setShowItemsOnPaymentForm,
                icon: Icons.list_alt_outlined,
              ),
              _StepperRow(
                label: AppLocalizations.of(context).setPaymentTypeRows,
                settingKey: SettingKeys.numberOfPaymentTypeRows,
                min: 0,
                max: 10,
              ),
              _SettingSwitch(
                settingKey: SettingKeys.showAllOccupiedTablesInFloorPlan,
                label: AppLocalizations.of(context).setShowAllOccupied,
                icon: Icons.event_seat_outlined,
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ],
    );
  }
}

// ── Products ──────────────────────────────────────────────────────────────────

/// The "Tax Included in Price by Default" switch, with the invariant that
/// makes the rest of the feature safe to build on: **ON implies at least one
/// default tax rate is configured.**
///
/// Flipping it on with nothing selected does not write `true` and bounce back
/// — it opens the picker first and only commits if the operator actually
/// chooses a rate. Everything downstream (the product editor's pre-fill, the
/// read-only cart dialog) can therefore treat "switch is on" as "there is a
/// tax to show" and skip the empty branch entirely.
class _TaxIncludedByDefaultSwitch extends ConsumerWidget {
  const _TaxIncludedByDefaultSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final value =
        settings[SettingKeys.taxIncludedByDefault]?.toLowerCase() == 'true';

    return SwitchListTile(
      title: Text(l.setTaxIncludedByDefault),
      subtitle: Text(l.setTaxInclusiveDefaultHint),
      value: value,
      activeThumbColor: theme.colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onChanged: (v) async {
        final notifier = ref.read(appSettingsProvider.notifier);

        // Turning it OFF is always allowed, and deliberately leaves
        // DefaultTaxRateIds untouched so flipping back ON restores the same
        // configuration instead of asking again.
        if (!v) {
          await notifier.setBool(SettingKeys.taxIncludedByDefault, false);
          return;
        }

        final alreadyConfigured = parseDefaultTaxRateIds(
          settings[SettingKeys.defaultTaxRateIds],
        ).isNotEmpty;
        if (alreadyConfigured) {
          await notifier.setBool(SettingKeys.taxIncludedByDefault, true);
          return;
        }

        final picked = await showDialog<bool>(
          context: context,
          builder: (_) => const _DefaultTaxRatePickerDialog(),
        );
        // Cancelled, or dismissed without choosing — the switch never moves.
        if (picked != true) return;
        await notifier.setBool(SettingKeys.taxIncludedByDefault, true);
      },
    );
  }
}

/// Modal shown when the tax-inclusive switch is turned on with no default tax
/// configured. Pops `true` only once at least one rate is selected AND saved,
/// which is the signal [_TaxIncludedByDefaultSwitch] needs to commit the flip.
class _DefaultTaxRatePickerDialog extends ConsumerStatefulWidget {
  const _DefaultTaxRatePickerDialog();

  @override
  ConsumerState<_DefaultTaxRatePickerDialog> createState() =>
      _DefaultTaxRatePickerDialogState();
}

class _DefaultTaxRatePickerDialogState
    extends ConsumerState<_DefaultTaxRatePickerDialog> {
  late final Set<int> _selected = parseDefaultTaxRateIds(
    ref.read(appSettingsProvider)[SettingKeys.defaultTaxRateIds],
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final taxesAsync = ref.watch(allTaxesProvider);
    final enabledTaxes =
        taxesAsync.value?.where((t) => t.isEnabled).toList() ?? const [];
    final hasRates = enabledTaxes.isNotEmpty;

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text(l.taxDefaultRequiredTitle, style: const TextStyle(fontSize: 17)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasRates ? l.taxDefaultRequiredBody : l.taxDefaultRequiredNoRates,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (hasRates) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (final tax in enabledTaxes)
                    _TaxRateChip(
                      tax: tax,
                      selected: _selected.contains(tax.id),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _selected.add(tax.id);
                        } else {
                          _selected.remove(tax.id);
                        }
                      }),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          // Disabled until the invariant can actually be satisfied.
          onPressed: _selected.isEmpty
              ? null
              : () async {
                  final ordered = _selected.toList()..sort();
                  await ref
                      .read(appSettingsProvider.notifier)
                      .set(
                        SettingKeys.defaultTaxRateIds,
                        ordered.join(','),
                      );
                  if (context.mounted) Navigator.pop(context, true);
                },
          child: Text(l.actionApply),
        ),
      ],
    );
  }
}

/// One selectable tax-rate chip. Extracted so the settings picker and the
/// gate dialog render identically.
class _TaxRateChip extends StatelessWidget {
  final Tax tax;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const _TaxRateChip({
    required this.tax,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = onSelected == null;

    return FilterChip(
      label: Text(
        '${tax.name} (${_formatTaxRate(tax.rate, tax.isFixed)})',
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: true,
      selectedColor: cs.primaryContainer,
      checkmarkColor: cs.onPrimaryContainer,
      backgroundColor: cs.surfaceContainerHighest,
      // Material greys a disabled chip's fill but NOT its border or label, so
      // both are dimmed explicitly — otherwise the "off" state reads as active.
      side: BorderSide(
        color: selected
            ? cs.primary.withValues(alpha: disabled ? 0.4 : 1)
            : cs.outline.withValues(alpha: disabled ? 0.15 : 0.3),
      ),
      labelStyle: TextStyle(
        color: (selected ? cs.onPrimaryContainer : cs.onSurface).withValues(
          alpha: disabled ? 0.5 : 1,
        ),
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

String _formatTaxRate(double rate, bool isFixed) {
  final n = rate == rate.roundToDouble()
      ? rate.toStringAsFixed(0)
      : rate.toString();
  return isFixed ? n : '$n%';
}

/// "Default tax rate" picker. Lists every tax from the local Drift cache
/// (`allTaxesProvider`) as toggleable chips and persists the chosen IDs as a
/// comma-separated string in [SettingKeys.defaultTaxRateIds].
///
/// Lives in General → Tax, directly under the switch it belongs to. When that
/// switch is OFF the chips render greyed out and inert rather than
/// disappearing — the selection is kept, so turning the feature back on
/// restores it, and the operator can still see what is configured.
/// Which payment methods come out of the CASH DRAWER.
///
/// 🚨 The company setting is authoritative when set, and inferred otherwise —
/// the inference (`isChangeAllowed`) is a development fallback that exists so a
/// fresh install shows something plausible, NOT a configuration. A method
/// wrongly counted as cash inflates the expected drawer and turns an honest
/// count into a shortfall; wrongly counted as electronic hides a real one.
/// Both sides read the same setting, so this screen is the single place that
/// decides it (`PosSessionService.GetCashPaymentTypeIdsAsync` mirrors it).
///
/// Clearing every method returns to inference rather than meaning "no cash" —
/// the storage cannot express an empty set, and a till that counts nothing is
/// not a case worth inventing syntax for.
class _CashPaymentMethodsSelector extends ConsumerWidget {
  const _CashPaymentMethodsSelector();

  Future<void> _write(WidgetRef ref, Set<int> ids) {
    final ordered = ids.toList()..sort();
    return ref
        .read(appSettingsProvider.notifier)
        .set(SettingKeys.cashPaymentTypeIds, ordered.join(','));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = ref.watch(appSettingsProvider);
    final typesAsync = ref.watch(allPaymentTypesProvider);

    final configured =
        (settings[SettingKeys.cashPaymentTypeIds] ?? '').trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.setCashMethods,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            l.cashMethodsHint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 12),
          typesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Text(
              l.noPaymentMethodsDefined,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
            data: (types) {
              final usable = types.where((t) => t.isEnabled).toList()
                ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
              if (usable.isEmpty) {
                return Text(
                  l.noPaymentMethodsDefined,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                );
              }

              // What the till would use RIGHT NOW — the configured set, or the
              // inference standing in for it. Toggling writes this whole set
              // back with one change, so the first tap promotes the guess into
              // a decision instead of collapsing it to a single method.
              final effective = resolveCashPaymentTypeIds(settings, usable);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      for (final t in usable)
                        FilterChip(
                          label: Text(t.name),
                          avatar: Icon(
                            effective.contains(t.id)
                                ? Icons.payments
                                : Icons.credit_card,
                            size: 16,
                          ),
                          selected: effective.contains(t.id),
                          onSelected: (on) {
                            final next = {...effective};
                            if (on) {
                              next.add(t.id);
                            } else {
                              next.remove(t.id);
                            }
                            _write(ref, next);
                          },
                        ),
                    ],
                  ),
                  if (!configured) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: context.warningColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.cashMethodsInferredHint,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: context.warningColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // One tap turns the guess into the stored answer, which
                        // is what silences the session screen's banner.
                        TextButton(
                          onPressed: () => _write(ref, effective),
                          child: Text(l.cashMethodsConfirm),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The cash difference a cashier may close through on their own.
class _MaxCashDifferenceField extends ConsumerWidget {
  const _MaxCashDifferenceField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _SettingTextField(
      settingKey: SettingKeys.maxCashDifference,
      label: l.setMaxCashDifference,
      hint: l.maxCashDifferenceHint,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }
}

class _DefaultTaxRatesSelector extends ConsumerWidget {
  const _DefaultTaxRatesSelector();

  Future<void> _toggle(WidgetRef ref, Set<int> current, int id, bool on) {
    final next = {...current};
    if (on) {
      next.add(id);
    } else {
      next.remove(id);
    }
    final ordered = next.toList()..sort();
    return ref
        .read(appSettingsProvider.notifier)
        .set(SettingKeys.defaultTaxRateIds, ordered.join(','));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = ref.watch(appSettingsProvider);
    final taxesAsync = ref.watch(allTaxesProvider);
    final selected = parseDefaultTaxRateIds(
      settings[SettingKeys.defaultTaxRateIds],
    );
    final enabled =
        settings[SettingKeys.taxIncludedByDefault]?.toLowerCase() == 'true';
    final dim = enabled ? 1.0 : 0.5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.setDefaultTaxRate,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: dim),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            enabled ? l.defaultTaxRateFullHint : l.defaultTaxRateDisabledHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: enabled ? 0.5 : 0.4),
            ),
          ),
          const SizedBox(height: 12),
          taxesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Text(
              l.couldNotLoadTaxRates,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
            data: (taxes) {
              final enabledTaxes = taxes.where((t) => t.isEnabled).toList();
              if (enabledTaxes.isEmpty) {
                return Text(
                  l.noTaxRatesDefined,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (final tax in enabledTaxes)
                    _TaxRateChip(
                      tax: tax,
                      selected: selected.contains(tax.id),
                      // Deselecting the LAST rate while the feature is on would
                      // break the "ON ⇒ a default exists" invariant, so the
                      // final chip refuses to turn itself off. Turn the switch
                      // off instead.
                      onSelected: !enabled
                          ? null
                          : (on) {
                              if (!on &&
                                  selected.length == 1 &&
                                  selected.contains(tax.id)) {
                                return;
                              }
                              _toggle(ref, selected, tax.id, on);
                            },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Picks the warehouse the POS uses by default for stock checks / sourcing.
/// Saves the chosen id to `SettingKeys.defaultWarehouseId` (an app property)
/// and immediately repoints `selectedWarehouseProvider` so the menu's
/// availability checks switch over without a restart.
class _DefaultWarehouseDropdown extends ConsumerWidget {
  const _DefaultWarehouseDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final whAsync = ref.watch(allWarehousesProvider);
    final currentId = int.tryParse(
      ref.watch(appSettingsProvider)[SettingKeys.defaultWarehouseId] ?? '',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).setDefaultWarehouse,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: 240,
                child: whAsync.when(
                  loading: () => const Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, __) => Text(
                    AppLocalizations.of(context).couldNotLoadWarehouses,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  data: (list) {
                    final validId = list.any((w) => w.id == currentId)
                        ? currentId
                        : null;
                    return DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: validId,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      hint: Text(
                        AppLocalizations.of(context).selectEllipsisShort,
                      ),
                      items: list
                          .map(
                            (w) => DropdownMenuItem<int>(
                              value: w.id,
                              child: Text(
                                w.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        if (id == null) return;
                        ref
                            .read(appSettingsProvider.notifier)
                            .set(SettingKeys.defaultWarehouseId, id.toString());
                        final w = list.where((x) => x.id == id).firstOrNull;
                        if (w != null) {
                          ref.read(selectedWarehouseProvider.notifier).state =
                              w;
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).defaultWarehouseHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final autoUpdateCost =
        settings[SettingKeys.autoUpdateCostPrice]?.toLowerCase() == 'true';
    final menuIsGrid =
        settings[SettingKeys.menuLayoutMode]?.toLowerCase() == 'grid';

    return _TabScrollView(
      cards: [
        _SettingsCard(
          title: AppLocalizations.of(context).setGeneral,
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.displayAndPrintTaxIncluded,
              label: AppLocalizations.of(context).setDisplayPrintTaxIncluded,
            ),
            _SettingDropdown(
              settingKey: SettingKeys.discountApplyRule,
              label: AppLocalizations.of(context).setDiscountApplyRule,
              options: const ['Before tax', 'After tax'],
            ),
            _SettingDropdown(
              settingKey: SettingKeys.productSorting,
              label: AppLocalizations.of(context).setSorting,
              options: const ['Name', 'Code', 'Barcode'],
            ),
            _SettingSwitch(
              settingKey: SettingKeys.allowNegativePrice,
              label: AppLocalizations.of(context).setAllowNegativePrice,
            ),
            _SettingSwitch(
              settingKey: SettingKeys.showProductImages,
              label: AppLocalizations.of(context).setShowProductImages,
            ),
          ],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setInventory,
          children: const [_DefaultWarehouseDropdown()],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setProductDefaults,
          children: [
            // "Default tax rate" moved to General → Tax (2026-08-15) to sit
            // with the tax-inclusive switch that gates it.
            _SettingTextField(
              settingKey: SettingKeys.defaultMeasurementUnit,
              label: AppLocalizations.of(context).setDefaultMeasurementUnit,
              hint: AppLocalizations.of(context).hintUnitsExample,
            ),
            _SettingDropdown(
              settingKey: SettingKeys.barcodeFormat,
              label: AppLocalizations.of(context).setDefaultBarcodeFormat,
              options: const ['EAN-13', 'EAN-8', 'UPC-A', 'Code128', 'QR'],
            ),
            _SettingSwitch(
              settingKey: SettingKeys.costPriceBasedMarkup,
              label: AppLocalizations.of(context).setCostPriceMarkup,
            ),
            _SettingSwitch(
              settingKey: SettingKeys.autoUpdateCostPrice,
              label: AppLocalizations.of(context).setAutoUpdateCostPrice,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Opacity(
                opacity: autoUpdateCost ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !autoUpdateCost,
                  child: _SettingSwitch(
                    settingKey: SettingKeys.updateSalePriceOnMarkup,
                    label: AppLocalizations.of(
                      context,
                    ).setUpdateSalePriceFromMarkup,
                  ),
                ),
              ),
            ),
          ],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setMovingAveragePrice,
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.enableMovingAveragePrice,
              label: AppLocalizations.of(context).setEnableMovingAverage,
            ),
          ],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setMenuGrid,
          children: [
            _SettingDropdown(
              settingKey: SettingKeys.menuLayoutMode,
              label: AppLocalizations.of(context).setLayout,
              options: const ['List', 'Grid'],
            ),
            _SettingDropdown(
              settingKey: SettingKeys.menuGridCols,
              label: AppLocalizations.of(context).columns,
              options: const ['4', '5'],
            ),
            // Rows only matter in the paged Grid layout; List scrolls freely.
            if (menuIsGrid)
              _SettingDropdown(
                settingKey: SettingKeys.menuGridRows,
                label: AppLocalizations.of(context).setRows,
                options: const ['3', '4', '5'],
              ),
          ],
        ),
      ],
    );
  }
}

// ── Weighing Scale ────────────────────────────────────────────────────────────
class _WeighingScaleTab extends ConsumerWidget {
  const _WeighingScaleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final serialOn =
        settings[SettingKeys.scaleEnabled]?.toLowerCase() == 'true';

    return _TabScrollView(
      cards: [
        // Replaces the six Scale.Barcode.* settings this card used to hold.
        // Those could only ever express ONE scale format per company; the
        // nomenclature is an ordered rule list, so a shop can carry a weight
        // format and a price format side by side. Companies configured under
        // the old scheme had their settings translated into an equivalent rule
        // by BarcodeRuleSeeder.BackfillAsync, so nothing needs re-entering.
        _SettingsCard(
          title: AppLocalizations.of(context).barcodeRules,
          children: const [BarcodeRulesEditor()],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setSerialConnection,
          children: [
            if (!kScaleSupported)
              const _ScaleUnsupportedNotice()
            else ...[
              _SettingSwitch(
                settingKey: SettingKeys.scaleEnabled,
                label: AppLocalizations.of(context).setReadLiveWeight,
                subtitle: AppLocalizations.of(context).setScaleStreamHint,
              ),
              Opacity(
                opacity: serialOn ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !serialOn,
                  child: Column(
                    children: [
                      const _ScalePortDropdown(),
                      _SettingDropdown(
                        settingKey: SettingKeys.scaleBaudRate,
                        label: AppLocalizations.of(context).setBaudRate,
                        options: _kBaudRates,
                      ),
                      const _ScaleLiveTest(),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

const _kBaudRates = [
  '1200',
  '2400',
  '4800',
  '9600',
  '19200',
  '38400',
  '57600',
  '115200',
];

/// Serial scales need a COM port, which only Windows exposes here. Say so
/// plainly rather than showing controls that could never work.
class _ScaleUnsupportedNotice extends StatelessWidget {
  const _ScaleUnsupportedNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: context.infoColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context).serialScaleWindowsOnly,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Port picker over the ports actually present, with a rescan button.
///
/// The saved port is always offered even when absent, so an unplugged scale
/// shows the port the operator configured instead of silently displaying some
/// other machine port (and `_SettingDropdown` would throw on an empty list).
class _ScalePortDropdown extends ConsumerWidget {
  const _ScalePortDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detected = ref.watch(availableSerialPortsProvider);
    final saved =
        ref.watch(
          appSettingsProvider.select((s) => s[SettingKeys.scalePort]),
        ) ??
        kSettingDefaults[SettingKeys.scalePort]!;

    final options = <String>{...detected, saved}.toList()..sort();

    return Row(
      children: [
        Expanded(
          child: _SettingDropdown(
            settingKey: SettingKeys.scalePort,
            label: detected.isEmpty
                ? 'Serial port (none detected)'
                : 'Serial port',
            options: options,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context).setRescanPorts,
            onPressed: () => ref.invalidate(availableSerialPortsProvider),
          ),
        ),
      ],
    );
  }
}

/// Live read from the configured port, so the operator can confirm the wiring
/// and baud rate here rather than discovering it mid-sale at the till.
class _ScaleLiveTest extends ConsumerWidget {
  const _ScaleLiveTest();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reading = ref.watch(scaleReadingProvider);

    final (Color color, IconData icon, String text) = switch (reading) {
      AsyncError(:final error) => (
        context.dangerColor,
        Icons.error_outline,
        error is ScaleException
            ? error.message
            : AppLocalizations.of(
                context,
              ).scaleErrorWithMessage(error.toString()),
      ),
      AsyncData(:final value) => (
        value.stable ? context.successColor : context.warningColor,
        value.stable ? Icons.check_circle_outline : Icons.hourglass_empty,
        '${value.weight}${value.unit ?? ''}'
            '${value.stable ? '' : '  (settling…)'}',
      ),
      _ => (
        theme.colorScheme.onSurfaceVariant,
        Icons.hourglass_empty,
        AppLocalizations.of(context).waitingForScale,
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Customer Display ──────────────────────────────────────────────────────────
class _CustomerDisplayTab extends ConsumerStatefulWidget {
  const _CustomerDisplayTab();

  @override
  ConsumerState<_CustomerDisplayTab> createState() =>
      _CustomerDisplayTabState();
}

class _CustomerDisplayTabState extends ConsumerState<_CustomerDisplayTab> {
  bool _showPortSettings = false;
  bool _webRunning = false;
  String _webUrl = '';

  @override
  void initState() {
    super.initState();
    // Re-start the server if it was already enabled (e.g. after settings tab reopen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final on =
          ref
              .read(appSettingsProvider)[SettingKeys.customerDisplayWebEnabled]
              ?.toLowerCase() ==
          'true';
      if (on && mounted) _startWeb();
    });
  }

  // ── Serial display helpers ──────────────────────────────────────────────────

  void _restorePortDefaults() {
    final n = ref.read(appSettingsProvider.notifier);
    n.set(SettingKeys.customerDisplayBaudRate, '9600');
    n.set(SettingKeys.customerDisplayDataBits, '8');
    n.set(SettingKeys.customerDisplayParity, 'None');
    n.set(SettingKeys.customerDisplayStopBits, '1');
    n.set(SettingKeys.customerDisplayFlowControl, 'None');
  }

  Future<void> _testDisplay() async {
    final settings = ref.read(appSettingsProvider);
    await CustomerDisplayService.showWelcome(settings: settings);
    if (mounted) {
      showAppSnackbar(
        context,
        ref,
        AppLocalizations.of(context).testMessageSent,
      );
    }
  }

  // ── Web server helpers ──────────────────────────────────────────────────────

  Future<void> _startWeb() async {
    await CustomerDisplayWebServer.instance.start();
    if (!mounted) return;
    setState(() {
      _webRunning = true;
      _webUrl = CustomerDisplayWebServer.instance.url;
    });
  }

  Future<void> _stopWeb() async {
    await CustomerDisplayWebServer.instance.stop();
    if (!mounted) return;
    setState(() {
      _webRunning = false;
      _webUrl = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled =
        ref
            .watch(appSettingsProvider)[SettingKeys.customerDisplayEnabled]
            ?.toLowerCase() ==
        'true';

    // _webRunning is local state, but the server is a singleton that outlives
    // this widget.  Derive from actual server state so the URL/QR section is
    // always visible when the server is running, even if _webRunning is stale.
    final serverRunning =
        _webRunning || CustomerDisplayWebServer.instance.isRunning;
    final displayUrl = (_webUrl.isNotEmpty
        ? _webUrl
        : CustomerDisplayWebServer.instance.url);

    return _TabScrollView(
      cards: [
        _SettingsCard(
          title: AppLocalizations.of(context).setCustomerDisplay,
          children: [
            // Enabled
            _SettingSwitch(
              settingKey: SettingKeys.customerDisplayEnabled,
              label: AppLocalizations.of(context).fieldEnabled,
              subtitle: AppLocalizations.of(context).setShowOrderTotalOnPole,
            ),
            Opacity(
              opacity: enabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !enabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // COM port row + toggle link
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SettingDropdown(
                              settingKey: SettingKeys.customerDisplayPort,
                              label: AppLocalizations.of(context).setComPort,
                              options: const [
                                'COM1',
                                'COM2',
                                'COM3',
                                'COM4',
                                'COM5',
                                'COM6',
                                'COM7',
                                'COM8',
                                'COM9',
                                'COM10',
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () => setState(
                              () => _showPortSettings = !_showPortSettings,
                            ),
                            child: Text(
                              _showPortSettings
                                  ? 'Hide port settings'
                                  : 'Show port settings',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Expandable port settings
                    if (_showPortSettings)
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            _SettingDropdown(
                              settingKey: SettingKeys.customerDisplayBaudRate,
                              label: AppLocalizations.of(
                                context,
                              ).setBitsPerSecond,
                              options: const [
                                '1200',
                                '2400',
                                '4800',
                                '9600',
                                '19200',
                                '38400',
                                '57600',
                                '115200',
                              ],
                            ),
                            _SettingDropdown(
                              settingKey: SettingKeys.customerDisplayDataBits,
                              label: AppLocalizations.of(context).setDataBits,
                              options: const ['5', '6', '7', '8'],
                            ),
                            _SettingDropdown(
                              settingKey: SettingKeys.customerDisplayParity,
                              label: AppLocalizations.of(context).setParity,
                              options: const [
                                'None',
                                'Even',
                                'Odd',
                                'Mark',
                                'Space',
                              ],
                            ),
                            _SettingDropdown(
                              settingKey: SettingKeys.customerDisplayStopBits,
                              label: AppLocalizations.of(context).setStopBits,
                              options: const ['1', '1.5', '2'],
                            ),
                            _SettingDropdown(
                              settingKey:
                                  SettingKeys.customerDisplayFlowControl,
                              label: AppLocalizations.of(
                                context,
                              ).setFlowControl,
                              options: const ['None', 'RTS/CTS', 'XON/XOFF'],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: _restorePortDefaults,
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    ).restoreDefaults,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Number of characters
                    _StepperRow(
                      label: AppLocalizations.of(context).setNumberOfCharacters,
                      settingKey: SettingKeys.customerDisplayNumChars,
                      min: 1,
                      max: 40,
                    ),

                    // Optional second welcome line for a 2-line pole display.
                    _SettingTextField(
                      settingKey: SettingKeys.customerDisplayWelcomeBottom,
                      label: AppLocalizations.of(context).setBottomLine,
                      hint: '',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ── Display messages: the two texts the on-screen (native / web)
        // customer display shows. Both save to the AppProperties table via
        // appSettingsProvider.set(). Leave a box blank to use the built-in
        // localized default. ────────────────────────────────────────────────
        _SettingsCard(
          title: AppLocalizations.of(context).setDisplayMessages,
          children: [
            // Idle screen greeting.
            _SettingTextField(
              settingKey: SettingKeys.customerDisplayWelcomeMessage,
              label: AppLocalizations.of(context).setWelcomeMessageLabel,
              hint: 'WELCOME!',
            ),
            // Message shown after a payment completes (replaces "THANK YOU").
            _SettingTextField(
              settingKey: SettingKeys.customerDisplayThankYouMessage,
              label: AppLocalizations.of(context).setThankYouMessage,
              hint: 'THANK YOU',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: OutlinedButton(
                onPressed: enabled ? _testDisplay : null,
                child: Text(AppLocalizations.of(context).setTestDisplay),
              ),
            ),
          ],
        ),

        // ── Open on this device (always available, no web server needed) ───
        _SettingsCard(
          title: AppLocalizations.of(context).setOpenOnThisDevice,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                AppLocalizations.of(context).openCustomerDisplayFullHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(
                  AppLocalizations.of(context).setOpenCustomerDisplay,
                ),
                onPressed: () async {
                  // Capture the theme map before any await so the browser
                  // renders in the current app theme (context is unsafe after).
                  final themeMap =
                      customerDisplayThemeMap(Theme.of(context));
                  // Auto-start the WS server if it isn't running yet —
                  // the native screen connects to ws://localhost:8181/ws
                  // regardless of whether the web-display toggle is on.
                  if (!CustomerDisplayWebServer.instance.isRunning) {
                    await _startWeb();
                  }
                  // Push a fresh idle broadcast so _lastState has company
                  // name + logo before the native screen connects and reads it.
                  final settings = ref.read(appSettingsProvider);
                  final company = ref.read(selectedCompanyProvider);
                  CustomerDisplayWebServer.instance.broadcast({
                    'type': 'idle',
                    'company': {
                      'name': company?.name ?? '',
                      'logo': company?.logo,
                    },
                    'welcomeText':
                        settings[SettingKeys.customerDisplayWelcomeMessage] ??
                        'WELCOME!',
                    'theme': themeMap,
                  });
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const CustomerDisplayScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        // ── Web / Screen Display ────────────────────────────────────────────
        _SettingsCard(
          title: AppLocalizations.of(context).setScreenDisplayWeb,
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.customerDisplayWebEnabled,
              label: AppLocalizations.of(context).setEnableLiveWebDisplay,
              subtitle: AppLocalizations.of(context).webDisplayHint,
              onChanged: (_, on) => on ? _startWeb() : _stopWeb(),
            ),
            if (serverRunning) ...[
              // ── Same-machine (second monitor) shortcut ──────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.monitor,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(
                              context,
                            ).sameMachineSecondMonitor,
                            style: theme.textTheme.labelMedium,
                          ),
                          SelectableText(
                            'http://localhost:${CustomerDisplayWebServer.port}',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_browser),
                      tooltip: AppLocalizations.of(context).setOpenInBrowser,
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'http://localhost:${CustomerDisplayWebServer.port}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(indent: 20, endIndent: 20, height: 20),
              // ── LAN / other device URL ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).otherDeviceSameNetwork,
                            style: theme.textTheme.labelMedium,
                          ),
                          SelectableText(
                            displayUrl,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: AppLocalizations.of(context).setCopyLanUrl,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: displayUrl));
                        showAppSnackbar(
                          context,
                          ref,
                          AppLocalizations.of(context).urlCopied,
                        );
                      },
                    ),
                  ],
                ),
              ),
              // QR code
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: displayUrl,
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context).customerDisplayQrHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Printer-group editor dialog (name + category checkboxes) ──────────────────
class _PrinterGroupDialog extends ConsumerStatefulWidget {
  final PrinterGroup? existing;
  final List<ProductGroup> productGroups;

  const _PrinterGroupDialog({
    required this.existing,
    required this.productGroups,
  });

  @override
  ConsumerState<_PrinterGroupDialog> createState() =>
      _PrinterGroupDialogState();
}

class _PrinterGroupDialogState extends ConsumerState<_PrinterGroupDialog> {
  late final TextEditingController _name;
  late final Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _selected = {...?widget.existing?.productGroupIds};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppSnackbar(
        context,
        ref,
        AppLocalizations.of(context).enterAGroupName,
        isError: true,
      );
      return;
    }
    Navigator.pop(
      context,
      PrinterGroup(
        id: widget.existing?.id ?? 0,
        name: name,
        productGroupIds: _selected.toList()..sort(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              style: theme.textTheme.titleLarge,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).fieldName,
                border: const UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AppLocalizations.of(context).categoriesLabel,
              style: theme.textTheme.titleMedium,
            ),
            Text(
              AppLocalizations.of(context).categoriesPrintedOnGroup,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // "No category" sentinel + every product group.
                  _row(
                    PrinterGroup.noCategoryId,
                    AppLocalizations.of(context).noCategory,
                  ),
                  ...widget.productGroups.map((g) => _row(g.id, g.name)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancelUpper),
        ),
        TextButton(
          onPressed: _save,
          child: Text(AppLocalizations.of(context).saveUpper),
        ),
      ],
    );
  }

  Widget _row(int id, String label) {
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      value: _selected.contains(id),
      title: Text(label),
      onChanged: (v) => setState(() {
        if (v == true) {
          _selected.add(id);
        } else {
          _selected.remove(id);
        }
      }),
    );
  }
}

// ── Kitchen Display ───────────────────────────────────────────────────────────
class _KitchenDisplayTab extends ConsumerStatefulWidget {
  const _KitchenDisplayTab();

  @override
  ConsumerState<_KitchenDisplayTab> createState() => _KitchenDisplayTabState();
}

class _KitchenDisplayTabState extends ConsumerState<_KitchenDisplayTab> {
  final _ipController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<String> _parseIps(String? raw) => (raw ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  void _addIp() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ip = _ipController.text.trim();
    final existing = _parseIps(
      ref.read(appSettingsProvider)[SettingKeys.kitchenDisplayIps],
    );
    if (existing.contains(ip)) return;
    final updated = [...existing, ip].join(',');
    ref
        .read(appSettingsProvider.notifier)
        .set(SettingKeys.kitchenDisplayIps, updated);
    _ipController.clear();
    // Auto-pair: the moment an IP is added, send the handshake so the KDS
    // binds and leaves its onboarding screen without any extra step.
    _pairIp(ip);
  }

  void _removeIp(String ip) {
    final existing = _parseIps(
      ref.read(appSettingsProvider)[SettingKeys.kitchenDisplayIps],
    );
    final updated = existing.where((e) => e != ip).join(',');
    ref
        .read(appSettingsProvider.notifier)
        .set(SettingKeys.kitchenDisplayIps, updated);
    // Tell the tablet to drop the binding and return to its pairing screen.
    ref.read(kitchenSyncProvider).unpair(ip);
  }

  void _pairIp(String ip) {
    // Defer the network work off the current frame: a setting `set()` may have
    // just mutated appSettingsProvider, and reading providers synchronously in
    // the same frame trips Riverpod's "only one task can be scheduled" guard.
    _afterFrame(() => ref.read(kitchenSyncProvider).pair(ip));
    showAppSnackbar(
      context,
      ref,
      AppLocalizations.of(context).pairingRequestSent(ip),
    );
  }

  /// Runs [action] after the current frame, swallowing errors — used for the
  /// fire-and-forget KDS network calls so they never collide with a provider
  /// mutation in the same synchronous frame, and never surface as a "failed to
  /// save" snackbar.
  void _afterFrame(void Function() action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        action();
      } catch (_) {
        /* best-effort LAN push */
      }
    });
  }

  void _schedulePush() =>
      _afterFrame(() => ref.read(kitchenSyncProvider).push());

  // ── Printer groups (stations) ──────────────────────────────────────────────

  List<PrinterGroup> _printerGroups() => PrinterGroup.listFromJson(
    ref.read(appSettingsProvider)[SettingKeys.kitchenPrinterGroups],
  );

  void _savePrinterGroups(List<PrinterGroup> groups) => ref
      .read(appSettingsProvider.notifier)
      .set(SettingKeys.kitchenPrinterGroups, PrinterGroup.listToJson(groups));

  Future<void> _editPrinterGroup({PrinterGroup? existing}) async {
    final productGroups = ref.read(allProductGroupsProvider).value ?? const [];
    final result = await showDialog<PrinterGroup>(
      context: context,
      builder: (_) =>
          _PrinterGroupDialog(existing: existing, productGroups: productGroups),
    );
    if (result == null) return;
    final list = [..._printerGroups()]; // growable copy — safe to append
    if (existing == null) {
      list.add(result.copyWith(id: PrinterGroup.nextId(list)));
    } else {
      final idx = list.indexWhere((g) => g.id == existing.id);
      if (idx >= 0) list[idx] = result;
    }
    _savePrinterGroups(list);
    // New/edited routing takes effect on the next push.
    _schedulePush();
  }

  void _deletePrinterGroup(PrinterGroup group) {
    _savePrinterGroups(
      _printerGroups().where((g) => g.id != group.id).toList(),
    );
    // Strip the deleted group from every display's assignment.
    final map = parseDisplayGroups(
      ref.read(appSettingsProvider)[SettingKeys.kitchenDisplayGroups],
    );
    var changed = false;
    for (final ip in map.keys.toList()) {
      if (map[ip]!.contains(group.id)) {
        map[ip] = map[ip]!.where((id) => id != group.id).toList();
        changed = true;
      }
    }
    if (changed) {
      ref
          .read(appSettingsProvider.notifier)
          .set(SettingKeys.kitchenDisplayGroups, encodeDisplayGroups(map));
    }
    _schedulePush();
  }

  void _toggleDisplayGroup(String ip, int groupId, bool on) {
    final map = parseDisplayGroups(
      ref.read(appSettingsProvider)[SettingKeys.kitchenDisplayGroups],
    );
    final current = [...(map[ip] ?? const <int>[])];
    if (on) {
      if (!current.contains(groupId)) current.add(groupId);
    } else {
      current.remove(groupId);
    }
    map[ip] = current;
    ref
        .read(appSettingsProvider.notifier)
        .set(SettingKeys.kitchenDisplayGroups, encodeDisplayGroups(map));
    // Re-route so the display reflects its new categories (deferred a frame).
    _schedulePush();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = ref.watch(appSettingsProvider);
    final ips = _parseIps(settings[SettingKeys.kitchenDisplayIps]);
    final printerGroups = PrinterGroup.listFromJson(
      settings[SettingKeys.kitchenPrinterGroups],
    );
    final displayGroups = parseDisplayGroups(
      settings[SettingKeys.kitchenDisplayGroups],
    );
    // Keep the product-group stream alive + loaded while this tab is open, so
    // the printer-group dialog has the real categories ready (it's autoDispose
    // and would otherwise read null and show only "No category").
    ref.watch(allProductGroupsProvider);

    return _TabScrollView(
      cards: [
        // ── Printer groups (stations) ──────────────────────────────────────
        _SettingsCard(
          title: AppLocalizations.of(context).setPrinterGroups,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                AppLocalizations.of(context).printerGroupsHelp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 1),
            if (printerGroups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Text(
                  AppLocalizations.of(context).noPrinterGroupsYet,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ...printerGroups.map((g) {
              final n = g.productGroupIds.length;
              return ListTile(
                leading: Icon(Icons.print, color: cs.primary),
                title: Text(g.name, style: theme.textTheme.bodyMedium),
                subtitle: Text(AppLocalizations.of(context).categoryCount(n)),
                onTap: () => _editPrinterGroup(existing: g),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: cs.secondary,
                        size: 20,
                      ),
                      tooltip: AppLocalizations.of(context).actionEdit,
                      onPressed: () => _editPrinterGroup(existing: g),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: cs.error,
                        size: 20,
                      ),
                      tooltip: AppLocalizations.of(context).actionDelete,
                      onPressed: () => _deletePrinterGroup(g),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _editPrinterGroup(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(AppLocalizations.of(context).setAddPrinterGroup),
                ),
              ),
            ),
          ],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setKdsTablets,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                AppLocalizations.of(
                  context,
                ).kdsTabletsHelp(kKdsPort.toString()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 1),
            // ── existing IPs ──
            if (ips.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Text(
                  AppLocalizations.of(context).noKitchenDisplays,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ...ips.map((ip) {
              final assigned = displayGroups[ip] ?? const <int>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    leading: Icon(Icons.tablet_android, color: cs.primary),
                    title: Text(ip, style: theme.textTheme.bodyMedium),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.link, color: cs.secondary, size: 20),
                          tooltip: AppLocalizations.of(context).setRepair,
                          onPressed: () => _pairIp(ip),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: cs.error,
                            size: 20,
                          ),
                          tooltip: AppLocalizations.of(context).actionRemove,
                          onPressed: () => _removeIp(ip),
                        ),
                      ],
                    ),
                  ),
                  // Per-display routing: pick which printer groups this tablet
                  // receives. None selected ⇒ it receives every item.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
                    child: printerGroups.isEmpty
                        ? Text(
                            AppLocalizations.of(context).receivesAllItems,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final g in printerGroups)
                                FilterChip(
                                  label: Text(g.name),
                                  selected: assigned.contains(g.id),
                                  onSelected: (v) =>
                                      _toggleDisplayGroup(ip, g.id, v),
                                ),
                              if (assigned.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    ).noGroupSelectedReceivesAll,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              );
            }),
            const Divider(height: 1),
            // ── add new IP ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Form(
                key: _formKey,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ipController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).setKdsIp,
                          hintText: '192.168.1.100',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: const Icon(Icons.lan_outlined, size: 18),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return AppLocalizations.of(
                              context,
                            ).enterAnIpAddress;
                          }
                          final parts = v.trim().split('.');
                          if (parts.length != 4) {
                            return AppLocalizations.of(
                              context,
                            ).invalidIpWithExample;
                          }
                          if (parts.any((p) => int.tryParse(p) == null)) {
                            return AppLocalizations.of(context).invalidIp;
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _addIp(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _addIp,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(AppLocalizations.of(context).actionAdd),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Email ─────────────────────────────────────────────────────────────────────
class _EmailTab extends ConsumerWidget {
  const _EmailTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TabScrollView(
      cards: [
        _SettingsCard(
          title: AppLocalizations.of(context).setSmtpServer,
          children: [
            _SettingTextField(
              settingKey: SettingKeys.emailSmtpHost,
              label: AppLocalizations.of(context).setSmtpHost,
              hint: 'smtp.gmail.com',
              keyboardType: TextInputType.url,
            ),
            _SettingTextField(
              settingKey: SettingKeys.emailSmtpPort,
              label: AppLocalizations.of(context).setSmtpPort,
              hint: '587',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        _SettingsCard(
          title: AppLocalizations.of(context).setSender,
          children: [
            _SettingTextField(
              settingKey: SettingKeys.emailFromAddress,
              label: AppLocalizations.of(context).setFromEmailAddress,
              hint: 'pos@yourbusiness.com',
              keyboardType: TextInputType.emailAddress,
            ),
            _SettingTextField(
              settingKey: SettingKeys.emailFromName,
              label: AppLocalizations.of(context).setFromName,
              hint: AppLocalizations.of(context).posSystem,
            ),
            _SettingTextField(
              settingKey: SettingKeys.emailUserEmail,
              label: AppLocalizations.of(context).accountUserEmail,
              hint: 'your@email.com',
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Print ─────────────────────────────────────────────────────────────────────
// The Print sidebar entry now embeds the 4-tab printer/receipt settings directly
// (Printers, Customize Receipt, Localize Text, Print Templates) — no intro splash.
class _PrintTab extends StatelessWidget {
  const _PrintTab();

  @override
  Widget build(BuildContext context) => const PrinterSettingsBody();
}

// ── Dual Currency ─────────────────────────────────────────────────────────────
class _DualCurrencyTab extends ConsumerWidget {
  const _DualCurrencyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TabScrollView(
      cards: [
        _SettingsCard(
          title: AppLocalizations.of(context).setDualCurrency,
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.dualCurrencyEnabled,
              label: AppLocalizations.of(context).setDualCurrencyEnabled,
              subtitle: AppLocalizations.of(context).setDualCurrencyHint,
            ),
            _SettingTextField(
              settingKey: SettingKeys.dualCurrencySymbol,
              label: AppLocalizations.of(context).setSecondaryCurrencySymbol,
              hint: 'e.g. €',
            ),
            _SettingTextField(
              settingKey: SettingKeys.dualCurrencyRate,
              label: AppLocalizations.of(context).setExchangeRate,
              hint: AppLocalizations.of(context).exchangeRateHint,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Database ──────────────────────────────────────────────────────────────────
class _DatabaseTab extends ConsumerStatefulWidget {
  const _DatabaseTab();

  @override
  ConsumerState<_DatabaseTab> createState() => _DatabaseTabState();
}

class _DatabaseTabState extends ConsumerState<_DatabaseTab> {
  bool _isBackingUp = false;

  Future<void> _doBackup() async {
    final l = AppLocalizations.of(context);
    // If no backup location is configured yet, ask the user to pick one first.
    var backupDir =
        ref.read(appSettingsProvider)[SettingKeys.dbBackupPath] ?? '';
    // On Android/iOS there is no folder to pick — the picker returns a SAF
    // `content://` URI that no file API here can write to, so asking for one
    // just guaranteed a failed backup. BackupService resolves the managed
    // app-storage location itself.
    if (backupDir.trim().isEmpty && !BackupService.usesManagedBackupDir) {
      final picked = await FilePicker.platform.getDirectoryPath(
        dialogTitle: AppLocalizations.of(context).selectBackupFolder,
      );
      if (picked == null || !mounted) return;
      await ref
          .read(appSettingsProvider.notifier)
          .set(SettingKeys.dbBackupPath, picked);
      backupDir = picked;
    }

    setState(() => _isBackingUp = true);
    try {
      final settings = ref.read(appSettingsProvider);
      final companyName = ref.read(selectedCompanyProvider)?.name ?? 'POS';

      final destPath = await BackupService.backupNow(
        backupDir: backupDir,
        companyName: companyName,
      );

      // Prune old backups if enabled
      if (settings[SettingKeys.dbBackupAutoDelete]?.toLowerCase() == 'true') {
        final days =
            int.tryParse(settings[SettingKeys.dbBackupRetentionDays] ?? '10') ??
            10;
        final resolvedDir = p.dirname(destPath);
        await BackupService.pruneOldBackups(
          backupDir: resolvedDir,
          retentionDays: days,
        );
      }

      if (mounted) {
        showAppSnackbar(context, ref, l.backupSaved(p.basename(destPath)));
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, l.backupFailed('$e'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  /// Picks a folder if none is configured, saves it, then opens it in Explorer.
  Future<void> _openLocation() async {
    var dir = ref.read(appSettingsProvider)[SettingKeys.dbBackupPath] ?? '';

    // Android/iOS: there is no file manager to hand a path to and no folder
    // worth picking. Surface the resolved managed location instead, so the
    // operator can actually find the file over USB rather than tapping a
    // button that silently did nothing.
    if (BackupService.usesManagedBackupDir) {
      final resolved = await BackupService.resolveBackupDir(dir);
      if (!mounted) return;
      showAppSnackbar(context, ref, resolved);
      return;
    }

    if (dir.trim().isEmpty) {
      final picked = await FilePicker.platform.getDirectoryPath(
        dialogTitle: AppLocalizations.of(context).selectBackupFolder,
      );
      if (picked == null || !mounted) return;
      await ref
          .read(appSettingsProvider.notifier)
          .set(SettingKeys.dbBackupPath, picked);
      dir = picked;
    }
    BackupService.openDirectory(dir);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final autoEnabled =
        settings[SettingKeys.dbAutoBackup]?.toLowerCase() == 'true';
    final autoDelete =
        settings[SettingKeys.dbBackupAutoDelete]?.toLowerCase() == 'true';
    final autoSyncEnabled =
        settings[SettingKeys.autoSyncEnabled]?.toLowerCase() == 'true';

    return _TabScrollView(
      cards: [
        // ── Auto sync ─────────────────────────────────────────────────────────
        _SettingsCard(
          title: AppLocalizations.of(context).setAutoSync,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Text(
                AppLocalizations.of(context).autoSyncFullHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _SettingSwitch(
              settingKey: SettingKeys.autoSyncEnabled,
              label: AppLocalizations.of(context).setEnableAutoSync,
            ),
            // 🚨 The recovery path for the session gate, and the reason it is
            // reachable from Settings rather than buried: the gate stops a till
            // selling, so if session state is ever wrong on a real register the
            // shop needs a way back that does not require a developer.
            _SettingSwitch(
              settingKey: SettingKeys.requireOpenSession,
              label: AppLocalizations.of(context).setRequireOpenSession,
            ),
            if (autoSyncEnabled)
              _SettingDropdown(
                settingKey: SettingKeys.autoSyncMode,
                label: AppLocalizations.of(context).setWhenToSync,
                // Persisted setting VALUES — never translate the list itself.
                // _settingOptionLabel renders them per-locale.
                options: const ['After every save', 'Every 1 hour'],
              ),
            _SettingSwitch(
              settingKey: SettingKeys.autoSyncShowNotification,
              label: AppLocalizations.of(context).setShowSyncNotification,
              subtitle: AppLocalizations.of(context).setSyncToast,
            ),
          ],
        ),

        // ── Backup now ────────────────────────────────────────────────────────
        _SettingsCard(
          title: AppLocalizations.of(context).setDatabase,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: FilledButton.icon(
                onPressed: _isBackingUp ? null : _doBackup,
                icon: _isBackingUp
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.backup_outlined),
                label: Text(
                  _isBackingUp
                      ? AppLocalizations.of(context).backingUpEllipsis
                      : AppLocalizations.of(context).backupDatabase,
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            // Restore — the other half of Backup, and it lives right beside it
            // because a backup nobody can restore is not a backup.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
              child: OutlinedButton.icon(
                onPressed: _isBackingUp
                    ? null
                    : () => runRestoreFlow(context, ref),
                icon: const Icon(Icons.restore),
                label: Text(AppLocalizations.of(context).restoreDatabaseAction),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Text(
                AppLocalizations.of(context).restoreDatabaseHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 20, 14),
              child: TextButton.icon(
                onPressed: _openLocation,
                icon: Icon(
                  Icons.folder_open_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  AppLocalizations.of(context).openDatabaseLocation,
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
          ],
        ),

        // ── Automatic backups ─────────────────────────────────────────────────
        _SettingsCard(
          title: AppLocalizations.of(context).setAutomaticBackups,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Text(
                AppLocalizations.of(context).autoBackupExplain,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const _AutoBackupSwitch(),
            Opacity(
              opacity: autoEnabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !autoEnabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingSwitch(
                      settingKey: SettingKeys.dbBackupOnStart,
                      label: AppLocalizations.of(context).setBackupOnStart,
                    ),
                    _SettingSwitch(
                      settingKey: SettingKeys.dbBackupOnClose,
                      label: AppLocalizations.of(context).setBackupOnClose,
                    ),
                    _StepperRow(
                      label: AppLocalizations.of(context).setBackUpEvery,
                      settingKey: SettingKeys.dbBackupIntervalHours,
                      min: 0,
                      max: 168,
                      suffix: AppLocalizations.of(context).unitHours,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Text(
                        AppLocalizations.of(context).setZeroToDisableBackups,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const _BackupLocationField(),
                    _SettingSwitch(
                      settingKey: SettingKeys.dbBackupAutoDelete,
                      label: AppLocalizations.of(context).setDeleteOldBackups,
                    ),
                    Opacity(
                      opacity: autoDelete ? 1.0 : 0.4,
                      child: IgnorePointer(
                        ignoring: !autoDelete,
                        child: _StepperRow(
                          label: AppLocalizations.of(
                            context,
                          ).setDeleteBackupsOlderThan,
                          settingKey: SettingKeys.dbBackupRetentionDays,
                          min: 1,
                          max: 365,
                          suffix: AppLocalizations.of(context).unitDays,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Enable automatic backups" — which cannot be turned on without a folder to
/// write to.
///
/// 🚨 Turning it on with an empty path used to look like it worked: nothing
/// complained, and `BackupService.resolveBackupDir('')` quietly falls back to
/// `<Documents>/POS_Backups`. So the terminal really was backing up — into a
/// folder the operator never chose and would not think to look in, which is the
/// same as having no backup on the day they need one. Reported 2026-08-16.
///
/// Enabling now opens the folder picker and only commits if a folder is
/// actually chosen — the same shape as `_TaxIncludedByDefaultSwitch` (backlog
/// item 5), where a switch whose feature needs configuration refuses to store
/// `true` in a state it cannot honour.
///
/// Android/iOS write to a managed app-storage folder with nothing to pick, so
/// there the switch behaves exactly as before.
class _AutoBackupSwitch extends ConsumerWidget {
  const _AutoBackupSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final path = (settings[SettingKeys.dbBackupPath] ?? '').trim();
    final managed = BackupService.usesManagedBackupDir;
    final value =
        (settings[SettingKeys.dbAutoBackup] ?? '').toLowerCase() == 'true';

    // Rendered directly rather than through _SettingSwitch, which writes the
    // new value BEFORE its callback runs: enabling would store `true`, then the
    // guard would store `false` again — a visible flicker and two writes of a
    // synced setting for what is really one refused change.
    return SwitchListTile(
      title: Text(l.setEnableAutomaticBackups),
      // Only while it is OFF: an install from before this guard existed can be
      // ON with an empty path (backing up to the fallback location), and
      // telling that operator backups "stay off" would be a lie.
      subtitle: (!managed && path.isEmpty && !value)
          ? Text(l.backupPathNotSet)
          : null,
      value: value,
      activeThumbColor: theme.colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onChanged: (enabled) async {
        final notifier = ref.read(appSettingsProvider.notifier);
        if (!enabled || managed || path.isNotEmpty) {
          await notifier.setBool(SettingKeys.dbAutoBackup, enabled);
          return;
        }

        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(Icons.folder_open_outlined,
                color: Theme.of(ctx).colorScheme.primary, size: 30),
            title: Text(l.backupPathRequiredTitle),
            content: Text(l.backupPathRequiredBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.selectBackupFolder),
              ),
            ],
          ),
        );
        if (proceed != true) return;

        final picked = await FilePicker.platform.getDirectoryPath(
          dialogTitle: l.selectBackupFolder,
        );
        if (picked == null || picked.trim().isEmpty) return;

        await notifier.set(SettingKeys.dbBackupPath, picked);
        await notifier.setBool(SettingKeys.dbAutoBackup, true);
      },
    );
  }
}

/// Backup location text field with a "…" browse button.
/// Saves to [SettingKeys.dbBackupPath] on focus-loss/submit/browse.
class _BackupLocationField extends ConsumerStatefulWidget {
  const _BackupLocationField();

  @override
  ConsumerState<_BackupLocationField> createState() =>
      _BackupLocationFieldState();
}

class _BackupLocationFieldState extends ConsumerState<_BackupLocationField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: ref
          .read(appSettingsProvider.notifier)
          .get(SettingKeys.dbBackupPath),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(appSettingsProvider.notifier);
    if (_ctrl.text.trim() == notifier.get(SettingKeys.dbBackupPath)) return;
    await notifier.set(SettingKeys.dbBackupPath, _ctrl.text.trim());
  }

  Future<void> _browse() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context).selectBackupFolder,
    );
    if (result != null) {
      _ctrl.text = result;
      await ref
          .read(appSettingsProvider.notifier)
          .set(SettingKeys.dbBackupPath, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The controller is seeded once in initState, so a path set from ANYWHERE
    // else — the "enable automatic backups" guard opens the same folder picker
    // — would leave this box showing the old (usually empty) value until the
    // screen was reopened, making it look like the choice had not been saved.
    ref.listen(appSettingsProvider, (_, next) {
      final stored = (next[SettingKeys.dbBackupPath] ?? '').trim();
      if (stored.isNotEmpty && stored != _ctrl.text.trim()) {
        _ctrl.text = stored;
      }
    });
    // Android/iOS write to a managed app-storage folder — there is nothing to
    // type and nothing to browse. Showing an editable path box with a "…"
    // button there offered a choice the platform cannot honour, and any value
    // entered broke the backup outright.
    final managed = BackupService.usesManagedBackupDir;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              readOnly: managed,
              enabled: !managed,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).setBackupLocation,
                hintText: managed
                    ? AppLocalizations.of(context).backupPathHintManaged
                    : Platform.isWindows
                        ? AppLocalizations.of(context).backupPathHintWindows
                        : AppLocalizations.of(context).backupPathHintUnix,
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
              onEditingComplete: _save,
              onSubmitted: (_) => _save(),
            ),
          ),
          if (!managed) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _browse,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('…'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Subscription ──────────────────────────────────────────────────────────────

String _fmtSubscriptionDate(DateTime? dt) {
  if (dt == null) return '–';
  final l = dt.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/'
      '${l.month.toString().padLeft(2, '0')}/'
      '${l.year}';
}

class _SubscriptionTab extends ConsumerWidget {
  const _SubscriptionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(subscriptionInfoProvider);

    return infoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _TabScrollView(
        cards: [
          _SettingsCard(
            title: AppLocalizations.of(context).subscriptionUpper,
            children: [
              _InfoRow(
                label: AppLocalizations.of(context).errorLabel,
                value: e.toString(),
              ),
            ],
          ),
        ],
      ),
      data: (info) => _TabScrollView(
        cards: [
          _SettingsCard(
            title: AppLocalizations.of(context).subscriptionUpper,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Row(
                  children: [
                    _SubscriptionStatusPill(info: info),
                    const Spacer(),
                    // The tab lives in a LazyIndexedStack, so once built it is
                    // never disposed and the autoDispose provider won't re-run
                    // while the operator sits on it. This is the only way to
                    // pull a lease changed in the admin portal without a
                    // restart.
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: AppLocalizations.of(context).refresh,
                      onPressed: () => ref.invalidate(subscriptionInfoProvider),
                    ),
                  ],
                ),
              ),
              _InfoRow(
                label: AppLocalizations.of(context).setStarted,
                value: _fmtSubscriptionDate(info.startedAt),
              ),
              _InfoRow(
                label: AppLocalizations.of(context).setRenewsEnds,
                value: _fmtSubscriptionDate(info.periodEnd ?? info.validUntil),
              ),
              // Allowance 0 = no subscription row provisioned upstream, NOT an
              // unlimited plan — say nothing rather than imply a cap either way.
              _InfoRow(
                label: AppLocalizations.of(context).setDevices,
                value: info.seatAllowance > 0
                    ? AppLocalizations.of(
                        context,
                      ).deviceCount(info.seatAllowance)
                    : '–',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Status chip driven by the same lease evaluation the boot guard enforces, so
/// it can never claim "Active" on a terminal that is one restart from blocked.
class _SubscriptionStatusPill extends StatelessWidget {
  const _SubscriptionStatusPill({required this.info});
  final SubscriptionInfo info;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (info.state) {
      // daysLeft counts to the period end shown in the rows below, so it goes
      // <= 0 both on the final day (hours left, still paid) and while running
      // on the grace window (period already over). "Expires in 0 days" would be
      // nonsense for either, and a green tick on an amber pill reads as broken.
      //
      // The two cases need DIFFERENT words, and which one can occur depends on
      // Lease:GraceDays — at 0 (the current setting) the grace window is empty,
      // so an `active` lease past its period end is impossible and this branch
      // only ever means "expires today". `periodEnd` is the discriminator.
      LicenseState.active when info.daysLeft <= 0 => (
        (info.periodEnd != null &&
                info.periodEnd!.isBefore(DateTime.now().toUtc()))
            ? AppLocalizations.of(context).statusGracePeriod
            : AppLocalizations.of(context).statusExpiresToday,
        Icons.warning_amber_rounded,
        context.warningColor,
      ),
      LicenseState.active when info.daysLeft <= 7 => (
        AppLocalizations.of(context).expiresInDays(info.daysLeft),
        Icons.schedule,
        context.warningColor,
      ),
      LicenseState.active => (
        AppLocalizations.of(context).statusActive,
        Icons.check_circle,
        context.successColor,
      ),
      LicenseState.expired => (
        AppLocalizations.of(context).statusExpired,
        Icons.error,
        Theme.of(context).colorScheme.error,
      ),
      LicenseState.tampered => (
        AppLocalizations.of(context).statusInvalid,
        Icons.gpp_bad,
        Theme.of(context).colorScheme.error,
      ),
      LicenseState.unknown => (
        AppLocalizations.of(context).statusNotActivated,
        Icons.help_outline,
        Theme.of(context).hintColor,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ── About ─────────────────────────────────────────────────────────────────────
// ── About tab helpers ─────────────────────────────────────────────────────────

class _AboutStats {
  final int productCount;
  final int customerCount;
  final int userCount;
  final DateTime? lastSync;
  final int dbSizeBytes;

  const _AboutStats({
    required this.productCount,
    required this.customerCount,
    required this.userCount,
    required this.lastSync,
    required this.dbSizeBytes,
  });

  String get dbSizeFormatted {
    if (dbSizeBytes < 1024) return '$dbSizeBytes B';
    if (dbSizeBytes < 1024 * 1024) {
      return '${(dbSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(dbSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

final _aboutStatsProvider = FutureProvider.autoDispose<_AboutStats>((
  ref,
) async {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id ?? 0;

  final products = await (db.select(
    db.productsTable,
  )..where((t) => t.companyId.equals(companyId))).get();
  final customers = await (db.select(
    db.customersTable,
  )..where((t) => t.companyId.equals(companyId))).get();
  final users = await (db.select(
    db.usersTable,
  )..where((t) => t.companyId.equals(companyId))).get();

  // Most recent lastSyncedAt across all entities
  final syncRows = await db.select(db.syncMetaTable).get();
  final lastSync = syncRows
      .map((r) => r.lastSyncedAt)
      .whereType<DateTime>()
      .fold<DateTime?>(
        null,
        (best, t) => best == null || t.isAfter(best) ? t : best,
      );

  int dbSizeBytes = 0;
  try {
    final path = await BackupService.dbFilePath();
    dbSizeBytes = File(path).lengthSync();
  } catch (_) {}

  return _AboutStats(
    productCount: products.length,
    customerCount: customers.length,
    userCount: users.length,
    lastSync: lastSync,
    dbSizeBytes: dbSizeBytes,
  );
});

String _fmtAboutDt(DateTime dt) {
  final l = dt.toLocal();
  final now = DateTime.now();
  final isToday =
      l.year == now.year && l.month == now.month && l.day == now.day;
  final datePart = isToday
      ? 'Today'
      : '${l.day.toString().padLeft(2, '0')}/'
            '${l.month.toString().padLeft(2, '0')}/'
            '${l.year}';
  final timePart =
      '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  return '$datePart at $timePart';
}

// ─────────────────────────────────────────────────────────────────────────────

class _AboutTab extends ConsumerWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final company = ref.watch(selectedCompanyProvider);
    final statsAsync = ref.watch(_aboutStatsProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Hero header ───────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.point_of_sale, size: 64, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  company?.name ?? AppLocalizations.of(context).posSystem,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  // Read from the running build, never hardcoded — see
                  // core/app_version.dart. Blank until the async read lands,
                  // which is a single cached platform call.
                  AppLocalizations.of(context).versionLabel(
                    ref.watch(appVersionProvider).value?.display ?? '…',
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'API: ${settings[SettingKeys.apiBaseUrl] ?? '–'}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Software update ───────────────────────────────────────────────
          const _UpdateCard(),
          const SizedBox(height: 20),

          // ── Company ───────────────────────────────────────────────────────
          _SettingsCard(
            title: AppLocalizations.of(context).setCompany,
            children: [
              _InfoRow(
                label: AppLocalizations.of(context).fieldName,
                value: company?.name ?? '–',
              ),
              _InfoRow(
                label: AppLocalizations.of(context).setTaxNo,
                value: company?.taxNumber ?? '–',
              ),
              _InfoRow(
                label: AppLocalizations.of(context).setPhone,
                value: company?.phoneNumber ?? '–',
              ),
              _InfoRow(
                label: AppLocalizations.of(context).setAddress,
                value: company?.address ?? '–',
              ),
            ],
          ),

          // ── Database ──────────────────────────────────────────────────────
          statsAsync.when(
            loading: () => _SettingsCard(
              title: AppLocalizations.of(context).setDatabase,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
            error: (e, _) => _SettingsCard(
              title: AppLocalizations.of(context).setDatabase,
              children: [
                _InfoRow(
                  label: AppLocalizations.of(context).errorLabel,
                  value: e.toString(),
                ),
              ],
            ),
            data: (s) => _SettingsCard(
              title: AppLocalizations.of(context).setDatabase,
              children: [
                _InfoRow(
                  label: AppLocalizations.of(context).products,
                  value: '${s.productCount}',
                ),
                _InfoRow(
                  label: AppLocalizations.of(context).customersLabel,
                  value: '${s.customerCount}',
                ),
                _InfoRow(
                  label: AppLocalizations.of(context).users,
                  value: '${s.userCount}',
                ),
                _InfoRow(
                  label: AppLocalizations.of(context).setDbSize,
                  value: s.dbSizeFormatted,
                ),
                _InfoRow(
                  label: AppLocalizations.of(context).setLastSync,
                  value: s.lastSync != null
                      ? _fmtAboutDt(s.lastSync!)
                      : 'Never',
                ),
              ],
            ),
          ),

          // ── Reset database ────────────────────────────────────────────────
          // Admin only (accessLevel 0 == Admin, 1 == Cashier). The card is not
          // rendered at all for a cashier rather than shown-and-disabled: this
          // wipes company-wide data, so it should not even be discoverable from
          // a till someone is standing at. The PIN check inside is the real
          // authorisation — this is just the first door.
          if (ref.watch(currentUserProvider)?.accessLevel == 0)
            _SettingsCard(
              title: AppLocalizations.of(context).resetDatabaseTitle,
              children: const [ResetDatabaseSection()],
            ),

          // ── Developer ─────────────────────────────────────────────────────
          // Admin only, and off by default: the switch puts a floating debug
          // button on top of the till whose panel injects barcodes into the
          // live scan handler. That is exactly right for diagnosing a scale
          // label and exactly wrong for a cashier to find by accident.
          if (ref.watch(currentUserProvider)?.accessLevel == 0)
            _SettingsCard(
              title: AppLocalizations.of(context).developerMode,
              children: [
                SwitchListTile(
                  title: Text(AppLocalizations.of(context).developerMode),
                  subtitle: Text(
                    AppLocalizations.of(context).developerModeHint,
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  secondary: Icon(Icons.bug_report,
                      color: theme.colorScheme.primary),
                  value: ref.watch(developerModeProvider),
                  onChanged: (v) =>
                      ref.read(developerModeProvider.notifier).set(v),
                ),
              ],
            ),

          // ── System ────────────────────────────────────────────────────────
          _SettingsCard(
            title: AppLocalizations.of(context).setSystemInfo,
            children: [
              _InfoRow(
                label: AppLocalizations.of(context).setCurrency,
                value: settings[SettingKeys.currencySymbol] ?? '–',
              ),
              _InfoRow(
                label: AppLocalizations.of(context).languageLabel,
                value: settings[SettingKeys.language] ?? '–',
              ),
              _InfoRow(
                label: AppLocalizations.of(context).dateFormatLabel,
                value: settings[SettingKeys.dateFormat] ?? '–',
              ),
              _InfoRow(
                label: AppLocalizations.of(context).dualCurrencyLower,
                value: settings[SettingKeys.dualCurrencyEnabled] == 'true'
                    ? AppLocalizations.of(context).statusEnabled
                    : AppLocalizations.of(context).statusDisabled,
              ),
              _InfoRow(
                label: AppLocalizations.of(context).setAutoBackup,
                value: settings[SettingKeys.dbAutoBackup] == 'true'
                    ? AppLocalizations.of(context).statusOn
                    : AppLocalizations.of(context).statusOff,
              ),
            ],
          ),

          // ── Onboarding ────────────────────────────────────────────────────
          _SettingsCard(
            title: AppLocalizations.of(context).setOnboarding,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).replayOnboardingHint,
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: Text(AppLocalizations.of(context).setReplay),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      // Reset only — the app replaces the root route after login
                      // (pushAndRemoveUntil to MainLayout), so re-showing it now
                      // would need a fragile stack rebuild. Clearing the flag lets
                      // the boot gate show it cleanly on the next launch.
                      onPressed: () async {
                        await ref
                            .read(onboardingCompleteProvider.notifier)
                            .reset();
                        if (context.mounted) {
                          showAppSnackbar(
                            context,
                            ref,
                            AppLocalizations.of(context).onboardingWillShow,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Timezone Card ─────────────────────────────────────────────────────────────

/// The canonical UTC id in the IANA database. There is **no plain `'UTC'` key** —
/// verified against the bundled database: 341 location keys, none named `'UTC'`
/// (the closest are `Etc/UTC` and `Etc/GMT*`). Feeding `'UTC'` to the timezone
/// dropdown as a value with no matching item trips DropdownButton's "exactly one
/// item" assertion, so it must never be used as a fallback or a default.
const String _kUtcTzId = 'Etc/UTC';

String _tzOffsetLabel(String name) {
  try {
    final loc = tz.getLocation(name);
    final offsetMs = loc.currentTimeZone.offset.inMilliseconds;
    final sign = offsetMs >= 0 ? '+' : '-';
    final abs = offsetMs.abs();
    final h = (abs ~/ 3600000).toString().padLeft(2, '0');
    final m = ((abs % 3600000) ~/ 60000).toString().padLeft(2, '0');
    return '$name (UTC$sign$h:$m)';
  } catch (_) {
    return name;
  }
}

class _TimezoneCard extends ConsumerStatefulWidget {
  const _TimezoneCard();

  @override
  ConsumerState<_TimezoneCard> createState() => _TimezoneCardState();
}

class _TimezoneCardState extends ConsumerState<_TimezoneCard> {
  bool _detecting = false;
  List<String> _tzIds = [];

  @override
  void initState() {
    super.initState();
    _tzIds = [];
    // Defer heavy timezone DB init so it doesn't block the route transition
    Future.microtask(() {
      tz_data.initializeTimeZones();
      final ids = tz.timeZoneDatabase.locations.keys.toList()..sort();
      if (mounted) setState(() => _tzIds = ids);
    });
  }

  /// The id to show in the dropdown, guaranteed to be one of [_tzIds].
  ///
  /// DropdownButton asserts that its value matches exactly one item, so this must
  /// never return something absent from the list. Legacy rows (and the old
  /// default) stored the invalid `'UTC'` — see [_kUtcTzId] — and an id can also
  /// vanish between tz database versions, so anything unknown lands on Etc/UTC.
  /// While [_tzIds] is still loading the list is empty, which the assertion
  /// explicitly allows, so any value is safe there.
  String _safeTzId(String current) {
    if (_tzIds.isEmpty || _tzIds.contains(current)) return current;
    if (_tzIds.contains(_kUtcTzId)) return _kUtcTzId;
    return _tzIds.first;
  }

  Future<void> _applyAutoTimezone() async {
    setState(() => _detecting = true);
    try {
      final detected = await FlutterTimezone.getLocalTimezone();
      await ref
          .read(appSettingsProvider.notifier)
          .set(SettingKeys.timezone, detected.identifier);
    } catch (_) {
      // Detection failed — keep the existing value.
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final isAuto = (settings[SettingKeys.timezoneMode] ?? 'Auto') == 'Auto';
    final currentTz = settings[SettingKeys.timezone] ?? _kUtcTzId;
    final safeId = _safeTzId(currentTz);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).setTimezone,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAuto
                          ? 'Auto-detected: ${_tzOffsetLabel(currentTz)}'
                          : 'Set timezone manually',
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              if (_detecting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: isAuto,
                  onChanged: (val) async {
                    await ref
                        .read(appSettingsProvider.notifier)
                        .set(SettingKeys.timezoneMode, val ? 'Auto' : 'Manual');
                    if (val) await _applyAutoTimezone();
                  },
                ),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context).autoLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
        if (!isAuto) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: DropdownButtonFormField<String>(
              // FormField seeds its state from initialValue ONCE. _tzIds loads
              // asynchronously, so safeId can legitimately change after the first
              // build (empty list → resolved id); without this the field would
              // keep serving the stale seed to the DropdownButton underneath.
              key: ValueKey(safeId),
              initialValue: safeId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).setIanaTimezone,
                labelStyle: TextStyle(fontSize: 13, color: theme.hintColor),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
              dropdownColor: theme.colorScheme.surfaceContainerHighest,
              items: _tzIds
                  .map(
                    (id) => DropdownMenuItem(
                      value: id,
                      child: Text(
                        _tzOffsetLabel(id),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(appSettingsProvider.notifier)
                      .set(SettingKeys.timezone, val);
                }
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Device-name editor dialog. Owns its [TextEditingController] so the controller
/// is disposed with the dialog's State (after the close animation), never inline
/// after showDialog() where a rebuild during the exit could touch it disposed.
class _DeviceNameDialog extends StatefulWidget {
  final String initial;
  const _DeviceNameDialog({required this.initial});

  @override
  State<_DeviceNameDialog> createState() => _DeviceNameDialogState();
}

class _DeviceNameDialogState extends State<_DeviceNameDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).setDeviceName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).posNameFullHint,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            // Same rules as onboarding's field: what's on screen is what gets
            // stored, instead of the name being silently rewritten on save.
            inputFormatters: const [DeviceNameInputFormatter()],
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).deviceNameLower,
              hintText: AppLocalizations.of(context).setHintCaisse,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: Text(AppLocalizations.of(context).actionSave),
        ),
      ],
    );
  }
}

/// Software update controls for the About tab.
///
/// Windows only — Android cannot silently self-install, so the card renders an
/// explanation there rather than a button that cannot work (same pattern as the
/// serial-scale card).
class _UpdateCard extends ConsumerWidget {
  const _UpdateCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (!UpdateService.isSupported) {
      return _SettingsCard(
        title: l10n.updateSectionTitle,
        children: [
          Text(
            l10n.updateUnsupportedPlatform,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    final status = ref.watch(updateControllerProvider);
    final blockers = ref.watch(updateBlockersProvider);
    final controller = ref.read(updateControllerProvider.notifier);

    return _SettingsCard(
      title: l10n.updateSectionTitle,
      children: [
        _SettingSwitch(
          settingKey: SettingKeys.autoCheckUpdates,
          label: l10n.updateAutoCheckLabel,
        ),
        const SizedBox(height: 8),
        _updateStatusLine(context, status),
        const SizedBox(height: 12),

        // Warnings sit above the action so they are read before it is pressed,
        // not after.
        for (final blocker in blockers)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  blocker.isFatal ? Icons.error_outline : Icons.info_outline,
                  size: 18,
                  color: blocker.isFatal
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _blockerMessage(context, ref, blocker),
                    style: TextStyle(
                      color: blocker.isFatal
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _updateAction(context, ref, status, blockers, controller),
        ),
      ],
    );
  }

  String _blockerMessage(
      BuildContext context, WidgetRef ref, UpdateBlocker blocker) {
    final l10n = AppLocalizations.of(context);
    switch (blocker) {
      case UpdateBlocker.activeCart:
        return l10n.updateBlockedByCart;
      case UpdateBlocker.unsyncedWork:
        final pending = ref.watch(pendingOrdersCountProvider).value ?? 0;
        return l10n.updatePendingWarning(pending);
    }
  }

  Widget _updateStatusLine(BuildContext context, UpdateStatus status) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final text = switch (status) {
      UpdateIdle() => '',
      UpdateChecking() => l10n.updateChecking,
      UpdateUpToDate() => l10n.updateUpToDate,
      UpdateAvailable(:final release) =>
        l10n.updateAvailableLabel(release.version.toString()),
      UpdateDownloading(:final fraction) => l10n.updateDownloadingLabel(
          fraction == null ? '…' : (fraction * 100).toStringAsFixed(0)),
      UpdateReadyToInstall() => l10n.updateRestartNotice,
      UpdateFailed(:final message) => '${l10n.updateFailedLabel} — $message',
    };

    if (text.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        if (status is UpdateDownloading) ...[
          const SizedBox(height: 8),
          // Indeterminate until the server declares a content length.
          LinearProgressIndicator(value: status.fraction),
        ],
      ],
    );
  }

  Widget _updateAction(
    BuildContext context,
    WidgetRef ref,
    UpdateStatus status,
    List<UpdateBlocker> blockers,
    UpdateController controller,
  ) {
    final l10n = AppLocalizations.of(context);

    switch (status) {
      case UpdateChecking():
        return const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );

      case UpdateAvailable(:final release):
        return FilledButton.icon(
          onPressed: () => controller.download(release),
          icon: const Icon(Icons.download),
          label: Text(l10n.updateDownloadAction),
        );

      case UpdateDownloading():
        return OutlinedButton.icon(
          onPressed: controller.cancelDownload,
          icon: const Icon(Icons.close),
          label: Text(l10n.updateCancelAction),
        );

      case UpdateReadyToInstall():
        // Disabled — not hidden — while a sale is open, so the reason stays on
        // screen next to the warning explaining it.
        final allowed = canInstallUpdate(blockers);
        return FilledButton.icon(
          onPressed: allowed ? () => _install(context, ref, controller) : null,
          icon: const Icon(Icons.restart_alt),
          label: Text(l10n.updateInstallAction),
        );

      default:
        return OutlinedButton.icon(
          onPressed: controller.check,
          icon: const Icon(Icons.system_update_alt),
          label: Text(l10n.updateCheckNow),
        );
    }
  }

  Future<void> _install(
      BuildContext context, WidgetRef ref, UpdateController controller) async {
    final launched = await controller.install();
    if (!context.mounted) return;

    if (!launched) {
      showAppSnackbar(
          context, ref, AppLocalizations.of(context).updateFailedLabel,
          isError: true);
      return;
    }

    // Windows cannot replace pos_app.exe while it is running — the installer is
    // waiting on exactly that. Give the detached process a moment to take hold,
    // then quit.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    exit(0);
  }
}
