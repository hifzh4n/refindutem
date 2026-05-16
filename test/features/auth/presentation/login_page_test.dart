import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:refindutem/core/errors/app_error_mapper.dart';
import 'package:refindutem/features/auth/presentation/pages/login_page.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows inline validation errors before submitting', (
    tester,
  ) async {
    final authRepository = MockAuthRepository();

    await tester.pumpWidget(
      buildTestApp(authRepository: authRepository, child: const LoginPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    verifyNever(
      () => authRepository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('shows mapped auth error inline', (tester) async {
    final authRepository = MockAuthRepository();
    when(
      () => authRepository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const AppServiceException('Email or password is incorrect.'));

    await tester.pumpWidget(
      buildTestApp(authRepository: authRepository, child: const LoginPage()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(EditableText).at(0),
      'student@student.utem.edu.my',
    );
    await tester.enterText(find.byType(EditableText).at(1), 'Password1!');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
  });
}
