// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mubtaath';

  @override
  String get back => 'Back';

  @override
  String get seeAll => 'See all';

  @override
  String get liveNow => 'Live';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get or => 'or';

  @override
  String get noResults => 'No results';

  @override
  String noResultsFor(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String listeners(int count) {
    return '$count listener';
  }

  @override
  String roomsCount(int count) {
    return '$count room';
  }

  @override
  String get pageNotFound => 'Page not found';

  @override
  String get navHome => 'Home';

  @override
  String get navCommunity => 'Community';

  @override
  String get navPrayer => 'Prayer';

  @override
  String get navGuide => 'Guide';

  @override
  String greeting(String name) {
    return 'Hey, $name 👋';
  }

  @override
  String studyingIn(String country) {
    return 'Studying in $country';
  }

  @override
  String get featuredRooms => 'Featured Rooms';

  @override
  String get searchResults => 'Search Results';

  @override
  String get tryDifferentSearch => 'Try a different search';

  @override
  String get login => 'Login';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to continue using the app';

  @override
  String get register => 'Register';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerSubtitle => 'Join the Saudi student community';

  @override
  String get registerEnterDetails => 'Enter your basic information';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get forgotPasswordTitle => 'Reset password';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your email to receive an account recovery code.';

  @override
  String get email => 'Email';

  @override
  String get emailHint => 'example@email.com';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get confirmPasswordHint => 'Re-enter your password';

  @override
  String get fullName => 'Full name';

  @override
  String get fullNameHint => 'Your full name';

  @override
  String get username => 'Username';

  @override
  String get usernameHint => 'Username';

  @override
  String get phone => 'Phone number';

  @override
  String get phoneHint => '+966XXXXXXXXX';

  @override
  String get send => 'Send';

  @override
  String get sendCode => 'Send Code';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get verify => 'Verify';

  @override
  String get resendCode => 'Resend code';

  @override
  String resendIn(int seconds) {
    return 'Resend in $seconds seconds';
  }

  @override
  String resendWithTimer(String timer) {
    return 'Resend code ( $timer )';
  }

  @override
  String get otpTitle => 'Enter verification code';

  @override
  String otpSubtitle(String email) {
    return 'We sent a verification code to $email';
  }

  @override
  String get emailConfirmation => 'Email Confirmation';

  @override
  String get otpEnterCode => 'Enter the verification code sent to';

  @override
  String get newCodeSent => 'A new code has been sent to your email';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get alreadyHaveAccountFull => 'Already have an account? ';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get orContinueWith => 'Or continue with';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get iAgreeToThe => 'I agree to the ';

  @override
  String get termsAndConditions => 'Terms and Conditions';

  @override
  String get andPrivacyPolicy => ' and Privacy Policy';

  @override
  String get agreeToTerms => 'I agree to the terms and conditions';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get legalPageLoadError =>
      'Couldn\'t load the content, please try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get resetSentTitle => 'Sent!';

  @override
  String get resetSentBodyPrefix => 'Account recovery code sent to';

  @override
  String get checkInbox => 'Check your inbox and spam folder.';

  @override
  String get backToLogin => 'Back to login';

  @override
  String get rememberPassword => 'Remember it?';

  @override
  String get resetLinkExpiry => 'The code is valid for 15 minutes only';

  @override
  String get resetPasswordTitle => 'Set a new password';

  @override
  String get resetPasswordSubtitle =>
      'Enter the code sent to your email and your new password';

  @override
  String get passwordResetSuccess =>
      'Your password has been changed, you can sign in now';

  @override
  String get loginError => 'Email or password is incorrect';

  @override
  String get genericError => 'An error occurred, please try again';

  @override
  String get invalidEmailError => 'Please enter a valid email address';

  @override
  String get registerError => 'A connection error occurred, please try again';

  @override
  String get otpIncompleteError =>
      'Please enter the complete verification code';

  @override
  String get otpInvalidError => 'Invalid verification code, please try again';

  @override
  String get otpResendError => 'Failed to resend code, please try again';

  @override
  String get validFullNameRequired => 'Please enter your full name';

  @override
  String get validFullNameMin => 'Full name must be at least 3 characters';

  @override
  String get validUsernameRequired => 'Please enter a username';

  @override
  String get validUsernameMin => 'Username must be at least 3 characters';

  @override
  String get validPhoneRequired => 'Please enter your phone number';

  @override
  String get validPhoneInvalid => 'Invalid phone number';

  @override
  String get validEmailRequired => 'Please enter your email address';

  @override
  String get validEmailInvalid => 'Invalid email format';

  @override
  String get validPasswordRequired => 'Please enter a password';

  @override
  String get validPasswordMin => 'Password must be at least 8 characters';

  @override
  String get validConfirmPasswordRequired => 'Please confirm your password';

  @override
  String get validPasswordMismatch => 'Passwords do not match';

  @override
  String get validTermsRequired =>
      'You must agree to the terms and conditions to continue';

  @override
  String get homeSearchHint => 'Search rooms and discussions...';

  @override
  String communityTitle(String countryName) {
    return '$countryName Community';
  }

  @override
  String get communitySearchHint => 'Search voice rooms...';

  @override
  String get filterAll => 'All';

  @override
  String get filterAcademic => 'Academic';

  @override
  String get filterSocial => 'Social';

  @override
  String get filterLegal => 'Legal';

  @override
  String get filterCultural => 'Cultural';

  @override
  String get noRoomsAvailable => 'No rooms available';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get noNotificationsSub => 'Your notifications will appear here';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get earlier => 'Earlier';

  @override
  String get timeNow => 'Now';

  @override
  String minutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appLanguage => 'App language';

  @override
  String get language => 'Language';

  @override
  String get arabic => 'Arabic';

  @override
  String get english => 'English';

  @override
  String get help => 'Help';

  @override
  String get aboutApp => 'About app';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirmTitle => 'Logout';

  @override
  String get logoutConfirmBody => 'Are you sure you want to logout?';

  @override
  String get logoutConfirm => 'Logout';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountConfirmTitle => 'Confirm permanent account deletion';

  @override
  String get deleteAccountConfirmBody =>
      'Warning: This action will permanently delete your account and all your data registered on the Mubtaath platform, and it cannot be undone. Are you sure?';

  @override
  String get deleteAccountConfirm => 'Delete permanently';

  @override
  String get deleteAccountError => 'Failed to delete account, please try again';

  @override
  String get appVersion => 'Version';

  @override
  String get prayerTimesTitle => 'Prayer Times';

  @override
  String get fajr => 'Fajr';

  @override
  String get sunrise => 'Sunrise';

  @override
  String get dhuhr => 'Dhuhr';

  @override
  String get asr => 'Asr';

  @override
  String get maghrib => 'Maghrib';

  @override
  String get isha => 'Isha';

  @override
  String get nextPrayer => 'Next prayer';

  @override
  String prayerTimeNow(String prayer) {
    return 'It\'s now time for $prayer prayer';
  }

  @override
  String elapsedSincePrayer(String prayer) {
    return 'Time since $prayer adhan';
  }

  @override
  String get prayerNotifOn => 'Prayer-time notifications enabled';

  @override
  String get prayerNotifOff => 'Prayer-time notifications turned off';

  @override
  String get prayerNotifBlocked =>
      'Enable notifications in device settings to get prayer reminders';

  @override
  String get prayerNotifTooltip =>
      'Prayer-time notifications (long-press to test)';

  @override
  String get prayerNotifLocationError =>
      'Couldn\'t determine your location — try refreshing before enabling notifications';

  @override
  String get prayerNotifTestTitle => '🕌 Mubtaath — Prayer times';

  @override
  String get prayerNotifTestBody =>
      'This is a test notification. Try it in the background within 12 seconds.';

  @override
  String get prayerNotifTestSent => 'Test notification sent ✓';

  @override
  String get timeRemaining => 'Time remaining';

  @override
  String get loadingLocation => 'Getting location...';

  @override
  String get locationError => 'Could not get location';

  @override
  String get qiblaDirection => 'Qibla direction';

  @override
  String get kaabaDirection => 'Kaaba direction';

  @override
  String get knowKaabaDirection => 'Find the Kaaba direction';

  @override
  String get fromNorth => 'from north';

  @override
  String get timePeriodAm => 'AM';

  @override
  String get timePeriodPm => 'PM';

  @override
  String get qiblaTitle => 'Qibla';

  @override
  String get pointToKaaba => 'Point the device toward the Qibla';

  @override
  String get liveCompass => 'Live Compass';

  @override
  String get compassInstruction =>
      'Point your phone until the pointer points toward the Kaaba';

  @override
  String get directionLabel => 'Direction';

  @override
  String get qiblaLabel => 'Qibla';

  @override
  String get facingQibla => 'You are facing the Qibla';

  @override
  String get calibrating => 'Calibrating...';

  @override
  String get compassNeedsCalibration => 'Compass is unstable';

  @override
  String get compassCalibrationHint =>
      'Move your phone in a figure-8 motion a few times to calibrate the compass';

  @override
  String degreeFromNorth(String degree) {
    return '$degree° from north';
  }

  @override
  String get locationPermissionMsg =>
      'Please grant location permission in device settings';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get howToUse => 'How to Use';

  @override
  String get qiblaInstructions =>
      '• Hold your phone flat on a level surface\n• Stay away from metals and electronics\n• The pointer points toward the Qibla';

  @override
  String get staticCompassNote => 'Qibla direction (calculated)';

  @override
  String get prayersComplete => 'Today\'s prayers complete';

  @override
  String get studentGuideTitle => 'Student Guide';

  @override
  String get studentGuideSearchHint => 'Search the guide...';

  @override
  String linksCount(int count) {
    return '$count links';
  }

  @override
  String itemsCount(int count) {
    return '$count items';
  }

  @override
  String get studentTipLabel => 'Student Tip';

  @override
  String get studentTipBody =>
      'Always keep a copy of your passport and embassy details on your phone';

  @override
  String resultsCount(int count) {
    return '$count results';
  }

  @override
  String get mainSections => 'Main Sections';

  @override
  String get guideCategoryEmbassy => 'Embassy & Consulates';

  @override
  String get guideCategoryEmergency => 'Emergency Services';

  @override
  String get guideCategoryLegal => 'Legal Support';

  @override
  String get guideCategoryHousing => 'Housing Guide';

  @override
  String get guideCategoryHealth => 'Health Insurance';

  @override
  String get guideCategoryTransport => 'Transport';

  @override
  String get profileTitle => 'Profile';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get savedSuccess => 'Saved';

  @override
  String get saveError => 'Failed to save, please try again';

  @override
  String get selectCountry => 'Select country';

  @override
  String get selectYourCountry => 'Select your country';

  @override
  String get selectCountrySubtitle =>
      'So we can prepare the right services for you';

  @override
  String countrySelected(String country) {
    return '$country selected';
  }

  @override
  String get continueButton => 'Continue';

  @override
  String get fieldBio => 'About';

  @override
  String get noBio => 'No bio provided';

  @override
  String get fieldFullName => 'Full name';

  @override
  String get fieldCountry => 'Country';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get currentPasswordHint => 'Enter your current password';

  @override
  String get newPassword => 'New password';

  @override
  String get newPasswordHint => 'Enter a new password';

  @override
  String get speakerRole => 'Speaker';

  @override
  String speakersCount(int count) {
    return '$count speakers';
  }

  @override
  String get roomDescription => 'Room Description';

  @override
  String get speakersLabel => 'Speakers';

  @override
  String get joinRoom => 'Join';

  @override
  String moreSpeakers(int count) {
    return '+ $count more speakers';
  }

  @override
  String get chatTab => 'Chat';

  @override
  String get messagePlaceholder => 'Type your message...';

  @override
  String get liveRoomBadge => 'Live Room';

  @override
  String listenersNow(int count) {
    return '$count listening now';
  }

  @override
  String get mubtaathTitle => 'Mubtaath';

  @override
  String get mubtaathTagline => 'The voice community for Saudi students abroad';

  @override
  String get microphonePermissionRequired =>
      'Please grant microphone permission to continue';

  @override
  String get participants => 'Participants';

  @override
  String get connecting => 'Connecting...';

  @override
  String get connected => 'Connected';

  @override
  String get audioConnectionError => 'Failed to connect audio';

  @override
  String get agoraConnectivityWarning => 'Connectivity Warning';

  @override
  String get agoraConnectivityWarningBody =>
      'Audio could not start. The voice connection is unavailable.';

  @override
  String get noParticipantsYet => 'No participants yet';

  @override
  String get tapMicToSpeak => 'Tap the mic to speak';

  @override
  String get leaveRoom => 'Leave room';

  @override
  String get audioOutput => 'Audio Output';

  @override
  String get audioOutputSpeaker => 'Speaker';

  @override
  String get audioOutputEarpiece => 'Earpiece';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get reportUser => 'Report User';

  @override
  String get reportMessage => 'Report Message';

  @override
  String get reportCategory => 'Report Category';

  @override
  String get categoryTechnical => 'Technical Issue';

  @override
  String get categorySuggestion => 'Suggestion';

  @override
  String get categoryComplaint => 'Complaint';

  @override
  String get categoryInappropriate => 'Inappropriate Behavior';

  @override
  String get categorySpam => 'Spam or Harassment';

  @override
  String get describeIssue => 'Describe the Issue';

  @override
  String get describeIssueHint => 'Write the details of your issue...';

  @override
  String get submitReport => 'Submit Report';

  @override
  String get reportSubmittedTitle => 'Report Submitted';

  @override
  String get reportSubmittedBody =>
      'Thank you, we will review your report as soon as possible';

  @override
  String get reportingUser => 'Reporting User';

  @override
  String get reportingMessage => 'Reporting Message';

  @override
  String get selectCategory => 'Select Category';

  @override
  String get descriptionRequired => 'Please describe the issue';

  @override
  String get categoryRequired => 'Please select a category';

  @override
  String get reportSentSuccess => 'Report sent successfully';

  @override
  String get reportSentError => 'Failed to send report, please try again';

  @override
  String get viewProfile => 'View Profile';

  @override
  String get userProfile => 'User Profile';

  @override
  String get newReport => 'New Report';

  @override
  String get myReports => 'My Reports';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusResolved => 'Resolved';

  @override
  String get statusDismissed => 'Dismissed';

  @override
  String get statusUnderReview => 'Under Review';

  @override
  String get adminReply => 'Admin Reply';

  @override
  String get noReportsYet => 'No reports yet';

  @override
  String get noReportsSubtitle => 'Your submitted reports will appear here';

  @override
  String get ticketDetails => 'Ticket Details';

  @override
  String get yourIssue => 'Your Issue';

  @override
  String get yourReply => 'Your Reply';

  @override
  String get replyToAdmin => 'Reply to Admin';

  @override
  String get replySentSuccess => 'Your reply was sent successfully';

  @override
  String get conversationThread => 'Conversation';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get floatingMessages => 'Floating Messages';

  @override
  String get kickedFromRoom => 'Removed from Room';

  @override
  String get kickedFromRoomBody =>
      'A moderator has removed you from this room.';

  @override
  String get tempBannedFromRoom => 'Temporarily Banned';

  @override
  String get tempBannedFromRoomBody =>
      'You have been temporarily banned from this room.';

  @override
  String get attendeesLabel => 'Attendees';

  @override
  String attendeesCount(int count) {
    return '$count attending';
  }

  @override
  String moreAttendees(int count) {
    return '+$count more';
  }

  @override
  String attendeesNow(int count) {
    return '$count listening now';
  }

  @override
  String get noAttendeesYet => 'No one is here yet';

  @override
  String get moderatorBadge => 'Moderator';

  @override
  String get ghostModeEnabled => 'Ghost mode on — you are hidden from the room';

  @override
  String get ghostModeDisabled =>
      'Ghost mode off — you are visible in the room';

  @override
  String get loudspeaker => 'Loudspeaker';

  @override
  String get earpiece => 'Earpiece';

  @override
  String get roomFull => 'Sorry, this room has reached its maximum capacity.';
}
