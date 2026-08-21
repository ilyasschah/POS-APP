// lib/app_settings_model.dart

import 'package:pos_app/core/config.dart';
import 'package:pos_app/database/app_database.dart';

class AppProperty {
  final int id;
  final String name;
  final String value;
  final String? companyName;

  AppProperty({
    required this.id,
    required this.name,
    required this.value,
    this.companyName,
  });

  factory AppProperty.fromJson(Map<String, dynamic> json) {
    return AppProperty(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      value: json['value'] ?? '',
      companyName: json['companyName'],
    );
  }

  /// Reconstruct from a Drift row. `companyName` is null offline — that
  /// field was a server-side join projection and isn't stored in
  /// AppPropertiesTable. Nothing in the settings codebase reads it.
  factory AppProperty.fromDrift(AppPropertiesTableData row) {
    return AppProperty(id: row.id, name: row.name, value: row.value ?? '');
  }
}

class SettingKeys {
  // General
  static const currencySymbol = 'CurrencySymbol';
  static const language = 'Application.Language';
  static const timezone = 'Application.Timezone';
  static const timezoneMode = 'Application.TimezoneMode';
  static const dateFormat = 'Application.DateFormat';
  static const taxIncludedByDefault = 'General.TaxIncludedByDefault';

  /// Comma-separated tax-rate IDs auto-applied to a product when it is added to
  /// the cart without its own tax assignments. Empty = no default tax.
  ///
  /// Lives under `General` because it is the companion of
  /// [taxIncludedByDefault] — the switch is meaningless without it, so the two
  /// are configured side by side in Settings → General → Tax. It was
  /// [legacyDefaultTaxRateIds] until 2026-08-15; see that field for the
  /// migration.
  static const defaultTaxRateIds = 'General.DefaultTaxRateIds';

  /// Pre-2026-08-15 home of [defaultTaxRateIds], back when the picker sat in
  /// the Products tab. Never written any more — only read, once, to carry an
  /// existing configuration over to the new key. Two things perform that
  /// migration, deliberately:
  ///   • `AppSettingsNotifier.build()` aliases it at READ time, so a till that
  ///     is offline (or never syncs again) keeps its default tax immediately;
  ///   • `SyncManager._migrateRenamedSettingKeys` persists it under the new key
  ///     on the next AppProperties pull, which is what eventually makes the
  ///     alias moot.
  /// The legacy row itself is left in place — harmless, and deleting it would
  /// make the migration irreversible if we ever need to roll back.
  static const legacyDefaultTaxRateIds = 'Products.DefaultTaxRateIds';

  // Order & Payment
  static const defaultPaymentType = 'Order.DefaultPaymentType';
  static const allowNegativeStock = 'Order.AllowNegativeStock';
  static const allowPriceChange = 'Order.AllowPriceChange';
  static const roundingMode = 'Order.RoundingMode';
  static const receiptFooter = 'Order.ReceiptFooter';
  static const orderPrefix = 'Order.NumberPrefix';

  // Products
  static const showProductImages = 'Products.ShowImages';
  static const defaultMeasurementUnit = 'Products.DefaultMeasurementUnit';
  static const barcodeFormat = 'Products.BarcodeFormat';
  static const displayAndPrintTaxIncluded =
      'Products.DisplayAndPrintTaxIncluded';
  static const discountApplyRule = 'Products.DiscountApplyRule';
  static const productSorting = 'Products.Sorting';
  static const allowNegativePrice = 'Products.AllowNegativePrice';
  static const costPriceBasedMarkup = 'Products.CostPriceBasedMarkup';
  static const autoUpdateCostPrice = 'Products.AutoUpdateCostPrice';
  static const updateSalePriceOnMarkup = 'Products.UpdateSalePriceOnMarkup';
  static const enableMovingAveragePrice = 'Products.EnableMovingAveragePrice';

  // Documents
  static const defaultDocumentType = 'Documents.DefaultDocumentType';
  static const invoicePrefix = 'Documents.InvoicePrefix';
  static const autoGenerateNumber = 'Documents.AutoGenerateNumber';

  // Customer Display
  static const customerDisplayEnabled = 'CustomerDisplay.Enabled';
  static const customerDisplayWebEnabled = 'CustomerDisplay.WebEnabled';
  static const customerDisplayPort = 'CustomerDisplay.Port';
  static const customerDisplayBaudRate = 'CustomerDisplay.BaudRate';
  static const customerDisplayDataBits = 'CustomerDisplay.DataBits';
  static const customerDisplayParity = 'CustomerDisplay.Parity';
  static const customerDisplayStopBits = 'CustomerDisplay.StopBits';
  static const customerDisplayFlowControl = 'CustomerDisplay.FlowControl';
  static const customerDisplayNumChars = 'CustomerDisplay.NumChars';
  static const customerDisplayWelcomeMessage =
      'CustomerDisplay.WelcomeMessage'; // top line
  static const customerDisplayWelcomeBottom = 'CustomerDisplay.WelcomeBottom';
  // Configurable message shown on the checkout-success screen (rich display).
  // Empty falls back to the localized "Thank you" string.
  static const customerDisplayThankYouMessage =
      'CustomerDisplay.ThankYouMessage';

  // Email
  static const emailSmtpHost = 'Email.SmtpHost';
  static const emailSmtpPort = 'Email.SmtpPort';
  static const emailFromAddress = 'Email.FromAddress';
  static const emailFromName = 'Email.FromName';
  static const emailUserEmail = 'Application.User.Email';

  // Print
  static const printerName = 'Print.PrinterName';
  static const printCopies = 'Print.Copies';
  static const autoprint = 'Print.AutoPrint';
  static const paperSize = 'Print.PaperSize';

  // App updates (Windows only). Device-scoped — see device_scoped_settings.dart.
  static const autoCheckUpdates = 'App.Update.AutoCheck';

  // Dual Currency
  static const dualCurrencyEnabled = 'DualCurrency.Enabled';
  static const dualCurrencySymbol = 'DualCurrency.Symbol';
  static const dualCurrencyRate = 'DualCurrency.ExchangeRate';

  // Database
  static const dbBackupVersion = 'Database.Backup.Version';
  static const dbBackupPath = 'Database.BackupPath';
  static const dbAutoBackup = 'Database.AutoBackup';

  // ── POS session ───────────────────────────────────────────────────────────
  /// Master switch for "no sale without an open session".
  ///
  /// 🚨 This is the recovery path, not a preference. The gate stops a till
  /// selling, so if session state is ever wrong on a real register the shop
  /// must have a way back — turning this off in Settings restores trading
  /// immediately. Without it a bad session row could close a shop for the day.
  static const requireOpenSession = 'PosSession.RequireOpenSession';

  /// Cash difference a cashier may close through without a manager.
  static const maxCashDifference = 'PosSession.MaxCashDifference';

  /// Authoritative list of PaymentType ids that come out of the cash drawer.
  static const cashPaymentTypeIds = 'PosSession.CashPaymentTypeIds';
  static const dbBackupOnStart = 'Database.Backup.OnStart';
  static const dbBackupOnClose = 'Database.Backup.OnClose';
  static const dbBackupIntervalHours = 'Database.Backup.IntervalHours';
  static const dbBackupAutoDelete = 'Database.Backup.AutoDelete';
  static const dbBackupRetentionDays = 'Database.Backup.RetentionDays';

  // API
  static const apiBaseUrl = 'Application.Api.BaseUrl';

  // Weighing Scale – Serial connection
  static const scaleEnabled = 'Scale.Enabled';
  static const scalePort = 'Scale.Port';
  static const scaleBaudRate = 'Scale.BaudRate';

  // Weighing Scale – Barcode parsing
  static const scaleBarcodeEnabled = 'Scale.Barcode.Enabled';
  static const scaleBarcodePrefix = 'Scale.Barcode.Prefix';
  static const scaleBarcodeCodeLength = 'Scale.Barcode.CodeLength';
  static const scaleBarcodeDecimalPlaces = 'Scale.Barcode.DecimalPlaces';
  static const scaleBarcodeTrimZeros = 'Scale.Barcode.TrimZeros';
  static const scaleBarcodePrintsPrice = 'Scale.Barcode.PrintsPrice';

  // Appearance
  static const themeMode = 'Theme_Mode';
  static const themeAccentColor = 'Theme_AccentColor';

  // Menu Grid
  // 'List' = continuous vertical scroll (Columns only, no pagination).
  // 'Grid' = paged Columns × Rows with a first/prev/next/last bar.
  static const menuLayoutMode = 'Menu_Layout_Mode';
  static const menuGridCols = 'Menu_Grid_Cols';
  static const menuGridRows = 'Menu_Grid_Rows';

  // Features
  static const featureFloorPlanEnabled = 'Feature_FloorPlan_Enabled';
  static const featureBookingEnabled = 'Feature_Booking_Enabled';
  static const tablesButtonLabel = 'Feature.TablesButtonLabel';
  // Both only bite while the floor plan is enabled; with it off, orders are
  // table-less and booking-free anyway.
  static const allowTablelessOrders = 'Order.AllowTablelessOrders';
  static const allowWalkInTableOrders = 'Order.AllowWalkInTableOrders';
  static const requireReasonOnVoid = 'Void.RequireReason';
  static const trackUnconfirmedVoidedItems = 'Void.TrackUnconfirmed';

  // Service type / status toggles. (The old industry "packs" that supplied
  // canned order types per business vertical were dropped — the custom
  // service type/status lists below replaced them entirely.)
  static const featureServiceTypeEnabled = 'Feature_ServiceType_Enabled';
  static const featureServiceStatusEnabled = 'Feature_ServiceStatus_Enabled';

  // Custom service types (JSON array of {id, name, prefix})
  static const customServiceTypes = 'Pos.CustomServiceTypes';

  // Custom service statuses (JSON array of {id, name, colorValue})
  static const customServiceStatuses = 'Pos.CustomServiceStatuses';

  // Booking behaviour (JSON object — see BookingSettingsModel)
  static const bookingSettings = 'Pos.BookingSettings';

  // ── Printer Hardware ─────────────────────────────────────────────────────
  static const printerType = 'Print.PrinterType';
  static const printMarginTop = 'Print.Margin.Top';
  static const printMarginBottom = 'Print.Margin.Bottom';
  static const printMarginLeft = 'Print.Margin.Left';
  static const printMarginRight = 'Print.Margin.Right';
  static const cashDrawerEnabled = 'Print.CashDrawer.Enabled';
  static const cashDrawerCommand = 'Print.CashDrawer.Command';
  static const printBarcode = 'Print.Branding.PrintBarcode';
  static const printLogoFullWidth = 'Print.Branding.LogoFullWidth';
  // When true, completing a sale also fires the station kitchen tickets (the same
  // routing the menu Kitchen button uses). DEVICE-SCOPED — stored in local
  // SharedPreferences per terminal, never cloud-synced (see device_scoped_settings).
  static const autoKitchenPrintOnCheckout = 'Print.AutoKitchenOnCheckout';

  // ── Receipt Toggles ──────────────────────────────────────────────────────
  static const receiptPrintTaxTotals = 'Receipt.PrintTaxTotals';
  static const receiptPrintTaxName = 'Receipt.PrintTaxName';
  static const receiptPrintItemsCount = 'Receipt.PrintItemsCount';
  static const receiptPrintTotalQuantity = 'Receipt.PrintTotalQuantity';
  static const receiptPrintMeasurementUnit = 'Receipt.PrintMeasurementUnit';
  static const receiptPrintOrderNumber = 'Receipt.PrintOrderNumber';
  static const receiptPrintOutstandingBalance =
      'Receipt.PrintOutstandingBalance';
  static const receiptDecimalPlaces = 'Receipt.DecimalPlaces';
  // When true the receipt/order number prints only its trailing counter segment
  // (e.g. "000008") instead of the full "POS1-200-000008".
  static const receiptShortNumber = 'Receipt.ShortReceiptNumber';

  // ── Receipt Customer Details ─────────────────────────────────────────────
  static const receiptCustomerName = 'Receipt.Customer.PrintName';
  static const receiptCustomerTaxNumber = 'Receipt.Customer.PrintTaxNumber';
  static const receiptCustomerPhone = 'Receipt.Customer.PrintPhone';
  static const receiptCustomerCode = 'Receipt.Customer.PrintCode';
  static const receiptCustomerAddress = 'Receipt.Customer.PrintAddress';
  static const receiptCustomerEmail = 'Receipt.Customer.PrintEmail';
  static const receiptAddressFormat = 'Receipt.Customer.AddressFormat';

  // ── Receipt Company Header (printed under the logo / business name) ───────
  static const receiptShowCompanyTaxNumber = 'Receipt.Company.PrintTaxNumber';
  static const receiptShowCompanyAddress = 'Receipt.Company.PrintAddress';
  static const receiptShowCompanyPhone = 'Receipt.Company.PrintPhone';

  // ── Receipt Labels (Localize Text) ───────────────────────────────────────
  // Master switch: when false, printed receipts ignore the custom labels below
  // and use the built-in defaults.
  static const receiptUseCustomLabels = 'Receipt.Label.UseCustom';
  static const labelCompanyTaxNumber = 'Receipt.Label.CompanyTaxNumber';
  static const labelCompanyPhone = 'Receipt.Label.CompanyPhone';
  static const labelReceiptNumber = 'Receipt.Label.ReceiptNumber';
  static const labelOrderNumber = 'Receipt.Label.OrderNumber';
  static const labelUser = 'Receipt.Label.User';
  static const labelItemsCount = 'Receipt.Label.ItemsCount';
  static const labelDiscount = 'Receipt.Label.Discount';
  static const labelSubtotal = 'Receipt.Label.Subtotal';
  static const labelTaxRate = 'Receipt.Label.TaxRate';
  static const labelTotal = 'Receipt.Label.Total';
  static const labelPaidAmount = 'Receipt.Label.PaidAmount';
  static const labelAmountDue = 'Receipt.Label.AmountDue';
  static const labelChange = 'Receipt.Label.Change';
  static const labelOutstandingBalance = 'Receipt.Label.OutstandingBalance';
  // Customer-block label overrides.
  static const labelCustomer = 'Receipt.Label.Customer';
  static const labelCustomerCode = 'Receipt.Label.CustomerCode';
  static const labelCustomerPhone = 'Receipt.Label.CustomerPhone';
  static const labelCustomerEmail = 'Receipt.Label.CustomerEmail';
  static const labelCustomerAddress = 'Receipt.Label.CustomerAddress';

  // ── Invoice / Templates ──────────────────────────────────────────────────
  static const invoiceTitle = 'Invoice.Title';
  static const invoicePrintA5 = 'Invoice.PrintA5';
  static const invoiceColumnTax = 'Invoice.Columns.Tax';
  static const invoiceColumnDiscount = 'Invoice.Columns.Discount';
  static const invoiceGlobalHeader = 'Invoice.GlobalHeader';
  static const invoiceGlobalFooter = 'Invoice.GlobalFooter';
  static const invoiceFontFamily = 'Invoice.FontFamily';
  static const invoiceRightToLeft = 'Invoice.RightToLeft';
  static const invoiceShowPaymentMethods = 'Invoice.ShowPaymentMethods';
  static const invoiceShowOutstandingBalance = 'Invoice.ShowOutstandingBalance';

  // ── Printers (Printer selection tab) ──────────────────────────────────────
  // JSON array of user-defined printers: [{prefix,name,enabled,builtin,groupId}].
  static const printersList = 'Printers.List';

  // ── Printer Role Settings ────────────────────────────────────────────────
  // Keys are dynamically prefixed: 'Receipt.<suffix>' or 'Kitchen.<suffix>'
  static String rolePrinterName(String role) => '$role.PrinterName';
  static String rolePaperSize(String role) => '$role.PaperSize';
  static String roleCopies(String role) => '$role.Copies';
  static String roleMarginTop(String role) => '$role.MarginTop';
  static String roleMarginBottom(String role) => '$role.MarginBottom';
  static String roleMarginLeft(String role) => '$role.MarginLeft';
  static String roleMarginRight(String role) => '$role.MarginRight';
  static String roleHeader(String role) => '$role.Header';
  static String roleFooter(String role) => '$role.Footer';
  static String rolePrintBarcode(String role) => '$role.PrintBarcode';
  static String roleLogoFullWidth(String role) => '$role.LogoFullWidth';
  static String roleRightToLeft(String role) => '$role.RightToLeft';
  static String roleFontFamily(String role) => '$role.FontFamily';
  static String roleFontSize(String role) => '$role.FontSize';
  static String roleCashDrawerEnabled(String role) =>
      '$role.CashDrawer.Enabled';
  static String roleCashDrawerCommand(String role) =>
      '$role.CashDrawer.Command';
  // The printer group (station) this printer prints. Empty = all products.
  // Resolved against [kitchenPrinterGroups]. Stored per-printer (offline-first).
  static String rolePrinterGroupId(String role) => '$role.PrinterGroupId';
  // When true, this printer is fired by the menu "Kitchen" button and receives
  // a kitchen ticket of its category's items. Default false.
  static String rolePrintKitchenTicket(String role) =>
      '$role.PrintKitchenTicket';

  // Application Style
  static const writingDirection = 'App.WritingDirection';
  static const enableVirtualKeyboard = 'App.EnableVirtualKeyboard';

  // Messages
  static const messageDuration = 'App.MessageDuration';
  static const messagePosition = 'App.MessagePosition';

  // Business Day
  static const showCashInOnStart = 'App.ShowCashInOnStart';
  static const selectBusinessDayOnStart = 'App.SelectBusinessDayOnStart';

  // Default landing screen — 'POS' | 'Tables' | 'Booking'. Drives the boot
  // landing tab and the post-checkout return tab. Options are gated on the
  // floor-plan / booking feature flags so we never route to a disabled screen.
  static const defaultScreen = 'App.DefaultScreen';

  // Auto-sync — background push+pull behaviour.
  static const autoSyncEnabled = 'App.AutoSync.Enabled';
  // 'After every save' | 'Every 1 hour'
  static const autoSyncMode = 'App.AutoSync.Mode';
  static const autoSyncShowNotification = 'App.AutoSync.ShowNotification';

  // Basic Operations
  static const useFloorPlans = 'Order.UseFloorPlans';

  // Items
  static const defaultSearch = 'Menu.DefaultSearch';
  static const showSearchOptions = 'Menu.ShowSearchOptions';
  static const defaultDiscountType = 'Order.DefaultDiscountType';
  static const separateRowForEachItem = 'Order.SeparateRowForEachItem';
  static const preventSaleBelowCostPrice = 'Order.PreventSaleBelowCostPrice';
  static const preventNegativeInventory = 'Order.PreventNegativeInventory';

  // Users
  static const singleUser = 'App.SingleUser';

  // Payment (extended)
  static const displayReceiptPrintDialog = 'Order.DisplayReceiptPrintDialog';
  static const defaultDueDateDays = 'Order.DefaultDueDateDays';
  static const mergeItemsOnReceipt = 'Receipt.MergeItems';
  static const singleItemDiscountAllowed = 'Order.SingleItemDiscountAllowed';

  // Order Name

  // Service Type (extended)
  static const enableServiceTypeSelection =
      'Feature.ServiceType.SelectionEnabled';
  static const requestServiceTypeAutomatically =
      'Feature.ServiceType.RequestAutomatically';
  static const defaultServiceType = 'Feature.ServiceType.Default';
  static const printLargeOrderNumberInReceipt = 'Receipt.PrintLargeOrderNumber';

  // Advanced Settings
  static const resetOrderNumberOnDayClose = 'Order.ResetNumberOnDayClose';
  static const showItemsOnPaymentForm = 'Order.ShowItemsOnPaymentForm';
  static const numberOfPaymentTypeRows = 'Order.NumberOfPaymentTypeRows';
  static const showAllOccupiedTablesInFloorPlan =
      'Feature.FloorPlan.ShowAllOccupied';
  // Warehouse used by default for POS stock checks / sourcing. Stored as the
  // warehouse id (string). Empty → fall back to the first warehouse.
  static const defaultWarehouseId = 'Order.DefaultWarehouseId';

  // Kitchen Display
  static const kitchenDisplayIps = 'Kitchen.DisplayIps';
  // JSON array of printer/display groups: [{id,name,productGroupIds:[...]}].
  // Each group maps a set of product categories to a kitchen/bar station.
  static const kitchenPrinterGroups = 'Kitchen.PrinterGroups';
  // JSON object { "<ip>": [groupId,...] } — which printer groups each paired
  // display receives. An IP with no entry receives ALL items (single-station).
  static const kitchenDisplayGroups = 'Kitchen.DisplayGroups';

  // Button Bar
  static const showSearchBtn = 'ButtonBar.ShowSearch';
  static const showTransferBtn = 'ButtonBar.ShowTransfer';
  static const showCustomerBtn = 'ButtonBar.ShowCustomer';
  static const showDiscountBtn = 'ButtonBar.ShowDiscount';
  static const showCommentBtn = 'ButtonBar.ShowComment';
  static const showRefundBtn = 'ButtonBar.ShowRefund';
  static const showCashDrawerBtn = 'ButtonBar.ShowCashDrawer';
  static const showWarehouseBtn = 'ButtonBar.ShowWarehouse';
  static const showBookingBtn = 'ButtonBar.ShowBooking';
  static const showTablesBtn = 'ButtonBar.ShowTables';
  static const showKitchenBtn = 'ButtonBar.ShowKitchen';
  /// Pre-bill ("Addition") button — prints the guest check the customer settles
  /// against. Nothing is banked, so it is separate from the Pay button.
  static const showAdditionBtn = 'ButtonBar.ShowAddition';
  static const showTaxBtn = 'ButtonBar.ShowTax';
  static const showQuantityBtn = 'ButtonBar.ShowQuantity';

  // Loyalty
  static const loyaltyEnabled = 'Loyalty.Enabled';
  static const loyaltyMinAmount = 'Loyalty.MinAmount';
  static const loyaltyPointsPerThreshold = 'Loyalty.PointsPerThreshold';
  static const loyaltyPointValue = 'Loyalty.PointValue';
}

/// Parses the comma-separated [SettingKeys.defaultTaxRateIds] payload into
/// concrete tax-rate IDs.
///
/// Lives here rather than in any one consumer because four places must agree
/// on what "a default tax is configured" means: the Settings picker, the gate
/// on the tax-inclusive switch, the product editor's pre-fill, and the cart's
/// auto-apply. Tolerant of blanks and junk — a malformed entry is skipped, not
/// thrown on, so a hand-edited property row can never brick the till.
Set<int> parseDefaultTaxRateIds(String? raw) => (raw ?? '')
    .split(',')
    .map((e) => int.tryParse(e.trim()))
    .whereType<int>()
    .toSet();

const Map<String, String> kSettingDefaults = {
  SettingKeys.currencySymbol: '\$',
  SettingKeys.language: 'en',
  // 'Etc/UTC', not 'UTC': the IANA database has no plain 'UTC' location key, and
  // the timezone picker asserts on a value it can't find among its items.
  SettingKeys.timezone: 'Etc/UTC',
  SettingKeys.timezoneMode: 'Auto',
  SettingKeys.dateFormat: 'dd-MM-yyyy',
  SettingKeys.taxIncludedByDefault: 'true',
  SettingKeys.defaultTaxRateIds: '',
  SettingKeys.defaultPaymentType: 'Cash',
  SettingKeys.allowNegativeStock: 'false',
  SettingKeys.allowPriceChange: 'true',
  SettingKeys.roundingMode: '2',
  SettingKeys.receiptFooter: 'Thank you for your purchase!',
  SettingKeys.orderPrefix: 'ORD',
  SettingKeys.showProductImages: 'true',
  SettingKeys.defaultMeasurementUnit: 'pcs',
  SettingKeys.barcodeFormat: 'EAN-13',
  SettingKeys.displayAndPrintTaxIncluded: 'true',
  SettingKeys.discountApplyRule: 'After tax',
  SettingKeys.productSorting: 'Name',
  SettingKeys.allowNegativePrice: 'true',
  SettingKeys.costPriceBasedMarkup: 'false',
  SettingKeys.autoUpdateCostPrice: 'true',
  SettingKeys.updateSalePriceOnMarkup: 'false',
  SettingKeys.enableMovingAveragePrice: 'false',
  SettingKeys.defaultDocumentType: 'Sales',
  SettingKeys.invoicePrefix: 'INV',
  SettingKeys.autoGenerateNumber: 'true',
  SettingKeys.customerDisplayEnabled: 'false',
  SettingKeys.customerDisplayWebEnabled: 'false',
  SettingKeys.customerDisplayPort: 'COM1',
  SettingKeys.customerDisplayBaudRate: '9600',
  SettingKeys.customerDisplayDataBits: '8',
  SettingKeys.customerDisplayParity: 'None',
  SettingKeys.customerDisplayStopBits: '1',
  SettingKeys.customerDisplayFlowControl: 'None',
  SettingKeys.customerDisplayNumChars: '20',
  SettingKeys.customerDisplayWelcomeMessage: 'WELCOME!',
  SettingKeys.customerDisplayWelcomeBottom: '',
  SettingKeys.customerDisplayThankYouMessage: '',
  SettingKeys.emailSmtpHost: '',
  SettingKeys.emailSmtpPort: '587',
  SettingKeys.emailFromAddress: '',
  SettingKeys.emailFromName: 'POS System',
  SettingKeys.emailUserEmail: '',
  SettingKeys.printerName: '',
  SettingKeys.printCopies: '1',
  SettingKeys.autoprint: 'false',
  SettingKeys.paperSize: '80mm',
  // On by default: a till running an old build is a support problem nobody
  // reports. The operator can still turn it off per terminal.
  SettingKeys.autoCheckUpdates: 'true',
  SettingKeys.dualCurrencyEnabled: 'false',
  SettingKeys.dualCurrencySymbol: '€',
  SettingKeys.dualCurrencyRate: '1.0',
  SettingKeys.dbBackupVersion: 'v2',
  SettingKeys.dbBackupPath: '',
  SettingKeys.dbAutoBackup: 'false',
  SettingKeys.requireOpenSession: 'true',
  SettingKeys.maxCashDifference: '10',
  SettingKeys.cashPaymentTypeIds: '',
  SettingKeys.dbBackupOnStart: 'false',
  SettingKeys.dbBackupOnClose: 'false',
  SettingKeys.dbBackupIntervalHours: '0',
  SettingKeys.dbBackupAutoDelete: 'false',
  SettingKeys.dbBackupRetentionDays: '10',
  // Single source of truth — see AppConfig. Spelling the URL out again here is
  // what let the Settings field advertise one endpoint while the app actually
  // dialled another.
  SettingKeys.apiBaseUrl: AppConfig.defaultApiBaseUrl,
  SettingKeys.scaleEnabled: 'false',
  SettingKeys.scalePort: 'COM2',
  SettingKeys.scaleBaudRate: '9600',
  SettingKeys.scaleBarcodeEnabled: 'false',
  SettingKeys.scaleBarcodePrefix: '',
  SettingKeys.scaleBarcodeCodeLength: '5',
  SettingKeys.scaleBarcodeDecimalPlaces: '3',
  SettingKeys.scaleBarcodeTrimZeros: 'true',
  SettingKeys.scaleBarcodePrintsPrice: 'false',
  SettingKeys.themeMode: 'dark',
  SettingKeys.themeAccentColor: '#FF5733',
  SettingKeys.menuLayoutMode: 'List',
  SettingKeys.menuGridCols: '4',
  SettingKeys.menuGridRows: '4',
  SettingKeys.featureFloorPlanEnabled: 'true',
  SettingKeys.featureBookingEnabled: 'true',
  SettingKeys.tablesButtonLabel: 'Tables',
  // Defaults preserve the pre-existing behaviour exactly: a Dine-in order still
  // requires a table, and an empty table can still be rung up without a booking.
  SettingKeys.allowTablelessOrders: 'false',
  SettingKeys.allowWalkInTableOrders: 'true',
  SettingKeys.requireReasonOnVoid: 'false',
  SettingKeys.trackUnconfirmedVoidedItems: 'true',
  SettingKeys.featureServiceTypeEnabled: 'true',
  SettingKeys.featureServiceStatusEnabled: 'true',
  SettingKeys.customServiceTypes:
      '[{"id":0,"name":"Dine-In","prefix":"ORDER"},'
      '{"id":1,"name":"Takeaway","prefix":"TAKEAWAY"},'
      '{"id":2,"name":"Delivery","prefix":"DELIVERY"}]',
  SettingKeys.customServiceStatuses:
      '[{"id":1,"name":"Seated","colorValue":${0xFF2196F3}},'
      '{"id":2,"name":"In Kitchen","colorValue":${0xFFFF9800}},'
      '{"id":3,"name":"Ready to Pay","colorValue":${0xFF4CAF50}}]',
  SettingKeys.bookingSettings:
      '{"resourceMode":"table","defaultDurationMinutes":90,"timeSnappingMinutes":15}',

  // Printer Hardware
  SettingKeys.printerType: 'Windows Printer',
  SettingKeys.printMarginTop: '5',
  SettingKeys.printMarginBottom: '5',
  SettingKeys.printMarginLeft: '5',
  SettingKeys.printMarginRight: '5',
  SettingKeys.cashDrawerEnabled: 'false',
  SettingKeys.cashDrawerCommand: r'\x1B\x70\x00\x19\xFA',
  SettingKeys.printBarcode: 'false',
  SettingKeys.printLogoFullWidth: 'false',
  SettingKeys.autoKitchenPrintOnCheckout: 'false',

  // Receipt Toggles
  SettingKeys.receiptPrintTaxTotals: 'true',
  SettingKeys.receiptPrintTaxName: 'true',
  SettingKeys.receiptPrintItemsCount: 'true',
  SettingKeys.receiptPrintTotalQuantity: 'true',
  SettingKeys.receiptPrintMeasurementUnit: 'false',
  SettingKeys.receiptPrintOrderNumber: 'true',
  SettingKeys.receiptPrintOutstandingBalance: 'false',
  SettingKeys.receiptDecimalPlaces: '2',
  SettingKeys.receiptShortNumber: 'false',

  // Receipt Customer Details
  SettingKeys.receiptCustomerName: 'true',
  SettingKeys.receiptCustomerTaxNumber: 'false',
  SettingKeys.receiptCustomerPhone: 'false',
  SettingKeys.receiptCustomerCode: 'false',
  SettingKeys.receiptCustomerAddress: 'false',
  SettingKeys.receiptCustomerEmail: 'false',
  SettingKeys.receiptAddressFormat:
      '%STREET_NAME% %BUILDING_NUMBER%\n%CITY%, %POSTAL_CODE%',

  // Receipt Company Header (default ON — preserves existing receipts)
  SettingKeys.receiptShowCompanyTaxNumber: 'true',
  SettingKeys.receiptShowCompanyAddress: 'true',
  SettingKeys.receiptShowCompanyPhone: 'true',

  // Receipt Labels
  SettingKeys.receiptUseCustomLabels: 'true',
  SettingKeys.labelCompanyTaxNumber: 'Tax Number',
  SettingKeys.labelCompanyPhone: 'Tel',
  SettingKeys.labelReceiptNumber: 'Receipt No.',
  SettingKeys.labelOrderNumber: 'Order No.',
  SettingKeys.labelUser: 'Cashier',
  SettingKeys.labelItemsCount: 'Items',
  SettingKeys.labelDiscount: 'Discount',
  SettingKeys.labelSubtotal: 'Subtotal',
  SettingKeys.labelTaxRate: 'Tax',
  SettingKeys.labelTotal: 'Total',
  SettingKeys.labelPaidAmount: 'Paid',
  SettingKeys.labelAmountDue: 'Amount Due',
  SettingKeys.labelChange: 'Change',
  SettingKeys.labelOutstandingBalance: 'Balance Due',
  SettingKeys.labelCustomer: 'Customer',
  SettingKeys.labelCustomerCode: 'Code',
  SettingKeys.labelCustomerPhone: 'Phone',
  SettingKeys.labelCustomerEmail: 'Email',
  SettingKeys.labelCustomerAddress: 'Address',

  // Invoice / Templates
  SettingKeys.invoiceTitle: 'TAX INVOICE',
  SettingKeys.invoicePrintA5: 'false',
  SettingKeys.invoiceRightToLeft: 'false',
  SettingKeys.invoiceColumnTax: 'true',
  SettingKeys.invoiceColumnDiscount: 'false',
  SettingKeys.invoiceGlobalHeader: '',
  SettingKeys.invoiceGlobalFooter: '',
  SettingKeys.invoiceFontFamily: '(None)',
  SettingKeys.invoiceShowPaymentMethods: 'true',
  SettingKeys.invoiceShowOutstandingBalance: 'true',

  // Printers
  SettingKeys.printersList: '',

  // Printer Role — Receipt
  'Receipt.PrinterName': '',
  'Receipt.PaperSize': '80mm',
  'Receipt.Copies': '1',
  'Receipt.MarginTop': '0',
  'Receipt.MarginBottom': '0',
  'Receipt.MarginLeft': '0',
  'Receipt.MarginRight': '0',
  'Receipt.Header': '',
  'Receipt.Footer': '',
  'Receipt.PrintBarcode': 'false',
  'Receipt.LogoFullWidth': 'false',
  'Receipt.RightToLeft': 'false',
  'Receipt.FontFamily': '(None)',
  'Receipt.FontSize': '100',
  'Receipt.CashDrawer.Enabled': 'false',
  'Receipt.CashDrawer.Command': r'\x1B\x70\x00\x19\xFA',

  // Basic Operations
  SettingKeys.useFloorPlans: 'true',

  // Items
  SettingKeys.defaultSearch: 'Name',
  SettingKeys.showSearchOptions: 'true',
  SettingKeys.defaultDiscountType: 'Percentage',
  SettingKeys.separateRowForEachItem: 'false',
  SettingKeys.preventSaleBelowCostPrice: 'true',
  SettingKeys.preventNegativeInventory: 'false',

  // Users
  SettingKeys.singleUser: 'true',

  // Payment (extended)
  SettingKeys.displayReceiptPrintDialog: 'false',
  SettingKeys.defaultDueDateDays: '0',
  SettingKeys.mergeItemsOnReceipt: 'true',
  SettingKeys.singleItemDiscountAllowed: 'true',

  // Order Name

  // Service Type (extended)
  SettingKeys.enableServiceTypeSelection: 'true',
  SettingKeys.requestServiceTypeAutomatically: 'true',
  SettingKeys.defaultServiceType: 'Dine-in',
  SettingKeys.printLargeOrderNumberInReceipt: 'false',

  // Advanced Settings
  SettingKeys.resetOrderNumberOnDayClose: 'false',
  SettingKeys.showItemsOnPaymentForm: 'true',
  SettingKeys.numberOfPaymentTypeRows: '0',
  SettingKeys.showAllOccupiedTablesInFloorPlan: 'true',
  SettingKeys.defaultWarehouseId: '',

  // Kitchen Display
  SettingKeys.kitchenDisplayIps: '',
  SettingKeys.kitchenPrinterGroups: '',
  SettingKeys.kitchenDisplayGroups: '',

  // Application Style
  SettingKeys.writingDirection: 'LTR',
  SettingKeys.enableVirtualKeyboard: 'false',

  // Messages
  SettingKeys.messageDuration: '3',
  SettingKeys.messagePosition: 'Bottom',

  // Business Day
  SettingKeys.showCashInOnStart: 'true',
  SettingKeys.selectBusinessDayOnStart: 'false',
  SettingKeys.defaultScreen: 'POS',
  SettingKeys.autoSyncEnabled: 'true',
  SettingKeys.autoSyncMode: 'After every save',
  SettingKeys.autoSyncShowNotification: 'false',

  // Button Bar
  SettingKeys.showSearchBtn: 'true',
  SettingKeys.showTransferBtn: 'true',
  SettingKeys.showCustomerBtn: 'true',
  SettingKeys.showDiscountBtn: 'true',
  SettingKeys.showCommentBtn: 'true',
  SettingKeys.showRefundBtn: 'true',
  SettingKeys.showCashDrawerBtn: 'true',
  SettingKeys.showWarehouseBtn: 'true',
  SettingKeys.showBookingBtn: 'true',
  SettingKeys.showTablesBtn: 'true',
  SettingKeys.showKitchenBtn: 'true',
  SettingKeys.showAdditionBtn: 'true',
  SettingKeys.showTaxBtn: 'true',
  SettingKeys.showQuantityBtn: 'true',

  // Printer Role — Kitchen
  'Kitchen.PrinterName': '',
  'Kitchen.PaperSize': '80mm',
  'Kitchen.Copies': '1',
  'Kitchen.MarginTop': '0',
  'Kitchen.MarginBottom': '0',
  'Kitchen.MarginLeft': '0',
  'Kitchen.MarginRight': '0',
  'Kitchen.Header': '',
  'Kitchen.Footer': '',
  'Kitchen.PrintBarcode': 'false',
  'Kitchen.LogoFullWidth': 'false',
  'Kitchen.RightToLeft': 'false',
  'Kitchen.FontFamily': '(None)',
  'Kitchen.FontSize': '100',
  'Kitchen.CashDrawer.Enabled': 'false',
  'Kitchen.CashDrawer.Command': r'\x1B\x70\x00\x19\xFA',

  SettingKeys.loyaltyEnabled: 'false',
  SettingKeys.loyaltyMinAmount: '100',
  SettingKeys.loyaltyPointsPerThreshold: '10',
  SettingKeys.loyaltyPointValue: '1.0',
};
