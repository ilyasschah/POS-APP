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
  String get developerMode => 'وضع المطوّر';

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
  String get setDefaultSearch => 'البحث الافتراضي';

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
  String get setShowSearchOptions => 'إظهار خيارات البحث';

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
  String get enterQuantity => 'أدخل الكمية';

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
}
