// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'kds_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class KdsLocalizationsAr extends KdsLocalizations {
  KdsLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'شاشة المطبخ';

  @override
  String headerOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طلب',
      many: '$count طلبًا',
      few: '$count طلبات',
      two: 'طلبان',
      one: 'طلب واحد',
      zero: 'لا توجد طلبات',
    );
    return 'شاشة المطبخ — $_temp0';
  }

  @override
  String pairedWith(String pos) {
    return 'مقترنة بـ $pos';
  }

  @override
  String get unpair => 'إلغاء الاقتران';

  @override
  String get unpairTitle => 'إلغاء اقتران هذه الشاشة؟';

  @override
  String unpairBody(String pos) {
    return 'سيتم فصل شاشة المطبخ هذه عن $pos والعودة إلى شاشة الاقتران.';
  }

  @override
  String get cancel => 'إلغاء';

  @override
  String get waitingForOrders => 'في انتظار الطلبات…';

  @override
  String get done => 'جاهز';

  @override
  String get typeDineIn => 'في المطعم';

  @override
  String get typeTakeaway => 'طلب خارجي';

  @override
  String get typeDelivery => 'توصيل';

  @override
  String get typeOrder => 'طلب';

  @override
  String get unknownItem => 'صنف غير معروف';

  @override
  String get brandTitle => 'شاشة المطبخ';

  @override
  String get waitingToPair => 'في انتظار الاقتران…';

  @override
  String get pairInstructions =>
      'للبدء، اقرن هذا الجهاز من إعدادات تطبيق نقطة البيع.';

  @override
  String get deviceNameLabel => 'اسم الجهاز';

  @override
  String get ipAddressLabel => 'عنوان IP';

  @override
  String get pairPath =>
      'نقطة البيع ← الإعدادات ← شاشة المطبخ ← أضف هذا العنوان';

  @override
  String get language => 'اللغة';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';
}
