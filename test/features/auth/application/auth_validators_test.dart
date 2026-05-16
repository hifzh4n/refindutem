import 'package:flutter_test/flutter_test.dart';
import 'package:refindutem/features/auth/application/auth_validators.dart';

void main() {
  group('AuthValidators', () {
    test('accepts UTeM email domains', () {
      expect(AuthValidators.email('student@student.utem.edu.my'), isNull);
      expect(AuthValidators.email('staff@utem.edu.my'), isNull);
    });

    test('rejects non-UTeM email domains', () {
      expect(
        AuthValidators.email('person@example.com'),
        'Use your UTeM email ending with @student.utem.edu.my or @utem.edu.my.',
      );
    });

    test('returns granular password messages', () {
      expect(
        AuthValidators.password('short'),
        'Password must be at least 8 characters.',
      );
      expect(
        AuthValidators.password('lowercase1!'),
        'Password needs at least 1 uppercase letter.',
      );
      expect(
        AuthValidators.password('Password1'),
        'Password needs at least 1 special character.',
      );
      expect(AuthValidators.password('Password1!'), isNull);
    });

    test('validates Malaysian phone numbers after +60', () {
      expect(AuthValidators.malaysiaPhone('123456789'), isNull);
      expect(AuthValidators.malaysiaPhone('+60123456789'), isNull);
      expect(
        AuthValidators.malaysiaPhone('223456789'),
        'Enter a valid Malaysia mobile number after +60, for example 123456789.',
      );
    });
  });
}
