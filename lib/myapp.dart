import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:user_repository/user_repository.dart';
import 'blocs/auth_bloc/authentication_bloc.dart';
import 'myappview.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthenticationBloc(
        userRepository: context.read<UserRepository>(),
      ),
      child: const MyAppView(),
    );
  }
}