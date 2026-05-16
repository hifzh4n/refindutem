class AuthValidators {
  const AuthValidators._();

  static final _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@(student\.utem\.edu\.my|utem\.edu\.my)$',
  );

  static final _passwordPattern = RegExp(
    r'^(?=.*[A-Z])(?=.*[^A-Za-z0-9]).{8,}$',
  );

  static final _namePattern = RegExp(r"^[A-Za-z][A-Za-z '\-./]*$");

  static String? name(String? value, String label) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '$label is required.';
    }

    if (trimmed.length < 2) {
      return '$label must be at least 2 characters.';
    }

    if (trimmed.length > 60) {
      return '$label must be 60 characters or fewer.';
    }

    if (!_namePattern.hasMatch(trimmed)) {
      return '$label can only use letters, spaces, hyphens, apostrophes, dots, and slashes.';
    }

    return null;
  }

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email is required.';
    }

    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Use your UTeM email ending with @student.utem.edu.my or @utem.edu.my.';
    }

    return null;
  }

  static String? password(String? value) {
    final raw = value ?? '';
    if (raw.isEmpty) {
      return 'Password is required.';
    }

    if (!_passwordPattern.hasMatch(raw)) {
      if (raw.length < 8) {
        return 'Password must be at least 8 characters.';
      }

      if (!RegExp(r'[A-Z]').hasMatch(raw)) {
        return 'Password needs at least 1 uppercase letter.';
      }

      if (!RegExp(r'[^A-Za-z0-9]').hasMatch(raw)) {
        return 'Password needs at least 1 special character.';
      }

      return 'Password must include 8 characters, uppercase, and a special character.';
    }

    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if ((value ?? '').isEmpty) {
      return 'Confirm your password.';
    }

    if (value != password) {
      return 'Passwords do not match.';
    }

    return null;
  }

  static String? malaysiaPhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }

    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    final withoutCountryCode = digitsOnly.startsWith('60')
        ? digitsOnly.substring(2)
        : digitsOnly;
    final withoutLeadingZero = withoutCountryCode.replaceFirst(
      RegExp(r'^0+'),
      '',
    );

    if (!RegExp(r'^1[0-9]{8,9}$').hasMatch(withoutLeadingZero)) {
      return 'Enter a valid Malaysia mobile number after +60, for example 123456789.';
    }

    return null;
  }
}
