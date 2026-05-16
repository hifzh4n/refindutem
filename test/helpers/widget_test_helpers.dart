import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:refindutem/app/app_dependencies.dart';
import 'package:refindutem/core/localization/app_localizations.dart';
import 'package:refindutem/core/theme/app_theme.dart';
import 'package:refindutem/features/auth/application/auth_state_controller.dart';
import 'package:refindutem/features/auth/domain/repositories/auth_repository.dart';
import 'package:refindutem/features/profile/domain/entities/profile_details.dart';
import 'package:refindutem/features/profile/domain/repositories/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

Widget buildTestApp({
  required Widget child,
  AuthRepository? authRepository,
  ProfileRepository? profileRepository,
}) {
  final resolvedAuthRepository = authRepository ?? MockAuthRepository();
  final resolvedProfileRepository =
      profileRepository ?? _IdleProfileRepository();

  return AppDependencies(
    authRepository: resolvedAuthRepository,
    profileRepository: resolvedProfileRepository,
    authStateController: _FakeAuthStateController(),
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: child,
    ),
  );
}

class _FakeAuthStateController extends ChangeNotifier
    implements AuthStateController {
  @override
  bool get isSignedIn => true;

  @override
  Session? get session => null;
}

class _IdleProfileRepository implements ProfileRepository {
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> deleteAvatar(String? avatarPath) async {}

  @override
  Future<ProfileDetails> getProfile() async {
    return const ProfileDetails(
      email: 'student@student.utem.edu.my',
      firstName: 'Test',
      lastName: 'User',
      phone: '+60123456789',
      avatarPath: null,
      avatarUrl: null,
    );
  }

  @override
  String normalizeMalaysiaPhone(String phone) => '+60${phone.trim()}';

  @override
  Future<AvatarUploadResult> replaceAvatar({required AvatarUploadInput input}) {
    throw UnimplementedError();
  }

  @override
  Future<UserResponse> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
    String? avatarPath,
  }) {
    throw UnimplementedError();
  }
}
