// lib/settings_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/scale/scale_service.dart';
import 'package:pos_app/settings/local_ui_prefs.dart';
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
import 'package:pos_app/tax/tax_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:pos_app/settings/device_identity.dart';
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

  static const _tabs = [
    (icon: Icons.tune, label: 'General'),
    (icon: Icons.receipt_long, label: 'Order & Payment'),
    (icon: Icons.inventory_2, label: 'Products'),
    (icon: Icons.monitor_weight, label: 'Weighing Scale'),
    (icon: Icons.display_settings, label: 'Customer Display'),
    (icon: Icons.kitchen, label: 'Kitchen Display'),
    (icon: Icons.email, label: 'Email'),
    (icon: Icons.print, label: 'Print'),
    (icon: Icons.currency_exchange, label: 'Dual Currency'),
    (icon: Icons.storage, label: 'Database'),
    (icon: Icons.workspace_premium, label: 'Subscription'),
    (icon: Icons.info_outline, label: 'About'),
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
                width: 211, // 210 panel + 1px right divider
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
                        itemCount: _tabs.length,
                        itemBuilder: (context, i) => NavItem(
                          icon: _tabs[i].icon,
                          label: _tabs[i].label,
                          isActive: i == _selectedIndex,
                          onTap: () => _selectTab(i),
                        ),
                      ),
                    ),

                    // Divider separating the nav list from the pinned action.
                    Divider(height: 1, color: context.navDivider),

                    // Pinned "Save & Restart" action at the bottom of the sidebar —
                    // mirrors the "Exit Management" button in management_layout.dart.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: Material(
                          color: context.navAccent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _saveAndRestart,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.save_outlined,
                                    color: cs.onPrimary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Save & Restart',
                                    style: TextStyle(
                                      color: cs.onPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Settings',
              style: TextStyle(fontWeight: FontWeight.bold),
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
        showAppSnackbar(context, ref, '${widget.label} saved');
      }
    } catch (_) {
      if (mounted) {
        showAppSnackbar(
          context,
          ref,
          'Failed to save ${widget.label}',
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
                  tooltip: 'Save',
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

  const _SettingSwitch({
    required this.settingKey,
    required this.label,
    this.subtitle,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final value =
        ref.watch(appSettingsProvider)[settingKey]?.toLowerCase() == 'true';

    return SwitchListTile(
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
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
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
        title: const Text('Delete Service Type'),
        content: Text('Remove "${target.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
              Text('Service Types', style: theme.textTheme.labelLarge),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showTypeDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
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
                    'Prefix: ${t.prefix}',
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
      title: Text(widget.isEdit ? 'Edit Service Type' : 'Add Service Type'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Uber Eats',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.prefixCtrl,
            decoration: const InputDecoration(
              labelText: 'Order Number Prefix',
              hintText: 'e.g. UBER',
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = widget.nameCtrl.text.trim();
            final prefix = widget.prefixCtrl.text.trim().toUpperCase();
            if (name.isNotEmpty && prefix.isNotEmpty) {
              Navigator.pop(context, [name, prefix]);
            }
          },
          child: const Text('Save'),
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
        title: const Text('Delete Service Status'),
        content: Text('Remove "${target.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
              Text('Service Statuses', style: theme.textTheme.labelLarge),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showStatusDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
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
      title: Text(widget.isEdit ? 'Edit Service Status' : 'Add Service Status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Waiting',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          const Text('Color', style: TextStyle(fontSize: 12)),
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = widget.nameCtrl.text.trim();
            if (name.isNotEmpty) {
              Navigator.pop(context, {'name': name, 'colorValue': _selected});
            }
          },
          child: const Text('Save'),
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
      title: 'BOOKING',
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
                          'Resource Mode',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'What a booking slot is assigned to',
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
                    items: const [
                      DropdownMenuItem(
                        value: 'table',
                        child: Row(
                          children: [
                            Icon(Icons.table_restaurant, size: 16),
                            SizedBox(width: 6),
                            Text('Table'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'room',
                        child: Row(
                          children: [
                            Icon(Icons.meeting_room, size: 16),
                            SizedBox(width: 6),
                            Text('Room'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'staff',
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 16),
                            SizedBox(width: 6),
                            Text('Staff'),
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
                          'Default Duration',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pre-filled slot length when adding a booking',
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
                          'Time Snapping',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Grid interval when picking start/end times',
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
        loading: () => const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading currencies…'),
          ],
        ),
        error: (_, __) => Text(
          'Could not load currencies',
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
              labelText: 'Currency',
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
        hintText: 'Search all settings...',
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
                tooltip: 'Clear',
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

  const SearchableSetting({
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
    final matches = _kSearchableSettings
        .where((s) => s.matches(query))
        .toList();

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
                "No settings found matching '$query'",
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
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
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
      child: const Text('Open'),
    );
  }
}

/// The flat, catalogued index of every individually-addressable setting. The
/// trailing controls reuse the same [appSettingsProvider] plumbing as the tabs,
/// so editing from search and editing in a tab are the same operation.
///
/// Tab indices mirror `_SettingsScreenState._tabs`.
final _kSearchableSettings = <SearchableSetting>[
  // ── General ────────────────────────────────────────────────────────────────
  SearchableSetting(
    title: 'Default screen',
    tabName: 'General · Startup',
    tabIndex: 0,
    trailingBuilder: (_) => const _DropdownControl(SettingKeys.defaultScreen, [
      'POS',
      'Tables',
      'Booking',
    ]),
  ),
  SearchableSetting(
    title: 'Currency',
    tabName: 'General · Regional',
    tabIndex: 0,
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: 'Language',
    tabName: 'General · Regional',
    tabIndex: 0,
    trailingBuilder: (_) => const _DropdownControl(SettingKeys.language, [
      'en',
      'fr',
      'ar',
      'es',
      'de',
      'it',
      'pt',
    ]),
  ),
  SearchableSetting(
    title: 'Date Format',
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
    title: 'Timezone',
    tabName: 'General · Regional',
    tabIndex: 0,
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: 'Tax Included in Price by Default',
    tabName: 'General · Tax',
    tabIndex: 0,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.taxIncludedByDefault),
  ),
  SearchableSetting(
    title: 'Theme Mode',
    tabName: 'General · Appearance',
    tabIndex: 0,
    trailingBuilder: (_) => const _ThemeModeControl(),
  ),
  SearchableSetting(
    title: 'Accent Color',
    tabName: 'General · Appearance',
    tabIndex: 0,
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: 'Font Size',
    tabName: 'General · Appearance',
    tabIndex: 0,
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: 'Writing Direction',
    tabName: 'General · Application Style',
    tabIndex: 0,
    trailingBuilder: (_) =>
        const _DropdownControl(SettingKeys.writingDirection, ['LTR', 'RTL']),
  ),
  SearchableSetting(
    title: 'Enable Virtual Keyboard',
    tabName: 'General · Application Style',
    tabIndex: 0,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.enableVirtualKeyboard),
  ),
  SearchableSetting(
    title: 'Message Duration (seconds)',
    tabName: 'General · Messages',
    tabIndex: 0,
    trailingBuilder: (_) => const _NumericStepper(
      settingKey: SettingKeys.messageDuration,
      min: 1,
      max: 10,
    ),
  ),
  SearchableSetting(
    title: 'Message Position',
    tabName: 'General · Messages',
    tabIndex: 0,
    trailingBuilder: (_) =>
        const _DropdownControl(SettingKeys.messagePosition, ['Top', 'Bottom']),
  ),
  SearchableSetting(
    title: 'Show cash in on application start',
    tabName: 'General · Business Day',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showCashInOnStart),
  ),
  SearchableSetting(
    title: 'Select business day on application start',
    tabName: 'General · Business Day',
    tabIndex: 0,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.selectBusinessDayOnStart),
  ),
  SearchableSetting(
    title: 'Search button',
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showSearchBtn),
  ),
  SearchableSetting(
    title: 'Transfer button',
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showTransferBtn),
  ),
  SearchableSetting(
    title: 'Customer button',
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showCustomerBtn),
  ),
  SearchableSetting(
    title: 'Discount button',
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showDiscountBtn),
  ),
  SearchableSetting(
    title: 'Comment button',
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showCommentBtn),
  ),
  SearchableSetting(
    title: 'Refund button',
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showRefundBtn),
  ),
  SearchableSetting(
    title: 'Cash Drawer button',
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showCashDrawerBtn),
  ),
  SearchableSetting(
    title: 'Warehouse Switcher button',
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showWarehouseBtn),
  ),
  SearchableSetting(
    title: 'Bookings button',
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showBookingBtn),
  ),
  SearchableSetting(
    title: 'Tables / Floor Plan button',
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showTablesBtn),
  ),
  SearchableSetting(
    title: 'Send to Kitchen button',
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showKitchenBtn),
  ),
  SearchableSetting(
    title: 'Tax button',
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showTaxBtn),
  ),
  SearchableSetting(
    title: 'Change quantity button',
    tabName: 'General · POS Buttons',
    tabIndex: 0,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showQuantityBtn),
  ),
  SearchableSetting(
    title: 'API Base URL',
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
    title: 'Enable Floor Plan / Tables',
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
    title: 'Enable Bookings / Calendar',
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
    title: 'Tables Button Label',
    tabName: 'Order & Payment · Features',
    tabIndex: 1,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.tablesButtonLabel,
      hint: 'e.g. Tables, Rooms',
    ),
  ),
  SearchableSetting(
    title: 'Allow table-less orders',
    tabName: 'Order & Payment · Features',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.allowTablelessOrders),
  ),
  SearchableSetting(
    title: 'Allow walk-in table orders',
    tabName: 'Order & Payment · Features',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.allowWalkInTableOrders),
  ),
  SearchableSetting(
    title: 'Booking settings',
    tabName: 'Order & Payment · Booking',
    tabIndex: 1,
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: 'Default search',
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
    title: 'Show search options',
    tabName: 'Order & Payment · Items',
    tabIndex: 1,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showSearchOptions),
  ),
  SearchableSetting(
    title: 'Default discount type',
    tabName: 'Order & Payment · Items',
    tabIndex: 1,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.defaultDiscountType,
      ['Percentage', 'Fixed'],
    ),
  ),
  SearchableSetting(
    title: 'Separate row for each item',
    tabName: 'Order & Payment · Items',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.separateRowForEachItem),
  ),
  SearchableSetting(
    title: 'Prevent sale below cost price',
    tabName: 'Order & Payment · Items',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.preventSaleBelowCostPrice),
  ),
  SearchableSetting(
    title: 'Prevent negative inventory',
    tabName: 'Order & Payment · Items',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.preventNegativeInventory),
  ),
  SearchableSetting(
    title: 'Single user',
    tabName: 'Order & Payment · Users',
    tabIndex: 1,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.singleUser),
  ),
  SearchableSetting(
    title: 'Display receipt print dialog',
    tabName: 'Order & Payment · Payment',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.displayReceiptPrintDialog),
  ),
  SearchableSetting(
    title: 'Default due date (days)',
    tabName: 'Order & Payment · Payment',
    tabIndex: 1,
    trailingBuilder: (_) => const _NumericStepper(
      settingKey: SettingKeys.defaultDueDateDays,
      min: 0,
      max: 90,
    ),
  ),
  SearchableSetting(
    title: 'Merge items on receipt',
    tabName: 'Order & Payment · Payment',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.mergeItemsOnReceipt),
  ),
  SearchableSetting(
    title: 'Single item discount allowed',
    tabName: 'Order & Payment · Payment',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.singleItemDiscountAllowed),
  ),
  SearchableSetting(
    title: 'Require reason on void',
    tabName: 'Order & Payment · Void Items',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.requireReasonOnVoid),
  ),
  SearchableSetting(
    title: 'Track unconfirmed voided items',
    tabName: 'Order & Payment · Void Items',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.trackUnconfirmedVoidedItems),
  ),
  SearchableSetting(
    title: 'Request service type automatically',
    tabName: 'Order & Payment · Service Type',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.requestServiceTypeAutomatically),
  ),
  SearchableSetting(
    title: 'Default service type',
    tabName: 'Order & Payment · Service Type',
    tabIndex: 1,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.defaultServiceType,
      ['Dine-in', 'Takeaway', 'Delivery'],
    ),
  ),
  SearchableSetting(
    title: 'Print large order number in receipt',
    tabName: 'Order & Payment · Service Type',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.printLargeOrderNumberInReceipt),
  ),
  SearchableSetting(
    title: 'Service Type Selector',
    tabName: 'Order & Payment · Service Type',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.featureServiceTypeEnabled),
  ),
  SearchableSetting(
    title: 'Service Status Selector',
    tabName: 'Order & Payment · Service Type',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.featureServiceStatusEnabled),
  ),
  SearchableSetting(
    title: 'Reset order number on day close',
    tabName: 'Order & Payment · Advanced',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.resetOrderNumberOnDayClose),
  ),
  SearchableSetting(
    title: 'Show items on payment form',
    tabName: 'Order & Payment · Advanced',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.showItemsOnPaymentForm),
  ),
  SearchableSetting(
    title: 'Number of payment type rows',
    tabName: 'Order & Payment · Advanced',
    tabIndex: 1,
    trailingBuilder: (_) => const _NumericStepper(
      settingKey: SettingKeys.numberOfPaymentTypeRows,
      min: 0,
      max: 10,
    ),
  ),
  SearchableSetting(
    title: 'Show all occupied tables in floor plan',
    tabName: 'Order & Payment · Advanced',
    tabIndex: 1,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.showAllOccupiedTablesInFloorPlan),
  ),

  // ── Products ─────────────────────────────────────────────────────────────────
  SearchableSetting(
    title: 'Display and print items with tax included',
    tabName: 'Products · General',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.displayAndPrintTaxIncluded),
  ),
  SearchableSetting(
    title: 'Discount apply rule',
    tabName: 'Products · General',
    tabIndex: 2,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.discountApplyRule,
      ['Before tax', 'After tax'],
    ),
  ),
  SearchableSetting(
    title: 'Sorting',
    tabName: 'Products · General',
    tabIndex: 2,
    trailingBuilder: (_) => const _DropdownControl(SettingKeys.productSorting, [
      'Name',
      'Code',
      'Barcode',
    ]),
  ),
  SearchableSetting(
    title: 'Allow negative price',
    tabName: 'Products · General',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.allowNegativePrice),
  ),
  SearchableSetting(
    title: 'Show Product Images in POS Grid',
    tabName: 'Products · General',
    tabIndex: 2,
    trailingBuilder: (_) => const _SwitchControl(SettingKeys.showProductImages),
  ),
  SearchableSetting(
    title: 'Default warehouse',
    tabName: 'Products · Inventory',
    tabIndex: 2,
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: 'Default tax rate',
    tabName: 'Products · Product Defaults',
    tabIndex: 2,
    trailingBuilder: (openTab) => _OpenTabButton(openTab),
  ),
  SearchableSetting(
    title: 'Default Measurement Unit',
    tabName: 'Products · Product Defaults',
    tabIndex: 2,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.defaultMeasurementUnit,
      hint: 'e.g. pcs, kg, L',
    ),
  ),
  SearchableSetting(
    title: 'Default Barcode Format',
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
    title: 'Cost price based markup',
    tabName: 'Products · Product Defaults',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.costPriceBasedMarkup),
  ),
  SearchableSetting(
    title: 'Automatically update cost price on purchase',
    tabName: 'Products · Product Defaults',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.autoUpdateCostPrice),
  ),
  SearchableSetting(
    title: 'Update sale price based on markup',
    tabName: 'Products · Product Defaults',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.updateSalePriceOnMarkup),
  ),
  SearchableSetting(
    title: 'Enable moving average price',
    tabName: 'Products · Moving Average Price',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.enableMovingAveragePrice),
  ),
  SearchableSetting(
    title: 'Menu Grid Columns',
    tabName: 'Products · Menu Grid',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _DropdownControl(SettingKeys.menuGridCols, ['4', '5']),
  ),
  SearchableSetting(
    title: 'Menu Grid Rows',
    tabName: 'Products · Menu Grid',
    tabIndex: 2,
    trailingBuilder: (_) =>
        const _DropdownControl(SettingKeys.menuGridRows, ['3', '4', '5']),
  ),

  // ── Weighing Scale ───────────────────────────────────────────────────────────
  SearchableSetting(
    title: 'Enable weighing scales barcode',
    tabName: 'Weighing Scale · Barcode Parsing',
    tabIndex: 3,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.scaleBarcodeEnabled),
  ),
  SearchableSetting(
    title: 'First two digits / prefix',
    tabName: 'Weighing Scale · Barcode Parsing',
    tabIndex: 3,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.scaleBarcodePrefix,
      hint: 'e.g. 21',
    ),
  ),
  SearchableSetting(
    title: 'Number of digits for product code',
    tabName: 'Weighing Scale · Barcode Parsing',
    tabIndex: 3,
    trailingBuilder: (_) => const _NumericStepper(
      settingKey: SettingKeys.scaleBarcodeCodeLength,
      min: 1,
      max: 10,
    ),
  ),
  SearchableSetting(
    title: 'Number of decimal places',
    tabName: 'Weighing Scale · Barcode Parsing',
    tabIndex: 3,
    trailingBuilder: (_) => const _NumericStepper(
      settingKey: SettingKeys.scaleBarcodeDecimalPlaces,
      min: 0,
      max: 5,
    ),
  ),
  SearchableSetting(
    title: 'Remove zeros from product code (trim zeros)',
    tabName: 'Weighing Scale · Barcode Parsing',
    tabIndex: 3,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.scaleBarcodeTrimZeros),
  ),
  SearchableSetting(
    title: 'Scale prints price instead of quantity',
    tabName: 'Weighing Scale · Barcode Parsing',
    tabIndex: 3,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.scaleBarcodePrintsPrice),
  ),

  // ── Customer Display ─────────────────────────────────────────────────────────
  SearchableSetting(
    title: 'Customer display enabled',
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.customerDisplayEnabled),
  ),
  SearchableSetting(
    title: 'COM port',
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
    title: 'Bits per second',
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.customerDisplayBaudRate,
      ['1200', '2400', '4800', '9600', '19200', '38400', '57600', '115200'],
    ),
  ),
  SearchableSetting(
    title: 'Data bits',
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.customerDisplayDataBits,
      ['5', '6', '7', '8'],
    ),
  ),
  SearchableSetting(
    title: 'Parity',
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.customerDisplayParity,
      ['None', 'Even', 'Odd', 'Mark', 'Space'],
    ),
  ),
  SearchableSetting(
    title: 'Stop bits',
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.customerDisplayStopBits,
      ['1', '1.5', '2'],
    ),
  ),
  SearchableSetting(
    title: 'Flow control',
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) => const _DropdownControl(
      SettingKeys.customerDisplayFlowControl,
      ['None', 'RTS/CTS', 'XON/XOFF'],
    ),
  ),
  SearchableSetting(
    title: 'Number of characters',
    tabName: 'Customer Display',
    tabIndex: 4,
    trailingBuilder: (_) => const _NumericStepper(
      settingKey: SettingKeys.customerDisplayNumChars,
      min: 1,
      max: 40,
    ),
  ),
  SearchableSetting(
    title: 'Welcome message top line',
    tabName: 'Customer Display · Welcome Message',
    tabIndex: 4,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.customerDisplayWelcomeMessage,
      hint: 'WELCOME!',
    ),
  ),
  SearchableSetting(
    title: 'Welcome message bottom line',
    tabName: 'Customer Display · Welcome Message',
    tabIndex: 4,
    trailingBuilder: (_) =>
        const _TextFieldControl(SettingKeys.customerDisplayWelcomeBottom),
  ),
  SearchableSetting(
    title: 'Enable live web customer display',
    tabName: 'Customer Display · Screen Display (Web)',
    tabIndex: 4,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.customerDisplayWebEnabled),
  ),

  // ── Email ────────────────────────────────────────────────────────────────────
  SearchableSetting(
    title: 'SMTP Host',
    tabName: 'Email · SMTP Server',
    tabIndex: 6,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.emailSmtpHost,
      hint: 'smtp.gmail.com',
      keyboardType: TextInputType.url,
    ),
  ),
  SearchableSetting(
    title: 'SMTP Port',
    tabName: 'Email · SMTP Server',
    tabIndex: 6,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.emailSmtpPort,
      hint: '587',
      keyboardType: TextInputType.number,
    ),
  ),
  SearchableSetting(
    title: 'From Email Address',
    tabName: 'Email · Sender',
    tabIndex: 6,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.emailFromAddress,
      hint: 'pos@yourbusiness.com',
      keyboardType: TextInputType.emailAddress,
    ),
  ),
  SearchableSetting(
    title: 'From Name',
    tabName: 'Email · Sender',
    tabIndex: 6,
    trailingBuilder: (_) =>
        const _TextFieldControl(SettingKeys.emailFromName, hint: 'POS System'),
  ),
  SearchableSetting(
    title: 'Account / User Email',
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
    title: 'Dual Currency Enabled',
    tabName: 'Dual Currency',
    tabIndex: 8,
    trailingBuilder: (_) =>
        const _SwitchControl(SettingKeys.dualCurrencyEnabled),
  ),
  SearchableSetting(
    title: 'Secondary Currency Symbol',
    tabName: 'Dual Currency',
    tabIndex: 8,
    trailingBuilder: (_) =>
        const _TextFieldControl(SettingKeys.dualCurrencySymbol, hint: 'e.g. €'),
  ),
  SearchableSetting(
    title: 'Exchange Rate',
    tabName: 'Dual Currency',
    tabIndex: 8,
    trailingBuilder: (_) => const _TextFieldControl(
      SettingKeys.dualCurrencyRate,
      hint: 'e.g. 1.08',
      keyboardType: TextInputType.numberWithOptions(decimal: true),
    ),
  ),

  // ── Whole-screen panels (tap the row to open the tab) ────────────────────────
  const SearchableSetting(
    title: 'Kitchen Display',
    tabName: 'Kitchen Display',
    tabIndex: 5,
    navigational: true,
  ),
  const SearchableSetting(
    title: 'Printer & Receipt Settings',
    tabName: 'Print',
    tabIndex: 7,
    navigational: true,
  ),
  const SearchableSetting(
    title: 'Database & Backup',
    tabName: 'Database',
    tabIndex: 9,
    navigational: true,
  ),
  const SearchableSetting(
    title: 'Subscription',
    tabName: 'Subscription',
    tabIndex: 10,
    navigational: true,
  ),
  const SearchableSetting(
    title: 'About',
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

// ── Accent Color Picker ───────────────────────────────────────────────────────

class _AccentColorPicker extends ConsumerWidget {
  const _AccentColorPicker();

  static const _colors = [
    ('Blue', Color(0xFF2196F3)),
    ('Sky', Color(0xFF03A9F4)),
    ('Indigo', Color(0xFF3F51B5)),
    ('Green', Color(0xFF4CAF50)),
    ('Teal', Color(0xFF009688)),
    ('Emerald', Color(0xFF10B981)),
    ('Pink', Color(0xFFE91E63)),
    ('Rose', Color(0xFFF43F5E)),
    ('Purple', Color(0xFF9C27B0)),
    ('Violet', Color(0xFF7C3AED)),
    ('Orange', Color(0xFFFF9800)),
    ('Red', Color(0xFFF44336)),
    ('Amber', Color(0xFFFFC107)),
    ('Deep Orange', Color(0xFFFF5722)),
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
            'Accent Color',
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
                      name,
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

  String _label(double v) {
    if (v <= 0.85) return 'Small';
    if (v < 1.05) return 'Default';
    if (v < 1.2) return 'Large';
    return 'Larger';
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
                'Font Size',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${_label(value)}  (${(value * 100).round()}%)',
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
            'Preview: the quick brown fox',
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
            'Theme Mode',
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
                    opt.label,
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.palette,
                    size: 14,
                    color: Colors.white38,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'CHOOSE THEME',
                    style: TextStyle(
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
                  opt.label,
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
        title: const Text('Sign Out Device'),
        content: Text(
          _email != null
              ? 'This will unlink $_email from this terminal. '
                    'You will need to sign in online to use the POS again.'
              : 'This will unlink this terminal. '
                    'You will need to sign in online to use the POS again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out Device'),
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
    final ctrl = TextEditingController(text: ref.read(deviceNameProvider));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A short, UNIQUE name for this terminal. It becomes the prefix of '
              'every document number (e.g. CAISSE1-200-000045), so two POS never '
              'produce the same number. Letters & digits only.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Device name',
                hintText: 'e.g. CAISSE1',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    await ref.read(deviceNameProvider.notifier).setName(result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deviceName = ref.watch(deviceNameProvider);

    return _SettingsCard(
      title: 'DEVICE',
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
            deviceName.isEmpty ? 'Not set' : deviceName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('POS name — prefix for document numbers'),
          trailing: TextButton.icon(
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit'),
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
            _email ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('Registered account'),
          trailing: TextButton.icon(
            icon: Icon(Icons.logout, size: 16, color: cs.error),
            label: Text('Sign Out', style: TextStyle(color: cs.error)),
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
          title: 'STARTUP',
          children: [
            _SettingDropdown(
              settingKey: SettingKeys.defaultScreen,
              label: 'Default screen',
              options: defaultScreenOptions,
            ),
          ],
        ),
        const _SettingsCard(
          title: 'REGIONAL',
          children: [
            _CurrencyDropdown(),
            _SettingDropdown(
              settingKey: SettingKeys.language,
              label: 'Language',
              options: ['en', 'fr', 'ar', 'es', 'de', 'it', 'pt'],
            ),
            _SettingDropdown(
              settingKey: SettingKeys.dateFormat,
              label: 'Date Format',
              options: ['dd-MM-yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd', 'dd/MM/yyyy'],
            ),
            _TimezoneCard(),
          ],
        ),
        const _SettingsCard(
          title: 'TAX',
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.taxIncludedByDefault,
              label: 'Tax Included in Price by Default',
              subtitle:
                  'All new products will default to tax-inclusive pricing',
            ),
          ],
        ),
        const _SettingsCard(
          title: 'APPEARANCE',
          children: [
            _ThemeModePicker(),
            _AccentColorPicker(),
            _FontScalePicker(),
          ],
        ),
        const _SettingsCard(
          title: 'APPLICATION STYLE',
          children: [
            _SettingDropdown(
              settingKey: SettingKeys.writingDirection,
              label: 'Writing Direction',
              options: ['LTR', 'RTL'],
            ),
            _SettingSwitch(
              settingKey: SettingKeys.enableVirtualKeyboard,
              label: 'Enable Virtual Keyboard',
            ),
          ],
        ),
        const _SettingsCard(
          title: 'MESSAGES (NOTIFICATIONS)',
          children: [
            _StepperRow(
              label: 'Message Duration (seconds)',
              settingKey: SettingKeys.messageDuration,
              min: 1,
              max: 10,
            ),
            _SettingDropdown(
              settingKey: SettingKeys.messagePosition,
              label: 'Message Position',
              options: ['Top', 'Bottom'],
            ),
          ],
        ),
        const _SettingsCard(
          title: 'BUSINESS DAY',
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.showCashInOnStart,
              label: 'Show cash in on application start',
            ),
            _SettingSwitch(
              settingKey: SettingKeys.selectBusinessDayOnStart,
              label: 'Select business day on application start',
            ),
          ],
        ),
        _SettingsCard(
          title: 'POS BUTTON BAR',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Select which action buttons appear on the main POS screen.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.showSearchBtn,
              label: 'Search',
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.showTransferBtn,
              label: 'Transfer',
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.showCustomerBtn,
              label: 'Customer',
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.showDiscountBtn,
              label: 'Discount',
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.showCommentBtn,
              label: 'Comment',
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.showRefundBtn,
              label: 'Refund',
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.showCashDrawerBtn,
              label: 'Cash Drawer',
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.showWarehouseBtn,
              label: 'Warehouse Switcher',
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.showBookingBtn,
              label: 'Bookings',
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.showTablesBtn,
              label: 'Tables / Floor Plan',
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.showKitchenBtn,
              label: 'Send to Kitchen',
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.showTaxBtn,
              label: 'Tax',
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.showQuantityBtn,
              label: 'Change quantity',
            ),
          ],
        ),
        const _SettingsCard(
          title: 'API',
          children: [
            _SettingTextField(
              settingKey: SettingKeys.apiBaseUrl,
              label: 'API Base URL',
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

    return _TabScrollView(
      cards: [
        _SettingsCard(
          title: 'FEATURES',
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.featureFloorPlanEnabled,
              label: 'Enable Floor Plan / Tables',
              subtitle:
                  'Show the Tables button in the POS and allow floor plan navigation',
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
              label: 'Enable Bookings / Calendar',
              subtitle: 'Requires Floor Plan / Tables to be enabled',
              onChanged: (ref, enabled) {
                if (enabled) {
                  ref
                      .read(appSettingsProvider.notifier)
                      .setBool(SettingKeys.featureFloorPlanEnabled, true);
                }
              },
            ),
            const _SettingTextField(
              settingKey: SettingKeys.tablesButtonLabel,
              label: 'Tables Button Label',
              hint: 'e.g. Tables, Rooms, Resources',
            ),
            // Both only apply while the floor plan is on, so they're greyed out
            // (rather than hidden) when it's off — a control that silently
            // vanishes reads as a bug, one that's visibly disabled explains why.
            _SettingSwitch(
              settingKey: SettingKeys.allowTablelessOrders,
              label: 'Allow table-less orders',
              subtitle:
                  'Ring up a dine-in order without picking a table, even with '
                  'Floor Plan / Tables enabled',
              enabled: floorPlanEnabled,
            ),
            _SettingSwitch(
              settingKey: SettingKeys.allowWalkInTableOrders,
              label: 'Allow walk-in table orders',
              subtitle:
                  'Start an order on a free table without a booking. When off, '
                  'a table can only be opened from its booking',
              enabled: floorPlanEnabled,
            ),
          ],
        ),
        const _BookingSettingsCard(),
        const _SettingsCard(
          title: 'ITEMS',
          children: [
            _SettingDropdown(
              settingKey: SettingKeys.defaultSearch,
              label: 'Default search',
              options: ['Name', 'Code', 'Barcode', 'All fields'],
            ),
            _SettingSwitch(
              settingKey: SettingKeys.showSearchOptions,
              label: 'Show search options',
            ),
            _SettingDropdown(
              settingKey: SettingKeys.defaultDiscountType,
              label: 'Default discount type',
              options: ['Percentage', 'Fixed'],
            ),
            _SettingSwitch(
              settingKey: SettingKeys.separateRowForEachItem,
              label: 'Separate row for each item',
            ),
            _SettingSwitch(
              settingKey: SettingKeys.preventSaleBelowCostPrice,
              label: 'Prevent sale below cost price',
            ),
            _SettingSwitch(
              settingKey: SettingKeys.preventNegativeInventory,
              label: 'Prevent negative inventory',
            ),
          ],
        ),
        const _SettingsCard(
          title: 'USERS',
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.singleUser,
              label: 'Single user',
            ),
          ],
        ),
        const _SettingsCard(
          title: 'PAYMENT',
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.displayReceiptPrintDialog,
              label: 'Display receipt print dialog',
            ),
            _StepperRow(
              label: 'Default due date (days)',
              settingKey: SettingKeys.defaultDueDateDays,
              min: 0,
              max: 90,
            ),
            _SettingSwitch(
              settingKey: SettingKeys.mergeItemsOnReceipt,
              label: 'Merge items on receipt',
            ),
            _SettingSwitch(
              settingKey: SettingKeys.singleItemDiscountAllowed,
              label: 'Single item discount allowed',
            ),
          ],
        ),
        const _SettingsCard(
          title: 'VOID ITEMS',
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.requireReasonOnVoid,
              label: 'Require reason on void',
            ),
            _SettingSwitch(
              settingKey: SettingKeys.trackUnconfirmedVoidedItems,
              label: 'Track unconfirmed voided items',
            ),
          ],
        ),
        _SettingsCard(
          title: 'SERVICE TYPE',
          children: [
            const _SettingSwitch(
              settingKey: SettingKeys.requestServiceTypeAutomatically,
              label: 'Request service type automatically',
            ),
            const _SettingDropdown(
              settingKey: SettingKeys.defaultServiceType,
              label: 'Default service type',
              options: ['Dine-in', 'Takeaway', 'Delivery'],
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.printLargeOrderNumberInReceipt,
              label: 'Print large order number in receipt',
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.featureServiceTypeEnabled,
              label: 'Service Type Selector',
              subtitle:
                  'Show order type buttons (e.g. Dine-In, Takeaway) on the POS',
            ),
            Opacity(
              opacity: typeEnabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !typeEnabled,
                child: const _CustomServiceTypesEditor(),
              ),
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.featureServiceStatusEnabled,
              label: 'Service Status Selector',
              subtitle: 'Show service status badge on table/booking cards',
            ),
            Opacity(
              opacity: statusEnabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !statusEnabled,
                child: const _CustomServiceStatusesEditor(),
              ),
            ),
          ],
        ),
        const _SettingsCard(
          title: 'ADVANCED SETTINGS',
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.resetOrderNumberOnDayClose,
              label: 'Reset order number on day close',
            ),
            _SettingSwitch(
              settingKey: SettingKeys.showItemsOnPaymentForm,
              label: 'Show items on payment form',
            ),
            _StepperRow(
              label: 'Number of payment type rows',
              settingKey: SettingKeys.numberOfPaymentTypeRows,
              min: 0,
              max: 10,
            ),
            _SettingSwitch(
              settingKey: SettingKeys.showAllOccupiedTablesInFloorPlan,
              label: 'Show all occupied tables in floor plan',
            ),
          ],
        ),
      ],
    );
  }
}

// ── Products ──────────────────────────────────────────────────────────────────

/// "Default tax rate" picker. Lists every tax from the local Drift cache
/// (`allTaxesProvider`) as toggleable chips and persists the chosen IDs as a
/// comma-separated string in [SettingKeys.defaultTaxRateIds]. The cart reads
/// the same setting to auto-apply these taxes when a product is added without
/// its own tax assignments — exactly what selecting taxes manually produces.
class _DefaultTaxRatesSelector extends ConsumerWidget {
  const _DefaultTaxRatesSelector();

  Set<int> _selectedIds(String? raw) => (raw ?? '')
      .split(',')
      .map((e) => int.tryParse(e.trim()))
      .whereType<int>()
      .toSet();

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final taxesAsync = ref.watch(allTaxesProvider);
    final selected = _selectedIds(
      ref.watch(appSettingsProvider)[SettingKeys.defaultTaxRateIds],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Default tax rate',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Automatically applied to products added to the cart that have no '
            'tax of their own.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
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
              'Could not load tax rates',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
            data: (taxes) {
              final enabled = taxes.where((t) => t.isEnabled).toList();
              if (enabled.isEmpty) {
                return Text(
                  'No tax rates defined yet. Add them under Tax Rates.',
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
                  for (final tax in enabled)
                    FilterChip(
                      label: Text(
                        '${tax.name} '
                        '(${_formatRate(tax.rate, tax.isFixed)})',
                      ),
                      selected: selected.contains(tax.id),
                      onSelected: (on) => _toggle(ref, selected, tax.id, on),
                      showCheckmark: true,
                      selectedColor: cs.primaryContainer,
                      checkmarkColor: cs.onPrimaryContainer,
                      backgroundColor: cs.surfaceContainerHighest,
                      side: BorderSide(
                        color: selected.contains(tax.id)
                            ? cs.primary
                            : cs.outline.withValues(alpha: 0.3),
                      ),
                      labelStyle: TextStyle(
                        color: selected.contains(tax.id)
                            ? cs.onPrimaryContainer
                            : cs.onSurface,
                        fontWeight: selected.contains(tax.id)
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _formatRate(double rate, bool isFixed) {
    final n = rate == rate.roundToDouble()
        ? rate.toStringAsFixed(0)
        : rate.toString();
    return isFixed ? n : '$n%';
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
                  'Default warehouse',
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
                    'Could not load warehouses',
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
                      hint: const Text('Select…'),
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
            'Used to check product stock availability in the POS menu.',
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

    return _TabScrollView(
      cards: [
        const _SettingsCard(
          title: 'GENERAL',
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.displayAndPrintTaxIncluded,
              label: 'Display and print items with tax included',
            ),
            _SettingDropdown(
              settingKey: SettingKeys.discountApplyRule,
              label: 'Discount apply rule',
              options: ['Before tax', 'After tax'],
            ),
            _SettingDropdown(
              settingKey: SettingKeys.productSorting,
              label: 'Sorting',
              options: ['Name', 'Code', 'Barcode'],
            ),
            _SettingSwitch(
              settingKey: SettingKeys.allowNegativePrice,
              label: 'Allow negative price',
            ),
            _SettingSwitch(
              settingKey: SettingKeys.showProductImages,
              label: 'Show Product Images in POS Grid',
            ),
          ],
        ),
        const _SettingsCard(
          title: 'INVENTORY',
          children: [_DefaultWarehouseDropdown()],
        ),
        _SettingsCard(
          title: 'PRODUCT DEFAULTS',
          children: [
            const _DefaultTaxRatesSelector(),
            const Divider(height: 1, indent: 20, endIndent: 20),
            const _SettingTextField(
              settingKey: SettingKeys.defaultMeasurementUnit,
              label: 'Default Measurement Unit',
              hint: 'e.g. pcs, kg, L',
            ),
            const _SettingDropdown(
              settingKey: SettingKeys.barcodeFormat,
              label: 'Default Barcode Format',
              options: ['EAN-13', 'EAN-8', 'UPC-A', 'Code128', 'QR'],
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.costPriceBasedMarkup,
              label: 'Cost price based markup',
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.autoUpdateCostPrice,
              label: 'Automatically update cost price on purchase',
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Opacity(
                opacity: autoUpdateCost ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !autoUpdateCost,
                  child: const _SettingSwitch(
                    settingKey: SettingKeys.updateSalePriceOnMarkup,
                    label: 'Update sale price based on markup',
                  ),
                ),
              ),
            ),
          ],
        ),
        const _SettingsCard(
          title: 'MOVING AVERAGE PRICE',
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.enableMovingAveragePrice,
              label: 'Enable moving average price',
            ),
          ],
        ),
        const _SettingsCard(
          title: 'MENU GRID',
          children: [
            _SettingDropdown(
              settingKey: SettingKeys.menuGridCols,
              label: 'Columns',
              options: ['4', '5'],
            ),
            _SettingDropdown(
              settingKey: SettingKeys.menuGridRows,
              label: 'Rows',
              options: ['3', '4', '5'],
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
    final barcodeOn =
        settings[SettingKeys.scaleBarcodeEnabled]?.toLowerCase() == 'true';
    final serialOn =
        settings[SettingKeys.scaleEnabled]?.toLowerCase() == 'true';

    return _TabScrollView(
      cards: [
        _SettingsCard(
          title: 'BARCODE PARSING',
          children: [
            const _SettingSwitch(
              settingKey: SettingKeys.scaleBarcodeEnabled,
              label: 'Enable weighing scales barcode',
              subtitle:
                  'Parse weight/price from barcodes printed by a weighing scale',
            ),
            Opacity(
              opacity: barcodeOn ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !barcodeOn,
                child: const Column(
                  children: [
                    _SettingTextField(
                      settingKey: SettingKeys.scaleBarcodePrefix,
                      label: 'First two digits / prefix',
                      hint: 'e.g. 21',
                    ),
                    _StepperRow(
                      label: 'Number of digits for product code',
                      settingKey: SettingKeys.scaleBarcodeCodeLength,
                      min: 1,
                      max: 10,
                    ),
                    _StepperRow(
                      label: 'Number of decimal places',
                      settingKey: SettingKeys.scaleBarcodeDecimalPlaces,
                      min: 0,
                      max: 5,
                    ),
                    _SettingSwitch(
                      settingKey: SettingKeys.scaleBarcodeTrimZeros,
                      label: 'Remove zeros from product code (trim zeros)',
                      subtitle:
                          'Strip leading zeros before looking up the product',
                    ),
                    _SettingSwitch(
                      settingKey: SettingKeys.scaleBarcodePrintsPrice,
                      label: 'Scale prints price instead of quantity',
                      subtitle:
                          'When on, the encoded value is a price and quantity is calculated as price ÷ unit price',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        _SettingsCard(
          title: 'SERIAL CONNECTION',
          children: [
            if (!kScaleSupported)
              const _ScaleUnsupportedNotice()
            else ...[
              const _SettingSwitch(
                settingKey: SettingKeys.scaleEnabled,
                label: 'Read live weight from a serial scale',
                subtitle:
                    'Streams the weight from a scale on a COM port into the quantity keypad',
              ),
              Opacity(
                opacity: serialOn ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !serialOn,
                  child: const Column(
                    children: [
                      _ScalePortDropdown(),
                      _SettingDropdown(
                        settingKey: SettingKeys.scaleBaudRate,
                        label: 'Baud rate',
                        options: _kBaudRates,
                      ),
                      _ScaleLiveTest(),
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
              'Serial scales are supported on Windows only. On this device, use '
              'the barcode parsing option above with a label-printing scale.',
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
            tooltip: 'Rescan ports',
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
        error is ScaleException ? error.message : 'Scale error: $error',
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
        'Waiting for the scale to send a weight…',
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
    if (mounted) showAppSnackbar(context, ref, 'Test message sent.');
  }

  // ── Web server helpers ──────────────────────────────────────────────────────

  Future<void> _startWeb() async {
    await CustomerDisplayWebServer.instance.start();
    // Pre-load the Lottie animation so /lottie.json can be served to browsers.
    try {
      final data = await rootBundle.load(
        'assets/animations/success_animation.json',
      );
      CustomerDisplayWebServer.instance.setLottieJson(
        utf8.decode(data.buffer.asUint8List()),
      );
    } catch (_) {}
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
          title: 'CUSTOMER DISPLAY',
          children: [
            // Enabled
            const _SettingSwitch(
              settingKey: SettingKeys.customerDisplayEnabled,
              label: 'Enabled',
              subtitle: 'Show order total on a serial VFD / LCD pole display',
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
                          const Expanded(
                            child: _SettingDropdown(
                              settingKey: SettingKeys.customerDisplayPort,
                              label: 'COM port',
                              options: [
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
                            const _SettingDropdown(
                              settingKey: SettingKeys.customerDisplayBaudRate,
                              label: 'Bits per second',
                              options: [
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
                            const _SettingDropdown(
                              settingKey: SettingKeys.customerDisplayDataBits,
                              label: 'Data bits',
                              options: ['5', '6', '7', '8'],
                            ),
                            const _SettingDropdown(
                              settingKey: SettingKeys.customerDisplayParity,
                              label: 'Parity',
                              options: ['None', 'Even', 'Odd', 'Mark', 'Space'],
                            ),
                            const _SettingDropdown(
                              settingKey: SettingKeys.customerDisplayStopBits,
                              label: 'Stop bits',
                              options: ['1', '1.5', '2'],
                            ),
                            const _SettingDropdown(
                              settingKey:
                                  SettingKeys.customerDisplayFlowControl,
                              label: 'Flow control',
                              options: ['None', 'RTS/CTS', 'XON/XOFF'],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: _restorePortDefaults,
                                  child: Text(
                                    'Restore defaults',
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
                    const _StepperRow(
                      label: 'Number of characters',
                      settingKey: SettingKeys.customerDisplayNumChars,
                      min: 1,
                      max: 40,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Welcome message card
        _SettingsCard(
          title: 'WELCOME MESSAGE',
          children: [
            const _SettingTextField(
              settingKey: SettingKeys.customerDisplayWelcomeMessage,
              label: 'Top line',
              hint: 'WELCOME!',
            ),
            const _SettingTextField(
              settingKey: SettingKeys.customerDisplayWelcomeBottom,
              label: 'Bottom line',
              hint: '',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: OutlinedButton(
                onPressed: enabled ? _testDisplay : null,
                child: const Text('Test display'),
              ),
            ),
          ],
        ),

        // ── Open on this device (always available, no web server needed) ───
        _SettingsCard(
          title: 'OPEN ON THIS DEVICE',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                'Opens the customer display as a full-screen Flutter view on this machine. '
                'Ideal for a second monitor — drag the window over and press F11.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open customer display'),
                onPressed: () async {
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
          title: 'SCREEN DISPLAY (WEB)',
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.customerDisplayWebEnabled,
              label: 'Enable live web customer display',
              subtitle:
                  'Host an interactive order screen accessible from any browser on your network',
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
                            'Same machine / second monitor',
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
                      tooltip: 'Open in browser (drag to second monitor)',
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
                            'Other device on same network',
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
                      tooltip: 'Copy LAN URL',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: displayUrl));
                        showAppSnackbar(context, ref, 'URL copied');
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
                      'Scan the QR code to open the customer display on any internet-connected device.',
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
      showAppSnackbar(context, ref, 'Enter a group name.', isError: true);
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
              decoration: const InputDecoration(
                hintText: 'Name',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            Text('Categories', style: theme.textTheme.titleMedium),
            Text(
              'Categories printed on this printer group',
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
                  _row(PrinterGroup.noCategoryId, 'No category'),
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
          child: const Text('CANCEL'),
        ),
        TextButton(onPressed: _save, child: const Text('SAVE')),
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
      'Pairing request sent to $ip — the KDS should switch to '
      'the kitchen view.',
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
          title: 'PRINTER GROUPS',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Group product categories into stations (e.g. Kitchen, Barman). '
                'Assign a group to a display below and that display only shows '
                'the items in those categories.',
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
                  'No printer groups yet.',
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
                subtitle: Text('$n categor${n == 1 ? 'y' : 'ies'}'),
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
                      tooltip: 'Edit',
                      onPressed: () => _editPrinterGroup(existing: g),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: cs.error,
                        size: 20,
                      ),
                      tooltip: 'Delete',
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
                  label: const Text('Add Printer Group'),
                ),
              ),
            ),
          ],
        ),
        _SettingsCard(
          title: 'KITCHEN DISPLAY TABLETS',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Each Kitchen Display tablet listens on port $kKdsPort. Adding its '
                'IP pairs it with this POS and pushes orders directly over the '
                'local network — the KDS works fully offline, no internet needed.',
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
                  'No kitchen displays configured.',
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
                          tooltip: 'Re-pair',
                          onPressed: () => _pairIp(ip),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: cs.error,
                            size: 20,
                          ),
                          tooltip: 'Remove',
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
                            'Receives all items. Create printer groups above to '
                            'route by category.',
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
                                    'No group selected → receives all items.',
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
                        decoration: const InputDecoration(
                          labelText: 'KDS IP address',
                          hintText: '192.168.1.100',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.lan_outlined, size: 18),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter an IP address';
                          }
                          final parts = v.trim().split('.');
                          if (parts.length != 4) {
                            return 'Invalid IP (e.g. 192.168.1.100)';
                          }
                          if (parts.any((p) => int.tryParse(p) == null)) {
                            return 'Invalid IP';
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
                      label: const Text('Add'),
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
    return const _TabScrollView(
      cards: [
        _SettingsCard(
          title: 'SMTP SERVER',
          children: [
            _SettingTextField(
              settingKey: SettingKeys.emailSmtpHost,
              label: 'SMTP Host',
              hint: 'smtp.gmail.com',
              keyboardType: TextInputType.url,
            ),
            _SettingTextField(
              settingKey: SettingKeys.emailSmtpPort,
              label: 'SMTP Port',
              hint: '587',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        _SettingsCard(
          title: 'SENDER',
          children: [
            _SettingTextField(
              settingKey: SettingKeys.emailFromAddress,
              label: 'From Email Address',
              hint: 'pos@yourbusiness.com',
              keyboardType: TextInputType.emailAddress,
            ),
            _SettingTextField(
              settingKey: SettingKeys.emailFromName,
              label: 'From Name',
              hint: 'POS System',
            ),
            _SettingTextField(
              settingKey: SettingKeys.emailUserEmail,
              label: 'Account / User Email',
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
    return const _TabScrollView(
      cards: [
        _SettingsCard(
          title: 'DUAL CURRENCY',
          children: [
            _SettingSwitch(
              settingKey: SettingKeys.dualCurrencyEnabled,
              label: 'Dual Currency Enabled',
              subtitle:
                  'Display prices and totals in a second currency simultaneously',
            ),
            _SettingTextField(
              settingKey: SettingKeys.dualCurrencySymbol,
              label: 'Secondary Currency Symbol',
              hint: 'e.g. €',
            ),
            _SettingTextField(
              settingKey: SettingKeys.dualCurrencyRate,
              label: 'Exchange Rate',
              hint: 'e.g. 1.08  (1 primary = X secondary)',
              keyboardType: TextInputType.numberWithOptions(decimal: true),
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
    // If no backup location is configured yet, ask the user to pick one first.
    var backupDir =
        ref.read(appSettingsProvider)[SettingKeys.dbBackupPath] ?? '';
    if (backupDir.trim().isEmpty) {
      final picked = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Backup Folder',
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
        showAppSnackbar(context, ref, 'Backup saved: ${p.basename(destPath)}');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Backup failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  /// Picks a folder if none is configured, saves it, then opens it in Explorer.
  Future<void> _openLocation() async {
    var dir = ref.read(appSettingsProvider)[SettingKeys.dbBackupPath] ?? '';
    if (dir.trim().isEmpty) {
      final picked = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Backup Folder',
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
          title: 'AUTO SYNC',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Text(
                'Push your local changes and pull fresh data automatically in '
                'the background.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.autoSyncEnabled,
              label: 'Enable auto-sync',
            ),
            if (autoSyncEnabled)
              const _SettingDropdown(
                settingKey: SettingKeys.autoSyncMode,
                label: 'When to sync',
                options: ['After every save', 'Every 1 hour'],
              ),
            const _SettingSwitch(
              settingKey: SettingKeys.autoSyncShowNotification,
              label: 'Show sync notification',
              subtitle: 'Display a toast each time a sync completes',
            ),
          ],
        ),

        // ── Backup now ────────────────────────────────────────────────────────
        _SettingsCard(
          title: 'DATABASE',
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
                label: Text(_isBackingUp ? 'Backing up…' : 'Backup database'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
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
                  'Open database location',
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
          title: 'AUTOMATIC BACKUPS',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Text(
                'Automatically create backup copies of your data to protect against loss or corruption',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const _SettingSwitch(
              settingKey: SettingKeys.dbAutoBackup,
              label: 'Enable automatic backups',
            ),
            Opacity(
              opacity: autoEnabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !autoEnabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SettingSwitch(
                      settingKey: SettingKeys.dbBackupOnStart,
                      label: 'Backup database on application start',
                    ),
                    const _SettingSwitch(
                      settingKey: SettingKeys.dbBackupOnClose,
                      label: 'Backup database on application close',
                    ),
                    const _StepperRow(
                      label: 'Back up automatically every',
                      settingKey: SettingKeys.dbBackupIntervalHours,
                      min: 0,
                      max: 168,
                      suffix: 'hours',
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Text(
                        'Set to 0 to turn off scheduled backups',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const _BackupLocationField(),
                    const _SettingSwitch(
                      settingKey: SettingKeys.dbBackupAutoDelete,
                      label: 'Delete old backups automatically',
                    ),
                    Opacity(
                      opacity: autoDelete ? 1.0 : 0.4,
                      child: IgnorePointer(
                        ignoring: !autoDelete,
                        child: const _StepperRow(
                          label: 'Delete backups older than',
                          settingKey: SettingKeys.dbBackupRetentionDays,
                          min: 1,
                          max: 365,
                          suffix: 'days',
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
      dialogTitle: 'Select Backup Folder',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                labelText: 'Backup location',
                hintText: Platform.isWindows
                    ? r'e.g. D:\database\Backup'
                    : 'e.g. /home/user/backups',
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
            title: 'SUBSCRIPTION',
            children: [_InfoRow(label: 'Error', value: e.toString())],
          ),
        ],
      ),
      data: (info) => _TabScrollView(
        cards: [
          _SettingsCard(
            title: 'SUBSCRIPTION',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Row(children: [_SubscriptionStatusPill(info: info)]),
              ),
              _InfoRow(
                label: 'Started',
                value: _fmtSubscriptionDate(info.startedAt),
              ),
              _InfoRow(
                label: 'Renews / ends',
                value: _fmtSubscriptionDate(info.periodEnd ?? info.validUntil),
              ),
              // Allowance 0 = no subscription row provisioned upstream, NOT an
              // unlimited plan — say nothing rather than imply a cap either way.
              _InfoRow(
                label: 'Devices',
                value: info.seatAllowance > 0
                    ? '${info.seatAllowance} '
                          '${info.seatAllowance == 1 ? 'device' : 'devices'}'
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
      LicenseState.active => (
        info.daysLeft <= 7
            ? 'Expires in ${info.daysLeft} '
                  '${info.daysLeft == 1 ? 'day' : 'days'}'
            : 'Active',
        Icons.check_circle,
        info.daysLeft <= 7 ? context.warningColor : context.successColor,
      ),
      LicenseState.expired => (
        'Expired',
        Icons.error,
        Theme.of(context).colorScheme.error,
      ),
      LicenseState.tampered => (
        'Invalid',
        Icons.gpp_bad,
        Theme.of(context).colorScheme.error,
      ),
      LicenseState.unknown => (
        'Not activated',
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
                  company?.name ?? 'POS System',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
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

          // ── Company ───────────────────────────────────────────────────────
          _SettingsCard(
            title: 'COMPANY',
            children: [
              _InfoRow(label: 'Name', value: company?.name ?? '–'),
              _InfoRow(label: 'Tax No', value: company?.taxNumber ?? '–'),
              _InfoRow(label: 'Phone', value: company?.phoneNumber ?? '–'),
              _InfoRow(label: 'Address', value: company?.address ?? '–'),
            ],
          ),

          // ── Database ──────────────────────────────────────────────────────
          statsAsync.when(
            loading: () => const _SettingsCard(
              title: 'DATABASE',
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
            error: (e, _) => _SettingsCard(
              title: 'DATABASE',
              children: [_InfoRow(label: 'Error', value: e.toString())],
            ),
            data: (s) => _SettingsCard(
              title: 'DATABASE',
              children: [
                _InfoRow(label: 'Products', value: '${s.productCount}'),
                _InfoRow(label: 'Customers', value: '${s.customerCount}'),
                _InfoRow(label: 'Users', value: '${s.userCount}'),
                _InfoRow(label: 'DB Size', value: s.dbSizeFormatted),
                _InfoRow(
                  label: 'Last Sync',
                  value: s.lastSync != null
                      ? _fmtAboutDt(s.lastSync!)
                      : 'Never',
                ),
              ],
            ),
          ),

          // ── System ────────────────────────────────────────────────────────
          _SettingsCard(
            title: 'SYSTEM INFO',
            children: [
              _InfoRow(
                label: 'Currency',
                value: settings[SettingKeys.currencySymbol] ?? '–',
              ),
              _InfoRow(
                label: 'Language',
                value: settings[SettingKeys.language] ?? '–',
              ),
              _InfoRow(
                label: 'Date Format',
                value: settings[SettingKeys.dateFormat] ?? '–',
              ),
              _InfoRow(
                label: 'Dual Currency',
                value: settings[SettingKeys.dualCurrencyEnabled] == 'true'
                    ? 'Enabled'
                    : 'Disabled',
              ),
              _InfoRow(
                label: 'Auto Backup',
                value: settings[SettingKeys.dbAutoBackup] == 'true'
                    ? 'On'
                    : 'Off',
              ),
            ],
          ),

          // ── Onboarding ────────────────────────────────────────────────────
          _SettingsCard(
            title: 'ONBOARDING',
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replay the first-run welcome tour. It shows again the '
                        'next time you open the app on this device.',
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('Replay'),
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
                            'Onboarding will show the next time you open the app.',
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
                      'Timezone',
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
                'Auto',
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
                labelText: 'IANA Timezone',
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
