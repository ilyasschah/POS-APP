import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/time_clock/time_clock_screen.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/auth/master_login_screen.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:pos_app/sync/sync_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

// Import the PowerModal (Adjust this path if you placed it in a different folder)
import 'package:pos_app/navigation/power_modal.dart';

class LoginScreen extends ConsumerStatefulWidget {
  /// Set when we landed here because the server rejected our token (see
  /// `SessionExpiry`); shows a "session expired" prompt on arrival.
  final bool sessionExpired;
  const LoginScreen({super.key, this.sessionExpired = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.sessionExpired && mounted) {
        showAppSnackbar(
          context,
          ref,
          AppLocalizations.of(context).sessionExpiredMsg,
          isError: true,
        );
      }
      final selectedCo = ref.read(selectedCompanyProvider);
      final defaultCoId = ref.read(defaultCompanyIdProvider);
      if (selectedCo == null) {
        final fallbackId = defaultCoId ?? 2;
        await ref.read(authServiceProvider).loadFallbackCompany(fallbackId);
      }
    });
  }

  void _handleUnlinkDevice() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.developerMode),
        content: Text(l10n.unlinkDeviceConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () async {
              // Release this terminal's seat BEFORE wiping the token (the call
              // needs it) so the admin portal drops e.g. 1/1 → 0/1. Best-effort —
              // offline sign-out is reclaimed by the server-side stale reaper.
              await ref.read(authServiceProvider).releaseDeviceSeat();
              await ref.read(authStorageProvider).unlinkDevice();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MasterLoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(l10n.unlinkDevice),
          ),
        ],
      ),
    );
  }

  Future<void> _showPinPad(User user) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PinPadModal(user: user),
    );
  }

  Widget _buildUserCard(BuildContext context, User user, int index) {
    final cs = Theme.of(context).colorScheme;
    final isAdmin = user.accessLevel == 0;
    final avatarBg = isAdmin ? cs.primaryContainer : cs.secondaryContainer;
    final avatarFg = isAdmin ? cs.onPrimaryContainer : cs.onSecondaryContainer;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showPinPad(user),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: avatarBg,
              child: Icon(
                PhosphorIcons.user(PhosphorIconsStyle.fill),
                size: 32,
                color: avatarFg,
              ),
            ),
            const Gap(14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                user.displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            const Gap(4),
            Text(
              isAdmin
                  ? AppLocalizations.of(context).roleAdmin
                  : AppLocalizations.of(context).roleCashier,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedCo = ref.watch(selectedCompanyProvider);

    if (selectedCo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final asyncUsers = ref.watch(allUsersProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        // Removed the "POS Login" title to clean up the top left
        actions: [
          // TIME CLOCK button — only when SelectBusinessDayOnStart == 'true'
          if (ref
                  .watch(
                    appSettingsProvider,
                  )[SettingKeys.selectBusinessDayOnStart]
                  ?.toLowerCase() ==
              'true')
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.access_time, size: 16),
                label: Text(AppLocalizations.of(context).timeClock),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.primary,
                  side: BorderSide(color: cs.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TimeClockScreen()),
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? PhosphorIcons.sun()
                  : PhosphorIcons.moon(),
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
          const SizedBox(
            width: 16,
          ), // Padding to replace the removed company name
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Replaced "Select User" with Company Name & Hidden Unlink Action
                  GestureDetector(
                    onLongPress: _handleUnlinkDevice,
                    child: Text(
                      selectedCo.name,
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Gap(40),
                  Expanded(
                    child: asyncUsers.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => _NoUsersRecovery(
                        companyId: selectedCo.id,
                        error: '$err',
                      ),
                      data: (users) {
                        if (users.isEmpty) {
                          return _NoUsersRecovery(companyId: selectedCo.id);
                        }
                        // Replaced GridView with Wrap to automatically center orphan cards
                        return SingleChildScrollView(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 20,
                            runSpacing: 20,
                            children: users.map((user) {
                              final index = users.indexOf(user);
                              return SizedBox(
                                width: 170,
                                height: 170,
                                child: _buildUserCard(context, user, index),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom-Left Power Button
          Positioned(
            bottom: 24,
            left: 24,
            child: FloatingActionButton(
              backgroundColor: cs.surfaceContainerHighest,
              foregroundColor: cs.onSurface,
              elevation: 0,
              tooltip: AppLocalizations.of(context).powerOptions,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const PowerModal(),
                );
              },
              child: const Icon(Icons.power_settings_new, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// No-users recovery
// ---------------------------------------------------------------------------

class _NoUsersRecovery extends ConsumerStatefulWidget {
  final int companyId;
  final String? error;
  const _NoUsersRecovery({required this.companyId, this.error});

  @override
  ConsumerState<_NoUsersRecovery> createState() => _NoUsersRecoveryState();
}

class _NoUsersRecoveryState extends ConsumerState<_NoUsersRecovery> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(seedUsersFromApiProvider(widget.companyId).future);
      ref.invalidate(allUsersProvider);
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _relink() async {
    await ref.read(authServiceProvider).releaseDeviceSeat();
    await ref.read(authStorageProvider).unlinkDevice();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MasterLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: cs.onSurfaceVariant),
            const Gap(16),
            Text(
              widget.error != null
                  ? AppLocalizations.of(context).couldNotLoadUsers
                  : AppLocalizations.of(context).noUsersCached,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const Gap(8),
            Text(
              _busy
                  ? AppLocalizations.of(context).restoringUsersFromServer
                  : AppLocalizations.of(context).reconnectToRestoreUsers,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
            const Gap(24),
            if (_busy)
              const CircularProgressIndicator()
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: Text(AppLocalizations.of(context).reloadUsers),
                  ),
                  OutlinedButton.icon(
                    onPressed: _relink,
                    icon: const Icon(Icons.link_off),
                    label: Text(AppLocalizations.of(context).relinkDevice),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PIN Pad Bottom Sheet
// ---------------------------------------------------------------------------

class _PinPadModal extends ConsumerStatefulWidget {
  final User user;
  const _PinPadModal({required this.user});

  @override
  ConsumerState<_PinPadModal> createState() => _PinPadModalState();
}

class _PinPadModalState extends ConsumerState<_PinPadModal> {
  String _pin = "";
  String _confirmPin = "";
  bool _isConfirming = false;
  bool _isLoading = false;
  final bool _isSyncing = false;

  void _onKeyPress(String value) {
    if (_pin.length < 4) {
      setState(() => _pin += value);
      if (_pin.length == 4) _processCompletePin();
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _processCompletePin() async {
    if (!widget.user.hasPinForThisDevice) {
      if (!_isConfirming) {
        setState(() {
          _confirmPin = _pin;
          _pin = "";
          _isConfirming = true;
        });
      } else {
        if (_pin == _confirmPin) {
          await _setNewPin();
        } else {
          _showError("PINs do not match. Try again.");
          setState(() {
            _pin = "";
            _confirmPin = "";
            _isConfirming = false;
          });
        }
      }
    } else {
      _verifyPin();
    }
  }

  Future<void> _verifyPin() async {
    final bytes = utf8.encode(_pin);
    final digest = sha256.convert(bytes);
    final hashedAttempt = base64Encode(digest.bytes);

    if (hashedAttempt == widget.user.hashedPin) {
      await _loginUser();
    } else {
      _showError("Incorrect PIN.");
      setState(() => _pin = "");
    }
  }

  Future<void> _setNewPin() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authServiceProvider)
          .setDevicePin(
            userId: widget.user.id,
            companyId: widget.user.companyId,
            pin: _pin,
          );
      await _loginUser();
    } catch (e) {
      _showError("Failed to save PIN.");
      setState(() {
        _pin = "";
        _confirmPin = "";
        _isConfirming = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loginUser() async {
    ref.read(currentUserProvider.notifier).setUser(widget.user);

    final authService = ref.read(authServiceProvider);
    final sync = ref.read(syncManagerProvider);
    Future(() async {
      await authService.exchangeUserToken(widget.user.id);
      await sync.sync(widget.user.companyId);
    }).catchError((Object _) {});

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainLayout()),
      (route) => false,
    );
  }

  void _showError(String message) {
    showAppSnackbar(context, ref, message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAdmin = widget.user.accessLevel == 0;
    final avatarBg = isAdmin ? cs.primaryContainer : cs.secondaryContainer;
    final avatarFg = isAdmin ? cs.onPrimaryContainer : cs.onSecondaryContainer;
    final title = _isSyncing
        ? AppLocalizations.of(context).syncingMasterData
        : !widget.user.hasPinForThisDevice
        ? (_isConfirming ? AppLocalizations.of(context).confirmNewPin : AppLocalizations.of(context).createFourDigitPin)
        : AppLocalizations.of(context).enterPin;

    final screen = MediaQuery.sizeOf(context);
    final scale = (screen.shortestSide / 600).clamp(0.7, 1.0).toDouble();
    double s(double v) => v * scale;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: s(360)),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(s(24), s(12), s(24), s(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: s(40),
                    height: s(4),
                    margin: EdgeInsets.only(bottom: s(20)),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  CircleAvatar(
                    radius: s(32),
                    backgroundColor: avatarBg,
                    child: Icon(
                      PhosphorIcons.user(PhosphorIconsStyle.fill),
                      size: s(32),
                      color: avatarFg,
                    ),
                  ),
                  Gap(s(12)),
                  Text(
                    widget.user.displayName,
                    style: GoogleFonts.inter(
                      fontSize: s(20),
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  Gap(s(4)),
                  Text(
                    title,
                    style: TextStyle(color: cs.primary, fontSize: s(15)),
                  ),
                  Gap(s(28)),
                  SizedBox(
                    width: s(280),
                    height: s(64),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final filled = index < _pin.length;
                              return Container(
                                width: s(56),
                                height: s(64),
                                margin: EdgeInsets.symmetric(horizontal: s(6)),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(s(14)),
                                  border: Border.all(
                                    color: filled
                                        ? cs.primary
                                        : cs.outlineVariant,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: s(24),
                                    height: s(24),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: filled
                                          ? cs.primary
                                          : cs.onSurfaceVariant.withValues(
                                              alpha: 0.2,
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                  ),
                  Gap(s(32)),
                  SizedBox(
                    width: double.infinity,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: s(10),
                        mainAxisSpacing: s(10),
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        if (index == 9) return const SizedBox.shrink();

                        if (index == 11) {
                          return FilledButton.tonal(
                            onPressed: _onBackspace,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: Icon(PhosphorIcons.backspace(), size: s(24)),
                          );
                        }

                        final number = index == 10 ? "0" : "${index + 1}";
                        return FilledButton.tonal(
                          onPressed: () => _onKeyPress(number),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            number,
                            style: GoogleFonts.inter(
                              fontSize: s(26),
                              fontWeight: FontWeight.w600,
                              color: cs.onSecondaryContainer,
                            ),
                          ),
                        );
                      },
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
