import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_state_controller.dart';
import '../../features/admin/presentation/pages/admin_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/landing/presentation/pages/landing_page.dart';
import '../../features/lost_found/presentation/pages/found_page.dart';
import '../../features/lost_found/presentation/pages/home_page.dart';
import '../../features/lost_found/presentation/pages/lost_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import 'app_routes.dart';

final _protectedRoutes = {
  AppRoutes.home,
  AppRoutes.lost,
  AppRoutes.found,
  AppRoutes.profile,
  AppRoutes.admin,
};

GoRouter createAppRouter(AuthStateController authState) {
  return GoRouter(
    initialLocation: AppRoutes.landing,
    refreshListenable: authState,
    redirect: (context, state) {
      final isSignedIn = authState.isSignedIn;
      final location = state.uri.path;
      final isAuthRoute =
          location == AppRoutes.login || location == AppRoutes.register;
      final isProtectedRoute = _protectedRoutes.contains(location);

      if (!isSignedIn && isProtectedRoute) {
        return AppRoutes.login;
      }

      if (isSignedIn && isAuthRoute) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.landing,
        name: 'landing',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.lost,
        name: 'lost',
        builder: (context, state) => const LostPage(),
      ),
      GoRoute(
        path: AppRoutes.found,
        name: 'found',
        builder: (context, state) => const FoundPage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        name: 'admin',
        builder: (context, state) => const AdminPage(),
      ),
    ],
  );
}
