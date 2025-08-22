import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:user_repository/user_repository.dart';

import '../../../blocs/auth_bloc/authentication_state.dart';
import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/sign_in_bloc/sign_in_bloc.dart';
import '../logic/login_functions.dart';
import '../../../config/constants/theme_switch.dart';
import '../widgets/login_form.dart';
import '../widgets/login_separator.dart';
import '../widgets/social_buttons.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => SignInBloc(context.read<UserRepository>())),
      ],
      child: MultiBlocListener(
        listeners: [
          // Listener per l'AuthenticationBloc (stato globale)
          BlocListener<AuthenticationBloc, AuthenticationState>(
            listener: (context, state) {
              if (state.status == AuthenticationStatus.authenticated) {
                context.go('/');
              } else if (state.status == AuthenticationStatus.emailNotVerified) {
                context.go('/verify-email');
              }
            },
          ),
          // Listener per il SignInBloc (operazioni di login)
          BlocListener<SignInBloc, SignInState>(
            listener: (context, state) {
              if (state is SignInFailure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.error),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              // Il successo è gestito dall'AuthenticationBloc
            },
          ),
        ],
        child: Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.brightness_6),
                onPressed: () {
                  Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                },
              ),
            ],
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 600),
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: BlocBuilder<SignInBloc, SignInState>(
                  builder: (context, state) {
                    final isLoading = state is SignInProcess;

                    return Row(
                      children: [
                        Expanded(
                          child: LoginForm(
                            onLogin: (email, password) => loginWithEmail(context, email, password),
                          ),
                        ),
                        const LoginSeparator(),
                        Expanded(
                          child: SocialButtons(
                            isGoogleLoading: isLoading,
                            onGoogleLogin: () => loginWithGoogle(context),
                            onEmailRegister: () => context.go('/register'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}