import 'package:flutter/material.dart';

import 'l10n/kds_localizations.dart';
import 'language_picker.dart';

/// Pre-pairing splash, shown until a POS binds this device. Mirrors the Loyverse
/// CDS onboarding: branded panel up top, "pair this device in the POS settings"
/// instructions plus the device name and IP the operator types into the POS.
/// Once the POS pushes a `/pair` handshake, the root swaps this out for the
/// kitchen view — so there's no company-selection / API step any more.
///
/// Fully responsive: the whole thing lives in a scroll view sized to at least
/// the viewport height, so it centres on tall screens and scrolls (never
/// overflows) on short ones or at large system text scales.
class OnboardingScreen extends StatelessWidget {
  final String deviceName;
  final String ipAddress;
  final int port;
  final Future<void> Function(String code) onLanguageChanged;

  const OnboardingScreen({
    super.key,
    required this.deviceName,
    required this.ipAddress,
    required this.port,
    required this.onLanguageChanged,
  });

  static const _brand = Color(0xFF546E7A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      children: [
                        _hero(context, constraints.maxHeight),
                        _instructions(context),
                      ],
                    ),
                  ),
                ),
                // 🚨 The picker has to be reachable HERE, before pairing. This
                // screen is the one a cook stands in front of while the display
                // is being set up, and it is the screen that tells them what to
                // do next — in a language they may not read. Making them pair
                // first to reach the language menu is the wrong way round.
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: LanguageButton(
                    onLanguageChanged: onLanguageChanged,
                    color: Colors.white,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, double maxHeight) {
    final l = KdsLocalizations.of(context);
    return Container(
      width: double.infinity,
      // Grows on tall screens, but never collapses on short ones.
      constraints: BoxConstraints(minHeight: (maxHeight * 0.42).clamp(220, 460)),
      color: _brand,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.kitchen, size: 72, color: Colors.white),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              l.brandTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                // ⚠️ No letterSpacing. Arabic is a CONNECTED script — spacing
                // its letters apart is what breaks the joins and renders the
                // word as a row of disconnected shapes, the same class of bug
                // the POS hit in its printed reports.
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFAED581),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l.waitingToPair,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _instructions(BuildContext context) {
    final l = KdsLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // No baked-in line break — the translations differ in length and a
            // hard \n that suits English wraps badly in French and Arabic.
            l.pairInstructions,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF263238),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),
          _InfoRow(label: l.deviceNameLabel, value: deviceName),
          const SizedBox(height: 10),
          // 🚨 The ADDRESS is forced left-to-right. An IP and port are Latin
          // digits and dots; inside an Arabic (RTL) paragraph the neutral `.`
          // and `:` get reordered by the bidi algorithm and "192.168.1.50:9100"
          // is displayed with its parts rearranged — an operator then types a
          // wrong address into the POS and the pairing silently never happens.
          _InfoRow(
            label: l.ipAddressLabel,
            value: '$ipAddress:$port',
            forceLtrValue: true,
          ),
          const SizedBox(height: 24),
          Text(
            l.pairPath,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  /// Pins the VALUE to left-to-right regardless of the display's language.
  /// For addresses and other machine text the operator has to retype — see the
  /// note at the IP row's call site.
  final bool forceLtrValue;

  const _InfoRow({
    required this.label,
    required this.value,
    this.forceLtrValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF263238),
      ),
    );

    // Wrap so a long value drops to the next line on narrow screens instead of
    // overflowing horizontally.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 18,
            color: Colors.black.withValues(alpha: 0.5),
          ),
        ),
        if (forceLtrValue)
          Directionality(textDirection: TextDirection.ltr, child: valueText)
        else
          valueText,
      ],
    );
  }
}
