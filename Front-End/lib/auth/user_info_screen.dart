import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/auth/role_visuals.dart';
import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/core/ilyass_screen.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/utils/api_error_parser.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// Fallback label for a terminal that has never reported its POS name: the tail
/// of its `POS-<uuid>` signature. Enough to tell two rows apart when revoking,
/// without pasting 40 characters into a list tile.
String _shortDeviceId(String deviceId) =>
    deviceId.length <= 12 ? deviceId : '…${deviceId.substring(deviceId.length - 8)}';

/// User Info & Security — an Ilyass Screen: who is signed in, the two things
/// they can change about their own access, and every terminal their account is
/// signed in on.
///
/// Laid out from the width it actually gets: profile and security side by side
/// with the device list on a wide till, one column on a tablet.
class UserInfoScreen extends ConsumerStatefulWidget {
  /// Opens the POS navigation drawer. Supplied by MainLayout; when null the
  /// leading control follows the mounting (see `IlyassLeading`).
  final VoidCallback? onMenuPressed;

  const UserInfoScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends ConsumerState<UserInfoScreen> {
  /// Below this, the three cards stack in one column.
  static const _twoColumnMinWidth = 860.0;

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
        showAppSnackbar(
            context, ref, AppLocalizations.of(context).deviceRevokedSuccessfully);
      }
    } on DioException catch (e, st) {
      if (mounted) rethrowApiError(e, st);
    }
  }

  /// Revoking signs another terminal out of this account — one mis-tap on a
  /// touch screen away. It used to happen without asking.
  Future<void> _confirmRevoke(String deviceId, String name) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.revokeDeviceTitle),
        content: Text(l.revokeDeviceConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.dangerColor,
              foregroundColor: ctx.onDangerColor,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.actionRevoke),
          ),
        ],
      ),
    );
    if (ok == true) await _revokeDevice(deviceId);
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
            title: Text(AppLocalizations.of(context).changePassword),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPasswordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).oldPassword,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).newPassword,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).confirmNewPassword,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context).actionCancel),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
                          showAppSnackbar(
                              context,
                              ref,
                              AppLocalizations.of(context)
                                  .newPasswordsDoNotMatch,
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
                          if (context.mounted) {
                            Navigator.pop(context);
                            showAppSnackbar(
                                context,
                                ref,
                                AppLocalizations.of(context)
                                    .passwordUpdatedSuccessfully);
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
                    : Text(AppLocalizations.of(context).actionSave),
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
            title: Text(AppLocalizations.of(context).updatePinForDevice),
            content: SizedBox(
              width: 300,
              child: TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).newFourDigitPin,
                  border: const OutlineInputBorder(),
                  counterText: "",
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context).actionCancel),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (pinCtrl.text.length < 4) {
                          showAppSnackbar(context, ref,
                              AppLocalizations.of(context).pinMustBeFourDigits,
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
                          if (context.mounted) {
                            Navigator.pop(context);
                            showAppSnackbar(
                                context,
                                ref,
                                AppLocalizations.of(context)
                                    .pinUpdatedSuccessfully);
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
                    : Text(AppLocalizations.of(context).savePin),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Watch the live Drift row so email/username/name stay fresh after any
    // sync or admin edit — currentUserProvider is set once at login and stale.
    final liveAsync = ref.watch(liveCurrentUserProvider);
    final currentUser = liveAsync.value ?? ref.watch(currentUserProvider);

    if (currentUser == null) {
      // Still an Ilyass Screen: a bare page here was a dead end with no way
      // back to the drawer.
      return IlyassScreen(
        title: l.userInfoSecurity,
        onMenuPressed: widget.onMenuPressed,
        body: Center(child: Text(l.noUserLoggedIn)),
      );
    }

    final profile = _ProfileCard(
      name: currentUser.displayName,
      isAdmin: currentUser.isAdmin,
      username: currentUser.username ?? '—',
      email: currentUser.email ?? l.noEmailProvided,
    );
    final security = _SectionCard(
      icon: Icons.shield_outlined,
      title: l.securityActions,
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.password_rounded,
            title: l.changePassword,
            subtitle: l.changePasswordHint,
            onTap: _showChangePasswordDialog,
          ),
          const Divider(height: 1, indent: 68),
          _ActionTile(
            icon: Icons.pin_outlined,
            title: l.updateDevicePin,
            subtitle: l.devicePinHint,
            onTap: _showChangePinDialog,
          ),
        ],
      ),
    );
    final devices = _buildDevicesCard(context);

    return IlyassScreen(
      title: l.userInfoSecurity,
      onMenuPressed: widget.onMenuPressed,
      maxContentWidth: kMaxReadableWidthWide,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _twoColumnMinWidth;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 360,
                        child: Column(
                          children: [profile, const SizedBox(height: 20), security],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: devices),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      profile,
                      const SizedBox(height: 16),
                      security,
                      const SizedBox(height: 16),
                      devices,
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildDevicesCard(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dates = ref.watch(appDateFormatProvider);

    final Widget body;
    if (_isLoadingDevices && _activeDevices.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_activeDevices.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Column(
          children: [
            Icon(
              Icons.devices_other_outlined,
              size: 44,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            Text(
              l.noActiveDevicesFound,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < _activeDevices.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 68),
            _deviceTile(context, _activeDevices[i], dates),
          ],
        ],
      );
    }

    return _SectionCard(
      icon: Icons.devices_outlined,
      title: l.activeDevices,
      subtitle: l.activeDevicesHint,
      trailing: [
        if (_activeDevices.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_activeDevices.length}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        IconButton(
          tooltip: l.refreshTooltip,
          icon: _isLoadingDevices
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          onPressed: _isLoadingDevices ? null : _fetchDevices,
        ),
      ],
      child: body,
    );
  }

  Widget _deviceTile(BuildContext context, dynamic device, AppDateFormat dates) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final deviceId = device['deviceId'] as String;
    final isCurrent = deviceId == _currentDeviceId;
    // The terminal's own POS name, recorded in the device registry. A device
    // enrolled before names were reported has none yet — show a short form of
    // the signature rather than the full UUID, which is unreadable and
    // identifies nothing to an operator.
    final name = (device['deviceName'] as String?)?.trim() ?? '';
    final label = name.isNotEmpty ? name : _shortDeviceId(deviceId);
    // The company's date format and timezone, not `DateTime.toString()`.
    final linkedRaw = device['createdAt'] as String?;
    final linked = linkedRaw == null ? null : DateTime.tryParse(linkedRaw);

    final tint = isCurrent ? context.successColor : cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _IconBadge(
            icon: isCurrent ? Icons.tablet_mac : Icons.devices,
            color: tint,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (linked != null || linkedRaw != null)
                  Text(
                    l.linkedAt(linked != null ? dates.stamp(linked) : linkedRaw!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: context.successColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l.thisDevice,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: context.successColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            IconButton(
              tooltip: l.actionRevoke,
              icon: Icon(Icons.link_off_rounded, color: context.dangerColor),
              onPressed: () => _confirmRevoke(deviceId, label),
            ),
        ],
      ),
    );
  }
}

/// A wide-till reading cap for this screen: two columns want more room than a
/// single form, but not the full width of a 24-inch display.
const double kMaxReadableWidthWide = 1080;

// ── Pieces ────────────────────────────────────────────────────────────────────

/// Who is signed in: an accent banner, the role avatar straddling it, name,
/// role pill, and the account's identifiers.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.isAdmin,
    required this.username,
    required this.email,
  });

  final String name;
  final bool isAdmin;
  final String username;
  final String email;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Role glyph + colours come from one place (`role_visuals.dart`) so the
    // profile header, the login grid and the PIN pad always agree.
    final role = roleAvatarColors(cs, isAdmin);

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                height: 72,
                color: cs.primary.withValues(alpha: 0.14),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: role.background,
                    child: Icon(
                      roleIcon(isAdmin),
                      size: 36,
                      color: role.foreground,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: role.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(roleIcon(isAdmin), size: 14, color: role.foreground),
                  const SizedBox(width: 6),
                  Text(
                    isAdmin ? l.administrator : l.roleCashier,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: role.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          _InfoTile(
            icon: Icons.alternate_email_rounded,
            label: l.username,
            value: username,
          ),
          const Divider(height: 1, indent: 68),
          _InfoTile(
            icon: Icons.mail_outline_rounded,
            label: l.fieldEmail,
            value: email,
          ),
        ],
      ),
    );
  }
}

/// A titled card with an optional one-line subtitle and header trailing
/// widgets (a count, a refresh button).
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing = const [],
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                ...trailing,
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

/// The card surface every section sits on — theme card colour, soft outline,
/// no drop shadow.
class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: child,
    );
  }
}

/// A read-only identifier: tinted icon, small label, the value underneath.
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: cs.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  maxLines: 1,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
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

/// A finger-sized row that opens something: accent badge, title, one-line
/// explanation, chevron.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        // 64px: comfortably above the 44px touch minimum on a 10" tablet.
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _IconBadge(icon: icon, color: cs.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 36px rounded square tinted in [color], carrying [icon].
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
