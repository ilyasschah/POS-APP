import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// Dismisses a dialog without applying changes
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Commits the current form
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// Primary button of an edit dialog
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get actionSaveChanges;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @actionUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get actionUpload;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// Heading of the master login screen shown on a new install
  ///
  /// In en, this message translates to:
  /// **'Device Registration'**
  String get deviceRegistrationTitle;

  /// No description provided for @deviceRegistrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your account to link this terminal'**
  String get deviceRegistrationSubtitle;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @developerMode.
  ///
  /// In en, this message translates to:
  /// **'Developer Mode'**
  String get developerMode;

  /// No description provided for @unlinkDeviceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unlink this device?'**
  String get unlinkDeviceConfirm;

  /// No description provided for @unlinkDevice.
  ///
  /// In en, this message translates to:
  /// **'Unlink Device'**
  String get unlinkDevice;

  /// Clock in/out button on the PIN screen. Shown upper-case in English.
  ///
  /// In en, this message translates to:
  /// **'TIME CLOCK'**
  String get timeClock;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get roleCashier;

  /// No description provided for @reloadUsers.
  ///
  /// In en, this message translates to:
  /// **'Reload users'**
  String get reloadUsers;

  /// No description provided for @relinkDevice.
  ///
  /// In en, this message translates to:
  /// **'Re-link device'**
  String get relinkDevice;

  /// No description provided for @couldNotLoadUsers.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load users on this terminal.'**
  String get couldNotLoadUsers;

  /// No description provided for @noUsersCached.
  ///
  /// In en, this message translates to:
  /// **'No users cached on this terminal.'**
  String get noUsersCached;

  /// No description provided for @restoringUsersFromServer.
  ///
  /// In en, this message translates to:
  /// **'Restoring users from the server…'**
  String get restoringUsersFromServer;

  /// No description provided for @reconnectToRestoreUsers.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to restore them, or re-link this device to sign in again.'**
  String get reconnectToRestoreUsers;

  /// No description provided for @actionYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get actionYes;

  /// No description provided for @actionNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get actionNo;

  /// No description provided for @actionApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get actionApply;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get actionSet;

  /// No description provided for @actionSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get actionSwitch;

  /// No description provided for @actionProceedAnyway.
  ///
  /// In en, this message translates to:
  /// **'Proceed Anyway'**
  String get actionProceedAnyway;

  /// No description provided for @deleteProductsConfirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete 1 product? This cannot be undone.} other{Delete {count} products? This cannot be undone.}}'**
  String deleteProductsConfirm(num count);

  /// No description provided for @colorMarkerHint.
  ///
  /// In en, this message translates to:
  /// **'Tints the product tile in the POS menu and the products list.'**
  String get colorMarkerHint;

  /// No description provided for @modifiersHint.
  ///
  /// In en, this message translates to:
  /// **'Add specific notes like \'Extra Spicy\' or \'Contains Nuts\'.'**
  String get modifiersHint;

  /// No description provided for @barcodesHint.
  ///
  /// In en, this message translates to:
  /// **'Assign multiple barcodes (e.g., individual item, box, or pallet).'**
  String get barcodesHint;

  /// No description provided for @importComplete.
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get importComplete;

  /// No description provided for @documentCreated.
  ///
  /// In en, this message translates to:
  /// **'Document created: '**
  String get documentCreated;

  /// No description provided for @importErrorCount.
  ///
  /// In en, this message translates to:
  /// **'{count} error(s):'**
  String importErrorCount(num count);

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importTitle;

  /// No description provided for @selectFile.
  ///
  /// In en, this message translates to:
  /// **'Select file'**
  String get selectFile;

  /// No description provided for @indicatesRequiredField.
  ///
  /// In en, this message translates to:
  /// **'* Indicates required field'**
  String get indicatesRequiredField;

  /// No description provided for @skipColumn.
  ///
  /// In en, this message translates to:
  /// **'(Skip)'**
  String get skipColumn;

  /// No description provided for @duplicatesQuestion.
  ///
  /// In en, this message translates to:
  /// **'What happens if duplicates are found?'**
  String get duplicatesQuestion;

  /// No description provided for @createDocumentFromQuantity.
  ///
  /// In en, this message translates to:
  /// **'Create document from specified quantity'**
  String get createDocumentFromQuantity;

  /// No description provided for @actionPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get actionPreview;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldProductGroup.
  ///
  /// In en, this message translates to:
  /// **'Product group'**
  String get fieldProductGroup;

  /// No description provided for @fieldSku.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get fieldSku;

  /// No description provided for @fieldMeasurementUnit.
  ///
  /// In en, this message translates to:
  /// **'Measurement unit'**
  String get fieldMeasurementUnit;

  /// No description provided for @fieldCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get fieldCost;

  /// No description provided for @fieldMarkup.
  ///
  /// In en, this message translates to:
  /// **'Markup'**
  String get fieldMarkup;

  /// No description provided for @fieldTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get fieldTax;

  /// No description provided for @fieldTaxInclusivePrice.
  ///
  /// In en, this message translates to:
  /// **'Tax inclusive price'**
  String get fieldTaxInclusivePrice;

  /// No description provided for @fieldPriceChangeAllowed.
  ///
  /// In en, this message translates to:
  /// **'Price change allowed'**
  String get fieldPriceChangeAllowed;

  /// No description provided for @fieldUsingDefaultQuantity.
  ///
  /// In en, this message translates to:
  /// **'Using default quantity'**
  String get fieldUsingDefaultQuantity;

  /// No description provided for @fieldServiceNotStock.
  ///
  /// In en, this message translates to:
  /// **'Service (not using stock)'**
  String get fieldServiceNotStock;

  /// No description provided for @fieldEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get fieldEnabled;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fieldDescription;

  /// No description provided for @fieldQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get fieldQuantity;

  /// No description provided for @fieldSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get fieldSupplier;

  /// No description provided for @fieldReorderPoint.
  ///
  /// In en, this message translates to:
  /// **'Reorder point'**
  String get fieldReorderPoint;

  /// No description provided for @fieldPreferredQuantity.
  ///
  /// In en, this message translates to:
  /// **'Preferred quantity'**
  String get fieldPreferredQuantity;

  /// No description provided for @fieldLowStockWarning.
  ///
  /// In en, this message translates to:
  /// **'Low stock warning'**
  String get fieldLowStockWarning;

  /// No description provided for @fieldLowStockWarningQuantity.
  ///
  /// In en, this message translates to:
  /// **'Low stock warning quantity'**
  String get fieldLowStockWarningQuantity;

  /// No description provided for @cannotDelete.
  ///
  /// In en, this message translates to:
  /// **'Cannot Delete'**
  String get cannotDelete;

  /// No description provided for @deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete Group'**
  String get deleteGroup;

  /// No description provided for @deleteGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \'{name}\'?'**
  String deleteGroupConfirm(String name);

  /// No description provided for @productGroups.
  ///
  /// In en, this message translates to:
  /// **'Product Groups'**
  String get productGroups;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get newGroup;

  /// No description provided for @deleteGroupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get deleteGroupTooltip;

  /// No description provided for @failedToLoadGroups.
  ///
  /// In en, this message translates to:
  /// **'Failed to load groups'**
  String get failedToLoadGroups;

  /// No description provided for @noneRoot.
  ///
  /// In en, this message translates to:
  /// **'None (Root)'**
  String get noneRoot;

  /// No description provided for @chooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose Image'**
  String get chooseImage;

  /// No description provided for @searchProductsEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Search products…'**
  String get searchProductsEllipsis;

  /// No description provided for @failedToLoadProducts.
  ///
  /// In en, this message translates to:
  /// **'Failed to load products'**
  String get failedToLoadProducts;

  /// No description provided for @noProductsFoundShort.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFoundShort;

  /// No description provided for @noProductGroupsYet.
  ///
  /// In en, this message translates to:
  /// **'No product groups yet'**
  String get noProductGroupsYet;

  /// No description provided for @createOneToOrganize.
  ///
  /// In en, this message translates to:
  /// **'Create one to organize your products'**
  String get createOneToOrganize;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroup;

  /// No description provided for @customersLabel.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersLabel;

  /// No description provided for @customerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customerLabel;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @categoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesLabel;

  /// No description provided for @errorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorLabel;

  /// No description provided for @accountUserEmail.
  ///
  /// In en, this message translates to:
  /// **'Account / User Email'**
  String get accountUserEmail;

  /// No description provided for @dateFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Date Format'**
  String get dateFormatLabel;

  /// No description provided for @accessLevel.
  ///
  /// In en, this message translates to:
  /// **'Access Level'**
  String get accessLevel;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @addFirstUser.
  ///
  /// In en, this message translates to:
  /// **'Add First User'**
  String get addFirstUser;

  /// No description provided for @addNewUser.
  ///
  /// In en, this message translates to:
  /// **'Add New User'**
  String get addNewUser;

  /// No description provided for @addPayment.
  ///
  /// In en, this message translates to:
  /// **'Add Payment'**
  String get addPayment;

  /// No description provided for @addUser.
  ///
  /// In en, this message translates to:
  /// **'Add User'**
  String get addUser;

  /// No description provided for @adminResetDevicePin.
  ///
  /// In en, this message translates to:
  /// **'Admin: Reset Device PIN'**
  String get adminResetDevicePin;

  /// No description provided for @adminResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Admin: Reset Password'**
  String get adminResetPassword;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @allCustomers.
  ///
  /// In en, this message translates to:
  /// **'All customers'**
  String get allCustomers;

  /// No description provided for @allDocumentTypes.
  ///
  /// In en, this message translates to:
  /// **'All document types'**
  String get allDocumentTypes;

  /// No description provided for @allTransactions.
  ///
  /// In en, this message translates to:
  /// **'All transactions'**
  String get allTransactions;

  /// No description provided for @allUsers.
  ///
  /// In en, this message translates to:
  /// **'All users'**
  String get allUsers;

  /// No description provided for @allWarehouses.
  ///
  /// In en, this message translates to:
  /// **'All warehouses'**
  String get allWarehouses;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @assignToWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Assign to Warehouse'**
  String get assignToWarehouse;

  /// No description provided for @couldNotLoadRules.
  ///
  /// In en, this message translates to:
  /// **'Could not load rules'**
  String get couldNotLoadRules;

  /// No description provided for @colCreated.
  ///
  /// In en, this message translates to:
  /// **'CREATED'**
  String get colCreated;

  /// No description provided for @colCustomer.
  ///
  /// In en, this message translates to:
  /// **'CUSTOMER'**
  String get colCustomer;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @deleteDocument.
  ///
  /// In en, this message translates to:
  /// **'Delete Document'**
  String get deleteDocument;

  /// No description provided for @deleteRule.
  ///
  /// In en, this message translates to:
  /// **'Delete Rule'**
  String get deleteRule;

  /// No description provided for @deleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete User'**
  String get deleteUser;

  /// No description provided for @colDisc.
  ///
  /// In en, this message translates to:
  /// **'DISC'**
  String get colDisc;

  /// No description provided for @discountBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Discount Breakdown'**
  String get discountBreakdown;

  /// No description provided for @documentExplorer.
  ///
  /// In en, this message translates to:
  /// **'Document Explorer'**
  String get documentExplorer;

  /// No description provided for @editRules.
  ///
  /// In en, this message translates to:
  /// **'Edit Rules'**
  String get editRules;

  /// No description provided for @editUser.
  ///
  /// In en, this message translates to:
  /// **'Edit User'**
  String get editUser;

  /// No description provided for @errorLoadingTaxes.
  ///
  /// In en, this message translates to:
  /// **'Error loading taxes'**
  String get errorLoadingTaxes;

  /// No description provided for @excel.
  ///
  /// In en, this message translates to:
  /// **'Excel'**
  String get excel;

  /// No description provided for @expirationDate.
  ///
  /// In en, this message translates to:
  /// **'Expiration Date'**
  String get expirationDate;

  /// No description provided for @expirationDateOptional.
  ///
  /// In en, this message translates to:
  /// **'Expiration Date (optional)'**
  String get expirationDateOptional;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @firstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'First Name *'**
  String get firstNameRequired;

  /// No description provided for @fixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed'**
  String get fixed;

  /// No description provided for @idLabel.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get idLabel;

  /// No description provided for @initialQuantity.
  ///
  /// In en, this message translates to:
  /// **'Initial Quantity'**
  String get initialQuantity;

  /// No description provided for @internalNote.
  ///
  /// In en, this message translates to:
  /// **'INTERNAL NOTE'**
  String get internalNote;

  /// No description provided for @inventoryMasterList.
  ///
  /// In en, this message translates to:
  /// **'Inventory Master List'**
  String get inventoryMasterList;

  /// No description provided for @itemDiscount.
  ///
  /// In en, this message translates to:
  /// **'Item Discount'**
  String get itemDiscount;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @lastNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Last Name *'**
  String get lastNameRequired;

  /// No description provided for @lowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get lowStock;

  /// No description provided for @lowStockWarning.
  ///
  /// In en, this message translates to:
  /// **'Low Stock Warning'**
  String get lowStockWarning;

  /// No description provided for @manageWarehouses.
  ///
  /// In en, this message translates to:
  /// **'Manage Warehouses'**
  String get manageWarehouses;

  /// No description provided for @markAsUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as Unpaid?'**
  String get markAsUnpaid;

  /// No description provided for @needsReorder.
  ///
  /// In en, this message translates to:
  /// **'Needs Reorder'**
  String get needsReorder;

  /// No description provided for @colNew.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get colNew;

  /// No description provided for @newFourDigitPin.
  ///
  /// In en, this message translates to:
  /// **'New 4-Digit PIN'**
  String get newFourDigitPin;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @newQuantity.
  ///
  /// In en, this message translates to:
  /// **'New Quantity'**
  String get newQuantity;

  /// No description provided for @noSecurityRules.
  ///
  /// In en, this message translates to:
  /// **'No security rules found.'**
  String get noSecurityRules;

  /// No description provided for @noTaxShort.
  ///
  /// In en, this message translates to:
  /// **'No tax'**
  String get noTaxShort;

  /// No description provided for @noneLabel.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneLabel;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteLabel;

  /// No description provided for @colNumber.
  ///
  /// In en, this message translates to:
  /// **'NUMBER'**
  String get colNumber;

  /// No description provided for @colOrderNo.
  ///
  /// In en, this message translates to:
  /// **'ORDER #'**
  String get colOrderNo;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @partial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get partial;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password *'**
  String get passwordRequired;

  /// No description provided for @paymentType.
  ///
  /// In en, this message translates to:
  /// **'Payment Type'**
  String get paymentType;

  /// No description provided for @preferredQuantity.
  ///
  /// In en, this message translates to:
  /// **'Preferred Quantity'**
  String get preferredQuantity;

  /// No description provided for @priceAfterTax.
  ///
  /// In en, this message translates to:
  /// **'Price (after tax)'**
  String get priceAfterTax;

  /// No description provided for @priceBeforeTax.
  ///
  /// In en, this message translates to:
  /// **'Price before tax'**
  String get priceBeforeTax;

  /// No description provided for @printStockReportPdf.
  ///
  /// In en, this message translates to:
  /// **'Print Stock Report (PDF)'**
  String get printStockReportPdf;

  /// No description provided for @productLabel.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get productLabel;

  /// No description provided for @productRequired.
  ///
  /// In en, this message translates to:
  /// **'Product *'**
  String get productRequired;

  /// No description provided for @referenceDocument.
  ///
  /// In en, this message translates to:
  /// **'Reference Document'**
  String get referenceDocument;

  /// No description provided for @removeStock.
  ///
  /// In en, this message translates to:
  /// **'Remove Stock'**
  String get removeStock;

  /// No description provided for @reorderPoint.
  ///
  /// In en, this message translates to:
  /// **'Reorder Point'**
  String get reorderPoint;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @ruleExistsEditing.
  ///
  /// In en, this message translates to:
  /// **'Rule exists — editing'**
  String get ruleExistsEditing;

  /// No description provided for @saveStockReportPdf.
  ///
  /// In en, this message translates to:
  /// **'Save Stock Report as PDF'**
  String get saveStockReportPdf;

  /// No description provided for @searchProductNameOrCode.
  ///
  /// In en, this message translates to:
  /// **'Search product name or code…'**
  String get searchProductNameOrCode;

  /// No description provided for @searchReports.
  ///
  /// In en, this message translates to:
  /// **'Search reports'**
  String get searchReports;

  /// No description provided for @securityActions.
  ///
  /// In en, this message translates to:
  /// **'Security Actions'**
  String get securityActions;

  /// No description provided for @selectDocumentType.
  ///
  /// In en, this message translates to:
  /// **'Select document type'**
  String get selectDocumentType;

  /// No description provided for @selectReport.
  ///
  /// In en, this message translates to:
  /// **'Select report'**
  String get selectReport;

  /// No description provided for @showReport.
  ///
  /// In en, this message translates to:
  /// **'Show report'**
  String get showReport;

  /// No description provided for @colStatus.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get colStatus;

  /// No description provided for @colSvc.
  ///
  /// In en, this message translates to:
  /// **'SVC'**
  String get colSvc;

  /// No description provided for @syncAndRefresh.
  ///
  /// In en, this message translates to:
  /// **'Sync & Refresh'**
  String get syncAndRefresh;

  /// No description provided for @tabNotFound.
  ///
  /// In en, this message translates to:
  /// **'Tab not found'**
  String get tabNotFound;

  /// No description provided for @taxOptional.
  ///
  /// In en, this message translates to:
  /// **'Tax (optional)'**
  String get taxOptional;

  /// No description provided for @taxAmount.
  ///
  /// In en, this message translates to:
  /// **'Tax amount'**
  String get taxAmount;

  /// No description provided for @totalDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Total discounts'**
  String get totalDiscounts;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @unpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get unpaid;

  /// No description provided for @updateItem.
  ///
  /// In en, this message translates to:
  /// **'Update Item'**
  String get updateItem;

  /// No description provided for @colUpdated.
  ///
  /// In en, this message translates to:
  /// **'UPDATED'**
  String get colUpdated;

  /// No description provided for @colUser.
  ///
  /// In en, this message translates to:
  /// **'USER'**
  String get colUser;

  /// No description provided for @userRequired.
  ///
  /// In en, this message translates to:
  /// **'User *'**
  String get userRequired;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Username *'**
  String get usernameRequired;

  /// No description provided for @usersAndSecurity.
  ///
  /// In en, this message translates to:
  /// **'Users & Security'**
  String get usersAndSecurity;

  /// No description provided for @valueTotal.
  ///
  /// In en, this message translates to:
  /// **'Value (Total)'**
  String get valueTotal;

  /// No description provided for @warehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get warehouse;

  /// No description provided for @warehouseRequired.
  ///
  /// In en, this message translates to:
  /// **'Warehouse *'**
  String get warehouseRequired;

  /// No description provided for @warningThreshold.
  ///
  /// In en, this message translates to:
  /// **'Warning Threshold'**
  String get warningThreshold;

  /// No description provided for @yesDeletePayments.
  ///
  /// In en, this message translates to:
  /// **'Yes, delete payments'**
  String get yesDeletePayments;

  /// No description provided for @errorLoadingDocuments.
  ///
  /// In en, this message translates to:
  /// **'Error loading documents: {message}'**
  String errorLoadingDocuments(String message);

  /// No description provided for @errorLoadingSecurityRules.
  ///
  /// In en, this message translates to:
  /// **'Error loading security rules: {message}'**
  String errorLoadingSecurityRules(String message);

  /// No description provided for @errorLoadingUsers.
  ///
  /// In en, this message translates to:
  /// **'Error loading users: {message}'**
  String errorLoadingUsers(String message);

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {message}'**
  String saveFailed(String message);

  /// No description provided for @savedToPath.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String savedToPath(String path);

  /// No description provided for @addBooking.
  ///
  /// In en, this message translates to:
  /// **'Add Booking'**
  String get addBooking;

  /// No description provided for @addCard.
  ///
  /// In en, this message translates to:
  /// **'Add Card'**
  String get addCard;

  /// No description provided for @addFirstTaxRate.
  ///
  /// In en, this message translates to:
  /// **'Add First Tax Rate'**
  String get addFirstTaxRate;

  /// No description provided for @addFirstWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Add First Warehouse'**
  String get addFirstWarehouse;

  /// No description provided for @addLoyaltyCard.
  ///
  /// In en, this message translates to:
  /// **'Add Loyalty Card'**
  String get addLoyaltyCard;

  /// No description provided for @addPromotion.
  ///
  /// In en, this message translates to:
  /// **'Add Promotion'**
  String get addPromotion;

  /// No description provided for @addTable.
  ///
  /// In en, this message translates to:
  /// **'Add Table'**
  String get addTable;

  /// No description provided for @addTimeCard.
  ///
  /// In en, this message translates to:
  /// **'Add Time Card'**
  String get addTimeCard;

  /// No description provided for @addWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Add Warehouse'**
  String get addWarehouse;

  /// No description provided for @addResizeRenameTables.
  ///
  /// In en, this message translates to:
  /// **'Add, resize, and rename tables'**
  String get addResizeRenameTables;

  /// No description provided for @allEmployees.
  ///
  /// In en, this message translates to:
  /// **'All employees ...'**
  String get allEmployees;

  /// No description provided for @applyName.
  ///
  /// In en, this message translates to:
  /// **'Apply name'**
  String get applyName;

  /// No description provided for @endShiftConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to end your shift?'**
  String get endShiftConfirm;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @bookingAlerts.
  ///
  /// In en, this message translates to:
  /// **'Booking Alerts'**
  String get bookingAlerts;

  /// No description provided for @bookingSaved.
  ///
  /// In en, this message translates to:
  /// **'Booking Saved!'**
  String get bookingSaved;

  /// No description provided for @cardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get cardNumber;

  /// No description provided for @shapeCircle.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get shapeCircle;

  /// No description provided for @clockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock in'**
  String get clockIn;

  /// No description provided for @clockOut.
  ///
  /// In en, this message translates to:
  /// **'Clock out'**
  String get clockOut;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDelete;

  /// No description provided for @couldNotLoadEmployees.
  ///
  /// In en, this message translates to:
  /// **'Could not load employees'**
  String get couldNotLoadEmployees;

  /// No description provided for @created.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// No description provided for @currencies.
  ///
  /// In en, this message translates to:
  /// **'Currencies'**
  String get currencies;

  /// No description provided for @customerRequired.
  ///
  /// In en, this message translates to:
  /// **'Customer *'**
  String get customerRequired;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get days;

  /// No description provided for @deleteBooking.
  ///
  /// In en, this message translates to:
  /// **'Delete Booking'**
  String get deleteBooking;

  /// No description provided for @deleteLoyaltyCard.
  ///
  /// In en, this message translates to:
  /// **'Delete Loyalty Card'**
  String get deleteLoyaltyCard;

  /// No description provided for @deleteTax.
  ///
  /// In en, this message translates to:
  /// **'Delete Tax'**
  String get deleteTax;

  /// No description provided for @deleteWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Delete Warehouse'**
  String get deleteWarehouse;

  /// No description provided for @documentItemsColumns.
  ///
  /// In en, this message translates to:
  /// **'Document items columns'**
  String get documentItemsColumns;

  /// No description provided for @documentType.
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get documentType;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @documentsColumns.
  ///
  /// In en, this message translates to:
  /// **'Documents columns'**
  String get documentsColumns;

  /// No description provided for @hintTwentyPercent.
  ///
  /// In en, this message translates to:
  /// **'e.g. 20 for 20%'**
  String get hintTwentyPercent;

  /// No description provided for @hintSecondFloor.
  ///
  /// In en, this message translates to:
  /// **'E.g., Second Floor'**
  String get hintSecondFloor;

  /// No description provided for @earningRule.
  ///
  /// In en, this message translates to:
  /// **'Earning Rule'**
  String get earningRule;

  /// No description provided for @editFloorPlan.
  ///
  /// In en, this message translates to:
  /// **'Edit Floor Plan'**
  String get editFloorPlan;

  /// No description provided for @employee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get employee;

  /// No description provided for @enableLoyaltyPoints.
  ///
  /// In en, this message translates to:
  /// **'Enable Loyalty Points'**
  String get enableLoyaltyPoints;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// No description provided for @endOfDay.
  ///
  /// In en, this message translates to:
  /// **'End of Day'**
  String get endOfDay;

  /// No description provided for @endShift.
  ///
  /// In en, this message translates to:
  /// **'End Shift'**
  String get endShift;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get endTime;

  /// No description provided for @colExport.
  ///
  /// In en, this message translates to:
  /// **'EXPORT'**
  String get colExport;

  /// No description provided for @externalRef.
  ///
  /// In en, this message translates to:
  /// **'External ref'**
  String get externalRef;

  /// No description provided for @floorPlan.
  ///
  /// In en, this message translates to:
  /// **'Floor Plan'**
  String get floorPlan;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @guestNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Guest Name *'**
  String get guestNameRequired;

  /// No description provided for @guests.
  ///
  /// In en, this message translates to:
  /// **'Guests'**
  String get guests;

  /// No description provided for @leaveBlankAutoAssign.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to auto-assign'**
  String get leaveBlankAutoAssign;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @loyaltyCards.
  ///
  /// In en, this message translates to:
  /// **'Loyalty Cards'**
  String get loyaltyCards;

  /// No description provided for @loyaltySettings.
  ///
  /// In en, this message translates to:
  /// **'Loyalty Settings'**
  String get loyaltySettings;

  /// No description provided for @minPurchaseAmount.
  ///
  /// In en, this message translates to:
  /// **'Min. purchase amount'**
  String get minPurchaseAmount;

  /// No description provided for @moveStock.
  ///
  /// In en, this message translates to:
  /// **'Move stock'**
  String get moveStock;

  /// No description provided for @moveStockTo.
  ///
  /// In en, this message translates to:
  /// **'Move stock to…'**
  String get moveStockTo;

  /// No description provided for @myCompany.
  ///
  /// In en, this message translates to:
  /// **'My Company'**
  String get myCompany;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get nameRequired;

  /// No description provided for @newFloor.
  ///
  /// In en, this message translates to:
  /// **'New Floor'**
  String get newFloor;

  /// No description provided for @newFloorPlan.
  ///
  /// In en, this message translates to:
  /// **'New Floor Plan'**
  String get newFloorPlan;

  /// No description provided for @newTax.
  ///
  /// In en, this message translates to:
  /// **'New Tax'**
  String get newTax;

  /// No description provided for @newTaxRate.
  ///
  /// In en, this message translates to:
  /// **'New Tax Rate'**
  String get newTaxRate;

  /// No description provided for @nextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get nextDay;

  /// No description provided for @noWarehousesFound.
  ///
  /// In en, this message translates to:
  /// **'No warehouses found.'**
  String get noWarehousesFound;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @numberLabel.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get numberLabel;

  /// No description provided for @oldTax.
  ///
  /// In en, this message translates to:
  /// **'Old Tax'**
  String get oldTax;

  /// No description provided for @openDocument.
  ///
  /// In en, this message translates to:
  /// **'Open Document'**
  String get openDocument;

  /// No description provided for @openOrder.
  ///
  /// In en, this message translates to:
  /// **'Open Order'**
  String get openOrder;

  /// No description provided for @openOrders.
  ///
  /// In en, this message translates to:
  /// **'Open Orders'**
  String get openOrders;

  /// No description provided for @openService.
  ///
  /// In en, this message translates to:
  /// **'Open Service'**
  String get openService;

  /// No description provided for @openedAt.
  ///
  /// In en, this message translates to:
  /// **'Opened at'**
  String get openedAt;

  /// No description provided for @orderNoLabel.
  ///
  /// In en, this message translates to:
  /// **'Order #'**
  String get orderNoLabel;

  /// No description provided for @pageLabel.
  ///
  /// In en, this message translates to:
  /// **'Page:'**
  String get pageLabel;

  /// No description provided for @paymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentLabel;

  /// No description provided for @paymentTypesShort.
  ///
  /// In en, this message translates to:
  /// **'Payment Types'**
  String get paymentTypesShort;

  /// No description provided for @pendingLower.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get pendingLower;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @pointsEarned.
  ///
  /// In en, this message translates to:
  /// **'Points earned'**
  String get pointsEarned;

  /// No description provided for @posLabel.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get posLabel;

  /// No description provided for @previousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get previousDay;

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceLabel;

  /// No description provided for @promotions.
  ///
  /// In en, this message translates to:
  /// **'Promotions'**
  String get promotions;

  /// No description provided for @rateRequired.
  ///
  /// In en, this message translates to:
  /// **'Rate *'**
  String get rateRequired;

  /// No description provided for @redemptionRule.
  ///
  /// In en, this message translates to:
  /// **'Redemption Rule'**
  String get redemptionRule;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @removeFloor.
  ///
  /// In en, this message translates to:
  /// **'Remove Floor'**
  String get removeFloor;

  /// No description provided for @removeFloorPlan.
  ///
  /// In en, this message translates to:
  /// **'Remove Floor Plan'**
  String get removeFloorPlan;

  /// No description provided for @removeTable.
  ///
  /// In en, this message translates to:
  /// **'Remove Table'**
  String get removeTable;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @revokeStock.
  ///
  /// In en, this message translates to:
  /// **'Revoke stock'**
  String get revokeStock;

  /// No description provided for @rowsPerPage.
  ///
  /// In en, this message translates to:
  /// **'Rows per page:'**
  String get rowsPerPage;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales;

  /// No description provided for @saveUpper.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get saveUpper;

  /// No description provided for @searchCustomer.
  ///
  /// In en, this message translates to:
  /// **'Search customer...'**
  String get searchCustomer;

  /// No description provided for @searchDocument.
  ///
  /// In en, this message translates to:
  /// **'Search document...'**
  String get searchDocument;

  /// No description provided for @selectEmployee.
  ///
  /// In en, this message translates to:
  /// **'Select employee'**
  String get selectEmployee;

  /// No description provided for @selectTablesRequired.
  ///
  /// In en, this message translates to:
  /// **'Select Tables *'**
  String get selectTablesRequired;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @shiftManagement.
  ///
  /// In en, this message translates to:
  /// **'Shift Management'**
  String get shiftManagement;

  /// No description provided for @showGrid.
  ///
  /// In en, this message translates to:
  /// **'Show grid'**
  String get showGrid;

  /// No description provided for @showQr.
  ///
  /// In en, this message translates to:
  /// **'Show QR'**
  String get showQr;

  /// No description provided for @snapToGrid.
  ///
  /// In en, this message translates to:
  /// **'Snap to grid'**
  String get snapToGrid;

  /// No description provided for @shapeSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get shapeSquare;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// No description provided for @startService.
  ///
  /// In en, this message translates to:
  /// **'Start Service'**
  String get startService;

  /// No description provided for @startShift.
  ///
  /// In en, this message translates to:
  /// **'Start Shift'**
  String get startShift;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get startTime;

  /// No description provided for @startingPoints.
  ///
  /// In en, this message translates to:
  /// **'Starting Points'**
  String get startingPoints;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @stayOnCalendar.
  ///
  /// In en, this message translates to:
  /// **'Stay on Calendar'**
  String get stayOnCalendar;

  /// No description provided for @stock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stock;

  /// No description provided for @switchTaxes.
  ///
  /// In en, this message translates to:
  /// **'Switch Taxes'**
  String get switchTaxes;

  /// No description provided for @taxRates.
  ///
  /// In en, this message translates to:
  /// **'Tax Rates'**
  String get taxRates;

  /// No description provided for @totalBeforeDiscount.
  ///
  /// In en, this message translates to:
  /// **'Total bef. discount'**
  String get totalBeforeDiscount;

  /// No description provided for @totalBeforeTax.
  ///
  /// In en, this message translates to:
  /// **'Total before tax'**
  String get totalBeforeTax;

  /// No description provided for @unitOfMeasure.
  ///
  /// In en, this message translates to:
  /// **'Unit of measure'**
  String get unitOfMeasure;

  /// No description provided for @userLabel.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userLabel;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @warehouseHasStock.
  ///
  /// In en, this message translates to:
  /// **'Warehouse has stock'**
  String get warehouseHasStock;

  /// No description provided for @warehouseNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Warehouse Name *'**
  String get warehouseNameRequired;

  /// No description provided for @warehouses.
  ///
  /// In en, this message translates to:
  /// **'Warehouses'**
  String get warehouses;

  /// No description provided for @whichTableForOrder.
  ///
  /// In en, this message translates to:
  /// **'Which table should this order be placed on?'**
  String get whichTableForOrder;

  /// No description provided for @errorLoadingLoyaltyCards.
  ///
  /// In en, this message translates to:
  /// **'Error loading loyalty cards: {message}'**
  String errorLoadingLoyaltyCards(String message);

  /// No description provided for @errorLoadingWarehouses.
  ///
  /// In en, this message translates to:
  /// **'Error loading warehouses: {message}'**
  String errorLoadingWarehouses(String message);

  /// No description provided for @colActions.
  ///
  /// In en, this message translates to:
  /// **'ACTIONS'**
  String get colActions;

  /// No description provided for @addCash.
  ///
  /// In en, this message translates to:
  /// **'Add cash'**
  String get addCash;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// No description provided for @addProductLower.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get addProductLower;

  /// No description provided for @addPromotionItem.
  ///
  /// In en, this message translates to:
  /// **'Add Promotion Item'**
  String get addPromotionItem;

  /// No description provided for @addReturnedProducts.
  ///
  /// In en, this message translates to:
  /// **'Add the products being returned'**
  String get addReturnedProducts;

  /// No description provided for @addTimeCardUpper.
  ///
  /// In en, this message translates to:
  /// **'ADD TIME CARD'**
  String get addTimeCardUpper;

  /// No description provided for @allWarehousesCap.
  ///
  /// In en, this message translates to:
  /// **'All Warehouses'**
  String get allWarehousesCap;

  /// No description provided for @appliesTo.
  ///
  /// In en, this message translates to:
  /// **'Applies To'**
  String get appliesTo;

  /// No description provided for @deleteVoidReasonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this void reason?'**
  String get deleteVoidReasonConfirm;

  /// No description provided for @authorise.
  ///
  /// In en, this message translates to:
  /// **'Authorise'**
  String get authorise;

  /// No description provided for @bookingHistory.
  ///
  /// In en, this message translates to:
  /// **'Booking History'**
  String get bookingHistory;

  /// No description provided for @cancelEdit.
  ///
  /// In en, this message translates to:
  /// **'Cancel Edit'**
  String get cancelEdit;

  /// No description provided for @cashIn.
  ///
  /// In en, this message translates to:
  /// **'Cash In'**
  String get cashIn;

  /// No description provided for @cashInOut.
  ///
  /// In en, this message translates to:
  /// **'Cash In / Out'**
  String get cashInOut;

  /// No description provided for @cashMovement.
  ///
  /// In en, this message translates to:
  /// **'Cash Movement'**
  String get cashMovement;

  /// No description provided for @cashOut.
  ///
  /// In en, this message translates to:
  /// **'Cash Out'**
  String get cashOut;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @closeRegister.
  ///
  /// In en, this message translates to:
  /// **'Close Register'**
  String get closeRegister;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @createUser.
  ///
  /// In en, this message translates to:
  /// **'Create User'**
  String get createUser;

  /// No description provided for @creditPayments.
  ///
  /// In en, this message translates to:
  /// **'Credit payments'**
  String get creditPayments;

  /// No description provided for @currencyCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Currency Code (e.g. USD) *'**
  String get currencyCodeRequired;

  /// No description provided for @currencyNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Currency Name (e.g. US Dollar) *'**
  String get currencyNameRequired;

  /// No description provided for @customersSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Customers & Suppliers'**
  String get customersSuppliers;

  /// No description provided for @colDate.
  ///
  /// In en, this message translates to:
  /// **'DATE'**
  String get colDate;

  /// No description provided for @deleteCurrency.
  ///
  /// In en, this message translates to:
  /// **'Delete Currency'**
  String get deleteCurrency;

  /// No description provided for @deleteVoidReason.
  ///
  /// In en, this message translates to:
  /// **'Delete Void Reason'**
  String get deleteVoidReason;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @discountType.
  ///
  /// In en, this message translates to:
  /// **'Discount Type'**
  String get discountType;

  /// No description provided for @discountValue.
  ///
  /// In en, this message translates to:
  /// **'Discount Value'**
  String get discountValue;

  /// No description provided for @hintWifiBill.
  ///
  /// In en, this message translates to:
  /// **'e.g. wifi bill, pre started'**
  String get hintWifiBill;

  /// No description provided for @cashReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the reason for adding or removing cash...'**
  String get cashReasonHint;

  /// No description provided for @errorLoadingTables.
  ///
  /// In en, this message translates to:
  /// **'Error loading tables'**
  String get errorLoadingTables;

  /// No description provided for @exitApplication.
  ///
  /// In en, this message translates to:
  /// **'Exit application'**
  String get exitApplication;

  /// No description provided for @failedToLoadOrders.
  ///
  /// In en, this message translates to:
  /// **'Failed to load orders'**
  String get failedToLoadOrders;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @financialInfo.
  ///
  /// In en, this message translates to:
  /// **'Financial Info'**
  String get financialInfo;

  /// No description provided for @fixedAmount.
  ///
  /// In en, this message translates to:
  /// **'Fixed Amount'**
  String get fixedAmount;

  /// No description provided for @fullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full Screen'**
  String get fullScreen;

  /// No description provided for @generalInfo.
  ///
  /// In en, this message translates to:
  /// **'General Info'**
  String get generalInfo;

  /// No description provided for @globalCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Global Currencies'**
  String get globalCurrencies;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get gridView;

  /// No description provided for @hideSidebar.
  ///
  /// In en, this message translates to:
  /// **'Hide Sidebar'**
  String get hideSidebar;

  /// No description provided for @isActive.
  ///
  /// In en, this message translates to:
  /// **'Is Active'**
  String get isActive;

  /// No description provided for @isEnabled.
  ///
  /// In en, this message translates to:
  /// **'Is Enabled'**
  String get isEnabled;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get listView;

  /// No description provided for @loadingPaymentTypes.
  ///
  /// In en, this message translates to:
  /// **'Loading payment types…'**
  String get loadingPaymentTypes;

  /// No description provided for @locationAddress.
  ///
  /// In en, this message translates to:
  /// **'Location & Address'**
  String get locationAddress;

  /// No description provided for @management.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get management;

  /// No description provided for @managerAuthorisation.
  ///
  /// In en, this message translates to:
  /// **'Manager authorisation'**
  String get managerAuthorisation;

  /// No description provided for @managerPin.
  ///
  /// In en, this message translates to:
  /// **'Manager PIN'**
  String get managerPin;

  /// No description provided for @menuLabel.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuLabel;

  /// No description provided for @newCurrency.
  ///
  /// In en, this message translates to:
  /// **'New Currency'**
  String get newCurrency;

  /// No description provided for @noCurrenciesFound.
  ///
  /// In en, this message translates to:
  /// **'No currencies found.'**
  String get noCurrenciesFound;

  /// No description provided for @noPromotionsFound.
  ///
  /// In en, this message translates to:
  /// **'No promotions found.'**
  String get noPromotionsFound;

  /// No description provided for @blindReturn.
  ///
  /// In en, this message translates to:
  /// **'No receipt? Blind return'**
  String get blindReturn;

  /// No description provided for @noUserLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'No user is currently logged in.'**
  String get noUserLoggedIn;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No Users Found'**
  String get noUsersFound;

  /// No description provided for @noVoidReasonsYet.
  ///
  /// In en, this message translates to:
  /// **'No void reasons yet.'**
  String get noVoidReasonsYet;

  /// No description provided for @colNote.
  ///
  /// In en, this message translates to:
  /// **'NOTE'**
  String get colNote;

  /// No description provided for @oldPassword.
  ///
  /// In en, this message translates to:
  /// **'Old Password'**
  String get oldPassword;

  /// No description provided for @paymentMethodColon.
  ///
  /// In en, this message translates to:
  /// **'Payment method:'**
  String get paymentMethodColon;

  /// No description provided for @paymentTypeLower.
  ///
  /// In en, this message translates to:
  /// **'Payment type'**
  String get paymentTypeLower;

  /// No description provided for @percentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get percentage;

  /// No description provided for @percentageSign.
  ///
  /// In en, this message translates to:
  /// **'Percentage (%)'**
  String get percentageSign;

  /// No description provided for @posSystem.
  ///
  /// In en, this message translates to:
  /// **'POS System'**
  String get posSystem;

  /// No description provided for @power.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get power;

  /// No description provided for @powerOptions.
  ///
  /// In en, this message translates to:
  /// **'Power Options'**
  String get powerOptions;

  /// No description provided for @promotionName.
  ///
  /// In en, this message translates to:
  /// **'Promotion Name'**
  String get promotionName;

  /// No description provided for @promotionsManagement.
  ///
  /// In en, this message translates to:
  /// **'Promotions Management'**
  String get promotionsManagement;

  /// No description provided for @quickSettings.
  ///
  /// In en, this message translates to:
  /// **'Quick Settings'**
  String get quickSettings;

  /// No description provided for @rankDisplayOrderLower.
  ///
  /// In en, this message translates to:
  /// **'Rank (display order)'**
  String get rankDisplayOrderLower;

  /// No description provided for @refundItems.
  ///
  /// In en, this message translates to:
  /// **'Refund items'**
  String get refundItems;

  /// No description provided for @refundPaymentType.
  ///
  /// In en, this message translates to:
  /// **'Refund payment type'**
  String get refundPaymentType;

  /// No description provided for @removeCash.
  ///
  /// In en, this message translates to:
  /// **'Remove cash'**
  String get removeCash;

  /// No description provided for @requiredQty.
  ///
  /// In en, this message translates to:
  /// **'Required Qty'**
  String get requiredQty;

  /// No description provided for @restartApplication.
  ///
  /// In en, this message translates to:
  /// **'Restart application'**
  String get restartApplication;

  /// No description provided for @sameProduct.
  ///
  /// In en, this message translates to:
  /// **'Same Product'**
  String get sameProduct;

  /// No description provided for @savePin.
  ///
  /// In en, this message translates to:
  /// **'Save PIN'**
  String get savePin;

  /// No description provided for @searchReceiptToSeeItems.
  ///
  /// In en, this message translates to:
  /// **'Search a receipt to see its items'**
  String get searchReceiptToSeeItems;

  /// No description provided for @searchByName.
  ///
  /// In en, this message translates to:
  /// **'Search by name…'**
  String get searchByName;

  /// No description provided for @searchByOrderStaffTable.
  ///
  /// In en, this message translates to:
  /// **'Search by order, staff or table'**
  String get searchByOrderStaffTable;

  /// No description provided for @searchNamePhoneCard.
  ///
  /// In en, this message translates to:
  /// **'Search name, phone or card number…'**
  String get searchNamePhoneCard;

  /// No description provided for @searchProductEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Search product…'**
  String get searchProductEllipsis;

  /// No description provided for @searchWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Search warehouse…'**
  String get searchWarehouse;

  /// No description provided for @selectCustomer.
  ///
  /// In en, this message translates to:
  /// **'Select Customer'**
  String get selectCustomer;

  /// No description provided for @selectWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Select Warehouse'**
  String get selectWarehouse;

  /// No description provided for @selectYourCompany.
  ///
  /// In en, this message translates to:
  /// **'Select Your Company'**
  String get selectYourCompany;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @supplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get supplier;

  /// No description provided for @targetUid.
  ///
  /// In en, this message translates to:
  /// **'Target UID (e.g. Product ID)'**
  String get targetUid;

  /// No description provided for @taxExempt.
  ///
  /// In en, this message translates to:
  /// **'Tax Exempt'**
  String get taxExempt;

  /// No description provided for @totalRefundAmount.
  ///
  /// In en, this message translates to:
  /// **'TOTAL REFUND AMOUNT'**
  String get totalRefundAmount;

  /// No description provided for @turnOffPc.
  ///
  /// In en, this message translates to:
  /// **'Turn off PC'**
  String get turnOffPc;

  /// No description provided for @colType.
  ///
  /// In en, this message translates to:
  /// **'TYPE'**
  String get colType;

  /// No description provided for @updateDevicePin.
  ///
  /// In en, this message translates to:
  /// **'Update Device PIN'**
  String get updateDevicePin;

  /// No description provided for @updatePinForDevice.
  ///
  /// In en, this message translates to:
  /// **'Update PIN for this Device'**
  String get updatePinForDevice;

  /// No description provided for @useWeight.
  ///
  /// In en, this message translates to:
  /// **'Use weight'**
  String get useWeight;

  /// No description provided for @userInfo.
  ///
  /// In en, this message translates to:
  /// **'User info'**
  String get userInfo;

  /// No description provided for @userInfoSecurity.
  ///
  /// In en, this message translates to:
  /// **'User Info & Security'**
  String get userInfoSecurity;

  /// No description provided for @viewOpenSales.
  ///
  /// In en, this message translates to:
  /// **'View open sales'**
  String get viewOpenSales;

  /// No description provided for @viewSalesHistory.
  ///
  /// In en, this message translates to:
  /// **'View sales history'**
  String get viewSalesHistory;

  /// No description provided for @voidReasons.
  ///
  /// In en, this message translates to:
  /// **'Void Reasons'**
  String get voidReasons;

  /// No description provided for @welcomeToYourPos.
  ///
  /// In en, this message translates to:
  /// **'Welcome to your POS'**
  String get welcomeToYourPos;

  /// No description provided for @errorLoadingBookings.
  ///
  /// In en, this message translates to:
  /// **'Error loading bookings: {message}'**
  String errorLoadingBookings(String message);

  /// No description provided for @errorLoadingCustomers.
  ///
  /// In en, this message translates to:
  /// **'Error loading customers: {message}'**
  String errorLoadingCustomers(String message);

  /// No description provided for @addPrinter.
  ///
  /// In en, this message translates to:
  /// **'Add printer'**
  String get addPrinter;

  /// No description provided for @addressFormat.
  ///
  /// In en, this message translates to:
  /// **'Address Format'**
  String get addressFormat;

  /// No description provided for @allProducts2.
  ///
  /// In en, this message translates to:
  /// **'All products'**
  String get allProducts2;

  /// No description provided for @forceOnCreditSales.
  ///
  /// In en, this message translates to:
  /// **'Always shown on credit sales; this forces it even when paid'**
  String get forceOnCreditSales;

  /// No description provided for @amountDue.
  ///
  /// In en, this message translates to:
  /// **'Amount due'**
  String get amountDue;

  /// No description provided for @bottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get bottom;

  /// No description provided for @cashDrawerCommand.
  ///
  /// In en, this message translates to:
  /// **'Cash drawer command'**
  String get cashDrawerCommand;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @collapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse Sidebar'**
  String get collapseSidebar;

  /// No description provided for @companyHeader.
  ///
  /// In en, this message translates to:
  /// **'Company Header'**
  String get companyHeader;

  /// No description provided for @companyPhoneTel.
  ///
  /// In en, this message translates to:
  /// **'Company phone (Tel)'**
  String get companyPhoneTel;

  /// No description provided for @companyTaxNumber.
  ///
  /// In en, this message translates to:
  /// **'Company tax number'**
  String get companyTaxNumber;

  /// No description provided for @customLabels.
  ///
  /// In en, this message translates to:
  /// **'Custom Labels'**
  String get customLabels;

  /// No description provided for @customerDetailLabels.
  ///
  /// In en, this message translates to:
  /// **'Customer Detail Labels'**
  String get customerDetailLabels;

  /// No description provided for @customerDetails.
  ///
  /// In en, this message translates to:
  /// **'Customer Details'**
  String get customerDetails;

  /// No description provided for @customizeReceipt.
  ///
  /// In en, this message translates to:
  /// **'Customize Receipt'**
  String get customizeReceipt;

  /// No description provided for @decimalPlaces.
  ///
  /// In en, this message translates to:
  /// **'Decimal places'**
  String get decimalPlaces;

  /// No description provided for @deletePrinter.
  ///
  /// In en, this message translates to:
  /// **'Delete printer'**
  String get deletePrinter;

  /// No description provided for @discountColumn.
  ///
  /// In en, this message translates to:
  /// **'Discount column'**
  String get discountColumn;

  /// No description provided for @hintBarPrinter.
  ///
  /// In en, this message translates to:
  /// **'e.g. Bar printer'**
  String get hintBarPrinter;

  /// No description provided for @expandSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand Sidebar'**
  String get expandSidebar;

  /// No description provided for @font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// No description provided for @fontFamily.
  ///
  /// In en, this message translates to:
  /// **'Font family'**
  String get fontFamily;

  /// No description provided for @fontSettings.
  ///
  /// In en, this message translates to:
  /// **'Font Settings'**
  String get fontSettings;

  /// No description provided for @footer.
  ///
  /// In en, this message translates to:
  /// **'Footer'**
  String get footer;

  /// No description provided for @footerText.
  ///
  /// In en, this message translates to:
  /// **'Footer text'**
  String get footerText;

  /// No description provided for @forRtlLanguages.
  ///
  /// In en, this message translates to:
  /// **'For RTL languages (Arabic, Hebrew)'**
  String get forRtlLanguages;

  /// No description provided for @globalFooter.
  ///
  /// In en, this message translates to:
  /// **'Global footer'**
  String get globalFooter;

  /// No description provided for @globalHeader.
  ///
  /// In en, this message translates to:
  /// **'Global header'**
  String get globalHeader;

  /// No description provided for @header.
  ///
  /// In en, this message translates to:
  /// **'Header'**
  String get header;

  /// No description provided for @headerAndFooter.
  ///
  /// In en, this message translates to:
  /// **'Header & Footer'**
  String get headerAndFooter;

  /// No description provided for @headerText.
  ///
  /// In en, this message translates to:
  /// **'Header text'**
  String get headerText;

  /// No description provided for @invoiceFont.
  ///
  /// In en, this message translates to:
  /// **'Invoice font'**
  String get invoiceFont;

  /// No description provided for @invoiceSettings.
  ///
  /// In en, this message translates to:
  /// **'Invoice Settings'**
  String get invoiceSettings;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'Items count'**
  String get itemsCount;

  /// No description provided for @kitchenPrinting.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Printing'**
  String get kitchenPrinting;

  /// No description provided for @leftSide.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get leftSide;

  /// No description provided for @localizeText.
  ///
  /// In en, this message translates to:
  /// **'Localize Text'**
  String get localizeText;

  /// No description provided for @marginsMm.
  ///
  /// In en, this message translates to:
  /// **'Margins (in millimeters)'**
  String get marginsMm;

  /// No description provided for @mergeIdenticalItems.
  ///
  /// In en, this message translates to:
  /// **'Merge identical items'**
  String get mergeIdenticalItems;

  /// No description provided for @noCategoryFilter.
  ///
  /// In en, this message translates to:
  /// **'No category filter — prints every item'**
  String get noCategoryFilter;

  /// No description provided for @noPrintersFound.
  ///
  /// In en, this message translates to:
  /// **'No printers found'**
  String get noPrintersFound;

  /// No description provided for @numberOfCopies.
  ///
  /// In en, this message translates to:
  /// **'Number of Copies'**
  String get numberOfCopies;

  /// No description provided for @openCashDrawerLower.
  ///
  /// In en, this message translates to:
  /// **'Open cash drawer'**
  String get openCashDrawerLower;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get options;

  /// No description provided for @orderNumberLower.
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get orderNumberLower;

  /// No description provided for @otherSettings.
  ///
  /// In en, this message translates to:
  /// **'Other Settings'**
  String get otherSettings;

  /// No description provided for @outstandingBalance.
  ///
  /// In en, this message translates to:
  /// **'Outstanding balance'**
  String get outstandingBalance;

  /// No description provided for @paidAmount.
  ///
  /// In en, this message translates to:
  /// **'Paid amount'**
  String get paidAmount;

  /// No description provided for @paymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get paymentMethods;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @printAddress.
  ///
  /// In en, this message translates to:
  /// **'Print address'**
  String get printAddress;

  /// No description provided for @printBarcode.
  ///
  /// In en, this message translates to:
  /// **'Print barcode'**
  String get printBarcode;

  /// No description provided for @printCategory.
  ///
  /// In en, this message translates to:
  /// **'Print Category'**
  String get printCategory;

  /// No description provided for @printDemoReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print demo receipt'**
  String get printDemoReceipt;

  /// No description provided for @printInA5.
  ///
  /// In en, this message translates to:
  /// **'Print in A5 size'**
  String get printInA5;

  /// No description provided for @printItemsCount.
  ///
  /// In en, this message translates to:
  /// **'Print items count'**
  String get printItemsCount;

  /// No description provided for @printKitchenTicket.
  ///
  /// In en, this message translates to:
  /// **'Print kitchen ticket'**
  String get printKitchenTicket;

  /// No description provided for @printLargeOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Print large order number'**
  String get printLargeOrderNumber;

  /// No description provided for @printLogoFullWidth.
  ///
  /// In en, this message translates to:
  /// **'Print logo full width'**
  String get printLogoFullWidth;

  /// No description provided for @printMeasurementUnit.
  ///
  /// In en, this message translates to:
  /// **'Print measurement unit'**
  String get printMeasurementUnit;

  /// No description provided for @printTrailingCounter.
  ///
  /// In en, this message translates to:
  /// **'Print only the trailing counter (e.g. 000008)'**
  String get printTrailingCounter;

  /// No description provided for @printOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Print order number'**
  String get printOrderNumber;

  /// No description provided for @printOutstandingBalance.
  ///
  /// In en, this message translates to:
  /// **'Print outstanding balance'**
  String get printOutstandingBalance;

  /// No description provided for @printPhoneTel.
  ///
  /// In en, this message translates to:
  /// **'Print phone (Tel)'**
  String get printPhoneTel;

  /// No description provided for @printTaxName.
  ///
  /// In en, this message translates to:
  /// **'Print tax name'**
  String get printTaxName;

  /// No description provided for @printTaxNumber.
  ///
  /// In en, this message translates to:
  /// **'Print tax number'**
  String get printTaxNumber;

  /// No description provided for @printTaxTotals.
  ///
  /// In en, this message translates to:
  /// **'Print tax totals'**
  String get printTaxTotals;

  /// No description provided for @printTemplates.
  ///
  /// In en, this message translates to:
  /// **'Print Templates'**
  String get printTemplates;

  /// No description provided for @printTotalQuantity.
  ///
  /// In en, this message translates to:
  /// **'Print total quantity'**
  String get printTotalQuantity;

  /// No description provided for @printerName.
  ///
  /// In en, this message translates to:
  /// **'Printer name'**
  String get printerName;

  /// No description provided for @printerSettings.
  ///
  /// In en, this message translates to:
  /// **'Printer settings'**
  String get printerSettings;

  /// No description provided for @printers.
  ///
  /// In en, this message translates to:
  /// **'Printers'**
  String get printers;

  /// No description provided for @productGroupsUpper.
  ///
  /// In en, this message translates to:
  /// **'PRODUCT GROUPS'**
  String get productGroupsUpper;

  /// No description provided for @receiptContent.
  ///
  /// In en, this message translates to:
  /// **'Receipt Content'**
  String get receiptContent;

  /// No description provided for @receiptLabels.
  ///
  /// In en, this message translates to:
  /// **'Receipt Labels'**
  String get receiptLabels;

  /// No description provided for @receiptNumber.
  ///
  /// In en, this message translates to:
  /// **'Receipt number'**
  String get receiptNumber;

  /// No description provided for @refreshAll.
  ///
  /// In en, this message translates to:
  /// **'Refresh all'**
  String get refreshAll;

  /// No description provided for @refreshPrinters.
  ///
  /// In en, this message translates to:
  /// **'Refresh printers'**
  String get refreshPrinters;

  /// No description provided for @renamePrinter.
  ///
  /// In en, this message translates to:
  /// **'Rename printer'**
  String get renamePrinter;

  /// No description provided for @reporting.
  ///
  /// In en, this message translates to:
  /// **'Reporting'**
  String get reporting;

  /// No description provided for @restricted.
  ///
  /// In en, this message translates to:
  /// **'Restricted'**
  String get restricted;

  /// No description provided for @rightSide.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get rightSide;

  /// No description provided for @rightToLeft.
  ///
  /// In en, this message translates to:
  /// **'Right to left'**
  String get rightToLeft;

  /// No description provided for @cashDrawerSignalHint.
  ///
  /// In en, this message translates to:
  /// **'Sends a signal to the cash drawer after checkout'**
  String get cashDrawerSignalHint;

  /// No description provided for @shortReceiptNumber.
  ///
  /// In en, this message translates to:
  /// **'Short receipt number'**
  String get shortReceiptNumber;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @taxColumn.
  ///
  /// In en, this message translates to:
  /// **'Tax column'**
  String get taxColumn;

  /// No description provided for @taxNumber.
  ///
  /// In en, this message translates to:
  /// **'Tax number'**
  String get taxNumber;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @top.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get top;

  /// No description provided for @topCustomers.
  ///
  /// In en, this message translates to:
  /// **'TOP CUSTOMERS'**
  String get topCustomers;

  /// No description provided for @topProducts.
  ///
  /// In en, this message translates to:
  /// **'TOP PRODUCTS'**
  String get topProducts;

  /// No description provided for @totalRevenue.
  ///
  /// In en, this message translates to:
  /// **'TOTAL REVENUE'**
  String get totalRevenue;

  /// No description provided for @fallbackWordingHint.
  ///
  /// In en, this message translates to:
  /// **'Turn off to fall back to the built-in wording'**
  String get fallbackWordingHint;

  /// No description provided for @useCustomLabels.
  ///
  /// In en, this message translates to:
  /// **'Use custom labels in reports and invoices'**
  String get useCustomLabels;

  /// No description provided for @kitchenFireHint.
  ///
  /// In en, this message translates to:
  /// **'Fire this printer when the Kitchen button is pressed. With'**
  String get kitchenFireHint;

  /// No description provided for @myCompanyLower.
  ///
  /// In en, this message translates to:
  /// **'My company'**
  String get myCompanyLower;

  /// No description provided for @customersSuppliersLower.
  ///
  /// In en, this message translates to:
  /// **'Customers & suppliers'**
  String get customersSuppliersLower;

  /// No description provided for @usersSecurityLower.
  ///
  /// In en, this message translates to:
  /// **'Users & security'**
  String get usersSecurityLower;

  /// No description provided for @voidReasonsLower.
  ///
  /// In en, this message translates to:
  /// **'Void reasons'**
  String get voidReasonsLower;

  /// No description provided for @taxRatesLower.
  ///
  /// In en, this message translates to:
  /// **'Tax rates'**
  String get taxRatesLower;

  /// No description provided for @paymentTypesLower.
  ///
  /// In en, this message translates to:
  /// **'Payment types'**
  String get paymentTypesLower;

  /// No description provided for @rptSalesByProduct.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get rptSalesByProduct;

  /// No description provided for @rptSalesByGroup.
  ///
  /// In en, this message translates to:
  /// **'Product groups'**
  String get rptSalesByGroup;

  /// No description provided for @rptSalesByCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get rptSalesByCustomer;

  /// No description provided for @rptTaxRates.
  ///
  /// In en, this message translates to:
  /// **'Tax rates'**
  String get rptTaxRates;

  /// No description provided for @rptUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get rptUsers;

  /// No description provided for @rptItemList.
  ///
  /// In en, this message translates to:
  /// **'Item list'**
  String get rptItemList;

  /// No description provided for @rptPaymentTypes.
  ///
  /// In en, this message translates to:
  /// **'Payment types'**
  String get rptPaymentTypes;

  /// No description provided for @rptPaymentByUser.
  ///
  /// In en, this message translates to:
  /// **'Payment types by users'**
  String get rptPaymentByUser;

  /// No description provided for @rptPaymentByCustomer.
  ///
  /// In en, this message translates to:
  /// **'Payment types by customers'**
  String get rptPaymentByCustomer;

  /// No description provided for @rptRefunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get rptRefunds;

  /// No description provided for @rptInvoiceList.
  ///
  /// In en, this message translates to:
  /// **'Invoice list'**
  String get rptInvoiceList;

  /// No description provided for @rptDailySales.
  ///
  /// In en, this message translates to:
  /// **'Daily sales'**
  String get rptDailySales;

  /// No description provided for @rptHourlySales.
  ///
  /// In en, this message translates to:
  /// **'Hourly sales'**
  String get rptHourlySales;

  /// No description provided for @rptHourlyByGroup.
  ///
  /// In en, this message translates to:
  /// **'Hourly sales by product groups'**
  String get rptHourlyByGroup;

  /// No description provided for @rptByTable.
  ///
  /// In en, this message translates to:
  /// **'Table or order number'**
  String get rptByTable;

  /// No description provided for @rptProfitMargin.
  ///
  /// In en, this message translates to:
  /// **'Profit & margin'**
  String get rptProfitMargin;

  /// No description provided for @rptUnpaidSales.
  ///
  /// In en, this message translates to:
  /// **'Unpaid sales'**
  String get rptUnpaidSales;

  /// No description provided for @rptStartingCash.
  ///
  /// In en, this message translates to:
  /// **'Starting cash entries'**
  String get rptStartingCash;

  /// No description provided for @rptVoidedItems.
  ///
  /// In en, this message translates to:
  /// **'Voided items'**
  String get rptVoidedItems;

  /// No description provided for @rptDiscountsGranted.
  ///
  /// In en, this message translates to:
  /// **'Discounts granted'**
  String get rptDiscountsGranted;

  /// No description provided for @rptDiscountsBySource.
  ///
  /// In en, this message translates to:
  /// **'Discounts by source'**
  String get rptDiscountsBySource;

  /// No description provided for @rptItemDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Items discounts'**
  String get rptItemDiscounts;

  /// No description provided for @rptStockMovement.
  ///
  /// In en, this message translates to:
  /// **'Stock movement'**
  String get rptStockMovement;

  /// No description provided for @rptSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get rptSuppliers;

  /// No description provided for @rptUnpaidPurchase.
  ///
  /// In en, this message translates to:
  /// **'Unpaid purchase'**
  String get rptUnpaidPurchase;

  /// No description provided for @rptPurchaseDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Purchase discounts'**
  String get rptPurchaseDiscounts;

  /// No description provided for @rptPurchasedItemDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Purchased items discounts'**
  String get rptPurchasedItemDiscounts;

  /// No description provided for @rptPurchaseInvoiceList.
  ///
  /// In en, this message translates to:
  /// **'Purchase invoice list'**
  String get rptPurchaseInvoiceList;

  /// No description provided for @rptExpirationDate.
  ///
  /// In en, this message translates to:
  /// **'Expiration date'**
  String get rptExpirationDate;

  /// No description provided for @rptReorderList.
  ///
  /// In en, this message translates to:
  /// **'Reorder product list'**
  String get rptReorderList;

  /// No description provided for @rptLowStockWarning.
  ///
  /// In en, this message translates to:
  /// **'Low stock warning'**
  String get rptLowStockWarning;

  /// No description provided for @rptTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get rptTransactionHistory;

  /// No description provided for @secSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get secSales;

  /// No description provided for @secPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get secPurchase;

  /// No description provided for @secStockReturn.
  ///
  /// In en, this message translates to:
  /// **'Stock Return'**
  String get secStockReturn;

  /// No description provided for @secLossAndDamage.
  ///
  /// In en, this message translates to:
  /// **'Loss and damage'**
  String get secLossAndDamage;

  /// No description provided for @secStockControl.
  ///
  /// In en, this message translates to:
  /// **'Stock control'**
  String get secStockControl;

  /// No description provided for @secFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get secFinance;

  /// No description provided for @accent.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get accent;

  /// No description provided for @backups.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get backups;

  /// No description provided for @barcodeScanning.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanning'**
  String get barcodeScanning;

  /// No description provided for @clockInUpper.
  ///
  /// In en, this message translates to:
  /// **'CLOCK IN'**
  String get clockInUpper;

  /// No description provided for @clockOutUpper.
  ///
  /// In en, this message translates to:
  /// **'CLOCK OUT'**
  String get clockOutUpper;

  /// No description provided for @customerDisplayLower.
  ///
  /// In en, this message translates to:
  /// **'Customer display'**
  String get customerDisplayLower;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @databaseLower.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get databaseLower;

  /// No description provided for @deviceNameLower.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get deviceNameLower;

  /// No description provided for @dualCurrencyLower.
  ///
  /// In en, this message translates to:
  /// **'Dual Currency'**
  String get dualCurrencyLower;

  /// No description provided for @enableBookings.
  ///
  /// In en, this message translates to:
  /// **'Enable bookings'**
  String get enableBookings;

  /// No description provided for @endOfDayLower.
  ///
  /// In en, this message translates to:
  /// **'End of day'**
  String get endOfDayLower;

  /// No description provided for @generalLower.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalLower;

  /// No description provided for @kitchenDisplayLower.
  ///
  /// In en, this message translates to:
  /// **'Kitchen display'**
  String get kitchenDisplayLower;

  /// No description provided for @loadingCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Loading currencies…'**
  String get loadingCurrencies;

  /// No description provided for @loyaltyCardsLower.
  ///
  /// In en, this message translates to:
  /// **'Loyalty cards'**
  String get loyaltyCardsLower;

  /// No description provided for @onScreenKeyboard.
  ///
  /// In en, this message translates to:
  /// **'On-screen keyboard'**
  String get onScreenKeyboard;

  /// No description provided for @openReservation.
  ///
  /// In en, this message translates to:
  /// **'Open reservation'**
  String get openReservation;

  /// No description provided for @reservedTable.
  ///
  /// In en, this message translates to:
  /// **'Reserved table'**
  String get reservedTable;

  /// No description provided for @selectCustomerLower.
  ///
  /// In en, this message translates to:
  /// **'Select customer'**
  String get selectCustomerLower;

  /// No description provided for @selectEllipsisShort.
  ///
  /// In en, this message translates to:
  /// **'Select…'**
  String get selectEllipsisShort;

  /// No description provided for @touchKeyboardHint.
  ///
  /// In en, this message translates to:
  /// **'Show a touch keyboard when typing.'**
  String get touchKeyboardHint;

  /// No description provided for @subscriptionUpper.
  ///
  /// In en, this message translates to:
  /// **'SUBSCRIPTION'**
  String get subscriptionUpper;

  /// No description provided for @takeReservationsHint.
  ///
  /// In en, this message translates to:
  /// **'Take reservations in advance.'**
  String get takeReservationsHint;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @timeClockTitle.
  ///
  /// In en, this message translates to:
  /// **'Time Clock'**
  String get timeClockTitle;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @totalUpper.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get totalUpper;

  /// No description provided for @walkIn.
  ///
  /// In en, this message translates to:
  /// **'Walk-in'**
  String get walkIn;

  /// No description provided for @weighingScaleLower.
  ///
  /// In en, this message translates to:
  /// **'Weighing scale'**
  String get weighingScaleLower;

  /// No description provided for @trimZerosFromCode.
  ///
  /// In en, this message translates to:
  /// **'Remove zeros from product code (trim zeros)'**
  String get trimZerosFromCode;

  /// No description provided for @posNamePrefixHint.
  ///
  /// In en, this message translates to:
  /// **'POS name — prefix for document numbers'**
  String get posNamePrefixHint;

  /// No description provided for @promotionsLower.
  ///
  /// In en, this message translates to:
  /// **'Promotions'**
  String get promotionsLower;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'A fast, offline-first point of sale for your counter and your tablets. Set it up in a few quick taps.'**
  String get welcomeBody;

  /// No description provided for @featBarcodeBody.
  ///
  /// In en, this message translates to:
  /// **'Scan to ring up or find any product instantly.'**
  String get featBarcodeBody;

  /// No description provided for @featCustomerDisplayBody.
  ///
  /// In en, this message translates to:
  /// **'Show the order and total on a second screen.'**
  String get featCustomerDisplayBody;

  /// No description provided for @featKitchenBody.
  ///
  /// In en, this message translates to:
  /// **'Send orders straight to the kitchen (KDS).'**
  String get featKitchenBody;

  /// No description provided for @featBackupsBody.
  ///
  /// In en, this message translates to:
  /// **'Automatic local backups keep your data safe.'**
  String get featBackupsBody;

  /// No description provided for @featScaleBody.
  ///
  /// In en, this message translates to:
  /// **'Sell by weight over a connected serial scale.'**
  String get featScaleBody;

  /// No description provided for @featPromotionsBody.
  ///
  /// In en, this message translates to:
  /// **'Automatic discounts and special pricing.'**
  String get featPromotionsBody;

  /// No description provided for @featLoyaltyBody.
  ///
  /// In en, this message translates to:
  /// **'Points and rewards that bring guests back.'**
  String get featLoyaltyBody;

  /// No description provided for @exitManagement.
  ///
  /// In en, this message translates to:
  /// **'Exit Management'**
  String get exitManagement;

  /// No description provided for @chooseColumns.
  ///
  /// In en, this message translates to:
  /// **'Choose columns'**
  String get chooseColumns;

  /// No description provided for @viewPrintReceipt.
  ///
  /// In en, this message translates to:
  /// **'View & Print Receipt'**
  String get viewPrintReceipt;

  /// No description provided for @deleteItemAction.
  ///
  /// In en, this message translates to:
  /// **'Delete Item'**
  String get deleteItemAction;

  /// No description provided for @editItemAction.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get editItemAction;

  /// No description provided for @noStockAssigned.
  ///
  /// In en, this message translates to:
  /// **'No stock assigned to this'**
  String get noStockAssigned;

  /// No description provided for @noStockControlRules.
  ///
  /// In en, this message translates to:
  /// **'No stock control rules configured'**
  String get noStockControlRules;

  /// No description provided for @selectGroupToEdit.
  ///
  /// In en, this message translates to:
  /// **'Select a group to edit, or create a new one.'**
  String get selectGroupToEdit;

  /// No description provided for @editNamedTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String editNamedTitle(Object name);

  /// No description provided for @forceResetPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Force Reset PIN: {name}'**
  String forceResetPinTitle(Object name);

  /// No description provided for @forceResetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Force Reset Password: {name}'**
  String forceResetPasswordTitle(Object name);

  /// No description provided for @editPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Payment #{id}'**
  String editPaymentTitle(Object id);

  /// No description provided for @editDashTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit — {name}'**
  String editDashTitle(Object name);

  /// No description provided for @confirmDeleteQuoted.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \'{name}\'?'**
  String confirmDeleteQuoted(Object name);

  /// No description provided for @codeValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Code: {code}'**
  String codeValueLabel(Object code);

  /// No description provided for @idValueLabel.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String idValueLabel(Object id);

  /// No description provided for @assignProductToWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Assign {name} to Warehouse'**
  String assignProductToWarehouse(Object name);

  /// No description provided for @deleteQuotedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteQuotedConfirm(Object name);

  /// No description provided for @deletePlainConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deletePlainConfirm(Object name);

  /// No description provided for @removeDiscardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"? Its settings will be discarded.'**
  String removeDiscardConfirm(Object name);

  /// No description provided for @removeQuotedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"?'**
  String removeQuotedConfirm(Object name);

  /// No description provided for @typeValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String typeValueLabel(Object type);

  /// No description provided for @ofPagesLabel.
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String ofPagesLabel(Object total);

  /// No description provided for @fixedAmountSymLabel.
  ///
  /// In en, this message translates to:
  /// **'Fixed Amount ({sym})'**
  String fixedAmountSymLabel(Object sym);

  /// No description provided for @couldNotReadSyncStatus.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read sync status: {message}'**
  String couldNotReadSyncStatus(Object message);

  /// No description provided for @uidValueLabel.
  ///
  /// In en, this message translates to:
  /// **'UID: {uid} | Value: {value}'**
  String uidValueLabel(Object uid, Object value);

  /// No description provided for @enterFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Enter {field}'**
  String enterFieldHint(Object field);

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @noStockAssignedWarehouse.
  ///
  /// In en, this message translates to:
  /// **'No stock assigned to this warehouse'**
  String get noStockAssignedWarehouse;

  /// No description provided for @noStockAssignedProduct.
  ///
  /// In en, this message translates to:
  /// **'No stock assigned to this product'**
  String get noStockAssignedProduct;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummary;

  /// No description provided for @promotionLabel.
  ///
  /// In en, this message translates to:
  /// **'Promotion'**
  String get promotionLabel;

  /// No description provided for @subtotalInclTax.
  ///
  /// In en, this message translates to:
  /// **'Subtotal (incl. tax)'**
  String get subtotalInclTax;

  /// No description provided for @customerDiscountLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer discount'**
  String get customerDiscountLabel;

  /// No description provided for @cartDiscountLabel.
  ///
  /// In en, this message translates to:
  /// **'Cart discount'**
  String get cartDiscountLabel;

  /// No description provided for @taxInclLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax (incl.)'**
  String get taxInclLabel;

  /// No description provided for @itemDiscountLabel.
  ///
  /// In en, this message translates to:
  /// **'Item discount'**
  String get itemDiscountLabel;

  /// No description provided for @itemDiscountsPlural.
  ///
  /// In en, this message translates to:
  /// **'Item discounts'**
  String get itemDiscountsPlural;

  /// No description provided for @taxesLabel.
  ///
  /// In en, this message translates to:
  /// **'Taxes'**
  String get taxesLabel;

  /// No description provided for @pointsRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Points Redeemed'**
  String get pointsRedeemed;

  /// No description provided for @subtotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotalLabel;

  /// No description provided for @applyDiscount.
  ///
  /// In en, this message translates to:
  /// **'Apply Discount'**
  String get applyDiscount;

  /// No description provided for @cartTab.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cartTab;

  /// No description provided for @itemTab.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get itemTab;

  /// No description provided for @selectItemFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select an item in the cart first.'**
  String get selectItemFirst;

  /// No description provided for @noItemSelected.
  ///
  /// In en, this message translates to:
  /// **'No item selected!'**
  String get noItemSelected;

  /// No description provided for @selectedItemNotFound.
  ///
  /// In en, this message translates to:
  /// **'Selected item not found.'**
  String get selectedItemNotFound;

  /// No description provided for @discountBelowCost.
  ///
  /// In en, this message translates to:
  /// **'Discount would price item below cost.'**
  String get discountBelowCost;

  /// No description provided for @discountNegativePrice.
  ///
  /// In en, this message translates to:
  /// **'Discount would result in a negative price.'**
  String get discountNegativePrice;

  /// No description provided for @inclPrefix.
  ///
  /// In en, this message translates to:
  /// **'incl. {name}'**
  String inclPrefix(Object name);

  /// No description provided for @saveAndRestart.
  ///
  /// In en, this message translates to:
  /// **'Save & Restart'**
  String get saveAndRestart;

  /// No description provided for @resourceMode.
  ///
  /// In en, this message translates to:
  /// **'Resource Mode'**
  String get resourceMode;

  /// No description provided for @resourceModeHint.
  ///
  /// In en, this message translates to:
  /// **'What a booking slot is assigned to'**
  String get resourceModeHint;

  /// No description provided for @defaultDuration.
  ///
  /// In en, this message translates to:
  /// **'Default Duration'**
  String get defaultDuration;

  /// No description provided for @defaultDurationHint.
  ///
  /// In en, this message translates to:
  /// **'Pre-filled slot length when adding a booking'**
  String get defaultDurationHint;

  /// No description provided for @timeSnapping.
  ///
  /// In en, this message translates to:
  /// **'Time Snapping'**
  String get timeSnapping;

  /// No description provided for @timeSnappingHint.
  ///
  /// In en, this message translates to:
  /// **'Grid interval when picking start/end times'**
  String get timeSnappingHint;

  /// No description provided for @couldNotLoadCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Could not load currencies'**
  String get couldNotLoadCurrencies;

  /// No description provided for @fontPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview: the quick brown fox'**
  String get fontPreview;

  /// No description provided for @chooseTheme.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE THEME'**
  String get chooseTheme;

  /// No description provided for @posButtonsHint.
  ///
  /// In en, this message translates to:
  /// **'Select which action buttons appear on the main POS screen.'**
  String get posButtonsHint;

  /// No description provided for @couldNotLoadTaxRates.
  ///
  /// In en, this message translates to:
  /// **'Could not load tax rates'**
  String get couldNotLoadTaxRates;

  /// No description provided for @noTaxRatesDefined.
  ///
  /// In en, this message translates to:
  /// **'No tax rates defined yet. Add them under Tax Rates.'**
  String get noTaxRatesDefined;

  /// No description provided for @couldNotLoadWarehouses.
  ///
  /// In en, this message translates to:
  /// **'Could not load warehouses'**
  String get couldNotLoadWarehouses;

  /// No description provided for @defaultWarehouseHint.
  ///
  /// In en, this message translates to:
  /// **'Used to check product stock availability in the POS menu.'**
  String get defaultWarehouseHint;

  /// No description provided for @waitingForScale.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the scale to send a weight…'**
  String get waitingForScale;

  /// No description provided for @restoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get restoreDefaults;

  /// No description provided for @sameMachineSecondMonitor.
  ///
  /// In en, this message translates to:
  /// **'Same machine / second monitor'**
  String get sameMachineSecondMonitor;

  /// No description provided for @otherDeviceSameNetwork.
  ///
  /// In en, this message translates to:
  /// **'Other device on same network'**
  String get otherDeviceSameNetwork;

  /// No description provided for @categoriesPrintedOnGroup.
  ///
  /// In en, this message translates to:
  /// **'Categories printed on this printer group'**
  String get categoriesPrintedOnGroup;

  /// No description provided for @noPrinterGroupsYet.
  ///
  /// In en, this message translates to:
  /// **'No printer groups yet.'**
  String get noPrinterGroupsYet;

  /// No description provided for @noKitchenDisplays.
  ///
  /// In en, this message translates to:
  /// **'No kitchen displays configured.'**
  String get noKitchenDisplays;

  /// No description provided for @noGroupSelectedReceivesAll.
  ///
  /// In en, this message translates to:
  /// **'No group selected → receives all items.'**
  String get noGroupSelectedReceivesAll;

  /// No description provided for @openDatabaseLocation.
  ///
  /// In en, this message translates to:
  /// **'Open database location'**
  String get openDatabaseLocation;

  /// No description provided for @setZeroToDisableBackups.
  ///
  /// In en, this message translates to:
  /// **'Set to 0 to turn off scheduled backups'**
  String get setZeroToDisableBackups;

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @statusInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get statusInvalid;

  /// No description provided for @statusNotActivated.
  ///
  /// In en, this message translates to:
  /// **'Not activated'**
  String get statusNotActivated;

  /// No description provided for @onboardingWillShow.
  ///
  /// In en, this message translates to:
  /// **'Onboarding will show the next time you open the app.'**
  String get onboardingWillShow;

  /// No description provided for @autoLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoLabel;

  /// No description provided for @themeDimmed.
  ///
  /// In en, this message translates to:
  /// **'Dimmed'**
  String get themeDimmed;

  /// No description provided for @themeNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get themeNight;

  /// No description provided for @themeGray.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get themeGray;

  /// No description provided for @themeHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High Contrast'**
  String get themeHighContrast;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get colorPink;

  /// No description provided for @colorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colorPurple;

  /// No description provided for @colorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @allFields.
  ///
  /// In en, this message translates to:
  /// **'All fields'**
  String get allFields;

  /// No description provided for @signInOnlineAgain.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in online to use the POS again.'**
  String get signInOnlineAgain;

  /// No description provided for @tablesLabel.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get tablesLabel;

  /// No description provided for @bookingLabel.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get bookingLabel;

  /// No description provided for @posNameFullHint.
  ///
  /// In en, this message translates to:
  /// **'A short, UNIQUE name for this terminal. It becomes the prefix of every document number (e.g. CAISSE1-200-000045), so two POS never produce the same number. Letters & digits only.'**
  String get posNameFullHint;

  /// No description provided for @defaultTaxRateFullHint.
  ///
  /// In en, this message translates to:
  /// **'Automatically applied to products added to the cart that have no tax of their own.'**
  String get defaultTaxRateFullHint;

  /// No description provided for @serialScaleWindowsOnly.
  ///
  /// In en, this message translates to:
  /// **'Serial scales are supported on Windows only. On this device, use the barcode parsing option above with a label-printing scale.'**
  String get serialScaleWindowsOnly;

  /// No description provided for @openCustomerDisplayFullHint.
  ///
  /// In en, this message translates to:
  /// **'Opens the customer display as a full-screen Flutter view on this machine. Ideal for a second monitor — drag the window over and press F11.'**
  String get openCustomerDisplayFullHint;

  /// No description provided for @printerGroupsHelp.
  ///
  /// In en, this message translates to:
  /// **'Group product categories into stations (e.g. Kitchen, Barman). Assign a group to a display below and that display only shows the items in those categories.'**
  String get printerGroupsHelp;

  /// No description provided for @receivesAllItems.
  ///
  /// In en, this message translates to:
  /// **'Receives all items. Create printer groups above to route by category.'**
  String get receivesAllItems;

  /// No description provided for @autoSyncFullHint.
  ///
  /// In en, this message translates to:
  /// **'Push your local changes and pull fresh data automatically in the background.'**
  String get autoSyncFullHint;

  /// No description provided for @replayOnboardingHint.
  ///
  /// In en, this message translates to:
  /// **'Replay the first-run welcome tour. It shows again the next time you open the app on this device.'**
  String get replayOnboardingHint;

  /// No description provided for @pairingRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Pairing request sent to {ip} — the KDS should switch to the kitchen view.'**
  String pairingRequestSent(Object ip);

  /// No description provided for @kdsTabletsHelp.
  ///
  /// In en, this message translates to:
  /// **'Each Kitchen Display tablet listens on port {port}. Adding its IP pairs it with this POS and pushes orders directly over the local network — the KDS works fully offline, no internet needed.'**
  String kdsTabletsHelp(Object port);

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get statusEnabled;

  /// No description provided for @statusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get statusDisabled;

  /// No description provided for @statusOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get statusOn;

  /// No description provided for @statusOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get statusOff;

  /// No description provided for @expiresInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Expires in 1 day} other{Expires in {count} days}}'**
  String expiresInDays(num count);

  /// No description provided for @deviceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 device} other{{count} devices}}'**
  String deviceCount(num count);

  /// No description provided for @scaleBarcodePriceHint.
  ///
  /// In en, this message translates to:
  /// **'When on, the encoded value is a price and quantity is calculated as price ÷ unit price'**
  String get scaleBarcodePriceHint;

  /// No description provided for @webDisplayHint.
  ///
  /// In en, this message translates to:
  /// **'Host an interactive order screen accessible from any browser on your network'**
  String get webDisplayHint;

  /// No description provided for @savedFieldFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save {field}'**
  String savedFieldFailed(Object field);

  /// No description provided for @prefixColonValue.
  ///
  /// In en, this message translates to:
  /// **'Prefix: {prefix}'**
  String prefixColonValue(Object prefix);

  /// No description provided for @unlinkEmailWarning.
  ///
  /// In en, this message translates to:
  /// **'This will unlink {email} from this terminal. You will need to sign in online to use the POS again.'**
  String unlinkEmailWarning(Object email);

  /// No description provided for @unlinkTerminalWarning.
  ///
  /// In en, this message translates to:
  /// **'This will unlink this terminal. You will need to sign in online to use the POS again.'**
  String get unlinkTerminalWarning;

  /// No description provided for @builtInBadge.
  ///
  /// In en, this message translates to:
  /// **'BUILT-IN'**
  String get builtInBadge;

  /// No description provided for @printerType.
  ///
  /// In en, this message translates to:
  /// **'Printer type'**
  String get printerType;

  /// No description provided for @paperSize.
  ///
  /// In en, this message translates to:
  /// **'Paper size'**
  String get paperSize;

  /// No description provided for @copiesPerTransaction.
  ///
  /// In en, this message translates to:
  /// **'Copies per transaction'**
  String get copiesPerTransaction;

  /// No description provided for @headerPrintedTopHint.
  ///
  /// In en, this message translates to:
  /// **'Printed at the top of every receipt'**
  String get headerPrintedTopHint;

  /// No description provided for @footerThankYouHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Thank you for shopping with us!'**
  String get footerThankYouHint;

  /// No description provided for @generalLabel.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @chooseCustomerDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Choose what customer details are printed on the receipt.'**
  String get chooseCustomerDetailsHint;

  /// No description provided for @addressFormatFullHint.
  ///
  /// In en, this message translates to:
  /// **'Specify how address lines are printed on receipts and invoices.'**
  String get addressFormatFullHint;

  /// No description provided for @tapPlaceholderHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a placeholder to insert it:'**
  String get tapPlaceholderHint;

  /// No description provided for @invoiceTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. TAX INVOICE'**
  String get invoiceTitleHint;

  /// No description provided for @invoiceHeaderHint.
  ///
  /// In en, this message translates to:
  /// **'Printed above the invoice'**
  String get invoiceHeaderHint;

  /// No description provided for @invoiceFooterHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. bank details, terms'**
  String get invoiceFooterHint;

  /// No description provided for @addPrinterHint.
  ///
  /// In en, this message translates to:
  /// **'Add a printer for each station, then open its settings to configure paper size, margins, header/footer and the cash drawer.'**
  String get addPrinterHint;

  /// No description provided for @kitchenFireFullHint.
  ///
  /// In en, this message translates to:
  /// **'Fire this printer when the Kitchen button is pressed. With several enabled, the category below decides what each prints.'**
  String get kitchenFireFullHint;

  /// No description provided for @categoryFilterHint.
  ///
  /// In en, this message translates to:
  /// **'This printer only prints products whose category belongs to the selected group (e.g. Barman → drinks). Pick \"All products\" to print the whole ticket here.'**
  String get categoryFilterHint;

  /// No description provided for @noPrinterGroupsDefined.
  ///
  /// In en, this message translates to:
  /// **'No printer groups defined yet. Create them in Settings → Customer Display → Printer Groups.'**
  String get noPrinterGroupsDefined;

  /// No description provided for @headerDetailsFullHint.
  ///
  /// In en, this message translates to:
  /// **'Details printed under the logo / business name at the top of the receipt. The header and footer text themselves are set per printer (⚙ → General).'**
  String get headerDetailsFullHint;

  /// No description provided for @sessionExpiredMsg.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get sessionExpiredMsg;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get enterPin;

  /// No description provided for @syncingMasterData.
  ///
  /// In en, this message translates to:
  /// **'Syncing master data…'**
  String get syncingMasterData;

  /// No description provided for @confirmNewPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm New PIN'**
  String get confirmNewPin;

  /// No description provided for @createFourDigitPin.
  ///
  /// In en, this message translates to:
  /// **'Create 4-Digit PIN'**
  String get createFourDigitPin;

  /// No description provided for @companyName.
  ///
  /// In en, this message translates to:
  /// **'Company Name'**
  String get companyName;

  /// No description provided for @taxNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax Number'**
  String get taxNumberLabel;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @streetName.
  ///
  /// In en, this message translates to:
  /// **'Street Name'**
  String get streetName;

  /// No description provided for @buildingNo.
  ///
  /// In en, this message translates to:
  /// **'Building No.'**
  String get buildingNo;

  /// No description provided for @additionalStreet.
  ///
  /// In en, this message translates to:
  /// **'Additional Street'**
  String get additionalStreet;

  /// No description provided for @plotId.
  ///
  /// In en, this message translates to:
  /// **'Plot ID'**
  String get plotId;

  /// No description provided for @districtSubdivision.
  ///
  /// In en, this message translates to:
  /// **'District / Subdivision'**
  String get districtSubdivision;

  /// No description provided for @postalCode.
  ///
  /// In en, this message translates to:
  /// **'Postal Code'**
  String get postalCode;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// No description provided for @stateProvince.
  ///
  /// In en, this message translates to:
  /// **'State / Province'**
  String get stateProvince;

  /// No description provided for @bankAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Bank Account Number'**
  String get bankAccountNumber;

  /// No description provided for @bankDetails.
  ///
  /// In en, this message translates to:
  /// **'Bank Details (IBAN, SWIFT, etc.)'**
  String get bankDetails;

  /// No description provided for @rateLabel.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rateLabel;

  /// No description provided for @taxOnTotal.
  ///
  /// In en, this message translates to:
  /// **'Tax on Total'**
  String get taxOnTotal;

  /// No description provided for @noTaxRatesFound.
  ///
  /// In en, this message translates to:
  /// **'No tax rates found.'**
  String get noTaxRatesFound;

  /// No description provided for @editVoidReason.
  ///
  /// In en, this message translates to:
  /// **'Edit Void Reason'**
  String get editVoidReason;

  /// No description provided for @addVoidReason.
  ///
  /// In en, this message translates to:
  /// **'Add Void Reason'**
  String get addVoidReason;

  /// No description provided for @addReason.
  ///
  /// In en, this message translates to:
  /// **'Add Reason'**
  String get addReason;

  /// No description provided for @totalDue.
  ///
  /// In en, this message translates to:
  /// **'Total Due'**
  String get totalDue;

  /// No description provided for @replaceTaxesHint.
  ///
  /// In en, this message translates to:
  /// **'Use this form to replace taxes for all products. Select the old tax you wish to replace with the new tax and click Replace.'**
  String get replaceTaxesHint;

  /// No description provided for @errorLoadingTaxesMsg.
  ///
  /// In en, this message translates to:
  /// **'Error loading taxes: {message}'**
  String errorLoadingTaxesMsg(Object message);

  /// No description provided for @orderTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Order Type'**
  String get orderTypeLabel;

  /// No description provided for @noServiceStatuses.
  ///
  /// In en, this message translates to:
  /// **'No service statuses configured.'**
  String get noServiceStatuses;

  /// No description provided for @quantityCannotBeNegative.
  ///
  /// In en, this message translates to:
  /// **'Quantity cannot be negative.'**
  String get quantityCannotBeNegative;

  /// No description provided for @cannotCalcQuantity.
  ///
  /// In en, this message translates to:
  /// **'Cannot calculate quantity: unit price is zero.'**
  String get cannotCalcQuantity;

  /// No description provided for @parsedQuantityZero.
  ///
  /// In en, this message translates to:
  /// **'Parsed quantity is zero — check scale barcode configuration.'**
  String get parsedQuantityZero;

  /// No description provided for @selectTableFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a table first!'**
  String get selectTableFirst;

  /// No description provided for @notAvailableOtherWarehouse.
  ///
  /// In en, this message translates to:
  /// **'This product is not available in any other warehouse.'**
  String get notAvailableOtherWarehouse;

  /// No description provided for @selectTableFromFloorPlan.
  ///
  /// In en, this message translates to:
  /// **'Please select a Table from the Floor Plan first!'**
  String get selectTableFromFloorPlan;

  /// No description provided for @cartIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty'**
  String get cartIsEmpty;

  /// No description provided for @totalPromotionalDiscount.
  ///
  /// In en, this message translates to:
  /// **'Total Promotional Discount'**
  String get totalPromotionalDiscount;

  /// No description provided for @calendarBookingUpdated.
  ///
  /// In en, this message translates to:
  /// **'Calendar booking will be updated automatically.'**
  String get calendarBookingUpdated;

  /// No description provided for @confirmTransfer.
  ///
  /// In en, this message translates to:
  /// **'Confirm Transfer'**
  String get confirmTransfer;

  /// No description provided for @setAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get setAbout;

  /// No description provided for @setAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get setAccentColor;

  /// No description provided for @setAddPrinterGroup.
  ///
  /// In en, this message translates to:
  /// **'Add Printer Group'**
  String get setAddPrinterGroup;

  /// No description provided for @setAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get setAddress;

  /// No description provided for @setAdvancedSettings.
  ///
  /// In en, this message translates to:
  /// **'ADVANCED SETTINGS'**
  String get setAdvancedSettings;

  /// No description provided for @setTaxInclusiveDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'All new products will default to tax-inclusive pricing'**
  String get setTaxInclusiveDefaultHint;

  /// No description provided for @setAllowNegativePrice.
  ///
  /// In en, this message translates to:
  /// **'Allow negative price'**
  String get setAllowNegativePrice;

  /// No description provided for @setAllowTablelessOrders.
  ///
  /// In en, this message translates to:
  /// **'Allow table-less orders'**
  String get setAllowTablelessOrders;

  /// No description provided for @setAllowWalkInTableOrders.
  ///
  /// In en, this message translates to:
  /// **'Allow walk-in table orders'**
  String get setAllowWalkInTableOrders;

  /// No description provided for @setApi.
  ///
  /// In en, this message translates to:
  /// **'API'**
  String get setApi;

  /// No description provided for @setApiBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'API Base URL'**
  String get setApiBaseUrl;

  /// No description provided for @setAppearance.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get setAppearance;

  /// No description provided for @setApplicationStyle.
  ///
  /// In en, this message translates to:
  /// **'APPLICATION STYLE'**
  String get setApplicationStyle;

  /// No description provided for @setAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'Auto Backup'**
  String get setAutoBackup;

  /// No description provided for @setAutoSync.
  ///
  /// In en, this message translates to:
  /// **'AUTO SYNC'**
  String get setAutoSync;

  /// No description provided for @setAutomaticBackups.
  ///
  /// In en, this message translates to:
  /// **'AUTOMATIC BACKUPS'**
  String get setAutomaticBackups;

  /// No description provided for @setAutoUpdateCostPrice.
  ///
  /// In en, this message translates to:
  /// **'Automatically update cost price on purchase'**
  String get setAutoUpdateCostPrice;

  /// No description provided for @setBackUpEvery.
  ///
  /// In en, this message translates to:
  /// **'Back up automatically every'**
  String get setBackUpEvery;

  /// No description provided for @setBackupOnClose.
  ///
  /// In en, this message translates to:
  /// **'Backup database on application close'**
  String get setBackupOnClose;

  /// No description provided for @setBackupOnStart.
  ///
  /// In en, this message translates to:
  /// **'Backup database on application start'**
  String get setBackupOnStart;

  /// No description provided for @setBackupLocation.
  ///
  /// In en, this message translates to:
  /// **'Backup location'**
  String get setBackupLocation;

  /// No description provided for @setBarcodeParsing.
  ///
  /// In en, this message translates to:
  /// **'BARCODE PARSING'**
  String get setBarcodeParsing;

  /// No description provided for @setBaudRate.
  ///
  /// In en, this message translates to:
  /// **'Baud rate'**
  String get setBaudRate;

  /// No description provided for @setBitsPerSecond.
  ///
  /// In en, this message translates to:
  /// **'Bits per second'**
  String get setBitsPerSecond;

  /// No description provided for @setBooking.
  ///
  /// In en, this message translates to:
  /// **'BOOKING'**
  String get setBooking;

  /// No description provided for @setBookingSettings.
  ///
  /// In en, this message translates to:
  /// **'Booking settings'**
  String get setBookingSettings;

  /// No description provided for @setBookingsButton.
  ///
  /// In en, this message translates to:
  /// **'Bookings button'**
  String get setBookingsButton;

  /// No description provided for @setBottomLine.
  ///
  /// In en, this message translates to:
  /// **'Bottom line'**
  String get setBottomLine;

  /// No description provided for @setBusinessDay.
  ///
  /// In en, this message translates to:
  /// **'BUSINESS DAY'**
  String get setBusinessDay;

  /// No description provided for @setCashDrawer.
  ///
  /// In en, this message translates to:
  /// **'Cash Drawer'**
  String get setCashDrawer;

  /// No description provided for @setCashDrawerButton.
  ///
  /// In en, this message translates to:
  /// **'Cash Drawer button'**
  String get setCashDrawerButton;

  /// No description provided for @setChangeQuantity.
  ///
  /// In en, this message translates to:
  /// **'Change quantity'**
  String get setChangeQuantity;

  /// No description provided for @setChangeQuantityButton.
  ///
  /// In en, this message translates to:
  /// **'Change quantity button'**
  String get setChangeQuantityButton;

  /// No description provided for @setColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get setColor;

  /// No description provided for @setComPort.
  ///
  /// In en, this message translates to:
  /// **'COM port'**
  String get setComPort;

  /// No description provided for @setCommentButton.
  ///
  /// In en, this message translates to:
  /// **'Comment button'**
  String get setCommentButton;

  /// No description provided for @setCompany.
  ///
  /// In en, this message translates to:
  /// **'COMPANY'**
  String get setCompany;

  /// No description provided for @setCopyLanUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy LAN URL'**
  String get setCopyLanUrl;

  /// No description provided for @setCostPriceMarkup.
  ///
  /// In en, this message translates to:
  /// **'Cost price based markup'**
  String get setCostPriceMarkup;

  /// No description provided for @setCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get setCurrency;

  /// No description provided for @setCustomerButton.
  ///
  /// In en, this message translates to:
  /// **'Customer button'**
  String get setCustomerButton;

  /// No description provided for @setCustomerDisplay.
  ///
  /// In en, this message translates to:
  /// **'CUSTOMER DISPLAY'**
  String get setCustomerDisplay;

  /// No description provided for @setCustomerDisplayEnabled.
  ///
  /// In en, this message translates to:
  /// **'Customer display enabled'**
  String get setCustomerDisplayEnabled;

  /// No description provided for @setDataBits.
  ///
  /// In en, this message translates to:
  /// **'Data bits'**
  String get setDataBits;

  /// No description provided for @setDatabase.
  ///
  /// In en, this message translates to:
  /// **'DATABASE'**
  String get setDatabase;

  /// No description provided for @setDatabaseBackup.
  ///
  /// In en, this message translates to:
  /// **'Database & Backup'**
  String get setDatabaseBackup;

  /// No description provided for @setDbSize.
  ///
  /// In en, this message translates to:
  /// **'DB Size'**
  String get setDbSize;

  /// No description provided for @setDefaultBarcodeFormat.
  ///
  /// In en, this message translates to:
  /// **'Default Barcode Format'**
  String get setDefaultBarcodeFormat;

  /// No description provided for @setDefaultDiscountType.
  ///
  /// In en, this message translates to:
  /// **'Default discount type'**
  String get setDefaultDiscountType;

  /// No description provided for @setDefaultDueDays.
  ///
  /// In en, this message translates to:
  /// **'Default due date (days)'**
  String get setDefaultDueDays;

  /// No description provided for @setDefaultMeasurementUnit.
  ///
  /// In en, this message translates to:
  /// **'Default Measurement Unit'**
  String get setDefaultMeasurementUnit;

  /// No description provided for @setDefaultScreen.
  ///
  /// In en, this message translates to:
  /// **'Default screen'**
  String get setDefaultScreen;

  /// No description provided for @setDefaultSearch.
  ///
  /// In en, this message translates to:
  /// **'Default search'**
  String get setDefaultSearch;

  /// No description provided for @setDefaultServiceType.
  ///
  /// In en, this message translates to:
  /// **'Default service type'**
  String get setDefaultServiceType;

  /// No description provided for @setDefaultTaxRate.
  ///
  /// In en, this message translates to:
  /// **'Default tax rate'**
  String get setDefaultTaxRate;

  /// No description provided for @setDefaultWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Default warehouse'**
  String get setDefaultWarehouse;

  /// No description provided for @setDeleteBackupsOlderThan.
  ///
  /// In en, this message translates to:
  /// **'Delete backups older than'**
  String get setDeleteBackupsOlderThan;

  /// No description provided for @setDeleteOldBackups.
  ///
  /// In en, this message translates to:
  /// **'Delete old backups automatically'**
  String get setDeleteOldBackups;

  /// No description provided for @setDeleteServiceStatus.
  ///
  /// In en, this message translates to:
  /// **'Delete Service Status'**
  String get setDeleteServiceStatus;

  /// No description provided for @setDeleteServiceType.
  ///
  /// In en, this message translates to:
  /// **'Delete Service Type'**
  String get setDeleteServiceType;

  /// No description provided for @setDevice.
  ///
  /// In en, this message translates to:
  /// **'DEVICE'**
  String get setDevice;

  /// No description provided for @setDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get setDeviceName;

  /// No description provided for @setDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get setDevices;

  /// No description provided for @setDiscountApplyRule.
  ///
  /// In en, this message translates to:
  /// **'Discount apply rule'**
  String get setDiscountApplyRule;

  /// No description provided for @setDiscountButton.
  ///
  /// In en, this message translates to:
  /// **'Discount button'**
  String get setDiscountButton;

  /// No description provided for @setSyncToast.
  ///
  /// In en, this message translates to:
  /// **'Display a toast each time a sync completes'**
  String get setSyncToast;

  /// No description provided for @setDisplayPrintTaxIncluded.
  ///
  /// In en, this message translates to:
  /// **'Display and print items with tax included'**
  String get setDisplayPrintTaxIncluded;

  /// No description provided for @setDualCurrencyHint.
  ///
  /// In en, this message translates to:
  /// **'Display prices and totals in a second currency simultaneously'**
  String get setDualCurrencyHint;

  /// No description provided for @setShowPrintDialog.
  ///
  /// In en, this message translates to:
  /// **'Display receipt print dialog'**
  String get setShowPrintDialog;

  /// No description provided for @setDualCurrency.
  ///
  /// In en, this message translates to:
  /// **'DUAL CURRENCY'**
  String get setDualCurrency;

  /// No description provided for @setDualCurrencyEnabled.
  ///
  /// In en, this message translates to:
  /// **'Dual Currency Enabled'**
  String get setDualCurrencyEnabled;

  /// No description provided for @setEnableAutomaticBackups.
  ///
  /// In en, this message translates to:
  /// **'Enable automatic backups'**
  String get setEnableAutomaticBackups;

  /// No description provided for @setEnableAutoSync.
  ///
  /// In en, this message translates to:
  /// **'Enable auto-sync'**
  String get setEnableAutoSync;

  /// No description provided for @setEnableBookings.
  ///
  /// In en, this message translates to:
  /// **'Enable Bookings / Calendar'**
  String get setEnableBookings;

  /// No description provided for @setEnableFloorPlan.
  ///
  /// In en, this message translates to:
  /// **'Enable Floor Plan / Tables'**
  String get setEnableFloorPlan;

  /// No description provided for @setEnableLiveWebDisplay.
  ///
  /// In en, this message translates to:
  /// **'Enable live web customer display'**
  String get setEnableLiveWebDisplay;

  /// No description provided for @setEnableMovingAverage.
  ///
  /// In en, this message translates to:
  /// **'Enable moving average price'**
  String get setEnableMovingAverage;

  /// No description provided for @setEnableVirtualKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Enable Virtual Keyboard'**
  String get setEnableVirtualKeyboard;

  /// No description provided for @setEnableScaleBarcode.
  ///
  /// In en, this message translates to:
  /// **'Enable weighing scales barcode'**
  String get setEnableScaleBarcode;

  /// No description provided for @setExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Exchange Rate'**
  String get setExchangeRate;

  /// No description provided for @setFeatures.
  ///
  /// In en, this message translates to:
  /// **'FEATURES'**
  String get setFeatures;

  /// No description provided for @setFirstTwoDigits.
  ///
  /// In en, this message translates to:
  /// **'First two digits / prefix'**
  String get setFirstTwoDigits;

  /// No description provided for @setFlowControl.
  ///
  /// In en, this message translates to:
  /// **'Flow control'**
  String get setFlowControl;

  /// No description provided for @setFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get setFontSize;

  /// No description provided for @setFromEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'From Email Address'**
  String get setFromEmailAddress;

  /// No description provided for @setFromName.
  ///
  /// In en, this message translates to:
  /// **'From Name'**
  String get setFromName;

  /// No description provided for @setGeneral.
  ///
  /// In en, this message translates to:
  /// **'GENERAL'**
  String get setGeneral;

  /// No description provided for @setIanaTimezone.
  ///
  /// In en, this message translates to:
  /// **'IANA Timezone'**
  String get setIanaTimezone;

  /// No description provided for @setInventory.
  ///
  /// In en, this message translates to:
  /// **'INVENTORY'**
  String get setInventory;

  /// No description provided for @setItems.
  ///
  /// In en, this message translates to:
  /// **'ITEMS'**
  String get setItems;

  /// No description provided for @setKdsIp.
  ///
  /// In en, this message translates to:
  /// **'KDS IP address'**
  String get setKdsIp;

  /// No description provided for @setKitchenDisplay.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Display'**
  String get setKitchenDisplay;

  /// No description provided for @setKdsTablets.
  ///
  /// In en, this message translates to:
  /// **'KITCHEN DISPLAY TABLETS'**
  String get setKdsTablets;

  /// No description provided for @setLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last Sync'**
  String get setLastSync;

  /// No description provided for @setLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get setLayout;

  /// No description provided for @setLoadingCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Loading currencies…'**
  String get setLoadingCurrencies;

  /// No description provided for @setMenuGrid.
  ///
  /// In en, this message translates to:
  /// **'MENU GRID'**
  String get setMenuGrid;

  /// No description provided for @setMenuGridColumns.
  ///
  /// In en, this message translates to:
  /// **'Menu Grid Columns'**
  String get setMenuGridColumns;

  /// No description provided for @setMenuGridRows.
  ///
  /// In en, this message translates to:
  /// **'Menu Grid Rows'**
  String get setMenuGridRows;

  /// No description provided for @setMenuLayout.
  ///
  /// In en, this message translates to:
  /// **'Menu Layout (List / Grid)'**
  String get setMenuLayout;

  /// No description provided for @setMergeItemsOnReceipt.
  ///
  /// In en, this message translates to:
  /// **'Merge items on receipt'**
  String get setMergeItemsOnReceipt;

  /// No description provided for @setMessageDuration.
  ///
  /// In en, this message translates to:
  /// **'Message Duration (seconds)'**
  String get setMessageDuration;

  /// No description provided for @setMessagePosition.
  ///
  /// In en, this message translates to:
  /// **'Message Position'**
  String get setMessagePosition;

  /// No description provided for @setMessages.
  ///
  /// In en, this message translates to:
  /// **'MESSAGES (NOTIFICATIONS)'**
  String get setMessages;

  /// No description provided for @setMovingAveragePrice.
  ///
  /// In en, this message translates to:
  /// **'MOVING AVERAGE PRICE'**
  String get setMovingAveragePrice;

  /// No description provided for @setNumberOfCharacters.
  ///
  /// In en, this message translates to:
  /// **'Number of characters'**
  String get setNumberOfCharacters;

  /// No description provided for @setNumberOfDecimals.
  ///
  /// In en, this message translates to:
  /// **'Number of decimal places'**
  String get setNumberOfDecimals;

  /// No description provided for @setProductCodeDigits.
  ///
  /// In en, this message translates to:
  /// **'Number of digits for product code'**
  String get setProductCodeDigits;

  /// No description provided for @setPaymentTypeRows.
  ///
  /// In en, this message translates to:
  /// **'Number of payment type rows'**
  String get setPaymentTypeRows;

  /// No description provided for @setOnboarding.
  ///
  /// In en, this message translates to:
  /// **'ONBOARDING'**
  String get setOnboarding;

  /// No description provided for @setOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get setOpen;

  /// No description provided for @setOpenCustomerDisplay.
  ///
  /// In en, this message translates to:
  /// **'Open customer display'**
  String get setOpenCustomerDisplay;

  /// No description provided for @setOpenInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser (drag to second monitor)'**
  String get setOpenInBrowser;

  /// No description provided for @setOpenOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'OPEN ON THIS DEVICE'**
  String get setOpenOnThisDevice;

  /// No description provided for @setOrderAndPayment.
  ///
  /// In en, this message translates to:
  /// **'Order & Payment'**
  String get setOrderAndPayment;

  /// No description provided for @setOrderNumberPrefix.
  ///
  /// In en, this message translates to:
  /// **'Order Number Prefix'**
  String get setOrderNumberPrefix;

  /// No description provided for @setParity.
  ///
  /// In en, this message translates to:
  /// **'Parity'**
  String get setParity;

  /// No description provided for @setScaleBarcodeHint.
  ///
  /// In en, this message translates to:
  /// **'Parse weight/price from barcodes printed by a weighing scale'**
  String get setScaleBarcodeHint;

  /// No description provided for @setPayment.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT'**
  String get setPayment;

  /// No description provided for @setPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get setPhone;

  /// No description provided for @setPosButtonBar.
  ///
  /// In en, this message translates to:
  /// **'POS BUTTON BAR'**
  String get setPosButtonBar;

  /// No description provided for @setPosNameHint.
  ///
  /// In en, this message translates to:
  /// **'POS name — prefix for document numbers'**
  String get setPosNameHint;

  /// No description provided for @setPreventNegativeInventory.
  ///
  /// In en, this message translates to:
  /// **'Prevent negative inventory'**
  String get setPreventNegativeInventory;

  /// No description provided for @setPreventSaleBelowCost.
  ///
  /// In en, this message translates to:
  /// **'Prevent sale below cost price'**
  String get setPreventSaleBelowCost;

  /// No description provided for @setPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get setPrint;

  /// No description provided for @setPrintLargeOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Print large order number in receipt'**
  String get setPrintLargeOrderNumber;

  /// No description provided for @setPrinterReceiptSettings.
  ///
  /// In en, this message translates to:
  /// **'Printer & Receipt Settings'**
  String get setPrinterReceiptSettings;

  /// No description provided for @setPrinterGroups.
  ///
  /// In en, this message translates to:
  /// **'PRINTER GROUPS'**
  String get setPrinterGroups;

  /// No description provided for @setProductDefaults.
  ///
  /// In en, this message translates to:
  /// **'PRODUCT DEFAULTS'**
  String get setProductDefaults;

  /// No description provided for @setReadLiveWeight.
  ///
  /// In en, this message translates to:
  /// **'Read live weight from a serial scale'**
  String get setReadLiveWeight;

  /// No description provided for @setRefundButton.
  ///
  /// In en, this message translates to:
  /// **'Refund button'**
  String get setRefundButton;

  /// No description provided for @setRegional.
  ///
  /// In en, this message translates to:
  /// **'REGIONAL'**
  String get setRegional;

  /// No description provided for @setRegisteredAccount.
  ///
  /// In en, this message translates to:
  /// **'Registered account'**
  String get setRegisteredAccount;

  /// No description provided for @setRenewsEnds.
  ///
  /// In en, this message translates to:
  /// **'Renews / ends'**
  String get setRenewsEnds;

  /// No description provided for @setRepair.
  ///
  /// In en, this message translates to:
  /// **'Re-pair'**
  String get setRepair;

  /// No description provided for @setReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get setReplay;

  /// No description provided for @setRequestServiceTypeAuto.
  ///
  /// In en, this message translates to:
  /// **'Request service type automatically'**
  String get setRequestServiceTypeAuto;

  /// No description provided for @setRequireReasonOnVoid.
  ///
  /// In en, this message translates to:
  /// **'Require reason on void'**
  String get setRequireReasonOnVoid;

  /// No description provided for @setRequiresFloorPlan.
  ///
  /// In en, this message translates to:
  /// **'Requires Floor Plan / Tables to be enabled'**
  String get setRequiresFloorPlan;

  /// No description provided for @setRescanPorts.
  ///
  /// In en, this message translates to:
  /// **'Rescan ports'**
  String get setRescanPorts;

  /// No description provided for @setResetOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Reset order number on day close'**
  String get setResetOrderNumber;

  /// No description provided for @setWalkInHint.
  ///
  /// In en, this message translates to:
  /// **'Ring up a dine-in order without picking a table'**
  String get setWalkInHint;

  /// No description provided for @setRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get setRoom;

  /// No description provided for @setRows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get setRows;

  /// No description provided for @setScalePrintsPrice.
  ///
  /// In en, this message translates to:
  /// **'Scale prints price instead of quantity'**
  String get setScalePrintsPrice;

  /// No description provided for @setScreenDisplayWeb.
  ///
  /// In en, this message translates to:
  /// **'SCREEN DISPLAY (WEB)'**
  String get setScreenDisplayWeb;

  /// No description provided for @setSearchAllSettings.
  ///
  /// In en, this message translates to:
  /// **'Search all settings...'**
  String get setSearchAllSettings;

  /// No description provided for @setSearchButton.
  ///
  /// In en, this message translates to:
  /// **'Search button'**
  String get setSearchButton;

  /// No description provided for @setSecondaryCurrencySymbol.
  ///
  /// In en, this message translates to:
  /// **'Secondary Currency Symbol'**
  String get setSecondaryCurrencySymbol;

  /// No description provided for @setSelectBusinessDayOnStart.
  ///
  /// In en, this message translates to:
  /// **'Select business day on application start'**
  String get setSelectBusinessDayOnStart;

  /// No description provided for @setSelectEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Select…'**
  String get setSelectEllipsis;

  /// No description provided for @setSendToKitchen.
  ///
  /// In en, this message translates to:
  /// **'Send to Kitchen'**
  String get setSendToKitchen;

  /// No description provided for @setSendToKitchenButton.
  ///
  /// In en, this message translates to:
  /// **'Send to Kitchen button'**
  String get setSendToKitchenButton;

  /// No description provided for @setSender.
  ///
  /// In en, this message translates to:
  /// **'SENDER'**
  String get setSender;

  /// No description provided for @setSeparateRowPerItem.
  ///
  /// In en, this message translates to:
  /// **'Separate row for each item'**
  String get setSeparateRowPerItem;

  /// No description provided for @setSerialConnection.
  ///
  /// In en, this message translates to:
  /// **'SERIAL CONNECTION'**
  String get setSerialConnection;

  /// No description provided for @setServiceStatusSelector.
  ///
  /// In en, this message translates to:
  /// **'Service Status Selector'**
  String get setServiceStatusSelector;

  /// No description provided for @setServiceStatuses.
  ///
  /// In en, this message translates to:
  /// **'Service Statuses'**
  String get setServiceStatuses;

  /// No description provided for @setServiceTypeHeader.
  ///
  /// In en, this message translates to:
  /// **'SERVICE TYPE'**
  String get setServiceTypeHeader;

  /// No description provided for @setServiceTypeSelector.
  ///
  /// In en, this message translates to:
  /// **'Service Type Selector'**
  String get setServiceTypeSelector;

  /// No description provided for @setServiceTypes.
  ///
  /// In en, this message translates to:
  /// **'Service Types'**
  String get setServiceTypes;

  /// No description provided for @setShowAllOccupied.
  ///
  /// In en, this message translates to:
  /// **'Show all occupied tables in floor plan'**
  String get setShowAllOccupied;

  /// No description provided for @setShowCashInOnStart.
  ///
  /// In en, this message translates to:
  /// **'Show cash in on application start'**
  String get setShowCashInOnStart;

  /// No description provided for @setShowItemsOnPaymentForm.
  ///
  /// In en, this message translates to:
  /// **'Show items on payment form'**
  String get setShowItemsOnPaymentForm;

  /// No description provided for @setShowOrderTotalOnPole.
  ///
  /// In en, this message translates to:
  /// **'Show order total on a serial VFD / LCD pole display'**
  String get setShowOrderTotalOnPole;

  /// No description provided for @setShowOrderTypeButtons.
  ///
  /// In en, this message translates to:
  /// **'Show order type buttons on the POS'**
  String get setShowOrderTypeButtons;

  /// No description provided for @setShowProductImages.
  ///
  /// In en, this message translates to:
  /// **'Show Product Images in POS Grid'**
  String get setShowProductImages;

  /// No description provided for @setShowSearchOptions.
  ///
  /// In en, this message translates to:
  /// **'Show search options'**
  String get setShowSearchOptions;

  /// No description provided for @setShowServiceStatusBadge.
  ///
  /// In en, this message translates to:
  /// **'Show service status badge on table/booking cards'**
  String get setShowServiceStatusBadge;

  /// No description provided for @setShowSyncNotification.
  ///
  /// In en, this message translates to:
  /// **'Show sync notification'**
  String get setShowSyncNotification;

  /// No description provided for @setShowTablesButton.
  ///
  /// In en, this message translates to:
  /// **'Show the Tables button in the POS'**
  String get setShowTablesButton;

  /// No description provided for @setSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get setSignOut;

  /// No description provided for @setSignOutDevice.
  ///
  /// In en, this message translates to:
  /// **'Sign Out Device'**
  String get setSignOutDevice;

  /// No description provided for @setSingleItemDiscount.
  ///
  /// In en, this message translates to:
  /// **'Single item discount allowed'**
  String get setSingleItemDiscount;

  /// No description provided for @setSingleUser.
  ///
  /// In en, this message translates to:
  /// **'Single user'**
  String get setSingleUser;

  /// No description provided for @setSmtpHost.
  ///
  /// In en, this message translates to:
  /// **'SMTP Host'**
  String get setSmtpHost;

  /// No description provided for @setSmtpPort.
  ///
  /// In en, this message translates to:
  /// **'SMTP Port'**
  String get setSmtpPort;

  /// No description provided for @setSmtpServer.
  ///
  /// In en, this message translates to:
  /// **'SMTP SERVER'**
  String get setSmtpServer;

  /// No description provided for @setSorting.
  ///
  /// In en, this message translates to:
  /// **'Sorting'**
  String get setSorting;

  /// No description provided for @setStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get setStaff;

  /// No description provided for @setStartOrderFreeTable.
  ///
  /// In en, this message translates to:
  /// **'Start an order on a free table without a booking'**
  String get setStartOrderFreeTable;

  /// No description provided for @setStarted.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get setStarted;

  /// No description provided for @setStartup.
  ///
  /// In en, this message translates to:
  /// **'STARTUP'**
  String get setStartup;

  /// No description provided for @setStopBits.
  ///
  /// In en, this message translates to:
  /// **'Stop bits'**
  String get setStopBits;

  /// No description provided for @setScaleStreamHint.
  ///
  /// In en, this message translates to:
  /// **'Streams the weight from a scale on a COM port into the quantity keypad'**
  String get setScaleStreamHint;

  /// No description provided for @setStripLeadingZeros.
  ///
  /// In en, this message translates to:
  /// **'Strip leading zeros before looking up the product'**
  String get setStripLeadingZeros;

  /// No description provided for @setSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get setSubscription;

  /// No description provided for @setSystemInfo.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM INFO'**
  String get setSystemInfo;

  /// No description provided for @setTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get setTable;

  /// No description provided for @setTablesFloorPlan.
  ///
  /// In en, this message translates to:
  /// **'Tables / Floor Plan'**
  String get setTablesFloorPlan;

  /// No description provided for @setTablesFloorPlanButton.
  ///
  /// In en, this message translates to:
  /// **'Tables / Floor Plan button'**
  String get setTablesFloorPlanButton;

  /// No description provided for @setTablesButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Tables Button Label'**
  String get setTablesButtonLabel;

  /// No description provided for @setTaxHeader.
  ///
  /// In en, this message translates to:
  /// **'TAX'**
  String get setTaxHeader;

  /// No description provided for @setTaxButton.
  ///
  /// In en, this message translates to:
  /// **'Tax button'**
  String get setTaxButton;

  /// No description provided for @setTaxIncludedByDefault.
  ///
  /// In en, this message translates to:
  /// **'Tax Included in Price by Default'**
  String get setTaxIncludedByDefault;

  /// No description provided for @setTaxNo.
  ///
  /// In en, this message translates to:
  /// **'Tax No'**
  String get setTaxNo;

  /// No description provided for @setTestDisplay.
  ///
  /// In en, this message translates to:
  /// **'Test display'**
  String get setTestDisplay;

  /// No description provided for @setThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get setThemeMode;

  /// No description provided for @setTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get setTimezone;

  /// No description provided for @setTopLine.
  ///
  /// In en, this message translates to:
  /// **'Top line'**
  String get setTopLine;

  /// No description provided for @setTrackUnconfirmedVoids.
  ///
  /// In en, this message translates to:
  /// **'Track unconfirmed voided items'**
  String get setTrackUnconfirmedVoids;

  /// No description provided for @setTransferButton.
  ///
  /// In en, this message translates to:
  /// **'Transfer button'**
  String get setTransferButton;

  /// No description provided for @setUpdateSalePriceFromMarkup.
  ///
  /// In en, this message translates to:
  /// **'Update sale price based on markup'**
  String get setUpdateSalePriceFromMarkup;

  /// No description provided for @setUsers.
  ///
  /// In en, this message translates to:
  /// **'USERS'**
  String get setUsers;

  /// No description provided for @setVoidItems.
  ///
  /// In en, this message translates to:
  /// **'VOID ITEMS'**
  String get setVoidItems;

  /// No description provided for @setWarehouseSwitcher.
  ///
  /// In en, this message translates to:
  /// **'Warehouse Switcher'**
  String get setWarehouseSwitcher;

  /// No description provided for @setWarehouseSwitcherButton.
  ///
  /// In en, this message translates to:
  /// **'Warehouse Switcher button'**
  String get setWarehouseSwitcherButton;

  /// No description provided for @setWeighingScale.
  ///
  /// In en, this message translates to:
  /// **'Weighing Scale'**
  String get setWeighingScale;

  /// No description provided for @setWelcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'WELCOME MESSAGE'**
  String get setWelcomeMessage;

  /// No description provided for @setWelcomeBottomLine.
  ///
  /// In en, this message translates to:
  /// **'Welcome message bottom line'**
  String get setWelcomeBottomLine;

  /// No description provided for @setWelcomeTopLine.
  ///
  /// In en, this message translates to:
  /// **'Welcome message top line'**
  String get setWelcomeTopLine;

  /// No description provided for @setWhenToSync.
  ///
  /// In en, this message translates to:
  /// **'When to sync'**
  String get setWhenToSync;

  /// No description provided for @setWritingDirection.
  ///
  /// In en, this message translates to:
  /// **'Writing Direction'**
  String get setWritingDirection;

  /// No description provided for @setHintCaisse.
  ///
  /// In en, this message translates to:
  /// **'e.g. CAISSE1'**
  String get setHintCaisse;

  /// No description provided for @setHintUber.
  ///
  /// In en, this message translates to:
  /// **'e.g. UBER'**
  String get setHintUber;

  /// No description provided for @setHintUberEats.
  ///
  /// In en, this message translates to:
  /// **'e.g. Uber Eats'**
  String get setHintUberEats;

  /// No description provided for @setHintWaiting.
  ///
  /// In en, this message translates to:
  /// **'e.g. Waiting'**
  String get setHintWaiting;

  /// No description provided for @selectExportType.
  ///
  /// In en, this message translates to:
  /// **'Select export type'**
  String get selectExportType;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV (Excel)'**
  String get exportCsv;

  /// No description provided for @exportXml.
  ///
  /// In en, this message translates to:
  /// **'XML'**
  String get exportXml;

  /// No description provided for @deleteProducts.
  ///
  /// In en, this message translates to:
  /// **'Delete Products'**
  String get deleteProducts;

  /// No description provided for @showHideColumns.
  ///
  /// In en, this message translates to:
  /// **'Show / Hide Columns'**
  String get showHideColumns;

  /// No description provided for @alwaysShown.
  ///
  /// In en, this message translates to:
  /// **'Always shown'**
  String get alwaysShown;

  /// No description provided for @actionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get actionReset;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @columns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get columns;

  /// No description provided for @importLabel.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importLabel;

  /// No description provided for @exportLabel.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportLabel;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProduct;

  /// No description provided for @categoriesHeader.
  ///
  /// In en, this message translates to:
  /// **'CATEGORIES'**
  String get categoriesHeader;

  /// No description provided for @errorLoadingGroups.
  ///
  /// In en, this message translates to:
  /// **'Error loading groups'**
  String get errorLoadingGroups;

  /// No description provided for @allProducts.
  ///
  /// In en, this message translates to:
  /// **'All Products'**
  String get allProducts;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found.'**
  String get noProductsFound;

  /// No description provided for @productNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Product Name *'**
  String get productNameRequired;

  /// No description provided for @categoryGroup.
  ///
  /// In en, this message translates to:
  /// **'Category / Group'**
  String get categoryGroup;

  /// No description provided for @noneUncategorized.
  ///
  /// In en, this message translates to:
  /// **'None (Uncategorized)'**
  String get noneUncategorized;

  /// No description provided for @productCodeSku.
  ///
  /// In en, this message translates to:
  /// **'Product Code / SKU'**
  String get productCodeSku;

  /// No description provided for @plu.
  ///
  /// In en, this message translates to:
  /// **'PLU'**
  String get plu;

  /// No description provided for @measurementUnit.
  ///
  /// In en, this message translates to:
  /// **'Measurement Unit'**
  String get measurementUnit;

  /// No description provided for @measurementUnitHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. kg, pcs'**
  String get measurementUnitHint;

  /// No description provided for @ageRestrictionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 18'**
  String get ageRestrictionHint;

  /// No description provided for @sellingPriceRequired.
  ///
  /// In en, this message translates to:
  /// **'Selling Price *'**
  String get sellingPriceRequired;

  /// No description provided for @purchaseCost.
  ///
  /// In en, this message translates to:
  /// **'Purchase Cost'**
  String get purchaseCost;

  /// No description provided for @marginMarkup.
  ///
  /// In en, this message translates to:
  /// **'Margin / Markup (%)'**
  String get marginMarkup;

  /// No description provided for @rankDisplayOrder.
  ///
  /// In en, this message translates to:
  /// **'Rank (Display Order)'**
  String get rankDisplayOrder;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @priceIsTaxInclusive.
  ///
  /// In en, this message translates to:
  /// **'Product Price is Tax Inclusive'**
  String get priceIsTaxInclusive;

  /// No description provided for @isServiceNotPhysical.
  ///
  /// In en, this message translates to:
  /// **'Is Service (Not physical)'**
  String get isServiceNotPhysical;

  /// No description provided for @changePriceAllowed.
  ///
  /// In en, this message translates to:
  /// **'Change Price Allowed'**
  String get changePriceAllowed;

  /// No description provided for @isEnabledVisible.
  ///
  /// In en, this message translates to:
  /// **'Is Enabled (Visible)'**
  String get isEnabledVisible;

  /// No description provided for @productColorMarker.
  ///
  /// In en, this message translates to:
  /// **'Product Color Marker'**
  String get productColorMarker;

  /// No description provided for @productImage.
  ///
  /// In en, this message translates to:
  /// **'Product Image'**
  String get productImage;

  /// No description provided for @productImageHint.
  ///
  /// In en, this message translates to:
  /// **'Replaces the placeholder icon on the POS menu tile.'**
  String get productImageHint;

  /// No description provided for @removeImage.
  ///
  /// In en, this message translates to:
  /// **'Remove Image'**
  String get removeImage;

  /// No description provided for @applyTaxes.
  ///
  /// In en, this message translates to:
  /// **'Apply Taxes'**
  String get applyTaxes;

  /// No description provided for @failedToLoadTaxes.
  ///
  /// In en, this message translates to:
  /// **'Failed to load taxes'**
  String get failedToLoadTaxes;

  /// No description provided for @primaryTaxRate.
  ///
  /// In en, this message translates to:
  /// **'Primary Tax Rate'**
  String get primaryTaxRate;

  /// No description provided for @noTax.
  ///
  /// In en, this message translates to:
  /// **'No Tax'**
  String get noTax;

  /// No description provided for @productModifiersComments.
  ///
  /// In en, this message translates to:
  /// **'Product Modifiers & Comments'**
  String get productModifiersComments;

  /// No description provided for @newModifierComment.
  ///
  /// In en, this message translates to:
  /// **'New Modifier / Comment'**
  String get newModifierComment;

  /// No description provided for @newModifierHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. No Onions'**
  String get newModifierHint;

  /// No description provided for @noCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments added yet.'**
  String get noCommentsYet;

  /// No description provided for @deleteComment.
  ///
  /// In en, this message translates to:
  /// **'Delete Comment'**
  String get deleteComment;

  /// No description provided for @productBarcodes.
  ///
  /// In en, this message translates to:
  /// **'Product Barcodes'**
  String get productBarcodes;

  /// No description provided for @barcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcode;

  /// No description provided for @generateBarcode.
  ///
  /// In en, this message translates to:
  /// **'Generate barcode'**
  String get generateBarcode;

  /// No description provided for @noBarcodesYet.
  ///
  /// In en, this message translates to:
  /// **'No barcodes assigned yet.'**
  String get noBarcodesYet;

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get pendingSync;

  /// No description provided for @deleteBarcode.
  ///
  /// In en, this message translates to:
  /// **'Delete Barcode'**
  String get deleteBarcode;

  /// No description provided for @transactionBlocked.
  ///
  /// In en, this message translates to:
  /// **'Transaction Blocked'**
  String get transactionBlocked;

  /// No description provided for @actionOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @transactionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Transaction Successful'**
  String get transactionSuccessful;

  /// No description provided for @printReceiptPrompt.
  ///
  /// In en, this message translates to:
  /// **'Would you like to print a receipt?'**
  String get printReceiptPrompt;

  /// No description provided for @saveAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Save as PDF'**
  String get saveAsPdf;

  /// No description provided for @printReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get printReceipt;

  /// No description provided for @splitPayments.
  ///
  /// In en, this message translates to:
  /// **'Split Payments'**
  String get splitPayments;

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @paidLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paidLabel;

  /// No description provided for @remainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remainingLabel;

  /// No description provided for @changeLabel.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeLabel;

  /// No description provided for @removeCustomer.
  ///
  /// In en, this message translates to:
  /// **'Remove customer'**
  String get removeCustomer;

  /// No description provided for @redeemPoints.
  ///
  /// In en, this message translates to:
  /// **'Redeem Points'**
  String get redeemPoints;

  /// No description provided for @pointsToUse.
  ///
  /// In en, this message translates to:
  /// **'Points to use'**
  String get pointsToUse;

  /// No description provided for @decrementOnePoint.
  ///
  /// In en, this message translates to:
  /// **'-1 pt'**
  String get decrementOnePoint;

  /// No description provided for @incrementOnePoint.
  ///
  /// In en, this message translates to:
  /// **'+1 pt'**
  String get incrementOnePoint;

  /// No description provided for @useMaxPoints.
  ///
  /// In en, this message translates to:
  /// **'Use Max ({points} pts)'**
  String useMaxPoints(String points);

  /// No description provided for @actionRedeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get actionRedeem;

  /// No description provided for @paymentTypes.
  ///
  /// In en, this message translates to:
  /// **'Payment Types'**
  String get paymentTypes;

  /// No description provided for @showNavigation.
  ///
  /// In en, this message translates to:
  /// **'Show navigation'**
  String get showNavigation;

  /// No description provided for @visibleColumns.
  ///
  /// In en, this message translates to:
  /// **'Visible Columns'**
  String get visibleColumns;

  /// No description provided for @columnsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get columnsTooltip;

  /// No description provided for @refreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshTooltip;

  /// No description provided for @newPaymentType.
  ///
  /// In en, this message translates to:
  /// **'New Payment Type'**
  String get newPaymentType;

  /// No description provided for @errorLoadingPaymentTypes.
  ///
  /// In en, this message translates to:
  /// **'Error loading payment types: {message}'**
  String errorLoadingPaymentTypes(String message);

  /// No description provided for @noCompanySelectedShort.
  ///
  /// In en, this message translates to:
  /// **'No company selected.'**
  String get noCompanySelectedShort;

  /// No description provided for @noPaymentTypesFound.
  ///
  /// In en, this message translates to:
  /// **'No payment types found.'**
  String get noPaymentTypesFound;

  /// No description provided for @addFirstPaymentType.
  ///
  /// In en, this message translates to:
  /// **'Add First Payment Type'**
  String get addFirstPaymentType;

  /// No description provided for @deletePaymentTypeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete payment type \'{name}\'?'**
  String deletePaymentTypeConfirm(String name);

  /// No description provided for @fieldNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get fieldNameRequired;

  /// No description provided for @fieldCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get fieldCode;

  /// No description provided for @fieldPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get fieldPosition;

  /// No description provided for @fieldShortcut.
  ///
  /// In en, this message translates to:
  /// **'Shortcut'**
  String get fieldShortcut;

  /// No description provided for @actionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get actionUpdate;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWithMessage(String message);

  /// No description provided for @activePromotions.
  ///
  /// In en, this message translates to:
  /// **'Active Promotions'**
  String get activePromotions;

  /// No description provided for @noActivePromotions.
  ///
  /// In en, this message translates to:
  /// **'No active promotions right now.'**
  String get noActivePromotions;

  /// Tooltip on the kitchen-ready badge in the POS header
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 order ready} other{{count} orders ready}}'**
  String ordersReady(num count);

  /// No description provided for @selectOrderType.
  ///
  /// In en, this message translates to:
  /// **'Select Order Type'**
  String get selectOrderType;

  /// No description provided for @serviceStatus.
  ///
  /// In en, this message translates to:
  /// **'Service Status'**
  String get serviceStatus;

  /// No description provided for @selectServiceStatus.
  ///
  /// In en, this message translates to:
  /// **'Select Service Status'**
  String get selectServiceStatus;

  /// No description provided for @posDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get posDiscount;

  /// No description provided for @posQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get posQuantity;

  /// No description provided for @posTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get posTax;

  /// No description provided for @posComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get posComment;

  /// No description provided for @posTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get posTransfer;

  /// No description provided for @posRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get posRefund;

  /// No description provided for @posKitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get posKitchen;

  /// No description provided for @posBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get posBookings;

  /// No description provided for @posPromos.
  ///
  /// In en, this message translates to:
  /// **'Promos'**
  String get posPromos;

  /// Void button on the cart action bar. Upper-case in English.
  ///
  /// In en, this message translates to:
  /// **'VOID'**
  String get posVoid;

  /// Primary checkout button. Upper-case in English.
  ///
  /// In en, this message translates to:
  /// **'PAY'**
  String get posPay;

  /// No description provided for @productRunningLow.
  ///
  /// In en, this message translates to:
  /// **'{product} is running low'**
  String productRunningLow(String product);

  /// No description provided for @productOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'{product} is out of stock'**
  String productOutOfStock(String product);

  /// No description provided for @availableIn.
  ///
  /// In en, this message translates to:
  /// **'Available in:'**
  String get availableIn;

  /// No description provided for @quantityInStock.
  ///
  /// In en, this message translates to:
  /// **'{qty} in stock'**
  String quantityInStock(String qty);

  /// No description provided for @noCompanySelected.
  ///
  /// In en, this message translates to:
  /// **'No company selected. Open the menu and pick a company.'**
  String get noCompanySelected;

  /// No description provided for @errorLoadingData.
  ///
  /// In en, this message translates to:
  /// **'Error loading data'**
  String get errorLoadingData;

  /// No description provided for @searchProductsHint.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get searchProductsHint;

  /// No description provided for @paginationFirst.
  ///
  /// In en, this message translates to:
  /// **'First'**
  String get paginationFirst;

  /// No description provided for @paginationPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get paginationPrevious;

  /// No description provided for @paginationNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get paginationNext;

  /// No description provided for @paginationLast.
  ///
  /// In en, this message translates to:
  /// **'Last'**
  String get paginationLast;

  /// No description provided for @voidOrder.
  ///
  /// In en, this message translates to:
  /// **'Void order'**
  String get voidOrder;

  /// No description provided for @voidOrderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to void this order?'**
  String get voidOrderConfirm;

  /// No description provided for @enterVoidReason.
  ///
  /// In en, this message translates to:
  /// **'Enter void reason here'**
  String get enterVoidReason;

  /// No description provided for @refreshOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Refresh order number'**
  String get refreshOrderNumber;

  /// No description provided for @enterQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter Quantity'**
  String get enterQuantity;

  /// No description provided for @setSalePrice.
  ///
  /// In en, this message translates to:
  /// **'Set Sale Price'**
  String get setSalePrice;

  /// No description provided for @fieldPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get fieldPrice;

  /// No description provided for @ageRestriction.
  ///
  /// In en, this message translates to:
  /// **'Age Restriction'**
  String get ageRestriction;

  /// No description provided for @confirmMinimumAge.
  ///
  /// In en, this message translates to:
  /// **'Confirm ({minAge}+)'**
  String confirmMinimumAge(String minAge);

  /// No description provided for @commentsForProduct.
  ///
  /// In en, this message translates to:
  /// **'Comments: {product}'**
  String commentsForProduct(String product);

  /// No description provided for @customComment.
  ///
  /// In en, this message translates to:
  /// **'Custom comment'**
  String get customComment;

  /// No description provided for @addANoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note...'**
  String get addANoteHint;

  /// No description provided for @noTaxesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No taxes available in system.'**
  String get noTaxesAvailable;

  /// No description provided for @transferOrder.
  ///
  /// In en, this message translates to:
  /// **'Transfer Order'**
  String get transferOrder;

  /// No description provided for @assignStaff.
  ///
  /// In en, this message translates to:
  /// **'Assign Staff'**
  String get assignStaff;

  /// No description provided for @unassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get unassigned;

  /// No description provided for @assignRoomOrResource.
  ///
  /// In en, this message translates to:
  /// **'Assign Room / Resource'**
  String get assignRoomOrResource;

  /// No description provided for @noRoom.
  ///
  /// In en, this message translates to:
  /// **'No room'**
  String get noRoom;

  /// space is the venue's own word for a table/room, from Feature.TablesButtonLabel
  ///
  /// In en, this message translates to:
  /// **'Select Available {space}'**
  String selectAvailableSpace(String space);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
