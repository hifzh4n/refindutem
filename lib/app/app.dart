import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/constants/app_constants.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/application/auth_state_controller.dart';
import '../features/auth/data/repositories/supabase_auth_repository.dart';
import '../features/profile/data/services/supabase_profile_service.dart';
import 'app_dependencies.dart';
import 'router/app_router.dart';

class ReFindUtemApp extends StatelessWidget {
  ReFindUtemApp({super.key});

  final _authRepository = SupabaseAuthRepository();
  final _profileRepository = SupabaseProfileService();
  final _authStateController = AuthStateController();

  @override
  Widget build(BuildContext context) {
    return AppDependencies(
      authRepository: _authRepository,
      profileRepository: _profileRepository,
      authStateController: _authStateController,
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        routerConfig: createAppRouter(_authStateController),
      ),
    );
  }
}
