import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/barcode/barcode_provider.dart';
import 'package:pos_app/barcode/scan_bus.dart';
import 'package:pos_app/barcode/nomenclature/barcode_matcher.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rule.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rules_provider.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/product/product_model.dart';
import 'package:pos_app/product/product_provider.dart';
import 'package:pos_app/product/product_search.dart';
import 'package:pos_app/settings/developer_mode.dart';

/// The floating bug button, and behind it a barcode simulator.
///
/// Modelled on Odoo's POS debug window: developer mode puts a draggable bug on
/// top of the till, and it opens a panel that can inject a barcode as if it had
/// been scanned.
///
/// 🚨 The reason this exists is that the two barcode kinds that actually carry
/// business logic — a PRICE-embedded label and a WEIGHT-embedded one — cannot
/// be tested by typing. Both are EAN-13 with a check digit computed over a body
/// that changes with every amount, so a hand-typed one is rejected before any
/// of the interesting code runs, and the alternative is a physical scale on the
/// desk. The panel builds valid labels from the company's own nomenclature and
/// shows what the till decodes them back to, which is the whole diagnosis in
/// one screen.
///
/// English on purpose: this is a developer tool, gated behind a switch a
/// cashier never touches, and its vocabulary (nomenclature, check digit,
/// product key) is the codebase's, not the shop's.
class BarcodeDebugOverlay extends ConsumerStatefulWidget {
  const BarcodeDebugOverlay({super.key});

  @override
  ConsumerState<BarcodeDebugOverlay> createState() =>
      _BarcodeDebugOverlayState();
}

class _BarcodeDebugOverlayState extends ConsumerState<BarcodeDebugOverlay> {
  static const double _size = 46;

  /// Null until dragged: the button parks itself out of the way of the
  /// checkout button, and moves only when the operator moves it.
  Offset? _pos;

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(developerModeProvider)) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxLeft = (constraints.maxWidth - _size).clamp(0.0, double.infinity);
        final maxTop = (constraints.maxHeight - _size).clamp(0.0, double.infinity);
        // Default: top-right, below the app bar — the bottom-right corner
        // belongs to the FABs and the cart's pay button.
        final pos = _pos ?? Offset(maxLeft - 12, 84);

        return Stack(
          children: [
            Positioned(
              left: pos.dx.clamp(0.0, maxLeft),
              top: pos.dy.clamp(0.0, maxTop),
              child: GestureDetector(
                // Draggable because it floats over a working till: wherever it
                // is parked, sooner or later it covers the one button someone
                // needs.
                onPanUpdate: (d) => setState(() {
                  _pos = Offset(
                    (pos.dx + d.delta.dx).clamp(0.0, maxLeft),
                    (pos.dy + d.delta.dy).clamp(0.0, maxTop),
                  );
                }),
                child: Tooltip(
                  message: 'Open debug widget',
                  child: Material(
                    color: theme.colorScheme.errorContainer,
                    elevation: 4,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => BarcodeDebugPanel.show(context),
                      child: SizedBox(
                        width: _size,
                        height: _size,
                        child: Icon(Icons.bug_report,
                            color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The debug window: simulate a scan, and build a label to simulate.
class BarcodeDebugPanel extends ConsumerStatefulWidget {
  const BarcodeDebugPanel({super.key});

  static Future<void> show(BuildContext context) => showDialog(
        context: context,
        builder: (_) => const BarcodeDebugPanel(),
      );

  @override
  ConsumerState<BarcodeDebugPanel> createState() => _BarcodeDebugPanelState();
}

class _BarcodeDebugPanelState extends ConsumerState<BarcodeDebugPanel> {
  final _code = TextEditingController();
  final _value = TextEditingController(text: '1.250');

  BarcodeRule? _rule;
  String? _productBarcode;
  final List<String> _history = [];

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    super.dispose();
  }

  void _send(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    ref.read(scanBusProvider).emit(trimmed, source: ScanSource.simulated);
    setState(() {
      _history.remove(trimmed);
      _history.insert(0, trimmed);
      if (_history.length > 8) _history.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rules = ref.watch(barcodeRulesProvider).value ?? kDefaultBarcodeRules;
    final products = ref.watch(allProductsListProvider).value ?? const <Product>[];
    final extraBarcodes =
        ref.watch(allBarcodesByProductIdProvider).value ?? const {};
    final sym = ref.watch(currencySymbolProvider);
    final listening = ref.read(scanBusProvider).hasListener;

    // Only the rules that embed something are worth generating for — a Unit
    // rule's "label" is just the product's own barcode.
    final embeddingRules = rules
        .where((r) =>
            r.isEnabled &&
            (r.type == BarcodeRuleType.weighted ||
                r.type == BarcodeRuleType.priced ||
                r.type == BarcodeRuleType.discounted))
        .toList();
    final rule = embeddingRules.contains(_rule)
        ? _rule
        : (embeddingRules.isEmpty ? null : embeddingRules.first);

    // A product can only carry an embedded label if its own stored barcode
    // already decodes under the rule — i.e. it has the prefix AND zeros in the
    // value positions. Listing only those turns the commonest setup mistake
    // ("nothing appears here") into the answer.
    final candidates = <_BarcodeCandidate>[
      if (rule != null)
        for (final p in products.where((p) => p.isEnabled))
          for (final code in [
            ...p.barcodes,
            ...(extraBarcodes[p.id] ?? const <String>[]),
          ])
            if (tryMatchRule(code.trim(), rule) != null)
              _BarcodeCandidate(product: p, barcode: code.trim()),
    ];
    final selected = candidates.any((c) => c.barcode == _productBarcode)
        ? _productBarcode
        : (candidates.isEmpty ? null : candidates.first.barcode);

    final amount = double.tryParse(_value.text.trim().replaceAll(',', '.'));
    final generated = (rule != null && selected != null && amount != null)
        ? buildBarcodeForRule(rule, selected, amount)
        : null;

    final width = MediaQuery.sizeOf(context).width;

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Row(
        children: [
          Icon(Icons.bug_report, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Barcode simulator',
                style: theme.textTheme.titleMedium),
          ),
        ],
      ),
      content: SizedBox(
        width: width < 640 ? width - 64 : 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!listening)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Note(
                    icon: Icons.info_outline,
                    color: context.warningColor,
                    text: 'No screen is listening. Open the POS screen — the '
                        'scan is delivered to the same handler the hardware '
                        'scanner reaches, and nothing else consumes it.',
                  ),
                ),

              // ── 1. Send a barcode ────────────────────────────────────────
              Text('Simulate a scan', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _code,
                      autofocus: true,
                      style: const TextStyle(fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: '2210001003504',
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _send(_code.text),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Scan'),
                  ),
                ],
              ),

              // Typing a 12-digit body by hand is the normal way to reach this
              // panel; finishing it is arithmetic nobody should do on paper.
              if (_needsCheckDigit(_code.text))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                        'Add EAN-13 check digit → ${withCheckDigit(_code.text.trim())}'),
                    onPressed: () => setState(() {
                      _code.text = withCheckDigit(_code.text.trim());
                    }),
                  ),
                ),

              const SizedBox(height: 12),
              _DecodeCard(
                code: _code.text,
                rules: rules,
                products: products,
                extraBarcodes: extraBarcodes,
                currencySymbol: sym,
              ),

              const Divider(height: 28),

              // ── 2. Build one ─────────────────────────────────────────────
              Text('Build a label', style: theme.textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                'Uses this company\'s nomenclature and recomputes the check '
                'digit, so the result is a label a real scale could print.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),

              if (embeddingRules.isEmpty)
                _Note(
                  icon: Icons.rule,
                  color: context.warningColor,
                  text: 'No priced, weighted or discount rule is enabled in the '
                      'nomenclature. Settings → Barcode rules.',
                )
              else ...[
                DropdownButtonFormField<BarcodeRule>(
                  initialValue: rule,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Rule',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final r in embeddingRules)
                      DropdownMenuItem(
                        value: r,
                        child: Text('${r.name}  ·  ${r.pattern}',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (r) => setState(() {
                    _rule = r;
                    _productBarcode = null;
                  }),
                ),
                const SizedBox(height: 10),
                if (candidates.isEmpty)
                  _Note(
                    icon: Icons.inventory_2_outlined,
                    color: context.warningColor,
                    text: 'No product carries a barcode this rule matches. The '
                        'stored barcode needs the rule\'s prefix and ZEROS in '
                        'the embedded positions — e.g. 2210001000005 for '
                        '22.....{NNDDD}.',
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Product',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final c in candidates)
                        DropdownMenuItem(
                          value: c.barcode,
                          child: Text(
                            '${c.product.name}  ·  ${c.barcode}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _productBarcode = v),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _value,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: switch (rule?.type) {
                      BarcodeRuleType.priced => 'Line total ($sym)',
                      BarcodeRuleType.discounted => 'Discount (%)',
                      _ => 'Weight',
                    },
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          generated ??
                              'Does not fit — the value needs more digits than '
                                  'the rule reserves.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: generated != null ? 'monospace' : null,
                            color: generated != null
                                ? null
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (generated != null) ...[
                        IconButton(
                          tooltip: 'Copy',
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () => Clipboard.setData(
                              ClipboardData(text: generated)),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _code.text = generated;
                          }),
                          child: const Text('Fill'),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: () {
                            _code.text = generated;
                            _send(generated);
                          },
                          child: const Text('Scan'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              if (_history.isNotEmpty) ...[
                const Divider(height: 28),
                Text('Recent', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final code in _history)
                      ActionChip(
                        label: Text(code,
                            style: const TextStyle(fontFamily: 'monospace')),
                        onPressed: () {
                          _code.text = code;
                          _send(code);
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  /// True for a 12-digit body that is one digit short of a valid EAN-13.
  static bool _needsCheckDigit(String raw) {
    final code = raw.trim();
    return code.length == 12 && RegExp(r'^\d+$').hasMatch(code);
  }
}

class _BarcodeCandidate {
  const _BarcodeCandidate({required this.product, required this.barcode});

  final Product product;
  final String barcode;
}

/// What the till makes of the typed barcode, computed with the same functions
/// the scan handler uses — rule, decoded value, product key, and the product
/// (if any) that key resolves to.
class _DecodeCard extends StatelessWidget {
  const _DecodeCard({
    required this.code,
    required this.rules,
    required this.products,
    required this.extraBarcodes,
    required this.currencySymbol,
  });

  final String code;
  final List<BarcodeRule> rules;
  final List<Product> products;
  final Map<int, List<String>> extraBarcodes;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = code.trim();

    if (trimmed.isEmpty) {
      return _Note(
        icon: Icons.keyboard,
        color: theme.colorScheme.onSurfaceVariant,
        text: 'Type or build a barcode to see how the till reads it.',
      );
    }

    final match = matchBarcode(trimmed, rules);
    final key = match?.productKey ?? trimmed;
    final sellable = products.where((p) => p.isEnabled);
    final product = sellable
            .where((p) => p.code?.toLowerCase() == key.toLowerCase())
            .firstOrNull ??
        findProductByBarcode(sellable, key, extraBarcodes: extraBarcodes);

    // The quantity the scan handler would put in the cart. Mirrors the switch
    // in `_handleBarcodeSubmit` — if these two ever disagree, this panel is
    // lying about the thing it exists to prove.
    String quantityLine() {
      if (product == null) return '—';
      return switch (match?.rule.type) {
        BarcodeRuleType.weighted => '${match!.value} × ${product.name}',
        BarcodeRuleType.priced => product.price > 0
            ? '${(match!.value / product.price).toStringAsFixed(4)} × '
                '${product.name}  (${match.value} $currencySymbol ÷ '
                '${product.price} $currencySymbol)'
            : 'Product price is 0 — the till refuses this one',
        BarcodeRuleType.discounted =>
          '1 × ${product.name}  −${match!.value}%',
        _ => '1 × ${product.name}',
      };
    }

    final typeLabel = switch (match?.rule.type) {
      BarcodeRuleType.weighted => 'WEIGHTED',
      BarcodeRuleType.priced => 'PRICED',
      BarcodeRuleType.discounted => 'DISCOUNTED',
      BarcodeRuleType.unit => 'UNIT',
      null => 'NO RULE',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (match == null
                          ? context.dangerColor
                          : theme.colorScheme.primary)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  typeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: match == null
                        ? context.dangerColor
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(match?.rule.name ?? 'no rule matched this code',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _KeyValue(
            label: 'EAN-13 check digit',
            value: trimmed.length == 13
                ? (hasValidCheckDigit(trimmed) ? 'valid' : 'INVALID')
                : 'n/a (${trimmed.length} chars)',
            color: trimmed.length == 13 && !hasValidCheckDigit(trimmed)
                ? context.dangerColor
                : null,
          ),
          _KeyValue(label: 'Product key', value: key),
          if (match != null && match.rule.type != BarcodeRuleType.unit)
            _KeyValue(label: 'Embedded value', value: '${match.value}'),
          _KeyValue(
            label: 'Product',
            value: product?.name ?? 'not found for this key',
            color: product == null ? context.dangerColor : null,
          ),
          _KeyValue(label: 'Cart line', value: quantityLine()),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace', color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}
