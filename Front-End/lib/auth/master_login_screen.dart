import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/auth/login_screen.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/license/license_service.dart';
import 'package:pos_app/onboarding/onboarding_prefs.dart';
import 'package:pos_app/onboarding/onboarding_screen.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:pos_app/sync/sync_provider.dart';
import 'package:pos_app/utils/api_error_parser.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

class MasterLoginScreen extends ConsumerStatefulWidget {
  const MasterLoginScreen({super.key});

  @override
  ConsumerState<MasterLoginScreen> createState() => _MasterLoginScreenState();
}

class _MasterLoginScreenState extends ConsumerState<MasterLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final selectedCo = ref.read(selectedCompanyProvider);
      if (selectedCo != null) return;
      final defaultCoId = ref.read(defaultCompanyIdProvider);
      if (defaultCoId != null) {
        await ref.read(authServiceProvider).loadFallbackCompany(defaultCoId);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _registerDevice() async {
    setState(() => _isLoading = true);
    try {
      final storage = ref.read(authStorageProvider);
      final deviceId = await storage.getOrCreateDeviceId();
      final dio = createDio();

      final response = await dio.post(
        '/Auth/Login',
        data: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'deviceId': deviceId,
        },
      );

      final data = response.data as Map<String, dynamic>;

      if (data['success'] != true) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError(data['message'] as String? ?? 'Invalid credentials.');
        }
        return;
      }

      final companyId = data['companyId'] as int? ??
          (data['user'] as Map<String, dynamic>?)?['companyId'] as int? ??
          ref.read(defaultCompanyIdProvider) ?? 1;

      await storage.saveMasterSession(data['token'] as String, companyId);
      // Pillar 2: persist the signed subscription lease — its validUntil drives
      // the offline subscription guard.
      await storage.saveLease(data['lease'] as String?);
      await storage.saveRegisteredEmail(_emailController.text.trim());
      // Cache the public key + pin the server clock so the boot guard can verify
      // the lease signature offline on the very next launch. Non-fatal.
      try {
        await ref.read(licenseServiceProvider).refreshFromServer(companyId);
      } catch (_) {}

      ref.read(defaultCompanyIdProvider.notifier).setDefaultCompany(companyId);

      // Populate selectedCompanyProvider NOW, while we are provably online.
      // Saving the session only records the company *id*; without this the
      // provider stays null until the PIN screen loads it — and
      // appSettingsProvider.set() silently no-ops when there is no selected
      // company, so anything onboarding writes next would be dropped.
      // Fully guarded internally (API → Drift cache → stub); never throws.
      await ref.read(authServiceProvider).loadFallbackCompany(companyId);

      try {
        await ref.read(seedUsersFromApiProvider(companyId).future);
      } catch (_) {}

      // Materialise ALL app settings in the DB right at master-login (we're
      // online here), so a fresh install has every setting seeded before the
      // operator even reaches the PIN screen. pullAppProperties ends with the
      // default-seed; best-effort — the normal per-login sync also does this.
      try {
        await ref.read(syncManagerProvider).pullAppProperties(companyId);
      } catch (_) {}

      if (mounted) {
        // First install: run onboarding HERE, after registration, so every
        // choice made in it has a company to be written against. An already
        // onboarded device goes straight to the PIN screen.
        final onboarded = ref.read(onboardingCompleteProvider);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (routeContext) => onboarded
                ? const LoginScreen()
                : OnboardingScreen(
                    // This route replaced the master-login route, so there is
                    // no `home` rebuild to carry us onward — hand off directly.
                    onFinished: () => Navigator.pushReplacement(
                      routeContext,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                  ),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(parseApiError(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Registration failed: $e');
      }
    }
  }

  void _showError(String message) {
    showAppSnackbar(context, ref, message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIcons.deviceMobile(),
                      color: cs.onPrimaryContainer,
                      size: 36,
                    ),
                  ),
                ),

                const Gap(24),

                Text(
                  l10n.deviceRegistrationTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),

                const Gap(8),

                Text(
                  l10n.deviceRegistrationSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),

                const Gap(40),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.fieldEmail,
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(PhosphorIcons.envelope(), color: cs.onSurfaceVariant),
                  ),
                ),

                const Gap(16),

                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _isLoading ? null : _registerDevice(),
                  decoration: InputDecoration(
                    labelText: l10n.fieldPassword,
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(PhosphorIcons.lock(), color: cs.onSurfaceVariant),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? PhosphorIcons.eye() : PhosphorIcons.eyeSlash(),
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                const Gap(32),

                FilledButton(
                  onPressed: _isLoading ? null : _registerDevice,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : Text(
                          AppLocalizations.of(context).linkDeviceUpper,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
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
}
