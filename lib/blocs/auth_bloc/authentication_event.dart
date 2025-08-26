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

class AuthenticationLogoutRequested extends AuthenticationEvent {
  const AuthenticationLogoutRequested();
}

class AuthenticationGoogleSignInRequested extends AuthenticationEvent {
  const AuthenticationGoogleSignInRequested();
}

class AuthenticationEmailLinkRequested extends AuthenticationEvent {
  final String email;

  const AuthenticationEmailLinkRequested(this.email);

  @override
  List<Object> get props => [email];
}

class AuthenticationEmailLinkSignInRequested extends AuthenticationEvent {
  final String email;
  final String emailLink;

  const AuthenticationEmailLinkSignInRequested(this.email, this.emailLink);

  @override
  List<Object> get props => [email, emailLink];
}