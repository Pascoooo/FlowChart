// dart
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

enum AuthenticationStatus { unknown, authenticated, unauthenticated }

class AuthenticationState extends Equatable {
  final AuthenticationStatus status;
  final MyUser user;
  final bool isLoading;
  final String? errorMessage;

  const AuthenticationState._({
    required this.status,
    this.user = MyUser.empty,
    this.isLoading = false,
    this.errorMessage,
  });

  const AuthenticationState.unknown()
      : this._(status: AuthenticationStatus.unknown);

  const AuthenticationState.authenticated(MyUser user)
      : this._(
    status: AuthenticationStatus.authenticated,
    user: user,
  );

  const AuthenticationState.unauthenticated({String? errorMessage})
      : this._(
    status: AuthenticationStatus.unauthenticated,
    errorMessage: errorMessage,
  );

  // 'copyWith' è essenziale per la manutenibilità
  AuthenticationState copyWith({
    AuthenticationStatus? status,
    MyUser? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthenticationState._(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    isLoading,
    errorMessage,
  ];
}