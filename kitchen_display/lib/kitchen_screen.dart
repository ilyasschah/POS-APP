import 'package:flutter/material.dart';

import 'kds_models.dart';

/// Pure display of kitchen tickets. It owns no network or storage — orders are
/// handed in from the root (which receives them over the LAN from the paired
/// POS), and marking an order ready is delegated back up via [onMarkReady].
class KitchenScreen extends StatefulWidget {
  final List<KitchenOrder> orders;
  final String posName;
  final void Function(KitchenOrder order) onMarkReady;
  final VoidCallback onUnpair;

  const KitchenScreen({
    super.key,
    required this.orders,
    required this.posName,
    required this.onMarkReady,
    required this.onUnpair,
  });

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) _updateScrollArrows();
    });
  }

  @override
  void didUpdateWidget(covariant KitchenScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) _updateScrollArrows();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollArrows() {
    if (!_scrollController.hasClients) return;
    final canLeft = _scrollController.offset > 0;
    final canRight =
        _scrollController.offset < _scrollController.position.maxScrollExtent;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scrollBy(double delta) {
    _scrollController.animateTo(
      (_scrollController.offset + delta)
          .clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _confirmUnpair() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unpair this display?'),
        content: Text(
          'This Kitchen Display will be disconnected from ${widget.posName} '
          'and return to the pairing screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onUnpair();
            },
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF546E7A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kitchen Display — ${orders.length} order${orders.length == 1 ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              'Paired with ${widget.posName}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.link_off),
            tooltip: 'Unpair',
            onPressed: _confirmUnpair,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: orders.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_menu, size: 72, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Waiting for orders…',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  thickness: 8,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: orders
                          .map((order) => KitchenCard(
                                order: order,
                                onMarkReady: () => widget.onMarkReady(order),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                if (_canScrollLeft)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _ScrollArrowButton(
                        icon: Icons.chevron_left,
                        onTap: () => _scrollBy(-340),
                      ),
                    ),
                  ),
                if (_canScrollRight)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _ScrollArrowButton(
                        icon: Icons.chevron_right,
                        onTap: () => _scrollBy(340),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ScrollArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ScrollArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}

class KitchenCard extends StatelessWidget {
  final KitchenOrder order;
  final VoidCallback onMarkReady;

  const KitchenCard({
    super.key,
    required this.order,
    required this.onMarkReady,
  });

  @override
  Widget build(BuildContext context) {
    final title = order.tableName != null && order.tableName!.isNotEmpty
        ? order.tableName!
        : order.number;
    final timeStr = order.dateCreated != null
        ? "${order.dateCreated!.hour.toString().padLeft(2, '0')}:${order.dateCreated!.minute.toString().padLeft(2, '0')}"
        : "";

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: order.headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              order.typeString,
              style: const TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // Items scroll within the card when the order is long or vertical
          // space is tight, so the header + DONE footer always stay visible
          // and the card never overflows.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: order.items.map((item) {
              return StatefulBuilder(
                builder: (context, setLocal) {
                  return InkWell(
                    onTap: () => setLocal(() => item.isDone = !item.isDone),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${item.quantity.toInt()} x ",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  decoration: item.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color:
                                      item.isDone ? Colors.grey : Colors.black87,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    decoration: item.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: item.isDone
                                        ? Colors.grey
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // The choices, above any typed note: they are what
                          // the cook has to DO differently, and a note is a
                          // remark about it.
                          ...item.modifiers.map(
                            (m) => Padding(
                              padding: const EdgeInsets.only(top: 4, left: 32),
                              child: Text(
                                '+ $m',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: item.isDone
                                      ? Colors.grey.shade400
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          if (item.comment != null && item.comment!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 32),
                              child: Text(
                                item.comment!,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: item.isDone
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
                }).toList(),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onMarkReady,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      "DONE",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
