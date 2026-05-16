import 'package:supabase_flutter/supabase_flutter.dart';

import '../entities/profile_details.dart';

abstract interface class ProfileRepository {
  Future<ProfileDetails> getProfile();

  Future<UserResponse> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
    String? avatarPath,
  });

  Future<AvatarUploadResult> replaceAvatar({required AvatarUploadInput input});

  Future<void> deleteAvatar(String? avatarPath);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  String normalizeMalaysiaPhone(String phone);
}
