import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/auth/login_screen.dart';
import 'package:pos_app/license/license_service.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

/// Full-screen, read-only block shown when the offline subscription lease has
/// expired (or been tampered with). Selling is impossible until the terminal
/// reaches the server and refreshes a valid lease (Pillar 2).
class SubscriptionBlockedScreen extends ConsumerStatefulWidget {
  const SubscriptionBlockedScreen({super.key, required this.evaluation});

  final LicenseEvaluation evaluation;

  @override
  ConsumerState<SubscriptionBlockedScreen> createState() =>
      _SubscriptionBlockedScreenState();
}

class _SubscriptionBlockedScreenState
    extends ConsumerState<SubscriptionBlockedScreen> {
  bool _checking = false;

  bool get _tampered => widget.evaluation.state == LicenseState.tampered;

  Future<void> _retry() async {
    setState(() => _checking = true);
    try {
      final companyId = await ref.read(authStorageProvider).getCompanyId();
      if (companyId == null) {
        if (mounted) {
          showAppSnackbar(context, ref,
              'This terminal is not linked. Re-link the device.',
              isError: true);
        }
        return;
      }

      final result =
          await ref.read(licenseServiceProvider).refreshFromServer(companyId);

      if (!mounted) return;

      if (result == null) {
        showAppSnackbar(context, ref,
            'Could not reach the server. Check your internet connection.',
            isError: true);
        return;
      }

      if (!result.blocked) {
        // Subscription is valid again — let the terminal back in.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      showAppSnackbar(
        context,
        ref,
        result.state == LicenseState.tampered
            ? 'License is invalid. Please contact support.'
            : 'Subscription is still expired. Please renew to continue.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final validUntil = widget.evaluation.validUntil;

    final title = _tampered ? 'License invalid' : 'Subscription expired';
    final message = _tampered
        ? 'This terminal’s license could not be verified. Please contact support to restore service.'
        : 'Your subscription has ended. Connect this terminal to the internet and renew to continue selling.';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 460,
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
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _tampered
                          ? PhosphorIcons.shieldWarning()
                          : PhosphorIcons.lockKey(),
                      color: cs.onErrorContainer,
                      size: 40,
                    ),
                  ),
                ),
                const Gap(24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const Gap(12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15, height: 1.4),
                ),
                if (!_tampered && validUntil != null) ...[
                  const Gap(20),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIcons.calendarX(),
                            size: 18, color: cs.onSurfaceVariant),
                        const Gap(8),
                        Text(
                          'Expired on ${DateFormat('d MMM yyyy').format(validUntil.toLocal())}',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Gap(32),
                FilledButton.icon(
                  onPressed: _checking ? null : _retry,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _checking
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : Icon(PhosphorIcons.arrowsClockwise()),
                  label: Text(
                    _checking ? 'CHECKING…' : 'RETRY CONNECTION',
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
