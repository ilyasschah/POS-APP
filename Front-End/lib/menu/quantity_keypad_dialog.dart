import 'package:flutter/material.dart';

/// Touch-friendly numeric keypad for entering a custom (decimal) quantity for a
/// cart line — e.g. weighing out `0.5 kg` without a scale barcode. Returns the
/// parsed quantity via [Navigator.pop], or `null` if the cashier cancels.
///
/// The price scales automatically: the cart stores a per-unit price, so a line
/// total is always `price × quantity`. Entering `0.5` therefore charges half,
/// whatever the product's measurement unit (kg, L, pcs, …).
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

class _QuantityKeypadDialog extends StatefulWidget {
  final String itemName;
  final double initialQuantity;
  final String? unit;

  const _QuantityKeypadDialog({
    required this.itemName,
    required this.initialQuantity,
    this.unit,
  });

  @override
  State<_QuantityKeypadDialog> createState() => _QuantityKeypadDialogState();
}

class _QuantityKeypadDialogState extends State<_QuantityKeypadDialog> {
  late String _input;
  // The seed value is shown but replaced on the first digit press, so the
  // cashier can just start typing the new quantity without clearing first.
  bool _replaceOnNextKey = true;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuantity;
    _input = q == q.roundToDouble() ? q.toInt().toString() : q.toString();
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
                'Change quantity',
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
