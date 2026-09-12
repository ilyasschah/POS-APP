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

  /// Every terminal registered to the ACCOUNT (`DeviceRegistry`) — not the PIN
  /// table. The PIN table only knows the terminals the signed-in USER set a PIN
  /// on, so an admin saw one device here while the account had three and the
  /// admin portal said "3 / 7".
  List<Map<String, dynamic>> _devices = [];
  int _seatAllowance = 0;
  int _activeSeats = 0;
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
      // The company comes from the token server-side, never from the query.
      final response = await dio.get('/Master/AccountDevices');
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _devices = ((data['devices'] as List?) ?? const [])
              .cast<Map<String, dynamic>>();
          _seatAllowance = (data['seatAllowance'] as num?)?.toInt() ?? 0;
          _activeSeats = (data['activeSeats'] as num?)?.toInt() ?? 0;
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
    final devices =
        _buildDevicesCard(context, canRevoke: currentUser.isAdmin);

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

  Widget _buildDevicesCard(BuildContext context, {required bool canRevoke}) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final dates = ref.watch(appDateFormatProvider);

    final Widget body;
    if (_isLoadingDevices && _devices.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_devices.isEmpty) {
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
      // This terminal first, then the server's order: active before released,
      // oldest first.
      final ordered = [
        ..._devices.where((d) => d['deviceId'] == _currentDeviceId),
        ..._devices.where((d) => d['deviceId'] != _currentDeviceId),
      ];
      body = Column(
        children: [
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 68),
            _deviceTile(context, ordered[i], dates, canRevoke: canRevoke),
          ],
        ],
      );
    }

    return _SectionCard(
      icon: Icons.devices_outlined,
      title: l.activeDevices,
      subtitle: l.activeDevicesHint,
      trailing: [
        if (_devices.isNotEmpty)
          // Seats in use against the licence — the same "3 / 7" the admin
          // portal shows, so the two never appear to disagree.
          Tooltip(
            message: l.seatsInUseTooltip,
            child: _Pill(
              label: _seatAllowance > 0
                  ? '$_activeSeats / $_seatAllowance'
                  : '${_devices.length}',
              color: cs.primary,
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

  Widget _deviceTile(
    BuildContext context,
    Map<String, dynamic> device,
    AppDateFormat dates, {
    required bool canRevoke,
  }) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final deviceId = device['deviceId'] as String;
    final isCurrent = deviceId == _currentDeviceId;
    final status = (device['status'] as String?) ?? 'active';
    // The terminal's own POS name, recorded in the device registry. A device
    // enrolled before names were reported has none yet — show a short form of
    // the signature rather than the full UUID, which is unreadable and
    // identifies nothing to an operator.
    final name = (device['deviceName'] as String?)?.trim() ?? '';
    final label = name.isNotEmpty ? name : _shortDeviceId(deviceId);
    // The company's date format and timezone, not `DateTime.toString()`.
    String? stamp(String key) {
      final raw = device[key] as String?;
      if (raw == null) return null;
      final dt = DateTime.tryParse(raw);
      return dt != null ? dates.stamp(dt) : raw;
    }

    final linked = stamp('registeredAt');
    final lastSeen = isCurrent ? null : stamp('lastSeenAt');

    final tint = isCurrent
        ? context.successColor
        : status == 'active'
            ? cs.onSurfaceVariant
            : cs.onSurfaceVariant.withValues(alpha: 0.5);

    // A released or reaped terminal still holds its name and takes a seat back
    // on its next sign-in, so it is listed — marked, not hidden.
    final statusPill = switch (status) {
      'active' => null,
      'inactive' => _Pill(label: l.statusInactive, color: cs.onSurfaceVariant),
      'blocked' =>
        _Pill(label: l.deviceStatusBlocked, color: context.dangerColor),
      'revoked' =>
        _Pill(label: l.deviceStatusRevoked, color: context.dangerColor),
      _ => _Pill(label: status, color: cs.onSurfaceVariant),
    };

    // Revoking removes the terminal from the whole ACCOUNT — every PIN on it,
    // its registry row, its seat — so it is an administrator's call. A blocked
    // terminal is left alone: its ban lives in its row, which a revoke keeps.
    final showRevoke = canRevoke && !isCurrent && status != 'blocked';

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
                if (linked != null)
                  Text(
                    l.linkedAt(linked),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                if (lastSeen != null)
                  Text(
                    l.lastSeenAt(lastSeen),
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
          if (statusPill != null) ...[statusPill, const SizedBox(width: 8)],
          if (isCurrent)
            _Pill(label: l.thisDevice, color: context.successColor)
          else if (showRevoke)
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

/// A small rounded label tinted in [color] — a status, "This device", the seat
/// count.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
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
