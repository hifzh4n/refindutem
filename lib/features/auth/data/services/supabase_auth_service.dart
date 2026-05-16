import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_error_mapper.dart';

class SupabaseAuthService {
  SupabaseAuthService();

  SupabaseClient get _client => Supabase.instance.client;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    _ensureConfigured();

    try {
      return await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.auth(
          error,
          fallback: 'Could not log in. Please try again.',
        ),
      );
    }
  }

  Future<AuthResponse> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    _ensureConfigured();

    final fullName = '${firstName.trim()} ${lastName.trim()}'.trim();

    try {
      return await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'name': fullName,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
        },
      );
    } catch (error) {
      throw AppServiceException(
        AppErrorMapper.auth(
          error,
          fallback: 'Could not create account. Please try again.',
        ),
      );
    }
  }

  Future<void> signOut() {
    final client = _tryClient();
    if (client == null) {
      return Future.value();
    }

    return client.auth.signOut();
  }

  void _ensureConfigured() {
    if (_tryClient() == null) {
      throw const AuthException(
        'Missing Supabase configuration. Run Flutter with --dart-define=SUPABASE_URL=your_url and --dart-define=SUPABASE_ANON_KEY=your_anon_key.',
      );
    }
  }

  SupabaseClient? _tryClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
