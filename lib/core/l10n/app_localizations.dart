import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'مبتعث'**
  String get appTitle;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @seeAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get seeAll;

  /// No description provided for @liveNow.
  ///
  /// In ar, this message translates to:
  /// **'مباشر'**
  String get liveNow;

  /// No description provided for @comingSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريباً'**
  String get comingSoon;

  /// No description provided for @or.
  ///
  /// In ar, this message translates to:
  /// **'أو'**
  String get or;

  /// No description provided for @noResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج'**
  String get noResults;

  /// No description provided for @noResultsFor.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج لـ \"{query}\"'**
  String noResultsFor(String query);

  /// No description provided for @listeners.
  ///
  /// In ar, this message translates to:
  /// **'{count} مستمع'**
  String listeners(int count);

  /// No description provided for @roomsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} روم'**
  String roomsCount(int count);

  /// No description provided for @pageNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الصفحة غير موجودة'**
  String get pageNotFound;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navCommunity.
  ///
  /// In ar, this message translates to:
  /// **'المجتمع'**
  String get navCommunity;

  /// No description provided for @navPrayer.
  ///
  /// In ar, this message translates to:
  /// **'الصلاة'**
  String get navPrayer;

  /// No description provided for @navGuide.
  ///
  /// In ar, this message translates to:
  /// **'الدليل'**
  String get navGuide;

  /// No description provided for @greeting.
  ///
  /// In ar, this message translates to:
  /// **'هلا، {name} 👋'**
  String greeting(String name);

  /// No description provided for @studyingIn.
  ///
  /// In ar, this message translates to:
  /// **'مبتعث في {country}'**
  String studyingIn(String country);

  /// No description provided for @featuredRooms.
  ///
  /// In ar, this message translates to:
  /// **'أبرز الرومات الحالية'**
  String get featuredRooms;

  /// No description provided for @searchResults.
  ///
  /// In ar, this message translates to:
  /// **'نتائج البحث'**
  String get searchResults;

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث...'**
  String get searchHint;

  /// No description provided for @tryDifferentSearch.
  ///
  /// In ar, this message translates to:
  /// **'جرّب بحثاً مختلفاً'**
  String get tryDifferentSearch;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @loginTitle.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بعودتك'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل دخولك لاستمرار استعمال التطبيق'**
  String get loginSubtitle;

  /// No description provided for @register.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get register;

  /// No description provided for @registerTitle.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب جديد'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'انضم لمجتمع المبتعثين السعوديين'**
  String get registerSubtitle;

  /// No description provided for @registerEnterDetails.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بياناتك الاساسية'**
  String get registerEnterDetails;

  /// No description provided for @forgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تعيين كلمة المرور'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريدك الإلكتروني لإرسال\nرمز استعادة الحساب.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @email.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get email;

  /// No description provided for @emailHint.
  ///
  /// In ar, this message translates to:
  /// **'example@email.com'**
  String get emailHint;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get passwordHint;

  /// No description provided for @confirmPassword.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get confirmPassword;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In ar, this message translates to:
  /// **'أعد إدخال كلمة المرور'**
  String get confirmPasswordHint;

  /// No description provided for @fullName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل'**
  String get fullName;

  /// No description provided for @fullNameHint.
  ///
  /// In ar, this message translates to:
  /// **'اسمك الكامل'**
  String get fullNameHint;

  /// No description provided for @username.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get username;

  /// No description provided for @usernameHint.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get usernameHint;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الجوال'**
  String get phone;

  /// No description provided for @phoneHint.
  ///
  /// In ar, this message translates to:
  /// **'+966XXXXXXXXX'**
  String get phoneHint;

  /// No description provided for @send.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get send;

  /// No description provided for @sendCode.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرمز'**
  String get sendCode;

  /// No description provided for @sendResetLink.
  ///
  /// In ar, this message translates to:
  /// **'إرسال رابط الاسترداد'**
  String get sendResetLink;

  /// No description provided for @verify.
  ///
  /// In ar, this message translates to:
  /// **'تحقق'**
  String get verify;

  /// No description provided for @resendCode.
  ///
  /// In ar, this message translates to:
  /// **'إعادة ارسال الرمز'**
  String get resendCode;

  /// No description provided for @resendIn.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال بعد {seconds} ثانية'**
  String resendIn(int seconds);

  /// No description provided for @resendWithTimer.
  ///
  /// In ar, this message translates to:
  /// **'إعادة ارسال الرمز ( {timer} )'**
  String resendWithTimer(String timer);

  /// No description provided for @otpTitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز التحقق'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا رمز التحقق إلى {email}'**
  String otpSubtitle(String email);

  /// No description provided for @emailConfirmation.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد البريد الإلكتروني'**
  String get emailConfirmation;

  /// No description provided for @otpEnterCode.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز التحقق المرسل إلى'**
  String get otpEnterCode;

  /// No description provided for @newCodeSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رمز جديد إلى بريدك الإلكتروني'**
  String get newCodeSent;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب؟'**
  String get alreadyHaveAccount;

  /// No description provided for @alreadyHaveAccountFull.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب بالفعل؟ '**
  String get alreadyHaveAccountFull;

  /// No description provided for @dontHaveAccount.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟'**
  String get dontHaveAccount;

  /// No description provided for @orContinueWith.
  ///
  /// In ar, this message translates to:
  /// **'أو تابع عبر'**
  String get orContinueWith;

  /// No description provided for @signInWithGoogle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول عبر قوقل'**
  String get signInWithGoogle;

  /// No description provided for @signInWithApple.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول عبر آبل'**
  String get signInWithApple;

  /// No description provided for @iAgreeToThe.
  ///
  /// In ar, this message translates to:
  /// **'أوافق على '**
  String get iAgreeToThe;

  /// No description provided for @termsAndConditions.
  ///
  /// In ar, this message translates to:
  /// **'الشروط والأحكام'**
  String get termsAndConditions;

  /// No description provided for @andPrivacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **' وسياسة الخصوصية'**
  String get andPrivacyPolicy;

  /// No description provided for @agreeToTerms.
  ///
  /// In ar, this message translates to:
  /// **'أوافق على الشروط والأحكام'**
  String get agreeToTerms;

  /// No description provided for @privacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacyPolicy;

  /// No description provided for @legalPageLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحميل المحتوى، يرجى المحاولة مجدداً'**
  String get legalPageLoadError;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @resetSentTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم الإرسال!'**
  String get resetSentTitle;

  /// No description provided for @resetSentBodyPrefix.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رمز استعادة الحساب إلى'**
  String get resetSentBodyPrefix;

  /// No description provided for @checkInbox.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من صندوق البريد الوارد والبريد المزعج.'**
  String get checkInbox;

  /// No description provided for @backToLogin.
  ///
  /// In ar, this message translates to:
  /// **'العودة لتسجيل الدخول'**
  String get backToLogin;

  /// No description provided for @rememberPassword.
  ///
  /// In ar, this message translates to:
  /// **'تذكرتها؟'**
  String get rememberPassword;

  /// No description provided for @resetLinkExpiry.
  ///
  /// In ar, this message translates to:
  /// **'الرمز صالح لمدة 15 دقيقة فقط'**
  String get resetLinkExpiry;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعيين كلمة مرور جديدة'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز المُرسل إلى بريدك مع كلمة المرور الجديدة'**
  String get resetPasswordSubtitle;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور بنجاح، يمكنك تسجيل الدخول'**
  String get passwordResetSuccess;

  /// No description provided for @loginError.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو كلمة المرور غير صحيحة'**
  String get loginError;

  /// No description provided for @genericError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ، يرجى المحاولة مجدداً'**
  String get genericError;

  /// No description provided for @socialAuthError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تسجيل الدخول، حاول مرة أخرى'**
  String get socialAuthError;

  /// No description provided for @socialAuthTokenError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحقق من الحساب، حاول مرة أخرى'**
  String get socialAuthTokenError;

  /// No description provided for @completeYourProfile.
  ///
  /// In ar, this message translates to:
  /// **'أكمل ملفك الشخصي'**
  String get completeYourProfile;

  /// No description provided for @phoneRequiredForAccount.
  ///
  /// In ar, this message translates to:
  /// **'نحتاج رقم جوالك لإكمال إنشاء حسابك'**
  String get phoneRequiredForAccount;

  /// No description provided for @writeYourBio.
  ///
  /// In ar, this message translates to:
  /// **'اكتب نبذة عنك'**
  String get writeYourBio;

  /// No description provided for @bioPromptHint.
  ///
  /// In ar, this message translates to:
  /// **'هذه النبذة تظهر للآخرين في ملفك الشخصي، وتقدر تعدلها لاحقاً من الإعدادات'**
  String get bioPromptHint;

  /// No description provided for @bioPromptPlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'اكتب شيئاً عن نفسك...'**
  String get bioPromptPlaceholder;

  /// No description provided for @skipForNow.
  ///
  /// In ar, this message translates to:
  /// **'تخطي الآن'**
  String get skipForNow;

  /// No description provided for @saveBio.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get saveBio;

  /// No description provided for @invalidEmailError.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال بريد إلكتروني صحيح'**
  String get invalidEmailError;

  /// No description provided for @registerError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في الاتصال، يرجى المحاولة مجدداً'**
  String get registerError;

  /// No description provided for @otpIncompleteError.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال رمز التحقق كاملاً'**
  String get otpIncompleteError;

  /// No description provided for @otpInvalidError.
  ///
  /// In ar, this message translates to:
  /// **'رمز التحقق غير صحيح، يرجى المحاولة مجدداً'**
  String get otpInvalidError;

  /// No description provided for @otpResendError.
  ///
  /// In ar, this message translates to:
  /// **'فشل إعادة إرسال الرمز، حاول مرة أخرى'**
  String get otpResendError;

  /// No description provided for @validFullNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال الاسم الكامل'**
  String get validFullNameRequired;

  /// No description provided for @validFullNameMin.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل يجب أن يكون 3 أحرف على الأقل'**
  String get validFullNameMin;

  /// No description provided for @validFullNameFormat.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال اسم حقيقي (الاسم الأول والأخير، بحروف فقط)'**
  String get validFullNameFormat;

  /// No description provided for @validUsernameRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال اسم المستخدم'**
  String get validUsernameRequired;

  /// No description provided for @validUsernameMin.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم يجب أن يكون 3 أحرف على الأقل'**
  String get validUsernameMin;

  /// No description provided for @validUsernameFormat.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم يجب أن يبدأ بحرف ويحتوي على حروف إنجليزية أو أرقام أو _ فقط'**
  String get validUsernameFormat;

  /// No description provided for @validPhoneRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال رقم الجوال'**
  String get validPhoneRequired;

  /// No description provided for @validPhoneInvalid.
  ///
  /// In ar, this message translates to:
  /// **'رقم الجوال غير صحيح لهذه الدولة'**
  String get validPhoneInvalid;

  /// No description provided for @validPhoneCountryRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار رمز الدولة'**
  String get validPhoneCountryRequired;

  /// No description provided for @validEmailRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال البريد الالكتروني'**
  String get validEmailRequired;

  /// No description provided for @validEmailInvalid.
  ///
  /// In ar, this message translates to:
  /// **'صيغة البريد الالكتروني غير صحيحة'**
  String get validEmailInvalid;

  /// No description provided for @validEmailDisposable.
  ///
  /// In ar, this message translates to:
  /// **'يرجى استخدام بريد إلكتروني حقيقي وليس مؤقتاً'**
  String get validEmailDisposable;

  /// No description provided for @validPasswordRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال كلمة المرور'**
  String get validPasswordRequired;

  /// No description provided for @validPasswordMin.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور يجب أن تكون 8 أحرف على الأقل'**
  String get validPasswordMin;

  /// No description provided for @validPasswordWeak.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور يجب أن تحتوي على حرف كبير وحرف صغير ورقم على الأقل'**
  String get validPasswordWeak;

  /// No description provided for @validConfirmPasswordRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تأكيد كلمة المرور'**
  String get validConfirmPasswordRequired;

  /// No description provided for @validPasswordMismatch.
  ///
  /// In ar, this message translates to:
  /// **'كلمتا المرور غير متطابقتين'**
  String get validPasswordMismatch;

  /// No description provided for @validTermsRequired.
  ///
  /// In ar, this message translates to:
  /// **'يجب الموافقة على الشروط والأحكام للمتابعة'**
  String get validTermsRequired;

  /// No description provided for @homeSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن رومات ونقاشات...'**
  String get homeSearchHint;

  /// No description provided for @communityTitle.
  ///
  /// In ar, this message translates to:
  /// **'مجتمع {countryName}'**
  String communityTitle(String countryName);

  /// No description provided for @communitySearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن الرومات الصوتية...'**
  String get communitySearchHint;

  /// No description provided for @filterAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get filterAll;

  /// No description provided for @filterAcademic.
  ///
  /// In ar, this message translates to:
  /// **'أكاديمي'**
  String get filterAcademic;

  /// No description provided for @filterSocial.
  ///
  /// In ar, this message translates to:
  /// **'اجتماعي'**
  String get filterSocial;

  /// No description provided for @filterLegal.
  ///
  /// In ar, this message translates to:
  /// **'قانوني'**
  String get filterLegal;

  /// No description provided for @filterCultural.
  ///
  /// In ar, this message translates to:
  /// **'ثقافي'**
  String get filterCultural;

  /// No description provided for @noRoomsAvailable.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد روم متاحة حالياً'**
  String get noRoomsAvailable;

  /// No description provided for @noActiveRoomsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد غرف نشطة حالياً'**
  String get noActiveRoomsTitle;

  /// No description provided for @noActiveRoomsHint.
  ///
  /// In ar, this message translates to:
  /// **'جميع الغرف مغلقة الآن. تابعنا — ستُفتح غرف جديدة قريباً، أو أنشئ غرفتك.'**
  String get noActiveRoomsHint;

  /// No description provided for @notificationsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notificationsTitle;

  /// No description provided for @markAllRead.
  ///
  /// In ar, this message translates to:
  /// **'تحديد الكل مقروء'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات'**
  String get noNotifications;

  /// No description provided for @noNotificationsSub.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر إشعاراتك هنا عند وصولها'**
  String get noNotificationsSub;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get yesterday;

  /// No description provided for @earlier.
  ///
  /// In ar, this message translates to:
  /// **'سابقاً'**
  String get earlier;

  /// No description provided for @timeNow.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get timeNow;

  /// No description provided for @minutesAgo.
  ///
  /// In ar, this message translates to:
  /// **'منذ {count} د'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In ar, this message translates to:
  /// **'منذ {count} س'**
  String hoursAgo(int count);

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// No description provided for @appLanguage.
  ///
  /// In ar, this message translates to:
  /// **'لغة التطبيق'**
  String get appLanguage;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In ar, this message translates to:
  /// **'الإنجليزية'**
  String get english;

  /// No description provided for @help.
  ///
  /// In ar, this message translates to:
  /// **'مساعدة'**
  String get help;

  /// No description provided for @aboutApp.
  ///
  /// In ar, this message translates to:
  /// **'عن التطبيق'**
  String get aboutApp;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد أنك تريد تسجيل الخروج؟'**
  String get logoutConfirmBody;

  /// No description provided for @logoutConfirm.
  ///
  /// In ar, this message translates to:
  /// **'خروج'**
  String get logoutConfirm;

  /// No description provided for @deleteAccount.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد حذف الحساب نهائياً'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'تحذير: هذا الإجراء سيقوم بحذف حسابك وكافة بياناتك المسجلة في منصة مبتعث بشكل نهائي ولا يمكن التراجع عنه. هل أنت متأكد؟'**
  String get deleteAccountConfirmBody;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In ar, this message translates to:
  /// **'حذف نهائي'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حذف الحساب، يرجى المحاولة مجدداً'**
  String get deleteAccountError;

  /// No description provided for @appVersion.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار'**
  String get appVersion;

  /// No description provided for @prayerTimesTitle.
  ///
  /// In ar, this message translates to:
  /// **'أوقات الصلاة'**
  String get prayerTimesTitle;

  /// No description provided for @fajr.
  ///
  /// In ar, this message translates to:
  /// **'الفجر'**
  String get fajr;

  /// No description provided for @sunrise.
  ///
  /// In ar, this message translates to:
  /// **'الشروق'**
  String get sunrise;

  /// No description provided for @dhuhr.
  ///
  /// In ar, this message translates to:
  /// **'الظهر'**
  String get dhuhr;

  /// No description provided for @asr.
  ///
  /// In ar, this message translates to:
  /// **'العصر'**
  String get asr;

  /// No description provided for @maghrib.
  ///
  /// In ar, this message translates to:
  /// **'المغرب'**
  String get maghrib;

  /// No description provided for @isha.
  ///
  /// In ar, this message translates to:
  /// **'العشاء'**
  String get isha;

  /// No description provided for @nextPrayer.
  ///
  /// In ar, this message translates to:
  /// **'الصلاة القادمة'**
  String get nextPrayer;

  /// No description provided for @prayerTimeNow.
  ///
  /// In ar, this message translates to:
  /// **'حان الآن وقت صلاة {prayer}'**
  String prayerTimeNow(String prayer);

  /// No description provided for @elapsedSincePrayer.
  ///
  /// In ar, this message translates to:
  /// **'مضى على أذان {prayer}'**
  String elapsedSincePrayer(String prayer);

  /// No description provided for @prayerNotifOn.
  ///
  /// In ar, this message translates to:
  /// **'تم تفعيل إشعارات مواقيت الصلاة'**
  String get prayerNotifOn;

  /// No description provided for @prayerNotifOff.
  ///
  /// In ar, this message translates to:
  /// **'تم إيقاف إشعارات مواقيت الصلاة'**
  String get prayerNotifOff;

  /// No description provided for @prayerNotifBlocked.
  ///
  /// In ar, this message translates to:
  /// **'فعّل الإشعارات من إعدادات الجهاز للتذكير بالمواقيت'**
  String get prayerNotifBlocked;

  /// No description provided for @prayerNotifTooltip.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات مواقيت الصلاة (اضغط مطولاً للتجربة)'**
  String get prayerNotifTooltip;

  /// No description provided for @prayerNotifLocationError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحديد موقعك، حاول تحديث الصفحة قبل تفعيل الإشعارات'**
  String get prayerNotifLocationError;

  /// No description provided for @prayerNotifTestTitle.
  ///
  /// In ar, this message translates to:
  /// **'🕌 مبتعث — مواقيت الصلاة'**
  String get prayerNotifTestTitle;

  /// No description provided for @prayerNotifTestBody.
  ///
  /// In ar, this message translates to:
  /// **'هذا إشعار تجريبي. جرّبه في الخلفية خلال ١٢ ثانية.'**
  String get prayerNotifTestBody;

  /// No description provided for @prayerNotifTestSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال إشعار تجريبي ✓'**
  String get prayerNotifTestSent;

  /// No description provided for @timeRemaining.
  ///
  /// In ar, this message translates to:
  /// **'الوقت المتبقي'**
  String get timeRemaining;

  /// No description provided for @loadingLocation.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحديد الموقع...'**
  String get loadingLocation;

  /// No description provided for @locationError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديد الموقع'**
  String get locationError;

  /// No description provided for @qiblaDirection.
  ///
  /// In ar, this message translates to:
  /// **'اتجاه القبلة'**
  String get qiblaDirection;

  /// No description provided for @kaabaDirection.
  ///
  /// In ar, this message translates to:
  /// **'اتجاه الكعبة المشرفة'**
  String get kaabaDirection;

  /// No description provided for @knowKaabaDirection.
  ///
  /// In ar, this message translates to:
  /// **'اعرف اتجاه الكعبة المشرفة'**
  String get knowKaabaDirection;

  /// No description provided for @fromNorth.
  ///
  /// In ar, this message translates to:
  /// **'من الشمال'**
  String get fromNorth;

  /// No description provided for @timePeriodAm.
  ///
  /// In ar, this message translates to:
  /// **'ص'**
  String get timePeriodAm;

  /// No description provided for @timePeriodPm.
  ///
  /// In ar, this message translates to:
  /// **'م'**
  String get timePeriodPm;

  /// No description provided for @qiblaTitle.
  ///
  /// In ar, this message translates to:
  /// **'القبلة'**
  String get qiblaTitle;

  /// No description provided for @pointToKaaba.
  ///
  /// In ar, this message translates to:
  /// **'وجّه الجهاز نحو القبلة'**
  String get pointToKaaba;

  /// No description provided for @liveCompass.
  ///
  /// In ar, this message translates to:
  /// **'البوصلة الحية'**
  String get liveCompass;

  /// No description provided for @compassInstruction.
  ///
  /// In ar, this message translates to:
  /// **'وجّه هاتفك حتى يشير المؤشر نحو الكعبة المشرفة'**
  String get compassInstruction;

  /// No description provided for @directionLabel.
  ///
  /// In ar, this message translates to:
  /// **'الاتجاه'**
  String get directionLabel;

  /// No description provided for @qiblaLabel.
  ///
  /// In ar, this message translates to:
  /// **'القبلة'**
  String get qiblaLabel;

  /// No description provided for @facingQibla.
  ///
  /// In ar, this message translates to:
  /// **'أنت تواجه القبلة'**
  String get facingQibla;

  /// No description provided for @calibrating.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ المعايرة...'**
  String get calibrating;

  /// No description provided for @compassNeedsCalibration.
  ///
  /// In ar, this message translates to:
  /// **'البوصلة غير مستقرة'**
  String get compassNeedsCalibration;

  /// No description provided for @compassCalibrationHint.
  ///
  /// In ar, this message translates to:
  /// **'حرّك جوالك على شكل رقم ٨ عدة مرات لمعايرة البوصلة'**
  String get compassCalibrationHint;

  /// No description provided for @gotIt.
  ///
  /// In ar, this message translates to:
  /// **'تمام'**
  String get gotIt;

  /// No description provided for @degreeFromNorth.
  ///
  /// In ar, this message translates to:
  /// **'{degree}° من الشمال'**
  String degreeFromNorth(String degree);

  /// No description provided for @locationPermissionMsg.
  ///
  /// In ar, this message translates to:
  /// **'يرجى منح إذن الموقع من إعدادات الجهاز'**
  String get locationPermissionMsg;

  /// No description provided for @openSettings.
  ///
  /// In ar, this message translates to:
  /// **'فتح الإعدادات'**
  String get openSettings;

  /// No description provided for @howToUse.
  ///
  /// In ar, this message translates to:
  /// **'كيفية الاستخدام'**
  String get howToUse;

  /// No description provided for @qiblaInstructions.
  ///
  /// In ar, this message translates to:
  /// **'• أمسك هاتفك أفقياً على سطح مستوٍ\n• ابتعد عن المعادن والإلكترونيات\n• المؤشر يشير إلى اتجاه القبلة'**
  String get qiblaInstructions;

  /// No description provided for @staticCompassNote.
  ///
  /// In ar, this message translates to:
  /// **'اتجاه القبلة (حسابي)'**
  String get staticCompassNote;

  /// No description provided for @prayersComplete.
  ///
  /// In ar, this message translates to:
  /// **'أُكمِلت صلوات اليوم'**
  String get prayersComplete;

  /// No description provided for @studentGuideTitle.
  ///
  /// In ar, this message translates to:
  /// **'دليل الطالب'**
  String get studentGuideTitle;

  /// No description provided for @studentGuideSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في الدليل...'**
  String get studentGuideSearchHint;

  /// No description provided for @linksCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} روابط'**
  String linksCount(int count);

  /// No description provided for @itemsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} عناصر'**
  String itemsCount(int count);

  /// No description provided for @studentTipLabel.
  ///
  /// In ar, this message translates to:
  /// **'نصيحة المبتعث'**
  String get studentTipLabel;

  /// No description provided for @studentTipBody.
  ///
  /// In ar, this message translates to:
  /// **'احتفظ دائماً بنسخة من جواز سفرك وبيانات السفارة في هاتفك'**
  String get studentTipBody;

  /// No description provided for @resultsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} نتيجة'**
  String resultsCount(int count);

  /// No description provided for @mainSections.
  ///
  /// In ar, this message translates to:
  /// **'الأقسام الرئيسية'**
  String get mainSections;

  /// No description provided for @guideCategoryEmbassy.
  ///
  /// In ar, this message translates to:
  /// **'السفارة والقنصليات'**
  String get guideCategoryEmbassy;

  /// No description provided for @guideCategoryEmergency.
  ///
  /// In ar, this message translates to:
  /// **'خدمات الطوارئ'**
  String get guideCategoryEmergency;

  /// No description provided for @guideCategoryLegal.
  ///
  /// In ar, this message translates to:
  /// **'الدعم القانوني'**
  String get guideCategoryLegal;

  /// No description provided for @guideCategoryHousing.
  ///
  /// In ar, this message translates to:
  /// **'دليل السكن'**
  String get guideCategoryHousing;

  /// No description provided for @guideCategoryHealth.
  ///
  /// In ar, this message translates to:
  /// **'التأمين الصحي'**
  String get guideCategoryHealth;

  /// No description provided for @guideCategoryTransport.
  ///
  /// In ar, this message translates to:
  /// **'المواصلات'**
  String get guideCategoryTransport;

  /// No description provided for @profileTitle.
  ///
  /// In ar, this message translates to:
  /// **'الملف الشخصي'**
  String get profileTitle;

  /// No description provided for @editProfile.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف'**
  String get editProfile;

  /// No description provided for @saveChanges.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التغييرات'**
  String get saveChanges;

  /// No description provided for @savedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get savedSuccess;

  /// No description provided for @saveError.
  ///
  /// In ar, this message translates to:
  /// **'فشل حفظ البيانات، حاول مجدداً'**
  String get saveError;

  /// No description provided for @selectCountry.
  ///
  /// In ar, this message translates to:
  /// **'اختر الدولة'**
  String get selectCountry;

  /// No description provided for @selectYourCountry.
  ///
  /// In ar, this message translates to:
  /// **'اختر دولتك'**
  String get selectYourCountry;

  /// No description provided for @selectCountrySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'لنتمكن من تجهيز الخدمات المناسبة لك'**
  String get selectCountrySubtitle;

  /// No description provided for @countrySelected.
  ///
  /// In ar, this message translates to:
  /// **'تم اختيار {country}'**
  String countrySelected(String country);

  /// No description provided for @continueButton.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get continueButton;

  /// No description provided for @fieldBio.
  ///
  /// In ar, this message translates to:
  /// **'النبذة'**
  String get fieldBio;

  /// No description provided for @noBio.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نبذة'**
  String get noBio;

  /// No description provided for @fieldFullName.
  ///
  /// In ar, this message translates to:
  /// **'الأسم الكامل'**
  String get fieldFullName;

  /// No description provided for @fieldCountry.
  ///
  /// In ar, this message translates to:
  /// **'الدولة'**
  String get fieldCountry;

  /// No description provided for @changePassword.
  ///
  /// In ar, this message translates to:
  /// **'تغيير كلمة المرور'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الحالية'**
  String get currentPassword;

  /// No description provided for @currentPasswordHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة مرورك الحالية'**
  String get currentPasswordHint;

  /// No description provided for @newPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الجديدة'**
  String get newPassword;

  /// No description provided for @newPasswordHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة مرور جديدة'**
  String get newPasswordHint;

  /// No description provided for @speakerRole.
  ///
  /// In ar, this message translates to:
  /// **'متحدث'**
  String get speakerRole;

  /// No description provided for @speakersCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} متحدثين'**
  String speakersCount(int count);

  /// No description provided for @roomDescription.
  ///
  /// In ar, this message translates to:
  /// **'وصف الروم'**
  String get roomDescription;

  /// No description provided for @speakersLabel.
  ///
  /// In ar, this message translates to:
  /// **'المتحدثين'**
  String get speakersLabel;

  /// No description provided for @joinRoom.
  ///
  /// In ar, this message translates to:
  /// **'الانضمام'**
  String get joinRoom;

  /// No description provided for @moreSpeakers.
  ///
  /// In ar, this message translates to:
  /// **'+ {count} متحدثين آخرين'**
  String moreSpeakers(int count);

  /// No description provided for @chatTab.
  ///
  /// In ar, this message translates to:
  /// **'الشات'**
  String get chatTab;

  /// No description provided for @messagePlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالتك...'**
  String get messagePlaceholder;

  /// No description provided for @liveRoomBadge.
  ///
  /// In ar, this message translates to:
  /// **'روم مباشر'**
  String get liveRoomBadge;

  /// No description provided for @listenersNow.
  ///
  /// In ar, this message translates to:
  /// **'{count} مستمع الآن'**
  String listenersNow(int count);

  /// No description provided for @mubtaathTitle.
  ///
  /// In ar, this message translates to:
  /// **'مبتعث'**
  String get mubtaathTitle;

  /// No description provided for @mubtaathTagline.
  ///
  /// In ar, this message translates to:
  /// **'المجتمع الصوتي للمبتعثين السعوديين'**
  String get mubtaathTagline;

  /// No description provided for @microphonePermissionRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى منح إذن الميكروفون للمتابعة'**
  String get microphonePermissionRequired;

  /// No description provided for @participants.
  ///
  /// In ar, this message translates to:
  /// **'المشاركون'**
  String get participants;

  /// No description provided for @connecting.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الاتصال...'**
  String get connecting;

  /// No description provided for @connected.
  ///
  /// In ar, this message translates to:
  /// **'متصل'**
  String get connected;

  /// No description provided for @audioConnectionError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بالصوت'**
  String get audioConnectionError;

  /// No description provided for @agoraConnectivityWarning.
  ///
  /// In ar, this message translates to:
  /// **'تحذير الاتصال الصوتي'**
  String get agoraConnectivityWarning;

  /// No description provided for @agoraConnectivityWarningBody.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر بدء الصوت. اتصال الصوت غير متاح حالياً.'**
  String get agoraConnectivityWarningBody;

  /// No description provided for @noParticipantsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد مشاركون بعد'**
  String get noParticipantsYet;

  /// No description provided for @tapMicToSpeak.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على الميكروفون للتحدث'**
  String get tapMicToSpeak;

  /// No description provided for @leaveRoom.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة الروم'**
  String get leaveRoom;

  /// No description provided for @leaveRoomConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة الروم؟'**
  String get leaveRoomConfirmTitle;

  /// No description provided for @leaveRoomConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد أنك تبي تخرج من الروم؟'**
  String get leaveRoomConfirmBody;

  /// No description provided for @leaveRoomConfirmYes.
  ///
  /// In ar, this message translates to:
  /// **'نعم، خروج'**
  String get leaveRoomConfirmYes;

  /// No description provided for @stayInRoom.
  ///
  /// In ar, this message translates to:
  /// **'البقاء'**
  String get stayInRoom;

  /// No description provided for @audioOutput.
  ///
  /// In ar, this message translates to:
  /// **'مخرج الصوت'**
  String get audioOutput;

  /// No description provided for @audioOutputSpeaker.
  ///
  /// In ar, this message translates to:
  /// **'السماعة الخارجية'**
  String get audioOutputSpeaker;

  /// No description provided for @audioOutputEarpiece.
  ///
  /// In ar, this message translates to:
  /// **'سماعة الأذن'**
  String get audioOutputEarpiece;

  /// No description provided for @helpAndSupport.
  ///
  /// In ar, this message translates to:
  /// **'المساعدة والدعم'**
  String get helpAndSupport;

  /// No description provided for @contactSupport.
  ///
  /// In ar, this message translates to:
  /// **'تواصل مع الدعم'**
  String get contactSupport;

  /// No description provided for @contactSupportSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج مساعدة قبل تسجيل الدخول؟ راسلنا وسنرد عليك عبر البريد الإلكتروني'**
  String get contactSupportSubtitle;

  /// No description provided for @yourEmail.
  ///
  /// In ar, this message translates to:
  /// **'بريدك الإلكتروني'**
  String get yourEmail;

  /// No description provided for @yourMessage.
  ///
  /// In ar, this message translates to:
  /// **'رسالتك'**
  String get yourMessage;

  /// No description provided for @describeYourIssue.
  ///
  /// In ar, this message translates to:
  /// **'اكتب ما تحتاج المساعدة فيه...'**
  String get describeYourIssue;

  /// No description provided for @sendMessage.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرسالة'**
  String get sendMessage;

  /// No description provided for @contactMessageSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رسالتك، سنتواصل معك قريباً'**
  String get contactMessageSent;

  /// No description provided for @reportUser.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن مستخدم'**
  String get reportUser;

  /// No description provided for @reportMessage.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن رسالة'**
  String get reportMessage;

  /// No description provided for @reportCategory.
  ///
  /// In ar, this message translates to:
  /// **'فئة البلاغ'**
  String get reportCategory;

  /// No description provided for @categoryTechnical.
  ///
  /// In ar, this message translates to:
  /// **'مشكلة تقنية'**
  String get categoryTechnical;

  /// No description provided for @categorySuggestion.
  ///
  /// In ar, this message translates to:
  /// **'اقتراح'**
  String get categorySuggestion;

  /// No description provided for @categoryComplaint.
  ///
  /// In ar, this message translates to:
  /// **'شكوى'**
  String get categoryComplaint;

  /// No description provided for @categoryInappropriate.
  ///
  /// In ar, this message translates to:
  /// **'سلوك غير لائق'**
  String get categoryInappropriate;

  /// No description provided for @categorySpam.
  ///
  /// In ar, this message translates to:
  /// **'إزعاج أو سبام'**
  String get categorySpam;

  /// No description provided for @describeIssue.
  ///
  /// In ar, this message translates to:
  /// **'وصف المشكلة'**
  String get describeIssue;

  /// No description provided for @describeIssueHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب تفاصيل المشكلة...'**
  String get describeIssueHint;

  /// No description provided for @submitReport.
  ///
  /// In ar, this message translates to:
  /// **'إرسال البلاغ'**
  String get submitReport;

  /// No description provided for @reportSubmittedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال البلاغ'**
  String get reportSubmittedTitle;

  /// No description provided for @reportSubmittedBody.
  ///
  /// In ar, this message translates to:
  /// **'شكراً، سنراجع البلاغ في أقرب وقت ممكن'**
  String get reportSubmittedBody;

  /// No description provided for @reportingUser.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن مستخدم'**
  String get reportingUser;

  /// No description provided for @reportingMessage.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن رسالة'**
  String get reportingMessage;

  /// No description provided for @selectCategory.
  ///
  /// In ar, this message translates to:
  /// **'اختر الفئة'**
  String get selectCategory;

  /// No description provided for @descriptionRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى كتابة وصف للمشكلة'**
  String get descriptionRequired;

  /// No description provided for @categoryRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار فئة'**
  String get categoryRequired;

  /// No description provided for @reportSentSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال البلاغ بنجاح'**
  String get reportSentSuccess;

  /// No description provided for @reportSentError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إرسال البلاغ، يرجى المحاولة مجدداً'**
  String get reportSentError;

  /// No description provided for @viewProfile.
  ///
  /// In ar, this message translates to:
  /// **'الدخول للملف الشخصي'**
  String get viewProfile;

  /// No description provided for @userProfile.
  ///
  /// In ar, this message translates to:
  /// **'الملف الشخصي'**
  String get userProfile;

  /// No description provided for @newReport.
  ///
  /// In ar, this message translates to:
  /// **'بلاغ جديد'**
  String get newReport;

  /// No description provided for @myReports.
  ///
  /// In ar, this message translates to:
  /// **'بلاغاتي'**
  String get myReports;

  /// No description provided for @statusPending.
  ///
  /// In ar, this message translates to:
  /// **'قيد الانتظار'**
  String get statusPending;

  /// No description provided for @statusResolved.
  ///
  /// In ar, this message translates to:
  /// **'تم الحل'**
  String get statusResolved;

  /// No description provided for @statusDismissed.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get statusDismissed;

  /// No description provided for @statusUnderReview.
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get statusUnderReview;

  /// No description provided for @adminReply.
  ///
  /// In ar, this message translates to:
  /// **'رد المشرف'**
  String get adminReply;

  /// No description provided for @noReportsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بلاغات بعد'**
  String get noReportsYet;

  /// No description provided for @noReportsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر بلاغاتك هنا بعد إرسالها'**
  String get noReportsSubtitle;

  /// No description provided for @ticketDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل التذكرة'**
  String get ticketDetails;

  /// No description provided for @yourIssue.
  ///
  /// In ar, this message translates to:
  /// **'مشكلتك'**
  String get yourIssue;

  /// No description provided for @yourReply.
  ///
  /// In ar, this message translates to:
  /// **'ردك'**
  String get yourReply;

  /// No description provided for @replyToAdmin.
  ///
  /// In ar, this message translates to:
  /// **'الرد على المشرف'**
  String get replyToAdmin;

  /// No description provided for @replySentSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال ردك بنجاح'**
  String get replySentSuccess;

  /// No description provided for @conversationThread.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة'**
  String get conversationThread;

  /// No description provided for @noMessagesYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رسائل بعد'**
  String get noMessagesYet;

  /// No description provided for @tryAgain.
  ///
  /// In ar, this message translates to:
  /// **'حاول مجدداً'**
  String get tryAgain;

  /// No description provided for @floatingMessages.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل العائمة'**
  String get floatingMessages;

  /// No description provided for @navBarStyle.
  ///
  /// In ar, this message translates to:
  /// **'شكل شريط التنقل'**
  String get navBarStyle;

  /// No description provided for @navStyleLiquid.
  ///
  /// In ar, this message translates to:
  /// **'شريط عائم (زجاجي)'**
  String get navStyleLiquid;

  /// No description provided for @navStyleClassic.
  ///
  /// In ar, this message translates to:
  /// **'شريط كلاسيكي'**
  String get navStyleClassic;

  /// No description provided for @kickedFromRoom.
  ///
  /// In ar, this message translates to:
  /// **'تمّ إخراجك من الغرفة'**
  String get kickedFromRoom;

  /// No description provided for @kickedFromRoomBody.
  ///
  /// In ar, this message translates to:
  /// **'قام المشرف بإزالتك من هذه الغرفة.'**
  String get kickedFromRoomBody;

  /// No description provided for @tempBannedFromRoom.
  ///
  /// In ar, this message translates to:
  /// **'حظر مؤقت'**
  String get tempBannedFromRoom;

  /// No description provided for @tempBannedFromRoomBody.
  ///
  /// In ar, this message translates to:
  /// **'تمّ حظرك مؤقتاً عن هذه الغرفة.'**
  String get tempBannedFromRoomBody;

  /// No description provided for @attendeesLabel.
  ///
  /// In ar, this message translates to:
  /// **'الحضور'**
  String get attendeesLabel;

  /// No description provided for @attendeesCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} حاضر'**
  String attendeesCount(int count);

  /// No description provided for @moreAttendees.
  ///
  /// In ar, this message translates to:
  /// **'+{count} آخرين'**
  String moreAttendees(int count);

  /// No description provided for @attendeesNow.
  ///
  /// In ar, this message translates to:
  /// **'{count} يستمعون الآن'**
  String attendeesNow(int count);

  /// No description provided for @noAttendeesYet.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد أحد هنا الآن'**
  String get noAttendeesYet;

  /// No description provided for @moderatorBadge.
  ///
  /// In ar, this message translates to:
  /// **'مشرف'**
  String get moderatorBadge;

  /// No description provided for @ghostModeEnabled.
  ///
  /// In ar, this message translates to:
  /// **'وضع التخفي مفعّل — أنت غير مرئي في الغرفة'**
  String get ghostModeEnabled;

  /// No description provided for @ghostModeDisabled.
  ///
  /// In ar, this message translates to:
  /// **'وضع التخفي ملغى — أنت ظاهر في الغرفة'**
  String get ghostModeDisabled;

  /// No description provided for @loudspeaker.
  ///
  /// In ar, this message translates to:
  /// **'مكبر الصوت'**
  String get loudspeaker;

  /// No description provided for @earpiece.
  ///
  /// In ar, this message translates to:
  /// **'السماعة العلوية للهاتف'**
  String get earpiece;

  /// No description provided for @roomFull.
  ///
  /// In ar, this message translates to:
  /// **'عذراً، وصلت الغرفة للحد الأقصى من الحضور'**
  String get roomFull;
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
      <String>['ar', 'en'].contains(locale.languageCode);

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
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
