// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'مبتعث';

  @override
  String get back => 'رجوع';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get liveNow => 'مباشر';

  @override
  String get comingSoon => 'قريباً';

  @override
  String get or => 'أو';

  @override
  String get noResults => 'لا توجد نتائج';

  @override
  String noResultsFor(String query) {
    return 'لا توجد نتائج لـ \"$query\"';
  }

  @override
  String listeners(int count) {
    return '$count مستمع';
  }

  @override
  String roomsCount(int count) {
    return '$count روم';
  }

  @override
  String get pageNotFound => 'الصفحة غير موجودة';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navCommunity => 'المجتمع';

  @override
  String get navPrayer => 'الصلاة';

  @override
  String get navGuide => 'الدليل';

  @override
  String greeting(String name) {
    return 'هلا، $name 👋';
  }

  @override
  String studyingIn(String country) {
    return 'مبتعث في $country';
  }

  @override
  String get featuredRooms => 'أبرز الرومات الحالية';

  @override
  String get searchResults => 'نتائج البحث';

  @override
  String get searchHint => 'ابحث...';

  @override
  String get tryDifferentSearch => 'جرّب بحثاً مختلفاً';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get loginTitle => 'مرحباً بعودتك';

  @override
  String get loginSubtitle => 'سجّل دخولك لاستمرار استعمال التطبيق';

  @override
  String get register => 'إنشاء حساب';

  @override
  String get registerTitle => 'إنشاء حساب جديد';

  @override
  String get registerSubtitle => 'انضم لمجتمع المبتعثين السعوديين';

  @override
  String get registerEnterDetails => 'أدخل بياناتك الاساسية';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get forgotPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotPasswordSubtitle =>
      'أدخل بريدك الإلكتروني لإرسال\nرمز استعادة الحساب.';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get emailHint => 'example@email.com';

  @override
  String get password => 'كلمة المرور';

  @override
  String get passwordHint => 'كلمة المرور';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get confirmPasswordHint => 'أعد إدخال كلمة المرور';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get fullNameHint => 'اسمك الكامل';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get usernameHint => 'اسم المستخدم';

  @override
  String get phone => 'رقم الجوال';

  @override
  String get phoneHint => '+966XXXXXXXXX';

  @override
  String get send => 'إرسال';

  @override
  String get sendCode => 'إرسال الرمز';

  @override
  String get sendResetLink => 'إرسال رابط الاسترداد';

  @override
  String get verify => 'تحقق';

  @override
  String get resendCode => 'إعادة ارسال الرمز';

  @override
  String resendIn(int seconds) {
    return 'إعادة الإرسال بعد $seconds ثانية';
  }

  @override
  String resendWithTimer(String timer) {
    return 'إعادة ارسال الرمز ( $timer )';
  }

  @override
  String get otpTitle => 'أدخل رمز التحقق';

  @override
  String otpSubtitle(String email) {
    return 'أرسلنا رمز التحقق إلى $email';
  }

  @override
  String get emailConfirmation => 'تأكيد البريد الإلكتروني';

  @override
  String get otpEnterCode => 'أدخل رمز التحقق المرسل إلى';

  @override
  String get newCodeSent => 'تم إرسال رمز جديد إلى بريدك الإلكتروني';

  @override
  String get alreadyHaveAccount => 'لديك حساب؟';

  @override
  String get alreadyHaveAccountFull => 'لديك حساب بالفعل؟ ';

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟';

  @override
  String get orContinueWith => 'أو تابع عبر';

  @override
  String get signInWithGoogle => 'تسجيل الدخول عبر قوقل';

  @override
  String get iAgreeToThe => 'أوافق على ';

  @override
  String get termsAndConditions => 'الشروط والأحكام';

  @override
  String get andPrivacyPolicy => ' وسياسة الخصوصية';

  @override
  String get agreeToTerms => 'أوافق على الشروط والأحكام';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get legalPageLoadError => 'تعذر تحميل المحتوى، يرجى المحاولة مجدداً';

  @override
  String get cancel => 'إلغاء';

  @override
  String get confirm => 'تأكيد';

  @override
  String get resetSentTitle => 'تم الإرسال!';

  @override
  String get resetSentBodyPrefix => 'تم إرسال رمز استعادة الحساب إلى';

  @override
  String get checkInbox => 'تحقق من صندوق البريد الوارد والبريد المزعج.';

  @override
  String get backToLogin => 'العودة لتسجيل الدخول';

  @override
  String get rememberPassword => 'تذكرتها؟';

  @override
  String get resetLinkExpiry => 'الرمز صالح لمدة 15 دقيقة فقط';

  @override
  String get resetPasswordTitle => 'تعيين كلمة مرور جديدة';

  @override
  String get resetPasswordSubtitle =>
      'أدخل الرمز المُرسل إلى بريدك مع كلمة المرور الجديدة';

  @override
  String get passwordResetSuccess =>
      'تم تغيير كلمة المرور بنجاح، يمكنك تسجيل الدخول';

  @override
  String get loginError => 'البريد الإلكتروني أو كلمة المرور غير صحيحة';

  @override
  String get genericError => 'حدث خطأ، يرجى المحاولة مجدداً';

  @override
  String get invalidEmailError => 'يرجى إدخال بريد إلكتروني صحيح';

  @override
  String get registerError => 'حدث خطأ في الاتصال، يرجى المحاولة مجدداً';

  @override
  String get otpIncompleteError => 'يرجى إدخال رمز التحقق كاملاً';

  @override
  String get otpInvalidError => 'رمز التحقق غير صحيح، يرجى المحاولة مجدداً';

  @override
  String get otpResendError => 'فشل إعادة إرسال الرمز، حاول مرة أخرى';

  @override
  String get validFullNameRequired => 'يرجى إدخال الاسم الكامل';

  @override
  String get validFullNameMin => 'الاسم الكامل يجب أن يكون 3 أحرف على الأقل';

  @override
  String get validFullNameFormat =>
      'يرجى إدخال اسم حقيقي (الاسم الأول والأخير، بحروف فقط)';

  @override
  String get validUsernameRequired => 'يرجى إدخال اسم المستخدم';

  @override
  String get validUsernameMin => 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';

  @override
  String get validUsernameFormat =>
      'اسم المستخدم يجب أن يبدأ بحرف ويحتوي على حروف إنجليزية أو أرقام أو _ فقط';

  @override
  String get validPhoneRequired => 'يرجى إدخال رقم الجوال';

  @override
  String get validPhoneInvalid => 'رقم الجوال غير صحيح لهذه الدولة';

  @override
  String get validPhoneCountryRequired => 'يرجى اختيار رمز الدولة';

  @override
  String get validEmailRequired => 'يرجى إدخال البريد الالكتروني';

  @override
  String get validEmailInvalid => 'صيغة البريد الالكتروني غير صحيحة';

  @override
  String get validEmailDisposable =>
      'يرجى استخدام بريد إلكتروني حقيقي وليس مؤقتاً';

  @override
  String get validPasswordRequired => 'يرجى إدخال كلمة المرور';

  @override
  String get validPasswordMin => 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';

  @override
  String get validPasswordWeak =>
      'كلمة المرور يجب أن تحتوي على حرف كبير وحرف صغير ورقم على الأقل';

  @override
  String get validConfirmPasswordRequired => 'يرجى تأكيد كلمة المرور';

  @override
  String get validPasswordMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get validTermsRequired => 'يجب الموافقة على الشروط والأحكام للمتابعة';

  @override
  String get homeSearchHint => 'ابحث عن رومات ونقاشات...';

  @override
  String communityTitle(String countryName) {
    return 'مجتمع $countryName';
  }

  @override
  String get communitySearchHint => 'ابحث عن الرومات الصوتية...';

  @override
  String get filterAll => 'الكل';

  @override
  String get filterAcademic => 'أكاديمي';

  @override
  String get filterSocial => 'اجتماعي';

  @override
  String get filterLegal => 'قانوني';

  @override
  String get filterCultural => 'ثقافي';

  @override
  String get noRoomsAvailable => 'لا توجد روم متاحة حالياً';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get markAllRead => 'تحديد الكل مقروء';

  @override
  String get noNotifications => 'لا توجد إشعارات';

  @override
  String get noNotificationsSub => 'ستظهر إشعاراتك هنا عند وصولها';

  @override
  String get today => 'اليوم';

  @override
  String get yesterday => 'أمس';

  @override
  String get earlier => 'سابقاً';

  @override
  String get timeNow => 'الآن';

  @override
  String minutesAgo(int count) {
    return 'منذ $count د';
  }

  @override
  String hoursAgo(int count) {
    return 'منذ $count س';
  }

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get appLanguage => 'لغة التطبيق';

  @override
  String get language => 'اللغة';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'الإنجليزية';

  @override
  String get help => 'مساعدة';

  @override
  String get aboutApp => 'عن التطبيق';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get logoutConfirmTitle => 'تسجيل الخروج';

  @override
  String get logoutConfirmBody => 'هل أنت متأكد أنك تريد تسجيل الخروج؟';

  @override
  String get logoutConfirm => 'خروج';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get deleteAccountConfirmTitle => 'تأكيد حذف الحساب نهائياً';

  @override
  String get deleteAccountConfirmBody =>
      'تحذير: هذا الإجراء سيقوم بحذف حسابك وكافة بياناتك المسجلة في منصة مبتعث بشكل نهائي ولا يمكن التراجع عنه. هل أنت متأكد؟';

  @override
  String get deleteAccountConfirm => 'حذف نهائي';

  @override
  String get deleteAccountError => 'تعذّر حذف الحساب، يرجى المحاولة مجدداً';

  @override
  String get appVersion => 'الإصدار';

  @override
  String get prayerTimesTitle => 'أوقات الصلاة';

  @override
  String get fajr => 'الفجر';

  @override
  String get sunrise => 'الشروق';

  @override
  String get dhuhr => 'الظهر';

  @override
  String get asr => 'العصر';

  @override
  String get maghrib => 'المغرب';

  @override
  String get isha => 'العشاء';

  @override
  String get nextPrayer => 'الصلاة القادمة';

  @override
  String prayerTimeNow(String prayer) {
    return 'حان الآن وقت صلاة $prayer';
  }

  @override
  String elapsedSincePrayer(String prayer) {
    return 'مضى على أذان $prayer';
  }

  @override
  String get prayerNotifOn => 'تم تفعيل إشعارات مواقيت الصلاة';

  @override
  String get prayerNotifOff => 'تم إيقاف إشعارات مواقيت الصلاة';

  @override
  String get prayerNotifBlocked =>
      'فعّل الإشعارات من إعدادات الجهاز للتذكير بالمواقيت';

  @override
  String get prayerNotifTooltip =>
      'إشعارات مواقيت الصلاة (اضغط مطولاً للتجربة)';

  @override
  String get prayerNotifLocationError =>
      'تعذر تحديد موقعك، حاول تحديث الصفحة قبل تفعيل الإشعارات';

  @override
  String get prayerNotifTestTitle => '🕌 مبتعث — مواقيت الصلاة';

  @override
  String get prayerNotifTestBody =>
      'هذا إشعار تجريبي. جرّبه في الخلفية خلال ١٢ ثانية.';

  @override
  String get prayerNotifTestSent => 'تم إرسال إشعار تجريبي ✓';

  @override
  String get timeRemaining => 'الوقت المتبقي';

  @override
  String get loadingLocation => 'جارٍ تحديد الموقع...';

  @override
  String get locationError => 'تعذّر تحديد الموقع';

  @override
  String get qiblaDirection => 'اتجاه القبلة';

  @override
  String get kaabaDirection => 'اتجاه الكعبة المشرفة';

  @override
  String get knowKaabaDirection => 'اعرف اتجاه الكعبة المشرفة';

  @override
  String get fromNorth => 'من الشمال';

  @override
  String get timePeriodAm => 'ص';

  @override
  String get timePeriodPm => 'م';

  @override
  String get qiblaTitle => 'القبلة';

  @override
  String get pointToKaaba => 'وجّه الجهاز نحو القبلة';

  @override
  String get liveCompass => 'البوصلة الحية';

  @override
  String get compassInstruction =>
      'وجّه هاتفك حتى يشير المؤشر نحو الكعبة المشرفة';

  @override
  String get directionLabel => 'الاتجاه';

  @override
  String get qiblaLabel => 'القبلة';

  @override
  String get facingQibla => 'أنت تواجه القبلة';

  @override
  String get calibrating => 'جارٍ المعايرة...';

  @override
  String get compassNeedsCalibration => 'البوصلة غير مستقرة';

  @override
  String get compassCalibrationHint =>
      'حرّك جوالك على شكل رقم ٨ عدة مرات لمعايرة البوصلة';

  @override
  String get gotIt => 'تمام';

  @override
  String degreeFromNorth(String degree) {
    return '$degree° من الشمال';
  }

  @override
  String get locationPermissionMsg => 'يرجى منح إذن الموقع من إعدادات الجهاز';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get howToUse => 'كيفية الاستخدام';

  @override
  String get qiblaInstructions =>
      '• أمسك هاتفك أفقياً على سطح مستوٍ\n• ابتعد عن المعادن والإلكترونيات\n• المؤشر يشير إلى اتجاه القبلة';

  @override
  String get staticCompassNote => 'اتجاه القبلة (حسابي)';

  @override
  String get prayersComplete => 'أُكمِلت صلوات اليوم';

  @override
  String get studentGuideTitle => 'دليل الطالب';

  @override
  String get studentGuideSearchHint => 'ابحث في الدليل...';

  @override
  String linksCount(int count) {
    return '$count روابط';
  }

  @override
  String itemsCount(int count) {
    return '$count عناصر';
  }

  @override
  String get studentTipLabel => 'نصيحة المبتعث';

  @override
  String get studentTipBody =>
      'احتفظ دائماً بنسخة من جواز سفرك وبيانات السفارة في هاتفك';

  @override
  String resultsCount(int count) {
    return '$count نتيجة';
  }

  @override
  String get mainSections => 'الأقسام الرئيسية';

  @override
  String get guideCategoryEmbassy => 'السفارة والقنصليات';

  @override
  String get guideCategoryEmergency => 'خدمات الطوارئ';

  @override
  String get guideCategoryLegal => 'الدعم القانوني';

  @override
  String get guideCategoryHousing => 'دليل السكن';

  @override
  String get guideCategoryHealth => 'التأمين الصحي';

  @override
  String get guideCategoryTransport => 'المواصلات';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get editProfile => 'تعديل الملف';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get savedSuccess => 'تم الحفظ';

  @override
  String get saveError => 'فشل حفظ البيانات، حاول مجدداً';

  @override
  String get selectCountry => 'اختر الدولة';

  @override
  String get selectYourCountry => 'اختر دولتك';

  @override
  String get selectCountrySubtitle => 'لنتمكن من تجهيز الخدمات المناسبة لك';

  @override
  String countrySelected(String country) {
    return 'تم اختيار $country';
  }

  @override
  String get continueButton => 'متابعة';

  @override
  String get fieldBio => 'النبذة';

  @override
  String get noBio => 'لا توجد نبذة';

  @override
  String get fieldFullName => 'الأسم الكامل';

  @override
  String get fieldCountry => 'الدولة';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get currentPasswordHint => 'أدخل كلمة مرورك الحالية';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get newPasswordHint => 'أدخل كلمة مرور جديدة';

  @override
  String get speakerRole => 'متحدث';

  @override
  String speakersCount(int count) {
    return '$count متحدثين';
  }

  @override
  String get roomDescription => 'وصف الروم';

  @override
  String get speakersLabel => 'المتحدثين';

  @override
  String get joinRoom => 'الانضمام';

  @override
  String moreSpeakers(int count) {
    return '+ $count متحدثين آخرين';
  }

  @override
  String get chatTab => 'الشات';

  @override
  String get messagePlaceholder => 'اكتب رسالتك...';

  @override
  String get liveRoomBadge => 'روم مباشر';

  @override
  String listenersNow(int count) {
    return '$count مستمع الآن';
  }

  @override
  String get mubtaathTitle => 'مبتعث';

  @override
  String get mubtaathTagline => 'المجتمع الصوتي للمبتعثين السعوديين';

  @override
  String get microphonePermissionRequired => 'يرجى منح إذن الميكروفون للمتابعة';

  @override
  String get participants => 'المشاركون';

  @override
  String get connecting => 'جارٍ الاتصال...';

  @override
  String get connected => 'متصل';

  @override
  String get audioConnectionError => 'تعذّر الاتصال بالصوت';

  @override
  String get agoraConnectivityWarning => 'تحذير الاتصال الصوتي';

  @override
  String get agoraConnectivityWarningBody =>
      'تعذّر بدء الصوت. اتصال الصوت غير متاح حالياً.';

  @override
  String get noParticipantsYet => 'لا يوجد مشاركون بعد';

  @override
  String get tapMicToSpeak => 'اضغط على الميكروفون للتحدث';

  @override
  String get leaveRoom => 'مغادرة الروم';

  @override
  String get audioOutput => 'مخرج الصوت';

  @override
  String get audioOutputSpeaker => 'السماعة الخارجية';

  @override
  String get audioOutputEarpiece => 'سماعة الأذن';

  @override
  String get helpAndSupport => 'المساعدة والدعم';

  @override
  String get reportUser => 'الإبلاغ عن مستخدم';

  @override
  String get reportMessage => 'الإبلاغ عن رسالة';

  @override
  String get reportCategory => 'فئة البلاغ';

  @override
  String get categoryTechnical => 'مشكلة تقنية';

  @override
  String get categorySuggestion => 'اقتراح';

  @override
  String get categoryComplaint => 'شكوى';

  @override
  String get categoryInappropriate => 'سلوك غير لائق';

  @override
  String get categorySpam => 'إزعاج أو سبام';

  @override
  String get describeIssue => 'وصف المشكلة';

  @override
  String get describeIssueHint => 'اكتب تفاصيل المشكلة...';

  @override
  String get submitReport => 'إرسال البلاغ';

  @override
  String get reportSubmittedTitle => 'تم إرسال البلاغ';

  @override
  String get reportSubmittedBody => 'شكراً، سنراجع البلاغ في أقرب وقت ممكن';

  @override
  String get reportingUser => 'الإبلاغ عن مستخدم';

  @override
  String get reportingMessage => 'الإبلاغ عن رسالة';

  @override
  String get selectCategory => 'اختر الفئة';

  @override
  String get descriptionRequired => 'يرجى كتابة وصف للمشكلة';

  @override
  String get categoryRequired => 'يرجى اختيار فئة';

  @override
  String get reportSentSuccess => 'تم إرسال البلاغ بنجاح';

  @override
  String get reportSentError => 'تعذّر إرسال البلاغ، يرجى المحاولة مجدداً';

  @override
  String get viewProfile => 'الدخول للملف الشخصي';

  @override
  String get userProfile => 'الملف الشخصي';

  @override
  String get newReport => 'بلاغ جديد';

  @override
  String get myReports => 'بلاغاتي';

  @override
  String get statusPending => 'قيد الانتظار';

  @override
  String get statusResolved => 'تم الحل';

  @override
  String get statusDismissed => 'مرفوض';

  @override
  String get statusUnderReview => 'قيد المراجعة';

  @override
  String get adminReply => 'رد المشرف';

  @override
  String get noReportsYet => 'لا توجد بلاغات بعد';

  @override
  String get noReportsSubtitle => 'ستظهر بلاغاتك هنا بعد إرسالها';

  @override
  String get ticketDetails => 'تفاصيل التذكرة';

  @override
  String get yourIssue => 'مشكلتك';

  @override
  String get yourReply => 'ردك';

  @override
  String get replyToAdmin => 'الرد على المشرف';

  @override
  String get replySentSuccess => 'تم إرسال ردك بنجاح';

  @override
  String get conversationThread => 'المحادثة';

  @override
  String get noMessagesYet => 'لا توجد رسائل بعد';

  @override
  String get tryAgain => 'حاول مجدداً';

  @override
  String get floatingMessages => 'الرسائل العائمة';

  @override
  String get navBarStyle => 'شكل شريط التنقل';

  @override
  String get navStyleLiquid => 'شريط عائم (زجاجي)';

  @override
  String get navStyleClassic => 'شريط كلاسيكي';

  @override
  String get kickedFromRoom => 'تمّ إخراجك من الغرفة';

  @override
  String get kickedFromRoomBody => 'قام المشرف بإزالتك من هذه الغرفة.';

  @override
  String get tempBannedFromRoom => 'حظر مؤقت';

  @override
  String get tempBannedFromRoomBody => 'تمّ حظرك مؤقتاً عن هذه الغرفة.';

  @override
  String get attendeesLabel => 'الحضور';

  @override
  String attendeesCount(int count) {
    return '$count حاضر';
  }

  @override
  String moreAttendees(int count) {
    return '+$count آخرين';
  }

  @override
  String attendeesNow(int count) {
    return '$count يستمعون الآن';
  }

  @override
  String get noAttendeesYet => 'لا يوجد أحد هنا الآن';

  @override
  String get moderatorBadge => 'مشرف';

  @override
  String get ghostModeEnabled => 'وضع التخفي مفعّل — أنت غير مرئي في الغرفة';

  @override
  String get ghostModeDisabled => 'وضع التخفي ملغى — أنت ظاهر في الغرفة';

  @override
  String get loudspeaker => 'مكبر الصوت';

  @override
  String get earpiece => 'السماعة العلوية للهاتف';

  @override
  String get roomFull => 'عذراً، وصلت الغرفة للحد الأقصى من الحضور';
}
