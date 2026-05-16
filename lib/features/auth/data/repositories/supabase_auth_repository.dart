import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/auth_repository.dart';
import '../services/supabase_auth_service.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({SupabaseAuthService? service})
    : _service = service ?? SupabaseAuthService();

  final SupabaseAuthService _service;

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _service.signIn(email: email, password: password);
  }

  @override
  Future<AuthResponse> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    return _service.signUp(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signOut() {
    return _service.signOut();
  }
}
