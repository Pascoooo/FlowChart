import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowchart_thesis/blocs/auth_bloc/authentication_bloc.dart';
import 'package:flowchart_thesis/blocs/auth_bloc/authentication_event.dart';
import 'package:user_repository/user_repository.dart';

class RegisterFunctions {
  bool validateEmail(BuildContext context, String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (email.isEmpty || !regex.hasMatch(email)) {
      showSnackBar(context, 'Inserisci un indirizzo email valido');
      return false;
    }
    return true;
  }

  bool validateNames(BuildContext context, String firstName, String lastName) {
    if (firstName.isEmpty || lastName.isEmpty) {
      showSnackBar(context, 'Nome e cognome sono obbligatori');
      return false;
    }
    return true;
  }

  bool validatePasswords(BuildContext context, String password, String confirm) {
    if (password.length < 6) {
      showSnackBar(context, 'La password deve essere di almeno 6 caratteri');
      return false;
    }
    if (password != confirm) {
      showSnackBar(context, 'Le password non corrispondono');
      return false;
    }
    return true;
  }

  Future<void> signUp(
      BuildContext context,
      String email,
      String firstName,
      String lastName,
      String password,
      ) async {
    final user = MyUser(
      userId: '',
      email: email,
      name: '$firstName $lastName',
      photoURL: '',
    );
    context.read<AuthenticationBloc>().add(
      AuthenticationSignUpRequested(user, password),
    );
  }

  void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}