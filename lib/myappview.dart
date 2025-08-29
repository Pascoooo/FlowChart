import 'package:flowchart_thesis/config/router/app_router.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:project_repository/project_repository.dart';
import 'package:provider/provider.dart';
import 'blocs/auth_bloc/authentication_bloc.dart';
import 'blocs/auth_bloc/authentication_state.dart';
import 'blocs/project_bloc/project_bloc.dart';

class MyAppView extends StatefulWidget {
  const MyAppView({super.key});

  @override
  State<MyAppView> createState() => _MyAppViewState();
}

class _MyAppViewState extends State<MyAppView> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.getRouter(context.read<AuthenticationBloc>());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, authState) {
        return MaterialApp.router(
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          theme: Provider.of<ThemeProvider>(context).themeData,
          title: 'Flowchart Thesis',
          builder: (context, child) {
            if (authState.status == AuthenticationStatus.authenticated) {
              return BlocProvider<ProjectBloc>(
                key: ValueKey('project-bloc-${authState.user.userId}'),
                create: (context) => ProjectBloc(
                  projectRepository: FirebaseProjectRepo(uid: authState.user.userId),
                ),
                child: child!,
              );
            } else {
              return child!;
            }
          },
        );
      },
    );
  }
}