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

// Eventi per compatibilità con il codice esistente
class AuthenticationGoogleSignInRequested extends AuthenticationEvent {
  const AuthenticationGoogleSignInRequested();
}

class AuthenticationEmailSignInRequested extends AuthenticationEvent {
  final String email;
  final String password;

  const AuthenticationEmailSignInRequested(this.email, this.password);

  @override
  List<Object> get props => [email, password];
}

class AuthenticationSignUpRequested extends AuthenticationEvent {
  final MyUser user;
  final String password;

  const AuthenticationSignUpRequested(this.user, this.password);

  @override
  List<Object> get props => [user, password];
}

class AuthenticationUserVerified extends AuthenticationEvent {
  const AuthenticationUserVerified();
}
