import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';

class SignUpUseCase {
  const SignUpUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthResponse> call({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    return _repository.signUp(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
  }
}
