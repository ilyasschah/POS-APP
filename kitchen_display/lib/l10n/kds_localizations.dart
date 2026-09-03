import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'kds_localizations_ar.dart';
import 'kds_localizations_en.dart';
import 'kds_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of KdsLocalizations
/// returned by `KdsLocalizations.of(context)`.
///
/// Applications need to include `KdsLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/kds_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: KdsLocalizations.localizationsDelegates,
///   supportedLocales: KdsLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the KdsLocalizations.supportedLocales
/// property.
abstract class KdsLocalizations {
  KdsLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static KdsLocalizations of(BuildContext context) {
    return Localizations.of<KdsLocalizations>(context, KdsLocalizations)!;
  }

  static const LocalizationsDelegate<KdsLocalizations> delegate =
      _KdsLocalizationsDelegate();

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

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Display'**
  String get appTitle;

  /// No description provided for @headerOrders.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Display — {count, plural, =0{no orders} =1{1 order} other{{count} orders}}'**
  String headerOrders(int count);

  /// No description provided for @pairedWith.
  ///
  /// In en, this message translates to:
  /// **'Paired with {pos}'**
  String pairedWith(String pos);

  /// No description provided for @unpair.
  ///
  /// In en, this message translates to:
  /// **'Unpair'**
  String get unpair;

  /// No description provided for @unpairTitle.
  ///
  /// In en, this message translates to:
  /// **'Unpair this display?'**
  String get unpairTitle;

  /// No description provided for @unpairBody.
  ///
  /// In en, this message translates to:
  /// **'This Kitchen Display will be disconnected from {pos} and return to the pairing screen.'**
  String unpairBody(String pos);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @waitingForOrders.
  ///
  /// In en, this message translates to:
  /// **'Waiting for orders…'**
  String get waitingForOrders;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get done;

  /// No description provided for @typeDineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine in'**
  String get typeDineIn;

  /// No description provided for @typeTakeaway.
  ///
  /// In en, this message translates to:
  /// **'Takeaway'**
  String get typeTakeaway;

  /// No description provided for @typeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get typeDelivery;

  /// No description provided for @typeOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get typeOrder;

  /// No description provided for @unknownItem.
  ///
  /// In en, this message translates to:
  /// **'Unknown Item'**
  String get unknownItem;

  /// No description provided for @brandTitle.
  ///
  /// In en, this message translates to:
  /// **'KITCHEN DISPLAY'**
  String get brandTitle;

  /// No description provided for @waitingToPair.
  ///
  /// In en, this message translates to:
  /// **'Waiting to pair…'**
  String get waitingToPair;

  /// No description provided for @pairInstructions.
  ///
  /// In en, this message translates to:
  /// **'To get started, pair this device in the POS app settings.'**
  String get pairInstructions;

  /// No description provided for @deviceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get deviceNameLabel;

  /// No description provided for @ipAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get ipAddressLabel;

  /// No description provided for @pairPath.
  ///
  /// In en, this message translates to:
  /// **'POS → Settings → Kitchen Display → add this address'**
  String get pairPath;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;
}

class _KdsLocalizationsDelegate
    extends LocalizationsDelegate<KdsLocalizations> {
  const _KdsLocalizationsDelegate();

  @override
  Future<KdsLocalizations> load(Locale locale) {
    return SynchronousFuture<KdsLocalizations>(lookupKdsLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_KdsLocalizationsDelegate old) => false;
}

KdsLocalizations lookupKdsLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return KdsLocalizationsAr();
    case 'en':
      return KdsLocalizationsEn();
    case 'fr':
      return KdsLocalizationsFr();
  }

  throw FlutterError(
    'KdsLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
