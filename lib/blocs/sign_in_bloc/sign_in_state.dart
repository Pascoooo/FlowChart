part of 'sign_in_bloc.dart';

sealed class SignInState extends Equatable {
  const SignInState();

  @override
  List<Object> get props => [];
}

final class SignInInitial extends SignInState {}

final class SignInFailure extends SignInState {
  final String error;

  const SignInFailure(this.error);

  @override
  List<Object> get props => [error];
}

final class SignInProcess extends SignInState {}

final class SignInSuccess extends SignInState {}
