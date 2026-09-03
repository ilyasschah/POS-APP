// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'kds_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class KdsLocalizationsFr extends KdsLocalizations {
  KdsLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Écran cuisine';

  @override
  String headerOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commandes',
      one: '1 commande',
      zero: 'aucune commande',
    );
    return 'Écran cuisine — $_temp0';
  }

  @override
  String pairedWith(String pos) {
    return 'Associé à $pos';
  }

  @override
  String get unpair => 'Dissocier';

  @override
  String get unpairTitle => 'Dissocier cet écran ?';

  @override
  String unpairBody(String pos) {
    return 'Cet écran cuisine sera déconnecté de $pos et reviendra à l’écran d’association.';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get waitingForOrders => 'En attente de commandes…';

  @override
  String get done => 'PRÊT';

  @override
  String get typeDineIn => 'Sur place';

  @override
  String get typeTakeaway => 'À emporter';

  @override
  String get typeDelivery => 'Livraison';

  @override
  String get typeOrder => 'Commande';

  @override
  String get unknownItem => 'Article inconnu';

  @override
  String get brandTitle => 'ÉCRAN CUISINE';

  @override
  String get waitingToPair => 'En attente d’association…';

  @override
  String get pairInstructions =>
      'Pour commencer, associez cet appareil dans les paramètres de l’application POS.';

  @override
  String get deviceNameLabel => 'Nom de l’appareil';

  @override
  String get ipAddressLabel => 'Adresse IP';

  @override
  String get pairPath =>
      'POS → Paramètres → Écran cuisine → ajouter cette adresse';

  @override
  String get language => 'Langue';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';
}
