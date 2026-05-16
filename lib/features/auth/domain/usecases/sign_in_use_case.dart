import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';

class SignInUseCase {
  const SignInUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthResponse> call({required String email, required String password}) {
    return _repository.signIn(email: email, password: password);
  }
}
