import 'package:flowchart_thesis/screens/auth/pages/email_verification_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flowchart_thesis/screens/error/error_page.dart';
import 'package:flowchart_thesis/screens/user_dashboard/views/dashboard_sketch.dart';
import 'package:flowchart_thesis/screens/settings/views/SettingsPage.dart';
import '../../blocs/auth_bloc/authentication_state.dart';
import '../../screens/auth/pages/forgot_password_page.dart';
import '../../screens/auth/pages/login_page.dart';
import '../../screens/auth/pages/register_page.dart';
import '../../screens/auth/pages/splashpage.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/recover';
  static const String verifyEmail = '/verify-email';
  static const String settings = '/settings';
  static const String error = '/error';
  static const String unknown = '/splash';

  static const Set<String> authRoutes = {login, register, forgotPassword};
}

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final Map<String, GoRouter> _cache = {};

  static GoRouter getRouter(AuthenticationState state) {
    final cacheKey = switch (state.status) {
      AuthenticationStatus.authenticated =>
      'auth_${state.user?.userId ?? 'unknown'}',
      AuthenticationStatus.unauthenticated => 'unauth',
      AuthenticationStatus.unknown => 'unknown',
      AuthenticationStatus.emailNotVerified => 'email_not_verified',
    };

    final existing = _cache[cacheKey];
    if (existing != null) return existing;
    if (_cache.length > 10) _cache.clear();

      final router = GoRouter(
          navigatorKey: _rootNavigatorKey,
          routes: _routes,
          errorBuilder: (context, state) => const ErrorPage(),
          redirect: (context, goState) {
            final path = goState.uri.path;
            final isAuthRoute = AppRoutes.authRoutes.contains(path);

            switch (state.status) {
              case AuthenticationStatus.unknown:
                return AppRoutes.unknown;
              case AuthenticationStatus.unauthenticated:
                return isAuthRoute ? null : AppRoutes.login;
              case AuthenticationStatus.emailNotVerified:
                return path == '/verify-email' ? null : '/verify-email';
              case AuthenticationStatus.authenticated:
                if (isAuthRoute || path == '/verify-email') {
                  return AppRoutes.home;
                }
                return null;
            }
          }
    );
    _cache[cacheKey] = router;
    return router;
  }

  static List<RouteBase> get _routes => [
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      builder: (context, state) => const DashboardPage(),
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
      path: AppRoutes.forgotPassword,
      name: 'forgotPassword',
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: AppRoutes.verifyEmail,
      name: 'verifyEmail',
      builder: (context, state) => const EmailVerificationPage(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: AppRoutes.error,
      name: 'error',
      builder: (context, state) => const ErrorPage(),
    ),
    GoRoute(
      path: AppRoutes.unknown,
      name: 'splash',
      builder: (context, state) => const SplashPage(),
    ),
  ];
}