import 'package:supabase_flutter/supabase_flutter.dart';

import '../entities/profile_details.dart';
import '../repositories/profile_repository.dart';

class UpdateProfileUseCase {
  const UpdateProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<UserResponse> call({
    required String firstName,
    required String lastName,
    required String phone,
    String? avatarPath,
  }) {
    return _repository.updateProfile(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      avatarPath: avatarPath,
    );
  }
}

class ReplaceAvatarUseCase {
  const ReplaceAvatarUseCase(this._repository);

  final ProfileRepository _repository;

  Future<AvatarUploadResult> call(AvatarUploadInput input) {
    return _repository.replaceAvatar(input: input);
  }
}
