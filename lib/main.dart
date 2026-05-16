import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'core/errors/app_error_mapper.dart';
import 'core/startup/startup_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    AppErrorLogger.instance = const DebugAppErrorLogger();
    final config = await SupabaseConfig.load();
    config.requireConfigured();
    await Supabase.initialize(url: config.url, anonKey: config.anonKey);
  } catch (error, stackTrace) {
    AppErrorLogger.instance.log(
      error,
      stackTrace,
      context: 'startup',
      severity: AppErrorSeverity.fatal,
    );

    if (SupabaseConfig.devFastFail) {
      Error.throwWithStackTrace(error, stackTrace);
    }

    runApp(StartupErrorApp(error: error));
    return;
  }

  runApp(ReFindUtemApp());
}
