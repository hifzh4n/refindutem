import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthRepository {
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  });

  Future<AuthResponse> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  });

  Future<void> signOut();
}
