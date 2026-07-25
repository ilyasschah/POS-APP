import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/customer_display/customer_display_web_server.dart';

// Internal item model — parsed from the WebSocket JSON broadcast.
// No dependency on CartItem / Riverpod so this screen works even when running
// as a separate process from the POS (two-monitor setup).
class _Item {
  final String name;
  final double qty;
  final double price;
  final double discount;
  final double lineTotal;
  final String? image; // raw base64, may be null

  _Item.fromJson(Map<String, dynamic> j)
    : name = (j['name'] ?? '') as String,
      qty = ((j['qty'] ?? 1) as num).toDouble(),
      price = ((j['price'] ?? 0) as num).toDouble(),
      discount = ((j['discount'] ?? 0) as num).toDouble(),
      lineTotal = ((j['lineTotal'] ?? 0) as num).toDouble(),
      image = j['image'] as String?;
}

// This screen is pushed inside the app's MaterialApp, so every colour is read
// from `Theme.of(context)` — the customer display follows the operator's chosen
// theme (light / dark / dimmed / night / …) and accent exactly, never a
// hardcoded palette.

// ─────────────────────────────────────────────────────────────────────────────
// Root widget
//
// Connects to ws://localhost:8181/ws and reacts to every broadcast the POS
// pushes.  Works correctly whether this widget lives in the same Flutter
// process as the POS or in a second native .exe instance on a second monitor —
// both are plain WebSocket clients against the POS's local server.
// ─────────────────────────────────────────────────────────────────────────────
class CustomerDisplayScreen extends StatefulWidget {
  const CustomerDisplayScreen({super.key});

  @override
  State<CustomerDisplayScreen> createState() => _CustomerDisplayScreenState();
}

class _CustomerDisplayScreenState extends State<CustomerDisplayScreen> {
  WebSocket? _ws; // null  = not connected
  Timer? _retryTimer;
  bool _everConnected = false;
  int _retryMs = 1000;

  // Epoch bumped each time we enter 'success' from a non-success state,
  // giving _SuccessView a fresh key so it rebuilds for every checkout.
  int _successEpoch = 0;

  Map<String, dynamic> _d = const {'type': 'idle'};

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _ws?.close();
    super.dispose();
  }

  Future<void> _connect() async {
    // Cancel any pending auto-retry so we never have two races in flight.
    _retryTimer?.cancel();

    // Close and discard the old socket before opening a new one.
    final stale = _ws;
    _ws = null;
    try {
      stale?.close();
    } catch (_) {}

    const uri = 'ws://localhost:${CustomerDisplayWebServer.port}/ws';
    try {
      final ws = await WebSocket.connect(uri);

      if (!mounted) {
        try {
          ws.close();
        } catch (_) {}
        return;
      }

      _ws = ws;
      setState(() {
        _everConnected = true;
        _retryMs = 1000;
      });

      ws.listen(
        (raw) {
          // Guard stale listeners: if _ws was replaced by a newer call, ignore.
          if (!mounted || _ws != ws) return;
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            final wasSuccess = _d['type'] == 'success';
            final isSuccess = data['type'] == 'success';
            setState(() {
              _d = data;
              if (isSuccess && !wasSuccess) _successEpoch++;
            });
          } catch (_) {
            // Malformed JSON or unexpected binary frame — skip silently.
          }
        },
        onDone: () {
          if (_ws == ws) _scheduleReconnect();
        },
        onError: (_) {
          if (_ws == ws) _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      if (mounted) _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    _ws = null;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(milliseconds: _retryMs), () {
      if (!mounted) return;
      _retryMs = min(_retryMs * 2, 30000);
      _connect();
    });
    setState(() {}); // show/refresh the reconnecting badge
  }

  @override
  Widget build(BuildContext context) {
    final type = (_d['type'] ?? 'idle') as String;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: switch (type) {
              'cart' => _SplitView(d: _d, key: const ValueKey('split')),
              'success' => _SuccessView(
                d: _d,
                key: ValueKey('success-$_successEpoch'),
              ),
              _ => _IdleView(d: _d, key: const ValueKey('idle')),
            },
          ),
          // Subtle badge (bottom-right), overlaid on whatever screen is showing
          // so idle/cart content remains visible during a brief reconnect —
          // avoids flashing a hard "disconnect" screen.
          if (_ws == null)
            _ReconnectBadge(
              label: _everConnected
                ? AppLocalizations.of(context).reconnectingEllipsis
                : AppLocalizations.of(context).connectingEllipsis,
              onTap: _connect,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reconnect / connecting badge
// ─────────────────────────────────────────────────────────────────────────────
class _ReconnectBadge extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ReconnectBadge({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final warn = context.warningColor;
    return Positioned(
      bottom: 12,
      right: 12,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: warn.withValues(alpha: .15),
            border: Border.all(color: warn.withValues(alpha: .5)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: warn,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: warn, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. IDLE
// ─────────────────────────────────────────────────────────────────────────────
class _IdleView extends StatelessWidget {
  final Map<String, dynamic> d;
  const _IdleView({required this.d, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final co = (d['company'] ?? {}) as Map;
    final logo = co['logo'] as String?;
    final name = (co['name'] ?? '') as String;
    final welcome = (d['welcomeText'] ?? 'WELCOME!') as String;

    return SizedBox.expand(
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (logo != null && logo.isNotEmpty) ...[
                _Logo(base64: logo, size: 180),
                const SizedBox(height: 32),
              ],
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                welcome,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. SPLIT PANE  (cartActive / paymentPending both broadcast type:'cart')
// ─────────────────────────────────────────────────────────────────────────────
class _SplitView extends StatelessWidget {
  final Map<String, dynamic> d;
  const _SplitView({required this.d, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final co = (d['company'] ?? {}) as Map;
    final logo = co['logo'] as String?;
    final name = (co['name'] ?? '') as String;
    final cur = (d['currency'] ?? '') as String;
    final items = ((d['items'] ?? []) as List)
        .map((e) => _Item.fromJson(e as Map<String, dynamic>))
        .toList();
    final tax = ((d['tax'] ?? 0) as num).toDouble();
    final discount = ((d['discount'] ?? 0) as num).toDouble();
    final total = ((d['total'] ?? 0) as num).toDouble();

    return SizedBox.expand(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left: branding canvas ─────────────────────────────────────────
          Expanded(
            flex: 45,
            child: ColoredBox(
              color: cs.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (logo != null && logo.isNotEmpty) ...[
                        _Logo(base64: logo, size: 150),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(width: 1, color: cs.outlineVariant),
          // ── Right: live transaction stream ────────────────────────────────
          Expanded(
            flex: 55,
            child: ColoredBox(
              color: cs.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Container(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: .5),
                      ),
                      itemBuilder: (_, i) =>
                          _ItemRow(item: items[i], currency: cur),
                    ),
                  ),
                  _TotalsBlock(
                    currency: cur,
                    tax: tax,
                    discount: discount,
                    total: total,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Item row ────────────────────────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final _Item item;
  final String currency;
  const _ItemRow({required this.item, required this.currency});

  String _qty(double q) =>
      q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDisc = item.discount > 0.001;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Thumb(image: item.image, name: item.name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_qty(item.qty)} × $currency '
                  '${item.price.toStringAsFixed(2)} / Units',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                if (hasDisc)
                  Text(
                    AppLocalizations.of(context).discountAmountLine(
                        currency, item.discount.toStringAsFixed(2)),
                    style: TextStyle(color: context.successColor, fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$currency ${item.lineTotal.toStringAsFixed(2)}',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// Product thumbnail ───────────────────────────────────────────────────────────
class _Thumb extends StatelessWidget {
  final String? image;
  final String name;
  const _Thumb({required this.image, required this.name});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget inner;
    if (image != null && image!.isNotEmpty) {
      try {
        inner = Image.memory(
          base64Decode(image!),
          fit: BoxFit.cover,
          cacheWidth: 50,
          errorBuilder: (_, __, ___) => _initials(context),
        );
      } catch (_) {
        inner = _initials(context);
      }
    } else {
      inner = _initials(context);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 50,
        height: 50,
        child: ColoredBox(
          color: cs.onSurface.withValues(alpha: .08),
          child: inner,
        ),
      ),
    );
  }

  Widget _initials(BuildContext context) => Center(
    child: Text(
      (name.isNotEmpty ? name[0] : '?').toUpperCase(),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// Pinned totals footer ────────────────────────────────────────────────────────
class _TotalsBlock extends StatelessWidget {
  final String currency;
  final double tax, discount, total;
  const _TotalsBlock({
    required this.currency,
    required this.tax,
    required this.discount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tax > 0)
            _TotRow(AppLocalizations.of(context).taxesLabel,
                '$currency ${tax.toStringAsFixed(2)}'),
          if (discount > 0)
            _TotRow(
              AppLocalizations.of(context).posDiscount,
              '−$currency ${discount.toStringAsFixed(2)}',
              valueColor: context.successColor,
            ),
          const SizedBox(height: 6),
          Divider(color: cs.outlineVariant, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).totalLabel,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              Text(
                '$currency ${total.toStringAsFixed(2)}',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              AppLocalizations.of(context).poweredByPos,
              style: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: .6),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _TotRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? cs.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. CHECKOUT SUCCESS
//
// No animation, no checkmark — just the configurable message and the amounts.
// The message comes from `CustomerDisplay.ThankYouMessage`; when it is blank the
// broadcast carries the localized "Thank you" fallback.
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final Map<String, dynamic> d;
  const _SuccessView({required this.d, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cur = (d['currency'] ?? '') as String;
    final total = ((d['total'] ?? 0) as num).toDouble();
    final cash = ((d['cash'] ?? 0) as num).toDouble();
    final change = ((d['change'] ?? 0) as num).toDouble();
    final message = ((d['thankYouText'] as String?)?.trim().isNotEmpty ?? false)
        ? (d['thankYouText'] as String)
        : AppLocalizations.of(context).thankYou;

    return SizedBox.expand(
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$cur ${total.toStringAsFixed(2)}',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: .7),
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (cash > 0) ...[
                const SizedBox(height: 28),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PayCol('CASH PAID', '$cur ${cash.toStringAsFixed(2)}'),
                    const SizedBox(width: 52),
                    _PayCol(
                      'CHANGE DUE',
                      '$cur ${change.toStringAsFixed(2)}',
                      green: true,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PayCol extends StatelessWidget {
  final String label, value;
  final bool green;
  const _PayCol(this.label, this.value, {this.green = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: green ? context.successColor : cs.onSurface,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared: base64 logo image
// ─────────────────────────────────────────────────────────────────────────────
class _Logo extends StatelessWidget {
  final String base64;
  final double size;
  const _Logo({required this.base64, required this.size});

  @override
  Widget build(BuildContext context) {
    try {
      return Image.memory(
        base64Decode(base64),
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: size.round(),
        errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
      );
    } catch (_) {
      return SizedBox(width: size, height: size);
    }
  }
}
