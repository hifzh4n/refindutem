import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

enum AppErrorSeverity { info, warning, error, fatal }

abstract interface class AppErrorLogger {
  static AppErrorLogger instance = const NoopAppErrorLogger();

  void log(
    Object error,
    StackTrace? stackTrace, {
    required String context,
    AppErrorSeverity severity = AppErrorSeverity.error,
  });
}

class NoopAppErrorLogger implements AppErrorLogger {
  const NoopAppErrorLogger();

  @override
  void log(
    Object error,
    StackTrace? stackTrace, {
    required String context,
    AppErrorSeverity severity = AppErrorSeverity.error,
  }) {}
}

class DebugAppErrorLogger implements AppErrorLogger {
  const DebugAppErrorLogger();

  @override
  void log(
    Object error,
    StackTrace? stackTrace, {
    required String context,
    AppErrorSeverity severity = AppErrorSeverity.error,
  }) {
    developer.log(
      error.toString(),
      name: 'ReFindUTeM.$context',
      error: error,
      stackTrace: stackTrace,
      level: switch (severity) {
        AppErrorSeverity.info => 800,
        AppErrorSeverity.warning => 900,
        AppErrorSeverity.error => 1000,
        AppErrorSeverity.fatal => 1200,
      },
    );
  }
}

class AppErrorMapper {
  const AppErrorMapper._();

  static String friendly(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
    String context = 'app',
    StackTrace? stackTrace,
  }) {
    AppErrorLogger.instance.log(error, stackTrace, context: context);

    return switch (error) {
      AppServiceException(:final message) => message,
      AuthException(:final message) => _authMessage(message),
      StorageException(:final message) => _storageMessage(message),
      PostgrestException(:final message, :final code) => _databaseMessage(
        message,
        code,
      ),
      TimeoutException() => 'The request timed out. Please try again.',
      _ => fallback,
    };
  }

  static String auth(
    Object error, {
    String fallback = 'Could not authenticate. Please try again.',
  }) {
    return friendly(error, fallback: fallback);
  }

  static String storage(
    Object error, {
    String fallback = 'Could not update this file. Please try again.',
  }) {
    return friendly(error, fallback: fallback);
  }

  static String rpc(
    Object error, {
    required String rpcName,
    String fallback = 'Could not complete this request. Please try again.',
  }) {
    if (error case PostgrestException(:final code, :final message)) {
      final normalized = message.toLowerCase();
      if (code == 'PGRST202' || normalized.contains(rpcName.toLowerCase())) {
        return 'This action is not configured yet. Please contact support.';
      }
    }

    return friendly(error, fallback: fallback);
  }

  static String _authMessage(String message) {
    final normalized = message.toLowerCase();

    if (normalized.contains('invalid login credentials')) {
      return 'Email or password is incorrect.';
    }

    if (normalized.contains('email not confirmed')) {
      return 'Please confirm your email before logging in.';
    }

    if (normalized.contains('rate limit') ||
        normalized.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }

    if (normalized.contains('network')) {
      return 'Network issue detected. Check your connection and try again.';
    }

    return message;
  }

  static String _storageMessage(String message) {
    final normalized = message.toLowerCase();

    if (normalized.contains('row-level security') ||
        normalized.contains('permission') ||
        normalized.contains('unauthorized')) {
      return 'You do not have permission to update this file.';
    }

    if (normalized.contains('bucket') && normalized.contains('not found')) {
      return 'Image storage is not configured yet. Please contact support.';
    }

    if (normalized.contains('not found')) {
      return 'The file could not be found. Please choose it again.';
    }

    if (normalized.contains('payload') || normalized.contains('too large')) {
      return 'The selected file is too large.';
    }

    return message;
  }

  static String _databaseMessage(String message, String? code) {
    if (code == '42501' || message.toLowerCase().contains('row-level')) {
      return 'You do not have permission to save this data.';
    }

    if (code == '23505') {
      return 'This record already exists.';
    }

    if (code == '23503') {
      return 'This record is linked to missing data.';
    }

    return message;
  }
}

class AppServiceException implements Exception {
  const AppServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
