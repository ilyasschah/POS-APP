import 'package:flutter/material.dart';

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

  const OnboardingScreen({
    super.key,
    required this.deviceName,
    required this.ipAddress,
    required this.port,
  });

  static const _brand = Color(0xFF546E7A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    _hero(context, constraints.maxHeight),
                    _instructions(context),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, double maxHeight) {
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
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'KITCHEN DISPLAY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
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
                'Waiting to pair…',
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'To get started, pair this device in\nthe POS app settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF263238),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),
          _InfoRow(label: 'Device name', value: deviceName),
          const SizedBox(height: 10),
          _InfoRow(label: 'IP address', value: '$ipAddress:$port'),
          const SizedBox(height: 24),
          Text(
            'POS → Settings → Kitchen Display → add this address',
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

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
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
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF263238),
          ),
        ),
      ],
    );
  }
}
