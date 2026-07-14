import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/kitchen/printer_group_model.dart';
import 'package:pos_app/printer/printer_config_model.dart';
import 'package:pos_app/printer/receipt_printer_service.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

const _kFontFamilies = [
  '(None)',
  'Courier',
  'Arial',
  'Helvetica',
  'Times New Roman',
  'Roboto',
  'Monospace',
];
const _kPaperSizes = ['80mm', '58mm'];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

/// The 4-tab printer/receipt settings, embeddable directly in the Settings
/// content pane (no Scaffold/AppBar of its own — the Settings screen already
/// provides the sidebar + chrome).
class PrinterSettingsBody extends StatelessWidget {
  const PrinterSettingsBody({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surface,
            child: SizedBox(
              height: 54,
              // Scrollable so the four tabs never overflow on a 10-inch tablet.
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.hintColor,
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 3,
                dividerColor: theme.dividerColor.withValues(alpha: 0.3),
                labelPadding: const EdgeInsets.symmetric(horizontal: 20),
                tabs: const [
                  _PTab(icon: Icons.print_outlined, label: 'Printers'),
                  _PTab(
                    icon: Icons.receipt_long_outlined,
                    label: 'Customize Receipt',
                  ),
                  _PTab(icon: Icons.translate_rounded, label: 'Localize Text'),
                  _PTab(icon: Icons.article_outlined, label: 'Print Templates'),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
          const Expanded(
            child: TabBarView(
              children: [
                _PrintersTab(),
                _CustomizeReceiptTab(),
                _LocalizeTextTab(),
                _PrintTemplatesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRINTERS TAB  (add-your-own printer list)
// ─────────────────────────────────────────────────────────────────────────────

class _PrintersTab extends ConsumerStatefulWidget {
  const _PrintersTab();

  @override
  ConsumerState<_PrintersTab> createState() => _PrintersTabState();
}

class _PrintersTabState extends ConsumerState<_PrintersTab> {
  List<Printer> _printers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() => _loading = true);
    try {
      final list = await Printing.listPrinters();
      if (mounted) setState(() { _printers = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PrinterConfig> _configs() => PrinterConfig.listFromJson(
        ref.read(appSettingsProvider)[SettingKeys.printersList],
      );

  Future<void> _saveConfigs(List<PrinterConfig> list) => ref
      .read(appSettingsProvider.notifier)
      .set(SettingKeys.printersList, PrinterConfig.listToJson(list));

  Future<void> _addPrinter() async {
    final name = await _promptName(context, title: 'Add printer');
    if (name == null || name.trim().isEmpty) return;
    final list = [..._configs()];
    list.add(PrinterConfig(
      prefix: 'Printer.${const Uuid().v4()}',
      name: name.trim(),
    ));
    await _saveConfigs(list);
  }

  Future<void> _rename(PrinterConfig p) async {
    final name = await _promptName(context, title: 'Rename printer', initial: p.name);
    if (name == null || name.trim().isEmpty) return;
    await _saveConfigs(
      _configs().map((c) => c.prefix == p.prefix ? c.copyWith(name: name.trim()) : c).toList(),
    );
  }

  Future<void> _delete(PrinterConfig p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete printer'),
        content: Text('Remove "${p.name}"? Its settings will be discarded.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _saveConfigs(_configs().where((c) => c.prefix != p.prefix).toList());
  }

  void _openHardware(PrinterConfig p) =>
      showPrinterHardwareDrawer(context, prefix: p.prefix, name: p.name);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch settings so the list rebuilds when a config is added/renamed/toggled.
    ref.watch(appSettingsProvider);
    final configs = _configs();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            'Add a printer for each station, then open its settings to configure '
            'paper size, margins, header/footer and the cash drawer.',
            style: TextStyle(fontSize: 12, color: theme.hintColor, height: 1.5),
          ),
        ),
        ...configs.map((p) => _PrinterRowCard(
              config: p,
              printers: _printers,
              loadingPrinters: _loading,
              onRefresh: _loadPrinters,
              onRename: () => _rename(p),
              onDelete: p.builtin ? null : () => _delete(p),
              onOpenSettings: () => _openHardware(p),
              onToggleEnabled: (v) => _saveConfigs(
                _configs()
                    .map((c) => c.prefix == p.prefix ? c.copyWith(enabled: v) : c)
                    .toList(),
              ),
              onPickPrinter: (name) => ref
                  .read(appSettingsProvider.notifier)
                  .set('${p.prefix}.PrinterName', name),
            )),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addPrinter,
            icon: const Icon(Icons.add),
            label: const Text('Add printer'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small name-entry dialog shared by Add / Rename.
Future<String?> _promptName(
  BuildContext context, {
  required String title,
  String? initial,
}) {
  final ctrl = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Printer name',
          hintText: 'e.g. Bar printer',
        ),
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(c, ctrl.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// Opens the hardware configuration for one printer as a right-side drawer
/// (a sliding side panel) instead of a full page, so the surrounding Settings
/// screen stays visible behind it.
Future<void> showPrinterHardwareDrawer(
  BuildContext context, {
  required String prefix,
  required String name,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  // Full width on a phone-narrow window; a comfortable side panel otherwise.
  final panelWidth =
      screenWidth < 600 ? screenWidth : (screenWidth * 0.5).clamp(440.0, 620.0);

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Printer settings',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, _, __) {
      final theme = Theme.of(ctx);
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: theme.scaffoldBackgroundColor,
          elevation: 16,
          child: ConstrainedBox(
            constraints: BoxConstraints.expand(width: panelWidth.toDouble()),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    height: 60,
                    padding: const EdgeInsets.only(left: 20, right: 8),
                    color: theme.colorScheme.surface,
                    child: Row(
                      children: [
                        Icon(Icons.print_outlined,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          iconSize: 26,
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                      height: 1,
                      color: theme.dividerColor.withValues(alpha: 0.3)),
                  Expanded(
                    child: _RolePrinterTab(role: prefix, displayName: name),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

// ── One printer row in the Printers tab ───────────────────────────────────────

class _PrinterRowCard extends ConsumerWidget {
  final PrinterConfig config;
  final List<Printer> printers;
  final bool loadingPrinters;
  final VoidCallback onRefresh;
  final VoidCallback onRename;
  final VoidCallback? onDelete;
  final VoidCallback onOpenSettings;
  final ValueChanged<bool> onToggleEnabled;
  final ValueChanged<String> onPickPrinter;

  const _PrinterRowCard({
    required this.config,
    required this.printers,
    required this.loadingPrinters,
    required this.onRefresh,
    required this.onRename,
    required this.onDelete,
    required this.onOpenSettings,
    required this.onToggleEnabled,
    required this.onPickPrinter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(appSettingsProvider);
    final selectedName = settings['${config.prefix}.PrinterName'] ?? '';
    final printerNames = printers.map((p) => p.name).toList();
    // Union the saved value in so an offline / disconnected printer still shows.
    final options = <String>{
      ...printerNames,
      if (selectedName.isNotEmpty) selectedName,
    }.toList();
    final safeSelected = options.contains(selectedName)
        ? selectedName
        : (options.isNotEmpty ? options.first : null);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 0 : 1,
      shadowColor: theme.shadowColor.withValues(alpha: 0.06),
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isDark
            ? BorderSide(color: theme.dividerColor.withValues(alpha: 0.2))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(_iconFor(config.prefix),
                      size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              config.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (config.builtin) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'BUILT-IN',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: config.enabled,
                  activeThumbColor: theme.colorScheme.primary,
                  onChanged: onToggleEnabled,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Rename',
                  onPressed: onRename,
                ),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: theme.colorScheme.error),
                    tooltip: 'Delete',
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Responsive: dropdown + settings side-by-side on a wide pane, stacked
            // on a narrow one so nothing is ever clipped.
            LayoutBuilder(
              builder: (ctx, c) {
                final Widget dropdown = loadingPrinters
                    ? const SizedBox(
                        height: 48,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : options.isEmpty
                        ? Row(
                            children: [
                              Expanded(
                                child: Text('No printers found',
                                    style: TextStyle(
                                        fontSize: 14, color: theme.hintColor)),
                              ),
                              IconButton(
                                onPressed: onRefresh,
                                iconSize: 22,
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Refresh printers',
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          )
                        : _StyledDropdown<String>(
                            value: safeSelected,
                            items: options
                                .map((n) => DropdownMenuItem(
                                      value: n,
                                      child: Text(n,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14)),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) onPickPrinter(v);
                            },
                            theme: theme,
                          );
                final settingsBtn = OutlinedButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Printer settings',
                      style: TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                if (c.maxWidth < 430) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dropdown,
                      const SizedBox(height: 10),
                      settingsBtn,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: dropdown),
                    const SizedBox(width: 10),
                    settingsBtn,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String prefix) {
    if (prefix == 'Receipt') return Icons.receipt_outlined;
    if (prefix == 'Kitchen') return Icons.restaurant_outlined;
    return Icons.print_outlined;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROLE PRINTER TAB  (outer tab body)
// ─────────────────────────────────────────────────────────────────────────────

class _RolePrinterTab extends ConsumerStatefulWidget {
  final String role;
  final String? displayName;
  const _RolePrinterTab({required this.role, this.displayName});

  @override
  ConsumerState<_RolePrinterTab> createState() => _RolePrinterTabState();
}

class _RolePrinterTabState extends ConsumerState<_RolePrinterTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;
  List<Printer> _printers = [];
  bool _loadingPrinters = true;
  bool _testPrinting = false;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
    _loadPrinters();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _loadPrinters() async {
    setState(() => _loadingPrinters = true);
    try {
      final list = await Printing.listPrinters();
      if (mounted) setState(() { _printers = list; _loadingPrinters = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  /// Prints a DEMO receipt with fake data (a 100 demo product, a taxed line, a
  /// demo customer) rendered with THIS printer's current settings — so the
  /// operator sees exactly what their header/footer, paper size, font, tax,
  /// customer-detail and label choices produce, without ringing up a real sale.
  Future<void> _printTestPage() async {
    if (_testPrinting) return;
    final company = ref.read(selectedCompanyProvider);
    if (company == null) {
      showAppSnackbar(context, ref, 'Select a company first', isError: true);
      return;
    }
    setState(() => _testPrinting = true);

    final settings = ref.read(appSettingsProvider);
    final sym = ref.read(currencySymbolProvider);

    // Fake data — a headline 100 item + a taxed second line so tax totals show.
    final demoTax =
        MenuTax(id: -1, name: 'VAT 20%', rate: 20, isFixed: false, isTaxOnTotal: false);
    final demoItems = <CartItem>[
      CartItem(
        cartItemId: 'demo-1',
        posOrderId: 0,
        productId: -1,
        productName: 'Demo Product',
        quantity: 1,
        price: 100,
        appliedTaxes: [demoTax],
        measurementUnit: 'pcs',
      ),
      CartItem(
        cartItemId: 'demo-2',
        posOrderId: 0,
        productId: -2,
        productName: 'Espresso',
        quantity: 2,
        price: 12,
        appliedTaxes: [demoTax],
      ),
    ];
    // Consistent tax-exclusive totals for the summary block.
    const demoSubtotal = 124.0; // 100 + 2×12
    const demoTaxTotal = 24.8; // 20%
    const demoGrand = 148.8;
    final demoCustomer = Customer(
      id: 0,
      name: 'Demo Customer',
      code: 'C-DEMO',
      taxNumber: '00000000',
      phoneNumber: '06 00 00 00 00',
      email: 'demo@shop.com',
      address: '123 Demo Street',
      streetName: '123 Demo Street',
      city: 'Casablanca',
      postalCode: '20000',
    );

    Uint8List? logoBytes;
    final logoB64 = company.logo;
    if (logoB64 != null && logoB64.isNotEmpty) {
      try {
        logoBytes = base64Decode(logoB64);
      } catch (_) {}
    }

    try {
      await ReceiptPrinterService().printCartReceipt(
        company: company,
        cashier: ref.read(currentUserProvider),
        customer: demoCustomer,
        orderNumber: 'DEMO-000100',
        printTime: DateTime.now(),
        items: demoItems,
        subtotal: demoSubtotal,
        totalDiscount: 0,
        totalTax: demoTaxTotal,
        grandTotal: demoGrand,
        currencySymbol: sym,
        paymentTypeName: 'Cash',
        amountPaid: 150,
        logoBytes: logoBytes,
        roleSettings: settings,
        role: widget.role,
      );
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Print failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _testPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Hardware selection card ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _HardwareCard(
            role: widget.role,
            displayName: widget.displayName,
            printers: _printers,
            loadingPrinters: _loadingPrinters,
            testPrinting: _testPrinting,
            onRefresh: _loadPrinters,
            onTestPage: _printers.isEmpty ? null : _printTestPage,
          ),
        ),

        // ── Sub-tab bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
            ),
            child: TabBar(
              controller: _tc,
              indicator: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.hintColor,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'General'),
                Tab(text: 'Cash Drawer'),
                Tab(text: 'Category'),
              ],
            ),
          ),
        ),

        // ── Sub-tab content ──────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: [
              _GeneralSubTab(role: widget.role),
              _CashDrawerSubTab(role: widget.role),
              _CategorySubTab(role: widget.role),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HARDWARE SELECTION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _HardwareCard extends ConsumerWidget {
  final String role;
  final String? displayName;
  final List<Printer> printers;
  final bool loadingPrinters;
  final bool testPrinting;
  final VoidCallback onRefresh;
  final VoidCallback? onTestPage;

  const _HardwareCard({
    required this.role,
    this.displayName,
    required this.printers,
    required this.loadingPrinters,
    required this.testPrinting,
    required this.onRefresh,
    required this.onTestPage,
  });

  String _k(String s) => '$role.$s';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(appSettingsProvider);
    final selectedName = settings[_k('PrinterName')] ?? '';
    final paperSize = settings[_k('PaperSize')] ?? '80mm';

    final printerNames = printers.map((p) => p.name).toList();
    final safeSelected =
        printerNames.contains(selectedName)
            ? selectedName
            : (printerNames.isNotEmpty ? printerNames.first : null);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: isDark
            ? Border.all(color: theme.dividerColor.withValues(alpha: 0.2))
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    role == 'Receipt'
                        ? Icons.receipt_outlined
                        : role == 'Kitchen'
                            ? Icons.restaurant_outlined
                            : Icons.print_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${displayName ?? role} Printer'.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (safeSelected != null)
                      Text(
                        safeSelected,
                        style: TextStyle(fontSize: 11, color: theme.hintColor),
                      ),
                  ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.15)),

          // Dropdowns + test page
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Printer + paper dropdowns (expand)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Printer type
                      Text(
                        'Printer type',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.hintColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (loadingPrinters)
                        const SizedBox(
                          height: 40,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (printers.isEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'No printers found',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.hintColor,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: onRefresh,
                              icon: const Icon(Icons.refresh, size: 18),
                              tooltip: 'Refresh printers',
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        )
                      else
                        _StyledDropdown<String>(
                          value: safeSelected,
                          items: printerNames
                              .map(
                                (n) => DropdownMenuItem(
                                  value: n,
                                  child: Text(
                                    n,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .set(_k('PrinterName'), v);
                            }
                          },
                          theme: theme,
                        ),

                      const SizedBox(height: 12),

                      // Paper size
                      Text(
                        'Paper size',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.hintColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _StyledDropdown<String>(
                        value: _kPaperSizes.contains(paperSize)
                            ? paperSize
                            : _kPaperSizes.first,
                        items: _kPaperSizes
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s, style: const TextStyle(fontSize: 13)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            ref
                                .read(appSettingsProvider.notifier)
                                .set(_k('PaperSize'), v);
                          }
                        },
                        theme: theme,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // Print test page button
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: IconButton(
                        onPressed: onTestPage,
                        icon: testPrinting
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : Icon(
                                Icons.print_outlined,
                                size: 26,
                                color: onTestPage != null
                                    ? theme.colorScheme.primary
                                    : theme.disabledColor,
                              ),
                        tooltip: 'Print demo receipt',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Print demo\nreceipt',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: theme.hintColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GENERAL SUB-TAB
// ─────────────────────────────────────────────────────────────────────────────

class _GeneralSubTab extends StatelessWidget {
  final String role;
  const _GeneralSubTab({required this.role});

  String _k(String s) => '$role.$s';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        // Number of copies
        _PCard(
          title: 'Number of Copies',
          icon: Icons.copy_outlined,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Copies per transaction',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  _NumericStepper(
                    settingKey: _k('Copies'),
                    min: 1,
                    max: 10,
                  ),
                ],
              ),
            ),
          ],
        ),

        // Margins
        _PCard(
          title: 'Margins (in millimeters)',
          icon: Icons.border_all_outlined,
          children: [_MarginsCross(role: role)],
        ),

        // Header
        _PCard(
          title: 'Header',
          icon: Icons.title_outlined,
          children: [
            _PSTextField(
              settingKey: _k('Header'),
              label: 'Header text',
              hint: 'Printed at the top of every receipt',
              maxLines: 3,
            ),
          ],
        ),

        // Footer
        _PCard(
          title: 'Footer',
          icon: Icons.subtitles_outlined,
          children: [
            _PSTextField(
              settingKey: _k('Footer'),
              label: 'Footer text',
              hint: 'e.g. Thank you for shopping with us!',
              maxLines: 3,
            ),
          ],
        ),

        // Options
        _PCard(
          title: 'Options',
          icon: Icons.tune_outlined,
          children: [
            _PSSwitch(
              settingKey: _k('PrintBarcode'),
              label: 'Print barcode',
            ),
            _PSSwitch(
              settingKey: _k('LogoFullWidth'),
              label: 'Print logo full width',
            ),
            _PSSwitch(
              settingKey: _k('RightToLeft'),
              label: 'Right to left',
              subtitle: 'For RTL languages (Arabic, Hebrew)',
            ),
          ],
        ),

        // Font settings
        _PCard(
          title: 'Font Settings',
          icon: Icons.font_download_outlined,
          children: [
            _PSDropdown(
              settingKey: _k('FontFamily'),
              label: 'Font family',
              options: _kFontFamilies,
            ),
            _FontSizeSlider(settingKey: _k('FontSize')),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARGINS CROSS LAYOUT
// ─────────────────────────────────────────────────────────────────────────────

class _MarginsCross extends StatelessWidget {
  final String role;
  const _MarginsCross({required this.role});

  String _k(String s) => '$role.$s';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          // Top
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                child: _MarginField(settingKey: _k('MarginTop'), label: 'Top'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Left — paper icon — Right
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                child: _MarginField(
                  settingKey: _k('MarginLeft'),
                  label: 'Left',
                ),
              ),
              Container(
                width: 60,
                height: 68,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  Icons.print_outlined,
                  size: 26,
                  color: theme.hintColor.withValues(alpha: 0.5),
                ),
              ),
              SizedBox(
                width: 110,
                child: _MarginField(
                  settingKey: _k('MarginRight'),
                  label: 'Right',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Bottom
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                child: _MarginField(
                  settingKey: _k('MarginBottom'),
                  label: 'Bottom',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FONT SIZE SLIDER
// ─────────────────────────────────────────────────────────────────────────────

class _FontSizeSlider extends ConsumerWidget {
  final String settingKey;
  const _FontSizeSlider({required this.settingKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final raw = ref.watch(appSettingsProvider)[settingKey] ??
        kSettingDefaults[settingKey] ??
        '100';
    final value = (double.tryParse(raw) ?? 100.0).clamp(50.0, 150.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Font size',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.hintColor,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${value.round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 50,
            max: 150,
            divisions: 20,
            activeColor: theme.colorScheme.primary,
            inactiveColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            onChanged: (v) => ref
                .read(appSettingsProvider.notifier)
                .set(settingKey, '${v.round()}'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '50%',
                style: TextStyle(fontSize: 10, color: theme.hintColor),
              ),
              Text(
                '100%',
                style: TextStyle(fontSize: 10, color: theme.hintColor),
              ),
              Text(
                '150%',
                style: TextStyle(fontSize: 10, color: theme.hintColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CASH DRAWER SUB-TAB
// ─────────────────────────────────────────────────────────────────────────────

class _CashDrawerSubTab extends ConsumerWidget {
  final String role;
  const _CashDrawerSubTab({required this.role});

  String _k(String s) => '$role.$s';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawerEnabled =
        ref.watch(appSettingsProvider)[_k('CashDrawer.Enabled')]
            ?.toLowerCase() ==
        'true';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        _PCard(
          title: 'Cash Drawer',
          icon: Icons.point_of_sale_outlined,
          children: [
            _PSSwitch(
              settingKey: _k('CashDrawer.Enabled'),
              label: 'Open cash drawer',
              subtitle: 'Sends a signal to the cash drawer after checkout',
            ),
            if (drawerEnabled) ...[
              _PSTextField(
                settingKey: _k('CashDrawer.Command'),
                label: 'Cash drawer command',
                hint: r'\x1B\x70\x00\x19\xFA',
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: _TestDrawerButton(),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY SUB-TAB  (which printer group this printer serves)
// ─────────────────────────────────────────────────────────────────────────────

class _CategorySubTab extends ConsumerWidget {
  final String role;
  const _CategorySubTab({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final groups =
        PrinterGroup.listFromJson(settings[SettingKeys.kitchenPrinterGroups]);
    final selected = settings[SettingKeys.rolePrinterGroupId(role)] ?? '';
    final kitchenOn =
        (settings[SettingKeys.rolePrintKitchenTicket(role)] ?? 'false')
                .toLowerCase() ==
            'true';

    void select(String value) => ref
        .read(appSettingsProvider.notifier)
        .set(SettingKeys.rolePrinterGroupId(role), value);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        _PCard(
          title: 'Kitchen Printing',
          icon: Icons.soup_kitchen_outlined,
          children: [
            _PSSwitch(
              settingKey: SettingKeys.rolePrintKitchenTicket(role),
              label: 'Print kitchen ticket',
              subtitle:
                  'Fire this printer when the Kitchen button is pressed. With '
                  'several enabled, the category below decides what each prints.',
            ),
          ],
        ),
        if (kitchenOn)
          _PCard(
            title: 'Print Category',
            icon: Icons.category_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  'This printer only prints products whose category belongs to '
                  'the selected group (e.g. Barman → drinks). Pick “All '
                  'products” to print the whole ticket here.',
                  style: TextStyle(
                      fontSize: 12.5, color: theme.hintColor, height: 1.5),
                ),
              ),
              _GroupRadioTile(
                title: 'All products',
                subtitle: 'No category filter — prints every item',
                selected: selected.isEmpty,
                onTap: () => select(''),
              ),
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Text(
                    'No printer groups defined yet. Create them in '
                    'Settings → Customer Display → Printer Groups.',
                    style: TextStyle(fontSize: 12.5, color: theme.hintColor),
                  ),
                )
              else
                ...groups.map(
                  (g) => _GroupRadioTile(
                    title: g.name,
                    subtitle:
                        '${g.productGroupIds.length} ${g.productGroupIds.length == 1 ? 'category' : 'categories'}',
                    selected: selected == '${g.id}',
                    onTap: () => select('${g.id}'),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// A radio-style selectable row (custom, so it avoids the deprecated Radio API
/// and gives a large finger-friendly tap target).
class _GroupRadioTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _GroupRadioTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? theme.colorScheme.primary : theme.hintColor,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 12, color: theme.hintColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEST DRAWER BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _TestDrawerButton extends ConsumerStatefulWidget {
  const _TestDrawerButton();

  @override
  ConsumerState<_TestDrawerButton> createState() => _TestDrawerButtonState();
}

class _TestDrawerButtonState extends ConsumerState<_TestDrawerButton> {
  bool _testing = false;

  Future<void> _test() async {
    setState(() => _testing = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _testing = false);
    showAppSnackbar(context, ref, 'Test signal sent to cash drawer');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _testing ? null : _test,
        icon: _testing
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onPrimary,
                ),
              )
            : const Icon(Icons.open_in_browser_outlined, size: 16),
        label: Text(_testing ? 'Sending signal...' : 'Test Drawer Open'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BASE SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _PTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _PCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: isDark ? 0 : 1,
      shadowColor: theme.shadowColor.withValues(alpha: 0.06),
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isDark
            ? BorderSide(color: theme.dividerColor.withValues(alpha: 0.2))
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 9),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.15)),
          ...children,
        ],
      ),
    );
  }
}

// ── Styled dropdown (shared helper, not Riverpod-aware) ───────────────────────

class _StyledDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final ThemeData theme;
  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      dropdownColor: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      isExpanded: true,
    );
  }
}

// ── Text field — auto-saves on focus loss ─────────────────────────────────────

class _PSTextField extends ConsumerStatefulWidget {
  final String settingKey;
  final String label;
  final String? hint;
  final int maxLines;

  const _PSTextField({
    required this.settingKey,
    required this.label,
    this.hint,
    this.maxLines = 1,
  });

  @override
  ConsumerState<_PSTextField> createState() => _PSTextFieldState();
}

class _PSTextFieldState extends ConsumerState<_PSTextField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: ref.read(appSettingsProvider.notifier).get(widget.settingKey),
    );
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(appSettingsProvider.notifier);
    if (_ctrl.text == notifier.get(widget.settingKey)) return;
    setState(() => _saving = true);
    try {
      await notifier.set(widget.settingKey, _ctrl.text);
    } catch (_) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Failed to save ${widget.label}',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.hintColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            maxLines: widget.maxLines,
            keyboardType: widget.maxLines > 1
                ? TextInputType.multiline
                : TextInputType.text,
            textInputAction:
                widget.maxLines > 1 ? null : TextInputAction.done,
            decoration: InputDecoration(
              hintText: widget.hint,
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
              suffixIcon: _saving
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
    );
  }
}

// ── Toggle switch — saves immediately ─────────────────────────────────────────

class _PSSwitch extends ConsumerWidget {
  final String settingKey;
  final String label;
  final String? subtitle;

  const _PSSwitch({
    required this.settingKey,
    required this.label,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final value =
        ref.watch(appSettingsProvider)[settingKey]?.toLowerCase() == 'true';

    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(fontSize: 11, color: theme.hintColor),
            )
          : null,
      value: value,
      activeThumbColor: theme.colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onChanged: (v) =>
          ref.read(appSettingsProvider.notifier).setBool(settingKey, v),
    );
  }
}

// ── Dropdown — saves immediately ──────────────────────────────────────────────

class _PSDropdown extends ConsumerWidget {
  final String settingKey;
  final String label;
  final List<String> options;

  const _PSDropdown({
    required this.settingKey,
    required this.label,
    required this.options,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current =
        ref.watch(appSettingsProvider)[settingKey] ??
        kSettingDefaults[settingKey] ??
        options.first;
    final safeValue = options.contains(current) ? current : options.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.hintColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          _StyledDropdown<String>(
            value: safeValue,
            items: options
                .map(
                  (o) => DropdownMenuItem(
                    value: o,
                    child: Text(o, style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) {
                ref.read(appSettingsProvider.notifier).set(settingKey, v);
              }
            },
            theme: theme,
          ),
        ],
      ),
    );
  }
}

// ── Numeric +/- stepper — saves immediately ───────────────────────────────────

class _NumericStepper extends ConsumerWidget {
  final String settingKey;
  final int min;
  final int max;

  const _NumericStepper({
    required this.settingKey,
    required this.min,
    required this.max,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final raw =
        ref.watch(appSettingsProvider)[settingKey] ??
        kSettingDefaults[settingKey] ??
        '$min';
    final value = (int.tryParse(raw) ?? min).clamp(min, max);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: Icons.remove,
            enabled: value > min,
            onTap: () => ref
                .read(appSettingsProvider.notifier)
                .set(settingKey, '${value - 1}'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          _StepBtn(
            icon: Icons.add,
            enabled: value < max,
            onTap: () => ref
                .read(appSettingsProvider.notifier)
                .set(settingKey, '${value + 1}'),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? theme.colorScheme.primary : theme.disabledColor,
        ),
      ),
    );
  }
}

// ── Margin mm field (digits only, labeled, auto-saves) ────────────────────────

class _MarginField extends ConsumerStatefulWidget {
  final String settingKey;
  final String label;
  const _MarginField({required this.settingKey, required this.label});

  @override
  ConsumerState<_MarginField> createState() => _MarginFieldState();
}

class _MarginFieldState extends ConsumerState<_MarginField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: ref.read(appSettingsProvider.notifier).get(widget.settingKey),
    );
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(appSettingsProvider.notifier);
    if (_ctrl.text == notifier.get(widget.settingKey)) return;
    await notifier.set(widget.settingKey, _ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      textAlign: TextAlign.center,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: 'mm',
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        isDense: true,
      ),
      onSubmitted: (_) => _save(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOMIZE RECEIPT TAB
// ─────────────────────────────────────────────────────────────────────────────

class _CustomizeReceiptTab extends StatelessWidget {
  const _CustomizeReceiptTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        _PCard(
          title: 'Receipt Content',
          icon: Icons.tune_outlined,
          children: [
            const _PSSwitch(
                settingKey: SettingKeys.receiptPrintTaxTotals,
                label: 'Print tax totals'),
            const _PSSwitch(
                settingKey: SettingKeys.receiptPrintTaxName,
                label: 'Print tax name'),
            const _PSSwitch(
                settingKey: SettingKeys.receiptPrintItemsCount,
                label: 'Print items count'),
            const _PSSwitch(
                settingKey: SettingKeys.receiptPrintTotalQuantity,
                label: 'Print total quantity'),
            const _PSSwitch(
                settingKey: SettingKeys.receiptPrintMeasurementUnit,
                label: 'Print measurement unit'),
            const _PSSwitch(
                settingKey: SettingKeys.receiptPrintOrderNumber,
                label: 'Print order number'),
            const _PSSwitch(
                settingKey: SettingKeys.receiptShortNumber,
                label: 'Short receipt number',
                subtitle: 'Print only the trailing counter (e.g. 000008)'),
            const _PSSwitch(
                settingKey: SettingKeys.printLargeOrderNumberInReceipt,
                label: 'Print large order number'),
            const _PSSwitch(
                settingKey: SettingKeys.receiptPrintOutstandingBalance,
                label: 'Print outstanding balance',
                subtitle:
                    'Always shown on credit sales; this forces it even when paid'),
            const _PSSwitch(
                settingKey: SettingKeys.mergeItemsOnReceipt,
                label: 'Merge identical items'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Decimal places',
                        style: TextStyle(
                            fontSize: 14, color: theme.colorScheme.onSurface)),
                  ),
                  const _NumericStepper(
                    settingKey: SettingKeys.receiptDecimalPlaces,
                    min: 0,
                    max: 6,
                  ),
                ],
              ),
            ),
          ],
        ),

        const _PCard(
          title: 'Customer Details',
          icon: Icons.badge_outlined,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Text(
                'Choose what customer details are printed on the receipt.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  SizedBox(
                      width: 150,
                      child: _PSCheck(
                          settingKey: SettingKeys.receiptCustomerName,
                          label: 'Name')),
                  SizedBox(
                      width: 150,
                      child: _PSCheck(
                          settingKey: SettingKeys.receiptCustomerCode,
                          label: 'Code')),
                  SizedBox(
                      width: 150,
                      child: _PSCheck(
                          settingKey: SettingKeys.receiptCustomerTaxNumber,
                          label: 'Tax number')),
                  SizedBox(
                      width: 150,
                      child: _PSCheck(
                          settingKey: SettingKeys.receiptCustomerAddress,
                          label: 'Address')),
                  SizedBox(
                      width: 150,
                      child: _PSCheck(
                          settingKey: SettingKeys.receiptCustomerPhone,
                          label: 'Phone number')),
                  SizedBox(
                      width: 150,
                      child: _PSCheck(
                          settingKey: SettingKeys.receiptCustomerEmail,
                          label: 'Email')),
                ],
              ),
            ),
          ],
        ),

        const _PCard(
          title: 'Address Format',
          icon: Icons.location_on_outlined,
          children: [_AddressFormatEditor()],
        ),
      ],
    );
  }
}

// ── Checkbox tile — saves immediately ─────────────────────────────────────────

class _PSCheck extends ConsumerWidget {
  final String settingKey;
  final String label;
  const _PSCheck({required this.settingKey, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value =
        ref.watch(appSettingsProvider)[settingKey]?.toLowerCase() == 'true';
    return InkWell(
      onTap: () =>
          ref.read(appSettingsProvider.notifier).setBool(settingKey, !value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => ref
                .read(appSettingsProvider.notifier)
                .setBool(settingKey, v ?? false),
          ),
          Flexible(
            child: Text(label,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── Address format editor: multi-line template + insertable placeholder chips ─

class _AddressFormatEditor extends ConsumerStatefulWidget {
  const _AddressFormatEditor();

  @override
  ConsumerState<_AddressFormatEditor> createState() =>
      _AddressFormatEditorState();
}

class _AddressFormatEditorState extends ConsumerState<_AddressFormatEditor> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  static const _tokens = [
    '%STREET_NAME%',
    '%ADDITIONAL_STREET_NAME%',
    '%BUILDING_NUMBER%',
    '%PLOT_IDENTIFICATION%',
    '%CITY_SUBDIVISION%',
    '%CITY%',
    '%POSTAL_CODE%',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text:
          ref.read(appSettingsProvider.notifier).get(SettingKeys.receiptAddressFormat),
    );
    _focus = FocusNode()
      ..addListener(() {
        if (!_focus.hasFocus) _save();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = ref.read(appSettingsProvider.notifier);
    if (_ctrl.text == n.get(SettingKeys.receiptAddressFormat)) return;
    await n.set(SettingKeys.receiptAddressFormat, _ctrl.text);
  }

  void _insert(String token) {
    final sel = _ctrl.selection;
    final text = _ctrl.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final newText = text.replaceRange(start, end, token);
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Specify how address lines are printed on receipts and invoices.',
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap a placeholder to insert it:',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.hintColor),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in _tokens)
                ActionChip(
                  label: Text(t, style: const TextStyle(fontSize: 11)),
                  onPressed: () => _insert(t),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCALIZE TEXT TAB
// ─────────────────────────────────────────────────────────────────────────────

class _LocalizeTextTab extends ConsumerWidget {
  const _LocalizeTextTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCustom = ref.watch(appSettingsProvider)[
                SettingKeys.receiptUseCustomLabels]
            ?.toLowerCase() !=
        'false';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        const _PCard(
          title: 'Custom Labels',
          icon: Icons.translate_rounded,
          children: [
            _PSSwitch(
              settingKey: SettingKeys.receiptUseCustomLabels,
              label: 'Use custom labels in reports and invoices',
              subtitle: 'Turn off to fall back to the built-in wording',
            ),
          ],
        ),
        if (useCustom) ...[
          const _PCard(
            title: 'Receipt Labels',
            icon: Icons.label_outline,
            children: [
              _PSTextField(
                  settingKey: SettingKeys.labelCompanyTaxNumber,
                  label: 'Company tax number'),
              _PSTextField(
                  settingKey: SettingKeys.labelReceiptNumber,
                  label: 'Receipt number'),
              _PSTextField(
                  settingKey: SettingKeys.labelOrderNumber, label: 'Order number'),
              _PSTextField(settingKey: SettingKeys.labelUser, label: 'User'),
              _PSTextField(
                  settingKey: SettingKeys.labelItemsCount, label: 'Items count'),
              _PSTextField(
                  settingKey: SettingKeys.labelDiscount, label: 'Discount'),
              _PSTextField(
                  settingKey: SettingKeys.labelSubtotal, label: 'Subtotal'),
              _PSTextField(settingKey: SettingKeys.labelTaxRate, label: 'Tax'),
              _PSTextField(settingKey: SettingKeys.labelTotal, label: 'Total'),
              _PSTextField(
                  settingKey: SettingKeys.labelPaidAmount, label: 'Paid amount'),
              _PSTextField(
                  settingKey: SettingKeys.labelAmountDue, label: 'Amount due'),
              _PSTextField(settingKey: SettingKeys.labelChange, label: 'Change'),
              _PSTextField(
                  settingKey: SettingKeys.labelOutstandingBalance,
                  label: 'Outstanding balance'),
            ],
          ),
          const _PCard(
            title: 'Customer Detail Labels',
            icon: Icons.badge_outlined,
            children: [
              _PSTextField(
                  settingKey: SettingKeys.labelCustomer, label: 'Customer'),
              _PSTextField(
                  settingKey: SettingKeys.labelCustomerAddress, label: 'Address'),
              _PSTextField(
                  settingKey: SettingKeys.labelCustomerCode, label: 'Code'),
              _PSTextField(
                  settingKey: SettingKeys.labelCustomerPhone,
                  label: 'Phone number'),
              _PSTextField(
                  settingKey: SettingKeys.labelCustomerEmail, label: 'Email'),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRINT TEMPLATES TAB  (invoice / A4 documents)
// ─────────────────────────────────────────────────────────────────────────────

class _PrintTemplatesTab extends StatelessWidget {
  const _PrintTemplatesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: const [
        _PCard(
          title: 'Font',
          icon: Icons.font_download_outlined,
          children: [
            _PSDropdown(
              settingKey: SettingKeys.invoiceFontFamily,
              label: 'Invoice font',
              options: _kFontFamilies,
            ),
          ],
        ),
        _PCard(
          title: 'Invoice Settings',
          icon: Icons.article_outlined,
          children: [
            _PSTextField(
                settingKey: SettingKeys.invoiceTitle,
                label: 'Title',
                hint: 'e.g. TAX INVOICE'),
            _PSSwitch(
                settingKey: SettingKeys.invoicePrintA5, label: 'Print in A5 size'),
          ],
        ),
        _PCard(
          title: 'Columns',
          icon: Icons.view_column_outlined,
          children: [
            _PSSwitch(settingKey: SettingKeys.invoiceColumnTax, label: 'Tax column'),
            _PSSwitch(
                settingKey: SettingKeys.invoiceColumnDiscount,
                label: 'Discount column'),
          ],
        ),
        _PCard(
          title: 'Other Settings',
          icon: Icons.tune_outlined,
          children: [
            _PSSwitch(
                settingKey: SettingKeys.invoiceShowPaymentMethods,
                label: 'Payment methods'),
            _PSSwitch(
                settingKey: SettingKeys.invoiceShowOutstandingBalance,
                label: 'Outstanding balance'),
          ],
        ),
        _PCard(
          title: 'Header & Footer',
          icon: Icons.notes_outlined,
          children: [
            _PSTextField(
                settingKey: SettingKeys.invoiceGlobalHeader,
                label: 'Global header',
                hint: 'Printed above the invoice',
                maxLines: 3),
            _PSTextField(
                settingKey: SettingKeys.invoiceGlobalFooter,
                label: 'Global footer',
                hint: 'e.g. bank details, terms',
                maxLines: 3),
          ],
        ),
      ],
    );
  }
}
