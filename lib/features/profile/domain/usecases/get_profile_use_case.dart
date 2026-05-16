import '../entities/profile_details.dart';
import '../repositories/profile_repository.dart';

class GetProfileUseCase {
  const GetProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<ProfileDetails> call() {
    return _repository.getProfile();
  }
}
