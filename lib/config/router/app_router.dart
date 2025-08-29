import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flowchart_thesis/screens/auth/pages/auth_page.dart';
import 'package:flowchart_thesis/screens/error/error_page.dart';
import 'package:flowchart_thesis/screens/settings/views/SettingsPage.dart';
import 'package:flowchart_thesis/screens/user_dashboard/views/dashboard_page.dart';
import 'package:flowchart_thesis/screens/user_dashboard/sketch_edit/drawing_editor_page.dart'; // <-- FIX
import '../../blocs/auth_bloc/authentication_bloc.dart';
import '../../blocs/auth_bloc/authentication_state.dart';

class AppRoutes {
  static const String homeName = 'home';
  static const String authName = 'auth';
  static const String settingsName = 'settings';
  static const String errorName = 'error';
  static const String drawingEditorName = 'drawing-editor';

  static const String homePath = '/';
  static const String authPath = '/auth';
  static const String settingsPath = '/settings';
  static const String errorPath = '/error';
  static const String drawingEditorPath = '/drawing-editor';
}

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final List<RouteBase> _routes = [
    GoRoute(
      path: AppRoutes.homePath,
      name: AppRoutes.homeName,
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: AppRoutes.authPath,
      name: AppRoutes.authName,
      builder: (context, state) => const AuthPage(),
    ),
    GoRoute(
      path: AppRoutes.settingsPath,
      name: AppRoutes.settingsName,
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: AppRoutes.drawingEditorPath,
      name: AppRoutes.drawingEditorName,
      builder: (context, state) => const DrawingEditorPage(),
    ),
    GoRoute(
      path: AppRoutes.errorPath,
      name: AppRoutes.errorName,
      builder: (context, state) {
        final error = state.extra as String?;
        return ErrorPage(
          error: error ?? 'Errore generico',
          onRetry: () => context.goNamed(AppRoutes.authName),
        );
      },
    ),
  ];

  static GoRouter getRouter(AuthenticationBloc authBloc) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      routes: _routes,
      initialLocation: AppRoutes.authPath,
      errorBuilder: (context, state) => ErrorPage(
        error: state.error?.toString() ?? 'Errore di navigazione',
        onRetry: () => context.goNamed(AppRoutes.homeName),
      ),
      redirect: (context, state) => _handleRedirect(authBloc.state, state),
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
    );
  }

  static String? _handleRedirect(
      AuthenticationState authState, GoRouterState routerState) {
    final currentPath = routerState.uri.path;
    final isAuthPath = currentPath == AppRoutes.authPath;


    if (authState.status == AuthenticationStatus.unauthenticated &&
        !isAuthPath) {
      return AppRoutes.authPath;
    }

    if (authState.status == AuthenticationStatus.authenticated &&
        isAuthPath) {
      return AppRoutes.homePath;
    }

    return null;
  }

  static void goToHome(BuildContext context) =>
      context.goNamed(AppRoutes.homeName);
  static void goToAuth(BuildContext context) =>
      context.goNamed(AppRoutes.authName);
  static void goToSettings(BuildContext context) =>
      context.goNamed(AppRoutes.settingsName);
  static void goToError(BuildContext context, {String? error}) =>
      context.goNamed(AppRoutes.errorName, extra: error);
}


class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}