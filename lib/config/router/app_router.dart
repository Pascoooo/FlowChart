import 'package:flowchart_thesis/screens/auth/views/login_page.dart';
import 'package:flowchart_thesis/screens/auth/views/register_page.dart';
import 'package:flowchart_thesis/screens/auth/views/forgot_password_page.dart';
import 'package:flowchart_thesis/screens/auth/views/email_verification_page.dart';
import 'package:flowchart_thesis/screens/error/error_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../screens/settings/views/SettingsPage.dart';
import '../../screens/user_dashboard/views/dashboard_sketch.dart';

// Define route constants to avoid magic strings
class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/recover';
  static const String emailVerification = '/verify-email';
  static const String error = '/error';
  static const String settings = '/settings';

  static const Set<String> authRoutes = {login, register, forgotPassword};
}

// Create a custom Listenable for auth state changes
class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }
}

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter get router => _router;

  static final GoRouter _router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      refreshListenable: _AuthStateNotifier(),
      redirect: _handleRedirect,
      routes: _routes,
      errorBuilder: (context, state) => const ErrorPage()
  );

  static String? _handleRedirect(BuildContext context, GoRouterState state) {
    final user = FirebaseAuth.instance.currentUser;
    final currentPath = state.uri.path;
    final isAuthRoute = AppRoutes.authRoutes.contains(currentPath);

    // User not authenticated
    if (user == null) {
      return isAuthRoute ? null : AppRoutes.home;
    }

    // User authenticated but email not verified
    if (!user.emailVerified) {
      return currentPath == AppRoutes.emailVerification
          ? null
          : AppRoutes.emailVerification;
    }

    // User authenticated and verified, redirect away from auth routes
    if (isAuthRoute) {
      return AppRoutes.home;
    }

    return null; // No redirect needed
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
      path: AppRoutes.emailVerification,
      name: 'emailVerification',
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
  ];
}