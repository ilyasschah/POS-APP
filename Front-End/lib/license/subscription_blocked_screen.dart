import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:pos_app/api/api_client.dart' show apiBaseUrl;
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
              AppLocalizations.of(context).terminalNotLinked,
              isError: true);
        }
        return;
      }

      final result =
          await ref.read(licenseServiceProvider).refreshFromServer(companyId);

      if (!mounted) return;

      if (result == null) {
        showAppSnackbar(context, ref,
            AppLocalizations.of(context).couldNotReachServer,
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
            ? AppLocalizations.of(context).licenseInvalidContactSupport
            : AppLocalizations.of(context).subscriptionStillInactive,
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

    final l10n = AppLocalizations.of(context);
    final title =
        _tampered ? l10n.licenseInvalidTitle : l10n.subscriptionInactiveTitle;
    final message =
        _tampered ? l10n.licenseInvalidBody : l10n.subscriptionInactiveBody;

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
                          AppLocalizations.of(context).expiredOnDate(
                    DateFormat('d MMM yyyy').format(validUntil.toLocal())),
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // 🚨 Which server answered. Without this the screen is
                // undiagnosable: a terminal pointed at the WRONG backend gets a
                // perfectly valid "expired" lease from it and shows exactly the
                // same words as a genuinely lapsed subscription. That cost a
                // full debugging session — a POS on the compiled-in default
                // endpoint reported "Expired on 30 Jul" while the intended
                // server said the subscription ran to 16 Aug. Always show the
                // endpoint here, and on the tampered screen too: "contact your
                // provider" is useless advice if the terminal is asking the
                // wrong provider.
                const Gap(16),
                Text(
                  AppLocalizations.of(context).checkedAgainstEndpoint(apiBaseUrl),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
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
                    _checking
                  ? AppLocalizations.of(context).checkingUpper
                  : AppLocalizations.of(context).retryConnectionUpper,
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
