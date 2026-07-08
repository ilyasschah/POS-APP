import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
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

class PrinterSettingsScreen extends ConsumerWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(rawAppPropertiesProvider).isLoading;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Printer Settings',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
          actions: [
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
              color: theme.colorScheme.surface,
              child: TabBar(
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.hintColor,
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 3,
                dividerColor: theme.dividerColor.withValues(alpha: 0.3),
                tabs: const [
                  _PTab(icon: Icons.receipt_outlined, label: 'Receipt Printer'),
                  _PTab(
                    icon: Icons.restaurant_outlined,
                    label: 'Kitchen Printer',
                  ),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            _RolePrinterTab(role: 'Receipt'),
            _RolePrinterTab(role: 'Kitchen'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROLE PRINTER TAB  (outer tab body)
// ─────────────────────────────────────────────────────────────────────────────

class _RolePrinterTab extends ConsumerStatefulWidget {
  final String role;
  const _RolePrinterTab({required this.role});

  @override
  ConsumerState<_RolePrinterTab> createState() => _RolePrinterTabState();
}

class _RolePrinterTabState extends ConsumerState<_RolePrinterTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;
  List<Printer> _printers = [];
  bool _loadingPrinters = true;
  bool _testPrinting = false;

  String _k(String suffix) => '${widget.role}.$suffix';

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
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

  Future<void> _printTestPage() async {
    if (_testPrinting || _printers.isEmpty) return;
    setState(() => _testPrinting = true);

    final settings = ref.read(appSettingsProvider);
    final printerName = settings[_k('PrinterName')] ?? '';
    final paperSize = settings[_k('PaperSize')] ?? '80mm';

    Printer? target;
    if (printerName.isNotEmpty) {
      target = _printers.cast<Printer?>().firstWhere(
        (p) => p!.name == printerName,
        orElse: () => null,
      );
    }
    target ??= _printers.cast<Printer?>().firstWhere(
      (p) => p!.isDefault,
      orElse: () => _printers.isNotEmpty ? _printers.first : null,
    );

    if (target == null) {
      if (mounted) setState(() => _testPrinting = false);
      return;
    }
    final resolvedPrinter = target;

    try {
      final doc = pw.Document();
      final mmW = paperSize == '58mm' ? 58.0 : 80.0;
      final format = PdfPageFormat(
        mmW * PdfPageFormat.mm,
        double.infinity,
        marginAll: 5 * PdfPageFormat.mm,
      );
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Center(
                child: pw.Text(
                  '** TEST PAGE **',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  '${widget.role} Printer',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  resolvedPrinter.name,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Printer is working correctly!',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Divider(),
            ],
          ),
        ),
      );
      await Printing.directPrintPdf(
        printer: resolvedPrinter,
        onLayout: (_) async => doc.save(),
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
  final List<Printer> printers;
  final bool loadingPrinters;
  final bool testPrinting;
  final VoidCallback onRefresh;
  final VoidCallback? onTestPage;

  const _HardwareCard({
    required this.role,
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
                        : Icons.restaurant_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$role Printer'.toUpperCase(),
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
                        tooltip: 'Print test page',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Print test\npage',
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
        padding: const EdgeInsets.all(9),
        child: Icon(
          icon,
          size: 18,
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
