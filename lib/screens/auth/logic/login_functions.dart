import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../blocs/auth_bloc/authentication_state.dart';

Future<void> loginWithEmail(BuildContext context, String email, String password) async {
  if (email.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill in all fields')),
    );
    return;
  }

  final bloc = context.read<AuthenticationBloc>();
  bloc.add(AuthenticationEmailSignInRequested(email, password));

  StreamSubscription<AuthenticationState>? sub;
  sub = bloc.stream.listen((state) {
    if (!context.mounted) {
      sub?.cancel();
      return;
    }
    if (state.status == AuthenticationStatus.authenticated) {
      context.go('/');
      sub?.cancel();
    } else if (state.status == AuthenticationStatus.unauthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed')),
      );
      sub?.cancel();
    }
  });
}

Future<void> loginWithGoogle(BuildContext context) async {
  final bloc = context.read<AuthenticationBloc>();
  bloc.add(const AuthenticationGoogleSignInRequested());

  StreamSubscription<AuthenticationState>? sub;
  sub = bloc.stream.listen((state) {
    if (!context.mounted) {
      sub?.cancel();
      return;
    }
    if (state.status == AuthenticationStatus.authenticated) {
      context.go('/');
      sub?.cancel();
    } else if (state.status == AuthenticationStatus.unauthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google login failed')),
      );
      sub?.cancel();
    }
  });
}