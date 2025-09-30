import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flowchart_thesis/screens/settings/views/settings_page.dart';
import 'package:flowchart_thesis/screens/user_dashboard/dashboard_page.dart';
import 'package:project_repository/project_repository.dart';
import '../../blocs/auth_bloc/authentication_bloc.dart';
import '../../blocs/auth_bloc/authentication_state.dart';
import '../../blocs/project_bloc/project_bloc.dart';
import '../../screens/auth/views/auth_page.dart';
import '../../screens/user_dashboard/project_workspace/drawing_page/drawing_editor_page.dart';
import '../error/error_page.dart';

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
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  // Getter pubblico per accedere al root navigator (es. per Overlay globale)
  static GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;

  static GoRouter getRouter(AuthenticationBloc authBloc) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: AppRoutes.authPath,
      errorBuilder: (context, state) => ErrorPage(
        error: state.error?.toString() ?? 'Errore di navigazione',
      ),
      redirect: (context, state) => _handleRedirect(authBloc.state, state),
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      routes: [
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) {
            final authState = context.read<AuthenticationBloc>().state;
            if (authState.status == AuthenticationStatus.authenticated) {
              return BlocProvider<ProjectBloc>(
                key: ValueKey('project-bloc-${authState.user.userId}'),
                create: (_) => ProjectBloc(
                  projectRepository: FirebaseProjectRepo(uid: authState.user.userId),
                ),
                child: child,
              );
            }
            return child;
          },
          routes: [
            GoRoute(
              path: AppRoutes.homePath,
              name: AppRoutes.homeName,
              builder: (context, state) => const DashboardPage(),
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
          ],
        ),
        // Rotte non autenticate
        GoRoute(
          path: AppRoutes.authPath,
          name: AppRoutes.authName,
          builder: (context, state) => const AuthPage(),
        ),
        GoRoute(
          path: AppRoutes.errorPath,
          name: AppRoutes.errorName,
          builder: (context, state) {
            final error = state.extra as String?;
            return ErrorPage(
              error: error ?? 'Errore sconosciuto',
            );
          },
        ),
      ],
    );
  }

  static void goToHome(BuildContext context) =>
      context.goNamed(AppRoutes.homeName);
  static void goToAuth(BuildContext context) =>
      context.goNamed(AppRoutes.authName);
  static void goToSettings(BuildContext context) =>
      context.pushNamed(AppRoutes.settingsName);
  static void goToError(BuildContext context, {String? error}) =>
      context.goNamed(AppRoutes.errorName, extra: error);

  static String? _handleRedirect(
      AuthenticationState authState, GoRouterState routerState) {
    final currentPath = routerState.uri.path;
    final isAuthPath = currentPath == AppRoutes.authPath;

    if (authState.status == AuthenticationStatus.unauthenticated &&
        !isAuthPath) {
      return AppRoutes.authPath;
    }
    if (authState.status == AuthenticationStatus.authenticated && isAuthPath) {
      return AppRoutes.homePath;
    }
    return null;
  }
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
