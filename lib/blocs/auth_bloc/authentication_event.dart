import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

sealed class AuthenticationEvent extends Equatable {
  const AuthenticationEvent();

  @override
  List<Object?> get props => [];
}

class AuthenticationUserChanged extends AuthenticationEvent {
  final MyUser? user;
  const AuthenticationUserChanged(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthenticationLogoutRequested extends AuthenticationEvent {
  const AuthenticationLogoutRequested();
}

class AuthenticationGoogleSignInRequested extends AuthenticationEvent {
  const AuthenticationGoogleSignInRequested();
}

class AuthenticationDeleteAccountRequested extends AuthenticationEvent {
  const AuthenticationDeleteAccountRequested();
}

class AuthenticationDisplayNameUpdateRequested extends AuthenticationEvent {
  final String displayName;
  const AuthenticationDisplayNameUpdateRequested(this.displayName);

  @override
  List<Object?> get props => [displayName];
}

class AuthenticationPhotoUpdateRequested extends AuthenticationEvent {
  final Uint8List photoFileBytes;
  const AuthenticationPhotoUpdateRequested(this.photoFileBytes);

  @override
  List<Object?> get props => [photoFileBytes];
}

class AuthenticationErrorCleared extends AuthenticationEvent {
  const AuthenticationErrorCleared();
}
