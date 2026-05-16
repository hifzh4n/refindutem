import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:refindutem/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:refindutem/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:refindutem/features/auth/domain/usecases/sign_up_use_case.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/widget_test_helpers.dart';

void main() {
  group('auth use cases', () {
    test('SignInUseCase delegates to repository', () async {
      final repository = MockAuthRepository();
      when(
        () => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse());

      await SignInUseCase(repository)(
        email: 'student@student.utem.edu.my',
        password: 'Password1!',
      );

      verify(
        () => repository.signIn(
          email: 'student@student.utem.edu.my',
          password: 'Password1!',
        ),
      ).called(1);
    });

    test('SignUpUseCase delegates to repository', () async {
      final repository = MockAuthRepository();
      when(
        () => repository.signUp(
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse());

      await SignUpUseCase(repository)(
        firstName: 'Hifzhan',
        lastName: 'Fauzi',
        email: 'student@student.utem.edu.my',
        password: 'Password1!',
      );

      verify(
        () => repository.signUp(
          firstName: 'Hifzhan',
          lastName: 'Fauzi',
          email: 'student@student.utem.edu.my',
          password: 'Password1!',
        ),
      ).called(1);
    });

    test('SignOutUseCase delegates to repository', () async {
      final repository = MockAuthRepository();
      when(repository.signOut).thenAnswer((_) async {});

      await SignOutUseCase(repository)();

      verify(repository.signOut).called(1);
    });
  });
}
