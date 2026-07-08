import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:dio/dio.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/security/security_key_model.dart';
import 'package:pos_app/security/security_key_provider.dart';
import 'package:pos_app/utils/api_error_parser.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class UsersScreen extends ConsumerWidget {
  /// Passed by ManagementLayout when the sidebar is hidden so the AppBar can
  /// show a menu icon rather than the default back arrow.
  final VoidCallback? onMenuPressed;

  const UsersScreen({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(selectedCompanyProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          // Suppress the auto back-arrow — ManagementLayout controls navigation.
          automaticallyImplyLeading: false,
          leading: onMenuPressed != null
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Show navigation',
                  onPressed: onMenuPressed,
                )
              : null,
          title: const Text("Users & Security"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: "Users"),
              Tab(icon: Icon(Icons.security), text: "Security Rules"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: "Add User",
              onPressed: company == null
                  ? null
                  : () => showDialog(
                      context: context,
                      builder: (_) => _AddUserDialog(companyId: company.id),
                    ),
            ),
          ],
        ),
        body: const TabBarView(children: [_UsersListTab(), _SecurityKeysTab()]),
      ),
    );
  }
}

class _SecurityKeysTab extends ConsumerWidget {
  const _SecurityKeysTab();

  String _getCategory(String key) {
    if (key == 'Management.Stock.QuickInventory' ||
        key == 'Management.Stock.ShowCostPrices') {
      return 'Stock';
    }
    if (key.startsWith('Management.') && key != 'Management') {
      return 'Management';
    }
    if (key == 'Management' ||
        key == 'Settings' ||
        key == 'BusinessDay.Close' ||
        key == 'UserProfile' ||
        key == 'ShiftManagement' ||
        key == 'CashMovement' ||
        key == 'FloorPlans.Design' ||
        key == 'FloorPlans.View' ||
        key == 'Bookings' ||
        key == 'Bookings.History') {
      return 'General';
    }
    return 'Sales';
  }

  String _getFriendlyName(String key) {
    final names = {
      'Management': 'Management',
      'Settings': 'Settings',
      'BusinessDay.Close': 'End of day',
      'UserProfile': 'User profile',
      'ShiftManagement': 'Shift management',
      'CashMovement': 'Cash in / out',
      'FloorPlans.Design': 'Design floor plans',
      'FloorPlans.View': 'Floor plan / tables',
      'Bookings': 'Bookings',
      'Bookings.History': 'Booking history',
      'Order.All': 'View all open orders',
      'Order.Void': 'Void order',
      'Order.Item.Void': 'Void item',
      'Order.Estimate': 'Create estimate',
      'Order.Estimate.Clear': 'Clear estimate',
      'Order.Transfer': 'Transfer order',
      'Payment.Discount': 'Apply discount',
      'Invoices.Delete': 'Delete document',
      'Refund': 'Refund',
      'Payment.TaxOverride': 'Override taxes',
      'SalesHistory': 'View sales history',
      'SalesHistory.Receipt': 'Reprint receipt',
      'CreditPayments': 'Credit payments',
      'StartingCash': 'Starting cash',
      'CashDrawer.Open': 'Open cash drawer',
      'Stock.Control.NegativeQuantity': 'Zero stock quantity sale',
      'Management.Dashboard': 'Dashboard',
      'Management.Documents': 'Documents',
      'Management.Products': 'Products',
      'Management.ProductGroups': 'Product groups',
      'Management.Stock': 'Stock',
      'Management.Warehouses': 'Warehouses',
      'Management.Reporting': 'Reporting',
      'Management.Customers': 'Customers & suppliers',
      'Management.Promotions': 'Promotions',
      'Management.Security': 'Users & security',
      'Management.PaymentTypes': 'Payment types',
      'Management.Countries': 'Countries',
      'Management.Currencies': 'Currencies',
      'Management.TaxRates': 'Tax rates',
      'Management.Company': 'My company',
      'Management.VoidReasons': 'Void reasons',
      'Management.Stock.QuickInventory': 'Quick inventory',
      'Management.Stock.ShowCostPrices': 'View cost prices',
      'Management.LoyaltyCards': 'Loyalty cards',
    };
    return names[key] ?? key;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncKeys = ref.watch(allSecurityKeysProvider);
    final company = ref.watch(selectedCompanyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return asyncKeys.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error loading security rules: $e")),
      data: (keys) {
        if (company == null) {
          return const Center(child: Text("No company selected."));
        }
        if (keys.isEmpty) {
          return const Center(child: Text("No security rules found."));
        }

        final groupedKeys = {
          'General': <SecurityKeyModel>[],
          'Sales': <SecurityKeyModel>[],
          'Management': <SecurityKeyModel>[],
          'Stock': <SecurityKeyModel>[],
        };

        for (var k in keys) {
          groupedKeys[_getCategory(k.name)]?.add(k);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: groupedKeys.entries.where((e) => e.value.isNotEmpty).map((
            entry,
          ) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.shade800 : Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  children: entry.value.map((keyItem) {
                    return FractionallySizedBox(
                      widthFactor: 0.5,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          right: 16.0,
                          bottom: 8.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _getFriendlyName(keyItem.name),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            _SecurityLevelDropdown(
                              securityKey: keyItem,
                              companyId: company.id,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

class _SecurityLevelDropdown extends ConsumerStatefulWidget {
  final SecurityKeyModel securityKey;
  final int companyId;
  const _SecurityLevelDropdown({
    required this.securityKey,
    required this.companyId,
  });
  @override
  ConsumerState<_SecurityLevelDropdown> createState() =>
      _SecurityLevelDropdownState();
}

class _SecurityLevelDropdownState
    extends ConsumerState<_SecurityLevelDropdown> {
  bool _isLoading = false;

  Future<void> _updateLevel(int newLevel) async {
    final oldLevel = widget.securityKey.level;
    final db = ref.read(appDatabaseProvider);

    // Optimistic write → Drift StreamProvider re-emits immediately, UI is instant.
    await db
        .into(db.securityKeysTable)
        .insertOnConflictUpdate(
          SecurityKeysTableCompanion(
            companyId: Value(widget.companyId),
            name: Value(widget.securityKey.name),
            level: Value(newLevel),
          ),
        );

    setState(() => _isLoading = true);
    try {
      await ref
          .read(userManagementProvider)
          .updateSecurityKey(
            widget.companyId,
            widget.securityKey.name,
            newLevel,
          );
      // No invalidate needed — Drift stream already emitted the new value.
      if (mounted) {
        showAppSnackbar(
          context,
          ref,
          '${_getFriendlyName(widget.securityKey.name)} updated.',
        );
      }
    } on DioException catch (e) {
      if (e.response == null) {
        // No connectivity — keep the optimistic Drift write and queue it.
        await db
            .into(db.pendingUserOpsTable)
            .insert(
              PendingUserOpsTableCompanion(
                operation: const Value('update_security_key'),
                companyId: Value(widget.companyId),
                payload: Value(
                  jsonEncode({
                    'name': widget.securityKey.name,
                    'level': newLevel,
                  }),
                ),
              ),
            );
        if (mounted) {
          showAppSnackbar(
            context,
            ref,
            'Saved offline. Will sync when connected.',
          );
        }
      } else {
        // Server rejected — revert the optimistic Drift write.
        await db
            .into(db.securityKeysTable)
            .insertOnConflictUpdate(
              SecurityKeysTableCompanion(
                companyId: Value(widget.companyId),
                name: Value(widget.securityKey.name),
                level: Value(oldLevel),
              ),
            );
        if (mounted) {
          final msg =
              e.response?.data?['message'] as String? ?? 'Update failed';
          showAppSnackbar(context, ref, msg, isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Reuse the same friendly-name map from the parent widget.
  String _getFriendlyName(String key) {
    const names = {
      'Management': 'Management',
      'Settings': 'Settings',
      'BusinessDay.Close': 'End of day',
      'SalesHistory': 'View sales history',
      'Order.All': 'View all open orders',
      'CashMovement': 'Cash in / out',
      'CreditPayments': 'Credit payments',
    };
    return names[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: Padding(
          padding: EdgeInsets.all(4.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return DropdownButton<int>(
      value: widget.securityKey.level,
      underline: const SizedBox(),
      focusColor: Colors.transparent,
      items: const [
        DropdownMenuItem(value: 0, child: Text("Cashier")),
        DropdownMenuItem(value: 1, child: Text("Admin")),
      ],
      onChanged: (val) {
        if (val != null && val != widget.securityKey.level) _updateLevel(val);
      },
    );
  }
}

class _UsersListTab extends ConsumerWidget {
  const _UsersListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(selectedCompanyProvider);
    // Kick off a background API seed each time this tab opens so users
    // created on another device (or after the last watermark sync) appear
    // immediately. autoDispose ensures it re-runs on next screen open.
    if (company != null) ref.watch(seedUsersFromApiProvider(company.id));

    final asyncUsers = ref.watch(allUsersAdminProvider);

    return asyncUsers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error loading users: $e")),
      data: (users) {
        if (company == null) {
          return const Center(child: Text("No company selected."));
        }
        final int companyId = company.id;

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "No users found.",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text("Add First User"),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _AddUserDialog(companyId: companyId),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, i) {
            final user = users[i];
            final cs = Theme.of(context).colorScheme;
            final initial = user.displayName.isNotEmpty
                ? user.displayName[0].toUpperCase()
                : '?';
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: user.accessLevel == 0
                    ? cs.primary
                    : cs.secondary,
                foregroundColor: user.accessLevel == 0
                    ? cs.onPrimary
                    : cs.onSecondary,
                child: Text(initial),
              ),
              title: Text(
                user.displayName,
                style: user.isEnabled
                    ? null
                    : TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.45),
                        decoration: TextDecoration.lineThrough,
                      ),
              ),
              subtitle: Text(
                "${user.accessLevel == 0 ? 'Admin' : 'Cashier'}"
                "${!user.isEnabled ? ' · Disabled' : ''}"
                "${user.email != null && user.email!.isNotEmpty ? ' · ${user.email}' : ''}",
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.security,
                      color: cs.error.withValues(alpha: 0.8),
                    ),
                    tooltip: "Security Actions",
                    onSelected: (value) {
                      if (value == 'reset_password') {
                        _adminResetPassword(context, user, ref);
                      } else if (value == 'reset_pin') {
                        _adminResetPin(context, user, ref);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'reset_password',
                        child: ListTile(
                          leading: Icon(Icons.password, color: cs.error),
                          title: const Text("Admin: Reset Password"),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'reset_pin',
                        child: ListTile(
                          leading: Icon(Icons.pin, color: cs.error),
                          title: const Text("Admin: Reset Device PIN"),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: cs.primary),
                    tooltip: "Edit User",
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) =>
                          _EditUserDialog(user: user, companyId: companyId),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: cs.error),
                    tooltip: "Delete User",
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Delete User"),
                          content: Text(
                            "Are you sure you want to delete ${user.displayName}?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onError,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text("Delete"),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await ref
                              .read(userManagementProvider)
                              .deleteUser(companyId, user.id);
                          // Remove from Drift — the stream auto-updates the list.
                          await (ref
                                  .read(appDatabaseProvider)
                                  .delete(
                                    ref.read(appDatabaseProvider).usersTable,
                                  )
                                ..where((t) => t.id.equals(user.id)))
                              .go();
                          if (context.mounted) {
                            showAppSnackbar(
                              context,
                              ref,
                              'User deleted successfully.',
                            );
                          }
                        } on DioException catch (e) {
                          // Revert the optimistic Drift delete by re-adding
                          // the seed so the user reappears.
                          ref.invalidate(seedUsersFromApiProvider(companyId));
                          if (context.mounted) {
                            final msg = e.response == null
                                ? 'No connection. Deleting users requires connectivity.'
                                : e.response?.data?['message'] ??
                                      'Delete failed';
                            showAppSnackbar(context, ref, msg, isError: true);
                          }
                        }
                      }
                    },
                  ),
                  _EnableToggle(user: user, companyId: companyId),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _EnableToggle extends ConsumerStatefulWidget {
  final User user;
  final int companyId;
  const _EnableToggle({required this.user, required this.companyId});
  @override
  ConsumerState<_EnableToggle> createState() => _EnableToggleState();
}

class _EnableToggleState extends ConsumerState<_EnableToggle> {
  bool _loading = false;

  Future<void> _toggle() async {
    final newEnabled = !widget.user.isEnabled;
    final db = ref.read(appDatabaseProvider);

    // Optimistic write — Drift stream emits immediately so the toggle flips
    // without waiting for the network round-trip.
    await (db.update(db.usersTable)..where((t) => t.id.equals(widget.user.id)))
        .write(UsersTableCompanion(isEnabled: Value(newEnabled)));

    setState(() => _loading = true);
    try {
      await ref
          .read(userManagementProvider)
          .toggleUserStatus(widget.companyId, widget.user.id, newEnabled);
      // No invalidate — Drift stream already emitted the new value.
    } on DioException catch (e) {
      if (e.response == null) {
        // No connectivity — keep the optimistic Drift write and queue it.
        await db
            .into(db.pendingUserOpsTable)
            .insert(
              PendingUserOpsTableCompanion(
                operation: const Value('toggle_user'),
                companyId: Value(widget.companyId),
                payload: Value(
                  jsonEncode({
                    'userId': widget.user.id,
                    'isEnabled': newEnabled,
                  }),
                ),
              ),
            );
        if (mounted) {
          showAppSnackbar(
            context,
            ref,
            'Saved offline. Will sync when connected.',
          );
        }
      } else {
        // Server rejected — revert the optimistic Drift write.
        await (db.update(db.usersTable)
              ..where((t) => t.id.equals(widget.user.id)))
            .write(UsersTableCompanion(isEnabled: Value(!newEnabled)));
        if (mounted) {
          final msg =
              e.response?.data?['message'] as String? ?? 'Update failed';
          showAppSnackbar(context, ref, msg, isError: true);
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
      value: widget.user.isEnabled,
      onChanged: (_) => _toggle(),
      activeThumbColor: context.successColor,
    );
  }
}

class _AddUserDialog extends ConsumerStatefulWidget {
  final int companyId;
  const _AddUserDialog({required this.companyId});
  @override
  ConsumerState<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends ConsumerState<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  int _accessLevel = 1;
  bool _isLoading = false;
  final _passwordCtrl = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(userManagementProvider).addUser(widget.companyId, {
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'accessLevel': _accessLevel,
        'isEnabled': true,
        'password': _passwordCtrl.text.trim(),
      });
      // Invalidate the background seed so _UsersListTab re-fetches from the
      // API and picks up the server-assigned ID for the new user.
      ref.invalidate(seedUsersFromApiProvider(widget.companyId));
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      setState(() {
        _errorMessage = e.response == null
            ? 'No connection. Adding users requires connectivity.'
            : e.response?.data?['message'] ?? 'Failed to create user.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add New User"),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      decoration: const InputDecoration(
                        labelText: "First Name *",
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Last Name *",
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? "Required" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: "Username *"),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: "Password *"),
                obscureText: true,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _accessLevel,
                decoration: const InputDecoration(labelText: "Access Level"),
                items: const [
                  DropdownMenuItem(value: 0, child: Text("Admin")),
                  DropdownMenuItem(value: 1, child: Text("Cashier")),
                ],
                onChanged: (v) => setState(() => _accessLevel = v ?? 1),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: context.dangerColor,
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
          child: const Text("Cancel"),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("Save"),
            onPressed: _submit,
          ),
      ],
    );
  }
}

class _EditUserDialog extends ConsumerStatefulWidget {
  final User user;
  final int companyId;
  const _EditUserDialog({required this.user, required this.companyId});
  @override
  ConsumerState<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;
  late int _accessLevel;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.user.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: widget.user.lastName ?? '');
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _emailCtrl = TextEditingController(text: widget.user.email ?? '');
    _accessLevel =
        (widget.user.accessLevel == 0 || widget.user.accessLevel == 1)
        ? widget.user.accessLevel
        : 1;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final display = [first, last].where((s) => s.isNotEmpty).join(' ');
    final db = ref.read(appDatabaseProvider);

    // Optimistic write — list updates immediately with all user fields.
    await (db.update(
      db.usersTable,
    )..where((t) => t.id.equals(widget.user.id))).write(
      UsersTableCompanion(
        name: Value(
          display.isNotEmpty ? display : (widget.user.username ?? ''),
        ),
        firstName: Value(first.isNotEmpty ? first : null),
        lastName: Value(last.isNotEmpty ? last : null),
        username: Value(username.isNotEmpty ? username : null),
        email: Value(email.isNotEmpty ? email : null),
        role: Value(_accessLevel),
      ),
    );

    try {
      await ref.read(userManagementProvider).updateUser(widget.companyId, {
        'id': widget.user.id,
        'accessLevel': _accessLevel,
        'firstName': first,
        'lastName': last,
        'username': username,
        'email': email,
      });
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      if (e.response == null) {
        // No connectivity — Drift already updated, queue for sync.
        await db
            .into(db.pendingUserOpsTable)
            .insert(
              PendingUserOpsTableCompanion(
                operation: const Value('update_user'),
                companyId: Value(widget.companyId),
                payload: Value(
                  jsonEncode({
                    'id': widget.user.id,
                    'accessLevel': _accessLevel,
                    'firstName': first,
                    'lastName': last,
                    'username': username,
                    'email': email,
                  }),
                ),
              ),
            );
        if (mounted) {
          showAppSnackbar(
            context,
            ref,
            'Saved offline. Will sync when connected.',
          );
          Navigator.of(context).pop();
        }
      } else {
        // Server rejected — revert the optimistic Drift write.
        await (db.update(
          db.usersTable,
        )..where((t) => t.id.equals(widget.user.id))).write(
          UsersTableCompanion(
            name: Value(widget.user.displayName),
            firstName: Value(widget.user.firstName),
            lastName: Value(widget.user.lastName),
            username: Value(widget.user.username),
            email: Value(widget.user.email),
            role: Value(widget.user.accessLevel),
          ),
        );
        setState(() {
          _errorMessage =
              e.response?.data?['message'] ?? 'Failed to update user.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Edit ${widget.user.displayName}"),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      decoration: const InputDecoration(
                        labelText: "First Name",
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      decoration: const InputDecoration(labelText: "Last Name"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: "Username"),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _accessLevel,
                decoration: const InputDecoration(labelText: "Access Level"),
                items: const [
                  DropdownMenuItem(value: 0, child: Text("Admin")),
                  DropdownMenuItem(value: 1, child: Text("Cashier")),
                ],
                onChanged: (v) => setState(() => _accessLevel = v ?? 1),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: context.dangerColor,
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
          child: const Text("Cancel"),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          )
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("Update"),
            onPressed: _submit,
          ),
      ],
    );
  }
}

Future<void> _adminResetPassword(
  BuildContext context,
  User user,
  WidgetRef ref,
) async {
  final passwordCtrl = TextEditingController();
  bool isSaving = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: Text("Force Reset Password: ${user.displayName}"),
        content: TextField(
          controller: passwordCtrl,
          decoration: const InputDecoration(
            labelText: "New Password",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.dangerColor),
            onPressed: isSaving
                ? null
                : () async {
                    if (passwordCtrl.text.isEmpty) return;
                    setStateDialog(() => isSaving = true);
                    try {
                      // ✨ Clean Delegation
                      await ref
                          .read(userManagementProvider)
                          .adminResetPassword(
                            user.companyId,
                            user.id,
                            passwordCtrl.text,
                          );

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        showAppSnackbar(context, ref, "Password forcibly reset!");
                      }
                    } on DioException catch (e, st) {
                      rethrowApiError(e, st);
                    } finally {
                      setStateDialog(() => isSaving = false);
                    }
                  },
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "Force Reset",
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _adminResetPin(
  BuildContext context,
  User user,
  WidgetRef ref,
) async {
  final pinCtrl = TextEditingController();
  bool isSaving = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: Text("Force Reset PIN: ${user.displayName}"),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: "New 4-Digit PIN",
            border: OutlineInputBorder(),
            counterText: "",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.dangerColor),
            onPressed: isSaving
                ? null
                : () async {
                    if (pinCtrl.text.length < 4) return;
                    setStateDialog(() => isSaving = true);
                    try {
                      // ✨ Clean Delegation: We reuse the exact same method from authServiceProvider!
                      await ref
                          .read(authServiceProvider)
                          .setDevicePin(
                            userId: user.id,
                            companyId: user.companyId,
                            pin: pinCtrl.text,
                          );

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        showAppSnackbar(
                            context, ref, "PIN forcibly reset for this Device!");
                        ref.invalidate(allUsersAdminProvider);
                      }
                    } on DioException catch (e, st) {
                      rethrowApiError(e, st);
                    } finally {
                      setStateDialog(() => isSaving = false);
                    }
                  },
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "Force Reset",
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
    ),
  );
}
