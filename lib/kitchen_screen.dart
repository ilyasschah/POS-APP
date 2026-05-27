import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'api_client.dart';

// --- MODELS ---
class KitchenItem {
  final int id;
  final String name;
  final double quantity;
  final String? comment;
  bool isDone;

  KitchenItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.comment,
    this.isDone = false,
  });
}

class KitchenOrder {
  final int id;
  final String number;
  final String? tableName;
  final int serviceType;
  final int serviceStatus;
  final DateTime? dateCreated;
  final List<KitchenItem> items;

  KitchenOrder({
    required this.id,
    required this.number,
    this.tableName,
    required this.serviceType,
    required this.serviceStatus,
    this.dateCreated,
    required this.items,
  });

  String get typeString {
    if (serviceType == 1) return "Dine in";
    if (serviceType == 2) return "Takeaway";
    if (serviceType == 3) return "Delivery";
    return "Order";
  }

  Color get headerColor {
    if (dateCreated == null) return const Color(0xFFAED581);
    final minutesOld = DateTime.now().difference(dateCreated!).inMinutes;
    if (minutesOld > 15) return const Color(0xFFFF8A65);
    if (minutesOld > 5) return const Color(0xFFFFF176);
    return const Color(0xFFAED581);
  }
}

// --- MAIN SCREEN ---
class KitchenScreen extends StatefulWidget {
  final int companyId;

  const KitchenScreen({super.key, required this.companyId});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  static const int _kdsPort = 9090;

  Timer? _refreshTimer;
  int _refreshSeconds = 30;
  bool _isLoading = false;
  List<KitchenOrder> _orders = [];
  final ApiClient _apiClient = ApiClient();
  HttpServer? _httpServer;
  String _deviceIp = '…';
  bool _serverRunning = false;
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startTimer();
    _startHttpServer();
    _resolveDeviceIp();
    _scrollController.addListener(_updateScrollArrows);
  }

  void _updateScrollArrows() {
    final canLeft = _scrollController.offset > 0;
    final canRight = _scrollController.offset < _scrollController.position.maxScrollExtent;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scrollBy(double delta) {
    _scrollController.animateTo(
      (_scrollController.offset + delta).clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _httpServer?.close(force: true);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _resolveDeviceIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            if (mounted) setState(() => _deviceIp = addr.address);
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _startHttpServer() async {
    try {
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, _kdsPort);
      if (mounted) setState(() => _serverRunning = true);
      debugPrint('[KDS] HTTP server listening on port $_kdsPort');
      _httpServer!.listen(_handleRequest);
    } catch (e) {
      debugPrint('[KDS] Failed to start HTTP server: $e');
    }
  }

  Future<void> _handleRequest(HttpRequest req) async {
    try {
      await req.drain<void>();
      if (req.method == 'POST' && req.uri.path == '/refresh') {
        _fetchData();
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'refreshing'}));
      } else if (req.method == 'GET' && req.uri.path == '/health') {
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'ok'}));
      } else {
        req.response.statusCode = HttpStatus.notFound;
      }
    } catch (e) {
      debugPrint('[KDS] handler error: $e');
      req.response.statusCode = HttpStatus.internalServerError;
    } finally {
      await req.response.close();
    }
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(seconds: _refreshSeconds),
      (_) => _fetchData(),
    );
  }

  Future<void> _fetchData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final rawData = await _apiClient.getKitchenOrders(widget.companyId);
      final loadedOrders = rawData.map<KitchenOrder>((item) {
        final rawItems = (item['items'] ?? []) as List<dynamic>;

        final kitchenItems = rawItems.map((i) {
          return KitchenItem(
            id: (i['id'] ?? 0) as int,
            name: (i['productName'] ?? 'Unknown Item') as String,
            quantity: ((i['quantity'] ?? 1) as num).toDouble(),
            comment: i['comment'] as String?,
          );
        }).toList();

        DateTime? createdAt;
        final rawDate = item['dateCreated'];
        if (rawDate != null) {
          createdAt = DateTime.tryParse(rawDate.toString())?.toLocal();
        }

        return KitchenOrder(
          id: item['id'] as int,
          number: (item['number'] ?? 'Unknown') as String,
          tableName: item['tableName'] as String?,
          serviceType: (item['serviceType'] ?? item['ServiceType'] ?? 1) as int,
          serviceStatus: (item['serviceStatus'] ?? 2) as int,
          dateCreated: createdAt,
          items: kitchenItems,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _orders = loadedOrders;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) _updateScrollArrows();
        });
      }
    } catch (e, stacktrace) {
      debugPrint("KITCHEN PARSE ERROR: $e");
      debugPrint(stacktrace.toString());
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _removeOrder(int orderId) {
    if (!mounted) return;
    setState(() {
      _orders.removeWhere((order) => order.id == orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF546E7A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Kitchen Display — ${_orders.length} order${_orders.length == 1 ? '' : 's'}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              'IP: $_deviceIp:$_kdsPort',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              const Icon(Icons.timer, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _refreshSeconds,
                dropdownColor: const Color(0xFF546E7A),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 10, child: Text("10s")),
                  DropdownMenuItem(value: 30, child: Text("30s")),
                  DropdownMenuItem(value: 60, child: Text("60s")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _refreshSeconds = val);
                    _startTimer();
                  }
                },
              ),
            ],
          ),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
      ),
      body: _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Setup card ────────────────────────────────────────
                  Container(
                    width: 420,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 24),
                          decoration: const BoxDecoration(
                            color: Color(0xFF546E7A),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lan_outlined,
                                  color: Colors.white, size: 28),
                              const SizedBox(width: 12),
                              const Text(
                                'Kitchen Display — Setup',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _serverRunning
                                      ? Colors.green.shade400
                                      : Colors.orange.shade400,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _serverRunning
                                          ? Icons.circle
                                          : Icons.hourglass_top,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _serverRunning ? 'Ready' : 'Starting…',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // body
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Enter this address in the POS app:',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.black54),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 18, horizontal: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  '$_deviceIp:$_kdsPort',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: 1.5,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Settings → Kitchen Display → Add this IP',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.black45),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // ── Waiting label ──────────────────────────────────────
                  const Text(
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
                      children: _orders.map((order) {
                        return KitchenCard(
                          order: order,
                          companyId: widget.companyId,
                          onRemove: () => _removeOrder(order.id),
                          onMarkReady: (id) async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final success = await _apiClient.updateStatus(
                                widget.companyId,
                                id,
                                3,
                              );
                              if (!mounted) return;
                              if (success) {
                                _removeOrder(id);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text("Order Marked as Ready!"),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text("Error: $e"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Left arrow
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
                // Right arrow
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

// --- SCROLL ARROW BUTTON ---
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

// --- CARD COMPONENT ---
class KitchenCard extends StatelessWidget {
  final KitchenOrder order;
  final VoidCallback onRemove;
  final int companyId;
  final Function(int) onMarkReady;

  const KitchenCard({
    super.key,
    required this.order,
    required this.onRemove,
    required this.companyId,
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
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

          Column(
            children: order.items.map((item) {
              return StatefulBuilder(
                builder: (context, setState) {
                  return InkWell(
                    onTap: () => setState(() => item.isDone = !item.isDone),
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
                                  color: item.isDone
                                      ? Colors.grey
                                      : Colors.black87,
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

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (order.serviceStatus == 2)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onMarkReady(order.id),
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
