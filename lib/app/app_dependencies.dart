import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../features/auth/application/auth_state_controller.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/sign_in_use_case.dart';
import '../features/auth/domain/usecases/sign_out_use_case.dart';
import '../features/auth/domain/usecases/sign_up_use_case.dart';
import '../features/profile/domain/repositories/profile_repository.dart';

class AppDependencies extends StatelessWidget {
  const AppDependencies({
    required this.authRepository,
    required this.profileRepository,
    required this.authStateController,
    required this.child,
    super.key,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final AuthStateController authStateController;
  final Widget child;

  static AppDependencyReader of(BuildContext context) {
    return AppDependencyReader(context);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        Provider<ProfileRepository>.value(value: profileRepository),
        ChangeNotifierProvider<AuthStateController>.value(
          value: authStateController,
        ),
        Provider<SignInUseCase>(
          create: (context) => SignInUseCase(context.read<AuthRepository>()),
        ),
        Provider<SignUpUseCase>(
          create: (context) => SignUpUseCase(context.read<AuthRepository>()),
        ),
        Provider<SignOutUseCase>(
          create: (context) => SignOutUseCase(context.read<AuthRepository>()),
        ),
      ],
      child: child,
    );
  }
}

class AppDependencyReader {
  const AppDependencyReader(this._context);

  final BuildContext _context;

  AuthRepository get authRepository => _context.read<AuthRepository>();
  ProfileRepository get profileRepository => _context.read<ProfileRepository>();
  AuthStateController get authState => _context.read<AuthStateController>();
  SignInUseCase get signIn => _context.read<SignInUseCase>();
  SignUpUseCase get signUp => _context.read<SignUpUseCase>();
  SignOutUseCase get signOut => _context.read<SignOutUseCase>();
}
