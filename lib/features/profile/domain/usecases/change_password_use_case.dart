import '../repositories/profile_repository.dart';

class ChangePasswordUseCase {
  const ChangePasswordUseCase(this._repository);

  final ProfileRepository _repository;

  Future<void> call({
    required String currentPassword,
    required String newPassword,
  }) {
    return _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}
