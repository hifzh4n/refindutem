import 'package:flutter_test/flutter_test.dart';
import 'package:refindutem/features/auth/data/services/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseAuthService', () {
    test('fails fast when Supabase config is missing', () async {
      final service = SupabaseAuthService();

      expect(
        () => service.signIn(
          email: 'student@student.utem.edu.my',
          password: 'Password1!',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('signOut is a no-op when Supabase config is missing', () async {
      final service = SupabaseAuthService();

      await expectLater(service.signOut(), completes);
    });
  });
}
