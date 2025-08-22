import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../blocs/auth_bloc/authentication_state.dart';

class EmailVerificationPage extends StatelessWidget {
  const EmailVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        if (state.status == AuthenticationStatus.authenticated) {
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Verifica Email')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Controlla la tua email e clicca sul link di verifica'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Ricontrolla lo stato di verifica
                  context.read<AuthenticationBloc>().add(
                    const AuthenticationUserVerified(),
                  );
                },
                child: const Text('Ho verificato'),
              ),
              TextButton(
                onPressed: () {
                  context.read<AuthenticationBloc>().add(
                    const AuthenticationLogoutRequested(),
                  );
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}