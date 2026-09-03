// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'kds_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class KdsLocalizationsEn extends KdsLocalizations {
  KdsLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kitchen Display';

  @override
  String headerOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders',
      one: '1 order',
      zero: 'no orders',
    );
    return 'Kitchen Display — $_temp0';
  }

  @override
  String pairedWith(String pos) {
    return 'Paired with $pos';
  }

  @override
  String get unpair => 'Unpair';

  @override
  String get unpairTitle => 'Unpair this display?';

  @override
  String unpairBody(String pos) {
    return 'This Kitchen Display will be disconnected from $pos and return to the pairing screen.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get waitingForOrders => 'Waiting for orders…';

  @override
  String get done => 'DONE';

  @override
  String get typeDineIn => 'Dine in';

  @override
  String get typeTakeaway => 'Takeaway';

  @override
  String get typeDelivery => 'Delivery';

  @override
  String get typeOrder => 'Order';

  @override
  String get unknownItem => 'Unknown Item';

  @override
  String get brandTitle => 'KITCHEN DISPLAY';

  @override
  String get waitingToPair => 'Waiting to pair…';

  @override
  String get pairInstructions =>
      'To get started, pair this device in the POS app settings.';

  @override
  String get deviceNameLabel => 'Device name';

  @override
  String get ipAddressLabel => 'IP address';

  @override
  String get pairPath => 'POS → Settings → Kitchen Display → add this address';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';
}
