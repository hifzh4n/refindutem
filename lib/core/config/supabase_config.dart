import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.anonKey,
    required this.source,
  });

  static const defineUrl = String.fromEnvironment('SUPABASE_URL');
  static const defineAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const devFastFail = bool.fromEnvironment('SUPABASE_FAST_FAIL');

  final String url;
  final String anonKey;
  final String source;

  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  List<String> get missingKeys => [
    if (url.isEmpty) 'SUPABASE_URL',
    if (anonKey.isEmpty) 'SUPABASE_ANON_KEY',
  ];

  static Future<SupabaseConfig> load({
    Map<String, String> runtimeOverrides = const {},
  }) async {
    final dotenvValues = await _loadDotenv();
    final assetValues = await _loadAssetConfig();

    final url = _firstNonEmpty([
      runtimeOverrides['SUPABASE_URL'],
      defineUrl,
      dotenvValues['SUPABASE_URL'],
      assetValues['SUPABASE_URL'],
    ]);
    final anonKey = _firstNonEmpty([
      runtimeOverrides['SUPABASE_ANON_KEY'],
      defineAnonKey,
      dotenvValues['SUPABASE_ANON_KEY'],
      assetValues['SUPABASE_ANON_KEY'],
    ]);

    return SupabaseConfig(
      url: url,
      anonKey: anonKey,
      source: _sourceFor(runtimeOverrides, dotenvValues, assetValues),
    );
  }

  void requireConfigured() {
    if (isConfigured) {
      return;
    }

    throw SupabaseConfigException(missingKeys);
  }

  static Future<Map<String, String>> _loadDotenv() async {
    try {
      await dotenv.load(fileName: '.env');
      return dotenv.env;
    } catch (_) {
      return const {};
    }
  }

  static Future<Map<String, String>> _loadAssetConfig() async {
    try {
      final raw = await rootBundle.loadString('assets/config/supabase.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const {};
      }

      return decoded.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
    } catch (_) {
      return const {};
    }
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return '';
  }

  static String _sourceFor(
    Map<String, String> runtimeOverrides,
    Map<String, String> dotenvValues,
    Map<String, String> assetValues,
  ) {
    if (runtimeOverrides.values.any((value) => value.trim().isNotEmpty)) {
      return 'runtime override';
    }

    if (defineUrl.isNotEmpty || defineAnonKey.isNotEmpty) {
      return '--dart-define';
    }

    if (dotenvValues.values.any((value) => value.trim().isNotEmpty)) {
      return '.env';
    }

    if (assetValues.values.any((value) => value.trim().isNotEmpty)) {
      return 'assets/config/supabase.json';
    }

    return 'none';
  }
}

class SupabaseConfigException implements Exception {
  const SupabaseConfigException(this.missingKeys);

  final List<String> missingKeys;

  @override
  String toString() {
    return 'Missing Supabase config: ${missingKeys.join(', ')}';
  }
}
