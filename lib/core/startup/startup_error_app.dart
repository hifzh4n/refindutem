import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: StartupErrorScreen(error: error),
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final missingKeys = error is SupabaseConfigException
        ? (error as SupabaseConfigException).missingKeys
        : const <String>[];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                    size: 52,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'App configuration needed',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    missingKeys.isEmpty
                        ? 'The app could not finish startup.'
                        : 'Missing: ${missingKeys.join(', ')}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  const _ConfigStep(
                    title: 'Run with dart-define',
                    body:
                        'flutter run --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_ANON_KEY=...',
                  ),
                  const _ConfigStep(
                    title: 'Local .env fallback',
                    body:
                        'Create a .env file with SUPABASE_URL and SUPABASE_ANON_KEY.',
                  ),
                  const _ConfigStep(
                    title: 'Runtime asset override',
                    body:
                        'Create assets/config/supabase.json from assets/config/supabase.example.json for deployment-specific values.',
                  ),
                  const _ConfigStep(
                    title: 'Dev fast-fail',
                    body:
                        'Add --dart-define=SUPABASE_FAST_FAIL=true if you want startup to throw during local development.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfigStep extends StatelessWidget {
  const _ConfigStep({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            SelectableText(body),
          ],
        ),
      ),
    );
  }
}
