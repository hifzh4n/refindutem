import 'package:flutter_test/flutter_test.dart';
import 'package:refindutem/core/errors/app_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppErrorMapper', () {
    test('maps invalid credentials to a friendly auth message', () {
      final message = AppErrorMapper.auth(
        const AuthException('Invalid login credentials'),
      );

      expect(message, 'Email or password is incorrect.');
    });

    test('maps missing RPC to configured support message', () {
      final message = AppErrorMapper.rpc(
        const PostgrestException(message: 'Could not find update_my_phone'),
        rpcName: 'update_my_phone',
      );

      expect(
        message,
        'This action is not configured yet. Please contact support.',
      );
    });

    test('preserves explicit app service messages', () {
      final message = AppErrorMapper.friendly(
        const AppServiceException('Custom friendly message.'),
      );

      expect(message, 'Custom friendly message.');
    });

    test('maps missing storage bucket to configuration message', () {
      final message = AppErrorMapper.storage(
        const StorageException('Bucket not found'),
      );

      expect(
        message,
        'Image storage is not configured yet. Please contact support.',
      );
    });
  });
}
