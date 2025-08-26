import 'package:flowchart_thesis/config/router/app_router.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'blocs/auth_bloc/authentication_bloc.dart';
import 'blocs/auth_bloc/authentication_state.dart';

class MyAppView extends StatelessWidget {
  const MyAppView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        return MaterialApp.router(
          routerConfig: AppRouter.getRouter(
              context.read<AuthenticationBloc>()),
          debugShowCheckedModeBanner: false,
          theme: Provider.of<ThemeProvider>(context).themeData,
          title: 'Flowchart Thesis',
        );
      },
    );
  }
}
