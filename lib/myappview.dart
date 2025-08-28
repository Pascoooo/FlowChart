import 'package:file_repository/file_repository.dart';
import 'package:flowchart_thesis/config/router/app_router.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'blocs/auth_bloc/authentication_bloc.dart';
import 'blocs/auth_bloc/authentication_state.dart';
import 'blocs/file_bloc/file_system_bloc.dart';

class MyAppView extends StatelessWidget {
  const MyAppView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, authState) {
        final router = AppRouter.getRouter(context.read<AuthenticationBloc>());
        return MaterialApp.router(
          key: ValueKey(authState.status),
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          theme: Provider.of<ThemeProvider>(context).themeData,
          title: 'Flowchart Thesis',
          builder: (context, child) {
            if (authState.status == AuthenticationStatus.authenticated) {
              return BlocProvider<FileSystemBloc>(
                key: ValueKey('file-bloc-${authState.user.userId}'),
                create: (context) => FileSystemBloc(
                  fileRepository: FirebaseFileRepo(uid: authState.user.userId),
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