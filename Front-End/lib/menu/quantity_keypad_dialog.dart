import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/scale/scale_service.dart';

/// Touch-friendly numeric keypad for entering a custom (decimal) quantity for a
/// cart line — e.g. weighing out `0.5 kg` without a scale barcode. Returns the
/// parsed quantity via [Navigator.pop], or `null` if the cashier cancels.
///
/// The price scales automatically: the cart stores a per-unit price, so a line
/// total is always `price × quantity`. Entering `0.5` therefore charges half,
/// whatever the product's measurement unit (kg, L, pcs, …).
///
/// When a serial scale is configured (Windows only), a live weight readout sits
/// above the keypad and can fill the quantity in one tap. The keypad always
/// remains usable, so an unplugged or misconfigured scale never blocks a sale.
Future<double?> showQuantityKeypad(
  BuildContext context, {
  required String itemName,
  required double initialQuantity,
  String? unit,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _QuantityKeypadDialog(
      itemName: itemName,
      initialQuantity: initialQuantity,
      unit: unit,
    ),
  );
}

class _QuantityKeypadDialog extends ConsumerStatefulWidget {
  final String itemName;
  final double initialQuantity;
  final String? unit;

  const _QuantityKeypadDialog({
    required this.itemName,
    required this.initialQuantity,
    this.unit,
  });

  @override
  ConsumerState<_QuantityKeypadDialog> createState() =>
      _QuantityKeypadDialogState();
}

class _QuantityKeypadDialogState extends ConsumerState<_QuantityKeypadDialog> {
  late String _input;
  // The seed value is shown but replaced on the first digit press, so the
  // cashier can just start typing the new quantity without clearing first.
  bool _replaceOnNextKey = true;

  @override
  void initState() {
    super.initState();
    _input = _fmt(widget.initialQuantity);
  }

  /// Renders a captured weight exactly the way a typed one reads, so `12.0 kg`
  /// off the scale shows as `12`, not `12.0`.
  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _useWeight(double weight) {
    setState(() {
      _input = _fmt(weight);
      _replaceOnNextKey = false;
    });
  }

  String get _display => _input.isEmpty ? '0' : _input;

  void _tapDigit(String d) {
    setState(() {
      if (_replaceOnNextKey) {
        _input = '';
        _replaceOnNextKey = false;
      }
      _input += d;
    });
  }

  void _tapDot() {
    setState(() {
      if (_replaceOnNextKey) {
        _input = '0';
        _replaceOnNextKey = false;
      }
      if (_input.isEmpty) _input = '0';
      if (!_input.contains('.')) _input += '.';
    });
  }

  void _tapSign() {
    setState(() {
      _replaceOnNextKey = false;
      if (_input.startsWith('-')) {
        _input = _input.substring(1);
      } else if (_input.isNotEmpty && _input != '0') {
        _input = '-$_input';
      }
    });
  }

  void _backspace() {
    setState(() {
      _replaceOnNextKey = false;
      if (_input.isNotEmpty) {
        _input = _input.substring(0, _input.length - 1);
      }
    });
  }

  void _confirm() {
    final value = double.tryParse(_input);
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context).setChangeQuantity,
                style: tt.titleLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.unit != null && widget.unit!.isNotEmpty
                    ? 'Item "${widget.itemName}"  ·  ${widget.unit}'
                    : 'Item "${widget.itemName}"',
                style: tt.bodySmall?.copyWith(color: cs.primary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (kScaleSupported && ref.watch(scaleConfigProvider).enabled) ...[
                const SizedBox(height: 10),
                _ScaleWeightBar(
                  productUnit: widget.unit,
                  onUse: _useWeight,
                ),
              ],
              const SizedBox(height: 12),
              // ── Value display ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.primary, width: 2),
                ),
                child: Text(
                  _display,
                  textAlign: TextAlign.right,
                  style: tt.headlineSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── Keypad ─────────────────────────────────────────────────────
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left: 3-column digit grid
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _row(['1', '2', '3']),
                          const SizedBox(height: 8),
                          _row(['4', '5', '6']),
                          const SizedBox(height: 8),
                          _row(['7', '8', '9']),
                          const SizedBox(height: 8),
                          _row(['-', '0', '.']),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right: backspace, esc, enter (enter is tall)
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _key(
                            child: const Icon(Icons.backspace_outlined),
                            onTap: _backspace,
                          ),
                          const SizedBox(height: 8),
                          _key(
                            child: const Text('esc'),
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _key(
                              child: const Icon(Icons.keyboard_return),
                              onTap: _confirm,
                              filled: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(List<String> keys) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _key(
              child: Text(keys[i]),
              onTap: () {
                switch (keys[i]) {
                  case '.':
                    _tapDot();
                  case '-':
                    _tapSign();
                  default:
                    _tapDigit(keys[i]);
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _key({
    required Widget child,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: filled ? cs.primary : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Center(
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: filled ? cs.onPrimary : cs.onSurface,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: filled ? cs.onPrimary : cs.onSurface,
                  size: 22,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live weight from the serial scale, with a one-tap capture into the keypad.
///
/// Capture is withheld until the scale reports a settled reading, so a cashier
/// can't bank a weight while the pan is still swinging. Scales that stream no
/// stability flag report every reading as settled (see [parseScaleWeight]).
class _ScaleWeightBar extends ConsumerWidget {
  const _ScaleWeightBar({required this.productUnit, required this.onUse});

  /// The cart line's measurement unit (`kg`, `L`, …), used only to warn on a
  /// mismatch — no unit conversion is ever applied to the scale's number.
  final String? productUnit;
  final ValueChanged<double> onUse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reading = ref.watch(scaleReadingProvider);

    return switch (reading) {
      AsyncError(:final error) => _shell(
          context,
          color: context.dangerColor,
          icon: Icons.error_outline,
          child: Text(
            error is ScaleException
                ? error.message
                : AppLocalizations.of(context)
                    .scaleErrorWithMessage(error.toString()),
            style: TextStyle(color: context.dangerColor, fontSize: 12),
          ),
        ),
      AsyncData(:final value) => _shell(
          context,
          color: value.stable ? context.successColor : context.warningColor,
          icon: value.stable
              ? Icons.monitor_weight_outlined
              : Icons.hourglass_empty,
          child: _reading(context, value.weight, value.unit, value.stable),
        ),
      _ => _shell(
          context,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          icon: Icons.hourglass_empty,
          child: Text(
            AppLocalizations.of(context).waitingForScale,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
    };
  }

  Widget _reading(
    BuildContext context,
    double weight,
    String? scaleUnit,
    bool stable,
  ) {
    final color = stable ? context.successColor : context.warningColor;
    // The parser never converts, so grams-on-a-kg-product would silently charge
    // 1000×. Surface it rather than guessing what the operator meant.
    final mismatch = scaleUnit != null &&
        productUnit != null &&
        productUnit!.isNotEmpty &&
        scaleUnit.toLowerCase() != productUnit!.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$weight${scaleUnit ?? ''}'
                '${stable ? '' : '   settling…'}',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FilledButton(
              onPressed: stable ? () => onUse(weight) : null,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: context.onStatusColor,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(AppLocalizations.of(context).useWeight),
            ),
          ],
        ),
        if (mismatch)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              AppLocalizations.of(context)
                  // `mismatch` already proved both are non-null; the field is
                  // public so the analyzer can't promote it.
                  .scaleUnitMismatch(scaleUnit, productUnit!),
              style: TextStyle(color: context.warningColor, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _shell(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}
