import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/utils/api_error_parser.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class UserInfoScreen extends ConsumerStatefulWidget {
  /// Opens the POS navigation drawer. Supplied by MainLayout; when null the
  /// app-bar menu button is hidden (e.g. if pushed as a standalone route).
  final VoidCallback? onMenuPressed;

  const UserInfoScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends ConsumerState<UserInfoScreen> {
  List<dynamic> _activeDevices = [];
  bool _isLoadingDevices = false;
  String _currentDeviceId = "";

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final storage = ref.read(authStorageProvider);
    _currentDeviceId = await storage.getOrCreateDeviceId();
    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoadingDevices = true);
    try {
      final dio = createDio();
      final response = await dio.get(
        '/UserDevicePins/GetActiveDevices',
        queryParameters: {'userId': user.id, 'companyId': user.companyId},
      );
      if (mounted) {
        setState(() {
          _activeDevices = response.data as List<dynamic>;
        });
      }
    } on DioException catch (e, st) {
      if (mounted) rethrowApiError(e, st);
    } finally {
      if (mounted) setState(() => _isLoadingDevices = false);
    }
  }

  Future<void> _revokeDevice(String deviceId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final dio = createDio();
      await dio.delete(
        '/UserDevicePins/RevokeDevice',
        queryParameters: {'companyId': user.companyId},
        data: {'userId': user.id, 'deviceId': deviceId},
      );
      _fetchDevices();
      if (mounted) {
        showAppSnackbar(context, ref, 'Device revoked successfully');
      }
    } on DioException catch (e, st) {
      if (mounted) rethrowApiError(e, st);
    }
  }

  void _showChangePasswordDialog() {
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Change Password"),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPasswordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Old Password",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "New Password",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Confirm New Password",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
                          showAppSnackbar(
                              context, ref, "New passwords do not match",
                              isError: true);
                          return;
                        }

                        setStateDialog(() => isSaving = true);
                        try {
                          final user = ref.read(currentUserProvider);
                          final dio = createDio();
                          await dio.patch(
                            '/Users/ChangePassword',
                            queryParameters: {'companyId': user!.companyId},
                            data: {
                              'userId': user.id,
                              'oldPassword': oldPasswordCtrl.text,
                              'newPassword': newPasswordCtrl.text,
                            },
                          );
                          if (mounted) {
                            Navigator.pop(ctx);
                            showAppSnackbar(
                                context, ref, "Password updated successfully");
                          }
                        } on DioException catch (e, st) {
                          rethrowApiError(e, st);
                        } finally {
                          if (mounted) setStateDialog(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangePinDialog() {
    final pinCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Update PIN for this Device"),
            content: SizedBox(
              width: 300,
              child: TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: "New 4-Digit PIN",
                  border: OutlineInputBorder(),
                  counterText: "",
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (pinCtrl.text.length < 4) {
                          showAppSnackbar(context, ref, "PIN must be 4 digits",
                              isError: true);
                          return;
                        }

                        setStateDialog(() => isSaving = true);
                        try {
                          final user = ref.read(currentUserProvider);
                          final dio = createDio();
                          await dio.post(
                            '/UserDevicePins/SetDevicePin',
                            queryParameters: {'companyId': user!.companyId},
                            data: {
                              'userId': user.id,
                              'deviceId': _currentDeviceId,
                              'pin': pinCtrl.text,
                            },
                          );
                          if (mounted) {
                            Navigator.pop(ctx);
                            showAppSnackbar(
                                context, ref, "PIN updated successfully");
                            ref.invalidate(allUsersProvider);
                          }
                        } on DioException catch (e, st) {
                          rethrowApiError(e, st);
                        } finally {
                          if (mounted) setStateDialog(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Save PIN"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch the live Drift row so email/username/name stay fresh after any
    // sync or admin edit — currentUserProvider is set once at login and stale.
    final liveAsync = ref.watch(liveCurrentUserProvider);
    final currentUser =
        liveAsync.value ?? ref.watch(currentUserProvider);

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: Text("No user is currently logged in.")),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: "Menu",
                onPressed: widget.onMenuPressed,
              )
            : null,
        title: const Text("User Info & Security"),
        backgroundColor: theme.colorScheme.surface,
        elevation: 1,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: currentUser.accessLevel == 0
                              ? Colors.orange
                              : theme.colorScheme.primary,
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          currentUser.displayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: currentUser.accessLevel == 0
                                ? Colors.orange.withValues(alpha: 0.1)
                                : theme.colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            currentUser.accessLevel == 0
                                ? "Administrator"
                                : "Cashier",
                            style: TextStyle(
                              color: currentUser.accessLevel == 0
                                  ? Colors.orange
                                  : theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildInfoRow(
                          context,
                          Icons.account_circle,
                          "Username",
                          currentUser.username ?? "N/A",
                        ),
                        const Divider(height: 32),
                        _buildInfoRow(
                          context,
                          Icons.email,
                          "Email",
                          currentUser.email ?? "No email provided",
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        icon: const Icon(Icons.password),
                        label: const Text("Change Password"),
                        onPressed: _showChangePasswordDialog,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        icon: const Icon(Icons.pin),
                        label: const Text("Update Device PIN"),
                        onPressed: _showChangePinDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Active Devices",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _fetchDevices,
                            ),
                          ],
                        ),
                        const Divider(),
                        if (_isLoadingDevices)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_activeDevices.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              "No active devices found.",
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _activeDevices.length,
                            itemBuilder: (context, index) {
                              final device = _activeDevices[index];
                              final isCurrentDevice =
                                  device['deviceId'] == _currentDeviceId;
                              return ListTile(
                                leading: Icon(
                                  isCurrentDevice
                                      ? Icons.tablet_mac
                                      : Icons.devices,
                                  color: isCurrentDevice
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                title: Text(device['deviceId']),
                                subtitle: Text(
                                  "Linked: ${DateTime.parse(device['createdAt']).toLocal().toString().split('.')[0]}",
                                ),
                                trailing: isCurrentDevice
                                    ? const Chip(
                                        label: Text(
                                          "This Device",
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _revokeDevice(device['deviceId']),
                                      ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}
