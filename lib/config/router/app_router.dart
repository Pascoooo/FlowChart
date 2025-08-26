import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flowchart_thesis/screens/error/error_page.dart';
import 'package:flowchart_thesis/screens/user_dashboard/views/dashboard_sketch.dart';
import 'package:flowchart_thesis/screens/settings/views/SettingsPage.dart';
import '../../blocs/auth_bloc/authentication_bloc.dart';
import '../../screens/auth/pages/auth_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String auth = '/auth';
  static const String settings = '/settings';
  static const String error = '/error';
  static const String splash = '/splash';
}

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final Map<String, GoRouter> _cache = {};

  static GoRouter getRouter(AuthenticationState state) {
    final cacheKey = switch (state.status) {
      AuthenticationStatus.authenticated => 'auth_${state.user?.userId ?? 'unknown'}',
      AuthenticationStatus.unauthenticated => 'unauth',
      AuthenticationStatus.unknown => 'unknown',
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
        switch (state.status) {
          case AuthenticationStatus.unknown:
            return AppRoutes.splash;
          case AuthenticationStatus.unauthenticated:
            return path == AppRoutes.auth ? null : AppRoutes.auth;
          case AuthenticationStatus.authenticated:
            return path == AppRoutes.auth || path == AppRoutes.splash ? AppRoutes.home : null;
        }
      },
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
          path: AppRoutes.auth,
          name: 'auth',
          builder: (context, state) => const AuthPage(),
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
          path: AppRoutes.splash,
          name: 'splash',
          builder: (context, state) => const _SplashPage(),
        ),
      ];
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}