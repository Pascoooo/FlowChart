import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../blocs/auth_bloc/authentication_state.dart';
import '../logic/login_functions.dart';
import '../../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../../config/constants/theme_switch.dart';
import '../widgets/login_form.dart';
import '../widgets/login_separator.dart';
import '../widgets/social_buttons.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthenticationBloc>().state;
    final isGoogleLoading =
        authState.isLoading && authState.inProgressProvider == AuthProvider.google;

    return Scaffold(
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
            child: Row(
              children: [
                Expanded(
                  child: LoginForm(
                    onLogin: (email, password) => loginWithEmail(context, email, password),
                  ),
                ),
                const LoginSeparator(),
                Expanded(
                  child: SocialButtons(
                    isGoogleLoading: isGoogleLoading,
                    onGoogleLogin: () => loginWithGoogle(context),
                    onEmailRegister: () => context.go('/register'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
