import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../../blocs/auth_bloc/authentication_event.dart';

Future<void> loginWithEmail(BuildContext context, String email, String password) async {
  if (email.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please fill in all fields")),
    );
    return;
  }
  try {
    context.read<AuthenticationBloc>().add(
      AuthenticationEmailSignInRequested(email, password),
    );

    if (!context.mounted) return;
    context.replace('home');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Login failed: $e")),
    );
  }
}

void loginWithGoogle(BuildContext context) {
  context.read<AuthenticationBloc>().add(const AuthenticationGoogleSignInRequested());
}
