// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get setSerialPort => 'Serial port';

  @override
  String get setDisplayCharset => 'Display character set';

  @override
  String get setDisplayCharsetHint =>
      'What the display\'s firmware can render — this is about the hardware, not the app\'s language. Try Arabic (Windows-1256) first; only pick the reversed one if the display shows Arabic words backwards.';

  @override
  String get charsetAscii => 'Plain (accents simplified)';

  @override
  String get charsetLatin1 => 'Western European (accents kept)';

  @override
  String get charsetArabic => 'Arabic (Windows-1256)';

  @override
  String get charsetArabicVisual =>
      'Arabic, reversed (only if words come out backwards)';

  @override
  String get printerConnection => 'Connection';

  @override
  String get printerConnectionSystem => 'This computer (Windows printer)';

  @override
  String get printerConnectionSystemUnavailable =>
      'This device (opens the print dialog)';

  @override
  String get printerConnectionNetwork => 'Network printer (Wi-Fi / LAN)';

  @override
  String get printerConnectionHint =>
      'A network printer prints silently on tablets as well as on this computer.';

  @override
  String get printerConnectionHintMobile =>
      'This device cannot print silently to a system printer — it can only open the print dialog. Choose Network printer and enter its address.';

  @override
  String get printerHost => 'Printer address';

  @override
  String get printerTcpPort => 'Port';

  @override
  String get poleDisplayTotalDue => 'TOTAL DUE';

  @override
  String get poleDisplayWelcome => 'WELCOME!';

  @override
  String get portNoneDetected => 'None detected';

  @override
  String get portNoneDetectedHint =>
      'This machine reports no COM or LPT port. Check the cable and Device Manager, then reopen this screen.';

  @override
  String portNotDetected(String port) {
    return '$port (not detected)';
  }

  @override
  String get portRefresh => 'Refresh ports';

  @override
  String get registerChoose => 'Choose register';

  @override
  String get registerSubtitle =>
      'The till this device is working. Devices on the same register share its open session, its documents and its drawer.';

  @override
  String get registerThisDeviceOnly => 'This device only';

  @override
  String get registerThisDeviceOnlyHint =>
      'Its own session, shared with nothing else.';

  @override
  String get registerTrading => 'Session open now';

  @override
  String get registerIdle => 'No open session';

  @override
  String get registerNew => 'New register';

  @override
  String get registerNameHint => 'e.g. Front Till';

  @override
  String get registerListOffline =>
      'Registers could not be loaded. Choosing a shared register needs a connection.';

  @override
  String get registerSwitchBlocked =>
      'Close this register\'s session before switching. Moving now would leave it open with no way back to it from here.';

  @override
  String get setRegister => 'Register';

  @override
  String get sessionJoinRegister => 'Sell in this session';

  @override
  String get sessionJoinTitle => 'Work this register?';

  @override
  String sessionJoinBody(String register, String session) {
    return 'This device will start working $register. Sales you ring go into session $session, alongside every other terminal on it — and any of them can close it.';
  }

  @override
  String get sessionJoinBlocked =>
      'This device already has its own session open. Close it before working another register, or it stays open with nothing able to reach it.';

  @override
  String get sessionJoinNoRegister =>
      'This session has not finished syncing, so the register it belongs to is not known here yet. Sync and try again.';

  @override
  String get sessionJoinOpenElsewhere =>
      'Another register already has a session open. Sell in that one instead of starting a second.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionSaveChanges => 'Save Changes';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionClose => 'Close';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionUpload => 'Upload';

  @override
  String get actionSkip => 'Skip';

  @override
  String get deviceRegistrationTitle => 'Device Registration';

  @override
  String get deviceRegistrationSubtitle =>
      'Sign in with your account to link this terminal';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password';

  @override
  String get developerMode => 'Developer mode';

  @override
  String get unlinkDeviceConfirm =>
      'Are you sure you want to unlink this device?';

  @override
  String get unlinkDevice => 'Unlink Device';

  @override
  String get timeClock => 'TIME CLOCK';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleCashier => 'Cashier';

  @override
  String get reloadUsers => 'Reload users';

  @override
  String get relinkDevice => 'Re-link device';

  @override
  String get couldNotLoadUsers => 'Couldn\'t load users on this terminal.';

  @override
  String get noUsersCached => 'No users cached on this terminal.';

  @override
  String get restoringUsersFromServer => 'Restoring users from the server…';

  @override
  String get reconnectToRestoreUsers =>
      'Reconnect to restore them, or re-link this device to sign in again.';

  @override
  String get actionYes => 'Yes';

  @override
  String get actionNo => 'No';

  @override
  String get actionApply => 'Apply';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionSet => 'Set';

  @override
  String get actionSwitch => 'Switch';

  @override
  String get actionProceedAnyway => 'Proceed Anyway';

  @override
  String deleteProductsConfirm(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count products? This cannot be undone.',
      one: 'Delete 1 product? This cannot be undone.',
    );
    return '$_temp0';
  }

  @override
  String get colorMarkerHint =>
      'Tints the product tile in the POS menu and the products list.';

  @override
  String get modifiersHint =>
      'Add specific notes like \'Extra Spicy\' or \'Contains Nuts\'.';

  @override
  String get barcodesHint =>
      'Assign multiple barcodes (e.g., individual item, box, or pallet).';

  @override
  String get importComplete => 'Import complete';

  @override
  String get documentCreated => 'Document created: ';

  @override
  String importErrorCount(num count) {
    return '$count error(s):';
  }

  @override
  String get importTitle => 'Import';

  @override
  String get selectFile => 'Select file';

  @override
  String get indicatesRequiredField => '* Indicates required field';

  @override
  String get skipColumn => '(Skip)';

  @override
  String get duplicatesQuestion => 'What happens if duplicates are found?';

  @override
  String get createDocumentFromQuantity =>
      'Create document from specified quantity';

  @override
  String get actionPreview => 'Preview';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldProductGroup => 'Product group';

  @override
  String get fieldSku => 'SKU';

  @override
  String get fieldMeasurementUnit => 'Measurement unit';

  @override
  String get fieldCost => 'Cost';

  @override
  String get fieldMarkup => 'Markup';

  @override
  String get fieldTax => 'Tax';

  @override
  String get fieldTaxInclusivePrice => 'Tax inclusive price';

  @override
  String get fieldPriceChangeAllowed => 'Price change allowed';

  @override
  String get fieldUsingDefaultQuantity => 'Using default quantity';

  @override
  String get fieldServiceNotStock => 'Service (not using stock)';

  @override
  String get fieldEnabled => 'Enabled';

  @override
  String get fieldDescription => 'Description';

  @override
  String get fieldQuantity => 'Quantity';

  @override
  String get fieldSupplier => 'Supplier';

  @override
  String get fieldReorderPoint => 'Reorder point';

  @override
  String get fieldPreferredQuantity => 'Preferred quantity';

  @override
  String get fieldLowStockWarning => 'Low stock warning';

  @override
  String get fieldLowStockWarningQuantity => 'Low stock warning quantity';

  @override
  String get cannotDelete => 'Cannot Delete';

  @override
  String get deleteGroup => 'Delete Group';

  @override
  String deleteGroupConfirm(String name) {
    return 'Are you sure you want to delete \'$name\'?';
  }

  @override
  String get productGroups => 'Product Groups';

  @override
  String get newGroup => 'New Group';

  @override
  String get deleteGroupTooltip => 'Delete group';

  @override
  String get failedToLoadGroups => 'Failed to load groups';

  @override
  String get noneRoot => 'None (Root)';

  @override
  String get chooseImage => 'Choose Image';

  @override
  String get searchProductsEllipsis => 'Search products…';

  @override
  String get failedToLoadProducts => 'Failed to load products';

  @override
  String get noProductsFoundShort => 'No products found';

  @override
  String get noProductGroupsYet => 'No product groups yet';

  @override
  String get createOneToOrganize => 'Create one to organize your products';

  @override
  String get createGroup => 'Create Group';

  @override
  String get customersLabel => 'Customers';

  @override
  String get customerLabel => 'Customer';

  @override
  String get languageLabel => 'Language';

  @override
  String get categoriesLabel => 'Categories';

  @override
  String get errorLabel => 'Error';

  @override
  String get accountUserEmail => 'Account / User Email';

  @override
  String get dateFormatLabel => 'Date Format';

  @override
  String get accessLevel => 'Access Level';

  @override
  String get actions => 'Actions';

  @override
  String get addFirstUser => 'Add First User';

  @override
  String get addNewUser => 'Add New User';

  @override
  String get addPayment => 'Add Payment';

  @override
  String get addUser => 'Add User';

  @override
  String get adminResetDevicePin => 'Admin: Reset Device PIN';

  @override
  String get adminResetPassword => 'Admin: Reset Password';

  @override
  String get filterAll => 'All';

  @override
  String get allCustomers => 'All customers';

  @override
  String get allDocumentTypes => 'All document types';

  @override
  String get allTransactions => 'All transactions';

  @override
  String get allUsers => 'All users';

  @override
  String get allWarehouses => 'All warehouses';

  @override
  String get amount => 'Amount';

  @override
  String get assignToWarehouse => 'Assign to Warehouse';

  @override
  String get couldNotLoadRules => 'Could not load rules';

  @override
  String get colCreated => 'CREATED';

  @override
  String get colCustomer => 'CUSTOMER';

  @override
  String get dateLabel => 'Date';

  @override
  String get deleteDocument => 'Delete Document';

  @override
  String get deleteRule => 'Delete Rule';

  @override
  String get deleteUser => 'Delete User';

  @override
  String get colDisc => 'DISC';

  @override
  String get discountBreakdown => 'Discount Breakdown';

  @override
  String get documentExplorer => 'Document Explorer';

  @override
  String get editRules => 'Edit Rules';

  @override
  String get editUser => 'Edit User';

  @override
  String get errorLoadingTaxes => 'Error loading taxes';

  @override
  String get excel => 'Excel';

  @override
  String get expirationDate => 'Expiration Date';

  @override
  String get expirationDateOptional => 'Expiration Date (optional)';

  @override
  String get firstName => 'First Name';

  @override
  String get firstNameRequired => 'First Name *';

  @override
  String get fixed => 'Fixed';

  @override
  String get idLabel => 'ID';

  @override
  String get initialQuantity => 'Initial Quantity';

  @override
  String get internalNote => 'INTERNAL NOTE';

  @override
  String get inventoryMasterList => 'Inventory Master List';

  @override
  String get itemDiscount => 'Item Discount';

  @override
  String get lastName => 'Last Name';

  @override
  String get lastNameRequired => 'Last Name *';

  @override
  String get lowStock => 'Low Stock';

  @override
  String get lowStockWarning => 'Low Stock Warning';

  @override
  String get manageWarehouses => 'Manage Warehouses';

  @override
  String get markAsUnpaid => 'Mark as Unpaid?';

  @override
  String get needsReorder => 'Needs Reorder';

  @override
  String get colNew => 'NEW';

  @override
  String get newFourDigitPin => 'New 4-Digit PIN';

  @override
  String get newPassword => 'New Password';

  @override
  String get newQuantity => 'New Quantity';

  @override
  String get noSecurityRules => 'No security rules found.';

  @override
  String get securityRulesIntro =>
      'Choose who may use each part of the POS. Cashier means everyone may; Admin means only an administrator — a cashier who tries is told to ask you.';

  @override
  String securityRulesSummary(int total, int adminOnly) {
    return '$total rules · $adminOnly admin-only';
  }

  @override
  String securityCategoryCount(int count, int restricted) {
    return '$count · $restricted admin-only';
  }

  @override
  String get securityLevelCashierHint => 'Cashiers and admins may do this';

  @override
  String get securityLevelAdminHint => 'Only an administrator may do this';

  @override
  String get noTaxShort => 'No tax';

  @override
  String get noneLabel => 'None';

  @override
  String get noteLabel => 'Note';

  @override
  String get colNumber => 'NUMBER';

  @override
  String get colOrderNo => 'ORDER #';

  @override
  String get paid => 'Paid';

  @override
  String get partial => 'Partial';

  @override
  String get passwordRequired => 'Password *';

  @override
  String get paymentType => 'Payment Type';

  @override
  String get preferredQuantity => 'Preferred Quantity';

  @override
  String get priceAfterTax => 'Price (after tax)';

  @override
  String get priceBeforeTax => 'Price before tax';

  @override
  String get printStockReportPdf => 'Print Stock Report (PDF)';

  @override
  String get productLabel => 'Product';

  @override
  String get productRequired => 'Product *';

  @override
  String get referenceDocument => 'Reference Document';

  @override
  String get removeStock => 'Remove Stock';

  @override
  String get reorderPoint => 'Reorder Point';

  @override
  String get reports => 'Reports';

  @override
  String get ruleExistsEditing => 'Rule exists — editing';

  @override
  String get saveStockReportPdf => 'Save Stock Report as PDF';

  @override
  String get searchProductNameOrCode => 'Search product name or code…';

  @override
  String get searchReports => 'Search reports';

  @override
  String get securityActions => 'Security Actions';

  @override
  String get selectDocumentType => 'Select document type';

  @override
  String get selectReport => 'Select report';

  @override
  String get showReport => 'Show report';

  @override
  String get colStatus => 'STATUS';

  @override
  String get colSvc => 'SVC';

  @override
  String get syncAndRefresh => 'Sync & Refresh';

  @override
  String get tabNotFound => 'Tab not found';

  @override
  String get taxOptional => 'Tax (optional)';

  @override
  String get taxAmount => 'Tax amount';

  @override
  String get totalDiscounts => 'Total discounts';

  @override
  String get typeLabel => 'Type';

  @override
  String get unpaid => 'Unpaid';

  @override
  String get updateItem => 'Update Item';

  @override
  String get colUpdated => 'UPDATED';

  @override
  String get colUser => 'USER';

  @override
  String get userRequired => 'User *';

  @override
  String get username => 'Username';

  @override
  String get usernameRequired => 'Username *';

  @override
  String get usersAndSecurity => 'Users & Security';

  @override
  String get valueTotal => 'Value (Total)';

  @override
  String get warehouse => 'Warehouse';

  @override
  String get warehouseRequired => 'Warehouse *';

  @override
  String get warningThreshold => 'Warning Threshold';

  @override
  String get yesDeletePayments => 'Yes, delete payments';

  @override
  String errorLoadingDocuments(String message) {
    return 'Error loading documents: $message';
  }

  @override
  String errorLoadingSecurityRules(String message) {
    return 'Error loading security rules: $message';
  }

  @override
  String errorLoadingUsers(String message) {
    return 'Error loading users: $message';
  }

  @override
  String saveFailed(String message) {
    return 'Save failed: $message';
  }

  @override
  String savedToPath(String path) {
    return 'Saved to $path';
  }

  @override
  String get addBooking => 'Add Booking';

  @override
  String get addCard => 'Add Card';

  @override
  String get addFirstTaxRate => 'Add First Tax Rate';

  @override
  String get addFirstWarehouse => 'Add First Warehouse';

  @override
  String get addLoyaltyCard => 'Add Loyalty Card';

  @override
  String get addPromotion => 'Add Promotion';

  @override
  String get addTable => 'Add Table';

  @override
  String get addTimeCard => 'Add Time Card';

  @override
  String get addWarehouse => 'Add Warehouse';

  @override
  String get addResizeRenameTables => 'Add, resize, and rename tables';

  @override
  String get allEmployees => 'All employees ...';

  @override
  String get applyName => 'Apply name';

  @override
  String get endShiftConfirm => 'Are you sure you want to end your shift?';

  @override
  String get back => 'Back';

  @override
  String get bookingAlerts => 'Booking Alerts';

  @override
  String get bookingSaved => 'Booking Saved!';

  @override
  String get cardNumber => 'Card Number';

  @override
  String get shapeCircle => 'Circle';

  @override
  String get clockIn => 'Clock in';

  @override
  String get clockOut => 'Clock out';

  @override
  String get confirmDelete => 'Confirm Delete';

  @override
  String get couldNotLoadEmployees => 'Could not load employees';

  @override
  String get created => 'Created';

  @override
  String get currencies => 'Currencies';

  @override
  String get customerRequired => 'Customer *';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get days => 'Days';

  @override
  String get deleteBooking => 'Delete Booking';

  @override
  String get deleteLoyaltyCard => 'Delete Loyalty Card';

  @override
  String get deleteTax => 'Delete Tax';

  @override
  String get deleteWarehouse => 'Delete Warehouse';

  @override
  String get documentItemsColumns => 'Document items columns';

  @override
  String get documentType => 'Document type';

  @override
  String get documents => 'Documents';

  @override
  String get documentsColumns => 'Documents columns';

  @override
  String get hintTwentyPercent => 'e.g. 20 for 20%';

  @override
  String get hintSecondFloor => 'E.g., Second Floor';

  @override
  String get earningRule => 'Earning Rule';

  @override
  String get editFloorPlan => 'Edit Floor Plan';

  @override
  String get employee => 'Employee';

  @override
  String get enableLoyaltyPoints => 'Enable Loyalty Points';

  @override
  String get endDate => 'End Date';

  @override
  String get endOfDay => 'End of Day';

  @override
  String get endShift => 'End Shift';

  @override
  String get endTime => 'End Time';

  @override
  String get colExport => 'EXPORT';

  @override
  String get externalRef => 'External ref';

  @override
  String get floorPlan => 'Floor Plan';

  @override
  String get gotIt => 'Got it';

  @override
  String get guestNameRequired => 'Guest Name *';

  @override
  String get guests => 'Guests';

  @override
  String get leaveBlankAutoAssign => 'Leave blank to auto-assign';

  @override
  String get logout => 'Logout';

  @override
  String get loyaltyCards => 'Loyalty Cards';

  @override
  String get loyaltySettings => 'Loyalty Settings';

  @override
  String get minPurchaseAmount => 'Min. purchase amount';

  @override
  String get moveStock => 'Move stock';

  @override
  String get moveStockTo => 'Move stock to…';

  @override
  String get myCompany => 'My Company';

  @override
  String get nameRequired => 'Name *';

  @override
  String get newFloor => 'New Floor';

  @override
  String get newFloorPlan => 'New Floor Plan';

  @override
  String get newTax => 'New Tax';

  @override
  String get newTaxRate => 'New Tax Rate';

  @override
  String get nextDay => 'Next day';

  @override
  String get noWarehousesFound => 'No warehouses found.';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get numberLabel => 'Number';

  @override
  String get oldTax => 'Old Tax';

  @override
  String get openDocument => 'Open Document';

  @override
  String get openOrder => 'Open Order';

  @override
  String get openOrders => 'Open Orders';

  @override
  String get openService => 'Open Service';

  @override
  String get openedAt => 'Opened at';

  @override
  String get orderNoLabel => 'Order #';

  @override
  String get pageLabel => 'Page:';

  @override
  String get paymentLabel => 'Payment';

  @override
  String get paymentTypesShort => 'Payment Types';

  @override
  String get pendingLower => 'pending';

  @override
  String get points => 'Points';

  @override
  String get pointsEarned => 'Points earned';

  @override
  String get posLabel => 'POS';

  @override
  String get previousDay => 'Previous day';

  @override
  String get priceLabel => 'Price';

  @override
  String get promotions => 'Promotions';

  @override
  String get rateRequired => 'Rate *';

  @override
  String get redemptionRule => 'Redemption Rule';

  @override
  String get refresh => 'Refresh';

  @override
  String get removeFloor => 'Remove Floor';

  @override
  String get removeFloorPlan => 'Remove Floor Plan';

  @override
  String get removeTable => 'Remove Table';

  @override
  String get rename => 'Rename';

  @override
  String get replace => 'Replace';

  @override
  String get revokeStock => 'Revoke stock';

  @override
  String get rowsPerPage => 'Rows per page:';

  @override
  String get sales => 'Sales';

  @override
  String get saveUpper => 'SAVE';

  @override
  String get searchCustomer => 'Search customer...';

  @override
  String get searchDocument => 'Search document...';

  @override
  String get selectEmployee => 'Select employee';

  @override
  String get selectTablesRequired => 'Select Tables *';

  @override
  String get settings => 'Settings';

  @override
  String get shiftManagement => 'Shift Management';

  @override
  String get showGrid => 'Show grid';

  @override
  String get showQr => 'Show QR';

  @override
  String get snapToGrid => 'Snap to grid';

  @override
  String get shapeSquare => 'Square';

  @override
  String get startDate => 'Start Date';

  @override
  String get startService => 'Start Service';

  @override
  String get startShift => 'Start Shift';

  @override
  String get startTime => 'Start Time';

  @override
  String get startingPoints => 'Starting Points';

  @override
  String get statusLabel => 'Status';

  @override
  String get stayOnCalendar => 'Stay on Calendar';

  @override
  String get stock => 'Stock';

  @override
  String get switchTaxes => 'Switch Taxes';

  @override
  String get taxRates => 'Tax Rates';

  @override
  String get totalBeforeDiscount => 'Total bef. discount';

  @override
  String get totalBeforeTax => 'Total before tax';

  @override
  String get unitOfMeasure => 'Unit of measure';

  @override
  String get userLabel => 'User';

  @override
  String get users => 'Users';

  @override
  String get warehouseHasStock => 'Warehouse has stock';

  @override
  String get warehouseNameRequired => 'Warehouse Name *';

  @override
  String get warehouses => 'Warehouses';

  @override
  String get whichTableForOrder =>
      'Which table should this order be placed on?';

  @override
  String errorLoadingLoyaltyCards(String message) {
    return 'Error loading loyalty cards: $message';
  }

  @override
  String errorLoadingWarehouses(String message) {
    return 'Error loading warehouses: $message';
  }

  @override
  String get colActions => 'ACTIONS';

  @override
  String get addCash => 'Add cash';

  @override
  String get addItem => 'Add Item';

  @override
  String get addProductLower => 'Add product';

  @override
  String get addPromotionItem => 'Add Promotion Item';

  @override
  String get addReturnedProducts => 'Add the products being returned';

  @override
  String get addTimeCardUpper => 'ADD TIME CARD';

  @override
  String get allWarehousesCap => 'All Warehouses';

  @override
  String get appliesTo => 'Applies To';

  @override
  String get deleteVoidReasonConfirm =>
      'Are you sure you want to delete this void reason?';

  @override
  String get authorise => 'Authorise';

  @override
  String get bookingHistory => 'Booking History';

  @override
  String get cancelEdit => 'Cancel Edit';

  @override
  String get cashIn => 'Cash In';

  @override
  String get cashInOut => 'Cash In / Out';

  @override
  String get cashMovement => 'Cash Movement';

  @override
  String get cashOut => 'Cash Out';

  @override
  String get changePassword => 'Change Password';

  @override
  String get clearAll => 'Clear all';

  @override
  String get closeRegister => 'Close Register';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get country => 'Country';

  @override
  String get createUser => 'Create User';

  @override
  String get creditPayments => 'Credit payments';

  @override
  String get currencyCodeRequired => 'Currency Code (e.g. USD) *';

  @override
  String get currencyNameRequired => 'Currency Name (e.g. US Dollar) *';

  @override
  String get customersSuppliers => 'Customers & Suppliers';

  @override
  String get colDate => 'DATE';

  @override
  String get deleteCurrency => 'Delete Currency';

  @override
  String get deleteVoidReason => 'Delete Void Reason';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get discountType => 'Discount Type';

  @override
  String get discountValue => 'Discount Value';

  @override
  String get hintWifiBill => 'e.g. wifi bill, pre started';

  @override
  String get cashReasonHint =>
      'Enter the reason for adding or removing cash...';

  @override
  String get errorLoadingTables => 'Error loading tables';

  @override
  String get exitApplication => 'Exit application';

  @override
  String get failedToLoadOrders => 'Failed to load orders';

  @override
  String get feedback => 'Feedback';

  @override
  String get financialInfo => 'Financial Info';

  @override
  String get fixedAmount => 'Fixed Amount';

  @override
  String get fullScreen => 'Full Screen';

  @override
  String get generalInfo => 'General Info';

  @override
  String get globalCurrencies => 'Global Currencies';

  @override
  String get gridView => 'Grid';

  @override
  String get hideSidebar => 'Hide Sidebar';

  @override
  String get isActive => 'Is Active';

  @override
  String get isEnabled => 'Is Enabled';

  @override
  String get listView => 'List';

  @override
  String get loadingPaymentTypes => 'Loading payment types…';

  @override
  String get locationAddress => 'Location & Address';

  @override
  String get management => 'Management';

  @override
  String get managerAuthorisation => 'Manager authorisation';

  @override
  String get managerPin => 'Manager PIN';

  @override
  String get menuLabel => 'Menu';

  @override
  String get newCurrency => 'New Currency';

  @override
  String get noCurrenciesFound => 'No currencies found.';

  @override
  String get noPromotionsFound => 'No promotions found.';

  @override
  String get blindReturn => 'No receipt? Blind return';

  @override
  String get noUserLoggedIn => 'No user is currently logged in.';

  @override
  String get noUsersFound => 'No Users Found';

  @override
  String get noVoidReasonsYet => 'No void reasons yet.';

  @override
  String get colNote => 'NOTE';

  @override
  String get oldPassword => 'Old Password';

  @override
  String get paymentMethodColon => 'Payment method:';

  @override
  String get paymentTypeLower => 'Payment type';

  @override
  String get percentage => 'Percentage';

  @override
  String get percentageSign => 'Percentage (%)';

  @override
  String get posSystem => 'POS System';

  @override
  String get power => 'Power';

  @override
  String get powerOptions => 'Power Options';

  @override
  String get promotionName => 'Promotion Name';

  @override
  String get promotionsManagement => 'Promotions Management';

  @override
  String get quickSettings => 'Quick Settings';

  @override
  String get rankDisplayOrderLower => 'Rank (display order)';

  @override
  String get refundItems => 'Refund items';

  @override
  String get refundPaymentType => 'Refund payment type';

  @override
  String get removeCash => 'Remove cash';

  @override
  String get requiredQty => 'Required Qty';

  @override
  String get restartApplication => 'Restart application';

  @override
  String get sameProduct => 'Same Product';

  @override
  String get savePin => 'Save PIN';

  @override
  String get searchReceiptToSeeItems => 'Search a receipt to see its items';

  @override
  String get searchByName => 'Search by name…';

  @override
  String get searchByOrderStaffTable => 'Search by order, staff or table';

  @override
  String get searchNamePhoneCard => 'Search name, phone or card number…';

  @override
  String get searchProductEllipsis => 'Search product…';

  @override
  String get searchWarehouse => 'Search warehouse…';

  @override
  String get selectCustomer => 'Select Customer';

  @override
  String get selectWarehouse => 'Select Warehouse';

  @override
  String get selectYourCompany => 'Select Your Company';

  @override
  String get signOut => 'Sign out';

  @override
  String get supplier => 'Supplier';

  @override
  String get targetUid => 'Target UID (e.g. Product ID)';

  @override
  String get taxExempt => 'Tax Exempt';

  @override
  String get totalRefundAmount => 'TOTAL REFUND AMOUNT';

  @override
  String get turnOffPc => 'Turn off PC';

  @override
  String get colType => 'TYPE';

  @override
  String get updateDevicePin => 'Update Device PIN';

  @override
  String get updatePinForDevice => 'Update PIN for this Device';

  @override
  String get useWeight => 'Use weight';

  @override
  String get userInfo => 'User info';

  @override
  String get userInfoSecurity => 'User Info & Security';

  @override
  String get viewOpenSales => 'View open sales';

  @override
  String get viewSalesHistory => 'View sales history';

  @override
  String get voidReasons => 'Void Reasons';

  @override
  String get welcomeToYourPos => 'Welcome to your POS';

  @override
  String errorLoadingBookings(String message) {
    return 'Error loading bookings: $message';
  }

  @override
  String errorLoadingCustomers(String message) {
    return 'Error loading customers: $message';
  }

  @override
  String get addPrinter => 'Add printer';

  @override
  String get addressFormat => 'Address Format';

  @override
  String get allProducts2 => 'All products';

  @override
  String get forceOnCreditSales =>
      'Always shown on credit sales; this forces it even when paid';

  @override
  String get amountDue => 'Amount due';

  @override
  String get bottom => 'Bottom';

  @override
  String get cashDrawerCommand => 'Cash drawer command';

  @override
  String get change => 'Change';

  @override
  String get collapseSidebar => 'Collapse Sidebar';

  @override
  String get companyHeader => 'Company Header';

  @override
  String get kitchenPrintingSection => 'Kitchen Printing';

  @override
  String get autoKitchenPrintOnCheckout =>
      'Auto-print kitchen tickets at checkout';

  @override
  String get autoKitchenPrintSubtitle =>
      'This terminal only. On sale completion, fires the same station tickets as the Kitchen button.';

  @override
  String get companyPhoneTel => 'Company phone (Tel)';

  @override
  String get companyTaxNumber => 'Company tax number';

  @override
  String get customLabels => 'Custom Labels';

  @override
  String get customerDetailLabels => 'Customer Detail Labels';

  @override
  String get customerDetails => 'Customer Details';

  @override
  String get customizeReceipt => 'Customize Receipt';

  @override
  String get decimalPlaces => 'Decimal places';

  @override
  String get deletePrinter => 'Delete printer';

  @override
  String get discountColumn => 'Discount column';

  @override
  String get hintBarPrinter => 'e.g. Bar printer';

  @override
  String get expandSidebar => 'Expand Sidebar';

  @override
  String get font => 'Font';

  @override
  String get fontFamily => 'Font family';

  @override
  String get fontSettings => 'Font Settings';

  @override
  String get footer => 'Footer';

  @override
  String get footerText => 'Footer text';

  @override
  String get forRtlLanguages => 'For RTL languages (Arabic, Hebrew)';

  @override
  String get globalFooter => 'Global footer';

  @override
  String get globalHeader => 'Global header';

  @override
  String get header => 'Header';

  @override
  String get headerAndFooter => 'Header & Footer';

  @override
  String get headerText => 'Header text';

  @override
  String get invoiceFont => 'Invoice font';

  @override
  String get invoiceSettings => 'Invoice Settings';

  @override
  String get itemsCount => 'Items count';

  @override
  String get kitchenPrinting => 'Kitchen Printing';

  @override
  String get leftSide => 'Left';

  @override
  String get localizeText => 'Localize Text';

  @override
  String get marginsMm => 'Margins (in millimeters)';

  @override
  String get mergeIdenticalItems => 'Merge identical items';

  @override
  String get noCategoryFilter => 'No category filter — prints every item';

  @override
  String get noPrintersFound => 'No printers found';

  @override
  String get printerSelectionUnsupportedOnThisDevice =>
      'This device cannot choose a system printer. Printing opens the device\'s own print dialog instead.';

  @override
  String get numberOfCopies => 'Number of Copies';

  @override
  String get openCashDrawerLower => 'Open cash drawer';

  @override
  String get options => 'Options';

  @override
  String get orderNumberLower => 'Order number';

  @override
  String get otherSettings => 'Other Settings';

  @override
  String get outstandingBalance => 'Outstanding balance';

  @override
  String get paidAmount => 'Paid amount';

  @override
  String get paymentMethods => 'Payment methods';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get printAddress => 'Print address';

  @override
  String get printBarcode => 'Print barcode';

  @override
  String get printCategory => 'Print Category';

  @override
  String get printDemoReceipt => 'Print demo receipt';

  @override
  String get printInA5 => 'Print in A5 size';

  @override
  String get printItemsCount => 'Print items count';

  @override
  String get printKitchenTicket => 'Print kitchen ticket';

  @override
  String get printLargeOrderNumber => 'Print large order number';

  @override
  String get printLogoFullWidth => 'Print logo full width';

  @override
  String get printMeasurementUnit => 'Print measurement unit';

  @override
  String get printTrailingCounter =>
      'Print only the trailing counter (e.g. 000008)';

  @override
  String get printOrderNumber => 'Print order number';

  @override
  String get printOutstandingBalance => 'Print outstanding balance';

  @override
  String get printPhoneTel => 'Print phone (Tel)';

  @override
  String get printTaxName => 'Print tax name';

  @override
  String get printTaxNumber => 'Print tax number';

  @override
  String get printTaxTotals => 'Print tax totals';

  @override
  String get printTemplates => 'Print Templates';

  @override
  String get printTotalQuantity => 'Print total quantity';

  @override
  String get printerName => 'Printer name';

  @override
  String get printerSettings => 'Printer settings';

  @override
  String get printers => 'Printers';

  @override
  String get productGroupsUpper => 'PRODUCT GROUPS';

  @override
  String get receiptContent => 'Receipt Content';

  @override
  String get receiptLabels => 'Receipt Labels';

  @override
  String get receiptNumber => 'Receipt number';

  @override
  String get refreshAll => 'Refresh all';

  @override
  String get refreshPrinters => 'Refresh printers';

  @override
  String get renamePrinter => 'Rename printer';

  @override
  String get reporting => 'Reporting';

  @override
  String get restricted => 'Restricted';

  @override
  String get rightSide => 'Right';

  @override
  String get rightToLeft => 'Right to left';

  @override
  String get cashDrawerSignalHint =>
      'Sends a signal to the cash drawer after checkout';

  @override
  String get shortReceiptNumber => 'Short receipt number';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get taxColumn => 'Tax column';

  @override
  String get taxNumber => 'Tax number';

  @override
  String get titleLabel => 'Title';

  @override
  String get top => 'Top';

  @override
  String get topCustomers => 'TOP CUSTOMERS';

  @override
  String get topProducts => 'TOP PRODUCTS';

  @override
  String get totalRevenue => 'TOTAL REVENUE';

  @override
  String get fallbackWordingHint =>
      'Turn off to fall back to the built-in wording';

  @override
  String get useCustomLabels => 'Use custom labels in reports and invoices';

  @override
  String get kitchenFireHint =>
      'Fire this printer when the Kitchen button is pressed. With';

  @override
  String get myCompanyLower => 'My company';

  @override
  String get customersSuppliersLower => 'Customers & suppliers';

  @override
  String get usersSecurityLower => 'Users & security';

  @override
  String get voidReasonsLower => 'Void reasons';

  @override
  String get taxRatesLower => 'Tax rates';

  @override
  String get paymentTypesLower => 'Payment types';

  @override
  String get rptSalesByProduct => 'Products';

  @override
  String get rptSalesByGroup => 'Product groups';

  @override
  String get rptSalesByCustomer => 'Customers';

  @override
  String get rptTaxRates => 'Tax rates';

  @override
  String get rptUsers => 'Users';

  @override
  String get rptItemList => 'Item list';

  @override
  String get rptPaymentTypes => 'Payment types';

  @override
  String get rptPaymentByUser => 'Payment types by users';

  @override
  String get rptPaymentByCustomer => 'Payment types by customers';

  @override
  String get rptRefunds => 'Refunds';

  @override
  String get rptInvoiceList => 'Invoice list';

  @override
  String get rptDailySales => 'Daily sales';

  @override
  String get rptHourlySales => 'Hourly sales';

  @override
  String get rptHourlyByGroup => 'Hourly sales by product groups';

  @override
  String get rptByTable => 'Table or order number';

  @override
  String get rptProfitMargin => 'Profit & margin';

  @override
  String get rptUnpaidSales => 'Unpaid sales';

  @override
  String get rptStartingCash => 'Starting cash entries';

  @override
  String get rptVoidedItems => 'Voided items';

  @override
  String get rptDiscountsGranted => 'Discounts granted';

  @override
  String get rptDiscountsBySource => 'Discounts by source';

  @override
  String get rptItemDiscounts => 'Items discounts';

  @override
  String get rptStockMovement => 'Stock movement';

  @override
  String get rptSuppliers => 'Suppliers';

  @override
  String get rptUnpaidPurchase => 'Unpaid purchase';

  @override
  String get rptPurchaseDiscounts => 'Purchase discounts';

  @override
  String get rptPurchasedItemDiscounts => 'Purchased items discounts';

  @override
  String get rptPurchaseInvoiceList => 'Purchase invoice list';

  @override
  String get rptExpirationDate => 'Expiration date';

  @override
  String get rptReorderList => 'Reorder product list';

  @override
  String get rptLowStockWarning => 'Low stock warning';

  @override
  String get rptTransactionHistory => 'Transaction history';

  @override
  String get secSales => 'Sales';

  @override
  String get secPurchase => 'Purchase';

  @override
  String get secStockReturn => 'Stock Return';

  @override
  String get secLossAndDamage => 'Loss and damage';

  @override
  String get secStockControl => 'Stock control';

  @override
  String get secFinance => 'Finance';

  @override
  String get accent => 'Accent';

  @override
  String get backups => 'Backups';

  @override
  String get barcodeScanning => 'Barcode scanning';

  @override
  String get clockInUpper => 'CLOCK IN';

  @override
  String get clockOutUpper => 'CLOCK OUT';

  @override
  String get customerDisplayLower => 'Customer display';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get databaseLower => 'Database';

  @override
  String get deviceNameLower => 'Device name';

  @override
  String get dualCurrencyLower => 'Dual Currency';

  @override
  String get enableBookings => 'Enable bookings';

  @override
  String get endOfDayLower => 'End of day';

  @override
  String get generalLower => 'General';

  @override
  String get kitchenDisplayLower => 'Kitchen display';

  @override
  String get loadingCurrencies => 'Loading currencies…';

  @override
  String get loyaltyCardsLower => 'Loyalty cards';

  @override
  String get onScreenKeyboard => 'On-screen keyboard';

  @override
  String get openReservation => 'Open reservation';

  @override
  String get reservedTable => 'Reserved table';

  @override
  String get selectCustomerLower => 'Select customer';

  @override
  String get selectEllipsisShort => 'Select…';

  @override
  String get touchKeyboardHint => 'Show a touch keyboard when typing.';

  @override
  String get subscriptionUpper => 'SUBSCRIPTION';

  @override
  String get takeReservationsHint => 'Take reservations in advance.';

  @override
  String get textSize => 'Text size';

  @override
  String get theme => 'Theme';

  @override
  String get timeClockTitle => 'Time Clock';

  @override
  String get today => 'Today';

  @override
  String get totalUpper => 'TOTAL';

  @override
  String get walkIn => 'Walk-in';

  @override
  String get weighingScaleLower => 'Weighing scale';

  @override
  String get trimZerosFromCode => 'Remove zeros from product code (trim zeros)';

  @override
  String get posNamePrefixHint => 'POS name — prefix for document numbers';

  @override
  String get promotionsLower => 'Promotions';

  @override
  String get welcomeBody =>
      'A fast, offline-first point of sale for your counter and your tablets. Set it up in a few quick taps.';

  @override
  String get featBarcodeBody =>
      'Scan to ring up or find any product instantly.';

  @override
  String get featCustomerDisplayBody =>
      'Show the order and total on a second screen.';

  @override
  String get featKitchenBody => 'Send orders straight to the kitchen (KDS).';

  @override
  String get featBackupsBody => 'Automatic local backups keep your data safe.';

  @override
  String get featScaleBody => 'Sell by weight over a connected serial scale.';

  @override
  String get featPromotionsBody => 'Automatic discounts and special pricing.';

  @override
  String get featLoyaltyBody => 'Points and rewards that bring guests back.';

  @override
  String get exitManagement => 'Exit Management';

  @override
  String get chooseColumns => 'Choose columns';

  @override
  String get viewPrintReceipt => 'View & Print Receipt';

  @override
  String get deleteItemAction => 'Delete Item';

  @override
  String get editItemAction => 'Edit Item';

  @override
  String get noStockAssigned => 'No stock assigned to this';

  @override
  String get noStockControlRules => 'No stock control rules configured';

  @override
  String get selectGroupToEdit =>
      'Select a group to edit, or create a new one.';

  @override
  String editNamedTitle(Object name) {
    return 'Edit $name';
  }

  @override
  String forceResetPinTitle(Object name) {
    return 'Force Reset PIN: $name';
  }

  @override
  String forceResetPasswordTitle(Object name) {
    return 'Force Reset Password: $name';
  }

  @override
  String editPaymentTitle(Object id) {
    return 'Edit Payment #$id';
  }

  @override
  String editDashTitle(Object name) {
    return 'Edit — $name';
  }

  @override
  String confirmDeleteQuoted(Object name) {
    return 'Are you sure you want to delete \'$name\'?';
  }

  @override
  String codeValueLabel(Object code) {
    return 'Code: $code';
  }

  @override
  String idValueLabel(Object id) {
    return 'ID: $id';
  }

  @override
  String assignProductToWarehouse(Object name) {
    return 'Assign $name to Warehouse';
  }

  @override
  String deleteQuotedConfirm(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String deletePlainConfirm(Object name) {
    return 'Delete $name?';
  }

  @override
  String removeDiscardConfirm(Object name) {
    return 'Remove \"$name\"? Its settings will be discarded.';
  }

  @override
  String removeQuotedConfirm(Object name) {
    return 'Remove \"$name\"?';
  }

  @override
  String typeValueLabel(Object type) {
    return 'Type: $type';
  }

  @override
  String ofPagesLabel(Object total) {
    return 'of $total';
  }

  @override
  String fixedAmountSymLabel(Object sym) {
    return 'Fixed Amount ($sym)';
  }

  @override
  String couldNotReadSyncStatus(Object message) {
    return 'Couldn\'t read sync status: $message';
  }

  @override
  String uidValueLabel(Object uid, Object value) {
    return 'UID: $uid | Value: $value';
  }

  @override
  String enterFieldHint(Object field) {
    return 'Enter $field';
  }

  @override
  String get actionClear => 'Clear';

  @override
  String get noStockAssignedWarehouse => 'No stock assigned to this warehouse';

  @override
  String get noStockAssignedProduct => 'No stock assigned to this product';

  @override
  String get orderSummary => 'Order Summary';

  @override
  String get promotionLabel => 'Promotion';

  @override
  String get subtotalInclTax => 'Subtotal (incl. tax)';

  @override
  String get customerDiscountLabel => 'Customer discount';

  @override
  String get cartDiscountLabel => 'Cart discount';

  @override
  String get taxInclLabel => 'Tax (incl.)';

  @override
  String get itemDiscountLabel => 'Item discount';

  @override
  String get itemDiscountsPlural => 'Item discounts';

  @override
  String get taxesLabel => 'Taxes';

  @override
  String get pointsRedeemed => 'Points Redeemed';

  @override
  String get subtotalLabel => 'Subtotal';

  @override
  String get applyDiscount => 'Apply Discount';

  @override
  String get cartTab => 'Cart';

  @override
  String get itemTab => 'Item';

  @override
  String get selectItemFirst => 'Please select an item in the cart first.';

  @override
  String get noItemSelected => 'No item selected!';

  @override
  String get selectedItemNotFound => 'Selected item not found.';

  @override
  String get discountBelowCost => 'Discount would price item below cost.';

  @override
  String get discountNegativePrice =>
      'Discount would result in a negative price.';

  @override
  String inclPrefix(Object name) {
    return 'incl. $name';
  }

  @override
  String get saveAndRestart => 'Save & Restart';

  @override
  String get resourceMode => 'Resource Mode';

  @override
  String get resourceModeHint => 'What a booking slot is assigned to';

  @override
  String get defaultDuration => 'Default Duration';

  @override
  String get defaultDurationHint =>
      'Pre-filled slot length when adding a booking';

  @override
  String get timeSnapping => 'Time Snapping';

  @override
  String get timeSnappingHint => 'Grid interval when picking start/end times';

  @override
  String get couldNotLoadCurrencies => 'Could not load currencies';

  @override
  String get fontPreview => 'Preview: the quick brown fox';

  @override
  String get chooseTheme => 'CHOOSE THEME';

  @override
  String get posButtonsHint =>
      'Select which action buttons appear on the main POS screen.';

  @override
  String get couldNotLoadTaxRates => 'Could not load tax rates';

  @override
  String get noTaxRatesDefined =>
      'No tax rates defined yet. Add them under Tax Rates.';

  @override
  String get taxDefaultRequiredTitle => 'Choose a default tax rate';

  @override
  String get taxDefaultRequiredBody =>
      'Tax-inclusive pricing needs a default tax rate. Pick at least one — it will be applied to every new product and locked at the till.';

  @override
  String get taxDefaultRequiredNoRates =>
      'No tax rates defined yet. Create one under Tax Rates before turning this on.';

  @override
  String get defaultTaxRateDisabledHint =>
      'Turn on tax-inclusive pricing above to apply a default tax rate.';

  @override
  String get taxLockedBySetting =>
      'Set in Settings → General → Tax. It can\'t be changed here.';

  @override
  String get taxLockedShort => 'Locked';

  @override
  String get couldNotLoadWarehouses => 'Could not load warehouses';

  @override
  String get defaultWarehouseHint =>
      'Used to check product stock availability in the POS menu.';

  @override
  String get waitingForScale => 'Waiting for the scale to send a weight…';

  @override
  String get restoreDefaults => 'Restore defaults';

  @override
  String get sameMachineSecondMonitor => 'Same machine / second monitor';

  @override
  String get otherDeviceSameNetwork => 'Other device on same network';

  @override
  String get categoriesPrintedOnGroup =>
      'Categories printed on this printer group';

  @override
  String get noPrinterGroupsYet => 'No printer groups yet.';

  @override
  String get noKitchenDisplays => 'No kitchen displays configured.';

  @override
  String get noGroupSelectedReceivesAll =>
      'No group selected → receives all items.';

  @override
  String get openDatabaseLocation => 'Open database location';

  @override
  String get setZeroToDisableBackups =>
      'Set to 0 to turn off scheduled backups';

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusInvalid => 'Invalid';

  @override
  String get statusNotActivated => 'Not activated';

  @override
  String get onboardingWillShow =>
      'Onboarding will show the next time you open the app.';

  @override
  String get autoLabel => 'Auto';

  @override
  String get themeDimmed => 'Dimmed';

  @override
  String get themeNight => 'Night';

  @override
  String get themeGray => 'Gray';

  @override
  String get themeHighContrast => 'High Contrast';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorPurple => 'Purple';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorRed => 'Red';

  @override
  String get allFields => 'All fields';

  @override
  String get signInOnlineAgain =>
      'You will need to sign in online to use the POS again.';

  @override
  String get tablesLabel => 'Tables';

  @override
  String get bookingLabel => 'Booking';

  @override
  String get posNameFullHint =>
      'A short, UNIQUE name for this terminal. It becomes the prefix of every document number (e.g. CAISSE1-200-000045), so two POS never produce the same number. Letters & digits only.';

  @override
  String get defaultTaxRateFullHint =>
      'Automatically applied to products added to the cart that have no tax of their own.';

  @override
  String get serialScaleWindowsOnly =>
      'Serial scales are supported on Windows only. On this device, use the barcode parsing option above with a label-printing scale.';

  @override
  String get openCustomerDisplayFullHint =>
      'Opens the customer display as a full-screen Flutter view on this machine. Ideal for a second monitor — drag the window over and press F11.';

  @override
  String get printerGroupsHelp =>
      'Group product categories into stations (e.g. Kitchen, Barman). Assign a group to a display below and that display only shows the items in those categories.';

  @override
  String get receivesAllItems =>
      'Receives all items. Create printer groups above to route by category.';

  @override
  String get autoSyncFullHint =>
      'Push your local changes and pull fresh data automatically in the background.';

  @override
  String get replayOnboardingHint =>
      'Replay the first-run welcome tour. It shows again the next time you open the app on this device.';

  @override
  String pairingRequestSent(Object ip) {
    return 'Pairing request sent to $ip — the KDS should switch to the kitchen view.';
  }

  @override
  String kdsTabletsHelp(Object port) {
    return 'Each Kitchen Display tablet listens on port $port. Adding its IP pairs it with this POS and pushes orders directly over the local network — the KDS works fully offline, no internet needed.';
  }

  @override
  String get statusActive => 'Active';

  @override
  String get statusEnabled => 'Enabled';

  @override
  String get statusDisabled => 'Disabled';

  @override
  String get statusOn => 'On';

  @override
  String get statusOff => 'Off';

  @override
  String expiresInDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expires in $count days',
      one: 'Expires in 1 day',
    );
    return '$_temp0';
  }

  @override
  String deviceCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
    );
    return '$_temp0';
  }

  @override
  String get scaleBarcodePriceHint =>
      'When on, the encoded value is a price and quantity is calculated as price ÷ unit price';

  @override
  String get webDisplayHint =>
      'Host an interactive order screen accessible from any browser on your network';

  @override
  String savedFieldFailed(Object field) {
    return 'Failed to save $field';
  }

  @override
  String prefixColonValue(Object prefix) {
    return 'Prefix: $prefix';
  }

  @override
  String unlinkEmailWarning(Object email) {
    return 'This will unlink $email from this terminal. You will need to sign in online to use the POS again.';
  }

  @override
  String get unlinkTerminalWarning =>
      'This will unlink this terminal. You will need to sign in online to use the POS again.';

  @override
  String get builtInBadge => 'BUILT-IN';

  @override
  String get printerType => 'Printer type';

  @override
  String get paperSize => 'Paper size';

  @override
  String get copiesPerTransaction => 'Copies per transaction';

  @override
  String get headerPrintedTopHint => 'Printed at the top of every receipt';

  @override
  String get footerThankYouHint => 'e.g. Thank you for shopping with us!';

  @override
  String get generalLabel => 'General';

  @override
  String get categoryLabel => 'Category';

  @override
  String get chooseCustomerDetailsHint =>
      'Choose what customer details are printed on the receipt.';

  @override
  String get addressFormatFullHint =>
      'Specify how address lines are printed on receipts and invoices.';

  @override
  String get tapPlaceholderHint => 'Tap a placeholder to insert it:';

  @override
  String get invoiceTitleHint => 'e.g. TAX INVOICE';

  @override
  String get invoiceHeaderHint => 'Printed above the invoice';

  @override
  String get invoiceFooterHint => 'e.g. bank details, terms';

  @override
  String get addPrinterHint =>
      'Add a printer for each station, then open its settings to configure paper size, margins, header/footer and the cash drawer.';

  @override
  String get kitchenFireFullHint =>
      'Fire this printer when the Kitchen button is pressed. With several enabled, the category below decides what each prints.';

  @override
  String get categoryFilterHint =>
      'This printer only prints products whose category belongs to the selected group (e.g. Barman → drinks). Pick \"All products\" to print the whole ticket here.';

  @override
  String get noPrinterGroupsDefined =>
      'No printer groups defined yet. Create them in Settings → Customer Display → Printer Groups.';

  @override
  String get headerDetailsFullHint =>
      'Details printed under the logo / business name at the top of the receipt. The header and footer text themselves are set per printer (⚙ → General).';

  @override
  String get sessionExpiredMsg => 'Your session expired. Please sign in again.';

  @override
  String get enterPin => 'Enter PIN';

  @override
  String get syncingMasterData => 'Syncing master data…';

  @override
  String get confirmNewPin => 'Confirm New PIN';

  @override
  String get createFourDigitPin => 'Create 4-Digit PIN';

  @override
  String get companyName => 'Company Name';

  @override
  String get taxNumberLabel => 'Tax Number';

  @override
  String get emailAddress => 'Email Address';

  @override
  String get streetName => 'Street Name';

  @override
  String get buildingNo => 'Building No.';

  @override
  String get additionalStreet => 'Additional Street';

  @override
  String get plotId => 'Plot ID';

  @override
  String get districtSubdivision => 'District / Subdivision';

  @override
  String get postalCode => 'Postal Code';

  @override
  String get cityLabel => 'City';

  @override
  String get stateProvince => 'State / Province';

  @override
  String get bankAccountNumber => 'Bank Account Number';

  @override
  String get bankDetails => 'Bank Details (IBAN, SWIFT, etc.)';

  @override
  String get rateLabel => 'Rate';

  @override
  String get taxOnTotal => 'Tax on Total';

  @override
  String get noTaxRatesFound => 'No tax rates found.';

  @override
  String get editVoidReason => 'Edit Void Reason';

  @override
  String get addVoidReason => 'Add Void Reason';

  @override
  String get addReason => 'Add Reason';

  @override
  String get totalDue => 'Total Due';

  @override
  String get replaceTaxesHint =>
      'Use this form to replace taxes for all products. Select the old tax you wish to replace with the new tax and click Replace.';

  @override
  String errorLoadingTaxesMsg(Object message) {
    return 'Error loading taxes: $message';
  }

  @override
  String get orderTypeLabel => 'Order Type';

  @override
  String get noServiceStatuses => 'No service statuses configured.';

  @override
  String get quantityCannotBeNegative => 'Quantity cannot be negative.';

  @override
  String get cannotCalcQuantity =>
      'Cannot calculate quantity: unit price is zero.';

  @override
  String get parsedQuantityZero =>
      'Parsed quantity is zero — check scale barcode configuration.';

  @override
  String get selectTableFirst => 'Please select a table first!';

  @override
  String get notAvailableOtherWarehouse =>
      'This product is not available in any other warehouse.';

  @override
  String get selectTableFromFloorPlan =>
      'Please select a Table from the Floor Plan first!';

  @override
  String get cartIsEmpty => 'Cart is empty';

  @override
  String get totalPromotionalDiscount => 'Total Promotional Discount';

  @override
  String get calendarBookingUpdated =>
      'Calendar booking will be updated automatically.';

  @override
  String get confirmTransfer => 'Confirm Transfer';

  @override
  String get setAbout => 'About';

  @override
  String get setAccentColor => 'Accent Color';

  @override
  String get setAddPrinterGroup => 'Add Printer Group';

  @override
  String get setAddress => 'Address';

  @override
  String get setAdvancedSettings => 'ADVANCED SETTINGS';

  @override
  String get setTaxInclusiveDefaultHint =>
      'All new products will default to tax-inclusive pricing';

  @override
  String get setAllowNegativePrice => 'Allow negative price';

  @override
  String get setAllowTablelessOrders => 'Allow table-less orders';

  @override
  String get setAllowWalkInTableOrders => 'Allow walk-in table orders';

  @override
  String get setApi => 'API';

  @override
  String get setApiBaseUrl => 'API Base URL';

  @override
  String get setAppearance => 'APPEARANCE';

  @override
  String get setApplicationStyle => 'APPLICATION STYLE';

  @override
  String get setAutoBackup => 'Auto Backup';

  @override
  String get setAutoSync => 'AUTO SYNC';

  @override
  String get setAutomaticBackups => 'AUTOMATIC BACKUPS';

  @override
  String get setAutoUpdateCostPrice =>
      'Automatically update cost price on purchase';

  @override
  String get setBackUpEvery => 'Back up automatically every';

  @override
  String get setBackupOnClose => 'Backup database on application close';

  @override
  String get setBackupOnStart => 'Backup database on application start';

  @override
  String get setBackupLocation => 'Backup location';

  @override
  String get setBarcodeParsing => 'BARCODE PARSING';

  @override
  String get setBaudRate => 'Baud rate';

  @override
  String get setBitsPerSecond => 'Bits per second';

  @override
  String get setBooking => 'BOOKING';

  @override
  String get setBookingSettings => 'Booking settings';

  @override
  String get setBookingsButton => 'Bookings button';

  @override
  String get setBottomLine => 'Bottom line';

  @override
  String get setBusinessDay => 'BUSINESS DAY';

  @override
  String get setCashDrawer => 'Cash Drawer';

  @override
  String get setCashDrawerButton => 'Cash Drawer button';

  @override
  String get setChangeQuantity => 'Change quantity';

  @override
  String get setChangeQuantityButton => 'Change quantity button';

  @override
  String get setColor => 'Color';

  @override
  String get setComPort => 'COM port';

  @override
  String get setCommentButton => 'Comment button';

  @override
  String get setCompany => 'COMPANY';

  @override
  String get setCopyLanUrl => 'Copy LAN URL';

  @override
  String get setCostPriceMarkup => 'Cost price based markup';

  @override
  String get setCurrency => 'Currency';

  @override
  String get setCustomerButton => 'Customer button';

  @override
  String get setCustomerDisplay => 'Customer display';

  @override
  String get setCustomerDisplayEnabled => 'Customer display enabled';

  @override
  String get setDataBits => 'Data bits';

  @override
  String get setDatabase => 'DATABASE';

  @override
  String get setDatabaseBackup => 'Database & Backup';

  @override
  String get setDbSize => 'DB Size';

  @override
  String get setDefaultBarcodeFormat => 'Default Barcode Format';

  @override
  String get setDefaultDiscountType => 'Default discount type';

  @override
  String get setDefaultDueDays => 'Default due date (days)';

  @override
  String get setDefaultMeasurementUnit => 'Default Measurement Unit';

  @override
  String get setDefaultScreen => 'Default screen';

  @override
  String get setDefaultSearch => 'Default search mode';

  @override
  String get setDefaultServiceType => 'Default service type';

  @override
  String get setDefaultTaxRate => 'Default tax rate';

  @override
  String get setDefaultWarehouse => 'Default warehouse';

  @override
  String get setDeleteBackupsOlderThan => 'Delete backups older than';

  @override
  String get setDeleteOldBackups => 'Delete old backups automatically';

  @override
  String get setDeleteServiceStatus => 'Delete Service Status';

  @override
  String get setDeleteServiceType => 'Delete Service Type';

  @override
  String get setDevice => 'DEVICE';

  @override
  String get setDeviceName => 'Device Name';

  @override
  String get setDevices => 'Devices';

  @override
  String get setDiscountApplyRule => 'Discount apply rule';

  @override
  String get setDiscountButton => 'Discount button';

  @override
  String get setSyncToast => 'Display a toast each time a sync completes';

  @override
  String get setDisplayMessages => 'DISPLAY MESSAGES';

  @override
  String get setDisplayPrintTaxIncluded =>
      'Display and print items with tax included';

  @override
  String get setDualCurrencyHint =>
      'Display prices and totals in a second currency simultaneously';

  @override
  String get setShowPrintDialog => 'Display receipt print dialog';

  @override
  String get setDualCurrency => 'DUAL CURRENCY';

  @override
  String get setDualCurrencyEnabled => 'Dual Currency Enabled';

  @override
  String get setEnableAutomaticBackups => 'Enable automatic backups';

  @override
  String get setEnableAutoSync => 'Enable auto-sync';

  @override
  String get setEnableBookings => 'Enable Bookings / Calendar';

  @override
  String get setEnableFloorPlan => 'Enable Floor Plan / Tables';

  @override
  String get setEnableLiveWebDisplay => 'Enable live web customer display';

  @override
  String get setEnableMovingAverage => 'Enable moving average price';

  @override
  String get setEnableVirtualKeyboard => 'Enable Virtual Keyboard';

  @override
  String get setEnableScaleBarcode => 'Enable weighing scales barcode';

  @override
  String get setExchangeRate => 'Exchange Rate';

  @override
  String get setFeatures => 'FEATURES';

  @override
  String get setFirstTwoDigits => 'First two digits / prefix';

  @override
  String get setFlowControl => 'Flow control';

  @override
  String get setFontSize => 'Font Size';

  @override
  String get setFromEmailAddress => 'From Email Address';

  @override
  String get setFromName => 'From Name';

  @override
  String get setGeneral => 'GENERAL';

  @override
  String get setIanaTimezone => 'IANA Timezone';

  @override
  String get setInventory => 'INVENTORY';

  @override
  String get setItems => 'ITEMS';

  @override
  String get setKdsIp => 'KDS IP address';

  @override
  String get setKitchenDisplay => 'Kitchen Display';

  @override
  String get setKdsTablets => 'KITCHEN DISPLAY TABLETS';

  @override
  String get setLastSync => 'Last Sync';

  @override
  String get setLayout => 'Layout';

  @override
  String get setLoadingCurrencies => 'Loading currencies…';

  @override
  String get setMenuGrid => 'MENU GRID';

  @override
  String get setMenuGridColumns => 'Menu Grid Columns';

  @override
  String get setMenuGridRows => 'Menu Grid Rows';

  @override
  String get setMenuLayout => 'Menu Layout (List / Grid)';

  @override
  String get setMergeItemsOnReceipt => 'Merge items on receipt';

  @override
  String get setMessageDuration => 'Message Duration (seconds)';

  @override
  String get setMessagePosition => 'Message Position';

  @override
  String get setMessages => 'MESSAGES (NOTIFICATIONS)';

  @override
  String get setMovingAveragePrice => 'MOVING AVERAGE PRICE';

  @override
  String get setNumberOfCharacters => 'Number of characters';

  @override
  String get setNumberOfDecimals => 'Number of decimal places';

  @override
  String get setProductCodeDigits => 'Number of digits for product code';

  @override
  String get setPaymentTypeRows => 'Number of payment type rows';

  @override
  String get setOnboarding => 'ONBOARDING';

  @override
  String get setOpen => 'Open';

  @override
  String get setOpenCustomerDisplay => 'Open customer display';

  @override
  String get setOpenInBrowser => 'Open in browser (drag to second monitor)';

  @override
  String get setOpenOnThisDevice => 'OPEN ON THIS DEVICE';

  @override
  String get setOrderAndPayment => 'Order & Payment';

  @override
  String get setOrderNumberPrefix => 'Order Number Prefix';

  @override
  String get setParity => 'Parity';

  @override
  String get setScaleBarcodeHint =>
      'Parse weight/price from barcodes printed by a weighing scale';

  @override
  String get setPayment => 'PAYMENT';

  @override
  String get setPhone => 'Phone';

  @override
  String get setPosButtonBar => 'POS BUTTON BAR';

  @override
  String get setPosNameHint => 'POS name — prefix for document numbers';

  @override
  String get setPreventNegativeInventory => 'Prevent negative inventory';

  @override
  String get setPreventSaleBelowCost => 'Prevent sale below cost price';

  @override
  String get setPrint => 'Print';

  @override
  String get setPrintLargeOrderNumber => 'Print large order number in receipt';

  @override
  String get setPrinterReceiptSettings => 'Printer & Receipt Settings';

  @override
  String get setPrinterGroups => 'PRINTER GROUPS';

  @override
  String get setProductDefaults => 'PRODUCT DEFAULTS';

  @override
  String get setReadLiveWeight => 'Read live weight from a serial scale';

  @override
  String get setRefundButton => 'Refund button';

  @override
  String get setRegional => 'REGIONAL';

  @override
  String get setRegisteredAccount => 'Registered account';

  @override
  String get setRenewsEnds => 'Renews / ends';

  @override
  String get setRepair => 'Re-pair';

  @override
  String get setReplay => 'Replay';

  @override
  String get setRequestServiceTypeAuto => 'Request service type automatically';

  @override
  String get setRequireReasonOnVoid => 'Require reason on void';

  @override
  String get setRequiresFloorPlan =>
      'Requires Floor Plan / Tables to be enabled';

  @override
  String get setRescanPorts => 'Rescan ports';

  @override
  String get setResetOrderNumber => 'Reset order number on day close';

  @override
  String get setWalkInHint => 'Ring up a dine-in order without picking a table';

  @override
  String get setRoom => 'Room';

  @override
  String get setRows => 'Rows';

  @override
  String get setScalePrintsPrice => 'Scale prints price instead of quantity';

  @override
  String get setScreenDisplayWeb => 'SCREEN DISPLAY (WEB)';

  @override
  String get setSearchAllSettings => 'Search all settings...';

  @override
  String get setSearchButton => 'Search button';

  @override
  String get setSecondaryCurrencySymbol => 'Secondary Currency Symbol';

  @override
  String get setSelectBusinessDayOnStart =>
      'Select business day on application start';

  @override
  String get setSelectEllipsis => 'Select…';

  @override
  String get setSendToKitchen => 'Send to Kitchen';

  @override
  String get setSendToKitchenButton => 'Send to Kitchen button';

  @override
  String get setSender => 'SENDER';

  @override
  String get setSeparateRowPerItem => 'Separate row for each item';

  @override
  String get setSerialConnection => 'SERIAL CONNECTION';

  @override
  String get setServiceStatusSelector => 'Service Status Selector';

  @override
  String get setServiceStatuses => 'Service Statuses';

  @override
  String get setServiceTypeHeader => 'SERVICE TYPE';

  @override
  String get setServiceTypeSelector => 'Service Type Selector';

  @override
  String get setServiceTypes => 'Service Types';

  @override
  String get setShowAllOccupied => 'Show all occupied tables in floor plan';

  @override
  String get setShowCashInOnStart => 'Show cash in on application start';

  @override
  String get setShowItemsOnPaymentForm => 'Show items on payment form';

  @override
  String get setShowOrderTotalOnPole =>
      'Show order total on a serial VFD / LCD pole display';

  @override
  String get setShowOrderTypeButtons => 'Show order type buttons on the POS';

  @override
  String get setShowProductImages => 'Show Product Images in POS Grid';

  @override
  String get setShowSearchOptions => 'Show search mode buttons';

  @override
  String get setShowServiceStatusBadge =>
      'Show service status badge on table/booking cards';

  @override
  String get setShowSyncNotification => 'Show sync notification';

  @override
  String get setShowTablesButton => 'Show the Tables button in the POS';

  @override
  String get setSignOut => 'Sign Out';

  @override
  String get setSignOutDevice => 'Sign Out Device';

  @override
  String get setSingleItemDiscount => 'Single item discount allowed';

  @override
  String get setSingleUser => 'Single user';

  @override
  String get setSmtpHost => 'SMTP Host';

  @override
  String get setSmtpPort => 'SMTP Port';

  @override
  String get setSmtpServer => 'SMTP SERVER';

  @override
  String get setSorting => 'Sorting';

  @override
  String get setStaff => 'Staff';

  @override
  String get setStartOrderFreeTable =>
      'Start an order on a free table without a booking';

  @override
  String get setStarted => 'Started';

  @override
  String get setStartup => 'STARTUP';

  @override
  String get setStopBits => 'Stop bits';

  @override
  String get setScaleStreamHint =>
      'Streams the weight from a scale on a COM port into the quantity keypad';

  @override
  String get setStripLeadingZeros =>
      'Strip leading zeros before looking up the product';

  @override
  String get setSubscription => 'Subscription';

  @override
  String get setSystemInfo => 'SYSTEM INFO';

  @override
  String get setTable => 'Table';

  @override
  String get setTablesFloorPlan => 'Tables / Floor Plan';

  @override
  String get setTablesFloorPlanButton => 'Tables / Floor Plan button';

  @override
  String get setTablesButtonLabel => 'Tables Button Label';

  @override
  String get setTaxHeader => 'TAX';

  @override
  String get setTaxButton => 'Tax button';

  @override
  String get setTaxIncludedByDefault => 'Tax Included in Price by Default';

  @override
  String get setTaxNo => 'Tax No';

  @override
  String get setTestDisplay => 'Test display';

  @override
  String get setThankYouMessage => 'Thank-you message (after payment)';

  @override
  String get setThemeMode => 'Theme Mode';

  @override
  String get setTimezone => 'Timezone';

  @override
  String get setTopLine => 'Top line';

  @override
  String get setTrackUnconfirmedVoids => 'Track unconfirmed voided items';

  @override
  String get setTransferButton => 'Transfer button';

  @override
  String get setUpdateSalePriceFromMarkup =>
      'Update sale price based on markup';

  @override
  String get setUsers => 'USERS';

  @override
  String get setVoidItems => 'VOID ITEMS';

  @override
  String get setWarehouseSwitcher => 'Warehouse Switcher';

  @override
  String get setWarehouseSwitcherButton => 'Warehouse Switcher button';

  @override
  String get setWeighingScale => 'Weighing Scale';

  @override
  String get setWelcomeMessage => 'WELCOME MESSAGE';

  @override
  String get setWelcomeMessageLabel => 'Welcome message (idle screen)';

  @override
  String get setWelcomeBottomLine => 'Welcome message bottom line';

  @override
  String get setWelcomeTopLine => 'Welcome message top line';

  @override
  String get setWhenToSync => 'When to sync';

  @override
  String get setWritingDirection => 'Writing Direction';

  @override
  String get setHintCaisse => 'e.g. CAISSE1';

  @override
  String get setHintUber => 'e.g. UBER';

  @override
  String get setHintUberEats => 'e.g. Uber Eats';

  @override
  String get setHintWaiting => 'e.g. Waiting';

  @override
  String get selectExportType => 'Select export type';

  @override
  String get exportCsv => 'CSV (Excel)';

  @override
  String get exportXml => 'XML';

  @override
  String get deleteProducts => 'Delete Products';

  @override
  String get showHideColumns => 'Show / Hide Columns';

  @override
  String get alwaysShown => 'Always shown';

  @override
  String get actionReset => 'Reset';

  @override
  String get products => 'Products';

  @override
  String get columns => 'Columns';

  @override
  String get importLabel => 'Import';

  @override
  String get exportLabel => 'Export';

  @override
  String get addProduct => 'Add Product';

  @override
  String get categoriesHeader => 'CATEGORIES';

  @override
  String get errorLoadingGroups => 'Error loading groups';

  @override
  String get allProducts => 'All Products';

  @override
  String get noProductsFound => 'No products found.';

  @override
  String noProductsMatchSearch(String query) {
    return 'No product matches \"$query\".';
  }

  @override
  String get productNameRequired => 'Product Name *';

  @override
  String get categoryGroup => 'Category / Group';

  @override
  String get noneUncategorized => 'None (Uncategorized)';

  @override
  String get productCodeSku => 'Product Code / SKU';

  @override
  String get plu => 'PLU';

  @override
  String get measurementUnit => 'Measurement Unit';

  @override
  String get measurementUnitHint => 'e.g. kg, pcs';

  @override
  String get sellByWeight => 'Sell by weight';

  @override
  String get sellByWeightHint =>
      'When on, the POS asks for a quantity instead of adding one unit. With no scale connected, the \'Price\' button edits the quantity.';

  @override
  String get uomStockUnit => 'stock unit';

  @override
  String get uomCategoryUnit => 'Unit';

  @override
  String get uomCategoryWeight => 'Weight';

  @override
  String get uomCategoryVolume => 'Volume';

  @override
  String get uomCategoryLength => 'Length';

  @override
  String uomStockHeldIn(String unit) {
    return 'Stock is counted in $unit.';
  }

  @override
  String uomStockConversionNote(String unit, String factor, String stockUnit) {
    return 'Priced per $unit. Stock still moves in $stockUnit — 1 $unit = $factor $stockUnit.';
  }

  @override
  String get weighItem => 'Weigh item';

  @override
  String get placeOnScale => 'Place the item on the scale';

  @override
  String get scaleNotConnected => 'No scale connected — enter the quantity';

  @override
  String get useThisWeight => 'Use this weight';

  @override
  String get enterQuantity => 'Enter Quantity';

  @override
  String get priceEditsQuantity => 'Price edits quantity';

  @override
  String get keypadAmount => 'Amount';

  @override
  String amountBuysQuantity(String amount, String quantity) {
    return '$amount buys $quantity';
  }

  @override
  String get barcodeRules => 'Barcode Rules';

  @override
  String barcodeRulesHint(Object NNDD) {
    return 'Barcode rules define how a scanned barcode is read. A barcode is matched against the first rule whose pattern fits, so order matters. Patterns can embed a value such as a weight or a price: $NNDD marks where the digits sit, and D positions are decimals. A product whose barcode carries an embedded value must store those positions as zeros.';
  }

  @override
  String get ruleName => 'Rule Name';

  @override
  String get ruleType => 'Type';

  @override
  String get ruleEncoding => 'Encoding';

  @override
  String get rulePattern => 'Barcode Pattern';

  @override
  String get ruleTypeUnit => 'Unit Product';

  @override
  String get ruleTypeWeighted => 'Weighted Product';

  @override
  String get ruleTypePriced => 'Priced Product';

  @override
  String get ruleTypeDiscounted => 'Discounted Product';

  @override
  String get addRuleLine => 'Add a line';

  @override
  String get barcodeRulesSaved => 'Barcode rules saved';

  @override
  String get testBarcode => 'Test a barcode';

  @override
  String get testBarcodeNoMatch => 'No rule matches this barcode';

  @override
  String testBarcodeMatched(String rule, String value) {
    return 'Matched $rule — value $value';
  }

  @override
  String get weightNotAllowedForService =>
      'A service cannot be sold by weight.';

  @override
  String get scaleReadFailed => 'Could not read the scale';

  @override
  String get ageRestrictionHint => 'e.g. 18';

  @override
  String get sellingPriceRequired => 'Selling Price *';

  @override
  String get purchaseCost => 'Purchase Cost';

  @override
  String get marginMarkup => 'Margin / Markup (%)';

  @override
  String get rankDisplayOrder => 'Rank (Display Order)';

  @override
  String get description => 'Description';

  @override
  String get priceIsTaxInclusive => 'Product Price is Tax Inclusive';

  @override
  String get isServiceNotPhysical => 'Is Service (Not physical)';

  @override
  String get changePriceAllowed => 'Change Price Allowed';

  @override
  String get isEnabledVisible => 'Is Enabled (Visible)';

  @override
  String get productColorMarker => 'Product Color Marker';

  @override
  String get productImage => 'Product Image';

  @override
  String get productImageHint =>
      'Replaces the placeholder icon on the POS menu tile.';

  @override
  String get removeImage => 'Remove Image';

  @override
  String get taxInclusiveNotAppliedNote =>
      'Heads up: the till still adds this tax on top of the price. Tax-inclusive pricing is stored on the product but not yet applied at checkout.';

  @override
  String get pricingTab => 'Pricing';

  @override
  String taxBreakdownIncluded(String price, String tax, String net) {
    return '$price includes $tax tax · net $net';
  }

  @override
  String taxBreakdownAdded(String price, String tax, String total) {
    return '$price + $tax tax = $total';
  }

  @override
  String get applyTaxes => 'Apply Taxes';

  @override
  String get failedToLoadTaxes => 'Failed to load taxes';

  @override
  String get primaryTaxRate => 'Primary Tax Rate';

  @override
  String get noTax => 'No Tax';

  @override
  String get productModifiersComments => 'Product Modifiers & Comments';

  @override
  String get newModifierComment => 'New Modifier / Comment';

  @override
  String get newModifierHint => 'e.g. No Onions';

  @override
  String get noCommentsYet => 'No comments added yet.';

  @override
  String get deleteComment => 'Delete Comment';

  @override
  String get productBarcodes => 'Product Barcodes';

  @override
  String get barcode => 'Barcode';

  @override
  String get generateBarcode => 'Generate barcode';

  @override
  String get noBarcodesYet => 'No barcodes assigned yet.';

  @override
  String get pendingSync => 'Pending sync';

  @override
  String get deleteBarcode => 'Delete Barcode';

  @override
  String get transactionBlocked => 'Transaction Blocked';

  @override
  String get actionOk => 'OK';

  @override
  String get transactionSuccessful => 'Transaction Successful';

  @override
  String get printReceiptPrompt => 'Would you like to print a receipt?';

  @override
  String get saveAsPdf => 'Save as PDF';

  @override
  String get printReceipt => 'Print Receipt';

  @override
  String get splitPayments => 'Split Payments';

  @override
  String get totalLabel => 'Total';

  @override
  String get paidLabel => 'Paid';

  @override
  String get remainingLabel => 'Remaining';

  @override
  String get changeLabel => 'Change';

  @override
  String get removeCustomer => 'Remove customer';

  @override
  String get redeemPoints => 'Redeem Points';

  @override
  String get pointsToUse => 'Points to use';

  @override
  String get decrementOnePoint => '-1 pt';

  @override
  String get incrementOnePoint => '+1 pt';

  @override
  String useMaxPoints(String points) {
    return 'Use Max ($points pts)';
  }

  @override
  String get actionRedeem => 'Redeem';

  @override
  String get paymentTypes => 'Payment Types';

  @override
  String get showNavigation => 'Show navigation';

  @override
  String get visibleColumns => 'Visible Columns';

  @override
  String get columnsTooltip => 'Columns';

  @override
  String get refreshTooltip => 'Refresh';

  @override
  String get newPaymentType => 'New Payment Type';

  @override
  String errorLoadingPaymentTypes(String message) {
    return 'Error loading payment types: $message';
  }

  @override
  String get noCompanySelectedShort => 'No company selected.';

  @override
  String get noPaymentTypesFound => 'No payment types found.';

  @override
  String get addFirstPaymentType => 'Add First Payment Type';

  @override
  String deletePaymentTypeConfirm(String name) {
    return 'Delete payment type \'$name\'?';
  }

  @override
  String get fieldNameRequired => 'Name *';

  @override
  String get codeRequired => 'Code *';

  @override
  String get taxCodeAlreadyUsed => 'Already used by another tax';

  @override
  String get fieldCode => 'Code';

  @override
  String get fieldPosition => 'Position';

  @override
  String get fieldShortcut => 'Shortcut';

  @override
  String get actionUpdate => 'Update';

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get activePromotions => 'Active Promotions';

  @override
  String get noActivePromotions => 'No active promotions right now.';

  @override
  String ordersReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders ready',
      one: '1 order ready',
    );
    return '$_temp0';
  }

  @override
  String get selectOrderType => 'Select Order Type';

  @override
  String get serviceStatus => 'Service Status';

  @override
  String get selectServiceStatus => 'Select Service Status';

  @override
  String get posDiscount => 'Discount';

  @override
  String get posQuantity => 'Quantity';

  @override
  String get posTax => 'Tax';

  @override
  String get posComment => 'Comment';

  @override
  String get posTransfer => 'Transfer';

  @override
  String get posRefund => 'Refund';

  @override
  String get posKitchen => 'Kitchen';

  @override
  String get posAddition => 'Addition';

  @override
  String get setAdditionButton => 'Addition button';

  @override
  String get additionPrinted => 'Addition printed';

  @override
  String get posOrder => 'Order';

  @override
  String get posBookings => 'Bookings';

  @override
  String get posPromos => 'Promos';

  @override
  String get posVoid => 'VOID';

  @override
  String get posPay => 'PAY';

  @override
  String productRunningLow(String product) {
    return '$product is running low';
  }

  @override
  String productOutOfStock(String product) {
    return '$product is out of stock';
  }

  @override
  String get availableIn => 'Available in:';

  @override
  String quantityInStock(String qty) {
    return '$qty in stock';
  }

  @override
  String get noCompanySelected =>
      'No company selected. Open the menu and pick a company.';

  @override
  String get errorLoadingData => 'Error loading data';

  @override
  String get searchProductsHint => 'Search products...';

  @override
  String get paginationFirst => 'First';

  @override
  String get paginationPrevious => 'Previous';

  @override
  String get paginationNext => 'Next';

  @override
  String get paginationLast => 'Last';

  @override
  String get voidOrder => 'Void order';

  @override
  String get voidOrderConfirm => 'Are you sure you want to void this order?';

  @override
  String get enterVoidReason => 'Enter void reason here';

  @override
  String get refreshOrderNumber => 'Refresh order number';

  @override
  String get setSalePrice => 'Set Sale Price';

  @override
  String get fieldPrice => 'Price';

  @override
  String get ageRestriction => 'Age Restriction';

  @override
  String confirmMinimumAge(String minAge) {
    return 'Confirm ($minAge+)';
  }

  @override
  String commentsForProduct(String product) {
    return 'Comments: $product';
  }

  @override
  String get customComment => 'Custom comment';

  @override
  String get addANoteHint => 'Add a note...';

  @override
  String get noTaxesAvailable => 'No taxes available in system.';

  @override
  String get transferOrder => 'Transfer Order';

  @override
  String get assignStaff => 'Assign Staff';

  @override
  String get unassigned => 'Unassigned';

  @override
  String get assignRoomOrResource => 'Assign Room / Resource';

  @override
  String get noRoom => 'No room';

  @override
  String selectAvailableSpace(String space) {
    return 'Select Available $space';
  }

  @override
  String get errorMissingCompanyContext =>
      'Error: missing company or user context.';

  @override
  String failedToQueueZReport(String message) {
    return 'Failed to queue Z-Report: $message';
  }

  @override
  String zReportNumber(String number) {
    return 'Z-Report #$number';
  }

  @override
  String get shiftSummaryUpper => 'SHIFT SUMMARY';

  @override
  String get dateTimeLabel => 'Date/Time';

  @override
  String get rangeLabel => 'Range';

  @override
  String get totalSales => 'Total Sales';

  @override
  String get totalReturns => 'Total Returns';

  @override
  String get discountsLabel => 'Discounts';

  @override
  String get taxableTotal => 'Taxable Total';

  @override
  String get totalTax => 'Total Tax';

  @override
  String get cashMovementsUpper => 'CASH MOVEMENTS';

  @override
  String get tenderTypesUpper => 'TENDER TYPES';

  @override
  String get noPaymentsRecorded => 'No payments recorded.';

  @override
  String get grandTotalUpper => 'GRAND TOTAL';

  @override
  String get unknownLabel => 'Unknown';

  @override
  String get currentShiftOpen => 'Current Shift (Open)';

  @override
  String get historyZReports => 'History (Z-Reports)';

  @override
  String get noOpenTransactions =>
      'No open transactions.\nThe register is balanced.';

  @override
  String get tenderBreakdown => 'Tender Breakdown';

  @override
  String get expectedInDrawer => 'EXPECTED IN DRAWER';

  @override
  String get shiftDetails => 'Shift Details';

  @override
  String get cashierOnDuty => 'Cashier on Duty';

  @override
  String get unknownUser => 'UNKNOWN USER';

  @override
  String get transactionsLabel => 'Transactions';

  @override
  String openPaymentsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open payments',
      one: '1 open payment',
    );
    return '$_temp0';
  }

  @override
  String get shiftIsOpen => 'Shift is Open';

  @override
  String get closeRegisterExplain =>
      'Closing the register will finalize these transactions, generate a Z-Report, and reset the day\'s totals. Ensure cash drops are complete before proceeding.';

  @override
  String get noZReportsYet => 'No Z-Reports generated yet.';

  @override
  String zReportOnDate(String date) {
    return 'Z-Report • $date';
  }

  @override
  String zReportSubtitle(String count, String total) {
    return 'Documents: $count  •  Grand Total: $total';
  }

  @override
  String get enterValidAmount => 'Please enter a valid amount.';

  @override
  String get selectDocumentOrAutoDistribute =>
      'Please select at least one document, or enable Automatic distribution.';

  @override
  String get nothingToSettle =>
      'Nothing to settle — the selected documents are already paid.';

  @override
  String anErrorOccurred(String message) {
    return 'An error occurred: $message';
  }

  @override
  String get useCustomerBalance => 'Use customer balance';

  @override
  String get automaticDistribution => 'Automatic distribution';

  @override
  String get loadUnpaidDocuments => 'Load unpaid documents';

  @override
  String get summaryLabel => 'Summary';

  @override
  String get customerBalance => 'Customer balance';

  @override
  String get totalInSelectedDocuments => 'Total in selected documents';

  @override
  String get customerNotSelectedReconcile =>
      'Customer not selected.\nPlease select customer for reconciliation.';

  @override
  String get autoDistributeExplain =>
      'Paid amount will be automatically distributed\nacross all unpaid sales.';

  @override
  String get noUnpaidDocumentsForCustomer =>
      'No unpaid documents found for this customer.';

  @override
  String get balanceLabel => 'Balance';

  @override
  String get internalNoteLabel => 'Internal note';

  @override
  String get allDates => 'All dates';

  @override
  String userNumbered(String id) {
    return 'User $id';
  }

  @override
  String get periodLabel => 'Period';

  @override
  String get docSearchHint => 'Search documents, or pick a filter';

  @override
  String get filterSuggestionsSection => 'Search for';

  @override
  String filterNumberContains(Object query) {
    return 'Number contains \"$query\"';
  }

  @override
  String filterReferenceContains(Object query) {
    return 'Reference contains \"$query\"';
  }

  @override
  String filterCustomerContains(Object query) {
    return 'Customer contains \"$query\"';
  }

  @override
  String get filterCustomRange => 'Custom range...';

  @override
  String get filterKeepTyping => 'Keep typing to narrow this list';

  @override
  String get documentNumber => 'Document number';

  @override
  String get documentNumberHint => 'e.g. 26-200-000001';

  @override
  String get externalDocument => 'External document';

  @override
  String get paidStatus => 'Paid status';

  @override
  String get totalResultsUpper => 'TOTAL RESULTS';

  @override
  String get noDocumentsMatchingFilters => 'No documents matching filters.';

  @override
  String get notAvailableShort => 'N/A';

  @override
  String get documentDeleted => 'Document deleted';

  @override
  String get deleteFailed => 'Delete failed';

  @override
  String get monthAbbreviations =>
      'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';

  @override
  String get selectDocumentTypeError => 'Please select a document type.';

  @override
  String get selectCustomerSupplierError =>
      'Please select a customer/supplier.';

  @override
  String get selectUserError => 'Please select a user.';

  @override
  String get selectWarehouseError => 'Please select a warehouse.';

  @override
  String get couldNotResolveLocalDocument =>
      'Could not resolve the local document.';

  @override
  String get documentSaved => 'Document saved!';

  @override
  String get newDocument => 'New Document';

  @override
  String editDocumentNumbered(String number) {
    return 'Edit Document — $number';
  }

  @override
  String documentNumbered(String number) {
    return 'Document — $number';
  }

  @override
  String saveHeaderFirstHint(String action) {
    return 'Save the document header first (Document Info → $action) to manage items, discounts and payments.';
  }

  @override
  String get documentInfo => 'Document Info';

  @override
  String get partiesLogistics => 'Parties & Logistics';

  @override
  String get financialsNotes => 'Financials & Notes';

  @override
  String get documentItems => 'Document Items';

  @override
  String get paymentsTab => 'Payments';

  @override
  String get dueDate => 'Due Date';

  @override
  String get stockDate => 'Stock Date';

  @override
  String get supplierRequired => 'Supplier *';

  @override
  String get applyAfterTax => 'Apply after tax';

  @override
  String get saveHeaderChanges => 'Save Header Changes';

  @override
  String get createAndAddItems => 'Create & Add Items';

  @override
  String get noItemsAddedYet => 'No items added yet.';

  @override
  String get clickAddProductToStart => 'Click \'Add Product\' to get started.';

  @override
  String get qtyShort => 'Qty';

  @override
  String get itemDiscShort => 'Item Disc.';

  @override
  String get actionsLabel => 'Actions';

  @override
  String get deleteItem => 'Delete Item';

  @override
  String deleteItemConfirm(String name) {
    return 'Delete \'$name\'?';
  }

  @override
  String get itemsBaseTotal => 'Items Base Total:';

  @override
  String get selectProductError => 'Please select a product.';

  @override
  String failedToAddItem(String message) {
    return 'Failed to add item: $message';
  }

  @override
  String updateFailedWithMessage(String message) {
    return 'Update failed: $message';
  }

  @override
  String get itemTax => 'Item Tax';

  @override
  String get appliedPayments => 'Applied Payments';

  @override
  String get deleteAllPaymentsWarning =>
      'This document has a complete payment balance.\n\nProceeding will permanently delete all associated payment transactions. Are you sure?';

  @override
  String get documentTotal => 'Document Total';

  @override
  String get totalPaid => 'Total Paid';

  @override
  String get remainingBalance => 'Remaining Balance';

  @override
  String get noPaymentsAddedYet => 'No payments added yet.';

  @override
  String get deletePayment => 'Delete Payment';

  @override
  String get deletePaymentConfirm =>
      'Are you sure you want to delete this payment?';

  @override
  String get selectPaymentTypeError => 'Please select a payment type.';

  @override
  String get failedToAddPayment => 'Failed to add payment.';

  @override
  String get updateFailedShort => 'Update failed.';

  @override
  String paymentTypeNamed(String name) {
    return 'Payment Type: $name';
  }

  @override
  String get discountLabel => 'Discount';

  @override
  String get orderNumberLabel => 'Order number';

  @override
  String get updatedLabel => 'Updated';

  @override
  String get statusGracePeriod => 'Renewal overdue';

  @override
  String get actionCreate => 'Create';

  @override
  String get activeDevices => 'Active Devices';

  @override
  String get addAtLeastOneProduct =>
      'Add at least one product to the promotion';

  @override
  String get addCustomerSupplier => 'Add Customer / Supplier';

  @override
  String get addToPromotion => 'Add to promotion';

  @override
  String get administrator => 'Administrator';

  @override
  String get allStockEntriesUpper => 'ALL STOCK ENTRIES';

  @override
  String get assignAddStock => 'Assign / Add Stock';

  @override
  String get barcodesTab => 'Barcodes';

  @override
  String cannotDeleteProductsLinked(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Can\'t delete $count products — linked to existing orders or documents',
      one: 'Can\'t delete 1 product — linked to existing orders or documents',
    );
    return '$_temp0';
  }

  @override
  String get clearEstimate => 'Clear estimate';

  @override
  String codeWithValue(String code) {
    return 'Code: $code';
  }

  @override
  String get commentsTab => 'Comments';

  @override
  String get companyUpdatedSuccessfully => 'Company updated successfully';

  @override
  String get conditionalPromoHint => 'Conditional (e.g. Buy 2, get discount)';

  @override
  String get costPrice => 'Cost Price';

  @override
  String couldNotDeleteNamed(String name, String message) {
    return 'Could not delete \"$name\": $message';
  }

  @override
  String couldNotSaveNamed(String name, String message) {
    return 'Could not save \"$name\": $message';
  }

  @override
  String get countriesLabel => 'Countries';

  @override
  String get createEstimate => 'Create estimate';

  @override
  String get createPromotion => 'Create Promotion';

  @override
  String get customerAdded => 'Customer added';

  @override
  String get customerUpdated => 'Customer updated';

  @override
  String get daysOfWeekLabel => 'Days of Week: ';

  @override
  String deleteWithCount(num count) {
    return 'Delete ($count)';
  }

  @override
  String deletedSomeProductsBlocked(num deleted, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$deleted deleted · $count products kept — linked to existing orders or documents',
      one:
          '$deleted deleted · 1 product kept — linked to existing orders or documents',
    );
    return '$_temp0';
  }

  @override
  String get deletedSuccessfully => 'Deleted successfully';

  @override
  String get designFloorPlans => 'Design floor plans';

  @override
  String get detailsTab => 'Details';

  @override
  String get deviceRevokedSuccessfully => 'Device revoked successfully';

  @override
  String get displayRank => 'Display Rank';

  @override
  String get dueDatePeriodDays => 'Due Date Period (days)';

  @override
  String get editCustomer => 'Edit Customer';

  @override
  String get editProduct => 'Edit Product';

  @override
  String get editPromotion => 'Edit Promotion';

  @override
  String get editQuantity => 'Edit quantity';

  @override
  String get endDateBeforeStartDate => 'End date is before the start date';

  @override
  String get everyDay => 'Every day';

  @override
  String exportFailed(String message) {
    return 'Export failed: $message';
  }

  @override
  String exportedProductsTo(num count, String path) {
    return 'Exported $count products to $path';
  }

  @override
  String get failedToCreateUser => 'Failed to create user.';

  @override
  String get failedToSaveChanges => 'Failed to save changes.';

  @override
  String get failedToUpdateUser => 'Failed to update user.';

  @override
  String get failedToUploadLogo => 'Failed to upload logo.';

  @override
  String get finishSetup => 'Finish Setup';

  @override
  String get flagLow => 'LOW';

  @override
  String get flagReorder => 'REORDER';

  @override
  String get floorPlanTables => 'Floor plan / tables';

  @override
  String get folderColor => 'Folder Color';

  @override
  String get folderImage => 'Folder Image';

  @override
  String get forceReset => 'Force Reset';

  @override
  String get groupDeleted => 'Group deleted';

  @override
  String get groupHasChildrenCannotDelete =>
      'This group has products or sub-groups and cannot be deleted.';

  @override
  String get groupName => 'Group Name';

  @override
  String get groupNameHint => 'e.g., Beverages, Desserts';

  @override
  String itemsCountValue(num count) {
    return 'Items: $count';
  }

  @override
  String linkedAt(String date) {
    return 'Linked: $date';
  }

  @override
  String get logoUpdatedSuccessfully => 'Logo updated successfully';

  @override
  String get lowStockWarningHelp => 'Alert when stock falls below threshold';

  @override
  String get nameIsRequired => 'Name is required.';

  @override
  String get nameIsRequiredShort => 'Name is required';

  @override
  String get newPasswordsDoNotMatch => 'New passwords do not match';

  @override
  String get newProduct => 'New Product';

  @override
  String get newProductGroup => 'New Product Group';

  @override
  String get nextTaxesAndStock => 'Next: Taxes & Stock';

  @override
  String get noActiveDevicesFound => 'No active devices found.';

  @override
  String get noConnectionAddUsers =>
      'No connection. Adding users requires connectivity.';

  @override
  String get noConnectionDeleteUsers =>
      'No connection. Deleting users requires connectivity.';

  @override
  String get noCountriesAvailable => 'No countries available.';

  @override
  String get noCustomersFound => 'No customers found.';

  @override
  String get noEmailProvided => 'No email provided';

  @override
  String get noLogoUploadedYet => 'No logo uploaded yet';

  @override
  String noProductsMatchQuery(String query) {
    return 'No products match \"$query\"';
  }

  @override
  String get noPromotionsYet =>
      'No promotions yet. Tap \"Add Promotion\" to create one.';

  @override
  String get noSuppliersFound => 'No suppliers found.';

  @override
  String onBelowValue(num value) {
    return 'On — below $value';
  }

  @override
  String get operationFailed => 'Operation failed.';

  @override
  String get overrideTaxes => 'Override taxes';

  @override
  String get parentFolder => 'Parent Folder';

  @override
  String get passwordForciblyReset => 'Password forcibly reset!';

  @override
  String get passwordUpdatedSuccessfully => 'Password updated successfully';

  @override
  String get pendingSyncNew => 'Pending sync (new)';

  @override
  String get pendingSyncUpdate => 'Pending sync (update)';

  @override
  String get pinForciblyResetForDevice => 'PIN forcibly reset for this Device!';

  @override
  String get pinMustBeFourDigits => 'PIN must be 4 digits';

  @override
  String get pinUpdatedSuccessfully => 'PIN updated successfully';

  @override
  String get pleaseEnterProductName => 'Please enter a Product Name.';

  @override
  String get pleaseSelectACountry => 'Please select a country.';

  @override
  String get preferredQty => 'Preferred Qty';

  @override
  String get preferredQuantityHelp => 'Target quantity to maintain in stock';

  @override
  String productIdLabel(num id) {
    return 'Product ID: $id';
  }

  @override
  String get productSavedLocallySyncFirst =>
      'Product saved locally. Sync to complete setup (taxes, barcodes, stock).';

  @override
  String get productUpdatedSuccessfully => 'Product updated successfully!';

  @override
  String get productsAssigned => 'Products assigned successfully';

  @override
  String productsDeletedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products deleted',
      one: '1 product deleted',
    );
    return '$_temp0';
  }

  @override
  String promotionsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Promotions',
      one: '1 Promotion',
    );
    return '$_temp0';
  }

  @override
  String get quickInventory => 'Quick inventory';

  @override
  String get removeFromPromotion => 'Remove from promotion';

  @override
  String removeStockFromWarehouseConfirm(String product, String warehouse) {
    return 'Remove $product from $warehouse?';
  }

  @override
  String get reorderPointHelp =>
      'Trigger reorder when stock drops below this level';

  @override
  String get reprintReceipt => 'Reprint receipt';

  @override
  String get requiredField => 'Required';

  @override
  String saveAssignmentsCount(num count) {
    return 'Save Assignments ($count selected)';
  }

  @override
  String get saveCompanyChangesUpper => 'SAVE COMPANY CHANGES';

  @override
  String get saveFailedShort => 'Save failed.';

  @override
  String savedLocallyNoServerId(String name) {
    return 'Saved \"$name\" locally, but the server did not return an id. It will be re-sent on the next sync.';
  }

  @override
  String get savedLocallyWillSyncOnline =>
      'Saved locally. Will sync when online.';

  @override
  String get savedOfflineWillSync => 'Saved offline. Will sync when connected.';

  @override
  String savedOfflineWillSyncNamed(String name) {
    return '\"$name\" saved offline — it will sync when the server is back.';
  }

  @override
  String get savingUpper => 'SAVING...';

  @override
  String get scanOrEnterBarcode => 'Scan or enter barcode';

  @override
  String securityRuleUpdated(String rule) {
    return '$rule updated.';
  }

  @override
  String get securityRules => 'Security Rules';

  @override
  String get selectAtLeastOneDay => 'Select at least one day of the week';

  @override
  String get selectProductsFromLeft =>
      'Select products from the left to add to the promotion.';

  @override
  String get selectedProducts => 'Selected Products';

  @override
  String get sellingPrice => 'Selling Price';

  @override
  String get serverErrorCheckInputs =>
      'A server error occurred. Please check your inputs.';

  @override
  String get serviceTag => 'Service';

  @override
  String setTaxesAndInventoryFor(String name) {
    return 'Set Taxes & Inventory: $name';
  }

  @override
  String get setupComplete => 'Setup Complete!';

  @override
  String get startingCashLower => 'Starting cash';

  @override
  String get statusInactive => 'Inactive';

  @override
  String get stockControlRules => 'Stock Control Rules';

  @override
  String get stockControlRulesUpper => 'STOCK CONTROL RULES';

  @override
  String get stockInWarehouseUpper => 'STOCK IN WAREHOUSE';

  @override
  String stockRulesForProduct(String name) {
    return 'Stock Rules — $name';
  }

  @override
  String get stockStatusHealthy => 'Stock healthy';

  @override
  String get stockStatusLow => 'Low stock — at/below warning level';

  @override
  String get stockStatusReorder => 'At/below reorder point';

  @override
  String get suggestedOrder => 'Suggested Order';

  @override
  String suggestedOrderValue(String qty, num target) {
    return '+$qty to reach $target';
  }

  @override
  String get tapCameraIconToChangeLogo => 'Tap the camera icon to change logo';

  @override
  String get thisDevice => 'This Device';

  @override
  String get unexpectedErrorOccurred => 'An unexpected error occurred.';

  @override
  String get unexpectedErrorTryAgain =>
      'An unexpected error occurred. Please try again.';

  @override
  String uomWithValue(String unit) {
    return 'UOM: $unit';
  }

  @override
  String get updateFailed => 'Update failed';

  @override
  String get userDeletedSuccessfully => 'User deleted successfully.';

  @override
  String get userProfileLower => 'User profile';

  @override
  String get viewAllOpenOrders => 'View all open orders';

  @override
  String get viewCostPrices => 'View cost prices';

  @override
  String get voidItem => 'Void item';

  @override
  String get warningThresholdHelp =>
      'Show warning when quantity is below this value';

  @override
  String get weekdayAbbreviations => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String get weekdays => 'Weekdays';

  @override
  String get weekends => 'Weekends';

  @override
  String get willDeleteWhenConnectionRestored =>
      'Will delete when connection is restored';

  @override
  String get zeroStockQuantitySale => 'Zero stock quantity sale';

  @override
  String addressWithValue(String address) {
    return 'Address: $address';
  }

  @override
  String get beginTrackingSession =>
      'Begin a tracking session to clock your hours.';

  @override
  String cashEntriesCount(num count) {
    return 'Cash entries ($count)';
  }

  @override
  String checkoutError(String message) {
    return 'Checkout error: $message';
  }

  @override
  String get clockOutMustBeAfterClockIn => 'Clock-out must be after clock-in.';

  @override
  String get completeTransaction => 'Complete\nTransaction';

  @override
  String couldNotLoadEntries(String message) {
    return 'Could not load entries: $message';
  }

  @override
  String get creditNeedsCustomer =>
      'Credit payment requires a selected customer.\n\nPlease choose a customer before completing this transaction.';

  @override
  String deleteDocumentConfirmPermanent(String number) {
    return 'Delete \'$number\'? This cannot be undone.';
  }

  @override
  String discountWithAmount(String amount, String symbol) {
    return 'Discount: $amount $symbol';
  }

  @override
  String documentsCountValue(num count) {
    return 'Documents count: $count';
  }

  @override
  String get enterValidAmountAboveZero =>
      'Enter a valid amount greater than zero.';

  @override
  String get exceedsMaximum => 'Exceeds maximum';

  @override
  String get failedToLoadCustomers => 'Failed to load customers';

  @override
  String get failedToLoadOrder => 'Failed to load order.';

  @override
  String featureComingSoon(String feature) {
    return '$feature — coming soon';
  }

  @override
  String get filterByCustomer => 'Filter by customer';

  @override
  String get hoursReport => 'Hours Report';

  @override
  String labelWithColon(String label) {
    return '$label: ';
  }

  @override
  String get lastMonth => 'Last month';

  @override
  String get lastWeek => 'Last week';

  @override
  String get lastYear => 'Last year';

  @override
  String maxUsableThisOrder(String points) {
    return 'Max usable this order: $points pts';
  }

  @override
  String get missingCompanyOrUserContext => 'Missing company or user context.';

  @override
  String get mySales => 'My sales';

  @override
  String get myShift => 'My Shift';

  @override
  String get noActiveShift => 'No Active Shift';

  @override
  String get noCashMovementsToday => 'No cash movements today.';

  @override
  String get noItemsForDocument => 'No items found for this document.';

  @override
  String get noOpenOrders => 'No open orders';

  @override
  String noOrdersMatchQuery(String query) {
    return 'No orders match \"$query\"';
  }

  @override
  String get noSalesDocumentsForPeriod =>
      'No sales documents for the selected period.';

  @override
  String get noTimeEntriesInRange => 'No time entries in the selected range.';

  @override
  String get nothingToExportInRange => 'Nothing to export in this range';

  @override
  String get nowSelectEndDate => 'Now select an end date';

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String pointsBalanceWorth(String points, String value, String symbol) {
    return 'Balance: $points pts = $value $symbol';
  }

  @override
  String get predefinedPeriod => 'Predefined period';

  @override
  String get receiptLabel => 'Receipt';

  @override
  String redeemingPoints(String points, String amount, String symbol) {
    return 'Redeeming $points pts (−$amount $symbol)';
  }

  @override
  String get reportCopiedAsCsv => 'Report copied to clipboard as CSV';

  @override
  String get salesHistoryTitle => 'Sales history';

  @override
  String get saveCashIn => 'Save Cash In';

  @override
  String get saveCashOut => 'Save Cash Out';

  @override
  String get selectAll => 'Select all';

  @override
  String get selectAnEmployeeError => 'Select an employee.';

  @override
  String get selectDocumentToViewItems =>
      'Select a document above to view its items.';

  @override
  String get sendEmail => 'Send email';

  @override
  String get shiftOpen => 'Shift Open';

  @override
  String get shiftStillOpen => 'Open';

  @override
  String get tapToRedeemPoints => 'Tap to redeem points';

  @override
  String taxNoWithValue(String number) {
    return 'Tax No.: $number';
  }

  @override
  String get thisMonth => 'This month';

  @override
  String get thisWeek => 'This week';

  @override
  String get thisYear => 'This year';

  @override
  String get timeCardAdded => 'Time card added';

  @override
  String totalAmountWithValue(String amount, String symbol) {
    return 'Total amount: $amount $symbol';
  }

  @override
  String get totalCompleted => 'Total (completed)';

  @override
  String get totalHours => 'Total hours';

  @override
  String totalHoursWithValue(String hours) {
    return 'Total hours: $hours';
  }

  @override
  String get weekdayInitials => 'Mo,Tu,We,Th,Fr,Sa,Su';

  @override
  String get yesterday => 'Yesterday';

  @override
  String noStockAvailableIn(String warehouse) {
    return 'No stock available in $warehouse.';
  }

  @override
  String get theSelectedWarehouse => 'the selected warehouse';

  @override
  String warehouseNumbered(String id) {
    return 'Warehouse $id';
  }

  @override
  String switchedToWarehouse(String warehouse) {
    return 'Switched to $warehouse — tap the product to add it.';
  }

  @override
  String lowStockAddAnyway(String qty, String unit) {
    return 'Adding this item leaves only $qty $unit in stock, at or below the low-stock warning level.\n\nAdd it anyway?';
  }

  @override
  String get unitsFallback => 'unit(s)';

  @override
  String kitchenPrintError(String message) {
    return 'Kitchen print error: $message';
  }

  @override
  String kitchenTicketsPrinted(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString kitchen tickets sent',
      one: 'Kitchen ticket sent',
    );
    return '$_temp0';
  }

  @override
  String get kitchenNoStationMatched =>
      'No station printer covers these items — printing the full ticket instead.';

  @override
  String couldNotSaveOrder(String message) {
    return 'Could not save order: $message';
  }

  @override
  String scaleBarcodeProductNotFound(String code) {
    return 'Scale barcode: product \"$code\" not found.';
  }

  @override
  String errorCreatingOrder(String message) {
    return 'Error creating order: $message';
  }

  @override
  String get orderSavedToTable => 'Order Saved to Table!';

  @override
  String get orderSaved => 'Order Saved!';

  @override
  String get orderVoided => 'Order Voided';

  @override
  String get orderTransferred => 'Order Transferred';

  @override
  String transferFailed(String message) {
    return 'Transfer failed: $message';
  }

  @override
  String receiptAlreadyRefunded(String reference) {
    return 'This receipt has already been refunded (Ref: $reference).';
  }

  @override
  String receiptNotFound(String number) {
    return 'Receipt \"$number\" not found.';
  }

  @override
  String get managerPinNotRecognised =>
      'Manager PIN not recognised. Blind return needs an admin.';

  @override
  String get addAtLeastOneItemToReturn => 'Add at least one item to return.';

  @override
  String get selectRefundPaymentType => 'Select a refund payment type.';

  @override
  String get blindRefundQueued =>
      'Blind refund queued — will sync automatically.';

  @override
  String blindRefundProcessed(String number) {
    return 'Blind refund $number processed.';
  }

  @override
  String get lookUpReceiptFirst => 'Look up a receipt first.';

  @override
  String get selectAtLeastOneItemToRefund =>
      'Select at least one item to refund.';

  @override
  String get refundQueued => 'Refund queued — will sync automatically.';

  @override
  String refundProcessed(String number) {
    return 'Refund $number processed.';
  }

  @override
  String get customerReceiptOptional => 'Customer\'s receipt # (optional)';

  @override
  String get optionalFromPaperReceipt => 'optional — from paper receipt';

  @override
  String get blindReturnManagerAuthorised =>
      'Blind return — manager authorised. No original receipt.';

  @override
  String get blindReturnExplain =>
      'A blind return refunds goods with no receipt. A manager must approve it.';

  @override
  String priceTimesMaxQty(String price, String qty) {
    return '$price × max $qty';
  }

  @override
  String get advancedHardware => 'Advanced / Hardware';

  @override
  String get changeAllowed => 'Change Allowed';

  @override
  String get colCustomerRequired => 'Customer Req.';

  @override
  String get colMarkPaid => 'Mark Paid';

  @override
  String get colQuickPay => 'Quick Pay';

  @override
  String get colSlip => 'Slip';

  @override
  String get coreSettings => 'Core Settings';

  @override
  String get customerRequiredLabel => 'Customer Required';

  @override
  String deleteTaxRateConfirm(String name) {
    return 'Are you sure you want to delete the tax rate \'$name\'?';
  }

  @override
  String get editPaymentType => 'Edit Payment Type';

  @override
  String get editTaxRate => 'Edit Tax Rate';

  @override
  String get enterValidNumber => 'Enter a valid number';

  @override
  String get fiscal => 'Fiscal';

  @override
  String get markAsPaid => 'Mark As Paid';

  @override
  String get oldAndNewTaxMustDiffer => 'Old and new tax must be different.';

  @override
  String get paymentTypeDeleted => 'Payment type deleted';

  @override
  String get pleaseSelectBothTaxes => 'Please select both taxes.';

  @override
  String get quickPayment => 'Quick Payment';

  @override
  String get slipRequired => 'Slip Required';

  @override
  String get switchFailed => 'Switch failed.';

  @override
  String taxRateAppliedSuccessfully(
    String rate,
    String oldName,
    String newName,
  ) {
    return 'Rate $rate from \'$oldName\' applied to \'$newName\' successfully.';
  }

  @override
  String get taxRateDeleted => 'Tax rate deleted';

  @override
  String get yearTotal => 'YEAR TOTAL';

  @override
  String get topMonth => 'TOP MONTH';

  @override
  String monthlySalesYear(String year) {
    return 'MONTHLY SALES — $year';
  }

  @override
  String activeMonthsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active months',
      one: '1 active month',
    );
    return '$_temp0';
  }

  @override
  String get periodicReports => 'Periodic Reports';

  @override
  String get selectDateRangeToFilter =>
      'Select a date range to filter the cards below';

  @override
  String get failedToLoadYearlyData => 'Failed to load yearly data';

  @override
  String get noDataToDisplay => 'No data to display';

  @override
  String get selectedPeriod => 'Selected Period';

  @override
  String get filterLabel => 'Filter';

  @override
  String get customersAndSuppliers => 'Customers & suppliers';

  @override
  String get cashRegister => 'Cash register';

  @override
  String get colImage => 'Image';

  @override
  String get fieldUnit => 'Unit';

  @override
  String get markupPercent => 'Markup %';

  @override
  String get lastPurchase => 'Last Purchase';

  @override
  String get fieldRank => 'Rank';

  @override
  String get taxInclusive => 'Tax Inclusive';

  @override
  String get priceChange => 'Price Change';

  @override
  String get businessPartnerRequired => 'Business partner (required)';

  @override
  String get addServiceType => 'Add Service Type';

  @override
  String get allValuesMustBePositive => 'All values must be positive numbers.';

  @override
  String get bookingArrived => 'Arrived';

  @override
  String get bookingCompleted => 'Completed';

  @override
  String get bookingInService => 'In Service';

  @override
  String get bookingNoShow => 'No Show';

  @override
  String get bookingPending => 'Pending';

  @override
  String couldNotCheckStock(String message) {
    return 'Could not check stock: $message';
  }

  @override
  String deleteLoyaltyCardConfirm(String name) {
    return 'Delete the loyalty card for $name? This cannot be undone.';
  }

  @override
  String earningRuleExample(String symbol) {
    return 'e.g. every 100 $symbol spent earns 10 pts';
  }

  @override
  String get editServiceType => 'Edit Service Type';

  @override
  String get editWarehouse => 'Edit Warehouse';

  @override
  String get enterValidPointsValue =>
      'Enter a valid non-negative points value.';

  @override
  String failedToAddCard(String message) {
    return 'Failed to add card: $message';
  }

  @override
  String failedToDeleteCard(String message) {
    return 'Failed to delete: $message';
  }

  @override
  String failedToUpdateCard(String message) {
    return 'Failed to update card: $message';
  }

  @override
  String guestsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guests',
      one: '1 guest',
    );
    return '$_temp0';
  }

  @override
  String get historyTab => 'History';

  @override
  String get loyaltyCardAdded => 'Loyalty card added';

  @override
  String get loyaltyCardDeleted => 'Loyalty card deleted';

  @override
  String get loyaltyCardUpdated => 'Loyalty card updated';

  @override
  String get loyaltySettingsSaved => 'Loyalty settings saved';

  @override
  String get newWarehouse => 'New Warehouse';

  @override
  String get noCardNumber => 'No card number';

  @override
  String get noCompletedBookings => 'No completed bookings yet.';

  @override
  String get noLoyaltyCardsYet => 'No loyalty cards yet.';

  @override
  String get noUpcomingBookings => 'No upcoming bookings.';

  @override
  String get onePointEquals => '1 point equals';

  @override
  String orderNumbered(String number) {
    return 'Order #$number';
  }

  @override
  String get pleaseSelectACustomer => 'Please select a customer.';

  @override
  String get pointsCannotBeNegative => 'Points cannot be negative.';

  @override
  String redemptionRuleExample(String symbol) {
    return 'e.g. 1 pt = 1 $symbol discount at checkout';
  }

  @override
  String removeNamedConfirm(String name) {
    return 'Remove \"$name\"?';
  }

  @override
  String stockMovedWarehouseDeleted(String name) {
    return 'Stock moved to $name; warehouse deleted';
  }

  @override
  String tablesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tables',
      one: '1 table',
    );
    return '$_temp0';
  }

  @override
  String get upcoming => 'Upcoming';

  @override
  String get warehouseAndStockDeleted => 'Warehouse and its stock deleted';

  @override
  String get warehouseDeleted => 'Warehouse deleted';

  @override
  String warehouseStillHoldsStock(String name, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '\'$name\' still holds $count stock items. What should happen to them before the warehouse is deleted?',
      one:
          '\'$name\' still holds 1 stock item. What should happen to it before the warehouse is deleted?',
    );
    return '$_temp0';
  }

  @override
  String get beforeTax => 'Before tax';

  @override
  String get afterTax => 'After tax';

  @override
  String get listLabel => 'List';

  @override
  String get gridLabel => 'Grid';

  @override
  String get cancelUpper => 'CANCEL';

  @override
  String get noCategory => 'No category';

  @override
  String get enterAGroupName => 'Enter a group name.';

  @override
  String categoryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return '$_temp0';
  }

  @override
  String get enterAnIpAddress => 'Enter an IP address';

  @override
  String get invalidIpWithExample => 'Invalid IP (e.g. 192.168.1.100)';

  @override
  String get invalidIp => 'Invalid IP';

  @override
  String get backupDatabase => 'Backup database';

  @override
  String get backingUpEllipsis => 'Backing up…';

  @override
  String backupSaved(String file) {
    return 'Backup saved: $file';
  }

  @override
  String backupFailed(String message) {
    return 'Backup failed: $message';
  }

  @override
  String get selectBackupFolder => 'Select Backup Folder';

  @override
  String get autoBackupExplain =>
      'Automatically create backup copies of your data to protect against loss or corruption';

  @override
  String get unitHours => 'hours';

  @override
  String get unitDays => 'days';

  @override
  String settingSaved(String setting) {
    return '$setting saved';
  }

  @override
  String get customerDisplayQrHint =>
      'Scan the QR code to open the customer display on any internet-connected device.';

  @override
  String get everythingIsSynced => 'Everything is synced';

  @override
  String get exitApplicationConfirm =>
      'Are you sure you want to exit the application?';

  @override
  String failedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count failed',
      one: '1 failed',
    );
    return '$_temp0';
  }

  @override
  String get fontSizeDefault => 'Default';

  @override
  String get fontSizeLarge => 'Large';

  @override
  String get fontSizeLarger => 'Larger';

  @override
  String get fontSizeSmall => 'Small';

  @override
  String itemsPendingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items pending',
      one: '1 item pending',
    );
    return '$_temp0';
  }

  @override
  String pendingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending',
      one: '1 pending',
    );
    return '$_temp0';
  }

  @override
  String get syncAfterEverySave => 'After every save';

  @override
  String get syncCashMovements => 'Cash movements';

  @override
  String get syncCompletedSales => 'Completed sales awaiting upload';

  @override
  String get syncCustomerDiscounts => 'Customer discounts';

  @override
  String get syncEveryHour => 'Every 1 hour';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncProductComments => 'Product comments';

  @override
  String get syncProductTaxes => 'Product taxes';

  @override
  String get syncShifts => 'Shifts';

  @override
  String get syncStatusTitle => 'Sync Status';

  @override
  String get syncStockCounts => 'Stock counts';

  @override
  String get syncStockTransfers => 'Stock transfers';

  @override
  String get syncVoids => 'Voids';

  @override
  String get syncZReports => 'Z-reports';

  @override
  String get syncedStatus => 'Synced';

  @override
  String get syncingEllipsis => 'Syncing…';

  @override
  String get backupPathHintWindows => 'e.g. D:\\database\\Backup';

  @override
  String get backupPathHintUnix => 'e.g. /home/user/backups';

  @override
  String get backupPathHintManaged =>
      'Managed by the app — tap Open location to see it';

  @override
  String get exchangeRateHint => 'e.g. 1.08  (1 primary = X secondary)';

  @override
  String get addServiceStatus => 'Add Service Status';

  @override
  String get clearFavorites => 'Clear favorites';

  @override
  String get editServiceStatus => 'Edit Service Status';

  @override
  String get hintTablesRooms => 'e.g. Tables, Rooms';

  @override
  String get hintUnitsExample => 'e.g. pcs, kg, L';

  @override
  String get includeSubgroups => 'Include subgroups';

  @override
  String get noReportsFound => 'No reports found.';

  @override
  String noSettingsMatching(String query) {
    return 'No settings found matching \'$query\'';
  }

  @override
  String get notSet => 'Not set';

  @override
  String get reportComingSoon => 'This report is coming soon.';

  @override
  String scaleErrorWithMessage(String message) {
    return 'Scale error: $message';
  }

  @override
  String get selectBusinessPartnerInFilter =>
      'Please select a business partner in the filter panel.';

  @override
  String get selectReportToViewOrPrint => 'Select report to view or print';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String ageRestrictionBody(num age) {
    return 'This product requires customers to be at least $age years old.\n\nPlease confirm the customer meets this requirement before proceeding.';
  }

  @override
  String get bookingCompletedLocked =>
      'This booking is completed and cannot be modified.';

  @override
  String get bookingPrefix => 'Booking: ';

  @override
  String get branch => 'Branch';

  @override
  String clockedInWithValue(String value) {
    return 'Clocked in · $value';
  }

  @override
  String deleteBookingConfirm(String name) {
    return 'Delete booking for \"$name\"?';
  }

  @override
  String get editBooking => 'Edit Booking';

  @override
  String errorLoadingDataWithMessage(String message) {
    return 'Error loading data: $message';
  }

  @override
  String errorLoadingSpaces(String message) {
    return 'Error loading spaces: $message';
  }

  @override
  String get exitEditMode => 'Exit Edit Mode';

  @override
  String get newBooking => 'New Booking';

  @override
  String noFreeSpacesAvailable(String space) {
    return 'No free ${space}s available';
  }

  @override
  String get openOrderNow => 'Open Order Now';

  @override
  String get removeFloorPlanConfirm =>
      'This will permanently remove the floor plan and all its tables. Continue?';

  @override
  String get sendingSignal => 'Sending signal...';

  @override
  String get shapeLabel => 'Shape';

  @override
  String get sizeLabel => 'Size';

  @override
  String get staffPrefix => '  ·  Staff: ';

  @override
  String tableNumbered(String number) {
    return 'Table #$number';
  }

  @override
  String taxesForProduct(String product) {
    return 'Taxes · $product';
  }

  @override
  String get testDrawerOpen => 'Test Drawer Open';

  @override
  String todayWithValue(String value) {
    return 'Today: $value';
  }

  @override
  String get updateStatusUpper => 'UPDATE STATUS';

  @override
  String voidReasonPrompt(String number) {
    return 'Enter or select void reason for voiding \"$number\"';
  }

  @override
  String get accessDenied => 'Access Denied';

  @override
  String get accessDeniedBody =>
      'You do not have permission to view this section.\nChoose another section from the menu, or ask an administrator for access.';

  @override
  String get accessDeniedAskAdmin =>
      'You do not have permission for this action.\nAsk an administrator to do it for you.';

  @override
  String get checkingUpper => 'CHECKING…';

  @override
  String get chooseYourMenuLayout => 'Choose your menu layout';

  @override
  String get connectingEllipsis => 'Connecting…';

  @override
  String createFirstAdminFor(String company) {
    return 'Create the first admin user for $company';
  }

  @override
  String discountAmountLine(String currency, String amount) {
    return 'Discount  −$currency $amount';
  }

  @override
  String get editCurrency => 'Edit Currency';

  @override
  String enableResource(String resource) {
    return 'Enable $resource';
  }

  @override
  String get errorLoadingRooms => 'Error loading rooms';

  @override
  String expiredOnDate(String date) {
    return 'Expired on $date';
  }

  @override
  String get getGoingInThreeSteps => 'Get going in 3 steps';

  @override
  String get managementPortal => 'Management Portal';

  @override
  String get menuLayoutHint =>
      'How products appear on the sales screen — change it anytime in Settings.';

  @override
  String get noFloorPlans => 'No Floor Plans';

  @override
  String openOrderForEachResource(String resource) {
    return 'Open an order for each $resource.';
  }

  @override
  String get poweredByPos => 'Powered by POS';

  @override
  String get reconnectingEllipsis => 'Reconnecting…';

  @override
  String get retryConnectionUpper => 'RETRY CONNECTION';

  @override
  String checkedAgainstEndpoint(String endpoint) {
    return 'Checked against $endpoint';
  }

  @override
  String scaleUnitMismatch(String scaleUnit, String productUnit) {
    return 'Scale reads $scaleUnit but this item is priced per $productUnit — no conversion is applied.';
  }

  @override
  String get selectServiceTypeForOrder => 'Select service type for this order';

  @override
  String tableHeldByReservation(String name) {
    return 'This table is held by a reservation for \"$name\".';
  }

  @override
  String get thankYou => 'Thank You!';

  @override
  String get weWillSwitchOnFeatures =>
      'We will switch on the right features for you.';

  @override
  String get whatsYourBusiness => 'What\'s your business?';

  @override
  String get changeThisLaterInSettings =>
      'You can change all of this later in Settings.';

  @override
  String get everythingBuiltIn =>
      'All of this is built in — no add-ons to buy.';

  @override
  String get everythingYouGet => 'Everything you get';

  @override
  String get getStarted => 'Get Started';

  @override
  String get linkDeviceUpper => 'LINK DEVICE';

  @override
  String numberOfProductsToImport(num count) {
    return 'Number of products to import: $count';
  }

  @override
  String get setUpYourTerminal => 'Set up your terminal';

  @override
  String get statusExpiresToday => 'Expires today';

  @override
  String get accessDeniedNoPermission =>
      'Access Denied: You do not have permission for this action.';

  @override
  String alreadyBookedDuringTime(String what, String name, String range) {
    return 'This $what is already booked during this time — $name ($range).';
  }

  @override
  String get cannotBookInPast => 'Cannot create a booking in the past.';

  @override
  String changesRejected(num count, String details) {
    return '$count changes were rejected: $details';
  }

  @override
  String get couldNotFindActiveOrder => 'Could not find active order.';

  @override
  String get couldNotOpenReservationOrder =>
      'Could not open the reservation order. It may have been completed or voided.';

  @override
  String get couldNotReachServer =>
      'Could not reach the server. Check your internet connection.';

  @override
  String get currencyDeleted => 'Currency deleted';

  @override
  String get endTimeAfterStartTime => 'End time must be after start time.';

  @override
  String failedToSaveField(String field) {
    return 'Failed to save $field';
  }

  @override
  String importFailed(String message) {
    return 'Import failed: $message';
  }

  @override
  String get licenseInvalidBody =>
      'This terminal’s license could not be verified. Please contact support to restore service.';

  @override
  String get licenseInvalidContactSupport =>
      'License is invalid. Please contact support.';

  @override
  String get licenseInvalidTitle => 'License invalid';

  @override
  String get orderNotFoundCompletedOrVoided =>
      'Order not found. It may have been completed or voided.';

  @override
  String pendingTapForStatus(num count) {
    return '$count pending — tap for sync status';
  }

  @override
  String printFailed(String message) {
    return 'Print failed: $message';
  }

  @override
  String get reservationNoLongerActive =>
      'This reservation is no longer active.';

  @override
  String get selectAtLeastOneTable => 'Please select at least one table.';

  @override
  String get selectCompanyFirst => 'Select a company first';

  @override
  String get staffMemberLower => 'staff member';

  @override
  String get subscriptionInactiveBody =>
      'Your subscription is not active. Please contact your service provider to renew, then retry the connection to continue selling.';

  @override
  String get subscriptionInactiveTitle => 'Subscription inactive';

  @override
  String get subscriptionStillInactive =>
      'Subscription is still inactive. Please contact your service provider.';

  @override
  String get syncComplete => 'Sync complete';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String syncFinishedWithFailures(String entities) {
    return 'Sync finished, but these didn\'t sync: $entities';
  }

  @override
  String get syncStatusTooltip => 'Sync status';

  @override
  String get tableNeedsBooking =>
      'This table needs a booking. Create one, then start service from it.';

  @override
  String get terminalNotLinked =>
      'This terminal is not linked. Re-link the device.';

  @override
  String get testMessageSent => 'Test message sent.';

  @override
  String get testSignalSentToDrawer => 'Test signal sent to cash drawer';

  @override
  String get urlCopied => 'URL copied';

  @override
  String get accessRulesNotSynced =>
      'Access rules haven\'t reached this device yet. Connect to the network and sync, then try again.';

  @override
  String get updateSectionTitle => 'Software update';

  @override
  String get updateAutoCheckLabel => 'Check for updates automatically';

  @override
  String get updateCheckNow => 'Check now';

  @override
  String get updateChecking => 'Checking…';

  @override
  String get updateUpToDate => 'You are on the latest version';

  @override
  String updateAvailableLabel(String version) {
    return 'Version $version is available';
  }

  @override
  String get updateDownloadAction => 'Download update';

  @override
  String updateDownloadingLabel(String percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get updateInstallAction => 'Install and restart';

  @override
  String get updateCancelAction => 'Cancel download';

  @override
  String get updateFailedLabel => 'Could not check for updates';

  @override
  String get updateBlockedByCart =>
      'Finish or clear the current sale before updating.';

  @override
  String updatePendingWarning(int count) {
    return '$count item(s) still waiting to sync. Sync first if you can.';
  }

  @override
  String get updateRestartNotice => 'The app will close to install the update.';

  @override
  String get updateUnsupportedPlatform =>
      'In-app updates are available on Windows only.';

  @override
  String updateAvailableSnackbar(String version) {
    return 'Version $version is available — open Settings › About to install it.';
  }

  @override
  String get setDocuments => 'Documents';

  @override
  String get resetDatabaseTitle => 'RESET DATABASE';

  @override
  String get resetDatabaseAction => 'Reset database';

  @override
  String get resetWarningBanner =>
      'This is a destructive operation. It deletes the selected data for your WHOLE company — every terminal loses it on its next sync. This cannot be undone.';

  @override
  String get resetStepBackupTitle => 'Backup database path';

  @override
  String get resetStepBackupSubtitle =>
      'Location where database backup will be saved';

  @override
  String get resetStepBackupHint =>
      'A backup of this device is taken before the reset. If the backup fails, the reset is cancelled.';

  @override
  String get resetBackupManagedHint => 'Managed app storage (this device)';

  @override
  String get resetStepEntitiesTitle => 'Select entities to reset';

  @override
  String get resetStepEntitiesSubtitle =>
      'Selected entities will be deleted from the database';

  @override
  String get resetStepConfirmTitle => 'Confirmation';

  @override
  String get resetStepConfirmSubtitle =>
      'Authorize and perform reset on selected entities';

  @override
  String get resetAdminPin => 'Enter administrator PIN';

  @override
  String get resetAlsoClearsDocuments =>
      'Also clears Documents — sales rows reference these.';

  @override
  String get resetDocumentsNote =>
      'Sales, orders, payments, voids, Z-reports, register sessions and cash movements. Bookings and attendance shifts are kept.';

  @override
  String get resetEverything => 'Everything';

  @override
  String get resetEverythingNote =>
      'All company data. Users and your settings are kept so you can sign back in.';

  @override
  String get resetWrongPin => 'Incorrect PIN.';

  @override
  String get resetConfirmTitle => 'Reset the database?';

  @override
  String get resetConfirmBody =>
      'This permanently deletes the selected data for your whole company, on every terminal. Only the local backup can recover it.';

  @override
  String get resetConfirmAction => 'Yes, reset';

  @override
  String get resetNoCompany => 'No company is selected on this device.';

  @override
  String get resetPhaseBackup => 'Backing up this device…';

  @override
  String get resetPhaseServer => 'Clearing account data…';

  @override
  String get resetPhaseLocal => 'Clearing this device…';

  @override
  String get resetDoneTitle => 'Reset complete';

  @override
  String get resetRestartManually =>
      'Please close and reopen the app to finish.';

  @override
  String get resetOnlyAdmins => 'Only administrators can reset the database.';

  @override
  String resetRestartingIn(int seconds) {
    return 'Restarting in $seconds…';
  }

  @override
  String resetBackupSavedTo(String path) {
    return 'Backup saved to $path';
  }

  @override
  String get restoreDatabaseTitle => 'Restore from backup';

  @override
  String get restoreDatabaseAction => 'Restore backup…';

  @override
  String get restoreDatabaseHint =>
      'Replaces everything on this terminal with a backup file. The app restarts to complete it.';

  @override
  String get restorePickTitle => 'Select a backup file (.sqlite)';

  @override
  String get restoreRejectedTitle => 'This file cannot be restored';

  @override
  String get restoreConfirmTitle => 'Restore this backup?';

  @override
  String get restoreConfirmBody =>
      'Everything currently on this terminal is replaced by the backup. Your current database is kept as pos_app.superseded.sqlite in case you picked the wrong file.';

  @override
  String get restoreConfirmAction => 'Restore and restart';

  @override
  String get restoreStagedTitle => 'Backup ready to restore';

  @override
  String get restoreStagedBody =>
      'The app will restart to swap the database in. Sign in again afterwards — any work in the backup that never reached the cloud is uploaded on the next sync.';

  @override
  String get restoreErrMissing => 'The file no longer exists.';

  @override
  String get restoreErrNotSqlite => 'That is not a database file.';

  @override
  String get restoreErrEncrypted =>
      'This backup is encrypted for a different device and cannot be opened here. Restore it on the terminal that created it, or start fresh and pull your data from the cloud.';

  @override
  String get restoreErrNotPosBackup =>
      'That is a database, but not a POS backup.';

  @override
  String restoreErrNewerSchema(int found, int supported) {
    return 'This backup was made by a newer version of the app (database v$found, this build understands v$supported). Update the app first.';
  }

  @override
  String get dbMissingTitle => 'Local database not found';

  @override
  String get dbMissingBody =>
      'The database file for this terminal is missing — it may have been deleted, moved, or be on a drive that is not connected.\n\nStarting fresh downloads your data from the cloud, but anything that never synced from this terminal cannot be recovered that way.';

  @override
  String get dbMissingRestore => 'Restore from a backup file';

  @override
  String get dbMissingFresh => 'Start fresh from the cloud';

  @override
  String get dbMissingFreshConfirm =>
      'Start fresh? Anything on this terminal that never reached the cloud will be gone.';

  @override
  String get onboardingDataTitle => 'Set up this terminal';

  @override
  String get onboardingDataSubtitle => 'How should this terminal get its data?';

  @override
  String get onboardingCloudTitle => 'Sync with the cloud';

  @override
  String get onboardingCloudBody =>
      'Sign in and download your company data. Choose this for a new terminal.';

  @override
  String get onboardingRestoreTitle => 'Restore from a backup';

  @override
  String get onboardingRestoreBody =>
      'Use a .sqlite backup from another terminal — for replacing a machine, including work that never synced.';

  @override
  String get balanceDue => 'Balance Due';

  @override
  String get telLabel => 'Tel';

  @override
  String get itemsLabel => 'Items';

  @override
  String get timeLabel => 'Time';

  @override
  String get unitPriceLabel => 'Unit price';

  @override
  String get taxInvoiceUpper => 'TAX INVOICE';

  @override
  String get billTo => 'Bill to';

  @override
  String get invoicesUpper => 'INVOICES';

  @override
  String get saveReceiptTitle => 'Save Receipt';

  @override
  String get saveGuestCheckTitle => 'Save Guest Check';

  @override
  String get saveInvoicePdfTitle => 'Save Invoice PDF';

  @override
  String get zReportUpper => 'Z-REPORT';

  @override
  String get endOfReport => '*** END OF REPORT ***';

  @override
  String get totalQty => 'Total Qty';

  @override
  String get pointsBalance => 'Points Balance';

  @override
  String get ptsShort => 'pts';

  @override
  String get invoiceNoLabel => 'Invoice No.';

  @override
  String get pointsUsed => 'Points Used';

  @override
  String get paymentStatus => 'Payment status';

  @override
  String pageNumberLabel(String number) {
    return 'Page $number';
  }

  @override
  String get createdWith => 'Created with';

  @override
  String get backupPathRequiredTitle => 'Choose a backup folder';

  @override
  String get backupPathRequiredBody =>
      'Automatic backups need a folder to write to. Pick one now — otherwise backups run to a location you did not choose.';

  @override
  String get backupPathNotSet =>
      'Automatic backups stay off until a backup folder is set.';

  @override
  String get posSession => 'POS Session';

  @override
  String get sessionNoneTitle => 'No open session';

  @override
  String get sessionNoneBody =>
      'This register is not trading yet. Open a session to start the day.';

  @override
  String get openRegister => 'Open Register';

  @override
  String get continueSelling => 'Continue Selling';

  @override
  String get sessionNumber => 'Session';

  @override
  String get sessionDevice => 'Device';

  @override
  String get sessionOpenedAt => 'Opened at';

  @override
  String get sessionOpenedBy => 'Opened by';

  @override
  String get sessionClosedBy => 'Closed by';

  @override
  String get sessionStatusLabel => 'Status';

  @override
  String get sessionOpeningCash => 'Opening cash';

  @override
  String get sessionExpectedCash => 'Expected cash';

  @override
  String get sessionCountedCash => 'Counted cash';

  @override
  String get sessionDifference => 'Difference';

  @override
  String get sessionOrders => 'Orders';

  @override
  String get sessionPaymentTotals => 'Payment totals';

  @override
  String get sessionSyncStatus => 'Synchronisation';

  @override
  String get sessionSynced => 'All synced';

  @override
  String get sessionNotSyncedYet => 'Not sent to the cloud yet';

  @override
  String sessionUnsyncedSales(int count) {
    return '$count sale(s) still on this device';
  }

  @override
  String sessionOpenOrders(int count) {
    return '$count order(s) still parked';
  }

  @override
  String get sessionCannotClose => 'Cannot close yet';

  @override
  String get sessionForceClosed => 'Force-closed';

  @override
  String get sessionLateArrivals =>
      'Late sales arrived after closing — needs reconciliation';

  @override
  String get sessionCashInferred =>
      'Cash methods are inferred — set which methods come out of the drawer in Settings → Order & Payment.';

  @override
  String get sessionOpeningCashPrompt =>
      'How much cash is in the drawer to start?';

  @override
  String get sessionHistory => 'Session history';

  @override
  String get sessionNoHistory => 'No sessions yet.';

  @override
  String get sessionConfirmOpening => 'Confirm opening';

  @override
  String get sessionInProgress => 'In Progress';

  @override
  String get sessionClosingControl => 'Closing Control';

  @override
  String get sessionClosedPosted => 'Closed & Posted';

  @override
  String get showKeypad => 'Keypad';

  @override
  String get hideKeypad => 'Hide keypad';

  @override
  String get removeLogo => 'Remove logo';

  @override
  String get removeLogoConfirm =>
      'The receipt will print the company name instead. You can upload a new logo at any time.';

  @override
  String get logoRemoved => 'Logo removed';

  @override
  String get openingControl => 'Opening Control';

  @override
  String get openingNote => 'Opening note';

  @override
  String get openingNoteHint => 'Add an opening note…';

  @override
  String get closingRegister => 'Closing Register';

  @override
  String get closingNote => 'Closing note';

  @override
  String get closingNoteHint => 'Add a closing note…';

  @override
  String sessionOrdersTotal(int count, String total) {
    return '$count documents: $total';
  }

  @override
  String get sessionExpected => 'Expected';

  @override
  String get sessionCounted => 'Counted';

  @override
  String get sessionOpeningRow => 'Opening';

  @override
  String get sessionCashInOutRow => 'Cash In / Out';

  @override
  String get sessionCashPaymentsRow => 'Payments in cash';

  @override
  String get cashCount => 'Cash Count';

  @override
  String get dailySale => 'Daily Sale';

  @override
  String get actionDiscard => 'Discard';

  @override
  String managerAuthRequired(String diff, String max) {
    return 'Difference of $diff exceeds the allowed $max. Manager authorisation is required.';
  }

  @override
  String get managerAuthorise => 'Manager authorisation';

  @override
  String get managerPinPrompt =>
      'Enter an administrator\'s PIN to authorise this difference.';

  @override
  String get managerPinWrong => 'That PIN is not an administrator PIN.';

  @override
  String get sessionRequiredTitle => 'Open the register first';

  @override
  String get sessionRequiredBody =>
      'Sales, refunds and cash movements belong to a session. Open the register to start trading.';

  @override
  String get sessionNotTradingBody =>
      'This register is being closed. Finish the closing count, then open a new session.';

  @override
  String get setRequireOpenSession => 'Require an open session to sell';

  @override
  String get sessionsTitle => 'Sessions';

  @override
  String get sessionColId => 'Session ID';

  @override
  String get sessionColPos => 'Point of Sale';

  @override
  String get sessionColOpenedBy => 'Opened By';

  @override
  String get sessionColOpening => 'Opening Date';

  @override
  String get sessionColClosing => 'Closing Date';

  @override
  String get sessionColStarting => 'Starting Balance';

  @override
  String get sessionColEnding => 'Ending Balance';

  @override
  String get sessionColTheoretical => 'Theoretical Closing';

  @override
  String get sessionColStatus => 'Status';

  @override
  String get sessionSearchHint => 'Search…';

  @override
  String sessionCountOf(int shown, int total) {
    return '$shown / $total';
  }

  @override
  String get sessionDetails => 'Session details';

  @override
  String get sessionCurrentOnThisDevice => 'Current session on this device';

  @override
  String get sessionClosedAt => 'Closed at';

  @override
  String get sessionDuration => 'Duration';

  @override
  String get sessionTotalTaken => 'Total taken';

  @override
  String get sessionCashMovements => 'Cash movements';

  @override
  String get sessionNotes => 'Notes';

  @override
  String get cashDrawer => 'Cash drawer';

  @override
  String get sessionRemoteFiguresOffline =>
      'Server unreachable — these are only this terminal\'s figures. The register\'s full takings load from the server.';

  @override
  String get sessionDocuments => 'Documents';

  @override
  String get sessionOverviewTab => 'Overview';

  @override
  String get sessionPaymentsTab => 'Payments';

  @override
  String get sessionNoPayments => 'No payments taken in this session yet.';

  @override
  String get sessionNoDocuments => 'No documents banked in this session yet.';

  @override
  String get sessionDocumentsHint => 'Tap a document to open it';

  @override
  String get sessionOpenDocumentHint => 'Tap a payment to open its document';

  @override
  String get sessionDocumentUnavailable =>
      'That document is not on this device.';

  @override
  String get developerModeHint =>
      'Shows a floating debug button on this terminal, with a barcode simulator for price and weight labels.';

  @override
  String get generateScaleBarcode => 'Scale label';

  @override
  String scaleBarcodeRuleUnusable(String pattern) {
    return 'The rule $pattern cannot generate a product barcode.';
  }

  @override
  String barcodeAlreadyUsedBy(String code, String product) {
    return '$code already belongs to $product.';
  }

  @override
  String get setPosSession => 'POS session';

  @override
  String get setCashMethods => 'Cash methods';

  @override
  String get cashMethodsHint =>
      'Which payment methods come out of the cash drawer and get physically counted at closing. Clearing all of them goes back to guessing.';

  @override
  String get cashMethodsInferredHint =>
      'Not set yet — these are guessed from \"change allowed\".';

  @override
  String get cashMethodsConfirm => 'Use these';

  @override
  String get noPaymentMethodsDefined => 'No payment methods defined.';

  @override
  String get setMaxCashDifference => 'Allowed cash difference';

  @override
  String get maxCashDifferenceHint =>
      'Beyond this, closing the drawer needs an administrator PIN.';

  @override
  String get cashDrawerTransport => 'How the drawer is connected';

  @override
  String get cashDrawerTransportPrinter => 'Through the receipt printer (RJ11)';

  @override
  String get cashDrawerTransportNetwork => 'Network — printer or drawer IP';

  @override
  String get cashDrawerTransportSerial => 'Serial port (COM)';

  @override
  String get cashDrawerTransportHint =>
      'Where the open signal is sent. Most drawers plug into the receipt printer\'s RJ11 port.';

  @override
  String get cashDrawerHost => 'IP address';

  @override
  String get cashDrawerTcpPort => 'Port';

  @override
  String get cashDrawerSerialPortLabel => 'COM port';

  @override
  String get cashDrawerBaudRate => 'Baud rate';

  @override
  String get cashDrawerOpenedOk => 'Cash drawer signal sent';

  @override
  String cashDrawerFailed(String error) {
    return 'Could not open the cash drawer: $error';
  }

  @override
  String get cashDrawerTransportUnavailable =>
      'This connection is not available on this device.';

  @override
  String get cashDrawerNotConfigured =>
      'No cash drawer is set up on this terminal. Turn one on in Settings → Printers → Cash Drawer.';

  @override
  String get posOpenDrawer => 'Open Drawer';

  @override
  String get setSounds => 'Sounds';

  @override
  String get setSoundsEnabled => 'Enable sounds';

  @override
  String get setSoundVolume => 'Volume';

  @override
  String get setSoundScanOk => 'Scan accepted';

  @override
  String get setSoundScanFail => 'Scan rejected';

  @override
  String get setSoundCheckout => 'Sale completed';

  @override
  String get setSoundError => 'Error message';

  @override
  String get soundsHint =>
      'Short tones played at the till. Press play to hear one.';

  @override
  String get playSound => 'Play this sound';

  @override
  String get printZReport => 'Print Z Report';

  @override
  String get zReportPreview => 'Z Report — preview';

  @override
  String get nothingToReport =>
      'Nothing to report — no payments have been taken.';

  @override
  String get modifierGroups => 'Modifier Groups';

  @override
  String get modifierGroupsHint =>
      'A group is a set of choices — \"Toppings\", \"Doneness\". Build it once here, then attach it to as many products as you like from the product\'s Modifiers tab.';

  @override
  String get addModifierGroup => 'New group';

  @override
  String get editModifierGroup => 'Edit group';

  @override
  String get noModifierGroupsYet => 'No modifier groups yet';

  @override
  String get modifierGroupNameHint => 'Toppings';

  @override
  String get modifierOptionsTitle => 'Choices';

  @override
  String get addModifierOption => 'Add a choice';

  @override
  String get optionNameHint => 'Extra cheese';

  @override
  String get extraPrice => 'Extra price';

  @override
  String get minSelections => 'Must choose at least';

  @override
  String get maxSelections => 'May choose at most';

  @override
  String get selectionRuleOptionalOne => 'Optional · pick one';

  @override
  String selectionRuleOptionalMany(int max) {
    return 'Optional · pick up to $max';
  }

  @override
  String get selectionRuleExactlyOne => 'Required · pick one';

  @override
  String selectionRuleRange(int min, int max) {
    return 'Required · pick $min to $max';
  }

  @override
  String get allowFreeText => 'Allow a typed note';

  @override
  String get allowFreeTextHint =>
      'Adds a free-text box to this section, for things like \"no ice\" or \"allergic to nuts\".';

  @override
  String get groupIsDisabled => 'Disabled';

  @override
  String get groupEnabled => 'Available at the till';

  @override
  String optionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count choices',
      one: '1 choice',
      zero: 'no choices',
    );
    return '$_temp0';
  }

  @override
  String deleteModifierGroupQ(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteModifierGroupBody =>
      'It will be removed from every product that offers it. Past sales keep their own copy and are not affected.';

  @override
  String get disableRatherThanDelete =>
      'Turning a group off is usually better than deleting it — the change reaches every till on the next sync, while a delete only reaches them on a full one.';

  @override
  String get modifierGroupSaved => 'Group saved';

  @override
  String get aGroupNeedsAName => 'The group needs a name';

  @override
  String get mandatoryNeedsOptions =>
      'A required group needs at least one choice, or the product could never be sold.';

  @override
  String minCannotExceedChoices(int min, int count) {
    return 'You are asking for $min choices but only listed $count.';
  }

  @override
  String get productModifierGroups => 'Modifier groups';

  @override
  String get productModifierGroupsHint =>
      'Tapping this product at the till will ask for these, in this order.';

  @override
  String get noGroupsAttached =>
      'No groups attached — this product is added straight to the cart.';

  @override
  String get attachModifierGroup => 'Attach a group';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get chooseAModifierGroup => 'Choose a group';

  @override
  String get noModifierGroupsExistYet =>
      'You have not built any modifier groups yet. Create one in Management → Modifier Groups, then come back and attach it here.';

  @override
  String get allModifierGroupsAttached => 'Every group is already attached';

  @override
  String get dragToReorderGroups =>
      'Drag to change the order the cashier is asked.';

  @override
  String get dragToReorderColumns => 'Drag to change the column order';

  @override
  String get noResultsForFilters => 'No results for these filters';

  @override
  String get colSelectionRule => 'Selection rule';

  @override
  String get posModifiers => 'Modifiers';

  @override
  String get setModifiersButton => 'Modifiers button';

  @override
  String customizeItem(String name) {
    return 'Customize $name';
  }

  @override
  String get addToOrder => 'Add to order';

  @override
  String chooseAtLeastN(int min) {
    return 'Choose at least $min';
  }

  @override
  String get aNoteForTheKitchen => 'Note for the kitchen';

  @override
  String get aNoteHint => 'no ice, allergic to nuts…';

  @override
  String get maxReachedForGroup => 'Limit reached';

  @override
  String get editChoices => 'Edit choices';

  @override
  String get tagRequired => 'Required';

  @override
  String get tagDone => 'Done';

  @override
  String get tagOptional => 'Optional';

  @override
  String get customizeEyebrow => 'CUSTOMIZE';

  @override
  String get groupIcon => 'Icon';

  @override
  String get groupIconHint => 'Shown beside this group at the till. Optional.';

  @override
  String get iconNone => 'None';

  @override
  String get iconBurger => 'Burger';

  @override
  String get iconPizza => 'Pizza';

  @override
  String get iconMeal => 'Meal';

  @override
  String get iconSide => 'Side';

  @override
  String get iconSauce => 'Sauce';

  @override
  String get iconDrink => 'Drink';

  @override
  String get iconDessert => 'Dessert';

  @override
  String get iconSpice => 'Spice';

  @override
  String get rptTitleSalesByProduct => 'SALES BY PRODUCT';

  @override
  String get rptTitleSalesByGroup => 'SALES BY PRODUCT GROUPS';

  @override
  String get rptTitleSalesTax => 'SALES TAX';

  @override
  String get rptTitleSalesByCustomer => 'SALES BY CUSTOMER';

  @override
  String get rptTitlePaymentByCustomer => 'PAYMENT TYPES BY CUSTOMERS';

  @override
  String get rptTitlePaymentByUser => 'PAYMENT TYPES BY USERS';

  @override
  String get rptTitlePaymentTypes => 'SALES BY PAYMENT TYPES';

  @override
  String get rptTitleItemList => 'SALES ITEM LIST';

  @override
  String get rptTitleProfit => 'PROFIT';

  @override
  String get rptTitleStockMovement => 'STOCK MOVEMENT';

  @override
  String get rptTitleItemDiscounts => 'ITEMS DISCOUNTS';

  @override
  String get rptTitleDiscountsBySource => 'DISCOUNTS BY SOURCE';

  @override
  String get rptTitleDiscountsGranted => 'DISCOUNTS GRANTED (AFTER TAX)';

  @override
  String get rptTitleVoidedItems => 'VOIDED ITEMS';

  @override
  String get rptTitleStartingCash => 'STARTING CASH ENTRIES';

  @override
  String get rptTitleUnpaidSales => 'UNPAID SALES';

  @override
  String get rptTitleHourlyByGroup => 'HOURLY SALES BY PRODUCT GROUPS';

  @override
  String get rptTitleByTable => 'SALES BY TABLE / ORDER NUMBER';

  @override
  String get rptTitleHourlySales => 'HOURLY SALES';

  @override
  String get rptTitleDailySales => 'DAILY SALES';

  @override
  String get rptTitleInvoices => 'INVOICES';

  @override
  String get rptTitleRefunds => 'REFUNDS';

  @override
  String get rptTitleSalesByUsers => 'SALES BY USERS';

  @override
  String get rptTitleUnpaidPurchase => 'UNPAID PURCHASE';

  @override
  String get rptTitlePurchaseBySupplier => 'PURCHASE BY SUPPLIER';

  @override
  String get rptTitlePurchaseByProduct => 'PURCHASE BY PRODUCT';

  @override
  String get rptTitleExpirationDate => 'EXPIRATION DATE';

  @override
  String get rptTitlePurchaseTax => 'PURCHASE TAX';

  @override
  String get rptTitlePurchaseInvoices => 'PURCHASE INVOICES';

  @override
  String get rptTitlePurchasedItemDiscounts => 'PURCHASED ITEMS DISCOUNTS';

  @override
  String get rptTitlePurchaseDiscounts => 'PURCHASE DISCOUNTS';

  @override
  String get rptTitleStockReturns => 'STOCK RETURNS BY PRODUCT';

  @override
  String get rptTitleLossAndDamage => 'LOSS AND DAMAGE BY PRODUCT';

  @override
  String get rptTitleReorderList => 'REORDER PRODUCT LIST';

  @override
  String get rptTitleLowStock => 'LOW STOCK WARNING';

  @override
  String get rptTitleTransactionHistory => 'TRANSACTION HISTORY';

  @override
  String get rptTitleStockReport => 'STOCK REPORT';

  @override
  String get rptColUom => 'UOM';

  @override
  String get rptColTaxName => 'Tax name';

  @override
  String get rptColRefNumber => 'Ref. number';

  @override
  String get rptColRefShort => 'Ref. #';

  @override
  String get rptColDocument => 'Document';

  @override
  String get rptColDocumentShort => 'Document #';

  @override
  String get rptColCustomerCode => 'Customer code';

  @override
  String get rptColTotalTax => 'Total tax';

  @override
  String get rptColCreateDate => 'Create date';

  @override
  String get rptColProfit => 'Profit';

  @override
  String get rptColMargin => 'Margin';

  @override
  String get rptColNumSales => 'Num. of sales';

  @override
  String get rptColNumberOfSales => 'Number of sales';

  @override
  String get rptColSalesCount => 'Sales count';

  @override
  String get rptColAverageSale => 'Average sale';

  @override
  String get rptColTotalSales => 'Total sales';

  @override
  String get rptColHours => 'Hours';

  @override
  String get rptColTotalDiscount => 'Total discount';

  @override
  String get rptColDiscountSource => 'Discount source';

  @override
  String get rptColTotalBeforeDisc => 'Total before disc.';

  @override
  String get rptColTotalAfterDisc => 'Total after disc.';

  @override
  String get rptColDiscountGranted => 'Discount granted';

  @override
  String get rptColBeforeDisc => 'Before disc.';

  @override
  String get rptColAfterDisc => 'After disc.';

  @override
  String get rptColTotalDisc => 'Total disc.';

  @override
  String get rptColTotalPaid => 'Total paid';

  @override
  String get rptColTotalUnpaid => 'Total unpaid';

  @override
  String get rptColDueDate => 'Due date';

  @override
  String get rptColVoidedBy => 'Voided by';

  @override
  String get rptColVoided => 'Voided';

  @override
  String get rptColCreated => 'Created';

  @override
  String get rptColReason => 'Reason';

  @override
  String get rptColQtyShort => 'Qty.';

  @override
  String get rptColOrderNo => 'Order #';

  @override
  String get rptColPaymentMethod => 'Payment method';

  @override
  String get rptColPurchaseNumber => 'Purchase number';

  @override
  String get rptColExpirationDate => 'Expiration date';

  @override
  String get rptColProductName => 'Product name';

  @override
  String get rptColOrderQty => 'Order qty.';

  @override
  String get rptColCurrentStock => 'Current stock';

  @override
  String get rptColWarningQty => 'Warning qty.';

  @override
  String get rptColTransactionType => 'Transaction type';

  @override
  String get rptColCredit => 'Credit';

  @override
  String get rptColDebit => 'Debit';

  @override
  String get rptColTableOrOrder => 'Table / order number';

  @override
  String get rptColZReportNo => 'Z-Report #';

  @override
  String get rptColCompany => 'Company';

  @override
  String get rptColCostPrice => 'Cost price';

  @override
  String get rptColCostBeforeTax => 'Cost bef. tax';

  @override
  String get rptColCostInclTax => 'Cost incl. tax';

  @override
  String get rptFastMoving => 'Fast moving';

  @override
  String get rptSlowMoving => 'Slow moving';

  @override
  String get rptStatusConfirmed => 'Confirmed';

  @override
  String get rptStatusPending => 'Pending';

  @override
  String get rptBusinessPartner => 'Business partner';

  @override
  String get rptNetTotal => 'Net Total';

  @override
  String get rptTotalsRow => 'TOTALS';

  @override
  String get rptNoGroup => '(none)';

  @override
  String get rptNoDiscountsInPeriod => 'No discounts in this period.';

  @override
  String rptTotalNumberOfSales(String count) {
    return 'Total number of sales: $count';
  }

  @override
  String rptAverageSalesPerItem(String count) {
    return 'Average number of sales per item: $count';
  }

  @override
  String rptOrdersDiscounted(String count) {
    return 'Number of orders discounted: $count';
  }

  @override
  String rptTotalDiscounted(String amount) {
    return 'Total discounted: $amount';
  }

  @override
  String rptPageOf(String page, String total) {
    return 'Page $page / $total';
  }

  @override
  String rptProductCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
    );
    return '$_temp0';
  }

  @override
  String get rptColHourStart => 'Hour start';

  @override
  String get rptColHourEnd => 'Hour end';

  @override
  String get rptFavorites => 'Favorites';

  @override
  String get rptColTotalBefTax => 'Total bef. tax';

  @override
  String get saveStockReportTitle => 'Save Stock Report';
}
