import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

sealed class AuthenticationEvent extends Equatable {
  const AuthenticationEvent();

  @override
  List<Object> get props => [];
}

class AuthenticationUserChanged extends AuthenticationEvent {
  final MyUser? user;

  const AuthenticationUserChanged(this.user);

  @override
  List<Object> get props => [user ?? MyUser.empty];
}

class AuthenticationUserVerified extends AuthenticationEvent {
  const AuthenticationUserVerified();
}

class AuthenticationLogoutRequested extends AuthenticationEvent {
  const AuthenticationLogoutRequested();
}

class AuthenticationGoogleSignInRequested extends AuthenticationEvent {
  const AuthenticationGoogleSignInRequested();
}


