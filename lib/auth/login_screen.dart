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
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:pos_app/sync/sync_provider.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Developer Mode"),
        content: const Text("Are you sure you want to unlink this device?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () async {
              await ref.read(authStorageProvider).unlinkDevice();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MasterLoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Unlink Device"),
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
              isAdmin ? "Admin" : "Cashier",
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
        title: GestureDetector(
          onLongPress: _handleUnlinkDevice,
          child: const Text("POS Login"),
        ),
        actions: [
          // TIME CLOCK button — only when SelectBusinessDayOnStart == 'true'
          if (ref
                  .watch(
                    appSettingsProvider,
                  )[SettingKeys.selectBusinessDayOnStart]
                  ?.toLowerCase() ==
              'true')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.access_time, size: 16),
                label: const Text('TIME CLOCK'),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business, size: 18),
                const SizedBox(width: 6),
                Text(selectedCo.name),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Select User",
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const Gap(40),
              Expanded(
                child: asyncUsers.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text(
                      "Error loading users: $err",
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                  data: (users) {
                    if (users.isEmpty) {
                      return Center(
                        child: Text(
                          "No enabled users found.",
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      );
                    }
                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            childAspectRatio: 1.0,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                      itemCount: users.length,
                      itemBuilder: (context, index) =>
                          _buildUserCard(context, users[index], index),
                    );
                  },
                ),
              ),
            ],
          ),
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
  bool _isSyncing = false;

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

    // Offline-first login: the user already authenticated against the LOCAL
    // cache (the user list + PIN are read from Drift), so go STRAIGHT into the
    // app on cached data — never block login on the network. The sync runs in
    // the BACKGROUND (push pending writes + pull fresh master data); Drift-backed
    // screens fill in reactively as the pull lands. A first install briefly shows
    // empty screens until the first pull completes — an acceptable trade for not
    // hanging on "Syncing master data…" when the server is slow/unreachable.
    //
    // Capture the manager before navigating so the future outlives this screen,
    // and swallow errors (we're already running on cache).
    //
    // First mint a per-user backend token (best-effort) so the backend sees THIS
    // cashier's identity + role, THEN sync so its refresh step slides that token
    // forward. Both run in the background — login never blocks, and offline the
    // device token keeps being used unchanged.
    final authService = ref.read(authServiceProvider);
    final sync = ref.read(syncManagerProvider);
    Future(() async {
      await authService.exchangeUserToken(widget.user.id);
      await sync.sync(widget.user.companyId);
    }).catchError((Object _) {});

    if (!mounted) return;

    // Land on the user's configured default screen. MainLayout (initialIndex
    // defaults to 0) resolves it from settings via resolveDefaultScreenIndex,
    // validated against the feature flags. MainLayout's auto-sync watcher keeps
    // syncing for the rest of the session.
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
        ? "Syncing master data…"
        : !widget.user.hasPinForThisDevice
        ? (_isConfirming ? "Confirm New PIN" : "Create 4-Digit PIN")
        : "Enter PIN";

    // Responsive scale: shrink the whole pad on smaller screens (8"/10"
    // tablets, short landscape) so it never feels oversized or overflows.
    // Derived from the screen's shortest side against a 600px reference.
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
                  // Drag handle
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

                  // PIN slots — fixed-size boxes so the row never shifts or resizes
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

                  // Number grid — fills the comfortable padded width
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
                        // Empty slot below "7 8 9"
                        if (index == 9) return const SizedBox.shrink();

                        // Backspace
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
