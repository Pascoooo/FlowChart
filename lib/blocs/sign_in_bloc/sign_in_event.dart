part of 'sign_in_bloc.dart';

sealed class SignInEvent extends Equatable {
  const SignInEvent();

  @override
  List<Object> get props => [];
}

class SignInWithEmailRequested extends SignInEvent {
  final String email;
  final String password;

  const SignInWithEmailRequested({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class SignInWithGoogleRequested extends SignInEvent {
  const SignInWithGoogleRequested();
}

class SignInReset extends SignInEvent {
  const SignInReset();
}