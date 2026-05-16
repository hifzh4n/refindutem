import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );

    assert(localizations != null, 'AppLocalizations was not found.');
    return localizations!;
  }

  String get appTitle => 'ReFind UTeM';
  String get profileTooltip => 'Profile';
  String get logout => 'Log out';
  String get logoutQuestion => 'Log out?';
  String get logoutConfirmation => 'Are you sure you want to log out?';
  String get cancel => 'Cancel';
  String get home => 'Home';
  String get lost => 'Lost';
  String get found => 'Found';
  String get profile => 'Profile';
  String get welcomeBack => 'Welcome back';
  String get loginSubtitle =>
      'Use your UTeM student or staff email to continue.';
  String get loginHeader => 'Log in';
  String get loginHeaderSubtitle =>
      'Access your campus lost and found dashboard.';
  String get studentEmail => 'Student email';
  String get password => 'Password';
  String get loggingIn => 'Logging in...';
  String get login => 'Log in';
  String get registerTitle => 'Join ReFind UTeM';
  String get registerSubtitle =>
      'Create a verified campus account for lost and found reports.';
  String get registerHeader => 'Register';
  String get registerHeaderSubtitle =>
      'Tell us who you are in the UTeM Family.';
  String get firstName => 'First name';
  String get lastName => 'Last name';
  String get email => 'Email';
  String get confirmPassword => 'Confirm password';
  String get creatingAccount => 'Creating account...';
  String get register => 'Register';
  String get createAccount => 'Create account';
  String get newToApp => 'New to ReFind UTeM?';
  String get alreadyHaveAccount => 'Already have an account?';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
