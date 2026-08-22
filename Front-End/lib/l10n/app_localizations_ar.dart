// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionSaveChanges => 'حفظ التغييرات';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionEdit => 'تعديل';

  @override
  String get actionAdd => 'إضافة';

  @override
  String get actionClose => 'إغلاق';

  @override
  String get actionConfirm => 'تأكيد';

  @override
  String get actionRetry => 'إعادة المحاولة';

  @override
  String get actionSearch => 'بحث';

  @override
  String get actionRemove => 'إزالة';

  @override
  String get actionUpload => 'رفع';

  @override
  String get actionSkip => 'تخطّي';

  @override
  String get deviceRegistrationTitle => 'تسجيل الجهاز';

  @override
  String get deviceRegistrationSubtitle => 'سجّل الدخول بحسابك لربط هذا الجهاز';

  @override
  String get fieldEmail => 'البريد الإلكتروني';

  @override
  String get fieldPassword => 'كلمة المرور';

  @override
  String get developerMode => 'وضع المطور';

  @override
  String get unlinkDeviceConfirm => 'هل تريد بالتأكيد إلغاء ربط هذا الجهاز؟';

  @override
  String get unlinkDevice => 'إلغاء ربط الجهاز';

  @override
  String get timeClock => 'تسجيل الحضور';

  @override
  String get roleAdmin => 'مدير';

  @override
  String get roleCashier => 'أمين الصندوق';

  @override
  String get reloadUsers => 'إعادة تحميل المستخدمين';

  @override
  String get relinkDevice => 'إعادة ربط الجهاز';

  @override
  String get couldNotLoadUsers => 'تعذّر تحميل المستخدمين على هذا الجهاز.';

  @override
  String get noUsersCached => 'لا يوجد مستخدمون مخزّنون على هذا الجهاز.';

  @override
  String get restoringUsersFromServer => 'جارٍ استعادة المستخدمين من الخادم…';

  @override
  String get reconnectToRestoreUsers =>
      'أعد الاتصال لاستعادتهم، أو أعد ربط هذا الجهاز لتسجيل الدخول مجدداً.';

  @override
  String get actionYes => 'نعم';

  @override
  String get actionNo => 'لا';

  @override
  String get actionApply => 'تطبيق';

  @override
  String get actionContinue => 'متابعة';

  @override
  String get actionSet => 'تعيين';

  @override
  String get actionSwitch => 'تبديل';

  @override
  String get actionProceedAnyway => 'المتابعة على أي حال';

  @override
  String deleteProductsConfirm(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حذف $count منتج؟ لا يمكن التراجع عن هذا.',
      many: 'حذف $count منتجاً؟ لا يمكن التراجع عن هذا.',
      few: 'حذف $count منتجات؟ لا يمكن التراجع عن هذا.',
      two: 'حذف منتجين؟ لا يمكن التراجع عن هذا.',
      one: 'حذف منتج واحد؟ لا يمكن التراجع عن هذا.',
      zero: 'لا توجد منتجات للحذف.',
    );
    return '$_temp0';
  }

  @override
  String get colorMarkerHint =>
      'يلوّن بطاقة المنتج في شاشة نقطة البيع وقائمة المنتجات.';

  @override
  String get modifiersHint =>
      'أضف ملاحظات مثل «حار جداً» أو «يحتوي على مكسّرات».';

  @override
  String get barcodesHint =>
      'عيّن عدة رموز شريطية (للقطعة أو الصندوق أو المنصة).';

  @override
  String get importComplete => 'اكتمل الاستيراد';

  @override
  String get documentCreated => 'تم إنشاء المستند: ';

  @override
  String importErrorCount(num count) {
    return '$count خطأ:';
  }

  @override
  String get importTitle => 'استيراد';

  @override
  String get selectFile => 'اختر ملفاً';

  @override
  String get indicatesRequiredField => '* يشير إلى حقل مطلوب';

  @override
  String get skipColumn => '(تخطّي)';

  @override
  String get duplicatesQuestion => 'ماذا يحدث عند العثور على تكرارات؟';

  @override
  String get createDocumentFromQuantity => 'إنشاء مستند من الكمية المحددة';

  @override
  String get actionPreview => 'معاينة';

  @override
  String get fieldName => 'الاسم';

  @override
  String get fieldProductGroup => 'مجموعة المنتجات';

  @override
  String get fieldSku => 'SKU';

  @override
  String get fieldMeasurementUnit => 'وحدة القياس';

  @override
  String get fieldCost => 'التكلفة';

  @override
  String get fieldMarkup => 'نسبة الربح';

  @override
  String get fieldTax => 'الضريبة';

  @override
  String get fieldTaxInclusivePrice => 'السعر شامل الضريبة';

  @override
  String get fieldPriceChangeAllowed => 'يسمح بتغيير السعر';

  @override
  String get fieldUsingDefaultQuantity => 'يستخدم الكمية الافتراضية';

  @override
  String get fieldServiceNotStock => 'خدمة (بدون مخزون)';

  @override
  String get fieldEnabled => 'مُفعّل';

  @override
  String get fieldDescription => 'الوصف';

  @override
  String get fieldQuantity => 'الكمية';

  @override
  String get fieldSupplier => 'المورّد';

  @override
  String get fieldReorderPoint => 'حد إعادة الطلب';

  @override
  String get fieldPreferredQuantity => 'الكمية المفضّلة';

  @override
  String get fieldLowStockWarning => 'تنبيه انخفاض المخزون';

  @override
  String get fieldLowStockWarningQuantity => 'كمية تنبيه انخفاض المخزون';

  @override
  String get cannotDelete => 'لا يمكن الحذف';

  @override
  String get deleteGroup => 'حذف المجموعة';

  @override
  String deleteGroupConfirm(String name) {
    return 'هل تريد بالتأكيد حذف «$name»؟';
  }

  @override
  String get productGroups => 'مجموعات المنتجات';

  @override
  String get newGroup => 'مجموعة جديدة';

  @override
  String get deleteGroupTooltip => 'حذف المجموعة';

  @override
  String get failedToLoadGroups => 'فشل تحميل المجموعات';

  @override
  String get noneRoot => 'بدون (الجذر)';

  @override
  String get chooseImage => 'اختر صورة';

  @override
  String get searchProductsEllipsis => 'ابحث عن المنتجات…';

  @override
  String get failedToLoadProducts => 'فشل تحميل المنتجات';

  @override
  String get noProductsFoundShort => 'لم يتم العثور على منتجات';

  @override
  String get noProductGroupsYet => 'لا توجد مجموعات منتجات بعد';

  @override
  String get createOneToOrganize => 'أنشئ واحدة لتنظيم منتجاتك';

  @override
  String get createGroup => 'إنشاء مجموعة';

  @override
  String get customersLabel => 'العملاء';

  @override
  String get customerLabel => 'العميل';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get categoriesLabel => 'الفئات';

  @override
  String get errorLabel => 'خطأ';

  @override
  String get accountUserEmail => 'الحساب / بريد المستخدم';

  @override
  String get dateFormatLabel => 'تنسيق التاريخ';

  @override
  String get accessLevel => 'مستوى الصلاحية';

  @override
  String get actions => 'الإجراءات';

  @override
  String get addFirstUser => 'أضف أول مستخدم';

  @override
  String get addNewUser => 'إضافة مستخدم جديد';

  @override
  String get addPayment => 'إضافة دفعة';

  @override
  String get addUser => 'إضافة مستخدم';

  @override
  String get adminResetDevicePin => 'المدير: إعادة تعيين رمز الجهاز';

  @override
  String get adminResetPassword => 'المدير: إعادة تعيين كلمة المرور';

  @override
  String get filterAll => 'الكل';

  @override
  String get allCustomers => 'كل العملاء';

  @override
  String get allDocumentTypes => 'كل أنواع المستندات';

  @override
  String get allTransactions => 'كل المعاملات';

  @override
  String get allUsers => 'كل المستخدمين';

  @override
  String get allWarehouses => 'كل المستودعات';

  @override
  String get amount => 'المبلغ';

  @override
  String get assignToWarehouse => 'تعيين إلى مستودع';

  @override
  String get couldNotLoadRules => 'تعذّر تحميل القواعد';

  @override
  String get colCreated => 'تاريخ الإنشاء';

  @override
  String get colCustomer => 'العميل';

  @override
  String get dateLabel => 'التاريخ';

  @override
  String get deleteDocument => 'حذف المستند';

  @override
  String get deleteRule => 'حذف القاعدة';

  @override
  String get deleteUser => 'حذف المستخدم';

  @override
  String get colDisc => 'الخصم';

  @override
  String get discountBreakdown => 'تفصيل الخصومات';

  @override
  String get documentExplorer => 'مستكشف المستندات';

  @override
  String get editRules => 'تعديل القواعد';

  @override
  String get editUser => 'تعديل المستخدم';

  @override
  String get errorLoadingTaxes => 'خطأ في تحميل الضرائب';

  @override
  String get excel => 'إكسل';

  @override
  String get expirationDate => 'تاريخ الانتهاء';

  @override
  String get expirationDateOptional => 'تاريخ الانتهاء (اختياري)';

  @override
  String get firstName => 'الاسم الأول';

  @override
  String get firstNameRequired => 'الاسم الأول *';

  @override
  String get fixed => 'ثابت';

  @override
  String get idLabel => 'المعرّف';

  @override
  String get initialQuantity => 'الكمية الأولية';

  @override
  String get internalNote => 'ملاحظة داخلية';

  @override
  String get inventoryMasterList => 'قائمة المخزون الرئيسية';

  @override
  String get itemDiscount => 'خصم الصنف';

  @override
  String get lastName => 'اسم العائلة';

  @override
  String get lastNameRequired => 'اسم العائلة *';

  @override
  String get lowStock => 'مخزون منخفض';

  @override
  String get lowStockWarning => 'تنبيه انخفاض المخزون';

  @override
  String get manageWarehouses => 'إدارة المستودعات';

  @override
  String get markAsUnpaid => 'وضع علامة غير مدفوع؟';

  @override
  String get needsReorder => 'يحتاج إعادة طلب';

  @override
  String get colNew => 'جديد';

  @override
  String get newFourDigitPin => 'رمز جديد من 4 أرقام';

  @override
  String get newPassword => 'كلمة مرور جديدة';

  @override
  String get newQuantity => 'الكمية الجديدة';

  @override
  String get noSecurityRules => 'لم يتم العثور على قواعد أمان.';

  @override
  String get noTaxShort => 'بدون ضريبة';

  @override
  String get noneLabel => 'بدون';

  @override
  String get noteLabel => 'ملاحظة';

  @override
  String get colNumber => 'الرقم';

  @override
  String get colOrderNo => 'رقم الطلب';

  @override
  String get paid => 'مدفوع';

  @override
  String get partial => 'جزئي';

  @override
  String get passwordRequired => 'كلمة المرور *';

  @override
  String get paymentType => 'نوع الدفع';

  @override
  String get preferredQuantity => 'الكمية المفضّلة';

  @override
  String get priceAfterTax => 'السعر (بعد الضريبة)';

  @override
  String get priceBeforeTax => 'السعر قبل الضريبة';

  @override
  String get printStockReportPdf => 'طباعة تقرير المخزون (PDF)';

  @override
  String get productLabel => 'المنتج';

  @override
  String get productRequired => 'المنتج *';

  @override
  String get referenceDocument => 'المستند المرجعي';

  @override
  String get removeStock => 'إزالة من المخزون';

  @override
  String get reorderPoint => 'حد إعادة الطلب';

  @override
  String get reports => 'التقارير';

  @override
  String get ruleExistsEditing => 'القاعدة موجودة — جارٍ التعديل';

  @override
  String get saveStockReportPdf => 'حفظ تقرير المخزون كملف PDF';

  @override
  String get searchProductNameOrCode => 'ابحث باسم المنتج أو رمزه…';

  @override
  String get searchReports => 'ابحث في التقارير';

  @override
  String get securityActions => 'إجراءات الأمان';

  @override
  String get selectDocumentType => 'اختر نوع المستند';

  @override
  String get selectReport => 'اختر تقريراً';

  @override
  String get showReport => 'عرض التقرير';

  @override
  String get colStatus => 'الحالة';

  @override
  String get colSvc => 'خدمة';

  @override
  String get syncAndRefresh => 'مزامنة وتحديث';

  @override
  String get tabNotFound => 'لم يتم العثور على التبويب';

  @override
  String get taxOptional => 'الضريبة (اختياري)';

  @override
  String get taxAmount => 'مبلغ الضريبة';

  @override
  String get totalDiscounts => 'إجمالي الخصومات';

  @override
  String get typeLabel => 'النوع';

  @override
  String get unpaid => 'غير مدفوع';

  @override
  String get updateItem => 'تحديث الصنف';

  @override
  String get colUpdated => 'تاريخ التحديث';

  @override
  String get colUser => 'المستخدم';

  @override
  String get userRequired => 'المستخدم *';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get usernameRequired => 'اسم المستخدم *';

  @override
  String get usersAndSecurity => 'المستخدمون والأمان';

  @override
  String get valueTotal => 'القيمة (الإجمالي)';

  @override
  String get warehouse => 'المستودع';

  @override
  String get warehouseRequired => 'المستودع *';

  @override
  String get warningThreshold => 'حد التنبيه';

  @override
  String get yesDeletePayments => 'نعم، احذف الدفعات';

  @override
  String errorLoadingDocuments(String message) {
    return 'خطأ في تحميل المستندات: $message';
  }

  @override
  String errorLoadingSecurityRules(String message) {
    return 'خطأ في تحميل قواعد الأمان: $message';
  }

  @override
  String errorLoadingUsers(String message) {
    return 'خطأ في تحميل المستخدمين: $message';
  }

  @override
  String saveFailed(String message) {
    return 'فشل الحفظ: $message';
  }

  @override
  String savedToPath(String path) {
    return 'تم الحفظ في $path';
  }

  @override
  String get addBooking => 'إضافة حجز';

  @override
  String get addCard => 'إضافة بطاقة';

  @override
  String get addFirstTaxRate => 'أضف أول نسبة ضريبة';

  @override
  String get addFirstWarehouse => 'أضف أول مستودع';

  @override
  String get addLoyaltyCard => 'إضافة بطاقة ولاء';

  @override
  String get addPromotion => 'إضافة عرض';

  @override
  String get addTable => 'إضافة طاولة';

  @override
  String get addTimeCard => 'إضافة بطاقة وقت';

  @override
  String get addWarehouse => 'إضافة مستودع';

  @override
  String get addResizeRenameTables =>
      'إضافة الطاولات وتغيير حجمها وإعادة تسميتها';

  @override
  String get allEmployees => 'كل الموظفين ...';

  @override
  String get applyName => 'تطبيق الاسم';

  @override
  String get endShiftConfirm => 'هل تريد بالتأكيد إنهاء ورديتك؟';

  @override
  String get back => 'رجوع';

  @override
  String get bookingAlerts => 'تنبيهات الحجز';

  @override
  String get bookingSaved => 'تم حفظ الحجز!';

  @override
  String get cardNumber => 'رقم البطاقة';

  @override
  String get shapeCircle => 'دائرة';

  @override
  String get clockIn => 'تسجيل الحضور';

  @override
  String get clockOut => 'تسجيل الانصراف';

  @override
  String get confirmDelete => 'تأكيد الحذف';

  @override
  String get couldNotLoadEmployees => 'تعذّر تحميل الموظفين';

  @override
  String get created => 'تم الإنشاء';

  @override
  String get currencies => 'العملات';

  @override
  String get customerRequired => 'العميل *';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get days => 'الأيام';

  @override
  String get deleteBooking => 'حذف الحجز';

  @override
  String get deleteLoyaltyCard => 'حذف بطاقة الولاء';

  @override
  String get deleteTax => 'حذف الضريبة';

  @override
  String get deleteWarehouse => 'حذف المستودع';

  @override
  String get documentItemsColumns => 'أعمدة أصناف المستند';

  @override
  String get documentType => 'نوع المستند';

  @override
  String get documents => 'المستندات';

  @override
  String get documentsColumns => 'أعمدة المستندات';

  @override
  String get hintTwentyPercent => 'مثال: 20 لـ 20%';

  @override
  String get hintSecondFloor => 'مثال: الطابق الثاني';

  @override
  String get earningRule => 'قاعدة الكسب';

  @override
  String get editFloorPlan => 'تعديل مخطط القاعة';

  @override
  String get employee => 'الموظف';

  @override
  String get enableLoyaltyPoints => 'تفعيل نقاط الولاء';

  @override
  String get endDate => 'تاريخ الانتهاء';

  @override
  String get endOfDay => 'نهاية اليوم';

  @override
  String get endShift => 'إنهاء الوردية';

  @override
  String get endTime => 'وقت الانتهاء';

  @override
  String get colExport => 'تصدير';

  @override
  String get externalRef => 'مرجع خارجي';

  @override
  String get floorPlan => 'مخطط القاعة';

  @override
  String get gotIt => 'فهمت';

  @override
  String get guestNameRequired => 'اسم الضيف *';

  @override
  String get guests => 'الضيوف';

  @override
  String get leaveBlankAutoAssign => 'اتركه فارغاً للتعيين التلقائي';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get loyaltyCards => 'بطاقات الولاء';

  @override
  String get loyaltySettings => 'إعدادات الولاء';

  @override
  String get minPurchaseAmount => 'الحد الأدنى لمبلغ الشراء';

  @override
  String get moveStock => 'نقل المخزون';

  @override
  String get moveStockTo => 'نقل المخزون إلى…';

  @override
  String get myCompany => 'شركتي';

  @override
  String get nameRequired => 'الاسم *';

  @override
  String get newFloor => 'طابق جديد';

  @override
  String get newFloorPlan => 'مخطط قاعة جديد';

  @override
  String get newTax => 'ضريبة جديدة';

  @override
  String get newTaxRate => 'نسبة ضريبة جديدة';

  @override
  String get nextDay => 'اليوم التالي';

  @override
  String get noWarehousesFound => 'لم يتم العثور على مستودعات.';

  @override
  String get notesOptional => 'ملاحظات (اختياري)';

  @override
  String get numberLabel => 'الرقم';

  @override
  String get oldTax => 'الضريبة القديمة';

  @override
  String get openDocument => 'فتح المستند';

  @override
  String get openOrder => 'فتح الطلب';

  @override
  String get openOrders => 'الطلبات المفتوحة';

  @override
  String get openService => 'فتح الخدمة';

  @override
  String get openedAt => 'فُتح في';

  @override
  String get orderNoLabel => 'رقم الطلب';

  @override
  String get pageLabel => 'الصفحة:';

  @override
  String get paymentLabel => 'الدفع';

  @override
  String get paymentTypesShort => 'أنواع الدفع';

  @override
  String get pendingLower => 'قيد الانتظار';

  @override
  String get points => 'النقاط';

  @override
  String get pointsEarned => 'النقاط المكتسبة';

  @override
  String get posLabel => 'نقطة البيع';

  @override
  String get previousDay => 'اليوم السابق';

  @override
  String get priceLabel => 'السعر';

  @override
  String get promotions => 'العروض';

  @override
  String get rateRequired => 'النسبة *';

  @override
  String get redemptionRule => 'قاعدة الاستبدال';

  @override
  String get refresh => 'تحديث';

  @override
  String get removeFloor => 'حذف الطابق';

  @override
  String get removeFloorPlan => 'حذف مخطط القاعة';

  @override
  String get removeTable => 'حذف الطاولة';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get replace => 'استبدال';

  @override
  String get revokeStock => 'سحب المخزون';

  @override
  String get rowsPerPage => 'الصفوف في الصفحة:';

  @override
  String get sales => 'المبيعات';

  @override
  String get saveUpper => 'حفظ';

  @override
  String get searchCustomer => 'ابحث عن عميل...';

  @override
  String get searchDocument => 'ابحث عن مستند...';

  @override
  String get selectEmployee => 'اختر موظفاً';

  @override
  String get selectTablesRequired => 'اختر الطاولات *';

  @override
  String get settings => 'الإعدادات';

  @override
  String get shiftManagement => 'إدارة الورديات';

  @override
  String get showGrid => 'إظهار الشبكة';

  @override
  String get showQr => 'إظهار رمز QR';

  @override
  String get snapToGrid => 'المحاذاة للشبكة';

  @override
  String get shapeSquare => 'مربع';

  @override
  String get startDate => 'تاريخ البدء';

  @override
  String get startService => 'بدء الخدمة';

  @override
  String get startShift => 'بدء الوردية';

  @override
  String get startTime => 'وقت البدء';

  @override
  String get startingPoints => 'النقاط الابتدائية';

  @override
  String get statusLabel => 'الحالة';

  @override
  String get stayOnCalendar => 'البقاء في التقويم';

  @override
  String get stock => 'المخزون';

  @override
  String get switchTaxes => 'تبديل الضرائب';

  @override
  String get taxRates => 'نسب الضرائب';

  @override
  String get totalBeforeDiscount => 'الإجمالي قبل الخصم';

  @override
  String get totalBeforeTax => 'الإجمالي قبل الضريبة';

  @override
  String get unitOfMeasure => 'وحدة القياس';

  @override
  String get userLabel => 'المستخدم';

  @override
  String get users => 'المستخدمون';

  @override
  String get warehouseHasStock => 'المستودع يحتوي على مخزون';

  @override
  String get warehouseNameRequired => 'اسم المستودع *';

  @override
  String get warehouses => 'المستودعات';

  @override
  String get whichTableForOrder => 'على أي طاولة يُوضع هذا الطلب؟';

  @override
  String errorLoadingLoyaltyCards(String message) {
    return 'خطأ في تحميل بطاقات الولاء: $message';
  }

  @override
  String errorLoadingWarehouses(String message) {
    return 'خطأ في تحميل المستودعات: $message';
  }

  @override
  String get colActions => 'الإجراءات';

  @override
  String get addCash => 'إضافة نقد';

  @override
  String get addItem => 'إضافة صنف';

  @override
  String get addProductLower => 'إضافة منتج';

  @override
  String get addPromotionItem => 'إضافة صنف للعرض';

  @override
  String get addReturnedProducts => 'أضف المنتجات المُرجعة';

  @override
  String get addTimeCardUpper => 'إضافة بطاقة وقت';

  @override
  String get allWarehousesCap => 'كل المستودعات';

  @override
  String get appliesTo => 'ينطبق على';

  @override
  String get deleteVoidReasonConfirm => 'هل تريد بالتأكيد حذف سبب الإلغاء هذا؟';

  @override
  String get authorise => 'تفويض';

  @override
  String get bookingHistory => 'سجل الحجوزات';

  @override
  String get cancelEdit => 'إلغاء التعديل';

  @override
  String get cashIn => 'إدخال نقد';

  @override
  String get cashInOut => 'إدخال / إخراج النقد';

  @override
  String get cashMovement => 'حركة النقد';

  @override
  String get cashOut => 'إخراج نقد';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get clearAll => 'مسح الكل';

  @override
  String get closeRegister => 'إغلاق الصندوق';

  @override
  String get confirmNewPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get country => 'الدولة';

  @override
  String get createUser => 'إنشاء مستخدم';

  @override
  String get creditPayments => 'المدفوعات الآجلة';

  @override
  String get currencyCodeRequired => 'رمز العملة (مثال USD) *';

  @override
  String get currencyNameRequired => 'اسم العملة (مثال الدولار الأمريكي) *';

  @override
  String get customersSuppliers => 'العملاء والموردون';

  @override
  String get colDate => 'التاريخ';

  @override
  String get deleteCurrency => 'حذف العملة';

  @override
  String get deleteVoidReason => 'حذف سبب الإلغاء';

  @override
  String get descriptionOptional => 'الوصف (اختياري)';

  @override
  String get discountType => 'نوع الخصم';

  @override
  String get discountValue => 'قيمة الخصم';

  @override
  String get hintWifiBill => 'مثال: فاتورة واي فاي، سلفة';

  @override
  String get cashReasonHint => 'أدخل سبب إضافة أو سحب النقد...';

  @override
  String get errorLoadingTables => 'خطأ في تحميل الطاولات';

  @override
  String get exitApplication => 'إغلاق التطبيق';

  @override
  String get failedToLoadOrders => 'فشل تحميل الطلبات';

  @override
  String get feedback => 'ملاحظات';

  @override
  String get financialInfo => 'المعلومات المالية';

  @override
  String get fixedAmount => 'مبلغ ثابت';

  @override
  String get fullScreen => 'ملء الشاشة';

  @override
  String get generalInfo => 'معلومات عامة';

  @override
  String get globalCurrencies => 'العملات العالمية';

  @override
  String get gridView => 'شبكة';

  @override
  String get hideSidebar => 'إخفاء الشريط الجانبي';

  @override
  String get isActive => 'نشط';

  @override
  String get isEnabled => 'مُفعّل';

  @override
  String get listView => 'قائمة';

  @override
  String get loadingPaymentTypes => 'جارٍ تحميل أنواع الدفع…';

  @override
  String get locationAddress => 'الموقع والعنوان';

  @override
  String get management => 'الإدارة';

  @override
  String get managerAuthorisation => 'تفويض المدير';

  @override
  String get managerPin => 'رمز المدير';

  @override
  String get menuLabel => 'القائمة';

  @override
  String get newCurrency => 'عملة جديدة';

  @override
  String get noCurrenciesFound => 'لم يتم العثور على عملات.';

  @override
  String get noPromotionsFound => 'لم يتم العثور على عروض.';

  @override
  String get blindReturn => 'لا يوجد إيصال؟ إرجاع دون مرجع';

  @override
  String get noUserLoggedIn => 'لا يوجد مستخدم مسجّل الدخول حالياً.';

  @override
  String get noUsersFound => 'لم يتم العثور على مستخدمين';

  @override
  String get noVoidReasonsYet => 'لا توجد أسباب إلغاء بعد.';

  @override
  String get colNote => 'ملاحظة';

  @override
  String get oldPassword => 'كلمة المرور القديمة';

  @override
  String get paymentMethodColon => 'طريقة الدفع:';

  @override
  String get paymentTypeLower => 'نوع الدفع';

  @override
  String get percentage => 'نسبة مئوية';

  @override
  String get percentageSign => 'نسبة مئوية (%)';

  @override
  String get posSystem => 'نظام نقطة البيع';

  @override
  String get power => 'الطاقة';

  @override
  String get powerOptions => 'خيارات الطاقة';

  @override
  String get promotionName => 'اسم العرض';

  @override
  String get promotionsManagement => 'إدارة العروض';

  @override
  String get quickSettings => 'إعدادات سريعة';

  @override
  String get rankDisplayOrderLower => 'الترتيب (ترتيب العرض)';

  @override
  String get refundItems => 'أصناف الاسترجاع';

  @override
  String get refundPaymentType => 'نوع دفع الاسترجاع';

  @override
  String get removeCash => 'سحب نقد';

  @override
  String get requiredQty => 'الكمية المطلوبة';

  @override
  String get restartApplication => 'إعادة تشغيل التطبيق';

  @override
  String get sameProduct => 'نفس المنتج';

  @override
  String get savePin => 'حفظ الرمز';

  @override
  String get searchReceiptToSeeItems => 'ابحث عن إيصال لعرض أصنافه';

  @override
  String get searchByName => 'ابحث بالاسم…';

  @override
  String get searchByOrderStaffTable => 'ابحث بالطلب أو الموظف أو الطاولة';

  @override
  String get searchNamePhoneCard => 'ابحث بالاسم أو الهاتف أو رقم البطاقة…';

  @override
  String get searchProductEllipsis => 'ابحث عن منتج…';

  @override
  String get searchWarehouse => 'ابحث عن مستودع…';

  @override
  String get selectCustomer => 'اختر عميلاً';

  @override
  String get selectWarehouse => 'اختر مستودعاً';

  @override
  String get selectYourCompany => 'اختر شركتك';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get supplier => 'المورّد';

  @override
  String get targetUid => 'المعرّف الهدف (مثال معرّف المنتج)';

  @override
  String get taxExempt => 'معفى من الضريبة';

  @override
  String get totalRefundAmount => 'إجمالي مبلغ الاسترجاع';

  @override
  String get turnOffPc => 'إيقاف تشغيل الجهاز';

  @override
  String get colType => 'النوع';

  @override
  String get updateDevicePin => 'تحديث رمز الجهاز';

  @override
  String get updatePinForDevice => 'تحديث الرمز لهذا الجهاز';

  @override
  String get useWeight => 'استخدام الوزن';

  @override
  String get userInfo => 'معلومات المستخدم';

  @override
  String get userInfoSecurity => 'معلومات المستخدم والأمان';

  @override
  String get viewOpenSales => 'عرض المبيعات المفتوحة';

  @override
  String get viewSalesHistory => 'عرض سجل المبيعات';

  @override
  String get voidReasons => 'أسباب الإلغاء';

  @override
  String get welcomeToYourPos => 'مرحباً بك في نقطة البيع';

  @override
  String errorLoadingBookings(String message) {
    return 'خطأ في تحميل الحجوزات: $message';
  }

  @override
  String errorLoadingCustomers(String message) {
    return 'خطأ في تحميل العملاء: $message';
  }

  @override
  String get addPrinter => 'إضافة طابعة';

  @override
  String get addressFormat => 'تنسيق العنوان';

  @override
  String get allProducts2 => 'كل المنتجات';

  @override
  String get forceOnCreditSales =>
      'يظهر دائماً في المبيعات الآجلة؛ هذا يفرضه حتى عند الدفع';

  @override
  String get amountDue => 'المبلغ المستحق';

  @override
  String get bottom => 'أسفل';

  @override
  String get cashDrawerCommand => 'أمر درج النقود';

  @override
  String get change => 'الباقي';

  @override
  String get collapseSidebar => 'طيّ الشريط الجانبي';

  @override
  String get companyHeader => 'ترويسة الشركة';

  @override
  String get kitchenPrintingSection => 'طباعة المطبخ';

  @override
  String get autoKitchenPrintOnCheckout =>
      'طباعة تذاكر المطبخ تلقائيًا عند الدفع';

  @override
  String get autoKitchenPrintSubtitle =>
      'هذا الجهاز فقط. عند إتمام البيع، تُطبع نفس تذاكر المحطات مثل زر المطبخ.';

  @override
  String get companyPhoneTel => 'هاتف الشركة';

  @override
  String get companyTaxNumber => 'الرقم الضريبي للشركة';

  @override
  String get customLabels => 'تسميات مخصصة';

  @override
  String get customerDetailLabels => 'تسميات تفاصيل العميل';

  @override
  String get customerDetails => 'تفاصيل العميل';

  @override
  String get customizeReceipt => 'تخصيص الإيصال';

  @override
  String get decimalPlaces => 'المنازل العشرية';

  @override
  String get deletePrinter => 'حذف الطابعة';

  @override
  String get discountColumn => 'عمود الخصم';

  @override
  String get hintBarPrinter => 'مثال: طابعة البار';

  @override
  String get expandSidebar => 'توسيع الشريط الجانبي';

  @override
  String get font => 'الخط';

  @override
  String get fontFamily => 'عائلة الخط';

  @override
  String get fontSettings => 'إعدادات الخط';

  @override
  String get footer => 'التذييل';

  @override
  String get footerText => 'نص التذييل';

  @override
  String get forRtlLanguages => 'للغات من اليمين لليسار (العربية، العبرية)';

  @override
  String get globalFooter => 'التذييل العام';

  @override
  String get globalHeader => 'الترويسة العامة';

  @override
  String get header => 'الترويسة';

  @override
  String get headerAndFooter => 'الترويسة والتذييل';

  @override
  String get headerText => 'نص الترويسة';

  @override
  String get invoiceFont => 'خط الفاتورة';

  @override
  String get invoiceSettings => 'إعدادات الفاتورة';

  @override
  String get itemsCount => 'عدد الأصناف';

  @override
  String get kitchenPrinting => 'طباعة المطبخ';

  @override
  String get leftSide => 'يسار';

  @override
  String get localizeText => 'ترجمة النص';

  @override
  String get marginsMm => 'الهوامش (بالمليمتر)';

  @override
  String get mergeIdenticalItems => 'دمج الأصناف المتطابقة';

  @override
  String get noCategoryFilter => 'بدون تصفية حسب الفئة — يطبع كل الأصناف';

  @override
  String get noPrintersFound => 'لم يتم العثور على طابعات';

  @override
  String get printerSelectionUnsupportedOnThisDevice =>
      'لا يمكن لهذا الجهاز اختيار طابعة من النظام. ستفتح الطباعة مربع حوار الطباعة الخاص بالجهاز بدلاً من ذلك.';

  @override
  String get numberOfCopies => 'عدد النسخ';

  @override
  String get openCashDrawerLower => 'فتح درج النقود';

  @override
  String get options => 'الخيارات';

  @override
  String get orderNumberLower => 'رقم الطلب';

  @override
  String get otherSettings => 'إعدادات أخرى';

  @override
  String get outstandingBalance => 'الرصيد المستحق';

  @override
  String get paidAmount => 'المبلغ المدفوع';

  @override
  String get paymentMethods => 'طرق الدفع';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get printAddress => 'طباعة العنوان';

  @override
  String get printBarcode => 'طباعة الرمز الشريطي';

  @override
  String get printCategory => 'فئة الطباعة';

  @override
  String get printDemoReceipt => 'طباعة إيصال تجريبي';

  @override
  String get printInA5 => 'الطباعة بحجم A5';

  @override
  String get printItemsCount => 'طباعة عدد الأصناف';

  @override
  String get printKitchenTicket => 'طباعة تذكرة المطبخ';

  @override
  String get printLargeOrderNumber => 'طباعة رقم الطلب بحجم كبير';

  @override
  String get printLogoFullWidth => 'طباعة الشعار بعرض كامل';

  @override
  String get printMeasurementUnit => 'طباعة وحدة القياس';

  @override
  String get printTrailingCounter => 'طباعة العدّاد النهائي فقط (مثال 000008)';

  @override
  String get printOrderNumber => 'طباعة رقم الطلب';

  @override
  String get printOutstandingBalance => 'طباعة الرصيد المستحق';

  @override
  String get printPhoneTel => 'طباعة الهاتف';

  @override
  String get printTaxName => 'طباعة اسم الضريبة';

  @override
  String get printTaxNumber => 'طباعة الرقم الضريبي';

  @override
  String get printTaxTotals => 'طباعة مجاميع الضريبة';

  @override
  String get printTemplates => 'قوالب الطباعة';

  @override
  String get printTotalQuantity => 'طباعة الكمية الإجمالية';

  @override
  String get printerName => 'اسم الطابعة';

  @override
  String get printerSettings => 'إعدادات الطابعة';

  @override
  String get printers => 'الطابعات';

  @override
  String get productGroupsUpper => 'مجموعات المنتجات';

  @override
  String get receiptContent => 'محتوى الإيصال';

  @override
  String get receiptLabels => 'تسميات الإيصال';

  @override
  String get receiptNumber => 'رقم الإيصال';

  @override
  String get refreshAll => 'تحديث الكل';

  @override
  String get refreshPrinters => 'تحديث الطابعات';

  @override
  String get renamePrinter => 'إعادة تسمية الطابعة';

  @override
  String get reporting => 'التقارير';

  @override
  String get restricted => 'مقيّد';

  @override
  String get rightSide => 'يمين';

  @override
  String get rightToLeft => 'من اليمين إلى اليسار';

  @override
  String get cashDrawerSignalHint => 'يرسل إشارة إلى درج النقود بعد الدفع';

  @override
  String get shortReceiptNumber => 'رقم إيصال مختصر';

  @override
  String get subtotal => 'المجموع الفرعي';

  @override
  String get taxColumn => 'عمود الضريبة';

  @override
  String get taxNumber => 'الرقم الضريبي';

  @override
  String get titleLabel => 'العنوان';

  @override
  String get top => 'أعلى';

  @override
  String get topCustomers => 'أفضل العملاء';

  @override
  String get topProducts => 'أفضل المنتجات';

  @override
  String get totalRevenue => 'إجمالي الإيرادات';

  @override
  String get fallbackWordingHint => 'أوقفه للعودة إلى الصياغة الافتراضية';

  @override
  String get useCustomLabels => 'استخدام تسميات مخصصة في التقارير والفواتير';

  @override
  String get kitchenFireHint => 'تشغيل هذه الطابعة عند الضغط على زر المطبخ. مع';

  @override
  String get myCompanyLower => 'شركتي';

  @override
  String get customersSuppliersLower => 'العملاء والموردون';

  @override
  String get usersSecurityLower => 'المستخدمون والأمان';

  @override
  String get voidReasonsLower => 'أسباب الإلغاء';

  @override
  String get taxRatesLower => 'نسب الضرائب';

  @override
  String get paymentTypesLower => 'أنواع الدفع';

  @override
  String get rptSalesByProduct => 'المنتجات';

  @override
  String get rptSalesByGroup => 'مجموعات المنتجات';

  @override
  String get rptSalesByCustomer => 'العملاء';

  @override
  String get rptTaxRates => 'نسب الضرائب';

  @override
  String get rptUsers => 'المستخدمون';

  @override
  String get rptItemList => 'قائمة الأصناف';

  @override
  String get rptPaymentTypes => 'أنواع الدفع';

  @override
  String get rptPaymentByUser => 'أنواع الدفع حسب المستخدم';

  @override
  String get rptPaymentByCustomer => 'أنواع الدفع حسب العميل';

  @override
  String get rptRefunds => 'الاسترجاعات';

  @override
  String get rptInvoiceList => 'قائمة الفواتير';

  @override
  String get rptDailySales => 'المبيعات اليومية';

  @override
  String get rptHourlySales => 'المبيعات بالساعة';

  @override
  String get rptHourlyByGroup => 'المبيعات بالساعة حسب المجموعة';

  @override
  String get rptByTable => 'الطاولة أو رقم الطلب';

  @override
  String get rptProfitMargin => 'الربح والهامش';

  @override
  String get rptUnpaidSales => 'المبيعات غير المدفوعة';

  @override
  String get rptStartingCash => 'إدخالات النقد الافتتاحي';

  @override
  String get rptVoidedItems => 'الأصناف الملغاة';

  @override
  String get rptDiscountsGranted => 'الخصومات الممنوحة';

  @override
  String get rptDiscountsBySource => 'الخصومات حسب المصدر';

  @override
  String get rptItemDiscounts => 'خصومات الأصناف';

  @override
  String get rptStockMovement => 'حركة المخزون';

  @override
  String get rptSuppliers => 'الموردون';

  @override
  String get rptUnpaidPurchase => 'المشتريات غير المدفوعة';

  @override
  String get rptPurchaseDiscounts => 'خصومات المشتريات';

  @override
  String get rptPurchasedItemDiscounts => 'خصومات الأصناف المشتراة';

  @override
  String get rptPurchaseInvoiceList => 'قائمة فواتير الشراء';

  @override
  String get rptExpirationDate => 'تاريخ الانتهاء';

  @override
  String get rptReorderList => 'قائمة إعادة طلب المنتجات';

  @override
  String get rptLowStockWarning => 'تنبيه انخفاض المخزون';

  @override
  String get rptTransactionHistory => 'سجل المعاملات';

  @override
  String get secSales => 'المبيعات';

  @override
  String get secPurchase => 'المشتريات';

  @override
  String get secStockReturn => 'إرجاع المخزون';

  @override
  String get secLossAndDamage => 'الفاقد والتالف';

  @override
  String get secStockControl => 'مراقبة المخزون';

  @override
  String get secFinance => 'المالية';

  @override
  String get accent => 'لون التمييز';

  @override
  String get backups => 'النسخ الاحتياطي';

  @override
  String get barcodeScanning => 'مسح الرموز الشريطية';

  @override
  String get clockInUpper => 'تسجيل الحضور';

  @override
  String get clockOutUpper => 'تسجيل الانصراف';

  @override
  String get customerDisplayLower => 'شاشة العميل';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get databaseLower => 'قاعدة البيانات';

  @override
  String get deviceNameLower => 'اسم الجهاز';

  @override
  String get dualCurrencyLower => 'العملة المزدوجة';

  @override
  String get enableBookings => 'تفعيل الحجوزات';

  @override
  String get endOfDayLower => 'نهاية اليوم';

  @override
  String get generalLower => 'عام';

  @override
  String get kitchenDisplayLower => 'شاشة المطبخ';

  @override
  String get loadingCurrencies => 'جارٍ تحميل العملات…';

  @override
  String get loyaltyCardsLower => 'بطاقات الولاء';

  @override
  String get onScreenKeyboard => 'لوحة مفاتيح على الشاشة';

  @override
  String get openReservation => 'فتح الحجز';

  @override
  String get reservedTable => 'طاولة محجوزة';

  @override
  String get selectCustomerLower => 'اختر عميلاً';

  @override
  String get selectEllipsisShort => 'اختر…';

  @override
  String get touchKeyboardHint => 'إظهار لوحة مفاتيح لمسية عند الكتابة.';

  @override
  String get subscriptionUpper => 'الاشتراك';

  @override
  String get takeReservationsHint => 'استقبال الحجوزات مسبقاً.';

  @override
  String get textSize => 'حجم النص';

  @override
  String get theme => 'الثيم';

  @override
  String get timeClockTitle => 'تسجيل الوقت';

  @override
  String get today => 'اليوم';

  @override
  String get totalUpper => 'الإجمالي';

  @override
  String get walkIn => 'بدون حجز';

  @override
  String get weighingScaleLower => 'ميزان';

  @override
  String get trimZerosFromCode => 'إزالة الأصفار من رمز المنتج';

  @override
  String get posNamePrefixHint => 'اسم نقطة البيع — بادئة أرقام المستندات';

  @override
  String get promotionsLower => 'العروض';

  @override
  String get welcomeBody =>
      'نقطة بيع سريعة تعمل دون اتصال لأجهزتك ولوحاتك. اضبطها بلمسات قليلة.';

  @override
  String get featBarcodeBody => 'امسح لتسجيل أو إيجاد أي منتج فوراً.';

  @override
  String get featCustomerDisplayBody => 'اعرض الطلب والمجموع على شاشة ثانية.';

  @override
  String get featKitchenBody => 'أرسل الطلبات مباشرة إلى المطبخ (KDS).';

  @override
  String get featBackupsBody => 'نسخ احتياطية محلية تلقائية تحافظ على بياناتك.';

  @override
  String get featScaleBody => 'بِع بالوزن عبر ميزان تسلسلي متصل.';

  @override
  String get featPromotionsBody => 'خصومات تلقائية وأسعار خاصة.';

  @override
  String get featLoyaltyBody => 'نقاط ومكافآت تُعيد العملاء.';

  @override
  String get exitManagement => 'الخروج من الإدارة';

  @override
  String get chooseColumns => 'اختر الأعمدة';

  @override
  String get viewPrintReceipt => 'عرض وطباعة الإيصال';

  @override
  String get deleteItemAction => 'حذف الصنف';

  @override
  String get editItemAction => 'تعديل الصنف';

  @override
  String get noStockAssigned => 'لا يوجد مخزون مخصص لهذا';

  @override
  String get noStockControlRules => 'لم يتم إعداد قواعد مراقبة المخزون';

  @override
  String get selectGroupToEdit => 'اختر مجموعة للتعديل أو أنشئ واحدة جديدة.';

  @override
  String editNamedTitle(Object name) {
    return 'تعديل $name';
  }

  @override
  String forceResetPinTitle(Object name) {
    return 'إعادة تعيين رمز الدخول: $name';
  }

  @override
  String forceResetPasswordTitle(Object name) {
    return 'إعادة تعيين كلمة المرور: $name';
  }

  @override
  String editPaymentTitle(Object id) {
    return 'تعديل الدفعة رقم $id';
  }

  @override
  String editDashTitle(Object name) {
    return 'تعديل — $name';
  }

  @override
  String confirmDeleteQuoted(Object name) {
    return 'هل تريد بالتأكيد حذف «$name»؟';
  }

  @override
  String codeValueLabel(Object code) {
    return 'الرمز: $code';
  }

  @override
  String idValueLabel(Object id) {
    return 'المعرّف: $id';
  }

  @override
  String assignProductToWarehouse(Object name) {
    return 'تعيين $name إلى مستودع';
  }

  @override
  String deleteQuotedConfirm(Object name) {
    return 'حذف «$name»؟';
  }

  @override
  String deletePlainConfirm(Object name) {
    return 'حذف $name؟';
  }

  @override
  String removeDiscardConfirm(Object name) {
    return 'إزالة «$name»؟ ستُفقد إعداداته.';
  }

  @override
  String removeQuotedConfirm(Object name) {
    return 'إزالة «$name»؟';
  }

  @override
  String typeValueLabel(Object type) {
    return 'النوع: $type';
  }

  @override
  String ofPagesLabel(Object total) {
    return 'من $total';
  }

  @override
  String fixedAmountSymLabel(Object sym) {
    return 'مبلغ ثابت ($sym)';
  }

  @override
  String couldNotReadSyncStatus(Object message) {
    return 'تعذّر قراءة حالة المزامنة: $message';
  }

  @override
  String uidValueLabel(Object uid, Object value) {
    return 'المعرّف: $uid | القيمة: $value';
  }

  @override
  String enterFieldHint(Object field) {
    return 'أدخل $field';
  }

  @override
  String get actionClear => 'مسح';

  @override
  String get noStockAssignedWarehouse => 'لا يوجد مخزون مخصص لهذا المستودع';

  @override
  String get noStockAssignedProduct => 'لا يوجد مخزون مخصص لهذا المنتج';

  @override
  String get orderSummary => 'ملخص الطلب';

  @override
  String get promotionLabel => 'عرض';

  @override
  String get subtotalInclTax => 'المجموع الفرعي (شامل الضريبة)';

  @override
  String get customerDiscountLabel => 'خصم العميل';

  @override
  String get cartDiscountLabel => 'خصم السلة';

  @override
  String get taxInclLabel => 'الضريبة (مشمولة)';

  @override
  String get itemDiscountLabel => 'خصم الصنف';

  @override
  String get itemDiscountsPlural => 'خصومات الأصناف';

  @override
  String get taxesLabel => 'الضرائب';

  @override
  String get pointsRedeemed => 'النقاط المستبدلة';

  @override
  String get subtotalLabel => 'المجموع الفرعي';

  @override
  String get applyDiscount => 'تطبيق الخصم';

  @override
  String get cartTab => 'السلة';

  @override
  String get itemTab => 'الصنف';

  @override
  String get selectItemFirst => 'يرجى اختيار صنف من السلة أولاً.';

  @override
  String get noItemSelected => 'لم يتم اختيار أي صنف!';

  @override
  String get selectedItemNotFound => 'الصنف المحدد غير موجود.';

  @override
  String get discountBelowCost => 'الخصم سيجعل السعر أقل من التكلفة.';

  @override
  String get discountNegativePrice => 'الخصم سيؤدي إلى سعر سالب.';

  @override
  String inclPrefix(Object name) {
    return 'شامل $name';
  }

  @override
  String get saveAndRestart => 'حفظ وإعادة التشغيل';

  @override
  String get resourceMode => 'نوع المورد';

  @override
  String get resourceModeHint => 'ما الذي يُخصَّص له موعد الحجز';

  @override
  String get defaultDuration => 'المدة الافتراضية';

  @override
  String get defaultDurationHint => 'مدة الموعد المعبّأة مسبقاً عند إضافة حجز';

  @override
  String get timeSnapping => 'محاذاة الوقت';

  @override
  String get timeSnappingHint => 'فاصل الشبكة عند اختيار أوقات البداية/النهاية';

  @override
  String get couldNotLoadCurrencies => 'تعذّر تحميل العملات';

  @override
  String get fontPreview => 'معاينة: نص تجريبي للخط';

  @override
  String get chooseTheme => 'اختر الثيم';

  @override
  String get posButtonsHint =>
      'اختر أزرار الإجراءات التي تظهر في الشاشة الرئيسية.';

  @override
  String get couldNotLoadTaxRates => 'تعذّر تحميل نسب الضرائب';

  @override
  String get noTaxRatesDefined =>
      'لم تُحدَّد أي نسب ضريبة بعد. أضِفها من نسب الضرائب.';

  @override
  String get taxDefaultRequiredTitle => 'اختر نسبة ضريبة افتراضية';

  @override
  String get taxDefaultRequiredBody =>
      'السعر شامل الضريبة يتطلّب نسبة ضريبة افتراضية. اختر واحدة على الأقل — ستُطبَّق على كل منتج جديد وتُقفَل في نقطة البيع.';

  @override
  String get taxDefaultRequiredNoRates =>
      'لم تُحدَّد أي نسب ضريبة بعد. أنشئ واحدة من نسب الضرائب قبل تفعيل هذا الخيار.';

  @override
  String get defaultTaxRateDisabledHint =>
      'فعِّل السعر شامل الضريبة أعلاه لتطبيق نسبة ضريبة افتراضية.';

  @override
  String get taxLockedBySetting =>
      'مضبوط في الإعدادات ← عام ← الضريبة. لا يمكن تغييره هنا.';

  @override
  String get taxLockedShort => 'مقفل';

  @override
  String get couldNotLoadWarehouses => 'تعذّر تحميل المستودعات';

  @override
  String get defaultWarehouseHint =>
      'يُستخدم للتحقق من توفّر المخزون في شاشة نقطة البيع.';

  @override
  String get waitingForScale => 'في انتظار إرسال الوزن من الميزان…';

  @override
  String get restoreDefaults => 'استعادة الإعدادات الافتراضية';

  @override
  String get sameMachineSecondMonitor => 'نفس الجهاز / شاشة ثانية';

  @override
  String get otherDeviceSameNetwork => 'جهاز آخر على نفس الشبكة';

  @override
  String get categoriesPrintedOnGroup =>
      'الفئات المطبوعة على مجموعة الطابعات هذه';

  @override
  String get noPrinterGroupsYet => 'لا توجد مجموعات طابعات بعد.';

  @override
  String get noKitchenDisplays => 'لم يتم إعداد أي شاشة مطبخ.';

  @override
  String get noGroupSelectedReceivesAll =>
      'لم يتم اختيار مجموعة ← يستقبل كل الأصناف.';

  @override
  String get openDatabaseLocation => 'فتح موقع قاعدة البيانات';

  @override
  String get setZeroToDisableBackups => 'اضبطه على 0 لإيقاف النسخ المجدولة';

  @override
  String get statusExpired => 'منتهٍ';

  @override
  String get statusInvalid => 'غير صالح';

  @override
  String get statusNotActivated => 'غير مُفعّل';

  @override
  String get onboardingWillShow =>
      'سيظهر الإعداد الأولي في المرة القادمة التي تفتح فيها التطبيق.';

  @override
  String get autoLabel => 'تلقائي';

  @override
  String get themeDimmed => 'خافت';

  @override
  String get themeNight => 'ليلي';

  @override
  String get themeGray => 'رمادي';

  @override
  String get themeHighContrast => 'تباين عالٍ';

  @override
  String get colorBlue => 'أزرق';

  @override
  String get colorGreen => 'أخضر';

  @override
  String get colorPink => 'وردي';

  @override
  String get colorPurple => 'بنفسجي';

  @override
  String get colorOrange => 'برتقالي';

  @override
  String get colorRed => 'أحمر';

  @override
  String get allFields => 'كل الحقول';

  @override
  String get signInOnlineAgain =>
      'ستحتاج إلى تسجيل الدخول عبر الإنترنت لاستخدام نقطة البيع مجدداً.';

  @override
  String get tablesLabel => 'الطاولات';

  @override
  String get bookingLabel => 'الحجز';

  @override
  String get posNameFullHint =>
      'اسم قصير وفريد لهذا الجهاز. يصبح بادئة كل رقم مستند (مثال: CAISSE1-200-000045)، حتى لا ينتج جهازان نفس الرقم. أحرف وأرقام فقط.';

  @override
  String get defaultTaxRateFullHint =>
      'تُطبَّق تلقائياً على المنتجات المضافة إلى السلة التي ليس لها ضريبة خاصة.';

  @override
  String get serialScaleWindowsOnly =>
      'الموازين التسلسلية مدعومة على ويندوز فقط. على هذا الجهاز، استخدم خيار تحليل الرمز الشريطي أعلاه مع ميزان يطبع الملصقات.';

  @override
  String get openCustomerDisplayFullHint =>
      'يفتح شاشة العميل بملء الشاشة على هذا الجهاز. مثالي لشاشة ثانية — اسحب النافذة واضغط F11.';

  @override
  String get printerGroupsHelp =>
      'جمّع فئات المنتجات في محطات (مثل المطبخ، البار). عيّن مجموعة لشاشة أدناه وستعرض تلك الشاشة أصناف تلك الفئات فقط.';

  @override
  String get receivesAllItems =>
      'يستقبل كل الأصناف. أنشئ مجموعات طابعات أعلاه للتوجيه حسب الفئة.';

  @override
  String get autoSyncFullHint =>
      'ارفع تغييراتك المحلية واجلب البيانات المحدّثة تلقائياً في الخلفية.';

  @override
  String get replayOnboardingHint =>
      'أعد تشغيل جولة الترحيب. ستظهر مجدداً في المرة القادمة التي تفتح فيها التطبيق على هذا الجهاز.';

  @override
  String pairingRequestSent(Object ip) {
    return 'تم إرسال طلب الإقران إلى $ip — يُفترض أن تتحوّل شاشة المطبخ إلى عرض المطبخ.';
  }

  @override
  String kdsTabletsHelp(Object port) {
    return 'يستمع كل جهاز شاشة مطبخ على المنفذ $port. إضافة عنوانه تقرنه بنقطة البيع وترسل الطلبات عبر الشبكة المحلية — تعمل الشاشة دون اتصال بالإنترنت.';
  }

  @override
  String get statusActive => 'نشط';

  @override
  String get statusEnabled => 'مُفعّل';

  @override
  String get statusDisabled => 'معطّل';

  @override
  String get statusOn => 'مُشغّل';

  @override
  String get statusOff => 'متوقف';

  @override
  String expiresInDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ينتهي خلال $count يوم',
      many: 'ينتهي خلال $count يوماً',
      few: 'ينتهي خلال $count أيام',
      two: 'ينتهي خلال يومين',
      one: 'ينتهي خلال يوم',
      zero: 'ينتهي اليوم',
    );
    return '$_temp0';
  }

  @override
  String deviceCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جهاز',
      many: '$count جهازاً',
      few: '$count أجهزة',
      two: 'جهازان',
      one: 'جهاز واحد',
      zero: 'لا أجهزة',
    );
    return '$_temp0';
  }

  @override
  String get scaleBarcodePriceHint =>
      'عند التفعيل، القيمة المشفّرة سعر وتُحسب الكمية كالسعر ÷ سعر الوحدة';

  @override
  String get webDisplayHint =>
      'استضف شاشة طلب تفاعلية يمكن الوصول إليها من أي متصفح على شبكتك';

  @override
  String savedFieldFailed(Object field) {
    return 'فشل حفظ $field';
  }

  @override
  String prefixColonValue(Object prefix) {
    return 'البادئة: $prefix';
  }

  @override
  String unlinkEmailWarning(Object email) {
    return 'سيؤدي هذا إلى إلغاء ربط $email بهذا الجهاز. ستحتاج إلى تسجيل الدخول عبر الإنترنت لاستخدام نقطة البيع مجدداً.';
  }

  @override
  String get unlinkTerminalWarning =>
      'سيؤدي هذا إلى إلغاء ربط هذا الجهاز. ستحتاج إلى تسجيل الدخول عبر الإنترنت لاستخدام نقطة البيع مجدداً.';

  @override
  String get builtInBadge => 'مدمج';

  @override
  String get printerType => 'نوع الطابعة';

  @override
  String get paperSize => 'حجم الورق';

  @override
  String get copiesPerTransaction => 'عدد النسخ لكل عملية';

  @override
  String get headerPrintedTopHint => 'يُطبع في أعلى كل إيصال';

  @override
  String get footerThankYouHint => 'مثال: شكراً لتسوقكم معنا!';

  @override
  String get generalLabel => 'عام';

  @override
  String get categoryLabel => 'الفئة';

  @override
  String get chooseCustomerDetailsHint =>
      'اختر تفاصيل العميل التي تُطبع على الإيصال.';

  @override
  String get addressFormatFullHint =>
      'حدّد كيفية طباعة أسطر العنوان على الإيصالات والفواتير.';

  @override
  String get tapPlaceholderHint => 'انقر على عنصر نائب لإدراجه:';

  @override
  String get invoiceTitleHint => 'مثال: فاتورة ضريبية';

  @override
  String get invoiceHeaderHint => 'يُطبع أعلى الفاتورة';

  @override
  String get invoiceFooterHint => 'مثال: تفاصيل البنك، الشروط';

  @override
  String get addPrinterHint =>
      'أضف طابعة لكل محطة، ثم افتح إعداداتها لضبط حجم الورق والهوامش والترويسة/التذييل ودرج النقود.';

  @override
  String get kitchenFireFullHint =>
      'تشغيل هذه الطابعة عند الضغط على زر المطبخ. عند تفعيل عدة طابعات، تحدّد الفئة أدناه ما تطبعه كل واحدة.';

  @override
  String get categoryFilterHint =>
      'تطبع هذه الطابعة فقط المنتجات التي تنتمي فئتها إلى المجموعة المحددة (مثل البار ← المشروبات). اختر «كل المنتجات» لطباعة التذكرة كاملة هنا.';

  @override
  String get noPrinterGroupsDefined =>
      'لم تُحدَّد مجموعات طابعات بعد. أنشئها من الإعدادات ← شاشة العميل ← مجموعات الطابعات.';

  @override
  String get headerDetailsFullHint =>
      'التفاصيل المطبوعة أسفل الشعار / اسم النشاط في أعلى الإيصال. تُضبط نصوص الترويسة والتذييل لكل طابعة (⚙ ← عام).';

  @override
  String get sessionExpiredMsg => 'انتهت جلستك. يرجى تسجيل الدخول مجدداً.';

  @override
  String get enterPin => 'أدخل الرمز';

  @override
  String get syncingMasterData => 'جارٍ مزامنة البيانات الرئيسية…';

  @override
  String get confirmNewPin => 'تأكيد الرمز الجديد';

  @override
  String get createFourDigitPin => 'أنشئ رمزاً من 4 أرقام';

  @override
  String get companyName => 'اسم الشركة';

  @override
  String get taxNumberLabel => 'الرقم الضريبي';

  @override
  String get emailAddress => 'البريد الإلكتروني';

  @override
  String get streetName => 'اسم الشارع';

  @override
  String get buildingNo => 'رقم المبنى';

  @override
  String get additionalStreet => 'شارع إضافي';

  @override
  String get plotId => 'معرّف القطعة';

  @override
  String get districtSubdivision => 'الحي / التقسيم';

  @override
  String get postalCode => 'الرمز البريدي';

  @override
  String get cityLabel => 'المدينة';

  @override
  String get stateProvince => 'الولاية / المحافظة';

  @override
  String get bankAccountNumber => 'رقم الحساب البنكي';

  @override
  String get bankDetails => 'التفاصيل البنكية (IBAN، SWIFT، إلخ)';

  @override
  String get rateLabel => 'النسبة';

  @override
  String get taxOnTotal => 'ضريبة على الإجمالي';

  @override
  String get noTaxRatesFound => 'لم يتم العثور على نسب ضريبة.';

  @override
  String get editVoidReason => 'تعديل سبب الإلغاء';

  @override
  String get addVoidReason => 'إضافة سبب إلغاء';

  @override
  String get addReason => 'إضافة سبب';

  @override
  String get totalDue => 'الإجمالي المستحق';

  @override
  String get replaceTaxesHint =>
      'استخدم هذا النموذج لاستبدال الضرائب لكل المنتجات. اختر الضريبة القديمة التي تريد استبدالها بالجديدة ثم انقر استبدال.';

  @override
  String errorLoadingTaxesMsg(Object message) {
    return 'خطأ في تحميل الضرائب: $message';
  }

  @override
  String get orderTypeLabel => 'نوع الطلب';

  @override
  String get noServiceStatuses => 'لم يتم إعداد حالات خدمة.';

  @override
  String get quantityCannotBeNegative => 'لا يمكن أن تكون الكمية سالبة.';

  @override
  String get cannotCalcQuantity => 'تعذّر حساب الكمية: سعر الوحدة صفر.';

  @override
  String get parsedQuantityZero =>
      'الكمية المقروءة صفر — تحقّق من إعداد رمز الميزان.';

  @override
  String get selectTableFirst => 'يرجى اختيار طاولة أولاً!';

  @override
  String get notAvailableOtherWarehouse =>
      'هذا المنتج غير متوفر في أي مستودع آخر.';

  @override
  String get selectTableFromFloorPlan =>
      'يرجى اختيار طاولة من مخطط القاعة أولاً!';

  @override
  String get cartIsEmpty => 'السلة فارغة';

  @override
  String get totalPromotionalDiscount => 'إجمالي الخصم الترويجي';

  @override
  String get calendarBookingUpdated => 'سيتم تحديث حجز التقويم تلقائياً.';

  @override
  String get confirmTransfer => 'تأكيد التحويل';

  @override
  String get setAbout => 'حول';

  @override
  String get setAccentColor => 'لون التمييز';

  @override
  String get setAddPrinterGroup => 'إضافة مجموعة طابعات';

  @override
  String get setAddress => 'العنوان';

  @override
  String get setAdvancedSettings => 'الإعدادات المتقدمة';

  @override
  String get setTaxInclusiveDefaultHint =>
      'ستكون أسعار كل المنتجات الجديدة شاملة الضريبة';

  @override
  String get setAllowNegativePrice => 'السماح بسعر سالب';

  @override
  String get setAllowTablelessOrders => 'السماح بطلبات بدون طاولة';

  @override
  String get setAllowWalkInTableOrders => 'السماح بطلبات الطاولات بدون حجز';

  @override
  String get setApi => 'واجهة برمجة التطبيقات';

  @override
  String get setApiBaseUrl => 'رابط الـ API الأساسي';

  @override
  String get setAppearance => 'المظهر';

  @override
  String get setApplicationStyle => 'نمط التطبيق';

  @override
  String get setAutoBackup => 'النسخ الاحتياطي التلقائي';

  @override
  String get setAutoSync => 'المزامنة التلقائية';

  @override
  String get setAutomaticBackups => 'النسخ الاحتياطي التلقائي';

  @override
  String get setAutoUpdateCostPrice => 'تحديث سعر التكلفة تلقائياً عند الشراء';

  @override
  String get setBackUpEvery => 'النسخ الاحتياطي التلقائي كل';

  @override
  String get setBackupOnClose => 'نسخ قاعدة البيانات عند إغلاق التطبيق';

  @override
  String get setBackupOnStart => 'نسخ قاعدة البيانات عند بدء التطبيق';

  @override
  String get setBackupLocation => 'مسار النسخ الاحتياطي';

  @override
  String get setBarcodeParsing => 'تحليل الرموز الشريطية';

  @override
  String get setBaudRate => 'معدل الباود';

  @override
  String get setBitsPerSecond => 'بت في الثانية';

  @override
  String get setBooking => 'الحجز';

  @override
  String get setBookingSettings => 'إعدادات الحجز';

  @override
  String get setBookingsButton => 'زر الحجوزات';

  @override
  String get setBottomLine => 'السطر السفلي';

  @override
  String get setBusinessDay => 'يوم العمل';

  @override
  String get setCashDrawer => 'درج النقود';

  @override
  String get setCashDrawerButton => 'زر درج النقود';

  @override
  String get setChangeQuantity => 'تغيير الكمية';

  @override
  String get setChangeQuantityButton => 'زر تغيير الكمية';

  @override
  String get setColor => 'اللون';

  @override
  String get setComPort => 'منفذ COM';

  @override
  String get setCommentButton => 'زر الملاحظة';

  @override
  String get setCompany => 'الشركة';

  @override
  String get setCopyLanUrl => 'نسخ رابط الشبكة المحلية';

  @override
  String get setCostPriceMarkup => 'هامش الربح على أساس التكلفة';

  @override
  String get setCurrency => 'العملة';

  @override
  String get setCustomerButton => 'زر العميل';

  @override
  String get setCustomerDisplay => 'شاشة العميل';

  @override
  String get setCustomerDisplayEnabled => 'شاشة العميل مُفعّلة';

  @override
  String get setDataBits => 'بتات البيانات';

  @override
  String get setDatabase => 'قاعدة البيانات';

  @override
  String get setDatabaseBackup => 'قاعدة البيانات والنسخ الاحتياطي';

  @override
  String get setDbSize => 'حجم قاعدة البيانات';

  @override
  String get setDefaultBarcodeFormat => 'تنسيق الرمز الشريطي الافتراضي';

  @override
  String get setDefaultDiscountType => 'نوع الخصم الافتراضي';

  @override
  String get setDefaultDueDays => 'تاريخ الاستحقاق الافتراضي (أيام)';

  @override
  String get setDefaultMeasurementUnit => 'وحدة القياس الافتراضية';

  @override
  String get setDefaultScreen => 'الشاشة الافتراضية';

  @override
  String get setDefaultSearch => 'وضع البحث الافتراضي';

  @override
  String get setDefaultServiceType => 'نوع الخدمة الافتراضي';

  @override
  String get setDefaultTaxRate => 'نسبة الضريبة الافتراضية';

  @override
  String get setDefaultWarehouse => 'المستودع الافتراضي';

  @override
  String get setDeleteBackupsOlderThan => 'حذف النسخ الأقدم من';

  @override
  String get setDeleteOldBackups => 'حذف النسخ القديمة تلقائياً';

  @override
  String get setDeleteServiceStatus => 'حذف حالة الخدمة';

  @override
  String get setDeleteServiceType => 'حذف نوع الخدمة';

  @override
  String get setDevice => 'الجهاز';

  @override
  String get setDeviceName => 'اسم الجهاز';

  @override
  String get setDevices => 'الأجهزة';

  @override
  String get setDiscountApplyRule => 'قاعدة تطبيق الخصم';

  @override
  String get setDiscountButton => 'زر الخصم';

  @override
  String get setSyncToast => 'إظهار إشعار عند اكتمال كل مزامنة';

  @override
  String get setDisplayMessages => 'رسائل الشاشة';

  @override
  String get setDisplayPrintTaxIncluded => 'عرض وطباعة الأصناف شاملة الضريبة';

  @override
  String get setDualCurrencyHint =>
      'عرض الأسعار والمجاميع بعملة ثانية في الوقت نفسه';

  @override
  String get setShowPrintDialog => 'إظهار مربع حوار طباعة الإيصال';

  @override
  String get setDualCurrency => 'العملة المزدوجة';

  @override
  String get setDualCurrencyEnabled => 'العملة المزدوجة مُفعّلة';

  @override
  String get setEnableAutomaticBackups => 'تفعيل النسخ الاحتياطي التلقائي';

  @override
  String get setEnableAutoSync => 'تفعيل المزامنة التلقائية';

  @override
  String get setEnableBookings => 'تفعيل الحجوزات / التقويم';

  @override
  String get setEnableFloorPlan => 'تفعيل مخطط القاعة / الطاولات';

  @override
  String get setEnableLiveWebDisplay => 'تفعيل شاشة العميل عبر الويب';

  @override
  String get setEnableMovingAverage => 'تفعيل متوسط السعر المتحرك';

  @override
  String get setEnableVirtualKeyboard => 'تفعيل لوحة المفاتيح الافتراضية';

  @override
  String get setEnableScaleBarcode => 'تفعيل رمز ميزان الوزن';

  @override
  String get setExchangeRate => 'سعر الصرف';

  @override
  String get setFeatures => 'الميزات';

  @override
  String get setFirstTwoDigits => 'أول رقمين / البادئة';

  @override
  String get setFlowControl => 'التحكم في التدفق';

  @override
  String get setFontSize => 'حجم الخط';

  @override
  String get setFromEmailAddress => 'عنوان البريد المُرسِل';

  @override
  String get setFromName => 'اسم المُرسِل';

  @override
  String get setGeneral => 'عام';

  @override
  String get setIanaTimezone => 'المنطقة الزمنية IANA';

  @override
  String get setInventory => 'المخزون';

  @override
  String get setItems => 'الأصناف';

  @override
  String get setKdsIp => 'عنوان IP لشاشة المطبخ';

  @override
  String get setKitchenDisplay => 'شاشة المطبخ';

  @override
  String get setKdsTablets => 'أجهزة شاشة المطبخ';

  @override
  String get setLastSync => 'آخر مزامنة';

  @override
  String get setLayout => 'التخطيط';

  @override
  String get setLoadingCurrencies => 'جارٍ تحميل العملات…';

  @override
  String get setMenuGrid => 'شبكة القائمة';

  @override
  String get setMenuGridColumns => 'أعمدة شبكة القائمة';

  @override
  String get setMenuGridRows => 'صفوف شبكة القائمة';

  @override
  String get setMenuLayout => 'تخطيط القائمة (قائمة / شبكة)';

  @override
  String get setMergeItemsOnReceipt => 'دمج الأصناف في الإيصال';

  @override
  String get setMessageDuration => 'مدة الرسالة (ثوانٍ)';

  @override
  String get setMessagePosition => 'موضع الرسالة';

  @override
  String get setMessages => 'الرسائل (الإشعارات)';

  @override
  String get setMovingAveragePrice => 'متوسط السعر المتحرك';

  @override
  String get setNumberOfCharacters => 'عدد الأحرف';

  @override
  String get setNumberOfDecimals => 'عدد المنازل العشرية';

  @override
  String get setProductCodeDigits => 'عدد أرقام رمز المنتج';

  @override
  String get setPaymentTypeRows => 'عدد صفوف أنواع الدفع';

  @override
  String get setOnboarding => 'الإعداد الأولي';

  @override
  String get setOpen => 'فتح';

  @override
  String get setOpenCustomerDisplay => 'فتح شاشة العميل';

  @override
  String get setOpenInBrowser => 'فتح في المتصفح (اسحب إلى الشاشة الثانية)';

  @override
  String get setOpenOnThisDevice => 'الفتح على هذا الجهاز';

  @override
  String get setOrderAndPayment => 'الطلب والدفع';

  @override
  String get setOrderNumberPrefix => 'بادئة رقم الطلب';

  @override
  String get setParity => 'التماثل';

  @override
  String get setScaleBarcodeHint => 'قراءة الوزن/السعر من رموز الميزان';

  @override
  String get setPayment => 'الدفع';

  @override
  String get setPhone => 'الهاتف';

  @override
  String get setPosButtonBar => 'شريط أزرار نقطة البيع';

  @override
  String get setPosNameHint => 'اسم نقطة البيع — بادئة أرقام المستندات';

  @override
  String get setPreventNegativeInventory => 'منع المخزون السالب';

  @override
  String get setPreventSaleBelowCost => 'منع البيع بأقل من التكلفة';

  @override
  String get setPrint => 'طباعة';

  @override
  String get setPrintLargeOrderNumber => 'طباعة رقم الطلب بحجم كبير';

  @override
  String get setPrinterReceiptSettings => 'إعدادات الطابعة والإيصال';

  @override
  String get setPrinterGroups => 'مجموعات الطابعات';

  @override
  String get setProductDefaults => 'القيم الافتراضية للمنتجات';

  @override
  String get setReadLiveWeight => 'قراءة الوزن مباشرة من ميزان تسلسلي';

  @override
  String get setRefundButton => 'زر الاسترجاع';

  @override
  String get setRegional => 'الإعدادات الإقليمية';

  @override
  String get setRegisteredAccount => 'الحساب المسجّل';

  @override
  String get setRenewsEnds => 'التجديد / الانتهاء';

  @override
  String get setRepair => 'إعادة الإقران';

  @override
  String get setReplay => 'إعادة التشغيل';

  @override
  String get setRequestServiceTypeAuto => 'طلب نوع الخدمة تلقائياً';

  @override
  String get setRequireReasonOnVoid => 'طلب سبب عند الإلغاء';

  @override
  String get setRequiresFloorPlan => 'يتطلب تفعيل مخطط القاعة / الطاولات';

  @override
  String get setRescanPorts => 'إعادة فحص المنافذ';

  @override
  String get setResetOrderNumber => 'إعادة تعيين رقم الطلب عند إغلاق اليوم';

  @override
  String get setWalkInHint => 'تسجيل طلب داخل المحل بدون اختيار طاولة';

  @override
  String get setRoom => 'غرفة';

  @override
  String get setRows => 'الصفوف';

  @override
  String get setScalePrintsPrice => 'الميزان يطبع السعر بدل الكمية';

  @override
  String get setScreenDisplayWeb => 'عرض الشاشة (ويب)';

  @override
  String get setSearchAllSettings => 'ابحث في كل الإعدادات...';

  @override
  String get setSearchButton => 'زر البحث';

  @override
  String get setSecondaryCurrencySymbol => 'رمز العملة الثانوية';

  @override
  String get setSelectBusinessDayOnStart => 'اختيار يوم العمل عند بدء التطبيق';

  @override
  String get setSelectEllipsis => 'اختر…';

  @override
  String get setSendToKitchen => 'إرسال إلى المطبخ';

  @override
  String get setSendToKitchenButton => 'زر الإرسال إلى المطبخ';

  @override
  String get setSender => 'المُرسِل';

  @override
  String get setSeparateRowPerItem => 'سطر منفصل لكل صنف';

  @override
  String get setSerialConnection => 'الاتصال التسلسلي';

  @override
  String get setServiceStatusSelector => 'محدّد حالة الخدمة';

  @override
  String get setServiceStatuses => 'حالات الخدمة';

  @override
  String get setServiceTypeHeader => 'نوع الخدمة';

  @override
  String get setServiceTypeSelector => 'محدّد نوع الخدمة';

  @override
  String get setServiceTypes => 'أنواع الخدمة';

  @override
  String get setShowAllOccupied => 'إظهار كل الطاولات المشغولة في المخطط';

  @override
  String get setShowCashInOnStart => 'إظهار النقد الافتتاحي عند بدء التطبيق';

  @override
  String get setShowItemsOnPaymentForm => 'إظهار الأصناف في نموذج الدفع';

  @override
  String get setShowOrderTotalOnPole => 'إظهار إجمالي الطلب على شاشة VFD / LCD';

  @override
  String get setShowOrderTypeButtons => 'إظهار أزرار نوع الطلب في نقطة البيع';

  @override
  String get setShowProductImages => 'إظهار صور المنتجات في شبكة نقطة البيع';

  @override
  String get setShowSearchOptions => 'إظهار أزرار وضع البحث';

  @override
  String get setShowServiceStatusBadge => 'إظهار شارة حالة الخدمة على البطاقات';

  @override
  String get setShowSyncNotification => 'إظهار إشعار المزامنة';

  @override
  String get setShowTablesButton => 'إظهار زر الطاولات في نقطة البيع';

  @override
  String get setSignOut => 'تسجيل الخروج';

  @override
  String get setSignOutDevice => 'تسجيل خروج الجهاز';

  @override
  String get setSingleItemDiscount => 'السماح بخصم على صنف واحد';

  @override
  String get setSingleUser => 'مستخدم واحد';

  @override
  String get setSmtpHost => 'خادم SMTP';

  @override
  String get setSmtpPort => 'منفذ SMTP';

  @override
  String get setSmtpServer => 'خادم SMTP';

  @override
  String get setSorting => 'الترتيب';

  @override
  String get setStaff => 'الموظفون';

  @override
  String get setStartOrderFreeTable => 'بدء طلب على طاولة فارغة بدون حجز';

  @override
  String get setStarted => 'بدأ';

  @override
  String get setStartup => 'بدء التشغيل';

  @override
  String get setStopBits => 'بتات التوقف';

  @override
  String get setScaleStreamHint =>
      'ينقل الوزن من ميزان على منفذ COM إلى لوحة الكمية';

  @override
  String get setStripLeadingZeros =>
      'إزالة الأصفار البادئة قبل البحث عن المنتج';

  @override
  String get setSubscription => 'الاشتراك';

  @override
  String get setSystemInfo => 'معلومات النظام';

  @override
  String get setTable => 'طاولة';

  @override
  String get setTablesFloorPlan => 'الطاولات / مخطط القاعة';

  @override
  String get setTablesFloorPlanButton => 'زر الطاولات / مخطط القاعة';

  @override
  String get setTablesButtonLabel => 'تسمية زر الطاولات';

  @override
  String get setTaxHeader => 'الضريبة';

  @override
  String get setTaxButton => 'زر الضريبة';

  @override
  String get setTaxIncludedByDefault => 'الضريبة مشمولة في السعر افتراضياً';

  @override
  String get setTaxNo => 'الرقم الضريبي';

  @override
  String get setTestDisplay => 'اختبار العرض';

  @override
  String get setThankYouMessage => 'رسالة الشكر (بعد الدفع)';

  @override
  String get setThemeMode => 'وضع الثيم';

  @override
  String get setTimezone => 'المنطقة الزمنية';

  @override
  String get setTopLine => 'السطر العلوي';

  @override
  String get setTrackUnconfirmedVoids => 'تتبع الأصناف الملغاة غير المؤكدة';

  @override
  String get setTransferButton => 'زر التحويل';

  @override
  String get setUpdateSalePriceFromMarkup => 'تحديث سعر البيع حسب هامش الربح';

  @override
  String get setUsers => 'المستخدمون';

  @override
  String get setVoidItems => 'الأصناف الملغاة';

  @override
  String get setWarehouseSwitcher => 'مبدّل المستودعات';

  @override
  String get setWarehouseSwitcherButton => 'زر مبدّل المستودعات';

  @override
  String get setWeighingScale => 'ميزان';

  @override
  String get setWelcomeMessage => 'رسالة الترحيب';

  @override
  String get setWelcomeMessageLabel => 'رسالة الترحيب (شاشة الانتظار)';

  @override
  String get setWelcomeBottomLine => 'السطر السفلي لرسالة الترحيب';

  @override
  String get setWelcomeTopLine => 'السطر العلوي لرسالة الترحيب';

  @override
  String get setWhenToSync => 'متى تتم المزامنة';

  @override
  String get setWritingDirection => 'اتجاه الكتابة';

  @override
  String get setHintCaisse => 'مثال: CAISSE1';

  @override
  String get setHintUber => 'مثال: UBER';

  @override
  String get setHintUberEats => 'مثال: Uber Eats';

  @override
  String get setHintWaiting => 'مثال: قيد الانتظار';

  @override
  String get selectExportType => 'اختر نوع التصدير';

  @override
  String get exportCsv => 'CSV (إكسل)';

  @override
  String get exportXml => 'XML';

  @override
  String get deleteProducts => 'حذف المنتجات';

  @override
  String get showHideColumns => 'إظهار / إخفاء الأعمدة';

  @override
  String get alwaysShown => 'ظاهر دائماً';

  @override
  String get actionReset => 'إعادة تعيين';

  @override
  String get products => 'المنتجات';

  @override
  String get columns => 'الأعمدة';

  @override
  String get importLabel => 'استيراد';

  @override
  String get exportLabel => 'تصدير';

  @override
  String get addProduct => 'إضافة منتج';

  @override
  String get categoriesHeader => 'الفئات';

  @override
  String get errorLoadingGroups => 'خطأ في تحميل الفئات';

  @override
  String get allProducts => 'كل المنتجات';

  @override
  String get noProductsFound => 'لم يتم العثور على منتجات.';

  @override
  String noProductsMatchSearch(String query) {
    return 'لا يوجد منتج يطابق \"$query\".';
  }

  @override
  String get productNameRequired => 'اسم المنتج *';

  @override
  String get categoryGroup => 'الفئة / المجموعة';

  @override
  String get noneUncategorized => 'بدون (غير مصنّف)';

  @override
  String get productCodeSku => 'رمز المنتج / SKU';

  @override
  String get plu => 'PLU';

  @override
  String get measurementUnit => 'وحدة القياس';

  @override
  String get measurementUnitHint => 'مثال: كجم، قطعة';

  @override
  String get sellByWeight => 'البيع بالوزن';

  @override
  String get sellByWeightHint =>
      'عند التفعيل، تطلب نقطة البيع كمية بدل إضافة وحدة واحدة. وإذا لم يكن هناك ميزان متصل، فإن زر «السعر» يعدّل الكمية.';

  @override
  String get uomStockUnit => 'وحدة المخزون';

  @override
  String get uomCategoryUnit => 'وحدة';

  @override
  String get uomCategoryWeight => 'وزن';

  @override
  String get uomCategoryVolume => 'حجم';

  @override
  String get uomCategoryLength => 'طول';

  @override
  String uomStockHeldIn(String unit) {
    return 'يُحسب المخزون بـ $unit.';
  }

  @override
  String uomStockConversionNote(String unit, String factor, String stockUnit) {
    return 'السعر لكل $unit. المخزون يتحرك بـ $stockUnit — 1 $unit = $factor $stockUnit.';
  }

  @override
  String get weighItem => 'وزن الصنف';

  @override
  String get placeOnScale => 'ضع الصنف على الميزان';

  @override
  String get scaleNotConnected => 'لا يوجد ميزان متصل — أدخل الكمية';

  @override
  String get useThisWeight => 'استخدام هذا الوزن';

  @override
  String get enterQuantity => 'أدخل الكمية';

  @override
  String get priceEditsQuantity => 'السعر يعدّل الكمية';

  @override
  String get barcodeRules => 'قواعد الباركود';

  @override
  String barcodeRulesHint(Object NNDD) {
    return 'تحدد قواعد الباركود كيفية قراءة الباركود الممسوح. يُطابَق الباركود مع أول قاعدة يناسبها النمط، لذا فإن الترتيب مهم. يمكن للنمط أن يتضمن قيمة مثل الوزن أو السعر: $NNDD تحدد مواضع الأرقام، ومواضع D هي خانات عشرية. المنتج الذي يحمل باركوده قيمة مضمّنة يجب أن يخزّن تلك المواضع أصفارًا.';
  }

  @override
  String get ruleName => 'اسم القاعدة';

  @override
  String get ruleType => 'النوع';

  @override
  String get ruleEncoding => 'الترميز';

  @override
  String get rulePattern => 'نمط الباركود';

  @override
  String get ruleTypeUnit => 'منتج بالوحدة';

  @override
  String get ruleTypeWeighted => 'منتج بالوزن';

  @override
  String get ruleTypePriced => 'منتج بالسعر';

  @override
  String get ruleTypeDiscounted => 'منتج بخصم';

  @override
  String get addRuleLine => 'إضافة سطر';

  @override
  String get barcodeRulesSaved => 'تم حفظ قواعد الباركود';

  @override
  String get testBarcode => 'اختبار باركود';

  @override
  String get testBarcodeNoMatch => 'لا توجد قاعدة تطابق هذا الباركود';

  @override
  String testBarcodeMatched(String rule, String value) {
    return 'القاعدة $rule — القيمة $value';
  }

  @override
  String get weightNotAllowedForService => 'لا يمكن بيع الخدمة بالوزن.';

  @override
  String get scaleReadFailed => 'تعذّرت قراءة الميزان';

  @override
  String get ageRestrictionHint => 'مثال: 18';

  @override
  String get sellingPriceRequired => 'سعر البيع *';

  @override
  String get purchaseCost => 'سعر الشراء';

  @override
  String get marginMarkup => 'الهامش / نسبة الربح (%)';

  @override
  String get rankDisplayOrder => 'الترتيب (ترتيب العرض)';

  @override
  String get description => 'الوصف';

  @override
  String get priceIsTaxInclusive => 'سعر المنتج شامل الضريبة';

  @override
  String get isServiceNotPhysical => 'خدمة (غير مادي)';

  @override
  String get changePriceAllowed => 'يسمح بتغيير السعر';

  @override
  String get isEnabledVisible => 'مُفعّل (ظاهر)';

  @override
  String get productColorMarker => 'علامة لون المنتج';

  @override
  String get productImage => 'صورة المنتج';

  @override
  String get productImageHint =>
      'تحل محل الأيقونة الافتراضية في شاشة نقطة البيع.';

  @override
  String get removeImage => 'إزالة الصورة';

  @override
  String get taxInclusiveNotAppliedNote =>
      'تنبيه: لا تزال نقطة البيع تضيف هذه الضريبة فوق السعر. السعر الشامل للضريبة مخزَّن على المنتج لكنه غير مطبَّق عند الدفع بعد.';

  @override
  String get pricingTab => 'التسعير';

  @override
  String taxBreakdownIncluded(String price, String tax, String net) {
    return '$price يشمل $tax ضريبة · الصافي $net';
  }

  @override
  String taxBreakdownAdded(String price, String tax, String total) {
    return '$price + $tax ضريبة = $total';
  }

  @override
  String get applyTaxes => 'تطبيق الضرائب';

  @override
  String get failedToLoadTaxes => 'فشل تحميل الضرائب';

  @override
  String get primaryTaxRate => 'نسبة الضريبة الأساسية';

  @override
  String get noTax => 'بدون ضريبة';

  @override
  String get productModifiersComments => 'إضافات وملاحظات المنتج';

  @override
  String get newModifierComment => 'إضافة / ملاحظة جديدة';

  @override
  String get newModifierHint => 'مثال: بدون بصل';

  @override
  String get noCommentsYet => 'لم تتم إضافة أي ملاحظات.';

  @override
  String get deleteComment => 'حذف الملاحظة';

  @override
  String get productBarcodes => 'الرموز الشريطية للمنتج';

  @override
  String get barcode => 'الرمز الشريطي';

  @override
  String get generateBarcode => 'توليد رمز شريطي';

  @override
  String get noBarcodesYet => 'لم يتم تعيين أي رمز شريطي.';

  @override
  String get pendingSync => 'بانتظار المزامنة';

  @override
  String get deleteBarcode => 'حذف الرمز الشريطي';

  @override
  String get transactionBlocked => 'تم حظر العملية';

  @override
  String get actionOk => 'موافق';

  @override
  String get transactionSuccessful => 'تمت العملية بنجاح';

  @override
  String get printReceiptPrompt => 'هل تريد طباعة إيصال؟';

  @override
  String get saveAsPdf => 'حفظ كملف PDF';

  @override
  String get printReceipt => 'طباعة الإيصال';

  @override
  String get splitPayments => 'تقسيم الدفع';

  @override
  String get totalLabel => 'الإجمالي';

  @override
  String get paidLabel => 'المدفوع';

  @override
  String get remainingLabel => 'المتبقي';

  @override
  String get changeLabel => 'الباقي';

  @override
  String get removeCustomer => 'إزالة العميل';

  @override
  String get redeemPoints => 'استبدال النقاط';

  @override
  String get pointsToUse => 'النقاط المستخدمة';

  @override
  String get decrementOnePoint => '-1 نقطة';

  @override
  String get incrementOnePoint => '+1 نقطة';

  @override
  String useMaxPoints(String points) {
    return 'استخدام الحد الأقصى ($points نقطة)';
  }

  @override
  String get actionRedeem => 'استبدال';

  @override
  String get paymentTypes => 'أنواع الدفع';

  @override
  String get showNavigation => 'إظهار التنقل';

  @override
  String get visibleColumns => 'الأعمدة الظاهرة';

  @override
  String get columnsTooltip => 'الأعمدة';

  @override
  String get refreshTooltip => 'تحديث';

  @override
  String get newPaymentType => 'نوع دفع جديد';

  @override
  String errorLoadingPaymentTypes(String message) {
    return 'خطأ في تحميل أنواع الدفع: $message';
  }

  @override
  String get noCompanySelectedShort => 'لم يتم اختيار شركة.';

  @override
  String get noPaymentTypesFound => 'لا توجد أنواع دفع.';

  @override
  String get addFirstPaymentType => 'أضف أول نوع دفع';

  @override
  String deletePaymentTypeConfirm(String name) {
    return 'هل تريد حذف نوع الدفع «$name»؟';
  }

  @override
  String get fieldNameRequired => 'الاسم *';

  @override
  String get codeRequired => 'الرمز *';

  @override
  String get taxCodeAlreadyUsed => 'مستخدم بالفعل في ضريبة أخرى';

  @override
  String get fieldCode => 'الرمز';

  @override
  String get fieldPosition => 'الترتيب';

  @override
  String get fieldShortcut => 'الاختصار';

  @override
  String get actionUpdate => 'تحديث';

  @override
  String errorWithMessage(String message) {
    return 'خطأ: $message';
  }

  @override
  String get activePromotions => 'العروض النشطة';

  @override
  String get noActivePromotions => 'لا توجد عروض نشطة حالياً.';

  @override
  String ordersReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طلب جاهز',
      many: '$count طلباً جاهزاً',
      few: '$count طلبات جاهزة',
      two: 'طلبان جاهزان',
      one: 'طلب واحد جاهز',
      zero: 'لا توجد طلبات جاهزة',
    );
    return '$_temp0';
  }

  @override
  String get selectOrderType => 'اختر نوع الطلب';

  @override
  String get serviceStatus => 'حالة الخدمة';

  @override
  String get selectServiceStatus => 'اختر حالة الخدمة';

  @override
  String get posDiscount => 'خصم';

  @override
  String get posQuantity => 'الكمية';

  @override
  String get posTax => 'الضريبة';

  @override
  String get posComment => 'ملاحظة';

  @override
  String get posTransfer => 'تحويل';

  @override
  String get posRefund => 'استرجاع';

  @override
  String get posKitchen => 'المطبخ';

  @override
  String get posAddition => 'الحساب';

  @override
  String get setAdditionButton => 'زر الحساب';

  @override
  String get additionPrinted => 'تمت طباعة الحساب';

  @override
  String get posOrder => 'طلب';

  @override
  String get posBookings => 'الحجوزات';

  @override
  String get posPromos => 'العروض';

  @override
  String get posVoid => 'إلغاء';

  @override
  String get posPay => 'دفع';

  @override
  String productRunningLow(String product) {
    return 'مخزون $product على وشك النفاد';
  }

  @override
  String productOutOfStock(String product) {
    return '$product غير متوفر في المخزون';
  }

  @override
  String get availableIn => 'متوفر في:';

  @override
  String quantityInStock(String qty) {
    return '$qty في المخزون';
  }

  @override
  String get noCompanySelected =>
      'لم يتم اختيار شركة. افتح القائمة واختر شركة.';

  @override
  String get errorLoadingData => 'خطأ في تحميل البيانات';

  @override
  String get searchProductsHint => 'ابحث عن المنتجات...';

  @override
  String get paginationFirst => 'الأولى';

  @override
  String get paginationPrevious => 'السابقة';

  @override
  String get paginationNext => 'التالية';

  @override
  String get paginationLast => 'الأخيرة';

  @override
  String get voidOrder => 'إلغاء الطلب';

  @override
  String get voidOrderConfirm => 'هل تريد بالتأكيد إلغاء هذا الطلب؟';

  @override
  String get enterVoidReason => 'أدخل سبب الإلغاء هنا';

  @override
  String get refreshOrderNumber => 'تحديث رقم الطلب';

  @override
  String get setSalePrice => 'تعيين سعر البيع';

  @override
  String get fieldPrice => 'السعر';

  @override
  String get ageRestriction => 'قيد العمر';

  @override
  String confirmMinimumAge(String minAge) {
    return 'تأكيد ($minAge+)';
  }

  @override
  String commentsForProduct(String product) {
    return 'ملاحظات: $product';
  }

  @override
  String get customComment => 'ملاحظة مخصصة';

  @override
  String get addANoteHint => 'أضف ملاحظة...';

  @override
  String get noTaxesAvailable => 'لا توجد ضرائب متاحة في النظام.';

  @override
  String get transferOrder => 'تحويل الطلب';

  @override
  String get assignStaff => 'إسناد إلى موظف';

  @override
  String get unassigned => 'غير مُسند';

  @override
  String get assignRoomOrResource => 'إسناد غرفة / مورد';

  @override
  String get noRoom => 'بدون غرفة';

  @override
  String selectAvailableSpace(String space) {
    return 'اختر $space متاحة';
  }

  @override
  String get errorMissingCompanyContext =>
      'خطأ: بيانات الشركة أو المستخدم غير متوفرة.';

  @override
  String failedToQueueZReport(String message) {
    return 'تعذر إنشاء تقرير Z: $message';
  }

  @override
  String zReportNumber(String number) {
    return 'تقرير Z رقم $number';
  }

  @override
  String get shiftSummaryUpper => 'ملخص الوردية';

  @override
  String get dateTimeLabel => 'التاريخ / الوقت';

  @override
  String get rangeLabel => 'النطاق';

  @override
  String get totalSales => 'إجمالي المبيعات';

  @override
  String get totalReturns => 'إجمالي المرتجعات';

  @override
  String get discountsLabel => 'الخصومات';

  @override
  String get taxableTotal => 'الإجمالي الخاضع للضريبة';

  @override
  String get totalTax => 'إجمالي الضريبة';

  @override
  String get cashMovementsUpper => 'حركات الصندوق';

  @override
  String get tenderTypesUpper => 'طرق الدفع';

  @override
  String get noPaymentsRecorded => 'لا توجد مدفوعات مسجلة.';

  @override
  String get grandTotalUpper => 'المجموع الكلي';

  @override
  String get unknownLabel => 'غير معروف';

  @override
  String get currentShiftOpen => 'الوردية الحالية (مفتوحة)';

  @override
  String get historyZReports => 'السجل (تقارير Z)';

  @override
  String get noOpenTransactions => 'لا توجد معاملات مفتوحة.\nالصندوق متوازن.';

  @override
  String get tenderBreakdown => 'تفصيل وسائل الدفع';

  @override
  String get expectedInDrawer => 'المبلغ المتوقع في الدرج';

  @override
  String get shiftDetails => 'تفاصيل الوردية';

  @override
  String get cashierOnDuty => 'الكاشير المناوب';

  @override
  String get unknownUser => 'مستخدم غير معروف';

  @override
  String get transactionsLabel => 'المعاملات';

  @override
  String openPaymentsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دفعة مفتوحة',
      many: '$count دفعة مفتوحة',
      few: '$count دفعات مفتوحة',
      two: 'دفعتان مفتوحتان',
      one: 'دفعة مفتوحة واحدة',
      zero: 'لا توجد دفعات مفتوحة',
    );
    return '$_temp0';
  }

  @override
  String get shiftIsOpen => 'الوردية مفتوحة';

  @override
  String get closeRegisterExplain =>
      'سيؤدي إغلاق الصندوق إلى إنهاء هذه المعاملات وإنشاء تقرير Z وتصفير إجماليات اليوم. تأكد من إتمام سحوبات النقد قبل المتابعة.';

  @override
  String get noZReportsYet => 'لم يتم إنشاء أي تقرير Z بعد.';

  @override
  String zReportOnDate(String date) {
    return 'تقرير Z • $date';
  }

  @override
  String zReportSubtitle(String count, String total) {
    return 'المستندات: $count  •  المجموع الكلي: $total';
  }

  @override
  String get enterValidAmount => 'يرجى إدخال مبلغ صحيح.';

  @override
  String get selectDocumentOrAutoDistribute =>
      'يرجى تحديد مستند واحد على الأقل، أو تفعيل التوزيع التلقائي.';

  @override
  String get nothingToSettle =>
      'لا يوجد ما يمكن تسويته — المستندات المحددة مدفوعة بالفعل.';

  @override
  String anErrorOccurred(String message) {
    return 'حدث خطأ: $message';
  }

  @override
  String get useCustomerBalance => 'استخدام رصيد العميل';

  @override
  String get automaticDistribution => 'توزيع تلقائي';

  @override
  String get loadUnpaidDocuments => 'تحميل المستندات غير المدفوعة';

  @override
  String get summaryLabel => 'الملخص';

  @override
  String get customerBalance => 'رصيد العميل';

  @override
  String get totalInSelectedDocuments => 'إجمالي المستندات المحددة';

  @override
  String get customerNotSelectedReconcile =>
      'لم يتم اختيار عميل.\nيرجى اختيار عميل لإجراء التسوية.';

  @override
  String get autoDistributeExplain =>
      'سيتم توزيع المبلغ المدفوع تلقائيًا\nعلى جميع المبيعات غير المدفوعة.';

  @override
  String get noUnpaidDocumentsForCustomer =>
      'لا توجد مستندات غير مدفوعة لهذا العميل.';

  @override
  String get balanceLabel => 'الرصيد';

  @override
  String get internalNoteLabel => 'ملاحظة داخلية';

  @override
  String get allDates => 'كل التواريخ';

  @override
  String userNumbered(String id) {
    return 'المستخدم $id';
  }

  @override
  String get periodLabel => 'الفترة';

  @override
  String get docSearchHint => 'ابحث عن مستند أو اختر عامل تصفية';

  @override
  String get filterSuggestionsSection => 'البحث عن';

  @override
  String filterNumberContains(Object query) {
    return 'الرقم يحتوي على \"$query\"';
  }

  @override
  String filterReferenceContains(Object query) {
    return 'المرجع يحتوي على \"$query\"';
  }

  @override
  String filterCustomerContains(Object query) {
    return 'العميل يحتوي على \"$query\"';
  }

  @override
  String get filterCustomRange => 'فترة مخصصة...';

  @override
  String get filterKeepTyping => 'واصل الكتابة لتضييق القائمة';

  @override
  String get documentNumber => 'رقم المستند';

  @override
  String get documentNumberHint => 'مثال: 26-200-000001';

  @override
  String get externalDocument => 'مستند خارجي';

  @override
  String get paidStatus => 'حالة الدفع';

  @override
  String get totalResultsUpper => 'إجمالي النتائج';

  @override
  String get noDocumentsMatchingFilters => 'لا توجد مستندات مطابقة للمرشحات.';

  @override
  String get notAvailableShort => 'غير متاح';

  @override
  String get documentDeleted => 'تم حذف المستند';

  @override
  String get deleteFailed => 'فشل الحذف';

  @override
  String get monthAbbreviations =>
      'يناير,فبراير,مارس,أبريل,مايو,يونيو,يوليو,أغسطس,سبتمبر,أكتوبر,نوفمبر,ديسمبر';

  @override
  String get selectDocumentTypeError => 'يرجى اختيار نوع المستند.';

  @override
  String get selectCustomerSupplierError => 'يرجى اختيار عميل / مورّد.';

  @override
  String get selectUserError => 'يرجى اختيار مستخدم.';

  @override
  String get selectWarehouseError => 'يرجى اختيار مستودع.';

  @override
  String get couldNotResolveLocalDocument => 'تعذر العثور على المستند المحلي.';

  @override
  String get documentSaved => 'تم حفظ المستند!';

  @override
  String get newDocument => 'مستند جديد';

  @override
  String editDocumentNumbered(String number) {
    return 'تعديل المستند — $number';
  }

  @override
  String documentNumbered(String number) {
    return 'المستند — $number';
  }

  @override
  String saveHeaderFirstHint(String action) {
    return 'احفظ ترويسة المستند أولاً (معلومات المستند ← $action) لإدارة الأصناف والخصومات والمدفوعات.';
  }

  @override
  String get documentInfo => 'معلومات المستند';

  @override
  String get partiesLogistics => 'الأطراف والخدمات اللوجستية';

  @override
  String get financialsNotes => 'المالية والملاحظات';

  @override
  String get documentItems => 'أصناف المستند';

  @override
  String get paymentsTab => 'المدفوعات';

  @override
  String get dueDate => 'تاريخ الاستحقاق';

  @override
  String get stockDate => 'تاريخ المخزون';

  @override
  String get supplierRequired => 'المورّد *';

  @override
  String get applyAfterTax => 'التطبيق بعد الضريبة';

  @override
  String get saveHeaderChanges => 'حفظ تغييرات الترويسة';

  @override
  String get createAndAddItems => 'إنشاء وإضافة الأصناف';

  @override
  String get noItemsAddedYet => 'لم تتم إضافة أي صنف بعد.';

  @override
  String get clickAddProductToStart => 'اضغط على «إضافة منتج» للبدء.';

  @override
  String get qtyShort => 'الكمية';

  @override
  String get itemDiscShort => 'خصم الصنف';

  @override
  String get actionsLabel => 'الإجراءات';

  @override
  String get deleteItem => 'حذف الصنف';

  @override
  String deleteItemConfirm(String name) {
    return 'حذف «$name»؟';
  }

  @override
  String get itemsBaseTotal => 'إجمالي الأصناف الأساسي:';

  @override
  String get selectProductError => 'يرجى اختيار منتج.';

  @override
  String failedToAddItem(String message) {
    return 'تعذرت إضافة الصنف: $message';
  }

  @override
  String updateFailedWithMessage(String message) {
    return 'فشل التحديث: $message';
  }

  @override
  String get itemTax => 'ضريبة الصنف';

  @override
  String get appliedPayments => 'المدفوعات المطبَّقة';

  @override
  String get deleteAllPaymentsWarning =>
      'هذا المستند مدفوع بالكامل.\n\nالمتابعة ستحذف نهائيًا جميع معاملات الدفع المرتبطة به. هل أنت متأكد؟';

  @override
  String get documentTotal => 'إجمالي المستند';

  @override
  String get totalPaid => 'إجمالي المدفوع';

  @override
  String get remainingBalance => 'الرصيد المتبقي';

  @override
  String get noPaymentsAddedYet => 'لم تتم إضافة أي دفعة بعد.';

  @override
  String get deletePayment => 'حذف الدفعة';

  @override
  String get deletePaymentConfirm => 'هل تريد بالتأكيد حذف هذه الدفعة؟';

  @override
  String get selectPaymentTypeError => 'يرجى اختيار نوع الدفع.';

  @override
  String get failedToAddPayment => 'تعذرت إضافة الدفعة.';

  @override
  String get updateFailedShort => 'فشل التحديث.';

  @override
  String paymentTypeNamed(String name) {
    return 'نوع الدفع: $name';
  }

  @override
  String get discountLabel => 'الخصم';

  @override
  String get orderNumberLabel => 'رقم الطلب';

  @override
  String get updatedLabel => 'آخر تحديث';

  @override
  String get statusGracePeriod => 'التجديد متأخر';

  @override
  String get actionCreate => 'إنشاء';

  @override
  String get activeDevices => 'الأجهزة النشطة';

  @override
  String get addAtLeastOneProduct =>
      'أضف منتجًا واحدًا على الأقل إلى العرض الترويجي';

  @override
  String get addCustomerSupplier => 'إضافة عميل / مورّد';

  @override
  String get addToPromotion => 'إضافة إلى العرض الترويجي';

  @override
  String get administrator => 'مسؤول';

  @override
  String get allStockEntriesUpper => 'جميع سجلات المخزون';

  @override
  String get assignAddStock => 'تخصيص / إضافة مخزون';

  @override
  String get barcodesTab => 'الباركود';

  @override
  String cannotDeleteProductsLinked(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذّر حذف $count منتج — مرتبطة بطلبات أو مستندات قائمة',
      many: 'تعذّر حذف $count منتجًا — مرتبطة بطلبات أو مستندات قائمة',
      few: 'تعذّر حذف $count منتجات — مرتبطة بطلبات أو مستندات قائمة',
      two: 'تعذّر حذف منتجين — مرتبطين بطلبات أو مستندات قائمة',
      one: 'تعذّر حذف منتج واحد — مرتبط بطلبات أو مستندات قائمة',
      zero: 'لا توجد منتجات للحذف',
    );
    return '$_temp0';
  }

  @override
  String get clearEstimate => 'مسح التقدير';

  @override
  String codeWithValue(String code) {
    return 'الرمز: $code';
  }

  @override
  String get commentsTab => 'التعليقات';

  @override
  String get companyUpdatedSuccessfully => 'تم تحديث الشركة بنجاح';

  @override
  String get conditionalPromoHint => 'مشروط (مثال: اشترِ 2 واحصل على خصم)';

  @override
  String get costPrice => 'سعر التكلفة';

  @override
  String couldNotDeleteNamed(String name, String message) {
    return 'تعذّر حذف \"$name\": $message';
  }

  @override
  String couldNotSaveNamed(String name, String message) {
    return 'تعذّر حفظ \"$name\": $message';
  }

  @override
  String get countriesLabel => 'الدول';

  @override
  String get createEstimate => 'إنشاء تقدير';

  @override
  String get createPromotion => 'إنشاء عرض ترويجي';

  @override
  String get customerAdded => 'تمت إضافة العميل';

  @override
  String get customerUpdated => 'تم تحديث العميل';

  @override
  String get daysOfWeekLabel => 'أيام الأسبوع: ';

  @override
  String deleteWithCount(num count) {
    return 'حذف ($count)';
  }

  @override
  String deletedSomeProductsBlocked(num deleted, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'تم حذف $deleted · تم الاحتفاظ بـ $count منتج — مرتبطة بطلبات أو مستندات قائمة',
      many:
          'تم حذف $deleted · تم الاحتفاظ بـ $count منتجًا — مرتبطة بطلبات أو مستندات قائمة',
      few:
          'تم حذف $deleted · تم الاحتفاظ بـ $count منتجات — مرتبطة بطلبات أو مستندات قائمة',
      two:
          'تم حذف $deleted · تم الاحتفاظ بمنتجين — مرتبطين بطلبات أو مستندات قائمة',
      one:
          'تم حذف $deleted · تم الاحتفاظ بمنتج واحد — مرتبط بطلبات أو مستندات قائمة',
      zero: 'تم حذف $deleted · لم يتم الاحتفاظ بأي منتج',
    );
    return '$_temp0';
  }

  @override
  String get deletedSuccessfully => 'تم الحذف بنجاح';

  @override
  String get designFloorPlans => 'تصميم مخططات الصالة';

  @override
  String get detailsTab => 'التفاصيل';

  @override
  String get deviceRevokedSuccessfully => 'تم إلغاء الجهاز بنجاح';

  @override
  String get displayRank => 'ترتيب العرض';

  @override
  String get dueDatePeriodDays => 'مدة الاستحقاق (أيام)';

  @override
  String get editCustomer => 'تعديل العميل';

  @override
  String get editProduct => 'تعديل المنتج';

  @override
  String get editPromotion => 'تعديل العرض الترويجي';

  @override
  String get editQuantity => 'تعديل الكمية';

  @override
  String get endDateBeforeStartDate => 'تاريخ الانتهاء قبل تاريخ البدء';

  @override
  String get everyDay => 'كل يوم';

  @override
  String exportFailed(String message) {
    return 'فشل التصدير: $message';
  }

  @override
  String exportedProductsTo(num count, String path) {
    return 'تم تصدير $count منتجًا إلى $path';
  }

  @override
  String get failedToCreateUser => 'فشل إنشاء المستخدم.';

  @override
  String get failedToSaveChanges => 'فشل حفظ التغييرات.';

  @override
  String get failedToUpdateUser => 'فشل تحديث المستخدم.';

  @override
  String get failedToUploadLogo => 'فشل رفع الشعار.';

  @override
  String get finishSetup => 'إنهاء الإعداد';

  @override
  String get flagLow => 'منخفض';

  @override
  String get flagReorder => 'إعادة طلب';

  @override
  String get floorPlanTables => 'مخطط الصالة / الطاولات';

  @override
  String get folderColor => 'لون المجلد';

  @override
  String get folderImage => 'صورة المجلد';

  @override
  String get forceReset => 'إعادة تعيين إجبارية';

  @override
  String get groupDeleted => 'تم حذف المجموعة';

  @override
  String get groupHasChildrenCannotDelete =>
      'تحتوي هذه المجموعة على منتجات أو مجموعات فرعية ولا يمكن حذفها.';

  @override
  String get groupName => 'اسم المجموعة';

  @override
  String get groupNameHint => 'مثال: المشروبات، الحلويات';

  @override
  String itemsCountValue(num count) {
    return 'العناصر: $count';
  }

  @override
  String linkedAt(String date) {
    return 'تم الربط: $date';
  }

  @override
  String get logoUpdatedSuccessfully => 'تم تحديث الشعار بنجاح';

  @override
  String get lowStockWarningHelp => 'تنبيه عند انخفاض المخزون دون الحد';

  @override
  String get nameIsRequired => 'الاسم مطلوب.';

  @override
  String get nameIsRequiredShort => 'الاسم مطلوب';

  @override
  String get newPasswordsDoNotMatch => 'كلمتا المرور الجديدتان غير متطابقتين';

  @override
  String get newProduct => 'منتج جديد';

  @override
  String get newProductGroup => 'مجموعة منتجات جديدة';

  @override
  String get nextTaxesAndStock => 'التالي: الضرائب والمخزون';

  @override
  String get noActiveDevicesFound => 'لم يتم العثور على أجهزة نشطة.';

  @override
  String get noConnectionAddUsers =>
      'لا يوجد اتصال. تتطلب إضافة المستخدمين اتصالاً بالشبكة.';

  @override
  String get noConnectionDeleteUsers =>
      'لا يوجد اتصال. يتطلب حذف المستخدمين اتصالاً بالشبكة.';

  @override
  String get noCountriesAvailable => 'لا توجد دول متاحة.';

  @override
  String get noCustomersFound => 'لم يتم العثور على عملاء.';

  @override
  String get noEmailProvided => 'لم يتم توفير بريد إلكتروني';

  @override
  String get noLogoUploadedYet => 'لم يتم رفع أي شعار بعد';

  @override
  String noProductsMatchQuery(String query) {
    return 'لا توجد منتجات تطابق \"$query\"';
  }

  @override
  String get noPromotionsYet =>
      'لا توجد عروض ترويجية بعد. اضغط على \"إضافة عرض ترويجي\" لإنشاء واحد.';

  @override
  String get noSuppliersFound => 'لم يتم العثور على موردين.';

  @override
  String onBelowValue(num value) {
    return 'مفعّل — أقل من $value';
  }

  @override
  String get operationFailed => 'فشلت العملية.';

  @override
  String get overrideTaxes => 'تجاوز الضرائب';

  @override
  String get parentFolder => 'المجلد الأصلي';

  @override
  String get passwordForciblyReset => 'تمت إعادة تعيين كلمة المرور إجباريًا!';

  @override
  String get passwordUpdatedSuccessfully => 'تم تحديث كلمة المرور بنجاح';

  @override
  String get pendingSyncNew => 'بانتظار المزامنة (جديد)';

  @override
  String get pendingSyncUpdate => 'بانتظار المزامنة (تحديث)';

  @override
  String get pinForciblyResetForDevice =>
      'تمت إعادة تعيين رمز PIN إجباريًا لهذا الجهاز!';

  @override
  String get pinMustBeFourDigits => 'يجب أن يتكوّن رمز PIN من 4 أرقام';

  @override
  String get pinUpdatedSuccessfully => 'تم تحديث رمز PIN بنجاح';

  @override
  String get pleaseEnterProductName => 'يرجى إدخال اسم المنتج.';

  @override
  String get pleaseSelectACountry => 'يرجى اختيار دولة.';

  @override
  String get preferredQty => 'الكمية المفضلة';

  @override
  String get preferredQuantityHelp =>
      'الكمية المستهدفة التي يجب الاحتفاظ بها في المخزون';

  @override
  String productIdLabel(num id) {
    return 'معرّف المنتج: $id';
  }

  @override
  String get productSavedLocallySyncFirst =>
      'تم حفظ المنتج محليًا. قم بالمزامنة لإكمال الإعداد (الضرائب، الباركود، المخزون).';

  @override
  String get productUpdatedSuccessfully => 'تم تحديث المنتج بنجاح!';

  @override
  String get productsAssigned => 'تم تخصيص المنتجات بنجاح';

  @override
  String productsDeletedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حذف $count منتج',
      many: 'تم حذف $count منتجًا',
      few: 'تم حذف $count منتجات',
      two: 'تم حذف منتجين',
      one: 'تم حذف منتج واحد',
      zero: 'لم يتم حذف أي منتج',
    );
    return '$_temp0';
  }

  @override
  String promotionsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عرض ترويجي',
      many: '$count عرضًا ترويجيًا',
      few: '$count عروض ترويجية',
      two: 'عرضان ترويجيان',
      one: 'عرض ترويجي واحد',
      zero: 'لا توجد عروض ترويجية',
    );
    return '$_temp0';
  }

  @override
  String get quickInventory => 'جرد سريع';

  @override
  String get removeFromPromotion => 'إزالة من العرض الترويجي';

  @override
  String removeStockFromWarehouseConfirm(String product, String warehouse) {
    return 'إزالة $product من $warehouse؟';
  }

  @override
  String get reorderPointHelp =>
      'بدء إعادة الطلب عند انخفاض المخزون دون هذا المستوى';

  @override
  String get reprintReceipt => 'إعادة طباعة الإيصال';

  @override
  String get requiredField => 'مطلوب';

  @override
  String saveAssignmentsCount(num count) {
    return 'حفظ التخصيصات ($count محدد)';
  }

  @override
  String get saveCompanyChangesUpper => 'حفظ تغييرات الشركة';

  @override
  String get saveFailedShort => 'فشل الحفظ.';

  @override
  String savedLocallyNoServerId(String name) {
    return 'تم حفظ \"$name\" محليًا، لكن الخادم لم يُرجع معرّفًا. ستتم إعادة إرساله في المزامنة التالية.';
  }

  @override
  String get savedLocallyWillSyncOnline =>
      'تم الحفظ محليًا. ستتم المزامنة عند الاتصال.';

  @override
  String get savedOfflineWillSync =>
      'تم الحفظ دون اتصال. ستتم المزامنة عند الاتصال.';

  @override
  String savedOfflineWillSyncNamed(String name) {
    return 'تم حفظ \"$name\" دون اتصال — ستتم المزامنة عند عودة الخادم.';
  }

  @override
  String get savingUpper => 'جارٍ الحفظ...';

  @override
  String get scanOrEnterBarcode => 'امسح الباركود أو أدخله';

  @override
  String securityRuleUpdated(String rule) {
    return 'تم تحديث $rule.';
  }

  @override
  String get securityRules => 'قواعد الأمان';

  @override
  String get selectAtLeastOneDay =>
      'اختر يومًا واحدًا على الأقل من أيام الأسبوع';

  @override
  String get selectProductsFromLeft =>
      'اختر المنتجات من القائمة لإضافتها إلى العرض الترويجي.';

  @override
  String get selectedProducts => 'المنتجات المحددة';

  @override
  String get sellingPrice => 'سعر البيع';

  @override
  String get serverErrorCheckInputs =>
      'حدث خطأ في الخادم. يرجى التحقق من مدخلاتك.';

  @override
  String get serviceTag => 'خدمة';

  @override
  String setTaxesAndInventoryFor(String name) {
    return 'تعيين الضرائب والمخزون: $name';
  }

  @override
  String get setupComplete => 'اكتمل الإعداد!';

  @override
  String get startingCashLower => 'النقد الافتتاحي';

  @override
  String get statusInactive => 'غير نشط';

  @override
  String get stockControlRules => 'قواعد التحكم في المخزون';

  @override
  String get stockControlRulesUpper => 'قواعد التحكم في المخزون';

  @override
  String get stockInWarehouseUpper => 'المخزون في المستودع';

  @override
  String stockRulesForProduct(String name) {
    return 'قواعد المخزون — $name';
  }

  @override
  String get stockStatusHealthy => 'المخزون بحالة جيدة';

  @override
  String get stockStatusLow => 'مخزون منخفض — عند مستوى التحذير أو أقل';

  @override
  String get stockStatusReorder => 'عند نقطة إعادة الطلب أو أقل';

  @override
  String get suggestedOrder => 'الطلب المقترح';

  @override
  String suggestedOrderValue(String qty, num target) {
    return '+$qty للوصول إلى $target';
  }

  @override
  String get tapCameraIconToChangeLogo => 'اضغط على رمز الكاميرا لتغيير الشعار';

  @override
  String get thisDevice => 'هذا الجهاز';

  @override
  String get unexpectedErrorOccurred => 'حدث خطأ غير متوقع.';

  @override
  String get unexpectedErrorTryAgain =>
      'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';

  @override
  String uomWithValue(String unit) {
    return 'وحدة القياس: $unit';
  }

  @override
  String get updateFailed => 'فشل التحديث';

  @override
  String get userDeletedSuccessfully => 'تم حذف المستخدم بنجاح.';

  @override
  String get userProfileLower => 'الملف الشخصي للمستخدم';

  @override
  String get viewAllOpenOrders => 'عرض جميع الطلبات المفتوحة';

  @override
  String get viewCostPrices => 'عرض أسعار التكلفة';

  @override
  String get voidItem => 'إلغاء الصنف';

  @override
  String get warningThresholdHelp =>
      'إظهار تحذير عندما تكون الكمية أقل من هذه القيمة';

  @override
  String get weekdayAbbreviations =>
      'الإثنين,الثلاثاء,الأربعاء,الخميس,الجمعة,السبت,الأحد';

  @override
  String get weekdays => 'أيام العمل';

  @override
  String get weekends => 'عطلة نهاية الأسبوع';

  @override
  String get willDeleteWhenConnectionRestored =>
      'سيتم الحذف عند استعادة الاتصال';

  @override
  String get zeroStockQuantitySale => 'البيع بكمية مخزون صفرية';

  @override
  String addressWithValue(String address) {
    return 'العنوان: $address';
  }

  @override
  String get beginTrackingSession => 'ابدأ جلسة تتبّع لتسجيل ساعاتك.';

  @override
  String cashEntriesCount(num count) {
    return 'حركات النقد ($count)';
  }

  @override
  String checkoutError(String message) {
    return 'خطأ في الدفع: $message';
  }

  @override
  String get clockOutMustBeAfterClockIn =>
      'يجب أن يكون وقت الانصراف بعد وقت الحضور.';

  @override
  String get completeTransaction => 'إتمام\nالمعاملة';

  @override
  String couldNotLoadEntries(String message) {
    return 'تعذّر تحميل الحركات: $message';
  }

  @override
  String get creditNeedsCustomer =>
      'يتطلب الدفع الآجل تحديد عميل.\n\nيرجى اختيار عميل قبل إتمام هذه المعاملة.';

  @override
  String deleteDocumentConfirmPermanent(String number) {
    return 'هل تريد حذف \"$number\"؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String discountWithAmount(String amount, String symbol) {
    return 'الخصم: $amount $symbol';
  }

  @override
  String documentsCountValue(num count) {
    return 'عدد المستندات: $count';
  }

  @override
  String get enterValidAmountAboveZero => 'أدخل مبلغًا صالحًا أكبر من الصفر.';

  @override
  String get exceedsMaximum => 'يتجاوز الحد الأقصى';

  @override
  String get failedToLoadCustomers => 'فشل تحميل العملاء';

  @override
  String get failedToLoadOrder => 'فشل تحميل الطلب.';

  @override
  String featureComingSoon(String feature) {
    return '$feature — قريبًا';
  }

  @override
  String get filterByCustomer => 'تصفية حسب العميل';

  @override
  String get hoursReport => 'تقرير الساعات';

  @override
  String labelWithColon(String label) {
    return '$label: ';
  }

  @override
  String get lastMonth => 'الشهر الماضي';

  @override
  String get lastWeek => 'الأسبوع الماضي';

  @override
  String get lastYear => 'العام الماضي';

  @override
  String maxUsableThisOrder(String points) {
    return 'الحد الأقصى القابل للاستخدام في هذا الطلب: $points نقطة';
  }

  @override
  String get missingCompanyOrUserContext => 'سياق الشركة أو المستخدم مفقود.';

  @override
  String get mySales => 'مبيعاتي';

  @override
  String get myShift => 'ورديتي';

  @override
  String get noActiveShift => 'لا توجد وردية نشطة';

  @override
  String get noCashMovementsToday => 'لا توجد حركات نقدية اليوم.';

  @override
  String get noItemsForDocument => 'لم يتم العثور على عناصر لهذا المستند.';

  @override
  String get noOpenOrders => 'لا توجد طلبات مفتوحة';

  @override
  String noOrdersMatchQuery(String query) {
    return 'لا توجد طلبات تطابق \"$query\"';
  }

  @override
  String get noSalesDocumentsForPeriod =>
      'لا توجد مستندات مبيعات للفترة المحددة.';

  @override
  String get noTimeEntriesInRange => 'لا توجد تسجيلات وقت في النطاق المحدد.';

  @override
  String get nothingToExportInRange => 'لا يوجد ما يمكن تصديره في هذا النطاق';

  @override
  String get nowSelectEndDate => 'اختر الآن تاريخ الانتهاء';

  @override
  String get paymentMethod => 'طريقة الدفع';

  @override
  String pointsBalanceWorth(String points, String value, String symbol) {
    return 'الرصيد: $points نقطة = $value $symbol';
  }

  @override
  String get predefinedPeriod => 'فترة محددة مسبقًا';

  @override
  String get receiptLabel => 'الإيصال';

  @override
  String redeemingPoints(String points, String amount, String symbol) {
    return 'استبدال $points نقطة (−$amount $symbol)';
  }

  @override
  String get reportCopiedAsCsv => 'تم نسخ التقرير إلى الحافظة بصيغة CSV';

  @override
  String get salesHistoryTitle => 'سجل المبيعات';

  @override
  String get saveCashIn => 'حفظ الإيداع';

  @override
  String get saveCashOut => 'حفظ السحب';

  @override
  String get selectAll => 'تحديد الكل';

  @override
  String get selectAnEmployeeError => 'اختر موظفًا.';

  @override
  String get selectDocumentToViewItems => 'اختر مستندًا أعلاه لعرض عناصره.';

  @override
  String get sendEmail => 'إرسال بريد إلكتروني';

  @override
  String get shiftOpen => 'الوردية مفتوحة';

  @override
  String get shiftStillOpen => 'مفتوحة';

  @override
  String get tapToRedeemPoints => 'اضغط لاستبدال النقاط';

  @override
  String taxNoWithValue(String number) {
    return 'الرقم الضريبي: $number';
  }

  @override
  String get thisMonth => 'هذا الشهر';

  @override
  String get thisWeek => 'هذا الأسبوع';

  @override
  String get thisYear => 'هذا العام';

  @override
  String get timeCardAdded => 'تمت إضافة بطاقة الوقت';

  @override
  String totalAmountWithValue(String amount, String symbol) {
    return 'المبلغ الإجمالي: $amount $symbol';
  }

  @override
  String get totalCompleted => 'الإجمالي (المكتملة)';

  @override
  String get totalHours => 'إجمالي الساعات';

  @override
  String totalHoursWithValue(String hours) {
    return 'إجمالي الساعات: $hours';
  }

  @override
  String get weekdayInitials => 'ن,ث,ر,خ,ج,س,ح';

  @override
  String get yesterday => 'أمس';

  @override
  String noStockAvailableIn(String warehouse) {
    return 'لا يوجد مخزون متاح في $warehouse.';
  }

  @override
  String get theSelectedWarehouse => 'المستودع المحدد';

  @override
  String warehouseNumbered(String id) {
    return 'المستودع $id';
  }

  @override
  String switchedToWarehouse(String warehouse) {
    return 'تم التبديل إلى $warehouse — اضغط على المنتج لإضافته.';
  }

  @override
  String lowStockAddAnyway(String qty, String unit) {
    return 'إضافة هذا الصنف ستترك $qty $unit فقط في المخزون، عند مستوى تنبيه المخزون المنخفض أو أقل منه.\n\nهل تريد إضافته على أي حال؟';
  }

  @override
  String get unitsFallback => 'وحدة/وحدات';

  @override
  String kitchenPrintError(String message) {
    return 'خطأ في طباعة المطبخ: $message';
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
      other: 'تم إرسال $countString تذاكر مطبخ',
      one: 'تم إرسال تذكرة المطبخ',
    );
    return '$_temp0';
  }

  @override
  String get kitchenNoStationMatched =>
      'لا توجد طابعة قسم تغطي هذه الأصناف — ستتم طباعة التذكرة الكاملة بدلاً من ذلك.';

  @override
  String couldNotSaveOrder(String message) {
    return 'تعذر حفظ الطلب: $message';
  }

  @override
  String scaleBarcodeProductNotFound(String code) {
    return 'باركود الميزان: المنتج «$code» غير موجود.';
  }

  @override
  String errorCreatingOrder(String message) {
    return 'خطأ أثناء إنشاء الطلب: $message';
  }

  @override
  String get orderSavedToTable => 'تم حفظ الطلب على الطاولة!';

  @override
  String get orderSaved => 'تم حفظ الطلب!';

  @override
  String get orderVoided => 'تم إلغاء الطلب';

  @override
  String get orderTransferred => 'تم تحويل الطلب';

  @override
  String transferFailed(String message) {
    return 'فشل التحويل: $message';
  }

  @override
  String receiptAlreadyRefunded(String reference) {
    return 'تم استرجاع هذا الإيصال بالفعل (المرجع: $reference).';
  }

  @override
  String receiptNotFound(String number) {
    return 'الإيصال «$number» غير موجود.';
  }

  @override
  String get managerPinNotRecognised =>
      'رمز المدير غير صحيح. الإرجاع دون مرجع يتطلب مسؤولاً.';

  @override
  String get addAtLeastOneItemToReturn => 'أضف صنفًا واحدًا على الأقل للإرجاع.';

  @override
  String get selectRefundPaymentType => 'اختر نوع دفع الاسترجاع.';

  @override
  String get blindRefundQueued =>
      'تم وضع الإرجاع دون مرجع في قائمة الانتظار — ستتم المزامنة تلقائيًا.';

  @override
  String blindRefundProcessed(String number) {
    return 'تمت معالجة الإرجاع دون مرجع $number.';
  }

  @override
  String get lookUpReceiptFirst => 'ابحث عن إيصال أولاً.';

  @override
  String get selectAtLeastOneItemToRefund =>
      'اختر صنفًا واحدًا على الأقل للاسترجاع.';

  @override
  String get refundQueued =>
      'تم وضع الاسترجاع في قائمة الانتظار — ستتم المزامنة تلقائيًا.';

  @override
  String refundProcessed(String number) {
    return 'تمت معالجة الاسترجاع $number.';
  }

  @override
  String get customerReceiptOptional => 'رقم إيصال العميل (اختياري)';

  @override
  String get optionalFromPaperReceipt => 'اختياري — من الإيصال الورقي';

  @override
  String get blindReturnManagerAuthorised =>
      'إرجاع دون مرجع — بموافقة المدير. لا يوجد إيصال أصلي.';

  @override
  String get blindReturnExplain =>
      'الإرجاع دون مرجع يعيد قيمة البضاعة بدون إيصال. يجب أن يوافق عليه المدير.';

  @override
  String priceTimesMaxQty(String price, String qty) {
    return '$price × بحد أقصى $qty';
  }

  @override
  String get advancedHardware => 'متقدم / الأجهزة';

  @override
  String get changeAllowed => 'يُسمح بإرجاع الباقي';

  @override
  String get colCustomerRequired => 'العميل مطلوب';

  @override
  String get colMarkPaid => 'وضع علامة مدفوع';

  @override
  String get colQuickPay => 'دفع سريع';

  @override
  String get colSlip => 'إيصال';

  @override
  String get coreSettings => 'الإعدادات الأساسية';

  @override
  String get customerRequiredLabel => 'العميل مطلوب';

  @override
  String deleteTaxRateConfirm(String name) {
    return 'هل تريد بالتأكيد حذف نسبة الضريبة \"$name\"؟';
  }

  @override
  String get editPaymentType => 'تعديل طريقة الدفع';

  @override
  String get editTaxRate => 'تعديل نسبة الضريبة';

  @override
  String get enterValidNumber => 'أدخل رقمًا صالحًا';

  @override
  String get fiscal => 'ضريبي';

  @override
  String get markAsPaid => 'وضع علامة كمدفوع';

  @override
  String get oldAndNewTaxMustDiffer =>
      'يجب أن تكون الضريبة القديمة مختلفة عن الجديدة.';

  @override
  String get paymentTypeDeleted => 'تم حذف طريقة الدفع';

  @override
  String get pleaseSelectBothTaxes => 'يرجى اختيار كلتا الضريبتين.';

  @override
  String get quickPayment => 'دفع سريع';

  @override
  String get slipRequired => 'الإيصال مطلوب';

  @override
  String get switchFailed => 'فشل التبديل.';

  @override
  String taxRateAppliedSuccessfully(
    String rate,
    String oldName,
    String newName,
  ) {
    return 'تم تطبيق النسبة $rate من \"$oldName\" على \"$newName\" بنجاح.';
  }

  @override
  String get taxRateDeleted => 'تم حذف نسبة الضريبة';

  @override
  String get yearTotal => 'إجمالي السنة';

  @override
  String get topMonth => 'أفضل شهر';

  @override
  String monthlySalesYear(String year) {
    return 'المبيعات الشهرية — $year';
  }

  @override
  String activeMonthsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شهر نشط',
      many: '$count شهرًا نشطًا',
      few: '$count أشهر نشطة',
      two: 'شهران نشطان',
      one: 'شهر نشط واحد',
      zero: 'لا توجد أشهر نشطة',
    );
    return '$_temp0';
  }

  @override
  String get periodicReports => 'التقارير الدورية';

  @override
  String get selectDateRangeToFilter =>
      'اختر نطاقًا زمنيًا لتصفية البطاقات أدناه';

  @override
  String get failedToLoadYearlyData => 'تعذر تحميل البيانات السنوية';

  @override
  String get noDataToDisplay => 'لا توجد بيانات لعرضها';

  @override
  String get selectedPeriod => 'الفترة المحددة';

  @override
  String get filterLabel => 'تصفية';

  @override
  String get customersAndSuppliers => 'العملاء والموردون';

  @override
  String get cashRegister => 'الصندوق';

  @override
  String get colImage => 'الصورة';

  @override
  String get fieldUnit => 'الوحدة';

  @override
  String get markupPercent => 'نسبة الربح %';

  @override
  String get lastPurchase => 'آخر شراء';

  @override
  String get fieldRank => 'الترتيب';

  @override
  String get taxInclusive => 'شامل الضريبة';

  @override
  String get priceChange => 'تغيير السعر';

  @override
  String get businessPartnerRequired => 'الشريك التجاري (مطلوب)';

  @override
  String get addServiceType => 'إضافة نوع خدمة';

  @override
  String get allValuesMustBePositive => 'يجب أن تكون جميع القيم أرقامًا موجبة.';

  @override
  String get bookingArrived => 'وصل';

  @override
  String get bookingCompleted => 'مكتملة';

  @override
  String get bookingInService => 'قيد الخدمة';

  @override
  String get bookingNoShow => 'لم يحضر';

  @override
  String get bookingPending => 'قيد الانتظار';

  @override
  String couldNotCheckStock(String message) {
    return 'تعذّر التحقق من المخزون: $message';
  }

  @override
  String deleteLoyaltyCardConfirm(String name) {
    return 'هل تريد حذف بطاقة الولاء الخاصة بـ $name؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String earningRuleExample(String symbol) {
    return 'مثال: كل 100 $symbol تُنفَق تكسب 10 نقاط';
  }

  @override
  String get editServiceType => 'تعديل نوع الخدمة';

  @override
  String get editWarehouse => 'تعديل المستودع';

  @override
  String get enterValidPointsValue => 'أدخل قيمة نقاط صالحة وغير سالبة.';

  @override
  String failedToAddCard(String message) {
    return 'فشل إضافة البطاقة: $message';
  }

  @override
  String failedToDeleteCard(String message) {
    return 'فشل الحذف: $message';
  }

  @override
  String failedToUpdateCard(String message) {
    return 'فشل تحديث البطاقة: $message';
  }

  @override
  String guestsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ضيف',
      many: '$count ضيفًا',
      few: '$count ضيوف',
      two: 'ضيفان',
      one: 'ضيف واحد',
      zero: 'لا يوجد ضيوف',
    );
    return '$_temp0';
  }

  @override
  String get historyTab => 'السجل';

  @override
  String get loyaltyCardAdded => 'تمت إضافة بطاقة الولاء';

  @override
  String get loyaltyCardDeleted => 'تم حذف بطاقة الولاء';

  @override
  String get loyaltyCardUpdated => 'تم تحديث بطاقة الولاء';

  @override
  String get loyaltySettingsSaved => 'تم حفظ إعدادات الولاء';

  @override
  String get newWarehouse => 'مستودع جديد';

  @override
  String get noCardNumber => 'لا يوجد رقم بطاقة';

  @override
  String get noCompletedBookings => 'لا توجد حجوزات مكتملة بعد.';

  @override
  String get noLoyaltyCardsYet => 'لا توجد بطاقات ولاء بعد.';

  @override
  String get noUpcomingBookings => 'لا توجد حجوزات قادمة.';

  @override
  String get onePointEquals => 'نقطة واحدة تساوي';

  @override
  String orderNumbered(String number) {
    return 'الطلب رقم $number';
  }

  @override
  String get pleaseSelectACustomer => 'يرجى اختيار عميل.';

  @override
  String get pointsCannotBeNegative => 'لا يمكن أن تكون النقاط سالبة.';

  @override
  String redemptionRuleExample(String symbol) {
    return 'مثال: نقطة واحدة = خصم 1 $symbol عند الدفع';
  }

  @override
  String removeNamedConfirm(String name) {
    return 'إزالة \"$name\"؟';
  }

  @override
  String stockMovedWarehouseDeleted(String name) {
    return 'تم نقل المخزون إلى $name؛ وتم حذف المستودع';
  }

  @override
  String tablesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طاولة',
      many: '$count طاولة',
      few: '$count طاولات',
      two: 'طاولتان',
      one: 'طاولة واحدة',
      zero: 'لا توجد طاولات',
    );
    return '$_temp0';
  }

  @override
  String get upcoming => 'القادمة';

  @override
  String get warehouseAndStockDeleted => 'تم حذف المستودع ومخزونه';

  @override
  String get warehouseDeleted => 'تم حذف المستودع';

  @override
  String warehouseStillHoldsStock(String name, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'لا يزال \"$name\" يحتوي على $count صنف في المخزون. ما الذي يجب فعله بها قبل حذف المستودع؟',
      many:
          'لا يزال \"$name\" يحتوي على $count صنفًا في المخزون. ما الذي يجب فعله بها قبل حذف المستودع؟',
      few:
          'لا يزال \"$name\" يحتوي على $count أصناف في المخزون. ما الذي يجب فعله بها قبل حذف المستودع؟',
      two:
          'لا يزال \"$name\" يحتوي على صنفين في المخزون. ما الذي يجب فعله بهما قبل حذف المستودع؟',
      one:
          'لا يزال \"$name\" يحتوي على صنف واحد في المخزون. ما الذي يجب فعله به قبل حذف المستودع؟',
      zero: 'لا يحتوي \"$name\" على أي مخزون.',
    );
    return '$_temp0';
  }

  @override
  String get beforeTax => 'قبل الضريبة';

  @override
  String get afterTax => 'بعد الضريبة';

  @override
  String get listLabel => 'قائمة';

  @override
  String get gridLabel => 'شبكة';

  @override
  String get cancelUpper => 'إلغاء';

  @override
  String get noCategory => 'بدون فئة';

  @override
  String get enterAGroupName => 'أدخل اسم المجموعة.';

  @override
  String categoryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فئة',
      many: '$count فئة',
      few: '$count فئات',
      two: 'فئتان',
      one: 'فئة واحدة',
      zero: 'لا توجد فئات',
    );
    return '$_temp0';
  }

  @override
  String get enterAnIpAddress => 'أدخل عنوان IP';

  @override
  String get invalidIpWithExample => 'عنوان IP غير صالح (مثال: 192.168.1.100)';

  @override
  String get invalidIp => 'عنوان IP غير صالح';

  @override
  String get backupDatabase => 'نسخ احتياطي لقاعدة البيانات';

  @override
  String get backingUpEllipsis => 'جارٍ النسخ الاحتياطي…';

  @override
  String backupSaved(String file) {
    return 'تم حفظ النسخة الاحتياطية: $file';
  }

  @override
  String backupFailed(String message) {
    return 'فشل النسخ الاحتياطي: $message';
  }

  @override
  String get selectBackupFolder => 'اختر مجلد النسخ الاحتياطي';

  @override
  String get autoBackupExplain =>
      'أنشئ نسخًا احتياطية من بياناتك تلقائيًا للحماية من الفقدان أو التلف';

  @override
  String get unitHours => 'ساعات';

  @override
  String get unitDays => 'أيام';

  @override
  String settingSaved(String setting) {
    return 'تم حفظ $setting';
  }

  @override
  String get customerDisplayQrHint =>
      'امسح رمز الاستجابة السريعة لفتح شاشة العميل على أي جهاز متصل بالإنترنت.';

  @override
  String get everythingIsSynced => 'تمت مزامنة كل شيء';

  @override
  String get exitApplicationConfirm => 'هل تريد بالتأكيد الخروج من التطبيق؟';

  @override
  String failedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إخفاق',
      many: '$count إخفاقًا',
      few: '$count إخفاقات',
      two: 'إخفاقان',
      one: 'إخفاق واحد',
      zero: 'لا توجد إخفاقات',
    );
    return '$_temp0';
  }

  @override
  String get fontSizeDefault => 'افتراضي';

  @override
  String get fontSizeLarge => 'كبير';

  @override
  String get fontSizeLarger => 'أكبر';

  @override
  String get fontSizeSmall => 'صغير';

  @override
  String itemsPendingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر معلّق',
      many: '$count عنصرًا معلّقًا',
      few: '$count عناصر معلّقة',
      two: 'عنصران معلّقان',
      one: 'عنصر واحد معلّق',
      zero: 'لا توجد عناصر معلّقة',
    );
    return '$_temp0';
  }

  @override
  String pendingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count معلّق',
      many: '$count معلّقًا',
      few: '$count معلّقة',
      two: 'اثنان معلّقان',
      one: 'واحد معلّق',
      zero: 'لا شيء معلّق',
    );
    return '$_temp0';
  }

  @override
  String get syncAfterEverySave => 'بعد كل عملية حفظ';

  @override
  String get syncCashMovements => 'الحركات النقدية';

  @override
  String get syncCompletedSales => 'مبيعات مكتملة بانتظار الرفع';

  @override
  String get syncCustomerDiscounts => 'خصومات العملاء';

  @override
  String get syncEveryHour => 'كل ساعة';

  @override
  String get syncNow => 'المزامنة الآن';

  @override
  String get syncProductComments => 'تعليقات المنتجات';

  @override
  String get syncProductTaxes => 'ضرائب المنتجات';

  @override
  String get syncShifts => 'الورديات';

  @override
  String get syncStatusTitle => 'حالة المزامنة';

  @override
  String get syncStockCounts => 'جرد المخزون';

  @override
  String get syncStockTransfers => 'تحويلات المخزون';

  @override
  String get syncVoids => 'الإلغاءات';

  @override
  String get syncZReports => 'تقارير Z';

  @override
  String get syncedStatus => 'تمت المزامنة';

  @override
  String get syncingEllipsis => 'جارٍ المزامنة…';

  @override
  String get backupPathHintWindows => 'مثال: D:\\database\\Backup';

  @override
  String get backupPathHintUnix => 'مثال: /home/user/backups';

  @override
  String get backupPathHintManaged => 'يديره التطبيق — اضغط فتح الموقع لعرضه';

  @override
  String get exchangeRateHint => 'مثال: 1.08  (1 عملة أساسية = X عملة ثانوية)';

  @override
  String get addServiceStatus => 'إضافة حالة خدمة';

  @override
  String get clearFavorites => 'مسح المفضلة';

  @override
  String get editServiceStatus => 'تعديل حالة الخدمة';

  @override
  String get hintTablesRooms => 'مثال: طاولات، غرف';

  @override
  String get hintUnitsExample => 'مثال: قطعة، كجم، لتر';

  @override
  String get includeSubgroups => 'تضمين المجموعات الفرعية';

  @override
  String get noReportsFound => 'لم يتم العثور على تقارير.';

  @override
  String noSettingsMatching(String query) {
    return 'لا توجد إعدادات تطابق \"$query\"';
  }

  @override
  String get notSet => 'غير محدّد';

  @override
  String get reportComingSoon => 'هذا التقرير قادم قريبًا.';

  @override
  String scaleErrorWithMessage(String message) {
    return 'خطأ في الميزان: $message';
  }

  @override
  String get selectBusinessPartnerInFilter =>
      'يرجى اختيار شريك تجاري من لوحة التصفية.';

  @override
  String get selectReportToViewOrPrint => 'اختر تقريرًا لعرضه أو طباعته';

  @override
  String versionLabel(String version) {
    return 'الإصدار $version';
  }

  @override
  String ageRestrictionBody(num age) {
    return 'يتطلب هذا المنتج أن يكون عمر العميل $age سنة على الأقل.\n\nيرجى التأكد من استيفاء العميل لهذا الشرط قبل المتابعة.';
  }

  @override
  String get bookingCompletedLocked => 'هذا الحجز مكتمل ولا يمكن تعديله.';

  @override
  String get bookingPrefix => 'الحجز: ';

  @override
  String get branch => 'الفرع';

  @override
  String clockedInWithValue(String value) {
    return 'تم تسجيل الحضور · $value';
  }

  @override
  String deleteBookingConfirm(String name) {
    return 'حذف حجز \"$name\"؟';
  }

  @override
  String get editBooking => 'تعديل الحجز';

  @override
  String errorLoadingDataWithMessage(String message) {
    return 'خطأ في تحميل البيانات: $message';
  }

  @override
  String errorLoadingSpaces(String message) {
    return 'خطأ في تحميل المساحات: $message';
  }

  @override
  String get exitEditMode => 'الخروج من وضع التحرير';

  @override
  String get newBooking => 'حجز جديد';

  @override
  String noFreeSpacesAvailable(String space) {
    return 'لا توجد $space متاحة';
  }

  @override
  String get openOrderNow => 'فتح الطلب الآن';

  @override
  String get removeFloorPlanConfirm =>
      'سيؤدي هذا إلى حذف مخطط الصالة وجميع طاولاته نهائيًا. هل تريد المتابعة؟';

  @override
  String get sendingSignal => 'جارٍ إرسال الإشارة...';

  @override
  String get shapeLabel => 'الشكل';

  @override
  String get sizeLabel => 'الحجم';

  @override
  String get staffPrefix => '  ·  الموظف: ';

  @override
  String tableNumbered(String number) {
    return 'الطاولة رقم $number';
  }

  @override
  String taxesForProduct(String product) {
    return 'الضرائب · $product';
  }

  @override
  String get testDrawerOpen => 'اختبار فتح الدرج';

  @override
  String todayWithValue(String value) {
    return 'اليوم: $value';
  }

  @override
  String get updateStatusUpper => 'تحديث الحالة';

  @override
  String voidReasonPrompt(String number) {
    return 'أدخل أو اختر سبب إلغاء \"$number\"';
  }

  @override
  String get accessDenied => 'تم رفض الوصول';

  @override
  String get accessDeniedBody =>
      'ليس لديك إذن لعرض هذا القسم.\nاختر قسمًا آخر من القائمة، أو اطلب الإذن من المسؤول.';

  @override
  String get checkingUpper => 'جارٍ التحقق…';

  @override
  String get chooseYourMenuLayout => 'اختر تخطيط القائمة';

  @override
  String get connectingEllipsis => 'جارٍ الاتصال…';

  @override
  String createFirstAdminFor(String company) {
    return 'أنشئ أول مستخدم مسؤول لـ $company';
  }

  @override
  String discountAmountLine(String currency, String amount) {
    return 'الخصم  −$currency $amount';
  }

  @override
  String get editCurrency => 'تعديل العملة';

  @override
  String enableResource(String resource) {
    return 'تفعيل $resource';
  }

  @override
  String get errorLoadingRooms => 'خطأ في تحميل الغرف';

  @override
  String expiredOnDate(String date) {
    return 'انتهت الصلاحية في $date';
  }

  @override
  String get getGoingInThreeSteps => 'ابدأ في 3 خطوات';

  @override
  String get managementPortal => 'بوابة الإدارة';

  @override
  String get menuLayoutHint =>
      'كيفية ظهور المنتجات في شاشة البيع — يمكنك تغييرها في أي وقت من الإعدادات.';

  @override
  String get noFloorPlans => 'لا توجد مخططات صالة';

  @override
  String openOrderForEachResource(String resource) {
    return 'افتح طلبًا لكل $resource.';
  }

  @override
  String get poweredByPos => 'مدعوم بواسطة POS';

  @override
  String get reconnectingEllipsis => 'جارٍ إعادة الاتصال…';

  @override
  String get retryConnectionUpper => 'إعادة محاولة الاتصال';

  @override
  String checkedAgainstEndpoint(String endpoint) {
    return 'تم التحقق عبر $endpoint';
  }

  @override
  String scaleUnitMismatch(String scaleUnit, String productUnit) {
    return 'يقرأ الميزان $scaleUnit لكن سعر هذا الصنف محدّد لكل $productUnit — لا يتم تطبيق أي تحويل.';
  }

  @override
  String get selectServiceTypeForOrder => 'اختر نوع الخدمة لهذا الطلب';

  @override
  String tableHeldByReservation(String name) {
    return 'هذه الطاولة محجوزة باسم \"$name\".';
  }

  @override
  String get thankYou => 'شكرًا لك!';

  @override
  String get weWillSwitchOnFeatures => 'سنقوم بتفعيل الميزات المناسبة لك.';

  @override
  String get whatsYourBusiness => 'ما هو نشاطك التجاري؟';

  @override
  String get changeThisLaterInSettings =>
      'يمكنك تغيير كل هذا لاحقًا من الإعدادات.';

  @override
  String get everythingBuiltIn => 'كل هذا مضمّن — لا حاجة لشراء إضافات.';

  @override
  String get everythingYouGet => 'كل ما تحصل عليه';

  @override
  String get getStarted => 'ابدأ الآن';

  @override
  String get linkDeviceUpper => 'ربط الجهاز';

  @override
  String numberOfProductsToImport(num count) {
    return 'عدد المنتجات المراد استيرادها: $count';
  }

  @override
  String get setUpYourTerminal => 'قم بإعداد جهازك';

  @override
  String get statusExpiresToday => 'تنتهي اليوم';

  @override
  String get accessDeniedNoPermission =>
      'تم رفض الوصول: ليس لديك إذن لتنفيذ هذا الإجراء.';

  @override
  String alreadyBookedDuringTime(String what, String name, String range) {
    return 'هذا $what محجوز بالفعل خلال هذا الوقت — $name ($range).';
  }

  @override
  String get cannotBookInPast => 'لا يمكن إنشاء حجز في الماضي.';

  @override
  String changesRejected(num count, String details) {
    return 'تم رفض $count تغييرات: $details';
  }

  @override
  String get couldNotFindActiveOrder => 'تعذّر العثور على طلب نشط.';

  @override
  String get couldNotOpenReservationOrder =>
      'تعذّر فتح طلب الحجز. ربما تم إكماله أو إلغاؤه.';

  @override
  String get couldNotReachServer =>
      'تعذّر الوصول إلى الخادم. تحقق من اتصالك بالإنترنت.';

  @override
  String get currencyDeleted => 'تم حذف العملة';

  @override
  String get endTimeAfterStartTime => 'يجب أن يكون وقت الانتهاء بعد وقت البدء.';

  @override
  String failedToSaveField(String field) {
    return 'فشل حفظ $field';
  }

  @override
  String importFailed(String message) {
    return 'فشل الاستيراد: $message';
  }

  @override
  String get licenseInvalidBody =>
      'تعذّر التحقق من ترخيص هذا الجهاز. يرجى التواصل مع الدعم لاستعادة الخدمة.';

  @override
  String get licenseInvalidContactSupport =>
      'الترخيص غير صالح. يرجى التواصل مع الدعم.';

  @override
  String get licenseInvalidTitle => 'ترخيص غير صالح';

  @override
  String get orderNotFoundCompletedOrVoided =>
      'لم يتم العثور على الطلب. ربما تم إكماله أو إلغاؤه.';

  @override
  String pendingTapForStatus(num count) {
    return '$count معلّق — اضغط لعرض حالة المزامنة';
  }

  @override
  String printFailed(String message) {
    return 'فشلت الطباعة: $message';
  }

  @override
  String get reservationNoLongerActive => 'لم يعد هذا الحجز نشطًا.';

  @override
  String get selectAtLeastOneTable => 'يرجى اختيار طاولة واحدة على الأقل.';

  @override
  String get selectCompanyFirst => 'اختر شركة أولاً';

  @override
  String get staffMemberLower => 'موظف';

  @override
  String get subscriptionInactiveBody =>
      'اشتراكك غير نشط. يرجى التواصل مع مزوّد الخدمة للتجديد، ثم أعد محاولة الاتصال لمتابعة البيع.';

  @override
  String get subscriptionInactiveTitle => 'الاشتراك غير نشط';

  @override
  String get subscriptionStillInactive =>
      'الاشتراك ما زال غير نشط. يرجى التواصل مع مزوّد الخدمة.';

  @override
  String get syncComplete => 'اكتملت المزامنة';

  @override
  String get syncFailed => 'فشلت المزامنة';

  @override
  String syncFinishedWithFailures(String entities) {
    return 'انتهت المزامنة، لكن هذه العناصر لم تتم مزامنتها: $entities';
  }

  @override
  String get syncStatusTooltip => 'حالة المزامنة';

  @override
  String get tableNeedsBooking =>
      'تحتاج هذه الطاولة إلى حجز. أنشئ حجزًا، ثم ابدأ الخدمة منه.';

  @override
  String get terminalNotLinked => 'هذا الجهاز غير مرتبط. أعد ربط الجهاز.';

  @override
  String get testMessageSent => 'تم إرسال رسالة الاختبار.';

  @override
  String get testSignalSentToDrawer => 'تم إرسال إشارة اختبار إلى درج النقد';

  @override
  String get urlCopied => 'تم نسخ الرابط';

  @override
  String get accessRulesNotSynced =>
      'لم تصل قواعد الوصول إلى هذا الجهاز بعد. اتصل بالشبكة وقم بالمزامنة ثم أعد المحاولة.';

  @override
  String get updateSectionTitle => 'تحديث البرنامج';

  @override
  String get updateAutoCheckLabel => 'البحث عن التحديثات تلقائيًا';

  @override
  String get updateCheckNow => 'التحقق الآن';

  @override
  String get updateChecking => 'جارٍ التحقق…';

  @override
  String get updateUpToDate => 'أنت تستخدم أحدث إصدار';

  @override
  String updateAvailableLabel(String version) {
    return 'الإصدار $version متاح';
  }

  @override
  String get updateDownloadAction => 'تنزيل التحديث';

  @override
  String updateDownloadingLabel(String percent) {
    return 'جارٍ التنزيل… $percent٪';
  }

  @override
  String get updateInstallAction => 'التثبيت وإعادة التشغيل';

  @override
  String get updateCancelAction => 'إلغاء التنزيل';

  @override
  String get updateFailedLabel => 'تعذّر التحقق من التحديثات';

  @override
  String get updateBlockedByCart =>
      'أكمل عملية البيع الحالية أو امسحها قبل التحديث.';

  @override
  String updatePendingWarning(int count) {
    return '$count عنصر/عناصر في انتظار المزامنة. زامن أولًا إن أمكن.';
  }

  @override
  String get updateRestartNotice => 'سيتم إغلاق التطبيق لتثبيت التحديث.';

  @override
  String get updateUnsupportedPlatform =>
      'التحديثات داخل التطبيق متاحة على نظام Windows فقط.';

  @override
  String updateAvailableSnackbar(String version) {
    return 'الإصدار $version متاح — افتح الإعدادات ‹ حول لتثبيته.';
  }

  @override
  String get setDocuments => 'المستندات';

  @override
  String get resetDatabaseTitle => 'إعادة تعيين قاعدة البيانات';

  @override
  String get resetDatabaseAction => 'إعادة تعيين قاعدة البيانات';

  @override
  String get resetWarningBanner =>
      'عملية مدمّرة. تحذف البيانات المحددة للشركة بأكملها — وستفقدها كل نقطة بيع عند المزامنة التالية. لا يمكن التراجع.';

  @override
  String get resetStepBackupTitle => 'مسار النسخ الاحتياطي';

  @override
  String get resetStepBackupSubtitle => 'الموقع الذي ستُحفظ فيه النسخة';

  @override
  String get resetStepBackupHint =>
      'تُأخذ نسخة من هذا الجهاز قبل إعادة التعيين. إذا فشلت، تُلغى العملية.';

  @override
  String get resetBackupManagedHint => 'تخزين التطبيق (هذا الجهاز)';

  @override
  String get resetStepEntitiesTitle => 'اختر العناصر';

  @override
  String get resetStepEntitiesSubtitle =>
      'ستُحذف العناصر المحددة من قاعدة البيانات';

  @override
  String get resetStepConfirmTitle => 'التأكيد';

  @override
  String get resetStepConfirmSubtitle => 'التفويض وتنفيذ إعادة التعيين';

  @override
  String get resetAdminPin => 'أدخل رمز المسؤول';

  @override
  String get resetAlsoClearsDocuments =>
      'يمسح أيضاً المستندات — سجلات البيع تشير إليها.';

  @override
  String get resetDocumentsNote =>
      'المبيعات والطلبات والمدفوعات والإلغاءات وتقارير Z. تُحفظ الحجوزات.';

  @override
  String get resetEverything => 'كل شيء';

  @override
  String get resetEverythingNote =>
      'كل بيانات الشركة. يُحتفظ بالمستخدمين والإعدادات.';

  @override
  String get resetWrongPin => 'رمز غير صحيح.';

  @override
  String get resetConfirmTitle => 'إعادة تعيين قاعدة البيانات؟';

  @override
  String get resetConfirmBody =>
      'يحذف هذا نهائياً البيانات المحددة لكل الشركة، على جميع الأجهزة. لا يمكن استرجاعها إلا من النسخة المحلية.';

  @override
  String get resetConfirmAction => 'نعم، أعد التعيين';

  @override
  String get resetNoCompany => 'لا توجد شركة محددة على هذا الجهاز.';

  @override
  String get resetPhaseBackup => 'جارٍ نسخ هذا الجهاز…';

  @override
  String get resetPhaseServer => 'جارٍ مسح بيانات الحساب…';

  @override
  String get resetPhaseLocal => 'جارٍ مسح هذا الجهاز…';

  @override
  String get resetDoneTitle => 'اكتملت إعادة التعيين';

  @override
  String get resetRestartManually => 'يرجى إغلاق التطبيق وإعادة فتحه.';

  @override
  String get resetOnlyAdmins => 'فقط المسؤولون يمكنهم إعادة التعيين.';

  @override
  String resetRestartingIn(int seconds) {
    return 'إعادة التشغيل خلال $seconds…';
  }

  @override
  String resetBackupSavedTo(String path) {
    return 'حُفظت النسخة في $path';
  }

  @override
  String get restoreDatabaseTitle => 'الاستعادة من نسخة احتياطية';

  @override
  String get restoreDatabaseAction => 'استعادة نسخة…';

  @override
  String get restoreDatabaseHint =>
      'يستبدل كل ما في هذا الجهاز بملف نسخة احتياطية. سيُعاد تشغيل التطبيق.';

  @override
  String get restorePickTitle => 'اختر ملف نسخة (.sqlite)';

  @override
  String get restoreRejectedTitle => 'تعذّرت استعادة هذا الملف';

  @override
  String get restoreConfirmTitle => 'استعادة هذه النسخة؟';

  @override
  String get restoreConfirmBody =>
      'سيُستبدل كل ما على هذا الجهاز بالنسخة. تُحفظ قاعدتك الحالية باسم pos_app.superseded.sqlite تحسّباً.';

  @override
  String get restoreConfirmAction => 'استعادة وإعادة تشغيل';

  @override
  String get restoreStagedTitle => 'النسخة جاهزة';

  @override
  String get restoreStagedBody =>
      'سيُعاد تشغيل التطبيق لتركيب قاعدة البيانات. سجّل الدخول بعدها — وسيُرفع العمل غير المتزامن عند المزامنة التالية.';

  @override
  String get restoreErrMissing => 'لم يعد الملف موجوداً.';

  @override
  String get restoreErrNotSqlite => 'هذا ليس ملف قاعدة بيانات.';

  @override
  String get restoreErrEncrypted =>
      'هذه النسخة مشفّرة لجهاز آخر ولا يمكن فتحها هنا. استعدها على الجهاز الذي أنشأها، أو ابدأ من جديد من السحابة.';

  @override
  String get restoreErrNotPosBackup => 'هذه قاعدة بيانات، لكنها ليست نسخة POS.';

  @override
  String restoreErrNewerSchema(int found, int supported) {
    return 'أُنشئت هذه النسخة بإصدار أحدث (قاعدة v$found، وهذا الإصدار يفهم v$supported). حدّث التطبيق أولاً.';
  }

  @override
  String get dbMissingTitle => 'لم يُعثر على قاعدة البيانات المحلية';

  @override
  String get dbMissingBody =>
      'ملف قاعدة بيانات هذا الجهاز مفقود — ربما حُذف أو نُقل أو على قرص غير متصل.\n\nالبدء من جديد يُنزّل بياناتك من السحابة، لكن ما لم يتزامن أبداً لا يمكن استرجاعه.';

  @override
  String get dbMissingRestore => 'استعادة من ملف نسخة';

  @override
  String get dbMissingFresh => 'البدء من جديد من السحابة';

  @override
  String get dbMissingFreshConfirm =>
      'البدء من جديد؟ سيُفقد كل ما لم يصل إلى السحابة.';

  @override
  String get onboardingDataTitle => 'إعداد هذا الجهاز';

  @override
  String get onboardingDataSubtitle => 'كيف يحصل هذا الجهاز على بياناته؟';

  @override
  String get onboardingCloudTitle => 'المزامنة مع السحابة';

  @override
  String get onboardingCloudBody =>
      'سجّل الدخول ونزّل بيانات شركتك. اختر هذا لجهاز جديد.';

  @override
  String get onboardingRestoreTitle => 'استعادة من نسخة';

  @override
  String get onboardingRestoreBody =>
      'استخدم نسخة .sqlite من جهاز آخر — لاستبدال جهاز، بما في ذلك العمل غير المتزامن.';

  @override
  String get balanceDue => 'الرصيد المستحق';

  @override
  String get telLabel => 'هاتف';

  @override
  String get itemsLabel => 'العناصر';

  @override
  String get timeLabel => 'الوقت';

  @override
  String get unitPriceLabel => 'سعر الوحدة';

  @override
  String get taxInvoiceUpper => 'فاتورة ضريبية';

  @override
  String get billTo => 'الفاتورة إلى';

  @override
  String get invoicesUpper => 'الفواتير';

  @override
  String get saveReceiptTitle => 'حفظ الإيصال';

  @override
  String get saveGuestCheckTitle => 'حفظ فاتورة الضيف';

  @override
  String get saveInvoicePdfTitle => 'حفظ الفاتورة PDF';

  @override
  String get zReportUpper => 'تقرير Z';

  @override
  String get endOfReport => '*** نهاية التقرير ***';

  @override
  String get totalQty => 'إجمالي الكمية';

  @override
  String get pointsBalance => 'رصيد النقاط';

  @override
  String get ptsShort => 'نقطة';

  @override
  String get invoiceNoLabel => 'رقم الفاتورة';

  @override
  String get pointsUsed => 'النقاط المستخدمة';

  @override
  String get paymentStatus => 'حالة الدفع';

  @override
  String pageNumberLabel(String number) {
    return 'صفحة $number';
  }

  @override
  String get createdWith => 'أُنشئت بواسطة';

  @override
  String get backupPathRequiredTitle => 'اختر مجلد النسخ الاحتياطي';

  @override
  String get backupPathRequiredBody =>
      'يحتاج النسخ الاحتياطي التلقائي إلى مجلد للكتابة فيه. اختر مجلدًا الآن، وإلا ستُحفظ النسخ في مكان لم تختره.';

  @override
  String get backupPathNotSet =>
      'يبقى النسخ الاحتياطي التلقائي متوقفًا حتى يتم تحديد مجلد.';

  @override
  String get posSession => 'جلسة نقطة البيع';

  @override
  String get sessionNoneTitle => 'لا توجد جلسة مفتوحة';

  @override
  String get sessionNoneBody =>
      'لم تبدأ هذه الصندوق العمل بعد. افتح جلسة لبدء اليوم.';

  @override
  String get openRegister => 'فتح الصندوق';

  @override
  String get continueSelling => 'متابعة البيع';

  @override
  String get sessionNumber => 'الجلسة';

  @override
  String get sessionDevice => 'الجهاز';

  @override
  String get sessionOpenedAt => 'فُتحت في';

  @override
  String get sessionOpenedBy => 'فتحها';

  @override
  String get sessionClosedBy => 'أغلقها';

  @override
  String get sessionStatusLabel => 'الحالة';

  @override
  String get sessionOpeningCash => 'النقد الافتتاحي';

  @override
  String get sessionExpectedCash => 'النقد المتوقع';

  @override
  String get sessionCountedCash => 'النقد المعدود';

  @override
  String get sessionDifference => 'الفرق';

  @override
  String get sessionOrders => 'الطلبات';

  @override
  String get sessionPaymentTotals => 'إجماليات الدفع';

  @override
  String get sessionSyncStatus => 'المزامنة';

  @override
  String get sessionSynced => 'تمت المزامنة';

  @override
  String get sessionNotSyncedYet => 'لم تُرسل إلى السحابة بعد';

  @override
  String sessionUnsyncedSales(int count) {
    return '$count عملية بيع ما زالت على هذا الجهاز';
  }

  @override
  String sessionOpenOrders(int count) {
    return '$count طلب ما زال معلقاً';
  }

  @override
  String get sessionCannotClose => 'لا يمكن الإغلاق بعد';

  @override
  String get sessionForceClosed => 'أُغلقت قسراً';

  @override
  String get sessionLateArrivals =>
      'وصلت مبيعات متأخرة بعد الإغلاق — تحتاج تسوية';

  @override
  String get sessionCashInferred =>
      'طرق النقد مستنتجة — حدّدها في الإعدادات ← الطلب والدفع.';

  @override
  String get sessionOpeningCashPrompt => 'كم المبلغ النقدي في الدرج للبدء؟';

  @override
  String get sessionHistory => 'سجل الجلسات';

  @override
  String get sessionNoHistory => 'لا توجد جلسات.';

  @override
  String get sessionConfirmOpening => 'تأكيد الافتتاح';

  @override
  String get sessionInProgress => 'قيد التنفيذ';

  @override
  String get sessionClosingControl => 'مراقبة الإغلاق';

  @override
  String get sessionClosedPosted => 'مغلقة ومُرحّلة';

  @override
  String get openingControl => 'مراقبة الافتتاح';

  @override
  String get openingNote => 'ملاحظة الافتتاح';

  @override
  String get openingNoteHint => 'أضف ملاحظة افتتاح…';

  @override
  String get closingRegister => 'إغلاق الصندوق';

  @override
  String get closingNote => 'ملاحظة الإغلاق';

  @override
  String get closingNoteHint => 'أضف ملاحظة إغلاق…';

  @override
  String sessionOrdersTotal(int count, String total) {
    return '$count مستندات: $total';
  }

  @override
  String get sessionExpected => 'المتوقع';

  @override
  String get sessionCounted => 'المعدود';

  @override
  String get sessionOpeningRow => 'الافتتاح';

  @override
  String get sessionCashInOutRow => 'إدخال / إخراج نقد';

  @override
  String get sessionCashPaymentsRow => 'مدفوعات نقدية';

  @override
  String get cashCount => 'عدّ النقد';

  @override
  String get dailySale => 'مبيعات اليوم';

  @override
  String get actionDiscard => 'تجاهل';

  @override
  String managerAuthRequired(String diff, String max) {
    return 'الفرق $diff يتجاوز الحد $max. مطلوب تصريح المدير.';
  }

  @override
  String get managerAuthorise => 'تصريح المدير';

  @override
  String get managerPinPrompt => 'أدخل رمز مدير للسماح بهذا الفرق.';

  @override
  String get managerPinWrong => 'هذا الرمز ليس رمز مدير.';

  @override
  String get sessionRequiredTitle => 'افتح الصندوق أولاً';

  @override
  String get sessionRequiredBody =>
      'المبيعات والمرتجعات وحركات النقد تتبع جلسة. افتح الصندوق لبدء العمل.';

  @override
  String get sessionNotTradingBody =>
      'يجري إغلاق هذا الصندوق. أكمل عملية العدّ ثم افتح جلسة جديدة.';

  @override
  String get setRequireOpenSession => 'اشترط جلسة مفتوحة للبيع';

  @override
  String get sessionsTitle => 'الجلسات';

  @override
  String get sessionColId => 'رقم الجلسة';

  @override
  String get sessionColPos => 'نقطة البيع';

  @override
  String get sessionColOpenedBy => 'فتحها';

  @override
  String get sessionColOpening => 'تاريخ الافتتاح';

  @override
  String get sessionColClosing => 'تاريخ الإغلاق';

  @override
  String get sessionColStarting => 'الرصيد الافتتاحي';

  @override
  String get sessionColEnding => 'الرصيد الختامي';

  @override
  String get sessionColTheoretical => 'الإغلاق النظري';

  @override
  String get sessionColStatus => 'الحالة';

  @override
  String get sessionSearchHint => 'بحث…';

  @override
  String sessionCountOf(int shown, int total) {
    return '$shown / $total';
  }

  @override
  String get sessionDetails => 'تفاصيل الجلسة';

  @override
  String get sessionCurrentOnThisDevice => 'الجلسة الحالية على هذا الجهاز';

  @override
  String get sessionClosedAt => 'أُغلقت في';

  @override
  String get sessionDuration => 'المدة';

  @override
  String get sessionTotalTaken => 'إجمالي المقبوض';

  @override
  String get sessionCashMovements => 'حركات النقد';

  @override
  String get sessionNotes => 'ملاحظات';

  @override
  String get cashDrawer => 'درج النقد';

  @override
  String get sessionRemoteFiguresOffline =>
      'هذه الجلسة تخص صندوقًا آخر — تُحمَّل مبالغها من الخادم.';

  @override
  String get sessionDocuments => 'المستندات';

  @override
  String get sessionOverviewTab => 'نظرة عامة';

  @override
  String get sessionPaymentsTab => 'المدفوعات';

  @override
  String get sessionNoPayments => 'لا توجد مدفوعات في هذه الجلسة بعد.';

  @override
  String get sessionNoDocuments => 'لا توجد مستندات في هذه الجلسة بعد.';

  @override
  String get sessionDocumentsHint => 'اضغط على مستند لفتحه';

  @override
  String get sessionOpenDocumentHint => 'اضغط على دفعة لفتح مستندها';

  @override
  String get sessionDocumentUnavailable =>
      'هذا المستند غير موجود على هذا الجهاز.';

  @override
  String get developerModeHint =>
      'يعرض زر تصحيح عائمًا على هذا الجهاز، مع محاكي باركود للسعر والوزن.';

  @override
  String get generateScaleBarcode => 'ملصق الميزان';

  @override
  String scaleBarcodeRuleUnusable(String pattern) {
    return 'القاعدة $pattern لا يمكنها توليد باركود منتج.';
  }

  @override
  String barcodeAlreadyUsedBy(String code, String product) {
    return '$code ينتمي بالفعل إلى $product.';
  }

  @override
  String get setPosSession => 'جلسة نقطة البيع';

  @override
  String get setCashMethods => 'طرق النقد';

  @override
  String get cashMethodsHint =>
      'طرق الدفع التي تخرج من درج النقد وتُعدّ يدويًا عند الإغلاق. إلغاء تحديدها جميعًا يعيد الاستنتاج التلقائي.';

  @override
  String get cashMethodsInferredHint =>
      'غير محددة — مستنتجة من «يسمح بإعادة الباقي».';

  @override
  String get cashMethodsConfirm => 'استخدم هذه';

  @override
  String get noPaymentMethodsDefined => 'لا توجد طرق دفع معرّفة.';

  @override
  String get setMaxCashDifference => 'فرق النقد المسموح';

  @override
  String get maxCashDifferenceHint =>
      'إذا تجاوزه الفرق، يتطلب الإغلاق رمز مسؤول.';
}
