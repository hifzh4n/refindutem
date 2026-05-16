import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:refindutem/features/profile/domain/entities/profile_details.dart';
import 'package:refindutem/features/profile/presentation/pages/profile_page.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('loads profile details into fields', (tester) async {
    final profileRepository = MockProfileRepository();
    when(profileRepository.getProfile).thenAnswer(
      (_) async => const ProfileDetails(
        email: 'hifzhan@student.utem.edu.my',
        firstName: 'Hifzhan',
        lastName: 'Fauzi',
        phone: '+60123456789',
        avatarPath: null,
        avatarUrl: null,
      ),
    );
    when(
      () => profileRepository.normalizeMalaysiaPhone(any()),
    ).thenReturn('+60123456789');

    await tester.pumpWidget(
      buildTestApp(
        profileRepository: profileRepository,
        child: const ProfilePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hifzhan'), findsOneWidget);
    expect(find.text('Fauzi'), findsOneWidget);
    expect(find.text('hifzhan@student.utem.edu.my'), findsOneWidget);
    expect(find.text('123456789'), findsWidgets);
  });

  testWidgets('keeps save profile disabled when there are no changes', (
    tester,
  ) async {
    final profileRepository = MockProfileRepository();
    when(profileRepository.getProfile).thenAnswer(
      (_) async => const ProfileDetails(
        email: 'hifzhan@student.utem.edu.my',
        firstName: 'Hifzhan',
        lastName: 'Fauzi',
        phone: '+60123456789',
        avatarPath: null,
        avatarUrl: null,
      ),
    );
    when(
      () => profileRepository.normalizeMalaysiaPhone(any()),
    ).thenReturn('+60123456789');

    await tester.pumpWidget(
      buildTestApp(
        profileRepository: profileRepository,
        child: const ProfilePage(),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save profile'),
    );
    expect(button.onPressed, isNull);
  });
}
